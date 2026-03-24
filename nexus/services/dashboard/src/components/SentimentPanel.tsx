"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { NewsArticle, SentimentData } from "@/types";
import clsx from "clsx";
import { formatDistanceToNow } from "date-fns";

interface Props { symbol: string }

function WssBar({ score }: { score: number }) {
  const pct = Math.round(Math.abs(score) * 100);
  const isPos = score >= 0;
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className={isPos ? "text-nexus-buy" : "text-nexus-sell"}>
        {score >= 0 ? "+" : ""}{score.toFixed(3)}
      </span>
      <div className="flex-1 h-1.5 bg-nexus-border rounded-full overflow-hidden">
        <div
          className={clsx("h-full rounded-full", isPos ? "bg-nexus-buy" : "bg-nexus-sell")}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

export function SentimentPanel({ symbol }: Props) {
  const [sentiment, setSentiment] = useState<SentimentData | null>(null);
  const [articles, setArticles] = useState<NewsArticle[]>([]);

  useEffect(() => {
    api.sentiment(symbol).then((data) => {
      setSentiment(data.current);
      setArticles(data.history || []);
    }).catch(() => {});
  }, [symbol]);

  return (
    <div className="bg-nexus-card border border-nexus-border rounded-lg p-4">
      <h3 className="text-white font-semibold text-sm uppercase tracking-wide mb-4">
        Sentiment · FinBERT
      </h3>

      {sentiment && (
        <div className="mb-4 space-y-2">
          <div>
            <div className="flex justify-between text-xs text-gray-500 mb-1">
              <span>Weighted Sentiment Score</span>
              <span className="text-white">{sentiment.article_count} articles</span>
            </div>
            <WssBar score={sentiment.wss} />
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-gray-500">Velocity</span>
            <span className={clsx("font-mono", sentiment.velocity >= 0 ? "text-nexus-buy" : "text-nexus-sell")}>
              {sentiment.velocity >= 0 ? "+" : ""}{sentiment.velocity.toFixed(3)}/hr
            </span>
          </div>
        </div>
      )}

      <div className="space-y-2 max-h-64 overflow-y-auto">
        {articles.length === 0 && (
          <p className="text-gray-500 text-xs text-center py-4">No recent news</p>
        )}
        {articles.map((article) => {
          const wss = article.sentiment?.weighted_score ?? 0;
          const label = article.sentiment?.label ?? "neutral";
          const labelColor = label === "positive" ? "text-nexus-buy" :
            label === "negative" ? "text-nexus-sell" : "text-nexus-neutral";

          return (
            <div key={article._id} className="border-b border-nexus-border pb-2 last:border-0">
              <div className="flex items-start justify-between gap-2">
                <a
                  href={article.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs text-gray-300 hover:text-white line-clamp-2 flex-1"
                >
                  {article.title}
                </a>
                <span className={clsx("text-xs font-mono shrink-0", labelColor)}>
                  {wss >= 0 ? "+" : ""}{wss.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between mt-1 text-xs text-gray-500">
                <span>{article.source}</span>
                <span>{formatDistanceToNow(new Date(article.published_at), { addSuffix: true })}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
