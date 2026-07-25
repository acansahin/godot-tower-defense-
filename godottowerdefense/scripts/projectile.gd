extends Node2D
class_name Projectile
## Homes toward its target and applies its payload on impact: direct damage, an
## optional splash (all enemies in radius for splash_factor damage), and optional
## slow / poison debuffs. Configured by the firing tower; drawn as a coloured bolt.

const FrostRing := preload("res://scripts/frost_ring.gd")  ## Ice's area-slow impact visual.

var speed: float = 420.0
var damage: float = 10.0
var color: Color = Color.WHITE
var element: String = ""  ## Damage element for the enemy-armour matchup.
var splash_radius: float = 0.0
var splash_factor: float = 0.5
var hits_flying: bool = true    ## False skips flyers (ground-only towers) for splash.
var slow_factor: float = 1.0    ## < 1 slows the enemy on hit.
var slow_time: float = 0.0
var slow_splash_radius: float = 0.0  ## If > 0, the slow (only) also chills enemies within this radius of impact.
var poison_dps: float = 0.0
var poison_time: float = 0.0
var stun_chance: float = 0.0    ## 0..1 chance to freeze the enemy on hit.
var stun_time: float = 0.0

var _target: Enemy = null
var pool: Node = null  ## The $Projectiles pool that owns this bolt (see projectiles.gd); null = unpooled.

func setup(start: Vector2, target: Enemy, dmg: float) -> void:
	global_position = start
	_target = target
	damage = dmg
	# A pooled bolt was already drawn once in its previous colour; the firing tower has just
	# overwritten `color`, so ask for a repaint (a fresh instance would paint anyway).
	queue_redraw()

## Returns this bolt to its pool (or frees it if unpooled), dropping the target reference so
## a not-yet-freed dead enemy is not kept alive by a parked projectile.
func _recycle() -> void:
	_target = null
	if pool != null:
		pool.recycle(self)
	else:
		queue_free()

func _process(delta: float) -> void:
	# Target may have died mid-flight.
	if not is_instance_valid(_target):
		_recycle()
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
	# Capped rather than played outright: a late wave at 3x speed lands dozens of
	# impacts per frame, and an uncapped burst just turns the 12-voice pool to mush.
	Audio.play_capped("hit", 0.15)
	_apply(target, 1.0, true)
	if splash_radius > 0.0:
		_apply_splash(target, impact)
	if slow_splash_radius > 0.0 and slow_time > 0.0:
		_apply_slow_splash(target, impact)
		FrostRing.spawn(self, impact, slow_splash_radius)  # show the frost field
	_recycle()

## Applies damage (scaled by mult and the element matchup) plus any slow / poison.
## `show_number` is only set for the direct hit — a wide splash would otherwise bury
## the screen under a dozen simultaneous numbers.
func _apply(enemy: Enemy, mult: float, show_number: bool) -> void:
	var matchup := Game.element_mult(element, enemy.armor_element)
	var dealt := damage * mult * matchup
	enemy.flash()
	if show_number:
		_show_damage(enemy.global_position, dealt, matchup)
	enemy.take_damage(dealt)
	if slow_time > 0.0:
		enemy.apply_slow(slow_factor, slow_time)
	if poison_time > 0.0:
		enemy.apply_poison(poison_dps * mult * matchup, poison_time)
	if stun_time > 0.0 and randf() < stun_chance:
		enemy.apply_stun(stun_time)

## Floating damage number, colour- and size-coded by the element matchup. This is the
## only place the matchup is visible during play: without it, the panel's "x1.75 vs
## Nature" is a promise the player never sees kept.
func _show_damage(pos: Vector2, dealt: float, matchup: float) -> void:
	var col := Color(1, 1, 1, 0.95)
	var font_size := 13
	if matchup > 1.0:
		col = Color(1.0, 0.85, 0.25)   # strong: big and gold
		font_size = 18
	elif matchup < 1.0:
		col = Color(0.62, 0.66, 0.74)  # resisted: small and grey
		font_size = 11
	FloatingText.spawn(self, pos + Vector2(0, -14.0), "%d" % int(round(dealt)),
			col, font_size)

func _apply_splash(main_target: Enemy, center: Vector2) -> void:
	var radius_sq := splash_radius * splash_radius
	# Only enemies near the impact, not the whole group (see enemy_index.gd).
	for e in EnemyIndex.query(center, splash_radius):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue
		if enemy.is_flying and not hits_flying:
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_sq:
			_apply(enemy, splash_factor, false)

## Spreads ONLY the slow to enemies around the impact (Ice's Lv2 upgrade). Deliberately
## deals no damage and applies no poison — just the chill — so the upgrade turns Ice into an
## area-control tower without also making it an AoE nuke. cc-immune enemies still shrug it
## off (apply_slow ignores them), same as a direct hit.
func _apply_slow_splash(main_target: Enemy, center: Vector2) -> void:
	var radius_sq := slow_splash_radius * slow_splash_radius
	for e in EnemyIndex.query(center, slow_splash_radius):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue  # the main target already got slowed by the direct hit
		if enemy.is_flying and not hits_flying:
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_sq:
			enemy.apply_slow(slow_factor, slow_time)

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
