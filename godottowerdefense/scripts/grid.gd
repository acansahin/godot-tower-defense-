extends Node2D
## Draws the build pads — the marked spots a tower may stand on — and, on a board that has
## none, shades the ground a tower may NOT stand on while one is being dragged.
##
## There is still no build GRID in the old sense: `Game.can_build_at()` remains the whole
## rule, and `Game.pads()` is the subset of it the player is offered. What this node adds
## is that the answer is visible BEFORE the question is asked — free placement only ever
## answered under the cursor, and a board built that way looked accidental.
##
## Two boards, two treatments, one node:
##
## * A board with pads draws them, always. Faint while nothing is happening, lit while a
##   tower is being dragged, so the lattice reads as part of the terrain rather than as a UI
##   layer switched on and off.
## * A board without pads (one that publishes its own `active_build_zones` allowlist instead)
##   keeps the old behaviour: closed ground shaded, and only while something is being placed.
##
## The node is still called Grid because Main and the scene tree call it that.

const STEP := 32.0
## Pad radius in board px, as a fraction of the lattice pitch rather than a fixed size, so
## the marks stay in proportion to the spacing instead of being re-tuned by hand every time
## the pitch moves.
##
## The RATIO is not the one a tight lattice wanted. At the old 70px pitch the marks were 21px
## (0.30) and neighbouring pads nearly touched, which was the constraint; at 186px that same
## ratio paints 56px dinner plates on the grass. What the mark has to do is say "a tower goes
## here" without competing with the tower, so it is pinned nearer the footprint the player is
## actually offered — 0.18 gives 33px against a TOWER_RADIUS of 30.
const PAD_RADIUS := Game.PAD_PITCH * 0.18
## Vertical squash. The board is seen from slightly above, so a circle painted flat on the
## ground is an ellipse — the same 0.45 the towers' contact shadows use.
const PAD_FLATTEN := 0.45
## A pad this close to a tower is under it, so it is not drawn. The tower's own art is wider
## than the pad and covers it, but the ring still showed at the base on the smaller sets.
const PAD_OCCUPIED := 12.0

var _show: bool = false

## Set by Main so an occupied pad can be left undrawn. Null is fine — every pad is drawn.
var towers: Node2D = null

## Main turns this on while a tower is being dragged.
func set_showing(value: bool) -> void:
	if _show == value:
		return
	_show = value
	queue_redraw()

func _draw() -> void:
	if Game.has_pads():
		_draw_pads()
		return
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

func _draw_pads() -> void:
	# Lit while placing, quieter otherwise — but never as quiet as the first attempt, which
	# used alpha 0.05 and vanished into the painting. A mark the player cannot find is the
	# same as no mark: the board is busy meadow and flowers, so the ring needs a dark
	# under-stroke to hold against light grass and a light one to hold against shadow.
	var fill := Color(0.88, 1.0, 0.82, 0.20) if _show else Color(1.0, 1.0, 0.94, 0.11)
	var edge := Color(0.82, 1.0, 0.78, 0.75) if _show else Color(1.0, 1.0, 0.93, 0.38)
	var under := Color(0.0, 0.05, 0.02, 0.45 if _show else 0.28)
	var width := 2.5 if _show else 2.0
	for pad in Game.pads():
		if _occupied(pad):
			continue
		draw_set_transform(pad, 0.0, Vector2(1.0, PAD_FLATTEN))
		draw_circle(Vector2.ZERO, PAD_RADIUS, fill)
		draw_arc(Vector2.ZERO, PAD_RADIUS + 1.5, 0.0, TAU, 24, under, width, true)
		draw_arc(Vector2.ZERO, PAD_RADIUS, 0.0, TAU, 24, edge, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _occupied(pad: Vector2) -> bool:
	if towers == null:
		return false
	for child in towers.get_children():
		var t := child as Tower
		if t != null and t.position.distance_to(pad) < PAD_OCCUPIED:
			return true
	return false
