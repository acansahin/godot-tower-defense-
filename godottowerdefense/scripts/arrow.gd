extends Projectile
## Fast single-target arrow. The node is rotated toward travel direction each
## frame, so _draw() just points along +x.

func _ready() -> void:
	speed = 520.0

func _draw() -> void:
	draw_line(Vector2(-10, 0), Vector2(8, 0), Color(0.50, 0.35, 0.15), 2.0)
	var head := PackedVector2Array([Vector2(9, 0), Vector2(2, -4), Vector2(2, 4)])
	draw_colored_polygon(head, Color(0.85, 0.85, 0.90))
	draw_line(Vector2(-10, 0), Vector2(-13, -3), Color.WHITE, 1.5)
	draw_line(Vector2(-10, 0), Vector2(-13, 3), Color.WHITE, 1.5)
