---
name: nexus
description: >
  Interact with a locally-running NEXUS Trading Intelligence Platform.
  Provides real-time market data, SENTINEL/ORACLE/PHANTOM algorithm signals,
  FinBERT news sentiment analysis, recursive cross-validation consensus
  predictions, and comprehensive risk analysis (VaR, Kelly position sizing,
  scenario analysis). Load this skill when the user asks about NEXUS, trading
  signals, algorithm predictions, market sentiment, risk analysis, or wants
  to manage the NEXUS platform.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags:
      - trading
      - finance
      - stocks
      - sentiment
      - algorithms
      - timeseries
      - risk
    category: finance
    related_skills: []
prerequisites:
  env:
    - name: NEXUS_GATEWAY_URL
      description: URL of the NEXUS API gateway (default http://localhost:3001)
      required: false
      default: "http://localhost:3001"
---

# NEXUS Trading Intelligence Platform

NEXUS is a production-grade multi-algorithm trading intelligence platform running as a Docker Compose stack. It combines real-time price data, financial news sentiment (FinBERT NLP), and three competing prediction algorithms that recursively validate and correct each other.

## Platform Architecture

| Service | Port | Purpose |
|---------|------|---------|
| Dashboard | 3000 | React 19 live trading dashboard |
| API Gateway | 3001 | REST API + Socket.io WebSocket |
| Flower | 5555 | Celery task monitoring |
| TimescaleDB | 5432 | Price ticks and predictions (internal) |
| MongoDB | 27017 | News articles and sentiment (internal) |
| Redis | 6379 | Streams and feature cache (internal) |

## Prerequisites Check

Before using this skill, verify NEXUS is running:

```bash
curl -s http://localhost:3001/health | python3 -m json.tool
```

Expected response:
```json
{"status": "ok", "service": "nexus-gateway", "symbols": ["AAPL", "MSFT", ...]}
```

If not running, start the platform:
```bash
cd /path/to/hermes-agent/nexus
make up   # or: docker compose up -d
```

Startup takes ~2-3 minutes for FinBERT model loading on first run.

## Helper Script

All commands use `nexus_client.py` in this skill's `scripts/` directory.
Run it with:
```bash
python skills/nexus/scripts/nexus_client.py <command> [args]
# or set NEXUS_GATEWAY_URL if gateway is not at localhost:3001
NEXUS_GATEWAY_URL=http://192.168.1.100:3001 python nexus_client.py status
```

## Quick Reference

| User Request | Command |
|---|---|
| "Is NEXUS running?" | `nexus_client.py status` |
| "What does NEXUS predict for AAPL?" | `nexus_client.py predict AAPL` |
| "Show me TSLA price history" | `nexus_client.py prices TSLA --interval 5m --limit 50` |
| "What's the sentiment on NVDA?" | `nexus_client.py sentiment NVDA` |
| "Show algorithm signals for MSFT" | `nexus_client.py algos MSFT` |
| "Get recent news for GOOGL" | `nexus_client.py news GOOGL --limit 15` |

## The Three Algorithms

**SENTINEL** — Momentum & Trend Following
- Uses EMA crossovers (9/21/50/200), RSI divergence, MACD histogram, Bollinger Bands
- Best in: trending markets
- Self-corrects: tracks false signal rate over 50-iteration rolling window

**ORACLE** — Sentiment & News-Driven
- Uses FinBERT weighted sentiment scores, news volume anomaly detection, sentiment velocity
- Best in: event-driven / earnings / macro news periods
- Self-corrects: applies exponential decay to stale sentiment

**PHANTOM** — Quantitative & Statistical
- Uses ARIMA time-series forecasts, Hurst exponent, Monte Carlo simulation, mean reversion
- Best in: range-bound / mean-reverting markets
- Self-corrects: refits ARIMA every 30 minutes, detects regime changes

## Consensus Prediction Explained

The consensus combines all three algorithms via regime-weighted voting:

| Regime | Condition | SENTINEL | ORACLE | PHANTOM |
|--------|-----------|----------|--------|---------|
| Strong Trend | ADX>25, Hurst>0.6 | 50% | 25% | 25% |
| Event-Driven | News spike >2σ | 25% | 50% | 25% |
| Mean Reverting | Hurst<0.4, low ADX | 25% | 25% | 50% |
| High Volatility | ATR spike >2σ | 33% | 33% | 33% |
| Low Conviction | All <60% confidence | — | — | — |

Every 10 ticks the cross-validator adjusts weights via gradient descent based on rolling accuracy.

## Risk Analysis

Every consensus prediction includes:

- **VaR 95%/99%**: Maximum expected loss at 95th/99th percentile (Monte Carlo, 1000+ paths)
- **Risk Score** (0–100): Weighted composite of Volatility(25%) + AlgoDisagreement(30%) + MaxDrawdown(20%) + Correlation(15%) + Liquidity(10%)
- **Position Size**: Modified Kelly Criterion — kelly_fraction × agreement × risk_multiplier × max_allocation (max 15%)
- **Stop Loss / Take Profit**: ATR-based dynamic levels (widens in volatile markets)
- **Scenarios**: Bull (95th pct), Base (median), Bear (5th pct), Black Swan (1st pct × 0.9)

## Workflow: Checking a Trade Opportunity

1. Check platform status: `nexus_client.py status`
2. Get consensus prediction: `nexus_client.py predict AAPL`
3. Review individual algorithms: `nexus_client.py algos AAPL`
4. Check news sentiment driving ORACLE: `nexus_client.py sentiment AAPL`
5. Review recent price action: `nexus_client.py prices AAPL --interval 15m --limit 40`

Key things to look for in the consensus output:
- **Algorithm Agreement** ≥ 67%: two or more algos agree → stronger signal
- **Risk Score** < 40: LOW/MODERATE risk → full position sizing applies
- **Regime**: determines which algorithm leads the consensus
- **Confidence** > 70%: high-confidence signals are more reliable

## Platform Management

**View logs:**
```bash
cd nexus && make logs-algo   # algorithm engine logs
cd nexus && make logs-ingestion  # price/news feed logs
cd nexus && make logs-gateway    # API gateway logs
```

**Check database:**
```bash
cd nexus && make db-check  # shows hypertable stats and collections
cd nexus && make redis-check  # shows active Redis streams
```

**Restart a service:**
```bash
cd nexus && docker compose restart algo-engine
```

**Scale algorithm workers:**
```bash
cd nexus && docker compose up -d --scale algo-engine=2
```

**Monitor Celery tasks:**
Open http://localhost:5555 in a browser (Flower dashboard).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXUS_GATEWAY_URL` | `http://localhost:3001` | Gateway URL for nexus_client.py |
| `POLYGON_API_KEY` | — | Primary price feed (Polygon.io) |
| `FINNHUB_API_KEY` | — | Backup price feed + free sentiment |
| `NEWSAPI_KEY` | — | News aggregation (NYT, WSJ, Reuters) |
| `FINBERT_DEVICE` | `cpu` | `cpu` or `cuda:0` for GPU inference |
| `MONTE_CARLO_PATHS` | `1000` | Increase to `10000` for production |

## Pitfalls

- **FinBERT loading**: First Docker build downloads 430MB model. Build once, then it's cached. If predictions seem wrong, run `docker compose logs algo-engine | grep FinBERT`.
- **No Polygon key**: Price streams fall back to Finnhub. All features still work.
- **No NewsAPI key**: ORACLE algorithm runs without news data; will produce neutral signals.
- **TimescaleDB compression**: Ticks older than 7 days are compressed and read-only. Historical queries still work via `time_bucket()`.
- **ARIMA convergence**: If PHANTOM produces all-HOLD signals, the ARIMA model may not have converged. Check `docker compose logs algo-engine | grep ARIMA`.
