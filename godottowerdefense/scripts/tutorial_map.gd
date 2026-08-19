extends Node2D
## The close training-ground painting. Gameplay geometry is installed by Tutorial before
## the first enemy or placement check; this node only draws the image and its teaching cues.

const BOARD := preload("res://assets/art/maps/winding_forest_close_v1.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(BOARD, Rect2(Vector2.ZERO, Game.WORLD_SIZE), false)
	# The generated painting intentionally has only a handful of open grass pockets. A quiet
	# ring makes those legal spots unambiguous without putting permanent build pads in the art.
	for entry in Game.active_build_zones:
		draw_circle(entry[0], float(entry[1]), Color(0.35, 0.95, 0.48, 0.055))
		draw_arc(entry[0], float(entry[1]), 0.0, TAU, 48,
				Color(0.55, 1.0, 0.62, 0.32), 2.0, true)
	if OS.get_cmdline_user_args().has("--show-tutorial-road"):
		for i in range(Game.active_path.size() - 1):
			draw_line(Game.active_path[i], Game.active_path[i + 1],
					Color(1.0, 0.18, 0.18, 0.88), 4.0, true)
		for point in Game.active_path:
			draw_circle(point, 5.0, Color(1.0, 0.9, 0.2, 0.95))
