"""
Hurst exponent calculation via R/S (Rescaled Range) analysis.
H > 0.6: trending (persistent)
H ≈ 0.5: random walk
H < 0.4: mean-reverting (anti-persistent)
"""
import numpy as np
import logging

logger = logging.getLogger(__name__)

MIN_SERIES_LEN = 50


def compute_hurst(prices: np.ndarray) -> float:
    """
    Compute Hurst exponent via R/S analysis.
    Returns value in [0, 1]. Returns 0.5 (random walk) on error.
    """
    if len(prices) < MIN_SERIES_LEN:
        return 0.5

    try:
        returns = np.log(prices[1:] / prices[:-1])
        n = len(returns)

        # Subdivide into windows of sizes from n//2 down to 8
        window_sizes = []
        rs_values = []

        size = n // 2
        while size >= 8:
            rs_list = []
            for start in range(0, n - size + 1, size):
                sub = returns[start:start + size]
                mean = np.mean(sub)
                deviation = np.cumsum(sub - mean)
                r = np.max(deviation) - np.min(deviation)
                s = np.std(sub, ddof=1)
                if s > 1e-10:
                    rs_list.append(r / s)

            if rs_list:
                window_sizes.append(np.log(size))
                rs_values.append(np.log(np.mean(rs_list)))

            size //= 2

        if len(window_sizes) < 3:
            return 0.5

        # Hurst exponent is the slope of log(R/S) vs log(n)
        coeffs = np.polyfit(window_sizes, rs_values, 1)
        h = coeffs[0]

        # Clamp to reasonable range
        return float(np.clip(h, 0.0, 1.0))

    except Exception as e:
        logger.debug("Hurst computation error: %s", e)
        return 0.5
