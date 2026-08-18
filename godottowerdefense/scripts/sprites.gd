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
## tall tower's feet and leave a short one floating. It is measured once per texture, from
## the band of rows just above the sprite's lowest pixel — see anchor() for why not from
## that lowest row itself.

const DIR := "res://assets/art/towers/"
const ENEMY_DIR := "res://assets/art/enemies/"

static var _textures: Dictionary = {}  ## path -> Texture2D or null
static var _anchors: Dictionary = {}   ## path -> Vector2 in texture pixels
static var _cycle: Dictionary = {}     ## creep kind -> number of painted poses
static var _heights: Dictionary = {}   ## path -> standing height in texture pixels

## The sprite for an element at a level, or null if that one has not been painted yet.
static func tower(element: String, level: int) -> Texture2D:
	return _load(DIR + "%s_%d.png" % [element, level])

## The sprite for a creep archetype (the keys of Game.WAVE_TYPES: "normal", "fast", "tank",
## …), or null if that one has not been painted yet. Same deal as tower(): the caller falls
## back to the code-drawn blob, so the roster can be repainted one archetype at a time.
##
## `frame` picks a pose out of a WALK CYCLE — `<kind>_1.png` and `<kind>_2.png`, the same
## creature with opposite legs forward. An archetype that has only the single standing
## `<kind>.png` returns that for every frame, so a one-pose creep and a two-pose one can
## walk the same road while the art catches up.
static func enemy(kind: String, frame: int = 0) -> Texture2D:
	var posed := _load(ENEMY_DIR + "%s_%d.png" % [kind, frame + 1])
	return posed if posed != null else _load(ENEMY_DIR + kind + ".png")

## The longest run of numbered poses this archetype was painted with: `<kind>_1.png` up to
## `<kind>_N.png`, or 1 for a lone standing `<kind>.png`, or 0 for one with no art at all.
##
## The cycle length is READ OFF THE FOLDER rather than declared anywhere, which is what keeps
## re-animating a creep a pure file copy: drop six frames next to a creature that had two and
## it steps six, with nothing in the code to update. Nothing caps N but MAX_POSES, and that is
## only there to bound the probe — it is not a budget.
##
## What sets the USEFUL number is the rate, and it is worth writing down because six looked
## like plenty and was not. The cycle is one stride, and the stride rate comes from the creep's
## own speed: a wave-2 creep walks 1.04 strides a second, so six frames play at 6.2 fps and the
## eye counts them one by one. Twelve is the working figure (12.5 fps there, 27 by wave 25).
## Past about sixteen a creature drawn 62 px tall has no room left to show the difference, and
## the generator loses the character's likeness long before that anyway.
##
## The animation also asks so it can LEAN ON THE ART WHERE THERE IS ART AND FAKE IT WHERE
## THERE IS NOT — a one-pose flyer gets a wing sweep faked out of a scale pulse, and the more
## real frames arrive the further that fake steps back instead of double-counting against
## them. Free after the first call: `_load` caches its misses as well as its hits.
const MAX_POSES := 24

static func pose_count(kind: String) -> int:
	if _cycle.has(kind):
		return _cycle[kind]
	var n := 0
	while n < MAX_POSES and _load(ENEMY_DIR + "%s_%d.png" % [kind, n + 1]) != null:
		n += 1
	if n == 0 and _load(ENEMY_DIR + kind + ".png") != null:
		n = 1
	_cycle[kind] = n
	return n

## Where the sprite meets the ground, in texture pixels: y is the bottom edge, x is the
## middle of the BAND of rows just above it.
##
## Not the lowest row alone, which is what this measured first. On a painted tower that row
## is a 4-6px sliver — the tip of one rock in the rubble, the corner of a stair — and where
## it happens to sit says nothing about where the building stands. Earth's top tier put it
## 17% left of centre and Water's 12% right, which hangs the tower a visible step off the
## spot it occupies. Four pixels up, both are within 1% of their true centre.
##
## The band is the bottom 4% of the sprite's height, and the per-row midpoints are combined
## by MEDIAN rather than mean so that a sliver or two cannot drag the answer the way it did.
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
	var band := maxi(3, int(round(image.get_height() * 0.04)))
	var mids: Array[float] = []
	for row in range(maxi(0, y - band + 1), y + 1):
		var mid := _row_middle(image, row)
		if mid >= 0.0:
			mids.append(mid)
	mids.sort()
	var centre: float = mids[mids.size() / 2] if not mids.is_empty() \
			else image.get_width() * 0.5
	var found := Vector2(centre, y + 1)
	_anchors[path] = found
	return found

## How tall the creature actually STANDS in this texture, in pixels: from its ground row up
## to its highest ink, not the height of the file.
##
## Those were the same number while every sprite was trimmed to its own bounds. A run cycle
## is not: its frames are cut on ONE window, tall enough for the frame where a leg reaches
## furthest back, with the figure bottom-aligned inside it — that empty band above the head
## IS the bounce of the run, and it is what a fixed window buys. Scaling by the file height
## would therefore hand a fifth of the creep's drawn size to empty air, and the whole roster
## would shrink the day it was animated. Unchanged for a single trimmed sprite, where the
## first row already has ink.
static func figure_height(texture: Texture2D) -> float:
	var path := texture.resource_path
	if _heights.has(path):
		return _heights[path]
	var image := texture.get_image()
	var top := 0
	while top < image.get_height() - 1 and not _row_has_ink(image, top):
		top += 1
	var found := float(anchor(texture).y - top)
	_heights[path] = found
	return found

## Horizontal middle of one row's opaque span, or -1 if the row is empty.
static func _row_middle(image: Image, y: int) -> float:
	var first := -1
	var last := -1
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.15:
			if first < 0:
				first = x
			last = x
	return float(first + last) * 0.5 if first >= 0 else -1.0

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
