extends Control
class_name HowToPlay
## The rules screen, in three tabs: Basics, Elements, Fusions.
##
## It replaces a single 21-line Label that had gone stale in every paragraph it had — it still
## described the Lv3 "pick a branch" system that fusion replaced, a sell "x" that moved into
## the tower panel, and a 20-wave run that is 50 waves now (Balance.STANDARD_WAVES).
##
## The FUSIONS tab is the reason this is code and not a Label: it draws each combination's own
## painted sprite next to what that combination does, so the eleven rows of Game.FUSIONS are
## something you can recognise on the board rather than a list of names. It is built BY
## ITERATING `Game.FUSIONS`, so a twelfth row appears here with no edit to this file — only its
## `FUSION_DESC_<NAME>` key has to exist in assets/i18n/strings.csv.
##
## Drawn in _draw() and hit-tested against Rect2s, matching workshop.gd and tower_panel.gd.
## Every string goes through tr(); nothing here is written in a language.

signal closed

const Sprites := preload("res://scripts/sprites.gd")

const PANEL_W := 1120.0
const PANEL_H := 664.0
## Title plus the tab row.
const HEADER_H := 112.0
## The Back button, plus the gap above it and the margin below.
const FOOTER_H := 76.0
const PAD := 24.0

const TAB_W := 190.0
const TAB_H := 40.0
const TAB_GAP := 8.0

const BODY_SIZE := 16
const SMALL_SIZE := 14
const LINE_GAP := 9.0

const BG := Color(0.10, 0.10, 0.14, 0.98)
const SCRIM := Color(0.03, 0.03, 0.06, 0.88)
const EDGE := Color(1, 1, 1, 0.20)
const TEXT := Color(0.88, 0.88, 0.91)
const TEXT_DIM := Color(0.66, 0.66, 0.72)
const GOLD := Color(1.0, 0.95, 0.8)
const TAB_ON := Color(0.20, 0.20, 0.26)
const TAB_OFF := Color(0.13, 0.13, 0.17)

## The Basics tab, in order. One key per line so the CSV never needs a quoted newline and so
## the indented pair under BASIC_GATE_1 can be laid out differently from the rest.
const BASIC_KEYS: Array = ["BASIC_1", "BASIC_2", "BASIC_3", "BASIC_4", "BASIC_5", "BASIC_6"]
const GATE_INDENTED: Array = ["BASIC_GATE_2", "BASIC_GATE_3"]

var _page: int = 0
var _hover_tab: int = -1
var _close_hover: bool = false

func open() -> void:
	_page = 0
	_hover_tab = -1
	_close_hover = false
	show()
	queue_redraw()

## Opens a chosen tab. Used by the `--show-how:N` harness; the player gets here by clicking.
func show_page(index: int) -> void:
	_page = clampi(index, 0, 2)
	queue_redraw()

func _panel_rect() -> Rect2:
	return Rect2((Game.SCREEN_SIZE.x - PANEL_W) * 0.5, (Game.SCREEN_SIZE.y - PANEL_H) * 0.5,
			PANEL_W, PANEL_H)

func _tab_rect(i: int) -> Rect2:
	var p := _panel_rect()
	var total := 3.0 * TAB_W + 2.0 * TAB_GAP
	return Rect2(p.position.x + (p.size.x - total) * 0.5 + i * (TAB_W + TAB_GAP),
			p.position.y + 62.0, TAB_W, TAB_H)

func _close_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + p.size.x * 0.5 - 90.0,
			p.position.y + p.size.y - 60.0, 180.0, 44.0)

## Where a page may draw: everything between the tab row and the Back button.
func _content_rect() -> Rect2:
	var p := _panel_rect()
	return Rect2(p.position.x + PAD, p.position.y + HEADER_H,
			p.size.x - PAD * 2.0, p.size.y - HEADER_H - FOOTER_H)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := _tab_at(event.position)
		var c := _close_rect().has_point(event.position)
		if t != _hover_tab or c != _close_hover:
			_hover_tab = t
			_close_hover = c
			queue_redraw()
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _close_rect().has_point(event.position):
		Audio.play("denied")
		hide()
		closed.emit()
		return
	var t := _tab_at(event.position)
	if t >= 0 and t != _page:
		_page = t
		Audio.play("build")
		queue_redraw()

func _tab_at(pos: Vector2) -> int:
	for i in 3:
		if _tab_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	var p := _panel_rect()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), SCRIM)
	draw_rect(p, BG)
	draw_rect(p, EDGE, false, 2.0)

	draw_string(font, Vector2(p.position.x, p.position.y + 44.0), tr("HOW_TITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 30, GOLD)

	var labels := [tr("TAB_BASICS"), tr("TAB_ELEMENTS"), tr("TAB_FUSIONS")]
	for i in 3:
		var r := _tab_rect(i)
		var on := i == _page
		draw_rect(r, TAB_ON if on or i == _hover_tab else TAB_OFF)
		draw_rect(r, EDGE if on else Color(1, 1, 1, 0.10), false, 2.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 27.0), String(labels[i]),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, GOLD if on else TEXT_DIM)

	match _page:
		1: _draw_elements(font)
		2: _draw_fusions(font)
		_: _draw_basics(font)

	var cr := _close_rect()
	draw_rect(cr, Color(0.22, 0.22, 0.28) if _close_hover else Color(0.17, 0.17, 0.22))
	draw_rect(cr, Color(1, 1, 1, 0.28), false, 2.0)
	draw_string(font, Vector2(cr.position.x, cr.position.y + 30.0), tr("BTN_BACK"),
			HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 20, Color.WHITE)

## Draws wrapped text at `y` within `rect` and returns the y BELOW it. Every page stacks with
## this rather than with hand-counted line positions, so a translation that runs one line
## longer pushes what follows down instead of drawing on top of it.
func _flow(font: Font, rect: Rect2, y: float, text: String, size: int, col: Color,
		indent: float = 0.0) -> float:
	var w := rect.size.x - indent
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y
	draw_multiline_string(font, Vector2(rect.position.x + indent, y + float(size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, col)
	return y + h + LINE_GAP

func _draw_basics(font: Font) -> void:
	var rect := _content_rect()
	var y := rect.position.y
	for k in BASIC_KEYS:
		y = _flow(font, rect, y, "•  " + tr(String(k)), BODY_SIZE, TEXT)
	y += 6.0
	draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y),
			Color(1, 1, 1, 0.12), 1.0)
	y += 14.0
	y = _flow(font, rect, y, tr("BASIC_GATE_TITLE"), 19, GOLD)
	y = _flow(font, rect, y, tr("BASIC_GATE_1"), BODY_SIZE, TEXT)
	for k in GATE_INDENTED:
		y = _flow(font, rect, y, "•  " + tr(String(k)), BODY_SIZE, Color(0.62, 0.90, 1.00), 28.0)
	y = _flow(font, rect, y, tr("BASIC_GATE_4"), BODY_SIZE, TEXT)

func _draw_elements(font: Font) -> void:
	var rect := _content_rect()
	var y := rect.position.y
	y = _flow(font, rect, y, tr("ELEM_WHEEL"), 22, GOLD)
	y = _flow(font, rect, y, tr("ELEM_RULE"), BODY_SIZE, TEXT)
	y = _flow(font, rect, y, tr("ELEM_BEST"), BODY_SIZE, TEXT)
	y = _flow(font, rect, y, tr("ELEM_IMMUNE"), BODY_SIZE, TEXT_DIM)
	y += 10.0

	# One card per buildable element, in the palette's own order so the two screens agree.
	var n := Game.TOWER_ORDER.size()
	var cw := (rect.size.x - float(n - 1) * 12.0) / float(n)
	for i in n:
		var el := String(Game.TOWER_ORDER[i])
		var cell := Rect2(rect.position.x + float(i) * (cw + 12.0), y, cw,
				rect.position.y + rect.size.y - y)
		_draw_card(font, cell, el, 2, String(Game.TOWER_DEFS[el]["name"]),
				[el], tr("ELEM_DESC_" + el.to_upper()), Game.ELEMENT_COLORS[el], true)

func _draw_fusions(font: Font) -> void:
	var rect := _content_rect()
	var y := rect.position.y
	y = _flow(font, rect, y, tr("FUSION_INTRO_1"), SMALL_SIZE, TEXT)
	y = _flow(font, rect, y, tr("FUSION_INTRO_2"), SMALL_SIZE, TEXT_DIM)
	y += 4.0

	# Two columns, filled in Game.FUSIONS' own order: six duals, four triples, then Pure.
	var keys := Game.FUSIONS.keys()
	var cols := 2
	var cw := (rect.size.x - 20.0) / float(cols)
	var rows := int(ceil(float(keys.size()) / float(cols)))
	var ch := minf((rect.position.y + rect.size.y - y) / float(rows), 70.0)
	for i in keys.size():
		var key := String(keys[i])
		var def: Dictionary = Game.FUSIONS[key]
		var elements := key.split("+")
		var name := String(def.get("name", key))
		var cell := Rect2(rect.position.x + float(i % cols) * (cw + 20.0),
				y + float(i / cols) * ch, cw, ch)
		_draw_card(font, cell, name.to_lower().replace(" ", "_"),
				int(Balance.FUSED_LEVELS.get(elements.size(), Balance.MAX_LEVEL)), name,
				Array(elements), tr("FUSION_DESC_" + name.to_upper().replace(" ", "_")),
				Color(def.get("color", Color.WHITE)), false)

## One entry: its painted sprite, its name, the elements that make it, its level, and what it
## does. `art` is the sprite key -- an element for a base tower, the combination's first name
## for a fusion, which is exactly what Tower.art_key() derives. An unpainted combination has
## no files, Sprites.tower() returns null and the coloured disc stands in for it, the same
## fallback the board itself uses.
##
## Two layouts, because the two tabs have opposite shapes to fill. `tall` STACKS the sprite
## over centred text: the Elements tab has four cards across the full height of the page, so
## a row layout there leaves the bottom two thirds empty and squeezes the text into a third
## of the width. The Fusions tab has eleven cards in two columns and no vertical room at all,
## so it puts the sprite beside the text instead.
func _draw_card(font: Font, cell: Rect2, art: String, level: int, name: String,
		elements: Array, desc: String, tint: Color, tall: bool) -> void:
	var icon := minf(cell.size.y - 8.0, 128.0 if tall else 56.0)
	if tall:
		icon = minf(icon, cell.size.x * 0.8)
	var tex: Texture2D = Sprites.tower(art, level)
	var icon_pos := Vector2(cell.position.x + (cell.size.x - icon) * 0.5, cell.position.y) 			if tall else Vector2(cell.position.x, cell.position.y + 2.0)
	if tex != null:
		var sc := minf(icon / float(tex.get_width()), icon / float(tex.get_height()))
		var dst := Vector2(float(tex.get_width()) * sc, float(tex.get_height()) * sc)
		draw_texture_rect(tex, Rect2(icon_pos + (Vector2(icon, icon) - dst) * 0.5, dst), false)
	else:
		draw_circle(icon_pos + Vector2(icon, icon) * 0.5, icon * 0.32, tint)

	var align := HORIZONTAL_ALIGNMENT_CENTER if tall else HORIZONTAL_ALIGNMENT_LEFT
	var tx := cell.position.x if tall else cell.position.x + icon + 12.0
	var tw := cell.size.x if tall else cell.size.x - icon - 12.0
	var y := cell.position.y + (icon + 26.0 if tall else 18.0)
	draw_string(font, Vector2(tx, y), name, align, tw, 17, tint)

	# The recipe, as one dot per element in the tower's own colours, then its fixed level. On
	# a stacked card the name is centred, so the dots are measured off the drawn text width
	# rather than off the cell's left edge.
	var name_w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var run := float(elements.size()) * 14.0
	var dot := Vector2(tx + (tw + name_w) * 0.5 + 12.0 if tall
			else tx + name_w + 14.0, y - 5.0)
	if tall:
		dot.x -= run * 0.5 - 7.0
	for e in elements:
		draw_circle(dot, 5.0, Game.ELEMENT_COLORS.get(String(e), Color.WHITE))
		draw_circle(dot, 5.0, Color(0, 0, 0, 0.35), false, 1.0)
		dot.x += 14.0
	if elements.size() > 1:
		draw_string(font, Vector2(dot.x + 4.0, y), tr("PANEL_LV") % level,
				HORIZONTAL_ALIGNMENT_LEFT, tw, SMALL_SIZE, TEXT_DIM)

	draw_multiline_string(font, Vector2(tx, y + 22.0), desc, align, tw, SMALL_SIZE, -1, TEXT_DIM)
