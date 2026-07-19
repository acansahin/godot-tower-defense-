extends Node2D
## Draws the whole static level: layered grass background with scattered flora,
## and the cobblestone S-road (drop shadow, shaded border, varied stones, and
## direction chevrons) built from Game.PATH. Pure _draw(), no nodes needed.

# Scattered grass decoration, placed by hand to sit off the road.
const PATCHES_DARK := [Vector2(180, 500), Vector2(1050, 250), Vector2(600, 665), Vector2(150, 200)]
const PATCHES_LIGHT := [Vector2(1160, 640), Vector2(760, 90), Vector2(430, 640), Vector2(1000, 60)]
const BUSHES := [Vector2(120, 300), Vector2(1180, 300), Vector2(60, 640), Vector2(700, 40), Vector2(1220, 120)]
const ROCKS := [Vector2(520, 100), Vector2(880, 640), Vector2(200, 660), Vector2(1120, 40)]
const FLOWERS := [
	Vector2(320, 250), Vector2(1080, 470), Vector2(640, 250), Vector2(470, 660),
	Vector2(820, 470), Vector2(160, 420), Vector2(1180, 470), Vector2(360, 100),
]

func _draw() -> void:
	var w := Game.SCREEN_SIZE.x
	var h := Game.SCREEN_SIZE.y

	# Grass with a soft top-light / bottom-shade gradient.
	draw_rect(Rect2(0, 0, w, h), Color(0.30, 0.55, 0.24))
	draw_rect(Rect2(0, 0, w, h * 0.5), Color(1, 1, 1, 0.045))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color(0, 0, 0, 0.06))

	# Two-tone grass patches for texture.
	for p in PATCHES_DARK:
		draw_circle(p, 62.0, Color(0.27, 0.50, 0.21, 0.6))
	for p in PATCHES_LIGHT:
		draw_circle(p, 54.0, Color(0.35, 0.60, 0.28, 0.5))

	_draw_flora()

	var path: Array = Game.PATH
	var road_w := 64.0
	_draw_road(path, road_w + 12.0, Vector2(0, 5), Color(0, 0, 0, 0.18))   # drop shadow
	_draw_road(path, road_w + 10.0, Vector2.ZERO, Color(0.26, 0.26, 0.29)) # dark border
	_draw_road(path, road_w, Vector2.ZERO, Color(0.55, 0.55, 0.58))        # stone surface
	_draw_road(path, road_w - 10.0, Vector2.ZERO, Color(1, 1, 1, 0.05))    # centre highlight
	_draw_cobbles(path)                                                    # cobble detail
	_draw_arrows(path)                                                     # travel direction

	# Corner vignette.
	for c in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		draw_circle(c, 340.0, Color(0, 0, 0, 0.05))

func _draw_flora() -> void:
	for b in BUSHES:  # bushes = clustered dark-green blobs
		draw_circle(b + Vector2(-9, 2), 11.0, Color(0.20, 0.42, 0.18))
		draw_circle(b + Vector2(9, 2), 11.0, Color(0.20, 0.42, 0.18))
		draw_circle(b + Vector2(0, -5), 13.0, Color(0.24, 0.47, 0.20))
	for r in ROCKS:  # rocks = grey stone with a highlight
		draw_circle(r, 9.0, Color(0.45, 0.45, 0.48))
		draw_circle(r + Vector2(-2, -2), 4.0, Color(0.60, 0.60, 0.63))
	for f in FLOWERS:  # flowers = tiny petals around a yellow centre
		var petal := Color(0.95, 0.6, 0.75) if int(f.x) % 2 == 0 else Color(0.7, 0.6, 0.95)
		for a in range(4):
			var ang := a * PI * 0.5
			draw_circle(f + Vector2(cos(ang), sin(ang)) * 3.2, 2.0, petal)
		draw_circle(f, 1.8, Color(1.0, 0.85, 0.3))

func _draw_road(path: Array, width: float, offset: Vector2, color: Color) -> void:
	for i in range(path.size() - 1):
		draw_line(path[i] + offset, path[i + 1] + offset, color, width)
	# Round the corners so segment joints look continuous.
	for p in path:
		draw_circle(p + offset, width * 0.5, color)

func _draw_cobbles(path: Array) -> void:
	var stones := [Color(0.50, 0.50, 0.53), Color(0.46, 0.46, 0.49), Color(0.42, 0.42, 0.46)]
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
			draw_circle(center + normal * offset, 7.0, stones[(row) % 3])
			draw_circle(center, 7.0, stones[(row + 1) % 3])
			draw_circle(center - normal * offset, 7.0, stones[(row + 2) % 3])
			d += step
			row += 1

## Faint chevrons along the road pointing the way enemies travel.
func _draw_arrows(path: Array) -> void:
	var col := Color(1, 1, 1, 0.14)
	var spacing := 90.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg := b - a
		var length := seg.length()
		if length < 1.0:
			continue
		var dir := seg / length
		var normal := Vector2(-dir.y, dir.x)
		var d := spacing * 0.5
		while d < length:
			var c := a + dir * d
			var tip := c + dir * 9.0
			draw_line(c + normal * 9.0, tip, col, 3.0)
			draw_line(c - normal * 9.0, tip, col, 3.0)
			d += spacing
