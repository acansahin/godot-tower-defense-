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
## The run ended in a win — the player cleared Balance.STANDARD_WAVES. Fired by
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

## How flat a circle lying on the GROUND is drawn: a circle at camera elevation e appears
## sin(e) times as tall as it is wide, so every shadow, pad, aura ring and impact ring is
## drawn `draw_set_transform(at, 0.0, Vector2(1.0, GROUND_SQUASH))`.
##
## ONE number, because there is one ground. Before this constant the seven ground decals
## carried four values - 0.32, 0.34, 0.40 and 0.45 across tower.gd, enemy.gd and grid.gd -
## which is four cameras agreeing about nothing, and `grid.gd`'s comment claiming its 0.45
## matched "the towers' contact shadows" had already gone stale against their 0.40. A site
## that wants to differ writes it as a MULTIPLE of this and says why.
##
## WHAT IS NOT ON THE GROUND STAYS OUT OF IT. Fire's brazier glow and the WATER_POOL /
## NATURE_RUNE / fusion rings in `tower.gd` are circles on top of a TOWER, hand-measured off
## the painted sheets; they follow the art's own plane and must not be dragged onto this
## one. Projectile rings are in the air. Only shadows, pads and light pooled on the board
## itself belong here.
##
## It is a property of the BOARD ART, not a taste: run `python tools/art_match.py`, which
## reads it off the road (a ribbon of constant width is drawn narrower where it runs east-
## west than where it runs north-south, and the ratio is this number). The winding board
## measures 1.000 - straight overhead - against tower sheets painted at 0.24-0.30, and that
## disagreement is most of why the towers read as stickers on it.
##
## Held at 0.45 rather than at either end on purpose: it is what pads and the fallback
## shadow already used, so collapsing the four costs the least visible change, and 0.45 is
## one edit from the 0.50 docs/board-art-prompt.md asks a replacement board to be painted
## at. When that board lands, move this to whatever art_match.py measures on it - this holds
## what the ENGINE draws at, the prompt holds what the BOARD is generated to, and the two
## are meant to end up equal.
const GROUND_SQUASH := 0.45

## Multiplied over every painted tower and creep as they are drawn. WHITE means "the art
## ships as painted", which is the honest state whenever the board and the roster were made
## for each other.
##
## It exists as a named knob because they were not: the six element sets were generated
## against board_source.png (open ground luminance 106) and the game is played on the
## winding board (73), so the roster is lit for a board 45% brighter than the one it stands
## on. Grading here is the CHEAP half of that fix and the wrong half to lean on - a multiply
## can darken stone but cannot put back a hue the board does not contain, and it dims the
## flame and crystal the sets are built around along with the masonry. The real fix is the
## board, and this is the dial to reach for while one is being painted, or to trim a set
## that lands slightly hot.
const ART_TINT := Color.WHITE

## How TALL a painted tower is drawn, in board px. Whether a row of towers reads as separate
## buildings or as one mass depends on the drawn WIDTH against TOWER_GAP, so those two move
## together and neither means much alone.
##
## It lives in Game rather than in `tower.gd` (which reads it) because THE PLACEMENT RULE HAS
## TO SEE IT. While the art was small the two could be strangers: a 60px sprite over a 30px
## footprint stuck out a little and nobody noticed. A pass that took it to 160 broke that in
## two ways a player sees at once - towers near the top of the board lost their upper half
## behind the HUD, and towers beside the road stood on it. Both were one bug: can_build_at
## reserved TOWER_RADIUS of room for something drawn five times that. ROAD_KEEPOUT and the
## top bound now derive from this number, so the rule follows the art at any size.
const TOWER_SPRITE_HEIGHT := 96.0
## Half the width of the painted FOOTING as a fraction of the drawn height. Measured across
## the 75 reachable sprites: the footing spans a median 0.75 of a sprite's width and the
## widest 0.96, which against height comes out at ~0.45 for the median set. This is what has
## to clear the kerb — not the drawn width (the tower flares above its base) and not
## TOWER_RADIUS (a tap target sized for a thumb).
const TOWER_BASE_HALF := 0.45
## How near a tap has to land to mean a tower. Bigger than TOWER_RADIUS, and that is a
## DELIBERATE SPLIT of the one-disc rule above: placement, the build test and the drag ghost
## still use TOWER_RADIUS, but hit-testing does not. The painted body is drawn much wider
## than the footprint - at TOWER_SPRITE_HEIGHT 96 the widest set covers 147px against a 60px
## build disc - so a tap disc sized to the footprint leaves most of a tower dead to the
## touch, which on a phone reads as the tower simply not responding. It tracks the art: the
## 30px that suited a 60px sprite, scaled by the same 1.6.
##
## `main.gd` `_tower_at()` keeps the NEAREST tower rather than the first in range, so discs
## that overlap are harmless. What it must not do is exceed TOWER_GAP (68), which would let a
## tap on empty grass select a tower standing further away than the nearest legal spot.
const PICK_RADIUS := 48.0
## Min distance from a tower's centre to the road centre-line: half the road, plus the half
## width of the painted FOOTING, so a tower never stands on the stone.
##
## It used to be a fraction of TOWER_RADIUS, which was fine while the sprite was about the
## size of the footprint and wrong the moment it was not — at a 160px sprite the rule kept
## 15px clear for a base 72px wide, and towers sat squarely on the road. Deriving it from the
## drawn size means the rule follows the art at whatever size the art is next set to.
const ROAD_KEEPOUT := ROAD_HALF + TOWER_SPRITE_HEIGHT * TOWER_BASE_HALF
## Centre-to-centre spacing, sized against what is DRAWN rather than against TOWER_RADIUS —
## the same correction ROAD_KEEPOUT above already carries, and for the same reason.
##
## It was `TOWER_RADIUS * 2 + 8` = 68px: two 30px footprints plus a little air. That is the
## right answer for the tap disc and the wrong one for the art. A painted tower is drawn
## TOWER_SPRITE_HEIGHT tall and runs 108-147px WIDE across the roster, so at 68px apart a
## row of them buries itself — neighbours overlap by a third of their width and read as one
## mass instead of as countable buildings.
##
## **The defect was invisible while a pad lattice existed**, because the pads were pitched at
## 112px and nothing could ever be dropped at 68 regardless of what this constant allowed.
## Removing the lattice made the rule the only thing standing between two towers and exposed
## it immediately. Worth remembering: a guide that constrains the player more tightly than
## the rule does will hide a wrong rule for as long as it lasts.
##
## 112 is measured, not derived — it is the pitch the pads used, chosen against the 96px
## sprite and confirmed by eye at board scale. It is a PAIR with TOWER_SPRITE_HEIGHT: move
## the drawn size and this moves with it, or the row goes back to being a blob. Re-measure
## with `--dump-board` and look at a `--fill-board --shot`, which is what shows the overlap.
const TOWER_GAP := 112.0

# --- Build pads ----------------------------------------------------------------
#
# Free placement answered "may a tower stand here" continuously and correctly, and the board
# it produced looked accidental: every tower at whatever angle the cursor happened to be, no
# two rows agreeing. The pads keep exactly that terrain rule and put it on a MARKED lattice,
# so a built-up board reads as a plan instead of a scatter. Nothing about what is legal
# ground changes — can_build_at() is still the only judge, and the pads are the subset of it
# the player is offered.
#
# The lattice is HEXAGONAL rather than square, and that is measured rather than a taste:
# on the winding board a square lattice at this pitch marks 38 spots and the staggered one
# 47, because the open meadows are small and roundish and a hex pack fits more of them into
# the same grass. Rows still line up, which is the part the player sees.


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

## Fraction of TOWER_RADIUS the footprint test reaches out to. A tower is drawn much taller
## than it is wide and its base is smaller than the 30px click disc, so testing the full
## radius would refuse a spot whose visible ground is perfectly clear. This asks "is the
## base on grass", not "is the whole click target".
##
## On the winding board the setting is worth roughly a third of the board's capacity, so it
## is measured rather than picked: 0.35 gives 29 buildable spots, 0.20 gives 37, and with
## the smaller ROAD_KEEPOUT above the pair measures 51. The floor is the ring of eight
## probes still being wider than the painted base — at 0 the test is centre-only, which is
## what let a tower sit on the last grass texel with three quarters of itself in a tree.
const FOOTPRINT_PROBE := 0.20

## True when the ground under a tower's base is open on every side, not just at its centre.
## A centre-only test lets a tower sit on the last grass texel with three quarters of its
## base buried in a tree, which reads as a bug whichever way the player looks at it.
##
## Eight points around the base plus the centre. Nine samples of a 209x117 image is nothing,
## and the alternative — a distance transform baked into the mask — would move the same
## decision somewhere the player cannot see it.
func _footprint_is_open(pos: Vector2) -> bool:
	if active_build_mask == null:
		return true
	if not is_open_ground(pos):
		return false
	var reach := TOWER_RADIUS * FOOTPRINT_PROBE
	for i in 8:
		var a := TAU * float(i) / 8.0
		if not is_open_ground(pos + Vector2(cos(a), sin(a)) * reach):
			return false
	return true

## True when a tower of TOWER_RADIUS may stand here. `others` is every tower already on the
## board (main passes its Towers node's children); pass an empty array to ask only about
## the terrain, which is what the coverage harness does.
func can_build_at(pos: Vector2, others: Array = []) -> bool:
	if pos.x - TOWER_RADIUS < 0.0 or pos.x + TOWER_RADIUS > PLAY_RIGHT:
		return false
	# Upward, the sprite is what has to fit, not the footprint: a tower is hung from its
	# ground anchor and drawn TOWER_SPRITE_HEIGHT above it, so reserving TOWER_RADIUS here is
	# what let a tower near the top of the board lose its upper half behind the HUD.
	if pos.y - TOWER_SPRITE_HEIGHT < PLAY_TOP or pos.y + TOWER_RADIUS > WORLD_SIZE.y:
		return false
	if dist_to_road(pos) < ROAD_KEEPOUT:
		return false
	for entry in active_obstacles:
		if pos.distance_to(entry[0]) < float(entry[1]) + TOWER_RADIUS:
			return false
	# A board may expose only a few painted clearings via active_build_zones instead of the
	# derived mask. No board currently sets this — it stands ready for one that wants to
	# name its own legal spots rather than let the terrain mask decide.
	#
	# An explicit allowlist WINS OUTRIGHT over the derived mask rather than intersecting with
	# it: the two would answer different questions ("where does this board want a tower"
	# versus "where is the ground actually clear"), and intersecting them would silently move
	# whatever spots the allowlist named.
	if not active_build_zones.is_empty():
		var inside_zone := false
		for entry in active_build_zones:
			if pos.distance_to(entry[0]) <= float(entry[1]) - TOWER_RADIUS:
				inside_zone = true
				break
		if not inside_zone:
			return false
	elif not _footprint_is_open(pos):
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
## These four entries describe an UNFUSED tower. The moment a tower absorbs a second element
## it stops reading this table entirely and reads Game.FUSIONS instead — see Tower._recompute,
## which picks the definition from the tower's element set rather than layering one over the
## other.
const TOWER_DEFS := {
	"fire": {
		"name": "Fire", "cost": 50, "color": Color(0.95, 0.45, 0.18), "element": "fire",
		"damage_tiers": [10, 18, 32, 56, 100],
		"range": 485.7, "interval": 0.40,      # range: 170px = 485.7 * 0.35
		# Burn: 4 dps over 2s, on every hit. Lava (Fire+Earth) inherits this channel and
		# deepens it; see FUSIONS.
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
		# Base THORN identity, and every fusion carrying Nature inherits it
		# (GAME_STRATEGY_V2.md §3.1): poison
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
## for the Phase 4 return GAME_STRATEGY_V2.md §28 describes.
##
## This is the BUILDABLE roster and it is the whole of it: cross-element towers are never
## bought from the palette, they are grown out of a tower already standing on the board by
## absorbing elements an avatar boss unlocked — see FUSIONS below. So the six duals, four
## triples and Pure are real towers with real map-ported identities, and none of them adds a
## palette slot.
## Ordered around the damage circle (see ELEMENT_BEATS) rather than alphabetically, so the
## palette itself teaches which element answers which.
const TOWER_ORDER: Array = ["water", "fire", "nature", "earth"]

# --- Fusion towers: the combination ladder --------------------------------------
# Replaces the Lv3 a/b branch system. A tower does not pick a flavour of itself any more;
# it ABSORBS other elements and becomes a different tower. The set of elements it carries
# is its whole identity:
#
#   1 element  -> TOWER_DEFS      the four base towers
#   2 elements -> FUSIONS         six duals   (all six exist in the source map)
#   3 elements -> FUSIONS         four triples (all four exist in the source map)
#   4 elements -> FUSIONS         Pure — the one entry the map does NOT have
#
# ORDER DOES NOT MATTER, exactly as in the map: Fire absorbing Water and Water absorbing
# Fire both produce Steam. The key is therefore the element names SORTED and joined with
# "+" (see fusion_key), which is why every key below reads alphabetically rather than in
# the palette's ring order.
#
# WHERE THE DATA COMES FROM. The recipes, the tower names, the tier names and the ability
# text are all READ from ELEMENT TD.w3x, not invented — `python tools/extract_w3x.py
# "<map>" recipes` prints them, and docs/element-td-data.md §2/§3 writes them up. Our four
# elements happen to close the table exactly: of the map's 15 duals and 20 triples, exactly
# 6 and 4 avoid Light and Darkness, and those are all ten rows below. Nothing was dropped
# and nothing was made up to fill a gap.
#
# WHERE THE NUMBERS DO NOT. The map's own damage/cooldown values cannot be used directly:
# GAME_STRATEGY_V2.md §4.3 already replaced the four base elements' stats with its own
# design values, and the map's cost curve (50 -> 175 -> 788 -> 3544) is some sixty times
# steeper than ours. So the map supplies IDENTITY and RELATIVE ORDER — Clay hits hardest of
# the duals, Roots barely damages at all, Infernal tops the triples — and each row's Lv1 DPS
# is then set on our scale, where a base tower's Lv1 is ~25 DPS. Each row's comment records
# the map value it was derived from so the derivation stays auditable.
#
# `interval` is the map's own cooldown wherever the object data actually carries one (Clay
# 1.05, Infernal 1.20, Rainbow 1.10, Flesh Golem 0.90); the rest inherit from a Warcraft III
# base unit and simply are not in the map, so those are the mean of the parents' intervals.
# `range` is likewise the mean of the parent elements' reach, in the WC3-unit field every
# other range read site expects (px / Balance.WC3_RANGE_SCALE = 0.35).
#
# `damage_tiers` follows the same 1.0/1.8/3.2/5.6/10.0 growth every tower in the game climbs
# (§4.2). A fusion no longer WALKS that ladder, though: its level is fixed by its depth
# (Balance.FUSED_LEVELS), so a dual only ever reads tiers[2], a triple tiers[3] and Pure
# tiers[4]. The unread entries stay because they are the map's own numbers and because the
# ratio between them is what sets each row's relative strength — but the ONE value each row
# actually fires at is the one to re-balance. `--dump-ladder` prints exactly that column.
#
# `names` is the map's own tier ladder for that combination. It is DEAD DATA today for the
# same reason: with the level fixed there is no second or third tier to climb into, so a
# fused tower shows `name` and nothing else (Game.fusion_display_name). Kept as source.
const FUSIONS := {
	# --- Duals (2 elements) --------------------------------------------------------
	## map: Clay Tower, 600 dmg @ 1.05s (the cooldown IS in the object data here).
	## "Throws clumps of clay at enemies, with a chance to slow." The chance is what
	## slow_chance exists for — every other slow in the game lands on every hit.
	##
	## DELIBERATE DEPARTURE from the map, which names this ladder Clay -> Golem -> Living
	## Statue. The painted set is a worked CLAY PIT, not a figure: the roster already has
	## Flesh Golem sitting on a plinth, and two golems is one too many. Since a fusion's
	## shape now comes from its NAME (docs/tower-art-prompt.md), keeping the map's names
	## would have put the word "Golem" over a pit of mud. The recipe, the stats and the
	## ability are still the map's; only these three words are ours.
	"earth+water": {
		"name": "Clay", "names": ["Clay", "Clay Pit", "Great Mire"],
		"color": Color(0.80, 0.62, 0.45),
		"damage_tiers": [47, 85, 150, 263, 470],
		"range": 585.714, "interval": 1.05,        # 205px = mean(water 210, earth 200)
		"slow_chance": 0.35, "slow_factor": 0.65, "slow_time": 1.5,
		"desc": "Chance to slow. The hardest-hitting dual",
	},
	## map: Lava Tower, 751 dmg, siege + msplash, "Siege with added incinerate damage."
	## The tooltip says ATTACKS LAND AND AIR — so fusing Earth into Lava lifts Earth's
	## ground-only restriction. That reward is the map's, not ours.
	"earth+fire": {
		"name": "Lava", "names": ["Lava", "Magma", "Volcano"],
		"color": Color(0.92, 0.35, 0.20),
		"damage_tiers": [59, 106, 189, 330, 590],
		"range": 528.571, "interval": 1.4,         # 185px = mean(fire 170, earth 200)
		"splash_radius": 110.0, "splash_factor": 0.55,
		"burn_dps": 14.0, "burn_time": 3.0,        # incinerate
		"can_hit_flying": true,
		"desc": "Splash plus burn — and it can hit flyers",
	},
	## map: Sun Tower, 600 dmg. "Medium damage tower, also give a bonus to the damage of
	## nearby Tidal Towers." Tidal is a Light+Dark+Water triple we will never have, so the
	## aura is generalised to every neighbouring tower — the same adaptation the six-element
	## build made for Moon/Sun, kept because a buff nobody can receive is not a tower.
	"fire+nature": {
		"name": "Sun", "names": ["Sun", "Solar", "Temple of Sol"],
		"color": Color(1.0, 0.78, 0.30),
		"damage_tiers": [49, 88, 157, 274, 490],
		"range": 557.143, "interval": 1.3,         # 195px = mean(fire 170, nature 220)
		"aura_stat": "damage", "aura_radius": 170.0, "aura_mult": 1.15,
		"desc": "+15% damage to every tower within 170px",
	},
	## map: Steam Tower, 150 dmg, msplash. "Blasts all nearby units with steam that
	## gradually reduces health" — an area hit (splash) plus a damage-over-time (poison).
	"fire+water": {
		"name": "Steam", "names": ["Steam", "Vapor", "Immolation"],
		"color": Color(0.70, 0.82, 0.95),
		"damage_tiers": [13, 23, 42, 73, 130],
		"range": 542.857, "interval": 0.4,         # 190px = mean(fire 170, water 210)
		"splash_radius": 80.0, "splash_factor": 0.5,
		"poison_dps": 16.0, "poison_time": 2.5,
		"desc": "Fast area steam that keeps eating health",
	},
	## map: Well Tower, 350 dmg. "Supporting tower that has the Spring Forward ability
	## which adds speed to nearby towers." Reuses the same aura machinery as Sun.
	"nature+water": {
		"name": "Well", "names": ["Well", "Spring", "Waterfall"],
		"color": Color(0.45, 0.85, 0.80),
		"damage_tiers": [30, 54, 96, 168, 300],
		"range": 614.286, "interval": 1.0,         # 215px = mean(water 210, nature 220)
		"aura_stat": "attack_speed", "aura_radius": 170.0, "aura_mult": 1.15,
		"desc": "+15% attack speed to every tower within 170px",
	},
	## map: Roots Tower, 100 dmg @ 8.10s, magic, "casts Entangling Roots on ground enemies.
	## Attacks land units." An 8.1s cooldown is unplayable at our pace, so the earlier port's
	## 2.2 is kept — the LOW DAMAGE / HIGH CONTROL identity is what carries over, not the
	## number. Entangle is a root, and a root is our stun payload.
	"earth+nature": {
		"name": "Roots", "names": ["Roots", "Brambles", "Entangling"],
		"color": Color(0.45, 0.60, 0.28),
		"damage_tiers": [18, 32, 58, 101, 180],
		"range": 600.0, "interval": 2.2,           # 210px = mean(nature 220, earth 200)
		"stun_chance": 0.5, "stun_time": 1.2,
		"can_hit_flying": false,
		"desc": "Roots ground enemies in place. Barely damages",
	},

	# --- Triples (3 elements) ------------------------------------------------------
	## map: Infernal Tower, 3750 dmg @ 1.20s, attack_type=CHAOS. "Strong tower with high
	## chaos-type damage." Chaos in Warcraft III is 100% against every armour type — which
	## is exactly what ignores_matchup does here. The hardest hitter of the four triples.
	"earth+fire+water": {
		"name": "Infernal", "names": ["Infernal", "Chaos"],
		"color": Color(0.85, 0.25, 0.35),
		"damage_tiers": [102, 184, 326, 571, 1020],
		"range": 552.381, "interval": 1.2,         # 193px = mean(fire, water, earth)
		"ignores_matchup": true, "can_hit_flying": true,
		"desc": "Chaos damage — no armour resists it",
	},
	## map: Rainbow Tower, 3250 dmg @ 1.10s, attack_type=CHAOS. "Chaos-damage multi-color
	## attacking tower. Very strong." Same rule as Infernal, faster and slightly softer.
	"fire+nature+water": {
		"name": "Rainbow", "names": ["Rainbow", "Spectrum"],
		"color": Color(0.85, 0.55, 0.95),
		"damage_tiers": [88, 158, 282, 493, 880],
		"range": 571.429, "interval": 1.1,         # 200px = mean(fire, water, nature)
		"ignores_matchup": true, "can_hit_flying": true,
		"desc": "Chaos damage, faster than Infernal",
	},
	## map: Dinosaur Tower, 2000 dmg. "Has the ability to devour enemies which stay in its
	## belly until they are gradually digested." Devour needs no new mechanism: a long stun
	## plus heavy poison IS "held still and digested". The visual (the creep drawn inside the
	## tower) is deliberately skipped — it would be a new node type for one row.
	"earth+fire+nature": {
		"name": "Dinosaur", "names": ["Dinosaur", "Fossil"],
		"color": Color(0.55, 0.70, 0.35),
		"damage_tiers": [104, 187, 333, 582, 1040],
		"range": 561.905, "interval": 1.6,         # 197px = mean(fire, nature, earth)
		"stun_chance": 0.25, "stun_time": 1.5,
		"poison_dps": 30.0, "poison_time": 4.0,
		"can_hit_flying": true,
		"desc": "Devours enemies: holds them still and digests",
	},
	## map: Flesh Golem Tower, 1350 dmg @ 0.90s, range 700 (one of the few explicit ones).
	## "-Moving Tower- Grows stronger with each unit it kills." The tower does not move here
	## (nothing in this game does), but the growth is the interesting half and it is real:
	## damage_per_kill accumulates for the rest of the tower's life.
	"earth+nature+water": {
		"name": "Flesh Golem", "names": ["Flesh Golem", "Living Flesh"],
		"color": Color(0.80, 0.45, 0.50),
		"damage_tiers": [54, 97, 173, 302, 540],
		"range": 600.0, "interval": 0.9,           # 210px = mean(water, nature, earth)
		"damage_per_kill": 0.5, "can_hit_flying": true,
		"desc": "+0.5 damage permanently for every kill it lands",
	},

	# --- Pure (4 elements) ---------------------------------------------------------
	## NOT A MAP TOWER. The map has six elements and its recipes stop at three, so a
	## four-element combination has no source entry. The NAME is borrowed from the map's own
	## fifth single-element tier ("Pure Fire", 24444 gold), which is the vocabulary it uses
	## for a tower at the end of its road.
	##
	## Its rule is the reason the whole ladder exists: holding all four elements means
	## element_mult_best always finds the element the target is weak to, so no armour ever
	## resists it, and pierces_rules lets its payload through Enemy.cc_immune (the wave-10
	## boss and the `immune` archetype) as well. Nothing in the game reduces a Pure tower.
	"earth+fire+nature+water": {
		"name": "Pure", "names": ["Pure"],
		"color": Color(1.0, 1.0, 0.95),
		## Trimmed by a fifth (was [91, 164, 291, 510, 910]) after play showed Pure flattening the
		## roster. Its DPS ran 5.1x the base elements against Dinosaur's 3.7 at the next tier —
		## 38% clear of everything else — and it is ALSO chaos (no armour resists) and pierces
		## (no immunity stops it) on the fastest interval of any fusion. Any one of those three
		## makes it the apex; all three together deleted the matchup game, and `--play-sim`
		## showed a board walking every tower to four elements. 4.0x still leads the roster.
		"damage_tiers": [71, 129, 228, 400, 714],
		"range": 571.429, "interval": 0.7,         # 200px = mean of all four
		"ignores_matchup": true, "pierces_rules": true, "can_hit_flying": true,
		"desc": "Pure damage. No armour, no immunity stops it",
	},
}

## The FUSIONS key for a set of elements: sorted, joined with "+". A tower's element list is
## built by appending, so it arrives in pick order — sorting here is what makes Fire+Water
## and Water+Fire the same tower, which is the map's own rule.
func fusion_key(elements: Array) -> String:
	var sorted_els: Array = elements.duplicate()
	sorted_els.sort()
	return "+".join(PackedStringArray(sorted_els))

## The combination definition for `elements`, or {} for a single element (or a set with no
## entry, which cannot happen with four elements but is not worth crashing over).
func fusion_def(elements: Array) -> Dictionary:
	if elements.size() < 2:
		return {}
	return FUSIONS.get(fusion_key(elements), {})

## The name a fused tower shows. This used to spread the map's per-tier `names` ladder across
## the five levels, which stopped meaning anything once a fusion's level became fixed by its
## depth (Balance.FUSED_LEVELS) — every dual would have sat on names[1] forever and names[0],
## the name players actually know the tower by, would never have been seen.
##
## So it is the row's own `name`, which is also the string Tower.art_key() looks the painted
## set up under: the label and the picture are now the same string and cannot drift apart.
func fusion_display_name(def: Dictionary) -> String:
	return String(def.get("name", "?"))

# --- Wave definitions ----------------------------------------------------------
# Each wave picks an archetype from WAVE_TYPES; its stats = the base scaling
# (quadratic HP etc. in wave_manager) times the archetype's multipliers. Fields
# (all optional, default 1.0 / false / 0):
#   name, color, hp, spd, count, radius, cc_immune, regen (frac of max hp/s),
#   split (children on death), air (all flyers).
const WAVE_TYPES := {
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
## This table starts with a gentle REAL wave, then introduces one idea at a time: speed,
## numbers, the element matchup, flyers, CC immunity, regeneration, splitting — and the
## first boss on 10, which is the cadence the generator keeps forever after.
##
## "element" (optional) is the wave's armor element (empty/absent = neutral); early waves
## and all Air waves stay neutral so element colour doesn't clash with the archetype tint.
## "art" / "name" may override only the painted creature and preview label while keeping
## the `type` archetype's combat stats — wave 1 uses the Scout art this way.
##
## NO BOSS LIVES IN THIS TABLE ANY MORE. Every boss wave — the four element avatars and the
## two set pieces — is applied by apply_milestone() below, keyed by wave number, on top of
## whatever supplied the wave. The table used to carry `boss_rule` rows that had to be kept in
## step with Balance.ELEMENT_BOSS_WAVES by hand; one list now decides, so they cannot disagree.
##
## This table therefore authors the CREEP progression only, and its rows for waves that a
## milestone overrides are what those waves revert to if the milestone list ever moves.
const WAVES: Array = [
	{"type": "normal", "art": "tutorial", "name": "Scout", "count": 0.65}, # 1
	{"type": "normal"},                                # 2  — a real wave, still gentle
	{"type": "fast"},                                  # 3  — speed
	{"type": "swarm"},                                 # 4  — numbers
	{"type": "normal", "element": "fire"},             # 5  — first armour element
	{"type": "air"},                                   # 6  — flyers: ground-only towers miss
	{"type": "immune"},                                # 7  — CC off: slow and stun stop working
	{"type": "fast", "element": "earth"},              # 8
	{"type": "regen", "element": "water"},             # 9  — must out-damage the heal
	{"type": "tank", "element": "water"},              # 10 — OVERRIDDEN: AVATAR 1 walks alone
	{"type": "split"},                                 # 11 — splits on death
	{"type": "tank", "element": "earth"},              # 12
	{"type": "air"},                                   # 13
	{"type": "immune", "element": "water"},            # 14
	{"type": "fast", "element": "nature"},             # 15
	{"type": "regen", "element": "nature"},            # 16
	{"type": "split", "element": "earth"},             # 17
	{"type": "swarm", "element": "water"},             # 18
	{"type": "tank", "element": "fire", "hp": 0.85},   # 19
	{"type": "swarm", "element": "fire"},              # 20 — OVERRIDDEN: AVATAR 2 walks alone
]

## The two SET-PIECE bosses, keyed by wave. Unlike the avatars these keep their creep wave —
## the escort is part of what makes them a wall — so they carry no `count` override.
##
## They sat on 10 and 20 while the run was 20 waves long, which is exactly where the avatars
## now land. Rather than delete two bosses that each ask a question nothing else asks, they
## moved to the same PLACES in the longer run: Balance.MIDPOINT_BOSS_WAVE and the final wave.
## Both follow the run length, so they stay the midpoint and the finale at any length.
##
## `boss_rule` (GAME_STRATEGY_V2.md §10.4, BUILD NEXT #7) is the ONE question each boss asks.
## Muhafız is immune to every control effect in the game (slow/stun/knockback — see
## Enemy.cc_immune) rather than to one named kind, so a future control type is covered
## automatically. Uyanmış Muhafız cycles its own armour every 5s (Enemy.rotating_armor) around
## Game.TOWER_ORDER's ring, starting at "fire" — it asks whether the run invested in one
## element or spread across all four, which the first boss never asks.
const MIDPOINT_BOSS := {
	"type": "tank", "boss": true, "element": "water", "boss_rule": "control_immune",
}
const FINAL_BOSS := {
	"type": "swarm", "boss": true, "element": "fire", "boss_rule": "rotating_armor",
}

## The definition for wave `n` once its milestone, if it has one, has been applied to `base`.
## Called by WaveManager for EVERY wave, whichever source produced `base` — the seed table or
## WaveGenerator — which is what lets a boss land on wave 40 without the generator knowing
## bosses exist.
##
## An avatar wave is built here rather than merged, and every field of it is deliberate:
##
## * `count` 0 is the whole point of the change — the avatar walks the road ALONE.
## * `type` is pinned to "normal" instead of inheriting the base row's archetype, because the
##   archetype's own `hp` multiplier would otherwise stack under ELEMENT_BOSS_HP_MULT: wave
##   10's row is a tank (3.0x), which would have made the first avatar three times the
##   fight the fourth one is. The four avatars must differ by ELEMENT, not by what the
##   underlying wave happened to be.
## * no `element`: theirs is this run's draw (Run.boss_element_for_wave), filled in by
##   wave_manager._start_wave, which is what makes the four arrive in a different order every
##   run. Beating one both unlocks that element for fusion AND lifts its own towers off
##   Balance.FREE_LEVEL_CAP (Run.beat_avatar) — these four kills are the only thing that
##   moves a tower past Lv2 by either road, see FUSIONS above.
func apply_milestone(n: int, base: Dictionary) -> Dictionary:
	if Balance.ELEMENT_BOSS_WAVES.has(n):
		return {"type": "normal", "boss": true, "boss_rule": "element_avatar", "count": 0.0}
	if n == Balance.MIDPOINT_BOSS_WAVE:
		return _merged(base, MIDPOINT_BOSS)
	if n == Balance.STANDARD_WAVES:
		return _merged(base, FINAL_BOSS)
	return base

func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out.merge(over, true)
	return out

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

## The matchup for a tower carrying a SET of elements: the best its set can manage against
## this armour. This one function is what makes the fusion ladder mean something beyond raw
## damage — the tower brings whichever of its elements the target is weakest to:
##
##   1 element  -> identical to element_mult, so an unfused tower is unchanged
##   2 elements -> covers two of the four armour elements at ELEMENT_STRONG
##   3 elements -> three
##   4 elements -> all four. Every armour element is beaten by exactly one of ours, so a Pure
##                 tower can never be resisted. That is the whole of "nothing reduces Pure
##                 damage" — no separate damage path, just a set that covers the ring.
##
## Called from projectile.gd's three matchup sites. A tower whose def sets `ignores_matchup`
## (the chaos-type triples) skips this entirely and uses a flat 1.0.
func element_mult_best(elements: Array, def: String) -> float:
	if def == "" or elements.is_empty():
		return 1.0
	var best := 0.0
	for e in elements:
		best = maxf(best, element_mult(String(e), def))
	return best

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

## The run's length moved to Balance.STANDARD_WAVES, where the HP ramp, the speed ramp and
## the boss waves are all derived from it — see the block above Balance.BASE_HP_FLAT. It is
## NOT Game.WAVES.size() and must not be confused with it: WAVES is the hand-authored
## TEACHING table and stops at 20, where every archetype has been introduced once, while
## waves 21 onward come from WaveGenerator. The two happened to share an answer only while
## the run was 20 waves long.

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

## Ends the run as a win: the player cleared Balance.STANDARD_WAVES. Reuses `is_over` for every
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
## The active board's open-ground mask: white where a tower may stand, black over trees,
## cliffs and water. Derived from the painting by `python tools/build_mask.py <board.png>`
## and sampled by can_build_at(); null for a board that has none, which keeps free placement.
##
## An Image rather than a Texture2D because this is read on the CPU. `get_image()` hands back
## whatever the importer produced, and on the Android export that is an ETC2-compressed
## image whose get_pixel() does not work — hence the decompress in _load_build_mask().
var active_build_mask: Image = null

## Board paintings that carry an open-ground mask beside them. A board absent from this table
## simply has no mask and keeps free placement, so adding one is dropping a `_build.png` next
## to the art and adding a line here.
const BUILD_MASKS := {
	"winding": "res://assets/art/maps/winding_forest_cleared_v7_graded_build.png",
}

## Cumulative distance from active_path[0] to each waypoint. Towers
## rank enemies by how far along the road they are (the First / Last targeting modes)
## off this table, so no enemy has to carry its own odometer.
var _path_cum: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	use_main_board()
	_load_locale()

# --- Language -----------------------------------------------------------------------
## The languages the CSV in assets/i18n has a column for, in the order the menu cycles them.
## Adding a third is a column in strings.csv, an entry here, a `LANG_<CODE>` key, and a path
## in project.godot's `internationalization/locale/translations` -- no other code change.
const LOCALES: Array = ["en", "tr"]
const LOCALE_SECTION := "settings"

## Emitted after the locale actually changed. Godot re-translates a Control's own `text` on
## its own, so most of the UI needs nothing -- this exists for the strings built in code with
## a format argument ("Gold: %d"), which are only rebuilt when their value next changes.
signal locale_changed(locale: String)

var locale: String = String(LOCALES[0])

## Reads the stored choice, falling back to the SYSTEM language when there is none: a Turkish
## phone should not have to find the button on its first launch. Anything we have no column
## for lands on English.
func _load_locale() -> void:
	# TEMPORARY harness: `-- --locale:en` forces a language for one run without touching the
	# save. The button is the only other way to switch, and no harness can click one, so
	# without this only whichever column the machine's own language selects is ever seen.
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--locale:"):
			set_locale(String(arg).split(":")[1], false)
			return
	var stored := String(Save.get_section(LOCALE_SECTION).get("locale", ""))
	if stored == "":
		stored = OS.get_locale_language()
	set_locale(stored if LOCALES.has(stored) else String(LOCALES[0]), false)

func set_locale(id: String, persist: bool = true) -> void:
	if not LOCALES.has(id):
		return
	locale = id
	TranslationServer.set_locale(id)
	if persist:
		var s := Save.get_section(LOCALE_SECTION)
		s["locale"] = locale
		Save.flush()
	locale_changed.emit(locale)

func cycle_locale() -> void:
	set_locale(String(LOCALES[(maxi(LOCALES.find(locale), 0) + 1) % LOCALES.size()]))

## "LANG_EN" / "LANG_TR" -- each language names itself in its own words in both columns, so
## the button reads "Turkce" to someone who cannot read the current language.
func locale_display_name() -> String:
	return tr("LANG_" + locale.to_upper())

## Restores the endless-run board. Called by Menu/Main so a scene reload always lands on the
## real run's profile rather than whatever a previous scene had installed.
func use_main_board() -> void:
	use_board("spiral")

## Selects the endless board for `wave`. The last available profile remains active after its
## chapter, so an unfinished map slot never sends a deep run back to an earlier layout.
##
## UNREACHED as of BUILD NEXT #8: Standard mode pins to main.gd's STANDARD_BOARD for its
## whole length instead of rotating (GAME_STRATEGY_V2.md §28 Phase 1 is one map), so nothing
## calls this today. Left in place — same as WaveGenerator since step 4 — for the Endless
## mode that reconnects it.
func use_board_for_wave(wave: int) -> void:
	var chapter := floori(float(maxi(wave, 1) - 1) / float(WAVES_PER_BOARD))
	use_board(String(BOARD_SEQUENCE[mini(chapter, BOARD_SEQUENCE.size() - 1)]))

## Installs a named board profile. Towers and run economy deliberately survive the swap;
## only the painting, road and future placement checks change between chapters.
func use_board(board_id: String) -> void:
	if active_board_id == board_id:
		return
	match board_id:
		"winding":
			configure_board(_smooth_path(WINDING_PATH, 4), [], [], board_id)
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
	active_build_mask = _load_build_mask(board_id)
	_path_cum = PackedFloat32Array()
	_path_cum.resize(active_path.size())
	for i in range(1, active_path.size()):
		_path_cum[i] = _path_cum[i - 1] \
				+ (active_path[i] as Vector2).distance_to(active_path[i - 1])
	active_board_id = board_id
	board_changed.emit(active_board_id)

## Loads `board_id`'s open-ground mask, or null if it has none. Called once per board swap,
## never per placement check.
func _load_build_mask(board_id: String) -> Image:
	var path := String(BUILD_MASKS.get(board_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("Game: build mask '%s' did not load as a texture" % path)
		return null
	var img := tex.get_image()
	if img == null:
		push_warning("Game: build mask '%s' has no image" % path)
		return null
	# The Android export compresses textures (project.godot's import_etc2_astc), and
	# get_pixel() on a compressed Image returns garbage rather than failing loudly — which
	# would show up as a board that is buildable everywhere on the phone and nowhere else.
	if img.is_compressed():
		img.decompress()
	return img

## True when the painting has open ground at `pos` — grass, not canopy, cliff or water.
## Always true for a board with no mask, so an unmasked board keeps free placement.
##
## The mask is far coarser than the board (one texel per 8px block), so this samples the
## texel containing `pos` rather than interpolating: the majority filter in build_mask.py
## already removed the single-block noise that interpolation would otherwise be smoothing.
func is_open_ground(pos: Vector2) -> bool:
	if active_build_mask == null:
		return true
	var w := active_build_mask.get_width()
	var h := active_build_mask.get_height()
	var x := clampi(int(pos.x / WORLD_SIZE.x * float(w)), 0, w - 1)
	var y := clampi(int(pos.y / WORLD_SIZE.y * float(h)), 0, h - 1)
	return active_build_mask.get_pixel(x, y).r > 0.5

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
