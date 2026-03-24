"""Database connection factories for algorithm workers."""
import asyncpg
import psycopg2
from psycopg2.extras import execute_values
from motor.motor_asyncio import AsyncIOMotorClient
import redis
from config import settings


def get_sync_pg():
    """Synchronous psycopg2 connection for Celery tasks."""
    return psycopg2.connect(settings.timescale_url)


def get_redis():
    """Synchronous Redis client."""
    return redis.from_url(settings.redis_url, decode_responses=True)


def get_mongo():
    """Synchronous motor-style PyMongo client."""
    from pymongo import MongoClient
    client = MongoClient(settings.mongodb_url)
    return client.nexus


def fetch_prices(symbol: str, limit: int = 500, conn=None) -> list[dict]:
    """Fetch recent price ticks for a symbol from TimescaleDB."""
    close_conn = conn is None
    if conn is None:
        conn = get_sync_pg()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT time, open, high, low, close, volume, vwap
                FROM price_ticks
                WHERE symbol = %s
                ORDER BY time DESC
                LIMIT %s
                """,
                (symbol, limit),
            )
            rows = cur.fetchall()
            return [
                {
                    "time": r[0],
                    "open": float(r[1]),
                    "high": float(r[2]),
                    "low": float(r[3]),
                    "close": float(r[4]),
                    "volume": int(r[5]),
                    "vwap": float(r[6]) if r[6] else None,
                }
                for r in reversed(rows)  # oldest-first for TA calculations
            ]
    finally:
        if close_conn:
            conn.close()


def insert_prediction(pred: dict, conn=None) -> str:
    """Insert a prediction row and return the UUID."""
    close_conn = conn is None
    if conn is None:
        conn = get_sync_pg()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO predictions
                    (symbol, algorithm, direction, confidence, price_at_signal,
                     price_target, horizon_minutes, feature_weights, iteration)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id
                """,
                (
                    pred["symbol"], pred["algorithm"], pred["direction"],
                    pred["confidence"], pred["price_at_signal"],
                    pred.get("price_target"), pred.get("horizon_minutes", 60),
                    psycopg2.extras.Json(pred.get("feature_weights")),
                    pred.get("iteration"),
                ),
            )
            pred_id = str(cur.fetchone()[0])
            conn.commit()
            return pred_id
    except Exception:
        conn.rollback()
        raise
    finally:
        if close_conn:
            conn.close()
