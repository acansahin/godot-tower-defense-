# Element TD — Tower Reference

Reference for the Warcraft III **Element TD** tower roster, kept for a future
element-based tower system in this project. Names are taken from the faithful
DotA port of the original WC3 map (MNoya/Element-TD localization). Exact element
recipes / numbers vary between the WC3 original and the standalone **Element TD 2**,
so treat recipes below as "verify before shipping".

## The element system

- **6 elements:** Fire, Water, Nature, Earth, Light, Darkness.
- **Damage circle** (each beats the next): Light → Darkness → Water → Fire → Nature → Earth → Light.
  Every creep has an armor element; the element *before* it in the circle deals
  bonus damage (≈200%), the element *after* is heavily resisted (≈50%).
- Each element upgrades **Lv1 → Lv2 → Lv3 → Pure**.
- Combining elements unlocks **15 dual** and **20 triple** special towers.

## Base towers (6)

Fire, Water, Nature, Earth, Light, Dark — each Lv1→Lv2→Lv3→Pure.
Typical roles: Fire = raw single-target damage; Water = slow; Nature = poison/DoT;
Earth = slow, heavy splash; Light = fast/cheap; Darkness = high single-target.

## Dual-element towers (15)

`Magic · Disease · Well · Blacksmith · Moss · Atom · Electricity · Flame · Vapor · Poison · Life · Geyser · Trickery · Gunpowder · Ice`

Known roles: Ice/Vapor/Geyser = water-based slow+damage · Flame/Gunpowder = fire
splash · Electricity = chain lightning · Poison/Disease = DoT / armor shred ·
Life = player regen · Blacksmith = economy/gold · Magic = pure (armor-ignoring) ·
Atom (a.k.a. Quark) = strong single/AoE.

### Recipes among Fire / Water / Nature / Earth (our subset)

| Recipe | WC3 name | ETD2 name | Effect (approx.) |
|---|---|---|---|
| Fire + Water | Vapor | Vapor | line hit, +10% dmg per creep pierced |
| Fire + Earth | Gunpowder | — | fire splash / AoE |
| Fire + Nature | (Flame?) | Solar | ignite, dmg scales with consecutive hits / range |
| Water + Nature | (Ice/Well) | Well | periodically buffs a nearby tower's attack speed |
| Water + Earth | Geyser | Geyser | every Nth attack does a big AoE burst |
| Nature + Earth | Moss | — | nature/earth hybrid |

> Note: WC3 and ETD2 disagree on some names/recipes (e.g. ETD2 "Solar" ≈ WC3 "Flame";
> ETD2 "Well" is a buff tower). Confirm on the [ETD2 wiki](https://eletd2.fandom.com/wiki/Towers) before implementing faithfully.

## Triple-element towers (20)

`Muck · Gold · Windstorm · Quake · Incantation · Flooding · Laser · Hail · Runic · Impulse · Obliteration · Ephemeral · Flamethrower · Haste · Tidal · Roots · Nova · Corrosion · Polar · Jinx`

Known: **4 slow towers** = Windstorm, Roots, Nova, Muck · **Impulse** = more damage
the farther the target · **Laser** = piercing/high single-target · **Flamethrower** =
cone/burn · **Gold** = bonus gold on kill · **Haste** = very fast attack ·
**Corrosion** = armor shred · **Runic/Incantation** = pure magic · **Flooding** =
splash grows with consecutive hits on one target.

## What we are building now (subset)

A simplified, directly-buildable version (no element-research meta):

**Base (4):**
- **Fire** — fast single-target, high damage, hits flying.
- **Water** — slows enemies on hit.
- **Nature** — weak hit + poison damage-over-time.
- **Earth** — slow, heavy splash (AoE); ground-only.

**Duals (a few, directly buildable):**
- **Steam** (Fire+Water) — solid damage + slow.
- **Lava** (Fire+Earth) — big splash + burn DoT; ground-only.
- **Ice** (Water+Nature) — strong slow + poison.

Effects are implemented generically (damage / splash / slow / poison) so more
towers are just new data entries in `Game.TOWER_DEFS`.

## Sources
- MNoya/Element-TD localization (WC3 port): https://github.com/MNoya/Element-TD
- Element TD 2 Wiki — Towers: https://eletd2.fandom.com/wiki/Towers
- List of All Towers in Element TD 2 — gamingph.com
- Guide to Element Tower Defence — forums.eletd.com
