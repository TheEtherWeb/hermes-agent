"""
Sentiment aggregation with exponential decay weighting and velocity calculation.
"""
import logging
import math
from datetime import datetime, timezone, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

DECAY_HALFLIFE_HOURS = 24.0  # recent articles weighted more
MIN_ARTICLES = 3             # minimum articles for a valid signal
VELOCITY_WINDOW_HOURS = 6    # rate-of-change window


def compute_weighted_sentiment(articles: list[dict], as_of: Optional[datetime] = None) -> dict:
    """
    Compute exponentially-decayed aggregate sentiment score from articles.

    Each article dict must have:
      - published_at: datetime
      - sentiment.weighted_score: float in [-1, 1]
      - sentiment.confidence: float in [0, 1]

    Returns: {wss, velocity, article_count, positive_ratio, negative_ratio}
    """
    if not articles:
        return _empty_sentiment()

    now = as_of or datetime.now(timezone.utc)
    lambda_decay = math.log(2) / DECAY_HALFLIFE_HOURS

    weighted_sum = 0.0
    weight_total = 0.0
    positive_count = 0
    negative_count = 0

    # Split into velocity windows
    recent_window = []
    older_window = []

    for article in articles:
        pub = article.get("published_at")
        if not pub:
            continue
        if isinstance(pub, str):
            pub = datetime.fromisoformat(pub)
        if pub.tzinfo is None:
            pub = pub.replace(tzinfo=timezone.utc)

        age_hours = max(0, (now - pub).total_seconds() / 3600)
        decay_weight = math.exp(-lambda_decay * age_hours)

        sentiment = article.get("sentiment")
        if not sentiment:
            continue

        wss = sentiment.get("weighted_score", 0.0)
        conf = sentiment.get("confidence", 0.5)

        weighted_sum += wss * conf * decay_weight
        weight_total += decay_weight

        label = sentiment.get("label", "neutral")
        if label == "positive":
            positive_count += 1
        elif label == "negative":
            negative_count += 1

        if age_hours <= VELOCITY_WINDOW_HOURS:
            recent_window.append(wss)
        elif age_hours <= VELOCITY_WINDOW_HOURS * 2:
            older_window.append(wss)

    if weight_total < 1e-9 or len(articles) < MIN_ARTICLES:
        return _empty_sentiment()

    aggregate_wss = weighted_sum / weight_total

    # Velocity: change in mean sentiment between recent and older windows
    recent_mean = sum(recent_window) / len(recent_window) if recent_window else aggregate_wss
    older_mean = sum(older_window) / len(older_window) if older_window else aggregate_wss
    velocity = recent_mean - older_mean

    total = len(articles)
    return {
        "wss": round(aggregate_wss, 4),
        "velocity": round(velocity, 4),
        "article_count": total,
        "positive_ratio": round(positive_count / total, 3),
        "negative_ratio": round(negative_count / total, 3),
    }


def _empty_sentiment() -> dict:
    return {
        "wss": 0.0,
        "velocity": 0.0,
        "article_count": 0,
        "positive_ratio": 0.0,
        "negative_ratio": 0.0,
    }
