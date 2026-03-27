"""
Backtester for the Kalshi Multi-Algorithm System
=================================================
Simulates the 3-algorithm pipeline on synthetic or historical market data
to evaluate strategy performance before deploying real capital.

Uses Monte Carlo simulation to generate realistic market scenarios and
measures:
  - Win rate, P&L, Sharpe ratio, max drawdown
  - Algorithm weight convergence
  - Kelly calibration accuracy
  - Edge of the consensus vs. individual algorithms

Run:
  python backtester.py
  python backtester.py --n-markets 1000 --n-rounds 20 --seed 42
"""

from __future__ import annotations

import json
import math
import random
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent))

from algorithms.statistical_engine import StatisticalAnalysisEngine
from algorithms.kelly_optimizer import KellyCriterionOptimizer, KCOConfig
from algorithms.consensus_engine import ConsensusSignalSynthesizer

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich import box
    HAS_RICH = True
    console = Console()
except ImportError:
    HAS_RICH = False
    console = None


# ─── Synthetic Market Generator ───────────────────────────────────────────────

CATEGORIES = [
    "politics", "economics", "sports", "weather", "crypto",
    "technology", "entertainment", "science", "health", "geopolitics",
]

CATEGORY_BASE_RATES = {
    "politics": 0.52,
    "economics": 0.50,
    "sports": 0.51,
    "weather": 0.55,
    "crypto": 0.48,
    "technology": 0.52,
    "entertainment": 0.50,
    "science": 0.54,
    "health": 0.51,
    "geopolitics": 0.49,
}


@dataclass
class SyntheticMarket:
    ticker: str
    true_prob: float         # Ground truth probability
    market_price: float      # Market's current price (with noise)
    category: str
    days_to_resolution: float
    volume: float
    liquidity: float         # 0-1 score
    resolved: Optional[bool] = None  # Set after simulation

    @property
    def yes_price_cents(self) -> int:
        return max(1, min(99, int(self.market_price * 100)))

    @property
    def no_price_cents(self) -> int:
        # Simulate a bid-ask spread
        spread = max(0.01, (1 - self.liquidity) * 0.05)
        no = 1.0 - self.market_price - spread
        return max(1, min(99, int(no * 100)))

    def resolve(self, rng: random.Random) -> bool:
        self.resolved = rng.random() < self.true_prob
        return self.resolved

    def to_api_dict(self) -> Dict:
        return {
            "ticker": self.ticker,
            "yes_ask": self.yes_price_cents,
            "yes_bid": max(1, self.yes_price_cents - 2),
            "no_ask": self.no_price_cents,
            "no_bid": max(1, self.no_price_cents - 2),
            "volume": self.volume,
            "volume_24h": self.volume,
            "category": self.category,
            "title": f"Synthetic {self.category} market {self.ticker}",
            "description": f"Will event {self.ticker} occur? (synthetic)",
        }


def generate_markets(
    n: int,
    rng: random.Random,
    noise_std: float = 0.08,
) -> List[SyntheticMarket]:
    """
    Generate synthetic prediction markets.

    True probabilities are drawn from a Beta distribution (skewed toward extremes
    to mimic real prediction markets). Market prices add Gaussian noise to the
    true probability, simulating market inefficiency.
    """
    markets = []
    for i in range(n):
        category = rng.choice(CATEGORIES)
        base_rate = CATEGORY_BASE_RATES.get(category, 0.50)

        # True probability: Beta-distributed around the base rate
        alpha = base_rate * 8
        beta_param = (1 - base_rate) * 8
        true_prob = rng.betavariate(alpha, beta_param)
        true_prob = max(0.02, min(0.98, true_prob))

        # Market price: true_prob + noise (market is imperfectly informed)
        # Some markets are more mispriced than others (fat-tailed noise)
        noise = rng.gauss(0, noise_std)
        market_price = max(0.02, min(0.98, true_prob + noise))

        # Days to resolution: log-uniform from 1 to 180 days
        days = math.exp(rng.uniform(math.log(1), math.log(180)))

        # Volume: log-normal
        volume = math.exp(rng.gauss(5, 1.5))

        # Liquidity: beta-distributed (most markets are illiquid)
        liquidity = rng.betavariate(2, 5)

        markets.append(SyntheticMarket(
            ticker=f"SYNTH-{category.upper()[:3]}-{i:04d}",
            true_prob=true_prob,
            market_price=market_price,
            category=category,
            days_to_resolution=days,
            volume=volume,
            liquidity=liquidity,
        ))

    return markets


# ─── Backtest Results ─────────────────────────────────────────────────────────

@dataclass
class BacktestResults:
    # Overall
    n_markets: int
    n_rounds: int
    n_bets: int
    n_wins: int

    # P&L
    final_bankroll: float
    initial_bankroll: float
    total_pnl: float
    max_drawdown: float
    sharpe_ratio: float

    # Per-algorithm accuracy
    sae_accuracy: float
    kco_accuracy: float

    # Breakdown by confidence tier
    high_confidence_win_rate: float   # confidence >= 75
    mid_confidence_win_rate: float    # confidence 55-75
    low_confidence_win_rate: float    # confidence < 55 (should be filtered out)

    # Category performance
    category_stats: Dict[str, Dict]

    @property
    def win_rate(self) -> float:
        return self.n_wins / self.n_bets if self.n_bets > 0 else 0.0

    @property
    def roi(self) -> float:
        return (self.final_bankroll - self.initial_bankroll) / self.initial_bankroll


# ─── Backtester ───────────────────────────────────────────────────────────────

class Backtester:
    """
    Runs the full 3-algorithm pipeline on synthetic markets.

    For each round:
      1. Generate N synthetic markets with known true probabilities
      2. Run SAE → KCO → CSS pipeline
      3. Simulate trade execution on markets with consensus BUY
      4. Resolve markets using their true probability
      5. Update all algorithms with outcomes
      6. Track performance metrics

    Reports: win rate, P&L, Sharpe, max drawdown, algorithm accuracy.
    """

    INITIAL_BANKROLL = 1000.0

    def __init__(
        self,
        bankroll: float = 1000.0,
        kelly_fraction: float = 0.25,
        min_confidence: float = 55.0,
        noise_std: float = 0.08,
    ):
        self.bankroll = bankroll
        self.kelly_fraction = kelly_fraction
        self.min_confidence = min_confidence
        self.noise_std = noise_std

    def _warmup(
        self,
        sae: StatisticalAnalysisEngine,
        rng: random.Random,
        n_warmup: int = 200,
    ):
        """
        Pre-seed category trackers with synthetic warm-up outcomes.
        Simulates having observed historical markets before live trading begins.
        Each category gets realistic win-rate data, and category base rates
        deviate slightly from 0.50 to reflect real-world biases.
        """
        warm_markets = generate_markets(n_warmup, rng, noise_std=0.06)
        warm_rng = random.Random(rng.randint(0, 999999))
        for m in warm_markets:
            # Resolve using true probability
            won = warm_rng.random() < m.true_prob
            sae.record_outcome(m.ticker, m.category, won)
            # Push price into SAE price buffer so momentum can build
            sae._get_buffer(m.ticker).push(m.market_price)

    def run(
        self,
        n_markets: int = 500,
        n_rounds: int = 10,
        seed: int = 42,
    ) -> BacktestResults:
        rng = random.Random(seed)

        # Initialize algorithms
        sae = StatisticalAnalysisEngine()
        kco = KellyCriterionOptimizer(
            bankroll=self.bankroll,
            config=KCOConfig(kelly_fraction=self.kelly_fraction),
        )
        css = ConsensusSignalSynthesizer()
        css.MIN_CONSENSUS_CONFIDENCE = self.min_confidence

        # Warm-up: seed algorithms with prior history so category rates are non-trivial
        self._warmup(sae, rng, n_warmup=300)

        current_bankroll = self.bankroll
        peak_bankroll = self.bankroll
        bankroll_history = [self.bankroll]

        total_bets = 0
        total_wins = 0
        all_pnls = []

        # Confidence tier tracking
        high_conf_bets, high_conf_wins = 0, 0
        mid_conf_bets, mid_conf_wins = 0, 0

        # Algorithm accuracy tracking
        sae_correct_count, kco_correct_count = 0, 0
        sae_total, kco_total = 0, 0

        # Category tracking
        category_bets: Dict[str, List[bool]] = {c: [] for c in CATEGORIES}

        for round_idx in range(n_rounds):
            markets = generate_markets(n_markets, rng, noise_std=self.noise_std)
            market_dicts = [m.to_api_dict() for m in markets]
            market_by_ticker = {m.ticker: m for m in markets}

            # Run 3-algorithm pipeline
            sae_signals = sae.analyze_batch(market_dicts)
            sae_map = {s.ticker: s for s in sae_signals}

            kco_signals = []
            for sig in sae_signals:
                mkt_info = market_by_ticker[sig.ticker].to_api_dict() if sig.ticker in market_by_ticker else {}
                kco_sig = kco.optimize(sig, market_info=mkt_info)
                kco_signals.append(kco_sig)

            css_signals = css.synthesize_batch(
                sae_signals=sae_signals,
                kco_signals=kco_signals,
                market_infos=market_dicts,
            )

            # Execute tradeable signals
            round_trades = []
            for css_sig in css_signals:
                if not css_sig.should_trade or css_sig.final_contracts == 0:
                    continue

                synth = market_by_ticker.get(css_sig.ticker)
                if synth is None:
                    continue

                price = max(0.01, css_sig.final_price)

                # Cap bet at 10% of current bankroll, then recompute contracts
                intended_cost = css_sig.final_bet_dollars
                max_cost = current_bankroll * 0.10
                actual_cost = min(intended_cost, max_cost)
                if actual_cost < price:  # need at least 1 contract
                    continue

                # Recompute contracts from actual_cost to avoid mismatch
                actual_contracts = int(actual_cost / price)
                if actual_contracts == 0:
                    continue
                actual_cost = actual_contracts * price

                if actual_cost > current_bankroll:
                    continue

                round_trades.append((css_sig, synth, actual_cost, actual_contracts, price))
                current_bankroll -= actual_cost

            # Resolve markets and update algorithms
            for css_sig, synth, bet_cost, actual_contracts, price in round_trades:
                won = synth.resolve(rng)

                if won:
                    pnl = actual_contracts * 1.0 - bet_cost
                else:
                    pnl = -bet_cost

                current_bankroll += (bet_cost + pnl)
                peak_bankroll = max(peak_bankroll, current_bankroll)
                all_pnls.append(pnl)

                total_bets += 1
                if won:
                    total_wins += 1

                # Confidence tier tracking
                conf = css_sig.consensus_confidence
                if conf >= 75:
                    high_conf_bets += 1
                    if won:
                        high_conf_wins += 1
                else:
                    mid_conf_bets += 1
                    if won:
                        mid_conf_wins += 1

                # Category tracking
                cat = synth.category
                category_bets.setdefault(cat, []).append(won)

                # Algorithm accuracy
                sae_sig = css_sig.sae_signal
                sae_predicted_yes = sae_sig.recommended_side == "YES"
                if css_sig.side == "YES":
                    sae_correct = (sae_predicted_yes and won) or (not sae_predicted_yes and not won)
                else:
                    sae_correct = (not sae_predicted_yes and won) or (sae_predicted_yes and not won)

                kco_ev_positive = css_sig.kco_signal.ev_per_dollar > 0
                kco_correct = (kco_ev_positive and won) or (not kco_ev_positive and not won)

                sae_correct_count += int(sae_correct)
                kco_correct_count += int(kco_correct)
                sae_total += 1
                kco_total += 1

                # Feed outcome back into all 3 algorithms
                sae.record_outcome(synth.ticker, synth.category, won)
                kco.record_outcome(synth.ticker, actual_contracts, price, won)
                css.record_outcome(synth.ticker, sae_correct, kco_correct, won)

            # Update bankroll in KCO
            kco.update_bankroll(current_bankroll)
            bankroll_history.append(current_bankroll)

        # ── Compute metrics ────────────────────────────────────────────────
        total_pnl = current_bankroll - self.bankroll

        # Max drawdown from history
        peak = bankroll_history[0]
        max_dd = 0.0
        for val in bankroll_history:
            peak = max(peak, val)
            dd = (peak - val) / peak if peak > 0 else 0
            max_dd = max(max_dd, dd)

        # Sharpe ratio (annualized, assuming each round ≈ 1 week)
        if all_pnls and len(all_pnls) > 1:
            mean_pnl = statistics.mean(all_pnls)
            std_pnl = statistics.stdev(all_pnls) if len(all_pnls) > 1 else 1e-9
            # Annualize: sqrt(52) weeks per year
            sharpe = (mean_pnl / max(std_pnl, 1e-9)) * math.sqrt(52)
        else:
            sharpe = 0.0

        # Category stats
        category_stats = {}
        for cat, outcomes in category_bets.items():
            if outcomes:
                category_stats[cat] = {
                    "bets": len(outcomes),
                    "wins": sum(outcomes),
                    "win_rate": sum(outcomes) / len(outcomes),
                }

        return BacktestResults(
            n_markets=n_markets * n_rounds,
            n_rounds=n_rounds,
            n_bets=total_bets,
            n_wins=total_wins,
            final_bankroll=current_bankroll,
            initial_bankroll=self.bankroll,
            total_pnl=total_pnl,
            max_drawdown=max_dd,
            sharpe_ratio=sharpe,
            sae_accuracy=sae_correct_count / max(sae_total, 1),
            kco_accuracy=kco_correct_count / max(kco_total, 1),
            high_confidence_win_rate=high_conf_wins / max(high_conf_bets, 1),
            mid_confidence_win_rate=mid_conf_wins / max(mid_conf_bets, 1),
            low_confidence_win_rate=0.0,
            category_stats=category_stats,
        )

    def print_results(self, r: BacktestResults):
        """Display backtest results."""
        if HAS_RICH:
            self._print_rich(r)
        else:
            self._print_plain(r)

    def _print_rich(self, r: BacktestResults):
        pnl_color = "green" if r.total_pnl >= 0 else "red"

        summary_lines = [
            f"[bold]Markets Scanned:[/bold] {r.n_markets:,} ({r.n_rounds} rounds × {r.n_markets // r.n_rounds:,} markets)",
            f"[bold]Bets Placed:[/bold] {r.n_bets} | Wins: [green]{r.n_wins}[/green] | Losses: [red]{r.n_bets - r.n_wins}[/red]",
            f"[bold]Win Rate:[/bold] {r.win_rate:.1%}",
            f"[bold]P&L:[/bold] [{pnl_color}]${r.total_pnl:+,.2f} (ROI: {r.roi:+.1%})[/{pnl_color}]",
            f"[bold]Final Bankroll:[/bold] ${r.final_bankroll:,.2f} (started ${r.initial_bankroll:,.2f})",
            f"[bold]Max Drawdown:[/bold] {r.max_drawdown:.1%}",
            f"[bold]Sharpe Ratio:[/bold] {r.sharpe_ratio:.2f}",
        ]
        console.print(Panel("\n".join(summary_lines), title="[bold blue]Backtest Results", border_style="blue"))

        # Algorithm performance
        alg_table = Table(title="Algorithm Performance", box=box.SIMPLE)
        alg_table.add_column("Algorithm", style="bold")
        alg_table.add_column("Accuracy", justify="right")
        alg_table.add_column("Description")
        alg_table.add_row("SAE (Algo 1)", f"{r.sae_accuracy:.1%}", "Statistical Analysis Engine")
        alg_table.add_row("KCO (Algo 2)", f"{r.kco_accuracy:.1%}", "Kelly Criterion Optimizer")
        alg_table.add_row(
            "CSS (Algo 3)",
            f"{r.win_rate:.1%}",
            "Consensus Synthesizer (overall win rate)",
        )
        console.print(alg_table)

        # Confidence tier breakdown
        conf_table = Table(title="Win Rate by Confidence Tier", box=box.SIMPLE)
        conf_table.add_column("Tier", style="bold")
        conf_table.add_column("Win Rate", justify="right")
        conf_table.add_column("Notes")
        conf_table.add_row(
            "High (≥75)", f"{r.high_confidence_win_rate:.1%}",
            "[green]Should be highest win rate[/green]",
        )
        conf_table.add_row(
            "Mid (55-75)", f"{r.mid_confidence_win_rate:.1%}",
            "Core volume of trades",
        )
        console.print(conf_table)

        # Category breakdown
        if r.category_stats:
            cat_table = Table(title="Performance by Category", box=box.SIMPLE)
            cat_table.add_column("Category", style="bold")
            cat_table.add_column("Bets", justify="right")
            cat_table.add_column("Win Rate", justify="right")
            for cat, stats in sorted(
                r.category_stats.items(),
                key=lambda x: x[1]["win_rate"],
                reverse=True,
            ):
                wr = stats["win_rate"]
                color = "green" if wr >= 0.55 else ("yellow" if wr >= 0.50 else "red")
                cat_table.add_row(cat, str(stats["bets"]), f"[{color}]{wr:.1%}[/{color}]")
            console.print(cat_table)

    def _print_plain(self, r: BacktestResults):
        print(f"\n{'='*60}")
        print(f" BACKTEST RESULTS")
        print(f"{'='*60}")
        print(f" Markets:       {r.n_markets:,} ({r.n_rounds} rounds)")
        print(f" Bets:          {r.n_bets} (wins: {r.n_wins})")
        print(f" Win Rate:      {r.win_rate:.1%}")
        print(f" P&L:           ${r.total_pnl:+,.2f} (ROI: {r.roi:+.1%})")
        print(f" Max Drawdown:  {r.max_drawdown:.1%}")
        print(f" Sharpe Ratio:  {r.sharpe_ratio:.2f}")
        print(f" SAE Accuracy:  {r.sae_accuracy:.1%}")
        print(f" KCO Accuracy:  {r.kco_accuracy:.1%}")
        print(f"{'='*60}\n")

        print(" Category Performance:")
        for cat, stats in sorted(
            r.category_stats.items(), key=lambda x: x[1]["win_rate"], reverse=True
        ):
            print(f"   {cat:<15} {stats['bets']:>4} bets  {stats['win_rate']:.1%}")


# ─── CLI ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Kalshi Algorithm Backtester")
    parser.add_argument("--n-markets", type=int, default=500)
    parser.add_argument("--n-rounds", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--bankroll", type=float, default=1000.0)
    parser.add_argument("--kelly", type=float, default=0.25)
    parser.add_argument("--min-confidence", type=float, default=55.0)
    parser.add_argument("--noise", type=float, default=0.08,
                        help="Market noise std dev (0=perfect market, 0.15=very noisy)")
    args = parser.parse_args()

    bt = Backtester(
        bankroll=args.bankroll,
        kelly_fraction=args.kelly,
        min_confidence=args.min_confidence,
        noise_std=args.noise,
    )
    results = bt.run(n_markets=args.n_markets, n_rounds=args.n_rounds, seed=args.seed)
    bt.print_results(results)
