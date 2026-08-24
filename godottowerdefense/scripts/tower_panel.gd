extends Control
class_name TowerPanel
## The panel that opens above a tower when it is tapped: upgrade, fuse, sell, in one place.
##
## Replaces THREE full-screen popups (UpgradeChoice, BranchChoice, ElementChoice) and the
## sell "×" that used to sit on the tower body. Those were full-screen because they asked
## run-wide questions; every question left is about ONE tower, so the answer belongs next to
## that tower rather than over the whole board.
##
## Unlike the popups it replaces, this does NOT pause the tree. Upgrading and fusing happen
## during prep with the wave stopped anyway, and pausing to read a price made the panel feel
## like an interruption rather than a control. Clicking anywhere off the panel closes it.
##
## Everything is drawn in _draw() and hit-tested against Rect2s, the same approach the popups
## used — no Control children, so there is nothing to keep in sync between a scene tree and
## the drawing code.

signal upgrade_pressed(tower: Tower)
signal fusion_pressed(tower: Tower, element: String)
signal sell_pressed(tower: Tower)

const PANEL_SIZE := Vector2(330.0, 196.0)
const PAD := 12.0
const ROW_H := 38.0
const GAP := 8.0
## Gap between the tower's head and the panel's bottom edge, in SCREEN px. The panel points
## down at the tower with a small triangle drawn in this gap.
const STEM := 26.0
const TAIL_W := 9.0

const BG := Color(0.086, 0.086, 0.110, 0.98)
const BORDER := Color(0.227, 0.227, 0.282)
const TEXT := Color(0.910, 0.910, 0.941)
const TEXT_DIM := Color(0.604, 0.604, 0.659)
const GOLD := Color(0.925, 0.788, 0.294)
const OK_BG := Color(0.122, 0.165, 0.122)
const OK_EDGE := Color(0.302, 0.478, 0.302)
const OK_TEXT := Color(0.561, 0.831, 0.561)
const OFF_BG := Color(0.078, 0.086, 0.110)
const OFF_EDGE := Color(0.180, 0.212, 0.267)
const SELL := Color(0.788, 0.376, 0.353)

var _tower: Tower = null
var _origin := Vector2.ZERO   ## Panel top-left, in screen space.
var _hover: int = -1          ## Index into `_rows`, or -1.
## The panel's rows for THIS frame. Rebuilt once per frame in _process (and on open, and
## after any press) rather than derived on demand: the layout, the hit test and the drawing
## all need the same list, and rebuilding it inside each of them meant a dozen rebuilds per
## frame and — worse — a hit test that could disagree with what was drawn if the tower's
## state changed between the two.
var _rows: Array = []
## Elements this tower could still grow into once their avatar boss falls. Not clickable;
## drawn as one dim line so the ladder above the player is visible from the very first tower,
## instead of fusion appearing out of nowhere the first time a boss dies.
var _locked: Array = []

## `kind` is "upgrade" | "fuse" | "sell"; `element` is only set for a fuse row.
func _build_rows() -> void:
	_rows = []
	_locked = []
	if _tower == null or not is_instance_valid(_tower):
		return
	if _tower.can_upgrade():
		_rows.append({"kind": "upgrade", "cost": _tower.upgrade_cost(),
				"label": "Level %d" % (_tower.level + 1)})
	for e in _tower.available_elements():
		var set_after: Array = _tower.elements.duplicate()
		set_after.append(String(e))
		var def: Dictionary = Game.fusion_def(set_after)
		_rows.append({"kind": "fuse", "element": String(e), "cost": _tower.fusion_cost(),
				"label": Game.fusion_name(def, _tower.level),
				"desc": String(def.get("desc", "")), "def": def})
	for e in Game.TOWER_ORDER:
		if not _tower.elements.has(String(e)) and not Run.is_fusion_unlocked(String(e)):
			_locked.append(String(e))
	_rows.append({"kind": "sell", "cost": -_tower.sell_value(), "label": "Sell"})

## Opens the panel for `tower`, parked above it and nudged to stay fully on screen.
func open_for(tower: Tower) -> void:
	_tower = tower
	_hover = -1
	_build_rows()
	_reposition()
	show()
	queue_redraw()

func close() -> void:
	_tower = null
	hide()

func is_open() -> bool:
	return visible and _tower != null and is_instance_valid(_tower)

## The tower lives in 1536x864 WORLD space and this panel in 1280x720 SCREEN space, so the
## canvas transform is what bridges them — the same one the camera's zoom is baked into, which
## is why this cannot be a plain subtraction.
##
## Then it is clamped into the screen. The right-hand clamp is the one that matters: the
## tower palette occupies the right 200px of screen (see Main.tscn) and eats clicks, so a
## panel that slid under it would be half unusable for towers built on that side.
func _reposition() -> void:
	if _tower == null or not is_instance_valid(_tower):
		return
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _tower.global_position
	_origin = Vector2(screen_pos.x - PANEL_SIZE.x * 0.5,
			screen_pos.y - PANEL_SIZE.y - STEM)
	var panel_h := _panel_height()
	_origin.y = screen_pos.y - panel_h - STEM
	_origin.x = clampf(_origin.x, 8.0, Game.SCREEN_SIZE.x - PANEL_SIZE.x - 208.0)
	# Below the tower instead of above it when there is no room up top — a tower near the top
	# edge would otherwise get a panel hanging off the screen.
	if _origin.y < 8.0:
		_origin.y = screen_pos.y + STEM

func _panel_height() -> float:
	var n := _rows.size()
	var body := float(n) * ROW_H + maxf(0.0, float(n - 1)) * GAP
	# Header, body, and a footer line: the hovered fusion's description, or the locked list.
	return PAD + 26.0 + 8.0 + body + PAD + 18.0

func _row_rect(i: int) -> Rect2:
	var y := _origin.y + PAD + 26.0 + 8.0 + float(i) * (ROW_H + GAP)
	return Rect2(Vector2(_origin.x + PAD, y), Vector2(PANEL_SIZE.x - PAD * 2.0, ROW_H))

func _panel_rect() -> Rect2:
	return Rect2(_origin, Vector2(PANEL_SIZE.x, _panel_height()))

func _row_at(pos: Vector2) -> int:
	for i in _rows.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1

func _process(_delta: float) -> void:
	if not visible:
		return
	# The tower can be sold from under the panel (by the panel itself), and a run can end
	# while it is open. Either way there is nothing left to describe.
	if _tower == null or not is_instance_valid(_tower):
		close()
		return
	# Rebuilt every frame because gold moves every frame — a row that just became affordable
	# has to light up without the player having to close and reopen the panel.
	_build_rows()
	# Followed rather than pinned: the camera shakes on a leak, and a panel that stayed put
	# while the board moved under it read as a detached rectangle.
	_reposition()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseMotion:
		var was := _hover
		_hover = _row_at(event.position)
		if _hover != was:
			queue_redraw()
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# A click outside the panel dismisses it. Accepted either way so it never falls through to
	# Main's own tower-click handler, which would immediately reopen the panel on the tower
	# underneath — or worse, open one for a different tower on the same click.
	if not _panel_rect().has_point(event.position):
		close()
		accept_event()
		return
	var i := _row_at(event.position)
	accept_event()
	if i < 0:
		return
	var row: Dictionary = _rows[i]
	var tower := _tower
	match String(row["kind"]):
		"upgrade": upgrade_pressed.emit(tower)
		"fuse": fusion_pressed.emit(tower, String(row["element"]))
		"sell":
			close()
			sell_pressed.emit(tower)
			return  # `_tower` is gone; nothing left to rebuild or draw
	# The press changed the tower, so the rows describing it are already stale — a fused
	# tower's next fusion costs more and offers different combinations.
	_build_rows()
	_hover = _row_at(event.position)
	queue_redraw()

func _draw() -> void:
	if not is_open():
		return
	var font := get_theme_default_font()
	var r := _panel_rect()
	# The stem: a small triangle pointing at the tower, so a panel that has been clamped
	# sideways still says which tower it belongs to.
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _tower.global_position
	var tip_y := r.position.y + r.size.y if screen_pos.y > r.position.y else r.position.y
	var dir := 1.0 if screen_pos.y > r.position.y else -1.0
	var anchor_x := clampf(screen_pos.x, r.position.x + 20.0, r.end.x - 20.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(anchor_x - TAIL_W, tip_y),
		Vector2(anchor_x + TAIL_W, tip_y),
		Vector2(anchor_x, tip_y + dir * 11.0),
	]), BORDER)
	draw_rect(r, BG)
	draw_rect(r, BORDER, false, 1.5)

	# --- header: what this tower currently IS --------------------------------
	var hx := r.position.x + PAD
	var hy := r.position.y + PAD + 15.0
	draw_circle(Vector2(hx + 6.0, hy - 5.0), 5.0, _tower.element_color)
	draw_string(font, Vector2(hx + 18.0, hy), _tower.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	var name_w := font.get_string_size(_tower.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(hx + 26.0 + name_w, hy), "Lv %d" % _tower.level,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_DIM)
	# Damage on the right, because it is the number a player compares between two towers.
	draw_string(font, Vector2(r.position.x, hy), "%d dmg  " % int(round(_tower.damage)),
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - PAD, 13, TEXT_DIM)

	for i in _rows.size():
		_draw_row(font, _row_rect(i), _rows[i], i == _hover)

	# --- footer -----------------------------------------------------------------
	# Hovering a fusion explains it — the ONLY place the game says what a combination does
	# before it is bought. With nothing hovered the line names the elements still locked, so
	# the ladder above the player is visible from the first tower they ever place rather than
	# appearing out of nowhere the first time an avatar boss falls.
	var note := ""
	if _hover >= 0 and _hover < _rows.size():
		note = String((_rows[_hover] as Dictionary).get("desc", ""))
	if note == "" and not _locked.is_empty():
		var names := PackedStringArray()
		for e in _locked:
			names.append(String(e).capitalize())
		note = "Locked: %s — beat their avatar boss" % ", ".join(names)
	if note != "":
		draw_string(font, Vector2(r.position.x + PAD, r.end.y - PAD + 2.0), note,
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - PAD * 2.0, 12, TEXT_DIM)

func _draw_row(font: Font, rect: Rect2, row: Dictionary, hovered: bool) -> void:
	var kind := String(row["kind"])
	var cost := int(row["cost"])
	# A sell row's "cost" is negative — it pays out. Everything else has to be affordable,
	# and a row you cannot pay for is drawn dark rather than hidden: knowing the next step
	# exists and costs 420 is the information that makes saving for it a decision.
	var affordable := cost <= 0 or Game.gold >= cost
	var accent := OK_TEXT
	if kind == "sell":
		accent = SELL
	elif kind == "fuse":
		accent = Game.ELEMENT_COLORS.get(String(row["element"]), OK_TEXT)
	draw_rect(rect, OK_BG if affordable else OFF_BG)
	var edge := OK_EDGE if affordable else OFF_EDGE
	if kind == "fuse" and affordable:
		edge = accent
	elif kind == "sell":
		edge = Color(0.35, 0.18, 0.18)
	draw_rect(rect, Color(edge.r, edge.g, edge.b, 1.0 if hovered else 0.75), false,
			2.0 if hovered else 1.0)

	var label := String(row["label"])
	var prefix := ""
	if kind == "upgrade":
		prefix = "Upgrade to "
	elif kind == "fuse":
		prefix = "+%s  ->  " % String(row["element"]).capitalize()
	draw_string(font, Vector2(rect.position.x + 10.0, rect.position.y + 25.0), prefix + label,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 90.0, 14,
			(TEXT if affordable else TEXT_DIM) if kind != "sell" else SELL)
	var price := "+%d" % (-cost) if cost < 0 else str(cost)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 25.0), price + "  ",
			HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 14,
			GOLD if affordable else TEXT_DIM)
