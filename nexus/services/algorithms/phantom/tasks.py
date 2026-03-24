"""PHANTOM Celery tasks — statistical/quantitative predictions."""
import logging
import numpy as np

from celery_app import app
from config import settings
from shared.db import fetch_prices, insert_prediction
from shared.feature_store import publish_prediction, get_arima_order, set_arima_order
from phantom.arima_model import auto_select_order, fit_and_forecast
from phantom.hurst import compute_hurst
from phantom.monte_carlo import simulate_paths, probability_of_increase, compute_var

logger = logging.getLogger(__name__)

MIN_PRICES = 100
REFIT_ACCURACY_THRESHOLD = 0.45
_iteration_counts: dict[str, int] = {}


@app.task(name="phantom.tasks.run_phantom", queue="phantom", bind=True, max_retries=3)
def run_phantom(self, symbol: str):
    """Run PHANTOM algorithm for a single symbol."""
    try:
        prices = fetch_prices(symbol, limit=300)
        if len(prices) < MIN_PRICES:
            logger.warning("PHANTOM: insufficient data for %s (%d rows)", symbol, len(prices))
            return

        closes = np.array([p["close"] for p in prices], dtype=float)
        current_price = float(closes[-1])

        _iteration_counts[symbol] = _iteration_counts.get(symbol, 0) + 1

        # Hurst exponent: determine market regime
        hurst = compute_hurst(closes)
        is_trending = hurst > 0.6
        is_mean_reverting = hurst < 0.4

        # Get or compute ARIMA order (cached in Redis)
        order = get_arima_order(symbol)
        if order is None:
            order = auto_select_order(closes[-200:])
            set_arima_order(symbol, order)

        arima_result = fit_and_forecast(closes, order, steps=5)
        forecast_end = arima_result["forecast"][-1] if arima_result["forecast"] else current_price
        arima_direction = 1 if forecast_end > current_price else -1

        # Historical volatility (annualized)
        log_returns = np.log(closes[1:] / closes[:-1])
        sigma = float(np.std(log_returns[-60:])) * np.sqrt(252 * 8)
        mu_daily = float(np.mean(log_returns[-60:])) * 252 * 8

        # Monte Carlo (1000 paths in dev)
        paths = simulate_paths(
            current_price=current_price,
            mu=mu_daily,
            sigma=sigma,
            n_paths=settings.monte_carlo_paths,
            n_steps=8,  # 8-hour horizon
        )
        p_increase = probability_of_increase(paths)

        # Mean reversion: Z-score vs 20-period rolling mean
        rolling_mean = float(np.mean(closes[-20:]))
        rolling_std = float(np.std(closes[-20:])) + 1e-9
        z_score = (current_price - rolling_mean) / rolling_std

        # PHANTOM signal generation
        direction, confidence = _compute_signal(
            is_trending=is_trending,
            is_mean_reverting=is_mean_reverting,
            arima_direction=arima_direction,
            p_increase=p_increase,
            hurst=hurst,
            z_score=z_score,
        )

        # Price target from ARIMA forecast
        price_target = forecast_end if direction != 0 else current_price

        result = {
            "symbol": symbol,
            "algorithm": "PHANTOM",
            "direction": direction,
            "confidence": round(float(confidence), 4),
            "price_at_signal": current_price,
            "price_target": round(float(price_target), 4),
            "horizon_minutes": 480,
            "feature_weights": {
                "hurst": round(hurst, 4),
                "p_increase": round(p_increase, 4),
                "z_score": round(z_score, 4),
                "arima_direction": arima_direction,
            },
            "iteration": _iteration_counts[symbol],
        }

        pred_id = insert_prediction(result)
        publish_prediction(symbol, "PHANTOM", {
            "id": pred_id,
            "direction": direction,
            "confidence": result["confidence"],
            "price_at_signal": current_price,
            "price_target": result["price_target"],
            "horizon_minutes": 480,
        })

        logger.info(
            "PHANTOM %s: dir=%+d conf=%.2f hurst=%.3f p_inc=%.3f z=%.2f",
            symbol, direction, confidence, hurst, p_increase, z_score,
        )
        return {"symbol": symbol, "direction": direction, "id": pred_id}

    except Exception as exc:
        logger.error("PHANTOM task error for %s: %s", symbol, exc)
        raise self.retry(exc=exc, countdown=60)


def _compute_signal(
    is_trending: bool,
    is_mean_reverting: bool,
    arima_direction: int,
    p_increase: float,
    hurst: float,
    z_score: float,
) -> tuple[int, float]:
    """Compute PHANTOM direction and confidence."""
    if is_mean_reverting:
        # Mean reversion signals: trade against overextension
        if z_score > 2.0:
            direction = -1  # price is high vs mean → expect reversion down
            confidence = min(0.5 + abs(z_score) * 0.1, 0.85)
        elif z_score < -2.0:
            direction = 1   # price is low vs mean → expect reversion up
            confidence = min(0.5 + abs(z_score) * 0.1, 0.85)
        else:
            direction = 0
            confidence = 0.3
    elif is_trending:
        # Trend-following: use ARIMA + Monte Carlo agreement
        if arima_direction == 1 and p_increase > 0.6:
            direction = 1
            confidence = min(0.4 + p_increase * 0.6, 0.88)
        elif arima_direction == -1 and p_increase < 0.4:
            direction = -1
            confidence = min(0.4 + (1 - p_increase) * 0.6, 0.88)
        else:
            direction = 0
            confidence = 0.3
    else:
        # Mixed regime: use Monte Carlo primarily
        if p_increase > 0.65:
            direction = 1
            confidence = 0.5 + (p_increase - 0.65) * 1.5
        elif p_increase < 0.35:
            direction = -1
            confidence = 0.5 + (0.35 - p_increase) * 1.5
        else:
            direction = 0
            confidence = 0.3

    return direction, float(np.clip(confidence, 0.1, 0.95))


@app.task(name="phantom.tasks.refit_arima_all", queue="phantom")
def refit_arima_all():
    """Refit ARIMA orders for all symbols (runs every 30 minutes via beat)."""
    from shared.feature_store import get_redis
    for symbol in settings.symbols:
        prices = fetch_prices(symbol, limit=200)
        if len(prices) >= 50:
            closes = np.array([p["close"] for p in prices], dtype=float)
            order = auto_select_order(closes)
            set_arima_order(symbol, order)
            logger.info("ARIMA refit %s: order=%s", symbol, order)
    return {"refitted": settings.symbols}


@app.task(name="phantom.tasks.run_all_symbols", queue="phantom")
def run_all_symbols():
    for symbol in settings.symbols:
        run_phantom.apply_async(args=[symbol], queue="phantom")
    return {"dispatched": settings.symbols}
