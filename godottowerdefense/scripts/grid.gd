extends Node2D
## Draws the scenery that BLOCKS building — the boulders, thickets and ponds in
## Game.obstacles — and nothing else. There is no build grid any more: a tower goes wherever
## the ground is clear, and Game.can_build_at() is the whole rule.
##
## The node is still called Grid because Main and the scene tree call it that, and renaming
## a node in a .tscn is a bigger change than the job it does.
##
## What it draws is a placeholder: once the painted terrain lands, each obstacle will be a
## lake or a stand of trees drawn on the background, and these mounds go away. Keeping the
## DRAWING and the COLLISION on one list is the point either way — a board where the picture
## says "rock" and the rule says "buildable" is worse than either alone.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	for entry in Game.obstacles:
		var centre: Vector2 = entry[0]
		var radius: float = entry[1]
		# A soft mound: shadow, body, lighter cap — something standing on the grass rather
		# than a hole cut in it.
		draw_circle(centre + Vector2(0, radius * 0.18), radius, Color(0, 0, 0, 0.16))
		draw_circle(centre, radius, Color(0.24, 0.40, 0.20))
		draw_circle(centre - Vector2(radius * 0.15, radius * 0.20), radius * 0.72,
				Color(0.30, 0.48, 0.24))
		draw_arc(centre, radius, 0.0, TAU, 28, Color(0.14, 0.24, 0.12, 0.7), 2.0, true)
