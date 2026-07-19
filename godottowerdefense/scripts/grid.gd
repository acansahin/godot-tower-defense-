extends Node2D
## The faint build grid. Precomputes the discrete cells where towers may be
## placed, flush against the road on every side. Rows differ in height per band
## so two rows exactly fill each gap between the horizontal roads; columns in a
## band tile outward from the vertical road that crosses it so towers also sit
## flush against the bends. Occupancy is tracked by Main against placed towers.

const ROAD_HALF := 32.0  ## Stone half-width; cell edges tile flush to this.

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
			var edge := ROAD_HALF + Game.CELL_WIDTH * 0.5
			var half := Game.CELL_WIDTH * 0.5
			var x := xv - edge
			while x - half >= 0.0:
				_try_add(x, yc, h)
				x -= Game.CELL_WIDTH
			x = xv + edge
			while x + half <= Game.SCREEN_SIZE.x:
				_try_add(x, yc, h)
				x += Game.CELL_WIDTH

func _try_add(x: float, yc: float, h: float) -> void:
	if _dist_to_road(Vector2(x, yc)) >= Game.ROAD_CLEARANCE:
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

## The buildable cell containing world_pos, or an empty Rect2 (size zero).
func snap(world_pos: Vector2) -> Rect2:
	for r in cells:
		if r.has_point(world_pos):
			return r
	return Rect2()

func _draw() -> void:
	for r in cells:
		draw_rect(r, Color(1, 1, 1, 0.05))
		draw_rect(r, Color(1, 1, 1, 0.10), false, 1.0)

func _dist_to_road(p: Vector2) -> float:
	var best := INF
	var path: Array = Game.PATH
	for i in range(path.size() - 1):
		best = minf(best, _dist_point_segment(p, path[i], path[i + 1]))
	return best

func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
