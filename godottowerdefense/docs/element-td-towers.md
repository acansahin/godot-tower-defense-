# Element TD — Tower Reference

The design target for this project's element system, taken from the original
Warcraft III maps rather than from secondary sources.

> **This file used to be guesswork and most of it was wrong.** Recipes were
> reconstructed from wiki pages and forum posts and carried a "verify before
> shipping" warning. The maps themselves have since been read directly — see
> [element-td-data.md](element-td-data.md) for the extracted numbers and
> `tools/extract_w3x.py` for the reader. Corrections are listed at the bottom.

## The element system

- **6 elements:** Fire, Water, Nature, Earth, Light, Darkness.
- Each element upgrades through **5 tiers**: `X` → `Amplified X` → `Focused X` →
  `Refined X` → `Pure X`, costing 50 / 175 / 788 / 3544 / 24444.
- Damage multiplies by **×5 per tier**, and Pure is **×10** on top of tier 4.
- The six elements sit at nearly identical DPS. They differ in **range and
  cadence** — Fire 500/0.33s, Water 750/0.17s, Nature 750/0.99s, Earth 750/1.00s,
  Light 2000/0.99s, Darkness 2000/2.75s.
- Combining elements unlocks **15 dual** and **20 triple** towers, each with their
  own upgrade tiers (duals 275/1775/7975, triples 1017/5317).
- **Damage circle:** Light → Darkness → Water → Fire → Nature → Earth → Light.
  Every creep has an armour element; the element *before* it in the circle deals
  bonus damage, the one *after* is resisted. The maps implement this through
  Warcraft III's own attack/armour type table, so the exact multipliers are not
  recoverable from the map files.

## Base towers (6)

Fire, Water, Nature, Earth, Light, Darkness. Full stat table in
[element-td-data.md](element-td-data.md#1-base-elements--6-elements--5-tiers).

## Dual towers (15)

Every pair of the six elements, each with three tiers:

| Recipe | Tier 1 → 2 → 3 |
|---|---|
| Light + Darkness | Moon → Lunar → Temple of Luna |
| Light + Fire | Electricity → Lightning → Energy |
| Light + Water | Ice → Freezing → Iceberg |
| Light + Earth | Money → Gold → Goldmine |
| Light + Nature | Life → Eternal → Immortal |
| Fire + Water | Steam → Vapor → Immolation |
| Fire + Earth | Lava → Magma → Volcano |
| Fire + Nature | Sun → Solar → Temple of Sol |
| Fire + Darkness | Magic → Sorcery → Wizard |
| Water + Earth | Clay → Golem → Living Statue |
| Water + Nature | Well → Spring → Waterfall |
| Water + Darkness | Poison → Venom → Virus |
| Earth + Nature | Roots → Brambles → Entangling |
| Earth + Darkness | Tech → Robot → Cyborg |
| Nature + Darkness | Death → Doom → Damnation |

Roles worth stealing: **Money/Gold** gives bounty on kill · **Life/Eternal**
converts kills into player lives · **Well/Spring** is a pure support aura ·
**Tech/Robot** is rate-of-fire · **Death/Doom** is a chance to instantly kill ·
**Magic/Sorcery** banks mana into burst damage.

## Triple towers (20)

Every three-element combination, each with two tiers — full table in
[element-td-data.md](element-td-data.md#3-triple-towers--20-recipes--2-tiers).
Notable: **Laser/Phasor** has the longest range in the game, **Tidal/Tsunami** is
the tower that Moon and Sun exist to buff, and **Undead/Lich** spawns minions from
its kills.

## What we are building now

The port takes the original's names, recipes **and numbers**. Progress:

- **Built:** Fire, Water, Nature, Earth as directly-buildable towers; Steam, Lava,
  Ice and a non-canon Lightning exist as data but are unlockable-only.
- **Next:** Light and Darkness, the 5-tier upgrade ladder, the 6-element damage
  circle, and the economy rescaled onto the original's curve.
- **Not started:** the dual/triple combination mechanic itself. Our towers are
  built directly from a palette; the original builds them by combining elements.

## Corrections to the earlier guesses

| This file used to claim | The maps actually contain |
|---|---|
| Fire + Water = Vapor | **Steam** (Vapor is its tier 2) |
| Fire + Earth = Gunpowder | **Lava** (tier 2 Magma) |
| Fire + Nature = Flame / Solar | **Sun** (tier 2 Solar) |
| Water + Earth = Geyser | **Clay** (tier 2 Golem) |
| Nature + Earth = Moss | **Roots** (tier 2 Brambles) |
| Water + Nature = Ice or Well | **Well** — and Ice is Water + **Light** |
| "Atom / Quark", "Blacksmith", "Trickery", "Disease" | not in these maps at all |
| 4 tiers (Lv1→Lv3→Pure) | **5 tiers**, with Pure at ×10 rather than ×5 |

The dual list this file previously carried (`Magic · Disease · Well · Blacksmith ·
Moss · Atom · Electricity · Flame · Vapor · Poison · Life · Geyser · Trickery ·
Gunpowder · Ice`) is from a later Element TD lineage, not from these two maps.

## Sources

- **The maps themselves** — `ELEMENT TD.w3x` (*Element TD version 2.0*, Pimp10110,
  2005) and `Element TD 1.4.w3x` (*Element TD Survivor 1.4*, MrChak, 2005), read
  with `tools/extract_w3x.py`. Authoritative for everything above.
- Element TD 2 Wiki — https://eletd2.fandom.com/wiki/Towers — a *different*,
  later game. Useful for ideas, not for this port's facts.
- MNoya/Element-TD (DotA port of a later WC3 version) —
  https://github.com/MNoya/Element-TD
