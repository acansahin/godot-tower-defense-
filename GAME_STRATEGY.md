# GAME_STRATEGY.md

**A design and product strategy for turning an Element TD port into a modern mobile tower
defense.**

Written for the repo at `godot-tower-defense-`, whose `godottowerdefense/` project is
today a faithful port of the 2005 Warcraft III map *Element TD*. This document argues that
faithful is the problem, separates what the original got right from what it got merely
complicated, and specifies a smaller, deeper game that an eight-year-old can read and an
adult can still lose to.

---

## How this document was produced, and how to trust it

Every claim about Element TD below was **read out of the map files on this machine**, not
recalled and not taken from a wiki. Two maps were opened with `tools/extract_w3x.py`:

| Map | Title | Author | Date |
|---|---|---|---|
| `ELEMENT TD.w3x` | Element TD version 2.0 | Pimp10110 | 2005-12-26 |
| `Element TD 1.4.w3x` | Element TD Survivor 1.4 | MrChak | 2005-12-22 |

Re-run any of it with:

```bash
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" towers
```

```bash
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" waves
```

```bash
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" pathing
```

```bash
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" cat war3map.j
```

This pass went past the object-data tables that `godottowerdefense/docs/element-td-data.md`
already records and decompiled the map's **script** (`war3map.j`, 3,936 lines) and its
**string table** (`war3map.wts`). Those two files are where the *rules* live — economy,
difficulty, the element draw, leak handling, the tip list — and none of it was previously
written down in this repo. Section 1 is built mostly on that new material.

**Three kinds of statement appear below and they are labelled:**

- **[EXTRACTED]** — a number or rule read from the map files. Not negotiable; re-derivable.
- **[BUILT]** — how the current Godot project behaves today, read from `game.gd`,
  `balance.gd`, `run.gd`, `meta.gd`, `wave_generator.gd`, `tutorial.gd`.
- Everything else is **my design proposal** and is argued, not asserted.

---

## 0. Executive summary

### The five things that must be true

1. **A child must be able to name every tower's job in one sentence, from its icon.**
   Four elements, four jobs, four colours, four shapes. Not thirty-six towers behind a
   recipe list.
2. **A run must end in a win, not only in a loss.** Twenty waves, then "You survived."
   Endless is a *mode*, not the default. A session that always ends in failure does not
   generate "one more run"; it generates "I'll stop here."
3. **Depth comes from the run, not the roster.** Four towers × one branch decision × a
   card every five waves produces more distinct games than thirty-six towers whose
   combinations must be memorised.
4. **Nothing that makes you stronger may ever be for sale.** Not lives, not gold, not
   Essence, not continues. This is both the ethical position and the commercially durable
   one for an audience that includes 8–14 year olds.
5. **Every number on screen must be comparable at a glance.** Element TD's Pure Darkness
   deals 206,241 damage and costs 24,444 gold. Our ceiling is three digits.

### The recommendation in one paragraph

Ship a **20-wave, ~12-minute Standard run** on **one map with two rulesets**, defended by
**four element towers** (Fire, Water, Earth, Nature) that upgrade through **five levels
with a single branch decision at level 3**, producing **eight distinct end-state towers**
from four palette icons. Enemies are **six archetypes plus a boss**, each introduced on its
own wave with a visual tell. Every five waves the run pauses and offers **one of three
cards** that change a mechanic rather than a percentage. Losing banks **Essence**, which
buys a **small, capped, quickly-maxed** permanent boost and then only ever buys *horizontal*
things — new cards, new rulesets, cosmetics. Monetisation is **cosmetics and content packs
only, at honest dollar prices, with no premium currency, no loot boxes, no ads, and no
progression for sale.** Everything else in this document is the argument for that paragraph
and the numbers that make it work.

### What this means for the existing build, in one line each

| Today | Recommendation |
|---|---|
| 6 elements, 15 dual towers, 21 tower defs | 4 elements, 8 branch end-states, 0 duals |
| 5 tiers at 50 / 175 / 788 / 3544 / 24444 gold | 5 levels at 50 / 40 / 70 / 120 / 200 gold |
| Damage 23 → 28,750 (Fire) | Damage 10 → 100 |
| Endless only, run always ends in a loss | Standard 20 waves with a win, Endless as a mode |
| 6-element damage circle | 4-element ring where every relation is physically obvious |
| Workshop: up to +79% damage, uncapped feel | Workshop capped at ~+25% total, maxed in ~20 runs |
| 8 enemy archetypes | 6 + boss |
| 3 maps in one endless run (chapters) | 3 maps × 3 rulesets = 9 levels, chosen by the player |

---

## Contents

| § | | § | |
|---|---|---|---|
| [1](#1-re-analysis-warcraft-iii-element-td) | Re-analysis of Element TD | [12](#12-game-session-length) | Session length |
| [2](#2-the-main-problem-too-many-towers) | The too-many-towers problem | [13](#13-child-friendly-design) | Child-friendly design |
| [3](#3-the-element-system-four-elements-as-the-whole-identity) | The four-element identity | [14](#14-content-expansion-strategy) | Content roadmap |
| [4](#4-tower-design-strategy) | Tower design (Models A–E) | [15](#15-mvp) | **MVP** |
| [5](#5-wave-design) | Wave design | [16](#16-post-mvp) | Post-MVP: v1.0 and future |
| [6](#6-map-strategy) | Map strategy | [17](#17-competitor-thinking) | Competitor lessons |
| [7](#7-player-progression) | Player progression | [18](#18-economy-model) | Economy model |
| [8](#8-in-app-purchase-strategy) | IAP strategy | [19](#19-player-journey) | Player journey |
| [9](#9-shop-design) | Shop design | [20](#20-final-recommendation) | **Final recommendation** |
| [10](#10-retention-without-coercion) | Retention | [21](#21-migration-applying-this-to-the-current-repo) | **Migration: this repo** |
| [11](#11-roguelite-elements) | Roguelite elements | [22](#22-the-rejected-list) | The rejected list |
| | | [—](#the-game-i-would-build) | **THE GAME I WOULD BUILD** |

---

# 1. Re-analysis: Warcraft III Element TD

## 1.1 What a run actually is

Eight players each get an **identical private arena** side by side on one map. **[EXTRACTED]**
Each arena is 80 × 118 pathing cells (2560 × 3776 world units) and its lane is a
**rectangular spiral wound inward four times**: 1,468 cells of lane against 2,300 cells of
buildable ground, 39% lane. Sixty waves march down it. You start with **30 gold and 50
lives**. When your lives hit zero your towers explode and the leaderboard renames you
"Schooled".

The loop is not "build towers, kill creeps". It is:

```
kill creeps  ->  earn gold  ->  DECIDE: spend now, or hold it for interest?
     ^                                          |
     |                                          v
  more towers  <- every 5 waves: one token -> DECIDE: element, interest, or pure essence?
```

Two decisions, repeated. Everything else in the map is decoration on those two.

## 1.2 Tower progression and the tier ladder

**[EXTRACTED]** Six elements. Each upgrades through five tiers named
`X Tower` → `Amplified X` → `Focused X` → `Refined X` → `Pure X`.

| Tier | Cost | Cost step | Damage step |
|---|---|---|---|
| 1 | 50 | - | - |
| 2 | 175 | ×3.5 | ×5 |
| 3 | 788 | ×4.5 | ×5 |
| 4 | 3,544 | ×4.5 | ×5 |
| Pure | 24,444 | ×6.9 | ×10 |

Fire runs 23 → 115 → 575 → 2,875 → **28,750** damage. Darkness ends at **206,241**.

**The rule that makes this work, and which we must keep:** *an upgrade multiplies damage
and nothing else.* **[EXTRACTED]** Fire is 500 range / 0.33 s cooldown as a 50-gold tower
and still 500 / 0.33 as Pure Fire. Range and cadence are fixed per element for the whole
game.

This is the best single structural decision in the map. It means the six elements never
converge: a maxed Fire is still short-ranged and twitchy, a maxed Darkness still swings
once every 2.75 seconds. Compare a TD where every upgrade adds range and speed: by tier 4
every tower is the same tower wearing a different colour.

**The rule that does not work:** those numbers. A player choosing between a 3,544-gold
upgrade and two 788-gold ones is doing arithmetic, not tactics. And a child cannot rank
6,875 against 8,250 at a glance. The *shape* of the ladder is right; the *magnitudes* are
a 2005 PC convention we have no reason to inherit.

## 1.3 The element system, and what "combination" actually means

Worth stating plainly, because almost everyone assumes otherwise: **the map has no
"merge two towers" mechanic.** **[EXTRACTED]** Each element is a *research track*
(`war3map.j`'s `Element_Upgrade[0..5]`). Which towers you may build is a question of
**which elements you own**:

- Own one element → its five-tier tower.
- Own two → the **dual** for that pair. 15 pairs.
- Own three → the **triple**. 20 triples.

That is 6 + 15 + 20 = **41 tower types**, at 5 / 3 / 2 tiers respectively — roughly
**115 distinct tower states**. Section 2 is about that number.

### How you get an element — the best mechanic in the map

**[EXTRACTED]** Every 5 levels, every living player receives **one lumber**. Sixty levels
means **twelve tokens across a whole game**. You spend a token at the "elemental summoning
centre" on one of three things:

1. **Summon an elemental** of an element. It walks your lane as a boss. **Kill it and you
   gain that element's power** (or its next level). **If it leaks you lose 3 lives.**
2. **+1% interest rate**, permanently, for the rest of the run.
3. A **pure elemental essence**, a *second gate*: without one you cannot upgrade any tower
   past tier 4.

Look at what option 1 actually does. You **pay** a scarce resource, you **risk** a real
cost, and you **earn** the reward by playing. That is why gaining an element in Element TD
feels like something, and why clicking a card in a modern roguelite often does not. A
reward that could have failed is remembered; a reward that is handed over is not.

**[EXTRACTED]** There is even a mode where you do not choose: typing `-random` before level
5 sets `udg_Random_Element`, after which the summoning centre offers a **random** element
(`GetRandomInt(0, 5)`, widening to `GetRandomInt(-1, 5)` to include the interest option).
The tip list calls it "Not for the weak at heart." That is a 2005 map inventing run
variance twenty years before every game had it.

## 1.4 Damage types and the matchup

**[EXTRACTED]** Every creep has an armour element, every tower has a damage element, and
the map resolves the pair through **Warcraft III's own built-in attack-type versus
armour-type table**. That is why `war3map.j` contains no `ATTACK_TYPE` reference at all,
and why the exact multipliers are **not recoverable from the map**. The cycle itself is
legible from the tower data: Light → Darkness → Water → Fire → Nature → Earth → Light.

The mechanic is excellent and **completely invisible while you play**. No icon, no colour
cue, no damage-number feedback. You learn it from the Quests menu, or by losing. This is
the clearest single example of a map designed for a player who will read documentation.

## 1.5 Enemies, waves and difficulty

**[EXTRACTED]** Sixty levels. Hit points are `hp(n) = 75 × 1.16^(n-1)` — level 1 is 75,
level 60 is 476,522, and the ratio is 1.16 the entire way, with **no breakpoints and no
boss spike baked into the curve**. (`war3map.j` declares `udg_HP_exponent_base = 1.23` and
then never reads it. It is a decoy. Trust the units.)

Ten creep classes, and a level can carry several at once — level 55 is monster + undead +
flying:

| Class | Levels carrying it | What it actually changes |
|---|---|---|
| humanoid / monster / animal / summoned | 53 | flavour only |
| mechanical | 7 | immune to Poison; cannot be instant-killed by Death |
| undead | 11 | cannot be instant-killed by Death |
| flying | 9 | ground-only towers cannot hit it |
| fast | 11 | speed 350–390 instead of 300 |
| resistant | 8 | magic resistance |
| healing | 9 | regenerates |

Note how few are *tactical*. Four of the ten labels change flavour and nothing else. The
real archetype set is **fast, flying, resistant, healing** — four ideas wearing ten names.

### Difficulty: one knob, two effects, and it is elegant

**[EXTRACTED]** Five named tiers, chosen from a dialog at the start:

| Tier | Creep HP | Creeps per wave | Bonus start gold |
|---|---|---|---|
| Very Easy | 50% | 18 | +0 |
| Easy | 62.5% | 21 | +7 |
| Normal | 75% | 24 | +15 |
| Hard | 87.5% | 27 | +22 |
| Very Hard | 100% | 30 | +30 |

The code is `SetUnitLifePercentBJ(unit, 50 + (difficulty-1) * 12.5)` and a spawn count of
`15 + difficulty * 3`. One selection scales both **how hard each enemy is** and **how many
there are**, and the underlying HP curve never changes. There is exactly one wave table in
the game, and five ways to meet it. We should steal this wholesale.

**[EXTRACTED] And it adapts.** Every 10 rounds `Trig_Adjust_Difficulty` checks how many
lives you lost, and if you were doing well it **promotes you a tier**, announcing "So well
in fact, that your difficulty is being increased to …". A flow-channel corrector with no
options menu, twenty years old.

### Bosses

**[EXTRACTED]** There are no scripted boss waves in the 60-level table at all. The only
bosses are **the elementals you summon yourself**: you buy one, it spawns at 50–100% health
depending on difficulty, it walks your lane, and killing it is how you progress.

**The boss *is* the progression system.** That is why the map needs no separate boss track,
and it is the idea most worth carrying forward — our bosses should *give* something, not
merely be larger.

## 1.6 Economy

**[EXTRACTED]** Four rules, and together they are the best-designed part of the map.

| Rule | Value |
|---|---|
| Starting gold | 30 |
| Bounty per kill | `max(level / 3, 1.10^(level-1) × (1 + 0.33 × money_tower_level))` |
| Interest | **2.5% of unspent gold every 15 seconds, uncapped**; +1% per token spent |
| Sell refund | **100%** of a non-elemental tower, **75%** of an elemental one |

**Interest is the engine of the whole game.** Every 15 seconds it asks: is this gold worth
more as a tower now, or as 2.5% compounding? Greed leaks. Caution falls behind the 1.16
curve. There is no correct answer, only a read of the next few waves. It converts an idle
timer into a decision — and, psychologically, it means that when you lose you lose to a
choice you made rather than to the game's arithmetic.

**Sell-back at 100% is the second-best rule.** Placement is not permanent. A player can
try a position, dislike it, and undo it for free. For a game whose entire skill ceiling is
*where you put things*, free undo is what makes learning possible.
**[BUILT]** Our refund is 50% (`tower.gd` `SELL_REFUND`), which taxes precisely the
behaviour a beginner needs.

## 1.7 Leaks: the most under-appreciated rule in the map

**[EXTRACTED]** When a creep reaches your exit, `Trig_Leak` does **not** delete it. It
creates an identical creep at your *entrance* carrying its current hit points and sends it
round again. You lose 1 life (3 if it was a summoned elemental) — and you keep the chance
at the bounty.

This is quietly brilliant. In most tower defenses a leak costs a life *and* the gold you
would have earned, so falling behind starves the economy that would let you catch up: the
death spiral. Element TD taxes the mistake without compounding it. The run stays winnable
from behind, which is exactly the state a player must be in to want to keep playing.

## 1.8 Multiplayer-inspired mechanics

**[EXTRACTED]** Two, and one is worth stealing in a solo game.

- **The race.** *"As soon as any player kills all monsters in a level, the next level will
  begin for all players. So if you're slow, you'll end up tons of creeps in your area."*
  Falling behind compounds into overlapping waves. Brutal, brilliant, unusable solo — but
  the *shape* of it (pulling the next wave early, at your own risk, for a benefit) survives
  as a solo mechanic, and **[BUILT]** already exists here as the HUD's "Send Next ▶" button
  and `Balance.early_call_bonus()`.
- **The scoreboard.** Lives per player, live, all game. A pure comparison engine. Solo,
  this becomes a personal best, and later a weekly leaderboard.

`Element TD 1.4` (Survivor) layers an **Elimination Mode** on the same wave table: last
player standing. Worth noting because it proves the *mode* was the cheapest content the map
ever shipped — no new towers, no new creeps, a different social frame. Section 12 uses that.

## 1.9 The board, and what it does to range

**[EXTRACTED]** Coverage measured from `war3map.wpm` on the map's own arena, one tower
against 367 lane samples:

| Range | Best spot covers | Median spot covers | Towers with it |
|---|---|---|---|
| 500 | 14% | 7% | Fire |
| 750 | 25% | 11% | Water / Nature / Earth |
| 2000 | **94%** | 58% | Light / Darkness |

**A Light tower watches 94% of its own lane on the original's own board.** State this
loudly, because it is tempting to assume our smaller board created the problem. It did not.
Element TD survives it only because Light arrives late, through a token draw, as one of 41
towers. In a four-tower game where everything is on the palette at wave 1, a tower that can
be placed anywhere is not a placement.

The buildable ground sits in **thick blocks between the arms of the spiral**, so a tower
has lane on two or three sides and a short-ranged tower must be pushed to the edge of its
block to reach anything. *That* is what makes range worth paying for — the geometry, not
the number. It is the lesson for §6.

## 1.10 Why it works: five psychological engines

Not a feature list. These are the reasons people played this map for years.

| Engine | Mechanic | Why it grips |
|---|---|---|
| **Recurring dilemma** | Interest every 15 s | A decision with no correct answer, repeated ~40 times a run. The player authors their own difficulty and therefore owns the outcome. |
| **Earned reward** | Summon a boss, kill it, gain an element | You paid, you risked, you executed. A reward that could have failed is remembered. |
| **Identity re-roll** | 12 token draws; `-random` mode | Every 5 waves the run's identity can change. The *same* wave table produces a different game. This is the roguelite loop, in 2005. |
| **Forgiving failure** | Leaks cycle again; 100% sell refund | Mistakes cost but never compound. A player who is behind can still believe they will catch up — the precondition for a retry. |
| **Legible pressure** | Waves announced with their classes; adaptive difficulty | You get the question before it is asked, so failure is attributable to you. Attributable failure is the only kind that motivates another attempt. |

## 1.11 KEEP / SIMPLIFY / CUT

### Keep

| Mechanic | Why |
|---|---|
| **Upgrades change damage only** | The one rule that stops the towers converging into one tower. Non-negotiable. |
| **Interest on banked gold** | The best decision in the genre. Keep the tension, add a cap (§18). |
| **Leaks cycle again** | Taxes the mistake without compounding it. |
| **Generous sell refund** | Free undo is what lets a beginner learn placement. Raise ours from 50% to 80%. |
| **The 1.16 HP curve** | Smooth, spike-free, proven over 60 levels, and already in `balance.gd`. |
| **One knob scales HP *and* count** | Elegant difficulty. Becomes our Easy / Normal / Hard rulesets. |
| **Wave telegraphing** | The next wave's identity, before it spawns. Ours does this **[BUILT]**; keep it, as icons. |
| **Range fixed per element, and *is* the identity** | Fire short and fast, Earth slow and heavy. |
| **Boss = progression, not just a big enemy** | Our boss should grant something, not merely die. |

### Simplify

| Mechanic | Problem | What it becomes |
|---|---|---|
| **41 towers / ~115 states** | Memorisation, decision paralysis, unbalanceable, unusable on a phone | 4 towers × 1 branch = **8 end-states** (§2, §4) |
| **6-element circle** | Six relations to hold, two of them arbitrary | **4-element ring** where every relation is physically obvious (§3) |
| **Invisible matchup** | Learned from a menu | A ×2 badge on the damage number and a ring under the enemy (§13) |
| **Token economy with 3 sinks** | Element / interest / pure-essence is three systems on one scarce currency | **One card choice every 5 waves** (§11) |
| **Cost ladder ×4.5 a tier** | Arithmetic instead of tactics; six-digit numbers | 50 / 40 / 70 / 120 / 200 (§4) |
| **Ten creep classes** | Four of them are flavour | **6 archetypes + boss** (§5) |
| **Adaptive auto-promotion** | Silently changing the rules confuses a child | The game *offers* the next ruleset after a 3-star clear (§6) |

### Cut

| Mechanic | Why it goes |
|---|---|
| **15 dual + 20 triple recipes** | The combination table is a memory test, and it is the reason the map ships a Quests menu. §2 quantifies it. |
| **The pure-essence second gate** | A gate on a gate; two token sinks competing for one scarce resource, explicable only in prose. |
| **`-random` element mode** | The *idea* survives as the card draw. In a four-element game there is nothing left to randomise. |
| **The 8-player race** | Requires other humans playing simultaneously. |
| **Class flavour (humanoid / monster / animal / summoned)** | Four labels that change nothing. |
| **Seventeen text tips** | See below. |

## 1.12 What confuses a child, with evidence

The map ships **seventeen in-game tips**, and they are the designer's own bug report. Read
them that way:

| # | Tip (abridged, **[EXTRACTED]** from `war3map.j`) | The bug it reports |
|---|---|---|
| 1 | "Every 5 levels all players get one lumber which you can spend at the elemental summoning center." | The core loop needs a sentence. |
| 2 | "You can summon elementals of the 6 basic elements. When you kill them you gain their power…" | The progression system needs a sentence. |
| 3 | "To upgrade your single-element towers past level 4, you need … a pure elemental essence for 1 lumber." | A hidden gate needs a sentence. |
| 4 | "Interest: Every 15 seconds you will get some bonus cash…" | The economy is invisible. |
| 5 | "Non-elemental tower refund 100%, Elemental towers refund 75%." | Two refund rates, neither shown. |
| 6 | "Any creeps that leak in your area will cycle through again…" | The best rule in the game is undiscoverable. |
| 7 | "Check Quests for all tower recipes and descriptions." | 35 recipes live in a documentation menu. |
| 8 | "Type '-<classification>' to see which levels are such." | The enemy schedule is behind a **chat command**. |
| 9 | "By level 30 you should have level 3 in at least 1 element." | The game cannot show you whether you are on pace, so it says so in prose. |

Every one of those is a mechanic that could not be *seen*. The design rule that falls out
of this list is the most important one in this document:

> **If a rule needs a sentence, it needs an icon instead.
> If it cannot have an icon, it should not be a rule.**

Add the things a child hits that no tip covers:

- **Names that do not say what they do.** "Amplified Nature", "Focused Water", "Refined
  Earth" — three words for "level 2, level 3, level 4". A child reads three unrelated
  towers.
- **Numbers that cannot be compared.** Is 6,875 a lot? Against 8,250? Against 476,522 hit
  points? Nothing on screen establishes scale, so numbers stop carrying information and
  become decoration.
- **A build decision with 41 options and no in-game guidance**, resolved by opening a
  documentation menu mid-match.
- **The matchup is felt as randomness.** With no feedback, "this tower is doing badly right
  now" is indistinguishable from bad luck — and a child who cannot attribute a loss cannot
  learn from it.

---

# 2. The main problem: too many towers

## 2.1 The size of the problem, in numbers

**[EXTRACTED]** Element TD:

| | Count | Tiers each | Distinct tower states |
|---|---|---|---|
| Elements | 6 | 5 | 30 |
| Duals | 15 | 3 | 45 |
| Triples | 20 | 2 | 40 |
| **Total** | **41** | | **115** |

**[BUILT]** Our project today: 22 entries in `Game.TOWER_DEFS` (6 elements at 5 tiers each,
15 duals, and Lightning), 6 of them on the palette, the rest gated behind element levels.

To play Element TD *well* you must hold in memory: 41 tower identities, 35 recipes, which
of six elements each recipe needs, a five-tier cost ladder with six-digit numbers, six
matchup relations, and ten creep classes. That is not depth. **Depth is a decision you can
make; that is a lookup you must perform.**

## 2.2 The four costs a large roster imposes

1. **Decision paralysis.** A choice among 41 options with no visible ranking is not
   experienced as freedom. Players resolve it the cheapest way available: they copy a build
   from a forum and stop choosing. The roster's variety is then *consumed by one person
   once* and never again.
2. **Memorisation replaces play.** When the answer lives in a recipe list, the skill being
   tested is recall, not reading the board. A child has neither the recall nor the patience.
3. **Unbalanceable.** 41 towers × 60 waves × 10 creep classes is a matrix nobody balances;
   in practice 5–8 towers are correct and the other 33 are flavour. **Most of the content
   is dead weight that still costs art, code and test time.**
4. **Unusable on a phone.** A 41-item palette on a 6-inch screen in landscape is a scroll
   list over the play field. Every tap is ambiguous. Our own board already gives up 240
   world px to a 6-item palette (**[BUILT]** `Game.PLAY_RIGHT`), and it eats clicks — a
   tower under it can never be upgraded or sold.

## 2.3 The alternative: depth from combinations *of few things*

Compare two ways to reach the same amount of variety.

| | Roster-first (Element TD) | Run-first (recommended) |
|---|---|---|
| Towers to learn | 41 | **4** |
| End-state towers | 115 states | **8** |
| Things memorised before you can play well | 35 recipes + 6 relations | **4 jobs + 4 relations** |
| Distinct *games* available | one per build the meta settles on | one per (branch set × card set × ruleset) |
| Combinations, counted | 41 towers, mostly unused | 4 towers × 2 branches = 16 branch-sets, × ~15 card outcomes ≈ **thousands of run shapes** |
| Cost per unit of variety | one tower = art + code + balance + tooltip | one card = **one data row** |
| Content expansion | a new tower needs 3 tiers of art | a new card needs a line of text |

The second column is not a compromise. **It produces more variety per unit of player
memory, and far more variety per unit of development cost.** §11 does this arithmetic
properly.

## 2.4 Direct answers to the ten questions

| Question | Answer | Reasoning |
|---|---|---|
| **How many towers should a new player initially have?** | **4**, all available in the first match. | Four is one palette row, four colours, four shapes. Nothing is drip-fed: the game must feel complete at minute one, and hiding half the game to create a fake unlock is the pattern this project should be known for *not* doing. |
| **How many should eventually exist?** | **4 at launch → 6 by year one → 7 ceiling.** With branches that is 8 → 12 → 14 end-states. | Seven is the point where a player can still name every tower's job. Past that, the roster becomes a lookup again. Element TD is the proof. |
| **How many tower choices during a single match?** | **4 palette icons.** The *decisions* per match are ~10 placements, ~6 branch choices, 4 card choices. | ~20 real decisions in 12 minutes is a dense, readable match. 41 icons is not more decisions, it is more scrolling. |
| **Should towers be unlocked permanently?** | **No for the core four. Yes for post-launch elements**, unlocked by a one-time mastery goal (not a grind, not a purchase). | Permanent unlocks that gate *core* play punish new players and make the first hour a demo. Unlocks that add a *fifth* option after the player has mastered four are a reward. |
| **Should some towers appear only during specific runs?** | **No towers. Yes cards.** Every tower is always available; the *cards* differ every run. | Run-scoped towers mean the run you wanted is unavailable, which reads as the game withholding. Run-scoped modifiers read as the run being different. Same variance, opposite feeling. |
| **Should towers evolve?** | **Yes — 5 levels, with one branch at level 3.** | Evolution is the cheapest legible depth in the genre: one tower, one decision, two outcomes, no new palette icon. |
| **Should towers combine?** | **No.** | Combination is the single mechanic that forces a recipe list, and the recipe list is what forces the Quests menu. Everything combination gives us, branching gives us with the decision *on the tower you are already looking at*. |
| **Should elemental combinations exist?** | **Not as towers.** As **cards** that cross elements: "Steam — Fire towers within range of a Water tower add a burn." | Preserves the *fantasy* of combination (Fire + Water = Steam) and its emergent placement puzzle, without a 15-row recipe table. This is the one place I would spend complexity. |
| **How many upgrade levels?** | **5**, with the branch at 3. Costs 50 / 40 / 70 / 120 / 200. | Five is enough for a visible growth arc and short enough that a maxed tower is reachable in a 20-wave match. The branch at 3 (not 2 or 4) means the player has seen the tower work before committing, and still has two levels to enjoy the commitment. |
| **Should upgrades change only stats or also mechanics?** | **Levels 2 and 4 change stats. Levels 3 and 5 change mechanics.** | Alternating gives every upgrade *something* while making two of them events. All-stats is dull; all-mechanics is unreadable. |

## 2.5 What happens to the towers we already have

**[BUILT]** The project contains 15 dual towers with real ported data (`Game.DUAL_RECIPES`,
`TOWER_DEFS`), and their *roles* are excellent: Money pays bounty on kill, Well is an
attack-speed aura, Death is an execute chance, Magic banks charges into a burst.

**Do not delete the design work — relocate it.** Every dual role becomes either a **branch
level-5 ultimate** or a **card**:

| Dual (map role) | Becomes |
|---|---|
| Well — attack-speed aura | Nature branch B "Grove" aura |
| Money — bounty on kill | Nature branch B gold trickle, and the "Prospector" card |
| Death — execute chance | Nature level-5 "Plague" ultimate rider |
| Ice — slowing splash | Water branch A "Glacier" |
| Lava / Steam — splash + burn | Fire branch B "Mortar" → "Volcano" |
| Clay / Roots — slow on hit | Water level-2 Chill, Earth branch A stun |
| Tech — very high rate of fire | The "Overclock" card |
| Magic — banks charges into a burst | The "Charge" card (already has a `TowerBehavior`) |

Fifteen towers of content survive as **two branch trees and four cards**, and the player
never opens a recipe list.

---

# 3. The element system: four elements as the whole identity

## 3.1 One job each, one sentence, one shape

| Element | Colour | Shape | The one sentence | Its job in a fight |
|---|---|---|---|---|
| **Fire** 🔥 | orange | triangle | *"Burns things down."* | Sustained single-target damage. Burn ticks on. The answer to anything with a lot of hit points and no friends. |
| **Water** 💧 | blue | droplet | *"Slows things down."* | Control. Chill on every hit. Buys every other tower more shooting time. The answer to *fast*. |
| **Earth** 🪨 | brown | hexagon | *"Hits hard, hits many."* | Slow, heavy, splash. Cracks armour. The answer to *crowds* and *armour* — but it cannot hit the sky. |
| **Nature** 🌿 | green | leaf | *"Poisons and helps."* | Poison that ignores armour and suppresses healing, plus auras that make neighbours better. The answer to *healers*, *swarms*, and to a thin economy. |

Every one of those sentences is true of the tower at level 1 and still true at level 5.
That is the test a job description has to pass.

## 3.2 The matchup ring, and why four is better than six

**[BUILT]** The current ring is Light → Darkness → Water → Fire → Nature → Earth → Light.
Drop Light and Darkness and the remainder closes on itself perfectly:

```
        WATER  ──beats──▶  FIRE
          ▲                  │
          │                beats
        beats                │
          │                  ▼
        EARTH  ◀──beats── NATURE
```

- **Water beats Fire** — water puts out fire.
- **Fire beats Nature** — fire burns plants.
- **Nature beats Earth** — roots split stone.
- **Earth beats Water** — earth dams and soaks up water.

**Every relation is physically obvious to an eight-year-old and needs no explanation at
all.** Compare the six-element version, where "Earth beats Light" and "Light beats
Darkness" are conventions you must be told. This is the strongest single argument for
cutting to four, and it is worth more than the extra content the two lost elements carry.

Practically it is also a **one-line change**: `Game.ELEMENT_BEATS` becomes
`{"water": "fire", "fire": "nature", "nature": "earth", "earth": "water"}` — the three
surviving relations are already there, and only `earth` re-targets from `light` to `water`.

### The multipliers should be asymmetric

**[BUILT]** Today: ×1.75 strong, ×0.7 weak. Recommendation: **×2.0 strong, ×0.8 weak.**

| | Value | Why |
|---|---|---|
| Strong | **×2.0** | "Double damage" is a concept a child already owns. 1.75 is a number they must be told. The damage popup can simply read **×2**. |
| Weak | **×0.8** | Deliberately gentler than the reward. Correct play should be *loud*; incorrect play should be *quiet*. A player who builds the wrong tower should notice it is not working, not be punished into a loss. **[BUILT]** the code comment on `ELEMENT_WEAK` records that 0.6 read as a difficulty spike — this pushes further the same direction. |

**Design principle worth stating once and applying everywhere: reward-forward asymmetry.**
For a young audience, make the upside legible and the downside survivable.

## 3.3 What happens to Light and Darkness

They are **[BUILT]** — full stat blocks, five tiers of painted art each, tutorial lessons,
dual recipes. Deleting them destroys real assets. Three options:

| Option | Advantages | Disadvantages |
|---|---|---|
| **A. Delete outright** | Cleanest codebase; no dead data | Throws away 10 painted tower sprites and working data |
| **B. Keep buildable, 6-element ring** | No work at all | Keeps a 6-slot palette and two arbitrary matchup relations — the exact problem being solved |
| **C. Retire to the shelf, return as a paid/earned content pack (recommended)** | 4-element launch; the art becomes the first *expansion* rather than a loss; gives the roadmap a ready-made Update 1 | The defs sit unused for a few months |

**Choose C.** Remove `light` and `darkness` from `Game.TOWER_ORDER` and from
`ELEMENT_BEATS`; leave their `TOWER_DEFS` entries and their `assets/art/towers/` sets in
the repo, unreferenced. When the fifth element ships (§14), **Light returns as "Storm" or
returns as Light** with the ring extended to five in a *pentagon* (each beats the next two,
loses to the previous two) — or, better, as an **element that sits outside the ring
entirely and always deals ×1**, which is a genuinely different design space and needs no
new relations to memorise.

## 3.4 The child test

Show a 9-year-old four icons for five seconds, then ask: *"A big slow armoured monster is
coming. Which one?"*

- With four elements: they point at the brown hexagon, because "hits hard" was the sentence.
- With six: they hesitate between brown, white and purple, because Light and Darkness have
  no physical job — they are *ranges*, and range is not a fantasy a child reaches for.

That is the real reason Light and Darkness go. Not the palette width. **They have no
one-sentence job that a child can imagine before they see the numbers.**

---

# 4. Tower design strategy

## 4.1 The five models, compared

| | **A** 4 elements × several upgrade paths | **B** 4 towers → subclasses | **C** roguelite in-match upgrades | **D** fusion / combination | **E** hybrid (B + C) |
|---|---|---|---|---|---|
| Palette size | 4 | 4 | 4 | grows to 15+ | **4** |
| Things to memorise | paths per tower | 2 subclass names per tower | card texts (read at the moment of choice) | recipe table | 2 names per tower |
| Decision moments per match | many small | ~6 meaningful | ~4 meaningful | ~4 heavy lookups | **~10 meaningful** |
| Run-to-run variety | low | low | **high** | medium | **high** |
| Mobile UI | good | good | good (a full-screen card moment) | poor | **good** |
| Balance surface | 4 × paths | 8 towers | 4 towers × N cards | 15+ towers × tiers | 8 towers × N cards |
| Cost of new content | new path art | new subclass art | **one data row** | new tower + art + tiers | one row *or* one subclass |
| Child-readable | yes | **yes** | partly (text) | no | **yes** |
| Long-term depth | low | medium | medium | high | **high** |

**Model A** is where the current build sits **[BUILT]** — five tiers that only change
damage. It is readable but flat: after the first run there is nothing new to decide.

**Model D** (fusion) is Element TD, and §2 is the case against it.

**Model C** alone is a survivors-like: high variety, but the towers themselves stop
mattering and the game becomes "read three cards, repeat". A tower defense's core pleasure
is *placement*, and Model C does not reward placement.

**Model B** alone gives towers identity and a real decision but only one decision per
tower, so run 5 plays like run 1.

## 4.2 Recommendation: **Model E**

> **4 base towers → 5 levels → one branch decision at level 3 → 2 distinct level-5
> ultimates, plus one card choice every 5 waves.**

Why this one:

- **The palette never grows.** Four icons forever. That is what keeps it a phone game.
- **The decision is on the object you are already looking at.** Tap a tower, see two big
  cards with an icon and four words. No menu, no recipe list, no cross-referencing.
- **Branches give *identity*; cards give *variance*.** They are the two different jobs, and
  neither can do the other's. Branches make this run's Fire tower a specific thing; cards
  make this run's Fire *strategy* a different thing from last run's.
- **Content expands along both axes independently.** A new card is a data row. A new
  branch is one tower's art. A new element is the only expensive item, and there should
  only ever be two or three more of those.
- **It balances.** Eight end-states against six enemy archetypes is a 48-cell matrix. One
  person can hold that in their head and test it.

## 4.3 The upgrade ladder

Same for every element. **Damage only, except at the branch.**

| Level | Cost | Cumulative | Damage | What changes |
|---|---|---|---|---|
| 1 (build) | 50 | 50 | ×1.0 | — |
| 2 | 40 | 90 | ×1.8 | stats |
| 3 | 70 | 160 | ×3.2 | **BRANCH: choose A or B.** Mechanic changes. |
| 4 | 120 | 280 | ×5.6 | stats |
| 5 | 200 | 480 | ×10.0 | **ULTIMATE.** Mechanic changes again. |

Reading the ladder:

- **Damage ×10 across five levels**, in steps of ~×1.78. Displayed damage for Fire is
  **10 / 18 / 32 / 56 / 100** — every number comparable at a glance, all of them under
  four digits, and the shape identical to the map's (compounding, damage-only).
- **Cost 50 / 40 / 70 / 120 / 200**, total **480**. Note level 2 is *cheaper* than the
  build: upgrading the tower you have should be the obviously-affordable move early, so a
  new player learns upgrading before they learn spamming.
- Compare **[EXTRACTED]** Element TD's 50 / 175 / 788 / 3544 / 24444 (total 28,999). Same
  five levels, same damage-only rule, numbers a human can hold.
- **Range and fire interval never change with level** — the map's rule, kept. They change
  only at the branch, which is what makes the branch feel like a different tower.

## 4.4 The eight towers, concretely

Level-1 stats are tuned to near-equal DPS with different *shapes*, exactly as Element TD
balances its six.

| Element | Lv1 damage | Interval | DPS | Range | Rider |
|---|---|---|---|---|---|
| **Fire** | 10 | 0.40 s | 25 | 170 px | Burn 4/s for 2 s |
| **Water** | 6 | 0.25 s | 24 | 210 px | Chill −25% speed, 1.5 s |
| **Earth** | 34 | 1.40 s | 24 | 200 px | Splash 90 px at 50%. **Ground only.** |
| **Nature** | 12 | 0.90 s | 13 | 220 px | Poison 12/s for 3 s (≈ 36, ignores armour) |

### 🔥 FIRE — *burns things down*

```
Lv1-2  Ember          fast single target, small burn
   |
   +-- A  BLAZE   Lv3  interval 0.40 -> 0.28. Burn STACKS to 3.
   |          Lv4  stats
   |          Lv5  INFERNO — when a burning enemy dies, its burn jumps to
   |               the nearest enemy. Anti-tank, anti-chain.
   |
   +-- B  MORTAR  Lv3  interval 0.40 -> 1.10, range 170 -> 240, splash 100 px.
              Lv4  stats
              Lv5  VOLCANO — the impact leaves a burning patch for 4 s.
                   Anti-swarm, anti-corner.
```

### 💧 WATER — *slows things down*

```
Lv1-2  Frost          rapid weak hits, chill on every hit
   |
   +-- A  GLACIER Lv3  chill -25% -> -45%; every 4th shot chills ALL enemies in range.
   |          Lv4  stats
   |          Lv5  ABSOLUTE ZERO — 15% chance to FREEZE (full stop, 1 s).
   |               The crowd-control anchor a defence is built around.
   |
   +-- B  TORRENT Lv3  each shot chains to 2 extra enemies at 60% damage.
              Lv4  stats
              Lv5  RIPTIDE — each chain jump deals 25% MORE than the last.
                   Rewards packed lanes; the damage-shaped Water.
```

### 🪨 EARTH — *hits hard, hits many*

```
Lv1-2  Boulder        slow heavy splash, GROUND ONLY
   |
   +-- A  QUAKE   Lv3  splash 90 -> 140 px; hits briefly stagger (0.4 s).
   |          Lv4  stats
   |          Lv5  FISSURE — splash also slows by 30% for 2 s.
   |               Turns a corner into a kill box.
   |
   +-- B  SIEGE   Lv3  splash 90 -> 60 px, damage +60%; hits CRACK armour:
              Lv4  the target takes +25% damage from everything for 3 s.
              Lv5  SUNDER — the crack spreads to enemies within 80 px.
                   The answer to bosses and armoured waves.
```

### 🌿 NATURE — *poisons and helps*

```
Lv1-2  Thorn          medium hits, poison DoT that ignores armour
   |
   +-- A  BLIGHT  Lv3  poison +80%; when a poisoned enemy dies the poison
   |          Lv4  spreads to everything within 90 px.
   |          Lv5  PLAGUE — poison stacks up to 3 times.
   |               Anti-swarm, anti-healer, anti-splitter.
   |
   +-- B  GROVE   Lv3  becomes a SUPPORT tower: towers within 160 px gain
              Lv4  +15% attack speed, and kills in that radius pay +1 gold.
              Lv5  HEARTWOOD — the aura also gives +12% damage, and a kill
                   inside it has a 3% chance to restore a life.
```

**Eight ultimates. Eight sentences. That is the entire roster a player must know**, against
Element TD's 41 towers and 35 recipes.

## 4.5 What makes a branch a real decision

A branch is only a decision if **neither option is generally better**. The test is that
each branch is the *unique* answer to at least one enemy archetype:

| Enemy problem | Blaze | Mortar | Glacier | Torrent | Quake | Siege | Blight | Grove |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Single big Brute | **✔** | | | | | **✔** | | |
| Dense Swarm | | **✔** | **✔** | **✔** | **✔** | | **✔** | |
| Fast runners | | | **✔** | | **✔** | | | |
| Flyers | ✔ | ✔ | ✔ | ✔ | ✖ | ✖ | ✔ | n/a |
| Menders (regen) | | | | | | | **✔** | |
| Splitters | | **✔** | | **✔** | **✔** | | **✔** | |
| Thin economy | | | | | | | | **✔** |

Every column is the sole or best answer to something. No column is empty. That is the
balance target, and it is small enough to verify by playing.

## 4.6 Levels change stats; branches and ultimates change mechanics

Restating the rule from §2.4 because it is the one most likely to erode:

| Level | Kind of change | Player experience |
|---|---|---|
| 2 | stats | "It got stronger." — cheap, frequent, satisfying |
| **3** | **mechanic (branch)** | "I chose what this tower *is*." — the big moment |
| 4 | stats | "It got stronger." — pays for the commitment |
| **5** | **mechanic (ultimate)** | "It does a new thing now." — the payoff |

Two events per tower, not five. If every level were a mechanic, a board of ten towers would
carry twenty rules and be unreadable. If none were, upgrading would be a slider.

## 4.7 Why not more branches, or a third branch option

- **A third option at level 3** turns a two-card popup into a three-card popup and adds
  50% more balance surface for no new *kind* of decision. Rejected: bigger, not funner.
- **A second branch at level 5** (2 × 2 = 4 end-states per element, 16 total) is tempting
  and is what Bloons TD 6 effectively does. Rejected for launch: 16 end-states is past the
  point where a player can name them all, and it doubles art. **Reserve it as the year-two
  expansion** — it extends the roster without adding a palette icon, which makes it the
  single best late content lever this design has.

---

# 5. Wave design

## 5.1 The philosophy: a wave is a question

A wave that is only "+10% hit points" asks nothing. The player does what they did last
wave, and the game is a slider being dragged.

**A wave should ask a question the player's current board cannot answer.** The answer is
always one of: *build a different element*, *branch differently*, *reposition*, or *spend
now instead of banking*. If a wave cannot be answered by one of those four, it is not a
wave, it is a delay.

The corollary: **the growth curve is the floor, not the content.** Keep
**[EXTRACTED]** `hp(n) = 75 × 1.16^(n-1)` — it is smooth, spike-free and already in
`balance.gd` — and put all the actual design into *which archetype arrives when*.

## 5.2 The smallest set of archetypes that generates interesting problems

**Six plus a boss.** Each is one problem, one counter, one silhouette.

| # | Archetype | The problem it poses | Countered by | First seen | Visual tell (no text) |
|---|---|---|---|---|---|
| 1 | **Runner** | none — it is the baseline that teaches everything else | anything | **W1** | plain, mid-size, walks |
| 2 | **Sprinter** | crosses a tower's range before a slow tower can fire twice | Water (chill), high-rate Fire, coverage near the entrance | **W3** | small, leaning forward, dust trail, visibly faster |
| 3 | **Swarm** | single-target DPS cannot keep up with the *count* | Earth splash, Mortar, Blight, Torrent | **W5** | many tiny bodies, tight cluster |
| 4 | **Brute** | high HP *and* takes 40% less damage | Siege (armour crack), Nature poison (ignores armour), Blaze | **W7** | huge, slow, plated shoulders, a shield glint on hit |
| 5 | **Flyer** | ignores nothing but **Earth cannot hit it**; often takes a shorter visual line | everything except Earth | **W9** | in the air, with a ground shadow |
| 6 | **Mender** | heals itself continuously unless damage is sustained | Nature poison (suppresses regen), any continuous DPS | **W12** | pulsing green cross above it; the pulse *stops* while suppressed |
| — | **Splitter** | killing it creates two smaller ones — the "graduation" archetype | splash to clean up children; Blight | **W15** | visibly cracked, seams glowing |
| B | **Boss** | one rule, plus a lot of hit points | build-dependent | **W10, W20** | crowned, screen-filling, its own health bar at the top |

**[BUILT]** The project already has all of these as `Game.WAVE_TYPES` rows: `normal`,
`fast`, `swarm`, `tank`, `immune`, `regen`, `air`, `split`. The change is a *merge*, not a
build.

### Rejected archetypes, with reasons

| Archetype | Why not |
|---|---|
| **Magic-resistant** (separate from armoured) | Two "resistant" concepts is one too many. **[BUILT]** merge `immune` into `tank` → **Brute**: high HP, damage reduction, ignores slow and stun, but **not** poison. One enemy, three implications, one silhouette. |
| **Stealth / invisible** | On a 6-inch screen an enemy you cannot see is not a puzzle, it is a bug report. Unfair by construction for the target audience. |
| **Shielded** (a second health bar) | The same idea as armoured with an extra UI element. Two bars is the beginning of a stat readout. |
| **Healer / support enemy** | It makes the *other* enemies the problem, so the player cannot see why their damage stopped working. High confusion, low tactical yield. Mender heals only itself, which is legible. |
| **Miniboss** | An "elite" wave — fewer enemies, each much tougher — delivers the same spike using an archetype that already exists. **[BUILT]** `wave_generator.gd` already has `ELITE_EVERY`. No new entity. |

## 5.3 Wave progression: waves 1–20 (Standard mode)

The teaching schedule. Each new idea gets its own wave, alone, with nothing else new.

| Wave | Composition | What it teaches | New? |
|---|---|---|---|
| 1 | Runner ×9, slow | Build a tower. Watch it shoot. | build |
| 2 | Runner ×10 | Upgrade a tower (gold now allows it). | upgrade |
| 3 | **Sprinter** ×13 | Fast things escape. Water helps. | **archetype** |
| 4 | Runner ×12, Fire armour | **First armour element.** Water pops ×2 gold numbers. | **matchup** |
| 5 | **Swarm** ×26 | One tower cannot do it. Splash, or more towers. → **CARD 1** | **archetype + card** |
| 6 | Sprinter ×15, Water armour | Apply the matchup under pressure. | — |
| 7 | **Brute** ×5 | Big, armoured, slow. Poison and Siege. | **archetype** |
| 8 | Swarm ×28, Nature armour | Two problems at once, first time. | stacking |
| 9 | **Flyer** ×12 | Earth misses. Coverage must be mixed. | **archetype** |
| 10 | **BOSS: The Warden** | Immune to slow. Cannot be chilled out of the problem. → **CARD 2** | **boss + card** |
| 11 | Swarm ×30 + Sprinter ×8 | First mixed wave. | mixing |
| 12 | **Mender** ×10 | Heals unless you sustain damage. Poison. | **archetype** |
| 13 | Brute ×7, Earth armour | Nature is the answer, and it also stops the healing. | — |
| 14 | Flyer ×16, Fire armour | Air + matchup. | — |
| 15 | **Splitter** ×10 → 20 | Kills make more. → **CARD 3** | **archetype + card** |
| 16 | Elite Brute ×3 | Fewer, far tougher. A spike. | elite |
| 17 | Swarm ×32 + Mender ×6 | The healer hides inside the crowd. | mixing |
| 18 | Sprinter ×20, Water armour | Speed under a bad matchup. | — |
| 19 | Flyer ×14 + Splitter ×8 | Splitting flyers. The last combination. | mixing |
| 20 | **BOSS: The Warden, Awakened** | Same boss, faster, spawns Swarm as it walks. → **CARD 4**, then **YOU SURVIVED** | **finale** |

Two properties of that table worth naming:

1. **Nothing new appears in the last five waves.** Waves 16–20 recombine what waves 1–15
   taught. A finale should test mastery, not introduce a rule.
2. **Cards land on 5 / 10 / 15 / 20** — after the waves that *hurt*. A card is most
   valuable emotionally right after the player has been shown a hole in their defence.

## 5.4 Bosses: a boss must have a rule, not just a health bar

**[BUILT]** Today a boss is `hp ×6, speed ×0.6, reward ×10, costs 10 lives`. That is a big
Runner: it changes no decision.

Each boss gets **one rule, shown as an icon on its health bar**:

| Boss | Rule | The decision it forces |
|---|---|---|
| **The Warden** (W10) | **Immune to slow.** | Water cannot solve this. You need real damage, and you need it *before* the exit. |
| **The Warden, Awakened** (W20) | Immune to slow, and **sheds a Swarm every 5 seconds**. | Splitting attention: kill the boss or clear its trail? |
| *(v1.0)* **The Cinder Colossus** | **Heals 5% each time it damages you.** | Leaks are no longer only a life cost. |
| *(v1.0)* **The Rootless** | **Splits into 3 at 50% health.** | Save your splash for the second half. |

Boss numbers: **HP ×8** of the wave curve, **speed ×0.7**, **reward ×12**, **costs 5
lives** on leak.

**[BUILT]** the current 10-life boss cost is half a 20-life run for one mistake. For a
young audience that is a run-ender disguised as a penalty. Five is felt and survivable.

## 5.5 Telegraphing: the player gets the question first

**[BUILT]** The HUD already emits a `wave_preview` with archetype, count, boss flag and
armour colour. Keep it, and make it **entirely visual**:

```
   NEXT ▸  [🪨 armour ring]  [swarm icon] ×26        (no words at all)
```

- The archetype **icon** is the same silhouette the enemy will have.
- The armour **ring colour** is the same ring drawn under the enemy on the board
  (**[BUILT]** `enemy.gd` already draws that ring).
- The count is a numeral.

A child reads that in under a second and knows to build brown. That is the entire wave
telegraph, and it replaces **[EXTRACTED]** Element TD's "Level 22: Couatl (Monster,
Flying) – 24 spawns" *and* its `-flying` chat command.

---

# 6. Map strategy

## 6.1 What actually creates replayability in a TD map

Not the number of maps. Three things:

1. **Where the good spots are, and how few of them there are.** A map is interesting when
   two towers want the same square. **[EXTRACTED]** Element TD's spiral does this by
   putting buildable ground in thick blocks *between* the lane's arms, so a short-ranged
   tower must be pushed to the block's edge to reach anything at all.
2. **How long the road is relative to tower range.** This is the single number that decides
   whether the map is about coverage or about kill boxes.
3. **What the map forbids.** Blocked water, a cliff, a strip you cannot build on. A
   constraint generates more decisions than an open field twice its size.

A second *painting* adds none of those on its own. A second *rule-set* adds all three.

## 6.2 Recommendation: 3 maps × 3 rulesets = 9 levels

| | Alternative | Advantages | Disadvantages |
|---|---|---|---|
| A | **10+ hand-made maps** | Obvious variety; each is a "level" | 10 paintings, 10 road traces, 10 balance passes. Most players see three. |
| B | **Procedural maps** | Infinite | A TD map's quality *is* its hand-tuned choke points; procedural produces readable-but-flat boards, and it removes the mastery of knowing a map |
| C | **3 maps × 3 rulesets** *(recommended)* | 9 distinct levels from 3 paintings; the third playthrough of a map is a *different problem*, and the player's map knowledge still pays | Needs the rulesets to genuinely differ, not just scale numbers |

**Choose C.** **[BUILT]** the project already has three painted boards with traced roads
(`winding`, `spiral`, `s` — `Game.BOARD_SEQUENCE`), which is exactly the launch content
this needs. Today they are *chapters of one endless run*; they become *three chosen levels*.

### What a ruleset changes

| | Easy | Normal | Hard |
|---|---|---|---|
| Creep HP | 70% | 100% | 135% |
| Creep count | 85% | 100% | 115% |
| Starting gold | 150 | 120 | 100 |
| Lives | 25 | 20 | 15 |
| Road variant | short (skips a loop) | full | full **+ a second entrance from wave 12** |
| Buildable ground | all clear ground | all clear ground | **one block closed off** |
| Modifier | none | none | **one** (see below) |

The HP/count pair is **[EXTRACTED]** Element TD's own difficulty design, re-fitted. The
road and ground variants are what make Hard a *different map* rather than a bigger number —
and both are cheap: **[BUILT]** `Game.configure_board()` already takes a path, obstacles
and build zones as parameters, so a ruleset is a second profile over the same painting.

### The modifier list (Hard only, one per map)

Deliberately short, and deliberately never *hidden* information:

| Modifier | Effect | The decision it forces |
|---|---|---|
| **Downpour** | Fire burn duration −40% | Fire is not the default answer here |
| **Rockslide** | One buildable block closed; +40 starting gold | Fewer spots, richer per spot |
| **Thin Air** | Flyers appear 3 waves earlier | Earth is a liability, plan around it |
| **Rich Veins** | +2 gold per kill, but −5 starting lives | Aggressive economy, no safety net |

Rejected modifiers: **fog / limited vision** (unreadable on a phone and unfair),
**destructible scenery** (a second tap target competing with towers), **moving paths
mid-wave** (breaks the one promise a TD makes).

## 6.3 Mobile readability rules

Hard constraints, not preferences. **[BUILT]** the world is 1536×864 framed at one zoom
with no panning, which is already the right call — keep it and enforce these:

1. **One screen. No scrolling, ever.** A leak you cannot see is a bug from the player's
   side.
2. **One path, with at most one optional branch that rejoins.** Two independent lanes
   double the attention cost and halve the tower value; on a phone the player simply loses
   one of them.
3. **The road is at least 80 px wide at world scale**, so a boss (76 px) fits on it and a
   swarm reads as a column rather than a smear.
4. **The UI's footprint is part of the map.** **[BUILT]** `Game.PLAY_TOP` / `PLAY_RIGHT`
   already derive the covered strip from the HUD and palette. Keep the road out of it.
5. **Never more than ~12 buildable "good" spots**, or the board becomes a filling exercise
   rather than a placement decision.
6. **Every rule the map imposes must be visible in the painting.** Water is painted water;
   a closed block is painted rubble. **[BUILT]** `grid.gd` shading the illegal ground
   *during a drag* is the right compromise for margins the painting cannot show.

## 6.4 How many maps, over time

| Milestone | Maps | Rulesets | Levels | Stars available |
|---|---|---|---|---|
| MVP | 1 | 2 | 2 | 6 |
| v1.0 | 3 | 3 | 9 | 27 |
| +6 months | 5 | 3 | 15 | 45 |
| Content pack | +3 | 3 | +9 | +27 |

Three stars per level: **clear it** / **lose ≤5 lives** / **lose 0 lives**. Star criteria
must be about *play*, never about time spent.

---

# 7. Player progression

## 7.1 The filter every system must pass

For each proposed system, one question: **what player motivation does it serve, and does
anything else already serve it?** If two systems serve the same motivation, ship one.

The motivations, in the order they matter for this audience: **mastery**, **discovery**,
**achievement**, **collection**, **experimentation**, **competition**, **customisation**.

## 7.2 The four systems to keep

| System | Motivation | What it does | Numbers |
|---|---|---|---|
| **Map stars** | achievement | The spine. 3 stars per level; stars unlock the next map. | 6 at MVP → 27 at v1.0. Unlock map 2 at 4 stars, map 3 at 12. |
| **Account level** | discovery | Slow XP from every run. Each level unlocks **one new card into the run pool** — so levelling up literally makes future runs more varied. | 20 levels. Level *n* costs `100 × n` XP; a run pays `wave_reached × 8` XP. Level 20 at ~35 runs. |
| **Element mastery** | mastery | Per-element XP from damage dealt by that element. Unlocks that element's **skins** and one **element-specific card** each. | 5 tiers per element. Tier 5 in all four ≈ 60 runs of varied play — and it *rewards using all four*, which is the behaviour the design wants. |
| **Weekly challenge** | competition + discovery | One fixed seed + one forced modifier, same for everyone, resets Monday. Optional leaderboard. | 1 per week. No penalty for missing it, ever. |

That is four systems, four distinct motivations, no overlap.

## 7.3 The systems to cut, and why

| System | Verdict | Why |
|---|---|---|
| **Daily missions** | **Cut** | Converts play into a checklist. "Kill 200 enemies with Fire" makes the player play *worse* on purpose. Serves retention metrics, not the player. |
| **Login streaks / daily rewards** | **Cut** | Punishes absence. The stated goal is "I want to play another match", not "I must log in". |
| **Energy / lives system** | **Cut** | The single most player-hostile mechanic in mobile, and unacceptable for a young audience. |
| **Battle pass with a countdown** | **Cut** | Manufactured urgency aimed at children. If seasonal content ships, it stays available. |
| **Achievements as a separate list** | **Cut** | Duplicates stars and mastery. Three achievement systems is one achievement system with extra menus. |
| **Difficulty levels as a separate progression track** | **Fold in** | They are the rulesets (§6). Not a fifth system. |
| **Endless mode** | **Keep as a MODE, not progression** | It is where "how deep can I get" lives, but it must not be the default (§12). |
| **Cosmetics / collections** | **Keep, but as the reward of mastery + the IAP surface** | Not its own progression track. |
| **Permanent power (Workshop)** | **Keep, heavily capped** | See below. |

## 7.4 The Workshop: the one system that could quietly ruin this

**[BUILT]** `Game.WORKSHOP_DEFS` today:

| Entry | Per level | Max level | Total at max |
|---|---|---|---|
| Forge | ×1.06 damage | 10 | **+79% damage** (compounding) |
| Tempo | ×1.04 attack speed | 8 | +37% |
| Lens | +6 range | 8 | +48 px |
| Treasury | +20 start gold | 10 | +200 gold |
| Ramparts | +2 start lives | 8 | **+16 lives on a base of 20** |

A maxed account is playing a substantially different, easier game than a new one. Three
consequences, all bad:

1. **Early runs are artificially weak**, so a new player's losses are partly not their
   fault — the exact failure that makes a game feel like work.
2. **The difficulty curve must be tuned for *some* Workshop level**, and it will be wrong
   for everyone else.
3. **It is a ready-made pay-to-win surface.** The moment Essence is purchasable — and there
   will always be pressure to make it purchasable — the game is pay-to-win by construction.

### Recommendation: cap it hard, then go horizontal

| Entry | Per level | New max | Total at max |
|---|---|---|---|
| Forge | ×1.06 damage | **4** | +26% |
| Tempo | ×1.04 attack speed | **2** | +8% |
| Lens | +6 range | **3** | +18 px |
| Treasury | +20 start gold | **3** | +60 gold |
| Ramparts | +2 start lives | **2** | +4 lives |

**Target: ~+25–30% total effective power, fully maxed in ~20 runs.** After that, Essence
buys only *horizontal* things: cards for the run pool, rulesets, cosmetics. Power stops
being a currency sink, permanently.

Why capped rather than deleted: a small, visible, quickly-completed power track is a real
and honest motivator for the first week — Kingdom Rush's upgrade points work exactly this
way. An *uncapped* one is a treadmill, and a treadmill with an Essence price tag is a
storefront.

---

# 8. In-app purchase strategy

## 8.1 The principle, stated once

> **Nothing that makes you stronger is ever for sale.**
> Not gold, not Essence, not lives, not continues, not wave skips, not permanent upgrades,
> not loot boxes, not anything randomised.

Everything below follows from that line. It is not only an ethical position; for a product
whose audience includes 8–14 year olds it is also the *commercially* durable one — the
regulatory surface around child-directed monetisation (COPPA in the US, GDPR-K in the EU,
the app stores' own family policies) is expanding, and loot boxes and dark patterns are
where it is expanding fastest. A design with no power for sale has nothing to walk back.

## 8.2 The categories, evaluated

| Category | Verdict | Reasoning |
|---|---|---|
| **Tower skins** | ✅ **Ship** | The player looks at four towers for the whole match. A skin is *seen*, constantly, by its owner. Highest perceived value per unit of art in the whole game. |
| **Projectile / element effects** | ✅ **Ship**, bundled with skins | Cheap to produce (**[BUILT]** most effects are already `_draw()` code), highly visible, zero balance impact. |
| **Map themes** (repaint a map: snow, desert, volcano) | ✅ **Ship** | Reuses the traced road and all geometry; only the painting changes. **[BUILT]** `map.gd` already selects a painting + water mask per profile, so a theme is an asset swap. |
| **Enemy skins** | ⚠️ **No** | Enemy silhouettes are *gameplay information* (§5.2). Selling the right to change them sells confusion. |
| **UI themes** | ⚠️ **No** | Same reason, one step removed. The HUD must read identically for everyone. |
| **New maps / campaigns** | ✅ **Ship** as content packs | Real new content at an honest price. The best kind of purchase: it makes the game bigger for the buyer and costs nothing to the non-buyer. |
| **Challenge packs** | ✅ **Ship** | Hand-designed puzzle levels; the cheapest content to author against an existing engine. |
| **Extra loadout slots** | ❌ **Never** | There *is* no loadout in this design — all four towers are always available. A slot system would be a cage built specifically to sell keys. This is the clearest example of the "fun or just bigger?" test failing. |
| **Faster cosmetic progression** | ⚠️ **No** | It is a soft admission that the earn rate is deliberately too slow. Set an honest earn rate instead. |
| **Boosters / consumables** | ❌ **Never** | A booster that helps you win means the base game was secretly tuned to need it. |
| **Any progression purchase** | ❌ **Never** | §8.1. |
| **Ads** | ❌ **Not in MVP or v1.0** | Interrupts a game whose whole appeal is a 12-minute uninterrupted flow, and drags a child-directed app into ad-network data handling. Revisit only if content packs demonstrably fail, and even then only as an opt-in "double Essence for this run" button on the results screen — never mid-match, never with a countdown. |
| **Premium currency** | ❌ **Never** | See §18.3. |

## 8.3 The SKU list

Concrete, honest, dollar-priced, all one-time purchases.

| SKU | What it is | Price | Type |
|---|---|---|---|
| **Supporter Pack** | One exclusive skin set for all four towers + a name badge + "thanks" on the title screen | $4.99 | cosmetic |
| **Skin set: Crystal / Clockwork / Coral / …** | One themed skin for each of the four towers, five levels each | $2.99 each | cosmetic |
| **Map theme: Snowfall / Dunes / Ashlands** | Repaints one map and its enemies' ground rings | $1.99 each | cosmetic |
| **Expedition Pack I** | 3 new maps (9 levels) + 1 new element + 6 new cards + 1 new boss | $4.99 | content |
| **Challenge Pack I** | 12 hand-designed challenge levels with fixed boards and forced constraints | $2.99 | content |
| **Everything Bundle** | All current content packs, discounted; future packs at a standing discount | $12.99 | content |

**Expected shape**, for planning rather than promise: a cosmetics-and-content model on a
premium-feeling free game typically converts 1.5–4% of players, at $6–12 lifetime per
payer. That is a real business at 200k+ installs and it is *not* a business at 5k. Which is
the argument for §15: find out whether the core is fun before building the store.

## 8.4 A purchase a player feels good about

The test for any SKU: **can the buyer explain to a friend why they bought it, without
embarrassment?**

- "I bought the Clockwork skins because my towers look amazing now." ✅
- "I bought the map pack because I'd finished all nine levels and wanted more." ✅
- "I bought 500 gems because I kept losing wave 14." ❌

The third sentence is the one this design makes impossible to say.

---

# 9. Shop design

## 9.1 When and where

| Question | Answer | Why |
|---|---|---|
| **When does the player first see the shop?** | After **run 3**, and only as a small icon appearing on the main menu with a one-time gentle highlight. | Three runs is enough to know whether they like the game. Selling before that is selling to someone who has not decided. |
| **Where does it live?** | **One entry point**: an icon on the main menu. Nowhere else. | Not on the results screen, not in the pause menu, not on the map select. |
| **How often do offers appear?** | **Never as a popup.** The shop is a room you walk into. | An unrequested store interrupt is the pattern this design is defined against. |
| **Mid-match?** | **Never.** No shop, no offer, no currency display, no ad. | The 12-minute flow is the product. |
| **Timers / countdowns?** | **None**, anywhere. | Manufactured urgency aimed at children is out of bounds. |
| **What is permanent?** | **Everything.** Every purchase is permanent, account-wide, and never expires or rotates out. | A cosmetic that can become unavailable is a FOMO instrument. |

## 9.2 Bundles, starter packs, seasons

- **Bundles: yes.** The "Everything Bundle" at a real discount is a genuine kindness to the
  player who has decided they love the game. Bundles that combine cosmetics with power do
  not exist here, because power does not exist here.
- **Starter packs: no.** A discounted pack shown to a new player is aimed at the moment of
  least information. It converts well and it is exactly the pattern being rejected.
- **Seasonal content: yes, but never limited.** A snow theme in December is charming. A
  snow theme that *disappears* in January is a countdown. Ship it and leave it.

## 9.3 What NOT to do — the explicit list

1. No premium currency, no exchange rates, no leftover balances.
2. No loot boxes, gacha, random skins, or "chance to receive".
3. No timers, no "offer expires in 04:59", no daily rotating deals.
4. No interstitials, no rewarded video before a retry, no "watch an ad to continue".
5. No popup on app launch, on run end, or on defeat. **Especially not on defeat** — a
   store shown at the moment of frustration is the definition of the pattern.
6. No "starter pack" aimed at new installs.
7. No selling anything that changes gameplay numbers.
8. No price obfuscation. Real currency, real prices, on the button.
9. No purchase flow that a child can complete without the platform's own parental gate.
10. No cosmetic that alters an enemy silhouette, a status icon, or a range ring.

---

# 10. Retention without coercion

## 10.1 The anatomy of "one more run"

The feeling has four ingredients. A game with all four does not need a daily reward; a game
missing any of them cannot be rescued by one.

| Ingredient | What it means | How this design delivers it |
|---|---|---|
| **1. The loss was legible and mine** | The player can name the mistake in one sentence | Wave telegraph before it spawns; ×2 / ×0.8 damage popups; a results screen that says *"Wave 14 — the Menders healed through your Fire"*, not a stat table |
| **2. The retry is cheap** | Restarting costs seconds, not a menu tour | **One button on the results screen: RETRY.** Same map, same ruleset, new card draw. No loading screen, no menu, no shop. |
| **3. The next run will be different** | The player can imagine a *different* run, not a better-executed same run | The card draw (§11), and the branch decisions they now regret |
| **4. The run is short enough to risk** | 12 minutes is a decision; 40 minutes is a commitment | §12 |

Ingredient 3 is the one Element TD nailed **[EXTRACTED]** with its twelve token draws and
`-random` mode, and the one a pure "bigger numbers" TD never has.

## 10.2 Goal horizons

Three timescales must be live at once. At any moment the player should be able to name
something they are 2 minutes, 2 days and 2 weeks away from.

| Horizon | Goal | Feels like |
|---|---|---|
| **Short (this run, minutes)** | Survive wave 20. Get the zero-leak star. See what card 3 offers. | tension |
| **Medium (this week, hours)** | 3-star map 2 on Normal. Unlock map 3. Reach Fire mastery 3. Beat the weekly. | progress |
| **Long (this month+)** | 27/27 stars. All four elements at mastery 5. Wave 40 in Endless. | identity |

## 10.3 The mechanisms, evaluated

| Mechanism | Keep? | Note |
|---|---|---|
| Short-term goals | ✅ | The star conditions *are* the short-term goals; no extra system needed |
| Medium-term goals | ✅ | Map unlocks + mastery tiers |
| Long-term goals | ✅ | Full stars + Endless depth |
| Unlocking towers | ⚠️ **Limited** | Never the core four (§2.4). Only a post-launch fifth element. |
| Discovering synergies | ✅ **Primary** | The strongest retention driver here: "Grove next to two Blaze towers" is a discovery the player *made* |
| Map progression | ✅ | The spine |
| Achievements | ❌ | Folded into stars and mastery |
| Challenge modes | ✅ | One weekly, optional, no penalty for missing it |
| Endless mode | ✅ | A mode, not the default |
| Randomised modifiers | ✅ | Cards, plus the weekly's forced modifier |
| Mastery systems | ✅ | Element mastery, which rewards *breadth* |

## 10.4 The three anti-patterns to refuse by name

1. **Retention through absence-punishment.** Streaks, decay, "your crops wilted". If the
   only reason to open the app is to prevent a loss, the game has stopped being fun and
   started being a subscription to guilt.
2. **Retention through incompleteness.** Withholding half the towers so that unlocking them
   is the content. The player's first ten hours are then a demo.
3. **Retention through time-gating.** Timers on anything. A player who wants to play for
   three hours should be able to.

**The replacement for all three: make the run good, make it short, and make the next one
different.**

---

# 11. Roguelite elements

## 11.1 The comparison the brief asks for

**100 towers** versus **12–20 towers + upgrade synergies + run modifiers.**

| | 100 towers | 4 towers × 2 branches + ~30 cards |
|---|---|---|
| Player memory load | 100 identities | 4 jobs + 8 ultimates + whatever card is on screen |
| Distinct run shapes | ~1 (the meta build) | branch sets (16) × card draws — hundreds, genuinely varied |
| Art cost | 100 × N tiers | 8 towers + 0 (a card is text and an icon) |
| Balance surface | 100 × 60 waves | 8 × 6 archetypes, plus card interactions |
| Cost of *one more* unit of content | tower: art, code, tiers, tooltip, balance | card: **one row in `Game.UPGRADE_POOL`** |
| Where the variety is felt | in the shop, before the run | **during the run**, at the moment of choice |

The last row decides it. **Variety in a roster is consumed once, by whoever works out the
best build. Variety in a run is re-consumed by every player, every run.**

**Recommendation: 4 towers + branches + cards. Emphatically.** And note what the card
system costs to build: **[BUILT]** it *already exists* — `Game.UPGRADE_POOL`,
`Run.roll_choices()`, `TowerMods.fold`, `upgrade_choice.gd`, and the rarity weights in
`Balance`. The most valuable system in this design is the one that is already finished.

## 11.2 The card system, specified

| Property | Value | Reasoning |
|---|---|---|
| **Cadence** | after waves **5 / 10 / 15 / 20** | **[BUILT]** is every 3 waves, which over 20 waves is 6 choices — frequent enough that each stops mattering. Four makes each an event. |
| **Cards offered** | **3**, choose 1 | Three is the readable maximum on a phone in landscape. |
| **Reroll** | **No** | A reroll makes the choice free. The point is that you did not get what you wanted. |
| **Pool at launch** | **20**, growing to ~40 via account level | Small enough that a player sees most of them in ten runs (which is how synergies get discovered), large enough that runs differ. |
| **Rarity** | 4 tiers, drifting better with wave depth | **[BUILT]** exactly as `Balance.RARITY_WEIGHTS` + `RARITY_WAVE_DRIFT` already does. Keep it. |
| **Card text budget** | **≤ 10 words**, plus one icon | §13. |

### The card taxonomy — four kinds, and the ratio

| Kind | Share | Example | Why it exists |
|---|---|---|---|
| **Mechanic** | 40% | *"Backdraft — Fire's burn also slows 15%"* | The interesting ones. Changes what a tower *does*. |
| **Cross-element** | 20% | *"Steam — Fire towers next to Water deal +40%"* | Preserves Element TD's combination fantasy as a **placement puzzle** instead of a recipe list. The single best idea to carry over. |
| **Economy** | 20% | *"Prospector — +2 gold per kill"* | Keeps the build-versus-bank decision alive mid-run. |
| **Raw stat** | 20% | *"Attunement — all towers +15% damage"* | Necessary ballast. A pool of only-clever cards has no safe pick, and a player who is behind needs one. |

### Twenty launch cards

| Card | Rarity | Effect |
|---|---|---|
| Ember Focus | common | Fire towers +25% damage |
| Deep Current | common | Water towers +25% damage |
| Bedrock | common | Earth towers +25% damage |
| Thornbloom | common | Nature towers +25% damage |
| Long Sight | common | All towers +18 range |
| Scavenger | common | +2 gold per kill |
| Fieldwork | common | Upgrades cost 15% less |
| Attunement | rare | All towers +15% damage |
| Wildfire | rare | Fire towers attack 25% faster |
| Undertow | rare | Water chill lasts 1 s longer |
| Shockwave | rare | Earth splash radius +35% |
| Virulence | rare | Nature poison +50% damage |
| **Steam** | rare | Fire towers near Water: +40% damage |
| **Mudflow** | rare | Earth towers near Water: splash also slows |
| **Wildgrowth** | rare | Nature towers near Fire: poison spreads on death |
| **Sandstorm** | rare | Water towers near Earth: chill hits everything in splash |
| Backdraft | epic | Fire burn also slows 15% |
| Quickening | epic | All towers attack 20% faster |
| Overclock | epic | Every 5th shot from any tower is doubled |
| Overcharge | legendary | All towers: +50% damage, +25 range, 15% faster |

The four bold **cross-element** cards are the heart of the design. They make *where a tower
sits relative to another tower* the deepest decision in the game — which is what Element
TD's spiral geometry was reaching for, achieved with four towers and four data rows instead
of fifteen recipes.

---

# 12. Game session length

## 12.1 The single most important change to the current build

**[BUILT]** Today a run is **endless**, has **no win condition and no last wave**, and ends
only when lives run out. Every session therefore ends in failure.

That is the wrong default for a mobile game, for one reason that outweighs everything else:

> **An endless run always ends on a loss. A player who has just lost is deciding whether to
> retry. A player who has just *won* is deciding what to try next. The second player opens
> the app again tomorrow.**

Element TD itself is not endless — **[EXTRACTED]** it has 60 levels and a "Congratulations"
message. Endless is a fine *mode*; it is a poor *product*.

**Recommendation: the default mode is a finite 20-wave Standard run that can be won.**

## 12.2 The four modes

| Mode | Waves | Target length | What it contributes | Ships in |
|---|---|---|---|---|
| **Standard** | 20 + 2 bosses | **12–14 min** | The main game. A complete arc with a win. Where stars are earned. | **MVP** |
| **Quick** | 10 + 1 boss | **5–6 min** | The bus stop. Same map, halved. Lower star ceiling (2 stars max) so it is a *format*, not an easier path. | v1.0 |
| **Challenge** | 12, fixed seed + forced modifier | **8 min** | The weekly. Identical for everyone; the comparison surface. | v1.0 |
| **Endless** | ∞, boss every 10 | **15+ min, open** | "How deep can I get." The depth expression. Score = wave. | v1.0 |

## 12.3 The arithmetic behind 12–14 minutes

A wave costs `spawn time + travel time + prep gap`.

| | Current **[BUILT]** | Recommended |
|---|---|---|
| Prep between waves | 4.0 s (`PREP_TIME`) | **3.0 s** |
| Prep before wave 1 | 12.0 s (`FIRST_PREP_TIME`) | 10.0 s |
| Spawn interval | 0.9 s → 0.3 s | 0.7 s → 0.3 s |
| Count | `9 + 1.2n`, cap 28 | `8 + n`, cap 28 |
| Wave-1 road crossing | ~45 s | **~30 s** |

At those numbers a wave runs ~30–38 s, and **20 waves + 2 boss waves lands at 12–13
minutes** — plus four card screens, which pause the tree.

**[BUILT]** Note the coupling recorded in `balance.gd` and `CLAUDE.md`: `BASE_SPEED_FLAT`
and `BASE_SPEED_LINEAR` are tied to *road length* and nothing else reads it. Shortening the
crossing means re-checking against `--dump-board`'s reported length, not just editing the
constant. The `Send Next ▶` early-call button (**[BUILT]**) is also a real lever here: an
expert player compresses the same 20 waves into ~9 minutes and gets paid for it.

## 12.4 Why not longer, and why not shorter

- **30+ minutes**: excludes the commute, the queue and the ten minutes before bed — the
  three occasions mobile games are actually played. It also makes a loss at minute 28 a
  reason to stop, not to retry.
- **Under 5 minutes**: too short for a defence to develop an *identity*. Two card choices
  is not a build. Quick mode is deliberately the secondary format for this reason.
- **12–14 minutes** is long enough to build something and short enough to risk again. It
  is also, not coincidentally, the length of a Kingdom Rush level and an Isle of Arrows run.

---

# 13. Child-friendly design

## 13.1 The text budget, as a hard rule

> **No screen may show more than 12 words of body text.
> No card may exceed 10 words. No tutorial step may exceed 5.**

This is enforceable, checkable, and it is the whole section in one line. Element TD's
seventeen tips (§1.12) are what happens without it.

**[BUILT]** The current tutorial violates this badly — e.g. *"Place Water in a glowing
grass pocket. Its rapid bolts repeatedly slow targets."* (11 words) and *"Water beats Fire
armour. Watch the blue slow effect and gold ×1.75 damage."* (12 words), for six lessons. It
should become four lessons of ≤5 words each, with the demonstration doing the teaching.

## 13.2 Icon philosophy

| Rule | Why |
|---|---|
| **Colour + shape, never colour alone** | ~8% of boys have a colour vision deficiency, and a 6-inch screen in sunlight flattens hue. Fire = orange **triangle**, Water = blue **droplet**, Earth = brown **hexagon**, Nature = green **leaf**. |
| **One visual vocabulary, used everywhere** | The burn icon on an enemy is the *same* triangle as the Fire tower's icon. A child learns one symbol and it works in three places: palette, tower, enemy. |
| **Silhouette reads at 24 px** | Test every icon at thumbnail size on a real phone. If it needs colour to be identified, redraw it. |
| **Motion carries meaning** | A Sprinter *leans forward*; a Brute *plods*; a Mender *pulses*. **[BUILT]** the creep animation carriers already do exactly this — a ground creep's stride is driven by its own speed. |
| **No text on any in-world element** | Numbers only: damage popups, gold, lives, wave. |

## 13.3 The feedback the player must get, and how

| Thing to communicate | Mechanism | Status |
|---|---|---|
| **This tower is strong here** | Damage popup **big and gold with a ×2 badge** | **[BUILT]** — `floating_text.gd` already sizes and colours by matchup. Add the badge. |
| **This tower is weak here** | Popup small and grey | **[BUILT]** |
| **This enemy's armour** | A coloured **ring on the ground** under it, matching the element's colour+shape | **[BUILT]** — `enemy.gd` draws the ring so a painted creature is never tinted |
| **This tower's reach** | Range ring on drag, and on tap | **[BUILT]** |
| **Where I may build** | Green/red ghost; shaded illegal ground during a drag | **[BUILT]** — `grid.gd`. The ghost turning red rather than vanishing is the right call and should be kept |
| **I can afford an upgrade** | Green ▲ chevron floating on the tower | **[BUILT]** |
| **What an upgrade will do** | **Missing.** Add a preview: the new range ring drawn faintly, plus a before→after damage **bar** (not numbers) | **build** |
| **What a branch will do** | **Missing.** A two-card popup: icon, ≤5 words, and a 1-second animated loop of the effect | **build** |
| **Enemy status** | Small icons above the enemy using the tower vocabulary: 🔥 burning, ❄ chilled, 🌿 poisoned, ✋ stunned | **[BUILT]** as coloured rings; convert to the shared icon set |
| **Why I lost** | Results screen, one sentence, naming the archetype that got through | **build** |

## 13.4 Tutorial structure

**90 seconds. Five steps. Twenty-three words total.** Action-gated: the game does not
proceed until the player does the thing.

| Step | What happens | Text |
|---|---|---|
| 1 | Board is empty. One spot pulses. A hand icon drags Fire onto it. | *"Drop it here"* (3) |
| 2 | Four Runners walk in. The tower fires. Player watches. | — (0) |
| 3 | The tower is highlighted; an ▲ chevron bounces. | *"Tap to upgrade"* (3) |
| 4 | Four enemies with **green leaf rings** walk in. The Fire tower's numbers pop **big and gold with ×2**. | *"Fire beats green"* (3) |
| 5 | Three Flyers cross. Player is given an Earth tower; its shots miss; a crossed-out wing icon flashes on the tower. Then Water is offered and hits them. | *"Earth can't hit flyers"* (4) |

Then: *"Your turn"* and the first Standard run begins.

**[BUILT]** The existing `tutorial.gd` already has the right *architecture* — a separate
scene, its own board profile, action-gated lessons, no `WaveManager`, restores the main
profile on exit. It has six lessons of prose. **Cut to four elements, five steps, and
replace prose with demonstration.**

Note what step 4 does: it teaches the entire matchup system **without naming it**, using
only a colour, a shape and a big gold number. That is what the text budget is for.

## 13.5 What NOT to put on screen

- No tooltips with stat blocks. A tower shows: its icon, its level pips, its range ring on
  tap, its ▲ if affordable, its ✕ to sell. Nothing else.
- No DPS numbers, no armour percentages, no efficiency ratings.
- No settings the player must understand to play (targeting priority, etc.).
  **[BUILT]** fixed "First" targeting with no per-tower picker is exactly right — keep it.
- No currency counters other than gold and lives during a match.
- No mid-match menus at all except pause.

---

# 14. Content expansion strategy

## 14.1 The rule

**Every update must be shippable by one person in one month, and must add a *kind* of
variety the game does not yet have.** An update that only adds more of something is a patch.

## 14.2 The roadmap

| Release | Content | New *kind* of variety | Effort |
|---|---|---|---|
| **MVP** | 4 towers · 8 branch ends · 6 enemies · 20 waves · 1 map × 2 rulesets · 1 boss · 20 cards | — | the base |
| **v1.0** | +2 maps · 3rd ruleset · Quick / Challenge / Endless modes · 2 more bosses · Splitter · account level · mastery · capped Workshop · cosmetics + first content pack | modes, and difficulty as a *choice* | 2–3 months |
| **U1: "Deep Roots"** | +10 cards, all cross-element; element mastery tier 5 rewards | **synergy** — placement becomes the deep skill | 1 month |
| **U2: "New Ground"** | +2 maps, +2 modifiers, map themes as cosmetics | **space** — new geometry problems | 1 month |
| **U3: "The Fifth"** | +1 element (Light returns, outside the matchup ring) with 2 branches; +6 cards | **roster** — the one expensive lever, used once | 1.5 months |
| **U4: "The Swarmborn"** | New enemy faction: 3 archetypes with a shared rule (e.g. they all buff each other while adjacent) | **enemy behaviour** — the first genuinely new tactical problem since launch | 1 month |
| **U5: "Gauntlet"** | New mode: 5 short maps back-to-back, towers carry over, one life pool | **structure** — a run made of runs | 1 month |

## 14.3 What is deliberately *not* on the roadmap

| Idea | Why not |
|---|---|
| Multiplayer / co-op | Multiplies QA, matchmaking, cheating, and support by an order of magnitude, for a mechanic Element TD itself only used as social pressure. Async leaderboards deliver 80% of it for 5% of the cost. |
| Map editor / user content | Moderation burden on a product with child users. Non-negotiable no. |
| Hero units / commander abilities | Kingdom Rush's hero is great, but it adds a second control scheme to a game whose entire input is "tap a tower". |
| A second currency | §18.3. |
| Triple-element towers | §2. |

---

# 15. MVP

## 15.1 The question the MVP exists to answer

> **Is a 12-minute run, defended by four towers with one branch decision each, fun enough
> to play twice?**

Nothing that does not help answer that question belongs in the MVP. In particular: **no
monetisation, no meta-progression, no account level, no Essence.** You cannot measure
whether a game is fun while also measuring whether it sells; and a progression system laid
over a core that is not yet fun will hide the problem rather than reveal it.

## 15.2 The exact contents

| | Count | Detail |
|---|---|---|
| **Towers** | **4** | Fire, Water, Earth, Nature. All available from wave 1. |
| **Tower levels** | **5** each | 50 / 40 / 70 / 120 / 200 gold. Damage ×1 / ×1.8 / ×3.2 / ×5.6 / ×10. |
| **Branches** | **1 per tower, at level 3** | 2 options each → **8 end-state towers**. |
| **Enemy types** | **6** | Runner, Sprinter, Swarm, Brute, Flyer, Mender. (Splitter waits for v1.0.) |
| **Waves** | **20** | Hand-authored, per §5.3. No generator. |
| **Maps** | **1** | The winding forest — **[BUILT]** already painted and traced. |
| **Rulesets** | **2** | Easy and Normal. |
| **Bosses** | **1** (appearing twice) | The Warden at wave 10; The Warden, Awakened at wave 20. |
| **Modes** | **1** | Standard, 20 waves, **with a win screen**. |
| **Roguelite** | **1 of 3 cards** after waves 5 / 10 / 15 / 20 | Pool of **20**, per §11.2. |
| **Progression** | **Map stars only** | 6 stars (2 rulesets × 3 stars). Nothing else. |
| **Monetisation** | **None** | No shop, no IAP, no ads, no currency beyond in-match gold. |
| **Tutorial** | 90 s, 5 steps, 23 words | §13.4. |
| **Meta / Essence / Workshop** | **None** | Deliberately absent. |

## 15.3 What the MVP measures

| Signal | Target | What a miss means |
|---|---|---|
| Tutorial completion | > 90% | The first 90 seconds are wrong |
| First run completed (reaches wave 20 or dies trying) | > 80% | The run is too long or too punishing |
| **Second run started within 60 s of the first ending** | **> 45%** | **The core is not fun. Stop and fix this before anything else.** |
| Runs per session | > 1.8 | The retry loop is not closing |
| Wave-20 clear rate on Normal, first 5 runs | 15–35% | Above: too easy. Below: too hard. |
| Distinct branch sets used across a player's first 10 runs | > 4 | One branch is dominant; balance is off |

The bolded row is the whole experiment. Everything else in this document is downstream of it.

## 15.4 How much of the MVP already exists

**[BUILT]** Most of it. The MVP is dominated by *removal*:

| MVP requirement | Status |
|---|---|
| Placement, upgrade, sell, targeting, projectiles, effects, pooling | ✅ done |
| Painted board + traced road + water animation | ✅ done (3 boards) |
| 6 enemy archetypes with painted 12-frame cycles | ✅ done (8 archetypes) |
| Element matchup + damage-popup feedback | ✅ done (6 elements → cut to 4) |
| Card choice screen, pool, rarity, modifier fold | ✅ done |
| Wave manager, telegraph, interest, early-call bonus | ✅ done |
| Action-gated tutorial | ✅ done (6 lessons → cut to 4) |
| Painted tower art, 5 tiers × 6 elements | ✅ done (4 needed) |
| **Branch at level 3** | ❌ **the main new build** |
| **Finite 20-wave mode with a win screen** | ❌ new (small) |
| **Boss with a rule** | ❌ new (small) |
| **Ruleset selection (Easy / Normal)** | ❌ new (small) |
| **Stars** | ❌ new (small) |
| Number rebalance (costs, damage, matchup) | ❌ data edits |

**The MVP is roughly: one real feature (branches), four small ones, and a lot of deletion.**

---

# 16. Post-MVP

Kept strictly separate from §15 so that scope creep has a wall to hit.

## 16.1 Version 1.0 — the commercial release

Ships only after the MVP's "second run within 60 s" number clears 45%.

| Area | v1.0 contents |
|---|---|
| **Towers** | Unchanged: 4 elements, 8 branch ends. **Resist the urge.** |
| **Enemies** | +Splitter (7 total), +2 bosses (4 total) |
| **Maps** | 3 maps × 3 rulesets = **9 levels, 27 stars** |
| **Modes** | Standard, Quick, Challenge (weekly), Endless |
| **Cards** | 30 in the pool, ~10 unlocked through account level |
| **Progression** | Map stars, account level (20), element mastery (4 × 5 tiers), weekly challenge |
| **Meta currency** | Essence, with the **capped** Workshop (§7.4) and horizontal spending after |
| **Monetisation** | Supporter Pack, 2 skin sets, 1 map theme, 1 content pack, Everything Bundle |
| **Platform** | Android first (**[BUILT]** the APK pipeline exists and is arm64-only), Web build as the demo/funnel, iOS after |
| **Live ops** | The weekly challenge. Nothing else. No events, no timers. |

## 16.2 Future expansions

In priority order, each gated on the previous one earning its keep:

1. **Deep Roots** — cross-element cards as a full system. *Cheapest, highest impact.*
2. **New Ground** — maps and themes. *Reuses the entire pipeline.*
3. **The Fifth** — a fifth element. *The one expensive lever.*
4. **The Swarmborn** — an enemy faction with a shared rule. *First new tactical problem.*
5. **Gauntlet** — a run made of five short maps. *Structural variety, no new assets.*
6. **Second branch at level 5** — 16 end-states. *Year two. Extends the roster with zero palette growth.*

## 16.3 The scope-creep wall

Three sentences to re-read whenever a feature is proposed:

> The MVP has **no** meta-progression, **no** monetisation, and **one** map.
> v1.0 has **four** progression systems and **no** new towers.
> Anything else is an expansion, and expansions ship after the thing before them earned it.

---

# 17. Competitor thinking

Patterns to take, and — as importantly — the mistake each game demonstrates.

| Game | The transferable pattern | The mistake not to copy |
|---|---|---|
| **Element TD (WC3)** | **Interest on banked gold** as a recurring dilemma; **leaks cycle again** so failure never compounds; **boss-kill as progression** | 41 towers behind a recipe menu; an invisible matchup; 17 tips |
| **Element TD 2** | Proof that the combination system *can* be modernised — and that doing so kept it niche. Its audience is the original's audience. | Combination depth did not broaden the audience. Depth is not the same as reach. |
| **Kingdom Rush** | **The branch at the top of the tree** — exactly Model E, and the reason its four towers feel like eight. Also: hand-authored levels with a 3-star condition, and *legible* enemy silhouettes | Its heroes and spells add a second control scheme; skip them |
| **Bloons TD 6** | The **hard commitment rule** (you may fully upgrade only one path) is what makes upgrade paths a real decision rather than a checklist | 23 towers × 3 paths × 5 tiers. This is the failure mode at industrial scale |
| **Infinitode 2** | The closest thing to *our* failure mode, and therefore the most instructive: enormous systemic depth, near-zero onboarding, a wall of numbers | Do not ship depth the player must dig for |
| **Rogue Tower** | **Variety from the board and the cards, not the roster.** Tiny tower list, huge run variance | Its procedural sprawl makes runs long and shapeless; ours must stay bounded |
| **Isle of Arrows** | **Short, complete runs with a win state**, no permanent power, high replay. The single best argument for §12.1 | Its drafting is its whole game; ours is placement |
| **The Tower (idle TD)** | An honest demonstration of what an **uncapped permanent upgrade tree** becomes: a spreadsheet with a game attached | This is what our Workshop turns into if §7.4's cap is not enforced |
| **Slay the Spire** | The **card-choice cadence**: a small pool, seen often enough that synergies are *discovered* rather than looked up | A full deckbuilder is a different genre; take the cadence, not the deck |
| **Vampire Survivors** | **Build identity emerging mid-run** from a few upgrades; and the "one more run" length (~15 min) | Its power fantasy removes decisions late; a TD must keep them |

**The synthesis:** Kingdom Rush's branch, Slay the Spire's card cadence, Isle of Arrows'
short winnable run, and Element TD's interest dilemma. Four patterns, four different games,
none of them requiring a large roster.

---

# 18. Economy model

## 18.1 In-match: Gold

One currency, one purpose: **the build-versus-bank decision every wave.**

| Rule | Value | Reasoning |
|---|---|---|
| Starting gold | **120** (Easy 150, Hard 100) | Two towers plus change. Enough to make a placement decision on wave 1, not enough to cover the board. |
| Tower build | **50** | Every element the same price. Cost must never be a reason to pick an element. |
| Upgrades | **40 / 70 / 120 / 200** (total 480 to max) | §4.3. Level 2 cheaper than the build, so upgrading is learned first. |
| Sell refund | **80%** of everything spent | **[BUILT]** is 50%. Element TD's 100% (**[EXTRACTED]**) is better still, but 80% keeps a small cost on churn while making experimentation affordable. |
| Bounty per kill | **`3 + wave`** | Wave 1 pays 4, wave 20 pays 23. Linear and predictable — a child can feel it going up. Element TD's `1.10^(n-1)` (**[EXTRACTED]**) is right for 60 levels and wrong for 20. |
| Enemies per wave | **`8 + wave`**, cap 28 | Wave 1 = 9, wave 20 = 28 (the map's own flat count, reached by ramp). |
| Interest | **5% of banked gold per wave cleared, capped at +60** | The map's 2.5%/15 s (**[EXTRACTED]**) re-expressed per wave. The cap is ours: uncapped, the correct late play is to stop building, which deletes the game. |
| Leak-free bonus | **+8** if nothing got through | Rewards the zero-leak star behaviour every wave, not just at the end. |
| Early-call bonus | **`3 + wave`** | **[BUILT]** exactly this. Lets an expert compress the run and get paid for it. |
| Boss reward | **×12** | A boss should visibly fund the next third of the run. |

### Worked cash flow, Normal ruleset

| Wave | Count | Bounty | Wave income | Interest (if banked ~50%) | Cumulative available |
|---|---|---|---|---|---|
| start | — | — | — | — | **120** |
| 1 | 9 | 4 | 36 | +2 | 166 |
| 5 | 13 | 8 | 104 | +12 | ~560 |
| 10 | 18 | 13 | 234 (+boss ×12) | +25 | ~1,650 |
| 15 | 23 | 18 | 414 | +40 | ~3,300 |
| 20 | 28 | 23 | 644 (+boss ×12) | +60 (cap) | **~6,000 total** |

Against a spend of **480 to fully max one tower**, ~6,000 gold across a run buys roughly:

- **10 towers at level 4** (2,800) with 3,200 spare for repositioning and over-levelling, or
- **8 towers fully maxed** (3,840), or
- **14 towers at level 3** (2,240) — the wide, cheap, branch-early build.

Three genuinely different economic strategies, all viable. That is the target: the budget
should be tight enough that "wide and cheap" and "few and maxed" are both real answers.

## 18.2 Out-of-match: Essence

| Rule | Value |
|---|---|
| Earned | `wave_reached + wave_reached² / 20` (**[BUILT]** `Balance.run_essence`) — wave 10 ≈ 15, wave 20 ≈ 40 |
| Bonus | ×1.5 on a completed 20-wave run; ×1.2 per star earned |
| Spent on | Workshop levels (capped, §7.4), then **cards for the run pool**, rulesets, cosmetic unlocks |
| Never | purchasable, tradeable, or convertible |

Superlinear earning is deliberate **[BUILT]**: pushing two waves deeper is worth more than
replaying two shallow runs, so "one more run" is a real decision rather than a grind.

**Offline earnings: cut.** **[BUILT]** `Balance.offline_essence` pays a capped trickle for
time away. It exists to make opening the app feel rewarding, which is the mechanic of an
idle game, not a tower defense — and it teaches the player that *not playing* is a way to
progress. Delete it. (The `OFFLINE_*` constants and `Meta._collect_offline()` go with it.)

## 18.3 Why there is no third currency

The standard mobile economy has 4–6 currencies (soft, premium, energy, event, upgrade
material, cosmetic token). Every one of them exists for one of three reasons, and none of
those reasons survives contact with this design:

| Reason a premium currency exists | Why it does not apply here |
|---|---|
| **To obscure the real price.** "500 gems for $4.99, this skin is 450 gems" leaves 50 stranded so the next purchase starts pre-committed. | Our SKUs are dollar-priced items. There is nothing to obscure. |
| **To sell power without saying so.** Gems → gold → upgrades. | Nothing that makes you stronger is for sale (§8.1). |
| **To create a second earn/spend loop for engagement.** | We have one, and it is the run. |

XP for account level and element mastery are **counters, not currencies** — they accumulate
and unlock, they are never spent, never converted and never displayed as a balance. That
distinction is what keeps the currency count at **two**.

> **Two currencies: Gold (in-match, resets) and Essence (out-of-match, permanent).
> Everything else is a counter or a price tag.**

---

# 19. Player journey

Each stage names the mechanic that arrives, so that depth is always *ahead* of the player
and never all at once.

## First 5 minutes

| | |
|---|---|
| **Happens** | Tap Play → 90-second tutorial → first Standard run on Map 1, Easy |
| **Learns** | Drag to build. Tap to upgrade. Fire beats green. Earth cannot hit flyers. |
| **New mechanics** | placement, upgrade, the matchup, one archetype counter |
| **Feels** | "I understand this." |
| **Risk** | If they quit here, the tutorial is too long or the first wave is too slow. |

## First 30 minutes (runs 1–3)

| | |
|---|---|
| **Happens** | Finishes run 1 (probably survives on Easy). Retries on Normal. Loses around wave 13–16. Retries. |
| **New mechanics** | **The branch at level 3** (run 1, wave ~6). **The card screen** (wave 5). **The first boss** (wave 10) and its rule. Sprinters, Swarms, Brutes. |
| **Feels** | "There's a decision here I didn't see the first time." |
| **Unlocks** | First stars. Map 2 at 4 stars. |

## First hour (runs 4–6)

| | |
|---|---|
| **Happens** | Clears Normal on Map 1. Tries for the zero-leak star. Moves to Map 2. |
| **New mechanics** | **Mender** (poison suppresses regen — the first genuinely *tactical* lesson). **Flyer** waves force mixed coverage. The first **cross-element card** appears and is not understood yet. |
| **Feels** | "The Brutes are the problem, not the numbers." |

## First 3 hours

| | |
|---|---|
| **Happens** | All three maps at Normal. First Hard attempt. Endless unlocked. |
| **New mechanics** | **Hard rulesets** — the modifier, the closed block, the second entrance. **Endless mode.** **Element mastery** ticks over and grants its first card. |
| **Feels** | "I have a build I like, and it doesn't work on this map." |
| **This is the retention hinge.** | The player's build being *invalidated by geometry* is the moment the game becomes about placement rather than about upgrades. |

## First week

| | |
|---|---|
| **Happens** | ~15 of 27 stars. First weekly challenge. Half the card pool seen. Workshop maxed (~20 runs). |
| **New mechanics** | **Weekly challenge** (a fixed seed everyone shares). **Cross-element synergy** finally clicks — "Steam" gets picked *on purpose*. |
| **Feels** | "I know what I'm going for before the run starts." |
| **Shop** | Appeared after run 3 as a quiet icon. If they buy, it is now, and it is a skin. |

## Long-term player (month 1+)

| | |
|---|---|
| **Happens** | 27/27 stars. Mastery 5 across all four elements. Endless personal best. |
| **New mechanics** | Only **content updates** — cards, maps, the fifth element, the enemy faction. |
| **Feels** | "I want to see how deep I can get, and I want the next map pack." |
| **Monetises** | Here, honestly, for content — not for power. |

**The shape of that table is the design goal:** something new arrives at 5 minutes, 30
minutes, 1 hour, 3 hours and 1 week, and after that the game's own depth (placement,
synergy, Endless) carries it until the next update.

---

# 20. Final recommendation

## 20.1 The twelve systems

| # | System | The recommendation |
|---|---|---|
| **1** | **Core gameplay loop** | Choose a map + ruleset → 20 waves, ~12 min → build/upgrade/branch under a gold budget with an interest dilemma → a card every 5 waves → boss at 10 and 20 → **win or lose** → stars + Essence → retry or next map. |
| **2** | **Tower system** | **4 towers, 5 levels, one branch at level 3 → 8 end-states.** Levels 2 and 4 change stats; 3 and 5 change mechanics. Range and cadence never change with level, only at the branch. Costs 50 / 40 / 70 / 120 / 200. Damage ×1 → ×10, displayed as 10 → 100. |
| **3** | **Element system** | **Fire / Water / Earth / Nature.** One job, one colour, one shape each. A 4-way ring where every relation is physically obvious: Water ▶ Fire ▶ Nature ▶ Earth ▶ Water. **×2.0** strong, **×0.8** weak — reward-forward asymmetry. Light and Darkness retire to the shelf and return as an expansion. |
| **4** | **Enemy system** | **6 archetypes + boss**: Runner, Sprinter, Swarm, Brute, Flyer, Mender (+ Splitter in v1.0). Each is one problem, one counter, one silhouette. Magic-resist merges into Brute. No stealth, no shields, no enemy healers. |
| **5** | **Wave system** | 20 hand-authored waves. One new idea per wave, alone. Nothing new after wave 15. Cards on 5/10/15/20. HP curve stays `75 × 1.16^(n-1)`. Every wave telegraphed with an icon, a ring colour and a numeral — no words. |
| **6** | **Map system** | **3 maps × 3 rulesets = 9 levels.** A ruleset changes HP, count, gold, lives, the road variant, the buildable ground, and on Hard one modifier. One screen, one path, no fog, no scrolling. 3 stars per level: clear / ≤5 leaks / 0 leaks. |
| **7** | **Progression system** | **Four systems, four motivations:** map stars (achievement), account level (discovery — each level adds a card to the pool), element mastery (mastery — rewards breadth), weekly challenge (competition). No dailies, no streaks, no energy, no battle pass. |
| **8** | **Roguelite system** | **1 of 3 cards after waves 5/10/15/20.** Pool of 20 → 40. Four kinds: mechanic 40%, cross-element 20%, economy 20%, raw stat 20%. No rerolls. **The cross-element cards are the depth of the whole game.** |
| **9** | **Monetisation system** | **Cosmetics and content packs only, dollar-priced, one-time, permanent.** No premium currency, no loot boxes, no ads, no timers, no starter packs, and nothing that makes you stronger. Shop appears after run 3, on the main menu, and never appears on its own. |
| **10** | **Retention system** | "One more run", built from four ingredients: a legible loss, a one-tap retry, a different next run, and a 12-minute length. Three live goal horizons at all times. Zero absence-punishment. |
| **11** | **MVP scope** | 4 towers · 8 branch ends · 6 enemies · 20 waves · 1 map × 2 rulesets · 1 boss · 1 mode · stars only · **no monetisation, no meta** · 20 cards · 90-second tutorial. One real new feature (branches) on top of what is already built. |
| **12** | **Expansion strategy** | One shippable-in-a-month update at a time, each adding a new *kind* of variety: synergy → space → roster → enemy behaviour → structure. Never two roster expansions in a row. Never a fifth progression system. |

## 20.2 The three loops, and how they interlock

```
                     +--------------------------------------------+
                     |                MAIN  MENU                  |
                     |   map + ruleset select | stars | shop      |
                     +----------------------+---------------------+
                                            |  choose level
                                            v
 ===================== GAMEPLAY LOOP  (12 minutes) ==========================
 |                                                                          |
 |   PLAYER STARTS MATCH                                                    |
 |          |                                                               |
 |          v                                                               |
 |   120 gold | 20 lives | 4 towers on the palette                          |
 |          |                                                               |
 |          v                                                               |
 |   +--> WAVE TELEGRAPH   (icon + armour ring + count -- no words)         |
 |   |         |                                                            |
 |   |         v                                                            |
 |   |   BUILD / UPGRADE / BRANCH / REPOSITION                              |
 |   |         |                                                            |
 |   |         v                                                            |
 |   |   WAVE RUNS  -- leaks cost lives, kills pay gold                     |
 |   |         |                                                            |
 |   |         v                                                            |
 |   |   DECIDE: spend the gold, or bank it for 5% interest?   <-- THE      |
 |   |         |                                                  DILEMMA   |
 |   |         v                                                            |
 |   |   every 5 waves --> CHOOSE 1 OF 3 CARDS --> the run changes shape    |
 |   |         |                                                            |
 |   +---------+   waves 1-19                                               |
 |             v   waves 10 and 20 = BOSS (with a rule)                     |
 |      MATCH ENDS  -->  WIN (wave 20 cleared)   or   LOSS (0 lives)        |
 ============================================================================
                                     |
        +----------------------------+----------------------------+
        v                            v                            v
 +----------------+      +-----------------------+      +--------------------+
 | RESULTS SCREEN |      |   PROGRESSION LOOP    |      |   RETENTION HOOK   |
 |                |      |                       |      |                    |
 | "Wave 14 --    |      |  stars    --> maps    |      |  a different card  |
 |  the Menders   |      |  Essence  --> cards   |      |  draw next time,   |
 |  healed        |      |  XP       --> account |      |  and a star you    |
 |  through Fire" |      |  mastery  --> skins   |      |  almost got        |
 |                |      +-----------+-----------+      +---------+----------+
 | [RETRY][NEXT]  |                  |                            |
 +-------+--------+                  | unlocks feed BACK          |
         |                           | into the run's card pool   |
         |                           v                            |
         |              +-------------------------+               |
         |              |    MONETISATION LOOP    |               |
         |              |  (touches NEITHER of    |               |
         |              |   the two loops above)  |               |
         |              |                         |               |
         |              |   love the game         |               |
         |              |        |                |               |
         |              |        v                |               |
         |              |   run out of maps       |               |
         |              |        |                |               |
         |              |        v                |               |
         |              |   buy a CONTENT PACK    |               |
         |              |   or a SKIN             |               |
         |              |        |                |               |
         |              |        v                |               |
         |              |   more levels to star,  |               |
         |              |   exactly the same rules|               |
         |              +------------+------------+               |
         |                           |                            |
         +---------------------------+----------------------------+
                                     v
                                NEXT  MATCH
```

**Read the diagram for what is missing.** The monetisation loop has **no arrow into the
gameplay loop**. Money buys *more game*, never *better numbers*. That one absent arrow is
the design's ethical position drawn as a picture — and it is also the reason the game can
be balanced once and stay balanced.

---

# 21. Migration: applying this to the current repo

The good news, stated first: **most of this is deletion and data edits.** The engine —
placement, targeting, projectiles, pooling, the modifier fold, the card screen, the wave
manager, the painted-art pipeline, the tutorial architecture, the Android/Web CI — is
already the right engine for the game described above.

## 21.1 File-by-file

| File / constant | Verdict | Change | Size |
|---|---|---|---|
| `game.gd` `TOWER_ORDER` | **Change** | `["water", "fire", "nature", "earth"]` — drop `light`, `darkness` | 1 line |
| `game.gd` `TOWER_DEFS` (light, darkness) | **Keep, unreferenced** | Leave the defs and their painted art for the expansion (§3.3) | 0 |
| `game.gd` `TOWER_DEFS` (15 duals + lightning) | **Cut from play, harvest the roles** | Their behaviours become branches and cards (§2.5). Delete the defs once the branches carry them. | medium |
| `game.gd` `DUAL_RECIPES`, `DUAL_ELEMENT_LEVEL` | **Cut** | The combination mechanic goes entirely | small |
| `game.gd` `ELEMENT_BEATS` | **Change** | 4-cycle: `water→fire→nature→earth→water`. Three of the four relations already exist; only `earth` re-targets. | 1 line |
| `game.gd` `ELEMENT_STRONG` / `ELEMENT_WEAK` | **Change** | `2.0` / `0.8` (§3.2) | 2 lines |
| `game.gd` `WAVE_TYPES` | **Change** | Merge `immune` into `tank` → **Brute**. Rename to the player-facing names. Keep `split` for v1.0. | small |
| `game.gd` `WAVES` | **Rewrite** | The 20-wave table in §5.3, with boss rules | medium |
| `game.gd` `UPGRADE_POOL` | **Rewrite contents, keep the schema** | Drop the 6 element cards (no duals to unlock) and the Lightning unlock; add the 4 cross-element cards. The `Run._fold_into` machinery is unchanged. | medium |
| `game.gd` `WORKSHOP_DEFS` | **Change** | Cap `max_level` per §7.4 | 5 lines |
| `balance.gd` `TIER_COSTS` | **Change** | `[50, 40, 70, 120, 200]` | 1 line |
| `balance.gd` `TIER_DAMAGE_MULT` | **Change** | `[1.8, 1.78, 1.75, 1.79]` — or simply give each element an explicit `damage_tiers` of `[10, 18, 32, 56, 100]` scaled to its own base, which is the path `tower.gd` already prefers | 1 line |
| `balance.gd` `SELL_REFUND` | **Change** | `0.5` → `0.8` (§18.1). Note the README credits this to `tower.gd`; it lives in `balance.gd` and `tower.gd:273` reads it. | 1 line |
| `balance.gd` `CHOICE_EVERY` | **Change** | `3` → `5` (§11.2) | 1 line |
| `balance.gd` `PREP_TIME` / `FIRST_PREP_TIME` | **Change** | `4.0` → `3.0`, `12.0` → `10.0` (§12.3) | 2 lines |
| `balance.gd` `BASE_COUNT_*`, `BOUNTY_GROWTH`, `REWARD_FLAT` | **Change** | `count = 8 + n` cap 28; bounty `3 + n` (§18.1) | small |
| `balance.gd` `INTEREST_RATE` / `INTEREST_CAP` | **Change** | `0.05` / `60` | 2 lines |
| `balance.gd` `BOSS_*` | **Change** | HP ×8, speed ×0.7, reward ×12, **life cost 10 → 5** (§5.4) | 4 lines |
| `balance.gd` `MAX_TOWER_RANGE`, `WC3_RANGE_SCALE` | **Cut** | With the WC3 numbers gone, ranges are authored directly in px (170–220). The cap exists only to tame Light's 2000; no surviving tower needs it. **Re-run `--dump-board` after.** | small |
| `balance.gd` `OFFLINE_*`, `meta.gd` `_collect_offline` | **Cut** | §18.2 — offline earnings teach that not playing is progress | small |
| `balance.gd` `run_essence` | **Keep** | Superlinear curve is right as-is | 0 |
| `wave_generator.gd` | **Keep, demote** | Endless mode only. Standard uses the hand table. | 0 |
| `game.gd` `BOARD_SEQUENCE` / `WAVES_PER_BOARD` | **Repurpose** | Boards stop being chapters of one run and become **selectable levels**. The profile machinery (`configure_board`) is exactly what a *ruleset* needs. | medium |
| `tutorial.gd` `LESSONS` | **Change** | 6 lessons → 4 steps; prose → ≤5 words each (§13.4) | medium |
| `tower.gd` | **Extend** | The one real new feature: a `branch` field on the tower, a 2-card popup at level 3, and branch-specific stat/behaviour overrides. `TowerBehavior` already exists for the mechanic swaps. | **the main build** |
| `main.gd`, `wave_manager.gd` | **Extend** | A finite mode with a win condition; star evaluation on clear | small |
| `end_screen.gd` | **Extend** | Win state, the one-sentence cause-of-death line, `[RETRY]` as the primary button | small |
| `menu.gd` | **Extend** | Map + ruleset select, stars | medium |
| `enemy_index.gd`, `projectiles.gd`, `effects.gd`, `sprites.gd`, `map.gd`, `save_service.gd`, `audio.gd` | **Keep untouched** | All correct as built | 0 |

## 21.2 Order of work

1. **Delete first.** Light/Darkness out of the palette, duals out, matchup to 4, numbers
   rebalanced. The game gets *smaller and better* before anything is added.
2. **Make the run finite.** 20 waves, a win screen, `[RETRY]`. This is the change that most
   alters how the game feels, and it is small.
3. **Build the branch.** The only substantial new feature.
4. **Rulesets and stars.** Easy/Normal over one map, 6 stars.
5. **Rewrite the tutorial** to 5 steps.
6. **Measure** (§15.3) before building anything from §16.

## 21.3 Verification, using the harnesses that already exist

`CLAUDE.md` documents the arg-gated harnesses; three of them are directly relevant:

- **`--dump-stats` before and after any "no behaviour change" refactor.** The rebalance in
  §21.1 is a deliberate behaviour change, so capture a baseline first and read the diff as
  a spec rather than as a regression.
- **`--dump-board` after cutting `MAX_TOWER_RANGE`** and after any ruleset road variant.
  Coverage percentages move in ways eyeballing does not predict.
- **`--shot` (without `--headless`) plus `--auto-pick`** to actually look at the board, and
  `map.gd`'s `show_road` overlay after any road variant, which is the only check that
  catches enemies walking beside the road rather than on it.
- `--dump-mods` / `--dump-meta` still cover the card fold and the Workshop after the
  `WORKSHOP_DEFS` caps change.

---

# 22. The rejected list

Everything considered and refused, in one place, so nobody has to re-argue it. Each row
failed the same test: ***does this make the game more fun, or merely bigger?***

| Feature | Why it was rejected |
|---|---|
| Dual / triple towers (35 recipes) | A memory test that requires a documentation menu (§2) |
| A 5th and 6th element at launch | Past four, a child cannot name every tower's job |
| Light and Darkness in the launch roster | No one-sentence physical job; two arbitrary matchup relations (§3.3) |
| A third branch option at level 3 | 50% more balance surface, no new *kind* of decision |
| A second branch at level 5 (16 end-states) | Correct idea, wrong year. Reserved for year two (§4.7) |
| Card rerolls | Makes the choice free, which is the opposite of a choice |
| Stealth enemies | An enemy you cannot see on a 6-inch screen is unfair by construction |
| Shielded enemies (second health bar) | Armoured with extra UI |
| Enemy healers / supports | The player cannot see why their damage stopped working |
| Minibosses | An elite wave does the same job with an existing entity |
| Multi-lane maps | Doubles attention cost, halves tower value, unreadable on a phone |
| Fog of war / limited vision | Unreadable, and a leak you cannot see is a bug from the player's side |
| Destructible scenery | A second tap target competing with towers on a thumb-sized screen |
| Procedural maps | A TD map's quality *is* its hand-tuned choke points |
| 10+ hand-made maps at launch | Nine levels from three paintings gets there cheaper |
| Daily missions | Converts play into a checklist and makes the player play worse on purpose |
| Login streaks / daily rewards | Punishes absence; retention through guilt |
| Energy / lives system | The most player-hostile mechanic in mobile, unacceptable for a young audience |
| Battle pass with a countdown | Manufactured urgency aimed at children |
| A separate achievements list | Duplicates stars and mastery |
| Offline Essence earnings | Teaches that *not playing* is a way to progress (§18.2) |
| Uncapped Workshop | Becomes a spreadsheet with a game attached (§7.4) |
| Premium currency | Exists only to obscure price, sell power, or manufacture a second loop (§18.3) |
| Loot boxes / random cosmetics | Gambling mechanics aimed at children |
| Starter packs | Aimed at the moment of least information |
| Extra loadout slots | A cage built specifically to sell keys |
| Boosters / consumables | Implies the base game is tuned to need them |
| Ads (any form, at launch) | Interrupts a 12-minute flow and drags a child app into ad-network data handling |
| Real-time multiplayer / co-op | Orders of magnitude of cost for what async leaderboards deliver at 5% |
| User-generated maps | Moderation burden on a product with child users |
| Hero units / commander spells | A second control scheme in a game whose whole input is "tap a tower" |
| Per-tower targeting priority | A setting the player must understand in order to play |
| Endless as the default mode | Every session would end in a loss (§12.1) |

---

# THE GAME I WOULD BUILD

Ignoring everything that would make it bigger, this is the game.

---

**A twelve-minute tower defense with four towers.**

You pick a map and a difficulty. You get 120 gold, 20 lives, and four icons: a **fire
triangle**, a **water droplet**, an **earth hexagon**, a **nature leaf**. You already know
what each one does, because water puts out fire and roots split stone, and nobody had to
tell you.

Twenty waves walk a road you can see all of at once. Before each one, an icon shows you
what is coming and what colour it is armoured in. You build, you upgrade, and at level 3
each tower asks you **one question** — *Blaze or Mortar? Glacier or Torrent?* — with two
pictures and four words. That question is the whole strategy layer, and you answer it eight
or ten times a run.

Between waves, one decision keeps repeating: **spend this gold, or bank it for interest?**
It is the decision Element TD built its entire economy on in 2005, and it is still the best
one in the genre, because there is no correct answer and you own whichever one you chose.

Every five waves the game stops and shows you **three cards**. Most change what a tower
*does*. Four of them are the reason the game has depth: *"Fire towers next to Water deal
+40%"*. That is Element TD's fifteen-recipe combination table, rebuilt as a **placement
puzzle** — the thing you are already good at looking at.

At wave 10 and wave 20 a boss arrives with a **rule**, not just a health bar. The first one
cannot be slowed, so Water alone will not save you.

And then — this is the part the current build does not do and the part that matters most —
**you win.** "Wave 20. You survived. ★★☆". Not "you died on wave 27, here is your score".
A player who has just won is deciding what to try next. A player who has just lost is
deciding whether to keep going.

You go back to a menu with nine tiles — three maps, three difficulties — and some of them
have stars you did not get.

---

**What it does not have:**

No premium currency. No loot boxes. No energy. No ads. No daily missions. No login streak.
No timers anywhere. No thirty-six towers. No recipe list. No stat tooltips. No paragraph
of text on any screen, ever. Nothing you can buy that makes you stronger.

**What you can buy:** a set of tower skins, a repainted map, or three more maps. Real
prices, on the button, one time, permanent. The kind of purchase you can explain to a
friend without embarrassment.

---

**Why this and not something else.** Element TD is a great game with a memory test bolted
to the front of it. Its towers are excellent, its economy is excellent, and its
progression — pay a token, summon a boss, kill it, gain a power — is better than most
things shipped since. What it also has is forty-one towers, thirty-five recipes, an
invisible damage matchup, six-digit numbers, and seventeen in-game tips explaining rules
that could not be seen.

**Keep the engine. Throw away the manual.**

Four towers a child can name. One branch decision that makes each of them two towers. A
card every five waves that makes each run a different game. Twelve minutes, a win screen,
and a retry button.

That is a game one person can finish, balance, and keep adding to for years — and it is the
game that the code in this repository is already about eighty percent of the way to being.

---

*End of document. Every Element TD figure marked **[EXTRACTED]** is re-derivable with
`tools/extract_w3x.py`; every claim marked **[BUILT]** is readable in
`godottowerdefense/scripts/`. Everything else is a proposal, and proposals are for arguing
with.*
