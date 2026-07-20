extends Node
class_name WaveManager
## Spawns waves of enemies with growing count and difficulty. Uses plain Timer
## nodes (freed automatically on scene reload) instead of coroutines so a
## restart never leaves a spawn loop running.

signal wave_started(number: int, total: int)
signal wave_preview(text: String, color: Color)  ## Describes the next wave for the HUD.
signal prep_started                ## The between-waves gap began (send-early available).

const ENEMY := preload("res://scenes/Enemy.tscn")
const PREP_TIME := 4.0  ## Delay before wave 1 and between waves.

# Economy rewards for surviving a wave.
const INTEREST_RATE := 0.08  ## Banked gold earns this each wave (capped).
const INTEREST_CAP := 40
const LEAK_FREE_BONUS := 6   ## Bonus if no enemy reached the end this wave.

# A few enemies still randomly fly on non-Air waves (halved now that Air waves exist).
const FLYER_START_WAVE := 3
const FLYER_CHANCE := 0.3

# Boss stat multipliers (which waves get a boss is set in Game.WAVES "boss": true).
const BOSS_HP_MULT := 6.0
const BOSS_SPEED_MULT := 0.6
const BOSS_REWARD_MULT := 10
const BOSS_RADIUS := 30.0
const BOSS_LIFE_COST := 10   ## Lives lost if a boss reaches the end.
const BOSS_TINT := Color(0.45, 0.1, 0.5)

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
var _element: String = ""       ## The current wave's armor element ("" = neutral).
var _lives_at_start: int = 0    ## Lives when the wave began (for the leak-free bonus).

func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_spawn_one)
	add_child(_spawn_timer)

	_prep_timer = Timer.new()
	_prep_timer.one_shot = true
	_prep_timer.timeout.connect(_start_wave)
	add_child(_prep_timer)

func start() -> void:
	wave_preview.emit(_preview_text(1), _preview_color(1))
	_queue_next_wave()

func _queue_next_wave() -> void:
	if _wave >= Game.WAVES.size():
		return
	_prep_timer.start(PREP_TIME)
	prep_started.emit()

## Skips the prep countdown and starts the next wave now, for a small bonus.
## Only valid during the between-waves gap.
func send_now() -> void:
	if _prep_timer.is_stopped():
		return
	_prep_timer.stop()
	Audio.play("send_early")
	Game.add_gold(3 + (_wave + 1))  # early-call reward
	_start_wave()

func _start_wave() -> void:
	_wave += 1
	var def: Dictionary = Game.WAVES[_wave - 1]
	_type_def = Game.WAVE_TYPES[def["type"]]
	# Base scaling (quadratic HP so towers must keep pace) x archetype multipliers.
	# The quadratic term is deliberately gentle: archetype multipliers stack on top of
	# it, so a steeper curve made the late waves (14+) spike well past what the gold
	# economy can answer.
	var base_hp := 20.0 + _wave * 10.0 + _wave * _wave * 2.55
	var base_spd := 60.0 + _wave * 6.0
	var base_count := 5 + int(_wave * 2.5)
	_hp = base_hp * float(_type_def.get("hp", 1.0))
	_spd = base_spd * float(_type_def.get("spd", 1.0))
	_reward = 3 + _wave
	_interval = maxf(0.3, 0.9 - _wave * 0.04)
	_to_spawn = maxi(1, int(round(base_count * float(_type_def.get("count", 1.0)))))
	# Element waves colour the body by element; neutral waves keep the archetype colour.
	_element = String(def.get("element", ""))
	if _element != "":
		_tint = Game.ELEMENT_COLORS.get(_element, Color.WHITE)
	else:
		_tint = _type_def.get("color", Color.WHITE)
	_lives_at_start = Game.lives
	Audio.play("wave_start")
	wave_started.emit(_wave, Game.WAVES.size())
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
	enemy.radius = 16.0 * float(_type_def.get("radius", 1.0))
	enemy.cc_immune = _type_def.get("cc_immune", false)
	var regen := float(_type_def.get("regen", 0.0))
	if regen > 0.0:
		enemy.regen_dps = _hp * regen
	enemy.split_into = int(_type_def.get("split", 0))
	if _type_def.get("air", false):
		enemy.make_flying()
	elif _wave >= FLYER_START_WAVE and randf() < FLYER_CHANCE * 0.5:
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
		c.setup(hp, spd, 1, tint)
		c.armor_element = _element  # children share the wave's element
		c.radius = r
		c.removed.connect(_on_enemy_removed)
		enemies_root.add_child(c)  # _ready puts it at PATH[0]; override below
		c.global_position = pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		c.set_progress(progress)
		_alive += 1

## HUD text describing wave `n` (or a dash past the last wave).
func _preview_text(n: int) -> String:
	if n > Game.WAVES.size():
		return "Next: —"
	var def: Dictionary = Game.WAVES[n - 1]
	var t: Dictionary = Game.WAVE_TYPES[def["type"]]
	var cnt := maxi(1, int(round((5 + int(n * 2.5)) * float(t.get("count", 1.0)))))
	var boss := "  BOSS" if def.get("boss", false) else ""
	var elem := String(def.get("element", ""))
	var epfx := (elem.capitalize() + " ") if elem != "" else ""
	return "Next: %s%s x%d%s" % [epfx, str(t.get("name", def["type"])), cnt, boss]

## Colour for the preview label: the wave's element, or a default gold if neutral.
func _preview_color(n: int) -> Color:
	if n <= Game.WAVES.size():
		var elem := String(Game.WAVES[n - 1].get("element", ""))
		if elem != "":
			return Game.ELEMENT_COLORS.get(elem, Color(0.95, 0.9, 0.7))
	return Color(0.95, 0.9, 0.7)

## Spawns one boss for the current wave. Not counted in _to_spawn — it is an
## extra enemy tracked via _alive, so the wave only clears once it dies too.
func _spawn_boss() -> void:
	if Game.is_over:
		return
	var boss := ENEMY.instantiate() as Enemy
	boss.setup(_hp * BOSS_HP_MULT, _spd * BOSS_SPEED_MULT, _reward * BOSS_REWARD_MULT, BOSS_TINT)
	boss.armor_element = _element
	boss.radius = BOSS_RADIUS
	boss.life_cost = BOSS_LIFE_COST
	boss.is_boss = true
	boss.removed.connect(_on_enemy_removed)
	enemies_root.add_child(boss)
	Audio.play("boss_spawn")
	_alive += 1

func _on_enemy_removed() -> void:
	_alive -= 1
	if Game.is_over:
		return
	# Wave is cleared once nothing is left to spawn and nothing is alive.
	if _to_spawn <= 0 and _alive <= 0:
		_grant_wave_rewards()
		if _wave >= Game.WAVES.size():
			Game.trigger_victory()
		else:
			_queue_next_wave()

## Leak-free bonus + interest on banked gold, granted when a wave is cleared.
func _grant_wave_rewards() -> void:
	Audio.play("wave_clear")
	if Game.lives == _lives_at_start:
		Game.add_gold(LEAK_FREE_BONUS)
	var interest := mini(INTEREST_CAP, int(Game.gold * INTEREST_RATE))
	if interest > 0:
		Game.add_gold(interest)
