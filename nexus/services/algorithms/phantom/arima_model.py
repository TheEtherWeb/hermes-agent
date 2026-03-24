"""
ARIMA model with auto-order selection (AIC minimization).
Order is cached in Redis to avoid grid-search on every tick.
"""
import logging
import warnings
import numpy as np
from typing import Optional

warnings.filterwarnings("ignore")  # suppress statsmodels convergence warnings

logger = logging.getLogger(__name__)

MAX_ORDER = 5   # p and q bounds
MAX_D = 2       # integration order bound
AIC_TIMEOUT_MS = 500  # skip order if fitting takes too long


def auto_select_order(prices: np.ndarray, max_p: int = MAX_ORDER, max_q: int = MAX_ORDER) -> tuple:
    """
    Grid-search ARIMA order by minimizing AIC.
    Returns (p, d, q) tuple.
    """
    from statsmodels.tsa.stattools import adfuller
    from statsmodels.tsa.arima.model import ARIMA

    # Determine d via ADF test
    d = 0
    series = prices.copy()
    for _ in range(MAX_D):
        try:
            result = adfuller(series, autolag="AIC")
            if result[1] < 0.05:  # stationary
                break
            series = np.diff(series)
            d += 1
        except Exception:
            break

    best_aic = float("inf")
    best_order = (1, d, 1)  # fallback order

    for p in range(0, min(max_p + 1, 4)):
        for q in range(0, min(max_q + 1, 4)):
            if p == 0 and q == 0:
                continue
            try:
                model = ARIMA(prices, order=(p, d, q))
                fit = model.fit(method_kwargs={"warn_convergence": False})
                if fit.aic < best_aic:
                    best_aic = fit.aic
                    best_order = (p, d, q)
            except Exception:
                continue

    logger.debug("ARIMA auto-order: %s (AIC=%.2f)", best_order, best_aic)
    return best_order


def fit_and_forecast(prices: np.ndarray, order: tuple, steps: int = 5) -> dict:
    """
    Fit ARIMA model with the given order and produce a forecast.
    Returns: {forecast, conf_int_lower, conf_int_upper, aic}
    """
    from statsmodels.tsa.arima.model import ARIMA

    try:
        model = ARIMA(prices, order=order)
        fit = model.fit(method_kwargs={"warn_convergence": False})

        forecast_result = fit.get_forecast(steps=steps)
        forecast = forecast_result.predicted_mean
        conf_int = forecast_result.conf_int(alpha=0.10)  # 90% confidence interval

        return {
            "forecast": forecast.tolist(),
            "conf_int_lower": conf_int.iloc[:, 0].tolist(),
            "conf_int_upper": conf_int.iloc[:, 1].tolist(),
            "aic": fit.aic,
            "order": order,
        }
    except Exception as e:
        logger.warning("ARIMA fit failed with order %s: %s", order, e)
        # Fallback: naive drift forecast
        drift = float(np.mean(np.diff(prices[-20:])))
        last = float(prices[-1])
        naive = [last + drift * (i + 1) for i in range(steps)]
        return {
            "forecast": naive,
            "conf_int_lower": [v * 0.97 for v in naive],
            "conf_int_upper": [v * 1.03 for v in naive],
            "aic": float("inf"),
            "order": (1, 1, 1),
        }
