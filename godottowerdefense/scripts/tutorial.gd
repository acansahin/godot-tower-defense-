extends Node
class_name Tutorial
## Drives the one-line hints shown across the opening of a run.
##
## A separate node rather than logic in hud.gd, because this is gameplay state (what the
## player has and has not done yet), and the HUD's job is to render what it is handed. It
## reads the level's signals and emits text; it never touches a Label.
##
## Deliberately NOT a modal, a mask or a forced sequence. Every step advances on the player
## doing the thing OR on the run moving past it, so a player who already knows the game is
## never blocked — the hints just fall away behind them.

signal hint_changed(text: String)

## Steps in order. `until_wave` is the wave by which a step has expired: once the run
## reaches it the step is skipped even if its action never happened, so a hint can never
## strand a player who solved it a different way (selling the tower they built, say).
enum Step { BUILD, WATCH, UPGRADE, SEND_EARLY, DONE }

const HINTS := {
	Step.BUILD: "Drag a tower from the right onto a square to build it.",
	Step.WATCH: "Towers fire on their own. Each element hits a different armour harder.",
	Step.UPGRADE: "Tap a tower to upgrade it.  Tap the red × to sell it.",
	Step.SEND_EARLY: "Press Send Next ▶ to start a wave early for bonus gold.",
	Step.DONE: "",
}

## The wave at which each step gives up and moves on by itself.
const EXPIRES_AT := {
	Step.BUILD: 3,
	Step.WATCH: 3,
	Step.UPGRADE: 5,
	Step.SEND_EARLY: 7,
}

var _step: int = Step.BUILD
var _wave: int = 0

func _ready() -> void:
	_emit()

## Called by Main when the player builds a tower.
func on_tower_built() -> void:
	if _step == Step.BUILD:
		_advance()

## Called by Main when the player upgrades a tower.
func on_tower_upgraded() -> void:
	if _step == Step.UPGRADE:
		_advance()

## Called by Main when the player calls a wave in early.
func on_sent_early() -> void:
	if _step == Step.SEND_EARLY:
		_advance()

## Called on every wave start. Advances the "watch it work" step, and expires any step the
## run has simply moved past.
func on_wave_started(number: int) -> void:
	_wave = number
	if _step == Step.WATCH:
		_advance()
		return
	while _step != Step.DONE and _wave >= int(EXPIRES_AT.get(_step, 0)):
		_advance()

func _advance() -> void:
	if _step == Step.DONE:
		return
	_step += 1
	_emit()

func _emit() -> void:
	hint_changed.emit(String(HINTS.get(_step, "")))
