extends Node2D
## Title screen — this scene is `run/main_scene`, so it is what the game opens on.
## Pressing Play hands off straight to Main. That click also supplies the user gesture
## browsers require before any audio is allowed to start.
##
## The backdrop USED to be the very same map.gd used in-game, which showed the retired
## `spiral` board while the game is played on `winding`, cropped to the top-left 1280x720
## because this scene has no Camera2D to fit the 1536x864 world. It is now a painted key art
## (`assets/art/menu/menu_bg.png`, generated from docs/menu-art-prompt.md) in the UI layer, so
## the menu no longer depends on the board at all — see docs/menu-art-prompt.md.
##
## The panel and buttons take `assets/theme/ui_theme.tres`, assigned on this scene's Root
## rather than project-wide, so HUD.tscn's buttons are untouched by it.

const GAME_SCENE := "res://scenes/Main.tscn"

@onready var _center: CenterContainer = $UI/Root/Center
@onready var _how_panel: HowToPlay = $UI/Root/HowPanel
@onready var _ruleset_button: Button = $UI/Root/Center/Column/Panel/VBox/RulesetButton
@onready var _play_button: Button = $UI/Root/Center/Column/Panel/VBox/PlayButton
@onready var _how_button: Button = $UI/Root/Center/Column/Panel/VBox/HowButton
@onready var _sound_button: Button = $UI/Root/Center/Column/Panel/VBox/SoundButton
@onready var _quit_button: Button = $UI/Root/Center/Column/Panel/VBox/QuitButton
@onready var _language_button: Button = $UI/Root/Center/Column/Panel/VBox/LanguageButton
@onready var _workshop_button: Button = $UI/Root/Center/Column/Panel/VBox/WorkshopButton
@onready var _status_label: Label = $UI/Root/Center/Column/Panel/VBox/StatusLabel
@onready var _workshop: Workshop = $UI/Root/Workshop

## Cycle order for the Difficulty button — just the two Phase 1 ships (GAME_STRATEGY_V2.md
## §12, §28; BUILD NEXT #8). Hard is a later phase and has no Balance.RULESETS entry yet.
const RULESET_CYCLE := ["normal", "easy"]

func _ready() -> void:
	# Nothing here draws a board any more, so this is not about the backdrop: it restores
	# the geometry lifecycle the run relies on. `Game.use_board()` early-returns on the id it
	# already holds (game.gd:1118) and `configure_board()` is what installs the path, so
	# returning from a run and going straight back in must pass through a different id.
	Game.use_main_board()
	_ruleset_button.pressed.connect(_on_ruleset)
	_play_button.pressed.connect(_on_play)
	_how_button.pressed.connect(_on_how)
	_sound_button.pressed.connect(_on_sound)
	_quit_button.pressed.connect(_on_quit)
	_language_button.pressed.connect(_on_language)
	_how_panel.closed.connect(_on_back)
	_workshop_button.pressed.connect(_on_workshop)
	_workshop.closed.connect(_on_workshop_closed)
	Meta.essence_changed.connect(func(_v: int) -> void: _refresh_status())
	# Godot re-translates a Control's own `text` by itself, so the six plain buttons need
	# nothing. These four are built in code around a value ("Essence: %d"), so they are only
	# rebuilt when that value next changes -- which for a language switch is never.
	Game.locale_changed.connect(func(_l: String) -> void: _refresh_localized())
	_refresh_ruleset_label()
	_refresh_language_label()
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
	# The same for the rules panel, and for the same reason: it is the tallest thing this
	# scene can put on screen, so it is where a theme's content margins overflow first.
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--show-how"):
			_on_how()
			# `--show-how:2` opens straight onto a chosen tab. The tabs need a click, and
			# neither MCP nor a headless run can produce one, so without this only the first
			# of the three pages could ever be photographed.
			var parts := String(arg).split(":")
			if parts.size() > 1:
				_how_panel.show_page(int(parts[1]))
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shot"):
			# `--shot` grabs the menu as it opens; `--shot:3` waits three seconds first, which
			# is how you catch a focus or hover state instead of the resting screen.
			var parts := String(arg).split(":")
			if parts.size() > 1:
				_save_screenshot(float(parts[1]), "shot_%s.png" % parts[1])
			else:
				_save_screenshot(1.0)

## TEMPORARY: saves one frame of the title screen to `user://shot.png` and prints where it
## landed. The twin of main.gd's `_save_screenshot()`, and it is duplicated rather than shared
## for the same reason it exists: the two scripts' only common ancestor is Node, so a shared
## helper would have to be an autoload or a static class, and nine lines do not pay for either.
## It exists at all because the backdrop art, the theme and the scrim all live in RENDERING,
## and no harness that prints numbers can see any of them. `--headless` never calls _draw(),
## so this one must run WITHOUT it:
##
##   Godot.exe --path <project> res://scenes/Menu.tscn --quit-after 200 -- --shot:2
##   Godot.exe --path <project> res://scenes/Menu.tscn --quit-after 200 -- --show-workshop --shot:2
##
## The wait is not decoration: the viewport texture is only complete after a frame has been
## drawn, and grabbing it in _ready gives back an empty image.
func _save_screenshot(delay: float, file := "shot.png") -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://" + file
	var err := image.save_png(path)
	if err != OK:
		print("--- SHOT FAILED: ", error_string(err))
		return
	print("--- SHOT: ", ProjectSettings.globalize_path(path))

## The wallet, the record, and — once only, on the launch that earned it — what came in
## while the player was away. The offline line is the reason to reopen the app, so it goes
## where it is seen before anything is clicked.
func _refresh_status() -> void:
	var parts := PackedStringArray()
	if Meta.pending_offline > 0:
		parts.append(tr("STATUS_OFFLINE") % Meta.pending_offline)
	parts.append(tr("STATUS_ESSENCE") % Meta.essence)
	if Meta.best_wave > 0:
		parts.append(tr("STATUS_BEST") % Meta.best_wave)
	# Stars for the CURRENTLY SELECTED ruleset only (GAME_STRATEGY_V2.md §12.4, BUILD NEXT
	# #8) — showing both at once would need the reader to remember which row is which; this
	# way the star line always answers "how did I do at the difficulty I am about to play".
	var earned_stars := Meta.stars_for(Game.ruleset)
	if earned_stars > 0:
		parts.append("%s: %s%s" % [Game.ruleset.capitalize(),
				"★".repeat(earned_stars), "☆".repeat(3 - earned_stars)])
	_status_label.text = "\n".join(parts)

## Cycles Game.ruleset (GAME_STRATEGY_V2.md §12, BUILD NEXT #8). Not persisted across
## sessions on purpose for now — Meta owns what outlives a run, and a difficulty pick is
## closer to "what am I about to play" than permanent progression; Game.ruleset already
## survives a mid-run retry (see game.gd's reset()), which is the case that actually matters.
func _on_ruleset() -> void:
	var i := RULESET_CYCLE.find(Game.ruleset)
	Game.ruleset = String(RULESET_CYCLE[(maxi(i, 0) + 1) % RULESET_CYCLE.size()])
	Audio.play("build")
	_refresh_ruleset_label()
	_refresh_status()  # the star line below is ruleset-specific

func _refresh_ruleset_label() -> void:
	_ruleset_button.text = tr("MENU_DIFFICULTY") % tr("DIFF_" + Game.ruleset.to_upper())

func _refresh_language_label() -> void:
	_language_button.text = tr("MENU_LANGUAGE") % Game.locale_display_name()

## Every label this scene builds in code rather than leaving to Godot's own re-translation.
func _refresh_localized() -> void:
	_refresh_ruleset_label()
	_refresh_language_label()
	_refresh_sound_label()
	_refresh_status()

## Cycles Game.LOCALES and stores the choice. The panel below and the whole game follow from
## TranslationServer, so there is nothing else to push.
func _on_language() -> void:
	Game.cycle_locale()
	Audio.play("build")

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
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_how() -> void:
	Audio.play("build")
	_center.hide()
	_how_panel.open()

## Reached from HowToPlay's own Back button, which plays its own sound.
func _on_back() -> void:
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
	_sound_button.text = tr("MENU_SOUND_OFF") if Audio.is_muted() else tr("MENU_SOUND_ON")
