extends Node2D
class_name Enemy
## Walks along Game.PATH, carries health, shows a health bar, gives gold on
## death and costs the player a life if it reaches the end.

signal removed  ## Emitted whenever the enemy leaves play (death OR escape).

var speed: float = 70.0
var max_health: float = 30.0
var health: float = 30.0
var reward: int = 5
var color: Color = Color(0.85, 0.3, 0.3)
var radius: float = 16.0

var _path: Array = []
var _target_index: int = 1
var _dead: bool = false

func setup(hp: float, spd: float, gold_reward: int, tint: Color) -> void:
	max_health = hp
	health = hp
	speed = spd
	reward = gold_reward
	color = tint

func _ready() -> void:
	add_to_group("enemies")
	_path = Game.PATH
	global_position = _path[0]
	queue_redraw()

func _process(delta: float) -> void:
	if _dead:
		return
	_move(delta)

func _move(delta: float) -> void:
	if _target_index >= _path.size():
		_escape()
		return
	var target: Vector2 = _path[_target_index]
	var to_target := target - global_position
	var step := speed * delta
	if to_target.length() <= step:
		global_position = target
		_target_index += 1
	else:
		global_position += to_target.normalized() * step

func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	queue_redraw()
	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	Game.add_gold(reward)
	removed.emit()
	queue_free()

func _escape() -> void:
	_dead = true
	Game.lose_life()
	removed.emit()
	queue_free()

func _draw() -> void:
	# Body.
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.55), 2.0, true)
	# Eyes give the blobs a bit of character.
	draw_circle(Vector2(-5, -3), 2.6, Color.WHITE)
	draw_circle(Vector2(5, -3), 2.6, Color.WHITE)
	draw_circle(Vector2(-5, -3), 1.2, Color.BLACK)
	draw_circle(Vector2(5, -3), 1.2, Color.BLACK)
	# Health bar above the head.
	var bar_w := 34.0
	var bar_h := 5.0
	var top := Vector2(-bar_w * 0.5, -radius - 14.0)
	draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0.15, 0.05, 0.05))
	var ratio: float = clamp(health / max_health, 0.0, 1.0)
	var hp_col := Color(0.30, 0.85, 0.30)
	if ratio < 0.3:
		hp_col = Color(0.90, 0.45, 0.20)
	draw_rect(Rect2(top, Vector2(bar_w * ratio, bar_h)), hp_col)
	draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5), false, 1.0)
