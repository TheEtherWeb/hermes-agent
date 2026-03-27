"""
Algorithm 1: Statistical Analysis Engine (SAE)
===============================================
Performs deep statistical analysis of Kalshi markets to identify:
  - True probability estimates using Bayesian inference
  - Mispriced markets via z-score edge detection
  - Price trend signals via moving averages & momentum
  - Market efficiency scoring
  - Category-level win rate tracking

This algorithm forms the foundational layer — it translates raw
market price data into statistically grounded probability estimates
and edge scores that the other algorithms consume.
"""

from __future__ import annotations

import math
import statistics
from collections import defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple


# ─── Output Signal ────────────────────────────────────────────────────────────

@dataclass
class SAESignal:
    """Output of the Statistical Analysis Engine for a single market."""

    ticker: str
    yes_price: float                  # Current YES price (0-1)
    no_price: float                   # Current NO price (0-1)

    # Bayesian probability estimate
    bayesian_prob: float              # Posterior probability YES resolves true
    bayesian_confidence: float        # Width of credible interval (lower = tighter)

    # Edge detection
    edge: float                       # Signed edge vs market price (positive = we have edge)
    edge_zscore: float                # How many std devs the edge is from zero
    is_mispriced: bool                # True if |edge_zscore| > threshold

    # Trend signals
    trend_direction: str              # "BULLISH", "BEARISH", or "NEUTRAL"
    momentum_score: float             # -1 to +1
    volatility: float                 # Rolling std dev of price changes

    # Market quality
    efficiency_score: float           # 0-100: how efficiently the market is priced
    liquidity_score: float            # 0-100: bid-ask spread quality
    volume_score: float               # 0-100: relative volume

    # Category context
    category: str
    category_win_rate: float          # Historical win rate for this category
    category_sample_size: int         # How many historical markets in this category

    # Signal summary
    signal_strength: float            # 0-100 composite strength
    recommended_side: str             # "YES", "NO", or "SKIP"
    reasoning: List[str] = field(default_factory=list)


# ─── Category Win Rate Tracker ────────────────────────────────────────────────

class CategoryTracker:
    """
    Tracks historical win rates per market category using
    exponential moving averages to give more weight to recent outcomes.
    """

    EMA_ALPHA = 0.15  # Weight on new observations

    def __init__(self):
        # category -> (ema_win_rate, sample_count)
        self._stats: Dict[str, Tuple[float, int]] = {}

    def record_outcome(self, category: str, won: bool):
        """Record a binary win/loss outcome for a category."""
        outcome = 1.0 if won else 0.0
        if category not in self._stats:
            self._stats[category] = (outcome, 1)
        else:
            ema, count = self._stats[category]
            new_ema = self.EMA_ALPHA * outcome + (1 - self.EMA_ALPHA) * ema
            self._stats[category] = (new_ema, count + 1)

    def get_win_rate(self, category: str) -> Tuple[float, int]:
        """Returns (win_rate, sample_count). Defaults to 0.5 if no data."""
        if category not in self._stats:
            return 0.5, 0
        return self._stats[category]

    def to_dict(self) -> Dict:
        return {k: {"win_rate": v[0], "count": v[1]} for k, v in self._stats.items()}

    def from_dict(self, data: Dict):
        self._stats = {k: (v["win_rate"], v["count"]) for k, v in data.items()}


# ─── Price History Buffer ─────────────────────────────────────────────────────

class PriceBuffer:
    """
    Rolling window of price observations for a single market.
    Supports computation of moving averages, momentum, and volatility.
    """

    def __init__(self, maxlen: int = 200):
        self._prices: deque = deque(maxlen=maxlen)
        self._timestamps: deque = deque(maxlen=maxlen)

    def push(self, price: float, ts: Optional[float] = None):
        self._prices.append(price)
        self._timestamps.append(ts or datetime.now(timezone.utc).timestamp())

    @property
    def prices(self) -> List[float]:
        return list(self._prices)

    def sma(self, n: int) -> Optional[float]:
        """Simple moving average over last n observations."""
        if len(self._prices) < n:
            return None
        window = list(self._prices)[-n:]
        return sum(window) / n

    def ema(self, n: int) -> Optional[float]:
        """Exponential moving average over last n observations."""
        if len(self._prices) < n:
            return None
        prices = list(self._prices)[-n:]
        alpha = 2.0 / (n + 1)
        ema_val = prices[0]
        for p in prices[1:]:
            ema_val = alpha * p + (1 - alpha) * ema_val
        return ema_val

    def momentum(self, short_n: int = 5, long_n: int = 20) -> float:
        """
        Momentum score [-1, +1] based on short vs long EMA crossover.
        Positive = bullish momentum (YES price trending up).
        """
        short = self.ema(short_n)
        long = self.ema(long_n)
        if short is None or long is None:
            return 0.0
        # Normalize to [-1, 1]
        diff = short - long
        return max(-1.0, min(1.0, diff / 0.15))

    def volatility(self, n: int = 20) -> float:
        """Rolling std dev of price changes over last n observations."""
        if len(self._prices) < 2:
            return 0.0
        prices = list(self._prices)[-n:]
        changes = [prices[i] - prices[i - 1] for i in range(1, len(prices))]
        if len(changes) < 2:
            return 0.0
        return statistics.stdev(changes)

    def trend_direction(self) -> str:
        """Classify the current trend as BULLISH, BEARISH, or NEUTRAL."""
        mom = self.momentum()
        if mom > 0.15:
            return "BULLISH"
        if mom < -0.15:
            return "BEARISH"
        return "NEUTRAL"


# ─── Bayesian Probability Estimator ──────────────────────────────────────────

class BayesianEstimator:
    """
    Beta-Binomial Bayesian estimator for binary market resolution.

    Prior: Beta(α₀, β₀) — encodes our prior belief about the base rate.
    Posterior is updated with each observed trade at a given price level.

    The market price IS a signal: if the market says 70¢, sophisticated
    participants have priced in their information. We use the market price
    as a strong (but not infallible) prior, then adjust based on:
      - Our historical category win rates
      - Recent price momentum
      - Volume-weighted trade pressure
    """

    # Prior strength (higher = more weight on prior, less reactive to data)
    PRIOR_STRENGTH = 10.0

    def __init__(self):
        pass

    def estimate(
        self,
        market_price: float,          # Current YES price (0-1)
        category_win_rate: float,     # Historical win rate for category
        category_sample_size: int,    # Number of category observations
        momentum: float,              # Price momentum [-1, +1]
        volume_weight: float = 1.0,   # Relative volume (1.0 = average)
    ) -> Tuple[float, float]:
        """
        Returns (posterior_probability, credible_interval_width).

        Lower credible_interval_width = more confident estimate.
        """
        # Prior: weight market price against category base rate.
        # As category sample size grows, category data earns more influence (up to 40%).
        # This allows the algorithm to detect systematic category-level biases vs market prices.
        category_weight = min(category_sample_size / 50.0, 0.40)  # 0→0%, 50→40%
        blended_prior = (
            (1 - category_weight) * market_price +
            category_weight * category_win_rate
        )

        # Alpha, beta parameterize our Beta prior
        alpha_prior = blended_prior * self.PRIOR_STRENGTH
        beta_prior = (1 - blended_prior) * self.PRIOR_STRENGTH

        # Incorporate momentum as soft evidence
        # Momentum pushes our estimate 0-3% in trend direction
        momentum_nudge = momentum * 0.03
        alpha_data = max(0, momentum_nudge) * volume_weight * 5
        beta_data = max(0, -momentum_nudge) * volume_weight * 5

        # Posterior parameters
        alpha_post = alpha_prior + alpha_data
        beta_post = beta_prior + beta_data

        # Posterior mean
        posterior_mean = alpha_post / (alpha_post + beta_post)

        # 95% credible interval width (approximation)
        n = alpha_post + beta_post
        se = math.sqrt(posterior_mean * (1 - posterior_mean) / n)
        ci_width = 2 * 1.96 * se  # 95% CI

        return max(0.01, min(0.99, posterior_mean)), ci_width


# ─── Edge Detection ───────────────────────────────────────────────────────────

class EdgeDetector:
    """
    Detects edges (mispricings) by comparing our probability estimate
    to the current market price, normalized by recent edge distribution.

    Uses a rolling z-score: if our estimated edge is unusually large
    compared to the historical distribution of edges on similar markets,
    it indicates a genuine mispricing worth betting on.
    """

    EDGE_HISTORY_SIZE = 500
    ZSCORE_THRESHOLD = 1.5  # Markets beyond this z-score are considered mispriced

    def __init__(self):
        self._edge_history: deque = deque(maxlen=self.EDGE_HISTORY_SIZE)

    def compute_edge(
        self,
        estimated_prob: float,
        market_price: float,
        side: str = "YES",
    ) -> float:
        """
        Compute the betting edge.
        Edge = estimated_probability - market_price  (for YES side)
        Positive edge = we think YES is underpriced.
        """
        if side == "YES":
            return estimated_prob - market_price
        else:
            return (1 - estimated_prob) - (1 - market_price)

    def compute_ev(self, edge: float, market_price: float, side: str = "YES") -> float:
        """
        Expected value per dollar invested.
        EV = (probability_of_win × payout_per_dollar) - cost_per_dollar
        For YES at price p: payout = 1/p per dollar; win prob = estimated_prob
        """
        if side == "YES":
            prob_win = market_price + edge
            if market_price <= 0:
                return 0.0
            return prob_win * (1.0 / market_price) - 1.0
        else:
            no_price = 1 - market_price
            prob_win = (1 - market_price) + edge
            if no_price <= 0:
                return 0.0
            return prob_win * (1.0 / no_price) - 1.0

    def zscore(self, edge: float) -> float:
        """Z-score of current edge vs historical distribution.
        During cold-start (< 10 samples), returns a proxy score based on
        the absolute edge magnitude so the engine isn't locked out on first use.
        """
        self._edge_history.append(abs(edge))
        if len(self._edge_history) < 10:
            # Bootstrap: treat raw edge as a proxy z-score (0.05 edge ≈ 1.5 z)
            return abs(edge) / 0.033
        hist = list(self._edge_history)
        mean = statistics.mean(hist)
        stdev = statistics.stdev(hist) if len(hist) > 1 else 1e-9
        return (abs(edge) - mean) / max(stdev, 1e-9)

    def is_mispriced(self, zscore: float) -> bool:
        return zscore >= self.ZSCORE_THRESHOLD


# ─── Statistical Analysis Engine ─────────────────────────────────────────────

class StatisticalAnalysisEngine:
    """
    Algorithm 1: Statistical Analysis Engine

    Combines Bayesian inference, momentum analysis, edge detection,
    and category-level win rate tracking into a unified signal.

    Designed to be called repeatedly as new market data arrives.
    Maintains internal state (price buffers, category trackers)
    that improve estimates over time.
    """

    # Minimum edge required before recommending a bet
    MIN_EDGE_THRESHOLD = 0.03  # 3 cents

    # Market efficiency: spread > this means poor liquidity
    POOR_SPREAD_THRESHOLD = 0.08

    def __init__(self):
        self.category_tracker = CategoryTracker()
        self.edge_detector = EdgeDetector()
        self.bayesian = BayesianEstimator()
        self._price_buffers: Dict[str, PriceBuffer] = {}
        self._market_volumes: Dict[str, float] = {}
        self._global_avg_volume = 1.0

    def _get_buffer(self, ticker: str) -> PriceBuffer:
        if ticker not in self._price_buffers:
            self._price_buffers[ticker] = PriceBuffer()
        return self._price_buffers[ticker]

    def ingest_price_history(self, ticker: str, history: List[Dict]):
        """
        Feed historical price candlesticks into the price buffer.
        Each history item should have 'yes_price' (0-100 cents) and optional 'ts'.
        """
        buf = self._get_buffer(ticker)
        for candle in sorted(history, key=lambda x: x.get("ts", 0)):
            price_cents = candle.get("yes_price", candle.get("close", 50))
            price = price_cents / 100.0 if price_cents > 1 else price_cents
            ts = candle.get("ts")
            buf.push(price, ts)

    def ingest_trades(self, ticker: str, trades: List[Dict]):
        """
        Feed recent trade data to update price buffer and volume tracking.
        """
        buf = self._get_buffer(ticker)
        total_vol = 0.0
        for trade in trades:
            price_cents = trade.get("yes_price", 50)
            price = price_cents / 100.0 if price_cents > 1 else price_cents
            count = trade.get("count", 1)
            buf.push(price, trade.get("created_time_unix"))
            total_vol += count

        if total_vol > 0:
            self._market_volumes[ticker] = total_vol
            vols = list(self._market_volumes.values())
            self._global_avg_volume = statistics.mean(vols) if vols else 1.0

    def record_outcome(self, ticker: str, category: str, won: bool):
        """Record a resolved market outcome for learning."""
        self.category_tracker.record_outcome(category, won)

    def analyze(
        self,
        ticker: str,
        yes_price_cents: int,       # Current YES ask price in cents
        no_price_cents: int,        # Current NO ask price in cents
        volume_24h: float = 0,      # 24h volume in contracts
        open_interest: float = 0,   # Open interest
        category: str = "general",
        close_time: Optional[datetime] = None,
    ) -> SAESignal:
        """
        Run full statistical analysis on a market.
        Returns an SAESignal with all computed metrics.
        """
        yes_p = yes_price_cents / 100.0
        no_p = no_price_cents / 100.0

        # ── Price Buffer ───────────────────────────────────────────────
        buf = self._get_buffer(ticker)
        if yes_p > 0:
            buf.push(yes_p)

        momentum = buf.momentum()
        vol = buf.volatility()
        trend = buf.trend_direction()

        # ── Category Stats ─────────────────────────────────────────────
        cat_win_rate, cat_count = self.category_tracker.get_win_rate(category)

        # ── Volume Weight ──────────────────────────────────────────────
        mkt_vol = self._market_volumes.get(ticker, volume_24h)
        vol_weight = mkt_vol / max(self._global_avg_volume, 1.0)
        vol_weight = max(0.1, min(5.0, vol_weight))  # cap 0.1x-5x

        # ── Bayesian Estimate ──────────────────────────────────────────
        bay_prob, ci_width = self.bayesian.estimate(
            market_price=yes_p,
            category_win_rate=cat_win_rate,
            category_sample_size=cat_count,
            momentum=momentum,
            volume_weight=vol_weight,
        )

        # ── Edge Detection ─────────────────────────────────────────────
        # yes_edge and no_edge are always equal in magnitude but opposite in sign.
        # Choose the side based on the DIRECTION of the edge (sign of bay_prob - yes_p).
        # Positive = YES is underpriced → bet YES.
        # Negative = YES is overpriced (NO is underpriced) → bet NO.
        raw_signed_edge = bay_prob - yes_p  # positive = YES edge, negative = NO edge

        if raw_signed_edge >= 0:
            best_side = "YES"
            best_edge = raw_signed_edge
        else:
            best_side = "NO"
            best_edge = abs(raw_signed_edge)  # always store positive magnitude

        edge_z = self.edge_detector.zscore(best_edge)
        is_mispriced = self.edge_detector.is_mispriced(edge_z)

        # ── Liquidity Score ────────────────────────────────────────────
        spread = max(0, 1.0 - yes_p - no_p)  # implied spread
        liquidity_score = max(0.0, 100.0 * (1 - spread / self.POOR_SPREAD_THRESHOLD))
        liquidity_score = min(100.0, liquidity_score)

        # ── Volume Score ───────────────────────────────────────────────
        volume_score = min(100.0, vol_weight * 20.0)

        # ── Market Efficiency ──────────────────────────────────────────
        # Efficient market: implied probs sum near 1, low spread, high volume
        implied_sum = yes_p + no_p
        efficiency_score = 100.0 * (1 - abs(1.0 - implied_sum)) * (liquidity_score / 100.0)
        efficiency_score = max(0.0, min(100.0, efficiency_score))

        # ── Signal Strength ────────────────────────────────────────────
        # Composite score: edge quality × confidence × liquidity
        edge_quality = min(100.0, abs(best_edge) * 500)  # 0.20 edge → 100 pts
        confidence_score = max(0.0, 100.0 * (1 - ci_width))
        signal_strength = (
            0.45 * edge_quality +
            0.30 * confidence_score +
            0.15 * liquidity_score +
            0.10 * volume_score
        )
        signal_strength = max(0.0, min(100.0, signal_strength))

        # ── Decision ──────────────────────────────────────────────────
        if (
            abs(best_edge) >= self.MIN_EDGE_THRESHOLD and
            is_mispriced and
            liquidity_score > 20
        ):
            recommended_side = best_side
        else:
            recommended_side = "SKIP"

        # ── Reasoning ─────────────────────────────────────────────────
        reasoning = []
        reasoning.append(
            f"Bayesian prob={bay_prob:.3f} vs market={yes_p:.3f} → edge={best_edge:+.3f} ({best_side})"
        )
        reasoning.append(f"Edge z-score={edge_z:.2f} ({'mispriced' if is_mispriced else 'efficient'})")
        reasoning.append(f"Trend={trend} | Momentum={momentum:+.3f} | Volatility={vol:.4f}")
        reasoning.append(
            f"Category '{category}': win_rate={cat_win_rate:.1%} over {cat_count} markets"
        )
        reasoning.append(
            f"Liquidity={liquidity_score:.0f}/100 | Volume={volume_score:.0f}/100 | "
            f"Efficiency={efficiency_score:.0f}/100"
        )

        return SAESignal(
            ticker=ticker,
            yes_price=yes_p,
            no_price=no_p,
            bayesian_prob=bay_prob,
            bayesian_confidence=1.0 - ci_width,
            edge=best_edge,
            edge_zscore=edge_z,
            is_mispriced=is_mispriced,
            trend_direction=trend,
            momentum_score=momentum,
            volatility=vol,
            efficiency_score=efficiency_score,
            liquidity_score=liquidity_score,
            volume_score=volume_score,
            category=category,
            category_win_rate=cat_win_rate,
            category_sample_size=cat_count,
            signal_strength=signal_strength,
            recommended_side=recommended_side,
            reasoning=reasoning,
        )

    def analyze_batch(self, markets: List[Dict]) -> List[SAESignal]:
        """
        Analyze a list of market dicts from the Kalshi API.
        Automatically extracts fields and runs analysis on each.
        Returns signals sorted by signal_strength descending.
        """
        signals = []
        for m in markets:
            ticker = m.get("ticker", "")
            yes_price = m.get("yes_ask", m.get("yes_bid", 50))
            no_price = m.get("no_ask", m.get("no_bid", 50))
            category = m.get("category", m.get("event_category", "general"))
            volume = m.get("volume", m.get("volume_24h", 0))

            try:
                close_dt = None
                close_str = m.get("close_time") or m.get("expiration_time")
                if close_str:
                    close_dt = datetime.fromisoformat(close_str.replace("Z", "+00:00"))

                sig = self.analyze(
                    ticker=ticker,
                    yes_price_cents=int(yes_price),
                    no_price_cents=int(no_price),
                    volume_24h=float(volume),
                    category=str(category).lower().replace(" ", "_"),
                    close_time=close_dt,
                )
                signals.append(sig)
            except Exception as e:
                continue  # Skip malformed markets

        return sorted(signals, key=lambda s: s.signal_strength, reverse=True)

    def get_state(self) -> Dict:
        """Serialize engine state for persistence."""
        return {
            "category_tracker": self.category_tracker.to_dict(),
            "edge_history": list(self.edge_detector._edge_history),
            "market_volumes": self._market_volumes,
            "global_avg_volume": self._global_avg_volume,
        }

    def load_state(self, state: Dict):
        """Restore engine state from persistence."""
        if "category_tracker" in state:
            self.category_tracker.from_dict(state["category_tracker"])
        if "edge_history" in state:
            for e in state["edge_history"]:
                self.edge_detector._edge_history.append(e)
        if "market_volumes" in state:
            self._market_volumes = state["market_volumes"]
        if "global_avg_volume" in state:
            self._global_avg_volume = state["global_avg_volume"]
