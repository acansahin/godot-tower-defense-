extends Node2D
## Draws the board: one painted image, stretched to Game.WORLD_SIZE.
##
## Everything this file used to generate — grass, cobblestones, flora, the road itself — is
## gone. The terrain is art now (`assets/art/board_source.png`), and the geometry follows
## it: the waypoints in Game.PATH were traced out of this very image by tools/trace_road.py,
## and Game.obstacles marks the water and the thickets the painting already shows.
##
## The one thing still drawn in code is the ROAD OVERLAY, and only while `show_road` is on.
## It is the check that the traced path and the painted road are the same road — the sort of
## mistake that is obvious in a screenshot and invisible in a number.

const WATER_SHADER := preload("res://shaders/water_flow.gdshader")

## The painting and its water mask both come from Game.BOARDS now, loaded on demand rather
## than preloaded. This file used to hold three `preload`s and two `match` statements over
## the board id, and both matches fell through to the spiral on an unknown id — so a board
## added to game.gd but forgotten here drew the WRONG PICTURE, with the right road on it,
## and never raised a thing. One table cannot disagree with itself.
##
## Loaded (not preloaded) because only one board is on screen at a time and each painting is
## ~3 MB; ResourceLoader caches, so a board revisited in the same session is free.
var _art_cache: Dictionary = {}

## Draws the traced Game.PATH over the painting. Turn on after re-tracing; the question it
## answers is whether the line sits down the middle of the cobbles all the way to the keep.
@export var show_road: bool = false

var _water_material: ShaderMaterial

func _ready() -> void:
	# The board is 1672px of painting shown across 1280px of screen: a mild downscale, but
	# still one that samples between pixels, so it gets the same filtering as the towers.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The board is the only thing on screen that never redraws, which is what makes a shader
	# the right tool for moving its water: layered surface currents and the waterfall happen
	# per pixel on the GPU and cost this node nothing per frame. Built here rather than saved
	# into the scene so the mask and the board it was derived from stay together.
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	Game.board_changed.connect(_on_board_changed)
	_on_board_changed(Game.active_board_id)

func _on_board_changed(board_id: String) -> void:
	# Each painting owns a separately derived mask; sharing one would ripple grass where a
	# different board happened to have water. Fall regions only choose vertical flow inside
	# that mask — black pixels remain perfectly still. All three live in Game.BOARDS.
	if not Game.BOARDS.has(board_id):
		return   # released between scenes; the next use_board() calls straight back here
	var def: Dictionary = Game.BOARDS[board_id]
	_water_material.set_shader_parameter("water_mask", _board_texture(board_id, "water"))
	_water_material.set_shader_parameter("waterfall_region_a", def["waterfall_a"])
	_water_material.set_shader_parameter("waterfall_region_b", def["waterfall_b"])
	material = _water_material
	queue_redraw()

## The painting or the water mask for `board_id`, by Game.BOARDS field name.
func _board_texture(board_id: String, key: String) -> Texture2D:
	# An EMPTY id is the released state Game.release_board() leaves between scenes, not a
	# mistake, so it returns quietly. Any other id that is missing from the table IS a
	# mistake, and the loud version of it is the whole reason this table exists.
	if board_id == "":
		return null
	var path := String(Game.BOARDS.get(board_id, {}).get(key, ""))
	if path == "":
		push_error("Map: board '%s' has no '%s' entry in Game.BOARDS" % [board_id, key])
		return null
	if not _art_cache.has(path):
		_art_cache[path] = load(path) as Texture2D
	return _art_cache[path] as Texture2D

func _draw() -> void:
	var board := _board_texture(Game.active_board_id, "art")
	if board == null:
		return
	draw_texture_rect(board, Rect2(Vector2.ZERO, Game.WORLD_SIZE), false)
	if show_road:
		_draw_traced_road()

func _draw_traced_road() -> void:
	var path: Array = Game.active_path
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], Color(1.0, 0.25, 0.25, 0.85), 3.0, true)
	for p in path:
		draw_circle(p, 5.0, Color(1.0, 0.85, 0.2, 0.9))
	# The keep: the last waypoint is where a leak happens.
	draw_arc(path[path.size() - 1], Game.ROAD_HALF, 0.0, TAU, 32,
			Color(0.4, 0.8, 1.0, 0.9), 3.0, true)
