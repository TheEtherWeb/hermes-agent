"use client";
import { useEffect, useState } from "react";
import {
  ComposedChart,
  Bar,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";
import { api } from "@/lib/api";
import { usePriceStream } from "@/hooks/usePriceStream";
import { format } from "date-fns";

interface Candle {
  bucket: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface Props {
  symbol: string;
}

export function PriceChart({ symbol }: Props) {
  const [candles, setCandles] = useState<Candle[]>([]);
  const [loading, setLoading] = useState(true);
  const { price: livePrice, change, connected } = usePriceStream(symbol);

  useEffect(() => {
    api.prices(symbol, "1m", 120).then((data) => {
      setCandles(data.candles || []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [symbol]);

  const currentPrice = livePrice ?? candles[candles.length - 1]?.close;
  const isPositive = change >= 0;

  if (loading) {
    return (
      <div className="bg-nexus-card border border-nexus-border rounded-lg p-6 h-80 flex items-center justify-center">
        <div className="text-gray-500 text-sm">Loading price data...</div>
      </div>
    );
  }

  const chartData = candles.map((c) => ({
    time: format(new Date(c.bucket), "HH:mm"),
    close: Number(c.close),
    open: Number(c.open),
    high: Number(c.high),
    low: Number(c.low),
    volume: Number(c.volume),
    // For candlestick: positive (close>open) vs negative candle bar
    barValue: Math.abs(Number(c.close) - Number(c.open)),
    barBase: Math.min(Number(c.open), Number(c.close)),
    positive: Number(c.close) >= Number(c.open),
  }));

  return (
    <div className="bg-nexus-card border border-nexus-border rounded-lg p-4">
      <div className="flex items-baseline justify-between mb-4">
        <div>
          <span className="text-2xl font-bold text-white font-mono">
            {currentPrice ? `$${currentPrice.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : "—"}
          </span>
          <span className={`ml-3 text-sm font-medium ${isPositive ? "text-nexus-buy" : "text-nexus-sell"}`}>
            {change >= 0 ? "+" : ""}{change.toFixed(2)}%
          </span>
        </div>
        <div className="flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full ${connected ? "bg-nexus-buy" : "bg-nexus-sell"}`} />
          <span className="text-xs text-gray-500">{connected ? "LIVE" : "OFFLINE"}</span>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={240}>
        <ComposedChart data={chartData} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1f2937" />
          <XAxis
            dataKey="time"
            tick={{ fill: "#6b7280", fontSize: 10 }}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis
            domain={["auto", "auto"]}
            tick={{ fill: "#6b7280", fontSize: 10 }}
            tickLine={false}
            tickFormatter={(v) => `$${v.toFixed(0)}`}
            width={60}
          />
          <Tooltip
            contentStyle={{ backgroundColor: "#111827", border: "1px solid #1f2937", borderRadius: "6px" }}
            labelStyle={{ color: "#9ca3af" }}
            itemStyle={{ color: "#e5e7eb" }}
            formatter={(value: number) => [`$${value.toFixed(2)}`]}
          />
          <Line
            type="monotone"
            dataKey="close"
            stroke="#3b82f6"
            strokeWidth={1.5}
            dot={false}
            activeDot={{ r: 3 }}
          />
          {/* Volume bars at bottom */}
          <Bar
            dataKey="volume"
            yAxisId={1}
            fill="#1f2937"
            opacity={0.5}
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
