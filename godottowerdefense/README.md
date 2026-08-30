# Element TD Prototype (Godot 4.7)

A tiny, fully-playable 2D tower-defense prototype inspired by the Warcraft III
custom map **Element TD**. Built with typed GDScript, deliberately small and
readable rather than production-architected.

When you press **Play**, the run starts immediately. The endless run uses the winding
forest for waves 1–10, changes to
the inward spiral for waves 11–20, then uses the broad S road for waves 21–30. The run is
structured as 10-wave map chapters so Z and later road shapes can be appended. Towers, gold
and lives survive a chapter change; a tower
that would land on the new road or blocked scenery is moved to the nearest clear ground. Both
boards are hand-painted 1536x864 worlds whose gameplay roads are **traced out of their
paintings**, not authored beside them. The run draws enemies from a data table
of **creep archetypes** (including flyers, tanks, swarms, splitters, regenerators, periodic
**bosses** and **elite** waves). The buildable roster is four elements —
**Water / Fire / Nature / Earth** — which grow into the map's own combination towers by
fusion (see below); Light and Darkness are retired for now, their data and art left in the
repo. Numbers come from the original Warcraft III map where the port takes them
(see [docs/element-td-data.md](docs/element-td-data.md)). On top of that sits an
**element-matchup** system (each is strong and
weak against another, so tower choice vs. an enemy's armor element matters),
**tap-to-open** tower panels (upgrade, fuse, sell), **time controls** (pause and
1x/2x/3x), a gold economy with interest and streak bonuses, lives,
and a **run summary** reporting how deep you got.

A run is **`Balance.STANDARD_WAVES` long — 50 — and can be won**. Waves 1–20 are hand-authored
so each mechanic is introduced deliberately; past that `WaveGenerator` supplies them. The run
ends when you clear the last wave or your lives run out, and the wave you reached is the score.

**The run length is one dial.** Set `Balance.STANDARD_WAVES` and the boss waves, the HP ramp
and the speed ramp all re-time themselves — a 50-wave run and a 100-wave run finish at the
same difficulty and differ only in how finely they climb to it. Nothing below is a per-wave
rate any more; each is an endpoint plus a slope derived from the length.

Every fifth of the run — waves **10, 20, 30 and 40** — an **element avatar boss** arrives
**alone**, with no ordinary creeps in the wave at all. One for each of the four elements, in a
random order every run, named in the next-wave preview so you have the prep gap to build its
counter. Beat it and that element unlocks for **fusion** for the rest of the run; let it walk
off the end of the road and you lose it. Two set-piece bosses hold the midpoint (**25**) and
the final wave (**50**), and those keep their escort.

Fusion is how cross-element power enters a run, and it happens on the board rather than on a
card. Tap any tower and its panel offers to absorb an unlocked element for gold. The set of
elements a tower carries is its whole identity:

| Elements | What it becomes |
|---|---|
| 1 | one of the four base towers |
| 2 | a **dual** — Steam, Lava, Sun, Clay, Well, Roots |
| 3 | a **triple** — Infernal, Rainbow, Dinosaur, Flesh Golem |
| 4 | **Pure** — nothing resists it and no enemy rule stops it |

Order does not matter, exactly as in the source map: Fire absorbing Water and Water
absorbing Fire both produce Steam. All ten combinations, their names, their per-tier name
ladders (Steam → Vapor → Immolation) and their abilities are read out of the original
Warcraft III map — see [docs/element-td-data.md §3.1](docs/element-td-data.md). Fusing is
permanent, and a fused tower keeps climbing the same five-level damage ladder as every
other tower. Adding a combination is a row in `Game.FUSIONS`.

Losing banks **Essence**, scaled to the wave you reached, and Essence buys permanent
**Workshop** levels from the title screen — tower damage, attack speed, range, starting gold
and starting lives. Those apply to every run afterwards, through the *same* modifier fold
the fusion ladder builds on. Progress is saved to `user://save.json` (versioned, atomic, with a
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

No plugins or downloads are required. Two kinds of art now sit side by side: the
**painted** board, all seventeen tower sets — four elements and eleven fusions, five tiers
each — and the enemies (`assets/art/`); and the **code-drawn** rest — the projectiles, every
effect but the Fire brazier, and all of the UI — still built from primitive shapes in
`_draw()`. That includes each tower's own bolt: all seventeen throw a different SHAPE, told
apart by silhouette rather than by colour, since a fused tower is tinted with the fusion's
colour and several of those are close. Every sound EFFECT is still synthesized at startup;
the only audio file that ships is the background music track. See §6.

### Controls
- The game opens on a **title screen**: **Play**, **How to Play** (a controls
  summary), a **Sound** toggle, and **Quit** (hidden on Web).
- **Drag a tower from the palette** (top-right, lists every tower with its colour
  and cost) onto **any legal ground** to build it. A green ghost disc marks a legal spot,
  red an illegal/unaffordable one, and the ghost also previews **the range that tower would
  cover** — so you can judge placement before spending the gold.
- **Hover a placed tower** to light up its range ring. Ranges stay faint otherwise, so a
  full board doesn't turn into a tangle of overlapping circles.
- **Place a tower anywhere the terrain allows, and the terrain decides.** Legal ground is
  off the road, on OPEN GROUND (grass, never trees, cliffs or water), inside the play area,
  and clear of the towers already standing. While you drag, the ground the rule REFUSES is
  shaded, so the answer is visible before you ask it. Where the open ground is comes from
  the painting itself, not from hand-placed zones: `tools/build_mask.py` reads the board art
  and writes a mask the placement rule samples, so the forest really is closed ground rather
  than merely looking closed. A lattice of marked pads used to stand between the rule and
  the player; it made legal spots unmissable and decided where towers went, and it is gone.
  The ghost never disappears over bad ground; it turns red, because a ghost that vanishes
  tells you nothing
  about why.
- **Click / tap a tower to upgrade it** (up to level 5) — each level raises **damage only**,
  and a painted tower swaps to that tier's art *at the same size*: an upgrade never takes
  more board than the tower already stood on. A green ▲ chevron floats beside any tower whose
  next level you can already afford, so you can spot upgrade candidates at a glance.
- **Tap a tower to open its panel** — upgrade, absorb an unlocked element, or sell.
  Selling refunds most of everything you spent on it, fusion costs included. The panel
  replaced a 26px sell "×" tucked into the corner of the tower's cell, which was the
  smallest tap target in the game and the one thing that could not be made bigger.
- Towers always target the enemy **closest to the exit** ("First") — the one most likely
  to cost you a life. There is no per-tower target picker.
- **The whole board is on screen at once.** The world is slightly larger than the design
  viewport and the camera zooms to frame all of it, so there is no scrolling and no leak
  you cannot see.
- **Time controls** sit in the bottom-left corner: **Pause** (or **Space**) freezes
  everything, and the speed button (or **F**) cycles **1x → 2x → 3x**.
- **Ground-only towers** (Earth) can't hit flyers — but fusing Earth into Lava or any
  triple lifts that restriction, which is the source map's own rule.
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
│   ├── element-td-towers.md # Element TD tower reference (design notes)
│   └── element-td-data.md   # Every number extracted from the source maps
├── assets/
│   └── art/                 # The project's only bitmap assets (icon.svg aside)
│       ├── board_source.png # The endless-run board; Game.PATH is traced out of it
│       ├── maps/            # Separate painted boards (winding, s, ...)
│       └── towers/          # <element>_1..5.png, cut from _source_<element>.png by
│                            # tools/cut_sprites.py (at the repo root, not here)
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
    ├── game.gd              # "Game" autoload: shared state, placement rule + TOWER_DEFS
    ├── meta.gd              # "Meta" autoload: Essence, Workshop levels, offline reward
    ├── workshop.gd          # Between-runs screen: spend Essence on permanent upgrades
    ├── run.gd               # "Run" autoload: avatar boss order, unlocked fusions, mods
    ├── tower_mods.gd        # Folded modifier totals for one (tower id, element) pair
    ├── wave_generator.gd    # Endless wave definitions past the seed table
    ├── audio.gd             # "Audio" autoload: synthesized chiptune SFX + music track
    ├── enemy_index.gd       # "EnemyIndex" autoload: per-frame spatial hash for targeting
    ├── menu.gd              # Title screen: play / how-to-play / sound / quit
    ├── main.gd             # Wires the level together (placement, upgrade, fuse, sell)
    ├── map.gd              # Draws the painted board (+ the traced-road overlay, off)
    ├── grid.gd             # Shades the ground placement refuses, while a tower is dragged
    ├── sprites.gd          # Loads the painted tower art + its ground anchor; null
    │                       # for anything not painted yet, so the code art falls back
    ├── enemy.gd            # Path walking, health, flyer visuals, slow/poison
    ├── enemy_layer.gd      # Draw-only child layer for enemy.gd (body / overlay split)
    ├── tower.gd            # Generic tower: targeting, stats, element set + fusion
    ├── tower_behavior.gd   # Base strategy: what a tower does with its frame
    ├── bolt_behavior.gd    # The default behavior: cooldown -> one homing bolt
    ├── projectile.gd       # Homing projectile: damage, splash, slow, poison
    ├── projectiles.gd      # Object pool on the $Projectiles node (reused bolts)
    ├── effects.gd          # Object pool on the $Effects node (floating text + bursts)
    ├── area_ring.gd        # Expanding ring at an effect's REAL radius: every splash hit, and the area slow
    ├── wave_manager.gd     # Spawns the 20-wave table (archetypes, bosses, economy)
    ├── tower_palette.gd    # Top-right drag-source, lists Game.TOWER_ORDER
    ├── placement_preview.gd # Green/red ghost footprint shown while dragging
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
├── Map (Node2D)            [map.gd]   -> the painted board, stretched to WORLD_SIZE
├── Grid (Node2D)           [grid.gd]  -> shades refused ground (only while a drag is in progress)
│                                         (still named Grid; there is no grid)
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
globally accessible as `Game`. It holds the board sequence and profiles (`WINDING_PATH`,
`PATH`, build zones and obstacles), the active map layout, the placement rule
(`TOWER_RADIUS`, `ROAD_HALF`, `ROAD_KEEPOUT`, `TOWER_GAP` and the `can_build_at()` that
reads the active profile) and the
bounds of the play area (`PLAY_RIGHT`, `PLAY_TOP` — derived from the screen-space UI that
covers the board, not written down) plus the shared `dist_to_road()` helper, the
costs, and the mutable `gold` / `lives` with signals. Four more autoloads sit beside it:
`Balance` (`scripts/balance.gd`, every tunable curve and economy number),
`Run` (`scripts/run.gd`, the current run's roguelite upgrades and unlocks),
`Audio` (`scripts/audio.gd`, synthesized SFX/music) and `EnemyIndex`
(`scripts/enemy_index.gd`, the per-frame enemy spatial hash used for targeting).

**Towers pull modifiers from `Run`; nothing is pushed into them.** A tower re-derives its
stats when `Run.modifiers_changed` fires, and a tower built *after* a Workshop level was
bought reads the same source on its first `_recompute()` — so there is no back-fill step to
forget. Per-
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
  endless. It also stores the active road/profile and the placement rule so every script
  reads one source of truth. `BOARD_SEQUENCE` assigns one profile to each 10-wave chapter;
  until another profile is added, the last available board remains active.
- **`Game.can_build_at(pos, others)`** *is* the placement rule, and the only one: inside
  the play area (`PLAY_TOP` … `PLAY_RIGHT`, so no tower is half under the HUD bar or under
  the palette, which also eats the click), at least `ROAD_KEEPOUT` from the road, clear of
  every circle in `OBSTACLES`, on open ground per the board's build mask (nine samples
  around the tower's base, so it cannot perch on the last grass texel with its back in a
  tree), and at least `TOWER_GAP` from any tower already standing. A board that publishes an
  explicit `active_build_zones` allowlist uses that INSTEAD of the mask, never both — no
  shipped board sets one today.
- **Placement is free**: `main.gd` `_placement_point()` returns the cursor, and the ghost and
  the drop both validate through `can_build_at()`, so the preview cannot disagree with the
  result. A hexagonal lattice of marked pads used to sit between them and has been removed
  along with `PAD_PITCH`, `PAD_SNAP`, `PAD_ORIGIN_STEPS`, `Game.pads()`, `has_pads()` and
  `nearest_pad()`.
- **`Game.TOWER_GAP` is what spaces towers now, and it is paired with
  `Game.TOWER_SPRITE_HEIGHT`.** 112px against a 96px sprite. It was 68px — two 30px
  footprints plus air — which is right for the tap disc and wrong for art drawn 108-147px
  wide; the pads hid that for as long as they existed, because nothing could be dropped at
  68px whatever the rule said. Together the two decide how many towers the game is: the
  winding board takes **33** at this spacing, against the 12 the pad lattice allowed. Twelve
  towers had been paid for twice —
  `Balance.WC3_RANGE_SCALE` 0.45 so they still watch the road, and
  `Balance.GLOBAL_DAMAGE_MULT` 4.2 so they still kill what they watch — with `--fill-board`
  clearing the last wave as the gate. The placement rule sizes itself off the DRAWN sprite
  rather than off `TOWER_RADIUS`, so a tower can neither stand on the road nor lose its top
  behind the HUD at whatever size the art is next set to.
  `TOWER_RADIUS` does placement, overlap and the drawn footprint. Hit-testing is the one
  thing split off it, onto the larger `PICK_RADIUS`, because the painted body is drawn far
  wider than the footprint and tapping what you see used to miss.
- **`Grid`** no longer owns anything. It sweeps the play area on a 32px step and shades
  every square `can_build_at()` rejects, but only while `Main` has switched it on for a
  drag. The painting already says where the lake and the road are; this is for the margins,
  which it cannot.
- **`TowerPalette`** (top-right) draws every tower in `Game.TOWER_ORDER` with its
  colour and cost and emits `drag_started(id)` when pressed. **`Main`** then follows the
  cursor with the **`Preview`** ghost — green or red per `can_build_at()` — and builds on
  release if the spot is legal and affordable.
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
- **`Enemy`** captures `Game.active_path` when spawned and consumes its full per-frame
  travel across multiple short curve segments, so smoothed roads and 1x–3x speeds do not
  change its effective movement rate; on death it grants gold, on reaching the end it
  costs `life_cost` lives (1 normally, 10 for a boss). Both cases emit `removed`
  so the wave manager can count down. `make_flying()` marks it airborne
  (squishier, faster, shadow) — only towers with `can_hit_flying` can
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
  `level` (pips + green upgrade chevron), the `elements` it carries (a row of coloured dots
  once it has been fused) and `total_spent`. A click anywhere on the tower opens its panel;
  upgrading, fusing and selling all live there. It draws itself from **`sprites.gd`** if its
  element and tier have been painted — but only while it is UNFUSED, since the painted sets
  are per base element and a Steam tower wearing the painted Fire art would be the one place
  where what you see and what the tower is disagree. Every fusion is code art, which is what
  fifteen duals get, and is what let the board be repainted one element at a time. A sprite is hung by its **ground anchor** — the
  median middle of the bottom 4% of its opaque rows, *not* the lowest row alone, which on a
  painted tower is a sliver of one rock — so the base sits on the spot the tower occupies, and
  `SPRITE_HEIGHT` is ONE height for all five levels (92 board px). It used to be a per-level
  ladder (78 → 138) and the growth was the problem: the footprint stays `TOWER_RADIUS`
  whatever the level, so upgraded neighbours 68px apart drew over each other and merged into
  one shape. Held by height rather than width because every painted set gets proportionally
  taller as it upgrades, so a fixed height also keeps the drawn base from growing.
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
- **`Main`** handles input: palette drags build the chosen tower wherever the drop is
  legal, and a click within `TOWER_RADIUS` of a placed tower (`_tower_at`, nearest wins)
  opens the tower panel above it. The panel only REPORTS what was pressed; `Main` spends the
  gold and changes the board (`_upgrade_tower` / `_fuse_tower` / `_sell_tower`), so exactly
  one file mutates a tower. It also owns the `Camera2D` and applies the screen shake that
  `Game.shake_requested` broadcasts, so an `Enemy` can ask for a kick without knowing the
  camera exists. It also applies `Game.use_board_for_wave()` before WaveManager spawns the
  first enemy of a chapter, so painting, pathing and new placement checks change together;
  towers invalid on the new terrain are relocated to the nearest legal open position.
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
| Splash reach | `TOWER_DEFS`/`FUSIONS` `splash_radius` | Earth 90px, Lava 110, Steam 80. DRAWN on every splash hit as a ring at the true radius (`area_ring.gd`) — before that, the impact drew the same 34px pop whether the tower splashed or not, so the one stat deciding where a splash tower should STAND was the one stat never shown |
| Chaos damage | `FUSIONS` `ignores_matchup` | Infernal, Rainbow, Pure. The only payload with no enemy-side tell: slow / poison / stun each hang a status ring on the creep, but "no armour resists this" is a rule about the formula, and the damage number prints a flat 1.0 matchup as plain white. So its impact throws the bolt's own counter-rotating shards |
| Aura towers | `TOWER_DEFS` `aura_stat`/`aura_radius`/`aura_mult` | Moon and Sun boost nearby damage, Well nearby attack speed, deepening with the provider's level. Read by the NEIGHBOURS in `tower.gd` `_recompute()`, so selling the provider returns the buff exactly. The reach is DRAWN — a standing ring at `aura_radius` plus one travelling out to it (`tower.gd` `_draw_aura_ring`), inside the range circle rather than on it, because an aura tower otherwise looked exactly like a weak damage tower |
| On-kill payloads | `TOWER_DEFS` `gold_on_kill`/`life_on_kill_chance`/`execute_chance` | Money pays gold, Life has a 2% chance to return a life, Death has a 4% chance to kill outright (never a boss). Applied in `projectile.gd` `_apply()`, which is the only place a kill can be attributed to the tower that earned it |
| Upgrade: max level / growth | `balance.gd` `MAX_LEVEL`, `TOWER_DEFS.damage_tiers` | 5 tiers; damage only, listed explicitly per element (×5 a tier, ×10 into Pure — with the map's own Pure-row typos preserved). Range and interval never change |
| Upgrade cost | `balance.gd` `TIER_COSTS` | Build 50, then 60 / 105 / 180 / 300 to climb to Lv5 — 695 for a maxed tower, the same ladder for every element. (The map's own ladder is 175 / 788 / 3544 / 24444; ours is far flatter because V2 replaced the base tower stats.) The build cost is held at 50 so START_GOLD still buys two towers on wave 1; only the upgrades were raised when the board shrank to 12 pads |
| Sell refund | `balance.gd` `SELL_REFUND` / `SELL_REFUND_UNFIRED` | 80% of total gold spent, or 100% if the tower never got a shot off. `total_spent` includes fusion costs, so a Pure tower refunds against the whole road it travelled. Sell from the tower panel |
| Fusion cost | `balance.gd` `FUSION_COSTS` | 240 / 630 / 1350 gold for the 2nd, 3rd and 4th element. Scaled from the map's own 275 / 1017 combination costs against its 50-gold base tower; the map has no four-element tower, so Pure's is roughly double the triple. Raised by half with `TIER_COSTS` when the board went from 47 build spots to 12 — capacity is `pads x (build + upgrades + fusions)` and had fallen to 23,520 against a ~41,300 income ceiling. **Sized against that budget, not against a played run** — `--play-sim` does play with real gold, but it measures whether a gradual build-up SURVIVES, not whether the capacity ledger adds up |
| Run length | `balance.gd` `STANDARD_WAVES` | 50. **The dial everything else hangs off** — `ELEMENT_BOSS_WAVES`, `MIDPOINT_BOSS_WAVE`, `hp_growth()` and `speed_slope()` are all derived from it, so 60 or 100 re-times the whole run instead of moving its finish line |
| Avatar bosses | `balance.gd` `ELEMENT_BOSS_*`, `game.gd` `apply_milestone()` | Waves 10/20/30/40 — a fifth of the run apart, derived from `STANDARD_WAVES`. Each walks **ALONE** (`count` 0): no ordinary creeps share the wave. One per element in a random order per run (`Run.boss_elements`, drawn from the run seed) and named in the preview. Type pinned to `normal` so the four differ by element only, never by an inherited archetype's HP multiplier. HP ×5, speed ×0.7, reward ×8, costs 3 lives. Killing one unlocks its element for fusion; leaking it does not |
| Set-piece bosses | `game.gd` `MIDPOINT_BOSS` / `FINAL_BOSS` | Muhafız on `MIDPOINT_BOSS_WAVE` (25) is immune to every control effect; Uyanmış Muhafız on the final wave (50) cycles its own armour every 5s. Unlike the avatars these keep their creep wave — the escort is part of the wall |
| Targeting | `tower.gd` `_find_target()` | Fixed to "First" — the enemy furthest along the path (closest to the exit); no per-tower picker |
| Game speed | `hud.gd` `SPEEDS` | 1x / 2x / 3x via `Engine.time_scale`; pause via `get_tree().paused` |
| Screen shake | `main.gd` `SHAKE_DECAY`, `enemy.gd` | 7px on a boss death, 4px on a leak, bled off at 26 px/s |
| Impact SFX cap | `audio.gd` `MAX_PER_FRAME` | 3 per effect per frame — a full board at 3x otherwise floods the 12-voice pool |
| Element matchup | `game.gd` `ELEMENT_BEATS` | cycle light→darkness→water→fire→nature→earth→light; ×1.75 dmg if you beat the target's armor element, ×0.7 if it beats you, ×1 if either side is neutral (applies to direct, splash and poison damage) |
| Waves | `game.gd` `WAVES` | 20 hand-authored entries teaching one archetype at a time (archetype + optional `element`/visual override + per-wave multipliers); wave 1 keeps Normal stats but introduces the Scout art. **No boss lives in this table** — every boss wave is applied by `apply_milestone()` on top of whatever supplied the wave, so the seed table and the boss-wave list cannot drift apart. Waves 21+ come from `WaveGenerator` |
| Map chapters | `game.gd` `BOARD_SEQUENCE` / `WAVES_PER_BOARD` | winding forest on waves 1–10, spiral on 11–20, S road from 21; each new profile added to the sequence receives the next 10-wave chapter |
| Creep archetypes | `game.gd` `WAVE_TYPES` | normal, fast, swarm, tank, immune, regen, air (flyer), split (splits on death) — each is a set of HP/speed/count/radius multipliers and flags on top of the base scaling |
| Immune archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `cc_immune` | ignores **slow and stun**, but **not poison** — poison is damage rather than crowd control, so Nature stays the answer to these waves instead of the whole roster going dead |
| Regen archetype | `game.gd` `WAVE_TYPES` + `enemy.gd` `REGEN_DELAY` | heals 3.5% of max HP/s, but **paused for 2s after taking any damage** — so it only heals through gaps in your coverage instead of setting a hard DPS threshold. Its "+" marker dims while suppressed. Poison ticks count as damage, so a single Nature tower shuts the healing off entirely |
| Prep time between waves | `wave_manager.gd` `PREP_TIME` | 4s (skippable via the HUD's Send Next button, for a small gold bonus) |
| Enemy speed / durability | `balance.gd` `CREEP_SPEED_PERCENT` / `CREEP_HP_PERCENT` | every board uses ×0.82 movement speed for clearer motion and ×1.20 HP to preserve combat pressure |
| Tower range cap | `balance.gd` `MAX_TOWER_RANGE` | 300px. **The only unfaithful number in the port.** Light and Darkness reach 2000 WC3 units (700px), which watches 99% of the road from one spot — as it does on the original's own arena, which is why this is a design choice and not a repair. Capped, they watch 51% and take four towers to cover 95% of the road, against Fire's 18% and twelve. The defs keep the real 2000; this caps what the board honours |
| Wave scaling (`n` = wave) | `balance.gd` | HP `225 × hp_growth()^(n-1) × 1.20`, where `hp_growth()` is derived so wave `STANDARD_WAVES` lands on `FINAL_HP_FACTOR` (55× wave 1) — at 50 waves that is ×1.085 per wave. Both ends have moved since: the floor 75 → 225 and the finish 200× → 120× → 40× → 55×, the last of those read off `--play-sim` rather than off a maxed board. Speed `(80 + (n-1)·speed_slope()) × 0.82`, derived so the last wave reaches `FINAL_SPEED_RAW` 260 raw = 213 px/s = a 15s crossing of the 3199px road. Count ramps `8 + n` to the map's flat 28 cap. Reward `3 + n`. Each × the archetype's multipliers |
| Why HP/speed are endpoints, not rates | `balance.gd` | **Measured.** With the ported flat `1.16` HP rate and the uncapped `80 + 9n` speed, a 50-wave run put the last wave at 1440× wave 1 and 435 px/s. `--fill-board` (a MAXED board) died on wave 35; softening HP alone to `1.09` — a 21× lighter finish — only reached 48, and `1.13`/`1.11` both died on exactly **43**, the signature of a limiter neither touched. That limiter was speed. Anchoring both endpoints took the same board from 35 to 49 |
| Flyers | `wave_manager.gd` | **the Air archetype only** — there is no per-enemy roll on ground waves any more; `make_flying()` gives HP ×0.65, speed ×1.25 |
| Bosses | `game.gd` `apply_milestone()` (`"boss": true` on the produced def) | HP ×6, speed ×0.6, reward ×10, costs 10 lives |
| Economy: interest | `balance.gd` `INTEREST_RATE`/`INTEREST_CAP` | 2.5% of banked gold per wave cleared, capped at 400. The map pays 2.5% every 15s and has no cap; the cap is ours, so that hoarding gold never beats building |
| Economy: leak-free bonus | `wave_manager.gd` `LEAK_FREE_BONUS` | +6 gold if no enemy reached the end that wave |
| Road paths | `game.gd` `WINDING_PATH` / `PATH` / `S_PATH` | all three traced routes are sampled into smooth walking curves: winding uses 36 controls → 141 points for waves 1–10, spiral 114 → 227 for 11–20, and S 32 → 125 from wave 21 |
| Placement | `game.gd` `TOWER_RADIUS` / `ROAD_KEEPOUT` / `TOWER_GAP` / `FOOTPRINT_PROBE` | 30px footprint, **83.2px** clear of the active road centre-line (the painted base, not the tap disc, is what must clear the kerb), **112px** centre-to-centre (sized against the drawn sprite, not the footprint), base probed at 0.2 × radius. Placement is free — anywhere `can_build_at()` says yes; **33** such spots fit on winding |
| Ground plane | `game.gd` `GROUND_SQUASH` | 0.45 — how flat a circle lying on the board is drawn. One number for every shadow, pad, aura ring and ground glow; measure a board's own with `tools/art_match.py` and move it to match. Circles on top of a *tower* (Fire's brazier, the pool/rune/fusion rings) follow the art's plane instead and stay out of it |
| Art grade | `game.gd` `ART_TINT` | `WHITE`. One multiply over every painted tower and creep, at the single `draw_texture_rect` each passes through — the dial for a roster lit for a different board than it stands on |
| Blocked ground | active board profile | winding restricts new builds to its painted clearings; spiral and S block their painted water and otherwise allow clear off-road ground |
| Tower ranges | `game.gd` `TOWER_DEFS` × `WC3_RANGE_SCALE`, capped | 175–300px |
| Enemy size | `wave_manager.gd` | radius 24 × the archetype multiplier; boss 38 (must stay under the 80px road width) |
| Board scale | see note below | everything is sized so a tower lands at ~60 CSS px across on a landscape phone |

**The geometry follows the picture, not the other way round.** `WINDING_PATH` follows
`assets/art/maps/winding_forest_close_v1.png`; `PATH` follows the spiral in
`assets/art/board_source.png`; `S_PATH` follows `assets/art/maps/s_forest_v1.png`. The
spiral was derived by `tools/trace_road.py`, whose water
scan also produced `Game.OBSTACLES`; the winding route was checked against its painting by
eye. Everything reads the selected profile: enemy walking, road keep-out, build zones and
the coverage reported by `--dump-board`. Re-trace after any repaint and check it with
`map.gd`'s `show_road` overlay. Whether a line sits down the middle of the cobbles is obvious
in a screenshot and invisible in a number.

Each painting also has its own small water mask (`board_water.png` or the matching
`*_water.png` beside a chapter map), generated by `tools/water_mask.py`. `map.gd` selects
that mask with the board profile, so the shared flow shader animates pools and waterfalls
on every map while keeping roads, grass and rocks still.

This costs the ported geometry. The old road was one inward turn of Element TD's own
spiral, read out of its pathing map (see
[docs/element-td-data.md](docs/element-td-data.md) §5) and measured against it; this one is
drawn. The trade was made deliberately when the art direction moved to a painted board, and
the coverage table in that document describes the old board — `--dump-board` reports this
one. Measure any change with it before and after; the numbers move in ways eyeballing does
not predict.

**The whole board is sized for a phone, and the sizes are coupled.** The game is
authored in a fixed 1280×720 world that `canvas_items` stretch fits to the screen,
so on a landscape phone everything arrives at roughly half scale — a 60px tower footprint
lands at ~30 CSS px, which is why the tap target is the *drawn* sprite (much bigger than
the footprint) and why the sell × sits on the tower rather than in a panel.

The UI eats into the board on two sides, and placement knows it: `Game.PLAY_TOP` and
`Game.PLAY_RIGHT` convert the HUD bar (40 screen px) and the tower palette (200) into world
px, and `can_build_at()` keeps a whole tower inside them. The palette matters most — it
swallows clicks across its whole rect, so a tower under it could never be upgraded or sold.
`PLAY_RIGHT` was a literal for a while and went stale through a world resize; it is now
derived. The road is kept out of that strip too.

If you ever change `TOWER_RADIUS`, these have to move with it or the game quietly
rebalances itself: `TOWER_DEFS` ranges and splash radii, `tower.gd`
`RANGE_GROWTH` and `SPRITE_HEIGHT`, `projectile.gd` `speed` (so flight *time* holds), the
enemy radii in `wave_manager.gd`, `enemy_index.gd` `CELL`, and every `_draw()` literal.
Ranges are what keep the difficulty fixed: about 10 towers can cover any given
point of road, and that number depends on range measured *against the tower spacing*, not
in pixels.

---

## 6. Where the art comes from

The project began with **no asset files at all** — every visual drawn in `_draw()`, every
sound synthesized at startup. That still holds for every sound EFFECT and part of the
screen, while the board, all six element towers, the creep roster and selected effects are
now painted images and the background music is a recorded track (§ Sound, above). The painted and code-drawn art paths still coexist so unfinished content can fall
back safely.

**Painted** (`assets/art/`, the project's only bitmap assets — `icon.svg` aside):
- **The board**: `board_source.png`, 1672×941. `map.gd` stretches it to `Game.WORLD_SIZE`
  and draws nothing else. It is the **style reference every tower sheet was generated
  against** — attached to the prompt, not described in it — which is what makes the towers
  look painted for it; see [docs/tower-art-prompt.md](docs/tower-art-prompt.md), which is
  mostly the story of the first six sheets that were not.
  **But a Standard run is not played on it.** `main.gd`'s `STANDARD_BOARD` is
  `maps/winding_forest_close_v1.png`, and `python tools/art_match.py` measures that board
  73 luminance on open ground against `board_source.png`'s 106, and a ground squash of
  1.000 (painted straight down) against tower sheets painted at 0.24-0.30. So the roster is
  lit and angled for a board it no longer stands on, which is what
  [docs/board-art-prompt.md](docs/board-art-prompt.md) exists to correct — it now attaches
  the TOWER sheets and asks a replacement board to join them.
- **All six element towers**, five tiers each: `towers/<element>_1..5.png`, cut from one
  generated sheet (`_source_<element>.png`) by `tools/cut_sprites.py` at `max_height` 220,
  which puts the tiers at ~2x their drawn size.
  The Water redesign established the shared silhouette for the roster: low circular early
  tiers grow mainly through wider stepped masonry, side structures and layered radial
  fortresses instead of becoming tall narrow columns. Element identity comes from masonry,
  banners and restrained contained effects, which keeps the six sets architecturally
  coherent with the board while preserving their matchup colours.
  Sets are generated five-at-a-time on
  purpose — asked for one at a time, the tiers come back looking unrelated. The tool splits
  the sheet on its empty columns, trims each sprite to its alpha bounds, and box-downscales
  it to roughly twice its drawn size: the raw art carries four to seven source pixels per
  screen pixel, which is what made the flames sparkle. Mipmaps are on, and every node that
  draws a texture asks for `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` — the 2D default is plain
  linear and ignores a mip chain entirely.
- **All nine creep archetypes**, `assets/art/enemies/<archetype>.png`, named for its
  `Game.WAVE_TYPES` key. `enemy.gd` draws one instead of the blob, hung by the same ground
  anchor as a tower, mirrored to face the way it walks, with the armour element moved to a
  ring on the ground beneath it so a painted creature never has to be tinted. The five
  archetypes are painted as numbered animation cycles (`normal_1.png` … `normal_6.png`) of
  any length — `Sprites.pose_count()` counts the files and the animation divides one cycle by
  that, so adding frames needs no code change. A GROUND creep steps on a walk phase driven by
  its own speed, so a slowed one plods and a swarmling scurries; `air` runs a WINGBEAT instead,
  at a fixed rate, because a dragon does not beat its wings slower for being slowed. Under
  either, a carrier of pure `_body` transforms — hop, forward lean, per-stride rock and a
  landing squash for a walker; lift, wing sweep and a bank for a flyer — does the work a
  single still cannot, and costs no redraw. See
  [docs/creep-art-prompt.md](docs/creep-art-prompt.md) for generating a cycle.
  Anything that marks the creature rather than the ground — health bar, boss crown, the
  slow / poison / stun / immune rings, the regen "+" — is placed off the DRAWN figure
  (`_head_y()`, `_ring_center()`), not off `radius`, which on a figure standing on its feet
  is a hoop round its ankles.
- **Not yet painted**: all fifteen duals. They draw the code art below, and `sprites.gd`
  returning `null` is what selects it — so a new set is added by dropping files in, with no
  code change.

**Drawn in code** — every visual not listed above:
- Everything an enemy wears over its sprite, and the whole enemy where none is painted
  (coloured blob with eyes; health bar; status rings for slow/poison/stun/immune; a white
  pop on impact): `enemy.gd` `_draw()`. A flyer's shadow breathes against its wingbeat —
  tight and faint at the top of the stroke, wide and dark as it settles — which is the cue
  that reads as altitude. The flapping pair of drawn wings is only for a flyer with no art,
  since Air is painted mid-flight with its own.
- Towers with no sprite yet (element-coloured orb, muzzle flash), plus the level pips,
  upgrade chevron and red sell × that every tower carries painted or not; the shaded
  no-build overlay (`grid.gd`), projectiles, the drag ghost and the palette: their
  respective `_draw()` methods.
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
  progression) is still built the same way, but it is now the FALLBACK: the background
  music is `assets/audio/guardians_of_the_verdant_spire.mp3`, imported with `loop=true` so
  the stream repeats itself. `_load_music_track()` plays it when it is in the build and
  drops back to the synthesized loop when it is not, so a stripped export is never silent.
  It is the only audio file in the project — every effect is still baked in code. The
  source track is 5:38 and 7.5 MB; what ships is a **1:57 section** cut out of it by
  `python tools/trim_mp3.py`, which drops it to 2.7 MB. The cut lands at 117.5s because
  that is where the tool's loudness report shows a dip ~12 dB under the surrounding bars,
  at the same level as the intro it loops back to — a round 120 would have cut mid-phrase.
  Short fades at both ends (0.8s in, 1.5s out) take the seam to silence. Press **M** to
  mute everything.
- `icon.svg` is a simple hand-written SVG placeholder for the app icon.
