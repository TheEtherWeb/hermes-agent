"""SENTINEL Celery tasks."""
import logging
from celery_app import app
from config import settings
from shared.db import fetch_prices, insert_prediction
from shared.feature_store import publish_prediction
from sentinel.signal_generator import SentinelSignalGenerator

logger = logging.getLogger(__name__)

# One generator instance per symbol (maintained across task invocations via module state)
_generators: dict[str, SentinelSignalGenerator] = {}


def _get_generator(symbol: str) -> SentinelSignalGenerator:
    if symbol not in _generators:
        _generators[symbol] = SentinelSignalGenerator()
    return _generators[symbol]


@app.task(name="sentinel.tasks.run_sentinel", queue="sentinel", bind=True, max_retries=3)
def run_sentinel(self, symbol: str):
    """Run SENTINEL algorithm for a single symbol."""
    try:
        prices = fetch_prices(symbol, limit=300)
        if not prices:
            logger.warning("SENTINEL: no price data for %s", symbol)
            return

        gen = _get_generator(symbol)
        result = gen.generate(prices)
        result["symbol"] = symbol
        result["algorithm"] = "SENTINEL"

        pred_id = insert_prediction(result)
        publish_prediction(symbol, "SENTINEL", {
            "id": pred_id,
            "direction": result["direction"],
            "confidence": result["confidence"],
            "price_at_signal": result["price_at_signal"],
            "price_target": result["price_target"],
            "horizon_minutes": result["horizon_minutes"],
        })

        logger.info(
            "SENTINEL %s: dir=%+d conf=%.2f target=%.2f",
            symbol, result["direction"], result["confidence"], result["price_target"]
        )
        return {"symbol": symbol, "direction": result["direction"], "id": pred_id}

    except Exception as exc:
        logger.error("SENTINEL task error for %s: %s", symbol, exc)
        raise self.retry(exc=exc, countdown=30)


@app.task(name="sentinel.tasks.run_all_symbols", queue="sentinel")
def run_all_symbols():
    """Dispatch SENTINEL tasks for all watched symbols."""
    for symbol in settings.symbols:
        run_sentinel.apply_async(args=[symbol], queue="sentinel")
    return {"dispatched": settings.symbols}
