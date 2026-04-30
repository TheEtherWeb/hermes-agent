"""
Hollowtide prototype.

A single-file simulation demonstrating the core systems from the design doc:

- Body graph with derived capacities and aging
- Skill system with context histograms and convergence detection
- Pressure-vector drift with transmutation thresholds
- Append-only chronicle
- A tiny world that emergently reproduces the Plague Smith scenario from rules,
  not a script.

No dependencies. Deterministic given a seed.

Run:
    python3 demo.py
    python3 demo.py --seed 7 --years 30
"""

from __future__ import annotations

import argparse
import math
import random
from collections import Counter
from dataclasses import dataclass, field
from typing import Optional


# ---------------------------------------------------------------------------
# Chronicle
# ---------------------------------------------------------------------------

@dataclass
class ChronicleEntry:
    day: int
    kind: str
    text: str


class Chronicle:
    def __init__(self) -> None:
        self.entries: list[ChronicleEntry] = []

    def write(self, day: int, kind: str, text: str) -> None:
        self.entries.append(ChronicleEntry(day, kind, text))

    def render(self) -> str:
        out = []
        for e in self.entries:
            year, day = divmod(e.day, 360)
            out.append(f"  Y{year:02d} D{day:03d}  [{e.kind:<11}] {e.text}")
        return "\n".join(out)


# ---------------------------------------------------------------------------
# Body graph
#
# Capacities are DERIVED from parts. Damage to a part propagates to capacities.
# Aging multiplies a tier-dependent ceiling.
# ---------------------------------------------------------------------------

AGE_TIERS = [
    (0,  "infant",      0.20),
    (5,  "child",       0.55),
    (13, "adolescent",  0.85),
    (20, "prime",       1.00),
    (40, "mature",      0.92),
    (55, "elder",       0.75),
    (70, "decrepit",    0.50),
    (85, "dying",       0.25),
]


@dataclass
class BodyPart:
    name: str
    condition: float = 1.0  # 0.0 = destroyed, 1.0 = pristine
    contributes: dict[str, float] = field(default_factory=dict)


@dataclass
class Body:
    parts: dict[str, BodyPart] = field(default_factory=dict)

    @classmethod
    def human(cls) -> "Body":
        return cls(parts={
            "left_hand":  BodyPart("left_hand",  contributes={"grip": 0.5, "fine_motor": 0.5}),
            "right_hand": BodyPart("right_hand", contributes={"grip": 0.5, "fine_motor": 0.5}),
            "eyes":       BodyPart("eyes",       contributes={"vision": 1.0}),
            "lungs":      BodyPart("lungs",      contributes={"endurance": 1.0}),
            "heart":      BodyPart("heart",      contributes={"endurance": 0.5, "vitality": 1.0}),
            "legs":       BodyPart("legs",       contributes={"locomotion": 1.0}),
            "brain":      BodyPart("brain",      contributes={"focus": 1.0, "recall": 1.0}),
        })

    def capacity(self, name: str, age_mult: float) -> float:
        total = 0.0
        for part in self.parts.values():
            if name in part.contributes:
                total += part.contributes[name] * part.condition
        return total * age_mult

    def injure(self, part_name: str, amount: float) -> None:
        if part_name in self.parts:
            p = self.parts[part_name]
            p.condition = max(0.0, p.condition - amount)


# ---------------------------------------------------------------------------
# Skill system
#
# A skill remembers WHEN, WHERE, AGAINST WHAT, FEELING WHAT it was used.
# Convergence is detected as low entropy across that histogram.
# ---------------------------------------------------------------------------

@dataclass
class Skill:
    name: str
    competence: float = 0.0
    context_counts: Counter = field(default_factory=Counter)
    signature: Optional[str] = None  # name of converged technique, if any

    def practice(self, context: tuple, gain: float = 1.0) -> None:
        self.competence = min(1.0, self.competence + gain * 0.01 * (1.0 - self.competence))
        self.context_counts[context] += 1

    def total_uses(self) -> int:
        return sum(self.context_counts.values())

    def entropy(self) -> float:
        n = self.total_uses()
        if n == 0:
            return 0.0
        h = 0.0
        for c in self.context_counts.values():
            p = c / n
            h -= p * math.log2(p)
        return h

    def dominant_context(self) -> Optional[tuple]:
        if not self.context_counts:
            return None
        return self.context_counts.most_common(1)[0][0]


# Procedural naming for signature techniques. Pulls from the dominant context.
TECHNIQUE_NAME_FRAGMENTS = {
    "night":      ["Moonless", "Lampless", "Owl-",   "Dim-"],
    "day":        ["Sunlit",   "Open-",     "Noon-",  "Bright-"],
    "grief":      ["Lament-",  "Mourner's", "Weeping","Ash-"],
    "rage":       ["Iron-",    "Cleaver-",  "Wrath-", "Splitting-"],
    "duty":       ["Oath-",    "Steady-",   "Long-",  "Watchman's"],
    "burial":     ["Tomb-",    "Nail-",     "Cairn-", "Quiet-"],
    "field":      ["Furrow-",  "Hedge-",    "Reaper's","Sheaf-"],
    "war":        ["Bloodied-","Banner-",   "Salt-",  "Drum-"],
}
TECHNIQUE_SUFFIX = {
    "smithing": ["Edge", "Hammer", "Forge", "Iron"],
    "sword":    ["Edge", "Cut", "Stroke", "Step"],
    "weaving":  ["Thread", "Loom", "Knot", "Shroud"],
}


def name_technique(rng: random.Random, skill: str, ctx: tuple) -> str:
    parts = []
    for token in ctx:
        frags = TECHNIQUE_NAME_FRAGMENTS.get(token)
        if frags:
            parts.append(rng.choice(frags).rstrip("-"))
    if not parts:
        parts.append("Nameless")
    suffix = rng.choice(TECHNIQUE_SUFFIX.get(skill, ["Work"]))
    return " ".join(parts) + " " + suffix


# ---------------------------------------------------------------------------
# Drift / evolution
#
# Each agent accumulates pressure along four vectors. When the L2 magnitude
# crosses a threshold AND the dominant axis is clear, transmutation fires.
# ---------------------------------------------------------------------------

PRESSURE_AXES = ("environment", "action", "emotion", "communion")

TRANSMUTATIONS = [
    # (dominant_axis, secondary_signal, lineage_tag, narrative)
    ("emotion",     "grief",     "ash-touched",  "Their hair greys to ash and does not grow back. They no longer dream."),
    ("communion",   "wolves",    "lupine-kin",   "Their gait shifts; the dogs in the village will no longer come near."),
    ("environment", "fen",       "bog-kin",      "Their fingers web. Their breath comes slow and damp."),
    ("action",      "burial",    "psychopomp",   "The dead settle in their presence. The living find them harder to look at."),
]
DRIFT_THRESHOLD = 12.0


@dataclass
class DriftState:
    pressures: dict[str, float] = field(default_factory=lambda: {a: 0.0 for a in PRESSURE_AXES})
    signals: Counter = field(default_factory=Counter)
    lineage: str = "human"

    def add(self, axis: str, signal: str, amount: float) -> None:
        self.pressures[axis] = self.pressures.get(axis, 0.0) + amount
        self.signals[signal] += 1

    def magnitude(self) -> float:
        return math.sqrt(sum(v * v for v in self.pressures.values()))

    def dominant_axis(self) -> str:
        return max(self.pressures, key=self.pressures.get)

    def check_transmutation(self) -> Optional[tuple[str, str]]:
        if self.magnitude() < DRIFT_THRESHOLD:
            return None
        dom = self.dominant_axis()
        for axis, signal, tag, narrative in TRANSMUTATIONS:
            if axis == dom and self.signals.get(signal, 0) >= 1000:
                return tag, narrative
        return None


# ---------------------------------------------------------------------------
# Agent
# ---------------------------------------------------------------------------

@dataclass
class Agent:
    name: str
    age_days: int = 20 * 360
    body: Body = field(default_factory=Body.human)
    skills: dict[str, Skill] = field(default_factory=dict)
    drift: DriftState = field(default_factory=DriftState)
    bonds: dict[str, float] = field(default_factory=dict)  # name -> intensity
    grief_transient: float = 0.0  # decays
    grief_floor: float = 0.0      # permanent — never decays
    alive: bool = True
    occupation: str = "villager"

    @property
    def grief(self) -> float:
        return max(self.grief_transient, self.grief_floor)

    def age_years(self) -> int:
        return self.age_days // 360

    def age_tier(self) -> tuple[str, float]:
        tier_name, mult = "infant", 0.20
        for min_age, label, m in AGE_TIERS:
            if self.age_years() >= min_age:
                tier_name, mult = label, m
        return tier_name, mult

    def get_skill(self, name: str) -> Skill:
        if name not in self.skills:
            self.skills[name] = Skill(name=name)
        return self.skills[name]


# ---------------------------------------------------------------------------
# World
# ---------------------------------------------------------------------------

@dataclass
class World:
    day: int = 0
    agents: list[Agent] = field(default_factory=list)
    chronicle: Chronicle = field(default_factory=Chronicle)
    rng: random.Random = field(default_factory=random.Random)
    geas_invoked: bool = False
    plague_days_remaining: int = 0

    def named(self, name: str) -> Optional[Agent]:
        for a in self.agents:
            if a.name == name and a.alive:
                return a
        return None

    def time_of_day(self) -> str:
        # Smith works at night (see schedule). One bucket per phase suffices
        # for the histogram to converge on it.
        return "night"


# ---------------------------------------------------------------------------
# Simulation rules — the only place game behaviour lives.
# ---------------------------------------------------------------------------

def daily_aging(world: World, agent: Agent) -> None:
    agent.age_days += 1
    # Transient grief decays. Permanent grief floor (set by bereavement of
    # children/spouse) does not.
    agent.grief_transient = max(0.0, agent.grief_transient - 0.0005)
    # Old age accumulates wear on the heart.
    if agent.age_years() >= 55 and world.rng.random() < 0.0008:
        agent.body.injure("heart", 0.01)


def check_natural_death(world: World, agent: Agent) -> None:
    tier, _ = agent.age_tier()
    risk = {"prime": 0.00002, "mature": 0.00008, "elder": 0.0004,
            "decrepit": 0.002, "dying": 0.01}.get(tier, 0.0)
    if agent.body.parts["heart"].condition < 0.2:
        risk += 0.005
    if world.rng.random() < risk:
        kill(world, agent, cause="age and the long quiet")


def kill(world: World, agent: Agent, cause: str) -> None:
    if not agent.alive:
        return
    agent.alive = False
    world.chronicle.write(world.day, "death",
                          f"{agent.name} ({agent.age_years()}) dies — {cause}.")
    # Bereavement spreads to anyone bonded to them. Loss of a child (under 16)
    # raises the *permanent* grief floor — that wound never closes.
    for other in world.agents:
        if other.alive and agent.name in other.bonds:
            intensity = other.bonds[agent.name]
            other.grief_transient = min(1.0, other.grief_transient + intensity)
            if agent.age_years() < 16 and other.age_years() > agent.age_years():
                other.grief_floor = min(1.0, other.grief_floor + intensity * 0.6)
            other.drift.add("emotion", "grief", intensity * 2.0)
            world.chronicle.write(
                world.day, "bereavement",
                f"{other.name} is bereaved of {agent.name}.")


def begin_plague(world: World) -> None:
    """A winter fever — a season-long event with daily exposure rolls."""
    world.plague_days_remaining = 90
    world.chronicle.write(world.day, "plague",
                          "A winter fever comes down out of the hills.")


def plague_tick(world: World) -> None:
    if world.plague_days_remaining <= 0:
        return
    world.plague_days_remaining -= 1
    for agent in list(world.agents):
        if not agent.alive:
            continue
        _, age_mult = agent.age_tier()
        vit = agent.body.capacity("vitality", age_mult)
        # Per-day exposure risk. Compounded over 90 days this kills the frail
        # reliably but spares the strong most years.
        daily = 0.004 * (1.6 - vit)
        if agent.age_years() < 10 or agent.age_years() > 60:
            daily *= 2.0
        if world.rng.random() < daily:
            kill(world, agent, cause="winter fever")
    if world.plague_days_remaining == 0:
        world.chronicle.write(world.day, "plague", "The fever lifts. Snow stays.")


ORDINARY_CONTEXTS = [
    ("day",   "duty", "field"),
    ("day",   "duty", "war"),
    ("day",   "rage", "war"),
    ("night", "duty", "field"),
    ("day",   "duty", "burial"),  # ordinary funerary work, not grief-driven
]


def practice_smithing(world: World, agent: Agent) -> None:
    skill = agent.get_skill("smithing")
    # The defining choice: a grieving smith works at night on burial-iron.
    if agent.grief > 0.3:
        ctx = ("night", "grief", "burial")
        skill.practice(ctx, gain=1.5)
        agent.drift.add("action", "burial", 0.05)
        agent.drift.add("emotion", "grief", 0.02)
    else:
        # Ordinary work is varied — no single context dominates, so the skill
        # cannot converge on a signature without the long pressure of grief.
        ctx = world.rng.choice(ORDINARY_CONTEXTS)
        skill.practice(ctx, gain=1.0)
        agent.drift.add("action", "field", 0.01)


def check_skill_convergence(world: World, agent: Agent) -> None:
    """Convergence: one context dominates. The histogram has collapsed."""
    for skill in agent.skills.values():
        if skill.signature is not None:
            continue
        n = skill.total_uses()
        if n < 800 or skill.competence < 0.5:
            continue
        ctx, count = skill.context_counts.most_common(1)[0]
        if count / n < 0.65:
            continue
        tech = name_technique(world.rng, skill.name, ctx)
        skill.signature = tech
        world.chronicle.write(
            world.day, "convergence",
            f"{agent.name}'s {skill.name} converges. "
            f"They have a private technique now: \"{tech}\". "
            f"It does not exist anywhere else.")


def check_drift(world: World, agent: Agent) -> None:
    if agent.drift.lineage != "human":
        return
    result = agent.drift.check_transmutation()
    if result is None:
        return
    tag, narrative = result
    agent.drift.lineage = tag
    world.chronicle.write(
        world.day, "transmutation",
        f"{agent.name} crosses a threshold and becomes {tag}. {narrative}")


def check_geas(world: World, agent: Agent) -> None:
    """Geas: invoked when grief, signature, and a triggering threat align."""
    if world.geas_invoked:
        return
    smith = agent.skills.get("smithing")
    if smith is None or smith.signature is None:
        return
    if agent.grief < 0.5:
        return
    # Trigger: an outside power has come to take the smith's work by force.
    # We model this by a random low-probability event once the smith is famous.
    if world.rng.random() < 0.003:
        world.geas_invoked = True
        world.chronicle.write(
            world.day, "geas",
            f"Soldiers of a southern kingdom come for {agent.name}'s nails. "
            f"{agent.name} pays a Geas. They die where they stand. "
            f"{agent.name}'s name becomes unspeakable; "
            f"those who knew them will forget within a year.")
        # Cost: name is unspeakable. We model this as the smith's bonds
        # being severed (others forget them) and the smith's recall ruined.
        agent.body.injure("brain", 0.4)
        for other in world.agents:
            if other is agent:
                continue
            other.bonds.pop(agent.name, None)


# ---------------------------------------------------------------------------
# Setup and run
# ---------------------------------------------------------------------------

def make_initial_world(seed: int) -> World:
    rng = random.Random(seed)
    world = World(rng=rng)

    oren = Agent(name="Oren", occupation="smith", age_days=24 * 360)
    mara = Agent(name="Mara",  age_days=22 * 360)
    child_a = Agent(name="Sela", age_days=4 * 360)
    child_b = Agent(name="Ivo",  age_days=2 * 360)
    child_c = Agent(name="Tess", age_days=6 * 360)

    # Bonds (intensity 0..1).
    oren.bonds = {"Mara": 0.9, "Sela": 0.7, "Ivo": 0.7, "Tess": 0.7}
    mara.bonds = {"Oren": 0.9, "Sela": 0.7, "Ivo": 0.7, "Tess": 0.7}
    for c in (child_a, child_b, child_c):
        c.bonds = {"Oren": 0.5, "Mara": 0.5}

    world.agents.extend([oren, mara, child_a, child_b, child_c])
    world.chronicle.write(0, "birth", "The village of Hollowtide is recorded.")
    for a in world.agents:
        world.chronicle.write(0, "register",
                              f"{a.name}, {a.occupation}, age {a.age_years()}.")
    return world


def simulate(world: World, years: int) -> None:
    total_days = years * 360
    plague_year = 3  # the inciting tragedy happens early
    for _ in range(total_days):
        world.day += 1

        # Macro events.
        if world.day == plague_year * 360 + 30:
            begin_plague(world)
        plague_tick(world)

        # Per-agent daily simulation.
        for agent in world.agents:
            if not agent.alive:
                continue
            daily_aging(world, agent)
            if agent.occupation == "smith" and agent.age_years() >= 14:
                practice_smithing(world, agent)
            check_skill_convergence(world, agent)
            check_drift(world, agent)
            check_geas(world, agent)
            check_natural_death(world, agent)


def report(world: World) -> str:
    lines = ["", "=" * 72, "  CHRONICLE OF HOLLOWTIDE", "=" * 72, ""]
    lines.append(world.chronicle.render())
    lines += ["", "-" * 72, "  STATE AT END OF SIMULATION", "-" * 72, ""]
    for a in world.agents:
        status = "alive" if a.alive else "dead"
        tier, _ = a.age_tier()
        lines.append(f"  {a.name:<8} {status:<5}  age {a.age_years():<3}  "
                     f"tier={tier:<10} lineage={a.drift.lineage}")
        for skill in a.skills.values():
            sig = f"  signature=\"{skill.signature}\"" if skill.signature else ""
            lines.append(f"      skill {skill.name:<10} "
                         f"competence={skill.competence:.2f}  "
                         f"uses={skill.total_uses():<5} "
                         f"H={skill.entropy():.2f}{sig}")
        if a.drift.magnitude() > 0:
            top = ", ".join(f"{k}={v:.1f}" for k, v in a.drift.pressures.items() if v)
            lines.append(f"      drift |p|={a.drift.magnitude():.1f}  ({top})")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Hollowtide prototype sim")
    parser.add_argument("--seed", type=int, default=1, help="RNG seed")
    parser.add_argument("--years", type=int, default=20,
                        help="Years of simulation")
    args = parser.parse_args()

    world = make_initial_world(args.seed)
    simulate(world, args.years)
    print(report(world))


if __name__ == "__main__":
    main()
