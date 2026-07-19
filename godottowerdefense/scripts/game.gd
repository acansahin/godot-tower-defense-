extends Node
## Global game state + shared constants.
## Registered as the "Game" autoload (see project.godot), so every script can
## read the shared map layout and the current gold/lives without passing
## references around.

signal gold_changed(amount: int)
signal lives_changed(amount: int)
signal game_over
signal victory

const SCREEN_SIZE := Vector2(1280, 720)

# Waypoints that define the S-shaped road. Enemies walk these in order.
# First point is off-screen left (spawn), last is off-screen right (exit).
const PATH: Array = [
	Vector2(-80, 140),
	Vector2(950, 140),
	Vector2(950, 360),
	Vector2(250, 360),
	Vector2(250, 560),
	Vector2(1360, 560),
]

# Grid placement: towers snap to cells drawn faintly on the grass, flush against
# the road. Columns share a fixed width; rows are sized per gap so that two rows
# exactly fill the space between two horizontal roads.
const CELL_WIDTH := 64.0         ## Column width (px); columns step by this.
const ROAD_CLEARANCE := 64.0     ## Min distance from a cell centre to the road centre-line (flush allowed).

# Build-grid rows as Vector2(centre_y, cell_height). The three horizontal roads
# sit at y = 140 / 360 / 560 (stone half-width 32). Two rows fill each gap flush
# to both roads, plus a strip flush against the outside of the top/bottom roads.
#   band A (140..360): grass 172..328 (156 tall) -> two 78-tall rows
#   band B (360..560): grass 392..528 (136 tall) -> two 68-tall rows
const GRID_ROWS: Array = [
	Vector2(69.0, 78.0),                          # above the top road
	Vector2(211.0, 78.0), Vector2(289.0, 78.0),   # between top & middle roads
	Vector2(426.0, 68.0), Vector2(494.0, 68.0),   # between middle & bottom roads
	Vector2(626.0, 68.0),                         # below the bottom road
]
const GRID_COL_START := 64.0     ## First column centre.
const GRID_COL_END := 1216.0     ## Last column centre (columns step by CELL_WIDTH).

const START_GOLD := 150
const START_LIVES := 20

# --- Element tower definitions -------------------------------------------------
# Every tower (base element or dual combination) is just a data entry. Fields:
#   name, cost, color, damage, range, interval, can_hit_flying,
#   splash_radius/splash_factor (AoE), slow_factor/slow_time (0..1 = slower),
#   poison_dps/poison_time (damage over time),
#   stun_chance/stun_time (chance to freeze the enemy in place). Missing = "off".
const TOWER_DEFS := {
	"fire": {
		"name": "Fire", "cost": 40, "color": Color(0.95, 0.45, 0.18),
		"damage": 12.0, "range": 175.0, "interval": 0.45,
	},
	"water": {
		"name": "Water", "cost": 45, "color": Color(0.30, 0.60, 0.95),
		"damage": 6.0, "range": 165.0, "interval": 0.6,
		"slow_factor": 0.55, "slow_time": 1.4,
	},
	"nature": {
		"name": "Nature", "cost": 40, "color": Color(0.35, 0.80, 0.35),
		"damage": 4.0, "range": 165.0, "interval": 0.65,
		"poison_dps": 10.0, "poison_time": 3.0,
	},
	"earth": {
		"name": "Earth", "cost": 70, "color": Color(0.72, 0.55, 0.34),
		"damage": 30.0, "range": 150.0, "interval": 1.5, "can_hit_flying": false,
		"splash_radius": 72.0, "splash_factor": 0.5,
	},
	# --- Dual combinations (directly buildable for now) ---
	"steam": {  # Fire + Water
		"name": "Steam", "cost": 110, "color": Color(0.70, 0.82, 0.95),
		"damage": 16.0, "range": 180.0, "interval": 0.5,
		"slow_factor": 0.6, "slow_time": 1.2,
	},
	"lava": {  # Fire + Earth
		"name": "Lava", "cost": 150, "color": Color(0.92, 0.35, 0.20),
		"damage": 40.0, "range": 160.0, "interval": 1.3, "can_hit_flying": false,
		"splash_radius": 88.0, "splash_factor": 0.6,
		"poison_dps": 8.0, "poison_time": 2.5,  # burn
	},
	"ice": {  # Water + Nature
		"name": "Ice", "cost": 120, "color": Color(0.60, 0.90, 0.98),
		"damage": 10.0, "range": 175.0, "interval": 0.7,
		"slow_factor": 0.4, "slow_time": 2.0,
		"poison_dps": 6.0, "poison_time": 3.0,
	},
	"lightning": {  # chance to stun (freeze in place)
		"name": "Lightning", "cost": 70, "color": Color(1.0, 0.9, 0.25),
		"damage": 14.0, "range": 185.0, "interval": 0.7,
		"stun_chance": 0.25, "stun_time": 1.2,
	},
}
## Order the palette lists towers in.
const TOWER_ORDER: Array = ["fire", "water", "nature", "earth", "lightning", "steam", "lava", "ice"]

var gold: int = 0
var lives: int = 0
var is_over: bool = false

func reset() -> void:
	gold = START_GOLD
	lives = START_LIVES
	is_over = false

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
