/**
 * Redis Streams → Socket.io bridge for real-time price updates.
 * Creates a consumer group and pushes new ticks to subscribed browser rooms.
 */
import { Server as SocketServer } from "socket.io";
import Redis from "ioredis";

const CONSUMER_GROUP = "gateway-price-push";
const CONSUMER_NAME = "gateway-1";
const READ_BLOCK_MS = 1000;

export function startPriceStream(io: SocketServer, redis: Redis, symbols: string[]): void {
  // Use a dedicated Redis client for blocking reads
  const streamClient = redis.duplicate();

  (async () => {
    // Ensure consumer groups exist
    for (const symbol of symbols) {
      try {
        await streamClient.xgroup(
          "CREATE",
          `nexus:prices:${symbol}`,
          CONSUMER_GROUP,
          "$", // start from newest messages
          "MKSTREAM"
        );
      } catch {
        // Group already exists — fine
      }
    }

    const streamKeys = symbols.reduce((acc, sym) => {
      acc[`nexus:prices:${sym}`] = ">";
      return acc;
    }, {} as Record<string, string>);

    console.log("Price stream bridge started for:", symbols);

    while (true) {
      try {
        const results = await streamClient.xreadgroup(
          "GROUP",
          CONSUMER_GROUP,
          CONSUMER_NAME,
          "COUNT",
          "50",
          "BLOCK",
          READ_BLOCK_MS,
          "STREAMS",
          ...Object.keys(streamKeys),
          ...Object.values(streamKeys)
        );

        if (!results) continue;

        for (const [streamName, messages] of results as [string, [string, string[]][]][]) {
          const symbol = streamName.split(":")[2]; // nexus:prices:{symbol}

          for (const [msgId, fields] of messages) {
            const tick = parseFields(fields);
            if (tick) {
              io.to(`prices:${symbol}`).emit("price_update", { symbol, ...tick });
            }
            // Acknowledge
            await streamClient.xack(streamName, CONSUMER_GROUP, msgId);
          }
        }
      } catch (err: any) {
        if (!err.message?.includes("Connection")) {
          console.error("Price stream error:", err.message);
        }
        await new Promise((r) => setTimeout(r, 1000));
      }
    }
  })();
}

function parseFields(fields: string[]): Record<string, string | number> | null {
  const obj: Record<string, string | number> = {};
  for (let i = 0; i < fields.length; i += 2) {
    const key = fields[i];
    const val = fields[i + 1];
    obj[key] = isNaN(Number(val)) ? val : Number(val);
  }
  return Object.keys(obj).length > 0 ? obj : null;
}
