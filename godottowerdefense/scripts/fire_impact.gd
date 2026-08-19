extends Node2D
## Short birth/death counterpart to the Fire projectile's continuous flight effect. The
## expanding core, smoke ring and embers make impact a distinct state instead of letting the
## projectile disappear on the exact frame damage is applied. Pooled by Effects.

const LIFETIME := 0.32
const EMBERS := 10

var pool: Node = null
var _age: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
static var _effects: Node = null

static func spawn(ctx: Node, pos: Vector2) -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var impact = _effects.acquire_fire_impact()
	impact.global_position = pos
	impact.setup()

func setup() -> void:
	_age = 0.0
	_angles.resize(EMBERS)
	for i in EMBERS:
		_angles[i] = TAU * i / EMBERS + randf_range(-0.18, 0.18)
	queue_redraw()

func _recycle() -> void:
	if pool != null:
		pool.recycle_fire_impact(self)
	else:
		queue_free()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		_recycle()
		return
	queue_redraw()

func _draw() -> void:
	var p := _age / LIFETIME
	var fade := 1.0 - p
	var core_radius := lerpf(7.0, 25.0, sin(p * PI))
	draw_circle(Vector2.ZERO, core_radius * 1.45,
			Color(1.0, 0.16, 0.015, 0.18 * fade))
	draw_circle(Vector2.ZERO, core_radius,
			Color(1.0, 0.43, 0.035, 0.76 * fade))
	draw_circle(Vector2(-2.0, -2.0), core_radius * 0.48,
			Color(1.0, 0.96, 0.55, 0.88 * fade))
	var ring_radius := lerpf(5.0, 34.0, p)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 28,
			Color(0.34, 0.09, 0.03, 0.46 * fade), 3.5 * fade, true)
	for i in EMBERS:
		var a: float = _angles[i]
		var distance := lerpf(6.0, 42.0 + float(i % 3) * 5.0, p)
		var ember_pos := Vector2(cos(a), sin(a) * 0.72) * distance
		ember_pos.y += p * p * 14.0
		draw_circle(ember_pos, lerpf(3.0, 0.8, p),
				Color(1.0, 0.48 + 0.04 * float(i % 4), 0.06, 0.92 * fade))
