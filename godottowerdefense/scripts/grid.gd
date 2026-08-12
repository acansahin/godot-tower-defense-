extends Node2D
## The faint build grid. Precomputes the discrete cells where towers may be
## placed, flush against the road on every side. Rows are one square cell tall per
## gap between the horizontal roads; columns in a band tile outward from the
## vertical road that crosses it so towers also sit flush against the bends.
## Occupancy is tracked by Main against placed towers.

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

func _build_cells() -> void:
	for row in Game.GRID_ROWS:
		var yc: float = row.x       # Vector2(centre_y, cell_height)
		var h: float = row.y
		var xv := _vertical_road_x(yc)
		if is_inf(xv):
			# No vertical road crosses this row: plain uniform columns.
			var x := Game.GRID_COL_START
			while x <= Game.GRID_COL_END:
				_try_add(x, yc, h)
				x += Game.CELL_WIDTH
		else:
			# Tile outward from flush against each side of the vertical road.
			var edge := Game.ROAD_HALF + Game.CELL_WIDTH * 0.5
			var half := Game.CELL_WIDTH * 0.5
			var x := xv - edge
			while x - half >= 0.0:
				_try_add(x, yc, h)
				x -= Game.CELL_WIDTH
			x = xv + edge
			while x + half <= Game.PLAY_RIGHT:
				_try_add(x, yc, h)
				x += Game.CELL_WIDTH

func _try_add(x: float, yc: float, h: float) -> void:
	if Game.dist_to_road(Vector2(x, yc)) >= Game.ROAD_CLEARANCE:
		cells.append(Rect2(x - Game.CELL_WIDTH * 0.5, yc - h * 0.5, Game.CELL_WIDTH, h))

## X of the vertical road segment crossing this y, or INF if none.
func _vertical_road_x(yc: float) -> float:
	var path: Array = Game.PATH
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		if absf(a.x - b.x) < 1.0 and yc >= minf(a.y, b.y) and yc <= maxf(a.y, b.y):
			return a.x
	return INF

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
