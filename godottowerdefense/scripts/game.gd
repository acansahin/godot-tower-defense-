extends Node
## Global game state + shared constants.
## Registered as the "Game" autoload (see project.godot), so every script can
## read the shared map layout and the current gold/lives without passing
## references around.

signal gold_changed(amount: int)
signal lives_changed(amount: int)
signal game_over
signal victory
## Camera kick in pixels. Broadcast here so an Enemy can ask for one without knowing
## anything about the level's camera; Main owns the actual Camera2D.
signal shake_requested(amount: float)

const SCREEN_SIZE := Vector2(1280, 720)

# Waypoints that define the S-shaped road. Enemies walk these in order.
# First point is off-screen left (spawn), last is off-screen right (exit).
#
# The two bend x's (840, 232) are not round numbers, and the exact values matter:
# each one is placed so that TWO columns of cells fit on the narrow outer side of
# the turn instead of one. Cells tile outward from a bend at ROAD_HALF +
# CELL_WIDTH*0.5 = 88 and then step by 96, and grid.gd drops any that would fall
# off the board, so the second column lands exactly on the boundary — 840 puts it
# at 1024, whose right edge is PLAY_RIGHT; 232 puts it at 48, whose left edge is 0.
# Move either bend 8px the wrong way and that outer column silently disappears.
const PATH: Array = [
	Vector2(-144, 112),
	Vector2(840, 112),
	Vector2(840, 368),
	Vector2(232, 368),
	Vector2(232, 624),
	Vector2(1424, 624),
]

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
## Right edge of the buildable area. The tower palette is anchored to the right of
## the screen, so the grid stops short of it — otherwise cells sit under the panel
## where they cannot be seen and (because the panel eats the click) the towers on
## them could never be upgraded or sold.
const PLAY_RIGHT := 1072.0

# Build-grid rows as Vector2(centre_y, cell_height). The three horizontal roads sit
# at y = 112 / 368 / 624, and the rows come in PAIRS filling the gap between them.
#
# The pairing is the whole point: a bend's vertical leg runs from one horizontal road
# to the next, so the number of rows it passes is the number of cells you get down the
# narrow outer side of that turn. One row per gap gave a 2x1 corner; two gives 2x2.
#
# The vertical budget is exact and leaves no room to be generous. Between the HUD bar
# (ends at 40) and the bottom-corner buttons (start at 664) there are 624px, and
# 4 rows x 88 + 3 roads x 80 = 592 uses all but 32 of it. That last 32 is grass above
# the top road, and it is load-bearing: without it a boss on the top road would draw
# its health bar up behind the HUD. Rows are 88 rather than 96 tall to pay for it —
# still ~44 CSS px on a phone, so the tap target survives.
const GRID_ROWS: Array = [
	Vector2(196.0, 88.0), Vector2(284.0, 88.0),  # between the top & middle roads
	Vector2(452.0, 88.0), Vector2(540.0, 88.0),  # between the middle & bottom roads
]
## Column bounds for a row NO vertical road crosses. Every row in the current layout is
## crossed by a bend and so tiles outward from it instead; these stay for a row placed
## clear of both bends.
const GRID_COL_START := 64.0     ## First column centre.
const GRID_COL_END := 1024.0     ## Last column centre (= PLAY_RIGHT - CELL_WIDTH * 0.5).

const START_GOLD := 150
const START_LIVES := 20

# --- Element tower definitions -------------------------------------------------
# Every tower (base element or dual combination) is just a data entry.
# All radii here are in pixels and scale with CELL_WIDTH: a range covers roughly
# 2.5 cells, which is what keeps the number of towers able to hit any given point
# of road (~10 when fully built) independent of how big the cells are. Change the
# cell size and these have to move with it or the difficulty shifts. Fields:
#   name, cost, color, damage, range, interval, can_hit_flying,
#   splash_radius/splash_factor (AoE), slow_factor/slow_time (0..1 = slower),
#   slow_splash (Lv2+ radius the slow ALSO spreads to — slow only, no damage),
#   poison_dps/poison_time (damage over time),
#   stun_chance/stun_time (chance to freeze the enemy in place). Missing = "off".
const TOWER_DEFS := {
	"fire": {
		"name": "Fire", "cost": 40, "color": Color(0.95, 0.45, 0.18), "element": "fire",
		"damage": 12.0, "range": 262.0, "interval": 0.45,
	},
	"water": {
		"name": "Water", "cost": 45, "color": Color(0.30, 0.60, 0.95), "element": "water",
		"damage": 6.0, "range": 248.0, "interval": 0.6,
		"slow_factor": 0.55, "slow_time": 1.4,
	},
	"nature": {
		"name": "Nature", "cost": 40, "color": Color(0.35, 0.80, 0.35), "element": "nature",
		"damage": 4.0, "range": 248.0, "interval": 0.65,
		"poison_dps": 10.0, "poison_time": 3.0,
	},
	"earth": {
		"name": "Earth", "cost": 70, "color": Color(0.72, 0.55, 0.34), "element": "earth",
		"damage": 30.0, "range": 225.0, "interval": 1.5, "can_hit_flying": false,
		"splash_radius": 108.0, "splash_factor": 0.5,
	},
	# --- Dual combinations (directly buildable for now) ---
	"steam": {  # Fire + Water
		"name": "Steam", "cost": 110, "color": Color(0.70, 0.82, 0.95),
		"damage": 16.0, "range": 270.0, "interval": 0.5,
		"slow_factor": 0.6, "slow_time": 1.2,
	},
	"lava": {  # Fire + Earth
		"name": "Lava", "cost": 150, "color": Color(0.92, 0.35, 0.20),
		"damage": 40.0, "range": 240.0, "interval": 1.3, "can_hit_flying": false,
		"splash_radius": 132.0, "splash_factor": 0.6,
		"poison_dps": 8.0, "poison_time": 2.5,  # burn
	},
	"ice": {  # Water + Nature
		"name": "Ice", "cost": 120, "color": Color(0.60, 0.90, 0.98),
		"damage": 10.0, "range": 262.0, "interval": 0.7,
		"slow_factor": 0.4, "slow_time": 2.0,
		"slow_splash": 135.0,  # from Lv2 the chill spreads to enemies within this radius of the target
		"poison_dps": 6.0, "poison_time": 3.0,
	},
	"lightning": {  # chance to stun (freeze in place)
		"name": "Lightning", "cost": 70, "color": Color(1.0, 0.9, 0.25),
		"damage": 14.0, "range": 278.0, "interval": 0.7,
		"stun_chance": 0.25, "stun_time": 1.2,
	},
}
## Order the palette lists towers in.
const TOWER_ORDER: Array = ["fire", "water", "nature", "earth", "lightning", "steam", "lava", "ice"]

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
	"air":    {"name": "Air",    "color": Color(0.72, 0.78, 0.96), "air": true},
	"split":  {"name": "Splitter","color": Color(0.85, 0.55, 0.25), "hp": 1.0, "count": 0.6, "split": 2, "radius": 1.15},
}

## 20 waves; boss on every 5th. Kept short — stats come from the scaling formula.
## "element" (optional) is the wave's armor element (empty/absent = neutral); the
## first waves and all Air waves stay neutral so element colour doesn't clash.
const WAVES: Array = [
	{"type": "normal"}, {"type": "fast"}, {"type": "swarm"},
	{"type": "normal", "element": "fire"},
	{"type": "tank", "boss": true, "element": "water"},
	{"type": "air"},
	{"type": "immune", "element": "nature"},
	{"type": "fast", "element": "earth"},
	{"type": "regen", "element": "water"},
	{"type": "swarm", "boss": true, "element": "fire"},
	{"type": "split", "element": "nature"},
	{"type": "tank", "element": "earth"},
	{"type": "air"},
	{"type": "immune", "element": "water"},
	{"type": "fast", "boss": true, "element": "fire"},
	{"type": "regen", "element": "nature"},
	{"type": "split", "element": "earth"},
	{"type": "swarm", "element": "water"},
	{"type": "tank", "element": "fire", "hp": 0.85},  # per-wave -15% HP (mild trim so it isn't a spike)
	{"type": "normal", "boss": true, "element": "nature", "hp": 1.3},  # per-wave +30% HP: the finale, the clear peak
]

# --- Element matchup -----------------------------------------------------------
# Simple 4-element cycle: each beats the next. A tower's damage element vs an
# enemy's armor element gives a multiplier (see element_mult). Neutral ("") on
# either side = x1, so Lightning / dual towers and early/air waves are unaffected.
const ELEMENT_BEATS := {"fire": "nature", "nature": "earth", "earth": "water", "water": "fire"}
const ELEMENT_COLORS := {
	"fire": Color(0.95, 0.45, 0.18), "water": Color(0.30, 0.60, 0.95),
	"nature": Color(0.35, 0.80, 0.35), "earth": Color(0.72, 0.55, 0.34),
}
const ELEMENT_STRONG := 1.75
## Mismatched element damage. Kept fairly gentle on purpose: at 0.6 a wave whose armour
## countered the player's main element (notably the water waves vs. the cheap, popular
## Fire tower) inflated its effective HP by 67%, which read as a difficulty spike rather
## than a prompt to diversify.
const ELEMENT_WEAK := 0.7

## Damage multiplier for attacker element `atk` hitting armour element `def`.
func element_mult(atk: String, def: String) -> float:
	if atk == "" or def == "":
		return 1.0
	if ELEMENT_BEATS.get(atk, "") == def:
		return ELEMENT_STRONG
	if ELEMENT_BEATS.get(def, "") == atk:
		return ELEMENT_WEAK
	return 1.0

var gold: int = 0
var lives: int = 0
var is_over: bool = false

## Cumulative distance from PATH[0] to each waypoint, built once in _ready(). Towers
## rank enemies by how far along the road they are (the First / Last targeting modes)
## off this table, so no enemy has to carry its own odometer.
var _path_cum: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_path_cum.resize(PATH.size())
	for i in range(1, PATH.size()):
		_path_cum[i] = _path_cum[i - 1] + (PATH[i] as Vector2).distance_to(PATH[i - 1])

## How far along the road a walker is, in pixels — higher means closer to the exit.
## `target_index` is the waypoint it is currently heading for, `pos` where it is now.
## Since enemies walk each leg in a straight line, the distance back to the previous
## waypoint is exactly how far into that leg they are.
func path_progress(target_index: int, pos: Vector2) -> float:
	var i: int = clampi(target_index, 1, PATH.size() - 1)
	return _path_cum[i - 1] + pos.distance_to(PATH[i - 1])

## Shortest distance from `p` to the road centre-line. Shared because two very
## different things need it: the build grid rejects cells that would sit on the
## stone, and the map scatters its flora only where the road is not.
func dist_to_road(p: Vector2) -> float:
	var best := INF
	for i in range(PATH.size() - 1):
		best = minf(best, _dist_point_segment(p, PATH[i], PATH[i + 1]))
	return best

func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func reset() -> void:
	gold = START_GOLD
	lives = START_LIVES
	is_over = false

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

func lose_life(amount: int = 1) -> void:
	lives = max(0, lives - amount)
	lives_changed.emit(lives)
	if lives == 0 and not is_over:
		is_over = true
		game_over.emit()

func trigger_victory() -> void:
	if not is_over:
		is_over = true
		victory.emit()
