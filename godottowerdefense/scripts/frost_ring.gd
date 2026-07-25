extends Node2D
## A quick expanding icy ring marking where Ice's Lv2+ area-slow landed — so the frost field
## is visible, not just implied by the blue rings on enemies. Purely drawn (no assets), and
## pooled in effects.gd like DeathBurst.
##
## No class_name on purpose: it is preloaded, which sidesteps the global-class-cache reimport
## dance for a brand-new script (see CLAUDE.md and enemy_layer.gd).

const LIFETIME := 0.35

var pool: Node = null       ## The $Effects pool that owns this ring (see effects.gd).
var _radius: float = 90.0   ## Matches the tower's slow_splash radius, so the ring shows the real area.
var _age: float = 0.0

## Cached $Effects pool node, re-resolved automatically after a scene reload frees it.
static var _effects: Node = null

## Pops a frost ring of `radius` at `pos`, drawn from the pool. `ctx` is any node in the tree.
static func spawn(ctx: Node, pos: Vector2, radius: float) -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var f = _effects.acquire_frost()
	f.global_position = pos
	f.setup(radius)

func setup(radius: float) -> void:
	_age = 0.0  # a reused ring restarts its expand/fade
	_radius = radius
	queue_redraw()

## Returns this ring to its pool (or frees it if unpooled).
func _recycle() -> void:
	if pool != null:
		pool.recycle_frost(self)
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
	var r: float = _radius * (0.35 + 0.65 * p)  # bursts outward toward the full slow radius
	var fade: float = 1.0 - p
	# Soft icy fill, then a crisper ring edge.
	draw_circle(Vector2.ZERO, r, Color(0.60, 0.85, 1.0, 0.10 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.72, 0.92, 1.0, 0.55 * fade), 2.0, true)
	# A few snowflake sparks riding the expanding edge.
	for i in 6:
		var a: float = TAU * i / 6.0 + p * 1.2
		draw_circle(Vector2(cos(a), sin(a)) * r, 1.8 * fade, Color(0.92, 0.98, 1.0, 0.7 * fade))
