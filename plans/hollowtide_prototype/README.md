# Hollowtide — Prototype

A single-file Python simulation that demonstrates the core systems from
[`../hollowtide-design.md`](../hollowtide-design.md) interacting. No
dependencies. Deterministic given a seed.

```sh
python3 demo.py
python3 demo.py --seed 4 --years 25
```

## What it models

- **Body graph** with derived capacities (vitality resists plague; brain
  damage from a Geas reduces recall and raises mortality risk).
- **Lifecycle** with age tiers, capacity ceilings, and natural death.
- **Skill** as a context histogram, not a number. A skill *converges* when
  one context exceeds 65% of total uses — the histogram has collapsed.
  Convergence produces a signature technique whose name is generated from
  the dominant context's tokens.
- **Drift** along four pressure axes (environment, action, emotion,
  communion). Crossing a threshold with the right signal triggers
  transmutation into a new lineage — irreversible.
- **Bereavement** raises a permanent grief floor when the lost is a child or
  spouse. That wound never closes.
- **Geas** invocation: requires a converged signature, sustained grief, and
  an external trigger. Applies a permanent cost atomically with the effect
  (here: brain damage and severance of all bonds — the smith's name becomes
  unspeakable).
- **Chronicle** as an append-only event log: the only persistent record.

## What it does NOT model

This is a tone- and rule-correctness prototype, not a game. It's missing
ecology, economy, factions, culture drift, multi-rate ticking, ECS wiring,
LOD, and a UI. Those are for the real implementation.

## What you should see

The world simulates a village of five — a smith named Oren, his wife Mara,
and three children. A winter fever sweeps through in year 3. After that,
behaviour is rule-driven, not scripted, so each seed produces a different
trajectory:

- Some seeds kill Oren himself in the plague. The simulation continues
  without him. The world is indifferent.
- Some seeds spare him but kill nothing of consequence — no convergence,
  no transmutation, an ordinary life.
- Some seeds kill his children. He drifts into night-and-burial work. Over
  years, his smithing converges on a unique technique. He transmutes into
  a *psychopomp*. Eventually soldiers come for his work, he pays a Geas,
  and he is forgotten.

A short sweep across seeds produced these emergent technique names, each
from the same naming rules acting on different convergence histories:

```
Owl Lament Nail Forge
Lampless Lament Nail Forge
Lampless Ash Cairn Iron
Moonless Mourner's Cairn Iron
Lampless Weeping Quiet Edge
Dim Ash Cairn Hammer
```

That's the demo's whole point: vivid specifics from a small set of rules
that nobody scripted.

## How the rules connect

```
plague   ──▶ deaths ──▶ bereavement ──▶ permanent grief floor
                                              │
                                              ▼
                                       practice context shifts
                                       (night, grief, burial)
                                              │
                  ┌───────────────────────────┴───────────────────────┐
                  ▼                                                   ▼
       drift pressure (action+emotion)                  skill context histogram
                  │                                                   │
                  ▼                                                   ▼
        magnitude > threshold AND                       dominant context > 65%
        burial signal > 1000                                          │
                  │                                                   ▼
                  ▼                                          signature technique
            transmutation                                           │
                  │                                                   │
                  └─────────────────┬─────────────────────────────────┘
                                    ▼
                       conditions for Geas met
                                    │
                                    ▼
                     Geas invoked → world changes,
                     permanent cost paid by smith
                                    │
                                    ▼
                            chronicle entry
```

No node here is a script. Each is a rule that fires when the simulation
state qualifies it. Remove the plague and nothing downstream happens.
Remove the grief floor and the histogram never collapses. Remove the Geas
gate and convergence has no consequence beyond the smith's own hands.

## Files

- `demo.py` — the whole simulation in one file.
- `README.md` — this.
