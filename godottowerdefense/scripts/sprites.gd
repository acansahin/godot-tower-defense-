extends RefCounted
## Loads the painted sprites and remembers where each one meets the ground.
##
## Art arrives one set at a time (five upgrade tiers of one element per generated sheet), so
## everything here is written to cope with a half-finished folder: ask for a sprite that has
## not been drawn yet and you get null, and the caller falls back to the code-drawn art it
## has always had. That is what lets the board be repainted element by element instead of in
## one big unplayable jump.
##
## The GROUND ANCHOR is the point of this file. A tower stands at a board position, and the
## sprite has to be hung so its base sits on that spot — not its centre, which would bury a
## tall tower's feet and leave a short one floating. It is measured once per texture: the
## middle of the lowest opaque row.

const DIR := "res://assets/art/towers/"

static var _textures: Dictionary = {}  ## path -> Texture2D or null
static var _anchors: Dictionary = {}   ## path -> Vector2 in texture pixels

## The sprite for an element at a level, or null if that one has not been painted yet.
static func tower(element: String, level: int) -> Texture2D:
	return _load(DIR + "%s_%d.png" % [element, level])

## Where the sprite meets the ground, in texture pixels: x is the centre of its lowest
## opaque row, y is the bottom edge.
static func anchor(texture: Texture2D) -> Vector2:
	var path := texture.resource_path
	if _anchors.has(path):
		return _anchors[path]
	var image := texture.get_image()
	var y := image.get_height() - 1
	# Walk up until a row has something in it: a trimmed sprite ends on its lowest pixel,
	# but a re-exported one can carry a transparent row or two.
	while y > 0 and not _row_has_ink(image, y):
		y -= 1
	var first := -1
	var last := -1
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.15:
			if first < 0:
				first = x
			last = x
	var centre := float(first + last) * 0.5 if first >= 0 else image.get_width() * 0.5
	var found := Vector2(centre, y + 1)
	_anchors[path] = found
	return found

static func _row_has_ink(image: Image, y: int) -> bool:
	for x in range(0, image.get_width(), 3):
		if image.get_pixel(x, y).a > 0.15:
			return true
	return false

static func _load(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[path] = texture
	return texture
