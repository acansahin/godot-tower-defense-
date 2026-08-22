extends Control
class_name ElementChoice
## Monoculture's sub-choice (GAME_STRATEGY_V2.md §6.3, BUILD NEXT #9): after picking the
## Monoculture card in upgrade_choice.gd, the player still has to say WHICH element it
## favours. Four cards instead of two, otherwise the same shape as branch_choice.gd — kept
## as its own file rather than generalizing that one, since "two branches of one element" and
## "one of four elements" only share a card-grid layout, not any of the domain logic around it.
##
## Runs while the tree is paused (process_mode = ALWAYS in the scene), same as the other two
## choice popups — Main owns pausing/unpausing.

signal chosen(element: String)

const CARD_SIZE := Vector2(260.0, 220.0)
const CARD_GAP := 24.0
const CARD_TOP := 240.0
const TITLE_Y := 150.0

var _hover: int = -1

func show_choices() -> void:
	_hover = -1
	show()
	queue_redraw()

func _card_rect(i: int) -> Rect2:
	var n := Game.TOWER_ORDER.size()
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
			chosen.emit(String(Game.TOWER_ORDER[i]))

func _card_at(pos: Vector2) -> int:
	for i in Game.TOWER_ORDER.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.85))
	draw_string(font, Vector2(0, TITLE_Y), "MONOCULTURE — CHOOSE ONE ELEMENT",
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 34, Color(1.0, 0.72, 0.22))
	draw_string(font, Vector2(0, TITLE_Y + 30.0), "+50% to it, -20% to the other three",
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 18, Color(0.75, 0.75, 0.82))
	for i in Game.TOWER_ORDER.size():
		_draw_card(_card_rect(i), String(Game.TOWER_ORDER[i]), i == _hover, font)

func _draw_card(r: Rect2, element: String, hovered: bool, font: Font) -> void:
	var col: Color = Game.ELEMENT_COLORS.get(element, Color.WHITE)
	draw_rect(r, Color(0.13, 0.13, 0.17, 0.98) if hovered else Color(0.10, 0.10, 0.13, 0.96))
	if hovered:
		draw_rect(r.grow(5.0), Color(col.r, col.g, col.b, 0.22), false, 5.0)
	draw_rect(r, col, false, 3.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), col)
	var center := r.position + r.size * 0.5
	draw_circle(center - Vector2(0, 12.0), 28.0, col)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y - 26.0),
			element.capitalize(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, col)
