"use client";
import { useEffect, useRef, useState } from "react";
import { io, Socket } from "socket.io-client";

const WS_URL = process.env.NEXT_PUBLIC_WS_URL || "http://localhost:3001";

let globalSocket: Socket | null = null;

export function useSocket(symbol: string) {
  const [connected, setConnected] = useState(false);
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!globalSocket) {
      globalSocket = io(WS_URL, {
        transports: ["websocket", "polling"],
        reconnectionAttempts: 10,
        reconnectionDelay: 1000,
      });
    }

    const socket = globalSocket;
    socketRef.current = socket;

    const onConnect = () => {
      setConnected(true);
      socket.emit("subscribe", symbol);
    };
    const onDisconnect = () => setConnected(false);

    socket.on("connect", onConnect);
    socket.on("disconnect", onDisconnect);

    if (socket.connected) {
      setConnected(true);
      socket.emit("subscribe", symbol);
    }

    return () => {
      socket.off("connect", onConnect);
      socket.off("disconnect", onDisconnect);
      socket.emit("unsubscribe", symbol);
    };
  }, [symbol]);

  return { socket: socketRef.current, connected };
}
