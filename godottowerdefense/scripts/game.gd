extends Node
## Global game state + shared constants.
## Registered as the "Game" autoload (see project.godot), so every script can
## read the shared map layout and the current gold/lives without passing
## references around.

signal gold_changed(amount: int)
signal lives_changed(amount: int)
## The run ended in a loss — lives hit zero. See `victory` below for the other way a
## Standard run ends (GAME_STRATEGY_V2.md's BUILD NEXT #4): a run is no longer necessarily
## endless, so `wave_reached` is not always the whole story any more.
signal game_over
## The run ended in a win — the player cleared Game.STANDARD_WAVES. Fired by
## Game.declare_victory(), never emitted alongside `game_over` for the same run.
signal victory
## Camera kick in pixels. Broadcast here so an Enemy can ask for one without knowing
## anything about the level's camera; Main owns the actual Camera2D.
signal shake_requested(amount: float)
## A tower was built, sold or upgraded. Only the aura towers care: a tower's stats depend
## on which aura providers stand near it, so every tower re-pulls its neighbourhood when
## the set changes. Emitted by Main, which owns those three actions.
signal towers_changed
## The endless run moved to another 10-wave board. The Map node redraws the matching
## painting from this signal; pathing and placement are already installed when it fires.
signal board_changed(board_id: String)

## The design viewport — what the player can see at once. UI (the choice screen, the
## Workshop, the HUD and the tower palette) is drawn against this, in SCREEN space; the
## world below is bigger and the camera scales it down to fit. Converting between the two
## is what PLAY_RIGHT and PLAY_TOP are for.
const SCREEN_SIZE := Vector2(1280, 720)
## The playable world. Sized so the WHOLE board fits on screen at one zoom — the camera
## never pans, because a tower defense you have to scroll is a tower defense where you
## cannot see the leak that just cost you a life.
##
## This was 2560x1440 for exactly one commit. That size came from optimising a single
## number (Light watched 92% of the road on the old board, so the box grew until it did
## not) and it broke the game to fix a statistic: a quarter of the world visible at a
## time, leaks happening off-screen, 196 cells against an economy that pays for 18 by
## wave 10. `--dump-board` says no world small enough to fit on one screen can bring a
## faithful 700px range under 75% coverage, so the range is capped instead — see
## Balance.MAX_TOWER_RANGE. Geometry could not solve both; this is the half worth keeping.
const WORLD_SIZE := Vector2(1536, 864)

# Waypoints of the painted road, TRACED OUT OF THE ARTWORK rather than authored. The board
# is a hand-painted map now (assets/art/board_source.png) and the geometry has to follow the
# picture, or enemies walk beside the road instead of on it.
#
# Produced by tools/trace_road.py: it casts rays from the keep at the centre of the spiral
# and follows the band of pale cobble across them. Both ends are extrapolated — the straight
# run in from the left edge is not an arc the ray-walk can start on, and the last approach is
# too close to the keep for a band to separate from the building — so this is a tracing
# checked by eye against the painting (map.gd's `show_road` draws it back over the art), not
# a proof.
#
# It replaces the spiral ported from Element TD's own pathing map. That geometry was measured
# and this one is drawn; the trade was made deliberately when the art moved to a painted
# board. The coverage table in docs/element-td-data.md describes the old board — --dump-board
# reports this one.
const PATH: Array = [
	Vector2(-144, 321),
	Vector2(51, 326),
	Vector2(66, 306),
	Vector2(81, 330),
	Vector2(110, 306),
	Vector2(125, 325),
	Vector2(140, 306),
	Vector2(198, 309),
	Vector2(213, 316),
	Vector2(228, 334),
	Vector2(243, 337),
	Vector2(257, 333),
	Vector2(272, 322),
	Vector2(287, 340),
	Vector2(346, 306),
	Vector2(412, 247),
	Vector2(452, 189),
	Vector2(523, 154),
	Vector2(588, 129),
	Vector2(658, 121),
	Vector2(720, 122),
	Vector2(775, 131),
	Vector2(827, 154),
	Vector2(865, 164),
	Vector2(898, 174),
	Vector2(927, 178),
	Vector2(959, 169),
	Vector2(985, 188),
	Vector2(1016, 206),
	Vector2(1058, 194),
	Vector2(1088, 209),
	Vector2(1101, 242),
	Vector2(1125, 272),
	Vector2(1134, 302),
	Vector2(1162, 326),
	Vector2(1168, 358),
	Vector2(1185, 391),
	Vector2(1177, 425),
	Vector2(1174, 459),
	Vector2(1158, 489),
	Vector2(1167, 539),
	Vector2(1117, 549),
	Vector2(1098, 574),
	Vector2(1076, 599),
	Vector2(1040, 615),
	Vector2(1013, 653),
	Vector2(983, 679),
	Vector2(946, 683),
	Vector2(910, 677),
	Vector2(871, 694),
	Vector2(834, 683),
	Vector2(800, 664),
	Vector2(762, 654),
	Vector2(718, 647),
	Vector2(675, 630),
	Vector2(635, 605),
	Vector2(589, 578),
	Vector2(548, 541),
	Vector2(501, 499),
	Vector2(479, 444),
	Vector2(493, 387),
	Vector2(557, 341),
	Vector2(596, 303),
	Vector2(640, 274),
	Vector2(709, 270),
	Vector2(740, 254),
	Vector2(788, 253),
	Vector2(826, 263),
	Vector2(845, 253),
	Vector2(872, 264),
	Vector2(892, 267),
	Vector2(910, 271),
	Vector2(927, 288),
	Vector2(938, 306),
	Vector2(948, 316),
	Vector2(957, 325),
	Vector2(969, 327),
	Vector2(974, 339),
	Vector2(988, 341),
	Vector2(990, 354),
	Vector2(990, 367),
	Vector2(996, 376),
	Vector2(981, 390),
	Vector2(1005, 398),
	Vector2(1024, 411),
	Vector2(1008, 422),
	Vector2(1006, 434),
	Vector2(987, 437),
	Vector2(996, 456),
	Vector2(992, 472),
	Vector2(980, 478),
	Vector2(962, 473),
	Vector2(957, 487),
	Vector2(947, 497),
	Vector2(933, 493),
	Vector2(921, 487),
	Vector2(910, 489),
	Vector2(895, 502),
	Vector2(882, 497),
	Vector2(867, 496),
	Vector2(849, 498),
	Vector2(829, 496),
	Vector2(806, 492),
	Vector2(791, 479),
	Vector2(775, 465),
	Vector2(756, 449),
	Vector2(755, 427),
	Vector2(739, 405),
	Vector2(773, 385),
	Vector2(805, 364),
	Vector2(866, 360),
	Vector2(892, 341),
	Vector2(917, 349),
	Vector2(920, 402),
]

# The winding forest first used by the interactive lesson is also the opening endless-run
# board. Both ends continue beyond the canvas, matching the painted road. Keeping this
# geometry beside PATH makes each board a profile owned by Game rather than by one scene.
const WINDING_PATH: Array = [
	Vector2(86, -70), Vector2(96, 38), Vector2(165, 74), Vector2(202, 120),
	Vector2(205, 205), Vector2(250, 276), Vector2(322, 322), Vector2(455, 337),
	Vector2(551, 359), Vector2(598, 414), Vector2(570, 497), Vector2(505, 570),
	Vector2(478, 643), Vector2(525, 716), Vector2(643, 758), Vector2(781, 758),
	Vector2(900, 698), Vector2(965, 634), Vector2(974, 560), Vector2(937, 496),
	Vector2(873, 459), Vector2(827, 395), Vector2(846, 331), Vector2(919, 276),
	Vector2(1010, 286), Vector2(1102, 331), Vector2(1194, 386), Vector2(1304, 386),
	Vector2(1378, 340), Vector2(1442, 276), Vector2(1415, 211), Vector2(1369, 156),
	Vector2(1378, 101), Vector2(1424, 55), Vector2(1536, 18), Vector2(1620, -28),
]

## Legal clearings on the dense winding painting. The same six generous pockets teach the
## player where building is possible and keep towers out of the painted cliffs and trees.
const WINDING_BUILD_ZONES: Array = [
	[Vector2(288, 155), 66.0], [Vector2(376, 155), 66.0],
	[Vector2(855, 140), 82.0], [Vector2(360, 455), 80.0],
	[Vector2(620, 600), 72.0], [Vector2(710, 600), 72.0],
]

## Control points for the generated S board (`assets/art/maps/s_forest_v1.png`). Coordinates
## are traced down the pale cobbles after the 1672x941 painting is fitted to WORLD_SIZE.
## use_board() samples a Catmull-Rom curve through them so walkers follow the painted bends
## smoothly instead of turning across 32 visible straight chords.
const S_PATH: Array = [
	Vector2(-70, 227), Vector2(83, 227), Vector2(170, 252), Vector2(257, 275),
	Vector2(354, 275), Vector2(432, 243), Vector2(492, 188), Vector2(560, 151),
	Vector2(662, 144), Vector2(767, 147), Vector2(864, 170), Vector2(928, 211),
	Vector2(969, 266), Vector2(974, 308), Vector2(946, 344), Vector2(891, 372),
	Vector2(809, 386), Vector2(717, 381), Vector2(634, 376), Vector2(570, 395),
	Vector2(524, 431), Vector2(505, 477), Vector2(510, 528), Vector2(538, 583),
	Vector2(588, 624), Vector2(662, 652), Vector2(753, 666), Vector2(854, 670),
	Vector2(956, 670), Vector2(1047, 670), Vector2(1121, 678), Vector2(1205, 670),
]

## Painted pools and waterfalls on the S board. Rocks and trees remain cosmetic, matching
## the spiral profile; only unmistakable water rejects tower placement.
const S_OBSTACLES: Array = [
	[Vector2(133, 110), 55.0], [Vector2(74, 303), 55.0],
	[Vector2(234, 569), 108.0], [Vector2(105, 708), 72.0],
	[Vector2(1144, 170), 68.0],
]

## Endless maps advance in 10-wave chapters. Add Z and future profiles here after adding
## their geometry to use_board(); the final available map remains active until then.
const WAVES_PER_BOARD := 10
const BOARD_SEQUENCE: Array = ["winding", "spiral", "s"]

# Grid placement: towers snap to cells drawn faintly on the grass, flush against
# the road. The whole board is sized for touch: on a landscape phone the 1280x720
# design viewport stretches by ~0.5, so a 96x88 cell lands at ~48x44 CSS px —
# right at the minimum comfortable tap target. Everything else in the game is
# drawn to match that scale.
const CELL_WIDTH := 96.0         ## Column width (px); columns step by this.
const ROAD_HALF := 40.0          ## Road stone half-width; cell edges tile flush to this.
## Min distance from a cell centre to the road centre-line. A cell flush BESIDE a
## vertical road sits at ROAD_HALF + CELL_WIDTH*0.5 = 88; one flush ABOVE or BELOW a
## horizontal road sits at ROAD_HALF + cell_height*0.5 = 84. This has to clear the
## smaller of the two, with a little slack — the check is `>=` and leaning on float
## equality would be fragile. Nothing is generated between 82 and 84, so the slack
## costs nothing.
const ROAD_CLEARANCE := 82.0
## Screen px the tower palette occupies down the right-hand side. It is a Control in
## Main.tscn anchored to the right at offset_left = -200, and (unlike every node in the
## HUD, which is mouse_filter = IGNORE) it swallows clicks across that whole rect.
const PALETTE_WIDTH := 200.0
## Right edge of the buildable area, in WORLD px. The palette lives in SCREEN space while
## the board lives in world space, and the camera fits the world to the screen, so the
## panel covers a wider strip of world than its own width: 200 screen px over a 1536px
## world shown on a 1280px viewport is 240px of board. Anything past here is under the
## panel, where it cannot be seen and — because the panel eats the click — a tower could
## never be upgraded or sold. Derived rather than written down because it was wrong for a
## commit: it stayed at 1488 through a world resize and put two columns under the palette.
const PLAY_RIGHT := WORLD_SIZE.x * (1.0 - PALETTE_WIDTH / SCREEN_SIZE.x)  # 1296
## Screen px of the HUD's top bar (HUD.tscn). Every HUD node is mouse_filter = IGNORE so
## it costs no clicks, but a cell half under the gold/lives readout is still half invisible.
const HUD_BAR_HEIGHT := 40.0
## Top edge of the buildable area, in WORLD px. Same screen-to-world conversion as
## PLAY_RIGHT.
const PLAY_TOP := WORLD_SIZE.y * (HUD_BAR_HEIGHT / SCREEN_SIZE.y)  # 48

# --- Free placement ------------------------------------------------------------
#
# There is NO BUILD GRID. A tower goes wherever the ground is clear: off the road, off the
# scenery, and not on top of another tower. The board used to be a tiling of 96x88 cells,
# which is a fine rule for a board drawn in code and the wrong one for a board that is a
# painted picture — a grid of pads over hand-painted terrain reads as a spreadsheet laid on
# a landscape, and it forces the art to line up with a lattice nobody drew.
#
# What replaces it is three distances, all in board px, all measured from a tower's centre.

## A tower's footprint. Placement, overlap and the click target all use this one radius, so
## what you can build on, what you can hit and what you can see are the same disc.
const TOWER_RADIUS := 30.0
## Clear of the stone by the tower's own bulk: the road is 80px wide, so a tower may sit
## with its edge exactly against the kerb. Tighter than the old ROAD_CLEARANCE of 82, which
## was not a design choice but an artefact of where a 96px cell could fall.
const ROAD_KEEPOUT := ROAD_HALF + TOWER_RADIUS
## Centre-to-centre spacing. Two towers at exactly 2*TOWER_RADIUS touch, which reads as one
## blob at phone scale; a little air makes a row of towers countable.
const TOWER_GAP := TOWER_RADIUS * 2.0 + 8.0

## Scenery that BLOCKS building, as [centre, radius] in board px. FOUND IN THE PAINTING, not
## invented: tools/trace_road.py's companion scan looks for teal water in the board art and
## reports its clusters, and these are what it found — the lake in the lower left and the
## pool the waterfall drops into.
##
## Only the water is listed. The trees and rocks the map is scattered with are small enough
## that a tower standing among them reads as a tower in a wood, and every one of them added
## here is a place the player is told "no" for a reason they cannot see at a glance.
const OBSTACLES: Array = [
	[Vector2(315, 715), 176.0],   # the lake and the pool the waterfall drops into
]

## True when a tower of TOWER_RADIUS may stand here. `others` is every tower already on the
## board (main passes its Towers node's children); pass an empty array to ask only about
## the terrain, which is what the coverage harness does.
func can_build_at(pos: Vector2, others: Array = []) -> bool:
	if pos.x - TOWER_RADIUS < 0.0 or pos.x + TOWER_RADIUS > PLAY_RIGHT:
		return false
	if pos.y - TOWER_RADIUS < PLAY_TOP or pos.y + TOWER_RADIUS > WORLD_SIZE.y:
		return false
	if dist_to_road(pos) < ROAD_KEEPOUT:
		return false
	for entry in active_obstacles:
		if pos.distance_to(entry[0]) < float(entry[1]) + TOWER_RADIUS:
			return false
	# A board may expose only a few painted clearings. The main board leaves this empty and
	# keeps free placement; the training board fills it so its dense forest really is closed
	# ground instead of merely looking closed.
	if not active_build_zones.is_empty():
		var inside_zone := false
		for entry in active_build_zones:
			if pos.distance_to(entry[0]) <= float(entry[1]) - TOWER_RADIUS:
				inside_zone = true
				break
		if not inside_zone:
			return false
	for other in others:
		if other != null and pos.distance_to(other.position) < TOWER_GAP:
			return false
	return true

# START_GOLD / START_LIVES moved to the Balance autoload with the rest of the economy —
# see scripts/balance.gd. This file keeps the map geometry and the data tables.

# --- Element tower definitions -------------------------------------------------
# Every tower (base element or dual combination) is just a data entry.
#
# The six base elements carry the ORIGINAL Element TD v2.0 numbers — see
# docs/element-td-data.md, re-derivable with tools/extract_w3x.py. Two things about
# that data drive everything else:
#
#   * `range` is in WARCRAFT III units, not pixels. Read sites multiply by
#     Balance.WC3_RANGE_SCALE (tower.gd `_recompute`, main.gd's range preview), so
#     retuning the board scale is one constant rather than six literals.
#   * The six sit at nearly equal DPS and differ only in range and cadence. Fire is
#     short and quick, Water is a stream of tiny hits, Light and Darkness reach four
#     times as far as Fire, and Darkness buys the biggest single hit with a 2.75s
#     wind-up. Do not "fix" one of these to match the others — the spread IS the design.
#
# DEPARTURE FROM THE MAP: in the original the six base elements are plain attackers,
# and slow / poison / splash arrive only with the dual towers (Ice, Poison, Lava...).
# Eight duals now exist, but they arrive mid-run behind two element cards — stripping
# the effects off Water, Nature and Earth would leave the opening waves with no crowd
# control at all. They keep their effects; the numbers are faithful, the payloads ours.
#
# `damage_tiers` lists the damage at each of the five tiers EXPLICITLY rather than
# deriving them from a growth multiplier. Tiers 1-4 are exact x5 steps and Pure is x10,
# but the map's Pure row was clearly hand-typed and lands a few points short of its own
# rule (Pure Water is 12491 where x10 would give 12500). A multiplier cannot reproduce
# that, and a faithful port reproduces the map including its typos. A def without this
# key falls back to Balance.TIER_DAMAGE_MULT.
#
# Fields: name, cost, color, damage / damage_tiers, range, interval, can_hit_flying,
#   splash_radius/splash_factor (AoE), slow_factor/slow_time (0..1 = slower),
#   slow_splash (Lv2+ radius the slow ALSO spreads to — slow only, no damage),
#   poison_dps/poison_time (damage over time),
#   stun_chance/stun_time (chance to freeze the enemy in place). Missing = "off".
## Lv1-2 base stats for the four elements are no longer ported WC3 numbers — they are
## GAME_STRATEGY_V2.md §4.3's own design values (BUILD NEXT #5-#6), replacing the WC3-tier
## damage ladder step 3 deliberately left untouched. `range` stays in the WC3-unit field
## (read by Balance.WC3_RANGE_SCALE, tower.gd `_recompute`) purely so every other range read
## site keeps working unmodified — the WC3-unit framing is now fiction for these four, so
## each is commented with the real px target it was reverse-derived from
## (target_px / Balance.WC3_RANGE_SCALE = 0.35). `damage_tiers` follows the shared
## 1.0/1.8/3.2/5.6/10.0 growth shape (§4.2) from each element's own new Lv1 base, rounded by
## hand the same way the WC3 Pure-tier numbers were — see the comment below this table.
##
## From Lv3, a tower's stats also depend on Game.TOWER_BRANCHES[element][branch] — see
## Tower._recompute() and BUILD NEXT #5's branch-choice popup. Lv1-2 (no branch chosen yet)
## always uses the bare entry below.
const TOWER_DEFS := {
	"fire": {
		"name": "Fire", "cost": 50, "color": Color(0.95, 0.45, 0.18), "element": "fire",
		"damage_tiers": [10, 18, 32, 56, 100],
		"range": 485.7, "interval": 0.40,      # range: 170px = 485.7 * 0.35
		# Burn: 4 dps, 2s, 1 stack (Blaze/Wildfire change this from Lv3 — see TOWER_BRANCHES).
		"burn_dps": 4.0, "burn_time": 2.0, "burn_max_stacks": 1,
	},
	"water": {
		"name": "Water", "cost": 50, "color": Color(0.30, 0.60, 0.95), "element": "water",
		"damage_tiers": [6, 11, 19, 34, 60],
		"range": 600.0, "interval": 0.25,      # range: 210px = 600.0 * 0.35
		"slow_factor": 0.75, "slow_time": 1.5, # Chill: -25% speed, 1.5s, on every hit
	},
	"nature": {
		"name": "Nature", "cost": 50, "color": Color(0.35, 0.80, 0.35), "element": "nature",
		"damage_tiers": [12, 22, 38, 67, 120],
		"range": 628.6, "interval": 0.90,      # range: 220px = 628.6 * 0.35
		"poison_dps": 12.0, "poison_time": 3.0,
		# Base THORN identity, both branches inherit it (GAME_STRATEGY_V2.md §3.1): poison
		# ignores the element matchup entirely (unlike every other payload in the game,
		# direct hits included) and, like all damage, blocks this tick's regen — see
		# Enemy.take_damage's regen-block, which already fires for poison ticks with no
		# extra code needed.
		"poison_ignores_matchup": true,
	},
	"earth": {
		"name": "Earth", "cost": 50, "color": Color(0.72, 0.55, 0.34), "element": "earth",
		"damage_tiers": [34, 61, 109, 190, 340],
		"range": 571.4, "interval": 1.40, "can_hit_flying": false,  # range: 200px = 571.4 * 0.35
		"splash_radius": 90.0, "splash_factor": 0.5,
	},
	## Reaches four times as far as Fire for the same DPS. On our board that is over
	## half the width — the map's boards are much larger, so this is the number whose
	## meaning changes most in the port. Measure before tuning.
	"light": {
		"name": "Light", "cost": 50, "color": Color(1.0, 0.96, 0.72), "element": "light",
		"damage_tiers": [50, 250, 1250, 6250, 62491],
		"range": 2000.0, "interval": 0.99,
	},
	## Same reach as Light, and the largest single hit in the game — but it lands once
	## every 2.75s, so a leaker that walks out of range between shots costs a full cycle.
	"darkness": {
		"name": "Darkness", "cost": 50, "color": Color(0.45, 0.28, 0.62), "element": "darkness",
		"damage_tiers": [165, 825, 4125, 20625, 206241],
		"range": 2000.0, "interval": 2.75,
	},
}
## The buildable roster, in palette order. Cut from six elements to four in the V2 redesign
## (see GAME_STRATEGY_V2.md §2, BUILD NEXT #2): Light and Darkness are retired as a *role*,
## not deleted — their TOWER_DEFS entries and painted art stay in the repo, unreferenced,
## for the Phase 4 return GAME_STRATEGY_V2.md §28 describes. The fifteen dual towers and
## Lightning went the same way as the dual mechanic they depended on (see ELEMENT_BEATS and
## the removed DUAL_RECIPES/DUAL_ELEMENT_LEVEL below) — cross-element play becomes a card
## effect (Run/UPGRADE_POOL), not a second tier of buildable towers.
## Ordered around the damage circle (see ELEMENT_BEATS) rather than alphabetically, so the
## palette itself teaches which element answers which.
const TOWER_ORDER: Array = ["water", "fire", "nature", "earth"]

# --- Tower branches (BUILD NEXT #5-#6) ------------------------------------------
# Every element splits into two branches at Lv3 (GAME_STRATEGY_V2.md §4, §4.3): a two-card
# popup (branch_choice.gd, shown from main.gd's _upgrade_tower once a tower reaches level 3)
# sets Tower.branch to "a" or "b" for the rest of the run. From then on Tower._recompute()
# layers this entry's `lv3` fields over the base TOWER_DEFS entry, then `lv4`/`lv5` as the
# tower keeps levelling — a plain Dictionary.merge(overwrite=true) each step, so any field
# the branch does not mention keeps its base/lower-tier value. `lv1_2` fields (currently
# unused) are reserved for a branch that needs to differ before Lv3, which none do.
#
# Levelling stays "seviye sadece hasarı değiştirir; branch her şeyi değiştirebilir" (§2.3):
# the 1.0/1.8/3.2/5.6/10.0 damage growth from TOWER_DEFS.damage_tiers is untouched by branch
# choice — a branch instead multiplies the RESULT via `damage_mult`, so Siege's "+60%
# damage" stacks on top of the same ladder every tower climbs, rather than replacing it.
#
# No stat here is WC3-derived; every number is GAME_STRATEGY_V2.md §4.3's own design value,
# already in the units _recompute() reads them in (seconds, px, 0..1 chance/factor) — none
# of them go through Balance.WC3_RANGE_SCALE. The mechanic each branch is actually FOR
# (burn stacking, knockback, armor-crack, the Grove aura) is new engine-side machinery in
# enemy.gd / tower.gd / projectile.gd, listed in each branch's comment; the stats here are
# only the part a plain override can express.
const TOWER_BRANCHES := {
	"fire": {
		"a": {
			"id": "blaze", "name": "Blaze", "desc": "Faster. Burn stacks up to 3x",
			# Burn now stacks instead of just refreshing (Enemy.apply_burn/_burn_stacks).
			"lv3": {"interval": 0.28, "burn_max_stacks": 3},
			# Cinderheart: at 3 stacks, burn ticks twice as fast (Enemy._burn_doubles_at_max).
			"lv5": {"burn_doubles_at_max": true},
		},
		"b": {
			"id": "wildfire", "name": "Wildfire", "desc": "Burn spreads to nearby enemies",
			# Burn also catches enemies within 70px at half power on every hit
			# (Projectile._apply_burn_splash).
			"lv3": {"burn_spread_radius": 70.0},
			# Firestorm: simplified from §4.3's persistent 4s ground patch — GDScript's
			# scene-tree lifecycle makes a standalone hazard object real scope on its own, and
			# an instant transfer reads the same in practice (a burning kill sets nearby
			# enemies alight) without a new autonomous node type. Documented, not hidden: see
			# BUILD NEXT #6 notes in the design memory.
			"lv5": {"burn_spreads_on_death": true},
		},
	},
	"water": {
		"a": {
			"id": "glacier", "name": "Glacier", "desc": "Deeper chill. Pulses every 4th shot",
			"lv3": {"slow_factor": 0.55, "chill_pulse_every": 4},
			# Absolute Zero reuses the existing generic stun_chance/stun_time payload — a
			# freeze IS a stun as far as Enemy/Projectile are concerned, just named for what
			# it looks like on Water.
			"lv5": {"stun_chance": 0.15, "stun_time": 1.0},
		},
		"b": {
			"id": "undertow", "name": "Undertow", "desc": "Chance to push enemies back",
			# 2s per-enemy cooldown and boss immunity are enforced engine-side
			# (Enemy.apply_knockback / Projectile._apply), not data here.
			"lv3": {"knockback_chance": 0.25, "knockback_distance": 60.0},
			"lv5": {"knockback_distance": 120.0, "knockback_chill_on_land": true},
		},
	},
	"earth": {
		"a": {
			"id": "quake", "name": "Quake", "desc": "Bigger splash. Every hit staggers",
			# Stagger reuses the generic stun payload at a short, always-on duration.
			"lv3": {"splash_radius": 140.0, "stun_chance": 1.0, "stun_time": 0.4},
			# Fissure reuses the EXISTING slow_splash mechanism (already "the slow also
			# spreads to this radius") — no new engine code, just filling in the fields Ice
			# used to.
			"lv5": {"slow_splash": 140.0, "slow_factor": 0.7, "slow_time": 2.0},
		},
		"b": {
			"id": "siege", "name": "Siege", "desc": "Smaller splash. Cracks armor",
			"lv3": {"splash_radius": 50.0, "damage_mult": 1.6},
			# The crack (+25% damage taken from ALL sources, 3s) is written up in §4.3 as
			# switching on at Lv4, not Lv3 — the only branch whose mechanic has its own
			# internal level gate rather than turning on wholesale at Lv3.
			"lv4": {"crack_bonus": 0.25, "crack_time": 3.0},
			# Sunder: the crack also spreads to enemies within 80px when applied.
			"lv5": {"crack_spread_radius": 80.0},
		},
	},
	"nature": {
		"a": {
			"id": "blight", "name": "Blight", "desc": "Stronger poison that never expires",
			# "Kendini yeniler" needs no new code: apply_poison() already extends the timer
			# (maxf) on every hit, so a target the tower keeps hitting never sees it lapse.
			"lv3": {"poison_dps_mult": 1.8, "poison_time": 8.0},
			# Plague: a poisoned enemy that dies passes its poison to the nearest survivor.
			"lv5": {"poison_spreads_on_death": true},
		},
		"b": {
			"id": "grove", "name": "Grove", "desc": "Doesn't attack. Empowers nearby towers",
			# no_attack stops Tower._process from ever asking for a target — see the
			# aura_stat pattern this reuses (Tower._recompute's neighbour loop), extended
			# with two fields (aura_gold_add, aura_life_chance_add) that pattern never
			# needed before because no earlier aura granted more than one stat at once.
			"lv3": {"no_attack": true, "aura_stat": "attack_speed", "aura_radius": 160.0,
					"aura_mult": 1.15},
			"lv4": {"aura_gold_add": 1},
			"lv5": {"aura_damage_mult": 1.12, "aura_life_chance_add": 0.03},
		},
	},
}

# --- Wave definitions ----------------------------------------------------------
# Each wave picks an archetype from WAVE_TYPES; its stats = the base scaling
# (quadratic HP etc. in wave_manager) times the archetype's multipliers. Fields
# (all optional, default 1.0 / false / 0):
#   name, color, hp, spd, count, radius, cc_immune, regen (frac of max hp/s),
#   split (children on death), air (all flyers).
const WAVE_TYPES := {
	## Training scene only. Few, slow and soft enough that a single tower clears it
	## comfortably. Never used by the endless-wave table or generator.
	"tutorial": {"name": "Scout", "color": Color(0.80, 0.55, 0.45),
			"hp": 0.45, "spd": 0.7, "count": 0.5},
	"normal": {"name": "Normal", "color": Color(0.85, 0.30, 0.30)},
	"fast":   {"name": "Fast",   "color": Color(0.95, 0.85, 0.25), "hp": 0.6, "spd": 1.7, "count": 1.3, "radius": 0.85},
	"swarm":  {"name": "Swarm",  "color": Color(0.90, 0.50, 0.75), "hp": 0.35, "spd": 1.15, "count": 2.6, "radius": 0.8},
	"tank":   {"name": "Tank",   "color": Color(0.45, 0.50, 0.55), "hp": 3.0, "spd": 0.6, "count": 0.4, "radius": 1.35},
	"immune": {"name": "Immune", "color": Color(0.60, 0.62, 0.70), "hp": 1.15, "count": 0.85, "cc_immune": true},
	"regen":  {"name": "Regen",  "color": Color(0.35, 0.75, 0.40), "hp": 1.0, "count": 0.8, "regen": 0.035},
	# 1.4 because a wingspan is not a height. Every other creep is a standing figure whose
	# bounding box IS its body, so drawing that box 2.6 radii tall sizes the creature. The
	# dragon's box is mostly wing — at 1.0 its body came out a third smaller than the single
	# pose it replaced, and its health bar floated clear of it.
	"air":    {"name": "Air",    "color": Color(0.72, 0.78, 0.96), "air": true, "radius": 1.4},
	"split":  {"name": "Splitter","color": Color(0.85, 0.55, 0.25), "hp": 1.0, "count": 0.6, "split": 2, "radius": 1.15},
}

## The SEED TABLE: the hand-authored opening of a run. A run does not end here — past the
## last entry, WaveGenerator takes over and produces waves forever (see wave_generator.gd).
## These exist so the first minutes are *taught* rather than rolled: each new mechanic
## arrives on its own wave, in a deliberate order, instead of whenever the dice say.
##
## The interactive tutorial now runs on its own map before Main. This table therefore starts
## with a gentle REAL wave, then introduces one idea at a time: speed, numbers, the element
## matchup, flyers, CC immunity, regeneration, splitting — and the first boss on 10, which
## is the cadence the generator keeps forever after.
##
## "element" (optional) is the wave's armor element (empty/absent = neutral); early waves
## and all Air waves stay neutral so element colour doesn't clash with the archetype tint.
## "art" / "name" may override only the painted creature and preview label while keeping
## the `type` archetype's combat stats — wave 1 uses the familiar tutorial Scout this way.
const WAVES: Array = [
	{"type": "normal", "art": "tutorial", "name": "Scout", "count": 0.65}, # 1
	{"type": "normal"},                                # 2  — a real wave, still gentle
	{"type": "fast"},                                  # 3  — speed
	{"type": "swarm"},                                 # 4  — numbers
	{"type": "normal", "element": "fire"},             # 5  — first armour element
	{"type": "air"},                                   # 6  — flyers: ground-only towers miss
	{"type": "immune", "element": "nature"},           # 7  — slow/stun stop working
	{"type": "fast", "element": "earth"},              # 8
	{"type": "regen", "element": "water"},             # 9  — must out-damage the heal
	# boss_rule (GAME_STRATEGY_V2.md §10.4, BUILD NEXT #7): the ONE question each boss asks.
	# Wave 10's Muhafız is immune to every control effect in the game (slow/stun/knockback —
	# see Enemy.cc_immune) rather than to one named kind, so a future control type is covered
	# automatically instead of needing its own exemption listed here.
	{"type": "tank", "boss": true, "element": "water", "boss_rule": "control_immune"},# 10 — FIRST BOSS
	{"type": "split", "element": "nature"},            # 11 — splitters
	{"type": "tank", "element": "earth"},              # 12
	{"type": "air"},                                   # 13
	{"type": "immune", "element": "water"},            # 14
	{"type": "fast", "element": "fire"},               # 15
	{"type": "regen", "element": "nature"},            # 16
	{"type": "split", "element": "earth"},             # 17
	{"type": "swarm", "element": "water"},             # 18
	{"type": "tank", "element": "fire", "hp": 0.85},   # 19 — mild trim so 20 reads as the spike
	# Wave 20's Uyanmış Muhafız cycles its own armour every 5s (Enemy.rotating_armor) around
	# Game.TOWER_ORDER's ring, starting here at "fire" — asks whether the run invested in one
	# element or spread across all four, which the first boss never asked.
	{"type": "swarm", "boss": true, "element": "fire", "boss_rule": "rotating_armor"},# 20 — SECOND BOSS, then the generator
]

# --- Roguelite upgrade pool ----------------------------------------------------
# Offered three at a time between waves; the player keeps one, and it lasts the run.
# Adding an upgrade is a row here — Run folds the effects generically and the choice
# screen renders whatever it is handed, so neither needs to know this one exists.
#
# Fields:
#   id          unique; also the key stacking is counted against
#   name/desc   what the card shows. `desc` must state the real number — a card whose
#               text and effect disagree is worse than no card
#   rarity      common | rare | epic | legendary (weights live in Balance)
#   effects     list of {stat, op, value}; see TowerMods.fold for the stats
#   element     optional — restrict to towers of this damage element
#   tower       optional — restrict to this exact tower id
#   unlock      optional — grants a tower id instead of applying effects
#   max_stacks  optional (default 1) — how many times it may be taken in one run
#   min_wave    optional — not offered before this wave
#
# An entry with neither `element` nor `tower` applies to every tower, which is why the
# global ones cost a higher rarity than their single-element equivalents.
## The 22-card pool BUILD NEXT #9 replaces the interim step-2 prune with (GAME_STRATEGY_V2.md
## §6.3): 8 tower-mechanic cards, 6 cross-element synergy cards, 4 economy cards, 4 run-
## identity cards. Every card here is genuinely new relative to the old pool — this is a
## wholesale replacement, not an extension, because the interim pool's flat "+25% damage to
## one element" cards were explicitly a step-2 placeholder for this step to retire.
##
## Most of the new stats (burn_time, slow_time, vs_flying, burn_slow, overclock_every,
## groundwork, target_lowest_hp, chill_burn, chill_hit) are TowerMods.fold cases; MAGMA,
## EMBERSEED, BLOOM, BEDROOT and SALVAGE carry no `effects` at all — they gate purely on
## Run.has_card(id) at the engine call site that needs them (tower.gd's BLOOM/BEDROOT aura
## scan, enemy.gd's EMBERSEED spread, projectile.gd's MAGMA refresh and Aftershock echo,
## tower.gd's Salvage-equivalent check lives in Tower.sell_value — see BUILD NEXT #9 notes
## in the design memory for the full engine-side map).
const UPGRADE_POOL: Array = [
	# --- Mekanik (8) -------------------------------------------------------------
	{"id": "wick", "name": "Wick", "rarity": "common", "max_stacks": 1,
		"element": "fire", "desc": "Fire's burn lasts twice as long",
		"effects": [{"stat": "burn_time", "op": "mult", "value": 2.0}]},
	{"id": "permafrost", "name": "Permafrost", "rarity": "common", "max_stacks": 3,
		"element": "water", "desc": "Water's chill lasts 1.5s longer",
		"effects": [{"stat": "slow_time", "op": "add", "value": 1.5}]},
	{"id": "long_sight", "name": "Long Sight", "rarity": "common", "max_stacks": 3,
		"desc": "All towers gain +25 range",
		"effects": [{"stat": "range", "op": "add", "value": 25.0}]},
	{"id": "backdraft", "name": "Backdraft", "rarity": "rare", "max_stacks": 1,
		"element": "fire", "desc": "Fire's burn also slows the target by 15%",
		"effects": [{"stat": "burn_slow", "op": "mult", "value": 0.85}]},
	{"id": "aftershock", "name": "Aftershock", "rarity": "rare", "max_stacks": 1,
		"element": "earth", "desc": "Earth's splash lands again 0.3s later at 40% power"},
	{"id": "spore", "name": "Spore", "rarity": "rare", "max_stacks": 1,
		"element": "nature", "desc": "Nature towers deal +60% damage to flying enemies",
		"effects": [{"stat": "vs_flying", "op": "mult", "value": 1.6}]},
	{"id": "overclock", "name": "Overclock", "rarity": "epic", "max_stacks": 1,
		"desc": "Every tower's 5th shot deals double damage",
		"effects": [{"stat": "overclock_every", "value": 5.0}]},
	{"id": "groundwork", "name": "Groundwork", "rarity": "legendary", "max_stacks": 1,
		"element": "earth", "desc": "Earth can now hit flying enemies, but its splash radius is halved",
		"effects": [{"stat": "groundwork", "value": 1.0}]},

	# --- Cross-element (6) — GAME_STRATEGY_V2.md §6.2 ---------------------------
	{"id": "steam", "name": "Steam", "rarity": "rare", "max_stacks": 1,
		"element": "fire", "desc": "Fire's burn deals +50% damage to chilled enemies",
		"effects": [{"stat": "chill_burn", "op": "mult", "value": 1.5}]},
	{"id": "erosion", "name": "Erosion", "rarity": "rare", "max_stacks": 1,
		"element": "earth", "desc": "Earth deals +40% damage to chilled enemies",
		"effects": [{"stat": "chill_hit", "op": "mult", "value": 1.4}]},
	{"id": "magma", "name": "Magma", "rarity": "epic", "max_stacks": 1,
		"desc": "Earth's splash refreshes the burn on any enemy it hits"},
	{"id": "embers_eed", "name": "Emberseed", "rarity": "epic", "max_stacks": 1,
		"desc": "A poisoned enemy dying while burning spreads its poison to three neighbours instead of one"},
	{"id": "bloom", "name": "Bloom", "rarity": "rare", "max_stacks": 1,
		"desc": "Nature towers within 140px of a Water tower tick their poison 30% faster"},
	{"id": "bedroot", "name": "Bedroot", "rarity": "rare", "max_stacks": 1,
		"desc": "Earth towers within 140px of a Nature tower also spread poison"},

	# --- Ekonomi (4) -------------------------------------------------------------
	{"id": "prospector", "name": "Prospector", "rarity": "common", "max_stacks": 5,
		"desc": "+2 gold for every enemy killed",
		"effects": [{"stat": "gold_per_kill", "op": "add", "value": 2.0}]},
	{"id": "foreman", "name": "Foreman", "rarity": "common", "max_stacks": 1,
		"desc": "Upgrades cost 20% less",
		"effects": [{"stat": "upgrade_cost_mult", "value": 0.8}]},
	{"id": "salvage", "name": "Salvage", "rarity": "rare", "max_stacks": 1,
		"desc": "Selling a tower always refunds it in full"},
	{"id": "compound", "name": "Compound", "rarity": "epic", "max_stacks": 1,
		"desc": "Wave-end interest rises from 5% to 8%",
		"effects": [{"stat": "interest_rate_add", "value": 0.03}]},

	# --- Run kimliği (4) ----------------------------------------------------------
	{"id": "deadeye", "name": "Deadeye", "rarity": "epic", "max_stacks": 1,
		"desc": "All towers now target the enemy with the LEAST health",
		"effects": [{"stat": "target_lowest_hp", "value": 1.0}]},
	{"id": "bulwark", "name": "Bulwark", "rarity": "epic", "max_stacks": 1,
		"grant_lives": 5,
		"desc": "+5 lives right now, but all towers deal 10% less damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 0.9}]},
	{"id": "monoculture", "name": "Monoculture", "rarity": "legendary", "max_stacks": 1,
		"needs_element_choice": true,
		"desc": "Choose an element: it deals +50% damage, the other three deal -20%"},
	{"id": "frontload", "name": "Frontload", "rarity": "legendary", "max_stacks": 1,
		"grant_gold": 300,
		"desc": "+300 gold right now, but every kill's bounty is reduced by 25%",
		"effects": [{"stat": "kill_gold_mult", "value": 0.75}]},
]

# --- Workshop: permanent upgrades ----------------------------------------------
# Bought with Essence between runs and applied at the start of every run afterwards.
# Levels are cumulative: owning level 3 folds the entry's `effects` three times, which is
# why every effect here has to be a per-level step rather than a total.
#
# Tower-stat effects go through exactly the same TowerMods.fold as the roguelite cards —
# permanent and temporary power share one path, so there is one place to reason about how
# they stack. `start_gold` and `start_lives` are run-start values instead and are read
# directly by Meta; they are not tower stats and must not be folded.
#
# Fields: id, name, desc (%s is replaced by the per-level step), max_level, base_cost,
#         cost_growth (cost of level n = base_cost * cost_growth^n), effects.
const WORKSHOP_DEFS: Array = [
	{"id": "forge", "name": "Forge", "desc": "+6% tower damage per level",
		"max_level": 10, "base_cost": 20, "cost_growth": 1.55,
		"effects": [{"stat": "damage", "op": "mult", "value": 1.06}]},
	{"id": "tempo", "name": "Tempo", "desc": "+4% attack speed per level",
		"max_level": 8, "base_cost": 30, "cost_growth": 1.65,
		"effects": [{"stat": "attack_speed", "op": "mult", "value": 1.04}]},
	{"id": "lens", "name": "Lens", "desc": "+6 tower range per level",
		"max_level": 8, "base_cost": 25, "cost_growth": 1.5,
		"effects": [{"stat": "range", "op": "add", "value": 6.0}]},
	{"id": "treasury", "name": "Treasury", "desc": "+20 starting gold per level",
		"max_level": 10, "base_cost": 18, "cost_growth": 1.45,
		"effects": [{"stat": "start_gold", "op": "add", "value": 20.0}]},
	{"id": "ramparts", "name": "Ramparts", "desc": "+2 starting lives per level",
		"max_level": 8, "base_cost": 35, "cost_growth": 1.7,
		"effects": [{"stat": "start_lives", "op": "add", "value": 2.0}]},
]

# --- Element matchup -----------------------------------------------------------
# A tower's damage element vs an enemy's armour element gives a multiplier (see
# element_mult). Neutral ("") on either side = x1, so Lightning / dual towers and
# early/air waves are unaffected.
## The damage circle, cut back to four elements (GAME_STRATEGY_V2.md §3.3): Water -> Fire
## -> Nature -> Earth -> Water. Each element beats the next one round; being beaten is the
## weak side. Three of these four relationships are the same links the six-element ring
## carried; only Earth's target moved, from the retired Light to Water, closing the ring
## on itself. Every relationship now has a physical read (water douses fire, fire burns
## plant, roots crack stone, earth dams water) instead of an arbitrary link to memorize.
const ELEMENT_BEATS := {
	"water": "fire", "fire": "nature", "nature": "earth", "earth": "water",
}
const ELEMENT_COLORS := {
	"fire": Color(0.95, 0.45, 0.18), "water": Color(0.30, 0.60, 0.95),
	"nature": Color(0.35, 0.80, 0.35), "earth": Color(0.72, 0.55, 0.34),
	"light": Color(1.0, 0.96, 0.72), "darkness": Color(0.45, 0.28, 0.62),
}
## 1.6 / 0.85 (was 1.75 / 0.7) per GAME_STRATEGY_V2.md §7.2, BUILD NEXT #3 — deliberately
## missed in the first pass at #3 and fixed here. At the old 2.5x spread between a strong and
## a weak hit, matchup was the single biggest lever in the game (bigger than placement or
## branch choice combined) and optimal play degenerated to "read the wave's colour, build its
## counter." At 1.6/0.85 (1.88x spread) matchup sits in the same weight class as those other
## decisions instead of dominating them — see §7.2's side-by-side comparison table.
const ELEMENT_STRONG := 1.6
## Mismatched element damage, deliberately gentler than ELEMENT_STRONG is generous: a reward-
## first asymmetry, so building the wrong element for a wave costs less than building the
## right one gains.
const ELEMENT_WEAK := 0.85

## Damage multiplier for attacker element `atk` hitting armour element `def`.
func element_mult(atk: String, def: String) -> float:
	if atk == "" or def == "":
		return 1.0
	if ELEMENT_BEATS.get(atk, "") == def:
		return ELEMENT_STRONG
	if ELEMENT_BEATS.get(def, "") == atk:
		return ELEMENT_WEAK
	return 1.0

## The active difficulty (GAME_STRATEGY_V2.md §12, BUILD NEXT #8): "normal" or "easy", a key
## into Balance.RULESETS. Picked on the menu (see menu.gd) before Main even loads, read by
## reset() below for start gold/lives and by wave_manager.gd for the HP/count scaling — it is
## NOT reset by Game.reset() itself, so a mid-run retry keeps whatever the player chose.
var ruleset: String = Balance.DEFAULT_RULESET
var gold: int = 0
var lives: int = 0
var is_over: bool = false
## True when `is_over` was reached by clearing the last wave rather than running out of
## lives. Distinguishes the two on the end screen (see EndScreen.show_summary) without a
## second copy of everything `is_over` already gates (spawning, life loss, the choice screen).
var is_won: bool = false
## Highest wave this run actually started. The run summary's headline number, and the basis
## for the permanent-currency award once meta progression lands.
var wave_reached: int = 0
# The all-time best wave now lives in Meta, where it is persisted along with the rest of
# the permanent progression — see Meta.best_wave.

## The number of hand-authored waves a Standard run plays before it can be won. Kept as its
## own named constant rather than reading Game.WAVES.size() at the call site, so the win
## condition (WaveManager) states its own intent instead of leaning on the seed table's
## length being exactly this by coincidence — the two happen to match today (20) and should
## keep matching if the seed table ever grows.
const STANDARD_WAVES := 20

## Which enemy caused the most recent life loss, and on which wave — overwritten by every
## leak, fatal or not, so by the time `game_over` fires this describes the exact leak that
## ended the run. Read by EndScreen for the one-line "why you lost" (GAME_STRATEGY_V2.md
## §24.1, BUILD NEXT #4). Cleared on reset() so a stale reason never survives into a run
## that hasn't lost yet.
var last_leak_wave: int = 0
var last_leak_label: String = ""    ## WAVE_TYPES display name, e.g. "Regen".
var last_leak_element: String = ""  ## Armor element, "" = neutral.

## Records that `label` (element `element`) got past the defense on the current wave. Called
## by Enemy._escape() BEFORE Game.lose_life(), so a fatal leak's own data is what survives.
func record_leak(label: String, element: String) -> void:
	last_leak_wave = wave_reached
	last_leak_label = label
	last_leak_element = element

## Ends the run as a win: the player cleared Game.STANDARD_WAVES. Reuses `is_over` for every
## guard that already stops the run (spawning, life loss, another choice) rather than adding
## a second flag those sites would also need to check — `is_won` only distinguishes how the
## summary is framed.
func declare_victory() -> void:
	if is_over:
		return
	is_over = true
	is_won = true
	victory.emit()

## The active board profile. Main uses PATH/OBSTACLES; the training scene swaps in the
## separate painted map's open road and its deliberately scarce build clearings. Keeping the
## profile here means Enemy movement, targeting progress and placement all read ONE path.
var active_path: Array = []
var active_obstacles: Array = []
var active_build_zones: Array = []
var active_board_id: String = ""

## Cumulative distance from active_path[0] to each waypoint. Towers
## rank enemies by how far along the road they are (the First / Last targeting modes)
## off this table, so no enemy has to carry its own odometer.
var _path_cum: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	use_main_board()

## Restores the endless-run board. Called by Menu/Main as well as on leaving training, so a
## scene reload can never inherit the short tutorial road from the scene before it.
func use_main_board() -> void:
	use_board("spiral")

## Selects the endless board for `wave`. The last available profile remains active after its
## chapter, so an unfinished map slot never sends a deep run back to an earlier layout.
## A real run always gets free placement — the scarce painted clearings are a lesson device,
## not an endless-run rule — so this never passes the tutorial's WINDING_BUILD_ZONES on.
##
## UNREACHED as of BUILD NEXT #8: Standard mode pins to main.gd's STANDARD_BOARD for its
## whole length instead of rotating (GAME_STRATEGY_V2.md §28 Phase 1 is one map), so nothing
## calls this today. Left in place — same as WaveGenerator since step 4 — for the Endless
## mode that reconnects it.
func use_board_for_wave(wave: int) -> void:
	var chapter := floori(float(maxi(wave, 1) - 1) / float(WAVES_PER_BOARD))
	use_board(String(BOARD_SEQUENCE[mini(chapter, BOARD_SEQUENCE.size() - 1)]), false)

## Installs a named board profile. Towers and run economy deliberately survive the swap;
## only the painting, road and future placement checks change between chapters.
## `restrict_clearings` only matters for "winding": Tutorial calls this with the default
## true to keep its scarce painted pockets closed ground; every endless-run caller passes
## false so wave 1-10 plays that same painting with free placement like the other boards.
func use_board(board_id: String, restrict_clearings: bool = true) -> void:
	if active_board_id == board_id:
		return
	match board_id:
		"winding":
			configure_board(_smooth_path(WINDING_PATH, 4), [],
					WINDING_BUILD_ZONES if restrict_clearings else [], board_id)
		"spiral":
			configure_board(_smooth_path(PATH, 2), OBSTACLES, [], board_id)
		"s":
			configure_board(_smooth_path(S_PATH, 4), S_OBSTACLES, [], board_id)
		_:
			push_error("Game.use_board: unknown board '%s'" % board_id)

## Installs one board's gameplay geometry. The painting itself belongs to that scene's Map
## node; this is only the geometry every gameplay system must agree on.
func configure_board(path: Array, obstacles: Array = [], build_zones: Array = [],
		board_id: String = "custom") -> void:
	if path.size() < 2:
		push_error("Game.configure_board needs at least two path points")
		return
	active_path = path.duplicate(true)
	active_obstacles = obstacles.duplicate(true)
	active_build_zones = build_zones.duplicate(true)
	_path_cum = PackedFloat32Array()
	_path_cum.resize(active_path.size())
	for i in range(1, active_path.size()):
		_path_cum[i] = _path_cum[i - 1] \
				+ (active_path[i] as Vector2).distance_to(active_path[i - 1])
	active_board_id = board_id
	board_changed.emit(active_board_id)

## Samples a smooth centre-line through a traced control polyline. Four subdivisions keep
## adjacent waypoints close enough that Enemy's linear movement looks curved, without
## bloating targeting/path-progress work on every frame.
func _smooth_path(control: Array, subdivisions: int) -> Array:
	if control.size() < 3 or subdivisions <= 1:
		return control.duplicate(true)
	var out: Array = []
	for i in range(control.size() - 1):
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, control.size() - 1)]
		for step in subdivisions:
			var t := float(step) / float(subdivisions)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(control[control.size() - 1])
	return out

## How far along the road a walker is, in pixels — higher means closer to the exit.
## `target_index` is the waypoint it is currently heading for, `pos` where it is now.
## Since enemies walk each leg in a straight line, the distance back to the previous
## waypoint is exactly how far into that leg they are.
func path_progress(target_index: int, pos: Vector2) -> float:
	var i: int = clampi(target_index, 1, active_path.size() - 1)
	return _path_cum[i - 1] + pos.distance_to(active_path[i - 1])

## Shortest distance from `p` to the road centre-line. Shared because two very
## different things need it: the build grid rejects cells that would sit on the
## stone, and the map scatters its flora only where the road is not.
func dist_to_road(p: Vector2) -> float:
	var best := INF
	for i in range(active_path.size() - 1):
		best = minf(best, _dist_point_segment(p, active_path[i], active_path[i + 1]))
	return best

func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func reset() -> void:
	# The Workshop's Treasury / Ramparts levels land here rather than in Balance: they are
	# permanent progression, not a tuning constant, and this is the one place a run begins.
	# `ruleset` (Easy/Normal, BUILD NEXT #8) is picked before this runs — see the menu — and
	# left as-is by a mid-run reset() so a retry keeps the difficulty the player chose.
	gold = Balance.ruleset_start_gold(ruleset) + Meta.bonus_start_gold()
	lives = Balance.ruleset_start_lives(ruleset) + Meta.bonus_start_lives()
	is_over = false
	is_won = false
	wave_reached = 0
	last_leak_wave = 0
	last_leak_label = ""
	last_leak_element = ""

## Asks the level for a short camera kick (boss deaths, leaks).
func request_shake(amount: float) -> void:
	shake_requested.emit(amount)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## Lives given back by a Life tower's kills. Separate from lose_life so the game-over check
## lives in one place and can never be reached by a path that only ever adds.
func add_life(amount: int = 1) -> void:
	if amount <= 0 or is_over:
		return
	lives += amount
	lives_changed.emit(lives)

func lose_life(amount: int = 1) -> void:
	lives = max(0, lives - amount)
	lives_changed.emit(lives)
	if lives == 0 and not is_over:
		is_over = true
		game_over.emit()
