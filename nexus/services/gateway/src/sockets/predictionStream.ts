/**
 * Redis Streams → Socket.io bridge for prediction and consensus events.
 */
import { Server as SocketServer } from "socket.io";
import Redis from "ioredis";

const CONSUMER_GROUP = "gateway-pred-push";
const CONSUMER_NAME = "gateway-pred-1";

export function startPredictionStream(io: SocketServer, redis: Redis, symbols: string[]): void {
  const streamClient = redis.duplicate();

  (async () => {
    // Ensure consumer groups for predictions and consensus streams
    for (const symbol of symbols) {
      for (const streamType of ["predictions", "consensus"]) {
        try {
          await streamClient.xgroup(
            "CREATE",
            `nexus:${streamType}:${symbol}`,
            CONSUMER_GROUP,
            "$",
            "MKSTREAM"
          );
        } catch {
          // Already exists
        }
      }
    }

    const predStreamKeys = symbols.flatMap((sym) => [
      `nexus:predictions:${sym}`,
      `nexus:consensus:${sym}`,
    ]);
    const streamArgs = [...predStreamKeys, ...predStreamKeys.map(() => ">")];

    console.log("Prediction stream bridge started");

    while (true) {
      try {
        const results = await streamClient.xreadgroup(
          "GROUP",
          CONSUMER_GROUP,
          CONSUMER_NAME,
          "COUNT",
          "20",
          "BLOCK",
          2000,
          "STREAMS",
          ...predStreamKeys,
          ...predStreamKeys.map(() => ">")
        );

        if (!results) continue;

        for (const [streamName, messages] of results as [string, [string, string[]][]][]) {
          const parts = streamName.split(":");
          const streamType = parts[1];  // 'predictions' or 'consensus'
          const symbol = parts[2];

          for (const [msgId, fields] of messages) {
            const data = parseFields(fields);
            if (data) {
              const eventName = streamType === "consensus" ? "consensus_update" : "prediction_update";
              io.to(`predictions:${symbol}`).emit(eventName, { symbol, ...data });
            }
            await streamClient.xack(streamName, CONSUMER_GROUP, msgId);
          }
        }
      } catch (err: any) {
        if (!err.message?.includes("Connection")) {
          console.error("Prediction stream error:", err.message);
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
    obj[key] = isNaN(Number(val)) || val === "" ? val : Number(val);
  }
  return Object.keys(obj).length > 0 ? obj : null;
}
