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

# --- Run start -----------------------------------------------------------------

## The original map starts a player on 30 gold, but its towers are not bought from a
## palette — you research elements and are given elementals, so 30 gold against a
## 50-gold tower is a bootstrap the player reaches by another route. We have no such
## route, so this is one of the two deliberate departures from the map (the other is
## noted on TOWER_DEFS): enough for three tier-1 towers.
const START_GOLD := 150
const START_LIVES := 20

# --- Tower upgrade curve (ported from Element TD v2.0) -------------------------
#
# See docs/element-td-data.md. The map's ladder is five tiers deep and, critically,
# **an upgrade multiplies damage and nothing else** — Fire is 500 range / 0.33s at
# tier 1 and still 500 / 0.33 as Pure Fire. Range and fire interval are fixed per
# element for the whole run, which is what makes the elements read as distinct
# shapes rather than as the same tower at different sizes.

const MAX_LEVEL := 5
## Gold to BUILD a tower at tier 1, then to reach each tier above it. Straight from the
## map: 50 / 175 / 788 / 3544 / 24444.
const TIER_COSTS: Array = [50, 175, 788, 3544, 24444]
## Damage multiplier applied on each upgrade. Tiers 2-4 are x5; Pure is x10, which is
## the one place the map breaks its own pattern and the reason Pure is a decision
## rather than a formality.
const TIER_DAMAGE_MULT: Array = [5.0, 5.0, 5.0, 10.0]
const SELL_REFUND := 0.5          ## fraction of total_spent returned when sold
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
const WC3_RANGE_SCALE := 0.35

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

## Gold cost of upgrading a tower from `level` to `level + 1`.
## `build_cost` is ignored: in the map every element shares one cost ladder regardless
## of which element it is. The parameter stays so callers need not change.
func upgrade_cost(_build_cost: int, level: int) -> int:
	if level < 1 or level >= TIER_COSTS.size():
		return 0
	return int(TIER_COSTS[level])

# --- Wave pacing + economy (was wave_manager.gd:12-22) -------------------------

const PREP_TIME := 4.0            ## Delay between waves.
## Delay before wave 1 only. Training teaches the controls, but the endless run opens on a
## different board with all six towers visible; four seconds is still too short to read the
## palette, choose a coverage spot and place the first defence.
const FIRST_PREP_TIME := 12.0
## Banked gold earns this each wave. The map pays 2.5% every 15 seconds and lets you
## research the rate upward; a wave is roughly one interest tick there, so the rate
## carries over directly. The cap is ours — the map has none, and without one the
## right play late in an endless run is to stop building and hold gold.
const INTEREST_RATE := 0.025
const INTEREST_CAP := 400
const LEAK_FREE_BONUS := 6        ## Bonus if no enemy reached the end this wave.

## Flying used to also be rolled per enemy on ground waves (15% from wave 3). That is gone:
## the archetypes are painted now, and a painted goblin hung in the air is a goblin with a
## drawing mistake, not a flyer. Air is the Air wave, and nothing else — which is also the
## reading the map itself takes.

## Gold for calling a wave in early, by the wave number being skipped into.
func early_call_bonus(wave: int) -> int:
	return 3 + wave

# --- Wave scaling formula (was wave_manager.gd:91-101) -------------------------

## Wave 1 hit points, and the ratio between consecutive waves. Both read out of the
## map: level 1 is 75 hp and every level after is exactly 1.16x the one before, from
## wave 1 through wave 60 (75 -> 476522) with no breakpoints and no boss spike baked
## into the curve itself.
##
## Note the map's own `udg_HP_exponent_base = 1.23` is a decoy — it is declared and
## never read. 1.16 is what the per-level unit types actually contain.
const BASE_HP_FLAT := 75.0
const HP_GROWTH := 1.16
## Creeps spawn at a fraction of their baked hit points, chosen by the map's difficulty
## selector: 50% on the easiest setting, +12.5 points per step. We have no difficulty
## screen, so this is the dial that stands in for one.
const CREEP_HP_PERCENT := 1.0
## Enemy speed is tied to the LENGTH OF THE ROAD, not to anything in the source map, and
## nothing else in the game reads that length — so if the road changes, these move with it
## or the pacing breaks silently. `--dump-board` prints the length: it is 3992px, and
## 80 + 9n gives a wave-1 crossing of about 45 seconds, which is the pace the game was
## tuned at over three road lengths now.
const BASE_SPEED_FLAT := 80.0
const BASE_SPEED_LINEAR := 9.0
## Enemies per wave. The map spawns a FLAT `16 + difficulty * 3` and never grows it — all
## of its difficulty is in the hit-point curve. Faithful, and unplayable as an opening: 28
## enemies at 0.9s apart means wave 1 spends 25 seconds just spawning before anything can
## even be killed, and the first five waves took five and a half minutes to deliver almost
## no progression.
##
## So the count ramps to the map's number instead of starting there. Wave 1 is 9 enemies
## and wave 17 onwards is the full 28, which keeps the map's late-game shape while giving
## the opening a pace a phone session can absorb.
const BASE_COUNT_FLAT := 9
const BASE_COUNT_LINEAR := 1.2
const BASE_COUNT_MAX := 28
## Gold per kill: the map's `max(wave / 3, 1.10^(wave-1))`, plus a flat floor of ours.
##
## The exponential is right for the long game but pays ONE gold a kill until wave 5, which
## against a 50-gold tower meant the first five waves bought about three towers between
## them — the board sat empty and nothing the player did seemed to matter. REWARD_FLAT
## lifts the opening without touching the curve that takes over from wave 8 or so.
const BOUNTY_GROWTH := 1.10
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

func wave_hp(wave: int) -> float:
	return BASE_HP_FLAT * pow(HP_GROWTH, wave - 1) * CREEP_HP_PERCENT

func wave_speed(wave: int) -> float:
	return BASE_SPEED_FLAT + wave * BASE_SPEED_LINEAR

func wave_count(wave: int) -> int:
	return mini(BASE_COUNT_MAX, BASE_COUNT_FLAT + int(float(wave) * BASE_COUNT_LINEAR))

func wave_reward(wave: int) -> int:
	return REWARD_FLAT + int(maxf(float(wave) / 3.0, pow(BOUNTY_GROWTH, wave - 1)))

func spawn_interval(wave: int) -> float:
	return maxf(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_START - wave * SPAWN_INTERVAL_DECAY)

# --- Roguelite choices ---------------------------------------------------------

## A choice is offered after every Nth wave is cleared. Kept frequent on purpose: a short
## session is only a few waves long, and a session that contains no choice at all is just
## a tower defense wave — the choice IS the roguelite loop, so it has to come around inside
## the length of a bus ride.
const CHOICE_EVERY := 3
const CHOICE_COUNT := 3   ## Cards offered per choice.

## Relative odds per rarity before the wave drift below.
const RARITY_WEIGHTS := {
	"common": 60.0, "rare": 25.0, "epic": 12.0, "legendary": 3.0,
}
## How far each rarity sits above common; multiplies the drift.
const RARITY_TIER := {
	"common": 0, "rare": 1, "epic": 2, "legendary": 3,
}
## Each wave nudges the better rarities up, so a deep run stops offering the same commons.
## At wave 30 this is roughly rare x1.5, epic x1.9, legendary x2.4 — a real shift without
## making legendaries routine.
const RARITY_WAVE_DRIFT := 0.015

## Display colours per rarity, used by the choice cards.
const RARITY_COLORS := {
	"common": Color(0.72, 0.76, 0.82),
	"rare": Color(0.38, 0.68, 1.00),
	"epic": Color(0.72, 0.45, 1.00),
	"legendary": Color(1.00, 0.72, 0.22),
}

## Weight for `rarity` when choosing at `wave`.
func rarity_weight(rarity: String, wave: int) -> float:
	var base: float = float(RARITY_WEIGHTS.get(rarity, 1.0))
	var tier: float = float(RARITY_TIER.get(rarity, 0))
	return base * (1.0 + RARITY_WAVE_DRIFT * float(wave) * tier)

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

# --- Boss (was wave_manager.gd:24-31) ------------------------------------------

const BOSS_HP_MULT := 6.0
const BOSS_SPEED_MULT := 0.6
const BOSS_REWARD_MULT := 10
## Not a straight scale-up: a boss has to stay narrower than the road it walks
## (2 * Game.ROAD_HALF = 80), so 38 -> 76 wide is the ceiling here.
const BOSS_RADIUS := 38.0
const BOSS_LIFE_COST := 10
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
