extends Node2D
## Title screen — this scene is `run/main_scene`, so it is what the game opens on.
## The backdrop is the very same map.gd used in-game, with a button panel over it.
## Pressing Play opens Tutorial.tscn, which can teach the essentials or be skipped before
## handing off to Main. That click also supplies the user gesture browsers require before
## any audio is allowed to start.

const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"

@onready var _center: CenterContainer = $UI/Root/Center
@onready var _how_panel: CenterContainer = $UI/Root/HowPanel
@onready var _play_button: Button = $UI/Root/Center/Panel/VBox/PlayButton
@onready var _how_button: Button = $UI/Root/Center/Panel/VBox/HowButton
@onready var _sound_button: Button = $UI/Root/Center/Panel/VBox/SoundButton
@onready var _quit_button: Button = $UI/Root/Center/Panel/VBox/QuitButton
@onready var _back_button: Button = $UI/Root/HowPanel/Panel/VBox/BackButton
@onready var _workshop_button: Button = $UI/Root/Center/Panel/VBox/WorkshopButton
@onready var _status_label: Label = $UI/Root/Center/Panel/VBox/StatusLabel
@onready var _workshop: Workshop = $UI/Root/Workshop

func _ready() -> void:
	Game.use_main_board()
	_play_button.pressed.connect(_on_play)
	_how_button.pressed.connect(_on_how)
	_sound_button.pressed.connect(_on_sound)
	_quit_button.pressed.connect(_on_quit)
	_back_button.pressed.connect(_on_back)
	_workshop_button.pressed.connect(_on_workshop)
	_workshop.closed.connect(_on_workshop_closed)
	Meta.essence_changed.connect(func(_v: int) -> void: _refresh_status())
	if OS.has_feature("web"):
		_quit_button.hide()   # there is nothing to quit to in a browser tab
	_how_panel.hide()
	_workshop.hide()
	_refresh_sound_label()
	_refresh_status()
	_play_button.grab_focus()
	# TEMPORARY harness: opens the Workshop straight away so its _draw runs in a rendered
	# test. Nothing else in the suite can reach it — it needs a button click, and neither
	# MCP nor a headless run can produce one (and headless never draws at all).
	#   Godot.exe --path <project> res://scenes/Menu.tscn --quit-after 300 -- --show-workshop
	if OS.get_cmdline_user_args().has("--show-workshop"):
		_on_workshop()

## The wallet, the record, and — once only, on the launch that earned it — what came in
## while the player was away. The offline line is the reason to reopen the app, so it goes
## where it is seen before anything is clicked.
func _refresh_status() -> void:
	var parts := PackedStringArray()
	if Meta.pending_offline > 0:
		parts.append("Welcome back: +%d Essence while away" % Meta.pending_offline)
	parts.append("Essence: %d" % Meta.essence)
	if Meta.best_wave > 0:
		parts.append("Best: wave %d" % Meta.best_wave)
	_status_label.text = "\n".join(parts)

func _on_workshop() -> void:
	Audio.play("build")
	_center.hide()
	_workshop.open()

func _on_workshop_closed() -> void:
	_center.show()
	_refresh_status()
	_play_button.grab_focus()

func _on_play() -> void:
	Audio.play("build")
	# Training owns its own temporary board profile and hands off to a fresh Main scene when
	# complete. It always offers Skip, so returning players are one click from the run.
	get_tree().change_scene_to_file(TUTORIAL_SCENE)

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
