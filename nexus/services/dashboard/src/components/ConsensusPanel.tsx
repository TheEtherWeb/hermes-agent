"use client";
import { useEffect, useState } from "react";
import { useSocket } from "@/hooks/useSocket";
import { api } from "@/lib/api";
import type { ConsensusPrediction } from "@/types";
import clsx from "clsx";

interface Props { symbol: string }

const RISK_COLORS: Record<string, string> = {
  LOW: "text-nexus-buy",
  MODERATE: "text-green-400",
  ELEVATED: "text-yellow-400",
  HIGH: "text-orange-400",
  EXTREME: "text-nexus-sell",
};

const REGIME_LABELS: Record<string, string> = {
  STRONG_TREND: "Strong Trend",
  EVENT_DRIVEN: "Event Driven",
  MEAN_REVERTING: "Mean Reverting",
  HIGH_VOLATILITY: "High Volatility",
  LOW_CONVICTION: "Low Conviction",
  UNKNOWN: "—",
};

export function ConsensusPanel({ symbol }: Props) {
  const { socket } = useSocket(symbol);
  const [consensus, setConsensus] = useState<ConsensusPrediction | null>(null);

  useEffect(() => {
    api.predictions(symbol).then((data) => {
      if (data.consensus) setConsensus(data.consensus);
    }).catch(() => {});
  }, [symbol]);

  useEffect(() => {
    if (!socket) return;
    const handler = (data: any) => {
      if (data.symbol === symbol) setConsensus((prev) => ({ ...prev, ...data } as ConsensusPrediction));
    };
    socket.on("consensus_update", handler);
    return () => { socket.off("consensus_update", handler); };
  }, [socket, symbol]);

  const dir = consensus?.direction ?? 0;
  const label = consensus?.direction_label ?? "NEUTRAL";
  const dirBg = dir === 1 ? "bg-nexus-buy/20 border-nexus-buy/40" :
    dir === -1 ? "bg-nexus-sell/20 border-nexus-sell/40" :
    "bg-nexus-neutral/20 border-nexus-neutral/40";
  const dirText = dir === 1 ? "text-nexus-buy" : dir === -1 ? "text-nexus-sell" : "text-nexus-neutral";

  return (
    <div className="bg-nexus-card border border-nexus-border rounded-lg p-4">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-white font-semibold text-sm uppercase tracking-wide">Consensus</h3>
        {consensus && (
          <span className="text-xs text-gray-500">
            {REGIME_LABELS[consensus.regime] || consensus.regime}
          </span>
        )}
      </div>

      {!consensus ? (
        <div className="text-gray-500 text-sm text-center py-6">Awaiting predictions…</div>
      ) : (
        <div className="space-y-3">
          {/* Direction badge */}
          <div className={clsx("inline-flex items-center gap-2 px-4 py-2 rounded-lg border text-lg font-bold", dirBg, dirText)}>
            {label}
            <span className="text-sm font-normal text-gray-400">
              {Math.round(consensus.confidence * 100)}% conf
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-sm">
            <InfoRow label="Target" value={`$${Number(consensus.price_target).toFixed(2)}`} />
            <InfoRow label="Timeframe" value={consensus.timeframe} />
            <InfoRow label="Agreement" value={`${Math.round(consensus.algo_agreement * 100)}%`} />
            <InfoRow
              label="Risk"
              value={`${consensus.risk_score}/100`}
              valueClass={RISK_COLORS[consensus.risk_level] || "text-white"}
            />
            <InfoRow label="Risk Level" value={consensus.risk_level || "—"} valueClass={RISK_COLORS[consensus.risk_level] || "text-white"} />
            <InfoRow label="Position Size" value={consensus.position_size ? `${(consensus.position_size * 100).toFixed(1)}%` : "—"} />
          </div>

          {consensus.stop_loss && consensus.take_profit && (
            <div className="grid grid-cols-2 gap-3 text-sm border-t border-nexus-border pt-3">
              <InfoRow label="Stop Loss" value={`$${Number(consensus.stop_loss).toFixed(2)}`} valueClass="text-nexus-sell" />
              <InfoRow label="Take Profit" value={`$${Number(consensus.take_profit).toFixed(2)}`} valueClass="text-nexus-buy" />
            </div>
          )}

          {consensus.var_95 && (
            <div className="grid grid-cols-2 gap-3 text-sm">
              <InfoRow label="VaR 95%" value={`${(consensus.var_95 * 100).toFixed(2)}%`} />
              <InfoRow label="VaR 99%" value={`${(consensus.var_99 * 100).toFixed(2)}%`} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function InfoRow({
  label, value, valueClass = "text-white"
}: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="flex justify-between">
      <span className="text-gray-500">{label}</span>
      <span className={clsx("font-mono", valueClass)}>{value}</span>
    </div>
  );
}
