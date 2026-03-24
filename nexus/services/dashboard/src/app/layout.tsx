import type { Metadata } from "next";
import "./globals.css";
import { TickerBar } from "@/components/TickerBar";

export const metadata: Metadata = {
  title: "NEXUS Trading Intelligence",
  description: "Multi-algorithm real-time trading intelligence platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-nexus-bg">
        <header className="sticky top-0 z-50 bg-nexus-card border-b border-nexus-border">
          <div className="flex items-center justify-between px-4 h-14">
            <div className="flex items-center gap-3">
              <span className="text-nexus-accent font-bold text-lg tracking-widest">NEXUS</span>
              <span className="text-gray-600 text-xs uppercase tracking-widest">Trading Intelligence</span>
            </div>
            <div className="text-gray-500 text-xs">v3.0</div>
          </div>
          <TickerBar />
        </header>
        <main className="p-4">{children}</main>
      </body>
    </html>
  );
}
