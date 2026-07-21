extends Control
## Details for the currently selected tower: stats, element matchup, effects, and the
## Upgrade / Sell / Targeting actions. Hidden until a tower is selected.
##
## Drawn entirely in _draw() with Rect2 hit-testing in _gui_input(), the same way
## tower_palette.gd builds its slots — the project ships zero assets and draws its UI
## in code everywhere, so this stays one Control rather than a node tree.
##
## It sits over the lower grid rows on purpose. Selection is a deliberate, transient
## action and the board is fully visible again the moment you deselect; the only
## permanently free strip (below y=660) is too short for 44px touch targets plus text.

signal upgrade_pressed
signal sell_pressed
signal target_pressed

const PAD := 12.0
const BUTTON_TOP := 98.0
const BUTTON_H := 44.0  ## Touch-target minimum — this also ships as an Android APK.

var _tower: Tower = null

## Shows `tower`'s details, or hides the panel when passed null.
func show_tower(tower: Tower) -> void:
	_tower = tower
	visible = tower != null
	queue_redraw()

## Repaints after anything that changes what the panel says — an upgrade, or a gold
## change that flips whether the Upgrade button is affordable.
func refresh() -> void:
	if visible:
		queue_redraw()

# --- Hit areas -----------------------------------------------------------------

func _upgrade_rect() -> Rect2:
	return Rect2(PAD, BUTTON_TOP, 150.0, BUTTON_H)

func _sell_rect() -> Rect2:
	return Rect2(170.0, BUTTON_TOP, 100.0, BUTTON_H)

func _target_rect() -> Rect2:
	return Rect2(278.0, BUTTON_TOP, size.x - 278.0 - PAD, BUTTON_H)

func _gui_input(event: InputEvent) -> void:
	if _tower == null:
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if _upgrade_rect().has_point(p):
		if _can_upgrade():
			upgrade_pressed.emit()
	elif _sell_rect().has_point(p):
		sell_pressed.emit()
	elif _target_rect().has_point(p):
		target_pressed.emit()
	accept_event()

func _can_upgrade() -> bool:
	return _tower.can_upgrade() and Game.gold >= _tower.upgrade_cost()

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	if _tower == null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.08, 0.93))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22), false, 1.0)
	# Element stripe down the left edge, so the panel reads as belonging to the tower
	# you just clicked even out of the corner of your eye.
	draw_rect(Rect2(0, 0, 4, size.y), _tower.element_color)

	draw_string(font, Vector2(PAD, 26), "%s  Lv%d" % [_tower.display_name, _tower.level],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, _tower.element_color.lightened(0.25))
	# DPS is the number players actually compare towers on, and it is the one number
	# the palette could never show — it only exists once damage and interval are known.
	draw_string(font, Vector2(PAD, 48),
			"DPS %.1f    Range %d    Rate %.2fs" % [
				_tower.damage / _tower.fire_interval, int(_tower.tower_range),
				_tower.fire_interval],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.90, 0.92, 0.96))
	draw_string(font, Vector2(PAD, 68), _element_line(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.84, 0.90))
	draw_string(font, Vector2(PAD, 87), _effects_line(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.80, 0.72))

	var up_label := "Max level" if not _tower.can_upgrade() \
			else "Upgrade  %dg" % _tower.upgrade_cost()
	_draw_button(_upgrade_rect(), up_label, _can_upgrade(), Color(0.20, 0.52, 0.24), font)
	_draw_button(_sell_rect(), "Sell  +%dg" % _tower.sell_value(), true,
			Color(0.55, 0.18, 0.18), font)
	_draw_button(_target_rect(), "Target: %s  ▸" % _tower.target_mode_name(), true,
			Color(0.24, 0.30, 0.44), font)

## Spells out the matchup. Duals and Lightning are neutral, which is worth stating
## outright — it is easy to assume the expensive towers must also get the bonus.
func _element_line() -> String:
	if _tower.element == "":
		return "Element: neutral  —  no matchup bonus or penalty"
	var beats := String(Game.ELEMENT_BEATS.get(_tower.element, ""))
	var beaten_by := ""
	for k in Game.ELEMENT_BEATS:
		if String(Game.ELEMENT_BEATS[k]) == _tower.element:
			beaten_by = String(k)
	return "Element: %s   x%.2f vs %s armor   x%.1f vs %s armor" % [
		_tower.element.capitalize(), Game.ELEMENT_STRONG, beats.capitalize(),
		Game.ELEMENT_WEAK, beaten_by.capitalize()]

func _effects_line() -> String:
	var parts: Array[String] = []
	if _tower.splash_radius > 0.0:
		parts.append("Splash r%d at %d%%" % [
			int(_tower.splash_radius), int(_tower.splash_factor * 100.0)])
	if _tower.slow_time > 0.0:
		parts.append("Slow to %d%% for %.1fs" % [
			int(_tower.slow_factor * 100.0), _tower.slow_time])
	if _tower.poison_dps > 0.0:
		parts.append("Poison %.0f/s for %.1fs" % [_tower.poison_dps, _tower.poison_time])
	if _tower.stun_chance > 0.0:
		parts.append("%d%% stun %.1fs" % [int(_tower.stun_chance * 100.0), _tower.stun_time])
	parts.append("Hits air" if _tower.can_hit_flying else "Ground only")
	return "   ·   ".join(parts)

func _draw_button(r: Rect2, label: String, enabled: bool, tint: Color, font: Font) -> void:
	draw_rect(r, tint if enabled else Color(0.18, 0.18, 0.22, 0.75))
	draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
	draw_string(font, r.position + Vector2(0, r.size.y * 0.5 + 5), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15,
			Color(1, 1, 1, 0.95) if enabled else Color(1, 1, 1, 0.40))
