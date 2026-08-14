extends TowerBehavior
class_name ChargeBehavior
## Fires like a bolt turret, but every Nth shot is a charged one that hits far harder —
## the Magic tower, which the map describes as storing mana to spend as extra damage.
##
## This earns a behavior where the other six support duals did not: an aura is read by the
## towers around it and an execute is read by the projectile, so both stay data. Here the
## shots genuinely differ from one another, which is control flow.
##
## Charge counts SHOTS rather than seconds on purpose. Attack-speed modifiers then make the
## burst arrive sooner instead of making it rarer, which is the way round a player expects
## a haste buff to work.

## Shots fired since the last charged one.
var _charged_shots: int = 0
## Seconds until this tower may fire again.
var _cooldown: float = 0.0

func tick(tower: Tower, delta: float, target: Enemy) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	if target == null:
		return
	var every: int = int(tower._def.get("charge_shots", 4))
	var mult: float = 1.0
	_charged_shots += 1
	if every > 0 and _charged_shots >= every:
		_charged_shots = 0
		mult = float(tower._def.get("charge_mult", 3.0))
	tower.fire_bolt(target, mult)
	_cooldown = tower.fire_interval

## True while the next shot is the charged one, so the tower can show it is loaded.
func is_charged(tower: Tower) -> bool:
	var every: int = int(tower._def.get("charge_shots", 4))
	return every > 0 and _charged_shots >= every - 1

func draw_turret(tower: Tower) -> void:
	tower.draw_barrel()
	# A bright orb at the muzzle while the burst is loaded. Without it the charged shot is
	# invisible until the damage number lands, and a tower whose whole identity is "wait,
	# then hit hard" has to show the waiting.
	if is_charged(tower):
		var tip := tower._aim_dir * 34.0
		var c := tower.element_color.lightened(0.45)
		tower.draw_circle(tip, 7.0, Color(c.r, c.g, c.b, 0.9))
		tower.draw_arc(tip, 10.0, 0.0, TAU, 16, Color(c.r, c.g, c.b, 0.5), 2.0, true)

func wants_redraw() -> bool:
	# The orb appears and disappears between shots, and a tower with no target does not
	# otherwise repaint — without this the loaded orb would freeze on screen mid-wave.
	return true
