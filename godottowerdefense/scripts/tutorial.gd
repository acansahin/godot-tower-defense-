extends Node2D
class_name Tutorial
## A compact, self-contained six-tower training match shown before every endless run.
##
## Training has its own painting, open-ended road and scarce build clearings. It deliberately
## does NOT use WaveManager: the lesson advances on actions (build Water, watch it fire,
## upgrade it, then try every element) and only spawns the tiny groups needed to demonstrate
## those actions. Leaving this scene restores Game's main-board profile before Main starts.

const GAME_SCENE := "res://scenes/Main.tscn"
const TOWER := preload("res://scenes/Tower.tscn")
const ENEMY := preload("res://scenes/Enemy.tscn")

const START_GOLD := 500
const START_LIVES := 10
const SPAWN_INTERVAL := 0.85

## One small lesson per basic element. Every tower fights the armour it counters, so the
## complete sequence also walks once around the element circle. Values are deliberately
## hand-tuned teaching encounters, not endless-wave balance data.
const LESSONS: Array = [
	{"tower": "water", "label": "Water: rapid slow", "armor": "fire",
		"count": 4, "hp": 70.0, "speed": 88.0, "interval": 0.62,
		"build": "Place Water in a glowing grass pocket. Its rapid bolts repeatedly slow targets.",
		"combat": "Water beats Fire armour. Watch the blue slow effect and gold ×1.75 damage."},
	{"tower": "fire", "label": "Fire: rapid damage", "armor": "nature",
		"count": 4, "hp": 75.0, "speed": 96.0, "interval": 0.62,
		"build": "Place Fire near a road bend. Its short reach rewards careful positioning.",
		"combat": "Fire beats Nature armour and attacks rapidly, but has the shortest range."},
	{"tower": "nature", "label": "Nature: poison", "armor": "earth",
		"count": 4, "hp": 125.0, "speed": 86.0, "interval": 0.74,
		"build": "Place Nature in another pocket. Poison keeps dealing damage after impact.",
		"combat": "Nature beats Earth armour. The green poison continues ticking between shots."},
	{"tower": "earth", "label": "Earth: splash", "armor": "light",
		"count": 6, "hp": 90.0, "speed": 82.0, "interval": 0.24,
		"build": "Place Earth beside a long road section. Earth hits clustered ground enemies.",
		"combat": "Earth beats Light armour. This tight group demonstrates its splash damage."},
	{"tower": "light", "label": "Light: long range", "armor": "darkness",
		"count": 4, "hp": 85.0, "speed": 100.0, "interval": 0.72,
		"build": "Place Light even if the road looks distant. It has the longest practical reach.",
		"combat": "Light beats Darkness armour and can watch several separated road bends."},
	{"tower": "darkness", "label": "Darkness: heavy hits", "armor": "water",
		"count": 3, "hp": 250.0, "speed": 76.0, "interval": 1.05,
		"build": "Place Darkness in the last free pocket. It fires slowly but hits extremely hard.",
		"combat": "Darkness beats Water armour. Each slow shot delivers the largest basic hit."},
]

## Traced by eye down the centre of winding_forest_close_v1.png. Both ends continue beyond
## the canvas: Scouts enter at the upper-left and leave at the upper-right, matching the art.
const TUTORIAL_PATH: Array = [
	Vector2(86, -70), Vector2(96, 38), Vector2(165, 74), Vector2(202, 120),
	Vector2(205, 205), Vector2(250, 276), Vector2(322, 322), Vector2(455, 337),
	Vector2(551, 359), Vector2(598, 414), Vector2(570, 497), Vector2(505, 570),
	Vector2(478, 643), Vector2(525, 716), Vector2(643, 758), Vector2(781, 758),
	Vector2(900, 698), Vector2(965, 634), Vector2(974, 560), Vector2(937, 496),
	Vector2(873, 459), Vector2(827, 395), Vector2(846, 331), Vector2(919, 276),
	Vector2(1010, 286), Vector2(1102, 331), Vector2(1194, 386), Vector2(1304, 386),
	Vector2(1378, 340), Vector2(1442, 276), Vector2(1415, 211), Vector2(1369, 156),
	Vector2(1378, 101), Vector2(1424, 55), Vector2(1536, 18), Vector2(1620, -28),
]

## Six teaching pads distributed across the four large grassy clearings. Splitting the two
## widest clearings into paired pads guarantees room for all six towers even when a new
## player drops the first one in the middle of a glow.
const BUILD_ZONES: Array = [
	[Vector2(288, 155), 66.0], [Vector2(376, 155), 66.0],
	[Vector2(855, 140), 82.0], [Vector2(360, 455), 80.0],
	[Vector2(620, 600), 72.0], [Vector2(710, 600), 72.0],
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
	Game.configure_board(TUTORIAL_PATH, [], BUILD_ZONES)
	Game.reset()
	Run.reset(0)
	# Fixed teaching budget: all six basics plus Water's first upgrade, with 25 left. Meta
	# progression must not make the lesson's instructions and displayed numbers disagree.
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
	hint_label.text = "Learn the essentials, or press Skip Tutorial to begin the endless run."
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
	# a six-element lineup but cannot steal the demonstration wave's kills.
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
		stage_label.text = "Training 1/6 — Water upgrade"
		hint_label.text = "Tap the Water tower's body to upgrade it. The red × sells for half during real runs."
	else:
		_advance_lesson()

func _finish_lesson() -> void:
	_step = Step.COMPLETE
	palette.hide()
	preview.hide()
	grid.set_showing(false)
	_set_hovered(null)
	stage_label.text = "Training complete"
	hint_label.text = "Ready for the endless run. Build a mixed defence and counter each wave's armour."
	complete_dim.show()
	complete_panel.show()
	play_button.grab_focus()
	Audio.play("wave_clear")
	if OS.get_cmdline_user_args().has("--tutorial-complete-shot"):
		_save_screenshot(0.25, "tutorial_complete.png")

## Harness: completes the action-gated lesson without synthetic mouse events. It exercises
## all six combat groups, Water's upgrade, board-profile movement and completion.
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
	print("--- TUTORIAL COMPLETE: all six towers built and all counter waves cleared ---")

func _find_auto_build_position() -> Vector2:
	# Try the pad centre first, then small offsets. The same search is used after every build,
	# so it proves that a legal six-tower layout exists rather than bypassing placement rules.
	const OFFSETS: Array = [
		Vector2.ZERO, Vector2(-32, 0), Vector2(32, 0), Vector2(0, -32), Vector2(0, 32),
	]
	for entry in BUILD_ZONES:
		for offset in OFFSETS:
			var candidate: Vector2 = entry[0] + offset
			if Game.can_build_at(candidate, towers_root.get_children()):
				return candidate
	return Vector2(-1, -1)

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
