"""
Market regime classification using GARCH, ADX, and Hurst exponent.
Runs every REGIME_CLASSIFY_EVERY_N ticks per symbol.
"""
import logging
import numpy as np
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)

# Regime classification thresholds
ADX_TREND_THRESHOLD = 25.0
HURST_TREND_THRESHOLD = 0.6
HURST_REVERT_THRESHOLD = 0.4
ATR_SPIKE_STDEV = 2.0
NEWS_SPIKE_STDEV = 2.0


def classify_regime(prices: list[dict], news_article_count: int = 0,
                    news_avg_count: float = 5.0) -> dict:
    """
    Classify current market regime from price data and news volume.

    Returns:
        regime: str — one of STRONG_TREND, EVENT_DRIVEN, MEAN_REVERTING,
                       HIGH_VOLATILITY, LOW_CONVICTION
        weights: dict — consensus weights for {SENTINEL, ORACLE, PHANTOM}
        metadata: dict — raw indicator values
    """
    if len(prices) < 50:
        return _equal_weights("LOW_CONVICTION", {})

    closes = np.array([p["close"] for p in prices], dtype=float)
    highs = np.array([p["high"] for p in prices], dtype=float)
    lows = np.array([p["low"] for p in prices], dtype=float)
    volumes = np.array([p["volume"] for p in prices], dtype=float)

    # ADX for trend strength
    try:
        import talib
        adx_arr = talib.ADX(highs, lows, closes, timeperiod=14)
        adx = float(adx_arr[-1]) if not np.isnan(adx_arr[-1]) else 15.0
    except Exception:
        adx = 15.0

    # ATR spike detection
    try:
        import talib
        atr_arr = talib.ATR(highs, lows, closes, timeperiod=14)
        atr_current = float(atr_arr[-1]) if not np.isnan(atr_arr[-1]) else 0.0
        atr_mean = float(np.nanmean(atr_arr[-20:])) if len(atr_arr) >= 20 else atr_current
        atr_std = float(np.nanstd(atr_arr[-20:])) + 1e-9
        atr_z = (atr_current - atr_mean) / atr_std
    except Exception:
        atr_z = 0.0

    # Hurst exponent
    from phantom.hurst import compute_hurst
    hurst = compute_hurst(closes)

    # News volume anomaly
    news_z = 0.0
    if news_avg_count > 0:
        news_z = (news_article_count - news_avg_count) / (news_avg_count ** 0.5 + 1e-9)

    metadata = {
        "adx": round(adx, 2),
        "hurst": round(hurst, 4),
        "atr_z": round(atr_z, 2),
        "news_z": round(news_z, 2),
    }

    # Regime priority: Event-Driven > High Volatility > Strong Trend > Mean Reverting > Low Conviction
    if news_z > NEWS_SPIKE_STDEV:
        regime = "EVENT_DRIVEN"
        weights = {"SENTINEL": 0.25, "ORACLE": 0.50, "PHANTOM": 0.25}
    elif atr_z > ATR_SPIKE_STDEV:
        regime = "HIGH_VOLATILITY"
        weights = {"SENTINEL": 0.333, "ORACLE": 0.333, "PHANTOM": 0.334}
    elif adx > ADX_TREND_THRESHOLD and hurst > HURST_TREND_THRESHOLD:
        regime = "STRONG_TREND"
        weights = {"SENTINEL": 0.50, "ORACLE": 0.25, "PHANTOM": 0.25}
    elif hurst < HURST_REVERT_THRESHOLD and adx < ADX_TREND_THRESHOLD:
        regime = "MEAN_REVERTING"
        weights = {"SENTINEL": 0.25, "ORACLE": 0.25, "PHANTOM": 0.50}
    else:
        regime = "LOW_CONVICTION"
        weights = {"SENTINEL": 0.333, "ORACLE": 0.333, "PHANTOM": 0.334}

    return {"regime": regime, "weights": weights, "metadata": metadata}


def _equal_weights(regime: str, metadata: dict) -> dict:
    return {
        "regime": regime,
        "weights": {"SENTINEL": 0.333, "ORACLE": 0.333, "PHANTOM": 0.334},
        "metadata": metadata,
    }
