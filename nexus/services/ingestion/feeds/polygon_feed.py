"""
Polygon.io WebSocket feed → Redis Streams.
Subscribes to per-second aggregate events (A.*) and trade events (T.*).
Publishes to nexus:prices:{symbol} with MAXLEN 10000.
"""
import asyncio
import json
import logging
import time
from datetime import datetime, timezone

import websockets
import redis.asyncio as aioredis

from config import settings

logger = logging.getLogger(__name__)

POLYGON_WS = "wss://socket.polygon.io/stocks"
STREAM_KEY = "nexus:prices:{symbol}"
STREAM_MAXLEN = 10_000


async def run_polygon_feed(redis_client: aioredis.Redis) -> None:
    """Connect to Polygon.io WebSocket and stream price ticks to Redis."""
    if not settings.polygon_api_key:
        logger.warning("POLYGON_API_KEY not set — skipping Polygon feed")
        return

    backoff = 1
    while True:
        try:
            await _connect_and_stream(redis_client)
            backoff = 1  # reset on clean exit
        except websockets.exceptions.ConnectionClosed as e:
            logger.warning("Polygon WS closed: %s — reconnecting in %ds", e, backoff)
        except Exception as e:
            logger.error("Polygon feed error: %s — reconnecting in %ds", e, backoff)
        await asyncio.sleep(backoff)
        backoff = min(backoff * 2, 60)


async def _connect_and_stream(redis_client: aioredis.Redis) -> None:
    async with websockets.connect(POLYGON_WS, ping_interval=20) as ws:
        # Auth
        await ws.send(json.dumps({"action": "auth", "params": settings.polygon_api_key}))
        resp = json.loads(await ws.recv())
        if not any(m.get("status") == "auth_success" for m in resp):
            logger.error("Polygon auth failed: %s", resp)
            return

        # Subscribe to aggregate-per-second and trade events
        subs = ",".join(
            f"A.{sym},T.{sym}" for sym in settings.symbols
        )
        await ws.send(json.dumps({"action": "subscribe", "params": subs}))
        logger.info("Polygon feed subscribed to: %s", settings.symbols)

        async for raw in ws:
            try:
                messages = json.loads(raw)
                for msg in messages:
                    if msg.get("ev") in ("A", "T"):
                        await _publish_tick(redis_client, msg)
            except Exception as e:
                logger.debug("Polygon parse error: %s", e)


async def _publish_tick(redis_client: aioredis.Redis, msg: dict) -> None:
    symbol = msg.get("sym", "")
    if not symbol:
        return

    # Aggregate (ev=A): open/high/low/close/volume for a 1-second bucket
    # Trade (ev=T): individual trade price/volume
    if msg["ev"] == "A":
        tick = {
            "symbol": symbol,
            "open": str(msg.get("o", msg.get("c", 0))),
            "high": str(msg.get("h", msg.get("c", 0))),
            "low": str(msg.get("l", msg.get("c", 0))),
            "close": str(msg.get("c", 0)),
            "volume": str(msg.get("av", msg.get("v", 0))),
            "vwap": str(msg.get("vw", 0)),
            "source": "polygon",
            "ts": str(msg.get("e", int(time.time() * 1000))),
        }
    else:  # Trade
        price = str(msg.get("p", 0))
        tick = {
            "symbol": symbol,
            "open": price,
            "high": price,
            "low": price,
            "close": price,
            "volume": str(msg.get("s", 0)),
            "vwap": price,
            "source": "polygon",
            "ts": str(msg.get("t", int(time.time() * 1000))),
        }

    key = STREAM_KEY.format(symbol=symbol)
    await redis_client.xadd(key, tick, maxlen=STREAM_MAXLEN, approximate=True)

    # Update latest snapshot
    await redis_client.hset(f"nexus:latest:{symbol}", mapping=tick)
