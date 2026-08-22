extends Node2D
## Wires the level together: grid-based tower placement (drag from the palette
## onto a cell), click-to-upgrade / tap-the-× to sell, and the HUD, then kicks off
## the waves.

const TOWER := preload("res://scenes/Tower.tscn")
const SHAKE_DECAY := 26.0  ## Pixels of camera shake bled off per second.

@onready var grid = $Grid
@onready var map = $Map
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var palette = $UI/TowerPalette
@onready var end_screen: EndScreen = $UI/EndScreen
@onready var upgrade_choice: UpgradeChoice = $UI/UpgradeChoice
@onready var branch_choice: BranchChoice = $UI/BranchChoice
@onready var element_choice: ElementChoice = $UI/ElementChoice
@onready var camera: Camera2D = $Camera2D
@onready var preview = $Preview  ## Drag ghost.

var _drag_kind: String = ""  ## Tower type being dragged from the palette ("" = none).
var _hovered: Tower = null   ## Tower under the mouse, drawn with a clear range ring.
var _shake: float = 0.0      ## Current camera shake magnitude in px; decays to 0.
var _auto_pick: bool = false ## Harness only (--fill-board/--auto-pick): auto-resolve upgrade AND branch choices.
## The tower waiting on a Lv3 branch pick, or null. Set right before branch_choice.show_choices()
## and read back in _on_branch_chosen — the popup itself only reports WHICH branch, not for
## which tower, since (unlike the roguelite choice) this decision belongs to one specific tower.
var _pending_branch_tower: Tower = null
var _auto_pick_branch_toggle: int = 0  ## Alternates "a"/"b" for --fill-board's branch auto-pick.
## Monoculture card awaiting its element sub-choice, or {} — see _on_upgrade_chosen /
## _on_element_chosen. Same one-in-flight-at-a-time pattern as _pending_branch_tower.
var _pending_monoculture_card: Dictionary = {}
## Standard mode's one board (GAME_STRATEGY_V2.md §28 Phase 1: "1 harita", BUILD NEXT #8).
## `Game.use_board_for_wave()`'s 10-wave winding->spiral->s rotation (Game.BOARD_SEQUENCE)
## is now Endless-only infrastructure, unreached from here — same treatment step 4 gave
## WaveGenerator. A Standard run stays on this board from wave 1 through Game.STANDARD_WAVES.
const STANDARD_BOARD := "winding"

## Harness only (`--map:s`): holds one board for a focused playtest instead of the default.
var _board_override: String = ""

func _ready() -> void:
	get_tree().paused = false
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--map:"):
			_board_override = String(arg).trim_prefix("--map:")
	Game.use_board(STANDARD_BOARD if _board_override == "" else _board_override, false)
	# One seed drives both the waves and the card offers, so a whole run — what it throws at
	# you and what it lets you answer with — replays from a single number.
	var run_seed := randi()
	Game.reset()
	Run.reset(run_seed)

	hud.set_gold(Game.gold)
	hud.set_lives(Game.lives)
	palette.set_gold(Game.gold)

	Game.gold_changed.connect(hud.set_gold)
	Game.gold_changed.connect(palette.set_gold)
	Game.lives_changed.connect(hud.set_lives)
	Game.game_over.connect(_on_game_over)
	Game.victory.connect(_on_victory)
	wave_manager.wave_starting.connect(_on_wave_starting)
	wave_manager.wave_started.connect(hud.set_wave)
	wave_manager.wave_preview.connect(hud.set_next)
	wave_manager.prep_started.connect(hud.enable_send)
	hud.send_pressed.connect(wave_manager.send_now)
	palette.drag_started.connect(_on_drag_started)
	Game.shake_requested.connect(_add_shake)

	# Roguelite choice. Main owns the pause so there is exactly one place that decides
	# whether the run is running — the choice screen itself only reports what was picked.
	wave_manager.choice_due.connect(_on_choice_due)
	upgrade_choice.chosen.connect(_on_upgrade_chosen)
	branch_choice.chosen.connect(_on_branch_chosen)
	element_choice.chosen.connect(_on_element_chosen)

	# Frame the WHOLE world, once. There is no panning: a tower defense you have to scroll
	# is one where the leak that just cost you a life happened somewhere you were not
	# looking. The world is a 16:9 box like the viewport, so a single zoom fits it exactly
	# on both axes with nothing cropped and no letterboxing.
	camera.position = Game.WORLD_SIZE * 0.5
	camera.zoom = Vector2.ONE * minf(Game.SCREEN_SIZE.x / Game.WORLD_SIZE.x,
			Game.SCREEN_SIZE.y / Game.WORLD_SIZE.y)

	wave_manager.enemies_root = enemies_root
	wave_manager.start(run_seed)
	if OS.get_cmdline_user_args().has("--show-road"):
		map.show_road = true
		map.queue_redraw()

	# Must run BEFORE any dump. Meta's Workshop levels feed Run.permanent, which feeds every
	# tower stat — so a --dump-stats taken against a save with purchases in it is measuring
	# something different from one taken against a clean save. Wipe first when comparing to
	# a stored baseline.
	if OS.get_cmdline_user_args().has("--wipe-save"):
		Save.clear()
		Meta._load()
		Run.reset(0)
		Game.reset()
	if OS.get_cmdline_user_args().has("--dump-stats"):
		_dump_tower_stats()
	if _fill_board_requested():
		_fill_board()
	if OS.get_cmdline_user_args().has("--air-pose"):
		_air_pose()
	if OS.get_cmdline_user_args().has("--boss-pose"):
		_boss_pose()
	# TEMPORARY: answers the roguelite choice screen for you. Not decoration for --shot: the
	# choice screen pauses the tree, and a paused tree stops the SceneTree timers every
	# delayed harness waits on — so an unattended run simply stops at wave 3 and every later
	# `--shot:N` silently never fires. --fill-board turns this on for itself; anything else
	# that wants to watch a late wave has to ask.
	if OS.get_cmdline_user_args().has("--auto-pick"):
		_auto_pick = true
	if OS.get_cmdline_user_args().has("--dump-waves"):
		_dump_waves()
	if OS.get_cmdline_user_args().has("--dump-mods"):
		_dump_mods()
	if OS.get_cmdline_user_args().has("--dump-board"):
		_dump_board()
	if OS.get_cmdline_user_args().has("--test-sell-hit"):
		call_deferred("_test_sell_hit")
	# TEMPORARY: pops the choice screen immediately, so its _draw can be exercised in a
	# rendered run without first playing three waves. Headless never calls _draw at all, so
	# nothing else in the suite would catch a broken card layout.
	if OS.get_cmdline_user_args().has("--dump-meta"):
		_dump_meta()
	# TEMPORARY: rewinds the "last seen" stamp so the NEXT launch collects an offline
	# reward. The only way to exercise _collect_offline without waiting hours or changing
	# the system clock — and offline is a feature whose bugs are all in the time arithmetic.
	if OS.get_cmdline_user_args().has("--go-back"):
		Meta.last_seen -= 4 * 3600
		Meta._persist()
		print("--- clock rewound 4h; relaunch to collect ---")
	if OS.get_cmdline_user_args().has("--show-choice"):
		_on_choice_due(30)  # late wave: exercises the higher-rarity cards and NEW TOWER
	for arg in OS.get_cmdline_user_args():
		# `--show-branch-choice` (default "fire") or `--show-branch-choice:water` etc. — pops
		# the Lv3 branch popup so its _draw() can be exercised without playing a tower to
		# level 3 first. Mirrors --show-choice above.
		if String(arg).begins_with("--show-branch-choice"):
			var parts := String(arg).split(":")
			branch_choice.show_choices(parts[1] if parts.size() > 1 else "fire")
		# `--show-element-choice` — pops Monoculture's sub-choice popup (BUILD NEXT #9) so its
		# _draw() can be exercised without rolling it out of the card pool first.
		if String(arg) == "--show-element-choice":
			element_choice.show_choices()
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shot"):
			# `--shot` grabs the opening board; `--shot:20` waits 20 seconds first, which is
			# how you photograph a wave in flight rather than an empty map. Several may be
			# passed at once — each lands in its own file — which is how you watch a run
			# through several waves without relaunching once per wave.
			var parts := String(arg).split(":")
			if parts.size() > 1:
				_save_screenshot(float(parts[1]), "shot_%s.png" % parts[1])
			else:
				_save_screenshot(1.0)

## WaveManager emits this before deriving stats or creating the first enemy. Used to also
## rotate the board by wave chapter; a Standard run now stays on STANDARD_BOARD for its whole
## length (see _ready()), so this is a no-op every wave (Game.use_board() already short-
## circuits on the board it is already showing) except to keep the `number` parameter's
## signal shape intact for whatever Endless mode reconnects here later.
func _on_wave_starting(number: int) -> void:
	var previous_board := Game.active_board_id
	Game.use_board(STANDARD_BOARD if _board_override == "" else _board_override, false)
	grid.queue_redraw()
	if previous_board == Game.active_board_id:
		return
	var moved := _relocate_towers_for_board()
	Game.towers_changed.emit()
	hud.set_hint("New map: %s%s" % [Game.active_board_id.capitalize(),
			" — %d towers moved to clear ground" % moved if moved > 0 else ""])
	_clear_map_hint_later()
	if _fill_board_requested():
		print("--- MAP CHANGE @ wave %d: %s (%d towers moved) ---"
				% [number, Game.active_board_id, moved])

## Keeps the player's investment through a chapter change without leaving a tower standing
## in the new road, water or blocked scenery. Legal towers stay exactly where the player put
## them; only invalid ones move to the nearest open position on a fine placement sweep.
func _relocate_towers_for_board() -> int:
	var occupied: Array = []
	var displaced: Array[Tower] = []
	for child in towers_root.get_children():
		var tower := child as Tower
		if tower == null:
			continue
		if Game.can_build_at(tower.position):
			occupied.append(tower.position)
		else:
			displaced.append(tower)
	var candidates := _buildable_lattice(Game.TOWER_GAP * 0.5)
	var moved := 0
	for tower in displaced:
		var best := Vector2.ZERO
		var best_distance := INF
		var found := false
		for candidate in candidates:
			if not _far_enough(candidate, occupied):
				continue
			var distance := tower.position.distance_squared_to(candidate)
			if distance < best_distance:
				best = candidate
				best_distance = distance
				found = true
		if not found:
			push_warning("No legal relocation position for tower at %s" % tower.position)
			continue
		tower.position = best
		occupied.append(best)
		moved += 1
	return moved

func _clear_map_hint_later() -> void:
	await get_tree().create_timer(4.0).timeout
	hud.set_hint("")

## TEMPORARY: saves one frame of the running game to `user://shot.png` and prints where it
## landed. Every other harness here prints numbers, and numbers cannot see a board — the
## grid overlapping the HUD, a road drawn behind the tower palette, a marker that vanishes
## at phone scale. `--headless` never calls _draw(), so this one must run WITHOUT it:
##
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 150 -- --shot
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 4000 -- --shot:60 --shot:120
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

## TEMPORARY verification harness for the roguelite modifier layer. Proves the three things
## that would otherwise only show up as a vague "the cards feel like they do nothing":
##   1. a card actually moves the stat it claims to, by the amount it claims;
##   2. an element-scoped card touches ONLY that element;
##   3. removing it returns the tower exactly to baseline — the whole point of rebuilding
##      stats instead of accumulating them, and the one thing playing can never check.
func _dump_mods() -> void:
	var probe := func(label: String) -> void:
		var line := label.rpad(22)
		for tid in Game.TOWER_ORDER:
			var t := TOWER.instantiate() as Tower
			towers_root.add_child(t)
			t.setup_def(String(tid))
			line += "%s dmg=%.3f int=%.4f rng=%.1f slowt=%.2f burnt=%.2f  " \
					% [tid, t.damage, t.fire_interval, t.tower_range, t.slow_time, t.burn_time]
			t.queue_free()
		print(line)

	print("--- MOD DUMP BEGIN ---")
	Run.reset(1)
	probe.call("baseline")
	# One card from each new BUILD NEXT #9 shape: an element-scoped mult-op stat (wick,
	# burn_time), an element-scoped add-op stat (permafrost, slow_time), a global add-op stat
	# (long_sight, range) and a global mult-op stat (bulwark, damage).
	Run.grant(_pool_entry("wick"))
	probe.call("+wick")
	Run.grant(_pool_entry("permafrost"))
	probe.call("+permafrost")
	Run.grant(_pool_entry("long_sight"))
	probe.call("+long_sight")
	Run.grant(_pool_entry("bulwark"))
	probe.call("+bulwark")
	Run.reset(1)
	# Monoculture's real path (main.gd _on_upgrade_chosen -> element_choice ->
	# _on_element_chosen), driven directly rather than through the UI — proves the
	# per-effect element override (run.gd's _effect_applies) actually lands +50%/-20% on the
	# right towers instead of just rendering the popup correctly.
	_on_upgrade_chosen(_pool_entry("monoculture"))
	_on_element_chosen("fire")
	probe.call("+monoculture:fire")
	Run.reset(1)
	probe.call("after reset")
	# Roster sanity: BUILD NEXT #2 removed the dual-recipe gate (owning both elements of a
	# pair used to add a fifth+ tower to the palette), so buildable_towers() should now be
	# nothing more than the four base elements, stable across a reset.
	print("roster @start:        %s" % str(Run.buildable_towers()))
	Run.reset(1)
	print("roster after reset:   %s" % str(Run.buildable_towers()))
	print("gold/kill before: %d" % Run.bonus_gold_per_kill())
	Run.grant(_pool_entry("prospector"))
	Run.grant(_pool_entry("prospector"))
	print("gold/kill after 2x Prospector: %d" % Run.bonus_gold_per_kill())
	# Frontload's kill_gold_mult (BUILD NEXT #9) — separate global fold from the flat
	# bonus_gold_per_kill above; see run.gd's kill_gold_mult() comment for why they must not
	# collapse into one number.
	print("kill gold mult before: %.2f" % Run.kill_gold_mult())
	Run.grant(_pool_entry("frontload"))
	print("kill gold mult after Frontload: %.2f" % Run.kill_gold_mult())
	# Offer sanity: no duplicates within one offer, and nothing offered past its stack cap.
	Run.reset(7)
	for w in [3, 9, 30]:
		var opts := Run.roll_choices(w)
		var names := PackedStringArray()
		for o in opts:
			names.append("%s(%s)" % [String((o as Dictionary)["name"]),
					String((o as Dictionary)["rarity"])])
		print("offer @w%-3d %s" % [w, ", ".join(names)])
	print("--- MOD DUMP END ---")

## TEMPORARY verification harness for meta progression. Checks the things that only show up
## across an app restart or a wall-clock change, neither of which is testable by playing:
## the essence curve, workshop costs, that a bought level actually reaches a tower via the
## SAME fold the roguelite cards use, and that start gold/lives move.
##
## Pass `--wipe-save` first to start from a clean slate; without it this runs against the
## real save, which is the point when checking that a purchase survived a relaunch.
func _dump_meta() -> void:
	print("--- META DUMP BEGIN ---")
	print("fresh=%s essence=%d best=%d runs=%d offline_collected=%d levels=%s"
			% [Save.is_fresh, Meta.essence, Meta.best_wave, Meta.total_runs,
				Meta.pending_offline, str(Meta.levels)])
	print("run essence by wave: 5=%d 10=%d 20=%d 40=%d 80=%d" % [
			Balance.run_essence(5), Balance.run_essence(10), Balance.run_essence(20),
			Balance.run_essence(40), Balance.run_essence(80)])
	print("offline (best=20): 1min=%d 1h=%d 4h=%d 8h=%d 48h(capped)=%d" % [
			Balance.offline_essence(60.0, 20), Balance.offline_essence(3600.0, 20),
			Balance.offline_essence(4.0 * 3600.0, 20), Balance.offline_essence(8.0 * 3600.0, 20),
			Balance.offline_essence(48.0 * 3600.0, 20)])
	print("forge cost by level: %s" % str(_costs("forge")))

	var probe := func(label: String) -> void:
		Run.reset(1)  # re-seeds `permanent` from Meta
		Game.reset()
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def("fire")
		print("%s fire dmg=%.4f rng=%.2f int=%.5f | start gold=%d lives=%d"
				% [label.rpad(20), t.damage, t.tower_range, t.fire_interval, Game.gold, Game.lives])
		t.queue_free()

	probe.call("no workshop")
	Meta.add_essence(100000)
	for i in 3:
		Meta.buy("forge")
	probe.call("forge x3")
	Meta.buy("lens")
	Meta.buy("tempo")
	probe.call("+lens +tempo")
	for i in 2:
		Meta.buy("treasury")
	Meta.buy("ramparts")
	probe.call("+treasury x2 +ramp")
	print("essence left=%d levels=%s" % [Meta.essence, str(Meta.levels)])
	# Settings round-trip. The mute flag was the one piece of state the game already had a
	# UI for and still forgot on every launch, so it is worth asserting it now persists.
	print("muted loaded as=%s -> writing true" % Audio.is_muted())
	Audio.set_muted(true)
	print("settings section now=%s" % str(Save.get_section("settings")))
	print("--- META DUMP END ---")

func _costs(id: String) -> Array:
	var d := Meta.def_of(id)
	var out: Array = []
	for lv in 5:
		out.append(Balance.workshop_cost(int(d["base_cost"]), float(d["cost_growth"]), lv))
	return out

func _pool_entry(id: String) -> Dictionary:
	for u in Game.UPGRADE_POOL:
		if String((u as Dictionary)["id"]) == id:
			return u
	push_error("no such upgrade: " + id)
	return {}

## TEMPORARY verification harness for the endless wave generator. Prints the definition of
## each wave, marks where the hand-authored seed table hands over, and — the part that
## matters — asks for every wave TWICE to prove wave_def(n) is pure. The HUD previews wave
## n+1 while wave n is spawning, so a generator that drifted between calls would advertise
## a different wave than the one that arrives, and nothing else would catch it.
func _dump_waves() -> void:
	var gen := WaveGenerator.new(12345)
	var seed_count: int = Game.WAVES.size()
	var impure := 0
	print("--- WAVE DUMP BEGIN (seed table = waves 1-%d) ---" % seed_count)
	for n in range(1, 61):
		var def: Dictionary
		var src: String
		if n <= seed_count:
			def = Game.WAVES[n - 1]
			src = "table"
		else:
			def = gen.wave_def(n)
			src = "gen"
			if str(gen.wave_def(n)) != str(def):
				impure += 1
		var flags := ""
		if def.get("boss", false):
			flags += " BOSS"
		if float(def.get("hp", 1.0)) != 1.0:
			flags += " hp=%.2f" % float(def.get("hp", 1.0))
		if float(def.get("count", 1.0)) != 1.0:
			flags += " count=%.2f" % float(def.get("count", 1.0))
		print("w%02d [%s] %-8s el=%-6s%s" % [n, src, String(def["type"]),
				String(def.get("element", "-")), flags])
	print("--- WAVE DUMP END (impure generated waves: %d) ---" % impure)

## TEMPORARY verification harness: parks a row of Air creeps along the road with an empty
## board, so the flyer's own drawing can be photographed. `--fill-board` cannot do this — it
## buries the road under towers and kills every creep at its spawn point — and a normal run
## does not reach the Air wave (6) without leaking away all twenty lives first.
##
## What it is for is the half of enemy.gd that numbers cannot check: the wingbeat carrier,
## the trailing air strokes, and whether the health bar still sits over the creature once the
## body is lifted off its anchor. Pair it with --shot, and WITHOUT --headless:
##   Godot.exe --path <project> res://scenes/Main.tscn -- --air-pose --shot:3
## Delete this and its call above once the flyer art lands.
func _air_pose() -> void:
	wave_manager.set_process(false)
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var def: Dictionary = Game.WAVE_TYPES["air"]
	# Spread along the path so several headings are on screen at once — the sprite is drawn
	# facing screen-left and mirrored for the other way, and the streaks mirror with it, so
	# one heading proves nothing about the other.
	for i in range(8):
		var e := enemy_scene.instantiate() as Enemy
		e.setup(400.0, 30.0, 5, Color(def["color"]))
		e.kind = "air"
		# The same expression WaveManager._spawn_one uses. Hardcoding the base radius made this
		# harness lie about size the moment the archetype was given a multiplier.
		e.radius = Balance.ENEMY_BASE_RADIUS * float(def.get("radius", 1.0))
		e.make_flying()
		enemies_root.add_child(e)
		var step := int(float(Game.active_path.size() - 2) * float(i) / 8.0) + 1
		e.set_progress(step)
		e.global_position = Game.active_path[step]
		# Half of them damaged, so the health bar is visible against the lifted body.
		if i % 2 == 1:
			e.take_damage(150.0)

## TEMPORARY verification harness: stages both bosses' rules (GAME_STRATEGY_V2.md §10.4,
## BUILD NEXT #7) on an empty board so cc_immune's ward and rotating_armor's icon/ring can be
## photographed without playing to wave 10 or 20 first. Pair with --shot, WITHOUT --headless:
##   Godot.exe --path <project> res://scenes/Main.tscn -- --boss-pose --shot --shot:6
## (the second shot is timed past ROTATING_ARMOR_PERIOD so the ring/icon is caught having
## already turned over at least once). Delete this and its call above once photographed.
func _boss_pose() -> void:
	wave_manager.set_process(false)
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var rules := [
		{"element": "water", "rule": "control_immune"},
		{"element": "fire", "rule": "rotating_armor"},
	]
	for i in rules.size():
		var e := enemy_scene.instantiate() as Enemy
		e.setup(2000.0, 20.0, 50, Balance.BOSS_TINT)
		e.kind = "tank"
		e.radius = Balance.BOSS_RADIUS
		e.is_boss = true
		e.armor_element = String(rules[i]["element"])
		match String(rules[i]["rule"]):
			"control_immune": e.cc_immune = true
			"rotating_armor": e.rotating_armor = true
		enemies_root.add_child(e)
		var step := int(float(Game.active_path.size() - 2) * float(i + 1) / float(rules.size() + 1)) + 1
		e.set_progress(step)
		e.global_position = Game.active_path[step]
		e.take_damage(2000.0 * 0.35)  # dent the health bar so it reads against a full boss

## TEMPORARY verification harness: covers every buildable cell with towers, cycling the
## roster, so a headless run actually exercises targeting, firing, the projectile pool and
## the effect payloads. Without it a headless run has no towers and proves nothing about
## the combat path. Gold is granted rather than spent so placement never fails.
##   Godot.exe --headless --path <project> res://scenes/Main.tscn --quit-after 900 -- --fill-board
## Delete this and its call above once the refactor has landed and been verified.
## True for either --fill-board or its real-time timing variant --fill-board:1x (BUILD
## NEXT #10) — `.has()` alone only matches the bare flag exactly, so both call sites need
## this rather than one `.has("--fill-board")` check.
func _fill_board_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--fill-board") or args.has("--fill-board:1x")

func _fill_board() -> void:
	# Headless runs one frame at a time regardless of wall clock, so the only way to cover
	# many waves in a bounded frame budget is to make each frame simulate more time. Skipped
	# by `--fill-board:1x` (BUILD NEXT #10's "GERÇEK BİR RUN'I ÖLÇ") — timing how long a
	# Standard run actually takes needs REAL wall-clock pacing, which is the one thing this
	# acceleration exists to avoid everywhere else.
	if not OS.get_cmdline_user_args().has("--fill-board:1x"):
		Engine.time_scale = 8.0
	_auto_pick = true
	Game.add_gold(999999)
	# Real WALL-CLOCK elapsed time (not scaled by Engine.time_scale — Time.get_ticks_msec is
	# an OS clock, unaffected by it either way), for --fill-board:1x's job of answering
	# GAME_STRATEGY_V2.md §11.2's own unmeasured guess: does a 20-wave Standard run actually
	# take ~10.5 minutes? (BUILD NEXT #10.) Meaningless at the default 8x speed, printed
	# regardless since it costs nothing extra to include.
	var start_ms := Time.get_ticks_msec()
	# The end screen pauses the tree, so a run that ends looks exactly like a hang from the
	# outside. Say so explicitly instead. Standard mode can now be WON (BUILD NEXT #4) — a
	# fully maxed board plausibly clears all 20 waves, so both outcomes need a line or a win
	# would silently look identical to the harness just hanging at frame budget.
	var report := func(outcome: String) -> void:
		# Deferred: _on_game_over/_on_victory bank the run, and reading Meta before that has
		# happened would report the wallet as it was a moment BEFORE the reward landed.
		await get_tree().process_frame
		var elapsed_s := float(Time.get_ticks_msec() - start_ms) / 1000.0
		print("--- RUN %s: wave %d | best %d | essence %d | runs %d | elapsed %.1fs (%.1fmin) ---"
				% [outcome, Game.wave_reached, Meta.best_wave, Meta.essence, Meta.total_runs,
					elapsed_s, elapsed_s / 60.0])
	Game.game_over.connect(func() -> void: report.call("OVER"))
	Game.victory.connect(func() -> void: report.call("WON"))
	var i := 0
	# No cells to walk any more: sweep the play area on the tower spacing and take every
	# spot the placement rule allows, which is the closest thing to "a full board" that free
	# placement has.
	for spot in _buildable_lattice():
		var kind := String(Game.TOWER_ORDER[i % Game.TOWER_ORDER.size()])
		var t := TOWER.instantiate() as Tower
		t.setup_def(kind)
		t.position = spot
		towers_root.add_child(t)
		# Max them out: Ice's area-slow (and the frost ring it spawns) only exists from
		# Lv2, so a board of Lv1 towers would never touch that path.
		while t.can_upgrade():
			t.upgrade()
			# --fill-board bypasses _upgrade_tower() (it grants a gold lump instead of
			# spending exact costs), so the Lv3 branch trigger there never fires — do it
			# here instead, alternating so both branches of every element get exercised.
			if t.level == 3 and t.branch == "":
				t.set_branch("a" if (i % 2 == 0) else "b")
		i += 1
	print("--- FILL BOARD: placed %d towers, all at max level ---" % i)

## Every position a tower could stand, swept on the tower spacing. Used by --fill-board and
## by --dump-board, which need "the set of places you may build" now that the board no
## longer keeps one.
func _buildable_lattice(step := -1.0) -> Array:
	var pitch: float = Game.TOWER_GAP if step <= 0.0 else step
	var out: Array = []
	var y := Game.PLAY_TOP + Game.TOWER_RADIUS
	while y <= Game.WORLD_SIZE.y - Game.TOWER_RADIUS:
		var x := Game.TOWER_RADIUS
		while x <= Game.PLAY_RIGHT - Game.TOWER_RADIUS:
			var at := Vector2(x, y)
			if Game.can_build_at(at) and _far_enough(at, out):
				out.append(at)
			x += pitch * 0.5
		y += pitch * 0.5
	return out

func _far_enough(at: Vector2, taken: Array) -> bool:
	for other in taken:
		if at.distance_to(other) < Game.TOWER_GAP:
			return false
	return true

## Measures the BOARD rather than the towers: how much of the road one tower can watch,
## and how many towers it takes to watch all of it.
##
## This exists because "Light covers half the board" was an assertion nobody had checked.
## Tower ranges are now the source map's, and that map's boards are far larger than ours,
## so the ratio of range to road length is the number that actually moved — not any single
## stat. Redesigning the path by eye cannot tell you whether it improved; this can.
##
## `cover` is the honest headline: the number of towers of that element, placed greedily on
## the best cells, needed to bring 95% of the road inside somebody's range. A board where
## two towers cover everything has no placement decisions left in it.
##
## `raw` is the same "best 1" measured with Balance.MAX_TOWER_RANGE lifted — the ported
## range as the source map wrote it. That column judges the SHAPE of the board rather than
## our cap, which is what makes it comparable with the original's own arena as printed by
## `python tools/extract_w3x.py "<map>.w3x" pathing`. Everything left of it is the board
## you actually play on.
##
##   Godot.exe --headless --path <project> res://scenes/Main.tscn --quit-after 5 -- --dump-board
func _dump_board() -> void:
	print("--- BOARD DUMP BEGIN ---")
	# Sample the road evenly. 12px is well under the smallest range (Fire, 175px), so the
	# sampling grain never decides the answer.
	const STEP := 12.0
	var samples: Array[Vector2] = []
	var path: Array = Game.active_path
	var total := 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg := a.distance_to(b)
		total += seg
		# A smoothed path has many segments shorter than STEP. Each still needs one sample;
		# dropping them made a denser, better route look shorter to the coverage harness.
		var n := maxi(1, ceili(seg / STEP))
		for k in n:
			samples.append(a.lerp(b, float(k) / float(n)))
	# The candidate set is every legal STANDING SPOT, swept on the tower spacing — the board
	# keeps no cell list any more. Coverage therefore answers the question free placement
	# actually poses: how much road can one tower watch from the best place it may stand.
	var spots: Array = _buildable_lattice()
	print("  road length      : %.0f px over %d waypoints" % [total, path.size()])
	print("  buildable spots  : %d (on a %.0fpx sweep)" % [spots.size(), Game.TOWER_GAP])
	print("  road samples     : %d (every %.0f px)" % [samples.size(), STEP])
	print("  %-10s %7s %8s %8s  %-12s %7s %8s"
			% ["element", "range", "best 1", "median", "cover 95%", "raw", "raw best"])
	for tid in Game.TOWER_ORDER:
		var def: Dictionary = Game.TOWER_DEFS[String(tid)]
		# Same formula as Tower._recompute, cap included — the columns that describe the
		# board you play on must measure the range you actually get.
		var raw: float = float(def.get("range", 0.0)) * Balance.WC3_RANGE_SCALE
		var r: float = minf(raw, Balance.MAX_TOWER_RANGE)
		var r_sq := r * r
		# Which samples each cell can see. Built once, then reused for both statistics.
		var seen: Array[PackedInt32Array] = []
		for centre in spots:
			var hit := PackedInt32Array()
			for s in samples.size():
				if centre.distance_squared_to(samples[s]) <= r_sq:
					hit.append(s)
			seen.append(hit)
		var counts: Array[int] = []
		for h in seen:
			counts.append(h.size())
		counts.sort()
		var best := counts[counts.size() - 1] if not counts.is_empty() else 0
		var median := counts[counts.size() / 2] if not counts.is_empty() else 0
		# Greedy set cover to 95%: repeatedly take the cell that adds the most new road.
		var covered := {}
		var target := int(float(samples.size()) * 0.95)
		var used := 0
		while covered.size() < target and used < spots.size():
			var best_gain := 0
			var best_i := -1
			for i in seen.size():
				var gain := 0
				for s in seen[i]:
					if not covered.has(s):
						gain += 1
				if gain > best_gain:
					best_gain = gain
					best_i = i
			if best_i < 0:
				break  # nothing left can add road; the rest is out of everyone's reach
			for s in seen[best_i]:
				covered[s] = true
			used += 1
		var cover_txt := "%d towers" % used if covered.size() >= target \
				else "%d towers (only %.0f%% reachable)" % [used,
					100.0 * float(covered.size()) / float(samples.size())]
		print("  %-10s %7.0f %7.0f%% %7.0f%%  %-12s %7.0f %7.0f%%" % [tid, r,
				100.0 * float(best) / float(samples.size()),
				100.0 * float(median) / float(samples.size()), cover_txt,
				raw, 100.0 * float(_best_seen(spots, samples, raw)) / float(samples.size())])
	print("--- BOARD DUMP END ---")

## Road samples visible from the single best cell at radius `r`. Used for the `raw` column,
## which repeats the "best 1" measurement with the cap lifted.
func _best_seen(spots: Array, samples: Array[Vector2], r: float) -> int:
	var r_sq := r * r
	var best := 0
	for centre in spots:
		var n := 0
		for s in samples:
			if centre.distance_squared_to(s) <= r_sq:
				n += 1
		best = maxi(best, n)
	return best

## TEMPORARY verification harness for the tower-stats refactor. Prints every tower's
## resolved stats at each level so a pure refactor can be proved byte-identical against a
## saved baseline — there are no tests, and playing the game cannot catch a 6th-decimal
## drift. Gated behind a user arg so it never runs in a normal session; everything after
## the bare `--` is passed through to OS.get_cmdline_user_args():
##   Godot.exe --headless --path <project> res://scenes/Main.tscn -- --dump-stats
## Delete this and its call above once the refactor has landed and been verified.
func _dump_tower_stats() -> void:
	print("--- TOWER STATS DUMP BEGIN ---")
	for tid in Game.TOWER_ORDER:
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def(String(tid))
		for _lv in Balance.MAX_LEVEL:
			print("%s L%d dmg=%.6f rng=%.4f rsq=%.4f int=%.6f pdps=%.6f ptime=%.4f " \
					% [tid, t.level, t.damage, t.tower_range, t._range_sq,
						t.fire_interval, t.poison_dps, t.poison_time] \
				+ "slowf=%.6f slowt=%.4f sslash=%.6f splr=%.4f splf=%.4f stunc=%.4f stunt=%.4f " \
					% [t.slow_factor, t.slow_time, t.slow_splash_radius, t.splash_radius,
						t.splash_factor, t.stun_chance, t.stun_time] \
				+ "cost=%d upcost=%d spent=%d sell=%d flying=%s" \
					% [t.build_cost, t.upgrade_cost(), t.total_spent, t.sell_value(),
						t.can_hit_flying])
			t.upgrade()
		t.queue_free()
	print("--- TOWER STATS DUMP END ---")

# --- Camera shake --------------------------------------------------------------

## Kept deliberately small: the mouse position is read back through the camera
## transform, so a violent shake would also drag the cursor's world position around
## and make clicks feel imprecise mid-shake.
func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	camera.offset = Vector2.ZERO if _shake <= 0.0 \
			else Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

# --- Placement: drag a palette item onto a grid cell ---------------------------

func _on_drag_started(kind: String) -> void:
	if Game.is_over:
		return
	_drag_kind = kind
	grid.set_showing(true)  # closed ground is only worth showing while something is being placed
	_set_hovered(null)  # the drag preview takes over; don't compete with a hover ring
	_update_ghost(get_global_mouse_position())

## While a drag is active this runs before the GUI so the ghost tracks the mouse
## and the drop is caught wherever the button is released. With no drag, mouse
## motion instead highlights whichever tower is under the cursor.
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

## Highlights the tower under the cursor (if any) so its range reads clearly.
func _update_hover(world_pos: Vector2) -> void:
	_set_hovered(_tower_at(world_pos))

## Single place that swaps the highlight, guarding against a tower that has been
## sold (queue_free'd) while it was still the hovered one.
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
	# The ghost is shown even where a tower cannot go — in red. A ghost that vanishes over
	# bad ground tells the player nothing about WHY, and the whole point of free placement
	# is that the board answers "can I build here" continuously.
	# TOWER_DEFS stores range in Warcraft III units — scale to pixels, exactly as
	# tower.gd's _recompute does, or the ghost circle lies about the tower's reach.
	preview.show_at(world_pos,
			Game.can_build_at(world_pos, towers_root.get_children())
					and Game.gold >= _cost(_drag_kind),
			minf(d.get("range", 160.0) * Balance.WC3_RANGE_SCALE, Balance.MAX_TOWER_RANGE),
			d.get("color", Color.WHITE))

func _drop(world_pos: Vector2) -> void:
	var kind := _drag_kind
	_drag_kind = ""
	preview.hide()
	grid.set_showing(false)
	var center := world_pos
	if not Game.can_build_at(center, towers_root.get_children()):
		Audio.play("denied")
		return
	if not Game.spend_gold(_cost(kind)):
		Audio.play("denied")
		return
	var tower := TOWER.instantiate() as Tower
	tower.setup_def(kind)
	tower.position = center
	towers_root.add_child(tower)
	# Aura towers buff their neighbours, so every standing tower re-pulls its surroundings
	# whenever the set changes. Emitted after the add_child so the new tower is included.
	Game.towers_changed.emit()
	Audio.play("build")

func _cost(kind: String) -> int:
	return int(Game.TOWER_DEFS[kind]["cost"])

## True if no tower already sits on the cell centred at this point.
## The tower under this point, or null. One radius does placement, hit-testing and the
## drawn body, so what the player aims at is what they see.
func _tower_at(world_pos: Vector2) -> Tower:
	var best: Tower = null
	var best_d := Game.TOWER_RADIUS
	for c in towers_root.get_children():
		var t := c as Tower
		if t == null:
			continue
		var d := t.position.distance_to(world_pos)
		if d <= best_d:
			best_d = d
			best = t
	return best

## The red sell disc sits outside the 30px body radius, so it needs its own hit pass before
## `_tower_at()`. Pick the nearest disc if two touch; tower spacing normally keeps them apart,
## but nearest is deterministic at the boundary and avoids selling a neighbour by child order.
func _sell_button_at(world_pos: Vector2) -> Tower:
	var best: Tower = null
	var best_d := INF
	for child in towers_root.get_children():
		var tower := child as Tower
		if tower == null or not tower.is_sell_hit(world_pos):
			continue
		var distance := world_pos.distance_to(tower.global_position + Tower.SELL_BTN_POS)
		if distance < best_d:
			best = tower
			best_d = distance
	return best

# --- Click a tower: upgrade it, or sell it via the corner "×" -------------------

## A left click / tap on a tower upgrades it — unless it landed on the tower's sell "×",
## which sells instead. Clicking bare ground does nothing. Every action lives on the tower
## itself now (no info panel), which keeps the whole board tappable on a phone.
func _unhandled_input(event: InputEvent) -> void:
	if Game.is_over or _drag_kind != "":
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_handle_tower_click(get_global_mouse_position())

func _handle_tower_click(world: Vector2) -> void:
	# Sell discs extend beyond the tower body's click radius. Test them first or a click on
	# the visible × is rejected as bare ground before `is_sell_hit()` ever gets a chance.
	var tower := _sell_button_at(world)
	if tower != null:
		_sell_tower(tower)
		return
	tower = _tower_at(world)
	if tower == null:
		return
	_upgrade_tower(tower)

## Upgrades the tower if another level exists and the gold is there; a denied buzz otherwise,
## so a mistap on a maxed / too-expensive tower gives feedback instead of doing nothing.
func _upgrade_tower(tower: Tower) -> void:
	if not tower.can_upgrade() or not Game.spend_gold(tower.upgrade_cost()):
		Audio.play("denied")
		return
	tower.upgrade()
	# An aura deepens with its provider's level, so upgrading one has to reach the towers
	# around it — not just the tower that was tapped.
	Game.towers_changed.emit()
	Audio.play("upgrade")
	# Lv3 is a branch, not a stat step (GAME_STRATEGY_V2.md §4, BUILD NEXT #5) — the tower
	# already climbed to level 3 above, using its base (unbranched) stats for this one frame;
	# the popup decides which branch it settles into from here. `branch == ""` guards against
	# re-asking if a future respec-adjacent feature ever calls _upgrade_tower on an already-
	# branched Lv3+ tower.
	if tower.level == 3 and tower.branch == "":
		if _auto_pick:
			# Harnesses (--fill-board) alternate so both branches of every element actually
			# get played, rather than every tower defaulting to the same half of the roster.
			tower.set_branch("a" if (_auto_pick_branch_toggle % 2 == 0) else "b")
			_auto_pick_branch_toggle += 1
			return
		_pending_branch_tower = tower
		get_tree().paused = true
		hud.set_input_blocked(true)
		branch_choice.show_choices(tower.element)

## branch_choice.gd reports back which branch (never for which tower — see
## _pending_branch_tower), so this is also where the interactive path un-pauses; the harness
## path in _upgrade_tower above never pauses in the first place and never reaches here.
func _on_branch_chosen(branch_id: String) -> void:
	if _pending_branch_tower != null and is_instance_valid(_pending_branch_tower):
		_pending_branch_tower.set_branch(branch_id)
		Game.towers_changed.emit()  # a newly-branched Grove's aura must reach its neighbours now
	_pending_branch_tower = null
	hud.set_input_blocked(false)
	get_tree().paused = false

## Removes the tower and refunds the gold sunk into it — all of it if the tower never fired,
## most of it otherwise (see Tower.sell_value / Tower.has_fired).
func _sell_tower(tower: Tower) -> void:
	Audio.play("sell")
	Game.add_gold(tower.sell_value())
	if _hovered == tower:
		_hovered = null  # it is about to be freed; never keep a dangling reference
	tower.queue_free()
	# queue_free() only takes effect at the end of the frame, so the sold tower is still a
	# child right now — drop it from the tree first or the neighbours would re-pull an aura
	# from a tower that no longer exists.
	towers_root.remove_child(tower)
	Game.towers_changed.emit()

## Harness for the exact regression: the sell centre is 41px from the tower centre and is
## therefore intentionally outside `_tower_at()`'s 30px body. It must still resolve through
## `_sell_button_at()`, refund the tower and detach it from the board.
func _test_sell_hit() -> void:
	var tower := TOWER.instantiate() as Tower
	tower.setup_def("fire")
	tower.position = Vector2(640, 360)
	towers_root.add_child(tower)
	var sell_point := tower.global_position + Tower.SELL_BTN_POS
	if _tower_at(sell_point) != null or _sell_button_at(sell_point) != tower:
		push_error("Sell hit harness: visible × did not resolve independently of tower body")
		return
	var gold_before := Game.gold
	var expected_refund := tower.sell_value()
	_handle_tower_click(sell_point)
	if tower.get_parent() != null or Game.gold != gold_before + expected_refund:
		push_error("Sell hit harness: sale did not detach tower and refund exact value")
		return
	var upgrade_target := TOWER.instantiate() as Tower
	upgrade_target.setup_def("water")
	upgrade_target.position = Vector2(740, 360)
	towers_root.add_child(upgrade_target)
	var upgrade_cost := upgrade_target.upgrade_cost()
	gold_before = Game.gold
	_handle_tower_click(upgrade_target.global_position)
	if upgrade_target.level != 2 or Game.gold != gold_before - upgrade_cost:
		push_error("Sell hit harness: body click no longer upgrades normally")
		return
	towers_root.remove_child(upgrade_target)
	upgrade_target.queue_free()
	print("--- SELL HIT OK: outside body, refund=%d, body upgrade=ok ---" % expected_refund)

# --- Roguelite choice ----------------------------------------------------------

## A wave interval elapsed: roll three cards and stop the run while the player decides.
func _on_choice_due(wave: int) -> void:
	if Game.is_over:
		return  # the last enemy leaked as the wave cleared; the run summary wins
	var options := Run.roll_choices(wave)
	if options.is_empty():
		return  # pool exhausted — never block the run over a missing reward
	if _auto_pick:
		# Harness only: nothing is going to tap a card in a headless run, and a paused tree
		# is indistinguishable from a hang. Take the first offer and carry on.
		print("choice @w%d -> %s" % [wave, String(options[0].get("name", "?"))])
		_on_upgrade_chosen(options[0])
		return
	get_tree().paused = true
	hud.set_input_blocked(true)
	upgrade_choice.show_choices(options)

## Monoculture's sub-choice (GAME_STRATEGY_V2.md §6.3, BUILD NEXT #9) is the one card whose
## effects depend on a choice made AFTER the card itself is picked, so it cannot just call
## Run.grant() here like every other card does.
func _on_upgrade_chosen(upgrade: Dictionary) -> void:
	if upgrade.get("needs_element_choice", false):
		_pending_monoculture_card = upgrade
		if _auto_pick:
			# Harness only: nothing is going to tap an element card in a headless run.
			_on_element_chosen(String(Game.TOWER_ORDER[0]))
			return
		element_choice.show_choices()
		return  # tree stays paused; _on_element_chosen finishes the job below
	Run.grant(upgrade)
	hud.set_input_blocked(false)
	get_tree().paused = false

## Builds Monoculture's actual effects list now that an element was picked — one effect at
## +50% for it, three more at -20% each for the others, using the per-effect `element`
## override run.gd's _effect_applies() reads (see its own comment for why that exists).
func _on_element_chosen(element: String) -> void:
	var effects: Array = []
	for el in Game.TOWER_ORDER:
		effects.append({"stat": "damage", "op": "mult",
				"value": 1.5 if el == element else 0.8, "element": el})
	var final_card: Dictionary = _pending_monoculture_card.duplicate()
	final_card["effects"] = effects
	_pending_monoculture_card = {}
	Run.grant(final_card)
	hud.set_input_blocked(false)
	get_tree().paused = false

func _on_game_over() -> void:
	Audio.play("gameover")
	# Bank the run BEFORE the summary draws: finish_run updates the best-wave record and
	# the wallet, both of which the summary reports.
	var earned := Meta.finish_run(Game.wave_reached)
	end_screen.show_summary(earned, false)

## Standard mode's win path (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4) — same bookkeeping as
## a loss (bank the run, show the summary), framed as a win rather than a result. audio.gd
## already synthesizes a "victory" jingle distinct from "gameover"; nothing played it before
## there was a way to win.
func _on_victory() -> void:
	Audio.play("victory")
	var earned := Meta.finish_run(Game.wave_reached)
	# Stars (GAME_STRATEGY_V2.md §12.4, BUILD NEXT #8): ★ for finishing at all — true here,
	# since this only runs on Game.victory — ★★ for ≤5 lives lost, ★★★ for a flawless clear.
	# Compared against the RULESET's own starting lives, not a hardcoded 20, so Easy's extra
	# lives do not make ★★★ easier to reach than Normal's.
	var lives_lost := Balance.ruleset_start_lives(Game.ruleset) - Game.lives
	var stars := 3 if lives_lost <= 0 else (2 if lives_lost <= 5 else 1)
	Meta.record_stars(Game.ruleset, stars)
	end_screen.show_summary(earned, true, stars)
