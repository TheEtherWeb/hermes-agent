"""
Algorithm 2: Kelly Criterion Optimizer (KCO)
=============================================
Determines optimal bet sizes using the Kelly Criterion and its variants,
with portfolio-level risk management to maximize long-run growth while
controlling drawdown risk.

Key capabilities:
  - Full Kelly, Fractional Kelly (0.25x default), and Half Kelly modes
  - Portfolio correlation matrix to prevent over-concentration
  - Maximum drawdown circuit breakers
  - Expected Value (EV) filtering
  - Risk-adjusted position sizing
  - Bankroll management with per-bet and portfolio-level limits

The Kelly Criterion maximizes the long-run logarithmic growth of capital.
For a binary market where:
  - p = probability of winning
  - q = 1 - p
  - b = net odds (payout / cost - 1)

  Kelly fraction f* = (b*p - q) / b

We use fractional Kelly (f = fraction * f*) to reduce variance
while maintaining most of the growth advantage.
"""

from __future__ import annotations

import math
import statistics
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from .statistical_engine import SAESignal


# ─── Configuration ────────────────────────────────────────────────────────────

@dataclass
class KCOConfig:
    """Configuration parameters for the Kelly Criterion Optimizer."""

    # Kelly fraction to use (0.25 = quarter Kelly, recommended)
    kelly_fraction: float = 0.25

    # Minimum positive EV to consider a bet
    min_ev_threshold: float = 0.03  # 3% minimum EV

    # Maximum fraction of bankroll on any single bet
    max_single_bet_fraction: float = 0.10  # 10% max per bet

    # Maximum fraction of bankroll across all open bets
    max_portfolio_fraction: float = 0.50  # 50% max deployed

    # Maximum correlation between simultaneous bets (0-1)
    max_correlation: float = 0.60

    # Stop-loss: halt trading if drawdown exceeds this fraction
    max_drawdown_fraction: float = 0.20  # 20% drawdown triggers pause

    # Minimum liquidity score from Algorithm 1 to trade
    min_liquidity_score: float = 25.0

    # Minimum edge (probability) to place a bet
    min_edge: float = 0.03

    # Minimum market price to bet (avoid extreme leverage from near-zero priced contracts)
    min_market_price: float = 0.08  # 8 cents minimum

    # Maximum contracts per single bet (hard dollar limit via max_single_bet_fraction)
    max_contracts_per_bet: int = 200

    # Risk tiers and multipliers
    risk_tier_multipliers: Dict[str, float] = field(default_factory=lambda: {
        "LOW": 1.00,
        "MEDIUM": 0.75,
        "HIGH": 0.50,
    })


# ─── Output Signal ────────────────────────────────────────────────────────────

@dataclass
class KCOSignal:
    """Output of the Kelly Criterion Optimizer for a single market."""

    ticker: str
    side: str                        # "YES" or "NO"
    market_price: float              # Price for the chosen side (0-1)

    # Kelly calculation
    raw_kelly_fraction: float        # Uncapped full Kelly fraction
    adjusted_kelly_fraction: float   # After applying kelly_fraction multiplier
    final_bet_fraction: float        # After all caps and risk adjustments

    # EV metrics
    ev_per_dollar: float             # Expected value per dollar invested
    ev_score: float                  # 0-100 score
    expected_profit: float           # In dollars given recommended bet size

    # Risk metrics
    risk_tier: str                   # "LOW", "MEDIUM", or "HIGH"
    risk_score: float                # 0-100 (higher = riskier)
    max_loss: float                  # Maximum possible loss on this bet

    # Position sizing
    recommended_bet_dollars: float   # Dollar amount to bet
    recommended_contracts: int       # Number of contracts (contracts = 100¢ each)

    # Portfolio context
    portfolio_utilization: float     # Current fraction of bankroll deployed
    headroom_fraction: float         # How much more can be deployed

    # Pass/fail decision
    should_bet: bool
    skip_reasons: List[str] = field(default_factory=list)
    reasoning: List[str] = field(default_factory=list)


# ─── Portfolio Tracker ─────────────────────────────────────────────────────────

class PortfolioTracker:
    """
    Tracks active positions and bankroll to enforce portfolio-level limits.
    """

    def __init__(self, initial_bankroll: float = 1000.0):
        self.initial_bankroll = initial_bankroll
        self.current_bankroll = initial_bankroll
        self.peak_bankroll = initial_bankroll
        self._positions: Dict[str, float] = {}  # ticker -> dollars deployed

    @property
    def deployed_dollars(self) -> float:
        return sum(self._positions.values())

    @property
    def deployed_fraction(self) -> float:
        if self.current_bankroll <= 0:
            return 1.0
        return self.deployed_dollars / self.current_bankroll

    @property
    def drawdown_fraction(self) -> float:
        if self.peak_bankroll <= 0:
            return 0.0
        return (self.peak_bankroll - self.current_bankroll) / self.peak_bankroll

    def add_position(self, ticker: str, dollars: float):
        self._positions[ticker] = self._positions.get(ticker, 0) + dollars

    def close_position(self, ticker: str, pnl: float):
        deployed = self._positions.pop(ticker, 0)
        self.current_bankroll += pnl
        self.peak_bankroll = max(self.peak_bankroll, self.current_bankroll)

    def get_positions(self) -> Dict[str, float]:
        return dict(self._positions)

    def update_bankroll(self, amount: float):
        self.current_bankroll = amount
        self.peak_bankroll = max(self.peak_bankroll, amount)

    def to_dict(self) -> Dict:
        return {
            "initial_bankroll": self.initial_bankroll,
            "current_bankroll": self.current_bankroll,
            "peak_bankroll": self.peak_bankroll,
            "positions": self._positions,
        }

    def from_dict(self, data: Dict):
        self.initial_bankroll = data.get("initial_bankroll", self.initial_bankroll)
        self.current_bankroll = data.get("current_bankroll", self.current_bankroll)
        self.peak_bankroll = data.get("peak_bankroll", self.peak_bankroll)
        self._positions = data.get("positions", {})


# ─── Correlation Matrix ───────────────────────────────────────────────────────

class CorrelationMatrix:
    """
    Estimates correlation between market bets based on category and keyword overlap.
    Markets in the same category or series are more correlated.

    Uses Jaccard similarity on category tags as a proxy for correlation.
    """

    @staticmethod
    def estimate_correlation(market_a: Dict, market_b: Dict) -> float:
        """Estimate correlation between two market bets (0-1)."""
        # Same series = highly correlated
        series_a = market_a.get("series_ticker", "")
        series_b = market_b.get("series_ticker", "")
        if series_a and series_b and series_a == series_b:
            return 0.85

        # Same category = moderately correlated
        cat_a = market_a.get("category", "").lower()
        cat_b = market_b.get("category", "").lower()
        if cat_a and cat_b and cat_a == cat_b:
            return 0.50

        # Keyword overlap in titles
        title_a = set((market_a.get("title") or "").lower().split())
        title_b = set((market_b.get("title") or "").lower().split())
        if title_a and title_b:
            intersection = len(title_a & title_b)
            union = len(title_a | title_b)
            if union > 0:
                jaccard = intersection / union
                return min(0.40, jaccard)  # cap keyword overlap at 0.4

        return 0.05  # Low baseline correlation


# ─── Kelly Criterion Optimizer ────────────────────────────────────────────────

class KellyCriterionOptimizer:
    """
    Algorithm 2: Kelly Criterion Optimizer

    Takes signals from the Statistical Analysis Engine and converts them
    into optimal, risk-managed position sizes.

    The core calculation:
      b = net_payout = (1 - price) / price   (profit per dollar bet)
      p = win_probability (from Algorithm 1)
      q = 1 - p
      f* = (b*p - q) / b = (p - q/b)

    Then we scale down by kelly_fraction (default 0.25x = quarter Kelly)
    to reduce variance while capturing most of the growth benefit.
    """

    def __init__(
        self,
        bankroll: float = 1000.0,
        config: Optional[KCOConfig] = None,
    ):
        self.config = config or KCOConfig()
        self.portfolio = PortfolioTracker(initial_bankroll=bankroll)
        self.correlation = CorrelationMatrix()
        self._active_markets: Dict[str, Dict] = {}  # ticker -> market info

    @property
    def bankroll(self) -> float:
        return self.portfolio.current_bankroll

    def update_bankroll(self, new_balance: float):
        """Update bankroll from live account balance."""
        self.portfolio.update_bankroll(new_balance)

    def _compute_kelly(
        self, prob_win: float, price: float
    ) -> Tuple[float, float]:
        """
        Compute raw Kelly fraction and EV per dollar.

        Returns (kelly_fraction, ev_per_dollar).
        kelly_fraction < 0 means bet the other side (or skip).
        """
        if price <= 0 or price >= 1:
            return 0.0, 0.0

        # Net odds: how much you net per dollar bet on a win
        # If price = 0.60, you bet $0.60 to win $1, net = $0.40/$0.60 = 0.667
        net_odds = (1.0 - price) / price

        q = 1.0 - prob_win

        # Kelly formula
        kelly = (net_odds * prob_win - q) / net_odds

        # EV per dollar: E[return] - 1
        ev = prob_win * (1.0 / price) - 1.0

        return kelly, ev

    def _classify_risk(
        self, kelly_fraction: float, price: float, volatility: float
    ) -> Tuple[str, float]:
        """
        Classify bet risk tier: LOW / MEDIUM / HIGH.
        Returns (tier, risk_score 0-100).
        """
        # Higher Kelly fraction = higher conviction but also higher variance
        # Extreme prices (near 0 or 1) = binary risk
        # High volatility = uncertain pricing

        price_risk = abs(price - 0.50) * 2  # 0 at 50¢, 1 at 1¢ or 99¢
        kelly_risk = min(1.0, kelly_fraction * 4)  # Kelly > 25% → max risk
        vol_risk = min(1.0, volatility * 20)

        risk_score = 100.0 * (0.40 * price_risk + 0.40 * kelly_risk + 0.20 * vol_risk)
        risk_score = max(0.0, min(100.0, risk_score))

        if risk_score < 33:
            return "LOW", risk_score
        elif risk_score < 66:
            return "MEDIUM", risk_score
        else:
            return "HIGH", risk_score

    def _check_portfolio_correlation(
        self, ticker: str, market_info: Dict
    ) -> Tuple[bool, str]:
        """
        Check if this bet would be too correlated with existing positions.
        Returns (is_ok, reason_if_not_ok).
        """
        for existing_ticker, existing_info in self._active_markets.items():
            if existing_ticker == ticker:
                continue
            corr = self.correlation.estimate_correlation(market_info, existing_info)
            if corr > self.config.max_correlation:
                return (
                    False,
                    f"Too correlated ({corr:.2f}) with existing position {existing_ticker}",
                )
        return True, ""

    def optimize(
        self,
        sae_signal: SAESignal,
        market_info: Optional[Dict] = None,
    ) -> KCOSignal:
        """
        Compute optimal position size for a market given Algorithm 1's signal.

        Args:
            sae_signal: Signal from StatisticalAnalysisEngine
            market_info: Raw market dict from Kalshi API (for correlation)

        Returns:
            KCOSignal with full position sizing recommendation.
        """
        ticker = sae_signal.ticker
        side = sae_signal.recommended_side
        skip_reasons = []
        reasoning = []

        # ── Determine price for chosen side ──────────────────────────
        if side == "YES":
            price = sae_signal.yes_price
            prob_win = sae_signal.bayesian_prob
        elif side == "NO":
            price = sae_signal.no_price
            prob_win = 1.0 - sae_signal.bayesian_prob
        else:
            # SAE said SKIP — still compute but force should_bet=False
            price = sae_signal.yes_price
            prob_win = sae_signal.bayesian_prob
            skip_reasons.append("Algorithm 1 recommends SKIP")

        price = max(0.01, min(0.99, price))
        prob_win = max(0.01, min(0.99, prob_win))

        # ── Minimum Price Filter ───────────────────────────────────────
        # Avoid extreme-leverage bets on near-zero priced contracts
        if price < self.config.min_market_price:
            skip_reasons.append(
                f"Market price too low ({price:.3f} < {self.config.min_market_price}) — "
                "extreme leverage risk"
            )

        # ── Kelly Calculation ─────────────────────────────────────────
        raw_kelly, ev = self._compute_kelly(prob_win, price)
        reasoning.append(
            f"Raw Kelly={raw_kelly:.4f} | EV/dollar={ev:+.4f} | "
            f"prob_win={prob_win:.3f} | price={price:.3f}"
        )

        # ── EV Filter ──────────────────────────────────────────────────
        if ev < self.config.min_ev_threshold:
            skip_reasons.append(
                f"Insufficient EV ({ev:.3f} < {self.config.min_ev_threshold})"
            )

        # ── Edge Filter ────────────────────────────────────────────────
        if abs(sae_signal.edge) < self.config.min_edge:
            skip_reasons.append(
                f"Edge too small ({sae_signal.edge:.3f} < {self.config.min_edge})"
            )

        # ── Liquidity Filter ───────────────────────────────────────────
        if sae_signal.liquidity_score < self.config.min_liquidity_score:
            skip_reasons.append(
                f"Poor liquidity score ({sae_signal.liquidity_score:.0f})"
            )

        # ── Drawdown Circuit Breaker ───────────────────────────────────
        if self.portfolio.drawdown_fraction >= self.config.max_drawdown_fraction:
            skip_reasons.append(
                f"Drawdown circuit breaker ({self.portfolio.drawdown_fraction:.1%} "
                f">= {self.config.max_drawdown_fraction:.1%})"
            )

        # ── Portfolio Capacity Check ───────────────────────────────────
        deployed = self.portfolio.deployed_fraction
        headroom = self.config.max_portfolio_fraction - deployed
        if headroom <= 0:
            skip_reasons.append(
                f"Portfolio at capacity ({deployed:.1%} deployed, "
                f"max={self.config.max_portfolio_fraction:.1%})"
            )

        # ── Correlation Check ──────────────────────────────────────────
        mkt_info = market_info or {"ticker": ticker, "category": sae_signal.category}
        corr_ok, corr_reason = self._check_portfolio_correlation(ticker, mkt_info)
        if not corr_ok:
            skip_reasons.append(corr_reason)

        # ── Adjust Kelly Fraction ──────────────────────────────────────
        # Start with raw Kelly, apply our multiplier
        adjusted_kelly = raw_kelly * self.config.kelly_fraction
        adjusted_kelly = max(0.0, adjusted_kelly)  # no negative fractions

        # ── Risk Classification ────────────────────────────────────────
        risk_tier, risk_score = self._classify_risk(
            raw_kelly, price, sae_signal.volatility
        )
        tier_multiplier = self.config.risk_tier_multipliers.get(risk_tier, 1.0)
        risk_adjusted_kelly = adjusted_kelly * tier_multiplier

        # ── Apply Hard Caps ────────────────────────────────────────────
        final_fraction = min(
            risk_adjusted_kelly,
            self.config.max_single_bet_fraction,
            max(0.0, headroom),
        )

        # ── Size in Dollars and Contracts ────────────────────────────
        bet_dollars = final_fraction * self.portfolio.current_bankroll
        # Each Kalshi contract costs `price` dollars and pays $1 if it wins
        contracts = max(0, int(bet_dollars / price))
        # Cap contracts to prevent extreme leverage on cheap markets
        contracts = min(contracts, self.config.max_contracts_per_bet)
        actual_bet = contracts * price

        # ── Expected Profit ────────────────────────────────────────────
        expected_profit = actual_bet * ev if ev > 0 else 0.0
        max_loss = actual_bet

        # ── EV Score (0-100) ───────────────────────────────────────────
        ev_score = min(100.0, max(0.0, ev * 200))  # 50% EV → 100 score

        reasoning.append(
            f"Kelly fractions: raw={raw_kelly:.4f} → adjusted={adjusted_kelly:.4f} "
            f"→ risk-adj={risk_adjusted_kelly:.4f} → final={final_fraction:.4f}"
        )
        reasoning.append(
            f"Risk tier={risk_tier} ({risk_score:.0f}/100) | "
            f"Bet=${actual_bet:.2f} ({contracts} contracts) | "
            f"Expected profit=${expected_profit:.2f}"
        )
        reasoning.append(
            f"Portfolio: deployed={deployed:.1%} | headroom={headroom:.1%} | "
            f"drawdown={self.portfolio.drawdown_fraction:.1%}"
        )

        # ── Register Active Market ────────────────────────────────────
        self._active_markets[ticker] = mkt_info

        should_bet = len(skip_reasons) == 0 and contracts > 0 and ev > 0

        return KCOSignal(
            ticker=ticker,
            side=side,
            market_price=price,
            raw_kelly_fraction=raw_kelly,
            adjusted_kelly_fraction=adjusted_kelly,
            final_bet_fraction=final_fraction,
            ev_per_dollar=ev,
            ev_score=ev_score,
            expected_profit=expected_profit,
            risk_tier=risk_tier,
            risk_score=risk_score,
            max_loss=max_loss,
            recommended_bet_dollars=actual_bet,
            recommended_contracts=contracts,
            portfolio_utilization=deployed,
            headroom_fraction=headroom,
            should_bet=should_bet,
            skip_reasons=skip_reasons,
            reasoning=reasoning,
        )

    def optimize_batch(
        self,
        sae_signals: List[SAESignal],
        market_infos: Optional[List[Dict]] = None,
    ) -> List[KCOSignal]:
        """
        Optimize a batch of markets simultaneously.
        Handles portfolio-level allocation across all candidates.

        Markets are processed in order of signal_strength (highest first)
        so stronger opportunities claim bankroll before weaker ones.
        """
        market_map = {}
        if market_infos:
            market_map = {m.get("ticker", ""): m for m in market_infos}

        # Sort by signal strength descending
        sorted_signals = sorted(sae_signals, key=lambda s: s.signal_strength, reverse=True)

        results = []
        for sig in sorted_signals:
            kco = self.optimize(sig, market_info=market_map.get(sig.ticker))
            results.append(kco)
            # Register allocated capital
            if kco.should_bet and kco.recommended_bet_dollars > 0:
                self.portfolio.add_position(sig.ticker, kco.recommended_bet_dollars)

        return results

    def record_outcome(
        self,
        ticker: str,
        contracts: int,
        price: float,
        won: bool,
    ):
        """Record the outcome of a resolved bet and update bankroll."""
        deployed = contracts * price
        if won:
            pnl = contracts * 1.0 - deployed  # Won full $1/contract
        else:
            pnl = -deployed  # Lost the stake

        self.portfolio.close_position(ticker, pnl)
        self._active_markets.pop(ticker, None)

    def get_state(self) -> Dict:
        return {
            "portfolio": self.portfolio.to_dict(),
            "active_markets": self._active_markets,
        }

    def load_state(self, state: Dict):
        if "portfolio" in state:
            self.portfolio.from_dict(state["portfolio"])
        if "active_markets" in state:
            self._active_markets = state["active_markets"]
