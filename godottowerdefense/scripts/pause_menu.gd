extends Control
class_name PauseMenu
## The in-run menu: Resume, Restart, Main Menu. Before it the only way out of a run was to lose
## every life — and with Balance.ENDLESS on that can be an hour away — so a phone player who
## wanted to stop had to kill the app.
##
## It REPORTS what was pressed and Main performs it, the same split as the tower panel, because
## leaving a run banks it (Meta.finish_run) and that is Main's business. The pause flag itself
## stays with the HUD, the one node that keeps processing; this only shows it.
##
## Restart and Main Menu each ask twice. Both throw away a board that may have taken half an
## hour, and on a phone a stray tap is the likeliest way to press either.
##
## PauseMenu.tscn sets process_mode = ALWAYS: it is only ever on screen while the tree is paused.

signal resume_pressed
signal restart_pressed
signal menu_pressed

@onready var _subtitle: Label = $Center/Panel/VBox/Subtitle
@onready var _resume_button: Button = $Center/Panel/VBox/ResumeButton
@onready var _restart_button: Button = $Center/Panel/VBox/RestartButton
@onready var _menu_button: Button = $Center/Panel/VBox/MenuButton

## The button pressed once and waiting for the second press that confirms it, or null.
var _armed: Button = null

func _ready() -> void:
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_restart_button.pressed.connect(_confirm.bind(_restart_button, restart_pressed))
	_menu_button.pressed.connect(_confirm.bind(_menu_button, menu_pressed))
	hide()

## Connected to HUD.pause_changed, so every way of pausing — the button, Space, the back button,
## the app going to the background — lands on the same screen.
func set_open(value: bool) -> void:
	_disarm()
	if value:
		# The Essence line says what leaving costs and pays, which is the question a player
		# holding a Restart button is actually asking. A sandbox run banks nothing, so it says
		# nothing about Essence.
		_subtitle.text = (tr("HUD_WAVE") % Game.wave_reached) if Game.sandbox \
				else tr("PAUSE_SUBTITLE") % [Game.wave_reached, Balance.run_essence(Game.wave_reached)]
	visible = value

func _confirm(button: Button, done: Signal) -> void:
	if _armed == button:
		done.emit()
		return
	_disarm()
	_armed = button
	button.text = tr("PAUSE_CONFIRM")

## Puts both labels back. They are KEYS, so Godot re-translates them on assignment.
func _disarm() -> void:
	_armed = null
	_restart_button.text = "END_RESTART"
	_menu_button.text = "END_MAIN_MENU"
