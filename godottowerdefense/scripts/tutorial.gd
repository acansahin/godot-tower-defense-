extends Node2D
class_name Tutorial
## A compact, self-contained four-tower training match shown before every Standard run
## (GAME_STRATEGY_V2.md §28 Phase 1: "90 saniyelik tutorial, 5 adım"; BUILD NEXT #10 cut this
## from six element lessons to four and trimmed every hint to <=5 words — the demonstration
## itself (build it, watch it fight its counter, see the number/colour payoff) is the
## teaching; the text is a caption, not the lesson).
##
## Training has its own painting, open-ended road and scarce build clearings. It deliberately
## does NOT use WaveManager: the lesson advances on actions (build Water, watch it fire,
## upgrade it, then try every element) and only spawns the tiny groups needed to demonstrate
## those actions. Leaving this scene clears its profile; Main then selects the wave-1 board.

const GAME_SCENE := "res://scenes/Main.tscn"
const TOWER := preload("res://scenes/Tower.tscn")
const ENEMY := preload("res://scenes/Enemy.tscn")

const START_GOLD := 500
const START_LIVES := 10
const SPAWN_INTERVAL := 0.85

## One small lesson per element (BUILD NEXT #10: six element lessons cut to Game.
## TOWER_ORDER's four). Every tower fights the armour it counters, so the complete sequence
## also walks once around the 4-element ring (GAME_STRATEGY_V2.md §3.3: water -> fire ->
## nature -> earth -> water). Values are deliberately hand-tuned teaching encounters, not
## endless-wave balance data — each is chosen so the lesson's tower clears its group cleanly
## at its OWN Lv1 stats (see game.gd's TOWER_DEFS), verified by --tutorial-auto's leak check.
## Hints are capped at 5 words: the demonstration teaches, the text only names what to watch.
const LESSONS: Array = [
	{"tower": "water", "label": "Water: rapid slow", "armor": "fire",
		"count": 4, "hp": 35.0, "speed": 88.0, "interval": 0.62,
		"build": "Drag Water onto open ground.",
		"combat": "Watch the blue slow, gold damage."},
	{"tower": "fire", "label": "Fire: burns over time", "armor": "nature",
		"count": 3, "hp": 30.0, "speed": 96.0, "interval": 0.72,
		"build": "Place Fire close to the road.",
		"combat": "Fast hits, short range, keeps burning."},
	{"tower": "nature", "label": "Nature: poison ignores armour", "armor": "earth",
		"count": 4, "hp": 40.0, "speed": 86.0, "interval": 0.74,
		"build": "Place Nature anywhere clear.",
		"combat": "Green poison ticks after each hit."},
	{"tower": "earth", "label": "Earth: splash damage", "armor": "water",
		"count": 5, "hp": 25.0, "speed": 82.0, "interval": 0.70,
		"build": "Place Earth near clustered enemies.",
		"combat": "One hit, whole group takes splash."},
]

enum Step { INTRO, BUILD, COMBAT, UPGRADE_WATER, COMPLETE }

@onready var grid: Node2D = $Grid
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var camera: Camera2D = $Camera2D
@onready var preview: Node2D = $Preview
@onready var palette: Control = $UI/TowerPalette
@onready var gold_label: Label = $UI/HUD/GoldLabel
@onready var lives_label: Label = $UI/HUD/LivesLabel
@onready var stage_label: Label = $UI/HUD/StageLabel
@onready var hint_label: Label = $UI/HUD/HintPanel/Hint
@onready var skip_button: Button = $UI/HUD/SkipButton
@onready var intro_dim: ColorRect = $UI/HUD/IntroDim
@onready var intro_panel: CenterContainer = $UI/HUD/IntroPanel
@onready var start_button: Button = $UI/HUD/IntroPanel/Panel/VBox/StartButton
@onready var complete_dim: ColorRect = $UI/HUD/CompleteDim
@onready var complete_panel: CenterContainer = $UI/HUD/CompletePanel
@onready var play_button: Button = $UI/HUD/CompletePanel/Panel/VBox/PlayButton

var _step: int = Step.INTRO
var _lesson_index := 0
var _drag_kind := ""
var _hovered: Tower = null
var _water_tower: Tower = null
var _lesson_tower: Tower = null
var _spawn_timer: Timer
var _to_spawn := 0
var _alive := 0
var _group_hp := 0.0
var _group_speed := 0.0
var _group_armor := ""
var _lesson_start_lives := START_LIVES
var _last_lesson_leaks := 0

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.use_board("winding")
	Game.reset()
	Run.reset(0)
	# Fixed teaching budget: all four basics (4x50=200) plus Water's first upgrade (40), with
	# 260 left over. Meta progression must not make the lesson's instructions and displayed
	# numbers disagree.
	Game.gold = START_GOLD
	Game.lives = START_LIVES
	Game.is_over = false

	camera.position = Game.WORLD_SIZE * 0.5
	camera.zoom = Vector2.ONE * minf(Game.SCREEN_SIZE.x / Game.WORLD_SIZE.x,
			Game.SCREEN_SIZE.y / Game.WORLD_SIZE.y)

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_one)
	add_child(_spawn_timer)

	Game.gold_changed.connect(_set_gold)
	Game.lives_changed.connect(_set_lives)
	palette.drag_started.connect(_on_drag_started)
	skip_button.pressed.connect(_start_game)
	start_button.pressed.connect(_begin_lesson)
	play_button.pressed.connect(_start_game)
	_set_gold(Game.gold)
	_set_lives(Game.lives)
	palette.set_gold(Game.gold)
	palette.set_allowed_towers([])
	palette.hide()
	complete_dim.hide()
	complete_panel.hide()
	stage_label.text = "Training Grounds"
	hint_label.text = "Learn the essentials, or press Skip Tutorial to start the run."
	if OS.get_cmdline_user_args().has("--tutorial-auto"):
		call_deferred("_run_auto_tutorial")
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shot"):
			var parts := String(arg).split(":")
			var delay := float(parts[1]) if parts.size() > 1 else 1.0
			var file := "tutorial_shot_%s.png" % parts[1] if parts.size() > 1 \
					else "tutorial_shot.png"
			_save_screenshot(delay, file)

func _exit_tree() -> void:
	# Scene changes and test quits both pass here. Never let Main inherit this short road.
	Game.use_main_board()

func _set_gold(value: int) -> void:
	gold_label.text = "Gold: %d" % value
	palette.set_gold(value)

func _set_lives(value: int) -> void:
	lives_label.text = "Lives: %d" % value

func _begin_lesson() -> void:
	Audio.play("build")
	intro_dim.hide()
	intro_panel.hide()
	palette.show()
	_lesson_index = 0
	_show_build_step()

func _start_game() -> void:
	Audio.play("build")
	Game.use_main_board()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_drag_started(kind: String) -> void:
	if _step != Step.BUILD or kind != _expected_tower():
		return
	_drag_kind = kind
	grid.set_showing(true)
	_set_hovered(null)
	_update_ghost(get_global_mouse_position())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag_kind == "":
			_update_hover(get_global_mouse_position())
		else:
			_update_ghost(get_global_mouse_position())
		return
	if _drag_kind == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_drop(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _drag_kind != "" or _step != Step.UPGRADE_WATER:
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var tower := _tower_at(get_global_mouse_position())
	if tower == null:
		return
	if tower != _water_tower or tower.is_sell_hit(get_global_mouse_position()):
		Audio.play("denied")
		hint_label.text = "Tap the Water tower's body to upgrade. The red × sells towers during a real run."
		return
	if not _upgrade_water():
		Audio.play("denied")

func _upgrade_water() -> bool:
	if not is_instance_valid(_water_tower) or not _water_tower.can_upgrade() \
			or not Game.spend_gold(_water_tower.upgrade_cost()):
		return false
	_water_tower.upgrade()
	Game.towers_changed.emit()
	Audio.play("upgrade")
	_advance_lesson()
	return true

func _lesson() -> Dictionary:
	return LESSONS[_lesson_index] as Dictionary

func _expected_tower() -> String:
	return String(_lesson()["tower"])

func _show_build_step() -> void:
	_step = Step.BUILD
	var lesson := _lesson()
	palette.set_allowed_towers([String(lesson["tower"])])
	stage_label.text = "Training %d/%d — %s" % [
		_lesson_index + 1, LESSONS.size(), String(lesson["label"])]
	hint_label.text = String(lesson["build"])

func _advance_lesson() -> void:
	if is_instance_valid(_lesson_tower):
		_lesson_tower.set_process(false)
	_lesson_index += 1
	if _lesson_index >= LESSONS.size():
		_finish_lesson()
		return
	_show_build_step()

func _update_hover(world_pos: Vector2) -> void:
	_set_hovered(_tower_at(world_pos))

func _set_hovered(tower: Tower) -> void:
	if _hovered == tower:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(false)
	_hovered = tower
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(true)

func _update_ghost(world_pos: Vector2) -> void:
	var d: Dictionary = Game.TOWER_DEFS[_drag_kind]
	preview.show_at(world_pos,
			Game.can_build_at(world_pos, towers_root.get_children())
					and Game.gold >= int(d["cost"]),
			minf(float(d.get("range", 160.0)) * Balance.WC3_RANGE_SCALE,
					Balance.MAX_TOWER_RANGE), d.get("color", Color.WHITE))

func _drop(world_pos: Vector2) -> void:
	var kind := _drag_kind
	_drag_kind = ""
	preview.hide()
	grid.set_showing(false)
	if _step != Step.BUILD or kind != _expected_tower() \
			or not Game.can_build_at(world_pos, towers_root.get_children()):
		Audio.play("denied")
		return
	var cost := int(Game.TOWER_DEFS[kind]["cost"])
	if not Game.spend_gold(cost):
		Audio.play("denied")
		return
	var tower := TOWER.instantiate() as Tower
	tower.setup_def(kind)
	tower.position = world_pos
	towers_root.add_child(tower)
	Game.towers_changed.emit()
	Audio.play("build")
	_lesson_tower = tower
	# Only the tower introduced by this step may fire. Earlier towers remain on the board as
	# a four-element lineup but cannot steal the demonstration wave's kills.
	for child in towers_root.get_children():
		var built := child as Tower
		if built != null:
			built.set_process(built == _lesson_tower)
	if _lesson_index == 0:
		_water_tower = tower
	_step = Step.COMBAT
	_lesson_start_lives = Game.lives
	_last_lesson_leaks = 0
	palette.set_allowed_towers([])
	hint_label.text = String(_lesson()["combat"])
	_start_group_after_delay()

func _tower_at(world_pos: Vector2) -> Tower:
	var best: Tower = null
	var best_d := Game.TOWER_RADIUS
	for child in towers_root.get_children():
		var tower := child as Tower
		if tower == null:
			continue
		var distance := tower.position.distance_to(world_pos)
		if distance <= best_d:
			best = tower
			best_d = distance
	return best

func _start_group_after_delay() -> void:
	var expected_lesson := _lesson_index
	await get_tree().create_timer(0.8).timeout
	if _step != Step.COMBAT or _lesson_index != expected_lesson:
		return
	var lesson := _lesson()
	_to_spawn = int(lesson["count"])
	_group_hp = float(lesson["hp"])
	_group_speed = float(lesson["speed"])
	_group_armor = String(lesson["armor"])
	_spawn_timer.wait_time = float(lesson.get("interval", SPAWN_INTERVAL))
	_spawn_one()
	if _to_spawn > 0:
		_spawn_timer.start()

func _spawn_one() -> void:
	if _to_spawn <= 0 or Game.is_over:
		_spawn_timer.stop()
		return
	_to_spawn -= 1
	var enemy := ENEMY.instantiate() as Enemy
	enemy.setup(_group_hp, _group_speed, 0,
			Game.ELEMENT_COLORS.get(_group_armor, Color(0.80, 0.55, 0.45)))
	enemy.kind = "tutorial"
	enemy.armor_element = _group_armor
	enemy.radius = Balance.ENEMY_BASE_RADIUS
	enemy.removed.connect(_on_enemy_removed)
	enemies_root.add_child(enemy)
	_alive += 1
	if _to_spawn <= 0:
		_spawn_timer.stop()

func _on_enemy_removed() -> void:
	_alive -= 1
	if _to_spawn <= 0 and _alive <= 0:
		call_deferred("_on_group_cleared")

func _on_group_cleared() -> void:
	if _step != Step.COMBAT:
		return
	_last_lesson_leaks = _lesson_start_lives - Game.lives
	if OS.get_cmdline_user_args().has("--tutorial-auto"):
		print("  tutorial %s: leaks=%d" % [_expected_tower(), _last_lesson_leaks])
	if _lesson_index == 0:
		_step = Step.UPGRADE_WATER
		stage_label.text = "Training 1/%d — Water upgrade" % LESSONS.size()
		hint_label.text = "Tap Water's body to upgrade it."
	else:
		_advance_lesson()

func _finish_lesson() -> void:
	_step = Step.COMPLETE
	palette.hide()
	preview.hide()
	grid.set_showing(false)
	_set_hovered(null)
	stage_label.text = "Training complete"
	hint_label.text = "Ready. Build a mixed defence, counter each wave's armour, and clear all 20 waves to win."
	complete_dim.show()
	complete_panel.show()
	play_button.grab_focus()
	Audio.play("wave_clear")
	if OS.get_cmdline_user_args().has("--tutorial-complete-shot"):
		_save_screenshot(0.25, "tutorial_complete.png")

## Harness: completes the action-gated lesson without synthetic mouse events. It exercises
## all four combat groups, Water's upgrade, board-profile movement and completion.
func _run_auto_tutorial() -> void:
	Engine.time_scale = 8.0
	_begin_lesson()
	await get_tree().process_frame
	for expected_lesson in range(LESSONS.size()):
		if _step != Step.BUILD or _lesson_index != expected_lesson:
			_harness_error("build step", expected_lesson)
			return
		var position := _find_auto_build_position()
		if position.x < 0.0:
			_harness_error("free build pad", expected_lesson)
			return
		_drag_kind = _expected_tower()
		_drop(position)
		var frames := 0
		while _step == Step.COMBAT and frames < 3600:
			await get_tree().process_frame
			frames += 1
		if _last_lesson_leaks > 0:
			_harness_error("leak-free combat", expected_lesson)
			return
		if expected_lesson == 0:
			if _step != Step.UPGRADE_WATER or not _upgrade_water():
				_harness_error("Water upgrade", expected_lesson)
				return
		elif expected_lesson < LESSONS.size() - 1:
			if _step != Step.BUILD or _lesson_index != expected_lesson + 1:
				_harness_error("next lesson", expected_lesson)
				return
	if _step != Step.COMPLETE:
		_harness_error("completion", _lesson_index)
		return
	Engine.time_scale = 1.0
	print("--- TUTORIAL COMPLETE: all four towers built and all counter waves cleared ---")

## Picks the still-free WINDING_BUILD_ZONES pad CLOSEST to the road, not just the first free
## one in array order — a real player reads the hint ("place Fire near a bend") and the live
## range-preview ghost while dragging; this is the harness's equivalent of that judgement.
## Matters most for Fire (170px, the shortest range of the four): the zone list has six pads
## left over from the old six-lesson tutorial, spread out for towers that used to reach much
## further, and array order alone could hand Fire a pad nothing on the road is in range of —
## found exactly this way when the four-lesson rewrite (BUILD NEXT #10) first hit "leaks=3"
## with the pad `_find_auto_build_position` used to return unconditionally.
func _find_auto_build_position() -> Vector2:
	const OFFSETS: Array = [
		Vector2.ZERO, Vector2(-32, 0), Vector2(32, 0), Vector2(0, -32), Vector2(0, 32),
	]
	var best := Vector2(-1, -1)
	var best_dist := INF
	for entry in Game.WINDING_BUILD_ZONES:
		for offset in OFFSETS:
			var candidate: Vector2 = entry[0] + offset
			if not Game.can_build_at(candidate, towers_root.get_children()):
				continue
			var d := Game.dist_to_road(candidate)
			if d < best_dist:
				best_dist = d
				best = candidate
			break  # one legal offset per zone is enough to rank the zone itself
	return best

func _harness_error(point: String, lesson: int) -> void:
	push_error("Tutorial harness failed at %s (lesson=%d, step=%d)" % [point, lesson, _step])
	Engine.time_scale = 1.0
	if OS.get_cmdline_user_args().has("--tutorial-complete-shot"):
		get_tree().quit()

func _save_screenshot(delay: float, file: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://" + file
	var err := image.save_png(path)
	if err != OK:
		push_error("Tutorial screenshot failed: %s" % error_string(err))
		return
	print("--- TUTORIAL SHOT: ", ProjectSettings.globalize_path(path))
	if file == "tutorial_complete.png" \
			and OS.get_cmdline_user_args().has("--tutorial-auto"):
		get_tree().quit()
