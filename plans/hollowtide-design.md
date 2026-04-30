# Hollowtide — Design Document

*A dark fantasy isekai simulation. Working title.*

> Everything that makes the player powerful also makes them less themselves,
> and the world keeps its books.

The world exists before the player, persists after them, and is indifferent to
them. Characters are shaped by what they do and what is done to them, never by
arbitrary numbers awarded for completing tasks. Power is real and so is its
price. The tone is oppressive, tragic, and systemic — sorrow emerges from rules,
not scripts.

This document specifies the design in enough detail to begin implementation. A
small runnable prototype demonstrating the core mechanics lives in
[`hollowtide_prototype/`](./hollowtide_prototype/).

---

## 1. Core Gameplay Loop

**Macro arc — a single life (8–40 hours of play):**

```
arrive ──▶ survive ──▶ bond ──▶ specialize ──▶ mark the world ──▶ decline ──▶ die or transmute ──▶ world persists
```

**Moment-to-moment loop:**

1. **Read the world.** Weather, omens, faction tempers, who is hungry, who
   hates whom. The UI surfaces this through diegetic channels (rumours, songs,
   ledgers) — never through floating numbers.
2. **Act.** Actions are verbs against the simulation: cut, plead, study,
   betray, endure. Not menu options unlocked by a class.
3. **Be reshaped.** Your body, skills, reputation, and soul-signature drift
   in response to what you do.
4. **World reshapes back.** Factions remember. Ecologies adjust. Rumours
   mutate as they spread.
5. New pressures collapse old plans. Return to (1).

**Save = world, not character.** When the player character dies, the save
continues. The player may take over a descendant, a witness, or a reincarnated
stranger — or simply watch the chronicle play out.

There is no win condition. There are only durations and what is left after them.

---

## 2. Systems

### 2.1 Lifecycle

There are no levels. There are **capacities** and there is **wear**.

- **Body** is a graph of organs and parts (Dwarf Fortress lineage). Each part
  has condition and contributes capacities (grip, vision, lung volume, fine
  motor, blood capacity). Capacities are *derived* from the body graph, never
  stored as a stat block. Damage propagates.
- **Mind** is an analogous graph: working memory, emotional regulation, focus,
  recall, conviction. Damaged by trauma, malnutrition, and certain Geases;
  partially preserved through ritual, study, or relationships.
- **Aging tiers**: infant, child, adolescent, prime, mature, elder, decrepit,
  dying. Each tier shifts capacity ceilings — you cannot out-train a body that
  is unbecoming.
- **Death is permanent.** No revival. No retry. The chronicle records you,
  imperfectly, and forgetting begins.
- **Generational echo:** bloodlines carry residues — half-remembered skills,
  inherited fears, predispositions toward emotional states. A descendant of a
  great tyrant flinches at her own anger and does not know why.

### 2.2 Race & Evolution

There are no fixed races. There are **lineages** and **drift**.

Every creature has a *form*: a bundle of anatomical, behavioral, and
metaphysical traits. Sustained pressure pushes the form toward thresholds.
Cross a threshold and the form **transmutes** — usually painful, always
irreversible.

Drift is driven by four pressure vectors:

| Pressure | Examples |
|---|---|
| Environment | climate, diet, exposure, ambient magic, latitude |
| Action | what the body repeatedly does (running, weaving, killing) |
| Emotion | long-tenured states (grief, devotion, terror, rage) |
| Communion | who and what you live alongside |

Transmutation thresholds are zones in pressure-space. Crossing one rewrites the
body graph and assigns a new lineage tag. Examples the simulation can produce:

- Three generations starving in a cursed fen → **bog-kin**: webbed, gilled,
  slow-witted, long-lived.
- A child raised by wolves who *grieves* with them when one dies →
  **lupine-kin**.
- A scholar who reads forbidden texts every night for forty years and tells
  no one → **thought-eater**: cannot speak, hears every nearby thought.

The **isekai protagonist** has a soul-signature foreign to this cosmology.
They drift faster but along stranger axes. Local gods do not see them clearly;
fate-structures bend awkwardly around them. This is gift and curse: they
accumulate transformative pressure quickly and unpredictably.

### 2.3 Skills

A skill is not a number. A skill is a **history of doing under conditions.**
Internally, each skill stores:

- a competence scalar (broad, slowly raised by practice)
- a **context histogram**: counts of how often the skill was used under each
  combination of conditions (time of day, terrain, opponent type, emotional
  state, ambient culture)
- a personality lens belonging to the doer

**Convergence.** When one act repeats under a tight cluster of conditions —
detectable as entropy collapse in the context histogram — the skill produces
a *signature*: a unique technique whose properties are drawn from those
conditions and named procedurally from the agent's culture and lexicon.

> A swordswoman who has only ever drawn her blade at night, in grief,
> against the unburied, will one day find she has a private technique. The
> game names it from her language and her culture's poetics. No one else
> has it. No one else can.

**Personality refracts everything.** Two smiths with identical practice produce
visibly different work. Cruel surgeons stitch differently than tender ones.

**Skills can be lost.** Head injury, prolonged grief, replacement of the
relevant body part, cultural taboo. A blacksmith who loses three fingers does
not have a "smithing penalty" — she has lost smithing, and a piece of her
self-image with it.

**Teaching is lossy.** A taught skill is a copy, degraded by the gap between
teacher and student in language, body, and feeling. Resonance — shared trauma,
shared culture, shared love — closes the gap.

### 2.4 Ultimate Abilities (Geases)

Rare. World-marking. Always paid for.

A Geas triggers when conditions converge that the simulation reads as a
*cosmic resonance event*: a deed of sufficient weight, an emotion of sufficient
duration, an offering of sufficient cost, occurring at an alignment the world
treats as significant. They are not unlocked. They are *invoked* — and the
world, if it accepts, takes its price.

Costs are mandatory and structural. Examples:

| Geas | Effect | Cost |
|---|---|---|
| **Sunder the Year** | Collapse a season into one night | Invoker ages two decades; one named loved one dies of grief within the month |
| **Bloodfather's Oath** | Every descendant of your line, forever, fights without fear | You lose the capacity to love |
| **The Quiet** | Every member of a named faction within sight falls dead | Your name becomes unspeakable; those who knew you forget you |
| **Drown the Map** | Raise the sea by a hand's breadth | You become the sea's voice; you are never alone in your own head again |

Geases leave permanent traces: chronicles, songs, geographic scars, faction
reformations. NPCs invoke them too — past ages of the world were shaped by
Geases the player will only encounter as ruins, taboos, or songs.

Implementation: a rule-based pattern matcher over recent world history and
agent state. Costs are debited from agent and world entities atomically with
the effect. Partial payment is forbidden. Every successful Geas writes a
permanent entry to the world chronicle.

### 2.5 World Simulation

Layered, slowest at the bottom, each layer pressuring the layer above:

| Layer | Tick | Role |
|---|---|---|
| Geology / climate | decades | shifts coasts, drought cycles, volcanic centuries |
| Ecology | seasons | migrations, blights, predator–prey balances |
| Population | months | birth, death, migration, plague |
| Economy | weeks | resource flows, scarcity, trade routes |
| Factions & politics | weeks | alliances, schisms, succession |
| Culture | years | language drift, religious mutation, art schools |
| Individuals | minutes–days | the people you can actually see |

A drought (geology) collapses harvests (ecology), starves a province
(population), spikes grain prices (economy), provokes a tax revolt (politics),
cracks the state religion (culture), and finally turns your neighbour into an
informer (individual). The player may experience only the last step. The chain
still ran.

Cultures **drift** across generations. Words change. Gods are renamed by their
grandchildren. The world the player arrived in is not the world they will die
in, even if nothing dramatic happens.

---

## 3. Emergent Scenarios

These are not scripted. They are example trajectories the simulation can
produce from the rules above.

### The Plague Smith

A village smith named Oren loses his wife and three children to fever in one
winter. He keeps working — only at night, only on burial nails, weeping. After
eleven years his smithing has converged: his context histogram has collapsed
to a single tight cluster (night × grief × burial-iron). He produces nails
that the dead beneath cannot cross. The neighbouring kingdom, plagued by
restless dead, hears of him. They send envoys. He refuses. They send soldiers.
He pays a Geas and the soldiers die where they stand. His name becomes
unspeakable; his village forgets him within a year and lives in a graveyard
of nails it cannot explain.

### The Wolfborn Heir

A noble's third son, sickly, is sent to a winter lodge to die quietly. He
survives on goat-milk and a she-wolf's grudging tolerance. Over fifteen years
his form drifts under combined Communion + Emotion pressure; he returns to
court at thirty walking strangely, unable to read, terrifyingly attuned to
grief. The court tries to kill him. The wolves come down out of the hills. A
new dynasty begins, and three generations later "lupine-kin" is a recognized
lineage in the regional census, though everyone has forgotten Oren's nails are
why the dead don't trouble them.

### The Quiet Rebellion

A hedge-witch in an occupied province teaches village children to read using
forbidden glyphs. None of the children become powerful. But over forty years,
the *language itself* drifts — the occupier's tongue is rewritten in their
mouths until imperial scribes can no longer parse local petitions. The empire's
grip slips not from war but from grammar. The witch dies in obscurity. A
descendant six generations later, a poet, accidentally invokes a Geas while
writing a love letter, and the empire ends in an afternoon.

### The Player Who Could Not Belong

An isekai protagonist drifts strangely — local gods cannot see them,
fate-threads slip. They cannot inherit titles; their children are born without
family-lines the kingdom recognizes. Eventually they leave human society
entirely and drift toward something this world has no word for. The save
continues. Their grandchild, who looks nearly human, becomes a saint of a
religion that did not exist when the player arrived.

---

## 4. Progression Structure

**Early game — a life's first quarter.**
The world is enormous and indifferent. You learn what hunger does, what the
seasons do, who hates whom in your valley. Skills are crude. The body is
plastic. Choices feel small and are not.

**Mid game — prime years.**
Specialization. Skill convergences begin to fire. Bonds harden into
obligations. You become *legible* to factions — they know your name, they want
things from you. The first irreversible marks land: a lost finger, a child, an
oath. Drift becomes visible in the mirror.

**Late game — mature to elder.**
Mass. Your reputation precedes you into rooms. You can invoke Geases — each
one collapses a part of you in exchange for a part of the world. People you
knew when you arrived are dead. Your apprentices teach lossy copies of you to
children who will misunderstand. You decide what to hand off and to whom.

**Endgame — death or transmutation.**
Either you die and the simulation continues without you (handoff offered to a
descendant, witness, or reincarnation), or you have drifted across a threshold
and become something the human layer of the simulation no longer fully tracks
— a hermit-saint, a forest, a rumour. Either way the chronicle records you,
imperfectly, and forgetting begins.

---

## 5. Technical Considerations

- **ECS architecture.** Entities are component bags; systems iterate. Bodies,
  minds, items, settlements, factions, and weather fronts are all entities
  with overlapping component sets.
- **Multi-rate simulation.** Each layer ticks on its own clock. Combat runs
  sub-second; ecology seasonal; geology decadal. Out-of-sight regions run at
  coarsened fidelity (statistical aggregates) and are *re-instantiated* on
  visit by a reconciler that produces individuals consistent with the
  aggregates.
- **Skill representation.** Per-skill: competence scalar plus a compressed
  context histogram (when, where, against what, how feeling). Convergence is
  detected by entropy collapse in the histogram. Signature techniques are
  templated and named procedurally from the agent's culture.
- **Body model.** Anatomical graph with material properties, condition, and
  capacity contributions. Wounds, scars, prosthetics, transmutations all
  mutate the graph. Capacities are derived, not stored.
- **Drift / evolution.** Each lineage tracks pressure vectors. Thresholds are
  zones in pressure-space. Crossings trigger transmutation events that rewrite
  the body graph and propagate lineage tags.
- **Geas system.** Rule-based pattern matcher over recent world history plus
  agent state. Atomic cost-and-effect application. Permanent chronicle entry.
- **Chronicle / legend log.** Append-only event store. Drives in-world
  historiography (each culture writes its own selective version), rumour
  propagation, and song generation.
- **Procedural language.** Phoneme sets per culture; words mutate
  generationally via a small drift model so names and sacred terms
  recognizably evolve over a long campaign.
- **Persistence.** Save = world snapshot + chronicle. Player identity is a
  lightweight pointer into the world; "death" rebinds the pointer.
- **Authoring discipline.** The hardest engineering problem here is not
  simulation depth — it is **legibility**. Players need readable surfaces
  (a journal, a body diagram, a dream-fragment text generator, a chronicle
  viewer) onto a system most of which they will never directly perceive.
  Budget at least as much time on these as on the sim itself; otherwise the
  game is doing magnificent work the player cannot feel.
- **Tone discipline.** No success fanfare. No green numbers. Feedback is
  diegetic — a song sung in a tavern about a thing you did, a child who
  flinches at your face, a ledger entry in a language you can no longer read.

---

## 6. What's Built So Far

The [`hollowtide_prototype/`](./hollowtide_prototype/) directory contains a
single-file Python simulation, no dependencies, that demonstrates the core
systems interacting:

- a body graph with derived capacities and aging
- a skill system with context histograms and convergence detection
- pressure-vector drift with transmutation thresholds
- an append-only chronicle
- a tiny multi-character world that re-runs the **Plague Smith** scenario
  emergently from the rules

Run it:

```sh
python3 plans/hollowtide_prototype/demo.py
```

Each run is deterministic given a seed and produces a chronicle of births,
deaths, skill convergences, drift events, and (if conditions align) a Geas
invocation.
