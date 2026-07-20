extends Node2D
## Translucent cell that follows the drag onto the build grid. Green marks a
## legal cell, red an illegal / unaffordable one. Draws the exact cell rect (in
## world space) so the ghost matches the grid, plus the range the tower being
## dragged would cover — so coverage can be judged before any gold is spent.

var _rect: Rect2 = Rect2()
var _valid: bool = true
var _range: float = 0.0
var _color: Color = Color.WHITE  ## Element colour of the tower being dragged.

func show_at(rect: Rect2, valid: bool = true, tower_range: float = 0.0,
		color: Color = Color.WHITE) -> void:
	_rect = rect
	_valid = valid
	_range = tower_range
	_color = color
	show()
	queue_redraw()

func _draw() -> void:
	# Range first, so the cell outline stays crisp on top of it.
	if _range > 0.0:
		var c := _color if _valid else Color(1.0, 0.40, 0.35)
		var centre := _rect.get_center()
		draw_circle(centre, _range, Color(c.r, c.g, c.b, 0.07))
		draw_arc(centre, _range, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.45), 2.0, true)
	if _valid:
		draw_rect(_rect, Color(0.30, 0.90, 0.45, 0.25))
		draw_rect(_rect, Color(0.40, 1.0, 0.55, 0.85), false, 2.0)
	else:
		draw_rect(_rect, Color(0.95, 0.30, 0.25, 0.28))
		draw_rect(_rect, Color(1.0, 0.40, 0.35, 0.9), false, 2.0)
