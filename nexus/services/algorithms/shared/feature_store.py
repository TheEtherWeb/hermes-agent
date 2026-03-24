"""
Redis-backed feature cache.
Stores computed indicator snapshots so algorithms don't recompute
from the same raw data independently.
"""
import json
import logging
from typing import Optional

from shared.db import get_redis

logger = logging.getLogger(__name__)

FEATURE_TTL = 60  # seconds — features expire after 1 minute


def get_features(symbol: str) -> Optional[dict]:
    """Retrieve cached feature snapshot for a symbol."""
    r = get_redis()
    key = f"nexus:features:{symbol}"
    raw = r.get(key)
    if raw:
        return json.loads(raw)
    return None


def set_features(symbol: str, features: dict) -> None:
    """Cache a feature snapshot for a symbol."""
    r = get_redis()
    key = f"nexus:features:{symbol}"
    r.setex(key, FEATURE_TTL, json.dumps(features))


def get_algo_weights(symbol: str) -> dict:
    """Get current consensus weights for a symbol. Defaults to equal thirds."""
    r = get_redis()
    key = f"nexus:algo:weight:{symbol}"
    raw = r.get(key)
    if raw:
        return json.loads(raw)
    return {"SENTINEL": 0.333, "ORACLE": 0.333, "PHANTOM": 0.334}


def set_algo_weights(symbol: str, weights: dict) -> None:
    """Update consensus weights for a symbol (Phase 5 cross-validator writes here)."""
    r = get_redis()
    key = f"nexus:algo:weight:{symbol}"
    r.set(key, json.dumps(weights))


def get_arima_order(symbol: str) -> Optional[tuple]:
    """Get cached ARIMA (p,d,q) order for PHANTOM."""
    r = get_redis()
    key = f"nexus:arima:order:{symbol}"
    raw = r.get(key)
    if raw:
        data = json.loads(raw)
        return tuple(data)
    return None


def set_arima_order(symbol: str, order: tuple) -> None:
    """Cache ARIMA order with 2-hour TTL."""
    r = get_redis()
    key = f"nexus:arima:order:{symbol}"
    r.setex(key, 7200, json.dumps(list(order)))


def publish_prediction(symbol: str, algorithm: str, prediction: dict) -> None:
    """Publish a prediction to the shared predictions stream."""
    r = get_redis()
    key = f"nexus:predictions:{symbol}"
    payload = {"algorithm": algorithm, **prediction}
    r.xadd(key, {k: str(v) for k, v in payload.items()}, maxlen=5000, approximate=True)


def get_latest_sentiment(symbol: str) -> Optional[dict]:
    """Get the most recent sentiment score for a symbol."""
    r = get_redis()
    key = f"nexus:sentiment:latest:{symbol}"
    raw = r.get(key)
    if raw:
        return json.loads(raw)
    return None


def set_latest_sentiment(symbol: str, sentiment: dict) -> None:
    """Cache latest sentiment score."""
    r = get_redis()
    key = f"nexus:sentiment:latest:{symbol}"
    r.setex(key, 3600, json.dumps(sentiment))  # 1-hour TTL
