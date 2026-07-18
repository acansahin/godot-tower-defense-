extends Node2D
## Draws the whole static level: green grass background and the grey
## cobblestone S-road built from Game.PATH. Pure _draw(), no nodes needed.

func _draw() -> void:
	var w := Game.SCREEN_SIZE.x
	var h := Game.SCREEN_SIZE.y

	# Grass background.
	draw_rect(Rect2(0, 0, w, h), Color(0.30, 0.55, 0.24))

	# A few darker grass patches for a bit of texture.
	var patches := [
		Vector2(180, 500), Vector2(1050, 250), Vector2(600, 660),
		Vector2(150, 200), Vector2(1160, 640), Vector2(760, 90),
	]
	for p in patches:
		draw_circle(p, 60.0, Color(0.27, 0.50, 0.21, 0.6))

	var path: Array = Game.PATH
	var road_w := 64.0
	_draw_road(path, road_w + 10.0, Color(0.28, 0.28, 0.30)) # dark border
	_draw_road(path, road_w, Color(0.55, 0.55, 0.58))        # stone surface
	_draw_cobbles(path, road_w)                              # cobble detail

func _draw_road(path: Array, width: float, color: Color) -> void:
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], color, width)
	# Round the corners so segment joints look continuous.
	for p in path:
		draw_circle(p, width * 0.5, color)

func _draw_cobbles(path: Array, width: float) -> void:
	var stone := Color(0.46, 0.46, 0.49)
	var step := 26.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg := b - a
		var length := seg.length()
		if length < 1.0:
			continue
		var dir := seg / length
		var normal := Vector2(-dir.y, dir.x)
		var d := step * 0.5
		var row := 0
		while d < length:
			var center := a + dir * d
			var offset: float = 18.0 if row % 2 == 0 else -18.0
			draw_circle(center + normal * offset, 7.0, stone)
			draw_circle(center, 7.0, stone)
			draw_circle(center - normal * offset, 7.0, stone)
			d += step
			row += 1
