"""
Monte Carlo price path simulation using Geometric Brownian Motion.
Used by both PHANTOM (signal generation) and the Risk Engine (VaR).
"""
import numpy as np
import logging

logger = logging.getLogger(__name__)


def simulate_paths(
    current_price: float,
    mu: float,           # annualized drift (from ARIMA forecast or historical mean)
    sigma: float,        # annualized volatility (from historical returns std dev)
    n_paths: int = 1000,
    n_steps: int = 5,    # forecast steps (trading hours)
    dt: float = 1/252/8, # 1 trading hour (assuming 8-hour day, 252 trading days)
) -> np.ndarray:
    """
    Simulate n_paths price paths using GBM.
    Returns array of shape (n_paths, n_steps+1) with prices including current.
    """
    # Drift and diffusion per step
    drift = (mu - 0.5 * sigma ** 2) * dt
    diffusion = sigma * np.sqrt(dt)

    # Generate random shocks
    random_shocks = np.random.normal(0, 1, (n_paths, n_steps))
    log_returns = drift + diffusion * random_shocks

    # Cumulative paths
    log_price_paths = np.cumsum(log_returns, axis=1)
    price_paths = current_price * np.exp(
        np.concatenate([np.zeros((n_paths, 1)), log_price_paths], axis=1)
    )

    return price_paths


def probability_of_increase(paths: np.ndarray) -> float:
    """Fraction of paths ending above starting price."""
    start = paths[:, 0]
    end = paths[:, -1]
    return float(np.mean(end > start))


def compute_var(paths: np.ndarray, confidence_levels: list[float] = [0.95, 0.99]) -> dict:
    """
    Compute Value-at-Risk from simulated paths.
    Returns max expected loss at each confidence level (as a fraction of current price).
    """
    start_prices = paths[:, 0]
    end_prices = paths[:, -1]
    returns = (end_prices - start_prices) / start_prices

    result = {}
    for cl in confidence_levels:
        var = float(np.percentile(returns, (1 - cl) * 100))
        result[f"var_{int(cl*100)}"] = round(abs(var), 4)

    return result


def compute_scenarios(paths: np.ndarray, current_price: float) -> dict:
    """
    Compute bull/base/bear/black_swan scenario prices from path distribution.
    """
    end_prices = paths[:, -1]
    return {
        "bull": {
            "price": round(float(np.percentile(end_prices, 95)), 4),
            "probability": 0.05,
            "label": "Bull Case",
        },
        "base": {
            "price": round(float(np.median(end_prices)), 4),
            "probability": 0.50,
            "label": "Base Case",
        },
        "bear": {
            "price": round(float(np.percentile(end_prices, 5)), 4),
            "probability": 0.05,
            "label": "Bear Case",
        },
        "black_swan": {
            "price": round(float(np.percentile(end_prices, 1)) * 0.90, 4),
            "probability": 0.01,
            "label": "Black Swan",
        },
    }
