const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";

async function apiFetch<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { cache: "no-store" });
  if (!res.ok) throw new Error(`API error: ${res.status} ${path}`);
  return res.json();
}

export const api = {
  prices: (symbol: string, interval = "1m", limit = 200) =>
    apiFetch<any>(`/api/prices/${symbol}?interval=${interval}&limit=${limit}`),

  latestPrice: (symbol: string) =>
    apiFetch<any>(`/api/prices/${symbol}/latest`),

  predictions: (symbol: string) =>
    apiFetch<any>(`/api/predictions/${symbol}`),

  sentiment: (symbol: string) =>
    apiFetch<any>(`/api/sentiment/${symbol}`),

  news: (symbol: string, limit = 20) =>
    apiFetch<any>(`/api/news/${symbol}?limit=${limit}`),
};
