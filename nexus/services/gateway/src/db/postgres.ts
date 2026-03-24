import { Pool } from "pg";
import { config } from "../config";

export const pool = new Pool({
  connectionString: config.timescaleUrl,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
});

pool.on("error", (err) => {
  console.error("PostgreSQL pool error:", err);
});
