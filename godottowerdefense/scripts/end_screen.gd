extends Control
class_name EndScreen
## Run summary. Waves are endless, so there is no victory screen to pair with this — a run
## always ends the same way, by running out of lives, and the only question is how deep the
## player got. Pauses the tree so nothing keeps moving, and restarts on button press.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var subtitle: Label = $Center/Panel/VBox/Subtitle
@onready var restart_button: Button = $Center/Panel/VBox/RestartButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton

func _ready() -> void:
	restart_button.pressed.connect(_restart)
	menu_button.pressed.connect(_to_menu)
	hide()

## Ends the run and shows how far it got. Deliberately framed as a result rather than a
## failure: in an endless mode the wave count IS the score, so the number is the headline
## and "you lost" is not said at all.
## `earned` is the Essence this run banked (Meta.finish_run has already added it).
func show_summary(earned: int) -> void:
	get_tree().paused = true
	var reached: int = Game.wave_reached
	title.text = "WAVE %d" % reached
	title.modulate = Color(1.00, 0.82, 0.35)
	# The Essence line comes first: it is the reason to start another run, and it is the
	# only part of a lost run that the player keeps.
	subtitle.text = "+%d Essence  ·  %s\nBest: wave %d   ·   Essence: %d" % [
			earned, _verdict(reached), Meta.best_wave, Meta.essence]
	show()

## A short line acknowledging the depth reached. Milestones are the ones the wave table
## makes meaningful — surviving the tutorial, the first boss on 10, the second on 20, and
## then the generator's own boss cadence.
func _verdict(reached: int) -> String:
	if reached >= 40:
		return "The road held for a very long time."
	if reached >= 20:
		return "Past the second boss."
	if reached >= 10:
		return "You beat the first boss."
	if reached >= 5:
		return "The elements are starting to matter."
	return "Just getting started."

func _restart() -> void:
	_clear_time_state()
	Game.reset()
	get_tree().reload_current_scene()

## Back to the title screen. Clearing the pause first is essential — show_result() set it,
## and it survives the scene change, which would leave the menu frozen.
func _to_menu() -> void:
	_clear_time_state()
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

## Both the pause flag and Engine.time_scale are global and outlive the scene, so
## every exit from the level has to hand them back at their defaults — otherwise the
## menu comes up frozen, or running at 3x.
func _clear_time_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
