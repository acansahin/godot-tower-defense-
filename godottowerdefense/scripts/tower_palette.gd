extends Control
## Top-right toolbar listing every tower in Game.TOWER_ORDER with its colour and
## cost. Pressing a slot emits `drag_started`; Main then drags a ghost to a grid
## cell to place it.
##
## Laid out as 2 columns rather than one tall column. Slots stacked in a single column
## cannot each be tall enough to hit with a thumb — the board is drawn at roughly half
## scale on a phone, so the old 38px-tall slot arrived as ~19 CSS px. Two columns buy
## the height back.
##
## The roster is Game.TOWER_ORDER (four elements as of BUILD NEXT #2 — see
## GAME_STRATEGY_V2.md §2) plus anything a card unlocks outright via Run.buildable_towers().
## The panel used to also carry up to eight duals and Lightning, fifteen slots against a
## panel sized for four; that headroom is gone with the dual roster, but the SHRINK-to-fit
## logic stays general rather than assuming a fixed count — a tower you own but cannot see
## is a bug the player cannot diagnose. Up to twelve slots keep the full-size box; past that
## everything scales down together.

signal drag_started(id: String)

const SLOT_SIZE := Vector2(87, 80)
const SLOT_STEP := Vector2(93, 86)  ## Slot pitch (size + gutter).
const SLOT_ORIGIN := Vector2(6, 36) ## Top-left of the first slot, below the header.
const COLUMNS := 2
## Never shrink past this: below roughly half size the text stops being legible and the
## box stops being a thumb target, and a palette that cannot be used is no better than
## one that is clipped. If a roster ever needs more than this can show, the panel needs
## to scroll rather than shrink further.
const MIN_SCALE := 0.62

var _gold: int = 0
var _filter_enabled: bool = false
var _allowed_ids: Array[String] = []

func _ready() -> void:
	# An unlock adds a slot mid-run, and the palette otherwise repaints only on a gold
	# change — which might not come for seconds, leaving the reward invisible as it lands.
	Run.roster_changed.connect(queue_redraw)

func set_gold(value: int) -> void:
	_gold = value
	queue_redraw()

## Training reveals only the tower needed by the current lesson. Main never enables this
## filter and continues to show Run's complete, dynamically unlocked roster.
func set_allowed_towers(ids: Array) -> void:
	_filter_enabled = true
	_allowed_ids.clear()
	for id in ids:
		_allowed_ids.append(String(id))
	queue_redraw()

func clear_allowed_towers() -> void:
	_filter_enabled = false
	_allowed_ids.clear()
	queue_redraw()

func _visible_ids() -> Array:
	return _allowed_ids if _filter_enabled else Run.buildable_towers()

## Vertical scale that fits `count` slots in the panel: 1.0 whenever they already fit.
func _scale_for(count: int) -> float:
	var rows := int(ceil(float(count) / float(COLUMNS)))
	if rows <= 0:
		return 1.0
	var needed := SLOT_ORIGIN.y + float(rows - 1) * SLOT_STEP.y + SLOT_SIZE.y
	if needed <= size.y:
		return 1.0
	# Only the part below the header can shrink; the header keeps its height.
	var room := size.y - SLOT_ORIGIN.y
	var content := needed - SLOT_ORIGIN.y
	return maxf(MIN_SCALE, room / content)

func _slot_rect(index: int, scale_y: float) -> Rect2:
	var col := index % COLUMNS
	@warning_ignore("integer_division")  # deliberate: this is a row index
	var row := index / COLUMNS
	var pos := Vector2(SLOT_ORIGIN.x + col * SLOT_STEP.x,
			SLOT_ORIGIN.y + row * SLOT_STEP.y * scale_y)
	return Rect2(pos, Vector2(SLOT_SIZE.x, SLOT_SIZE.y * scale_y))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var ids: Array = _visible_ids()
		var scale_y := _scale_for(ids.size())
		for i in ids.size():
			if _slot_rect(i, scale_y).has_point(event.position):
				drag_started.emit(ids[i])
				return

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.40))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18), false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(10, 26), tr("PALETTE_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(1, 1, 1, 0.9))
	var ids: Array = _visible_ids()
	var scale_y := _scale_for(ids.size())
	for i in ids.size():
		_draw_slot(_slot_rect(i, scale_y), ids[i], font)

## One slot: colour swatch on top, name and cost stacked underneath. Both strings are
## centred across the slot's full width and clipped to it, so a long name ("Electricity")
## stays inside its box instead of bleeding into the neighbouring column.
##
## Every vertical offset is a fraction of the slot's height rather than a pixel constant,
## so a shrunk slot stays composed instead of having its text drop out of the bottom.
func _draw_slot(r: Rect2, id: String, font: Font) -> void:
	var d: Dictionary = Game.TOWER_DEFS[id]
	var cost: int = int(d["cost"])
	var affordable := _gold >= cost
	var k := r.size.y / SLOT_SIZE.y  # 1.0 at full size
	draw_rect(r, Color(0.20, 0.20, 0.24, 0.85) if affordable else Color(0.22, 0.12, 0.12, 0.7))
	draw_rect(r, Color(1, 1, 1, 0.22), false, 2.0)
	# Element colour swatch, centred near the top.
	var c := r.position + Vector2(r.size.x * 0.5, 26.0 * k)
	draw_circle(c, 16.0 * k, d["color"])
	draw_arc(c, 16.0 * k, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 2.0, true)
	# Name + cost, centred under the swatch.
	var text_w := r.size.x - 6.0
	var text_x := r.position.x + 3.0
	var font_size := int(roundf(14.0 * k))
	draw_string(font, Vector2(text_x, r.position.y + 58.0 * k), str(d["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size, Color.WHITE)
	var cost_col := Color(1, 0.9, 0.4) if affordable else Color(0.9, 0.45, 0.45)
	draw_string(font, Vector2(text_x, r.position.y + 74.0 * k), "%d g" % cost,
			HORIZONTAL_ALIGNMENT_CENTER, text_w, font_size, cost_col)
