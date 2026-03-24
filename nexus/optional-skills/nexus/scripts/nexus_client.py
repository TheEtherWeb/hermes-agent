#!/usr/bin/env python3
"""
NEXUS Trading Intelligence Platform — CLI client.
Stdlib-only: urllib, json, argparse, sys.
No external dependencies required.

Usage:
  python nexus_client.py status
  python nexus_client.py predict AAPL
  python nexus_client.py prices AAPL [--interval 1m] [--limit 50]
  python nexus_client.py sentiment AAPL
  python nexus_client.py news AAPL [--limit 10]
  python nexus_client.py algos AAPL
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime


BASE_URL = os.environ.get("NEXUS_GATEWAY_URL", "http://localhost:3001")


def _get(path: str) -> dict:
    url = f"{BASE_URL}{path}"
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"Error {e.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Cannot connect to NEXUS gateway at {BASE_URL}: {e.reason}", file=sys.stderr)
        print("Is the platform running? Try: cd nexus && make up", file=sys.stderr)
        sys.exit(1)


def cmd_status(args):
    data = _get("/health")
    print(f"Status:  {data.get('status', '?').upper()}")
    print(f"Service: {data.get('service', 'nexus-gateway')}")
    symbols = data.get("symbols", [])
    print(f"Symbols: {', '.join(symbols)}")


def cmd_predict(args):
    symbol = args.symbol.upper()
    data = _get(f"/api/predictions/{symbol}")

    consensus = data.get("consensus")
    if not consensus:
        print(f"No consensus prediction available for {symbol}")
        return

    direction = {1: "LONG ▲", 0: "NEUTRAL →", -1: "SHORT ▼"}.get(consensus.get("direction", 0), "?")
    risk_colors = {
        "LOW": "\033[92m", "MODERATE": "\033[92m",
        "ELEVATED": "\033[93m", "HIGH": "\033[91m", "EXTREME": "\033[91m",
    }
    risk_level = consensus.get("risk_level", "?")
    rc = risk_colors.get(risk_level, "")
    reset = "\033[0m"

    print(f"\n{'='*50}")
    print(f"  NEXUS Consensus: {symbol}")
    print(f"{'='*50}")
    print(f"  Direction:     {direction}")
    print(f"  Confidence:    {round(float(consensus.get('confidence', 0)) * 100)}%")
    print(f"  Timeframe:     {consensus.get('timeframe', '?')}")
    print(f"  Target Price:  ${float(consensus.get('price_target', 0)):.2f}")
    print(f"  Agreement:     {round(float(consensus.get('algo_agreement', 0)) * 100)}%")
    print(f"  Regime:        {consensus.get('regime', '?')}")
    print(f"  Risk Score:    {consensus.get('risk_score', '?')}/100  {rc}{risk_level}{reset}")
    if consensus.get("position_size"):
        print(f"  Position Size: {float(consensus['position_size'])*100:.1f}%")
    if consensus.get("stop_loss"):
        print(f"  Stop Loss:     ${float(consensus['stop_loss']):.2f}")
    if consensus.get("take_profit"):
        print(f"  Take Profit:   ${float(consensus['take_profit']):.2f}")
    if consensus.get("var_95"):
        print(f"  VaR 95%:       {float(consensus['var_95'])*100:.2f}%")
    print(f"{'='*50}\n")

    # Print algo weights
    weights_raw = consensus.get("algo_weights") or "{}"
    if isinstance(weights_raw, str):
        weights = json.loads(weights_raw)
    else:
        weights = weights_raw
    if weights:
        print("  Algo Weights:")
        for algo, w in weights.items():
            print(f"    {algo:10s} {float(w)*100:.1f}%")
    print()


def cmd_prices(args):
    symbol = args.symbol.upper()
    interval = getattr(args, "interval", "1m")
    limit = getattr(args, "limit", 20)
    data = _get(f"/api/prices/{symbol}?interval={interval}&limit={limit}")

    candles = data.get("candles", [])
    if not candles:
        print(f"No price data for {symbol}")
        return

    print(f"\n{symbol} ({interval} candles, last {len(candles)}):")
    print(f"{'Time':20s} {'Open':>10} {'High':>10} {'Low':>10} {'Close':>10} {'Volume':>12}")
    print("-" * 76)
    for c in candles[-20:]:
        t = c.get("bucket", "?")[:19]
        print(
            f"{t:20s} "
            f"{float(c.get('open',0)):10.2f} "
            f"{float(c.get('high',0)):10.2f} "
            f"{float(c.get('low',0)):10.2f} "
            f"{float(c.get('close',0)):10.2f} "
            f"{int(c.get('volume',0)):12,}"
        )

    latest = data.get("latest")
    if latest:
        print(f"\nLatest: ${float(latest.get('close',0)):.2f} (source: {latest.get('source','?')})")
    print()


def cmd_sentiment(args):
    symbol = args.symbol.upper()
    data = _get(f"/api/sentiment/{symbol}")

    current = data.get("current")
    if current:
        wss = float(current.get("wss", 0))
        velocity = float(current.get("velocity", 0))
        articles = int(current.get("article_count", 0))
        direction = "▲ bullish" if wss > 0.1 else "▼ bearish" if wss < -0.1 else "→ neutral"
        print(f"\n{symbol} Sentiment (FinBERT):")
        print(f"  WSS Score:  {wss:+.4f}  {direction}")
        print(f"  Velocity:   {velocity:+.4f}/hr")
        print(f"  Articles:   {articles}")
    else:
        print(f"No sentiment data for {symbol}")

    history = data.get("history", [])
    if history:
        print(f"\n  Recent Articles:")
        for art in history[:10]:
            s = art.get("sentiment", {})
            wss_str = f"{float(s.get('weighted_score', 0)):+.2f}" if s else "  —  "
            label = (s.get("label", "") or "neutral")[:3].upper()
            title = (art.get("title", "?") or "")[:60]
            print(f"  [{wss_str} {label}] {title}")
    print()


def cmd_algos(args):
    symbol = args.symbol.upper()
    data = _get(f"/api/predictions/{symbol}")

    algorithms = data.get("algorithms", [])
    accuracy = {a["algorithm"]: a for a in data.get("accuracy", [])}
    weights = data.get("weights", {})

    print(f"\n{symbol} — Algorithm Signals:")
    print(f"{'Algorithm':12s} {'Signal':8s} {'Conf':6s} {'Accuracy':10s} {'Target':10s} {'Weight':8s}")
    print("-" * 60)
    for algo_data in algorithms:
        algo = algo_data.get("algorithm", "?")
        dir_n = algo_data.get("direction", 0)
        signal = {1: "BUY  ▲", 0: "HOLD →", -1: "SELL ▼"}.get(dir_n, "?")
        conf = f"{round(float(algo_data.get('confidence', 0)) * 100)}%"
        target = f"${float(algo_data.get('price_target') or 0):.2f}"
        acc_row = accuracy.get(algo, {})
        total = int(acc_row.get("total", 0))
        correct = int(acc_row.get("correct", 0))
        acc = f"{round(correct/total*100)}% ({total})" if total > 0 else "—"
        w = weights.get(algo, 0.333)
        weight_str = f"{float(w)*100:.1f}%"
        print(f"{algo:12s} {signal:8s} {conf:6s} {acc:10s} {target:10s} {weight_str:8s}")
    print()


def main():
    parser = argparse.ArgumentParser(
        description="NEXUS Trading Intelligence Platform CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("status", help="Check platform health")

    predict_p = subparsers.add_parser("predict", help="Get consensus prediction")
    predict_p.add_argument("symbol", help="Ticker symbol (e.g. AAPL)")

    prices_p = subparsers.add_parser("prices", help="Get OHLCV price data")
    prices_p.add_argument("symbol")
    prices_p.add_argument("--interval", default="1m", choices=["1m", "5m", "15m", "1h", "1d"])
    prices_p.add_argument("--limit", type=int, default=20)

    sentiment_p = subparsers.add_parser("sentiment", help="Get FinBERT sentiment")
    sentiment_p.add_argument("symbol")

    news_p = subparsers.add_parser("news", help="Get recent news articles")
    news_p.add_argument("symbol")
    news_p.add_argument("--limit", type=int, default=10)

    algos_p = subparsers.add_parser("algos", help="Get all algorithm signals")
    algos_p.add_argument("symbol")

    args = parser.parse_args()
    commands = {
        "status": cmd_status,
        "predict": cmd_predict,
        "prices": cmd_prices,
        "sentiment": cmd_sentiment,
        "algos": cmd_algos,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
