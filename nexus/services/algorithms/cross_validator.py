"""
Recursive Cross-Validation Engine (Phase 5 core).
Every N ticks: measures accuracy, updates algo weights via gradient descent.
Regime-aware meta-learning across a 500-iteration rolling window.
"""
import json
import logging
import numpy as np
from datetime import datetime, timezone

from shared.db import get_sync_pg
from shared.feature_store import get_algo_weights, set_algo_weights

logger = logging.getLogger(__name__)

LEARNING_RATE_BASE = 0.05
LEARNING_RATE_MAX = 0.20
MIN_WEIGHT = 0.05
MAX_WEIGHT = 0.60

# Rolling performance log per symbol: list of {accuracy, regime, weights}
_meta_log: dict[str, list] = {}


def run_cross_validation(symbol: str, regime: str, n: int = 10) -> dict:
    """
    Execute one cross-validation cycle for a symbol.
    Updates consensus weights using gradient descent on recent accuracy.

    Returns updated weights dict.
    """
    conn = get_sync_pg()
    try:
        current_weights = get_algo_weights(symbol)
        algo_accuracies = _fetch_recent_accuracies(conn, symbol, n)

        if not algo_accuracies:
            return current_weights

        # Step 1: Compute agreement correlation matrix
        algo_preds = _fetch_recent_predictions(conn, symbol, n)
        correlation = _compute_correlation(algo_preds)

        # Step 2: Gradient descent weight update
        new_weights = _gradient_descent_update(
            current_weights, algo_accuracies, regime
        )

        # Step 3: Persist updated weights
        set_algo_weights(symbol, new_weights)

        # Step 4: Update meta-learning log
        _update_meta_log(symbol, algo_accuracies, regime, new_weights)

        logger.info(
            "Cross-validation %s [%s]: SENTINEL=%.2f ORACLE=%.2f PHANTOM=%.2f",
            symbol, regime,
            new_weights["SENTINEL"], new_weights["ORACLE"], new_weights["PHANTOM"],
        )

        return {"weights": new_weights, "accuracies": algo_accuracies, "correlation": correlation}

    finally:
        conn.close()


def _fetch_recent_accuracies(conn, symbol: str, n: int) -> dict:
    """Fetch rolling accuracy for each algorithm over the last N evaluations."""
    accuracies = {}
    with conn.cursor() as cur:
        for algorithm in ("SENTINEL", "ORACLE", "PHANTOM"):
            cur.execute(
                """
                SELECT AVG(CASE WHEN was_correct THEN 1.0 ELSE 0.0 END) as accuracy,
                       COUNT(*) as count
                FROM predictions
                WHERE symbol = %s AND algorithm = %s
                  AND was_correct IS NOT NULL
                  AND time > NOW() - INTERVAL '2 days'
                """,
                (symbol, algorithm),
            )
            row = cur.fetchone()
            if row and row[1] and row[1] >= 5:
                accuracies[algorithm] = {"accuracy": float(row[0] or 0.5), "count": int(row[1])}
            else:
                accuracies[algorithm] = {"accuracy": 0.5, "count": 0}
    return accuracies


def _fetch_recent_predictions(conn, symbol: str, n: int) -> dict:
    """Fetch last N prediction directions per algorithm."""
    preds = {}
    with conn.cursor() as cur:
        for algorithm in ("SENTINEL", "ORACLE", "PHANTOM"):
            cur.execute(
                """
                SELECT direction FROM predictions
                WHERE symbol = %s AND algorithm = %s
                ORDER BY time DESC LIMIT %s
                """,
                (symbol, algorithm, n),
            )
            preds[algorithm] = [r[0] for r in cur.fetchall()]
    return preds


def _compute_correlation(algo_preds: dict) -> dict:
    """Compute pairwise agreement ratios between algorithms."""
    algos = list(algo_preds.keys())
    correlation = {}
    for i, a in enumerate(algos):
        for j, b in enumerate(algos):
            if i >= j:
                continue
            preds_a = algo_preds[a]
            preds_b = algo_preds[b]
            if not preds_a or not preds_b:
                correlation[f"{a}_{b}"] = 0.5
                continue
            min_len = min(len(preds_a), len(preds_b))
            agreement = sum(
                1 for x, y in zip(preds_a[:min_len], preds_b[:min_len]) if x == y
            ) / min_len
            correlation[f"{a}_{b}"] = round(agreement, 3)
    return correlation


def _gradient_descent_update(
    current_weights: dict,
    accuracies: dict,
    regime: str,
) -> dict:
    """
    Update weights using gradient descent.
    Learning rate increases when accuracy is below median (needs to learn faster).
    """
    all_accuracies = [v["accuracy"] for v in accuracies.values()]
    median_accuracy = np.median(all_accuracies)

    new_weights = {}
    for algo, weight in current_weights.items():
        acc = accuracies.get(algo, {}).get("accuracy", 0.5)

        # Error: distance from perfect accuracy
        error = 1.0 - acc

        # Adaptive learning rate
        if acc < median_accuracy:
            lr = LEARNING_RATE_MAX  # below median → learn faster
        else:
            lr = LEARNING_RATE_BASE  # above median → stable

        # Gradient step: increase weight for high-accuracy algos
        gradient = error * (weight - acc)  # push weight toward accuracy
        new_w = weight - lr * gradient

        # Clamp
        new_weights[algo] = max(MIN_WEIGHT, min(MAX_WEIGHT, new_w))

    # Normalize to sum to 1.0
    total = sum(new_weights.values())
    new_weights = {k: round(v / total, 4) for k, v in new_weights.items()}

    return new_weights


def _update_meta_log(symbol: str, accuracies: dict, regime: str, weights: dict) -> None:
    """Maintain rolling 500-iteration meta-learning log."""
    from config import settings

    if symbol not in _meta_log:
        _meta_log[symbol] = []

    _meta_log[symbol].append({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "regime": regime,
        "accuracies": {k: v["accuracy"] for k, v in accuracies.items()},
        "weights": weights,
    })

    # Trim to META_LEARNING_WINDOW
    max_len = settings.meta_learning_window
    if len(_meta_log[symbol]) > max_len:
        _meta_log[symbol] = _meta_log[symbol][-max_len:]
