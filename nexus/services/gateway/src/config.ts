import dotenv from "dotenv";
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || "3001"),
  redisUrl: process.env.REDIS_URL || "redis://localhost:6379",
  timescaleUrl: process.env.TIMESCALE_URL || "postgresql://nexus:nexus_dev@localhost:5432/nexus",
  mongodbUrl: process.env.MONGODB_URL || "mongodb://nexus:nexus_dev@localhost:27017/nexus?authSource=admin",
  watchedSymbols: (process.env.WATCHED_SYMBOLS || "AAPL,MSFT,GOOGL,TSLA,NVDA")
    .split(",")
    .map((s) => s.trim().toUpperCase()),
  corsOrigins: process.env.CORS_ORIGINS || "*",
};
