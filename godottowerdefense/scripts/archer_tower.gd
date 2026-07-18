extends Tower
## Fast, cheap, single-target tower. Fires arrows at the closest enemy.

const ARROW := preload("res://scenes/Arrow.tscn")

func _ready() -> void:
	tower_range = 170.0
	fire_interval = 0.35
	damage = 9.0

func _fire(target: Enemy) -> void:
	var arrow := ARROW.instantiate() as Projectile
	_projectiles().add_child(arrow)
	arrow.setup(global_position, target, damage)

func _draw() -> void:
	# Faint range indicator.
	draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 48, Color(0.2, 0.9, 0.4, 0.08), 2.0, true)
	# Wooden tower.
	draw_circle(Vector2.ZERO, 18.0, Color(0.30, 0.22, 0.14))     # base
	draw_rect(Rect2(-11, -30, 22, 32), Color(0.62, 0.45, 0.28))  # body
	draw_rect(Rect2(-13, -36, 26, 8), Color(0.45, 0.32, 0.20))   # battlement
	draw_circle(Vector2(0, -30), 7.0, Color(0.25, 0.75, 0.35))   # archer
