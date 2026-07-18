extends Control
class_name EndScreen
## Victory / Game Over overlay. Pauses the tree so nothing keeps moving, and
## restarts the level on button press.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var subtitle: Label = $Center/Panel/VBox/Subtitle
@onready var restart_button: Button = $Center/Panel/VBox/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_restart)
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
