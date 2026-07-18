extends Node2D
## Wires the level together: spawns build spots, connects the HUD and menus to
## global game state, and kicks off the waves.

const ARCHER := preload("res://scenes/ArcherTower.tscn")
const CANNON := preload("res://scenes/CannonTower.tscn")
const SPOT := preload("res://scenes/TowerSpot.tscn")

@onready var spots_root: Node2D = $TowerSpots
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var build_menu: BuildMenu = $UI/BuildMenu
@onready var end_screen: EndScreen = $UI/EndScreen

var _active_spot: TowerSpot = null

func _ready() -> void:
	get_tree().paused = false
	# Required so the tower-spot Area2D nodes receive mouse clicks / hover.
	get_viewport().physics_object_picking = true
	Game.reset()

	_spawn_spots()

	hud.set_gold(Game.gold)
	hud.set_lives(Game.lives)

	Game.gold_changed.connect(hud.set_gold)
	Game.lives_changed.connect(hud.set_lives)
	Game.game_over.connect(_on_game_over)
	Game.victory.connect(_on_victory)
	wave_manager.wave_started.connect(hud.set_wave)
	build_menu.build_selected.connect(_on_build_selected)

	wave_manager.enemies_root = enemies_root
	wave_manager.start()

func _spawn_spots() -> void:
	for pos in Game.TOWER_SPOTS:
		var spot := SPOT.instantiate() as TowerSpot
		spot.position = pos
		spot.pressed.connect(_on_spot_pressed)
		spots_root.add_child(spot)

func _on_spot_pressed(spot: TowerSpot) -> void:
	_active_spot = spot
	build_menu.open_at(spot.global_position, Game.gold)

func _on_build_selected(kind: String) -> void:
	if _active_spot == null:
		return
	var cost: int = Game.ARCHER_COST if kind == "archer" else Game.CANNON_COST
	if not Game.spend_gold(cost):
		return
	var scene: PackedScene = ARCHER if kind == "archer" else CANNON
	var tower := scene.instantiate() as Node2D
	tower.position = _active_spot.position
	towers_root.add_child(tower)
	_active_spot.set_occupied()
	_active_spot = null
	build_menu.close()

func _on_game_over() -> void:
	end_screen.show_result(false)

func _on_victory() -> void:
	end_screen.show_result(true)
