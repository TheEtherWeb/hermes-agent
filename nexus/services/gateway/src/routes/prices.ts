import { Router, Request, Response } from "express";
import { pool } from "../db/postgres";
import { redis } from "../db/redis";

const router = Router();

// GET /api/prices/:symbol?interval=1m&limit=200
router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = req.params.symbol.toUpperCase();
  const interval = (req.query.interval as string) || "1m";
  const limit = Math.min(parseInt(req.query.limit as string) || 200, 1000);

  try {
    // Use TimescaleDB time_bucket for OHLCV candles
    const intervalMap: Record<string, string> = {
      "1m": "1 minute",
      "5m": "5 minutes",
      "15m": "15 minutes",
      "1h": "1 hour",
      "1d": "1 day",
    };
    const bucket = intervalMap[interval] || "1 minute";

    const result = await pool.query(
      `SELECT
        time_bucket($1::interval, time) AS bucket,
        first(open, time) AS open,
        max(high) AS high,
        min(low) AS low,
        last(close, time) AS close,
        sum(volume) AS volume,
        avg(vwap) AS vwap
      FROM price_ticks
      WHERE symbol = $2
        AND time > NOW() - INTERVAL '7 days'
      GROUP BY bucket
      ORDER BY bucket DESC
      LIMIT $3`,
      [bucket, symbol, limit]
    );

    // Also get latest snapshot from Redis
    const latest = await redis.hgetall(`nexus:latest:${symbol}`);

    res.json({
      symbol,
      interval,
      candles: result.rows.reverse(),
      latest: latest || null,
    });
  } catch (err) {
    console.error(`Prices error for ${symbol}:`, err);
    res.status(500).json({ error: "Failed to fetch price data" });
  }
});

// GET /api/prices/:symbol/latest — fast Redis snapshot
router.get("/:symbol/latest", async (req: Request, res: Response) => {
  const symbol = req.params.symbol.toUpperCase();
  try {
    const latest = await redis.hgetall(`nexus:latest:${symbol}`);
    if (!latest || Object.keys(latest).length === 0) {
      return res.status(404).json({ error: "No data for symbol" });
    }
    res.json({ symbol, ...latest });
  } catch (err) {
    res.status(500).json({ error: "Redis error" });
  }
});

export default router;
