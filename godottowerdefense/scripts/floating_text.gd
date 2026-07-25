extends Node2D
class_name FloatingText
## A short-lived label that drifts upward and fades — damage dealt, gold earned.
##
## Deliberately has no .tscn: it is a bare Node2D plus this script, so it is built with
## FloatingText.new() and needs no scene file. That also avoids a script preloading the
## very scene it is attached to.

const LIFETIME := 0.75
const RISE := 34.0  ## Pixels travelled over the full lifetime.

var _text: String = ""
var _color: Color = Color.WHITE
var _font_size: int = 14
var _half_width: float = 0.0  ## Cached so _draw doesn't re-measure every frame.
var _drift: float = 0.0       ## Horizontal jitter so stacked hits don't overlap exactly.
var _age: float = 0.0
var pool: Node = null  ## The $Effects pool that owns this label (see effects.gd); null = unpooled.

## Cached $Effects pool node, re-resolved automatically after a scene reload frees it.
static var _effects: Node = null

## Pops one in the level's Effects layer, drawn from the pool. `ctx` is any node in the tree.
static func spawn(ctx: Node, pos: Vector2, text: String, color: Color,
		font_size: int = 14) -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var t: FloatingText = _effects.acquire_text()
	t.global_position = pos
	t.setup(text, color, font_size)

## Returns this label to its pool (or frees it if unpooled).
func _recycle() -> void:
	if pool != null:
		pool.recycle_text(self)
	else:
		queue_free()

func setup(text: String, color: Color, font_size: int) -> void:
	_age = 0.0  # a reused label restarts its rise/fade from the top
	_text = text
	_color = color
	_font_size = font_size
	_drift = randf_range(-9.0, 9.0)
	var font := ThemeDB.fallback_font
	if font != null:
		_half_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size).x * 0.5
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		_recycle()
		return
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var p: float = _age / LIFETIME
	# Ease out: most of the rise happens early, then it hangs in place and fades.
	var inv: float = 1.0 - p
	var pos := Vector2(_drift - _half_width, -RISE * (1.0 - inv * inv))
	var alpha: float = 1.0 - p * p
	# Dark outline first, so numbers stay legible over both pale grass and dark bodies.
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + o, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size,
				Color(0, 0, 0, 0.55 * alpha))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size,
			Color(_color.r, _color.g, _color.b, alpha))
