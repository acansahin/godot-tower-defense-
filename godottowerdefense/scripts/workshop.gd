extends Control
class_name Workshop
## The between-runs spending screen: turn Essence into permanent Workshop levels.
##
## Reached from the title screen, so it is never in the way of a run. Drawn in code and
## hit-tested by rect, matching upgrade_choice.gd and tower_palette.gd.
##
## Owns no state: every number on screen is read live from Meta, and a purchase is a call to
## Meta.buy(). That is what keeps "what the UI shows" and "what the save contains" from
## being two things that can disagree.

signal closed

const ROW_HEIGHT := 74.0
const ROW_GAP := 10.0
const PANEL := Rect2(240.0, 96.0, 800.0, 528.0)
const BUY_W := 150.0
const BUY_H := 54.0

var _hover: int = -1     ## Index of the row whose Buy button is hovered (-1 = none).
var _close_hover: bool = false

func open() -> void:
	_hover = -1
	show()
	queue_redraw()

func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 22.0, PANEL.position.y + 96.0 + i * (ROW_HEIGHT + ROW_GAP),
			PANEL.size.x - 44.0, ROW_HEIGHT)

## The Buy button inside row `i`, right-aligned.
func _buy_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.position.x + r.size.x - BUY_W - 12.0,
			r.position.y + (ROW_HEIGHT - BUY_H) * 0.5, BUY_W, BUY_H)

func _close_rect() -> Rect2:
	return Rect2(PANEL.position.x + PANEL.size.x * 0.5 - 90.0,
			PANEL.position.y + PANEL.size.y - 62.0, 180.0, 46.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _buy_at(event.position)
		var c := _close_rect().has_point(event.position)
		if h != _hover or c != _close_hover:
			_hover = h
			_close_hover = c
			queue_redraw()
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _close_rect().has_point(event.position):
		Audio.play("sell")
		hide()
		closed.emit()
		return
	var i := _buy_at(event.position)
	if i < 0:
		return
	var id := String((Game.WORKSHOP_DEFS[i] as Dictionary)["id"])
	# Feedback either way: a silent no-op on a tap that looks legal reads as a broken button.
	if Meta.buy(id):
		Audio.play("upgrade")
	else:
		Audio.play("denied")
	queue_redraw()

func _buy_at(pos: Vector2) -> int:
	for i in Game.WORKSHOP_DEFS.size():
		if _buy_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.88))
	draw_rect(PANEL, Color(0.10, 0.10, 0.14, 0.98))
	draw_rect(PANEL, Color(1, 1, 1, 0.20), false, 2.0)

	draw_string(font, Vector2(PANEL.position.x, PANEL.position.y + 46.0), "WORKSHOP",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 34, Color(1, 0.95, 0.8))
	draw_string(font, Vector2(PANEL.position.x, PANEL.position.y + 76.0),
			"Permanent upgrades — they apply to every run from now on",
			HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 17, Color(0.72, 0.72, 0.80))
	# Wallet, top-right of the panel.
	draw_string(font, Vector2(PANEL.position.x - 22.0, PANEL.position.y + 46.0),
			"%d Essence" % Meta.essence, HORIZONTAL_ALIGNMENT_RIGHT, PANEL.size.x, 22,
			Color(0.62, 0.90, 1.00))

	for i in Game.WORKSHOP_DEFS.size():
		_draw_row(i, Game.WORKSHOP_DEFS[i], font)

	var cr := _close_rect()
	draw_rect(cr, Color(0.22, 0.22, 0.28) if _close_hover else Color(0.17, 0.17, 0.22))
	draw_rect(cr, Color(1, 1, 1, 0.28), false, 2.0)
	draw_string(font, Vector2(cr.position.x, cr.position.y + 31.0), "Back",
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 21, Color.WHITE)

func _draw_row(i: int, d: Dictionary, font: Font) -> void:
	var r := _row_rect(i)
	var id := String(d["id"])
	var lv := Meta.level_of(id)
	var maxed := lv >= int(d.get("max_level", 1))
	var cost := Meta.next_cost(id)
	var affordable := Meta.can_buy(id)

	draw_rect(r, Color(0.15, 0.15, 0.19, 0.95))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
	draw_string(font, Vector2(r.position.x + 16.0, r.position.y + 30.0), String(d["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, 320.0, 22, Color(1, 0.95, 0.85))
	draw_string(font, Vector2(r.position.x + 16.0, r.position.y + 55.0), String(d["desc"]),
			HORIZONTAL_ALIGNMENT_LEFT, 420.0, 16, Color(0.78, 0.78, 0.86))

	# Level pips: the fastest read of "how far along am I", and they make the max obvious
	# without a "3 / 10" the player has to parse.
	var max_lv := int(d.get("max_level", 1))
	var px := r.position.x + 452.0
	var py := r.position.y + ROW_HEIGHT * 0.5
	for k in max_lv:
		var filled := k < lv
		var c := Vector2(px + k * 13.0, py)
		draw_circle(c, 5.0, Color(0.45, 0.85, 1.0) if filled else Color(1, 1, 1, 0.16))
		if filled:
			draw_arc(c, 5.0, 0.0, TAU, 10, Color(0, 0, 0, 0.35), 1.5, true)

	var br := _buy_rect(i)
	var hovered := _hover == i
	var label := "MAX"
	var col := Color(0.30, 0.30, 0.36)
	if not maxed:
		label = "%d ✦" % cost
		if affordable:
			col = Color(0.20, 0.48, 0.34) if not hovered else Color(0.26, 0.60, 0.42)
		else:
			col = Color(0.30, 0.18, 0.18)
	draw_rect(br, col)
	draw_rect(br, Color(1, 1, 1, 0.26), false, 2.0)
	var text_col := Color(0.62, 0.62, 0.68)
	if not maxed:
		text_col = Color.WHITE if affordable else Color(0.95, 0.55, 0.55)
	draw_string(font, Vector2(br.position.x, br.position.y + 35.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 21, text_col)
