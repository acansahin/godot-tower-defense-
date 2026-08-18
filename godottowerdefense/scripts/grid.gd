extends Node2D
## Shades the ground a tower may NOT stand on, and only while one is being dragged.
##
## There is no build grid any more: Game.can_build_at() is the whole rule — off the road, out
## of the water, clear of other towers. This makes that rule visible at the moment the player
## is asking it, and stays out of the way the rest of the time. The painting already says
## where the lake and the road are; this is for the margins, which it cannot.
##
## The node is still called Grid because Main and the scene tree call it that.

const STEP := 32.0

var _show: bool = false

## Main turns this on while a tower is being dragged.
func set_showing(value: bool) -> void:
	if _show == value:
		return
	_show = value
	queue_redraw()

func _draw() -> void:
	if not _show:
		return
	var y := 0.0
	while y < Game.WORLD_SIZE.y:
		var x := 0.0
		while x < Game.PLAY_RIGHT:
			if not Game.can_build_at(Vector2(x + STEP * 0.5, y + STEP * 0.5)):
				draw_rect(Rect2(x, y, STEP, STEP), Color(0.06, 0.02, 0.12, 0.30))
			x += STEP
		y += STEP
