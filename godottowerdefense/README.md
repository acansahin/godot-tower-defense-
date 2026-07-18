# Element TD Prototype (Godot 4.5)

A tiny, fully-playable 2D tower-defense prototype inspired by the Warcraft III
custom map **Element TD**. Built with typed GDScript, deliberately small and
readable rather than production-architected.

When you press **Play** you get: a grassy map, an S-shaped cobblestone road,
enemies that spawn in escalating waves and walk the road, clickable build spots
where you place **Archer** or **Cannon** towers, a gold economy, lives, and a
win/lose flow.

---

## 1. Setup / How to run

1. Install **Godot 4.5** (standard build, GDScript — no C# needed).
2. Open the Godot Project Manager → **Import**.
3. Select `godot-tower-defense/project.godot` and open it.
4. Godot imports the assets on first open (creates a local `.godot/` cache).
5. Press **F5** / the ▶ **Play** button. `scenes/Main.tscn` is the main scene.

No external assets, plugins, or downloads are required — all art is drawn in
code with primitive shapes and colors.

### Controls
- **Left-click a build spot** (the glowing pads beside the road) to open the
  build menu.
- Pick **Archer** or **Cannon** (greyed out if you can't afford it).
- Click anywhere else to close the menu.
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
├── scenes/
│   ├── Main.tscn            # The level (main scene)
│   ├── Enemy.tscn           # A single enemy
│   ├── ArcherTower.tscn     # Archer tower
│   ├── CannonTower.tscn     # Cannon tower
│   ├── Arrow.tscn           # Archer projectile
│   ├── Cannonball.tscn      # Cannon projectile (splash)
│   ├── TowerSpot.tscn       # Clickable build pad (Area2D)
│   ├── HUD.tscn             # Gold / Lives / Wave bar
│   ├── BuildMenu.tscn       # Archer / Cannon / Cancel popup
│   └── EndScreen.tscn       # Victory / Game Over overlay
└── scripts/
    ├── game.gd              # "Game" autoload: shared state + constants
    ├── main.gd             # Wires the level together
    ├── map.gd              # Draws grass + cobblestone S-road
    ├── enemy.gd            # Path walking, health, health bar
    ├── tower.gd            # Base tower (targeting + firing)
    ├── archer_tower.gd     # Fast single-target tower
    ├── cannon_tower.gd     # Slow high-damage splash tower
    ├── projectile.gd       # Base projectile (homing + splash)
    ├── arrow.gd            # Arrow visuals
    ├── cannonball.gd       # Cannonball visuals
    ├── tower_spot.gd       # Build-pad click handling
    ├── wave_manager.gd     # Spawns escalating waves
    ├── hud.gd              # HUD label updates
    ├── build_menu.gd       # Build popup logic
    └── end_screen.gd       # Win/lose overlay + restart
```

---

## 3. Scene structure & node hierarchy

### `Main.tscn` (main scene)
```
Main (Node2D)               [main.gd]
├── Map (Node2D)            [map.gd]   -> draws grass + road
├── TowerSpots (Node2D)                -> build pads spawned here at runtime
├── Enemies (Node2D)                   -> enemies spawned here at runtime
├── Towers (Node2D)                    -> built towers live here
├── Projectiles (Node2D)               -> arrows / cannonballs live here
├── WaveManager (Node)      [wave_manager.gd]
└── UI (CanvasLayer)
    ├── HUD (instance of HUD.tscn)         [hud.gd]
    ├── BuildMenu (instance of BuildMenu.tscn)  [build_menu.gd]
    └── EndScreen (instance of EndScreen.tscn)  [end_screen.gd]
```

### `Enemy.tscn`
```
Enemy (Node2D)              [enemy.gd]   -> body + health bar drawn in _draw()
```

### `ArcherTower.tscn` / `CannonTower.tscn`
```
ArcherTower (Node2D)        [archer_tower.gd]
CannonTower (Node2D)        [cannon_tower.gd]
```

### `Arrow.tscn` / `Cannonball.tscn`
```
Arrow (Node2D)              [arrow.gd]
Cannonball (Node2D)         [cannonball.gd]
```

### `TowerSpot.tscn`
```
TowerSpot (Area2D)          [tower_spot.gd]
└── CollisionShape2D (CircleShape2D, r=26)
```

### `HUD.tscn`
```
HUD (Control)               [hud.gd]
├── Bar (ColorRect)
├── GoldLabel (Label)
├── LivesLabel (Label)
└── WaveLabel (Label)
```

### `BuildMenu.tscn`
```
BuildMenu (Control)         [build_menu.gd]
├── Backdrop (ColorRect)    -> full-screen click catcher (closes menu)
└── Panel (PanelContainer)
    └── VBox (VBoxContainer)
        ├── Title (Label)
        ├── ArcherButton (Button)
        ├── CannonButton (Button)
        └── CancelButton (Button)
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
globally accessible as `Game`. It holds the shared map layout (`PATH`,
`TOWER_SPOTS`), the costs, and the mutable `gold` / `lives` with signals.

---

## 4. How the pieces talk

- **`Game` (autoload)** owns gold & lives and broadcasts `gold_changed`,
  `lives_changed`, `game_over`, `victory`. It also stores the road `PATH` and
  `TOWER_SPOTS` so every script reads one source of truth.
- **`WaveManager`** spawns enemies with growing count/HP/speed using plain
  `Timer` nodes (so a restart can't leave a spawn loop running).
- **`Enemy`** walks `Game.PATH`; on death it grants gold, on reaching the end it
  costs a life. Both cases emit `removed` so the wave manager can count down.
- **`Tower`** (base) finds the closest enemy in range and fires on a cooldown.
  `ArcherTower` fires single-target arrows; `CannonTower` fires cannonballs that
  also splash the nearest **one** extra enemy for **50%** damage.
- **`Projectile`** homes onto its target and applies damage (plus optional
  splash) on impact.
- **`TowerSpot`** is a clickable `Area2D`; clicking it opens the `BuildMenu`,
  which asks `Main` to build and spend gold.

---

## 5. Tuning values (all in one glance)

| Thing | Where | Value |
|---|---|---|
| Starting gold | `game.gd` `START_GOLD` | 150 |
| Starting lives | `game.gd` `START_LIVES` | 20 |
| Archer cost | `game.gd` `ARCHER_COST` | 40 |
| Cannon cost | `game.gd` `CANNON_COST` | 90 |
| Archer: range / interval / dmg | `archer_tower.gd` | 170 / 0.35s / 9 |
| Cannon: range / interval / dmg | `cannon_tower.gd` | 150 / 1.6s / 35 |
| Cannon splash radius / factor | `cannon_tower.gd` | 70px / 0.5 |
| Waves | `wave_manager.gd` `TOTAL_WAVES` | 10 |
| Prep time between waves | `wave_manager.gd` `PREP_TIME` | 4s |
| Wave scaling | `wave_manager.gd` `_start_wave()` | count `5+2·n`, HP `25+18·n`, speed `60+4·n`, reward `3+n` |
| Road path | `game.gd` `PATH` | 6 waypoints (S-shape) |
| Build spots | `game.gd` `TOWER_SPOTS` | 8 positions |

The road and the build spots are defined as plain arrays of `Vector2` in
`game.gd` — edit those two arrays to reshape the level, and everything (road
drawing, enemy walking, spot placement) follows automatically.

---

## 6. Generated placeholder resources

There are **no image/audio files** — every visual is procedurally drawn:
- Grass, cobblestone road and grass patches: `map.gd` `_draw()`.
- Enemies (colored blobs with eyes + health bar): `enemy.gd` `_draw()`.
- Towers, arrows, cannonballs, build pads: their respective `_draw()` methods.
- `icon.svg` is a simple hand-written SVG placeholder for the app icon.
```
