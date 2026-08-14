extends RefCounted
class_name TowerBehavior
## What a tower DOES with its frame — the seam that lets one element be a homing turret
## and another a beam, an aura or an economy building, without a branch in Tower._process.
##
## Tower keeps everything universal: targeting, barrel easing, stats, upgrade/sell chrome,
## the range ring and the level pips. A behavior owns only the action and the turret art.
##
## RULE OF THUMB: a new subclass only when the CONTROL FLOW differs. Different numbers, a
## new debuff, a bigger splash — those stay data in Game.TOWER_DEFS. Eight behaviors for
## eight towers would be a worse codebase than the dictionary it replaced.
##
## One instance PER TOWER (they hold per-tower state such as a cooldown), and they never
## store the tower — it is passed in on every call, so a behavior can never outlive or
## dangle against the node it belongs to.

## False for towers that never pick a victim (auras, economy buildings). Tower then skips
## the EnemyIndex scan entirely rather than scanning and throwing the result away.
func wants_target() -> bool:
	return true

## True if the tower should repaint this frame for reasons only the behavior knows about.
## Tower's own redraw triggers all assume a turret that tracks a target, so a behavior
## that animates without one (a pulsing aura) has to say so or it would freeze on screen.
func wants_redraw() -> bool:
	return false

## Called every frame, after Tower has aimed and decayed its recoil. `target` is null when
## there is none — and always null when wants_target() is false.
func tick(_tower: Tower, _delta: float, _target: Enemy) -> void:
	pass

## Draws the moving part only: barrel, orb, muzzle flash. The range ring, stone base,
## level pips, sell "×" and upgrade chevron are Tower's and are drawn around this.
func draw_turret(_tower: Tower) -> void:
	pass
