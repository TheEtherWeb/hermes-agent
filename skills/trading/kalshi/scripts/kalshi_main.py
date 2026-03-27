#!/usr/bin/env python3
"""
Kalshi Multi-Algorithm Betting System
======================================
CLI entry point with Rich terminal dashboard.

Commands:
  scan       - Analyze markets and display top opportunities
  portfolio  - Show portfolio status and algorithm performance
  watch      - Continuous monitoring loop
  backtest   - Run backtester on historical data
  paper      - Enable paper trading mode

Usage:
  python kalshi_main.py scan --limit 200 --top 10
  python kalshi_main.py scan --execute --dry-run
  python kalshi_main.py scan --execute --live  (REAL MONEY - requires API key)
  python kalshi_main.py portfolio
  python kalshi_main.py watch --interval 300
  python kalshi_main.py backtest
"""

import argparse
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import List

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.columns import Columns
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.text import Text
    from rich import box
    from rich.live import Live
    from rich.layout import Layout
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from algorithms.orchestrator import KalshiOrchestrator
from algorithms.consensus_engine import CSSSignal


console = Console() if HAS_RICH else None


# ─── Display Helpers ──────────────────────────────────────────────────────────

def _confidence_color(score: float) -> str:
    if score >= 75:
        return "bold green"
    elif score >= 55:
        return "yellow"
    else:
        return "red"


def _side_color(side: str) -> str:
    if side == "YES":
        return "cyan"
    elif side == "NO":
        return "magenta"
    return "dim"


def _regime_icon(regime: str) -> str:
    return {"TRENDING": "↗", "MEAN_REVERTING": "↔", "UNCERTAIN": "~"}.get(regime, "?")


def print_signal_table(signals: List[CSSSignal], title: str = "Top Opportunities"):
    """Display CSS signals in a Rich table."""
    if not HAS_RICH:
        _print_plain_table(signals, title)
        return

    table = Table(
        title=f"[bold]{title}[/bold]",
        box=box.ROUNDED,
        show_header=True,
        header_style="bold blue",
        expand=True,
    )

    table.add_column("Rank", style="dim", width=5, justify="right")
    table.add_column("Ticker", style="bold", width=28)
    table.add_column("Action", width=6, justify="center")
    table.add_column("Side", width=5, justify="center")
    table.add_column("Price", width=7, justify="right")
    table.add_column("Contracts", width=9, justify="right")
    table.add_column("Cost $", width=8, justify="right")
    table.add_column("Confidence", width=10, justify="right")
    table.add_column("EV/$ ", width=7, justify="right")
    table.add_column("Edge", width=7, justify="right")
    table.add_column("Regime", width=10, justify="center")
    table.add_column("Days", width=6, justify="right")
    table.add_column("Reason", width=30)

    for i, sig in enumerate(signals, 1):
        is_trade = sig.should_trade
        row_style = "" if is_trade else "dim"

        action_color = "bold green" if sig.action == "BUY" else ("bold red" if sig.action == "SELL" else "dim")
        action_txt = Text(sig.action, style=action_color)

        side_txt = Text(sig.side, style=_side_color(sig.side) if is_trade else "dim")

        conf_color = _confidence_color(sig.consensus_confidence)
        conf_txt = Text(f"{sig.consensus_confidence:.1f}", style=conf_color)

        ev = sig.kco_signal.ev_per_dollar
        ev_color = "green" if ev > 0.05 else ("yellow" if ev > 0 else "red")
        ev_txt = Text(f"{ev:+.3f}", style=ev_color)

        edge = sig.sae_signal.edge
        edge_color = "green" if edge > 0.03 else ("yellow" if edge > 0 else "red")
        edge_txt = Text(f"{edge:+.3f}", style=edge_color)

        regime_str = f"{_regime_icon(sig.market_regime)} {sig.market_regime[:5]}"
        days_str = (
            f"{sig.days_to_resolution:.0f}" if sig.days_to_resolution else "N/A"
        )

        # Top skip reason or trading reason
        if sig.skip_reasons:
            reason = sig.skip_reasons[0][:30]
        elif sig.reasoning:
            reason = sig.reasoning[-1][:30]
        else:
            reason = ""

        table.add_row(
            str(i),
            sig.ticker[:28],
            action_txt,
            side_txt,
            f"{sig.final_price:.2f}",
            str(sig.final_contracts),
            f"${sig.final_bet_dollars:.2f}",
            conf_txt,
            ev_txt,
            edge_txt,
            regime_str,
            days_str,
            reason,
            style=row_style,
        )

    console.print(table)


def _print_plain_table(signals: List[CSSSignal], title: str):
    """Fallback plain-text table if Rich is not available."""
    print(f"\n{'='*80}")
    print(f" {title}")
    print(f"{'='*80}")
    fmt = "{:>3} {:<28} {:<5} {:<4} {:>6} {:>5} {:>8} {:>10} {:>7}"
    print(fmt.format("#", "TICKER", "ACT", "SIDE", "PRICE", "CNT", "COST$", "CONF", "EV"))
    print("-" * 80)
    for i, sig in enumerate(signals, 1):
        print(fmt.format(
            i,
            sig.ticker[:28],
            sig.action,
            sig.side,
            f"{sig.final_price:.2f}",
            sig.final_contracts,
            f"${sig.final_bet_dollars:.2f}",
            f"{sig.consensus_confidence:.1f}",
            f"{sig.kco_signal.ev_per_dollar:+.3f}",
        ))


def print_portfolio(orchestrator: KalshiOrchestrator):
    """Display portfolio and algorithm performance dashboard."""
    summary = orchestrator.get_portfolio_summary()

    if not HAS_RICH:
        print(json.dumps(summary, indent=2))
        return

    import json

    # Portfolio panel
    bankroll = summary["bankroll"]
    initial = summary["initial_bankroll"]
    peak = summary["peak_bankroll"]
    pnl = bankroll - initial
    pnl_pct = (pnl / initial * 100) if initial else 0
    pnl_color = "green" if pnl >= 0 else "red"

    portfolio_lines = [
        f"[bold]Bankroll:[/bold] ${bankroll:,.2f}  "
        f"([{pnl_color}]{pnl:+,.2f} ({pnl_pct:+.1f}%)[/{pnl_color}])",
        f"[bold]Peak:[/bold] ${peak:,.2f}  "
        f"[bold]Drawdown:[/bold] {summary['drawdown']:.1%}",
        f"[bold]Deployed:[/bold] ${summary['deployed_dollars']:.2f} "
        f"({summary['deployed_fraction']:.1%})",
        f"[bold]Open Positions:[/bold] {summary['open_positions']}",
    ]
    portfolio_panel = Panel(
        "\n".join(portfolio_lines),
        title="[bold blue]Portfolio",
        border_style="blue",
    )

    # Algorithm performance panel
    alg_perf = summary["algorithm_accuracy"]
    alg_w = summary["algorithm_weights"]
    alg_lines = [
        f"[bold]SAE (Algo 1):[/bold] weight={alg_w['sae']:.2f} | accuracy={alg_perf['sae']:.1%}",
        f"[bold]KCO (Algo 2):[/bold] weight={alg_w['kco']:.2f} | accuracy={alg_perf['kco']:.1%}",
        f"[bold]Win Rate:[/bold] {summary['win_rate']:.1%}",
        f"[bold]Win Streak:[/bold] {summary['win_streak']} | "
        f"[bold]Loss Streak:[/bold] {summary['loss_streak']}",
    ]
    alg_panel = Panel(
        "\n".join(alg_lines),
        title="[bold magenta]Algorithm Performance",
        border_style="magenta",
    )

    # Trade stats panel
    stats = summary["trade_stats"]
    stats_lines = [
        f"[bold]Total Bets:[/bold] {stats['total']}",
        f"[bold]Wins:[/bold] [green]{stats['wins']}[/green] | "
        f"[bold]Losses:[/bold] [red]{stats['losses']}[/red]",
        f"[bold]Total P&L:[/bold] [{'green' if stats['pnl'] >= 0 else 'red'}]"
        f"${stats['pnl']:+,.2f}[/]",
        f"[bold]Win Rate:[/bold] {stats['win_rate']:.1%}",
    ]
    stats_panel = Panel(
        "\n".join(stats_lines),
        title="[bold green]Trade Statistics",
        border_style="green",
    )

    console.print()
    console.print(Columns([portfolio_panel, alg_panel, stats_panel]))
    console.print()


# ─── CLI Commands ─────────────────────────────────────────────────────────────

def cmd_scan(args):
    """Run a market scan."""
    if HAS_RICH:
        console.print(Panel(
            "[bold cyan]Kalshi Multi-Algorithm Betting System[/bold cyan]\n"
            "Running: SAE → KCO → CSS pipeline",
            border_style="cyan",
        ))

    with KalshiOrchestrator(
        bankroll=args.bankroll,
        kelly_fraction=args.kelly,
        demo_mode=not args.live,
        min_confidence=args.min_confidence,
        max_bets_per_scan=args.max_bets,
    ) as orch:
        execute = args.execute
        dry_run = not args.live  # dry_run unless --live flag set

        fetch_hist = args.history

        if HAS_RICH:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console,
            ) as progress:
                task = progress.add_task("Fetching markets from Kalshi...", total=None)
                markets = orch._fetch_markets(limit=args.limit)
                progress.update(task, description=f"Analyzing {len(markets)} markets...")
                signals = orch.analyze_markets(markets, fetch_history=fetch_hist)
                if execute:
                    progress.update(task, description="Executing top trades...")
                    tradeable = [s for s in signals if s.should_trade][:orch.max_bets_per_scan]
                    for sig in tradeable:
                        orch.execute_trade(sig, dry_run=dry_run)
                progress.update(task, description="Done!", completed=True)
        else:
            markets = orch._fetch_markets(limit=args.limit)
            signals = orch.analyze_markets(markets, fetch_history=fetch_hist)

        tradeable = [s for s in signals if s.should_trade]
        all_signals = signals[:args.top]

        if HAS_RICH:
            # Show stats header
            total = len(signals)
            trade_count = len(tradeable)
            console.print(
                f"\nScanned [bold]{total}[/bold] markets | "
                f"[bold green]{trade_count}[/bold green] tradeable | "
                f"Showing top {min(args.top, total)}\n"
            )

        print_signal_table(all_signals, title=f"Top {args.top} Opportunities")

        if execute and HAS_RICH:
            executed = tradeable[:orch.max_bets_per_scan]
            if executed:
                mode_str = "[DRY RUN]" if dry_run else "[LIVE]"
                console.print(f"\n[bold]{mode_str} Executed {len(executed)} trades[/bold]")
                for sig in executed:
                    console.print(
                        f"  {'✓' if not dry_run else '○'} {sig.ticker} | "
                        f"{sig.side} | {sig.final_contracts} contracts @ "
                        f"${sig.final_price:.2f} | conf={sig.consensus_confidence:.1f}"
                    )

        print_portfolio(orch)

        return signals


def cmd_portfolio(args):
    """Show portfolio status."""
    with KalshiOrchestrator(
        bankroll=args.bankroll,
        demo_mode=not args.live,
    ) as orch:
        print_portfolio(orch)


def cmd_watch(args):
    """Continuous monitoring loop."""
    if HAS_RICH:
        console.print(f"[bold cyan]Watch mode: scanning every {args.interval}s[/bold cyan]")
        console.print("Press Ctrl+C to stop.\n")

    scan_count = 0
    try:
        while True:
            scan_count += 1
            ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            if HAS_RICH:
                console.rule(f"[bold]Scan #{scan_count} — {ts}[/bold]")
            else:
                print(f"\n{'='*60}\nScan #{scan_count} — {ts}\n{'='*60}")

            cmd_scan(args)

            if HAS_RICH:
                console.print(f"\nNext scan in {args.interval}s...")
            time.sleep(args.interval)
    except KeyboardInterrupt:
        if HAS_RICH:
            console.print("\n[yellow]Watch mode stopped.[/yellow]")
        else:
            print("\nWatch mode stopped.")


def cmd_backtest(args):
    """Run the backtester."""
    from backtester import Backtester

    bt = Backtester(
        bankroll=args.bankroll,
        kelly_fraction=args.kelly,
        min_confidence=args.min_confidence,
    )
    results = bt.run(
        n_markets=args.n_markets,
        n_rounds=args.n_rounds,
        seed=args.seed,
    )
    bt.print_results(results)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Kalshi Multi-Algorithm Betting System",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Global options
    parser.add_argument("--bankroll", type=float, default=1000.0,
                        help="Starting bankroll in dollars (default: 1000)")
    parser.add_argument("--kelly", type=float, default=0.25,
                        help="Kelly fraction multiplier (default: 0.25 = quarter Kelly)")
    parser.add_argument("--live", action="store_true",
                        help="Use live API (default: demo). REAL MONEY if --execute is set!")
    parser.add_argument("--min-confidence", type=float, default=55.0,
                        help="Minimum consensus confidence to consider a trade (0-100)")

    subparsers = parser.add_subparsers(dest="command")

    # ── scan ──
    scan_parser = subparsers.add_parser("scan", help="Analyze markets")
    scan_parser.add_argument("--limit", type=int, default=200,
                             help="Number of markets to fetch")
    scan_parser.add_argument("--top", type=int, default=15,
                             help="Number of top opportunities to display")
    scan_parser.add_argument("--execute", action="store_true",
                             help="Execute trades on top opportunities")
    scan_parser.add_argument("--max-bets", type=int, default=3,
                             help="Max bets to place per scan")
    scan_parser.add_argument("--history", action="store_true",
                             help="Fetch trade history for richer analysis (slower)")

    # ── portfolio ──
    port_parser = subparsers.add_parser("portfolio", help="Show portfolio status")

    # ── watch ──
    watch_parser = subparsers.add_parser("watch", help="Continuous monitoring loop")
    watch_parser.add_argument("--interval", type=int, default=300,
                              help="Seconds between scans (default: 300)")
    watch_parser.add_argument("--limit", type=int, default=200)
    watch_parser.add_argument("--top", type=int, default=10)
    watch_parser.add_argument("--execute", action="store_true")
    watch_parser.add_argument("--max-bets", type=int, default=3)
    watch_parser.add_argument("--history", action="store_true")

    # ── backtest ──
    bt_parser = subparsers.add_parser("backtest", help="Run backtester")
    bt_parser.add_argument("--n-markets", type=int, default=500,
                           help="Number of synthetic markets to simulate")
    bt_parser.add_argument("--n-rounds", type=int, default=10,
                           help="Number of rounds (each round = n_markets)")
    bt_parser.add_argument("--seed", type=int, default=42)

    args = parser.parse_args()

    if args.command == "scan" or args.command is None:
        if args.command is None:
            # Default: run scan
            args.command = "scan"
            args.limit = 200
            args.top = 15
            args.execute = False
            args.max_bets = 3
            args.history = False
        cmd_scan(args)
    elif args.command == "portfolio":
        cmd_portfolio(args)
    elif args.command == "watch":
        cmd_watch(args)
    elif args.command == "backtest":
        cmd_backtest(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
