extends Node2D
## The pop a bolt makes where it lands: an expanding core, a ring pushing out behind it and
## a spray of embers. Pooled by Effects.
##
## This was `fire_impact.gd`, and it was fire's alone because Fire was the first element
## painted and the only one whose shot did not simply cease to exist on the frame damage was
## applied. Every other element's hit was a floating number and nothing else — a Water bolt
## crossed the board and then was not there any more. The geometry turned out to be nothing
## to do with fire, so it is TINTED now and the fire palette is one caller of it.
##
## Two knobs keep the fire look byte-for-byte where it matters and give the rest something
## quieter: `scale`, because a hit that fires four times a second should not stamp the same
## bloom a fireball does, and `gravity`, because embers falling out of the burst read as
## burning debris and are wrong for a splash of water.
##
## The palette is DERIVED from one colour rather than passed in five parts. Fire's
## hand-tuned constants sat within a few hundredths of `darkened`/`lightened` steps off its
## core, so keeping five colours per caller bought nothing.

const LIFETIME := 0.32
const EMBERS := 10

var pool: Node = null
var _age: float = 0.0
var _color: Color = Color(1.0, 0.43, 0.035)
var _scale: float = 1.0
var _gravity: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
static var _effects: Node = null

## Spawns one in the level's Effects layer, drawn from the pool. `ctx` is any node in the
## tree. `scale` sizes the whole burst against Fire's original (1.0), and `gravity` is how
## far the embers sag over the burst's life, in px — 0 for anything that is not on fire.
static func spawn(ctx: Node, pos: Vector2, color: Color, scale: float = 1.0,
		gravity: float = 0.0) -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var impact = _effects.acquire_impact()
	impact.global_position = pos
	impact.setup(color, scale, gravity)

func setup(color: Color, scale: float, gravity: float) -> void:
	_age = 0.0
	_color = color
	_scale = scale
	_gravity = gravity
	_angles.resize(EMBERS)
	for i in EMBERS:
		_angles[i] = TAU * i / EMBERS + randf_range(-0.18, 0.18)
	queue_redraw()

func _recycle() -> void:
	if pool != null:
		pool.recycle_impact(self)
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
	var glow := _color.darkened(0.25)
	# Two different lightenings on purpose. The CENTRE is the blown-out heart of the flash
	# and goes most of the way to white; the sparks keep their element's colour, because at
	# the fire palette's 0.72 a Water hit threw a spray of near-white dots that read as grey
	# gravel bouncing off the road.
	var hot := _color.lightened(0.70)
	var spark := _color.lightened(0.12)
	var smoke := _color.darkened(0.68)
	var core_radius := lerpf(7.0, 25.0, sin(p * PI)) * _scale
	draw_circle(Vector2.ZERO, core_radius * 1.45,
			Color(glow.r, glow.g, glow.b, 0.18 * fade))
	draw_circle(Vector2.ZERO, core_radius,
			Color(_color.r, _color.g, _color.b, 0.76 * fade))
	draw_circle(Vector2(-2.0, -2.0) * _scale, core_radius * 0.48,
			Color(hot.r, hot.g, hot.b, 0.88 * fade))
	var ring_radius := lerpf(5.0, 34.0, p) * _scale
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 28,
			Color(smoke.r, smoke.g, smoke.b, 0.46 * fade), 3.5 * fade * _scale, true)
	for i in EMBERS:
		var a: float = _angles[i]
		var distance := lerpf(6.0, 42.0 + float(i % 3) * 5.0, p) * _scale
		# Flattened on y, so the burst sits on the ground plane the board is drawn in.
		var ember_pos := Vector2(cos(a), sin(a) * 0.72) * distance
		ember_pos.y += p * p * _gravity
		draw_circle(ember_pos, lerpf(3.0, 0.8, p) * _scale,
				Color(spark.r, spark.g, spark.b, 0.92 * fade))
