extends Node2D
## Wires the level together: grid-based tower placement (drag from the palette
## onto a cell), one-click tower upgrades, and the HUD, then kicks off the waves.

const TOWER := preload("res://scenes/Tower.tscn")

@onready var grid = $Grid
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var palette = $UI/TowerPalette
@onready var end_screen: EndScreen = $UI/EndScreen
@onready var preview = $Preview  ## Drag ghost.

var _drag_kind: String = ""  ## Tower type being dragged from the palette ("" = none).

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

	wave_manager.enemies_root = enemies_root
	wave_manager.start()

# --- Placement: drag a palette item onto a grid cell ---------------------------

func _on_drag_started(kind: String) -> void:
	if Game.is_over:
		return
	_drag_kind = kind
	_update_ghost(get_global_mouse_position())

## While a drag is active this runs before the GUI so the ghost tracks the mouse
## and the drop is caught wherever the button is released.
func _input(event: InputEvent) -> void:
	if _drag_kind == "":
		return
	if event is InputEventMouseMotion:
		_update_ghost(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_drop(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _update_ghost(world_pos: Vector2) -> void:
	var cell: Rect2 = grid.snap(world_pos)
	if cell.size == Vector2.ZERO:
		preview.hide()
		return
	var center := cell.get_center()
	preview.show_at(cell, _cell_is_free(center) and Game.gold >= _cost(_drag_kind))

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

## Redraw every tower so upgrade badges appear/disappear as gold changes.
func _refresh_tower_badges(_gold: int) -> void:
	for c in towers_root.get_children():
		(c as Node2D).queue_redraw()

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

# --- Upgrades: click a tower that shows the upgrade badge ----------------------

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_over or _drag_kind != "":
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell: Rect2 = grid.snap(get_global_mouse_position())
	if cell.size == Vector2.ZERO:
		return
	var tower := _tower_on_cell(cell.get_center())
	if tower == null:
		return
	# Clicking the red ✕ badge sells the tower; clicking anywhere else upgrades it
	# (when affordable and not maxed — exactly when the green badge is showing).
	if tower.is_sell_hit(get_global_mouse_position() - tower.position):
		_sell_tower(tower)
	elif tower.can_upgrade() and Game.gold >= tower.upgrade_cost():
		Game.spend_gold(tower.upgrade_cost())
		tower.upgrade()
		Audio.play("upgrade")

## Removes a tower and refunds half of the gold sunk into it.
func _sell_tower(tower: Tower) -> void:
	Audio.play("sell")
	Game.add_gold(tower.sell_value())
	tower.queue_free()

func _on_game_over() -> void:
	Audio.play("gameover")
	end_screen.show_result(false)

func _on_victory() -> void:
	Audio.play("victory")
	end_screen.show_result(true)
