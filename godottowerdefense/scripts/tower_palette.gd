extends Control
## The tower palette: one slim column in the top-right corner, a painted icon and a price per
## tower. Pressing a slot emits `drag_started`; Main then follows the pointer with a ghost and
## places the tower where it is dropped, or where the next tap lands.
##
## It replaced a 200px panel down the whole right-hand side, titled "Towers", with a colour
## swatch and a name per slot laid out in two columns. Four towers filled two rows of it and
## the rest was an empty dark slab over the board. The icon is the Lv1 sprite the tower will
## actually be on the board, which is why the name went: the picture already says which tower
## it is, and says it in the terms the board uses.
##
## POSITION AND SIZE COME FROM Game.PALETTE_RECT, not from Main.tscn. The placement rule reads
## the same rect to keep towers out from under the column, so a column moved in the scene and
## not in Game would leave buildable ground under it again, or dead ground beside it.
##
## Main tells this panel which slot is ARMED, and it is drawn with a bright border. Tapping to
## place is otherwise a mode with no indicator: the ghost sits out on the board where a thumb
## is not, so the palette is the one place a player looks to see what they picked.
##
## The slot is 68x84, which arrives at roughly 34x42 CSS px on a phone (the board is drawn at
## about half scale there). That is a little under the old 87x80 slot and was the price of
## the smaller panel.
##
## The roster is Run.buildable_towers(), which today is exactly Game.TOWER_ORDER. A fifth
## tower needs PALETTE_RECT grown by one slot (84 + 6px): the column is drawn for as many
## towers as there are, but only the rect keeps the board clear underneath.

signal drag_started(id: String)

const Sprites := preload("res://scripts/sprites.gd")

const PAD := 8.0
const SLOT := Vector2(68, 84)
const GAP := 6.0
## The icon's box inside a slot. The painted towers are much taller than wide, so the icon is
## fitted to this box by its longer side rather than stretched.
const ICON := 60.0
const COST_SIZE := 15

var _gold: int = 0
var _armed: String = ""
var _strip: StyleBoxFlat
var _armed_box: StyleBoxFlat

func _ready() -> void:
	position = Game.PALETTE_RECT.position
	size = Game.PALETTE_RECT.size
	# The tower sheets are cut at ~2x their size on the board and this draws them at a third
	# of that again; without mipmaps the downscale sparkles (see CLAUDE.md, Known traps).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_strip = StyleBoxFlat.new()
	_strip.bg_color = Color(0.05, 0.05, 0.07, 0.55)
	_strip.set_corner_radius_all(10)
	_armed_box = StyleBoxFlat.new()
	_armed_box.bg_color = Color(0.98, 0.92, 0.55, 0.16)
	_armed_box.border_color = Color(1.0, 0.93, 0.50, 0.95)
	_armed_box.set_border_width_all(3)
	_armed_box.set_corner_radius_all(8)
	# An unlock adds a slot mid-run, and the palette otherwise repaints only on a gold
	# change — which might not come for seconds, leaving the reward invisible as it lands.
	Run.roster_changed.connect(queue_redraw)

func set_gold(value: int) -> void:
	_gold = value
	queue_redraw()

## Which tower is being placed right now, or "" for none. Set by Main, which owns that state.
func set_armed(id: String) -> void:
	if _armed == id:
		return
	_armed = id
	queue_redraw()

func _slot_rect(index: int) -> Rect2:
	return Rect2(Vector2(PAD, PAD + float(index) * (SLOT.y + GAP)), SLOT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var ids: Array = Run.buildable_towers()
		for i in ids.size():
			if _slot_rect(i).has_point(event.position):
				drag_started.emit(ids[i])
				return

func _draw() -> void:
	var ids: Array = Run.buildable_towers()
	if ids.is_empty():
		return
	# The backing strip hugs the slots rather than the whole rect, so there is never an empty
	# dark area over the board.
	var last := _slot_rect(ids.size() - 1)
	draw_style_box(_strip, Rect2(Vector2.ZERO, Vector2(size.x, last.end.y + PAD)))
	var font := get_theme_default_font()
	for i in ids.size():
		_draw_slot(_slot_rect(i), String(ids[i]), font)

## One slot: the tower's own Lv1 sprite, and its price underneath. A tower you cannot afford
## is dimmed and priced in red rather than hidden, so the palette never changes shape.
func _draw_slot(r: Rect2, id: String, font: Font) -> void:
	var d: Dictionary = Game.TOWER_DEFS[id]
	var cost: int = int(d["cost"])
	var affordable := _gold >= cost
	if id == _armed:
		draw_style_box(_armed_box, r)
	var icon_centre := r.position + Vector2(r.size.x * 0.5, 4.0 + ICON * 0.5)
	var tint := Color.WHITE if affordable else Color(1, 1, 1, 0.40)
	var tex := Sprites.tower(id, 1)
	if tex != null:
		var tex_size := tex.get_size()
		var fit := ICON / maxf(tex_size.x, tex_size.y)
		var drawn := tex_size * fit
		draw_texture_rect(tex, Rect2(icon_centre - drawn * 0.5, drawn), false, tint)
	else:
		# Unpainted: the element colour the board's code art uses.
		var c: Color = d["color"]
		draw_circle(icon_centre, 20.0, Color(c.r, c.g, c.b, c.a * tint.a))
		draw_arc(icon_centre, 20.0, 0.0, TAU, 24, Color(0, 0, 0, 0.4 * tint.a), 2.0, true)
	var cost_col := Color(1, 0.9, 0.4) if affordable else Color(0.95, 0.45, 0.45)
	draw_string(font, Vector2(r.position.x, r.end.y - 6.0), "%d" % cost,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, COST_SIZE, cost_col)
