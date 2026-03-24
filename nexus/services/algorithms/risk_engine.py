"""
Risk Analysis Engine.
Computes:
  - Historical VaR (95%/99%)
  - Monte Carlo VaR (10,000 paths in prod)
  - Scenario analysis: Bull / Base / Bear / Black Swan
  - Modified Kelly Criterion position sizing
  - ATR-based dynamic stop-loss / take-profit
  - Composite risk score (0–100)
"""
import logging
import numpy as np
from typing import Optional

from shared.db import get_sync_pg, fetch_prices
from phantom.monte_carlo import simulate_paths, compute_var, compute_scenarios
from config import settings

logger = logging.getLogger(__name__)

RISK_LEVEL_THRESHOLDS = [
    (20, "LOW"),
    (40, "MODERATE"),
    (60, "ELEVATED"),
    (80, "HIGH"),
    (100, "EXTREME"),
]


def analyze_risk(
    symbol: str,
    consensus: dict,
    prices: Optional[list[dict]] = None,
) -> dict:
    """
    Full risk analysis for a consensus prediction.
    Returns enriched consensus dict with risk fields.
    """
    if prices is None:
        prices = fetch_prices(symbol, limit=300)

    if len(prices) < 30:
        return _minimal_risk(consensus)

    closes = np.array([p["close"] for p in prices], dtype=float)
    highs = np.array([p["high"] for p in prices], dtype=float)
    lows = np.array([p["low"] for p in prices], dtype=float)
    volumes = np.array([p["volume"] for p in prices], dtype=float)

    current_price = float(closes[-1])

    # ── Historical VaR ────────────────────────────────────────────────────────
    log_returns = np.log(closes[1:] / closes[:-1])
    returns_252 = log_returns[-252:] if len(log_returns) >= 252 else log_returns
    hist_var_95 = abs(float(np.percentile(returns_252, 5)))
    hist_var_99 = abs(float(np.percentile(returns_252, 1)))

    # ── Monte Carlo VaR ────────────────────────────────────────────────────────
    sigma = float(np.std(log_returns[-60:])) * np.sqrt(252 * 8)
    mu = float(np.mean(log_returns[-60:])) * 252 * 8

    mc_paths = simulate_paths(
        current_price=current_price,
        mu=mu,
        sigma=sigma,
        n_paths=settings.monte_carlo_paths,
        n_steps=8,
    )
    mc_var = compute_var(mc_paths, [0.95, 0.99])

    # Use the more conservative of historical vs Monte Carlo
    var_95 = max(hist_var_95, mc_var.get("var_95", hist_var_95))
    var_99 = max(hist_var_99, mc_var.get("var_99", hist_var_99))

    # ── Scenario Analysis ──────────────────────────────────────────────────────
    scenarios = compute_scenarios(mc_paths, current_price)

    # ── ATR-based stop-loss / take-profit ─────────────────────────────────────
    try:
        import talib
        atr_arr = talib.ATR(highs, lows, closes, timeperiod=14)
        atr = float(atr_arr[-1]) if not np.isnan(atr_arr[-1]) else current_price * 0.02
    except Exception:
        atr = current_price * 0.02

    direction = consensus.get("direction", 0)
    if direction == 1:
        stop_loss = current_price - atr * 2.0
        take_profit = current_price + atr * 3.0
    elif direction == -1:
        stop_loss = current_price + atr * 2.0
        take_profit = current_price - atr * 3.0
    else:
        stop_loss = current_price - atr * 1.5
        take_profit = current_price + atr * 1.5

    # ── Composite Risk Score ────────────────────────────────────────────────────
    risk_score = _compute_composite_risk(
        closes=closes,
        volumes=volumes,
        atr=atr,
        algo_agreement=float(consensus.get("algo_agreement", 0.5)),
    )
    risk_level = _score_to_level(risk_score)

    # ── Modified Kelly Position Sizing ─────────────────────────────────────────
    position_size = _kelly_position_size(
        confidence=float(consensus.get("confidence", 0.5)),
        algo_agreement=float(consensus.get("algo_agreement", 0.5)),
        risk_score=risk_score,
        var_95=var_95,
    )

    return {
        **consensus,
        "risk_score": risk_score,
        "risk_level": risk_level,
        "position_size": round(position_size, 4),
        "stop_loss": round(stop_loss, 4),
        "take_profit": round(take_profit, 4),
        "var_95": round(var_95, 4),
        "var_99": round(var_99, 4),
        "scenarios": scenarios,
    }


def _compute_composite_risk(
    closes: np.ndarray,
    volumes: np.ndarray,
    atr: float,
    algo_agreement: float,
) -> int:
    """
    Composite risk score (0–100) weighted sum of 5 factors.
    Weights: Volatility(25%) + AlgoDisagreement(30%) + MaxDrawdown(20%)
             + Correlation(15%) + Liquidity(10%)
    """
    # 1. Volatility (ATR vs 20-day avg ATR) — weight 25%
    if len(closes) >= 20:
        returns = np.log(closes[1:] / closes[:-1])
        recent_vol = float(np.std(returns[-20:])) * np.sqrt(252)
        long_vol = float(np.std(returns)) * np.sqrt(252) + 1e-9
        vol_ratio = recent_vol / long_vol
        vol_score = min(100, vol_ratio * 50)
    else:
        vol_score = 50.0

    # 2. Algorithm disagreement — weight 30%
    disagreement = 1.0 - algo_agreement
    disagreement_score = disagreement * 100

    # 3. Maximum drawdown (60-day) — weight 20%
    if len(closes) >= 60:
        window = closes[-60:]
        running_max = np.maximum.accumulate(window)
        drawdowns = (window - running_max) / (running_max + 1e-9)
        max_dd = abs(float(np.min(drawdowns)))
        dd_score = min(100, max_dd * 300)  # 33% drawdown → 100 score
    else:
        dd_score = 30.0

    # 4. Correlation to market (S&P500 proxy: broad market movement)
    # Simplified: use autocorrelation as proxy for systematic risk
    if len(closes) >= 20:
        returns = np.log(closes[1:] / closes[:-1])
        autocorr = abs(float(np.corrcoef(returns[:-1], returns[1:])[0, 1]))
        corr_score = autocorr * 100
    else:
        corr_score = 40.0

    # 5. Liquidity risk (volume ratio) — weight 10%
    if len(volumes) >= 20:
        recent_vol_avg = float(np.mean(volumes[-5:]))
        long_vol_avg = float(np.mean(volumes[-20:])) + 1e-9
        liq_ratio = long_vol_avg / max(recent_vol_avg, 1)
        liq_score = min(100, (liq_ratio - 1.0) * 50) if liq_ratio > 1 else 0.0
    else:
        liq_score = 20.0

    composite = (
        0.25 * vol_score +
        0.30 * disagreement_score +
        0.20 * dd_score +
        0.15 * corr_score +
        0.10 * liq_score
    )

    return max(0, min(100, int(composite)))


def _score_to_level(score: int) -> str:
    for threshold, level in RISK_LEVEL_THRESHOLDS:
        if score <= threshold:
            return level
    return "EXTREME"


def _kelly_position_size(
    confidence: float,
    algo_agreement: float,
    risk_score: int,
    var_95: float,
) -> float:
    """
    Modified Kelly Criterion for position sizing.
    position_size = kelly_fraction × agreement_multiplier × risk_multiplier × max_allocation
    """
    # Win probability ≈ confidence
    win_probability = confidence
    # Assume reward:risk ratio of 2:1 based on stop/target
    avg_win = 0.02
    avg_loss = 0.01

    if avg_win <= 0:
        return 0.01

    kelly = (win_probability * avg_win - (1 - win_probability) * avg_loss) / avg_win
    kelly = max(0.0, min(kelly, 1.0))  # clamp

    agreement_multiplier = algo_agreement  # 0.33 to 1.0
    risk_multiplier = 1.0 - (risk_score / 100.0)  # 0.0 to 1.0

    # VaR-adjusted: reduce if VaR is unusually high
    var_adjustment = max(0.5, 1.0 - var_95 * 5)

    position_size = kelly * agreement_multiplier * risk_multiplier * var_adjustment * settings.max_allocation
    return max(0.001, min(position_size, settings.max_allocation))


def _minimal_risk(consensus: dict) -> dict:
    """Minimal risk output when insufficient price data."""
    return {
        **consensus,
        "risk_score": 75,
        "risk_level": "HIGH",
        "position_size": 0.01,
        "stop_loss": None,
        "take_profit": None,
        "var_95": 0.05,
        "var_99": 0.08,
        "scenarios": None,
    }
