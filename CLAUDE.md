# CLAUDE.md

Guide for Claude Code sessions working on this repo. Read this first — it covers what
isn't obvious from the code. For the full architecture/tuning reference see
[godottowerdefense/README.md](godottowerdefense/README.md); don't duplicate it here.

## What this is / where it lives

"Element TD Prototype" — a 2D tower defense in **Godot 4.7 + GDScript**, GL Compatibility
renderer, inspired by the Warcraft III map *Element TD*.

> **The Godot project root is the `godottowerdefense/` subfolder, not the repo root.**

`project.godot`, `scenes/`, `scripts/`, `docs/`, `export_presets.cfg` and `README.md` all
live under `godottowerdefense/`. The repo root holds only `.github/` and this file. Every
Godot command, export path and CI `cd` depends on this.

## How to run it

The Godot MCP tools work in this environment and are the fastest check:

1. `run_project` with projectPath `<repo>/godottowerdefense`
2. `get_debug_output` — parse and runtime errors appear here
3. `stop_project`

A parse error shows up as `Debugger Break, Reason: 'Parser Error: …'` plus a
`res://scripts/x.gd:LINE` frame. Read that exact line rather than guessing — and note the
line may be in a *different* function than the one you just edited.

There are no tests. Verification = run the project and play it. Audio can't be heard
through MCP, so ask the user to listen when changing sounds.

**MCP cannot pass command-line arguments**, and the verification harnesses need them. Run
Godot directly for those (`C:\Program Files\Godot\Godot.exe.exe` — the doubled extension is
correct). Everything after a bare `--` reaches `OS.get_cmdline_user_args()`:

```
"C:\Program Files\Godot\Godot.exe.exe" --headless --path <project> \
    res://scenes/Main.tscn --quit-after 1800 -- --fill-board
```

Arg-gated harnesses currently in `main.gd`, none of which can fire in a normal session:
`--dump-stats` (every tower's stats at every level), `--dump-waves` (60 wave definitions
plus a generator-purity check), `--dump-mods` (roguelite modifiers apply / stay in scope /
unwind on reset), `--dump-meta` (essence curve, workshop costs, purchases reaching towers,
settings round-trip), `--dump-duals` (the support duals: an aura applies, deepens with
its provider's level, stops at its radius and unwinds EXACTLY when the provider is
removed; plus each dual's payload and Magic's charge cycle), `--dump-board` (road length,
cell count, and per element how much of the road one tower watches and how many towers it
takes to watch 95% of it — plus a `raw` column measuring the same with the range cap
lifted), `--fill-board` (a tower on every cell at max level, 8x speed,
auto-picks upgrades, prints each wave and the run-over line), `--show-choice` (pops the
choice screen so its `_draw` can be exercised), `--shot` (saves one drawn frame to
`user://shot.png` and prints the path — the only harness that shows you the board rather
than describing it, so **drop `--headless` for this one**), `--go-back` (rewinds the
last-seen stamp 4h so the next launch collects an offline reward), `--wipe-save` (clears
`user://save.json`).

**`--wipe-save` first when comparing against a stored baseline.** Workshop levels feed
`Run.permanent`, which feeds every tower stat, so a `--dump-stats` taken against a save
with purchases in it measures something different from one taken against a clean save.
Note that `--dump-meta` *buys* things, so it leaves a dirty save behind.

**`--headless` does no rendering, so `_draw()` never runs** — a broken draw passes a
headless run silently. Drop the flag to test drawing. `--quit-after N` bounds a run to N
frames, which is what makes all of this scriptable.

**For any refactor claiming "no behaviour change", diff `--dump-stats` before and after.**
This caught a real regression — a dropped `stun_chance` silently disabled Lightning's stun,
which no amount of playing would have surfaced. When rebuilding stats that were previously
accumulated by repeated multiplication, reproduce the repeated multiply rather than using
`pow()`, or the floating-point results will not match byte-for-byte.

## How it ships

Both workflows run automatically on push to `main`:

| Workflow | Output |
|---|---|
| `.github/workflows/deploy.yml` | Web export → GitHub Pages |
| `.github/workflows/android.yml` | Debug APK → run **Artifacts**, and a **GitHub Release** on `v*` tags |

- Both build inside the `barichello/godot-ci:4.7` container. Nothing Android-related is
  installed on the user's machine; never try to build an APK locally.
- `android.yml` also supports manual `workflow_dispatch`.
- **Artifacts vs releases:** artifacts expire (~90 days) and need a GitHub login, so they
  are for testing only. To produce a permanent, publicly downloadable APK, push a tag:
  `git tag v1.0 && git push origin v1.0`. That builds, stamps `version/name` from the tag
  and `version/code` from the run number, and attaches the APK to a Release.
- The APK is **arm64-only** (`armeabi-v7a=false` in `export_presets.cfg`) to keep it small;
  this drops pre-2017 32-bit phones.
- The Android job **generates its own debug keystore** and passes it via the
  `GODOT_ANDROID_KEYSTORE_DEBUG_*` env vars — don't rely on the image's baked-in one.
- The Web export is single-threaded on purpose, so no COOP/COEP headers are needed.
- `godottowerdefense/web/orientation.js` is injected into the web page via the preset's
  `html/head_include` and copied next to `index.html` by `deploy.yml` — it gates portrait
  phones behind a "rotate your device" panel. It is **not** a Godot resource, so if you
  add more web-only files you must copy them in the workflow too. Note a page can't force
  rotation on its own: Chrome only honours an orientation lock in fullscreen, and iOS
  Safari not at all.

## The board is measured, not eyeballed

`Game.WORLD_SIZE` is 1536x864 and the camera frames **all** of it at one zoom — there is no
panning. Run `--dump-board` before and after touching `Game.PATH`, `Game.TOWER_RADIUS`,
`Game.TOWER_GAP`, `Game.OBSTACLES`, `Balance.WC3_RANGE_SCALE` or `Balance.MAX_TOWER_RANGE`,
and `--shot` to actually look at the result; the numbers move in ways eyeballing does not
predict, and the draw code breaks in ways the numbers do not show.

**The board is a painting now, and the geometry is traced out of it.**
`assets/art/board_source.png` is the terrain; `Game.PATH` is 114 waypoints that
`python tools/trace_road.py` read off the cobbles, and `Game.OBSTACLES` is the water the
same tool's scan found. Re-trace after any change to the art and check the result with
`map.gd`'s `show_road` overlay — it draws the traced line back over the painting, which is
the only check that catches enemies walking beside the road rather than on it.

**There is also no build grid.** A tower stands wherever `Game.can_build_at()` allows: off
the road by `ROAD_KEEPOUT`, out of `OBSTACLES`, inside `PLAY_TOP`/`PLAY_RIGHT`, and
`TOWER_GAP` from its neighbours. `--dump-board` and `--fill-board` therefore sweep a
lattice (`main.gd` `_buildable_lattice()`) instead of walking a cell list.

The road that came before it was **one inward turn of the original's spiral**, ported from
the map's own pathing data — `python tools/extract_w3x.py "<map>.w3x" pathing` prints the
original arena, and docs/element-td-data.md §5 writes it up. That geometry was measured and
the current one is drawn; the trade was made deliberately when the art moved to a painted
board, so §5's coverage table describes the old board and `--dump-board` describes this one.

The history below is about the *ported* board, and it still matters, because four plausible
fixes are all wrong and one of them was shipped for a commit before play proved it:

- A faithful 700px Light watches 98% of the road and covers the board with **two** towers.
  The six elements sit at near-equal DPS, so 4x range is simply free power.
- **This is not the small board's fault.** The `pathing` dump measures 94% for the same
  tower on the original's own arena. No board shape fixes it; Element TD gets away with it
  because Light arrives late through an element draw, and ours is on the palette at wave 1.
- **Folding the path tighter makes it worse** — the legs end up closer together and one big
  circle catches more of them, while the tight folds leave almost no buildable cells.
- **Shrinking `WC3_RANGE_SCALE` breaks Fire long before it fixes Light**, because a cell
  centre sits ~84px from the road centre-line and Fire has to reach that far to work at all.
- **Growing the world until the range is fair takes four screens, and that is not a game.**
  It was tried: 2560x1440 put Light at a healthy 48%, and made the rest unplayable — a
  quarter of the board visible at a time, leaks happening off-screen where the only feedback
  is a shake, and 196 cells against an economy that pays for 18 by wave 10.

So the reach is capped (`Balance.MAX_TOWER_RANGE`, 300 on the painted board) and the world
stays on one screen. That cap is the only number in the port that is not the map's; the
definitions still carry the real 2000 so nothing is lost. On this board the cap measures
51% of the road watched from the best spot and four towers to cover 95% of it, against
Fire's 18% and twelve — re-measure it whenever the map is repainted, because the two boards
gave different answers to the same cap.

**The UI covers part of the world, and placement has to know.** The HUD and the tower palette
live in 1280x720 SCREEN space while the board lives in 1536x864 WORLD space, so the palette's
200px panel hides 240px of board — and it eats clicks, so a tower under it can never be
upgraded or sold. `Game.PLAY_TOP` / `Game.PLAY_RIGHT` derive those bounds instead of stating
them; the literal that came before them went stale through a world resize and put two
columns of buildable ground under the panel. Keep the road out of that strip too.

Two constants are tied to the road length and nothing else reads it, so they move together
or the pacing breaks silently: `Balance.BASE_SPEED_*` (at the wrong value a wave-1 enemy
took 186 seconds to walk the road) and the count ramp `BASE_COUNT_*`.

## Architecture, and where to add things

Everything is **data-driven**. There is exactly one generic `Tower`, `Enemy` and
`Projectile` scene+script; types are differentiated by fields set at runtime, never by
subclasses or per-type scenes. Seven autoloads. **The registration order in
`project.godot` is load-bearing** — each depends only on the ones above it:

| # | Autoload | Owns |
|---|---|---|
| 1 | `Balance` [balance.gd](godottowerdefense/scripts/balance.gd) | every tunable curve, cost and economy number. Depends on nothing |
| 2 | `Save` [save_service.gd](godottowerdefense/scripts/save_service.gd) | the only code that touches `user://`. Versioned, atomic, never fatal |
| 3 | `Game` [game.gd](godottowerdefense/scripts/game.gd) | shared run state (gold, lives, signals) and **all** data tables |
| 4 | `Meta` [meta.gd](godottowerdefense/scripts/meta.gd) | what outlives a run: Essence, Workshop levels, best wave, offline stamp |
| 5 | `Run` [run.gd](godottowerdefense/scripts/run.gd) | one run: cards taken, towers unlocked, folded modifiers. Reads `Meta` on reset |
| 6 | `Audio` [audio.gd](godottowerdefense/scripts/audio.gd) | code-synthesized SFX and music. Reads `Save` for the mute setting |
| 7 | `EnemyIndex` [enemy_index.gd](godottowerdefense/scripts/enemy_index.gd) | per-frame spatial hash used for targeting |

Two boundaries worth keeping straight:

- **`Game` owns *what a thing is*; `Balance` owns *how its numbers grow*.** New tower or
  wave archetype → `Game`. Growth curve, cost, multiplier, bonus → `Balance`.
- **`Run` holds what dies when you lose; `Meta` holds what does not.** Both feed the *same*
  `TowerMods.fold`, so permanent and temporary power stack through one code path.
  `Run.permanent` is seeded from `Meta.run_start_modifiers()` in `Run.reset()`.

**Towers pull, nothing is pushed.** A tower re-derives its stats when
`Run.modifiers_changed` fires, and one built *after* a card was picked reads the same
source on its first `_recompute()` — so there is no back-fill step to forget.

[scripts/main.gd](godottowerdefense/scripts/main.gd) is the level wiring hub — placement,
upgrade, sell, the roguelite choice, and all signal connections.

To add content, add a **data row**, not a scene or script:

| Adding a… | Goes in |
|---|---|
| Tower | `Game.TOWER_DEFS` + its id in `Game.TOWER_ORDER` **to make it buildable** |
| Roguelite upgrade | `Game.UPGRADE_POOL` (stats it may touch: `TowerMods.fold`) |
| Permanent upgrade | `Game.WORKSHOP_DEFS` — effects must be **per-level steps**, not totals |
| Saved field | a key in the relevant `Save` section; bump `SAVE_VERSION` + add a `_migrate` branch if the shape changes |
| Wave (first 20 only) | `Game.WAVES` — past that, waves are generated |
| Creep archetype | `Game.WAVE_TYPES` |
| Tower behavior (beam/charge/…) | a `TowerBehavior` subclass + a case in `Tower._make_behavior` — but only if the CONTROL FLOW differs. An aura is data read by the neighbours; an on-kill payout is data read by the projectile. Of fifteen duals exactly one (Magic) needed a subclass |
| Dual tower | a row in `Game.DUAL_RECIPES` + a `TOWER_DEFS` entry; it becomes buildable when `Run.element_level` reaches `DUAL_ELEMENT_LEVEL` in both its elements |
| Sound effect | a block in `audio.gd`'s `_build_all()` |
| Painted tower set | `assets/art/towers/<element>_1..5.png`, cut from one generated sheet by `python tools/cut_sprites.py <sheet.png> <out_dir> <element> <max_height>`. **No code change** — `sprites.gd` picks the files up by name and `tower.gd` prefers them over the code art. Keep the sheet as `_source_<element>.png` beside them |

## Conventions

- Typed GDScript, **tab** indentation, `##` doc comments on scripts and non-obvious
  functions.
- **Sound is still zero-asset**, and stays that way: every SFX and the music loop are
  synthesized in `audio.gd`. Don't add `.wav` / `.ogg`.
- **Art is no longer zero-asset**, but it is still *mostly* code. The board and the fire,
  water and nature towers are painted PNGs under `godottowerdefense/assets/art/`; everything
  else — the other three elements, every dual, every enemy, all effects and all UI — is
  `_draw()`. The two
  coexist on purpose: `sprites.gd` returns `null` for anything unpainted and the caller
  falls back to the code art, which is what lets the repaint proceed one element at a time
  instead of in one unplayable jump. Adding a painted set is dropping files in; it needs no
  code change. Adding an asset for anything else is still worth asking about first.

## Known traps

Each of these cost real time; don't rediscover them.

- **Android export requires ETC2/ASTC.** `project.godot` needs
  `textures/vram_compression/import_etc2_astc=true` under `[rendering]`. It was needed even
  back when the game had no textures at all — without it the export aborts with a
  configuration error (this failed two CI builds) — and it now actually applies to the
  board and tower art.
- **Generating mipmaps changes nothing on its own.** The 2D default texture filter is plain
  linear and ignores a mip chain entirely, so a node that draws a texture must also set
  `texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (see `tower.gd` and
  `map.gd` `_ready()`). Downscaling in the pipeline is the other half: `cut_sprites.py`
  averages the source down to ~2x its drawn size, because sampling one pixel out of a 7x7
  block is what makes generated art sparkle — which reads as "low resolution" and is the
  opposite.
- **A newly added PNG imports with `mipmaps/generate=false`.** So a fresh tower set arrives
  looking worse than the one beside it, for a reason nothing in the code shows. After
  dropping files in and running `--import`, check
  `grep mipmaps/generate assets/art/towers/*.import` against the sets already there, flip
  the new ones to `true` and re-import. `.import` files are committed, which is why the
  existing sets stay correct.
- **GDScript `abs()` returns Variant**, so `var s := 4.0 * abs(x) - 1.0` fails with
  "cannot infer type". Use `absf()`, or type it explicitly (`var s: float = …`). Apply the
  same care to `:=` on ternary expressions.
- **`const X := PackedStringArray([...])` doesn't compile** — that is a constructor call,
  not a constant expression. Use a plain `const X: Array = [...]` and cast on read
  (`String(X[i])`). Same for `PackedFloat32Array` and friends.
- **A freed object fails a *typed* parameter check before the function body runs.** So
  `func f(e: Enemy)` that starts with `if not is_instance_valid(e)` still throws when
  handed a freed node — the guard never executes. Test `is_instance_valid()` at the
  *call site* whenever you hold a node reference across frames.
- **A new script with `class_name` is invisible to headless runs until the project is
  reimported.** Godot resolves global classes through `.godot/global_script_class_cache.cfg`,
  which only the editor's scan rebuilds. If `run_project` reports
  `Identifier "Foo" not declared`, run
  `"C:\Program Files\Godot\Godot.exe.exe" --headless --path <repo>/godottowerdefense --import`
  once, then re-run. (CI is unaffected — it imports from scratch.)
- **The element matchup must apply to damage-over-time too.** Poison damage is baked at
  hit time in `projectile.gd` `_apply()` and must be multiplied by
  `Game.element_mult(element, enemy.armor_element)`, exactly like direct and splash
  damage. Hook impact sounds/effects there too — *not* in `enemy.take_damage()`, which
  also fires on every poison tick.
- **The end screen pauses the tree** (`end_screen.gd` sets `get_tree().paused = true`), so
  anything that must keep working there — the `Audio` autoload and its players — needs
  `process_mode = PROCESS_MODE_ALWAYS`.
- **Web audio stays suspended until the first user gesture** (browser autoplay policy), so
  sounds right after load may be silent until the player clicks. Don't rely on a startup
  jingle.

## The Element TD source maps

The tower roster, the five-tier ladder, the element recipes and the wave curve are all
**ported from the original Warcraft III maps**, not invented and not taken from a wiki.
The maps live outside the repo (the user's `Desktop/Warcraft III/Maps/Downloads/`), and
`tools/extract_w3x.py` reads them with no third-party dependency:

```
python tools/extract_w3x.py "<map>.w3x" towers    # roster grouped by cost tier
python tools/extract_w3x.py "<map>.w3x" recipes   # the "( X + Y )" combination table
python tools/extract_w3x.py "<map>.w3x" waves     # the 60-level HP curve + creep classes
python tools/extract_w3x.py "<map>.w3x" pathing  # the arena: spiral shape, size, coverage
```

`tools/` holds three more scripts, all built on the same rule — **no third-party
dependency**, which is why `tools/png_reader.py` is a 100-line stdlib PNG decoder/encoder
rather than Pillow:

```
python tools/trace_road.py                        # re-derive Game.PATH + OBSTACLES from the board art
python tools/cut_sprites.py <sheet> <dir> <name> <max_h>   # split a generated tier sheet into sprites
```

The extracted result is written up in
[docs/element-td-data.md](godottowerdefense/docs/element-td-data.md). **Change a ported
number only against that file or a fresh tool run** — three separate mistakes came from
reasoning about these numbers instead of reading them:

- **WC3 damage is `base + dice`, not `base`.** Every Element TD tower rolls `1d1`, so the
  real damage is the object editor's `ua1b` **plus one**. Reading `ua1b` alone makes the
  exact ×5 tier ladder look ragged and off-by-four.
- **An absent object-data field means "inherit", not "zero".** Tiers 3-5 omit `ua1d`
  entirely; treating that as no dice loses the +1.
- **`udg_HP_exponent_base = 1.23` in `war3map.j` is a decoy** — declared, never read. The
  real wave curve is `75 × 1.16^(n-1)`, baked into a separate unit type per level.

Two deliberate departures from the map are marked in the code and must stay marked:
`Balance.START_GOLD` (the map's 30 assumes towers are researched, not bought) and the
slow/poison/splash payloads still riding on Water/Nature/Earth (the map puts those on
dual towers, which we have not built).

## Further reading

- [godottowerdefense/README.md](godottowerdefense/README.md) — full architecture,
  controls, scene trees, and the tuning table. **Keep it updated when gameplay changes**;
  it has gone stale before.
- [godottowerdefense/docs/element-td-towers.md](godottowerdefense/docs/element-td-towers.md)
  — the design target (6 elements, 15 duals, 20 triples) versus what's actually built
  (6 elements; the duals exist as data but the combination mechanic does not).
- [godottowerdefense/docs/element-td-data.md](godottowerdefense/docs/element-td-data.md)
  — every number extracted from the source maps, and how to re-derive it.
