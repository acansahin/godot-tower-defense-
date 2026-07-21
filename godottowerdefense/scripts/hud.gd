extends Control
class_name HUD
## Top bar showing gold, lives and the current wave, plus the bottom-left time
## controls. Values are pushed in from Main via signals.
##
## HUD.tscn sets process_mode = ALWAYS on this node. That is what makes the pause
## button able to *un*pause: once `get_tree().paused` is set, a PAUSABLE node stops
## receiving input, so the control that paused the game could never undo it. Same
## reasoning as the Audio autoload (see audio.gd).

signal send_pressed  ## Player asked to send the next wave early.

## Speeds the speed button cycles through. Kept whole numbers — the button label
## formats them with %d.
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

@onready var gold_label: Label = $GoldLabel
@onready var lives_label: Label = $LivesLabel
@onready var wave_label: Label = $WaveLabel
@onready var next_label: Label = $NextLabel
@onready var send_button: Button = $SendButton
@onready var pause_button: Button = $PauseButton
@onready var speed_button: Button = $SpeedButton

var _speed_index: int = 0
var _paused: bool = false

func _ready() -> void:
	send_button.pressed.connect(func() -> void: send_pressed.emit())
	pause_button.pressed.connect(toggle_pause)
	speed_button.pressed.connect(cycle_speed)
	# Also the reset: Engine.time_scale is global and survives a scene change, so a
	# fresh level must always re-assert it (Main._ready does the same for `paused`).
	_apply_speed()
	_apply_pause()

func set_gold(value: int) -> void:
	gold_label.text = "Gold: %d" % value

func set_lives(value: int) -> void:
	lives_label.text = "Lives: %d" % value

func set_wave(number: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [number, total]
	send_button.disabled = true  # a wave is active now

func set_next(text: String, color: Color) -> void:
	next_label.text = text
	next_label.add_theme_color_override("font_color", color)

## Re-enabled during the between-waves gap.
func enable_send() -> void:
	send_button.disabled = false

# --- Time controls -------------------------------------------------------------

## Space toggles pause, F cycles the speed. Handled here rather than in Main
## because Main stops processing input the moment the tree is paused.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		toggle_pause()
	elif key.keycode == KEY_F:
		cycle_speed()
	else:
		return
	get_viewport().set_input_as_handled()

## No-op once the game is over: the end screen owns the pause flag at that point,
## and un-pausing would let the level keep running behind the overlay.
func toggle_pause() -> void:
	if Game.is_over:
		return
	_paused = not _paused
	_apply_pause()

func cycle_speed() -> void:
	if Game.is_over:
		return
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()

func _apply_pause() -> void:
	get_tree().paused = _paused
	pause_button.text = "Resume" if _paused else "Pause"

func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	speed_button.text = "%dx" % int(SPEEDS[_speed_index])
