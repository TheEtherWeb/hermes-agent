"""
FinBERT sentiment pipeline.
Model is pre-downloaded in the Docker image to avoid runtime downloads.
"""
import logging
from functools import lru_cache
from typing import Optional

import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def _load_model():
    """Load FinBERT model once per process (cached)."""
    from config import settings
    device = settings.finbert_device
    logger.info("Loading FinBERT model (device=%s)...", device)

    tokenizer = AutoTokenizer.from_pretrained("ProsusAI/finbert")
    model = AutoModelForSequenceClassification.from_pretrained("ProsusAI/finbert")

    if device != "cpu" and torch.cuda.is_available():
        model = model.to(device)

    model.eval()
    logger.info("FinBERT loaded successfully")
    return tokenizer, model, device


def analyze_sentiment(text: str) -> dict:
    """
    Classify a single text with FinBERT.
    Returns: {positive, negative, neutral, weighted_score, label}
    weighted_score (WSS) = P(positive) * confidence - P(negative) * confidence
    """
    tokenizer, model, device = _load_model()

    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=512,
        padding=True,
    )

    if device != "cpu":
        inputs = {k: v.to(device) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = model(**inputs)

    probs = torch.nn.functional.softmax(outputs.logits, dim=-1)[0]
    labels = ["positive", "negative", "neutral"]
    scores = dict(zip(labels, probs.cpu().tolist()))

    confidence = float(probs.max())
    wss = scores["positive"] * confidence - scores["negative"] * confidence

    return {
        "positive": round(scores["positive"], 4),
        "negative": round(scores["negative"], 4),
        "neutral": round(scores["neutral"], 4),
        "weighted_score": round(wss, 4),
        "confidence": round(confidence, 4),
        "label": max(scores, key=scores.get),
    }


def batch_analyze(texts: list[str], batch_size: int = 16) -> list[dict]:
    """Analyze a batch of texts efficiently."""
    results = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        for text in batch:
            try:
                results.append(analyze_sentiment(text[:1024]))  # truncate
            except Exception as e:
                logger.warning("FinBERT error on text: %s", e)
                results.append({
                    "positive": 0.33, "negative": 0.33, "neutral": 0.34,
                    "weighted_score": 0.0, "confidence": 0.33, "label": "neutral"
                })
    return results
