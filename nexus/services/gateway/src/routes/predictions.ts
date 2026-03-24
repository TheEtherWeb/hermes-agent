import { Router, Request, Response } from "express";
import { pool } from "../db/postgres";
import { redis } from "../db/redis";

const router = Router();

// GET /api/predictions/:symbol — latest consensus + individual algo predictions
router.get("/:symbol", async (req: Request, res: Response) => {
  const symbol = req.params.symbol.toUpperCase();
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);

  try {
    // Latest prediction per algorithm
    const algosResult = await pool.query(
      `SELECT DISTINCT ON (algorithm)
        id, time, algorithm, direction, confidence,
        price_at_signal, price_target, horizon_minutes, was_correct
      FROM predictions
      WHERE symbol = $1
      ORDER BY algorithm, time DESC`,
      [symbol]
    );

    // Rolling accuracy per algorithm (last 7 days)
    const accuracyResult = await pool.query(
      `SELECT algorithm,
        COUNT(*) as total,
        SUM(CASE WHEN was_correct THEN 1 ELSE 0 END) as correct,
        AVG(confidence)::numeric(5,4) as avg_confidence
      FROM predictions
      WHERE symbol = $1
        AND was_correct IS NOT NULL
        AND time > NOW() - INTERVAL '7 days'
      GROUP BY algorithm`,
      [symbol]
    );

    // Latest consensus
    const consensusResult = await pool.query(
      `SELECT *
      FROM consensus_predictions
      WHERE symbol = $1
      ORDER BY time DESC
      LIMIT 1`,
      [symbol]
    );

    // Recent prediction history
    const historyResult = await pool.query(
      `SELECT id, time, algorithm, direction, confidence, was_correct, price_at_signal, price_target
      FROM predictions
      WHERE symbol = $1
      ORDER BY time DESC
      LIMIT $2`,
      [symbol, limit]
    );

    // Current algo weights from Redis
    const weightsRaw = await redis.get(`nexus:algo:weight:${symbol}`);
    const weights = weightsRaw ? JSON.parse(weightsRaw) : { SENTINEL: 0.333, ORACLE: 0.333, PHANTOM: 0.334 };

    res.json({
      symbol,
      algorithms: algosResult.rows,
      accuracy: accuracyResult.rows,
      consensus: consensusResult.rows[0] || null,
      history: historyResult.rows,
      weights,
    });
  } catch (err) {
    console.error(`Predictions error for ${symbol}:`, err);
    res.status(500).json({ error: "Failed to fetch predictions" });
  }
});

export default router;
