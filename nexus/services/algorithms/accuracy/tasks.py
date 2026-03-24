"""
Accuracy evaluation task — runs every 5 minutes via Celery beat.
Resolves pending predictions by comparing against actual price movement.
"""
import logging
import psycopg2
from datetime import datetime, timezone

from celery_app import app
from config import settings
from shared.db import get_sync_pg

logger = logging.getLogger(__name__)


@app.task(name="accuracy.tasks.evaluate_pending", queue="accuracy")
def evaluate_pending():
    """Resolve all predictions whose horizon has elapsed."""
    conn = get_sync_pg()
    resolved = 0
    try:
        with conn.cursor() as cur:
            # Find unresolved predictions past their horizon
            cur.execute(
                """
                SELECT id, symbol, algorithm, direction, price_at_signal, horizon_minutes, time
                FROM predictions
                WHERE was_correct IS NULL
                  AND time + (horizon_minutes * INTERVAL '1 minute') < NOW()
                LIMIT 500
                """,
            )
            pending = cur.fetchall()

            for pred_id, symbol, algorithm, direction, price_at_signal, horizon_min, pred_time in pending:
                # Find the price closest to outcome time
                outcome_time = pred_time + psycopg2.extensions.DateTimeTZFromTicks(
                    pred_time.timestamp() + horizon_min * 60
                )

                cur.execute(
                    """
                    SELECT close, time FROM price_ticks
                    WHERE symbol = %s
                      AND time BETWEEN %s AND %s + INTERVAL '5 minutes'
                    ORDER BY ABS(EXTRACT(EPOCH FROM (time - %s)))
                    LIMIT 1
                    """,
                    (symbol, pred_time + psycopg2.extensions.DateTimeTZFromTicks(
                        pred_time.timestamp() + horizon_min * 60 - 300
                    ), pred_time, pred_time + psycopg2.extensions.DateTimeTZFromTicks(
                        pred_time.timestamp() + horizon_min * 60
                    )),
                )
                outcome_row = cur.fetchone()
                if not outcome_row:
                    continue

                actual_price, actual_time = outcome_row
                actual_return = (float(actual_price) - float(price_at_signal)) / float(price_at_signal)

                # Was the directional prediction correct?
                if direction == 1:
                    was_correct = actual_return > 0.001  # > 0.1% up
                elif direction == -1:
                    was_correct = actual_return < -0.001  # > 0.1% down
                else:
                    was_correct = abs(actual_return) < 0.01  # within 1% for HOLD

                cur.execute(
                    """
                    UPDATE predictions
                    SET outcome = %s, outcome_time = %s, price_at_outcome = %s, was_correct = %s
                    WHERE id = %s
                    """,
                    (
                        1 if was_correct else 0,
                        actual_time,
                        float(actual_price),
                        was_correct,
                        pred_id,
                    ),
                )
                resolved += 1

            conn.commit()

            # Update algo_performance table
            if resolved > 0:
                _update_performance(cur, conn)

    except Exception as e:
        logger.error("Accuracy evaluation error: %s", e)
        conn.rollback()
    finally:
        conn.close()

    logger.info("Resolved %d pending predictions", resolved)
    return {"resolved": resolved}


def _update_performance(cur, conn) -> None:
    """Refresh algo_performance table with rolling accuracy metrics."""
    for symbol in settings.symbols:
        for algorithm in ("SENTINEL", "ORACLE", "PHANTOM"):
            cur.execute(
                """
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN was_correct THEN 1 ELSE 0 END) as correct,
                    AVG(confidence) as avg_confidence
                FROM predictions
                WHERE symbol = %s AND algorithm = %s
                  AND was_correct IS NOT NULL
                  AND time > NOW() - INTERVAL '7 days'
                """,
                (symbol, algorithm),
            )
            row = cur.fetchone()
            if not row or row[0] < 5:
                continue

            total, correct, avg_conf = row
            accuracy = float(correct) / float(total)

            cur.execute(
                """
                INSERT INTO algo_performance
                    (symbol, algorithm, window_size, accuracy, avg_confidence)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (symbol, algorithm, int(total), round(accuracy, 4), round(float(avg_conf or 0), 4)),
            )
    conn.commit()
