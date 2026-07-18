extends Projectile
## Slower, heavier cannonball that splashes one nearby enemy on impact
## (splash values are set by the CannonTower that fires it).

func _ready() -> void:
	speed = 340.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0.12, 0.12, 0.14))
	draw_circle(Vector2(-2, -2), 2.5, Color(0.40, 0.40, 0.45))  # highlight
