extends Node2D
class_name Enemy
## Walks along Game.PATH, carries health, shows a health bar, gives gold on
## death and costs the player a life if it reaches the end.
##
## Rendering is split across three z-ordered CanvasItems so a plain walking enemy repaints
## NOTHING per frame (movement is a transform; the engine re-renders the cached draw lists
## for free):
##   * this node's own _draw()  — the under-layer: ground shadow, or flapping wings.
##   * `_body`    (child, mid)  — body, highlight, outline, impact flash, eyes. The idle
##                                breathing wobble is `_body.scale`, a transform, so the body
##                                only repaints on a flash or a colour change.
##   * `_overlay` (child, top)  — status rings, archetype/regen markers, boss crown, health
##                                bar. Repaints only on a state change (damage, status
##                                apply/expire) and animates per-frame only while stunned or
##                                actively regen-healing.
## Layers are added body-then-overlay with default z, so each enemy still draws as one unit
## (shadow → body → overlay) in spawn order — visually identical to a single-node draw.

const EnemyLayer := preload("res://scripts/enemy_layer.gd")

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
var cc_immune: bool = false  ## Ignores slow / stun. Poison still applies (it's damage, not control).
var regen_dps: float = 0.0   ## Heals this much per second.
var split_into: int = 0      ## Children spawned on death (0 = none).
var armor_element: String = ""  ## Element matchup vs tower damage element ("" = neutral).

var _path: Array = []
var _target_index: int = 1
var _dead: bool = false
var _wing_phase: float = 0.0  ## Drives the wing-flap animation.
var _anim_phase: float = 0.0  ## Drives the idle breathing wobble.
var _body: Node2D             ## Mid layer: body + eyes; scaled for the breathing wobble.
var _overlay: Node2D          ## Top layer: rings, markers, crown, health bar.

## Seconds an enemy must go undamaged before regen_dps starts healing it again. This is
## what stops regen from being a hard DPS threshold: while you keep hitting it, it heals
## nothing, so falling slightly short of the old break-even rate no longer means the
## enemy is simply unkillable.
const REGEN_DELAY := 2.0

# Status effects applied by tower projectiles.
var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _poison_dps: float = 0.0
var _poison_time: float = 0.0
var _stun_time: float = 0.0
var _regen_block: float = 0.0  ## Counts down after damage; regen is paused while > 0.
var _flash: float = 0.0        ## 1 -> 0 white pop after a direct hit.

# --- Layer repaint helpers -----------------------------------------------------
# Each guards against being called before _ready() has built the layers (make_flying is
# invoked before the enemy is added to the tree), so no call site needs to know the order.

func _repaint_body() -> void:
	if _body != null:
		_body.queue_redraw()

func _repaint_overlay() -> void:
	if _overlay != null:
		_overlay.queue_redraw()

func _repaint_all() -> void:
	queue_redraw()
	_repaint_body()
	_repaint_overlay()

## White pop confirming a projectile connected. Deliberately NOT driven from
## take_damage(): poison ticks go through there every single frame, which would leave a
## poisoned enemy permanently lit instead of flashing on impacts. Repaints the body now so
## the pop shows this frame regardless of process order relative to the firing projectile.
func flash() -> void:
	_flash = 1.0
	_repaint_body()

## Slows to `factor` of base speed for `time` seconds. Strongest slow wins.
func apply_slow(factor: float, time: float) -> void:
	if cc_immune:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, time)
	_repaint_overlay()

## Freezes the enemy in place for `time` seconds (longest stun wins).
func apply_stun(time: float) -> void:
	if cc_immune:
		return
	_stun_time = maxf(_stun_time, time)
	_repaint_overlay()

## Deals `dps` damage per second for `time` seconds. Strongest poison wins.
## Deliberately NOT gated on cc_immune: that flag means crowd-control immunity, and
## poison is damage rather than control. This is what keeps Nature / Ice / Lava useful
## against Immune waves instead of leaving most of the roster with no effect at all.
func apply_poison(dps: float, time: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_time = maxf(_poison_time, time)
	_repaint_overlay()

## Sets how far along the path this enemy starts (used for split children).
func set_progress(index: int) -> void:
	_target_index = index

## How far along the road this enemy is, in pixels (higher = closer to the exit).
## Drives the First / Last tower targeting modes.
func progress() -> float:
	return Game.path_progress(_target_index, global_position)

## False once this enemy has died or escaped. queue_free() only takes effect at the
## end of the frame, so towers holding a target reference must check this rather than
## is_instance_valid() alone — otherwise they spend a shot on a corpse.
func is_alive() -> bool:
	return not _dead

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
	_repaint_all()  # shadow<->wings on the parent, tint on the body

func _ready() -> void:
	add_to_group("enemies")
	_path = Game.PATH
	global_position = _path[0]
	# Mid + top draw layers. Added body-first so within this enemy they stack shadow (this
	# node) -> body -> overlay, matching the old single-node draw order.
	var body := EnemyLayer.new()
	body.draw_fn = _draw_body
	add_child(body)
	_body = body
	var overlay := EnemyLayer.new()
	overlay.draw_fn = _draw_overlay
	add_child(overlay)
	_overlay = overlay
	_repaint_all()

func _process(delta: float) -> void:
	if _dead:
		return
	_anim_phase += delta * 3.0
	# Idle breathing wobble — a transform on the body layer, so it costs no redraw.
	var br := sin(_anim_phase)
	_body.scale = Vector2(1.0 + 0.05 * br, 1.0 - 0.05 * br)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 7.0)
		_body.queue_redraw()  # the impact pop fades on the body layer
	# Continuous animation is the exception, not the rule: wings flap while flying (parent
	# layer), stun sparks spin and the regen pulse breathes while active (overlay layer).
	# Everything else repaints only on a state change, so a plain walking enemy — which is
	# most of them, most of the time — asks for zero redraws here.
	if is_flying:
		_wing_phase += delta * 10.0
		queue_redraw()
	if _stun_time > 0.0 or (regen_dps > 0.0 and _regen_block <= 0.0 and health < max_health):
		_overlay.queue_redraw()
	_tick_status(delta)
	if _dead:
		return  # poison may have killed it this frame
	_move(delta)

## Advances slow / poison timers and applies poison damage over time.
func _tick_status(delta: float) -> void:
	if _regen_block > 0.0:
		_regen_block -= delta
		if _regen_block <= 0.0:
			_repaint_overlay()  # un-dim the regen marker
	elif regen_dps > 0.0 and health < max_health:
		health = minf(max_health, health + regen_dps * delta)
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			_repaint_overlay()
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			_repaint_overlay()
	if _poison_time > 0.0:
		_poison_time -= delta
		take_damage(_poison_dps * delta)
		if _poison_time <= 0.0:
			_poison_dps = 0.0
			_repaint_overlay()

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
	_regen_block = REGEN_DELAY  # any hit — including a poison tick — suspends regen
	health -= amount
	_repaint_overlay()  # health bar + regen marker live on the overlay
	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	Audio.play("boss_death" if is_boss else "enemy_death", 0.1)
	# Spawn the visuals before the queue_free() below — they read the tree through `self`.
	DeathBurst.spawn(self, global_position, color, radius)
	FloatingText.spawn(self, global_position + Vector2(0, -radius),
			"+%d" % reward, Color(1, 0.85, 0.35), 13)
	if is_boss:
		Game.request_shake(7.0)
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
	Audio.play("leak")
	Game.request_shake(4.0)  # a leak should be felt, not just noticed in the HUD
	Game.lose_life(life_cost)
	removed.emit()
	queue_free()

## Under-layer (this node): the flat ground shadow, or the flyer's wings + shadow. Static
## for a ground enemy (drawn once); repainted each frame only while flying, for the flap.
func _draw() -> void:
	if is_flying:
		_draw_wings()
	else:
		# Flat ground shadow.
		draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Mid layer: the body itself, drawn onto the `_body` canvas item `ci`. Drawn at rest — the
## breathing wobble is `_body.scale`, set in _process — so this only repaints on an impact
## flash or a colour change (make_flying).
func _draw_body(ci: CanvasItem) -> void:
	# Body with a soft top-left highlight for volume.
	ci.draw_circle(Vector2.ZERO, radius, color)
	var hl := color.lightened(0.25)
	ci.draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.55, Color(hl.r, hl.g, hl.b, 0.55))
	ci.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.55), 2.0, true)
	# Impact pop, over the body but under the eyes so it reads as the whole blob lighting up.
	if _flash > 0.0:
		ci.draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.55 * _flash))
	# Eyes give the blobs a bit of character.
	ci.draw_circle(Vector2(-5, -3), 2.6, Color.WHITE)
	ci.draw_circle(Vector2(5, -3), 2.6, Color.WHITE)
	ci.draw_circle(Vector2(-5, -3), 1.2, Color.BLACK)
	ci.draw_circle(Vector2(5, -3), 1.2, Color.BLACK)

## Top layer: status rings, archetype/regen markers, boss crown, and the health bar, drawn
## onto the `_overlay` canvas item `ci`. Sits over the body (rings hug just outside the body
## radius; crown + regen "+" sit over it).
func _draw_overlay(ci: CanvasItem) -> void:
	# Status rings: blue = slowed, green = poisoned.
	if _slow_time > 0.0:
		ci.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 22, Color(0.4, 0.7, 1.0, 0.85), 2.0, true)
	if _poison_time > 0.0:
		ci.draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 22, Color(0.45, 0.9, 0.35, 0.8), 2.0, true)
	if _stun_time > 0.0:
		# Yellow ring with spinning "stunned" sparks.
		ci.draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 22, Color(1.0, 0.95, 0.3, 0.9), 2.0, true)
		for i in range(3):
			var a := _anim_phase * 4.0 + i * TAU / 3.0
			ci.draw_circle(Vector2(cos(a), sin(a)) * (radius + 9.0), 2.6, Color(1.0, 0.95, 0.45))
	# Archetype markers so wave types read at a glance.
	if cc_immune:
		ci.draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 26, Color(0.78, 0.82, 0.9, 0.9), 3.0, true)
	if regen_dps > 0.0:
		# Bright "+" and a pulsing ring only while it is actually healing; dim otherwise.
		# This makes "my damage is stopping the heal" unmistakable at a glance.
		var healing := _regen_block <= 0.0 and health < max_health
		var g := Color(0.5, 1.0, 0.55, 1.0 if healing else 0.3)
		var p := Vector2(radius * 0.55, -radius * 0.55)
		ci.draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), g, 2.0)
		ci.draw_line(p + Vector2(0, -3), p + Vector2(0, 3), g, 2.0)
		if healing:
			var pulse: float = 0.5 + 0.5 * sin(_anim_phase * 3.0)
			ci.draw_arc(Vector2.ZERO, radius + 12.0 + pulse * 3.0, 0.0, TAU, 24,
					Color(0.45, 1.0, 0.5, 0.30 + 0.45 * pulse), 2.0, true)
	if is_boss:
		_draw_crown(ci)

	# Health bar above the head (scales with body size so bosses read clearly).
	var bar_w := radius * 2.2
	var bar_h := 5.0
	var top := Vector2(-bar_w * 0.5, -radius - 14.0)
	ci.draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0.15, 0.05, 0.05))
	var ratio: float = clamp(health / max_health, 0.0, 1.0)
	var hp_col := Color(0.30, 0.85, 0.30)
	if ratio < 0.3:
		hp_col = Color(0.90, 0.45, 0.20)
	ci.draw_rect(Rect2(top, Vector2(bar_w * ratio, bar_h)), hp_col)
	ci.draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5), false, 1.0)

## Gold crown sitting on a boss's head, drawn onto the overlay canvas item `ci`.
func _draw_crown(ci: CanvasItem) -> void:
	var gold := Color(1.0, 0.82, 0.2)
	var y := -radius + 2.0
	var wd := radius * 0.9
	ci.draw_rect(Rect2(-wd, y, wd * 2.0, 5.0), gold)
	for i in range(3):
		var cx := -wd + wd * i
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6, y), Vector2(cx + 6, y), Vector2(cx, y - 11),
		]), gold)
		ci.draw_circle(Vector2(cx, y - 11.0), 2.2, Color(0.9, 0.2, 0.2))  # gem tip
	ci.draw_rect(Rect2(-wd, y, wd * 2.0, 5.0), Color(0, 0, 0, 0.3), false, 1.0)

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
