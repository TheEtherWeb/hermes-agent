"""
Consensus engine: combines SENTINEL, ORACLE, PHANTOM outputs into a single prediction.
Weighted by regime classification and rolling accuracy.
Triggers cross-validation every N ticks.
"""
import json
import logging
import numpy as np
from datetime import datetime, timezone
from typing import Optional

from shared.db import get_sync_pg, get_redis
from shared.feature_store import get_algo_weights, publish_prediction
from regime_detector import classify_regime
from cross_validator import run_cross_validation
from config import settings

logger = logging.getLogger(__name__)

_tick_counters: dict[str, int] = {}


def compute_consensus(symbol: str, prices: list[dict], news_count: int = 0) -> Optional[dict]:
    """
    Build consensus prediction from latest individual algorithm predictions.
    Triggers regime classification and cross-validation at configured intervals.
    """
    # Increment tick counter
    _tick_counters[symbol] = _tick_counters.get(symbol, 0) + 1
    tick = _tick_counters[symbol]

    # Regime classification (every N ticks)
    if tick % settings.regime_classify_every_n == 0:
        regime_result = classify_regime(prices, news_count)
        regime = regime_result["regime"]
        regime_weights = regime_result["weights"]
        # Store regime weights as base; cross-validator may override
        from shared.feature_store import set_algo_weights
        # Only update if no custom accuracy-based weights set yet
        current = get_algo_weights(symbol)
        if all(abs(v - 0.333) < 0.01 for v in current.values()):
            set_algo_weights(symbol, regime_weights)
    else:
        regime = "UNKNOWN"

    # Cross-validation (every N ticks)
    if tick % settings.cross_validate_every_n == 0 and tick > 50:
        run_cross_validation(symbol, regime, n=settings.cross_validate_every_n)

    # Fetch latest predictions from each algorithm
    conn = get_sync_pg()
    try:
        preds = _fetch_latest_predictions(conn, symbol)
    finally:
        conn.close()

    if len(preds) < 2:
        logger.debug("Consensus: insufficient predictions for %s (%d algos)", symbol, len(preds))
        return None

    # Apply weights
    weights = get_algo_weights(symbol)
    consensus = _weighted_vote(preds, weights, prices)

    if consensus is None:
        return None

    # LOW_CONVICTION: reduce position size
    if regime == "LOW_CONVICTION":
        if "position_size" in consensus:
            consensus["position_size"] *= 0.5

    # Publish to consensus stream
    r = get_redis()
    r.xadd(
        f"nexus:consensus:{symbol}",
        {k: str(v) for k, v in consensus.items() if v is not None},
        maxlen=1000,
        approximate=True,
    )

    return consensus


def _fetch_latest_predictions(conn, symbol: str) -> dict:
    """Get most recent prediction from each algorithm."""
    preds = {}
    with conn.cursor() as cur:
        for algorithm in ("SENTINEL", "ORACLE", "PHANTOM"):
            cur.execute(
                """
                SELECT direction, confidence, price_at_signal, price_target, horizon_minutes
                FROM predictions
                WHERE symbol = %s AND algorithm = %s
                ORDER BY time DESC LIMIT 1
                """,
                (symbol, algorithm),
            )
            row = cur.fetchone()
            if row:
                preds[algorithm] = {
                    "direction": int(row[0]),
                    "confidence": float(row[1]),
                    "price_at_signal": float(row[2]),
                    "price_target": float(row[3]) if row[3] else None,
                    "horizon_minutes": int(row[4]),
                }
    return preds


def _weighted_vote(preds: dict, weights: dict, prices: list[dict]) -> Optional[dict]:
    """Compute weighted consensus from individual predictions."""
    if not preds or not prices:
        return None

    current_price = float(prices[-1]["close"])

    # Weighted direction vote
    direction_score = 0.0
    total_weight = 0.0
    weighted_target = 0.0
    confidence_products = []

    for algo, pred in preds.items():
        w = weights.get(algo, 0.333)
        direction_score += pred["direction"] * w
        total_weight += w

        if pred.get("price_target"):
            weighted_target += pred["price_target"] * w

        confidence_products.append(pred["confidence"] * w)

    if total_weight < 1e-9:
        return None

    direction_score /= total_weight

    # Consensus direction
    if direction_score > 0.2:
        direction = 1
        direction_label = "LONG"
    elif direction_score < -0.2:
        direction = -1
        direction_label = "SHORT"
    else:
        direction = 0
        direction_label = "NEUTRAL"

    # Consensus price target
    price_target = weighted_target / total_weight if weighted_target else current_price

    # Harmonic mean of confidence × rolling accuracy
    if confidence_products:
        n = len(confidence_products)
        harmonic_conf = n / sum(1.0 / max(c, 0.01) for c in confidence_products)
    else:
        harmonic_conf = 0.3

    # Agreement ratio: fraction of algos agreeing on direction
    directions = [p["direction"] for p in preds.values()]
    majority = max(set(directions), key=directions.count)
    agreement = sum(1 for d in directions if d == majority) / len(directions)

    # Determine timeframe from mode of horizon_minutes
    horizons = [p.get("horizon_minutes", 240) for p in preds.values()]
    median_horizon = float(np.median(horizons))
    if median_horizon <= 240:
        timeframe = "1D"
    elif median_horizon <= 720:
        timeframe = "3D"
    elif median_horizon <= 2016:
        timeframe = "1W"
    else:
        timeframe = "2W"

    return {
        "symbol": symbol if hasattr(symbol, '__class__') else "?",
        "direction": direction,
        "direction_label": direction_label,
        "price_target": round(price_target, 4),
        "confidence": round(harmonic_conf, 4),
        "timeframe": timeframe,
        "algo_agreement": round(agreement, 3),
        "algo_weights": json.dumps(weights),
        "regime": "UNKNOWN",
    }
