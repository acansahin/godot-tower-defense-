extends TowerBehavior
class_name BoltBehavior
## Cooldown, then one homing Projectile at the current target — the behavior every tower
## in the game uses today. Lifted verbatim out of Tower._process and Tower._draw, so
## introducing the seam changed no numbers and no pixels.
##
## This is the default: a Game.TOWER_DEFS entry with no "behavior" key gets one of these.

## Seconds until this tower may fire again. Per-tower state, which is exactly why
## behaviors are instantiated per tower rather than shared.
var _cooldown: float = 0.0

func tick(tower: Tower, delta: float, target: Enemy) -> void:
	# Order preserved from the original _process: a frame that spends the cooldown does
	# not also fire, so the real cadence is a hair under the nominal interval. Identical
	# for every tower, so it shifts no balance.
	if _cooldown > 0.0:
		_cooldown -= delta
	elif target != null:
		tower.fire_bolt(target)
		_cooldown = tower.fire_interval

func draw_turret(tower: Tower) -> void:
	tower.draw_barrel()
