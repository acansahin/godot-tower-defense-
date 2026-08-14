extends Control
class_name UpgradeChoice
## The between-waves reward screen: three cards, keep one, it lasts the run.
##
## Drawn in code and hit-tested by rect, the same way tower_palette.gd works, rather than
## built from themed Buttons. The cards need a per-rarity border, title colour and glow,
## and doing that with StyleBoxFlat overrides is more code than drawing them — and this
## project draws everything anyway.
##
## Runs while the tree is paused (process_mode = ALWAYS in the scene), which is what lets it
## stop the run without stopping itself. It never pauses or unpauses on its own: Main owns
## that, so there is one place that knows whether the game should be running.

signal chosen(upgrade: Dictionary)

const CARD_SIZE := Vector2(360.0, 330.0)
const CARD_GAP := 30.0
const CARD_TOP := 208.0
const TITLE_Y := 130.0

var _options: Array = []
var _hover: int = -1

## Shows `options` (up to three upgrade definitions) and waits for a tap.
func show_choices(options: Array) -> void:
	_options = options
	_hover = -1
	show()
	queue_redraw()

## Rect of card `i`, centred as a row across the design viewport.
func _card_rect(i: int) -> Rect2:
	var n := _options.size()
	var total := n * CARD_SIZE.x + maxf(0.0, float(n - 1)) * CARD_GAP
	var x := (Game.SCREEN_SIZE.x - total) * 0.5 + i * (CARD_SIZE.x + CARD_GAP)
	return Rect2(Vector2(x, CARD_TOP), CARD_SIZE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hover
		_hover = _card_at(event.position)
		if _hover != was:
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _card_at(event.position)
		if i >= 0:
			Audio.play("upgrade")
			hide()
			var picked: Dictionary = _options[i]
			_options = []
			chosen.emit(picked)

func _card_at(pos: Vector2) -> int:
	for i in _options.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	# Dim the level behind, but not to black: seeing the board you are choosing for is part
	# of the decision.
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.82))
	draw_string(font, Vector2(0, TITLE_Y), "CHOOSE AN UPGRADE",
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 40, Color(1, 0.95, 0.8))
	draw_string(font, Vector2(0, TITLE_Y + 34.0), "It lasts until this run ends",
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 19, Color(0.75, 0.75, 0.82))
	for i in _options.size():
		_draw_card(_card_rect(i), _options[i], i == _hover, font)

func _draw_card(r: Rect2, up: Dictionary, hovered: bool, font: Font) -> void:
	var rarity := String(up.get("rarity", "common"))
	var col: Color = Balance.RARITY_COLORS.get(rarity, Color.WHITE)
	# Body, lifted slightly while hovered so the touch target confirms itself.
	draw_rect(r, Color(0.13, 0.13, 0.17, 0.98) if hovered else Color(0.10, 0.10, 0.13, 0.96))
	# Rarity glow, outside the border, only while hovered.
	if hovered:
		draw_rect(r.grow(5.0), Color(col.r, col.g, col.b, 0.22), false, 5.0)
	draw_rect(r, col, false, 3.0)
	# Rarity strip along the top: the fastest read on the card.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), col)

	var pad := 18.0
	var w := r.size.x - pad * 2.0
	var x := r.position.x + pad
	draw_string(font, Vector2(x, r.position.y + 62.0), String(up.get("name", "?")),
			HORIZONTAL_ALIGNMENT_CENTER, w, 30, col)
	draw_string(font, Vector2(x, r.position.y + 92.0), rarity.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(col.r, col.g, col.b, 0.75))
	# Separator, so the description reads as body text rather than more heading.
	draw_line(Vector2(x, r.position.y + 112.0), Vector2(x + w, r.position.y + 112.0),
			Color(1, 1, 1, 0.14), 2.0)
	# draw_multiline_string, not draw_string: the latter clips to `width` instead of
	# wrapping, which silently cuts the end off every description longer than a line.
	draw_multiline_string(font, Vector2(x, r.position.y + 146.0), String(up.get("desc", "")),
			HORIZONTAL_ALIGNMENT_CENTER, w, 19, 6, Color(0.90, 0.90, 0.95))
	# Unlock cards get a footer, because "you gain a new tower" is a different KIND of
	# reward from a stat bump and should not have to be inferred from the wording.
	if String(up.get("unlock", "")) != "":
		draw_string(font, Vector2(x, r.position.y + r.size.y - 22.0), "NEW TOWER",
				HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(col.r, col.g, col.b, 0.95))
