extends Control
class_name BranchChoice
## The Lv3 branch popup (GAME_STRATEGY_V2.md §4, BUILD NEXT #5): two cards, pick one, it lasts
## the rest of this tower's life. Deliberately a near-copy of upgrade_choice.gd rather than a
## shared base — two cards instead of three, no rarity border, and the decision is about ONE
## tower rather than the whole run, which is different enough content that sharing layout code
## would mean threading a bunch of "is this the branch popup or the card popup" branches
## through one file for no real reuse.
##
## Runs while the tree is paused (process_mode = ALWAYS in the scene), same as UpgradeChoice —
## Main owns pausing/unpausing, this only draws and reports a pick.

signal chosen(branch_id: String)

const CARD_SIZE := Vector2(420.0, 300.0)
const CARD_GAP := 40.0
const CARD_TOP := 230.0
const TITLE_Y := 140.0

var _element: String = ""
var _options: Array = []  ## [{"key": "a"/"b", ...branch def...}, ...]
var _hover: int = -1

## Shows the two branches for `element` (a tower just reached Lv3). No-op if the element has
## no entry in Game.TOWER_BRANCHES — every buildable element does, so this only guards a def
## with a typo rather than something expected to happen in play.
func show_choices(element: String) -> void:
	var branches: Dictionary = Game.TOWER_BRANCHES.get(element, {})
	if branches.is_empty():
		push_warning("BranchChoice: no branches defined for '%s'" % element)
		return
	_element = element
	_options = []
	for key in ["a", "b"]:
		if branches.has(key):
			var opt: Dictionary = (branches[key] as Dictionary).duplicate()
			opt["key"] = key
			_options.append(opt)
	_hover = -1
	show()
	queue_redraw()

func _card_rect(i: int) -> Rect2:
	var n := _options.size()
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
			var picked := String((_options[i] as Dictionary)["key"])
			_options = []
			chosen.emit(picked)

func _card_at(pos: Vector2) -> int:
	for i in _options.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Game.SCREEN_SIZE), Color(0.03, 0.03, 0.06, 0.85))
	var col: Color = Game.ELEMENT_COLORS.get(_element, Color(1, 0.95, 0.8))
	draw_string(font, Vector2(0, TITLE_Y), "%s BRANCHES AT LV3" % _element.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 36, col)
	draw_string(font, Vector2(0, TITLE_Y + 32.0), "Pick one — this tower keeps it for good",
			HORIZONTAL_ALIGNMENT_CENTER, Game.SCREEN_SIZE.x, 18, Color(0.75, 0.75, 0.82))
	for i in _options.size():
		_draw_card(_card_rect(i), _options[i], i == _hover, font, col)

func _draw_card(r: Rect2, opt: Dictionary, hovered: bool, font: Font, accent: Color) -> void:
	draw_rect(r, Color(0.13, 0.13, 0.17, 0.98) if hovered else Color(0.10, 0.10, 0.13, 0.96))
	if hovered:
		draw_rect(r.grow(5.0), Color(accent.r, accent.g, accent.b, 0.22), false, 5.0)
	draw_rect(r, accent, false, 3.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), accent)

	var pad := 20.0
	var w := r.size.x - pad * 2.0
	var x := r.position.x + pad
	draw_string(font, Vector2(x, r.position.y + 68.0), String(opt.get("name", "?")),
			HORIZONTAL_ALIGNMENT_CENTER, w, 32, accent)
	draw_line(Vector2(x, r.position.y + 92.0), Vector2(x + w, r.position.y + 92.0),
			Color(1, 1, 1, 0.14), 2.0)
	draw_multiline_string(font, Vector2(x, r.position.y + 130.0), String(opt.get("desc", "")),
			HORIZONTAL_ALIGNMENT_CENTER, w, 20, 6, Color(0.90, 0.90, 0.95))
