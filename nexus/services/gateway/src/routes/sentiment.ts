import { Router, Request, Response } from "express";
import { redis } from "../db/redis";
import { NewsArticle } from "../db/mongo";

const router = Router();

// GET /api/sentiment/:symbol
router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = req.params.symbol.toUpperCase();

  try {
    // Latest aggregated sentiment from Redis cache
    const latestRaw = await redis.get(`nexus:sentiment:latest:${symbol}`);
    const latest = latestRaw ? JSON.parse(latestRaw) : null;

    // Recent sentiment history from MongoDB (last 20 articles)
    const articles = await NewsArticle.find(
      {
        $or: [{ symbol }, { symbols: symbol }],
        "sentiment.weighted_score": { $exists: true },
      },
      { title: 1, source: 1, published_at: 1, "sentiment.weighted_score": 1, "sentiment.label": 1 }
    )
      .sort({ published_at: -1 })
      .limit(20)
      .lean();

    res.json({
      symbol,
      current: latest,
      history: articles,
    });
  } catch (err) {
    console.error(`Sentiment error for ${symbol}:`, err);
    res.status(500).json({ error: "Failed to fetch sentiment data" });
  }
});

export default router;
