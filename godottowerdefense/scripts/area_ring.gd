extends Node2D
## An expanding ring marking where an AREA effect landed, drawn at its REAL radius. Purely
## drawn (no assets), and pooled in effects.gd like DeathBurst.
##
## This was `frost_ring.gd`, and it was the area-slow's alone. The move is the same one
## `fire_impact.gd` made on its way to becoming ImpactBurst: the geometry turned out to have
## nothing to do with frost, so it is TINTED now and the icy palette is one caller of it.
##
## What it buys is the thing SPLASH never had. A splash tower hits everything within
## `splash_radius` — 90px for Earth, 110 for Lava, 80 for Steam — and until this was wired up
## nothing on the board said so: the impact drew the same 34px ring whether the tower splashed
## or not, so a single-target hit and a 110px blast were the same picture. The player could
## read the number in the panel and had no way to see it on the map.
##
## `strength` exists for the same reason ImpactBurst's `scale` does: the slow-field ring pops
## once in a while, while Steam splashes two and a half times a second, and one ring drawn at
## full weight that often turns the road into strobing hoops.
##
## No class_name on purpose: it is preloaded, which sidesteps the global-class-cache reimport
## dance for a brand-new script (see CLAUDE.md and enemy_layer.gd).

const LIFETIME := 0.35
## The palette the area-slow used before this was generalised. Kept here rather than at the
## call site so the one caller that wants ice does not have to carry a magic colour.
const FROST_TINT := Color(0.60, 0.85, 1.0)

var pool: Node = null       ## The $Effects pool that owns this ring (see effects.gd).
var _radius: float = 90.0   ## The effect's REAL radius, so the ring shows the true area.
var _tint: Color = FROST_TINT
var _strength: float = 1.0
var _age: float = 0.0

## Cached $Effects pool node, re-resolved automatically after a scene reload frees it.
static var _effects: Node = null

## Pops a ring of `radius` at `pos`, drawn from the pool. `ctx` is any node in the tree.
## `strength` scales every alpha against the original frost ring's (1.0).
static func spawn(ctx: Node, pos: Vector2, radius: float, tint: Color = FROST_TINT,
		strength: float = 1.0) -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var f = _effects.acquire_area()
	f.global_position = pos
	f.setup(radius, tint, strength)

func setup(radius: float, tint: Color, strength: float) -> void:
	_age = 0.0  # a reused ring restarts its expand/fade
	_radius = radius
	_tint = tint
	_strength = strength
	queue_redraw()

## Returns this ring to its pool (or frees it if unpooled).
func _recycle() -> void:
	if pool != null:
		pool.recycle_area(self)
	else:
		queue_free()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		_recycle()
		return
	queue_redraw()

func _draw() -> void:
	var p: float = _age / LIFETIME
	var r: float = _radius * (0.35 + 0.65 * p)  # bursts outward toward the full radius
	var fade: float = (1.0 - p) * _strength
	# Derived from the one tint rather than passed in three parts — the frost ring's three
	# hand-tuned colours sat within a few hundredths of these lightenings off its own fill,
	# which is what made the generalisation free.
	var edge := _tint.lightened(0.30)
	var spark := _tint.lightened(0.80)
	# Soft fill, then a crisper ring edge.
	draw_circle(Vector2.ZERO, r, Color(_tint.r, _tint.g, _tint.b, 0.10 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(edge.r, edge.g, edge.b, 0.55 * fade), 2.0, true)
	# A few sparks riding the expanding edge.
	for i in 6:
		var a: float = TAU * i / 6.0 + p * 1.2
		draw_circle(Vector2(cos(a), sin(a)) * r, 1.8 * fade,
				Color(spark.r, spark.g, spark.b, 0.7 * fade))
