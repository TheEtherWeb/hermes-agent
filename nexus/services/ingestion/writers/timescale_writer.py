"""
Redis Streams consumer → TimescaleDB batch writer.
Reads from nexus:prices:{symbol} streams and bulk-inserts into price_ticks.
Uses consumer groups so multiple writers can share load.
"""
import asyncio
import logging
from datetime import datetime, timezone

import asyncpg
import redis.asyncio as aioredis

from config import settings

logger = logging.getLogger(__name__)

CONSUMER_GROUP = "timescale-writer"
CONSUMER_NAME = "writer-1"
BATCH_SIZE = 500
FLUSH_INTERVAL = 0.5  # seconds — flush every 500ms


async def run_timescale_writer(pool: asyncpg.Pool, redis_client: aioredis.Redis) -> None:
    """Consume price streams and batch-write to TimescaleDB."""
    # Create consumer groups for each symbol stream
    for symbol in settings.symbols:
        key = f"nexus:prices:{symbol}"
        try:
            await redis_client.xgroup_create(key, CONSUMER_GROUP, id="0", mkstream=True)
        except Exception:
            pass  # group already exists

    logger.info("TimescaleDB writer started for symbols: %s", settings.symbols)
    buffer: list[dict] = []

    while True:
        # Read from all symbol streams
        stream_keys = {f"nexus:prices:{sym}": ">" for sym in settings.symbols}
        try:
            results = await redis_client.xreadgroup(
                CONSUMER_GROUP,
                CONSUMER_NAME,
                stream_keys,
                count=BATCH_SIZE,
                block=int(FLUSH_INTERVAL * 1000),
            )
        except Exception as e:
            logger.error("Redis XREADGROUP error: %s", e)
            await asyncio.sleep(1)
            continue

        if results:
            for stream_name, messages in results:
                for msg_id, fields in messages:
                    row = _parse_fields(fields)
                    if row:
                        buffer.append((msg_id, stream_name, row))

        if buffer and (len(buffer) >= BATCH_SIZE or not results):
            await _flush_buffer(pool, redis_client, buffer)
            buffer.clear()


async def _flush_buffer(pool: asyncpg.Pool, redis_client: aioredis.Redis, buffer: list) -> None:
    rows = [item[2] for item in buffer]
    try:
        async with pool.acquire() as conn:
            # Guard: reject ticks older than 6 days (compressed chunk protection)
            cutoff = datetime.now(timezone.utc).timestamp() - 6 * 86400
            valid_rows = [r for r in rows if r["ts"] > cutoff * 1000]
            if len(valid_rows) < len(rows):
                logger.warning("Dropped %d ticks older than 6 days", len(rows) - len(valid_rows))

            if valid_rows:
                await conn.executemany(
                    """
                    INSERT INTO price_ticks (time, symbol, open, high, low, close, volume, vwap, source)
                    VALUES (
                        to_timestamp($1::bigint / 1000.0),
                        $2, $3, $4, $5, $6, $7, $8, $9
                    )
                    ON CONFLICT DO NOTHING
                    """,
                    [
                        (r["ts"], r["symbol"], r["open"], r["high"],
                         r["low"], r["close"], r["volume"], r["vwap"], r["source"])
                        for r in valid_rows
                    ],
                )

        # Acknowledge processed messages
        for msg_id, stream_name, _ in buffer:
            await redis_client.xack(stream_name, CONSUMER_GROUP, msg_id)

        logger.debug("Flushed %d price ticks to TimescaleDB", len(valid_rows))
    except Exception as e:
        logger.error("TimescaleDB flush error: %s", e)


def _parse_fields(fields: dict) -> dict | None:
    try:
        return {
            "symbol": fields.get(b"symbol", b"").decode(),
            "open": float(fields.get(b"open", b"0")),
            "high": float(fields.get(b"high", b"0")),
            "low": float(fields.get(b"low", b"0")),
            "close": float(fields.get(b"close", b"0")),
            "volume": int(fields.get(b"volume", b"0")),
            "vwap": float(fields.get(b"vwap", b"0") or b"0"),
            "source": fields.get(b"source", b"unknown").decode(),
            "ts": int(fields.get(b"ts", b"0")),
        }
    except (ValueError, KeyError) as e:
        logger.debug("Tick parse error: %s", e)
        return None
