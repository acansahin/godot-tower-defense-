# Element TD Prototype (Godot 4.7)

A tiny, fully-playable 2D tower-defense prototype inspired by the Warcraft III
custom map **Element TD**. Built with typed GDScript, deliberately small and
readable rather than production-architected.

When you press **Play** you get: a grassy map, an S-shaped cobblestone road, a
faint build grid beside the road, and an **endless** run of enemies drawn from a data table
of **creep archetypes** (including flyers, tanks, swarms, splitters, regenerators, periodic
**bosses** and **elite** waves). The buildable roster is the six elements —
**Light / Darkness / Water / Fire / Nature / Earth**, with the stats of the original
Warcraft III map (see [docs/element-td-data.md](docs/element-td-data.md)) — plus an
**element-matchup** system (each is strong and
weak against another, so tower choice vs. an enemy's armor element matters),
**tap-to-upgrade** towers each with a small **sell button**, **time controls** (pause and
1x/2x/3x), a gold economy with interest and streak bonuses, lives, a **tutorial** opening,
and a **run summary** reporting how deep you got.

A run has **no win condition and no last wave**. Waves 1–20 are hand-authored so each
mechanic is introduced deliberately; past that, `WaveGenerator` produces waves forever, with
a boss every 10. The run ends when your lives run out, and the wave you reached is the score.

Every 3 waves the run pauses and offers **three roguelite upgrades** — element damage,
attack speed, poison, slow strength, economy, or an **Elemental** that raises one of the
six element tracks. Elements are what gate the **dual towers**: raise both halves of a
recipe (Water + Light = Ice, Fire + Water = Steam, ...) and it appears in the palette,
exactly as the original map gates towers by which elements you own. They last the run and
reset with it. Adding one is a row in `Game.UPGRADE_POOL`.

Losing banks **Essence**, scaled to the wave you reached, and Essence buys permanent
**Workshop** levels from the title screen — tower damage, attack speed, range, starting gold
and starting lives. Those apply to every run afterwards, through the *same* modifier fold
the roguelite cards use. Progress is saved to `user://save.json` (versioned, atomic, with a
`.bak` fallback), and time away earns a capped **offline** Essence trickle.

Towers are **data-driven**: every tower is one entry in `Game.TOWER_DEFS` with a
colour and an effect payload (damage, splash, slow, poison). Adding a new tower
is just adding a row — no new scene or script. See
[`docs/element-td-towers.md`](docs/element-td-towers.md) for the full Element TD
tower reference this is growing toward.

---

## 1. Setup / How to run

1. Install **Godot 4.7** (standard build, GDScript — no C# needed).
2. Open the Godot Project Manager → **Import**.
3. Select `godottowerdefense/project.godot` and open it.
4. Godot imports the assets on first open (creates a local `.godot/` cache).
5. Press **F5** / the ▶ **Play** button. `scenes/Menu.tscn` is the main scene — the
   title screen; press **Play** there to start a run.

No external assets, plugins, or downloads are required — all art is drawn in
code with primitive shapes and colors.

### Controls
- The game opens on a **title screen**: **Play**, **How to Play** (a controls
  summary), a **Sound** toggle, and **Quit** (hidden on Web).
- **Drag a tower from the palette** (top-right, lists every tower with its colour
  and cost) onto a grid cell to build it. A green ghost marks a legal cell, red an
  illegal/unaffordable one, and the ghost also previews **the range that tower would
  cover** — so you can judge placement before spending the gold.
- **Hover a placed tower** to light up its range ring. Ranges stay faint otherwise, so a
  full board doesn't turn into a tangle of overlapping circles.
- Cells are the faint squares on the grass — 40 of them, in two rows filling each gap
  between the horizontal roads, so the narrow outer side of every bend is a 2×2 block.
  Towers can't be built on the road or on an occupied cell.
  A drop that lands slightly off still snaps to the nearest cell (see
  `grid.gd` `SNAP_TOLERANCE`); the ghost shows you which one before you let go.
- **Click / tap a tower to upgrade it** (up to level 3) — each level boosts damage, range,
  fire rate and DoT. A green ▲ chevron floats beside any tower whose next level you can
  already afford, so you can spot upgrade candidates at a glance.
- **Tap the small red × at a tower's bottom-right corner to sell it** — refunds half of
  everything you spent on it. Keeping every action on the tower itself means the whole
  board stays reachable with a thumb on a phone.
- Towers always target the enemy **closest to the exit** ("First") — the one most likely
  to cost you a life. There is no per-tower target picker.
- **Time controls** sit in the bottom-left corner: **Pause** (or **Space**) freezes
  everything, and the speed button (or **F**) cycles **1x → 2x → 3x**.
- **Ground-only towers** (Earth) can't hit flyers; the other five can.
- **Upgrading raises damage only.** Range and fire rate are fixed per element for the
  whole run, so a Pure Fire still has Fire's short reach and quick cadence. The five
  tiers cost 50 / 175 / 788 / 3544 / 24444 gold.
- The HUD shows a **next-wave preview** (archetype, count, boss flag, and armor
  element colour) before it spawns — a **Send Next ▶** button lets you call it
  early for a small gold bonus instead of waiting out the prep timer.
- Each enemy's armor element tints its body; matching it against the right tower
  element deals bonus damage (and less if it's the wrong one) — see the element
  matchup below.
- **The waves never stop.** There is no win screen — a run ends when your lives run
  out, and the run summary reports the wave you reached plus your best this session.
  It offers **Restart** and **Main Menu**.

---

## 2. Folder structure

```
godottowerdefense/
├── project.godot            # Project config, autoload, window size, main scene
├── icon.svg                 # Placeholder app icon
├── README.md
├── .gitignore
├── docs/
│   └── element-td-towers.md # Element TD tower reference (design notes)
├── web/
│   └── orientation.js       # Web build only: "rotate your device" gate + fullscreen
│                            # landscape lock (injected via the preset's head_include)
├── scenes/
│   ├── Menu.tscn            # Title screen (main scene — what the game opens on)
│   ├── Main.tscn            # The level
│   ├── Enemy.tscn           # A single enemy (also used for flyers / bosses)
│   ├── Tower.tscn           # Generic tower (configured from Game.TOWER_DEFS)
│   ├── Projectile.tscn      # Generic homing projectile (damage + effects)
│   ├── HUD.tscn             # Gold / Lives / Wave bar
│   └── EndScreen.tscn       # Run summary overlay (wave reached)
└── scripts/
    ├── balance.gd           # "Balance" autoload: every tunable curve + economy number
    ├── save_service.gd      # "Save" autoload: versioned, atomic user:// persistence
    ├── game.gd              # "Game" autoload: shared state, grid + TOWER_DEFS
    ├── meta.gd              # "Meta" autoload: Essence, Workshop levels, offline reward
    ├── workshop.gd          # Between-runs screen: spend Essence on permanent upgrades
    ├── run.gd               # "Run" autoload: this run's upgrades, unlocks, folded mods
    ├── tower_mods.gd        # Folded modifier totals for one (tower id, element) pair
    ├── upgrade_choice.gd    # The 3-card between-waves reward screen
    ├── wave_generator.gd    # Endless wave definitions past the seed table
    ├── tutorial.gd          # Opening hints; drives the HUD's hint line
    ├── audio.gd             # "Audio" autoload: synthesized chiptune SFX + music
    ├── enemy_index.gd       # "EnemyIndex" autoload: per-frame spatial hash for targeting
    ├── menu.gd              # Title screen: play / how-to-play / sound / quit
    ├── main.gd             # Wires the level together (placement, upgrades, sell)
    ├── map.gd              # Draws grass + cobblestone S-road
    ├── grid.gd            # Builds + draws the faint placement grid, snapping
    ├── enemy.gd            # Path walking, health, flyer visuals, slow/poison
    ├── enemy_layer.gd      # Draw-only child layer for enemy.gd (body / overlay split)
    ├── tower.gd            # Generic tower: targeting, stats, click-upgrade + sell ×
    ├── tower_behavior.gd   # Base strategy: what a tower does with its frame
    ├── bolt_behavior.gd    # The default behavior: cooldown -> one homing bolt
    ├── projectile.gd       # Homing projectile: damage, splash, slow, poison
    ├── projectiles.gd      # Object pool on the $Projectiles node (reused bolts)
    ├── effects.gd          # Object pool on the $Effects node (floating text + bursts)
    ├── frost_ring.gd       # Expanding chill ring drawn by Ice's Lv2+ area slow
    ├── wave_manager.gd     # Spawns the 20-wave table (archetypes, bosses, economy)
    ├── tower_palette.gd    # Top-right drag-source, lists Game.TOWER_ORDER
    ├── placement_preview.gd # Green/red ghost cell shown while dragging
    ├── floating_text.gd    # Rising, fading damage / gold label (built in code)
    ├── death_burst.gd      # Expanding ring of dots left by a dying enemy
    ├── hud.gd              # HUD labels + the time controls (pause / speed)
    └── end_screen.gd       # Win/lose overlay + restart
```

---

## 3. Scene structure & node hierarchy

### `Menu.tscn` (main scene — the title screen)
```
Menu (Node2D)               [menu.gd]
├── Map (Node2D)            [map.gd]   -> the same level art, used as a backdrop
└── UI (CanvasLayer)
    └── Root (Control)                 (process_mode = Always)
        ├── Dim (ColorRect)
        ├── Center (CenterContainer)   -> Panel/VBox: title + Play / How to Play /
        │                                 Sound / Quit buttons
        └── HowPanel (CenterContainer) -> Panel/VBox: controls text + Back (hidden)
```
**Play** calls `change_scene_to_file("res://scenes/Main.tscn")`. **Quit** hides itself on
Web (`OS.has_feature("web")`). The **Sound** button mirrors `Audio.is_muted()`, so it
stays in sync with the **M** key.

### `Main.tscn` (the level)
```
Main (Node2D)               [main.gd]
├── Map (Node2D)            [map.gd]   -> draws grass + road
├── Grid (Node2D)           [grid.gd]  -> faint build cells + snapping
├── Enemies (Node2D)                   -> enemies spawned here at runtime
├── Towers (Node2D)                    -> built towers live here
├── Projectiles (Node2D)   [projectiles.gd]  -> object pool; reused bolts live here
├── Effects (Node2D)       [effects.gd]      -> object pool; floating text + death bursts
├── Camera2D                           -> centred/identity; offset only for screen shake
├── Preview (Node2D)        [placement_preview.gd]  -> drag ghost (hidden)
├── WaveManager (Node)      [wave_manager.gd]
└── UI (CanvasLayer)
    ├── HUD (instance of HUD.tscn)          [hud.gd]
    ├── TowerPalette (Control)              [tower_palette.gd]
    └── EndScreen (instance of EndScreen.tscn)  [end_screen.gd]
```

### `Enemy.tscn`
```
Enemy (Node2D)              [enemy.gd]   -> under-layer _draw(): ground shadow, or wings
├── _body (Node2D)          [enemy_layer.gd] -> body + eyes + flash; scaled for the wobble
└── _overlay (Node2D)       [enemy_layer.gd] -> status rings, markers, crown, health bar
```
The two child layers are created in code (not in the `.tscn`). Splitting the visuals lets
a plain walking enemy repaint nothing per frame: movement is just a transform, the idle
breathing wobble is `_body.scale`, and only real changes (a hit, a status ring, a health
tick) redraw the layer that owns them.

### `Tower.tscn` / `Projectile.tscn`
```
Tower (Node2D)              [tower.gd]        -> one scene, all tower types
Projectile (Node2D)         [projectile.gd]   -> one scene, all projectiles
```
Both are plain `Node2D`s configured at runtime: `Main` calls `tower.setup_def(id)`
after instantiating `Tower.tscn`, and each `Tower` configures the `Projectile` it
fires. Visuals (element colour, effects) come entirely from the data.

### `HUD.tscn`
```
HUD (Control)               [hud.gd]
├── Bar (ColorRect)
├── GoldLabel (Label)
├── LivesLabel (Label)
├── WaveLabel (Label)
├── NextLabel (Label)        -> next-wave preview (archetype/count/boss/element)
├── SendButton (Button)      -> "Send Next ▶", enabled during the prep gap
├── PauseButton (Button)     -> bottom-left, pause / resume
└── SpeedButton (Button)     -> bottom-left, cycles 1x / 2x / 3x
```
`HUD.tscn` sets `process_mode = ALWAYS` on the root. That is what lets the pause button
*un*pause: a PAUSABLE node stops receiving input the moment `get_tree().paused` is set,
so the control that paused the game could never undo it.

### `EndScreen.tscn`
```
EndScreen (Control)         [end_screen.gd]  (process_mode = Always)
├── Dim (ColorRect)
└── Center (CenterContainer)
    └── Panel (PanelContainer)
        └── VBox (VBoxContainer)
            ├── Title (Label)
            ├── Subtitle (Label)
            ├── RestartButton (Button)   -> reloads the level
            └── MenuButton (Button)      -> back to Menu.tscn
```
Both buttons clear `get_tree().paused` first — `show_result()` sets it, and it would
otherwise survive the scene change and leave the next screen frozen.

The `Game` autoload (`scripts/game.gd`) is registered in `project.godot` and is
globally accessible as `Game`. It holds the shared map layout (`PATH`), the build
grid definition (`GRID_ROWS`, `CELL_WIDTH`, `ROAD_HALF`, `ROAD_CLEARANCE`,
`PLAY_RIGHT`, `GRID_COL_*`) plus the shared `dist_to_road()` helper, the
costs, and the mutable `gold` / `lives` with signals. Four more autoloads sit beside it:
`Balance` (`scripts/balance.gd`, every tunable curve and economy number),
`Run` (`scripts/run.gd`, the current run's roguelite upgrades and unlocks),
`Audio` (`scripts/audio.gd`, synthesized SFX/music) and `EnemyIndex`
(`scripts/enemy_index.gd`, the per-frame enemy spatial hash used for targeting).

**Towers pull modifiers from `Run`; nothing is pushed into them.** A tower re-derives its
stats when `Run.modifiers_changed` fires, and a tower built *after* a card was picked reads
the same source on its first `_recompute()` — so there is no back-fill step to forget. Per-
frame cost is zero: `Run` folds the modifier list into one `TowerMods` per
(tower id, element) pair and caches it until the set changes.

The split between `Game` and `Balance` is deliberate and worth keeping: **`Game` owns
*what a thing is*** (the `TOWER_DEFS` / `WAVE_TYPES` / `WAVES` tables and the map
geometry), **`Balance` owns *how the numbers grow*** (upgrade curve, wave scaling, boss
multipliers, interest and bonuses, archetype modifiers). A balance pass used to mean
editing three files and hunting for un-named literals; it is now one file.

---

## 4. How the pieces talk

- **`Game` (autoload)** owns gold & lives and broadcasts `gold_changed`,
  `lives_changed` and `game_over` — there is no `victory`, because waves are
  endless. It also stores the road `PATH` and
  the grid constants so every script reads one source of truth.
- **`Grid`** precomputes the buildable cells (flush against the road, one row on
  each side of every horizontal road, tiled flush to the vertical bends), draws
  them faintly, and answers two lookups: `snap()` (exact — used for upgrade, sell
  and hover, where being generous would spend gold on a mistap) and
  `snap_forgiving()` (nearest cell within `SNAP_TOLERANCE` — used only for placing).
  Cells stop at `Game.PLAY_RIGHT` so none ever sits under the tower palette.
- **`TowerPalette`** (top-right) draws every tower in `Game.TOWER_ORDER` with its
  colour and cost and emits `drag_started(id)` when pressed. **`Main`** then drags
  the **`Preview`** ghost to the snapped cell and builds on release if the cell is
  free and affordable.
- **`WaveManager`** reads the fixed 20-entry `Game.WAVES` table using plain
  `Timer` nodes (so a restart can't leave a spawn loop running). Each entry picks
  a **creep archetype** from `Game.WAVE_TYPES` (normal / fast / swarm / tank /
  immune / regen / air / split — HP, speed, count, CC-immunity, regen and
  splitting are all multipliers/flags on the archetype), optionally flags a
  **boss** (HP ×6, reward ×10, costs 10 lives) and an **armor element** that
  tints the wave and feeds the element matchup. It also runs the economy layer:
  interest on banked gold each wave clear (2.5%, capped at 400), a leak-free bonus
  (+6 gold) if nothing got through, and the early-call bonus from the HUD's
  **Send Next** button. `wave_preview` emits the next wave's description/colour
  ahead of time for the HUD.
- **`Enemy`** walks `Game.PATH`; on death it grants gold, on reaching the end it
  costs `life_cost` lives (1 normally, 10 for a boss). Both cases emit `removed`
  so the wave manager can count down. `make_flying()` marks it airborne
  (squishier, faster, wings + shadow) — only towers with `can_hit_flying` can
  target it. `apply_slow()` / `apply_poison()` / `apply_stun()` drive the status
  effects (shown as blue / green / yellow rings); `armor_element` is the enemy's
  side of the element matchup (`Game.element_mult`) applied to incoming damage,
  including poison ticks.
- **`Tower`** is one generic script. `setup_def(id)` loads a `Game.TOWER_DEFS`
  entry (stats + effect payload + colour). Stats are **never accumulated in place**:
  `_recompute()` rebuilds them from the definition plus the current level whenever either
  changes, so the level-1 baseline is never destroyed. What a tower *does* with its frame
  lives behind **`TowerBehavior`** — every tower today gets **`BoltBehavior`** (cooldown →
  one homing bolt), and an element needing a structurally different attack (a beam, an
  aura, an economy building) becomes a new behavior rather than a branch inside `Tower`.
  A def selects one with an optional `"behavior"` key; omitting it means a bolt turret.
  It always shoots the enemy **closest to the
  exit** (fixed "First" targeting — the one most likely to leak) and fires a `Projectile`
  carrying that payload; `can_hit_flying` gates flyers. Targeting is **sticky**: while
  the current target is alive, in range and legal the tower keeps it, which stops the
  barrel twitching between equal candidates and skips the scan on most frames. When it
  does need a new target it queries **`EnemyIndex`** (see below) rather than the whole
  enemy group, so the scan looks only at enemies near the tower. It tracks an upgrade
  `level` (pips + green upgrade chevron) and `total_spent`. A click on the tower upgrades
  it; a tap on the small red **×** at its bottom-right corner (`is_sell_hit`) sells it —
  no info panel, so the actions live on the tower itself and stay reachable on a phone.
- **`EnemyIndex` (autoload)** is a uniform spatial hash of every live enemy, rebuilt
  lazily at most once per frame (on the first query, keyed on the frame counter). Towers
  and splash projectiles call `query(center, radius)` to get only the enemies in cells
  overlapping their range — turning what used to be an O(enemies)-per-tower group scan
  (the dominant late-wave cost) into one shared O(enemies) rebuild plus small local
  lookups. Callers still run their own exact distance/targetable test, so targeting is
  unchanged, just cheaper.
- **`Projectile`** homes onto its target and applies its payload on impact:
  direct damage, an area **splash** (all enemies in radius, `hits_flying`-gated),
  a **slow**, a **poison** DoT, and/or a chance to **stun**. Direct, splash and
  poison damage are all scaled by `Game.element_mult(element, enemy.armor_element)`
  — the tower's element vs. the enemy's armor element.
- **`Main`** handles input: palette drags build the chosen tower on the grid, and a click
  on a placed tower either upgrades it or, if it hit the corner ×, sells it (`_upgrade_tower`
  / `_sell_tower`). It also owns the `Camera2D` and applies the screen shake that
  `Game.shake_requested` broadcasts, so an `Enemy` can ask for a kick without knowing the
  camera exists.
- **`FloatingText` / `DeathBurst`** are one-shot visuals parented to `Effects`. Both are
  built with `.new()` rather than from a `.tscn` — they are a bare `Node2D` plus a
  script, which also avoids a script preloading the very scene it is attached to.
  Damage numbers are spawned from `projectile.gd` `_apply()`, **not**
  `enemy.take_damage()`, which also fires on every poison tick. Both are **pooled** by
  `effects.gd` (as are projectiles by `projectiles.gd`): a spent instance is hidden and
  its `_process` stopped, then reused on the next spawn, so a busy wave stops churning
  nodes in and out of the tree. `spawn()` and the towers pull from the pool; nothing at
  the call sites changed.

---

## 5. Tuning values (all in one glance)

| Thing | Where | Value |
|---|---|---|
| Starting gold | `balance.gd` `START_GOLD` | 150 (the map gives 30, but its towers are researched rather than bought — see the note on the constant) |
| Starting lives | `game.gd` `START_LIVES` | 20 |
| Tower stats (all towers) | `game.gd` `TOWER_DEFS` | per-tower cost / dmg / range / interval / effects |
| Base towers | `TOWER_DEFS` | six elements at the map's numbers. They sit at near-equal DPS and differ in reach and cadence: Fire 500/0.33s, Water 750/0.17s, Nature 750/0.99s, Earth 750/1.00s, Light 2000/0.99s, Darkness 2000/2.75s (range in **WC3 units**, scaled by `Balance.WC3_RANGE_SCALE`). Water/Nature/Earth also keep our slow/poison/splash payloads, which the map puts on dual towers we have not built |
| Dual towers | `TOWER_DEFS` + `DUAL_RECIPES` | all fifteen of the map's duals at 275g, on its damage. Absent from `TOWER_ORDER`: a dual enters the palette when `Run.element_level` reaches `DUAL_ELEMENT_LEVEL` in **both** its elements |
| Aura towers | `TOWER_DEFS` `aura_stat`/`aura_radius`/`aura_mult` | Moon and Sun boost nearby damage, Well nearby attack speed, deepening with the provider's level. Read by the NEIGHBOURS in `tower.gd` `_recompute()`, so selling the provider returns the buff exactly |
| On-kill payloads | `TOWER_DEFS` `gold_on_kill`/`life_on_kill_chance`/`execute_chance` | Money pays gold, Life has a 2% chance to return a life, Death has a 4% chance to kill outright (never a boss). Applied in `projectile.gd` `_apply()`, which is the only place a kill can be attributed to the tower that earned it |
| Upgrade: max level / growth | `balance.gd` `MAX_LEVEL`, `TOWER_DEFS.damage_tiers` | 5 tiers; damage only, listed explicitly per element (×5 a tier, ×10 into Pure — with the map's own Pure-row typos preserved). Range and interval never change |
| Upgrade cost | `balance.gd` `TIER_COSTS` | 175 / 788 / 3544 / 24444, the same ladder for every element |
| Sell refund | `tower.gd` `SELL_REFUND` | 50% of total gold spent (tap the corner × to sell) |
| Targeting | `tower.gd` `_find_target()` | Fixed to "First" — the enemy furthest along the path (closest to the exit); no per-tower picker |
| Game speed | `hud.gd` `SPEEDS` | 1x / 2x / 3x via `Engine.time_scale`; pause via `get_tree().paused` |
| Screen shake | `main.gd` `SHAKE_DECAY`, `enemy.gd` | 7px on a boss death, 4px on a leak, bled off at 26 px/s |
| Impact SFX cap | `audio.gd` `MAX_PER_FRAME` | 3 per effect per frame — a full board at 3x otherwise floods the 12-voice pool |
| Element matchup | `game.gd` `ELEMENT_BEATS` | cycle light→darkness→water→fire→nature→earth→light; ×1.75 dmg if you beat the target's armor element, ×0.7 if it beats you, ×1 if either side is neutral (applies to direct, splash and poison damage) |
| Waves | `game.gd` `WAVES` | 20 fixed entries (archetype + optional `boss`/`element`, plus an optional per-wave `hp`/`count` multiplier to smooth a single wave without touching the shared archetype) |
| Creep archetypes | `game.gd` `WAVE_TYPES` | normal, fast, swarm, tank, immune, regen, air (flyer), split (splits on death) — each is a set of HP/speed/count/radius multipliers and flags on top of the base scaling |
| Immune archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `cc_immune` | ignores **slow and stun**, but **not poison** — poison is damage rather than crowd control, so Nature stays the answer to these waves instead of the whole roster going dead |
| Regen archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `REGEN_DELAY` | heals 3.5% of max HP/s, but **paused for 2s after taking any damage** — so it only heals through gaps in your coverage instead of setting a hard DPS threshold. Its "+" marker dims while suppressed. Poison ticks count as damage, so a single Nature tower shuts the healing off entirely |
| Prep time between waves | `wave_manager.gd` `PREP_TIME` | 4s (skippable via the HUD's Send Next button, for a small gold bonus) |
| Wave scaling (`n` = wave) | `balance.gd` | HP `75 × 1.16^(n-1)` and a **flat** count of 28 — both from the map, where difficulty lives entirely in the HP curve and never in wave size. Reward `max(n/3, 1.10^(n-1))`, speed `60 + 6·n`, each × the archetype's multipliers |
| Flyers (non-Air waves) | `wave_manager.gd` | from wave 3, 15% chance per enemy (halved on top of Air waves existing); `make_flying()` gives HP ×0.65, speed ×1.25 |
| Bosses | `game.gd` `WAVES` (`"boss": true` per entry) | HP ×6, speed ×0.6, reward ×10, costs 10 lives |
| Economy: interest | `balance.gd` `INTEREST_RATE`/`INTEREST_CAP` | 2.5% of banked gold per wave cleared, capped at 400. The map pays 2.5% every 15s and has no cap; the cap is ours, so that hoarding gold never beats building |
| Economy: leak-free bonus | `wave_manager.gd` `LEAK_FREE_BONUS` | +6 gold if no enemy reached the end that wave |
| Road path | `game.gd` `PATH` | 6 waypoints (S-shape), 80px wide (`ROAD_HALF` 40), ~3296px long |
| Build grid | `game.gd` `GRID_ROWS` / `CELL_WIDTH` | 96×88 cells, 40 of them (10 per row, 4 rows in 2 pairs) |
| Tower ranges | `game.gd` `TOWER_DEFS` | 225–278px ≈ 2.3–2.9 cells |
| Drop forgiveness | `grid.gd` `SNAP_TOLERANCE` | 24px outside a cell still counts (placement only) |
| Enemy size | `wave_manager.gd` | radius 24 × the archetype multiplier; boss 38 (must stay under the 80px road width) |
| Board scale | see note below | everything is sized so a cell lands at ~48 CSS px on a landscape phone |

The road (`PATH`) and the grid rows (`GRID_ROWS`) are defined as plain arrays in
`game.gd`. The road drawing, enemy walking, grid and map decoration all follow
from `PATH`; the grid rows are hand-placed for the fixed S-map, in pairs filling
each gap between horizontal roads. The pairing is deliberate: a bend's vertical
leg runs from one horizontal road to the next, so the number of rows it passes is
how many cells you get down the narrow outer side of that turn — two rows make it
a 2×2 block instead of a lone column.

**The whole board is sized for a phone, and the sizes are coupled.** The game is
authored in a fixed 1280×720 world that `canvas_items` stretch fits to the screen,
so on a landscape phone everything arrives at roughly half scale — a 96×88 cell
lands at ~48×44 CSS px, right at the minimum comfortable tap target, which is why
the cells are as large as they are and why only 40 fit. The vertical budget is
exact: the HUD bar ends at y 40, the bottom-corner buttons start at y 664, and
4 rows × 88 + 3 roads × 80 = 592 uses all but 32px of that gap. Those last 32px
are the grass strip above the top road, and they are load-bearing — without them a
boss walking the top road draws its health bar up behind the HUD. That is also why
rows are 88 tall rather than a square 96.

If you ever change `CELL_WIDTH`, these have to move with it or the game quietly
rebalances itself: `TOWER_DEFS` ranges and splash radii, `tower.gd`
`RANGE_GROWTH`, `projectile.gd` `speed` (so flight *time* holds), the enemy radii
in `wave_manager.gd`, `enemy_index.gd` `CELL`, and every `_draw()` literal.
Ranges are what keep the difficulty fixed: about 10 towers can cover any given
point of road, and that number depends on range measured *in cells*, not pixels.

---

## 6. Generated placeholder resources

There are **no image/audio files** — every visual is procedurally drawn and every
sound effect is synthesized in code:
- Grass, cobblestone road and grass patches: `map.gd` `_draw()`.
- Build grid cells: `grid.gd` `_draw()`.
- Enemies (colored blobs with eyes + health bar; flyers add wings + a shadow;
  status rings for slow/poison; a white pop on impact): `enemy.gd` `_draw()`.
- Towers (element-coloured orb, level pips, upgrade chevron, muzzle flash, and the red
  sell ×), projectiles, the drag ghost and the palette: their respective `_draw()` methods.
- Combat feedback: floating damage numbers (`floating_text.gd`) sized and coloured by
  the element matchup — big and gold at ×1.75, small and grey at ×0.7 — plus the
  gold-gain pop and the death puff (`death_burst.gd`). These are the only place the
  element matchup is visible while you play.
- **Sound** (`audio.gd`, the `Audio` autoload): every SFX — per-element tower shots,
  enemy hit/death, boss explosion, build/upgrade/sell/denied UI blips, wave start/clear,
  and the run-end jingles — is baked once at startup into an `AudioStreamWAV`
  and replayed through a small pool of `AudioStreamPlayer`s. Voiced as retro **chiptune /
  8-bit**: NES-style pulse (square) leads with duty cycles, fast arpeggios for chords,
  triangle-wave bass, and sample-and-hold noise for percussion/explosions. A quiet
  16-second chiptune loop (triangle bass + pulse-arpeggio melody over an Am–F–C–G
  progression) plays continuously underneath so between-wave lulls aren't silent. No
  sound files ship with the game. Press **M** to mute everything.
- `icon.svg` is a simple hand-written SVG placeholder for the app icon.
```
