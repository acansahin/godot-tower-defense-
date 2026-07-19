extends Node2D
## Translucent cell that follows the drag onto the build grid. Green marks a
## legal cell, red an illegal / unaffordable one. Draws the exact cell rect (in
## world space) so the ghost matches the grid.

var _rect: Rect2 = Rect2()
var _valid: bool = true

func show_at(rect: Rect2, valid: bool = true) -> void:
	_rect = rect
	_valid = valid
	show()
	queue_redraw()

func _draw() -> void:
	if _valid:
		draw_rect(_rect, Color(0.30, 0.90, 0.45, 0.25))
		draw_rect(_rect, Color(0.40, 1.0, 0.55, 0.85), false, 2.0)
	else:
		draw_rect(_rect, Color(0.95, 0.30, 0.25, 0.28))
		draw_rect(_rect, Color(1.0, 0.40, 0.35, 0.9), false, 2.0)
