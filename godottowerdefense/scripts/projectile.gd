extends Node2D
class_name Projectile
## Base projectile: homes toward its target and deals damage on impact.
## If splash_radius > 0 it also hits the single nearest OTHER enemy for
## damage * splash_factor. Arrow and Cannonball only differ in _draw().

var speed: float = 420.0
var damage: float = 10.0
var splash_radius: float = 0.0
var splash_factor: float = 0.5

var _target: Enemy = null

func setup(start: Vector2, target: Enemy, dmg: float) -> void:
	global_position = start
	_target = target
	damage = dmg

func _process(delta: float) -> void:
	# Target may have died mid-flight.
	if not is_instance_valid(_target):
		queue_free()
		return
	var to_target := _target.global_position - global_position
	rotation = to_target.angle()
	var step := speed * delta
	if to_target.length() <= step + _target.radius * 0.5:
		_hit(_target)
		return
	global_position += to_target.normalized() * step

func _hit(target: Enemy) -> void:
	var impact := target.global_position
	target.take_damage(damage)
	if splash_radius > 0.0:
		_apply_splash(target, impact)
	queue_free()

func _apply_splash(main_target: Enemy, center: Vector2) -> void:
	var best: Enemy = null
	var best_dist := splash_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue
		var d := center.distance_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	if best != null:
		best.take_damage(damage * splash_factor)
