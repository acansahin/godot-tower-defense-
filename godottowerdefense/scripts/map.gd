extends Node2D
## Draws the whole static level: layered grass background with scattered flora,
## and the cobblestone serpentine road (drop shadow, shaded border, varied stones, and
## direction chevrons) built from Game.PATH. Pure _draw(), no nodes needed.
##
## Everything here is sized to Game.WORLD_SIZE, not the viewport: the world is four
## screens and the camera pans across it, so drawing to the screen size would leave
## three quarters of the board as empty background.

# Grass decoration is scattered procedurally from a fixed seed rather than hand-placed.
# Same seed = same layout every run, so it is still "art" and not noise — but it costs
# nothing to maintain: these used to be 21 literal Vector2s that all silently landed on
# the stone the moment the road moved.
const DECOR_SEED := 20250812
const DECOR_CLEARANCE := 24.0  ## Extra gap kept between a decoration and the road edge.

# How many of each to scatter, and the minimum gap from the road for each kind.
# Counts are per screen-sized area and multiplied up by DECOR_DENSITY below, so the
# world growing does not silently thin the decoration out to nothing.
const N_PATCHES_DARK := 5
const N_PATCHES_LIGHT := 5
const N_BUSHES := 6
const N_ROCKS := 5
const N_FLOWERS := 10
## World area in screens. 2560x1440 against a 1280x720 viewport is 4.
const DECOR_DENSITY := int((Game.WORLD_SIZE.x * Game.WORLD_SIZE.y)
		/ (Game.SCREEN_SIZE.x * Game.SCREEN_SIZE.y))

var _patches_dark: PackedVector2Array
var _patches_light: PackedVector2Array
var _bushes: PackedVector2Array
var _rocks: PackedVector2Array
var _flowers: PackedVector2Array

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	# Big blobs need to clear the road by their own radius; small ones only by a hair.
	_patches_dark = _scatter(rng, N_PATCHES_DARK * DECOR_DENSITY, 86.0)
	_patches_light = _scatter(rng, N_PATCHES_LIGHT * DECOR_DENSITY, 76.0)
	_bushes = _scatter(rng, N_BUSHES * DECOR_DENSITY, 20.0)
	_rocks = _scatter(rng, N_ROCKS * DECOR_DENSITY, 14.0)
	_flowers = _scatter(rng, N_FLOWERS * DECOR_DENSITY, 6.0)
	queue_redraw()

## `count` points on the grass, each at least `clear` px of its own bulk away from the
## stone. Rejection sampling with a bounded number of tries: if a point cannot be placed
## the scatter simply ends up shorter, which is invisible and beats looping forever.
func _scatter(rng: RandomNumberGenerator, count: int, clear: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var min_dist := Game.ROAD_HALF + DECOR_CLEARANCE + clear
	var tries := 0
	while out.size() < count and tries < count * 40:
		tries += 1
		var p := Vector2(rng.randf_range(0.0, Game.WORLD_SIZE.x),
				rng.randf_range(0.0, Game.WORLD_SIZE.y))
		if Game.dist_to_road(p) >= min_dist:
			out.append(p)
	return out

func _draw() -> void:
	var w := Game.WORLD_SIZE.x
	var h := Game.WORLD_SIZE.y

	# Grass with a soft top-light / bottom-shade gradient.
	draw_rect(Rect2(0, 0, w, h), Color(0.30, 0.55, 0.24))
	draw_rect(Rect2(0, 0, w, h * 0.5), Color(1, 1, 1, 0.045))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color(0, 0, 0, 0.06))

	# Two-tone grass patches for texture.
	for p in _patches_dark:
		draw_circle(p, 86.0, Color(0.27, 0.50, 0.21, 0.6))
	for p in _patches_light:
		draw_circle(p, 76.0, Color(0.35, 0.60, 0.28, 0.5))

	_draw_flora()

	var path: Array = Game.PATH
	var road_w := Game.ROAD_HALF * 2.0
	_draw_road(path, road_w + 16.0, Vector2(0, 7), Color(0, 0, 0, 0.18))   # drop shadow
	_draw_road(path, road_w + 13.0, Vector2.ZERO, Color(0.26, 0.26, 0.29)) # dark border
	_draw_road(path, road_w, Vector2.ZERO, Color(0.55, 0.55, 0.58))        # stone surface
	_draw_road(path, road_w - 13.0, Vector2.ZERO, Color(1, 1, 1, 0.05))    # centre highlight
	_draw_cobbles(path)                                                    # cobble detail
	_draw_arrows(path)                                                     # travel direction

	# Corner vignette.
	for c in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		draw_circle(c, 400.0, Color(0, 0, 0, 0.05))

func _draw_flora() -> void:
	for b in _bushes:  # bushes = clustered dark-green blobs
		draw_circle(b + Vector2(-13, 3), 15.0, Color(0.20, 0.42, 0.18))
		draw_circle(b + Vector2(13, 3), 15.0, Color(0.20, 0.42, 0.18))
		draw_circle(b + Vector2(0, -7), 18.0, Color(0.24, 0.47, 0.20))
	for r in _rocks:  # rocks = grey stone with a highlight
		draw_circle(r, 13.0, Color(0.45, 0.45, 0.48))
		draw_circle(r + Vector2(-3, -3), 6.0, Color(0.60, 0.60, 0.63))
	for f in _flowers:  # flowers = tiny petals around a yellow centre
		var petal := Color(0.95, 0.6, 0.75) if int(f.x) % 2 == 0 else Color(0.7, 0.6, 0.95)
		for a in range(4):
			var ang := a * PI * 0.5
			draw_circle(f + Vector2(cos(ang), sin(ang)) * 4.5, 2.8, petal)
		draw_circle(f, 2.5, Color(1.0, 0.85, 0.3))

func _draw_road(path: Array, width: float, offset: Vector2, color: Color) -> void:
	for i in range(path.size() - 1):
		draw_line(path[i] + offset, path[i + 1] + offset, color, width)
	# Round the corners so segment joints look continuous.
	for p in path:
		draw_circle(p + offset, width * 0.5, color)

func _draw_cobbles(path: Array) -> void:
	var stones := [Color(0.50, 0.50, 0.53), Color(0.46, 0.46, 0.49), Color(0.42, 0.42, 0.46)]
	var step := 32.0
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
			var offset: float = 24.0 if row % 2 == 0 else -24.0
			draw_circle(center + normal * offset, 9.0, stones[(row) % 3])
			draw_circle(center, 9.0, stones[(row + 1) % 3])
			draw_circle(center - normal * offset, 9.0, stones[(row + 2) % 3])
			d += step
			row += 1

## Faint chevrons along the road pointing the way enemies travel.
func _draw_arrows(path: Array) -> void:
	var col := Color(1, 1, 1, 0.14)
	var spacing := 110.0
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
			var tip := c + dir * 13.0
			draw_line(c + normal * 13.0, tip, col, 4.0)
			draw_line(c - normal * 13.0, tip, col, 4.0)
			d += spacing
