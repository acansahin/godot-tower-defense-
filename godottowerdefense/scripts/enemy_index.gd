extends Node
## "EnemyIndex" autoload: a per-frame uniform spatial hash of every live enemy, so towers
## and splash projectiles find in-range targets by inspecting only the grid cells their
## radius overlaps instead of scanning the whole "enemies" group.
##
## The hash is rebuilt lazily at most ONCE per frame, keyed on the process-frame counter
## (the same self-throttling trick audio.gd uses for its per-frame cap). The rebuild happens
## on the first query of a frame, so it never depends on node process order: whichever tower
## fires first that frame pays the single O(enemies) rebuild, and every other tower and
## splash projectile that frame reuses it. This replaces what was up to O(towers × enemies)
## scanning plus one temp-array allocation per scanning tower.

const CELL := 128.0  ## Hash cell size (px). A query of radius R touches ~(2R/CELL + 1)² cells.

var _frame: int = -1
var _cells: Dictionary = {}  ## Vector2i cell -> Array of Enemy in that cell.

## Rebuilds the hash if this is the first query of the current frame; a no-op otherwise.
func _rebuild_if_stale() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	_cells.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null:
			continue
		var key := _key(enemy.global_position)
		var bucket = _cells.get(key)  # untyped: get() returns null for a missing key
		if bucket == null:
			bucket = []
			_cells[key] = bucket
		bucket.append(enemy)

## Cell coordinate for a world position.
func _key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))

## Every enemy in a cell overlapping the `radius` circle around `center`. Callers still run
## their own exact distance + targetable test, so this is a strict SUPERSET of what a full
## scan would consider — it only prunes far-away enemies, leaving targeting behaviour
## identical while turning each scan from O(all enemies) into O(enemies near the tower).
func query(center: Vector2, radius: float) -> Array:
	_rebuild_if_stale()
	var out: Array = []
	var min_x := floori((center.x - radius) / CELL)
	var max_x := floori((center.x + radius) / CELL)
	var min_y := floori((center.y - radius) / CELL)
	var max_y := floori((center.y + radius) / CELL)
	for cx in range(min_x, max_x + 1):
		for cy in range(min_y, max_y + 1):
			var bucket = _cells.get(Vector2i(cx, cy))
			if bucket != null:
				out.append_array(bucket)
	return out
