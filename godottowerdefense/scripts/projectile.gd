extends Node2D
class_name Projectile
## Homes toward its target and applies its payload on impact: direct damage, an
## optional splash (all enemies in radius for splash_factor damage), and optional
## slow / poison debuffs. Configured by the firing tower; drawn as a coloured bolt.

const AreaRing := preload("res://scripts/area_ring.gd")  ## Expanding ring at a REAL radius; see area_ring.gd.
const ImpactBurst := preload("res://scripts/impact_burst.gd")
## Fire's impact keeps its own hot core and its falling embers; every other element gets the
## same burst tinted with its own colour, smaller, and with the gravity off.
const FIRE_IMPACT_COLOR := Color(1.0, 0.43, 0.035)
const FIRE_IMPACT_GRAVITY := 14.0
## Sized down from Fire's: a Water tower fires several times a second, and a full-size bloom
## on every one of those hits buries the creeps under it.
const IMPACT_SCALE := 0.7
## How high a shot RISES on the way over, in px, and drawn-only — see _draw(). Keyed by
## `shape` rather than by element, so a fusion lobs on its own account: Clay throws a clod of
## mud and Lava throws a rock, while Steam is a puff and Roots drives straight. A shape
## absent from the table flies flat.
const ARC_HEIGHT := {"fire": 22.0, "earth": 28.0, "clay": 26.0, "lava": 28.0}
const BIRTH_TIME := 0.09
## How far the fire bolt's body reaches behind its head. Close to the plain bolt's own 24px
## tail on purpose: a fireball may be the chunkier of the two, but the twelve-frame painted
## one used to be in a different weight class from every other element's shot, and matching
## the family is the point of this drawing.
const FIRE_TRAIL_LONG := 30.0

var speed: float = 630.0  ## px/s. Scales with tower range so flight *time* stays constant.
var damage: float = 10.0
var color: Color = Color.WHITE
## What this bolt is DRAWN as — Tower.art_key(), the same key the firing tower's painted set
## is filed under: "water" for a base tower, "steam" / "flesh_golem" / "pure" for a fusion.
##
## It used to be the tower's base `element`, which is what the tower was BUILT as and never
## changes when it fuses. That made the drawing lie: two Steam towers, one raised out of Fire
## and one out of Water, threw a flame leaf and a water slug at the same creep. Identity comes
## from the element SET everywhere else in the game (Tower._recompute picks the definition
## that way, Game.fusion_key keys it that way), and now the shot agrees.
var shape: String = ""
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
	# Every element's bolt animates now — a wavering flame tail, a breaking stream, a spinning
	# leaf, a tumbling rock — so the clock runs for all of them and the repaint is
	# unconditional. It used to be Fire's alone, and every other bolt was drawn exactly once:
	# setting `rotation` below re-renders the cached commands under a new transform, it does
	# not re-run _draw().
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
		# The blast, at the size it actually is. Earth 90px, Lava 110, Steam 80 — three
		# different areas that all used to land as the same 34px pop, so the one stat that
		# decides where a splash tower should STAND was the one stat never drawn. Quieter than
		# the slow field's ring (0.55) because Steam sets this off two and a half times a
		# second and a full-weight hoop at that rate strobes.
		AreaRing.spawn(self, impact, splash_radius, color, 0.55)
	if slow_splash_radius > 0.0 and slow_time > 0.0:
		_apply_slow_splash(target, impact)
		AreaRing.spawn(self, impact, slow_splash_radius)  # show the frost field, in its own ice
	if burn_spread_radius > 0.0 and burn_time > 0.0:
		_apply_burn_splash(target, impact)
	if crack_spread_radius > 0.0 and crack_time > 0.0:
		_apply_crack_splash(target, impact)
	# Falling embers read as burning debris, so they go to the two bolts that actually set
	# things alight: base Fire and Lava, the only rows in the game carrying a burn payload.
	# Base Fire keeps its own hand-tuned core colour so its impact is unchanged; Lava gets the
	# same weight in its own. This tested `element` before, i.e. the build origin — so a Roots
	# tower grown out of a Fire tower dropped a fireball's impact into a bramble.
	if shape == "fire":
		ImpactBurst.spawn(self, impact, FIRE_IMPACT_COLOR, 1.0, FIRE_IMPACT_GRAVITY)
	elif burn_time > 0.0:
		ImpactBurst.spawn(self, impact, color, 1.0, FIRE_IMPACT_GRAVITY)
	elif ignores_matchup:
		# Infernal, Rainbow and Pure. Chaos is the one payload in the game with NO tell of any
		# kind: a slow, a poison and a stun each hang a status ring on the enemy, and burn
		# drops embers — but "no armour resists this" is a rule about the damage formula, and
		# _show_damage prints a flat 1.0 matchup as a plain white number identical to a neutral
		# hit. So the shards from the bolt land with it, and the shape a player learnt in the
		# air is the shape they see arrive.
		ImpactBurst.spawn(self, impact, color, IMPACT_SCALE, 0.0, true)
	else:
		ImpactBurst.spawn(self, impact, color, IMPACT_SCALE)
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

## The bolt. Every element throws its own thing, and the whole point of the four shapes is
## that they are told apart by SILHOUETTE: a fire leaf, a water slug, a spinning leaf and a
## tumbling rock. Colour cannot do that job here — a fused tower is tinted with the fusion's
## colour, so on a busy board the same green can be Nature, Roots or Dinosaur.
##
## The SHAPE comes from `shape` — the tower's own identity, base or fused — so all seventeen
## towers throw their own thing and a fusion is no longer a base bolt in a different colour.
## The COLOUR is still the definition's, which for a fusion is the fusion's.
##
## In this node's local frame +x is the direction of travel (`rotation` is set to the bearing
## every frame), so everything trailing is drawn at -x.
func _draw() -> void:
	# A drawn-only arc. Collision keeps following the straight homing path, so lobbing a shot
	# can never miss a fast target or shift a tower's balance. Fire lobs and Earth lobs harder
	# — it is throwing a rock — while Water is a jet and Nature glides, so both of those stay
	# flat and get 0 from the table.
	var arc: float = ARC_HEIGHT.get(shape, 0.0)
	var offset := Vector2.ZERO
	if arc > 0.0:
		var progress := clampf(_travelled / _flight_length, 0.0, 1.0)
		offset = Vector2(0.0, -sin(progress * PI) * arc).rotated(-rotation)
	# Bolts come out of a pool, so without this they appear at full size on their first frame
	# and pop. Growing over the first fraction of a second hides the seam.
	var birth := clampf(_visual_time / BIRTH_TIME, 0.0, 1.0)
	match shape:
		"fire": _draw_fire_bolt(offset, birth)
		"water": _draw_water_bolt(offset, birth)
		"nature": _draw_nature_bolt(offset, birth)
		"earth": _draw_earth_bolt(offset, birth)
		"clay": _draw_clay_bolt(offset, birth)
		"lava": _draw_lava_bolt(offset, birth)
		"sun": _draw_sun_bolt(offset, birth)
		"steam": _draw_steam_bolt(offset, birth)
		"well": _draw_well_bolt(offset, birth)
		"roots": _draw_roots_bolt(offset, birth)
		"dinosaur": _draw_dino_bolt(offset, birth)
		"flesh_golem": _draw_flesh_bolt(offset, birth)
		# One drawing for the three chaos rows — see _draw_chaos_bolt.
		"infernal", "rainbow", "pure": _draw_chaos_bolt(offset, birth)
		_: _draw_plain_bolt(offset, birth)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Fire: a tapered leaf lying on its side — the SAME shape the tower's brazier is built from,
## turned through ninety degrees. Three nested copies give it depth, exactly as on the tower.
func _draw_fire_bolt(offset: Vector2, birth: float) -> void:
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	_draw_flame_body(FIRE_TRAIL_LONG, 7.4, Color(1.0, 0.26, 0.03, 0.30))
	_draw_flame_body(FIRE_TRAIL_LONG * 0.62, 5.0, Color(1.0, 0.55, 0.09, 0.55))
	_draw_flame_body(FIRE_TRAIL_LONG * 0.30, 3.0, Color(1.0, 0.88, 0.42, 0.75))
	draw_circle(Vector2.ZERO, 8.2, Color(1.0, 0.30, 0.03, 0.26))
	draw_circle(Vector2.ZERO, 5.4, Color(1.0, 0.58, 0.08, 0.92))
	draw_circle(Vector2(-0.6, -1.6), 2.5, Color(1.0, 0.96, 0.70, 0.95))

## Water: a thrown slug of water with the stream breaking up behind it. Blunt and heavy-headed
## where Fire's is pointed and tapered, which is the whole difference at 20px and in motion.
func _draw_water_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	var wob := sin(_visual_time * 21.0)
	# Squashed across the flight line: the head reads as pushed flat by the air it is crossing.
	draw_set_transform(offset, 0.0, Vector2(1.16, 0.86) * birth)
	draw_circle(Vector2.ZERO, 11.0, Color(c.r, c.g, c.b, 0.22))
	draw_circle(Vector2.ZERO, 7.2, c)
	draw_circle(Vector2(-1.8, -2.4), 3.0, Color(1.0, 1.0, 1.0, 0.62))
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	# Droplets shed behind it, each smaller and further off the line than the last. They wobble
	# together rather than independently — one stream coming apart, not three separate shots.
	for i in 3:
		var f := float(i)
		draw_circle(Vector2(-9.0 - f * 7.0, wob * (1.4 + f * 1.5)), 4.4 - f * 1.1,
				Color(c.r, c.g, c.b, 0.62 - f * 0.15))

## Nature: a leaf turning over as it flies, paying out a vine behind it. The node is already
## rotated onto the flight line, so the spin rides on top of that and the leaf tumbles along
## its own path rather than about the screen.
func _draw_nature_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	# Vine first, so the leaf sits over the end of it.
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	var prev := Vector2.ZERO
	for i in range(1, 5):
		var f := float(i)
		var to := Vector2(-f * 7.0, sin(_visual_time * 13.0 - f * 0.9) * f * 1.7)
		draw_line(prev, to, Color(c.r * 0.55, c.g * 0.85, c.b * 0.45, 0.58 - f * 0.11),
				2.6 - f * 0.4)
		prev = to
	draw_set_transform(offset, _visual_time * 9.0, Vector2.ONE * birth)
	# A pointed oval: six points is enough for a leaf at this size, and the two sharp ends are
	# the only part the eye actually reads.
	draw_colored_polygon(PackedVector2Array([
		Vector2(9.0, 0.0), Vector2(3.0, -4.6), Vector2(-3.0, -4.2),
		Vector2(-9.0, 0.0), Vector2(-3.0, 4.2), Vector2(3.0, 4.6),
	]), c)
	draw_line(Vector2(-7.6, 0.0), Vector2(7.6, 0.0), Color(1.0, 1.0, 1.0, 0.42), 1.4)

## Earth: a rock, tumbling, trailing the dust it knocked loose. Angular on purpose — the other
## three shots are built entirely out of curves, so flat facets are what identifies this one
## before its colour is even registered.
func _draw_earth_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	for i in 3:
		var f := float(i)
		draw_circle(Vector2(-10.0 - f * 6.5, sin(_visual_time * 9.0 + f * 2.0) * (1.5 + f)),
				4.6 - f * 0.9, Color(c.r * 0.85, c.g * 0.80, c.b * 0.72, 0.30 - f * 0.07))
	draw_set_transform(offset, _visual_time * 6.0, Vector2.ONE * birth)
	var body := PackedVector2Array([
		Vector2(8.4, -1.6), Vector2(4.0, -7.4), Vector2(-3.2, -7.0), Vector2(-8.0, -1.2),
		Vector2(-5.6, 5.8), Vector2(1.8, 8.0), Vector2(7.4, 4.2),
	])
	draw_colored_polygon(body, c.darkened(0.18))
	# One lit facet. Without it a spinning rock is a spinning blob — the turn is only visible
	# because something on the surface catches the light and moves.
	draw_colored_polygon(PackedVector2Array([
		Vector2(8.4, -1.6), Vector2(4.0, -7.4), Vector2(-3.2, -7.0), Vector2(0.6, -1.0),
	]), c.lightened(0.30))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.45), 1.4)

## The bolt every element had before it had one of its own. Unreachable from the shipped roster
## — Game.TOWER_DEFS has exactly the four elements above — and kept as the match's default so a
## fifth element added later draws something rather than nothing while its shape is designed.
func _draw_plain_bolt(offset: Vector2, birth: float) -> void:
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -6), Vector2(0, 6), Vector2(-24, 0),
	]), Color(color.r, color.g, color.b, 0.30))
	draw_circle(Vector2.ZERO, 12.0, Color(color.r, color.g, color.b, 0.25))  # glow
	draw_circle(Vector2.ZERO, 7.5, color)
	draw_circle(Vector2(-2.2, -2.2), 3.0, Color(1, 1, 1, 0.6))               # highlight
	draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 12, Color(0, 0, 0, 0.4), 1.5, true)

## One tapered flame body lying along the bolt's own -x: `length` behind the head, `half` tall
## at it. Seven points rather than the triangle the plain bolt uses, because the taper is what
## makes it fire — a triangle of the same size is a dart.
##
## The tail wavers on one sine. That waver is the whole reason the painted twelve frames can
## go: what the animation actually bought at this size was a tail that did not look welded on,
## and a flying bolt is on screen for well under a second.
func _draw_flame_body(length: float, half: float, col: Color) -> void:
	var wag := sin(_visual_time * 17.0) * half * 0.45
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -half),
		Vector2(-length * 0.30, -half * 0.86),
		Vector2(-length * 0.70, -half * 0.34 + wag),
		Vector2(-length, wag),
		Vector2(-length * 0.70, half * 0.34 + wag),
		Vector2(-length * 0.30, half * 0.86),
		Vector2(0.0, half),
	]), col)

# --- The fusion bolts -------------------------------------------------------------------
# Eleven combination towers, and until now every one of them threw whatever its BUILD ORIGIN
# threw, tinted with the fusion's colour. `shape` fixed which drawing gets picked; these are
# the drawings.
#
# Each is built out of the four base bolts' own vocabulary rather than a new one, because the
# point of a combination is that both parents stay legible in it: Clay is Earth's tumble
# shedding Water's droplets, Lava is Earth's rock inside Fire's flame body, Roots is Nature's
# vine ending in something Earth-angular. What a dual must never read as is a third,
# unrelated element.
#
# They are told apart by SILHOUETTE, exactly as the four base bolts are and for the same
# reason: on a late board a dozen of these are in the air at once, and several share a
# palette (Sun, Lava and Infernal are all warm; Well, Steam and Water are all pale blue).

## Clay: a wet lump turning over, shedding what will not stick to it. Earth's tumble at half
## the spin — a clod of mud is heavier than a rock and does not spin like one — with Water's
## droplet trail where Earth throws dust.
func _draw_clay_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	var wob := sin(_visual_time * 15.0)
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	for i in 3:
		var f := float(i)
		# Darkened rather than tinted: wet clay coming off the lump is the SHADOWED side of
		# the same colour, and at 0.85 of a pale tan the drips vanished into the road.
		draw_circle(Vector2(-9.0 - f * 6.0, wob * (1.2 + f * 1.3)), 4.2 - f * 0.9,
				Color(c.r * 0.55, c.g * 0.42, c.b * 0.32, 0.75 - f * 0.16))
	draw_set_transform(offset, _visual_time * 3.0, Vector2.ONE * birth)
	# Seven points like Earth's rock, but not one of them sharp: the silhouette is what
	# separates a clod from a stone, since at this size both are brown blobs otherwise.
	var body := PackedVector2Array([
		Vector2(8.8, 0.6), Vector2(5.2, -6.4), Vector2(-1.6, -8.0), Vector2(-8.2, -3.0),
		Vector2(-7.4, 4.2), Vector2(-1.0, 8.4), Vector2(6.0, 5.4),
	])
	draw_colored_polygon(body, c)
	# The outline is not decoration, it is the whole reason the shape reads. Photographed
	# against the pale cobbles of the road — which is where this bolt spends its whole life —
	# an unoutlined tan lump on tan stone was a smudge with no edges at all. Earth's rock has
	# carried the same line since it was drawn, for the same reason.
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, Color(0.0, 0.0, 0.0, 0.45), 1.4)
	# The wet highlight does NOT turn with the lump — a slick surface keeps catching the light
	# from the same place, and a highlight that tumbles just reads as a painted spot.
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	draw_circle(Vector2(-1.4, -3.2), 2.8, Color(1.0, 1.0, 1.0, 0.30))
	draw_circle(Vector2(2.6, 2.0), 1.6, Color(1.0, 1.0, 1.0, 0.18))

## Lava: Earth's rock, still molten. Fire's own flame body trails it and the facets GLOW
## instead of catching the light, so both parents stay readable and what identifies the tower
## is the overlap — a rock that is on fire — rather than a third idea.
##
## The stone itself is drawn nearly black, and that is the whole trick: paint it in the row's
## orange and it stops being a rock and becomes a fireball with corners.
func _draw_lava_bolt(offset: Vector2, birth: float) -> void:
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	_draw_flame_body(FIRE_TRAIL_LONG * 0.85, 6.4, Color(1.0, 0.30, 0.04, 0.34))
	_draw_flame_body(FIRE_TRAIL_LONG * 0.45, 4.2, Color(1.0, 0.62, 0.12, 0.55))
	draw_circle(Vector2.ZERO, 11.5, Color(1.0, 0.42, 0.08, 0.22))
	draw_set_transform(offset, _visual_time * 5.0, Vector2.ONE * birth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7.8, -1.4), Vector2(3.6, -6.8), Vector2(-3.0, -6.4), Vector2(-7.4, -1.0),
		Vector2(-5.2, 5.2), Vector2(1.6, 7.4), Vector2(6.8, 3.8),
	]), Color(0.20, 0.12, 0.11))
	# Cracks, and they are the only part carrying colour. Brightening on the same sine the
	# flame body wavers on, so the stone breathes with its own trail rather than beside it.
	var heat := 0.72 + 0.28 * sin(_visual_time * 17.0)
	draw_line(Vector2(-6.0, -2.2), Vector2(4.6, 1.4), Color(1.0, 0.72, 0.22, 0.90 * heat), 2.0)
	draw_line(Vector2(-0.6, -6.0), Vector2(1.8, 6.2), Color(1.0, 0.48, 0.10, 0.72 * heat), 1.6)
	draw_line(Vector2(1.4, -1.0), Vector2(-5.4, 3.8), Color(1.0, 0.55, 0.14, 0.60 * heat), 1.4)

## Sun: a disc throwing rays, turning as it goes, and the ONLY bolt in the game with no trail
## behind it. Every other shot is a thing being thrown; what a sun does that none of them do
## is shine in all directions at once, so this drawing is symmetric on purpose and reads as
## light rather than as a projectile.
func _draw_sun_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	draw_set_transform(offset, _visual_time * 4.0, Vector2.ONE * birth)
	# Eight rays, alternating long and short. Eight equal ones turn into a static star at this
	# size — the alternation is what makes the rotation visible at all.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var reach: float = 15.5 if i % 2 == 0 else 10.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * 5.0, dir * reach, Color(c.r, c.g, c.b, 0.55), 2.2)
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	draw_circle(Vector2.ZERO, 11.0, Color(c.r, c.g, c.b, 0.22))
	draw_circle(Vector2.ZERO, 6.4, c)
	draw_circle(Vector2.ZERO, 3.2, Color(1.0, 0.99, 0.88, 0.95))

## Steam: a puff coming apart, deliberately the faintest bolt in the game. Steam fires two and
## a half times a second — the shortest interval of any tower — and at that rate anything with
## a hard edge on it turns the road into a stream of beads. It also SWELLS across its flight
## instead of tumbling, which is a motion no other bolt has.
func _draw_steam_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	var grow := 1.0 + clampf(_travelled / _flight_length, 0.0, 1.0) * 0.45
	draw_set_transform(offset, 0.0, Vector2.ONE * birth * grow)
	# Three lobes drifting apart, where Water's shot is one slug holding together.
	for i in 3:
		var f := float(i)
		var puff := Vector2(-f * 6.5, sin(_visual_time * 8.0 + f * 2.1) * (1.0 + f * 1.8))
		draw_circle(puff, 8.0 - f * 1.9, Color(c.r, c.g, c.b, 0.30 - f * 0.07))
		draw_circle(puff, 4.6 - f * 1.2, Color(c.r, c.g, c.b, 0.42 - f * 0.10))
	draw_circle(Vector2(1.5, -1.0), 3.4, Color(1.0, 1.0, 1.0, 0.55))

## Well: a drop carried inside a turning ring. Water's blunt head with Nature's rotation on
## it — and the ring is the aura the tower exists to project, which is the one thing about
## Well a player actually has to learn.
func _draw_well_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	# Squashed on y and turning, so it reads as a ring lying around the drop in perspective
	# rather than as a circle drawn on top of it.
	draw_set_transform(offset, _visual_time * 6.0, Vector2(1.0, 0.55) * birth)
	draw_arc(Vector2.ZERO, 11.5, 0.0, TAU, 22, Color(c.r, c.g, c.b, 0.60), 2.2, true)
	draw_set_transform(offset, 0.0, Vector2(1.10, 0.90) * birth)
	draw_circle(Vector2.ZERO, 9.5, Color(c.r, c.g, c.b, 0.22))
	draw_circle(Vector2.ZERO, 6.0, c)
	draw_circle(Vector2(-1.5, -2.0), 2.6, Color(1.0, 1.0, 1.0, 0.62))

## Roots: a thorn on the end of a vine. Nature's vine trail unchanged in idea, ending in
## something ANGULAR instead of a leaf — Roots is the one Nature combination that holds things
## still rather than poisoning them, and a barb is what that looks like.
##
## The barb does not spin. A root drives forward; it is the only bolt here that stays fixed on
## its own flight line, and that is most of what tells it apart from Nature's tumbling leaf.
func _draw_roots_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	var prev := Vector2.ZERO
	for i in range(1, 6):
		var f := float(i)
		var to := Vector2(-f * 6.5, sin(_visual_time * 9.0 - f * 0.8) * f * 1.9)
		# LIGHTENED, not darkened. Roots' own colour is a deep olive and the board it crosses
		# is a pine forest — scaling that colour down, which is what every other trail in this
		# file does, drew a dark green line on dark green trees and the vine simply was not
		# there in the photograph.
		draw_line(prev, to, Color(c.r + 0.22, c.g + 0.26, c.b + 0.16, 0.75 - f * 0.11),
				3.2 - f * 0.45)
		prev = to
	var barb := PackedVector2Array([
		Vector2(11.0, 0.0), Vector2(-1.0, -5.4), Vector2(-4.5, 0.0), Vector2(-1.0, 5.4),
	])
	draw_colored_polygon(barb, c.lightened(0.12))
	var barb_edge := barb.duplicate()
	barb_edge.append(barb[0])
	draw_polyline(barb_edge, Color(0.0, 0.0, 0.0, 0.50), 1.3)
	# Two back-swept hooks. Without them the head is an arrowhead, which belongs to a
	# different kind of tower entirely.
	draw_line(Vector2(1.0, -3.4), Vector2(5.6, -6.8), c.lightened(0.18), 1.8)
	draw_line(Vector2(1.0, 3.4), Vector2(5.6, 6.8), c.lightened(0.18), 1.8)
	draw_line(Vector2(-3.0, 0.0), Vector2(9.2, 0.0), Color(1.0, 1.0, 1.0, 0.32), 1.4)

## Dinosaur: a bite, opening and closing as it crosses. The row's whole identity is "devours
## enemies", so what flies is the jaws themselves rather than something they spat — and the
## spatter trailing behind is Nature's poison, which is the other half of what the bite does.
func _draw_dino_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	# 0 shut, 1 wide. Fast enough to snap two or three times over a short flight.
	var gape := 0.5 + 0.5 * sin(_visual_time * 16.0)
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	for i in 3:
		var f := float(i)
		draw_circle(Vector2(-10.0 - f * 6.0, sin(_visual_time * 10.0 + f * 2.0) * (1.4 + f)),
				3.6 - f * 0.8, Color(c.r * 0.70, c.g * 0.95, c.b * 0.50, 0.45 - f * 0.11))
	# Upper and lower jaw, hinged at the back and mirrored about the flight line.
	for side in 2:
		var s: float = -1.0 if side == 0 else 1.0
		var hinge := Vector2(-7.0, s * 1.0)
		var tip := Vector2(10.5, s * (1.6 + gape * 5.4))
		draw_colored_polygon(PackedVector2Array([
			hinge, tip, tip + Vector2(-6.0, s * 4.0), hinge + Vector2(1.0, s * 4.0),
		]), c.darkened(0.14) if side == 0 else c)
		# Three teeth along the biting edge, pointing across the gap.
		for i in 3:
			var root := hinge.lerp(tip, 0.20 + float(i) * 0.28)
			draw_line(root, root - Vector2(0.0, s * 3.4), Color(1.0, 0.98, 0.90, 0.85), 1.6)
	draw_circle(Vector2(-3.5, 0.0), 3.2, Color(c.r, c.g, c.b, 0.60))

## Flesh Golem: a thrown piece of the thing itself, beating. This row grows permanently with
## every kill it lands, so its shot is the one that has to look ALIVE — the pulse is a
## heartbeat rather than a flicker, and it is the only bolt in the game whose body changes
## size under its own power.
func _draw_flesh_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	# Cubed, so the beat has the sharp attack and long release a pulse actually has. A plain
	# sine here reads as breathing, which is a different animal.
	var beat := pow(0.5 + 0.5 * sin(_visual_time * 12.0), 3.0)
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	# Sinew paid out behind it, thinning as it stretches.
	var prev := Vector2.ZERO
	for i in range(1, 4):
		var f := float(i)
		var to := Vector2(-f * 7.5, sin(_visual_time * 11.0 - f * 1.1) * f * 2.2)
		draw_line(prev, to, Color(c.r * 0.95, c.g * 0.42, c.b * 0.48, 0.80 - f * 0.16),
				4.0 - f * 0.80)
		prev = to
	draw_set_transform(offset, 0.0, Vector2.ONE * birth * (0.92 + beat * 0.18))
	draw_circle(Vector2.ZERO, 10.5, Color(c.r, c.g, c.b, 0.20))
	draw_circle(Vector2.ZERO, 7.6, c.darkened(0.22))
	# A dark rim, so the mass has an edge. Without it this was the one bolt in the set with no
	# line and no facet anywhere on it, and it photographed as a flat pink counter.
	draw_arc(Vector2.ZERO, 7.6, 0.0, TAU, 20, Color(0.18, 0.05, 0.07, 0.55), 1.6, true)
	# A brighter core showing THROUGH the mass. The beat has to be something inside the bolt,
	# not the whole bolt changing size, or it reads as the shot flying at the camera.
	draw_circle(Vector2(-0.8, -0.6), 3.8 + beat * 1.8,
			Color(1.0, 0.80, 0.76, 0.55 + beat * 0.40))
	draw_circle(Vector2(-2.6, -3.0), 2.2, Color(1.0, 1.0, 1.0, 0.34))

## The chaos bolt: Infernal, Rainbow and Pure. ONE drawing for all three, because they share
## the one rule worth learning — chaos damage, which no armour resists — and a player who has
## learnt to read this shape has learnt it. They are told apart by colour, which is safe here
## and nowhere else: nothing else in the game looks like this, so the colour is a label on a
## known thing rather than the identity itself.
##
## Two counter-rotating rings of shards. Counter-rotating on purpose — every other spinning
## thing on the board turns one way, so opposed motion is the cheapest way to say "this one is
## not playing by the rules".
func _draw_chaos_bolt(offset: Vector2, birth: float) -> void:
	var c := color
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	draw_circle(Vector2.ZERO, 14.0, Color(c.r, c.g, c.b, 0.16))
	for ring in 2:
		var spin: float = 5.0 if ring == 0 else -6.5
		var radius: float = 11.0 if ring == 0 else 6.8
		draw_set_transform(offset, _visual_time * spin, Vector2.ONE * birth)
		for i in 3:
			var a := TAU * float(i) / 3.0 + float(ring) * 0.52
			var at := Vector2(cos(a), sin(a)) * radius
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -3.4).rotated(a),
				at + Vector2(4.4, 0.0).rotated(a),
				at + Vector2(0.0, 3.4).rotated(a),
			]), Color(c.r, c.g, c.b, 0.85 - float(ring) * 0.18))
	draw_set_transform(offset, 0.0, Vector2.ONE * birth)
	draw_circle(Vector2.ZERO, 5.0, c.lightened(0.35))
	draw_circle(Vector2.ZERO, 2.6, Color(1.0, 1.0, 1.0, 0.92))
