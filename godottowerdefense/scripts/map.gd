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

const BOARD := preload("res://assets/art/board_source.png")
const WATER_SHADER := preload("res://shaders/water_flow.gdshader")
## Where the water is, found in the painting by tools/water_mask.py. Re-run that after any
## repaint; the shader ripples exactly what this file calls white.
const WATER_MASK := preload("res://assets/art/board_water.png")

## Draws the traced Game.PATH over the painting. Turn on after re-tracing; the question it
## answers is whether the line sits down the middle of the cobbles all the way to the keep.
@export var show_road: bool = false

func _ready() -> void:
	# The board is 1672px of painting shown across 1280px of screen: a mild downscale, but
	# still one that samples between pixels, so it gets the same filtering as the towers.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The board is the only thing on screen that never redraws, which is what makes a shader
	# the right tool for moving its water: layered surface currents and the waterfall happen
	# per pixel on the GPU and cost this node nothing per frame. Built here rather than saved
	# into the scene so the mask and the board it was derived from stay together.
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("water_mask", WATER_MASK)
	material = mat
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(BOARD, Rect2(Vector2.ZERO, Game.WORLD_SIZE), false)
	if show_road:
		_draw_traced_road()

func _draw_traced_road() -> void:
	var path: Array = Game.PATH
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], Color(1.0, 0.25, 0.25, 0.85), 3.0, true)
	for p in path:
		draw_circle(p, 5.0, Color(1.0, 0.85, 0.2, 0.9))
	# The keep: the last waypoint is where a leak happens.
	draw_arc(path[path.size() - 1], Game.ROAD_HALF, 0.0, TAU, 32,
			Color(0.4, 0.8, 1.0, 0.9), 3.0, true)
