"""
NEXUS Ingestion Service entry point.
Runs all feed coroutines concurrently:
  - Polygon.io WebSocket → Redis Streams
  - Finnhub WebSocket → Redis Streams (backup)
  - NewsAPI polling → MongoDB
  - TimescaleDB batch writer (Redis consumer group)
  - HTTP health endpoint on :8080
"""
import asyncio
import logging
import os

import asyncpg
import redis.asyncio as aioredis
from aiohttp import web
from motor.motor_asyncio import AsyncIOMotorClient

from config import settings
from feeds.polygon_feed import run_polygon_feed
from feeds.finnhub_feed import run_finnhub_feed
from feeds.news_feed import run_news_feed
from writers.timescale_writer import run_timescale_writer

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)


async def health_handler(request: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "service": "ingestion"})


async def main() -> None:
    logger.info("Starting NEXUS ingestion service...")
    logger.info("Watching symbols: %s", settings.symbols)

    # Database connections
    pg_pool = await asyncpg.create_pool(settings.timescale_url, min_size=2, max_size=10)
    redis_client = aioredis.from_url(settings.redis_url, decode_responses=False)
    mongo_client = AsyncIOMotorClient(settings.mongodb_url)
    mongo_db = mongo_client.nexus

    # Health server
    app = web.Application()
    app.router.add_get("/health", health_handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8080)
    await site.start()
    logger.info("Health endpoint at :8080/health")

    # Run all feeds concurrently
    await asyncio.gather(
        run_polygon_feed(redis_client),
        run_finnhub_feed(redis_client),
        run_news_feed(mongo_db, redis_client),
        run_timescale_writer(pg_pool, redis_client),
    )


if __name__ == "__main__":
    asyncio.run(main())
