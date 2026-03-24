"""
SENTINEL signal generation logic.
Produces BUY (1), HOLD (0), or SELL (-1) signals with confidence scores.
Applies self-correction based on rolling false-signal rate.
"""
import logging
import numpy as np
from sentinel.indicators import compute_all, is_valid

logger = logging.getLogger(__name__)

# Minimum required candles for all indicators to be valid
MIN_CANDLES = 210


class SentinelSignalGenerator:
    def __init__(self):
        # Rolling window for false signal tracking (50 iterations)
        self.signal_history: list[int] = []
        self.outcome_history: list[bool] = []
        self.false_signal_window = 50
        self.iteration = 0

        # Feature weights for self-correction (sum to 1.0)
        self.weights = {
            "w_ema_cross": 0.30,
            "w_rsi": 0.20,
            "w_macd": 0.25,
            "w_volume": 0.15,
            "w_bb": 0.10,
        }

    def generate(self, prices: list[dict]) -> dict:
        """
        Generate signal from OHLCV price history.
        Returns: {direction, confidence, price_target, horizon_minutes, feature_weights}
        """
        if len(prices) < MIN_CANDLES:
            logger.debug("SENTINEL: insufficient data (%d/%d candles)", len(prices), MIN_CANDLES)
            return self._hold(prices[-1]["close"] if prices else 0)

        ind = compute_all(prices)
        self.iteration += 1

        # ── EMA crossover signals ─────────────────────────────────────────────
        ema_signal = 0.0
        if is_valid(ind["ema9"]) and is_valid(ind["ema21"]):
            # 9/21 short-term cross
            ema9_cross = (ind["ema9"][-1] > ind["ema21"][-1]) and \
                         (ind["ema9"][-2] <= ind["ema21"][-2])
            ema9_cross_down = (ind["ema9"][-1] < ind["ema21"][-1]) and \
                              (ind["ema9"][-2] >= ind["ema21"][-2])

            if ema9_cross:
                ema_signal += 0.6
            elif ema9_cross_down:
                ema_signal -= 0.6
            else:
                ema_signal += 0.3 if ind["ema9"][-1] > ind["ema21"][-1] else -0.3

        if is_valid(ind["ema50"]) and is_valid(ind["ema200"]):
            # Golden/death cross
            golden = (ind["ema50"][-1] > ind["ema200"][-1]) and \
                     (ind["ema50"][-2] <= ind["ema200"][-2])
            death = (ind["ema50"][-1] < ind["ema200"][-1]) and \
                    (ind["ema50"][-2] >= ind["ema200"][-2])
            if golden:
                ema_signal = min(ema_signal + 0.4, 1.0)
            elif death:
                ema_signal = max(ema_signal - 0.4, -1.0)

        # ── RSI signal ────────────────────────────────────────────────────────
        rsi_signal = 0.0
        if is_valid(ind["rsi"]):
            rsi = ind["rsi"][-1]
            if rsi < 30:
                rsi_signal = 0.8  # oversold → bullish
            elif rsi < 40:
                rsi_signal = 0.4
            elif rsi > 70:
                rsi_signal = -0.8  # overbought → bearish
            elif rsi > 60:
                rsi_signal = -0.4
            else:
                rsi_signal = 0.0

        # ── MACD signal ───────────────────────────────────────────────────────
        macd_signal = 0.0
        if is_valid(ind["macd_hist"]) and is_valid(ind["macd_hist"], -2):
            hist = ind["macd_hist"][-1]
            hist_prev = ind["macd_hist"][-2]
            if hist > 0 and hist > hist_prev:
                macd_signal = 0.7  # bullish momentum accelerating
            elif hist > 0:
                macd_signal = 0.3
            elif hist < 0 and hist < hist_prev:
                macd_signal = -0.7
            elif hist < 0:
                macd_signal = -0.3

        # ── Volume confirmation ────────────────────────────────────────────────
        volume_signal = 0.0
        if is_valid(ind["vol_ma20"]):
            vol_ratio = ind["volumes"][-1] / (ind["vol_ma20"][-1] + 1e-9)
            if vol_ratio > 1.5:  # volume spike confirms signal
                volume_signal = np.sign(ema_signal) * min(vol_ratio / 3.0, 1.0)

        # ── Bollinger Band signal ──────────────────────────────────────────────
        bb_signal = 0.0
        if is_valid(ind["bb_upper"]) and is_valid(ind["bb_lower"]):
            close = ind["closes"][-1]
            upper = ind["bb_upper"][-1]
            lower = ind["bb_lower"][-1]
            mid = ind["bb_mid"][-1]
            bb_range = upper - lower

            if bb_range > 0:
                position = (close - lower) / bb_range
                # Squeeze: volatility contraction → potential breakout
                prev_range = ind["bb_upper"][-5] - ind["bb_lower"][-5] if len(ind["closes"]) >= 5 else bb_range
                squeeze = bb_range < prev_range * 0.7
                if not squeeze:
                    if position < 0.2:
                        bb_signal = 0.5   # near lower band
                    elif position > 0.8:
                        bb_signal = -0.5  # near upper band

        # ── Composite signal ──────────────────────────────────────────────────
        w = self.weights
        raw_score = (
            w["w_ema_cross"] * ema_signal +
            w["w_rsi"]      * rsi_signal +
            w["w_macd"]     * macd_signal +
            w["w_volume"]   * volume_signal +
            w["w_bb"]       * bb_signal
        )

        # Apply whipsaw suppression: reduce confidence if false signal rate is high
        false_rate = self._false_signal_rate()
        suppression = max(0.5, 1.0 - false_rate * 2.0)
        adjusted_score = raw_score * suppression

        # Determine direction and confidence
        abs_score = abs(adjusted_score)
        if abs_score < 0.25:
            direction = 0
            confidence = abs_score / 0.25 * 0.5 + 0.1
        elif adjusted_score > 0:
            direction = 1
            confidence = min(0.5 + abs_score * 0.5, 0.95)
        else:
            direction = -1
            confidence = min(0.5 + abs_score * 0.5, 0.95)

        close = ind["closes"][-1]
        atr = ind["atr"][-1] if is_valid(ind["atr"]) else close * 0.02
        if direction == 1:
            price_target = close + atr * 2.5
        elif direction == -1:
            price_target = close - atr * 2.5
        else:
            price_target = close

        return {
            "direction": direction,
            "confidence": round(float(confidence), 4),
            "price_at_signal": float(close),
            "price_target": round(float(price_target), 4),
            "horizon_minutes": 240,  # 4-hour horizon
            "feature_weights": self.weights.copy(),
            "iteration": self.iteration,
            # Metadata for cross-validator
            "_raw_signals": {
                "ema": ema_signal,
                "rsi": rsi_signal,
                "macd": macd_signal,
                "volume": volume_signal,
                "bb": bb_signal,
            },
        }

    def record_outcome(self, predicted_direction: int, was_correct: bool) -> None:
        """Update rolling false signal tracking."""
        self.signal_history.append(predicted_direction)
        self.outcome_history.append(was_correct)
        if len(self.signal_history) > self.false_signal_window:
            self.signal_history.pop(0)
            self.outcome_history.pop(0)

        # Gradient descent weight update
        if len(self.outcome_history) >= 10:
            self._update_weights(predicted_direction, was_correct)

    def _false_signal_rate(self) -> float:
        if not self.outcome_history:
            return 0.0
        return 1.0 - (sum(self.outcome_history) / len(self.outcome_history))

    def _update_weights(self, direction: int, was_correct: bool) -> None:
        """Simplified gradient descent on feature weights."""
        lr = 0.01
        error = 0.0 if was_correct else float(direction)
        # Nudge weights based on error signal
        for key in self.weights:
            grad = error * 0.1
            self.weights[key] = max(0.05, min(0.60, self.weights[key] - lr * grad))
        # Normalize
        total = sum(self.weights.values())
        self.weights = {k: v / total for k, v in self.weights.items()}

    def _hold(self, close: float) -> dict:
        return {
            "direction": 0,
            "confidence": 0.1,
            "price_at_signal": float(close),
            "price_target": float(close),
            "horizon_minutes": 240,
            "feature_weights": self.weights.copy(),
            "iteration": self.iteration,
        }
