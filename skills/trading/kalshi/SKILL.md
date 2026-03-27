# Kalshi Multi-Algorithm Betting System

**Location:** `skills/trading/kalshi/`

A statistically rigorous, weight-based prediction market trading system for [Kalshi](https://kalshi.com) featuring three autonomous algorithms that work in concert to maximize win margin.

---

## Architecture: 3 Autonomous Algorithms

```
 Market Data (Kalshi API)
         │
         ▼
┌─────────────────────────────┐
│  Algorithm 1: SAE           │  Statistical Analysis Engine
│  • Bayesian inference       │  → prob estimate, edge, z-score,
│  • Edge detection (z-score) │    trend, volatility, efficiency
│  • Moving avg / momentum    │
│  • Category win rate EMA    │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Algorithm 2: KCO           │  Kelly Criterion Optimizer
│  • Fractional Kelly sizing  │  → optimal bet size, EV/dollar,
│  • EV filtering             │    risk tier, portfolio limits
│  • Portfolio correlation    │
│  • Drawdown circuit breaker │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Algorithm 3: CSS           │  Consensus Signal Synthesizer
│  • Dynamic algo weighting   │  → BUY/HOLD, confidence score,
│  • Sentiment analysis       │    final bet size, reasoning
│  • Regime detection         │
│  • Contrarian indicators    │
│  • Time-decay weighting     │
└────────────┬────────────────┘
             │
             ▼
     Final Trade Signal
   (BUY / HOLD + bet size)
             │
      ┌──────┴──────┐
      │             │
   Execute       Monitor
   (optional)  Resolutions
      │             │
      └──────┬──────┘
             │
      Feedback Loop →
      Updates all 3 algos
```

---

## Algorithm Details

### Algorithm 1: Statistical Analysis Engine (SAE)
`scripts/algorithms/statistical_engine.py`

**Purpose:** Transform raw market prices into statistically grounded probability estimates and edge scores.

**Key components:**
- **BayesianEstimator** — Beta-Binomial posterior that blends market price (strong prior) with category historical win rates and price momentum
- **EdgeDetector** — Computes signed edge (estimated_prob − market_price) and normalizes via rolling z-score. Markets with z-score > 1.5 are flagged as mispriced
- **PriceBuffer** — Rolling window of price observations with SMA, EMA, momentum crossover, and volatility calculation
- **CategoryTracker** — Exponential moving average of historical win rates per market category (politics, crypto, sports, etc.)

**Outputs:**
| Field | Description |
|-------|-------------|
| `bayesian_prob` | Posterior probability YES resolves true |
| `edge` | Signed edge in probability space |
| `edge_zscore` | How unusual this edge is vs. history |
| `trend_direction` | BULLISH / BEARISH / NEUTRAL |
| `momentum_score` | [-1, +1] short/long EMA crossover |
| `volatility` | Rolling std dev of price changes |
| `efficiency_score` | 0-100 market pricing quality |
| `signal_strength` | 0-100 composite score |
| `recommended_side` | YES / NO / SKIP |

---

### Algorithm 2: Kelly Criterion Optimizer (KCO)
`scripts/algorithms/kelly_optimizer.py`

**Purpose:** Convert statistical edges into optimal, risk-managed position sizes that maximize long-run growth while controlling drawdown.

**Kelly formula:**
```
b = (1 - price) / price      # net odds per dollar
f* = (b·p - q) / b           # raw Kelly fraction
f_adjusted = f* × kelly_fraction  # default 0.25× (quarter Kelly)
```

**Risk management stack:**
1. Kelly fraction multiplier (default 0.25× = quarter Kelly)
2. Risk tier adjustment (LOW/MEDIUM/HIGH → 100%/75%/50% of Kelly)
3. Single-bet cap (default 10% of bankroll)
4. Portfolio capacity cap (default 50% total deployed)
5. Correlation limit (≤60% correlation with existing bets)
6. Drawdown circuit breaker (halt at 20% drawdown)
7. EV filter (minimum +3% EV required)

**Outputs:**
| Field | Description |
|-------|-------------|
| `raw_kelly_fraction` | Full Kelly recommendation |
| `final_bet_fraction` | After all risk adjustments |
| `ev_per_dollar` | Expected profit per dollar |
| `risk_tier` | LOW / MEDIUM / HIGH |
| `recommended_bet_dollars` | Dollar amount |
| `recommended_contracts` | Number of contracts |
| `should_bet` | Boolean pass/fail |

---

### Algorithm 3: Consensus Signal Synthesizer (CSS)
`scripts/algorithms/consensus_engine.py`

**Purpose:** The "wisdom layer" — synthesizes Algorithms 1 & 2 through multiple independent signals. Only recommends trading when signals converge.

**Key components:**
- **AlgorithmPerformanceTracker** — EMA-weighted accuracy tracking for SAE and KCO. Better-performing algorithms earn higher voting weight (min 20%, max 80%)
- **SentimentAnalyzer** — Keyword-based sentiment scoring on market titles. Flags high-uncertainty events (elections, crises) that reduce confidence
- **RegimeDetector** — Hurst exponent approximation via variance ratio to classify market as TRENDING / MEAN_REVERTING / UNCERTAIN
- **ContrarianIndicator** — Flags markets priced >88¢ or <12¢ where our model significantly disagrees (fade the crowd)
- **Time Decay** — Discounts long-dated markets (>90 days: 0.55×) and boosts imminent resolutions (<24h: 1.10×)

**Consensus score formula:**
```
score = (w₁·SAE_strength + w₂·KCO_EV) × agreement × regime_mult
        × uncertainty_mult × time_mult × streak_mult
```

**Trade threshold:** `consensus_confidence ≥ 55` (configurable)

**Outputs:**
| Field | Description |
|-------|-------------|
| `consensus_confidence` | 0-100 final confidence |
| `action` | BUY / HOLD |
| `contrarian_flag` | Whether this is a contrarian bet |
| `market_regime` | TRENDING / MEAN_REVERTING / UNCERTAIN |
| `final_bet_dollars` | Confidence-adjusted bet size |
| `should_trade` | Final boolean decision |
| `reasoning` | Full reasoning chain |

---

## Quickstart

### 1. Install dependencies
```bash
pip install httpx rich cryptography
```

### 2. Set credentials
```bash
# Demo environment (paper trading)
export KALSHI_DEMO=true
export KALSHI_EMAIL=you@example.com
export KALSHI_PASSWORD=yourpassword

# OR production with API key
export KALSHI_API_KEY_ID=your-key-id
export KALSHI_PRIVATE_KEY=/path/to/private.pem
```

### 3. Run a market scan (read-only)
```bash
cd skills/trading/kalshi/scripts
python kalshi_main.py scan --limit 200 --top 15
```

### 4. Backtest on synthetic data
```bash
python backtester.py --n-markets 500 --n-rounds 10
```

### 5. Paper trade (simulated execution)
```bash
python kalshi_main.py scan --execute --dry-run --max-bets 3
```

### 6. Watch mode (continuous)
```bash
python kalshi_main.py watch --interval 300  # scan every 5 minutes
```

### 7. Live trading (REAL MONEY — use with caution)
```bash
python kalshi_main.py scan --execute --live --max-bets 2 --min-confidence 70
```

---

## CLI Reference

```
python kalshi_main.py [global opts] <command> [opts]

Global options:
  --bankroll FLOAT       Starting bankroll in dollars [1000.0]
  --kelly FLOAT          Kelly multiplier [0.25]
  --live                 Use live API (default: demo)
  --min-confidence FLOAT Minimum consensus score to trade [55.0]

Commands:
  scan        Analyze markets and display opportunities
    --limit N          Markets to fetch [200]
    --top N            Results to display [15]
    --execute          Execute trades
    --max-bets N       Max bets per scan [3]
    --history          Fetch trade history (slower, better analysis)

  portfolio   Show portfolio and algorithm performance

  watch       Continuous monitoring loop
    --interval SECS    Seconds between scans [300]

  backtest    Monte Carlo backtest on synthetic markets
    --n-markets N      Markets per round [500]
    --n-rounds N       Number of rounds [10]
    --seed N           Random seed [42]
    --noise FLOAT      Market noise std dev [0.08]
```

---

## State & Persistence

The system automatically persists algorithm state between runs:

```
~/.kalshi_algo/
├── state.json     # SAE, KCO, CSS algorithm state
└── trades.jsonl   # Trade log (JSON Lines format)
```

This means:
- Category win rates accumulate over time
- Algorithm weights adapt to actual performance
- Edge z-score normalization improves with more data
- Win/loss streaks are tracked continuously

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Quarter Kelly (0.25×) | Full Kelly has extreme variance; 0.25× captures ~80% of growth with far lower drawdown |
| 3-algorithm consensus | No single model dominates; CSS prevents overtrading and over-fitting |
| Dynamic algorithm weighting | The CSS automatically promotes the better-performing algorithm |
| Bayesian prior = market price | Market prices encode collective wisdom; we adjust from there rather than ignoring it |
| Category win rate EMA | Prediction markets have category-level biases (e.g., political markets may systematically underprice incumbents) |
| Correlation limit 60% | Prevents making multiple bets that move together (portfolio concentration risk) |
| 20% drawdown circuit breaker | Halts trading during losing streaks before they become catastrophic |
| Time decay multiplier | Long-dated bets tie up capital and face more uncertainty; short-dated bets near resolution deserve a premium |

---

## Files

```
skills/trading/kalshi/
├── SKILL.md                              # This file
├── scripts/
│   ├── kalshi_client.py                  # Kalshi REST API client
│   ├── kalshi_main.py                    # CLI entry point + Rich dashboard
│   ├── backtester.py                     # Monte Carlo backtester
│   └── algorithms/
│       ├── __init__.py
│       ├── statistical_engine.py         # Algorithm 1: SAE
│       ├── kelly_optimizer.py            # Algorithm 2: KCO
│       ├── consensus_engine.py           # Algorithm 3: CSS
│       └── orchestrator.py              # Pipeline coordinator
└── references/
    └── api-reference.md                  # Kalshi API endpoint reference
```

---

## Risk Disclaimer

Prediction market trading involves financial risk. This system is provided for educational and research purposes. Always:
1. Start with paper trading / demo mode
2. Use small position sizes while validating
3. Monitor drawdown closely
4. Never bet more than you can afford to lose
5. Understand that past backtest performance does not guarantee future results
