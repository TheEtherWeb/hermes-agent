import { Router, Request, Response } from "express";
import { NewsArticle } from "../db/mongo";

const router = Router();

// GET /api/news/:symbol?limit=20
router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = req.params.symbol.toUpperCase();
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

  try {
    const articles = await NewsArticle.find(
      { $or: [{ symbol }, { symbols: symbol }] },
      { title: 1, source: 1, url: 1, published_at: 1, sentiment: 1, body: 1 }
    )
      .sort({ published_at: -1 })
      .limit(limit)
      .lean();

    res.json({ symbol, articles });
  } catch (err) {
    console.error(`News error for ${symbol}:`, err);
    res.status(500).json({ error: "Failed to fetch news" });
  }
});

export default router;
