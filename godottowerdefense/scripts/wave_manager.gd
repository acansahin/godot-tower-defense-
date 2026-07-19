extends Node
class_name WaveManager
## Spawns waves of enemies with growing count and difficulty. Uses plain Timer
## nodes (freed automatically on scene reload) instead of coroutines so a
## restart never leaves a spawn loop running.

signal wave_started(number: int, total: int)

const ENEMY := preload("res://scenes/Enemy.tscn")
const TOTAL_WAVES := 10
const PREP_TIME := 4.0  ## Delay before wave 1 and between waves.

# Flyers: from wave FLYER_START_WAVE on, each spawned enemy has FLYER_CHANCE of
# being airborne. Only archer towers can hit them.
const FLYER_START_WAVE := 3
const FLYER_CHANCE := 0.3

# Boss: a single oversized, tanky, high-reward enemy on every Nth wave.
const BOSS_EVERY := 5
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
	_queue_next_wave()

func _queue_next_wave() -> void:
	if _wave >= TOTAL_WAVES:
		return
	_prep_timer.start(PREP_TIME)

func _start_wave() -> void:
	_wave += 1
	# Quadratic HP so towers must be upgraded to keep pace with late waves.
	_hp = 20.0 + _wave * 10.0 + _wave * _wave * 3.0
	_spd = 60.0 + _wave * 6.0
	_reward = 3 + _wave
	_interval = max(0.35, 0.9 - _wave * 0.04)
	_tint = Color.from_hsv(fposmod(0.02 + _wave * 0.06, 1.0), 0.65, 0.85)
	_to_spawn = 5 + int(_wave * 2.5)
	wave_started.emit(_wave, TOTAL_WAVES)
	if _wave % BOSS_EVERY == 0:
		_spawn_boss()                # slow, tanky centrepiece for milestone waves
	_spawn_one()                     # first enemy immediately
	_spawn_timer.start(_interval)    # the rest on a cadence

func _spawn_one() -> void:
	if Game.is_over or _to_spawn <= 0:
		_spawn_timer.stop()
		return
	_to_spawn -= 1
	var enemy := ENEMY.instantiate() as Enemy
	enemy.setup(_hp, _spd, _reward, _tint)
	if _wave >= FLYER_START_WAVE and randf() < FLYER_CHANCE:
		enemy.make_flying()
	enemy.removed.connect(_on_enemy_removed)
	enemies_root.add_child(enemy)
	_alive += 1
	if _to_spawn <= 0:
		_spawn_timer.stop()

## Spawns one boss for the current wave. Not counted in _to_spawn — it is an
## extra enemy tracked via _alive, so the wave only clears once it dies too.
func _spawn_boss() -> void:
	if Game.is_over:
		return
	var boss := ENEMY.instantiate() as Enemy
	boss.setup(_hp * BOSS_HP_MULT, _spd * BOSS_SPEED_MULT, _reward * BOSS_REWARD_MULT, BOSS_TINT)
	boss.radius = BOSS_RADIUS
	boss.life_cost = BOSS_LIFE_COST
	boss.is_boss = true
	boss.removed.connect(_on_enemy_removed)
	enemies_root.add_child(boss)
	_alive += 1

func _on_enemy_removed() -> void:
	_alive -= 1
	if Game.is_over:
		return
	# Wave is cleared once nothing is left to spawn and nothing is alive.
	if _to_spawn <= 0 and _alive <= 0:
		if _wave >= TOTAL_WAVES:
			Game.trigger_victory()
		else:
			_queue_next_wave()
