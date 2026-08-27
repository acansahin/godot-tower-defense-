extends Control
class_name EndScreen
## Run summary, either way a Standard run ends (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4):
## clearing Balance.STANDARD_WAVES (Game.victory) or running out of lives (Game.game_over).
## Pauses the tree so nothing keeps moving, and restarts on button press.

@onready var title: Label = $Center/Panel/VBox/Title
@onready var subtitle: Label = $Center/Panel/VBox/Subtitle
@onready var restart_button: Button = $Center/Panel/VBox/RestartButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton

func _ready() -> void:
	restart_button.pressed.connect(_restart)
	menu_button.pressed.connect(_to_menu)
	hide()

## Ends the run and shows how it went. A loss is still framed as a result rather than a
## failure — the wave count is the headline and "you lost" is never said outright — but a
## win says so plainly; the two are different enough events that hedging the win into the
## same neutral language as a loss would undersell the one thing a Standard run can now do
## that it could not before (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4).
## `earned` is the Essence this run banked (Meta.finish_run has already added it). `stars`
## (GAME_STRATEGY_V2.md §12.4, BUILD NEXT #8) is only meaningful when `won` — main.gd's
## _on_victory computes it and has already called Meta.record_stars before this runs;
## show_summary only displays what happened, same division as the Essence line above it.
func show_summary(earned: int, won: bool, stars: int = 0) -> void:
	get_tree().paused = true
	var reached: int = Game.wave_reached
	var star_line := ""
	if won:
		title.text = "VICTORY"
		title.modulate = Color(0.55, 0.92, 0.60)
		star_line = "\n" + "★".repeat(stars) + "☆".repeat(3 - stars)
	else:
		title.text = "WAVE %d" % reached
		title.modulate = Color(1.00, 0.82, 0.35)
	# The Essence line comes first: it is the reason to start another run, and on a loss it
	# is the only part of the run the player keeps. The death-reason line only makes sense
	# on a loss — a win was not caused by any one enemy getting through.
	var reason := "" if won else _death_reason()
	var reason_line := ("\n" + reason) if reason != "" else ""
	subtitle.text = "+%d Essence  ·  %s\nBest: wave %d   ·   Essence: %d%s%s" % [
			earned, _verdict(reached), Meta.best_wave, Meta.essence, reason_line, star_line]
	show()

## One sentence naming the enemy that ended the run (GAME_STRATEGY_V2.md §24.1, BUILD
## NEXT #4) — "Wave 14 — a Fire-armored Regen got through" rather than a bare wave number,
## since the wave itself is usually not surprising but which single enemy actually slipped
## through often is. Empty if nothing has leaked yet (should not happen on a real loss, but
## Game.last_leak_wave staying 0 is the honest way to say "no data" rather than guessing).
func _death_reason() -> String:
	if Game.last_leak_wave <= 0:
		return ""
	var prefix := (Game.last_leak_element.capitalize() + "-armored ") \
			if Game.last_leak_element != "" else ""
	return "Wave %d — a %s%s got through" % [
			Game.last_leak_wave, prefix, Game.last_leak_label]

## A short line acknowledging the depth reached. Measured as a FRACTION of the run rather
## than in wave numbers: the milestones it names are the avatar bosses and the midpoint boss,
## and those follow Balance.STANDARD_WAVES, so hard-coded 10/20/40 stopped describing them
## the moment the run stopped being 20 waves long.
func _verdict(reached: int) -> String:
	var progress := float(reached) / float(maxi(Balance.STANDARD_WAVES, 1))
	if progress >= 0.8:
		return "The road held almost to the end."
	if progress >= 0.5:
		return "Past the Guardian at the midpoint."
	if progress >= 0.2:
		return "You took an element off its avatar."
	if progress >= 0.1:
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
