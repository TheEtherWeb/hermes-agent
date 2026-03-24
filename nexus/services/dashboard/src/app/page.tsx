"use client";
import { useState } from "react";
import { PriceChart } from "@/components/PriceChart";
import { AlgoPanel } from "@/components/AlgoPanel";
import { ConsensusPanel } from "@/components/ConsensusPanel";
import { SentimentPanel } from "@/components/SentimentPanel";
import clsx from "clsx";

const SYMBOLS = (process.env.NEXT_PUBLIC_WATCHED_SYMBOLS || "AAPL,MSFT,GOOGL,TSLA,NVDA")
  .split(",")
  .map((s) => s.trim().toUpperCase());

export default function DashboardPage() {
  const [symbol, setSymbol] = useState(SYMBOLS[0]);

  return (
    <div className="max-w-7xl mx-auto space-y-4">
      {/* Symbol selector */}
      <div className="flex items-center gap-2 flex-wrap">
        {SYMBOLS.map((sym) => (
          <button
            key={sym}
            onClick={() => setSymbol(sym)}
            className={clsx(
              "px-4 py-1.5 rounded-full text-sm font-medium transition-colors",
              symbol === sym
                ? "bg-nexus-accent text-white"
                : "bg-nexus-card border border-nexus-border text-gray-400 hover:text-white"
            )}
          >
            {sym}
          </button>
        ))}
      </div>

      {/* Price chart */}
      <PriceChart symbol={symbol} />

      {/* Algorithm signals */}
      <div>
        <h2 className="text-gray-400 text-xs uppercase tracking-wider mb-2">Algorithm Signals</h2>
        <AlgoPanel symbol={symbol} />
      </div>

      {/* Consensus + Sentiment side by side */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div>
          <h2 className="text-gray-400 text-xs uppercase tracking-wider mb-2">Consensus Prediction</h2>
          <ConsensusPanel symbol={symbol} />
        </div>
        <div>
          <h2 className="text-gray-400 text-xs uppercase tracking-wider mb-2">News Sentiment</h2>
          <SentimentPanel symbol={symbol} />
        </div>
      </div>
    </div>
  );
}
