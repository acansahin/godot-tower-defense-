extends Control
class_name BuildMenu
## Small popup that appears next to a clicked build spot and offers Archer /
## Cannon / Cancel. A full-screen backdrop closes the menu when the player
## clicks anywhere else (and blocks building on another spot while open).

signal build_selected(kind: String)

@onready var panel: PanelContainer = $Panel
@onready var archer_button: Button = $Panel/VBox/ArcherButton
@onready var cannon_button: Button = $Panel/VBox/CannonButton
@onready var cancel_button: Button = $Panel/VBox/CancelButton
@onready var backdrop: ColorRect = $Backdrop

func _ready() -> void:
	backdrop.gui_input.connect(_on_backdrop_input)
	archer_button.pressed.connect(_on_archer)
	cannon_button.pressed.connect(_on_cannon)
	cancel_button.pressed.connect(close)
	hide()

func open_at(world_pos: Vector2, gold: int) -> void:
	archer_button.text = "Archer  (%d g)" % Game.ARCHER_COST
	cannon_button.text = "Cannon  (%d g)" % Game.CANNON_COST
	archer_button.disabled = gold < Game.ARCHER_COST
	cannon_button.disabled = gold < Game.CANNON_COST
	show()
	# Wait one frame so the panel reports a real size, then keep it on screen.
	await get_tree().process_frame
	var size := panel.size
	var pos := world_pos + Vector2(30, -size.y * 0.5)
	pos.x = clampf(pos.x, 8.0, Game.SCREEN_SIZE.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, Game.SCREEN_SIZE.y - size.y - 8.0)
	panel.position = pos

func _on_archer() -> void:
	build_selected.emit("archer")

func _on_cannon() -> void:
	build_selected.emit("cannon")

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func close() -> void:
	hide()
