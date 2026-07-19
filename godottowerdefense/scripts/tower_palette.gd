extends Control
## Top-right toolbar listing every tower in Game.TOWER_ORDER with its colour and
## cost. Pressing a slot emits `drag_started`; Main then drags a ghost to a grid
## cell to place it.

signal drag_started(id: String)

var _gold: int = 0

func set_gold(value: int) -> void:
	_gold = value
	queue_redraw()

func _slot_rect(index: int) -> Rect2:
	return Rect2(8, 30 + index * 42, size.x - 16, 38)

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
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18), false, 1.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(10, 22), "Towers", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
	var ids: Array = Game.TOWER_ORDER
	for i in ids.size():
		_draw_slot(_slot_rect(i), ids[i], font)

func _draw_slot(r: Rect2, id: String, font: Font) -> void:
	var d: Dictionary = Game.TOWER_DEFS[id]
	var cost: int = int(d["cost"])
	var affordable := _gold >= cost
	draw_rect(r, Color(0.20, 0.20, 0.24, 0.85) if affordable else Color(0.22, 0.12, 0.12, 0.7))
	draw_rect(r, Color(1, 1, 1, 0.22), false, 1.0)
	# Element colour swatch.
	var c := r.position + Vector2(20, r.size.y * 0.5)
	draw_circle(c, 12.0, d["color"])
	draw_arc(c, 12.0, 0.0, TAU, 16, Color(0, 0, 0, 0.4), 1.5, true)
	# Name + cost.
	draw_string(font, r.position + Vector2(40, 17), str(d["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var cost_col := Color(1, 0.9, 0.4) if affordable else Color(0.9, 0.45, 0.45)
	draw_string(font, r.position + Vector2(40, 33), "%d g" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cost_col)
