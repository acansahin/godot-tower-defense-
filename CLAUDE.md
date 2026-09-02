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
plus a generator-purity check), `--dump-fusions` (all eleven `Game.FUSIONS` rows at every
level, each as a DPS multiple of the base elements printed above it, plus every fusion key
round-tripped through `fusion_key()` — a typo'd key silently falls back to the base
definition, so the tower keeps working, keeps its old stats and pockets the gold),
`--dump-bosses` (20 run seeds' avatar-boss orders: proves each element appears exactly once
and that the SEED, not the global RNG, picks the order), `--dump-matchup`
(`element_mult_best` for every element set against every armour — the table to read before
arguing about Pure's balance, since it is the proof a four-element set is never resisted),
`--dump-meta` (essence curve, workshop costs, purchases reaching towers,
settings round-trip), `--dump-board` (road length,
cell count, and per element how much of the road one tower watches and how many towers it
takes to watch 95% of it — plus a `raw` column measuring the same with the range cap
lifted), `--fill-board` (a tower on every cell at max level, 8x speed, spread across the
whole fusion ladder — a quarter stay base, a quarter become duals, then triples, then Pure —
prints an ART TALLY of every set standing on the board with `art*`/`art-` for whether it
is painted — which is how a newly cut tower set is checked, since a new set is two or three
towers out of 47 — then each wave with `earned=`, the gold gained since the previous wave began, and the
run-over line with real WALL-CLOCK elapsed time plus which fusions unlocked. `earned` is a
DELTA on purpose: this harness grants itself a million gold so placement never fails, so the
absolute balance measures nothing while the delta is real income. Because a maxed board
leaks nothing it is an UPPER bound. **The COST arithmetic below is still sized on paper
rather than by playing** (`--play-sim` measures whether a gradual build-up survives, not
whether the ledger adds up): kills pay `3 + wave` on a count curve
capped at 28, which with the interest cap and the leak-free bonus totals ~41,300 gold over a
50-wave run, and `Balance.TIER_COSTS` + `Balance.FUSION_COSTS` are set so a full board
absorbs ~85% of that. Re-do that arithmetic whenever the pad count moves — at 12 pads the
board could originally take only 23,520 even taken to the last upgrade of the last Pure
tower, so a player finished it and sat on ~18,000 spare gold. Elapsed is meaningless at 8x, but
`--fill-board:1x` skips the speed-up for exactly this: BUILD NEXT #10 used it to measure a
real Standard run at ~4.7 minutes, though that is a maxed-board LOWER BOUND, not proof of the
~10.5 min target for an actual player's gradual build-up — `--play-sim` is the one that
plays that out),
`--play-sim` (the counterpart to `--fill-board`, and the harness that closed the hole the
line above describes: it starts on `START_GOLD`, buys through the SAME functions a tap goes
through — the placement rule, `_upgrade_tower()`, `_fuse_tower()` — so the simulated player
can do nothing the real one cannot and can skip no rule they are subject to. It leaks lives
and it loses, and the wave it dies on is the number to read. **It is a FLOOR, not an
average**, and reading a result means remembering which player it is: cheapest useful
purchase first, board before depth, the first free pad rather than the best one, no element
chosen against the wave's armour, and it never sells. A human plays better than this, so a
run it clears is not proof the run is easy — but a run it dies early in IS proof of a
problem. It is what `FINAL_HP_FACTOR` 40 -> 55 and the Pure damage cut were read off),
`--show-fusion-panel`
(stands one Lv3 tower on an empty board with two elements unlocked and opens its panel, so
the panel's `_draw` can be photographed without playing to an avatar boss
first), `--air-pose` (parks eight Air creeps along
the road on an EMPTY board so the flyer's drawing can be photographed — `--fill-board`
buries the road and kills them at the spawn point, and a normal run never reaches the Air
wave without leaking away all twenty lives first), `--boss-pose` (stages both bosses' rules —
control-immune and rotating-armor, BUILD NEXT #7 — on an empty board so the ward/ring/icon
can be photographed without playing to wave 10 or 20 first), `--avatar-pose` (walks all FOUR
element avatars down an empty road at once, and prints the art set each one resolved to. The
avatars are the one creature a run cannot show on demand — they arrive on waves 10/20/30/40 in
an order the RUN SEED picks, so photographing all four by playing means four long runs and a
different order each time. `art=normal` on a row whose sheet exists means the sheet is not being
picked up, which on the board is indistinguishable from an element nobody painted),
`--bolt-pose` (flies one of
EVERY bolt drawing — the four elements and all eleven fusions — across an empty board at a
crawl, so the fifteen can be compared side by side. Neither other route works: a normal run
only ever has the four base shots in the air, since a fusion needs an avatar boss to unlock
its second element, and `--fill-board` buries the road so its bolts live for a handful of
frames in one corner. Rows are printed top-to-bottom in the order they are laid out, and the
list is built FROM `Game.FUSIONS`, so a row whose shape has no case in `projectile.gd` shows
up as a plain bolt in the photograph instead of passing unnoticed), `--hit-pose` (the same
idea for the other end of the shot: stands one REAL tower of each impact-relevant identity —
splash, burn, chaos and neither — in front of a creep it cannot kill, on a grid, so every kind
of impact lands over and over in a known spot. Real towers on purpose: the impact branch reads
five payload fields, and a harness that spawned its own bolts would set them the way
`Tower.fire_bolt()` does and would then be free to DISAGREE with it. `--fill-board` cannot do
this either — a maxed board kills every creep within a frame or two of its spawn, so all
seventeen kinds of impact happen on top of one another in one corner. Take two or three shots:
a slow tower fires every 1.4s and a ring lives 0.35s, so any single frame misses it three times
out of four), `--shot` (saves one drawn frame to
`user://shot.png` and prints the path — the only harness that shows you the board rather
than describing it, so **drop `--headless` for this one**; `--shot:20` waits 20s first and
lands in `shot_20.png`, and several may be passed at once to watch a run across waves),
`--auto-pick` (buys every fusion as soon as it is unlocked and affordable, so an unattended
run climbs to Pure instead of finishing on four base towers. It is no longer needed just to
keep a delayed `--shot:N` alive: nothing pauses the tree any more, since the three popups
that did are gone), `--go-back` (rewinds the
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

**Placement is FREE: `Game.can_build_at()` is the whole rule and it answers about any
point.** Off the road by `ROAD_KEEPOUT`, out of `OBSTACLES`, inside `PLAY_TOP`/`PLAY_RIGHT`,
on open ground (below), and `TOWER_GAP` from its neighbours. `main.gd` `_placement_point()`
returns the cursor, and both the ghost and the drop validate through `can_build_at()`, so
the preview cannot disagree with the result. `grid.gd` shades the ground the rule REFUSES,
and only while a tower is being dragged, so the answer is visible before the question.

**A hex lattice of marked pads used to stand between the two, and it has been removed.** It
existed because free placement produced boards that looked accidental, and it was paid for
in a way that only became clear later: at `PAD_PITCH` 112 the winding board offered **12**
spots where free placement offers **87**. That is the number every balance constant since
was set against — see the warnings on `Balance.WC3_RANGE_SCALE` and
`Balance.GLOBAL_DAMAGE_MULT`, both of which were raised to compensate for a scarcity that no
longer exists. **Re-run `--dump-board`, `--fill-board` and `--play-sim` before trusting any
of those numbers.**

What went with it: `PAD_PITCH`, `PAD_SNAP`, `PAD_ORIGIN_STEPS`, `Game.pads()`,
`has_pads()`, `nearest_pad()`, the origin search, and `grid.gd`'s pad drawing. What stayed
is everything that was actually load-bearing — the build mask, `ROAD_KEEPOUT`,
`TOWER_GAP`, `FOOTPRINT_PROBE` and the `PLAY_TOP`/`PLAY_RIGHT` bounds.

`--dump-board` and `--fill-board` sweep `main.gd` `_buildable_lattice()`, which now SAMPLES
the continuous legal set at half the tower spacing rather than enumerating slots. Read its
count as a capacity estimate: a player placing by hand fits a slightly different number.

A board that supplies an explicit `active_build_zones` allowlist gets NO pads — its own rings
would already be its guides. No shipped board sets this today (the interactive tutorial that
used to, drawing rings around six pockets, has been removed), but the mechanism stays in
`Game` for a future board that wants to name its own legal spots. `--dump-board` and
`--fill-board` sweep the pads when a board has them (`main.gd` `_buildable_lattice()`), so
the harnesses measure the spots the player is actually offered.

## The towers and the board are not the same picture, and that is measured too

`python tools/art_match.py` answers "do these belong together?" the way `--dump-board`
answers "can you build here?" — with numbers instead of a screenshot. It reports four things
and the played board currently fails all four.

The first is about PLACEMENT rather than looks, and it is the one no other tool reports:
**how much of the band 70-300px from the road is open ground** — the only ground a tower can
both stand on and shoot from. `--dump-board` counts pads, an answer that also depends on
`PAD_PITCH` and the origin search; `build_mask.py` reports open ground over the whole image,
which a board can win with one empty corner the road never goes near. The winding board
measures **22.6%** against a target of 80%, and that is what 12 pads looks like as a
fraction. The other three:

| | winding (played) | board_source (what the roster was painted against) | the roster |
|---|---|---|---|
| Open-ground luminance | 73.3 | 106.4 | masonry 50-125 |
| Open-ground blue | 25.1 | 35.6 | masonry median 46.5 |
| Ground squash | **1.000** | — | **0.24-0.30** |

Three separate faults, and only the third is unfixable in code:

- **The value gap is an accident of history.** The six element sets were generated with
  `board_source.png` attached — the spiral — and a Standard run has played on the winding
  board since. The roster is lit for a board 45% brighter than the one it stands on.
  `docs/tower-art-prompt.md` caught this for the FUSION sheets and told them to attach the
  winding board instead; they still measure bright (clay 92, pure 93, rainbow 125), so
  attaching the right board was not on its own enough.
- **The hue gap is why grey stone floats.** Nothing painted on the winding board carries
  blue above ~32. Neutral masonry carries 44-114. A multiply can darken stone; it cannot put
  back a hue the board does not contain.
- **The camera gap is the big one.** `art_match.py` reads it off the road: a ribbon of
  constant width is drawn narrower where it runs east-west than where it runs north-south,
  and the ratio is `sin(elevation)`. The winding board measures **1.000** — painted straight
  down — against tower sheets painted at 0.24-0.30 (`tower.gd`'s hand-measured `WATER_POOL`
  and `NATURE_RUNE` tables are ground circles, so they report the sheets' camera directly).
  **No colour work closes 60 degrees.** The fix is a board repaint, and
  `docs/board-art-prompt.md` now asks for 0.50 — halfway, because matching the sheets
  exactly would lay the playfield nearly edge-on.

**`Game.GROUND_SQUASH` is the engine's half of that number.** Every shadow, pad, aura ring
and ground glow is drawn `Vector2(1.0, Game.GROUND_SQUASH)`; before it there were four
values across seven sites and `grid.gd`'s comment claiming its 0.45 matched the towers'
contact shadows had gone stale against their 0.40. What is NOT on the ground stays out of
it — Fire's brazier glow and the pool/rune/fusion rings sit on top of a tower and follow the
art's plane, not the board's. When a new board lands, move this constant to whatever
`art_match.py` measures on it.

`Game.ART_TINT` is the matching knob for value: one `Color` multiplied over every painted
tower and creep, at the single `draw_texture_rect` each passes through. It is `WHITE`, which
is the honest state — it exists so a roster that lands slightly hot can be trimmed in one
place, not as a substitute for the repaint.

**You cannot build on trees, cliffs or water, and that rule is read off the painting.**
`python tools/build_mask.py <board.png>` writes `<board>_build.png`, a 1-texel-per-8px mask
saying where there is open ground; `Game` loads it for the active board (`BUILD_MASKS`) and
`can_build_at()` samples nine points around the tower's base against it. Re-run the tool
after a repaint and the rule follows the art — there is nothing to re-measure by hand.

Two things about it are load-bearing:

- **The classifier is `g - b`, not "is it green".** Conifers are extremely green; what makes
  a meadow a meadow is that it has almost no blue in it. Grass measures (110-128, 110-129,
  22-28) and a tree (16, 30, 14), so green-over-blue separates them cleanly where a plain
  green test cannot. `build_mask.py`'s docstring has the rest.
- **An explicit `active_build_zones` allowlist WINS OUTRIGHT over the mask**, it does not
  intersect with it. This was found through the now-removed interactive tutorial, which drew
  rings around six pockets and meant exactly those; intersecting the two silently moved the
  tutorial's own spots and broke a lesson.

The cost is measured, not guessed. On the winding board the mask takes buildable spots from
**174 to 51**, and road coverage from 94%/87% (Water/Fire) to **85%/78%** — a seventh of the
road has no tower that can reach it, which is the point of terrain and not a bug. Re-run
`--dump-board` after any change to the mask, the thresholds, or the art.

**Two constants next to the mask are worth as much as the mask itself, and both are
measured.** At `FOOTPRINT_PROBE` 0.35 and the full-radius `ROAD_KEEPOUT` the same painting
allowed only **29** spots; 0.20 and `ROAD_BASE_FRACTION` 0.5 give 51 for the same art,
because what has to clear a tree or a kerb is the painted BASE and not the 30px tap disc.
The cost of that is visible rather than statistical: it admits a couple of towers onto lit
rock by the waterfall, where an isolated open block survives the despeckle. Extra
`build_mask.py` majority passes do **not** remove them — measured at 2, 3 and 4 passes, the
same block survives all three.

**More open ground does not mean more gold, but it does mean more to spend it on.** On a
maxed board income is bounded by how many creeps the waves contain, not by how many towers
are shooting them, so the placement numbers above barely move it. What they DO move is the
other side of the ledger: capacity is `pads x (build + upgrades + fusions)`, so cutting the
board from 47 pads to 12 cut what a run can absorb from 92,120 gold to 23,520 against an
income ceiling of ~41,300. `Balance.TIER_COSTS` and `Balance.FUSION_COSTS` were raised by
half to close that. **Any change to the pad count has to redo this arithmetic.**

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
upgrade, fusion, sell, and all signal connections. Every one of those actions is reported by
[scripts/tower_panel.gd](godottowerdefense/scripts/tower_panel.gd) and *performed* by Main,
so exactly one file mutates a tower.

To add content, add a **data row**, not a scene or script:

| Adding a… | Goes in |
|---|---|
| Tower | `Game.TOWER_DEFS` + its id in `Game.TOWER_ORDER` **to make it buildable** |
| Fusion (dual / triple / Pure) | a row in `Game.FUSIONS`, keyed by its element names **sorted and joined with `+`** (`fusion_key()` builds the same key from a tower's element set, which is what makes Fire+Water and Water+Fire one tower). It replaces the base definition rather than layering over it, so the row must be complete: `damage_tiers`, `range`, `interval`, `color`, `names`, `desc`. **No code change for the PAYLOAD** — those fields are the ones `projectile.gd` already reads. The SHOT is the exception: `Projectile._draw()` dispatches on `shape` (the firing tower's `art_key()`, so `flesh_golem`, never `earth+nature+water`) and a row with no case there falls through to `_draw_plain_bolt` — which is silent, since a plain bolt in the row's colour looks deliberate. Add the case and check it with `--bolt-pose` |
| Permanent upgrade | `Game.WORKSHOP_DEFS` — effects must be **per-level steps**, not totals. This is the only thing left that writes `TowerMods` |
| Saved field | a key in the relevant `Save` section; bump `SAVE_VERSION` + add a `_migrate` branch if the shape changes |
| Wave (first 20 only) | `Game.WAVES` — past that, waves are generated. **No boss goes in this table**, see below |
| Any boss wave | `Game.apply_milestone()`, which has the last word over both the seed table and the generator. Avatar waves come from `Balance.ELEMENT_BOSS_WAVES` (itself derived from `Balance.STANDARD_WAVES`, so they stay a fifth of the run apart at any length); the two set pieces are `Game.MIDPOINT_BOSS` / `Game.FINAL_BOSS`. Boss waves used to be `Game.WAVES` rows kept in step with `ELEMENT_BOSS_WAVES` by hand — one list decides now, so they cannot disagree |
| A longer or shorter run | `Balance.STANDARD_WAVES` **and nothing else**. Boss waves, the HP ramp and the speed ramp all derive from it, so the run ends at the same difficulty whatever the length. **Both ramps are endpoints, not per-wave rates, and that is measured**: with the ported flat `1.16` HP rate and the uncapped `80 + 9n` speed, `--fill-board` died on wave 35 of 50; softening HP alone to `1.09` (a 21x lighter finish) only reached 48, while `1.13` and `1.11` both died on exactly **43** — a limiter neither of them touched, which was speed. Re-run `--fill-board` after changing it; a maxed board clearing the last wave is the MINIMUM bar, since a real player's board is weaker |
| Creep archetype | `Game.WAVE_TYPES` |
| Tower behavior (beam/charge/…) | a `TowerBehavior` subclass + a case in `Tower._make_behavior` — but only if the CONTROL FLOW differs. An aura is data read by the neighbours; an on-kill payout is data read by the projectile. Of the eleven fusions, none needed a subclass |
| Sound effect | a block in `audio.gd`'s `_build_all()` |
| Painted creep | `assets/art/enemies/<archetype>.png`, named for its `Game.WAVE_TYPES` key (`normal.png`, `tank.png`, …). **No code change** — `sprites.gd` `enemy()` finds it and `enemy.gd` prefers it over the blob. Art faces SCREEN-LEFT and is mirrored by `_facing`. A boss is an archetype wearing a crown, with ONE exception: the four element avatars take `boss_<element>_1..N.png` if those exist (`Enemy.art_kind()` picks them off `avatar_element` and falls back to the crowned archetype otherwise), so the four can be painted one at a time — check them with `--avatar-pose`. Numbered files (`normal_1.png`…`normal_6.png`) are an animation cycle of ANY length — `Sprites.pose_count()` counts them and both carriers divide their cycle by the answer, so re-animating a creep is a file copy; one file alone is a still. Only the `"air"` row in `WAVE_TYPES` flies, and its cycle is a WINGBEAT, not a stride. Generate sheets from [docs/creep-art-prompt.md](godottowerdefense/docs/creep-art-prompt.md) — one creature per sheet, one frame per row, TWELVE of them: the cycle is one stride played at the creep's own walking rate, so six frames measured 6.2 fps at wave 2 and the eye counts them. **The pace comes from the STRIDE the art was drawn with** (`Sprites.stride()`, the widest gap between the feet), not from the creep's radius: one cycle carries the creature the two steps it is painted taking, so a sheet drawn with a lunging stride walks slowly and one drawn at the roster's 0.6-0.9x of body height walks at a normal rate. `Enemy.WALK_TEMPO` (1.35) is the one deliberate lie — a third faster than the feet, which buys frame rate for a slip too small to read — and `Enemy.FRAME_BLEND` dissolves each pose into the next so a 5 fps cycle does not read as a slide show |
| Painted tower set | `assets/art/towers/<name>_1..5.png`, cut from one generated sheet by `python tools/cut_sprites.py <sheet.png> <out_dir> <name> 220`. `<name>` is the element for a base tower and the combination's FIRST name for a fusion (`steam`, `flesh_golem` — never the per-tier name; `Tower.art_key()` derives it). **No code change** — `sprites.gd` picks the files up by name and `tower.gd` prefers them over the code art, so an unpainted combination just keeps drawing itself. Keep the sheet as `_source_<name>.png` beside them, and generate it from the template in [docs/tower-art-prompt.md](godottowerdefense/docs/tower-art-prompt.md) — **attach the board the tower will stand on** (the winding map, not `board_source.png`) **and, for a fusion, both parent sheets**; every set generated from words alone had to be redone |

## Conventions

- Typed GDScript, **tab** indentation, `##` doc comments on scripts and non-obvious
  functions.
- **Sound EFFECTS are still zero-asset**, and stay that way: every SFX is synthesized in
  `audio.gd`. Don't add effect files. The **background music is the one exception** —
  `assets/audio/guardians_of_the_verdant_spire.mp3`, imported with `loop=true` so the
  stream repeats itself rather than the player restarting it. `audio.gd`'s
  `_load_music_track()` falls back to the synthesized `_build_music()` loop when the file
  isn't in the build, so don't delete that function when touching the music.
  What ships is a **1:57 loop cut out of a 5:38 source** (7.5 MB -> 2.7 MB, and all of it
  lands in the web build and the APK). `tools/trim_mp3.py` made the cut without decoding
  or re-encoding: it drops whole MPEG frames and fades by rewriting each frame's
  `global_gain`, which keeps `tools/` stdlib-only. **Pick the cut point off its `--report`
  loudness curve, not off a round number** — 117.5s is a dip ~12 dB under the surrounding
  bars sitting at the same level as the intro it loops back to, and 120s would have cut
  mid-phrase. The full-length source is not in the repo; it is the user's original file.
- **Art is no longer zero-asset**, but it is still *mostly* code. The board, all six element
  towers and ALL ELEVEN FUSIONS are painted PNGs under `godottowerdefense/assets/art/`, so a
  `--fill-board` run now reports `art*` on every row; the enemies are painted too. What is
  still `_draw()`: all effects except the Fire brazier, and all UI. The two
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

`tools/` holds the rest of the pipeline, all built on the same rule — **no third-party
dependency**, which is why `tools/png_reader.py` is a 100-line stdlib PNG decoder/encoder
rather than Pillow:

```
python tools/trace_road.py                        # re-derive Game.PATH + OBSTACLES from the board art
python tools/build_mask.py <board.png>            # where a tower may stand: open ground, not trees/cliffs/water
python tools/water_mask.py <board.png> <mask.png> # where the water is, for map.gd's ripple shader
python tools/art_match.py [board.png]             # do the towers and the board look like one picture? see below
python tools/art_match.py <new> --against <old>   # did an EDIT of a board move the road? (keeps WINDING_PATH or not)
python tools/grade_board.py <board.png>           # pull a board's GRASS onto the register the towers were painted for
python tools/art_match.py <new> --against <old>   # did an EDIT of a board move the road? (keeps WINDING_PATH or not)
python tools/cut_sprites.py <sheet> <dir> <name> <max_h>   # split a generated sheet into sprites
python tools/key_white.py <in> <out>              # restore alpha to a sheet flattened onto white
python tools/stitch_sheets.py <out> <a> <b>       # one cycle split across two files -> one sheet
python tools/compose_cycle.py <out> <sheet>:<row> ...   # pick the usable rows out of several sheets -> one cycle
python tools/strip_ground_veil.py <keyed> <out>   # peel the puddle/spray an elemental sheet paints under its feet
python tools/respace_frames.py <in> <out> --frames N   # separate frames that touch, by connectivity
python tools/trim_mp3.py <in.mp3> --report        # loudness over time, so a loop point is READ not guessed
python tools/trim_mp3.py <in> <out> --end 117.5 --fade-in 0.8 --fade-out 1.5   # cut + fade, no re-encode
```

The last three exist because a generated sheet does not always arrive in the shape the cutter
needs, and each failure is silent rather than loud:

- **`key_white`** — a sheet saved without an alpha channel (PNG colour type 2) has no empty
  scanlines at all, so the cutter returns the whole image as one frame. Check with the colour
  type, not by eye: flattened white looks identical to transparent in most viewers.
- **`stitch_sheets`** — twelve frames is a 1:6 canvas and generators refuse it, so a cycle
  arrives as two sheets of six. Cutting them separately gives each half its OWN shared window,
  and the creature changes size halfway through its cycle. Stitch first, then cut once.
- **`respace_frames`** — when two frames overlap vertically the cutter silently returns one
  fewer frame than was drawn. Raising `gap_tol` splits them and shears the thin extremities off
  every other frame (on the Air cycle it cropped frame 1 from 322px to 267px, cutting the tips
  off the raised wings). Re-spacing by connected component separates them with nothing cropped.

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

Six deliberate departures from the map are marked in the code and must stay marked:
`Balance.START_GOLD` (the map's 30 assumes towers are researched, not bought); the
slow/poison/splash payloads still riding on Water/Nature/Earth (the map puts those on the
combination towers); the **Pure** row in `Game.FUSIONS`, which is a four-element tower
the map has no equivalent for — it has six elements and its recipes stop at three (its
`chaos` damage rule is ported, its name is borrowed from the map's own fifth single-element
tier, but the tower itself is ours); and the **Clay** row's per-tier NAMES, which the map
calls Clay -> Golem -> Living Statue and this port calls Clay -> Clay Pit -> Great Mire.
That one is downstream of the art: a fusion's shape now comes from its name, the roster
already has a Flesh Golem sitting on a plinth, and the painted set is a worked clay pit —
so the map's names would have put the word "Golem" over a pit of mud. Everything else in
the row is still the map's. Finally the two numbers that pay for a twelve-tower board:
`Balance.WC3_RANGE_SCALE` (0.35 -> 0.45, so twelve towers still watch the road) and
`Balance.GLOBAL_DAMAGE_MULT` (4.2, so they still kill what they watch). The map's wave curve
was deliberately NOT the lever — that curve is ported, while the tower damage numbers are
already ours.

The **combination numbers are not ported, and the reason is worth knowing**: the map's
ladder is 50 → 175 → 788 → 3544 → 24444, some sixty times steeper than ours, and V2 already
replaced the four base elements' stats with its own design values. So `Game.FUSIONS` takes
the map's *identity and relative ordering* (Clay hits hardest of the duals, Roots barely
damages at all, Infernal tops the triples) and re-derives the numbers on our scale. Every
row records the map value it came from. What IS ported verbatim: the recipes, the tower
names, the per-tier name ladder, the `chaos` attack type, the explicit cooldowns, and each
ability — see docs/element-td-data.md §3.1.

## Further reading

- [godottowerdefense/README.md](godottowerdefense/README.md) — full architecture,
  controls, scene trees, and the tuning table. **Keep it updated when gameplay changes**;
  it has gone stale before.
- [godottowerdefense/docs/element-td-towers.md](godottowerdefense/docs/element-td-towers.md)
  — the map's full roster (6 elements, 15 duals, 20 triples). **Written before the cut to
  four elements**, so read it as a description of the SOURCE, not of what is built: the port
  now uses the four elements and the ten combinations that avoid Light and Darkness, plus
  Pure. docs/element-td-data.md §3.1 is the table of what is actually in the game.
- [godottowerdefense/docs/element-td-data.md](godottowerdefense/docs/element-td-data.md)
  — every number extracted from the source maps, and how to re-derive it. §3.1 is the ten
  combinations the port uses, with their real damage, cooldown, attack type and ability text.
- [godottowerdefense/docs/tower-art-prompt.md](godottowerdefense/docs/tower-art-prompt.md)
  — the prompt template the six painted tower sets were generated from, and what each of
  its constraints protects against downstream. The eleven fusions are all code art today;
  this is the template if any of them is ever painted.
- [godottowerdefense/docs/creep-art-prompt.md](godottowerdefense/docs/creep-art-prompt.md)
  — the same for a creep ANIMATION sheet: the six-frame run cycle, the wingbeat variant for
  Air, and why each constraint exists (the anchor, the per-creature height scaling, the row
  split).
- [godottowerdefense/docs/board-art-prompt.md](godottowerdefense/docs/board-art-prompt.md)
  — the same for a BOARD painting, and the one whose constraints are hardest to see: four
  separate tools read colours off the board, so a shadow across the meadow deletes the
  meadow and a mossy road cannot be traced. Also records why a replacement is wanted — the
  winding board leaves only 17% of the road's reachable band open — and that `trace_road.py`
  is spiral-only, so a winding road's control points are read off the painting by hand.
