extends Node2D
## Title screen — this scene is `run/main_scene`, so it is what the game opens on.
## The backdrop is the very same map.gd used in-game, with a button panel over it.
## Pressing Play swaps in Main.tscn; that click doubles as the user gesture browsers
## require before any audio is allowed to start.

const GAME_SCENE := "res://scenes/Main.tscn"

@onready var _center: CenterContainer = $UI/Root/Center
@onready var _how_panel: CenterContainer = $UI/Root/HowPanel
@onready var _play_button: Button = $UI/Root/Center/Panel/VBox/PlayButton
@onready var _how_button: Button = $UI/Root/Center/Panel/VBox/HowButton
@onready var _sound_button: Button = $UI/Root/Center/Panel/VBox/SoundButton
@onready var _quit_button: Button = $UI/Root/Center/Panel/VBox/QuitButton
@onready var _back_button: Button = $UI/Root/HowPanel/Panel/VBox/BackButton

func _ready() -> void:
	_play_button.pressed.connect(_on_play)
	_how_button.pressed.connect(_on_how)
	_sound_button.pressed.connect(_on_sound)
	_quit_button.pressed.connect(_on_quit)
	_back_button.pressed.connect(_on_back)
	if OS.has_feature("web"):
		_quit_button.hide()   # there is nothing to quit to in a browser tab
	_how_panel.hide()
	_refresh_sound_label()
	_play_button.grab_focus()

func _on_play() -> void:
	Audio.play("build")
	# Main's _ready() clears the pause flag and calls Game.reset(), so no setup needed here.
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_how() -> void:
	Audio.play("build")
	_center.hide()
	_how_panel.show()
	_back_button.grab_focus()

func _on_back() -> void:
	Audio.play("denied")
	_how_panel.hide()
	_center.show()
	_play_button.grab_focus()

func _on_sound() -> void:
	Audio.set_muted(not Audio.is_muted())
	_refresh_sound_label()
	Audio.play("build")   # silent when muting, audible when turning sound back on

func _on_quit() -> void:
	get_tree().quit()

## Keeps the label in step with the M key, which can toggle mute from anywhere.
func _refresh_sound_label() -> void:
	_sound_button.text = "Sound: Off" if Audio.is_muted() else "Sound: On"
