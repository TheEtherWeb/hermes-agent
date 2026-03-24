import express from "express";
import { createServer } from "http";
import { Server as SocketServer } from "socket.io";
import cors from "cors";
import rateLimit from "express-rate-limit";

import { config } from "./config";
import { pool } from "./db/postgres";
import { redis } from "./db/redis";
import { connectMongo } from "./db/mongo";
import { startPriceStream } from "./sockets/priceStream";
import { startPredictionStream } from "./sockets/predictionStream";

import pricesRouter from "./routes/prices";
import predictionsRouter from "./routes/predictions";
import sentimentRouter from "./routes/sentiment";
import newsRouter from "./routes/news";

async function bootstrap() {
  // Connect databases
  await redis.connect();
  await connectMongo();

  const app = express();
  const httpServer = createServer(app);

  // Socket.io with CORS
  const io = new SocketServer(httpServer, {
    cors: {
      origin: config.corsOrigins,
      methods: ["GET", "POST"],
    },
    pingInterval: 10_000,
    pingTimeout: 5_000,
  });

  // Middleware
  app.use(cors({ origin: config.corsOrigins }));
  app.use(express.json());
  app.use(
    rateLimit({
      windowMs: 60_000,
      max: 300,
      standardHeaders: true,
      legacyHeaders: false,
    })
  );

  // Health endpoint
  app.get("/health", async (_req, res) => {
    try {
      await pool.query("SELECT 1");
      await redis.ping();
      res.json({ status: "ok", service: "nexus-gateway", symbols: config.watchedSymbols });
    } catch (err: any) {
      res.status(503).json({ status: "error", message: err.message });
    }
  });

  // REST routes
  app.use("/api/prices", pricesRouter);
  app.use("/api/predictions", predictionsRouter);
  app.use("/api/sentiment", sentimentRouter);
  app.use("/api/news", newsRouter);

  // Socket.io room management
  io.on("connection", (socket) => {
    console.log(`Client connected: ${socket.id}`);

    // Client subscribes to a symbol
    socket.on("subscribe", (symbol: string) => {
      const sym = symbol.toUpperCase();
      socket.join(`prices:${sym}`);
      socket.join(`predictions:${sym}`);
      console.log(`${socket.id} subscribed to ${sym}`);
    });

    socket.on("unsubscribe", (symbol: string) => {
      const sym = symbol.toUpperCase();
      socket.leave(`prices:${sym}`);
      socket.leave(`predictions:${sym}`);
    });

    socket.on("disconnect", () => {
      console.log(`Client disconnected: ${socket.id}`);
    });
  });

  // Start Redis → Socket.io bridges
  startPriceStream(io, redis, config.watchedSymbols);
  startPredictionStream(io, redis, config.watchedSymbols);

  httpServer.listen(config.port, () => {
    console.log(`NEXUS API Gateway running on :${config.port}`);
    console.log(`Watching symbols: ${config.watchedSymbols.join(", ")}`);
  });
}

bootstrap().catch((err) => {
  console.error("Gateway startup error:", err);
  process.exit(1);
});
