extends Node2D
## Wires the level together: grid-based tower placement (drag from the palette
## onto a cell), tower selection + the info panel, and the HUD, then kicks off
## the waves.

const TOWER := preload("res://scenes/Tower.tscn")
const SHAKE_DECAY := 26.0  ## Pixels of camera shake bled off per second.

@onready var grid = $Grid
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var palette = $UI/TowerPalette
@onready var end_screen: EndScreen = $UI/EndScreen
@onready var tower_info = $UI/TowerInfo
@onready var camera: Camera2D = $Camera2D
@onready var preview = $Preview  ## Drag ghost.

var _drag_kind: String = ""  ## Tower type being dragged from the palette ("" = none).
var _hovered: Tower = null   ## Tower under the mouse, drawn with a clear range ring.
var _selected: Tower = null  ## Tower the info panel is showing (null = panel hidden).
var _shake: float = 0.0      ## Current camera shake magnitude in px; decays to 0.

func _ready() -> void:
	get_tree().paused = false
	Game.reset()

	hud.set_gold(Game.gold)
	hud.set_lives(Game.lives)
	palette.set_gold(Game.gold)

	Game.gold_changed.connect(hud.set_gold)
	Game.gold_changed.connect(palette.set_gold)
	Game.gold_changed.connect(_refresh_tower_badges)
	Game.lives_changed.connect(hud.set_lives)
	Game.game_over.connect(_on_game_over)
	Game.victory.connect(_on_victory)
	wave_manager.wave_started.connect(hud.set_wave)
	wave_manager.wave_preview.connect(hud.set_next)
	wave_manager.prep_started.connect(hud.enable_send)
	hud.send_pressed.connect(wave_manager.send_now)
	palette.drag_started.connect(_on_drag_started)
	tower_info.upgrade_pressed.connect(_upgrade_selected)
	tower_info.sell_pressed.connect(_sell_selected)
	tower_info.target_pressed.connect(_cycle_selected_target)
	Game.shake_requested.connect(_add_shake)

	wave_manager.enemies_root = enemies_root
	wave_manager.start()

# --- Camera shake --------------------------------------------------------------

## Kept deliberately small: the mouse position is read back through the camera
## transform, so a violent shake would also drag the cursor's world position around
## and make clicks feel imprecise mid-shake.
func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	camera.offset = Vector2.ZERO if _shake <= 0.0 \
			else Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

# --- Placement: drag a palette item onto a grid cell ---------------------------

func _on_drag_started(kind: String) -> void:
	if Game.is_over:
		return
	_drag_kind = kind
	_set_hovered(null)  # the drag preview takes over; don't compete with a hover ring
	# Also clears the panel, which overlaps the lower grid rows — leaving it up would
	# let a drop land on a cell hidden underneath it.
	_select(null)
	_update_ghost(get_global_mouse_position())

## While a drag is active this runs before the GUI so the ghost tracks the mouse
## and the drop is caught wherever the button is released. With no drag, mouse
## motion instead highlights whichever tower is under the cursor.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag_kind == "":
			_update_hover(get_global_mouse_position())
		else:
			_update_ghost(get_global_mouse_position())
		return
	if _drag_kind == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_drop(get_global_mouse_position())
		get_viewport().set_input_as_handled()

## Highlights the tower under the cursor (if any) so its range reads clearly.
func _update_hover(world_pos: Vector2) -> void:
	var cell: Rect2 = grid.snap(world_pos)
	_set_hovered(null if cell.size == Vector2.ZERO else _tower_on_cell(cell.get_center()))

## Single place that swaps the highlight, guarding against a tower that has been
## sold (queue_free'd) while it was still the hovered one.
func _set_hovered(tower: Tower) -> void:
	if _hovered == tower:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(false)
	_hovered = tower
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(true)

func _update_ghost(world_pos: Vector2) -> void:
	var cell: Rect2 = grid.snap(world_pos)
	if cell.size == Vector2.ZERO:
		preview.hide()
		return
	var center := cell.get_center()
	var d: Dictionary = Game.TOWER_DEFS[_drag_kind]
	preview.show_at(cell, _cell_is_free(center) and Game.gold >= _cost(_drag_kind),
			d.get("range", 160.0), d.get("color", Color.WHITE))

func _drop(world_pos: Vector2) -> void:
	var kind := _drag_kind
	_drag_kind = ""
	preview.hide()
	var cell: Rect2 = grid.snap(world_pos)
	if cell.size == Vector2.ZERO:
		return
	var center := cell.get_center()
	if not _cell_is_free(center):
		Audio.play("denied")
		return
	if not Game.spend_gold(_cost(kind)):
		Audio.play("denied")
		return
	var tower := TOWER.instantiate() as Tower
	tower.setup_def(kind)
	tower.position = center
	towers_root.add_child(tower)
	Audio.play("build")

## Redraw every tower so upgrade badges appear/disappear as gold changes, and let the
## info panel re-evaluate whether its Upgrade button is affordable.
func _refresh_tower_badges(_gold: int) -> void:
	for c in towers_root.get_children():
		(c as Node2D).queue_redraw()
	tower_info.refresh()

func _cost(kind: String) -> int:
	return int(Game.TOWER_DEFS[kind]["cost"])

## True if no tower already sits on the cell centred at this point.
func _cell_is_free(center: Vector2) -> bool:
	return _tower_on_cell(center) == null

## The tower placed on the cell centred at this point, or null if none.
func _tower_on_cell(center: Vector2) -> Tower:
	for c in towers_root.get_children():
		var t := c as Tower
		if t != null and t.position.distance_to(center) < 1.0:
			return t
	return null

# --- Selection: click a tower to open its info panel ---------------------------

## Click a tower to select it; click bare ground to deselect. Upgrading and selling
## moved into the panel deliberately — a bare click used to upgrade instantly, which
## on a touchscreen meant a mistimed tap silently spent gold.
func _unhandled_input(event: InputEvent) -> void:
	if Game.is_over or _drag_kind != "":
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell: Rect2 = grid.snap(get_global_mouse_position())
	_select(null if cell.size == Vector2.ZERO else _tower_on_cell(cell.get_center()))

## Single place that swaps the selection, keeping the tower's ring and the panel in
## step. Guards a tower that was sold while still selected.
func _select(tower: Tower) -> void:
	if is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = tower
	if is_instance_valid(_selected):
		_selected.set_selected(true)
	tower_info.show_tower(_selected)

func _upgrade_selected() -> void:
	if not is_instance_valid(_selected):
		return
	if not _selected.can_upgrade() or not Game.spend_gold(_selected.upgrade_cost()):
		return
	_selected.upgrade()
	Audio.play("upgrade")
	tower_info.refresh()

## Removes the selected tower and refunds half of the gold sunk into it.
func _sell_selected() -> void:
	if not is_instance_valid(_selected):
		return
	var tower := _selected
	_select(null)  # clears the panel before the node goes away
	Audio.play("sell")
	Game.add_gold(tower.sell_value())
	if _hovered == tower:
		_hovered = null  # it is about to be freed; never keep a dangling reference
	tower.queue_free()

func _cycle_selected_target() -> void:
	if not is_instance_valid(_selected):
		return
	_selected.cycle_target_mode()
	tower_info.refresh()

func _on_game_over() -> void:
	Audio.play("gameover")
	_select(null)  # don't leave the panel sitting under the overlay
	end_screen.show_result(false)

func _on_victory() -> void:
	Audio.play("victory")
	_select(null)
	end_screen.show_result(true)
