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

## How it ships

Both workflows run automatically on push to `main`:

| Workflow | Output |
|---|---|
| `.github/workflows/deploy.yml` | Web export → GitHub Pages |
| `.github/workflows/android.yml` | Debug APK → download from the run's **Artifacts** |

- Both build inside the `barichello/godot-ci:4.7` container. Nothing Android-related is
  installed on the user's machine; never try to build an APK locally.
- `android.yml` also supports manual `workflow_dispatch`.
- The Android job **generates its own debug keystore** and passes it via the
  `GODOT_ANDROID_KEYSTORE_DEBUG_*` env vars — don't rely on the image's baked-in one.
- The Web export is single-threaded on purpose, so no COOP/COEP headers are needed.
- `godottowerdefense/web/orientation.js` is injected into the web page via the preset's
  `html/head_include` and copied next to `index.html` by `deploy.yml` — it gates portrait
  phones behind a "rotate your device" panel. It is **not** a Godot resource, so if you
  add more web-only files you must copy them in the workflow too. Note a page can't force
  rotation on its own: Chrome only honours an orientation lock in fullscreen, and iOS
  Safari not at all.

## Architecture, and where to add things

Everything is **data-driven**. There is exactly one generic `Tower`, `Enemy` and
`Projectile` scene+script; types are differentiated by fields set at runtime, never by
subclasses or per-type scenes. Two autoloads:

- `Game` — [scripts/game.gd](godottowerdefense/scripts/game.gd): shared state (gold,
  lives, signals) and **all** data tables.
- `Audio` — [scripts/audio.gd](godottowerdefense/scripts/audio.gd): code-synthesized SFX
  and background music.

[scripts/main.gd](godottowerdefense/scripts/main.gd) is the level wiring hub — placement,
upgrade, sell, and all signal connections.

To add content, add a **data row**, not a scene or script:

| Adding a… | Goes in |
|---|---|
| Tower | `Game.TOWER_DEFS` + its id in `Game.TOWER_ORDER` |
| Wave | `Game.WAVES` |
| Creep archetype | `Game.WAVE_TYPES` |
| Sound effect | a block in `audio.gd`'s `_build_all()` |

## Conventions

- Typed GDScript, **tab** indentation, `##` doc comments on scripts and non-obvious
  functions.
- **Zero asset files by design.** Every visual is `_draw()` code; every sound is
  synthesized in `audio.gd`. Don't add `.png` / `.wav` / `.ogg` without asking first — it
  breaks the project's whole premise.

## Known traps

Each of these cost real time; don't rediscover them.

- **Android export requires ETC2/ASTC.** `project.godot` needs
  `textures/vram_compression/import_etc2_astc=true` under `[rendering]` even though the
  game has no textures. Without it the export aborts with a configuration error (this
  failed two CI builds).
- **GDScript `abs()` returns Variant**, so `var s := 4.0 * abs(x) - 1.0` fails with
  "cannot infer type". Use `absf()`, or type it explicitly (`var s: float = …`). Apply the
  same care to `:=` on ternary expressions.
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

## Further reading

- [godottowerdefense/README.md](godottowerdefense/README.md) — full architecture,
  controls, scene trees, and the tuning table. **Keep it updated when gameplay changes**;
  it has gone stale before.
- [godottowerdefense/docs/element-td-towers.md](godottowerdefense/docs/element-td-towers.md)
  — the design target (6 elements, 15 duals, 20 triples) versus what's actually built
  (4 elements, 3 duals + Lightning).
