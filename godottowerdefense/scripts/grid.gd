extends Node2D
## Shows where a tower may stand, in whichever of the two ways the board offers.
##
## `Game.can_build_at()` is the whole placement rule on every board and this node never
## second-guesses it — it only asks it somewhere the player can see the answer BEFORE the
## question. Without it, placement only ever answered under the cursor and the player had to
## probe the board to find out where the trees, the kerb and the neighbours were.
##
## FREE-PLACEMENT BOARDS get shading: the legal set is continuous, so the only thing that can
## be drawn is the ground the rule refuses, and only while something is being placed — a
## permanent overlay competes with the painting it is drawn on. This replaced a lattice of
## marked pads, which made the legal spots unmissable at the cost of deciding for the player
## where a tower goes.
##
## GRID BOARDS get the lattice itself, and it stays up. There is nothing to compete with: a
## board with a grid has a rectilinear road drawn to match it, so the cells are part of the
## picture rather than a spreadsheet laid over one. While a tower is being placed the same
## lattice also fills the cells the rule refuses, so "where may I build" and "where is it
## worth building" are one drawing instead of two.
##
## The node is still called Grid because Main and the scene tree call it that.

## Shading step for a free-placement board: a quantised read of a continuous rule.
const STEP := 32.0
const REFUSED := Color(0.06, 0.02, 0.12, 0.30)

const CELL_IDLE := Color(1.0, 1.0, 1.0, 0.07)     ## The lattice at rest.
const CELL_OPEN := Color(0.55, 1.0, 0.70, 0.35)   ## A free cell, while placing.
const CELL_TAKEN := Color(1.0, 1.0, 1.0, 0.10)    ## Occupied, while placing.
const CELL_INSET := 3.0

var _show: bool = false

## Set by Main so the neighbour part of the rule can be evaluated. Null is fine — the drawing
## then reflects terrain alone, which is what it used to do ALWAYS: this was assigned and
## never read, so the overlay called ground within TOWER_GAP of a standing tower buildable
## and the drop then refused it. A guide that disagrees with the rule is worse than none.
var towers: Node = null

func _ready() -> void:
	# A grid board's lattice is up whether or not anything is being placed, so it has to
	# follow a board swap as well as the tower set.
	Game.board_changed.connect(func(_id: String): queue_redraw())

## Main turns this on while a tower is being placed.
func set_showing(value: bool) -> void:
	if _show == value:
		return
	_show = value
	queue_redraw()

func _standing() -> Array:
	return towers.get_children() if towers != null else []

func _draw() -> void:
	if Game.has_grid():
		_draw_lattice()
		return
	if not _show:
		return
	var others := _standing()
	var y := 0.0
	while y < Game.WORLD_SIZE.y:
		var x := 0.0
		while x < Game.WORLD_SIZE.x:
			if not Game.can_build_at(Vector2(x + STEP * 0.5, y + STEP * 0.5), others):
				draw_rect(Rect2(x, y, STEP, STEP), REFUSED)
			x += STEP
		y += STEP

## One outline per legal cell, plus — while placing — a wash over the ground the rule
## refuses. Terrain and occupancy are asked SEPARATELY because they mean different things to
## the player: a cell under a tree is never coming back, a cell under a tower is one sale
## away.
func _draw_lattice() -> void:
	var cell := Game.active_grid_cell
	var extent := Game.grid_size()
	var others := _standing()
	var inset := Vector2(CELL_INSET, CELL_INSET)
	for row in extent.y:
		for col in extent.x:
			var at := Game.cell_centre(Vector2i(col, row))
			var rect := Rect2(at - cell * 0.5 + inset, cell - inset * 2.0)
			if not Game.can_build_at(at):
				if _show:
					draw_rect(rect, REFUSED)
				continue
			if not _show:
				draw_rect(rect, CELL_IDLE, false, 1.0)
				continue
			var free := Game.can_build_at(at, others)
			draw_rect(rect, CELL_OPEN if free else CELL_TAKEN, false, 2.0)
			if free:
				draw_rect(rect, Color(CELL_OPEN.r, CELL_OPEN.g, CELL_OPEN.b, 0.07))
