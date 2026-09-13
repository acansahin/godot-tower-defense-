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
## A DISC, not a cell rect, even on a board with a build grid — the grid marks where the
## tower will SNAP to, which `grid.gd` already draws, while this marks what it will occupy.
## The footprint the player sees is the same disc Game.can_build_at() tests.
##
## THREE ANSWERS, not two. Ground and price are separate refusals in `main.gd` `_drop()`, and
## while they shared one red the ghost could not tell a spot that is blocked from a spot that
## is merely unaffordable — so a player short 20 gold went looking for a tree that was not
## there. Amber is the price; red is the ground.

const OK_TINT := Color(0.30, 0.90, 0.45)     ## Nature's green: this spot is free.
const POOR_TINT := Color(1.0, 0.80, 0.30)    ## Amber: legal ground, not enough gold.
const BAD_TINT := Color(1.0, 0.40, 0.35)     ## Blocked ground.

var _pos: Vector2 = Vector2.ZERO
var _valid: bool = true
var _affordable: bool = true
var _range: float = 0.0

func show_at(pos: Vector2, valid: bool = true, tower_range: float = 0.0,
		affordable: bool = true) -> void:
	_pos = pos
	_valid = valid
	_affordable = affordable
	_range = tower_range
	show()
	queue_redraw()

func _draw() -> void:
	var c := BAD_TINT
	if _valid:
		c = OK_TINT if _affordable else POOR_TINT
	# Range first, so the footprint stays crisp on top of it.
	if _range > 0.0:
		draw_circle(_pos, _range, Color(c.r, c.g, c.b, 0.07))
		draw_arc(_pos, _range, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.45), 2.0, true)
	draw_circle(_pos, Game.TOWER_RADIUS, Color(c.r, c.g, c.b, 0.30))
	draw_arc(_pos, Game.TOWER_RADIUS, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.95), 2.5, true)
