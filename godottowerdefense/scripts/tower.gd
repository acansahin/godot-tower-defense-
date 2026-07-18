extends Node2D
class_name Tower
## Base tower behaviour: cooldown-driven firing at the closest enemy in range.
## ArcherTower and CannonTower override _fire() and _draw().

var tower_range: float = 160.0
var fire_interval: float = 0.4
var damage: float = 8.0

var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	var target := _find_target()
	if target != null:
		_fire(target)
		_cooldown = fire_interval

func _find_target() -> Enemy:
	var best: Enemy = null
	var best_dist := tower_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	return best

## Container that new projectiles are added to (kept off the tower so they
## keep flying independently).
func _projectiles() -> Node:
	return get_tree().current_scene.get_node("Projectiles")

func _fire(_target: Enemy) -> void:
	pass  # overridden

func _draw() -> void:
	pass  # overridden
