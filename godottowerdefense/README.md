# Element TD Prototype (Godot 4.7)

A tiny, fully-playable 2D tower-defense prototype inspired by the Warcraft III
custom map **Element TD**. Built with typed GDScript, deliberately small and
readable rather than production-architected.

When you press **Play** you get: a grassy map, an S-shaped cobblestone road, a
faint build grid beside the road, enemies that spawn in escalating waves
(including occasional **flyers** and periodic **bosses**), a drag-and-drop
**element tower palette** (Fire / Water / Nature / Earth plus a few dual
combinations), one-click tower **upgrades**, tower **selling**, a gold economy,
lives, and a win/lose flow.

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
5. Press **F5** / the ▶ **Play** button. `scenes/Main.tscn` is the main scene.

No external assets, plugins, or downloads are required — all art is drawn in
code with primitive shapes and colors.

### Controls
- **Drag a tower from the palette** (top-right, lists every tower with its colour
  and cost) onto a grid cell to build it. A green ghost marks a legal cell, red an
  illegal/unaffordable one.
- Cells are the faint squares on the grass; two rows fit flush between each pair
  of roads. Towers can't be built on the road or on an occupied cell.
- **Click a tower's body to upgrade it.** When you can afford the next level, a
  green ▲ arrow (with its cost) appears on the tower — clicking upgrades it
  instantly (up to level 3). Each level boosts damage, range, fire rate (and DoT).
- **Sell a tower** by clicking the small red ✕ in its bottom-right corner; you get
  back half of everything you spent on it (shown next to the ✕).
- **Ground-only towers** (Earth, Lava) can't hit flyers; the others can.
- Survive all 10 waves to win; lose all your lives and it's game over. Both
  screens have a **Restart** button.

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
├── scenes/
│   ├── Main.tscn            # The level (main scene)
│   ├── Enemy.tscn           # A single enemy (also used for flyers / bosses)
│   ├── Tower.tscn           # Generic tower (configured from Game.TOWER_DEFS)
│   ├── Projectile.tscn      # Generic homing projectile (damage + effects)
│   ├── HUD.tscn             # Gold / Lives / Wave bar
│   └── EndScreen.tscn       # Victory / Game Over overlay
└── scripts/
    ├── game.gd              # "Game" autoload: shared state, grid + TOWER_DEFS
    ├── main.gd             # Wires the level together (placement, upgrades, sell)
    ├── map.gd              # Draws grass + cobblestone S-road
    ├── grid.gd            # Builds + draws the faint placement grid, snapping
    ├── enemy.gd            # Path walking, health, flyer visuals, slow/poison
    ├── tower.gd            # Generic tower: targeting, firing, upgrade + sell badges
    ├── projectile.gd       # Homing projectile: damage, splash, slow, poison
    ├── wave_manager.gd     # Spawns escalating waves, flyers and bosses
    ├── tower_palette.gd    # Top-right drag-source, lists Game.TOWER_ORDER
    ├── placement_preview.gd # Green/red ghost cell shown while dragging
    ├── hud.gd              # HUD label updates
    └── end_screen.gd       # Win/lose overlay + restart
```

---

## 3. Scene structure & node hierarchy

### `Main.tscn` (main scene)
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
└── WaveLabel (Label)
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
            └── RestartButton (Button)
```

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
- **`WaveManager`** spawns enemies with growing count/HP/speed using plain
  `Timer` nodes (so a restart can't leave a spawn loop running). From wave 3 on,
  each enemy has a chance to be a **flyer**; every 5th wave also spawns one
  **boss**.
- **`Enemy`** walks `Game.PATH`; on death it grants gold, on reaching the end it
  costs `life_cost` lives (1 normally, 10 for a boss). Both cases emit `removed`
  so the wave manager can count down. `make_flying()` marks it airborne
  (squishier, faster, wings + shadow) — only towers with `can_hit_flying` can
  target it. `apply_slow()` / `apply_poison()` drive the status effects (shown as
  blue / green rings).
- **`Tower`** is one generic script. `setup_def(id)` loads a `Game.TOWER_DEFS`
  entry (stats + effect payload + colour). It finds the closest **targetable**
  enemy in range and fires a `Projectile` carrying that payload; `can_hit_flying`
  gates flyers. It tracks an upgrade `level` (pips + green upgrade arrow) and
  `total_spent` (red sell ✕, refunds `SELL_REFUND`).
- **`Projectile`** homes onto its target and applies its payload on impact:
  direct damage, an area **splash** (all enemies in radius, `hits_flying`-gated),
  a **slow**, and/or a **poison** DoT.
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
| Upgrade: max level / growth | `tower.gd` | L3, dmg ×1.6, range +20, interval ×0.82, DoT ×1.6 |
| Upgrade cost | `tower.gd` `upgrade_cost()` | `build_cost × level` (e.g. Fire 40, 80) |
| Sell refund | `tower.gd` `SELL_REFUND` | 50% of total gold spent |
| Waves | `wave_manager.gd` `TOTAL_WAVES` | 10 |
| Prep time between waves | `wave_manager.gd` `PREP_TIME` | 4s |
| Wave scaling (`n` = wave) | `wave_manager.gd` `_start_wave()` | count `5 + int(2.5·n)`, HP `20 + 10·n + 3·n²`, speed `60 + 6·n`, reward `3 + n` |
| Flyers | `wave_manager.gd` | from wave 3, 30% chance; HP ×0.65, speed ×1.25 |
| Bosses | `wave_manager.gd` | every 5th wave; HP ×6, speed ×0.6, reward ×10, costs 10 lives |
| Road path | `game.gd` `PATH` | 6 waypoints (S-shape) |
| Build grid | `game.gd` `GRID_ROWS` / `CELL_WIDTH` | 64px cells, rows flush per band |

The road (`PATH`) and the grid rows (`GRID_ROWS`) are defined as plain arrays in
`game.gd`. The road drawing, enemy walking and grid all follow from `PATH`; the
grid rows are hand-placed for the fixed S-map so two towers sit flush between
each pair of horizontal roads.

---

## 6. Generated placeholder resources

There are **no image/audio files** — every visual is procedurally drawn:
- Grass, cobblestone road and grass patches: `map.gd` `_draw()`.
- Build grid cells: `grid.gd` `_draw()`.
- Enemies (colored blobs with eyes + health bar; flyers add wings + a shadow;
  status rings for slow/poison): `enemy.gd` `_draw()`.
- Towers (element-coloured orb, level pips, upgrade arrow, sell ✕), projectiles,
  the drag ghost and the palette: their respective `_draw()` methods.
- `icon.svg` is a simple hand-written SVG placeholder for the app icon.
```
