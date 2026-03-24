"""
NewsAPI polling + RSS feed ingestion → MongoDB news_articles collection.
Publishes article IDs to Redis 'nexus:news_queue' for NLP processing.
"""
import asyncio
import hashlib
import json
import logging
from datetime import datetime, timezone, timedelta

import aiohttp
import feedparser
from motor.motor_asyncio import AsyncIOMotorDatabase

from config import settings

logger = logging.getLogger(__name__)

NEWSAPI_URL = "https://newsapi.org/v2/everything"
NEWS_QUEUE_KEY = "nexus:news_queue"

# RSS feeds for Tier 1 sources
RSS_FEEDS = [
    "https://rss.nytimes.com/services/xml/rss/nyt/Business.xml",
    "https://feeds.reuters.com/reuters/businessNews",
    "https://feeds.a.dj.com/rss/RSSMarketsMain.xml",  # WSJ Markets
]

NEWSAPI_SOURCES = "the-new-york-times,reuters,the-wall-street-journal,bloomberg,cnbc"
POLL_INTERVAL_NEWSAPI = 300   # 5 minutes
POLL_INTERVAL_RSS = 60        # 1 minute


async def run_news_feed(db: AsyncIOMotorDatabase, redis_client) -> None:
    """Run NewsAPI polling and RSS ingestion concurrently."""
    await asyncio.gather(
        _poll_newsapi(db, redis_client),
        _poll_rss(db, redis_client),
    )


async def _poll_newsapi(db: AsyncIOMotorDatabase, redis_client) -> None:
    if not settings.newsapi_key:
        logger.warning("NEWSAPI_KEY not set — skipping NewsAPI feed")
        return

    async with aiohttp.ClientSession() as session:
        while True:
            try:
                await _fetch_newsapi(session, db, redis_client)
            except Exception as e:
                logger.error("NewsAPI fetch error: %s", e)
            await asyncio.sleep(POLL_INTERVAL_NEWSAPI)


async def _fetch_newsapi(session: aiohttp.ClientSession, db: AsyncIOMotorDatabase, redis_client) -> None:
    query = " OR ".join(settings.symbols) + " OR earnings OR fed rate OR market"
    params = {
        "q": query,
        "sources": NEWSAPI_SOURCES,
        "sortBy": "publishedAt",
        "apiKey": settings.newsapi_key,
        "language": "en",
        "pageSize": 50,
        "from": (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat(),
    }

    async with session.get(NEWSAPI_URL, params=params, timeout=aiohttp.ClientTimeout(total=15)) as resp:
        if resp.status != 200:
            logger.warning("NewsAPI HTTP %d", resp.status)
            return
        data = await resp.json()

    articles = data.get("articles", [])
    inserted = 0
    for article in articles:
        doc = _normalize_article(article, "newsapi")
        if await _upsert_article(db, doc):
            await redis_client.lpush(NEWS_QUEUE_KEY, json.dumps({"_id": doc["article_id"], "title": doc["title"], "body": doc["body"]}))
            inserted += 1

    logger.info("NewsAPI: fetched %d, inserted %d new", len(articles), inserted)


async def _poll_rss(db: AsyncIOMotorDatabase, redis_client) -> None:
    while True:
        for feed_url in RSS_FEEDS:
            try:
                await _fetch_rss(feed_url, db, redis_client)
            except Exception as e:
                logger.error("RSS fetch error %s: %s", feed_url, e)
        await asyncio.sleep(POLL_INTERVAL_RSS)


async def _fetch_rss(feed_url: str, db: AsyncIOMotorDatabase, redis_client) -> None:
    loop = asyncio.get_event_loop()
    feed = await loop.run_in_executor(None, feedparser.parse, feed_url)
    inserted = 0
    for entry in feed.entries[:20]:
        article = {
            "url": entry.get("link", ""),
            "title": entry.get("title", ""),
            "description": entry.get("summary", ""),
            "publishedAt": entry.get("published", ""),
            "source": {"name": feed.feed.get("title", "RSS")},
            "content": entry.get("content", [{}])[0].get("value", entry.get("summary", "")),
        }
        doc = _normalize_article(article, "rss")
        if doc and await _upsert_article(db, doc):
            await redis_client.lpush(NEWS_QUEUE_KEY, json.dumps({"_id": doc["article_id"], "title": doc["title"], "body": doc["body"]}))
            inserted += 1

    if inserted:
        logger.info("RSS %s: %d new articles", feed_url, inserted)


def _normalize_article(article: dict, ingestion_source: str) -> dict | None:
    url = article.get("url", "")
    if not url or url == "https://removed.com":
        return None

    article_id = hashlib.sha256(url.encode()).hexdigest()
    title = article.get("title", "")
    body = article.get("content", article.get("description", ""))

    try:
        published_at = datetime.fromisoformat(
            article.get("publishedAt", "").replace("Z", "+00:00")
        )
    except (ValueError, AttributeError):
        published_at = datetime.now(timezone.utc)

    # Extract symbols mentioned (simple ticker pattern: 1-5 uppercase letters)
    import re
    text = f"{title} {body}"
    ticker_pattern = re.compile(r'\b([A-Z]{1,5})\b')
    found = ticker_pattern.findall(text)
    mentioned_symbols = [s for s in found if s in settings.symbols]

    return {
        "article_id": article_id,
        "url": url,
        "title": title,
        "body": body[:4096],  # cap body length
        "source": article.get("source", {}).get("name", ingestion_source),
        "published_at": published_at,
        "ingested_at": datetime.now(timezone.utc),
        "symbol": mentioned_symbols[0] if mentioned_symbols else None,
        "symbols": mentioned_symbols,
        "sentiment": None,  # filled by NLP worker
    }


async def _upsert_article(db: AsyncIOMotorDatabase, doc: dict) -> bool:
    """Insert article if not already present. Returns True if inserted."""
    if not doc:
        return False
    result = await db.news_articles.update_one(
        {"article_id": doc["article_id"]},
        {"$setOnInsert": doc},
        upsert=True
    )
    return result.upserted_id is not None
