extends Node2D
class_name DeathBurst
## The puff of dots an enemy leaves behind when it dies. The project ships no assets,
## so "particles" here are a ring of draw_circle calls that expand and fade.
##
## Like FloatingText, it has no .tscn — built with DeathBurst.new().

const LIFETIME := 0.35
const DOTS := 9

var _color: Color = Color.WHITE
var _radius: float = 16.0
var _age: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()

## Spawns one in the level's Effects layer. `ctx` is any node already in the tree —
## call it *before* the dying enemy queue_free()s itself.
static func spawn(ctx: Node, pos: Vector2, color: Color, radius: float) -> void:
	var root := ctx.get_tree().current_scene.get_node_or_null("Effects")
	if root == null:
		return
	var b := DeathBurst.new()
	root.add_child(b)
	b.global_position = pos
	b.setup(color, radius)

func setup(color: Color, radius: float) -> void:
	_color = color
	_radius = radius
	_angles.resize(DOTS)
	for i in DOTS:
		# Even spread plus jitter, so a stream of deaths doesn't stamp the same star.
		_angles[i] = TAU * i / DOTS + randf_range(-0.25, 0.25)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p: float = _age / LIFETIME
	var spread: float = _radius * (0.4 + 1.6 * p)
	var dot: float = _radius * 0.22 * (1.0 - p * 0.6)
	var col := Color(_color.r, _color.g, _color.b, 1.0 - p)
	for a in _angles:
		draw_circle(Vector2(cos(a), sin(a)) * spread, dot, col)
