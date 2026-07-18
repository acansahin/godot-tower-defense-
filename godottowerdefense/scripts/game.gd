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

# Grass tiles beside the road where a tower can be built.
# Each spot is chosen to sit within firing range of at least one road segment.
const TOWER_SPOTS: Array = [
	Vector2(400, 235),
	Vector2(690, 235),
	Vector2(850, 250),
	Vector2(450, 460),
	Vector2(700, 460),
	Vector2(950, 460),
	Vector2(1120, 470),
	Vector2(350, 470),
]

const START_GOLD := 150
const START_LIVES := 20
const ARCHER_COST := 40
const CANNON_COST := 90

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
