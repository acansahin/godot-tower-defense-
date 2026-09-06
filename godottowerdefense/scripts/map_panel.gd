extends Control
class_name MapPanel
## The level select: which BOARD the next run plays on.
##
## A "level" in GAME_STRATEGY_V2.md §12.4 is a board and a difficulty together, so this panel
## is one half of the pair and the Difficulty button on the menu is the other. Three boards ×
## three rulesets × three stars is the §12.4 ladder: 27 stars.
##
## Drawn in code and hit-tested by rect, matching workshop.gd and how_to_play.gd. Owns no
## state beyond hover: the selection lives on Game.selected_board and the stars live in Meta,
## so what this draws and what a run actually plays cannot drift apart.
##
## LOCKED BOARDS ARE DRAWN, NOT HIDDEN. The star requirement is the reason to play the board
## you already have, so it has to be visible before it is met — a panel that only lists what
## is already unlocked shows the player nothing to aim at.

signal closed

const ROW_HEIGHT := 96.0
const ROW_GAP := 10.0
const PANEL_W := 960.0
## The road-shape thumbnail on the left of each row. Drawn at half the file's own 256x144
## (tools/board_thumb.py) so the mip chain has something real to sample.
const THUMB_W := 128.0
const THUMB_H := 72.0
## Between the thumbnail and the text, and between the text and the Select button.
const TEXT_GAP := 14.0
## Above the first row: the title, the subtitle and the star wallet.
const HEADER_H := 96.0
## Below the last row: the Back button, plus the gap above it and the margin under it.
const FOOTER_H := 92.0
const PICK_W := 150.0
## One difficulty's star line. Three of them sit side by side under the description, so this
## has to hold the longest DIFF_* string in any shipped language plus three stars.
const STAR_COL_W := 165.0
const PICK_H := 54.0
## Smallest gap left between the panel and the top or bottom of the screen.
const MARGIN := 8.0

var _hover: int = -1     ## Index of the row whose button is hovered (-1 = none).
var _close_hover: bool = false
var _thumb_cache: Dictionary = {}

## The road-shape thumbnail for `board_id`, or null if its row has no `thumb`.
func _thumb(board_id: String) -> Texture2D:
	var path := String(Game.BOARDS.get(board_id, {}).get("thumb", ""))
	if path == "":
		return null
	if not _thumb_cache.has(path):
		_thumb_cache[path] = load(path) as Texture2D
	return _thumb_cache[path] as Texture2D

func open() -> void:
	_hover = -1
	show()
	queue_redraw()

## How much a row has to shrink for the list to fit on screen, 1.0 when it already does.
##
## The panel grows with the board count and the screen does not. At four boards the fixed
## 96px row fitted with 100px to spare; at SIX it put the Back button 94px BELOW the bottom
## edge, which is the How to Play trap again — a panel the player cannot leave. Re-tuning the
## constants down would buy exactly one more board, so everything inside a row is drawn as a
## fraction of this instead and the ladder can take a seventh without anyone touching a
## number. The floor stops it shrinking into illegibility; a roster big enough to hit it
## wants a scrolling list, not a smaller font.
func _row_scale() -> float:
	var rows := maxi(Game.board_ids().size(), 1)
	var body := rows * ROW_HEIGHT + float(rows - 1) * ROW_GAP
	var room := Game.SCREEN_SIZE.y - MARGIN * 2.0 - HEADER_H - FOOTER_H
	return clampf(room / body, 0.62, 1.0)

## Grows with the rows rather than standing at a fixed height — same reasoning as
## workshop.gd's `_panel_rect()`, where a fixed panel walked the last row into the Back
## button and the Back button silently ate its click.
func _panel_rect() -> Rect2:
	var rows := maxi(Game.board_ids().size(), 1)
	var body := (rows * ROW_HEIGHT + float(rows - 1) * ROW_GAP) * _row_scale()
	var h := HEADER_H + body + FOOTER_H
	return Rect2((Game.SCREEN_SIZE.x - PANEL_W) * 0.5,
			maxf((Game.SCREEN_SIZE.y - h) * 0.5, MARGIN), PANEL_W, h)

func _row_rect(i: int) -> Rect2:
	var p := _panel_rect()
	var k := _row_scale()
	return Rect2(p.position.x + 22.0,
			p.position.y + HEADER_H + i * (ROW_HEIGHT + ROW_GAP) * k,
			p.size.x - 44.0, ROW_HEIGHT * k)

## The Select button inside row `i`, right-aligned.
func _pick_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	var ph := PICK_H * _row_scale()
	return Rect2(r.position.x + r.size.x - PICK_W - 12.0,
			r.position.y + (r.size.y - ph) * 0.5, PICK_W, ph)

func _close_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + p.size.x * 0.5 - 90.0,
			p.position.y + p.size.y - 62.0, 180.0, 46.0)

## True when the player has earned enough stars anywhere to open `board_id`.
func _unlocked(board_id: String) -> bool:
	# A sandbox run is for testing every map, so the gates do not apply to it.
	return Game.sandbox or Meta.total_stars() >= int(Game.BOARDS[board_id]["star_gate"])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _pick_at(event.position)
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
	var i := _pick_at(event.position)
	if i < 0:
		return
	var id := String(Game.board_ids()[i])
	# Feedback either way: a silent no-op on a tap that looks legal reads as a broken button.
	if _unlocked(id):
		Game.selected_board = id
		Audio.play("build")
	else:
		Audio.play("denied")
	queue_redraw()

func _pick_at(pos: Vector2) -> int:
	for i in Game.board_ids().size():
		if _pick_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	var p := _panel_rect()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.88))
	draw_rect(p, Color(0.10, 0.10, 0.14, 0.98))
	draw_rect(p, Color(1, 1, 1, 0.20), false, 2.0)

	draw_string(font, Vector2(p.position.x, p.position.y + 46.0), tr("MAP_TITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 34, Color(1, 0.95, 0.8))
	draw_string(font, Vector2(p.position.x, p.position.y + 76.0), tr("MAP_SUBTITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 17, Color(0.72, 0.72, 0.80))
	# Star wallet, top-right — the currency every lock on this panel is priced in.
	draw_string(font, Vector2(p.position.x - 22.0, p.position.y + 46.0),
			tr("MAP_STAR_TOTAL") % Meta.total_stars(), HORIZONTAL_ALIGNMENT_RIGHT, p.size.x, 22,
			Color(1.00, 0.86, 0.42))

	var ids: Array = Game.board_ids()
	for i in ids.size():
		_draw_row(i, String(ids[i]), font)

	var cr := _close_rect()
	draw_rect(cr, Color(0.22, 0.22, 0.28) if _close_hover else Color(0.17, 0.17, 0.22))
	draw_rect(cr, Color(1, 1, 1, 0.28), false, 2.0)
	draw_string(font, Vector2(cr.position.x, cr.position.y + 31.0), tr("BTN_BACK"),
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 21, Color.WHITE)

func _draw_row(i: int, id: String, font: Font) -> void:
	var r := _row_rect(i)
	var k := _row_scale()
	var def: Dictionary = Game.BOARDS[id]
	var open := _unlocked(id)
	var chosen := Game.selected_board == id

	draw_rect(r, Color(0.17, 0.20, 0.17, 0.95) if chosen else Color(0.15, 0.15, 0.19, 0.95))
	draw_rect(r, Color(0.55, 0.85, 0.55, 0.55) if chosen else Color(1, 1, 1, 0.12), false, 2.0)

	# The road's SHAPE is what tells the three maps apart -- a spiral, an S and a long
	# wander -- and it is the one thing a name and a sentence cannot show. A locked board is
	# dimmed rather than hidden: seeing the shape you have not earned is the reason to earn it.
	var thumb := _thumb(id)
	var tx := r.position.x + 12.0
	if thumb != null:
		var tr2 := Rect2(tx, r.position.y + (r.size.y - THUMB_H * k) * 0.5,
				THUMB_W * k, THUMB_H * k)
		draw_texture_rect(thumb, tr2, false,
				Color.WHITE if open else Color(0.45, 0.45, 0.50))
		draw_rect(tr2, Color(1, 1, 1, 0.22), false, 1.0)

	# Text box derived, not written down: at a literal 460 the descriptions clipped mid-word
	# ("...punish a g"), and a literal would go stale again the moment any of the columns move.
	var text_x := tx + (THUMB_W * k + TEXT_GAP if thumb != null else 4.0)
	var text_w := (r.position.x + r.size.x - PICK_W - 12.0 - TEXT_GAP) - text_x
	var name_col := Color(1, 0.95, 0.85) if open else Color(0.55, 0.55, 0.62)
	draw_string(font, Vector2(text_x, r.position.y + 30.0 * k), tr(String(def["name_key"])),
			HORIZONTAL_ALIGNMENT_LEFT, text_w, int(22.0 * k), name_col)
	draw_string(font, Vector2(text_x, r.position.y + 54.0 * k), tr(String(def["desc_key"])),
			HORIZONTAL_ALIGNMENT_LEFT, text_w, int(15.0 * k),
			Color(0.78, 0.78, 0.86) if open else Color(0.48, 0.48, 0.55))

	# One star line per difficulty, so the row answers "what is left to do here" rather than
	# only "have I beaten it". A level never won shows three hollow stars, not a blank.
	var sx := text_x
	var sy := r.position.y + 80.0 * k
	for rid in Balance.RULESETS.keys():
		var got := Meta.stars_for(id, String(rid))
		# Full difficulty name, not `.left(3)`: three letters gave "Nor / Eas / Har" in English
		# and "Nor / Kol / Zor" in Turkish, which is a puzzle rather than a label.
		draw_string(font, Vector2(sx, sy),
				"%s %s%s" % [tr("DIFF_" + String(rid).to_upper()),
						"★".repeat(got), "☆".repeat(3 - got)],
				HORIZONTAL_ALIGNMENT_LEFT, STAR_COL_W * k - 10.0, int(14.0 * k),
				Color(1.00, 0.86, 0.42) if got > 0 else Color(0.50, 0.50, 0.56))
		sx += STAR_COL_W * k

	var br := _pick_rect(i)
	var hovered := _hover == i
	var label := tr("MAP_SELECT")
	var col := Color(0.20, 0.48, 0.34) if not hovered else Color(0.26, 0.60, 0.42)
	var text_col := Color.WHITE
	if chosen:
		label = tr("MAP_CHOSEN")
		col = Color(0.26, 0.42, 0.30)
	elif not open:
		# The requirement, not the word "locked": a number the player can work toward.
		label = tr("MAP_LOCKED") % int(def["star_gate"])
		col = Color(0.24, 0.20, 0.20)
		text_col = Color(0.92, 0.72, 0.50)
	draw_rect(br, col)
	draw_rect(br, Color(1, 1, 1, 0.26), false, 2.0)
	draw_string(font, Vector2(br.position.x, br.position.y + 33.0 * k), label,
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x, int(18.0 * k), text_col)
