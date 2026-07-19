extends Node2D
class_name Enemy
## Walks along Game.PATH, carries health, shows a health bar, gives gold on
## death and costs the player a life if it reaches the end.

signal removed  ## Emitted whenever the enemy leaves play (death OR escape).
## Emitted by a splitter when it dies so WaveManager can spawn its children.
## (position, path_progress, count, child_hp, child_speed, tint, child_radius)
signal split_requested(pos: Vector2, progress: int, count: int, hp: float, spd: float, tint: Color, r: float)

var speed: float = 70.0
var max_health: float = 30.0
var health: float = 30.0
var reward: int = 5
var color: Color = Color(0.85, 0.3, 0.3)
var radius: float = 16.0
var is_flying: bool = false  ## Flyers can only be hit by archer towers.
var is_boss: bool = false    ## Bosses get a crown + heavier presence.
var life_cost: int = 1       ## Lives lost if this enemy reaches the end (bosses cost more).
# Archetype traits (set by WaveManager from the wave's WAVE_TYPES entry).
var cc_immune: bool = false  ## Ignores slow / poison / stun.
var regen_dps: float = 0.0   ## Heals this much per second.
var split_into: int = 0      ## Children spawned on death (0 = none).

var _path: Array = []
var _target_index: int = 1
var _dead: bool = false
var _wing_phase: float = 0.0  ## Drives the wing-flap animation.
var _anim_phase: float = 0.0  ## Drives the idle breathing wobble.

# Status effects applied by tower projectiles.
var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _poison_dps: float = 0.0
var _poison_time: float = 0.0
var _stun_time: float = 0.0

## Slows to `factor` of base speed for `time` seconds. Strongest slow wins.
func apply_slow(factor: float, time: float) -> void:
	if cc_immune:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, time)
	queue_redraw()

## Freezes the enemy in place for `time` seconds (longest stun wins).
func apply_stun(time: float) -> void:
	if cc_immune:
		return
	_stun_time = maxf(_stun_time, time)
	queue_redraw()

## Deals `dps` damage per second for `time` seconds. Strongest poison wins.
func apply_poison(dps: float, time: float) -> void:
	if cc_immune:
		return
	_poison_dps = maxf(_poison_dps, dps)
	_poison_time = maxf(_poison_time, time)
	queue_redraw()

## Sets how far along the path this enemy starts (used for split children).
func set_progress(index: int) -> void:
	_target_index = index

func setup(hp: float, spd: float, gold_reward: int, tint: Color) -> void:
	max_health = hp
	health = hp
	speed = spd
	reward = gold_reward
	color = tint

## Turns this enemy into a flyer: squishier and faster, with a pale airborne
## tint. Only archer towers (can_hit_flying) can target it.
func make_flying() -> void:
	is_flying = true
	max_health *= 0.65
	health = max_health
	speed *= 1.25
	color = Color(0.72, 0.78, 0.96)
	queue_redraw()

func _ready() -> void:
	add_to_group("enemies")
	_path = Game.PATH
	global_position = _path[0]
	queue_redraw()

func _process(delta: float) -> void:
	if _dead:
		return
	_anim_phase += delta * 3.0
	if is_flying:
		_wing_phase += delta * 10.0
	queue_redraw()  # animate the idle wobble / wings every frame
	_tick_status(delta)
	if _dead:
		return  # poison may have killed it this frame
	_move(delta)

## Advances slow / poison timers and applies poison damage over time.
func _tick_status(delta: float) -> void:
	if regen_dps > 0.0 and health < max_health:
		health = minf(max_health, health + regen_dps * delta)
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			queue_redraw()
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			queue_redraw()
	if _poison_time > 0.0:
		_poison_time -= delta
		take_damage(_poison_dps * delta)
		if _poison_time <= 0.0:
			_poison_dps = 0.0
			queue_redraw()

func _move(delta: float) -> void:
	if _stun_time > 0.0:
		return  # frozen in place
	if _target_index >= _path.size():
		_escape()
		return
	var target: Vector2 = _path[_target_index]
	var to_target := target - global_position
	var step := speed * _slow_factor * delta
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
	# Splitters break into smaller children that continue from here. Emit BEFORE
	# `removed` so WaveManager adds them to the alive count first (no early clear).
	if split_into > 0:
		split_requested.emit(global_position, _target_index, split_into,
				max_health * 0.35, speed * 1.15, color, radius * 0.62)
	removed.emit()
	queue_free()

func _escape() -> void:
	_dead = true
	Game.lose_life(life_cost)
	removed.emit()
	queue_free()

func _draw() -> void:
	if is_flying:
		_draw_wings()
	else:
		# Flat ground shadow.
		draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Idle breathing wobble applied to the body only.
	var br := sin(_anim_phase)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + 0.05 * br, 1.0 - 0.05 * br))
	# Body with a soft top-left highlight for volume.
	draw_circle(Vector2.ZERO, radius, color)
	var hl := color.lightened(0.25)
	draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.55, Color(hl.r, hl.g, hl.b, 0.55))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0, 0, 0, 0.55), 2.0, true)
	# Eyes give the blobs a bit of character.
	draw_circle(Vector2(-5, -3), 2.6, Color.WHITE)
	draw_circle(Vector2(5, -3), 2.6, Color.WHITE)
	draw_circle(Vector2(-5, -3), 1.2, Color.BLACK)
	draw_circle(Vector2(5, -3), 1.2, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Status rings: blue = slowed, green = poisoned.
	if _slow_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 22, Color(0.4, 0.7, 1.0, 0.85), 2.0, true)
	if _poison_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 22, Color(0.45, 0.9, 0.35, 0.8), 2.0, true)
	if _stun_time > 0.0:
		# Yellow ring with spinning "stunned" sparks.
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 22, Color(1.0, 0.95, 0.3, 0.9), 2.0, true)
		for i in range(3):
			var a := _anim_phase * 4.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a), sin(a)) * (radius + 9.0), 2.6, Color(1.0, 0.95, 0.45))
	# Archetype markers so wave types read at a glance.
	if cc_immune:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 26, Color(0.78, 0.82, 0.9, 0.9), 3.0, true)
	if regen_dps > 0.0:
		var g := Color(0.5, 1.0, 0.55)
		var p := Vector2(radius * 0.55, -radius * 0.55)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), g, 2.0)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), g, 2.0)
	if is_boss:
		_draw_crown()

	# Health bar above the head (scales with body size so bosses read clearly).
	var bar_w := radius * 2.2
	var bar_h := 5.0
	var top := Vector2(-bar_w * 0.5, -radius - 14.0)
	draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0.15, 0.05, 0.05))
	var ratio: float = clamp(health / max_health, 0.0, 1.0)
	var hp_col := Color(0.30, 0.85, 0.30)
	if ratio < 0.3:
		hp_col = Color(0.90, 0.45, 0.20)
	draw_rect(Rect2(top, Vector2(bar_w * ratio, bar_h)), hp_col)
	draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5), false, 1.0)

## Gold crown sitting on a boss's head.
func _draw_crown() -> void:
	var gold := Color(1.0, 0.82, 0.2)
	var y := -radius + 2.0
	var wd := radius * 0.9
	draw_rect(Rect2(-wd, y, wd * 2.0, 5.0), gold)
	for i in range(3):
		var cx := -wd + wd * i
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6, y), Vector2(cx + 6, y), Vector2(cx, y - 11),
		]), gold)
		draw_circle(Vector2(cx, y - 11.0), 2.2, Color(0.9, 0.2, 0.2))  # gem tip
	draw_rect(Rect2(-wd, y, wd * 2.0, 5.0), Color(0, 0, 0, 0.3), false, 1.0)

## Flapping wings and a ground shadow, drawn behind the body for flyers.
func _draw_wings() -> void:
	draw_circle(Vector2(0, radius + 10.0), radius * 0.7, Color(0, 0, 0, 0.18))
	var flap: float = sin(_wing_phase) * 6.0
	var wing_col := Color(0.90, 0.93, 1.0, 0.9)
	var left := PackedVector2Array([
		Vector2(-radius * 0.4, -2.0),
		Vector2(-radius - 12.0, -8.0 - flap),
		Vector2(-radius - 6.0, 4.0),
	])
	var right := PackedVector2Array([
		Vector2(radius * 0.4, -2.0),
		Vector2(radius + 12.0, -8.0 - flap),
		Vector2(radius + 6.0, 4.0),
	])
	draw_colored_polygon(left, wing_col)
	draw_colored_polygon(right, wing_col)
