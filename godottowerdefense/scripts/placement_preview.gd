extends Node2D
## The ghost that follows a drag: the tower's own footprint where it would stand, plus the
## range it would cover so coverage can be judged before any gold is spent.
##
## GREEN MEANS YES AND RED MEANS NO, for every tower. The range circle used to be drawn in
## the dragged element's own colour, which made the answer unreadable for Fire: a legal red
## circle and the illegal red one are the same red, so the one tower whose colour matters
## most was the one the ghost could not answer for. The element is already named and
## coloured in the palette slot the drag started from; the ghost's job is the legality.
##
## A DISC, not a cell rect. There is no grid to line up with any more — the footprint the
## player sees while dragging is the same disc Game.can_build_at() tests.

const OK_TINT := Color(0.30, 0.90, 0.45)     ## Nature's green: this spot is free.
const BAD_TINT := Color(1.0, 0.40, 0.35)     ## Blocked ground, or not enough gold.

var _pos: Vector2 = Vector2.ZERO
var _valid: bool = true
var _range: float = 0.0

func show_at(pos: Vector2, valid: bool = true, tower_range: float = 0.0) -> void:
	_pos = pos
	_valid = valid
	_range = tower_range
	show()
	queue_redraw()

func _draw() -> void:
	var c := OK_TINT if _valid else BAD_TINT
	# Range first, so the footprint stays crisp on top of it.
	if _range > 0.0:
		draw_circle(_pos, _range, Color(c.r, c.g, c.b, 0.07))
		draw_arc(_pos, _range, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.45), 2.0, true)
	var fill := Color(0.30, 0.90, 0.45, 0.30) if _valid else Color(0.95, 0.30, 0.25, 0.32)
	var edge := Color(0.40, 1.0, 0.55, 0.9) if _valid else Color(1.0, 0.40, 0.35, 0.95)
	draw_circle(_pos, Game.TOWER_RADIUS, fill)
	draw_arc(_pos, Game.TOWER_RADIUS, 0.0, TAU, 32, edge, 2.5, true)
