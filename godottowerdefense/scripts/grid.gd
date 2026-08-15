extends Node2D
## The faint build grid. Precomputes the discrete cells where towers may be placed: one
## uniform tiling of the play area, minus everything the road runs through or too close
## to. Occupancy is tracked by Main against placed towers.

## How far outside a cell a *drop* may land and still count as that cell. Sized for a
## finger: on a phone the whole board is drawn at ~0.5 scale, so a release that looks
## dead-centre can easily land on the road, and a near-miss used to do nothing at all
## (Main just returned — no sound, no ghost). 24 grows the effective drop target from
## 96x96 to 144x144 while still leaving a real dead band down the middle of the road:
## the gap between two rows is exactly one road wide (80), so anything from 40 up would
## swallow the road whole and leave nowhere to release a drag you changed your mind about.
const SNAP_TOLERANCE := 24.0

var cells: Array[Rect2] = []

func _ready() -> void:
	_build_cells()
	queue_redraw()

## Tiles the play area and keeps every cell that clears the road.
##
## This replaced a table of explicit horizontal rows, each tiled outward from the vertical
## road crossing it. That worked only while the road ran in straight horizontal legs: the
## road is now a spiral, and the ground it leaves buildable is a ring of blocks that no row
## table can describe. Tiling and testing the distance describes any road shape at all, and
## it is the same rule the player sees — "you may build wherever you are not on the road".
##
## The tiling is anchored at the world origin rather than at the road, so cells line up in
## a single grid across the whole board instead of in per-row runs that drift out of step
## with each other where two legs meet.
##
## A cell must fit WHOLE inside the play area: off the bottom edge, under the HUD's top bar
## (Game.PLAY_TOP) or under the tower palette (Game.PLAY_RIGHT) all mean a tower you cannot
## fully see, and under the palette also one you could never click again.
func _build_cells() -> void:
	var half_w := Game.CELL_WIDTH * 0.5
	var half_h := Game.CELL_HEIGHT * 0.5
	var y := half_h
	while y - half_h < Game.PLAY_TOP:
		y += Game.CELL_HEIGHT
	while y + half_h <= Game.WORLD_SIZE.y:
		var x := half_w
		while x + half_w <= Game.PLAY_RIGHT:
			if Game.dist_to_road(Vector2(x, y)) >= Game.ROAD_CLEARANCE:
				cells.append(Rect2(x - half_w, y - half_h, Game.CELL_WIDTH, Game.CELL_HEIGHT))
			x += Game.CELL_WIDTH
		y += Game.CELL_HEIGHT

## The buildable cell containing world_pos, or an empty Rect2 (size zero). Exact —
## use this for anything that acts on what is ALREADY on the board (upgrade, sell,
## hover). Being generous there would mean a tap on bare road spends gold upgrading
## whichever tower happened to be nearby.
func snap(world_pos: Vector2) -> Rect2:
	for r in cells:
		if r.has_point(world_pos):
			return r
	return Rect2()

## Same, but a miss falls back to the nearest cell within SNAP_TOLERANCE. Only for
## placing a NEW tower, where the worst case of being generous is building one cell
## over — and where Main runs the drag ghost through this same call, so the player
## sees which cell a forgiving press resolved to before lifting their finger.
func snap_forgiving(world_pos: Vector2) -> Rect2:
	var exact := snap(world_pos)
	if exact.size != Vector2.ZERO:
		return exact
	var best := Rect2()
	var best_d := INF
	for r in cells:
		if not r.grow(SNAP_TOLERANCE).has_point(world_pos):
			continue
		var d := world_pos.distance_squared_to(r.get_center())
		if d < best_d:
			best_d = d
			best = r
	return best

func _draw() -> void:
	# Kept faint enough to read as "buildable ground" rather than UI, but no fainter:
	# at phone scale a 1px border sub-pixels away completely and the board looks blank.
	for r in cells:
		draw_rect(r, Color(1, 1, 1, 0.07))
		draw_rect(r, Color(1, 1, 1, 0.16), false, 2.0)
