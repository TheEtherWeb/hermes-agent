"use client";
import { useEffect, useState } from "react";
import { useSocket } from "./useSocket";

export interface PriceTick {
  symbol: string;
  close: number;
  open: number;
  high: number;
  low: number;
  volume: number;
  source: string;
  ts: number;
}

export function usePriceStream(symbol: string, initialPrice?: number) {
  const { socket, connected } = useSocket(symbol);
  const [price, setPrice] = useState<number | null>(initialPrice ?? null);
  const [tick, setTick] = useState<PriceTick | null>(null);
  const [change, setChange] = useState<number>(0); // percent change

  useEffect(() => {
    if (!socket) return;

    const prevPrice = { value: price };

    const handler = (data: PriceTick) => {
      if (data.symbol === symbol) {
        const newPrice = Number(data.close);
        if (prevPrice.value !== null) {
          setChange(((newPrice - prevPrice.value) / prevPrice.value) * 100);
        }
        prevPrice.value = newPrice;
        setPrice(newPrice);
        setTick(data);
      }
    };

    socket.on("price_update", handler);
    return () => { socket.off("price_update", handler); };
  }, [socket, symbol]);

  return { price, tick, change, connected };
}
