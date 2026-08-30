extends Node2D
## Shades the ground a tower may NOT stand on, while one is being dragged.
##
## `Game.can_build_at()` is the whole placement rule and it answers about any point on the
## board, so the player may build anywhere it says yes. What this node adds is that the
## answer is visible BEFORE the question is asked: without it, free placement only ever
## answered under the cursor, and the player had to probe the board to find out where the
## trees, the kerb and the neighbours were.
##
## It replaces a lattice of marked pads that used to stand here. Those made the legal spots
## unmissable, at the cost of deciding for the player where a tower goes; the shading gives
## the same information as terrain rather than as a set of slots. Only shown while placing —
## a permanent overlay competes with the board it is drawn on.
##
## The node is still called Grid because Main and the scene tree call it that.

const STEP := 32.0

var _show: bool = false

## Set by Main so the neighbour-spacing part of the rule can be evaluated. Null is fine —
## the shading then reflects terrain alone.
var towers: Node = null

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
