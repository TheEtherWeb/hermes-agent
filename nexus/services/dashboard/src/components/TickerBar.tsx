"use client";
import { usePriceStream } from "@/hooks/usePriceStream";
import clsx from "clsx";

const SYMBOLS = (process.env.NEXT_PUBLIC_WATCHED_SYMBOLS || "AAPL,MSFT,GOOGL,TSLA,NVDA").split(",");

function TickerItem({ symbol }: { symbol: string }) {
  const { price, change } = usePriceStream(symbol);
  const isPos = change >= 0;

  return (
    <div className="flex items-center gap-2 px-4 border-r border-nexus-border last:border-0">
      <span className="text-gray-400 text-xs font-medium">{symbol}</span>
      <span className="text-white text-xs font-mono">
        {price ? `$${price.toFixed(2)}` : "—"}
      </span>
      {change !== 0 && (
        <span className={clsx("text-xs font-mono", isPos ? "text-nexus-buy" : "text-nexus-sell")}>
          {isPos ? "+" : ""}{change.toFixed(2)}%
        </span>
      )}
    </div>
  );
}

export function TickerBar() {
  return (
    <div className="bg-nexus-card border-b border-nexus-border">
      <div className="flex items-center h-10 overflow-x-auto">
        {SYMBOLS.map((sym) => (
          <TickerItem key={sym.trim()} symbol={sym.trim().toUpperCase()} />
        ))}
      </div>
    </div>
  );
}
