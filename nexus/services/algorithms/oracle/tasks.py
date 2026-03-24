"""ORACLE Celery tasks — sentiment-driven predictions."""
import logging
import json
from datetime import datetime, timezone, timedelta

from celery_app import app
from config import settings
from shared.db import fetch_prices, insert_prediction, get_mongo
from shared.feature_store import publish_prediction, set_latest_sentiment
from oracle.finbert_pipeline import batch_analyze
from oracle.sentiment_aggregator import compute_weighted_sentiment

logger = logging.getLogger(__name__)

# Rolling correlation tracker: news sentiment → price movement
_correlation_history: dict[str, list] = {}

# Feature weights for ORACLE (self-correcting)
_weights: dict[str, dict] = {}


def _get_weights(symbol: str) -> dict:
    if symbol not in _weights:
        _weights[symbol] = {
            "w_sentiment": 0.45,
            "w_velocity": 0.30,
            "w_volume_anomaly": 0.15,
            "w_price_correlation": 0.10,
        }
    return _weights[symbol]


@app.task(name="oracle.tasks.run_oracle", queue="oracle", bind=True, max_retries=3)
def run_oracle(self, symbol: str):
    """Run ORACLE algorithm for a single symbol."""
    try:
        db = get_mongo()

        # Fetch recent articles for this symbol (last 24 hours)
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        articles = list(
            db.news_articles.find(
                {
                    "$or": [{"symbol": symbol}, {"symbols": symbol}],
                    "published_at": {"$gte": cutoff},
                },
                {"title": 1, "body": 1, "published_at": 1, "sentiment": 1},
                sort=[("published_at", -1)],
                limit=50,
            )
        )

        # Run FinBERT on articles without sentiment scores yet
        unscored = [a for a in articles if not a.get("sentiment")]
        if unscored:
            texts = [f"{a.get('title', '')} {a.get('body', '')[:512]}" for a in unscored]
            scores = batch_analyze(texts)
            for article, score in zip(unscored, scores):
                db.news_articles.update_one(
                    {"_id": article["_id"]},
                    {"$set": {"sentiment": score}},
                )
                article["sentiment"] = score

        agg = compute_weighted_sentiment(articles)

        # Cache sentiment for other components
        sentiment_data = {**agg, "symbol": symbol, "computed_at": datetime.now(timezone.utc).isoformat()}
        set_latest_sentiment(symbol, sentiment_data)

        # Generate ORACLE signal
        result = _generate_signal(symbol, agg)
        if result is None:
            return {"symbol": symbol, "skipped": True, "reason": "insufficient data"}

        result["symbol"] = symbol
        result["algorithm"] = "ORACLE"

        pred_id = insert_prediction(result)
        publish_prediction(symbol, "ORACLE", {
            "id": pred_id,
            "direction": result["direction"],
            "confidence": result["confidence"],
            "price_at_signal": result["price_at_signal"],
            "price_target": result.get("price_target", result["price_at_signal"]),
            "horizon_minutes": result["horizon_minutes"],
        })

        logger.info(
            "ORACLE %s: dir=%+d conf=%.2f wss=%.3f velocity=%.3f articles=%d",
            symbol, result["direction"], result["confidence"],
            agg["wss"], agg["velocity"], agg["article_count"],
        )
        return {"symbol": symbol, "direction": result["direction"], "id": pred_id}

    except Exception as exc:
        logger.error("ORACLE task error for %s: %s", symbol, exc)
        raise self.retry(exc=exc, countdown=60)


def _generate_signal(symbol: str, agg: dict) -> dict | None:
    prices = fetch_prices(symbol, limit=10)
    if not prices:
        return None

    current_price = prices[-1]["close"]
    wss = agg["wss"]
    velocity = agg["velocity"]
    article_count = agg["article_count"]

    # Need at least a few articles to produce a reliable signal
    if article_count < 3:
        return {
            "direction": 0,
            "confidence": 0.1,
            "price_at_signal": float(current_price),
            "price_target": float(current_price),
            "horizon_minutes": 480,
            "feature_weights": _get_weights(symbol),
        }

    w = _get_weights(symbol)

    # Volume anomaly component (more articles than usual = higher uncertainty)
    recent_avg = article_count  # simplified; full impl uses rolling baseline
    volume_anomaly = min(1.0, article_count / max(recent_avg, 1)) - 1.0  # 0 = normal

    sentiment_component = wss
    velocity_component = velocity
    anomaly_component = volume_anomaly * (1.0 if wss > 0 else -1.0)

    raw_score = (
        w["w_sentiment"] * sentiment_component +
        w["w_velocity"] * velocity_component +
        w["w_volume_anomaly"] * anomaly_component
    )

    abs_score = abs(raw_score)
    if abs_score < 0.15:
        direction = 0
        confidence = 0.2 + abs_score
    elif raw_score > 0:
        direction = 1
        confidence = min(0.4 + abs_score, 0.90)
    else:
        direction = -1
        confidence = min(0.4 + abs_score, 0.90)

    # Price target: based on sentiment magnitude
    price_move = current_price * abs(wss) * 0.02  # up to 2% move
    price_target = current_price + (price_move if direction == 1 else -price_move)

    return {
        "direction": direction,
        "confidence": round(float(confidence), 4),
        "price_at_signal": float(current_price),
        "price_target": round(float(price_target), 4),
        "horizon_minutes": 720,  # 12-hour horizon for news-driven signals
        "feature_weights": _get_weights(symbol),
    }


@app.task(name="oracle.tasks.run_all_symbols", queue="oracle")
def run_all_symbols():
    for symbol in settings.symbols:
        run_oracle.apply_async(args=[symbol], queue="oracle")
    return {"dispatched": settings.symbols}
