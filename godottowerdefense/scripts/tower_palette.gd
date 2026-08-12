extends Control
## Top-right toolbar listing every tower in Game.TOWER_ORDER with its colour and
## cost. Pressing a slot emits `drag_started`; Main then drags a ghost to a grid
## cell to place it.
##
## Laid out as 2 columns x 4 rows rather than one tall column. Eight slots stacked
## in a single column cannot each be tall enough to hit with a thumb — the board is
## drawn at roughly half scale on a phone, so the old 38px-tall slot arrived as ~19
## CSS px. Two columns buy the height back.

signal drag_started(id: String)

const SLOT_SIZE := Vector2(87, 80)
const SLOT_STEP := Vector2(93, 86)  ## Slot pitch (size + gutter).
const SLOT_ORIGIN := Vector2(6, 36) ## Top-left of the first slot, below the header.
const COLUMNS := 2

var _gold: int = 0

func set_gold(value: int) -> void:
	_gold = value
	queue_redraw()

func _slot_rect(index: int) -> Rect2:
	var col := index % COLUMNS
	@warning_ignore("integer_division")  # deliberate: this is a row index
	var row := index / COLUMNS
	return Rect2(SLOT_ORIGIN + Vector2(col * SLOT_STEP.x, row * SLOT_STEP.y), SLOT_SIZE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var ids: Array = Game.TOWER_ORDER
		for i in ids.size():
			if _slot_rect(i).has_point(event.position):
				drag_started.emit(ids[i])
				return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.40))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18), false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(10, 26), "Towers", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
	var ids: Array = Game.TOWER_ORDER
	for i in ids.size():
		_draw_slot(_slot_rect(i), ids[i], font)

## One slot: colour swatch on top, name and cost stacked underneath. Both strings are
## centred across the slot's full width and clipped to it, so a long name ("Lightning")
## stays inside its box instead of bleeding into the neighbouring column.
func _draw_slot(r: Rect2, id: String, font: Font) -> void:
	var d: Dictionary = Game.TOWER_DEFS[id]
	var cost: int = int(d["cost"])
	var affordable := _gold >= cost
	draw_rect(r, Color(0.20, 0.20, 0.24, 0.85) if affordable else Color(0.22, 0.12, 0.12, 0.7))
	draw_rect(r, Color(1, 1, 1, 0.22), false, 2.0)
	# Element colour swatch, centred near the top.
	var c := r.position + Vector2(r.size.x * 0.5, 26.0)
	draw_circle(c, 16.0, d["color"])
	draw_arc(c, 16.0, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 2.0, true)
	# Name + cost, centred under the swatch.
	var text_w := r.size.x - 6.0
	var text_x := r.position.x + 3.0
	draw_string(font, Vector2(text_x, r.position.y + 58.0), str(d["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, text_w, 14, Color.WHITE)
	var cost_col := Color(1, 0.9, 0.4) if affordable else Color(0.9, 0.45, 0.45)
	draw_string(font, Vector2(text_x, r.position.y + 74.0), "%d g" % cost,
			HORIZONTAL_ALIGNMENT_CENTER, text_w, 14, cost_col)
