# Element TD Prototype (Godot 4.7)

A tiny, fully-playable 2D tower-defense prototype inspired by the Warcraft III
custom map **Element TD**. Built with typed GDScript, deliberately small and
readable rather than production-architected.

When you press **Play** you get: a grassy map, an S-shaped cobblestone road, a
faint build grid beside the road, 20 waves of enemies drawn from a data table of
**creep archetypes** (including flyers, tanks, swarms, splitters, regenerators and
periodic **bosses**), a drag-and-drop **element tower palette** (Fire / Water /
Nature / Earth, the dual towers Steam / Lava / Ice, and Lightning), an
**element-matchup** system (each base element is strong/weak against another, so
tower choice vs. an enemy's armor element matters), one-click tower **upgrades**,
tower **selling**, a gold economy with interest and streak bonuses, lives, and a
win/lose flow.

Towers are **data-driven**: every tower is one entry in `Game.TOWER_DEFS` with a
colour and an effect payload (damage, splash, slow, poison). Adding a new tower
is just adding a row — no new scene or script. See
[`docs/element-td-towers.md`](docs/element-td-towers.md) for the full Element TD
tower reference this is growing toward.

---

## 1. Setup / How to run

1. Install **Godot 4.7** (standard build, GDScript — no C# needed).
2. Open the Godot Project Manager → **Import**.
3. Select `godot-tower-defense/project.godot` and open it.
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
- Cells are the faint squares on the grass; two rows fit flush between each pair
  of roads. Towers can't be built on the road or on an occupied cell.
- **Click a tower's body to upgrade it.** When you can afford the next level, a
  green ▲ arrow (with its cost) appears on the tower — clicking upgrades it
  instantly (up to level 3). Each level boosts damage, range, fire rate (and DoT).
- **Sell a tower** by clicking the small red ✕ in its bottom-right corner; you get
  back half of everything you spent on it (shown next to the ✕).
- **Ground-only towers** (Earth, Lava) can't hit flyers; the others can.
- The HUD shows a **next-wave preview** (archetype, count, boss flag, and armor
  element colour) before it spawns — a **Send Next ▶** button lets you call it
  early for a small gold bonus instead of waiting out the prep timer.
- Each enemy's armor element tints its body; matching it against the right tower
  element deals bonus damage (and less if it's the wrong one) — see the element
  matchup below.
- Survive all 20 waves to win; lose all your lives and it's game over. Both
  screens offer **Restart** and **Main Menu**.

---

## 2. Folder structure

```
godot-tower-defense/
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
│   └── EndScreen.tscn       # Victory / Game Over overlay
└── scripts/
    ├── game.gd              # "Game" autoload: shared state, grid + TOWER_DEFS
    ├── audio.gd             # "Audio" autoload: synthesized chiptune SFX + music
    ├── menu.gd              # Title screen: play / how-to-play / sound / quit
    ├── main.gd             # Wires the level together (placement, upgrades, sell)
    ├── map.gd              # Draws grass + cobblestone S-road
    ├── grid.gd            # Builds + draws the faint placement grid, snapping
    ├── enemy.gd            # Path walking, health, flyer visuals, slow/poison
    ├── tower.gd            # Generic tower: targeting, firing, upgrade + sell badges
    ├── projectile.gd       # Homing projectile: damage, splash, slow, poison
    ├── wave_manager.gd     # Spawns the 20-wave table (archetypes, bosses, economy)
    ├── tower_palette.gd    # Top-right drag-source, lists Game.TOWER_ORDER
    ├── placement_preview.gd # Green/red ghost cell shown while dragging
    ├── hud.gd              # HUD label updates
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
├── Projectiles (Node2D)               -> tower projectiles live here
├── Preview (Node2D)        [placement_preview.gd]  -> drag ghost (hidden)
├── WaveManager (Node)      [wave_manager.gd]
└── UI (CanvasLayer)
    ├── HUD (instance of HUD.tscn)          [hud.gd]
    ├── TowerPalette (Control)              [tower_palette.gd]
    └── EndScreen (instance of EndScreen.tscn)  [end_screen.gd]
```

### `Enemy.tscn`
```
Enemy (Node2D)              [enemy.gd]   -> body + health bar in _draw();
                                            flyers add wings + shadow
```

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
└── SendButton (Button)      -> "Send Next ▶", enabled during the prep gap
```

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
grid definition (`GRID_ROWS`, `CELL_WIDTH`, `ROAD_CLEARANCE`, `GRID_COL_*`), the
costs, and the mutable `gold` / `lives` with signals.

---

## 4. How the pieces talk

- **`Game` (autoload)** owns gold & lives and broadcasts `gold_changed`,
  `lives_changed`, `game_over`, `victory`. It also stores the road `PATH` and
  the grid constants so every script reads one source of truth.
- **`Grid`** precomputes the buildable cells (flush against the road, two rows
  filling each gap between horizontal roads, tiled flush to the vertical bends),
  draws them faintly, and answers `snap(world_pos) -> Rect2` for placement.
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
  interest on banked gold each wave clear (8%, capped at 40), a leak-free bonus
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
  entry (stats + effect payload + colour). It finds the closest **targetable**
  enemy in range and fires a `Projectile` carrying that payload; `can_hit_flying`
  gates flyers. It tracks an upgrade `level` (pips + green upgrade arrow) and
  `total_spent` (red sell ✕, refunds `SELL_REFUND`).
- **`Projectile`** homes onto its target and applies its payload on impact:
  direct damage, an area **splash** (all enemies in radius, `hits_flying`-gated),
  a **slow**, a **poison** DoT, and/or a chance to **stun**. Direct, splash and
  poison damage are all scaled by `Game.element_mult(element, enemy.armor_element)`
  — the tower's element vs. the enemy's armor element.
- **`Main`** handles input: palette drags build the chosen tower on the grid; a
  click on a tower's body upgrades it, and a click on its ✕ badge sells it (no
  menus).

---

## 5. Tuning values (all in one glance)

| Thing | Where | Value |
|---|---|---|
| Starting gold | `game.gd` `START_GOLD` | 150 |
| Starting lives | `game.gd` `START_LIVES` | 20 |
| Tower stats (all towers) | `game.gd` `TOWER_DEFS` | per-tower cost / dmg / range / interval / effects |
| Base towers | `TOWER_DEFS` | Fire (dmg), Water (slow), Nature (poison), Earth (splash, ground) |
| Dual towers | `TOWER_DEFS` | Steam (dmg+slow), Lava (splash+burn, ground), Ice (slow+poison) |
| Neutral tower | `TOWER_DEFS` | Lightning (25% chance to stun 1.2s) |
| Upgrade: max level / growth | `tower.gd` | L3, dmg ×1.6, range +20, interval ×0.82, DoT ×1.6 |
| Upgrade cost | `tower.gd` `upgrade_cost()` | `build_cost × level` (e.g. Fire 40, 80) |
| Sell refund | `tower.gd` `SELL_REFUND` | 50% of total gold spent |
| Element matchup | `game.gd` `ELEMENT_BEATS` | cycle fire→nature→earth→water→fire; ×1.75 dmg if you beat the target's armor element, ×0.7 if it beats you, ×1 if either side is neutral (applies to direct, splash and poison damage) |
| Waves | `game.gd` `WAVES` | 20 fixed entries (archetype + optional boss/element per wave) |
| Creep archetypes | `game.gd` `WAVE_TYPES` | normal, fast, swarm, tank, immune, regen, air (flyer), split (splits on death) — each is a set of HP/speed/count/radius multipliers and flags on top of the base scaling |
| Immune archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `cc_immune` | ignores **slow and stun**, but **not poison** — poison is damage rather than crowd control, so Nature/Ice/Lava stay the answer to these waves instead of the whole roster going dead |
| Regen archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `REGEN_DELAY` | heals 3.5% of max HP/s, but **paused for 2s after taking any damage** — so it only heals through gaps in your coverage instead of setting a hard DPS threshold. Its "+" marker dims while suppressed. Poison ticks count as damage, so a single Nature/Ice/Lava tower shuts the healing off entirely |
| Prep time between waves | `wave_manager.gd` `PREP_TIME` | 4s (skippable via the HUD's Send Next button, for a small gold bonus) |
| Wave scaling (`n` = wave) | `wave_manager.gd` `_start_wave()` | count `5 + int(2.5·n)`, HP `20 + 10·n + 2.55·n²`, speed `60 + 6·n`, reward `3 + n`, each × the archetype's multipliers |
| Flyers (non-Air waves) | `wave_manager.gd` | from wave 3, 15% chance per enemy (halved on top of Air waves existing); `make_flying()` gives HP ×0.65, speed ×1.25 |
| Bosses | `game.gd` `WAVES` (`"boss": true` per entry) | HP ×6, speed ×0.6, reward ×10, costs 10 lives |
| Economy: interest | `wave_manager.gd` `INTEREST_RATE`/`INTEREST_CAP` | 8% of banked gold per wave cleared, capped at 40 |
| Economy: leak-free bonus | `wave_manager.gd` `LEAK_FREE_BONUS` | +6 gold if no enemy reached the end that wave |
| Road path | `game.gd` `PATH` | 6 waypoints (S-shape) |
| Build grid | `game.gd` `GRID_ROWS` / `CELL_WIDTH` | 64px cells, rows flush per band |

The road (`PATH`) and the grid rows (`GRID_ROWS`) are defined as plain arrays in
`game.gd`. The road drawing, enemy walking and grid all follow from `PATH`; the
grid rows are hand-placed for the fixed S-map so two towers sit flush between
each pair of horizontal roads.

---

## 6. Generated placeholder resources

There are **no image/audio files** — every visual is procedurally drawn and every
sound effect is synthesized in code:
- Grass, cobblestone road and grass patches: `map.gd` `_draw()`.
- Build grid cells: `grid.gd` `_draw()`.
- Enemies (colored blobs with eyes + health bar; flyers add wings + a shadow;
  status rings for slow/poison): `enemy.gd` `_draw()`.
- Towers (element-coloured orb, level pips, upgrade arrow, sell ✕), projectiles,
  the drag ghost and the palette: their respective `_draw()` methods.
- **Sound** (`audio.gd`, the `Audio` autoload): every SFX — per-element tower shots,
  enemy hit/death, boss explosion, build/upgrade/sell/denied UI blips, wave start/clear,
  and the victory/game-over jingles — is baked once at startup into an `AudioStreamWAV`
  and replayed through a small pool of `AudioStreamPlayer`s. Voiced as retro **chiptune /
  8-bit**: NES-style pulse (square) leads with duty cycles, fast arpeggios for chords,
  triangle-wave bass, and sample-and-hold noise for percussion/explosions. A quiet
  16-second chiptune loop (triangle bass + pulse-arpeggio melody over an Am–F–C–G
  progression) plays continuously underneath so between-wave lulls aren't silent. No
  sound files ship with the game. Press **M** to mute everything.
- `icon.svg` is a simple hand-written SVG placeholder for the app icon.
```
