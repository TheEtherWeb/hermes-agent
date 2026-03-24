"""
Finnhub WebSocket feed — backup price source.
Publishes to nexus:prices:{symbol} with source='finnhub'.
Only active when Polygon is unavailable or for cross-validation.
"""
import asyncio
import json
import logging
import time

import websockets
import redis.asyncio as aioredis

from config import settings

logger = logging.getLogger(__name__)

FINNHUB_WS = "wss://ws.finnhub.io"
STREAM_KEY = "nexus:prices:{symbol}"
STREAM_MAXLEN = 10_000


async def run_finnhub_feed(redis_client: aioredis.Redis) -> None:
    """Connect to Finnhub WebSocket and stream price ticks to Redis."""
    if not settings.finnhub_api_key:
        logger.warning("FINNHUB_API_KEY not set — skipping Finnhub feed")
        return

    backoff = 1
    while True:
        try:
            await _connect_and_stream(redis_client)
            backoff = 1
        except websockets.exceptions.ConnectionClosed as e:
            logger.warning("Finnhub WS closed: %s — reconnecting in %ds", e, backoff)
        except Exception as e:
            logger.error("Finnhub feed error: %s — reconnecting in %ds", e, backoff)
        await asyncio.sleep(backoff)
        backoff = min(backoff * 2, 60)


async def _connect_and_stream(redis_client: aioredis.Redis) -> None:
    url = f"{FINNHUB_WS}?token={settings.finnhub_api_key}"
    async with websockets.connect(url, ping_interval=20) as ws:
        for symbol in settings.symbols:
            await ws.send(json.dumps({"type": "subscribe", "symbol": symbol}))

        logger.info("Finnhub feed subscribed to: %s", settings.symbols)

        async for raw in ws:
            try:
                msg = json.loads(raw)
                if msg.get("type") == "trade" and msg.get("data"):
                    for trade in msg["data"]:
                        await _publish_tick(redis_client, trade)
            except Exception as e:
                logger.debug("Finnhub parse error: %s", e)


async def _publish_tick(redis_client: aioredis.Redis, trade: dict) -> None:
    symbol = trade.get("s", "")
    price = str(trade.get("p", 0))
    volume = str(trade.get("v", 0))
    ts = str(trade.get("t", int(time.time() * 1000)))

    tick = {
        "symbol": symbol,
        "open": price,
        "high": price,
        "low": price,
        "close": price,
        "volume": volume,
        "vwap": price,
        "source": "finnhub",
        "ts": ts,
    }

    key = STREAM_KEY.format(symbol=symbol)
    await redis_client.xadd(key, tick, maxlen=STREAM_MAXLEN, approximate=True)
