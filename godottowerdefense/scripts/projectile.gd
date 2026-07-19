extends Node2D
class_name Projectile
## Homes toward its target and applies its payload on impact: direct damage, an
## optional splash (all enemies in radius for splash_factor damage), and optional
## slow / poison debuffs. Configured by the firing tower; drawn as a coloured bolt.

var speed: float = 420.0
var damage: float = 10.0
var color: Color = Color.WHITE
var splash_radius: float = 0.0
var splash_factor: float = 0.5
var hits_flying: bool = true    ## False skips flyers (ground-only towers) for splash.
var slow_factor: float = 1.0    ## < 1 slows the enemy on hit.
var slow_time: float = 0.0
var poison_dps: float = 0.0
var poison_time: float = 0.0

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
	_apply(target, 1.0)
	if splash_radius > 0.0:
		_apply_splash(target, impact)
	queue_free()

## Applies damage (scaled by mult) plus any slow / poison to one enemy.
func _apply(enemy: Enemy, mult: float) -> void:
	enemy.take_damage(damage * mult)
	if slow_time > 0.0:
		enemy.apply_slow(slow_factor, slow_time)
	if poison_time > 0.0:
		enemy.apply_poison(poison_dps * mult, poison_time)

func _apply_splash(main_target: Enemy, center: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue
		if enemy.is_flying and not hits_flying:
			continue
		if center.distance_to(enemy.global_position) <= splash_radius:
			_apply(enemy, splash_factor)

func _draw() -> void:
	# The node rotates toward its target, so local -x is "behind": draw a tapered
	# trail there, a soft glow, then the bright coloured core.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -4), Vector2(0, 4), Vector2(-16, 0),
	]), Color(color.r, color.g, color.b, 0.30))
	draw_circle(Vector2.ZERO, 8.0, Color(color.r, color.g, color.b, 0.25))  # glow
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.6))              # highlight
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 12, Color(0, 0, 0, 0.4), 1.0, true)
