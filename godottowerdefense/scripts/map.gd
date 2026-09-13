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
##
## A board whose BOARDS row leaves `art` EMPTY is a GREYBOX, and this file draws its ground
## and its road from Game.active_path instead of from a picture. That is not the old
## generated terrain coming back: it is one flat fill and one ribbon, and it exists so a
## board's SHAPE can be played and measured before anything is painted for it. An empty
## field is a declaration; a MISSING field is still the loud error it always was.

## Greybox palette. Deliberately drab — a board with no art should look unfinished rather
## than look like a style — but the road has to stay legible THROUGH grid.gd's refused-ground
## wash, which is laid over exactly the ground the road occupies. At the first contrast (ground
## 0.24, road 0.46) the wash merged the two into one brown band in a screenshot, so the road
## carries most of the separation and the kerb draws a hard edge against the ground.
const GREYBOX_GROUND := Color(0.19, 0.22, 0.20)
const GREYBOX_KERB := Color(0.13, 0.14, 0.13)
const GREYBOX_ROAD := Color(0.60, 0.57, 0.50)

const WATER_SHADER := preload("res://shaders/water_flow.gdshader")
const MapAmbience := preload("res://scripts/map_ambience.gd")

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
var _ambience: Node2D

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
	_ambience = MapAmbience.new()
	add_child(_ambience)
	Game.board_changed.connect(_on_board_changed)
	_on_board_changed(Game.active_board_id)

func _on_board_changed(board_id: String) -> void:
	# Each painting owns a separately derived mask; sharing one would ripple grass where a
	# different board happened to have water. Fall regions only choose vertical flow inside
	# that mask — black pixels remain perfectly still. All three live in Game.BOARDS.
	if not Game.BOARDS.has(board_id):
		return   # released between scenes; the next use_board() calls straight back here
	var def: Dictionary = Game.BOARDS[board_id]
	var water := _board_texture(board_id, "water")
	if water == null:
		# Nothing to ripple. The shader is a UV displacement OF THE PAINTING, so leaving it
		# installed with a null mask would ask it to sample a texture that is not there.
		material = null
		_ambience.setup(board_id, String(def.get("ambience", "")))
		queue_redraw()
		return
	_water_material.set_shader_parameter("water_mask", water)
	_water_material.set_shader_parameter("waterfall_region_a", def["waterfall_a"])
	_water_material.set_shader_parameter("waterfall_region_b", def["waterfall_b"])
	var ambience := String(def.get("ambience", "forest"))
	_water_material.set_shader_parameter("foliage_strength",
			0.00062 if ambience == "forest" else 0.0)
	_water_material.set_shader_parameter("heat_strength",
			0.00042 if ambience == "ash" else (0.00024 if ambience == "desert" else 0.0))
	_water_material.set_shader_parameter("lava_mode", ambience == "ash")
	_ambience.setup(board_id, ambience)
	material = _water_material
	queue_redraw()

## The painting or the water mask for `board_id`, by Game.BOARDS field name.
func _board_texture(board_id: String, key: String) -> Texture2D:
	# An EMPTY id is the released state Game.release_board() leaves between scenes, not a
	# mistake, so it returns quietly. Any other id that is missing from the table IS a
	# mistake, and the loud version of it is the whole reason this table exists.
	if board_id == "":
		return null
	var def: Dictionary = Game.BOARDS.get(board_id, {})
	if not def.has(key):
		push_error("Map: board '%s' has no '%s' entry in Game.BOARDS" % [board_id, key])
		return null
	# Present and empty: a greybox board saying it has no picture for this slot.
	var path := String(def[key])
	if path == "":
		return null
	if not _art_cache.has(path):
		_art_cache[path] = load(path) as Texture2D
	return _art_cache[path] as Texture2D

func _draw() -> void:
	var board := _board_texture(Game.active_board_id, "art")
	if board == null:
		_draw_greybox()
		return
	draw_texture_rect(board, Rect2(Vector2.ZERO, Game.WORLD_SIZE), false)
	if show_road:
		_draw_traced_road()

## An unpainted board: flat ground, a kerbed road ribbon, nothing else.
##
## The ribbon is drawn as the set of points within ROAD_HALF of Game.active_path — a thick
## line per leg plus a disc at every joint — which is not an approximation of the road but
## its DEFINITION: `Game.dist_to_road()` measures to that same polyline, so what is painted
## here and what the placement rule refuses are the same shape, corners included.
func _draw_greybox() -> void:
	if Game.active_path.size() < 2:
		return
	draw_rect(Rect2(Vector2.ZERO, Game.WORLD_SIZE), GREYBOX_GROUND)
	_draw_ribbon(Game.ROAD_HALF + 5.0, GREYBOX_KERB)
	_draw_ribbon(Game.ROAD_HALF, GREYBOX_ROAD)
	if show_road:
		_draw_traced_road()

func _draw_ribbon(half: float, col: Color) -> void:
	var path: Array = Game.active_path
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], col, half * 2.0)
	for p in path:
		draw_circle(p, half, col)

func _draw_traced_road() -> void:
	var path: Array = Game.active_path
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], Color(1.0, 0.25, 0.25, 0.85), 3.0, true)
	for p in path:
		draw_circle(p, 5.0, Color(1.0, 0.85, 0.2, 0.9))
	# The keep: the last waypoint is where a leak happens.
	draw_arc(path[path.size() - 1], Game.ROAD_HALF, 0.0, TAU, 32,
			Color(0.4, 0.8, 1.0, 0.9), 3.0, true)
