"""
Multi-Algorithm Orchestrator
============================
Runs all three autonomous algorithms in a coordinated pipeline:

  Algorithm 1 (SAE) → Algorithm 2 (KCO) → Algorithm 3 (CSS)
             ↑___________________________|
                    Feedback loop

The orchestrator:
  1. Fetches live market data from Kalshi
  2. Feeds it through SAE → KCO → CSS pipeline
  3. Displays a ranked opportunity table (Rich terminal UI)
  4. Optionally executes trades in paper or live mode
  5. Monitors resolved markets and feeds outcomes back into all 3 algorithms
  6. Persists state between runs for continuous learning

Modes:
  - scan:    Analyze markets and display opportunities (no trading)
  - paper:   Simulate trades with virtual bankroll
  - live:    Execute real trades (requires API credentials)
  - watch:   Continuous monitoring loop
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .statistical_engine import StatisticalAnalysisEngine, SAESignal
from .kelly_optimizer import KellyCriterionOptimizer, KCOConfig, KCOSignal
from .consensus_engine import ConsensusSignalSynthesizer, CSSSignal


# ─── State File ───────────────────────────────────────────────────────────────

DEFAULT_STATE_PATH = Path.home() / ".kalshi_algo" / "state.json"


# ─── Trade Log Entry ─────────────────────────────────────────────────────────

class TradeLog:
    """Simple in-memory + disk trade log."""

    def __init__(self, log_path: Optional[Path] = None):
        self.log_path = log_path or (Path.home() / ".kalshi_algo" / "trades.jsonl")
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self._entries: List[Dict] = []

    def record(self, entry: Dict):
        entry["logged_at"] = datetime.now(timezone.utc).isoformat()
        self._entries.append(entry)
        with open(self.log_path, "a") as f:
            f.write(json.dumps(entry) + "\n")

    def load(self) -> List[Dict]:
        if not self.log_path.exists():
            return []
        entries = []
        with open(self.log_path) as f:
            for line in f:
                try:
                    entries.append(json.loads(line.strip()))
                except json.JSONDecodeError:
                    continue
        self._entries = entries
        return entries

    def get_open_trades(self) -> List[Dict]:
        return [e for e in self._entries if e.get("status") == "open"]

    def get_stats(self) -> Dict:
        closed = [e for e in self._entries if e.get("status") == "closed"]
        if not closed:
            return {"total": 0, "wins": 0, "losses": 0, "pnl": 0.0, "win_rate": 0.0}
        wins = [e for e in closed if e.get("won", False)]
        total_pnl = sum(e.get("pnl", 0) for e in closed)
        return {
            "total": len(closed),
            "wins": len(wins),
            "losses": len(closed) - len(wins),
            "pnl": total_pnl,
            "win_rate": len(wins) / len(closed) if closed else 0.0,
        }


# ─── Orchestrator ─────────────────────────────────────────────────────────────

class KalshiOrchestrator:
    """
    Main orchestrator that runs all 3 algorithms and manages the full
    trading lifecycle: data → analysis → decision → execution → learning.
    """

    # Categories to map from Kalshi event types
    CATEGORY_MAP = {
        "politics": "politics",
        "economics": "economics",
        "finance": "finance",
        "sports": "sports",
        "weather": "weather",
        "crypto": "crypto",
        "tech": "technology",
        "entertainment": "entertainment",
        "science": "science",
        "health": "health",
        "global": "geopolitics",
    }

    def __init__(
        self,
        bankroll: float = 1000.0,
        kelly_fraction: float = 0.25,
        demo_mode: bool = True,
        state_path: Optional[Path] = None,
        min_confidence: float = 55.0,
        max_bets_per_scan: int = 5,
    ):
        from ..kalshi_client import KalshiClient

        self.demo_mode = demo_mode
        self.min_confidence = min_confidence
        self.max_bets_per_scan = max_bets_per_scan
        self.state_path = state_path or DEFAULT_STATE_PATH
        self.state_path.parent.mkdir(parents=True, exist_ok=True)

        # Initialize all 3 algorithms
        self.sae = StatisticalAnalysisEngine()
        self.kco = KellyCriterionOptimizer(
            bankroll=bankroll,
            config=KCOConfig(kelly_fraction=kelly_fraction),
        )
        self.css = ConsensusSignalSynthesizer()
        self.css.MIN_CONSENSUS_CONFIDENCE = min_confidence

        # API client
        self.client = KalshiClient(demo=demo_mode)

        # Trade log
        self.trade_log = TradeLog()
        self.trade_log.load()

        # Load persisted state
        self._load_state()

    # ─── State Persistence ────────────────────────────────────────────────────

    def _save_state(self):
        state = {
            "saved_at": datetime.now(timezone.utc).isoformat(),
            "sae": self.sae.get_state(),
            "kco": self.kco.get_state(),
            "css": self.css.get_state(),
        }
        with open(self.state_path, "w") as f:
            json.dump(state, f, indent=2)

    def _load_state(self):
        if not self.state_path.exists():
            return
        try:
            with open(self.state_path) as f:
                state = json.load(f)
            self.sae.load_state(state.get("sae", {}))
            self.kco.load_state(state.get("kco", {}))
            self.css.load_state(state.get("css", {}))
        except (json.JSONDecodeError, KeyError):
            pass  # Start fresh if state is corrupted

    # ─── Market Data Pipeline ─────────────────────────────────────────────────

    def _fetch_markets(self, limit: int = 200, category: Optional[str] = None) -> List[Dict]:
        """Fetch open markets from Kalshi API."""
        all_markets = []
        cursor = None
        page_size = min(limit, 100)

        while len(all_markets) < limit:
            kwargs: Dict = {"limit": page_size, "status": "open"}
            if cursor:
                kwargs["cursor"] = cursor

            data = self.client.get_markets(**kwargs)
            markets = data.get("markets", [])
            all_markets.extend(markets)
            cursor = data.get("cursor")
            if not cursor or not markets:
                break

        return all_markets[:limit]

    def _enrich_with_history(self, market: Dict) -> Dict:
        """Fetch recent trade history and inject into market dict."""
        ticker = market.get("ticker", "")
        if not ticker:
            return market
        try:
            trades_data = self.client.get_market_trades(ticker, limit=50)
            trades = trades_data.get("trades", [])
            market["_recent_trades"] = trades
            self.sae.ingest_trades(ticker, trades)
        except Exception:
            pass
        return market

    def _extract_close_time(self, market: Dict) -> Optional[datetime]:
        """Parse market close/expiration time."""
        for key in ("close_time", "expiration_time", "expected_expiration_ts"):
            val = market.get(key)
            if val is None:
                continue
            if isinstance(val, (int, float)):
                return datetime.fromtimestamp(val, tz=timezone.utc)
            if isinstance(val, str):
                try:
                    return datetime.fromisoformat(val.replace("Z", "+00:00"))
                except ValueError:
                    pass
        return None

    def _normalize_category(self, market: Dict) -> str:
        """Map Kalshi category fields to our internal categories."""
        raw = (
            market.get("category") or
            market.get("event_category") or
            market.get("series_ticker", "")
        ).lower()
        for key, cat in self.CATEGORY_MAP.items():
            if key in raw:
                return cat
        return "general"

    # ─── Full Analysis Pipeline ───────────────────────────────────────────────

    def analyze_markets(
        self,
        markets: List[Dict],
        fetch_history: bool = False,
    ) -> List[CSSSignal]:
        """
        Run all 3 algorithms on a list of markets.
        Returns final CSS signals sorted by composite score.
        """
        if fetch_history:
            enriched = []
            for m in markets:
                enriched.append(self._enrich_with_history(m))
            markets = enriched

        # ── Algorithm 1: Statistical Analysis Engine ──────────────────
        for m in markets:
            category = self._normalize_category(m)
            m["_category"] = category

        sae_signals = self.sae.analyze_batch(markets)

        # Rebuild market map for downstream
        market_map = {m.get("ticker", ""): m for m in markets}

        # ── Algorithm 2: Kelly Criterion Optimizer ────────────────────
        # Create a fresh KCO snapshot for this scan (doesn't commit positions)
        kco_signals_list = []
        for sig in sae_signals:
            mkt = market_map.get(sig.ticker, {})
            kco_sig = self.kco.optimize(sig, market_info=mkt)
            kco_signals_list.append(kco_sig)

        kco_map = {s.ticker: s for s in kco_signals_list}

        # ── Algorithm 3: Consensus Signal Synthesizer ─────────────────
        close_times = [self._extract_close_time(market_map.get(sig.ticker, {})) for sig in sae_signals]

        css_signals = self.css.synthesize_batch(
            sae_signals=sae_signals,
            kco_signals=kco_signals_list,
            market_infos=markets,
            close_times=close_times,
        )

        return css_signals

    # ─── Execution ────────────────────────────────────────────────────────────

    def execute_trade(self, signal: CSSSignal, dry_run: bool = False) -> Optional[Dict]:
        """
        Execute a trade based on a CSS signal.
        Returns the order result dict or None if not executed.
        """
        if not signal.should_trade or signal.final_contracts == 0:
            return None

        ticker = signal.ticker
        side = signal.side.lower()  # "yes" or "no"
        contracts = signal.final_contracts
        price_cents = int(signal.final_price * 100)

        if dry_run:
            result = {
                "status": "dry_run",
                "ticker": ticker,
                "side": side,
                "contracts": contracts,
                "price_cents": price_cents,
                "estimated_cost": signal.final_bet_dollars,
            }
        else:
            result = self.client.place_order(
                ticker=ticker,
                action="buy",
                side=side,
                count=contracts,
                order_type="limit",
                yes_price=price_cents if side == "yes" else None,
                no_price=price_cents if side == "no" else None,
            )

        # Log the trade
        self.trade_log.record({
            "ticker": ticker,
            "side": side,
            "contracts": contracts,
            "price_cents": price_cents,
            "cost": signal.final_bet_dollars,
            "confidence": signal.consensus_confidence,
            "status": "open",
            "order": result,
            "signal_summary": {
                "sae_edge": signal.sae_signal.edge,
                "kco_ev": signal.kco_signal.ev_per_dollar,
                "consensus": signal.consensus_confidence,
                "regime": signal.market_regime,
            },
        })

        # Register capital deployment with KCO
        if not dry_run:
            self.kco.portfolio.add_position(ticker, signal.final_bet_dollars)

        return result

    # ─── Outcome Monitoring ───────────────────────────────────────────────────

    def check_resolutions(self, paper_mode: bool = True):
        """
        Check for resolved markets among open positions.
        Updates all 3 algorithms with outcomes.
        """
        open_trades = self.trade_log.get_open_trades()
        if not open_trades:
            return

        for trade in open_trades:
            ticker = trade.get("ticker", "")
            try:
                mkt_data = self.client.get_market(ticker)
                mkt = mkt_data.get("market", mkt_data)
                status = mkt.get("status", "open")
                result = mkt.get("result", "")

                if status not in ("settled", "closed", "finalized"):
                    continue

                # Determine win/loss
                bet_side = trade.get("side", "yes")
                won = (
                    (bet_side == "yes" and result == "yes") or
                    (bet_side == "no" and result == "no")
                )

                cost = trade.get("cost", 0)
                contracts = trade.get("contracts", 0)
                pnl = (contracts - cost) if won else -cost

                # Update all algorithms
                category = mkt.get("_category", "general")
                self.sae.record_outcome(ticker, category, won)
                self.kco.record_outcome(
                    ticker=ticker,
                    contracts=contracts,
                    price=trade.get("price_cents", 50) / 100.0,
                    won=won,
                )

                # Estimate which algorithms were "correct"
                signal_summary = trade.get("signal_summary", {})
                sae_was_bullish = signal_summary.get("sae_edge", 0) > 0
                sae_correct = (sae_was_bullish and won) or (not sae_was_bullish and not won)
                kco_ev_positive = signal_summary.get("kco_ev", 0) > 0
                kco_correct = (kco_ev_positive and won) or (not kco_ev_positive and not won)

                self.css.record_outcome(ticker, sae_correct, kco_correct, won)

                # Mark as closed in log
                trade["status"] = "closed"
                trade["won"] = won
                trade["pnl"] = pnl
                trade["resolution"] = result
                self.trade_log.record({**trade, "type": "resolution"})

            except Exception:
                continue

        self._save_state()

    # ─── Scan Mode (Main Entry Point) ─────────────────────────────────────────

    def scan(
        self,
        limit: int = 200,
        fetch_history: bool = False,
        execute: bool = False,
        dry_run: bool = True,
        top_n: int = 10,
    ) -> List[CSSSignal]:
        """
        Full scan cycle:
          1. Fetch markets
          2. Run 3-algorithm pipeline
          3. Display results
          4. Optionally execute top trades

        Returns the list of CSS signals for programmatic use.
        """
        # Check for resolved positions first
        self.check_resolutions()

        # Fetch and analyze markets
        markets = self._fetch_markets(limit=limit)
        signals = self.analyze_markets(markets, fetch_history=fetch_history)

        # Execute top opportunities if requested
        if execute:
            tradeable = [s for s in signals if s.should_trade][:self.max_bets_per_scan]
            for signal in tradeable:
                self.execute_trade(signal, dry_run=dry_run)

        self._save_state()
        return signals[:top_n]

    def get_portfolio_summary(self) -> Dict:
        """Get current portfolio and performance summary."""
        portfolio = self.kco.portfolio
        css_perf = self.css.get_performance_summary()
        trade_stats = self.trade_log.get_stats()

        return {
            "bankroll": portfolio.current_bankroll,
            "initial_bankroll": portfolio.initial_bankroll,
            "peak_bankroll": portfolio.peak_bankroll,
            "deployed_dollars": portfolio.deployed_dollars,
            "deployed_fraction": portfolio.deployed_fraction,
            "drawdown": portfolio.drawdown_fraction,
            "open_positions": len(portfolio.get_positions()),
            "algorithm_weights": {
                "sae": css_perf["sae_weight"],
                "kco": css_perf["kco_weight"],
            },
            "algorithm_accuracy": {
                "sae": css_perf["sae_accuracy"],
                "kco": css_perf["kco_accuracy"],
            },
            "trade_stats": trade_stats,
            "win_rate": css_perf["win_rate"],
            "win_streak": css_perf["win_streak"],
            "loss_streak": css_perf["loss_streak"],
        }

    def close(self):
        """Clean shutdown: save state and close API client."""
        self._save_state()
        self.client.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
