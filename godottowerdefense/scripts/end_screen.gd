extends Control
class_name EndScreen
## Victory / Game Over overlay. Pauses the tree so nothing keeps moving, and
## restarts the level on button press.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var subtitle: Label = $Center/Panel/VBox/Subtitle
@onready var restart_button: Button = $Center/Panel/VBox/RestartButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton

func _ready() -> void:
	restart_button.pressed.connect(_restart)
	menu_button.pressed.connect(_to_menu)
	hide()

func show_result(won: bool) -> void:
	get_tree().paused = true
	if won:
		title.text = "VICTORY!"
		title.modulate = Color(0.40, 1.00, 0.50)
		subtitle.text = "You survived every wave."
	else:
		title.text = "GAME OVER"
		title.modulate = Color(1.00, 0.40, 0.40)
		subtitle.text = "The enemies broke through."
	show()

func _restart() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().reload_current_scene()

## Back to the title screen. Clearing the pause first is essential — show_result() set it,
## and it survives the scene change, which would leave the menu frozen.
func _to_menu() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")
