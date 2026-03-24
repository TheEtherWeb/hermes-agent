"use client";
import { useEffect, useState } from "react";
import { useSocket } from "@/hooks/useSocket";
import { api } from "@/lib/api";
import type { AlgoPrediction } from "@/types";
import clsx from "clsx";

interface Props {
  symbol: string;
}

const ALGO_DESCRIPTIONS: Record<string, string> = {
  SENTINEL: "Momentum · EMA/RSI/MACD/Bollinger",
  ORACLE: "Sentiment · FinBERT News Analysis",
  PHANTOM: "Statistical · ARIMA + Monte Carlo",
};

const DIRECTION_LABELS: Record<number, string> = { 1: "BUY", 0: "HOLD", "-1": "SELL" } as any;
const DIRECTION_COLORS: Record<number, string> = {
  1: "text-nexus-buy",
  0: "text-nexus-neutral",
  [-1]: "text-nexus-sell",
};

export function AlgoPanel({ symbol }: Props) {
  const { socket } = useSocket(symbol);
  const [preds, setPreds] = useState<Record<string, AlgoPrediction>>({});
  const [accuracy, setAccuracy] = useState<Record<string, number>>({});

  useEffect(() => {
    api.predictions(symbol).then((data) => {
      const byAlgo: Record<string, AlgoPrediction> = {};
      for (const p of (data.algorithms || [])) {
        byAlgo[p.algorithm] = p;
      }
      setPreds(byAlgo);

      const acc: Record<string, number> = {};
      for (const a of (data.accuracy || [])) {
        acc[a.algorithm] = a.total > 0 ? Math.round((a.correct / a.total) * 100) : 0;
      }
      setAccuracy(acc);
    }).catch(() => {});
  }, [symbol]);

  useEffect(() => {
    if (!socket) return;
    const handler = (data: any) => {
      if (data.symbol === symbol && data.algorithm) {
        setPreds((prev) => ({ ...prev, [data.algorithm]: { ...prev[data.algorithm], ...data } }));
      }
    };
    socket.on("prediction_update", handler);
    return () => { socket.off("prediction_update", handler); };
  }, [socket, symbol]);

  const algos = ["SENTINEL", "ORACLE", "PHANTOM"] as const;

  return (
    <div className="grid grid-cols-3 gap-3">
      {algos.map((algo) => {
        const pred = preds[algo];
        const dir = pred?.direction ?? 0;
        const conf = pred ? Math.round(pred.confidence * 100) : 0;
        const acc = accuracy[algo] ?? 0;

        return (
          <div
            key={algo}
            className="bg-nexus-card border border-nexus-border rounded-lg p-4"
          >
            <div className="flex items-start justify-between mb-2">
              <div>
                <div className="text-white font-bold text-sm">{algo}</div>
                <div className="text-gray-500 text-xs mt-0.5">{ALGO_DESCRIPTIONS[algo]}</div>
              </div>
              <div className={clsx("text-lg font-bold font-mono", DIRECTION_COLORS[dir])}>
                {DIRECTION_LABELS[dir] || "—"}
              </div>
            </div>

            {/* Confidence bar */}
            <div className="mt-3">
              <div className="flex justify-between text-xs text-gray-500 mb-1">
                <span>Confidence</span>
                <span className="text-white">{conf}%</span>
              </div>
              <div className="h-1.5 bg-nexus-border rounded-full overflow-hidden">
                <div
                  className={clsx(
                    "h-full rounded-full transition-all",
                    dir === 1 ? "bg-nexus-buy" : dir === -1 ? "bg-nexus-sell" : "bg-nexus-neutral"
                  )}
                  style={{ width: `${conf}%` }}
                />
              </div>
            </div>

            {/* Accuracy */}
            <div className="mt-3 flex justify-between text-xs">
              <span className="text-gray-500">7d Accuracy</span>
              <span className={clsx("font-mono", acc >= 55 ? "text-nexus-buy" : acc >= 45 ? "text-yellow-400" : "text-nexus-sell")}>
                {acc > 0 ? `${acc}%` : "—"}
              </span>
            </div>

            {pred?.price_target && (
              <div className="mt-1 flex justify-between text-xs">
                <span className="text-gray-500">Target</span>
                <span className="text-white font-mono">
                  ${Number(pred.price_target).toFixed(2)}
                </span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
