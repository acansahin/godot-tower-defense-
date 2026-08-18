extends Node
class_name WaveManager
## Spawns waves of enemies with growing count and difficulty. Uses plain Timer
## nodes (freed automatically on scene reload) instead of coroutines so a
## restart never leaves a spawn loop running.
##
## A run is ENDLESS. Waves come from Game.WAVES while it lasts — the hand-authored opening —
## and from WaveGenerator forever after. There is no last wave and no victory: a run ends
## only when the player runs out of lives, and how deep they got is the score.

signal wave_started(number: int)
signal wave_preview(text: String, color: Color)  ## Describes the next wave for the HUD.
signal prep_started                ## The between-waves gap began (send-early available).
## A roguelite choice is owed for clearing `wave`. Emitted rather than acted on, because
## pausing the run is Main's business — WaveManager only knows that a wave ended.
signal choice_due(wave: int)

const ENEMY := preload("res://scenes/Enemy.tscn")

# Wave pacing, the HP/speed/count scaling curve, the gold economy and the boss stat
# multipliers all live in the Balance autoload — see scripts/balance.gd. Which waves get
# a boss is still set per-wave in Game.WAVES ("boss": true).

## Node that spawned enemies are parented to (assigned by Main before start()).
var enemies_root: Node

var _wave: int = 0
var _to_spawn: int = 0
var _alive: int = 0
var _spawn_timer: Timer
var _prep_timer: Timer

# Parameters for the wave currently spawning.
var _hp: float = 0.0
var _spd: float = 0.0
var _reward: int = 0
var _interval: float = 0.6
var _tint: Color = Color.WHITE
var _type_def: Dictionary = {}  ## The current wave's WAVE_TYPES entry.
var _kind: String = ""          ## Which WAVE_TYPES key that is; picks the painted sprite.
var _element: String = ""       ## The current wave's armor element ("" = neutral).
var _lives_at_start: int = 0    ## Lives when the wave began (for the leak-free bonus).
var _generator: WaveGenerator = null  ## Supplies every wave past the seed table.
## Cache of generated definitions, keyed by wave number. The generator is pure so this is
## only a speed-up, not a correctness fix — but a wave gets asked for at least twice (once
## as next-wave preview, once when it starts) and the preview text re-derives it again.
var _generated: Dictionary = {}

func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_spawn_one)
	add_child(_spawn_timer)

	_prep_timer = Timer.new()
	_prep_timer.one_shot = true
	_prep_timer.timeout.connect(_start_wave)
	add_child(_prep_timer)

## Begins the run. `run_seed` selects which endless waves this run will roll; the same seed
## replays the same run, which is what makes a balance complaint reproducible.
func start(run_seed: int = 0) -> void:
	_generator = WaveGenerator.new(run_seed)
	wave_preview.emit(_preview_text(1), _preview_color(1))
	_queue_next_wave()

## The definition for wave `n`: the hand-authored seed table while it lasts, the generator
## forever after. Both return the same Dictionary shape, so nothing downstream has to know
## which one answered.
func _wave_def(n: int) -> Dictionary:
	if n <= Game.WAVES.size():
		return Game.WAVES[n - 1]
	if not _generated.has(n):
		_generated[n] = _generator.wave_def(n)
	return _generated[n]

func _queue_next_wave() -> void:
	# No upper bound: the run is endless and ends only when the player runs out of lives.
	_prep_timer.start(_prep_time_for(_wave + 1))
	prep_started.emit()

## Build time before wave `n`. Wave 1 gets a longer gap: the player has never seen the
## palette, and the default 4 seconds is not enough to read it, drag a tower and aim.
func _prep_time_for(n: int) -> float:
	return Balance.FIRST_PREP_TIME if n <= 1 else Balance.PREP_TIME

## Skips the prep countdown and starts the next wave now, for a small bonus.
## Only valid during the between-waves gap.
func send_now() -> void:
	if _prep_timer.is_stopped():
		return
	_prep_timer.stop()
	Audio.play("send_early")
	Game.add_gold(Balance.early_call_bonus(_wave + 1))
	_start_wave()

func _start_wave() -> void:
	_wave += 1
	Game.wave_reached = _wave
	var def: Dictionary = _wave_def(_wave)
	_kind = String(def["type"])
	_type_def = Game.WAVE_TYPES[_kind]
	# Base scaling (quadratic HP so towers must keep pace) x archetype multipliers.
	# The curve itself lives in Balance; the archetype and per-wave multipliers below
	# stack on top of it, so a single wave can be smoothed without rebalancing the whole
	# archetype (which is shared across several waves).
	var base_hp := Balance.wave_hp(_wave)
	var base_spd := Balance.wave_speed(_wave)
	_hp = base_hp * float(_type_def.get("hp", 1.0)) * float(def.get("hp", 1.0))
	_spd = base_spd * float(_type_def.get("spd", 1.0))
	_reward = Balance.wave_reward(_wave)
	_interval = Balance.spawn_interval(_wave)
	_to_spawn = _spawn_count(_wave, _type_def, def)
	# Element waves colour the body by element; neutral waves keep the archetype colour.
	_element = String(def.get("element", ""))
	if _element != "":
		_tint = Game.ELEMENT_COLORS.get(_element, Color.WHITE)
	else:
		_tint = _type_def.get("color", Color.WHITE)
	_lives_at_start = Game.lives
	if OS.get_cmdline_user_args().has("--fill-board"):
		print("wave %d: %s el=%s%s  hp=%.0f count=%d" % [_wave, String(def["type"]),
				String(def.get("element", "-")), "  BOSS" if def.get("boss", false) else "",
				_hp, _to_spawn])
	Audio.play("wave_start")
	wave_started.emit(_wave)
	wave_preview.emit(_preview_text(_wave + 1), _preview_color(_wave + 1))
	if def.get("boss", false):
		_spawn_boss()                # milestone centrepiece
	_spawn_one()                     # first enemy immediately
	_spawn_timer.start(_interval)    # the rest on a cadence

func _spawn_one() -> void:
	if Game.is_over or _to_spawn <= 0:
		_spawn_timer.stop()
		return
	_to_spawn -= 1
	var enemy := ENEMY.instantiate() as Enemy
	enemy.setup(_hp, _spd, _reward, _tint)
	enemy.armor_element = _element
	enemy.kind = _kind
	enemy.has_own_wings = _type_def.get("air", false)
	enemy.radius = Balance.ENEMY_BASE_RADIUS * float(_type_def.get("radius", 1.0))
	enemy.cc_immune = _type_def.get("cc_immune", false)
	var regen := float(_type_def.get("regen", 0.0))
	if regen > 0.0:
		enemy.regen_dps = _hp * regen
	enemy.split_into = int(_type_def.get("split", 0))
	if _type_def.get("air", false):
		enemy.make_flying()
	elif _wave >= Balance.FLYER_START_WAVE and randf() < Balance.FLYER_CHANCE:
		enemy.make_flying()
	if enemy.split_into > 0:
		enemy.split_requested.connect(_spawn_child)
	enemy.removed.connect(_on_enemy_removed)
	enemies_root.add_child(enemy)
	_alive += 1
	if _to_spawn <= 0:
		_spawn_timer.stop()

## Spawns a splitter's children where it died, continuing along the path.
func _spawn_child(pos: Vector2, progress: int, count: int, hp: float, spd: float, tint: Color, r: float) -> void:
	if Game.is_over:
		return
	for i in count:
		var c := ENEMY.instantiate() as Enemy
		c.setup(hp, spd, Balance.SPLIT_CHILD_REWARD, tint)
		c.armor_element = _element  # children share the wave's element
		c.kind = _kind              # and its art: a splitter's halves are smaller splitters
		c.has_own_wings = _type_def.get("air", false)
		c.radius = r
		c.removed.connect(_on_enemy_removed)
		enemies_root.add_child(c)  # _ready puts it at PATH[0]; override below
		c.global_position = pos + Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		c.set_progress(progress)
		_alive += 1

## How many enemies wave `n` spawns: the base count scaled by the archetype's `count`
## multiplier and then the per-wave override. Shared by the spawner and the HUD preview —
## these used to be two copies of the formula, and the preview could drift from the wave
## it was describing.
func _spawn_count(n: int, type_def: Dictionary, wave_def: Dictionary) -> int:
	var raw := int(round(Balance.wave_count(n)
			* float(type_def.get("count", 1.0)) * float(wave_def.get("count", 1.0))))
	return clampi(raw, 1, Balance.MAX_SPAWN_COUNT)

## HUD text describing wave `n`. There is always a next wave, so this never runs dry.
func _preview_text(n: int) -> String:
	var def: Dictionary = _wave_def(n)
	var t: Dictionary = Game.WAVE_TYPES[def["type"]]
	var cnt := _spawn_count(n, t, def)
	var boss := "  BOSS" if def.get("boss", false) else ""
	# An elite wave is a per-wave HP override with no boss flag — worth calling out, since
	# the count drops at the same time and the wave would otherwise look easier, not harder.
	var elite := "  ELITE" if not def.get("boss", false) and float(def.get("hp", 1.0)) > 1.0 else ""
	var elem := String(def.get("element", ""))
	var epfx := (elem.capitalize() + " ") if elem != "" else ""
	return "Next: %s%s x%d%s%s" % [epfx, str(t.get("name", def["type"])), cnt, boss, elite]

## Colour for the preview label: the wave's element, or a default gold if neutral.
func _preview_color(n: int) -> Color:
	var elem := String(_wave_def(n).get("element", ""))
	if elem != "":
		return Game.ELEMENT_COLORS.get(elem, Color(0.95, 0.9, 0.7))
	return Color(0.95, 0.9, 0.7)

## Spawns one boss for the current wave. Not counted in _to_spawn — it is an
## extra enemy tracked via _alive, so the wave only clears once it dies too.
func _spawn_boss() -> void:
	if Game.is_over:
		return
	var boss := ENEMY.instantiate() as Enemy
	boss.setup(_hp * Balance.BOSS_HP_MULT, _spd * Balance.BOSS_SPEED_MULT,
			_reward * Balance.BOSS_REWARD_MULT, Balance.BOSS_TINT)
	boss.armor_element = _element
	boss.kind = _kind  # a boss is an archetype wearing a crown, not a creature of its own
	boss.has_own_wings = _type_def.get("air", false)
	boss.radius = Balance.BOSS_RADIUS
	boss.life_cost = Balance.BOSS_LIFE_COST
	boss.is_boss = true
	boss.removed.connect(_on_enemy_removed)
	enemies_root.add_child(boss)
	Audio.play("boss_spawn")
	_alive += 1

func _on_enemy_removed() -> void:
	_alive -= 1
	if Game.is_over:
		return
	# Wave is cleared once nothing is left to spawn and nothing is alive. There is no
	# terminal wave to check for — the next one is always queued.
	if _to_spawn <= 0 and _alive <= 0:
		_grant_wave_rewards()
		# Queue the next wave first, then ask for the choice. The prep timer is a node, so
		# it stops with the tree while the choice screen is up and resumes with whatever is
		# left when the player picks — they get their full build time either way.
		_queue_next_wave()
		if _wave % Balance.CHOICE_EVERY == 0:
			choice_due.emit(_wave)

## Leak-free bonus + interest on banked gold, granted when a wave is cleared.
func _grant_wave_rewards() -> void:
	Audio.play("wave_clear")
	if Game.lives == _lives_at_start:
		Game.add_gold(Balance.LEAK_FREE_BONUS)
	var interest := mini(Balance.INTEREST_CAP, int(Game.gold * Balance.INTEREST_RATE))
	if interest > 0:
		Game.add_gold(interest)
