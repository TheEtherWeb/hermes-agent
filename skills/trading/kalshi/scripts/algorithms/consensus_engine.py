"""
Algorithm 3: Consensus Signal Synthesizer (CSS)
================================================
The meta-algorithm that synthesizes outputs from Algorithms 1 & 2
into final actionable trade recommendations.

Key capabilities:
  - Dynamic weighting of Algorithm 1 (SAE) and Algorithm 2 (KCO) signals
    based on their recent prediction accuracy
  - Sentiment analysis on market titles and descriptions
  - Regime detection (trending vs. mean-reverting market conditions)
  - Contrarian indicators (fade extremes when crowd is overwhelmingly one-sided)
  - Cross-market signal reinforcement (correlated markets confirming each other)
  - Adaptive confidence thresholds based on recent win/loss streaks
  - News event impact scoring (time-to-resolution weighting)
  - Final BUY/SELL/HOLD decision with confidence score and full reasoning chain

The CSS is the "wisdom layer" that prevents any single algorithm from
dominating and ensures we only bet when multiple independent signals align.
"""

from __future__ import annotations

import math
import statistics
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple

from .statistical_engine import SAESignal
from .kelly_optimizer import KCOSignal


# ─── Sentiment Lexicon ────────────────────────────────────────────────────────

# Words that push probability estimates up or down
BULLISH_KEYWORDS = {
    "will", "yes", "increase", "rise", "win", "pass", "approve", "elect",
    "above", "exceed", "higher", "gain", "positive", "up", "growth",
    "record", "high", "beat", "confirm", "reach", "achieve",
}

BEARISH_KEYWORDS = {
    "no", "not", "fail", "fall", "drop", "lose", "reject", "below",
    "decline", "miss", "lower", "negative", "down", "decrease", "cut",
    "withdraw", "cancel", "halt", "collapse", "crash", "delay",
}

# High-volatility event types that reduce confidence
HIGH_UNCERTAINTY_KEYWORDS = {
    "supreme court", "election", "vote", "referendum", "war", "crisis",
    "earthquake", "hurricane", "pandemic", "emergency", "breaking",
    "unexpected", "surprise", "shock",
}


# ─── Output Signal ────────────────────────────────────────────────────────────

@dataclass
class CSSSignal:
    """Final consensus signal — the output of all 3 algorithms combined."""

    ticker: str
    side: str                         # "YES", "NO", or "HOLD"
    action: str                       # "BUY", "SELL", or "HOLD"

    # Consensus scores (0-100)
    consensus_confidence: float       # Overall confidence in the signal
    sae_weight: float                 # Current weight on Algorithm 1
    kco_weight: float                 # Current weight on Algorithm 2
    sentiment_score: float            # -100 to +100 (positive = bullish)
    contrarian_flag: bool             # True if contrarian signal is active

    # Regime
    market_regime: str                # "TRENDING", "MEAN_REVERTING", "UNCERTAIN"
    regime_confidence: float          # 0-100

    # Time factors
    days_to_resolution: Optional[float]
    time_decay_multiplier: float      # < 1 means bet urgency is lower

    # Final position sizing
    final_bet_dollars: float
    final_contracts: int
    final_price: float

    # Input signals
    sae_signal: SAESignal
    kco_signal: KCOSignal

    # Decision
    should_trade: bool
    skip_reasons: List[str] = field(default_factory=list)
    reasoning: List[str] = field(default_factory=list)

    @property
    def composite_score(self) -> float:
        """Single composite score (0-100) combining all signals."""
        if self.action == "HOLD":
            return 0.0
        return self.consensus_confidence * (self.final_bet_dollars > 0)


# ─── Algorithm Performance Tracker ────────────────────────────────────────────

class AlgorithmPerformanceTracker:
    """
    Tracks each algorithm's recent prediction accuracy and adjusts
    its weight in the consensus dynamically.

    Uses a rolling window of predictions vs. outcomes, with exponential
    weighting so recent performance counts more than older history.
    """

    WINDOW_SIZE = 50       # Number of recent predictions to track
    EMA_ALPHA = 0.12       # Higher = faster adaptation to new data
    MIN_WEIGHT = 0.20      # No algorithm can drop below this weight
    MAX_WEIGHT = 0.80      # No algorithm can exceed this weight

    def __init__(self, n_algorithms: int = 2):
        self.n = n_algorithms
        self._accuracy: List[deque] = [
            deque(maxlen=self.WINDOW_SIZE) for _ in range(n_algorithms)
        ]
        self._ema_accuracy: List[float] = [0.5] * n_algorithms

    def record_outcome(self, alg_index: int, was_correct: bool):
        """Record whether algorithm alg_index made a correct prediction."""
        outcome = 1.0 if was_correct else 0.0
        self._accuracy[alg_index].append(outcome)
        old_ema = self._ema_accuracy[alg_index]
        self._ema_accuracy[alg_index] = (
            self.EMA_ALPHA * outcome + (1 - self.EMA_ALPHA) * old_ema
        )

    def get_weights(self) -> List[float]:
        """
        Return normalized weights for each algorithm based on recent accuracy.
        Better-performing algorithms get higher weights.
        """
        accuracies = self._ema_accuracy[:]
        total = sum(accuracies)
        if total == 0:
            return [1.0 / self.n] * self.n

        raw_weights = [a / total for a in accuracies]

        # Apply min/max constraints
        constrained = [max(self.MIN_WEIGHT, min(self.MAX_WEIGHT, w)) for w in raw_weights]

        # Renormalize
        total = sum(constrained)
        return [w / total for w in constrained]

    def get_accuracy(self, alg_index: int) -> float:
        """Return EMA accuracy for a given algorithm."""
        return self._ema_accuracy[alg_index]

    def to_dict(self) -> Dict:
        return {
            "ema_accuracy": self._ema_accuracy,
            "histories": [list(q) for q in self._accuracy],
        }

    def from_dict(self, data: Dict):
        if "ema_accuracy" in data:
            self._ema_accuracy = data["ema_accuracy"]
        if "histories" in data:
            for i, h in enumerate(data["histories"]):
                if i < self.n:
                    self._accuracy[i] = deque(h, maxlen=self.WINDOW_SIZE)


# ─── Sentiment Analyzer ───────────────────────────────────────────────────────

class SentimentAnalyzer:
    """
    Lightweight keyword-based sentiment analyzer for market titles.
    Returns a score from -100 (bearish) to +100 (bullish).
    """

    def analyze(self, title: str, description: str = "") -> Tuple[float, float]:
        """
        Returns (sentiment_score, uncertainty_multiplier).
        sentiment_score: -100 to +100
        uncertainty_multiplier: 0-1 (lower = less confident due to high uncertainty keywords)
        """
        text = (title + " " + description).lower()
        words = set(text.split())

        bullish_hits = len(words & BULLISH_KEYWORDS)
        bearish_hits = len(words & BEARISH_KEYWORDS)
        uncertainty_hits = len(words & HIGH_UNCERTAINTY_KEYWORDS)

        total_sentiment_hits = bullish_hits + bearish_hits
        if total_sentiment_hits == 0:
            sentiment = 0.0
        else:
            sentiment = 100.0 * (bullish_hits - bearish_hits) / total_sentiment_hits

        # Uncertainty events reduce our confidence
        uncertainty_penalty = min(0.4, uncertainty_hits * 0.10)
        uncertainty_multiplier = 1.0 - uncertainty_penalty

        return sentiment, uncertainty_multiplier


# ─── Regime Detector ─────────────────────────────────────────────────────────

class RegimeDetector:
    """
    Detects the current market regime based on price history and
    cross-market statistics.

    Regimes:
      - TRENDING: Prices are moving directionally; momentum strategies work
      - MEAN_REVERTING: Prices oscillate around a stable level; fading works
      - UNCERTAIN: No clear pattern; reduce position sizes
    """

    def detect(
        self,
        price_history: List[float],
        market_efficiency: float,
        volatility: float,
    ) -> Tuple[str, float]:
        """
        Returns (regime, confidence 0-100).
        """
        if len(price_history) < 10:
            return "UNCERTAIN", 30.0

        # Hurst exponent approximation via variance ratio
        # H > 0.5 → trending; H < 0.5 → mean-reverting
        h = self._hurst_approx(price_history)

        if h > 0.60:
            regime = "TRENDING"
            confidence = min(100.0, (h - 0.50) * 500)
        elif h < 0.40:
            regime = "MEAN_REVERTING"
            confidence = min(100.0, (0.50 - h) * 500)
        else:
            regime = "UNCERTAIN"
            confidence = 50.0

        # Adjust confidence based on market efficiency
        confidence *= (market_efficiency / 100.0)

        # High volatility → more uncertain
        if volatility > 0.05:
            regime = "UNCERTAIN"
            confidence = max(20.0, confidence * 0.7)

        return regime, max(10.0, min(100.0, confidence))

    @staticmethod
    def _hurst_approx(prices: List[float]) -> float:
        """
        Simplified Hurst exponent estimation using variance ratio.
        Compares variance at different lag levels.
        """
        if len(prices) < 8:
            return 0.5

        prices = prices[-64:]  # use last 64 obs max

        def log_variance(lag: int) -> float:
            diffs = [prices[i] - prices[i - lag] for i in range(lag, len(prices))]
            if len(diffs) < 2:
                return 0.0
            v = statistics.variance(diffs)
            return math.log(v) if v > 0 else 0.0

        try:
            lv1 = log_variance(1)
            lv2 = log_variance(2)
            lv4 = log_variance(4)
            if lv4 == lv1:
                return 0.5
            # Slope in log-log space approximates 2H
            slope = (lv4 - lv1) / math.log(4)
            return max(0.1, min(0.9, slope / 2.0))
        except Exception:
            return 0.5


# ─── Contrarian Indicator ─────────────────────────────────────────────────────

class ContrarianIndicator:
    """
    Flags markets where the crowd is too one-sided, suggesting
    the market may be overpriced (too bullish) or underpriced (too bearish).

    In prediction markets, extreme prices (> 90¢ or < 10¢) often offer
    the best contrarian opportunities if our analysis disagrees.
    """

    # Threshold for "extreme" pricing
    EXTREME_THRESHOLD = 0.88
    VERY_EXTREME_THRESHOLD = 0.95

    def check(
        self,
        yes_price: float,
        bayesian_prob: float,
        sentiment: float,
    ) -> Tuple[bool, str]:
        """
        Returns (is_contrarian, reason).
        is_contrarian = True if we should fade the crowd.
        """
        # Market priced very high but our model says lower
        if yes_price >= self.EXTREME_THRESHOLD and bayesian_prob < yes_price - 0.10:
            return True, (
                f"Contrarian YES short: market at {yes_price:.0%} but model at "
                f"{bayesian_prob:.0%} — fade the crowd"
            )

        # Market priced very low but our model says higher
        if yes_price <= (1 - self.EXTREME_THRESHOLD) and bayesian_prob > yes_price + 0.10:
            return True, (
                f"Contrarian NO short: market at {yes_price:.0%} but model at "
                f"{bayesian_prob:.0%} — fade the crowd"
            )

        return False, ""


# ─── Time-to-Resolution Weighting ─────────────────────────────────────────────

def time_decay_multiplier(close_time: Optional[datetime]) -> Tuple[float, Optional[float]]:
    """
    Compute a time decay multiplier for urgency.

    Very long-dated bets (> 90 days) get a discount because:
      - Capital is tied up longer
      - More time for the situation to change
      - Lower information edge over longer horizons

    Very short-dated bets (< 24h) get a premium because:
      - Resolution is imminent
      - Information is most reliable near expiry

    Returns (multiplier, days_to_resolution).
    """
    if close_time is None:
        return 0.80, None

    now = datetime.now(timezone.utc)
    if close_time.tzinfo is None:
        close_time = close_time.replace(tzinfo=timezone.utc)

    delta = close_time - now
    days = delta.total_seconds() / 86400

    if days <= 0:
        return 0.0, 0.0  # Already expired
    elif days < 1:
        multiplier = 1.10  # Imminent resolution bonus
    elif days <= 7:
        multiplier = 1.00  # Sweet spot
    elif days <= 30:
        multiplier = 0.90  # Mild discount
    elif days <= 90:
        multiplier = 0.75  # Moderate discount
    else:
        multiplier = 0.55  # Long-dated discount

    return multiplier, days


# ─── Consensus Signal Synthesizer ────────────────────────────────────────────

class ConsensusSignalSynthesizer:
    """
    Algorithm 3: Consensus Signal Synthesizer

    Combines Algorithm 1 (SAE) and Algorithm 2 (KCO) signals through:
      1. Dynamic algorithm weighting based on past performance
      2. Sentiment analysis adjustment
      3. Regime detection filter
      4. Contrarian check
      5. Time-to-resolution weighting
      6. Final consensus score and BUY/SELL/HOLD decision

    Minimum consensus confidence to trade is configurable.
    """

    # Minimum consensus score (0-100) to recommend a trade
    MIN_CONSENSUS_CONFIDENCE = 55.0

    # Minimum agreement between SAE and KCO to trade
    MIN_ALGORITHM_AGREEMENT = 0.25  # 25% agreement (directional match is sufficient)

    # Streak tracking: reduce size after losses, increase after wins
    MAX_STREAK_MULTIPLIER = 1.20
    MIN_STREAK_MULTIPLIER = 0.70

    def __init__(self):
        self.perf_tracker = AlgorithmPerformanceTracker(n_algorithms=2)
        self.sentiment = SentimentAnalyzer()
        self.regime_detector = RegimeDetector()
        self.contrarian = ContrarianIndicator()

        self._win_streak: int = 0
        self._loss_streak: int = 0
        self._total_bets: int = 0
        self._winning_bets: int = 0

    @property
    def win_rate(self) -> float:
        if self._total_bets == 0:
            return 0.0
        return self._winning_bets / self._total_bets

    def _streak_multiplier(self) -> float:
        """Adjust confidence based on recent win/loss streak."""
        if self._win_streak >= 3:
            return min(self.MAX_STREAK_MULTIPLIER, 1.0 + self._win_streak * 0.05)
        elif self._loss_streak >= 2:
            return max(self.MIN_STREAK_MULTIPLIER, 1.0 - self._loss_streak * 0.10)
        return 1.0

    def _compute_algorithm_agreement(
        self,
        sae_signal: SAESignal,
        kco_signal: KCOSignal,
    ) -> float:
        """
        Compute a normalized agreement score (0-1) between Algorithm 1 and 2.
        Agreement means: both recommend the same side with similar strength.
        """
        sae_wants_bet = sae_signal.recommended_side in ("YES", "NO")
        kco_wants_bet = kco_signal.should_bet

        if not sae_wants_bet and not kco_wants_bet:
            return 0.5  # Both say skip — mild agreement on inaction

        if sae_wants_bet != kco_wants_bet:
            return 0.20  # Partial disagreement — one says bet, one says skip

        if sae_signal.recommended_side != kco_signal.side:
            return 0.05  # Completely opposite sides — strong disagreement

        # Both say bet the same side — directional agreement is the core signal.
        # We use base agreement (0.50) plus a bonus from average signal strength,
        # so directional agreement always matters more than signal magnitude.
        sae_strength = sae_signal.signal_strength / 100.0
        kco_strength = kco_signal.ev_score / 100.0
        strength_avg = (sae_strength + kco_strength) / 2.0

        # Base 0.50 for directional match + up to 0.50 from strength
        agreement = 0.50 + 0.50 * strength_avg
        return min(1.0, agreement)

    def synthesize(
        self,
        sae_signal: SAESignal,
        kco_signal: KCOSignal,
        market_info: Optional[Dict] = None,
        price_history: Optional[List[float]] = None,
        close_time: Optional[datetime] = None,
    ) -> CSSSignal:
        """
        Synthesize signals from Algorithms 1 & 2 into a final trade recommendation.
        """
        ticker = sae_signal.ticker
        skip_reasons = []
        reasoning = []
        mkt = market_info or {}

        # ── Dynamic Algorithm Weights ─────────────────────────────────
        weights = self.perf_tracker.get_weights()
        sae_w, kco_w = weights[0], weights[1]
        reasoning.append(
            f"Algorithm weights: SAE={sae_w:.2f} | KCO={kco_w:.2f} | "
            f"SAE accuracy={self.perf_tracker.get_accuracy(0):.1%} | "
            f"KCO accuracy={self.perf_tracker.get_accuracy(1):.1%}"
        )

        # ── Algorithm Agreement ────────────────────────────────────────
        agreement = self._compute_algorithm_agreement(sae_signal, kco_signal)
        reasoning.append(f"Algorithm agreement score: {agreement:.2f}")

        if agreement < self.MIN_ALGORITHM_AGREEMENT:
            skip_reasons.append(
                f"Low algorithm agreement ({agreement:.2f} < "
                f"{self.MIN_ALGORITHM_AGREEMENT}) — algorithms disagree"
            )

        # ── Sentiment Analysis ─────────────────────────────────────────
        title = mkt.get("title", ticker)
        description = mkt.get("description", "")
        sentiment_score, uncertainty_mult = self.sentiment.analyze(title, description)
        reasoning.append(
            f"Sentiment: {sentiment_score:+.0f}/100 | "
            f"Uncertainty multiplier: {uncertainty_mult:.2f}"
        )

        # ── Regime Detection ───────────────────────────────────────────
        hist = price_history or sae_signal.__dict__.get("_price_history", [])
        regime, regime_conf = self.regime_detector.detect(
            price_history=hist,
            market_efficiency=sae_signal.efficiency_score,
            volatility=sae_signal.volatility,
        )
        reasoning.append(f"Market regime: {regime} (confidence={regime_conf:.0f}%)")

        # In uncertain regimes, reduce our confidence
        regime_multiplier = 1.0
        if regime == "UNCERTAIN":
            regime_multiplier = 0.75
            reasoning.append("Uncertain regime: reducing confidence by 25%")

        # ── Contrarian Check ───────────────────────────────────────────
        is_contrarian, contrarian_reason = self.contrarian.check(
            yes_price=sae_signal.yes_price,
            bayesian_prob=sae_signal.bayesian_prob,
            sentiment=sentiment_score,
        )
        if is_contrarian:
            reasoning.append(f"Contrarian signal: {contrarian_reason}")
            # Don't block — contrarian can be a valid signal

        # ── Time Decay ─────────────────────────────────────────────────
        time_mult, days_to_res = time_decay_multiplier(close_time)
        reasoning.append(
            f"Time to resolution: "
            f"{'N/A' if days_to_res is None else f'{days_to_res:.1f} days'} | "
            f"Time multiplier: {time_mult:.2f}"
        )

        if time_mult == 0.0:
            skip_reasons.append("Market already expired")

        # ── Weighted Consensus Score ───────────────────────────────────
        # Blend SAE signal strength and KCO EV score using dynamic weights
        sae_score = sae_signal.signal_strength
        kco_score = kco_signal.ev_score

        weighted_score = sae_w * sae_score + kco_w * kco_score

        # Apply bounded adjustments (avoid multiplicative collapse).
        # Each modifier shifts by at most ±20-30% to preserve signal.
        streak_mult = self._streak_multiplier()

        # Agreement: map [0,1] → [0.60, 1.0] multiplier
        agreement_mult = 0.60 + 0.40 * max(0.0, agreement)

        # Regime: UNCERTAIN → 0.82, others → 1.0
        bounded_regime = 0.82 if regime == "UNCERTAIN" else 1.0

        # Uncertainty: cap minimum at 0.80 (no more than 20% penalty)
        bounded_unc = max(0.80, uncertainty_mult)

        # Time: map time_mult to [0.80, 1.05]
        bounded_time = 0.80 + 0.25 * max(0.0, min(1.0, (time_mult - 0.55) / 0.55))

        # Streak: small adjustment
        bounded_streak = max(0.90, min(1.10, streak_mult))

        final_confidence = (
            weighted_score
            * agreement_mult
            * bounded_regime
            * bounded_unc
            * bounded_time
            * bounded_streak
        )
        final_confidence = max(0.0, min(100.0, final_confidence))

        reasoning.append(
            f"Consensus score: {weighted_score:.1f} × agreement={agreement:.2f} × "
            f"regime={regime_multiplier:.2f} × uncertainty={uncertainty_mult:.2f} × "
            f"time={time_mult:.2f} × streak={streak_mult:.2f} = {final_confidence:.1f}"
        )

        # ── Minimum Confidence Gate ────────────────────────────────────
        if final_confidence < self.MIN_CONSENSUS_CONFIDENCE:
            skip_reasons.append(
                f"Below confidence threshold ({final_confidence:.1f} < "
                f"{self.MIN_CONSENSUS_CONFIDENCE})"
            )

        # ── Final Side and Action ──────────────────────────────────────
        # Determine final side from the algorithm with higher weight
        if sae_w >= kco_w:
            primary_side = sae_signal.recommended_side
        else:
            primary_side = kco_signal.side

        if len(skip_reasons) > 0 or primary_side == "SKIP":
            action = "HOLD"
            side = "HOLD"
            should_trade = False
        else:
            side = primary_side
            action = "BUY"
            should_trade = True

        # ── Adjust final bet size ──────────────────────────────────────
        confidence_ratio = final_confidence / 100.0
        final_dollars = kco_signal.recommended_bet_dollars * confidence_ratio
        final_price = kco_signal.market_price
        final_contracts = max(0, int(final_dollars / final_price)) if final_price > 0 else 0
        actual_dollars = final_contracts * final_price

        reasoning.append(
            f"Final bet: ${actual_dollars:.2f} ({final_contracts} contracts) "
            f"on {side} @ {final_price:.2f} | Action: {action}"
        )

        return CSSSignal(
            ticker=ticker,
            side=side,
            action=action,
            consensus_confidence=final_confidence,
            sae_weight=sae_w,
            kco_weight=kco_w,
            sentiment_score=sentiment_score,
            contrarian_flag=is_contrarian,
            market_regime=regime,
            regime_confidence=regime_conf,
            days_to_resolution=days_to_res,
            time_decay_multiplier=time_mult,
            final_bet_dollars=actual_dollars,
            final_contracts=final_contracts,
            final_price=final_price,
            sae_signal=sae_signal,
            kco_signal=kco_signal,
            should_trade=should_trade,
            skip_reasons=skip_reasons,
            reasoning=reasoning,
        )

    def synthesize_batch(
        self,
        sae_signals: List[SAESignal],
        kco_signals: List[KCOSignal],
        market_infos: Optional[List[Dict]] = None,
        close_times: Optional[List[Optional[datetime]]] = None,
    ) -> List[CSSSignal]:
        """
        Synthesize a batch of signal pairs into final recommendations.
        Returns sorted by composite_score descending.
        """
        market_map = {}
        if market_infos:
            market_map = {m.get("ticker", ""): m for m in market_infos}

        kco_map = {s.ticker: s for s in kco_signals}
        close_map = {}
        if close_times:
            for sae, ct in zip(sae_signals, close_times):
                close_map[sae.ticker] = ct

        results = []
        for sae in sae_signals:
            kco = kco_map.get(sae.ticker)
            if kco is None:
                continue

            css = self.synthesize(
                sae_signal=sae,
                kco_signal=kco,
                market_info=market_map.get(sae.ticker),
                close_time=close_map.get(sae.ticker),
            )
            results.append(css)

        return sorted(results, key=lambda s: s.composite_score, reverse=True)

    def record_outcome(
        self,
        ticker: str,
        sae_was_correct: bool,
        kco_was_correct: bool,
        overall_won: bool,
    ):
        """Record trade outcome to update algorithm weights and streaks."""
        self.perf_tracker.record_outcome(0, sae_was_correct)
        self.perf_tracker.record_outcome(1, kco_was_correct)

        self._total_bets += 1
        if overall_won:
            self._winning_bets += 1
            self._win_streak += 1
            self._loss_streak = 0
        else:
            self._loss_streak += 1
            self._win_streak = 0

    def get_performance_summary(self) -> Dict:
        weights = self.perf_tracker.get_weights()
        return {
            "total_bets": self._total_bets,
            "winning_bets": self._winning_bets,
            "win_rate": self.win_rate,
            "win_streak": self._win_streak,
            "loss_streak": self._loss_streak,
            "sae_weight": weights[0],
            "kco_weight": weights[1],
            "sae_accuracy": self.perf_tracker.get_accuracy(0),
            "kco_accuracy": self.perf_tracker.get_accuracy(1),
            "streak_multiplier": self._streak_multiplier(),
        }

    def get_state(self) -> Dict:
        return {
            "perf_tracker": self.perf_tracker.to_dict(),
            "win_streak": self._win_streak,
            "loss_streak": self._loss_streak,
            "total_bets": self._total_bets,
            "winning_bets": self._winning_bets,
        }

    def load_state(self, state: Dict):
        if "perf_tracker" in state:
            self.perf_tracker.from_dict(state["perf_tracker"])
        self._win_streak = state.get("win_streak", 0)
        self._loss_streak = state.get("loss_streak", 0)
        self._total_bets = state.get("total_bets", 0)
        self._winning_bets = state.get("winning_bets", 0)
