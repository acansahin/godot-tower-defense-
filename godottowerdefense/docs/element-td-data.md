# Element TD — extracted map data

Every number here was read out of the original Warcraft III map, not copied from a
wiki and not guessed. Re-derive any of it with:

```
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" towers
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" recipes
python tools/extract_w3x.py "<path>/ELEMENT TD.w3x" waves
```

**Source:** `ELEMENT TD.w3x` — *Element TD version 2.0* by **Pimp10110**, 2005-12-26.
A second map, `Element TD 1.4.w3x` — *Element TD Survivor 1.4* by **MrChak**,
2005-12-22 — carries the same tower tables with a survivor/elimination game mode
layered on top. Both are fan-made Warcraft III maps; this file records their design
for a reimplementation, and the names below are theirs.

> These are 2005 maps, predating Karawasa's better-known Element TD and the
> standalone Element TD 2. Where this data disagrees with the ETD2 wiki, this
> data is what *these* maps actually contain.

---

## 1. Base elements — 6 elements × 5 tiers

Tier names: `X Tower` → `Amplified X` → `Focused X` → `Refined X` → `Pure X`.

| Tier | Cost |
|---|---|
| 1 | 50 |
| 2 | 175 |
| 3 | 788 |
| 4 | 3544 |
| Pure | 24444 |

Two structural rules hold across all six elements:

- **Each tier multiplies damage by 5.**
- **Pure multiplies the tier-4 damage by 10**, not 5.

Damage below is what the tower actually deals. Every element rolls `1d1` — a die that
can only come up 1 — so the real number is the object editor's *base damage plus one*.
Reading `ua1b` alone gives values one short across the board and makes the clean ×5
ladder look ragged.

| Element | Range | Cooldown | T1 | T2 | T3 | T4 | Pure |
|---|---|---|---|---|---|---|---|
| Fire | 500 | 0.33 | 23 | 115 | 575 | 2875 | 28750 |
| Water | 750 | 0.17 | 10 | 50 | 250 | 1250 | 12491 |
| Nature | 750 | 0.99 | 66 | 330 | 1650 | 8250 | 82490 |
| Earth | 750 | 1.00 | 55 | 275 | 1375 | 6875 | 68741 |
| Light | 2000 | 0.99 | 50 | 250 | 1250 | 6250 | 62491 |
| Darkness | 2000 | 2.75 | 165 | 825 | 4125 | 20625 | 206241 |

Tiers 1→4 are exact ×5 steps with no rounding anywhere. **The Pure row is not.** By the
rule it should read 28750 / 12500 / 82500 / 68750 / 62500 / 206250; five of the six land
a few points short, so those numbers were evidently typed by hand rather than computed.
Fire is the only element whose Pure tier obeys the ×10. The port reproduces the table as
written, typos included — see `TOWER_DEFS.damage_tiers` in `scripts/game.gd`.

**Upgrading changes damage and nothing else.** Range and cooldown are identical at all
five tiers: Fire is 500/0.33 as a 50-gold tower and still 500/0.33 as Pure Fire. This is
what stops the elements converging on one another as they level.

**The elements are not balanced by power — they are balanced by shape.** DPS is
nearly identical across all six at every tier (≈50–67 at tier 1, ≈63k–87k at Pure).
What differs is range and cadence: Fire is short-ranged and quick, Water fires
almost six times a second for tiny hits, Light and Darkness reach four times as far
as Fire, and Darkness trades a 2.75 s wind-up for the largest single hit in the game.

> The map ships a typo: tier 2 of Nature is named "Aplified Nature Tower".

## 2. Dual towers — 15 recipes × 3 tiers

Costs: **275** → **1775** → **7975**.

| Recipe | Tier 1 | Tier 2 | Tier 3 | Role |
|---|---|---|---|---|
| Light + Darkness | Moon | Lunar | Temple of Luna | medium damage, buffs nearby Tidal towers |
| Light + Fire | Electricity | Lightning | Energy | good damage and range, chance to double |
| Light + Water | Ice | Freezing | Iceberg | slowing splash |
| Light + Earth | Money | Gold | Goldmine | extra bounty on kill |
| Light + Nature | Life | Eternal | Immortal | kills feed the player's lives |
| Fire + Water | Steam | Vapor | Immolation | area steam, drains health over time |
| Fire + Earth | Lava | Magma | Volcano | siege splash plus incinerate |
| Fire + Nature | Sun | Solar | Temple of Sol | medium damage, buffs nearby Tidal towers |
| Fire + Darkness | Magic | Sorcery | Wizard | stores mana to spend as extra damage |
| Water + Earth | Clay | Golem | Living Statue | chance to slow |
| Water + Nature | Well | Spring | Waterfall | support: attack-speed aura |
| Water + Darkness | Poison | Venom | Virus | slowing poison; no effect on mechanical |
| Earth + Nature | Roots | Brambles | Entangling | entangles ground enemies only |
| Earth + Darkness | Tech | Robot | Cyborg | very high rate of fire |
| Nature + Darkness | Death | Doom | Damnation | chance to instantly kill living enemies |

## 3. Triple towers — 20 recipes × 2 tiers

Costs: **1017** → **5317**.

| Recipe | Tier 1 | Tier 2 | Role |
|---|---|---|---|
| Light + Fire + Water | Storm | Monsoon | slowing |
| Light + Fire + Earth | Metal | Smithy | — |
| Light + Fire + Nature | Star | Celestial | fires shards |
| Light + Fire + Darkness | Enchantment | Incantation | support |
| Light + Water + Earth | Glacier | Ice Age | slowing siege splash, frost damage |
| Light + Water + Nature | Mammoth | Magnataur | periodic effect |
| Light + Water + Darkness | Tidal | Tsunami | the tower Moon/Sun buff |
| Light + Earth + Nature | Gemstone | Crystal | chance-based |
| Light + Earth + Darkness | Laser | Phasor | longest range in the game |
| Light + Nature + Darkness | Undead | Lich | kills spawn Dark Minions |
| Fire + Water + Earth | Infernal | Chaos | strong, chaos-type damage |
| Fire + Water + Nature | Rainbow | Spectrum | chaos damage |
| Fire + Water + Darkness | Acid | Hydrochloric | coats enemies |
| Fire + Earth + Nature | Dinosaur | Fossil | devours enemies |
| Fire + Earth + Darkness | Flamethrower | Flamespewing | super rapid fire |
| Fire + Nature + Darkness | Summoning | Conjuring | summons |
| Water + Earth + Nature | Flesh Golem | Living Flesh | moving tower |
| Water + Earth + Darkness | Sludge | Mire | thrown splash |
| Water + Nature + Darkness | Drowning | Davey Jones' | splash |
| Earth + Nature + Darkness | Crypt | Tomb | — |

## 4. Waves — 60 levels

**Hit points: `hp(n) = 75 × 1.16^(n-1)`.** Level 1 is 75, level 60 is 476 522, and the
ratio between consecutive levels is 1.16 the whole way — no breakpoints, no boss
spikes in the HP curve itself.

> `war3map.j` declares `udg_HP_exponent_base = 1.23` and then never reads it. The
> real base is 1.16, baked into a separate unit type per level. Trust the units.

**Bounty per kill:**

```
max( level / 3,  1.10^(level-1) × (1 + 0.33 × money_tower_level) )
```

**Interest: 2.5 % of unspent gold every 15 s**, raisable by research — the map's
whole economy tension is holding gold versus spending it.

**Speed** is 300 for most levels; "fast" levels run 350–390.

### Creep classes and the levels carrying them

Ten classes, and a level can carry several at once (level 55 is monster + undead +
flying). This is the same idea as our `Game.WAVE_TYPES`, with the level lists
hand-authored rather than generated.

| Class | Levels |
|---|---|
| humanoid | 3, 8, 11, 16, 21, 26, 27, 31, 34, 39, 41, 44, 49, 51, 54, 60 |
| monster | 2, 7, 10, 12, 14, 19, 20, 22, 24, 28, 30, 35, 36, 40, 42, 45, 47, 53, 55, 57, 59 |
| animal | 1, 5, 9, 13, 18, 23, 33, 38, 43, 52, 56 |
| mechanical | 6, 17, 25, 32, 46, 50, 58 |
| undead | 2, 8, 12, 15, 23, 27, 33, 39, 44, 50, 55 |
| flying | 6, 11, 18, 22, 30, 36, 42, 48, 55 |
| summoned | 4, 15, 29, 37, 48 |
| fast | 4, 10, 16, 24, 34, 38, 44, 49, 52, 56, 59 |
| resistant | 5, 14, 20, 29, 37, 45, 51, 58 |
| healing | 7, 13, 26, 31, 40, 47, 53, 57, 60 |

Two class interactions matter and match rules we already have: **mechanical** is
immune to Poison, and **undead / mechanical** cannot be instant-killed by Death.

## 5. What could not be extracted

- **The element damage matchup.** The maps use Warcraft III's built-in attack-type
  versus armour-type table rather than a scripted multiplier, so there is no number
  to read — `war3map.j` contains no `ATTACK_TYPE` reference at all. Our own ×1.75 /
  ×0.7 values stay.
- **`(listfile)` and `(attributes)`** are the only encrypted blocks in either
  archive. Neither holds game data.
