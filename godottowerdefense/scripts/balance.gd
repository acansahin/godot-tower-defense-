extends Node
## "Balance" autoload: every tunable curve and economy number in one place.
##
## Game owns *what a tower or wave is* (the TOWER_DEFS / WAVE_TYPES / WAVES tables).
## This file owns *how the numbers grow* — upgrade curves, wave scaling, boss
## multipliers, the gold economy, and the archetype modifiers that used to sit as bare
## literals inside enemy.gd. Before this existed a balance pass meant editing three
## files and hunting for un-named constants; now it is one file, and gameplay scripts
## read from it rather than declaring their own.
##
## Registered FIRST in project.godot's autoload list: it has no dependencies of its own,
## so nothing can be caught reading it before it exists.
##
## Nothing here changes behaviour — every value is the one that used to live at the site
## named in its comment.

# --- Run start / rulesets (BUILD NEXT #8) ---------------------------------------

## Easy/Normal (GAME_STRATEGY_V2.md §12, §28 Phase 1 — Hard is later phase content, not
## implemented here). "normal" is the tuned baseline every OTHER constant in this file
## already assumes (CREEP_HP_PERCENT, BASE_COUNT_*, …), so its multipliers are 1.0 and it
## changes nothing about the curves below; "easy" scales down from that same baseline
## rather than replacing it, via ruleset_hp_mult/ruleset_count_mult below, applied in
## wave_hp/wave_count. start_gold/start_lives are absolute per §12.2's own table, not
## multipliers.
##
## The original map starts a player on 30 gold, but its towers are not bought from a
## palette — you research elements and are given elementals, so 30 gold against a
## 50-gold tower is a bootstrap the player reaches by another route. We have no such
## route, so 120 (Normal) is one of the two deliberate departures from the map (the other
## is noted on TOWER_DEFS): enough for over two tier-1 towers.
const RULESETS := {
	"normal": {"hp_mult": 1.0, "count_mult": 1.0, "start_gold": 120, "start_lives": 20},
	"easy": {"hp_mult": 0.70, "count_mult": 0.85, "start_gold": 150, "start_lives": 25},
}
const DEFAULT_RULESET := "normal"

func _ruleset(id: String) -> Dictionary:
	return RULESETS.get(id, RULESETS[DEFAULT_RULESET])

func ruleset_hp_mult(id: String) -> float:
	return float(_ruleset(id).get("hp_mult", 1.0))

func ruleset_count_mult(id: String) -> float:
	return float(_ruleset(id).get("count_mult", 1.0))

func ruleset_start_gold(id: String) -> int:
	return int(_ruleset(id).get("start_gold", 120))

func ruleset_start_lives(id: String) -> int:
	return int(_ruleset(id).get("start_lives", 20))

# --- Tower upgrade curve (ported from Element TD v2.0) -------------------------
#
# See docs/element-td-data.md. The map's ladder is five tiers deep and, critically,
# **an upgrade multiplies damage and nothing else** — Fire is 500 range / 0.33s at
# tier 1 and still 500 / 0.33 as Pure Fire. Range and fire interval are fixed per
# element for the whole run, which is what makes the elements read as distinct
# shapes rather than as the same tower at different sizes.

const MAX_LEVEL := 5
## Gold to BUILD a tower at tier 1, then to reach each tier above it. Replaced the WC3-ported
## 50/175/788/3544/24444 ladder in the V2 redesign (GAME_STRATEGY_V2.md §4.2, §29.1, BUILD
## NEXT #3): the map's ladder ended in a 24444-gold, five-and-a-half-digit purchase that no
## run economy sized for a phone session could ever reach cleanly. 50/40/70/120/200 keeps
## the total cost of a maxed tower (480) inside what one run's economy actually earns
## (§29.2 measures ~6090 gold across 20 waves against ~12 good build spots x 480 = 5760).
## Build cost, then the cost of each upgrade. The BUILD cost is deliberately left where it
## was while the four upgrades were raised by half, because the two ends of this ladder do
## different jobs: the first number is the opening (START_GOLD 120 still buys two towers on
## wave 1, which is the tempo the early waves are tuned for), and the rest is the sink.
##
## The sink had to grow because the board shrank. Measured over a 50-wave run: kills pay
## `3 + wave` each on a count curve that caps at 28, which with the interest cap and the
## leak-free bonus is about 41,300 gold if nothing is missed. Against that, a board of 12
## pads could absorb only 23,520 even taken to the absolute end -- every tower at Lv5 AND
## every one of them walked all the way up to Pure. The player finished the board and then
## held ~18,000 gold with nothing to buy. At the old 47 pads capacity was 92,120 and the
## question never came up.
##
## x1.5 on the upgrades and on FUSION_COSTS puts capacity at ~34,980, or about 85% of that
## income ceiling. Not 100%: the 41,300 assumes every enemy dies, so a real run earns less,
## and a board that can only just be finished by a flawless player is a board nobody
## finishes. **This number is sized against a budget, not against a played run** -- no
## harness plays with real gold (`--fill-board` grants itself a million), so the last word
## belongs to an actual playthrough.
const TIER_COSTS: Array = [50, 60, 105, 180, 300]
## Damage multiplier applied on each upgrade. Unused while every TOWER_DEFS entry supplies
## its own explicit `damage_tiers` (see game.gd) — kept as the documented fallback shape,
## not yet rewritten to the V2 tier ratio (10/18/32/56/100, i.e. x1.8/x1.78/x1.75/x1.79)
## since that number belongs with the branch redesign (BUILD NEXT #5-#6), not this pass.
const TIER_DAMAGE_MULT: Array = [5.0, 5.0, 5.0, 10.0]
## Fraction of total_spent returned when a tower that has already fired is sold. A tower
## sold before its first shot instead returns SELL_REFUND_UNFIRED (100%) — see
## Tower.sell_value(). Two-tier refund replaces V1's flat 50% (GAME_STRATEGY_V2.md §9,
## BUILD NEXT #3): a flat rate punished the exact mistake a new player must be free to
## make (bad placement), while a flat 100% would let an expert re-tile the whole board
## before every wave for free. The condition is "did this tower ever do anything", not
## "how long has it stood" — a tower dropped mid-wave in the wrong spot is still a free
## take-back as long as it never got a shot off.
const SELL_REFUND := 0.8
## Refund fraction for a tower sold before its first shot. See SELL_REFUND above.
const SELL_REFUND_UNFIRED := 1.0
## slow_splash radius gains this fraction of its base per level past 2 (Lv3 = x1.3).
const SLOW_SPLASH_GROWTH := 0.3
## Hard floor on a tower's seconds-per-shot. Water is the fastest element at 0.17s and
## nothing else comes near — this exists so that stacked attack-speed modifiers can
## never reach zero, which would make the cooldown branch in _process fire every frame.
const MIN_FIRE_INTERVAL := 0.05

## Warcraft III distance -> our pixels. The map's ranges are 500 (Fire), 750 (Water,
## Nature, Earth) and 2000 (Light, Darkness); one scale keeps those ratios exact.
##
## 0.35 puts Water/Nature/Earth at 262px, which is where our four towers already sat, so
## the familiar elements do not move. Fire lands at 175px — short, which is its identity.
## Light and Darkness would land at 700px; MAX_TOWER_RANGE below is what stops them.
## DEPARTURE, raised from 0.35 when the board went from 47 build spots to 12 (Game.PAD_PITCH,
## widened so towers could be drawn 60% larger). Twelve towers watch less road than
## forty-seven, and a creep on road no tower can reach is never shot whatever the damage is,
## so reach had to be restored before damage was worth touching.
##
## Measured against the 47-tower coverage (86/79/87/85% of the road reachable for
## water/fire/nature/earth): 0.45 gives 88/82/89/87 and leaves one tower watching 31% of the
## road. 0.55 gives 92/88/93/91 at 39%, and 0.65 - which a 9-tower version of this board
## needed - puts one water tower on 44% and covers 95% of the road with three towers, which
## ends placement as a decision. 0.45 is the smallest that restores coverage, and smallest is
## the right choice: every extra point of range is a point of placement.
##
## It also keeps MAX_TOWER_RANGE honest. At 0.45 the longest tower reaches 276px and the cap
## is 300, so the cap still binds nothing the port can build - which is why raising the CAP
## is not the lever it looks like. The four elements sit at 219-283; the cap only ever
## existed to stop the 2000-range definitions.
const WC3_RANGE_SCALE := 0.45

## Hard ceiling on a tower's reach, in pixels. THE ONE PLACE THE PORT IS NOT FAITHFUL
## about a number, and it is here rather than in TOWER_DEFS on purpose: the definitions
## keep the map's real 2000, and this says what our board can afford to honour.
##
## Light and Darkness reach 2000 WC3 units, four times Fire, and the six elements sit at
## nearly equal DPS — so the reach is close to free power. `--dump-board` measures a
## faithful 700px Light watching 98% of the road (the `raw` column) and covering the whole
## board with TWO towers, on every world size that fits on one screen — 1280x720, 1536x864,
## 1707x960 alike — and on every road shape tried on them. Growing the world until it was
## fair took four screens and broke the game to fix a statistic, so the reach is capped.
##
## What is NOT true — and was written here for two commits — is that this is the small
## board's fault. `extract_w3x.py … pathing` measures the original's own arena: a 2000-unit
## tower there watches 94% of its own lane. Element TD lives with that because Light
## arrives through an element draw, one of 36 towers, deep into a run. Ours is on the
## palette at wave 1, so we cap: a tower you can place anywhere is not a placement.
##
## 300 is measured, not felt. It was set on the first painted board, where it put the
## longest towers at 41% of the road and four of them to cover 95% of it. The map has been
## repainted since and the same cap now measures 51%, still four towers, against Fire's 18%
## and twelve — the new spiral is longer (4023px against 3079) but its arms sit closer
## together, which flatters a long reach. --dump-board is the check whenever the map changes.
##
## Two neighbouring values were measured and rejected. 380, the cap the generated board used,
## let one Light tower watch 70% of the road and two cover the whole thing — no placement
## decisions left. 260 drags Light down onto Water's 32%, and the longest range in the game
## stops being a different tower.
##
## The cap also catches the longest duals (Poison, Tech and Moon reach 481px uncapped), which
## have the same problem for the same reason.
const MAX_TOWER_RANGE := 300.0

## Every tower's damage, multiplied once. A DELIBERATE DEPARTURE from the port, and the
## counterweight to the board holding 12 towers instead of 47.
##
## The board was respaced so towers could be drawn at the size the painted art wants
## (Game.PAD_PITCH, Game.TOWER_SPRITE_HEIGHT), and that took the build spots from 47 to 12.
## A maxed board clearing the LAST wave is the game's minimum bar - `--fill-board` is the
## gate - and it is a real gate rather than a formality: 47 towers cleared wave 50, while 28
## died on 46 and 25 on 47 with no compensation at all, and at 12 towers 3.5 still died on
## 48. 4.2 clears it.
##
## It lives here rather than in the fifteen `damage_tiers` arrays for three reasons: those
## arrays are the roster's IDENTITY and their ratios are what make Clay the hardest dual and
## Roots the weakest, one number can be re-tuned against the gate in a single run, and
## `--dump-stats` shows the whole effect in one diff.
##
## The wave curve was the other candidate and was left alone on purpose: `75 x 1.16^(n-1)` is
## ported from the map, while the tower damage numbers are already ours.
const GLOBAL_DAMAGE_MULT := 5.0

## Gold cost of upgrading a tower from `level` to `level + 1`.
## `build_cost` is ignored: in the map every element shares one cost ladder regardless
## of which element it is. The parameter stays so callers need not change.
func upgrade_cost(_build_cost: int, level: int) -> int:
	if level < 1 or level >= TIER_COSTS.size():
		return 0
	return int(TIER_COSTS[level])

# --- Wave pacing + economy (was wave_manager.gd:12-22) -------------------------

## Delay between waves. 3.0 (was 4.0) per GAME_STRATEGY_V2.md §11.2's session-length budget
## — a 20-wave Standard run has to fit ~10.5 minutes, and 19 inter-wave gaps is where most
## of the trim comes from without touching in-wave pacing.
const PREP_TIME := 3.0
## Delay before wave 1 only. Training teaches the controls, but the run opens on a
## different board with the tower palette visible; ten seconds (was 12, §11.2) is still
## long enough to read the palette, choose a coverage spot and place the first defence.
const FIRST_PREP_TIME := 10.0
## Banked gold earns this each wave, HUD-visible as a projection (GAME_STRATEGY_V2.md §8.1,
## BUILD NEXT #3): 5% (was 2.5%) with a cap of +60 gold per wave (was 400) rather than a
## cap on the bank balance itself. At 5%/wave, 50 gold held for 10 waves earns 31 gold —
## less than a single build — so interest rewards banking toward a threshold purchase, not
## indefinite hoarding; see GAME_STRATEGY_V2.md §8.2 for the full walk-through.
const INTEREST_RATE := 0.05
const INTEREST_CAP := 60
const LEAK_FREE_BONUS := 6        ## Bonus if no enemy reached the end this wave.

## Flying used to also be rolled per enemy on ground waves (15% from wave 3). That is gone:
## the archetypes are painted now, and a painted goblin hung in the air is a goblin with a
## drawing mistake, not a flyer. Air is the Air wave, and nothing else — which is also the
## reading the map itself takes.

## Gold for calling a wave in early, by the wave number being skipped into.
func early_call_bonus(wave: int) -> int:
	return 3 + wave

# --- Run length: the one dial the rest of the pacing hangs off -----------------
#
# HOW LONG A RUN IS, and every curve that has to finish with it. Set this and the wave
# numbers, the HP ramp and the speed ramp all re-time themselves — none of them is written
# down independently any more, so a 50-wave run and a 100-wave run END at the same
# difficulty and differ only in how finely they climb to it.
#
# That inversion is the whole point, and it was measured rather than assumed. The run was 20
# waves long and every ramp was a per-wave RATE, so stretching the run multiplied the finish
# line instead of moving it: at 50 waves the ported 1.16 HP rate puts the last wave at 1440x
# wave 1 (against 18x at wave 20), and the uncapped speed rate puts it at 435 px/s, which
# crosses the 3199px road in 7 seconds. At 100 waves that is 804 px/s and 4 seconds.
#
# `--fill-board` proved the rates cannot simply be softened one at a time. Dropping the HP
# rate 1.16 -> 1.09 makes the final wave TWENTY-ONE TIMES lighter and moved a maxed board's
# death only from wave 35 to 48 — and 1.13 and 1.11 both died on exactly wave 43, the
# signature of a limiter that neither of them touched. That limiter is speed.

## How many waves a Standard run plays before it can be won. Lives here rather than in Game
## because everything below derives from it, and Balance is the autoload nothing else may
## depend on — see project.godot's ordering.
const STANDARD_WAVES := 50

## The four element-avatar waves: evenly spread at 20/40/60/80% of the run, so the fusion
## ladder keeps its shape at any length. 50 -> 10/20/30/40, 60 -> 12/24/36/48,
## 100 -> 20/40/60/80.
const ELEMENT_BOSS_WAVES: Array = [
	STANDARD_WAVES / 5, STANDARD_WAVES * 2 / 5,
	STANDARD_WAVES * 3 / 5, STANDARD_WAVES * 4 / 5,
]

## The mid-run set-piece boss (Muhafız). The other one is the final wave itself, so it needs
## no constant. Never collides with an avatar wave: N/2 is not a fifth of N.
const MIDPOINT_BOSS_WAVE := STANDARD_WAVES / 2

# --- Wave scaling formula (was wave_manager.gd:91-101) -------------------------

## Wave 1 hit points, read straight out of the map: its level 1 is 75 hp.
## HP of a wave-1 creep before CREEP_HP_PERCENT. Raised from 75 with FINAL_HP_FACTOR cut by
## the same ratio, which LIFTS THE START OF THE CURVE WITHOUT MOVING ITS END.
##
## That shape is the fix for a specific mistake. GLOBAL_DAMAGE_MULT pays for a board that
## holds 12 towers instead of 47, but the player does not lose those towers evenly: early on
## they could only afford two or three either way, and the shortfall is entirely a late-game
## one. A flat damage multiplier therefore over-pays at the start by nearly its whole factor.
## Measured at wave 1: 9 creeps of 90 HP against a Lv1 Water tower now doing 120 DPS, which
## kills one in 0.75s on a 0.9s spawn interval -- a single tower nearly held the wave alone,
## and START_GOLD buys two.
##
## So the early waves rise and the last wave does not move: wave 1 goes from 90 to 270 HP,
## wave 12 from 264 to 613, wave 20 from 576 to 1131, and wave 50 stays at 10,800. Holding
## the end is not cosmetic -- `--fill-board` only just clears it, and 4.2 damage lost there
## where 5.0 wins, so any lift at that end costs another damage re-tune.
const BASE_HP_FLAT := 225.0

## Where the LAST wave lands, as a multiple of wave 1's hit points. THIS is the tuned number
## now; the per-wave ratio is derived from it and STANDARD_WAVES by hp_growth() below.
##
## A DELIBERATE DEPARTURE FROM THE MAP, and the third one in the port (the others are
## START_GOLD and MAX_TOWER_RANGE). The map's curve is a flat 1.16 per level across 60
## levels — 75 -> 476522, a 6353x climb — and it can afford that because its tower ladder
## climbs with it: 50 -> 24444 damage, roughly 490x. Ours is far flatter (GAME_STRATEGY_V2's
## 10 -> 100 per tier plus the fusion rows), so the map's rate outruns our towers long before
## the run is over. `--fill-board` puts a MAXED board's ceiling around this factor; a real
## player's board is strictly weaker, which is the margin this number is spending.
##
## Note the map's own `udg_HP_exponent_base = 1.23` is a decoy — declared and never read.
## 1.16 is what its per-level unit types actually contain, and it is what this replaces.
##
## MEASURED, and the margin is the point. `--fill-board` swept this against a maxed board —
## every pad, every tower at level 5, unlimited gold — and found the ceiling between 150 and
## 200: 200 dies on wave 49 (to an elite tank, archetype x3.0 and elite x1.6 stacking to
## x4.8 on top of the curve), while 150, 110 and 80 all clear the run. A maxed board is the
## UPPER BOUND of what the game can field, so 150 is where a run stops being winnable by
## anyone at all — not where it should sit. 120 keeps roughly a fifth of that headroom for a
## board a player could actually afford to build.
##
## THE NUMBER MOST LIKELY TO NEED PLAY-TESTING in the whole file, and the reason is a gap in
## the harness suite rather than a doubt about the measurement: nothing simulates a player's
## gradual build-up, so the distance between "a maxed board wins" and "a good board wins" is
## the one quantity here that was reasoned about rather than measured.
## Cut from 120 to 40 in step with BASE_HP_FLAT going 75 -> 225, so the product is unchanged
## and wave STANDARD_WAVES still lands on exactly the HP it did. The per-wave ratio falls
## from 1.103 to 1.078: a flatter climb from a higher floor.
const FINAL_HP_FACTOR := 40.0

## The per-wave HP ratio, derived so wave STANDARD_WAVES lands on FINAL_HP_FACTOR. At 50
## waves this is 1.113, close to the map's own 1.16 — the run is longer, so each step is
## smaller and the destination is the same.
func hp_growth() -> float:
	return pow(FINAL_HP_FACTOR, 1.0 / float(maxi(STANDARD_WAVES - 1, 1)))
## Creeps spawn at a fraction of their baked hit points, chosen by the map's difficulty
## selector: 50% on the easiest setting, +12.5 points per step. We have no difficulty
## screen, so this is the dial that stands in for one.
const CREEP_HP_PERCENT := 1.20
## Enemy speed is tied to the LENGTH OF THE ROAD, not to anything in the source map, and
## nothing else in the game reads that length — so if the road changes, these move with it
## or the pacing breaks silently. `--dump-board --map:winding` prints the length: it is
## 3199px (NOT the 3992px this comment quoted for two commits — that number was `spiral`,
## measured by a bare `--dump-board` before boards rotated per-run; a run today still
## rotates winding -> spiral -> s every 10 waves, `Game.WAVES_PER_BOARD`). GAME_STRATEGY_V2.md's
## BUILD NEXT plan pins Standard mode to `winding` alone once that lands (not done yet, see
## build-next memory) — until then this constant is tuned against `winding`'s 3199px, which
## is what wave 1 actually plays on: 80 raw is a wave-1 crossing of about 49 seconds.
const BASE_SPEED_FLAT := 80.0

## Raw speed the FINAL wave reaches, before CREEP_SPEED_PERCENT. The slope is derived from
## it and STANDARD_WAVES (speed_slope() below) rather than being a per-wave rate, because a
## rate has no idea when the run ends and this is the ramp that decides whether the run is
## PLAYABLE at all.
##
## 260 raw is 213 px/s, which crosses winding's 3199px road in 15 seconds — the pacing the
## last wave of the old 20-wave run had, kept as the finish line at any run length. What it
## replaces is a bare `80 + 9n` with no ceiling, which was fine while the run stopped at 20
## and became the actual wall past it: `--fill-board` died on wave 43 at two different HP
## rates, where a `fast` creep (x1.7) crosses the whole board in 4.9 seconds and a Water
## tower at 0.25s gets a handful of shots at it. Speed, not hit points, was killing the run.
const FINAL_SPEED_RAW := 260.0

## Raw speed added per wave, derived so wave STANDARD_WAVES arrives at FINAL_SPEED_RAW.
func speed_slope() -> float:
	return (FINAL_SPEED_RAW - BASE_SPEED_FLAT) / float(maxi(STANDARD_WAVES - 1, 1))
## Global movement reduction: enemies stay readable on every road. The matching 20% HP
## increase above preserves combat pressure instead of making the longer exposure free.
const CREEP_SPEED_PERCENT := 0.82
## Enemies per wave. The map spawns a FLAT `16 + difficulty * 3` and never grows it — all
## of its difficulty is in the hit-point curve. Faithful, and unplayable as an opening: 28
## enemies at 0.9s apart means wave 1 spends 25 seconds just spawning before anything can
## even be killed, and the first five waves took five and a half minutes to deliver almost
## no progression.
##
## So the count ramps to the map's number instead of starting there. Wave 1 is 9 enemies
## and wave 17 onwards is the full 28, which keeps the map's late-game shape while giving
## the opening a pace a phone session can absorb.
##
## `8 + n` (was `9 + 1.2n`) per GAME_STRATEGY_V2.md §11.2, BUILD NEXT #3 — a flatter ramp
## that reaches the same 28-enemy cap four waves later (wave 20 vs wave 16), part of the
## same session-length trim as PREP_TIME.
## Raised from 8 for the same reason as BASE_HP_FLAT, and with the same shape: BASE_COUNT_MAX
## still caps every wave from the mid-teens on, so this lifts the early waves and leaves the
## late ones exactly where they were. Wave 1 goes from 9 creeps to 13, wave 5 from 13 to 17,
## and wave 20 onward is 28 either way.
const BASE_COUNT_FLAT := 12
const BASE_COUNT_LINEAR := 1.0
const BASE_COUNT_MAX := 28
## Gold per kill: `3 + wave` (GAME_STRATEGY_V2.md §29.1, BUILD NEXT #3), replacing the map's
## `max(wave / 3, 1.10^(wave-1))` + flat floor. That exponential stays under the /3 term
## until the high 20s, so through the whole 20-wave Standard span it barely grew (old
## wave_reward(20) = 9); the new run economy is sized against a linear curve instead
## (new wave_reward(20) = 23) — see §29.2's whole-run budget, which assumes this shape.
const REWARD_FLAT := 3
const SPAWN_INTERVAL_START := 0.9
const SPAWN_INTERVAL_DECAY := 0.04
const SPAWN_INTERVAL_MIN := 0.3
const ENEMY_BASE_RADIUS := 24.0
## Hard ceiling on how many enemies one wave may spawn, applied AFTER the archetype and
## per-wave multipliers.
##
## The count curve is linear and the run is now endless, so without this a wave-100 swarm
## asks for ~660 bodies — which is both a framerate cliff and not actually harder to play,
## just longer. Difficulty past this point comes from the quadratic HP curve instead, which
## is the dial that keeps asking the player to build better rather than to wait longer.
##
## Set just above the busiest hand-authored wave (wave 20 swarm = 143), so waves 1-20 are
## completely unaffected and only the generated tail is clamped.
const MAX_SPAWN_COUNT := 160

func wave_hp(wave: int, ruleset: String = DEFAULT_RULESET) -> float:
	return BASE_HP_FLAT * pow(hp_growth(), wave - 1) * CREEP_HP_PERCENT * ruleset_hp_mult(ruleset)

## Both ramps count from wave - 1, so wave 1 sits exactly on the FLAT constants and wave
## STANDARD_WAVES exactly on the FINAL ones. A run past its last wave (Endless, once it
## exists) keeps climbing rather than clamping — the anchor sets the shape, not a ceiling.
func wave_speed(wave: int) -> float:
	return (BASE_SPEED_FLAT + float(wave - 1) * speed_slope()) * CREEP_SPEED_PERCENT

## Ruleset scaling is applied AFTER the flat+linear count and rounded, rather than folded
## into BASE_COUNT_FLAT/LINEAR directly, so "normal" (mult 1.0) reproduces the exact integer
## the un-scaled formula always gave — no behaviour change for the ruleset every existing
## number in this file was already tuned against.
func wave_count(wave: int, ruleset: String = DEFAULT_RULESET) -> int:
	var base := BASE_COUNT_FLAT + int(float(wave) * BASE_COUNT_LINEAR)
	return mini(BASE_COUNT_MAX, int(round(float(base) * ruleset_count_mult(ruleset))))

func wave_reward(wave: int) -> int:
	return REWARD_FLAT + wave

func spawn_interval(wave: int) -> float:
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START - wave * SPAWN_INTERVAL_DECAY)

# --- Element avatar bosses and the fusion ladder --------------------------------
#
# These four waves used to be CHOICE_WAVES, where a three-card roguelite screen appeared.
# The cards are gone: cross-element power is no longer drawn from a pool, it is TAKEN off a
# boss. Each of these waves carries an `element_avatar` boss (Game.WAVES) whose element is
# one of the four, drawn per run in a random order (Run.boss_elements). Kill it and that
# element unlocks for fusion for the rest of the run; leak it and you get nothing.
#
# Every tenth wave, and each avatar walks ALONE — the wave spawns no ordinary creeps at all
# (Game.apply_milestone sets `count` to 0). It used to ride on top of a normal creep wave,
# where the fight that decides a whole element got lost in the traffic; on its own it reads
# as the set piece it is, and the player can aim everything at it.
#
# These four ARE the fusion ladder's pacing, so they are spread evenly rather than bunched:
# at 10/20/30/40 of STANDARD_WAVES' 50 they land at 20%, 40%, 60% and 80% of the run —
# within a few points of the 15%/35%/55%/75% the old 3/7/11/15-of-20 gave, so Pure still
# becomes possible at the same point in the run's shape even though the wave number quadrupled.

## ELEMENT_BOSS_WAVES is declared with STANDARD_WAVES at the top of this file, because it is
## derived from the run length rather than written down. Game.apply_milestone() builds the
## wave from it, so the seed table no longer carries `element_avatar` rows that had to be
## kept in step with it by hand.

## Avatar bosses are deliberately softer than the two set-piece bosses (BOSS_HP_MULT 8.0).
## There are four of them rather than two, the first arrives on wave 3 when START_GOLD has
## paid for maybe two towers, and losing one costs the player a whole element for the run —
## which is punishment enough without also costing five lives.
const ELEMENT_BOSS_HP_MULT := 5.0
const ELEMENT_BOSS_REWARD_MULT := 8
const ELEMENT_BOSS_LIFE_COST := 3

## Gold to absorb the 2nd, 3rd and 4th element into a tower — the dual, the triple and Pure.
## Scaled from the map's own 275 / 1017 combination costs against its 50-gold base tower
## (docs/element-td-data.md §2, §3); the map has no four-element tower, so Pure's is set to
## roughly double the triple, which is what the map's own tier-to-tier steps do at the top.
##
## Sized against `--fill-board`'s own income measurement: ~3.7k gold banked by wave 15 (when
## the last avatar boss falls and Pure first becomes possible) and ~7.1k across the full 20,
## on a maxed board that leaks nothing — so an UPPER bound on what a real player has. Against
## that, walking one tower all the way to Pure costs 480 (maxed base) + 1480 (fusions) = 1960,
## about a quarter of the run: reachable, and a real commitment rather than a default.
##
## Still unproven by PLAY. Nothing simulates a player's gradual build-up, so the numbers above
## are a ceiling, not a budget — these three are the values most likely to move.
## Raised by half with TIER_COSTS above, and for the same reason: with 12 build spots instead
## of 47 the fusion ladder is where most of a run's gold has to go, so it is most of the
## sink. Was [160, 420, 900].
const FUSION_COSTS: Array = [240, 630, 1350]

# --- Meta progression ----------------------------------------------------------

## Essence earned for reaching wave `n`. Mildly superlinear, so pushing two waves deeper is
## worth more than replaying two shallow runs — that is what makes "one more run" a real
## decision rather than a grind. Wave 10 pays ~15, wave 20 ~40, wave 40 ~120.
func run_essence(wave_reached: int) -> int:
	if wave_reached <= 0:
		return 0
	var w := float(wave_reached)
	return int(w + w * w / 20.0)

## How long offline earnings keep accruing. Capped so the game never punishes a player for
## opening it — past this point, waiting longer gains nothing and they may as well play.
const OFFLINE_CAP_HOURS := 8.0
## Essence per hour offline, per wave of the player's best run. Scaling on `best_wave` keeps
## the reward meaningful late instead of decaying into a rounding error, without making it
## competitive with actually playing.
const OFFLINE_ESSENCE_PER_HOUR_PER_WAVE := 0.35
## Offline pays nothing at all below this, so a player who alt-tabs mid-session does not get
## a "welcome back" popup for 40 seconds away.
const OFFLINE_MIN_SECONDS := 300.0

## Essence accrued for `seconds` away, given the player's deepest run.
func offline_essence(seconds: float, best_wave: int) -> int:
	if seconds < OFFLINE_MIN_SECONDS or best_wave <= 0:
		return 0
	var hours := minf(seconds / 3600.0, OFFLINE_CAP_HOURS)
	return int(hours * OFFLINE_ESSENCE_PER_HOUR_PER_WAVE * float(best_wave))

## Cost of taking a workshop entry from `level` to `level + 1`.
func workshop_cost(base_cost: int, cost_growth: float, level: int) -> int:
	return int(round(float(base_cost) * pow(cost_growth, float(level))))

# --- Branch mechanics (BUILD NEXT #5-#6) ----------------------------------------

## Knockback: minimum seconds between two knockbacks on the SAME enemy.
## GAME_STRATEGY_V2.md §4.3's own stated reason: without it, several such towers can
## juggle one enemy in place forever, which is a lock rather than the "buys distance"
## identity the payload is for.
const KNOCKBACK_COOLDOWN := 2.0

# --- Boss (was wave_manager.gd:24-31) ------------------------------------------

## Values from GAME_STRATEGY_V2.md §10.4, BUILD NEXT #3 (was 6.0/0.6/10/10): a boss should
## read as a distinct event rather than a scaled-up Runner, and V1 playtesting found the old
## numbers too close to a normal wave — a slightly slower, harder-hitting boss that pays out
## visibly more, and costs less than half the run's starting lives if it slips.
const BOSS_HP_MULT := 8.0
const BOSS_SPEED_MULT := 0.7
const BOSS_REWARD_MULT := 12
## Not a straight scale-up: a boss has to stay narrower than the road it walks
## (2 * Game.ROAD_HALF = 80), so 38 -> 76 wide is the ceiling here.
const BOSS_RADIUS := 38.0
const BOSS_LIFE_COST := 5
const BOSS_TINT := Color(0.45, 0.1, 0.5)

# --- Enemy archetype modifiers (were bare literals in enemy.gd) ----------------

## Seconds an enemy must go undamaged before regen starts healing it again. This is what
## stops regen from being a hard DPS threshold (was enemy.gd:54).
const REGEN_DELAY := 2.0

## Applied by Enemy.make_flying() to every flyer, Air-wave and random alike
## (was enemy.gd:141-142).
const FLYER_HP_MULT := 0.65
const FLYER_SPEED_MULT := 1.25
## Pale airborne tint, applied by make_flying(). Game.WAVE_TYPES["air"]["color"] carries
## the same value as a literal and cannot read it from here — WAVE_TYPES is a `const`, and
## an autoload is a runtime node, not a constant. Keep the two in step by hand.
const FLYER_TINT := Color(0.72, 0.78, 0.96)

## Stats a splitter's children inherit from the parent (was enemy.gd:247-248).
const SPLIT_HP_MULT := 0.35
const SPLIT_SPEED_MULT := 1.15
const SPLIT_RADIUS_MULT := 0.62
const SPLIT_CHILD_REWARD := 1

# --- Camera shake (was enemy.gd:242, :255) -------------------------------------

const SHAKE_BOSS_DEATH := 7.0
const SHAKE_LEAK := 4.0            ## A leak should be felt, not just noticed in the HUD.
