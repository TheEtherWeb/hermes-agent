# NEXUS Trading Intelligence Platform

Multi-algorithm real-time trading intelligence combining momentum analysis, NLP news sentiment, and statistical modeling with recursive cross-validation.

## Quick Start

```bash
cd nexus
cp .env.example .env
# Add your API keys to .env (optional — works on free tiers without them)
make up
```

- Dashboard: http://localhost:3000
- API Gateway: http://localhost:3001
- Celery Monitor: http://localhost:5555

## Architecture

```
Price feeds (Polygon.io + Finnhub WebSocket)
           ↓
     Redis Streams
    ↙    ↓       ↘
SENTINEL  ORACLE  PHANTOM   ← Three independent algorithms
    ↘    ↓       ↙
   Cross-Validator           ← Gradient descent weight updates every 10 ticks
         ↓
   Consensus Engine          ← Regime-weighted voting
         ↓
    Risk Engine              ← Monte Carlo VaR + Kelly position sizing
         ↓
  API Gateway (REST + WS)   → React Dashboard
```

## The Three Algorithms

| Algorithm | Method | Best Regime |
|-----------|--------|-------------|
| **SENTINEL** | EMA crossovers, RSI, MACD, Bollinger Bands | Trending markets |
| **ORACLE** | FinBERT sentiment, news volume anomaly | Event-driven periods |
| **PHANTOM** | ARIMA, Hurst exponent, Monte Carlo | Range-bound markets |

## API Keys

All keys are optional. The platform degrades gracefully:

| Key | Source | Without it |
|-----|--------|-----------|
| `POLYGON_API_KEY` | polygon.io | Falls back to Finnhub |
| `FINNHUB_API_KEY` | finnhub.io | No backup price feed |
| `NEWSAPI_KEY` | newsapi.org | ORACLE signals neutral |

## REST API

```
GET /health
GET /api/prices/:symbol?interval=1m&limit=200
GET /api/prices/:symbol/latest
GET /api/predictions/:symbol
GET /api/sentiment/:symbol
GET /api/news/:symbol?limit=20
```

## WebSocket Events

Connect with Socket.io, then emit `subscribe` with a symbol:

```js
socket.emit("subscribe", "AAPL");
socket.on("price_update", (tick) => { /* real-time price */ });
socket.on("prediction_update", (pred) => { /* new algorithm prediction */ });
socket.on("consensus_update", (consensus) => { /* new consensus with risk */ });
```

## Hermes Skill

To use NEXUS from within Hermes Agent:

```bash
# Symlink the skill
ln -s $(pwd)/optional-skills/nexus ../optional-skills/nexus
```

Then Hermes can query NEXUS via the skill's CLI:
```
python nexus/optional-skills/nexus/scripts/nexus_client.py predict AAPL
```

## Development

```bash
make logs          # all service logs
make logs-algo     # algorithm engine + beat scheduler
make db-check      # verify TimescaleDB hypertables
make redis-check   # list active Redis streams
make health        # check gateway health endpoint
make down          # stop all services
make clean         # stop + remove volumes (destructive)
```

## Phase Roadmap

- ✅ Phase 1: Foundation (Docker, TimescaleDB, Redis, price ingestor, API)
- ✅ Phase 2: News Pipeline (NewsAPI, RSS, MongoDB, FinBERT Celery workers)
- ✅ Phase 3: SENTINEL algorithm (EMA/RSI/MACD/Bollinger)
- ✅ Phase 4: ORACLE + PHANTOM algorithms
- ✅ Phase 5: Recursive Engine (cross-validator, regime detection, consensus)
- ✅ Phase 6: Risk Engine (Monte Carlo VaR, Kelly sizing, scenarios)
- ⬜ Phase 7: Production (Kubernetes, Prometheus/Grafana, load testing)
- ⬜ Phase 8: Enhancement (options flow, backtesting, mobile)
