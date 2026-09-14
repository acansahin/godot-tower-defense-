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
## The pause flag changed, by any route. Main shows the pause menu off it.
signal pause_changed(paused: bool)
## Android's back button, or Escape. What it should DO depends on what is open, which is
## Main's to decide — so this only reports it.
signal back_pressed

## Speeds the speed button cycles through. Kept whole numbers — the button label
## formats them with %d.
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

@onready var gold_label: Label = $GoldLabel
@onready var lives_label: Label = $LivesLabel
@onready var wave_label: Label = $WaveLabel
@onready var next_label: Label = $NextLabel
@onready var hint_label: Label = $HintLabel
@onready var send_button: Button = $SendButton
@onready var pause_button: Button = $PauseButton
@onready var speed_button: Button = $SpeedButton

var _speed_index: int = 0
var _paused: bool = false
## Set while an overlay owns the run. This node is process_mode = ALWAYS so that the pause
## button can un-pause — which also means Space still reaches it while the upgrade screen
## is up, and would cheerfully resume the game behind a modal that is still open.
var _blocked: bool = false

func set_input_blocked(value: bool) -> void:
	_blocked = value

func _ready() -> void:
	send_button.pressed.connect(func() -> void: send_pressed.emit())
	pause_button.pressed.connect(toggle_pause)
	speed_button.pressed.connect(cycle_speed)
	# Also the reset: Engine.time_scale is global and survives a scene change, so a
	# fresh level must always re-assert it (Main._ready does the same for `paused`).
	_apply_speed()
	_apply_pause()
	# Until the first wave starts nothing calls set_wave(), so without this the label would
	# sit on the scene file's own English literal for the whole prep phase.
	wave_label.text = tr("HUD_WAVE") % 0

func set_gold(value: int) -> void:
	gold_label.text = tr("HUD_GOLD") % value

func set_lives(value: int) -> void:
	lives_label.text = tr("HUD_LIVES") % value

## No "/ total" — waves are endless, so the number counts up with nothing to count toward.
func set_wave(number: int) -> void:
	wave_label.text = tr("HUD_WAVE") % number
	send_button.disabled = true  # a wave is active now

## Shows a hint along the bottom, or clears it when handed "". The HUD only renders this —
## which hint is current, and when it expires, is the caller's business.
func set_hint(text: String) -> void:
	hint_label.text = text

func set_next(text: String, color: Color) -> void:
	next_label.text = text
	next_label.add_theme_color_override("font_color", color)

## Re-enabled during the between-waves gap.
func enable_send() -> void:
	send_button.disabled = false

# --- Time controls -------------------------------------------------------------

## Space toggles pause, F cycles the speed, Escape is the desktop's back button. Handled here
## rather than in Main because Main stops processing input the moment the tree is paused.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		toggle_pause()
	elif key.keycode == KEY_F:
		cycle_speed()
	elif key.keycode == KEY_ESCAPE:
		back_pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()

## The phone's side of the time controls, here for the same reason as the keys: this node still
## runs while the tree is paused. project.godot sets `quit_on_go_back=false`, without which the
## back button closed the app in the middle of a run.
##
## Going to the background pauses the run. On a phone that is a call, a notification pulled
## down, or the home button — and before this the creeps kept walking behind it. FOCUS_OUT only
## counts on mobile and web: on the desktop it is a developer clicking another window while a
## harness runs, and a harness that pauses itself measures nothing.
func _notification(what: int) -> void:
	if not is_node_ready():
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_pressed.emit()
		NOTIFICATION_APPLICATION_PAUSED:
			pause_for_background()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("mobile") or OS.has_feature("web"):
				pause_for_background()

## Only ever SETS the flag: coming back to the app must not resume a run the player was not
## watching, so the return lands on the pause menu and waits for a tap.
func pause_for_background() -> void:
	if not _paused:
		toggle_pause()

## No-op once the game is over: the end screen owns the pause flag at that point,
## and un-pausing would let the level keep running behind the overlay.
func toggle_pause() -> void:
	if Game.is_over or _blocked:
		return
	_paused = not _paused
	_apply_pause()

func cycle_speed() -> void:
	if Game.is_over or _blocked:
		return
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()

func _apply_pause() -> void:
	get_tree().paused = _paused
	pause_button.text = tr("HUD_RESUME") if _paused else tr("HUD_PAUSE")
	pause_changed.emit(_paused)

func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	speed_button.text = "%dx" % int(SPEEDS[_speed_index])
