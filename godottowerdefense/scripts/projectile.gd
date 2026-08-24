extends Node2D
class_name Projectile
## Homes toward its target and applies its payload on impact: direct damage, an
## optional splash (all enemies in radius for splash_factor damage), and optional
## slow / poison debuffs. Configured by the firing tower; drawn as a coloured bolt.

const FrostRing := preload("res://scripts/frost_ring.gd")  ## Ice's area-slow impact visual.
const FireImpact := preload("res://scripts/fire_impact.gd")
const Sprites := preload("res://scripts/sprites.gd")
const FIREBALL_FRAMES := 12
const FIREBALL_FPS := 18.0
const FIRE_ARC_HEIGHT := 22.0
const FIRE_BIRTH_TIME := 0.09

var speed: float = 630.0  ## px/s. Scales with tower range so flight *time* stays constant.
var damage: float = 10.0
var color: Color = Color.WHITE
var element: String = ""  ## Base damage element; drives element-specific visuals and hooks.
## Every element the firing tower carries. The matchup takes the BEST of these against the
## target's armour (Game.element_mult_best), which is what a fusion actually buys: broader
## coverage, up to a Pure tower's set of four that nothing can resist.
var elements: Array = []
## Chaos-type damage (Infernal, Rainbow, Pure): skip the matchup and use a flat 1.0.
var ignores_matchup: bool = false
## Pure: this bolt's control payload ignores Enemy.cc_immune. Threaded into every
## apply_slow / apply_stun / apply_knockback call below.
var pierces_rules: bool = false
var slow_chance: float = 1.0  ## Clay: chance the slow lands at all (1.0 = every hit).
## The tower that fired this bolt, for Flesh Golem's per-kill growth. Weak by convention:
## always tested with is_instance_valid() before use, since a bolt can outlive a tower the
## player sold mid-flight.
var source_tower: Node = null
var splash_radius: float = 0.0
var splash_factor: float = 0.5
var hits_flying: bool = true    ## False skips flyers (ground-only towers) for splash.
var slow_factor: float = 1.0    ## < 1 slows the enemy on hit.
var slow_time: float = 0.0
var slow_splash_radius: float = 0.0  ## If > 0, the slow (only) also chills enemies within this radius of impact.
var poison_dps: float = 0.0
var poison_time: float = 0.0
var poison_ignores_matchup: bool = false  ## Nature's THORN: bypasses Game.element_mult entirely.
var poison_spreads_on_death: bool = false ## Poison passes to a survivor on death.
var stun_chance: float = 0.0    ## 0..1 chance to freeze the enemy on hit.
var execute_chance: float = 0.0      ## 0..1 chance to kill outright (Death). Never bosses.
var gold_on_kill: int = 0            ## Extra gold when this bolt lands the killing blow (Money).
var life_on_kill_chance: float = 0.0 ## 0..1 chance a kill by this bolt returns a life (Life).
var stun_time: float = 0.0

# --- Damage-over-time and debuff payload ----------------------------------------
# Generic channels a definition switches on: Lava sets burn, Dinosaur sets poison, Roots
# sets stun. The rest (stacking, spreading, crack, knockback) have no producer in
# Game.FUSIONS today and sit here the same way execute_chance and gold_on_kill do -- a
# payload the data may turn on, not a feature waiting to be deleted.
var burn_dps: float = 0.0             ## Per-stack. See Enemy.apply_burn.
var burn_time: float = 0.0
var burn_max_stacks: int = 1
var burn_spread_radius: float = 0.0   ## Also burns (half power) within this radius.
var burn_doubles_at_max: bool = false ## Burn ticks 2x at the stack cap.
var burn_spreads_on_death: bool = false  ## A burning death lights its neighbours.
var crack_bonus: float = 0.0          ## Armor crack: +fraction damage taken from all sources.
var crack_time: float = 0.0
var crack_spread_radius: float = 0.0  ## Crack also spreads within this radius.
var knockback_chance: float = 0.0     ## Chance per hit to shove the target back.
var knockback_distance: float = 0.0
var knockback_chill_on_land: bool = false  ## Applies this bolt's slow where it lands.

# --- Conditional multipliers, resolved against the TARGET at hit time ------------
# Folded from Run (the Workshop) rather than set by a definition -- see TowerMods.
var vs_flying_mult: float = 1.0   ## Damage multiplier vs flying targets.
var burn_slow_factor: float = 1.0 ## Burn also applies this slow (1.0 = off).
var chill_burn_mult: float = 1.0  ## Burn vs a target something has chilled.
var chill_hit_mult: float = 1.0   ## Direct hits vs a chilled target.

var _target: Enemy = null
var pool: Node = null  ## The $Projectiles pool that owns this bolt (see projectiles.gd); null = unpooled.
var _visual_time: float = 0.0
var _flight_length: float = 1.0
var _travelled: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup(start: Vector2, target: Enemy, dmg: float) -> void:
	global_position = start
	_target = target
	damage = dmg
	_visual_time = 0.0
	_travelled = 0.0
	_flight_length = maxf(1.0, start.distance_to(target.global_position))
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
	if element == "fire":
		_visual_time += delta
		queue_redraw()
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
	_travelled += step

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
	if burn_spread_radius > 0.0 and burn_time > 0.0:
		_apply_burn_splash(target, impact)
	if crack_spread_radius > 0.0 and crack_time > 0.0:
		_apply_crack_splash(target, impact)
	if element == "fire":
		FireImpact.spawn(self, impact)
	_recycle()

## This bolt's damage multiplier against `enemy`'s armour. The one place the fusion ladder
## touches the damage formula: a chaos-type tower is flat 1.0, everything else takes the best
## its element SET can manage. An unfused tower carries one element, so this is identical to
## the old Game.element_mult call for it.
func _matchup(enemy: Enemy) -> float:
	if ignores_matchup:
		return 1.0
	return Game.element_mult_best(elements, enemy.armor_element)

## Applies damage (scaled by mult and the element matchup) plus any slow / poison / burn /
## crack / knockback. `show_number` is only set for the direct hit — a wide splash would
## otherwise bury the screen under a dozen simultaneous numbers.
func _apply(enemy: Enemy, mult: float, show_number: bool) -> void:
	# Whether it was alive BEFORE this bolt touched it. _apply also runs for every splash
	# victim, and one of those can already be a corpse from an earlier hit this frame —
	# without this the on-kill payouts below would pay out for killing something twice.
	var was_alive := enemy.is_alive()
	var matchup := _matchup(enemy)
	var dealt := damage * mult * matchup
	# Spore (vs flying) and EROSION (vs a target Water has chilled) — both conditional on the
	# TARGET's own state, so they can only be resolved here at hit time, never baked into a
	# static tower stat. `chill_hit_mult`/`chill_burn_mult` are 1.0 unless the matching card
	# was taken AND this tower's element is the one it scoped to (folded in Tower._recompute).
	if enemy.is_flying:
		dealt *= vs_flying_mult
	if enemy.is_chilled():
		dealt *= chill_hit_mult
	enemy.flash()
	if show_number:
		_show_damage(enemy.global_position, dealt, matchup)
	enemy.take_damage(dealt)
	# Clay is the one tower whose slow is a CHANCE rather than a certainty ("with a chance to
	# slow", straight off its map tooltip); slow_chance is 1.0 for every other slowing tower,
	# so the roll is a no-op for them.
	if slow_time > 0.0 and (slow_chance >= 1.0 or randf() < slow_chance):
		enemy.apply_slow(slow_factor, slow_time, pierces_rules)
	if poison_time > 0.0:
		# Nature's THORN ignores the matchup entirely (GAME_STRATEGY_V2.md §3.1) — the one
		# payload in the game that does not respect `matchup`, direct hits included.
		var poison_matchup := 1.0 if poison_ignores_matchup else matchup
		enemy.apply_poison(poison_dps * mult * poison_matchup, poison_time,
				poison_spreads_on_death)
	if burn_time > 0.0:
		var burn_dealt := burn_dps * mult * matchup
		if enemy.is_chilled():
			burn_dealt *= chill_burn_mult  # STEAM
		enemy.apply_burn(burn_dealt, burn_time, burn_max_stacks,
				burn_doubles_at_max, burn_spreads_on_death)
		# Backdraft: burn also chills — read here rather than folded into `slow_time` above,
		# since Fire towers have no slow payload of their own to piggyback on otherwise.
		if burn_slow_factor < 1.0:
			enemy.apply_slow(burn_slow_factor, burn_time, pierces_rules)
	if crack_time > 0.0:
		enemy.apply_crack(crack_bonus, crack_time)
	if knockback_distance > 0.0 and randf() < knockback_chance:
		var landed := enemy.apply_knockback(knockback_distance, pierces_rules)
		if landed and knockback_chill_on_land and slow_time > 0.0:
			enemy.apply_slow(slow_factor, slow_time, pierces_rules)
	if stun_time > 0.0 and randf() < stun_chance:
		enemy.apply_stun(stun_time, pierces_rules)
	# Death's execute. Rolled AFTER the normal hit so a creep the damage already killed does
	# not consume the roll, and never on a boss — the map spares mechanical and undead
	# creeps, and bosses are the set-piece enemies we have to stand in for those classes.
	if enemy.is_alive() and not enemy.is_boss and execute_chance > 0.0 \
			and randf() < execute_chance:
		FloatingText.spawn(self, enemy.global_position + Vector2(0, -28.0), "EXECUTE",
				Color(0.75, 0.55, 0.95), 18)
		enemy.take_damage(enemy.health)
	# Money and Life pay out only when THIS bolt landed the killing blow, which is why the
	# check is here and not in Enemy._die(): the enemy has no idea who shot it, and a payout
	# there would fire for every kill on the board regardless of which tower earned it.
	if was_alive and not enemy.is_alive():
		if gold_on_kill > 0:
			Game.add_gold(gold_on_kill)
		if life_on_kill_chance > 0.0 and randf() < life_on_kill_chance:
			Game.add_life(1)
			FloatingText.spawn(self, enemy.global_position + Vector2(0, -34.0), "+1 life",
					Color(0.60, 0.95, 0.62), 17)
		# Flesh Golem "grows stronger with each unit it kills". Tested at the CALL SITE, not
		# inside a typed parameter: the tower can have been sold while this bolt was in the
		# air, and a freed node fails a typed check before the function body ever runs.
		if source_tower != null and is_instance_valid(source_tower):
			(source_tower as Tower).note_kill()

## Floating damage number, colour- and size-coded by the element matchup. This is the
## only place the matchup is visible during play: without it, the panel's "x1.75 vs
## Nature" is a promise the player never sees kept.
func _show_damage(pos: Vector2, dealt: float, matchup: float) -> void:
	var col := Color(1, 1, 1, 0.95)
	var font_size := 19
	if matchup > 1.0:
		col = Color(1.0, 0.85, 0.25)   # strong: big and gold
		font_size = 26
	elif matchup < 1.0:
		col = Color(0.62, 0.66, 0.74)  # resisted: small and grey
		font_size = 16
	FloatingText.spawn(self, pos + Vector2(0, -20.0), "%d" % int(round(dealt)),
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

## Burn spread: the burn also catches enemies near the impact, at half power and
## with no direct damage component — same shape as _apply_slow_splash, and for the same
## reason (GAME_STRATEGY_V2.md §3.1): this is a status spreading, not a second splash nuke.
func _apply_burn_splash(main_target: Enemy, center: Vector2) -> void:
	var radius_sq := burn_spread_radius * burn_spread_radius
	for e in EnemyIndex.query(center, burn_spread_radius):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue
		if enemy.is_flying and not hits_flying:
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_sq:
			enemy.apply_burn(burn_dps * 0.5 * _matchup(enemy), burn_time, burn_max_stacks,
					burn_doubles_at_max, burn_spreads_on_death)

## Crack spread: the armor crack also reaches enemies near the impact.
func _apply_crack_splash(main_target: Enemy, center: Vector2) -> void:
	var radius_sq := crack_spread_radius * crack_spread_radius
	for e in EnemyIndex.query(center, crack_spread_radius):
		var enemy := e as Enemy
		if enemy == null or enemy == main_target:
			continue
		if enemy.is_flying and not hits_flying:
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_sq:
			enemy.apply_crack(crack_bonus, crack_time)

func _draw() -> void:
	if element == "fire":
		var progress := clampf(_travelled / _flight_length, 0.0, 1.0)
		# Collision continues along the established homing path. Only the rendered fireball
		# rises, so the arc cannot miss a fast target or change tower balance.
		var arc_offset := Vector2(0.0, -sin(progress * PI) * FIRE_ARC_HEIGHT).rotated(-rotation)
		var birth := clampf(_visual_time / FIRE_BIRTH_TIME, 0.0, 1.0)
		draw_set_transform(arc_offset, 0.0, Vector2.ONE * birth)
		# Continuous trail/core carry the silhouette between the discrete painted poses.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-2.0, -7.0), Vector2(-2.0, 7.0), Vector2(-38.0, 0.0),
		]), Color(1.0, 0.24, 0.025, 0.25))
		for i in 4:
			var trail_x := -10.0 - i * 7.5
			var trail_y := sin(_visual_time * (13.0 + i) + i * 1.9) * (1.5 + i * 0.7)
			draw_circle(Vector2(trail_x, trail_y), 4.2 - i * 0.62,
					Color(1.0, 0.38 + i * 0.07, 0.04, 0.31 - i * 0.05))
		var frame := int(floor(_visual_time * FIREBALL_FPS)) % FIREBALL_FRAMES
		var fireball := Sprites.effect("fireball", frame)
		if fireball != null:
			draw_texture_rect(fireball, Rect2(-Vector2(25.0, 11.0), Vector2(50.0, 22.0)),
					false, Color(1.0, 1.0, 1.0, 0.78))
		draw_circle(Vector2(2.0, 0.0), 10.0, Color(1.0, 0.18, 0.02, 0.20))
		draw_circle(Vector2(2.0, 0.0), 6.2, Color(1.0, 0.48, 0.05, 0.82))
		draw_circle(Vector2(0.8, -1.8), 2.8, Color(1.0, 1.0, 0.70, 0.88))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# The node rotates toward its target, so local -x is "behind": draw a tapered
	# trail there, a soft glow, then the bright coloured core.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -6), Vector2(0, 6), Vector2(-24, 0),
	]), Color(color.r, color.g, color.b, 0.30))
	draw_circle(Vector2.ZERO, 12.0, Color(color.r, color.g, color.b, 0.25))  # glow
	draw_circle(Vector2.ZERO, 7.5, color)
	draw_circle(Vector2(-2.2, -2.2), 3.0, Color(1, 1, 1, 0.6))               # highlight
	draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 12, Color(0, 0, 0, 0.4), 1.5, true)
