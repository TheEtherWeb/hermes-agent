"""
Algorithm engine entry point.
This module starts the Celery worker. Docker CMD handles the actual invocation.
Also provides a health check server on :8081.
"""
import asyncio
import logging
import os
from aiohttp import web

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)


async def health_handler(request: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "service": "algo-engine"})


async def run_health_server() -> None:
    app = web.Application()
    app.router.add_get("/health", health_handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", 8081)
    await site.start()
    logger.info("Algo engine health endpoint at :8081/health")
    while True:
        await asyncio.sleep(3600)


if __name__ == "__main__":
    asyncio.run(run_health_server())
