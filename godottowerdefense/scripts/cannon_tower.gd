extends Tower
## Slow, expensive, high-damage tower. Fires cannonballs that splash one
## extra nearby enemy for 50% damage.

const CANNONBALL := preload("res://scenes/Cannonball.tscn")

func _ready() -> void:
	tower_range = 150.0
	fire_interval = 1.6
	damage = 35.0

func _fire(target: Enemy) -> void:
	var ball := CANNONBALL.instantiate() as Projectile
	_projectiles().add_child(ball)
	ball.setup(global_position, target, damage)
	ball.splash_radius = 70.0
	ball.splash_factor = 0.5

func _draw() -> void:
	# Faint range indicator.
	draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 48, Color(0.9, 0.6, 0.2, 0.08), 2.0, true)
	# Stone tower with a dark barrel.
	draw_circle(Vector2.ZERO, 20.0, Color(0.30, 0.30, 0.32))     # base
	draw_circle(Vector2(0, -6), 13.0, Color(0.42, 0.42, 0.46))   # turret
	draw_rect(Rect2(-4, -34, 8, 26), Color(0.12, 0.12, 0.14))    # barrel
