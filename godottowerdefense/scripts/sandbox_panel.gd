extends Control
class_name SandboxPanel
## The testing mode: a run with the whole game unlocked, starting wherever you point it.
##
## It exists because of the progression gate. A base tower stops at Lv2 until its own
## element's avatar boss is dead, and no fusion can be bought until another one is — so
## looking at a Lv5 tower, or at any of the eleven fusions, or at the wave-40 creeps, means
## playing forty waves first, every time. This starts with all four avatars already down.
##
## Four settings, each a value cycled by tapping its row: the map, the wave to start on, the
## gold, and the lives. Drawn in code and hit-tested by rect, matching map_panel.gd.
##
## **A sandbox run writes nothing to Meta** — no stars, no best wave, no Essence. That rule
## lives in Game.sandbox and is checked in main.gd's two ending paths; without it an
## afternoon of testing would hand out the stars that gate the maps.

signal closed
signal start_requested

const ROW_HEIGHT := 62.0
const ROW_GAP := 8.0
const PANEL_W := 720.0
const HEADER_H := 104.0
## The Start and Back buttons, plus the gaps around them.
const FOOTER_H := 132.0
const ARROW_W := 46.0
const VALUE_W := 210.0

## Each row's choices. Tapping the row steps to the next one and wraps.
const WAVES: Array = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45]
const GOLDS: Array = [500, 2000, 10000, 100000, 999999]
const LIVES: Array = [20, 50, 200, 999]

var _hover: int = -1
var _close_hover: bool = false
var _start_hover: bool = false

func open() -> void:
	_hover = -1
	show()
	queue_redraw()

## Rows are built here rather than written out, so the panel and the values cannot disagree.
func _rows() -> Array:
	return [
		{"key": "SANDBOX_MAP", "value": tr(String(Game.BOARDS[Game.selected_board]["name_key"]))},
		{"key": "SANDBOX_WAVE", "value": str(Game.sandbox_wave)},
		{"key": "SANDBOX_GOLD", "value": str(Game.sandbox_gold)},
		{"key": "SANDBOX_LIVES", "value": str(Game.sandbox_lives)},
	]

func _panel_rect() -> Rect2:
	var rows := _rows().size()
	var h := HEADER_H + rows * ROW_HEIGHT + (rows - 1) * ROW_GAP + FOOTER_H
	return Rect2((Game.SCREEN_SIZE.x - PANEL_W) * 0.5,
			maxf((Game.SCREEN_SIZE.y - h) * 0.5, 8.0), PANEL_W, h)

func _row_rect(i: int) -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + 22.0, p.position.y + HEADER_H + i * (ROW_HEIGHT + ROW_GAP),
			p.size.x - 44.0, ROW_HEIGHT)

func _start_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + p.size.x * 0.5 - 140.0,
			p.position.y + p.size.y - 118.0, 280.0, 52.0)

func _close_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + p.size.x * 0.5 - 90.0,
			p.position.y + p.size.y - 58.0, 180.0, 44.0)

## Steps row `i` to its next value. `dir` is +1 or -1.
func _step(i: int, dir: int) -> void:
	match i:
		0:
			var ids: Array = Game.board_ids()
			var at := maxi(ids.find(Game.selected_board), 0)
			Game.selected_board = String(ids[posmod(at + dir, ids.size())])
		1:
			var at1 := maxi(WAVES.find(Game.sandbox_wave), 0)
			Game.sandbox_wave = int(WAVES[posmod(at1 + dir, WAVES.size())])
		2:
			var at2 := maxi(GOLDS.find(Game.sandbox_gold), 0)
			Game.sandbox_gold = int(GOLDS[posmod(at2 + dir, GOLDS.size())])
		3:
			var at3 := maxi(LIVES.find(Game.sandbox_lives), 0)
			Game.sandbox_lives = int(LIVES[posmod(at3 + dir, LIVES.size())])
	Audio.play("build")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _row_at(event.position)
		var c := _close_rect().has_point(event.position)
		var s := _start_rect().has_point(event.position)
		if h != _hover or c != _close_hover or s != _start_hover:
			_hover = h
			_close_hover = c
			_start_hover = s
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
	if _start_rect().has_point(event.position):
		Game.sandbox = true
		Audio.play("build")
		start_requested.emit()
		return
	var i := _row_at(event.position)
	if i < 0:
		return
	# The left arrow steps back, anywhere else on the row steps forward, so the whole row is
	# a target on a phone rather than two thumb-sized arrows.
	var r := _row_rect(i)
	var back := Rect2(r.position.x + r.size.x - VALUE_W - ARROW_W * 2.0 - 24.0,
			r.position.y, ARROW_W + 12.0, r.size.y)
	_step(i, -1 if back.has_point(event.position) else 1)

func _row_at(pos: Vector2) -> int:
	for i in _rows().size():
		if _row_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	var p := _panel_rect()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.88))
	draw_rect(p, Color(0.10, 0.10, 0.14, 0.98))
	draw_rect(p, Color(1.0, 0.75, 0.35, 0.45), false, 2.0)

	draw_string(font, Vector2(p.position.x, p.position.y + 46.0), tr("SANDBOX_TITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 32, Color(1.0, 0.82, 0.42))
	draw_string(font, Vector2(p.position.x, p.position.y + 74.0), tr("SANDBOX_SUBTITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 16, Color(0.74, 0.74, 0.82))

	var rows := _rows()
	for i in rows.size():
		_draw_row(i, rows[i], font)

	var sr := _start_rect()
	draw_rect(sr, Color(0.26, 0.60, 0.42) if _start_hover else Color(0.20, 0.48, 0.34))
	draw_rect(sr, Color(1, 1, 1, 0.28), false, 2.0)
	draw_string(font, Vector2(sr.position.x, sr.position.y + 34.0), tr("SANDBOX_START"),
			HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 21, Color.WHITE)

	var cr := _close_rect()
	draw_rect(cr, Color(0.22, 0.22, 0.28) if _close_hover else Color(0.17, 0.17, 0.22))
	draw_rect(cr, Color(1, 1, 1, 0.28), false, 2.0)
	draw_string(font, Vector2(cr.position.x, cr.position.y + 30.0), tr("BTN_BACK"),
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 20, Color.WHITE)

func _draw_row(i: int, d: Dictionary, font: Font) -> void:
	var r := _row_rect(i)
	var hot := _hover == i
	draw_rect(r, Color(0.18, 0.18, 0.23, 0.95) if hot else Color(0.15, 0.15, 0.19, 0.95))
	draw_rect(r, Color(1, 1, 1, 0.14), false, 2.0)
	draw_string(font, Vector2(r.position.x + 18.0, r.position.y + 39.0), tr(String(d["key"])),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - VALUE_W - 120.0, 20, Color(0.90, 0.90, 0.95))

	var vx := r.position.x + r.size.x - VALUE_W - ARROW_W - 12.0
	draw_string(font, Vector2(vx - ARROW_W - 12.0, r.position.y + 39.0), "\u25c0",
			HORIZONTAL_ALIGNMENT_CENTER, ARROW_W, 20, Color(0.70, 0.70, 0.78))
	draw_string(font, Vector2(vx, r.position.y + 39.0), String(d["value"]),
			HORIZONTAL_ALIGNMENT_CENTER, VALUE_W, 22, Color(1.0, 0.90, 0.60))
	draw_string(font, Vector2(vx + VALUE_W, r.position.y + 39.0), "\u25b6",
			HORIZONTAL_ALIGNMENT_CENTER, ARROW_W, 20, Color(0.70, 0.70, 0.78))
