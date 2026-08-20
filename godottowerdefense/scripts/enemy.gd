extends Node2D
class_name Enemy
## Walks along Game.PATH, carries health, shows a health bar, gives gold on
## death and costs the player a life if it reaches the end.
##
## Rendering is split across three z-ordered CanvasItems so a plain walking enemy repaints
## NOTHING per frame (movement is a transform; the engine re-renders the cached draw lists
## for free):
##   * this node's own _draw()  — the under-layer: ground shadow, or flapping wings.
##   * `_body`    (child, mid)  — body, highlight, outline, impact flash, eyes. The idle
##                                breathing wobble is `_body.scale`, a transform, so the body
##                                only repaints on a flash or a colour change.
##   * `_overlay` (child, top)  — status rings, archetype/regen markers, boss crown, health
##                                bar. Repaints only on a state change (damage, status
##                                apply/expire) and animates per-frame only while stunned or
##                                actively regen-healing.
## Layers are added body-then-overlay with default z, so each enemy still draws as one unit
## (shadow → body → overlay) in spawn order — visually identical to a single-node draw.

const EnemyLayer := preload("res://scripts/enemy_layer.gd")
const Sprites := preload("res://scripts/sprites.gd")

## How tall a painted creep is drawn, as a multiple of its `radius`.
##
## Radius is the game's own size for an enemy — it drives the archetype scaling (0.8x to
## 1.35x), the boss size, the health-bar width and every status ring — so the art is hung off
## it rather than off a per-archetype table. 2.6 puts a Normal at 62px tall against the 48px
## blob it replaces: a standing figure reads taller than the ball did at the same footprint.
const SPRITE_HEIGHT_PER_RADIUS := 2.6

## Carrier-motion amplitudes. Painted frames provide the limb poses; these transforms make
## the motion readable at the game's small on-board scale, including on two-pose creatures.
## Kept low so the feet read as planted on the cobbles. At 0.16 the body lifted almost 4px
## while its shadow stayed behind, which looked like hovering at the board's display scale.
const WALK_HOP_PER_RADIUS := 0.06
const WALK_SQUASH := 0.03
const FLIGHT_LIFT_PER_RADIUS := 0.26

signal removed  ## Emitted whenever the enemy leaves play (death OR escape).
## Emitted by a splitter when it dies so WaveManager can spawn its children.
## (position, path_progress, count, child_hp, child_speed, tint, child_radius)
signal split_requested(pos: Vector2, progress: int, count: int, hp: float, spd: float, tint: Color, r: float)

var speed: float = 70.0
var max_health: float = 30.0
var health: float = 30.0
var reward: int = 5
var color: Color = Color(0.85, 0.3, 0.3)
var radius: float = 16.0
var is_flying: bool = false  ## Flyers can only be hit by archer towers.
var is_boss: bool = false    ## Bosses get a crown + heavier presence.
var life_cost: int = 1       ## Lives lost if this enemy reaches the end (bosses cost more).
# Archetype traits (set by WaveManager from the wave's WAVE_TYPES entry).
var cc_immune: bool = false  ## Ignores slow / stun. Poison still applies (it's damage, not control).
var regen_dps: float = 0.0   ## Heals this much per second.
var split_into: int = 0      ## Children spawned on death (0 = none).
var armor_element: String = ""  ## Element matchup vs tower damage element ("" = neutral).
## Which WAVE_TYPES archetype this is ("normal", "fast", …). Set by WaveManager; the only
## thing that reads it is the painted sprite lookup, which is why an unset one is harmless.
var kind: String = ""

var _path: Array = []
var _target_index: int = 1
var _dead: bool = false
var _wing_phase: float = 0.0  ## Drives the wing-flap animation.
var _anim_phase: float = 0.0  ## Drives the idle breathing wobble, the stun sparks, the regen pulse.
## Drives the walk cycle of a PAINTED creep. Separate from _anim_phase because it advances
## with the creep's own speed — a slowed one steps slower, a swarmling scurries, a tank
## plods — while the effects above must keep their own steady rate.
var _walk_phase: float = 0.0
## Which pose of the walk cycle is on screen. Swaps at each footfall, and swapping is the
## one thing in the walk that costs a redraw — twice a stride, against a transform every
## frame, which is the right way round.
var _frame: int = 0
## +1 while walking the way the art is drawn (screen-left), -1 while walking the other way.
## Painted creeps are drawn facing ONE direction and mirrored for the other, because the road
## is a spiral and a creep meets every heading on it. Folded into `_body.scale` alongside the
## breathing wobble, so turning around costs a transform rather than a redraw.
var _facing: float = 1.0
var _body: Node2D             ## Mid layer: body + eyes; scaled for the breathing wobble.
var _overlay: Node2D          ## Top layer: rings, markers, crown, health bar.

## Seconds an enemy must go undamaged before regen_dps starts healing it again lives in
## the Balance autoload (Balance.REGEN_DELAY), along with the flyer / splitter modifiers
## this file applies. This is what stops regen from being a hard DPS threshold: while you
## keep hitting it, it heals nothing, so falling slightly short of the break-even rate no
## longer means the enemy is simply unkillable.

# Status effects applied by tower projectiles.
var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _poison_dps: float = 0.0
var _poison_time: float = 0.0
var _stun_time: float = 0.0
var _regen_block: float = 0.0  ## Counts down after damage; regen is paused while > 0.
var _flash: float = 0.0        ## 1 -> 0 white pop after a direct hit.

# --- Layer repaint helpers -----------------------------------------------------
# Each guards against being called before _ready() has built the layers (make_flying is
# invoked before the enemy is added to the tree), so no call site needs to know the order.

func _repaint_body() -> void:
	if _body != null:
		_body.queue_redraw()

func _repaint_overlay() -> void:
	if _overlay != null:
		_overlay.queue_redraw()

func _repaint_all() -> void:
	queue_redraw()
	_repaint_body()
	_repaint_overlay()

## White pop confirming a projectile connected. Deliberately NOT driven from
## take_damage(): poison ticks go through there every single frame, which would leave a
## poisoned enemy permanently lit instead of flashing on impacts. Repaints the body now so
## the pop shows this frame regardless of process order relative to the firing projectile.
func flash() -> void:
	_flash = 1.0
	_repaint_body()

## Slows to `factor` of base speed for `time` seconds. Strongest slow wins.
func apply_slow(factor: float, time: float) -> void:
	if cc_immune:
		return
	_slow_factor = minf(_slow_factor, factor)
	_slow_time = maxf(_slow_time, time)
	_repaint_overlay()

## Freezes the enemy in place for `time` seconds (longest stun wins).
func apply_stun(time: float) -> void:
	if cc_immune:
		return
	_stun_time = maxf(_stun_time, time)
	_repaint_overlay()

## Deals `dps` damage per second for `time` seconds. Strongest poison wins.
## Deliberately NOT gated on cc_immune: that flag means crowd-control immunity, and
## poison is damage rather than control. This is what keeps Nature / Ice / Lava useful
## against Immune waves instead of leaving most of the roster with no effect at all.
func apply_poison(dps: float, time: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_time = maxf(_poison_time, time)
	_repaint_overlay()

## Sets how far along the path this enemy starts (used for split children).
func set_progress(index: int) -> void:
	_target_index = index

## How far along the road this enemy is, in pixels (higher = closer to the exit).
## Drives the First / Last tower targeting modes.
func progress() -> float:
	return Game.path_progress(_target_index, global_position)

## False once this enemy has died or escaped. queue_free() only takes effect at the
## end of the frame, so towers holding a target reference must check this rather than
## is_instance_valid() alone — otherwise they spend a shot on a corpse.
func is_alive() -> bool:
	return not _dead

func setup(hp: float, spd: float, gold_reward: int, tint: Color) -> void:
	max_health = hp
	health = hp
	speed = spd
	reward = gold_reward
	color = tint

## Turns this enemy into a flyer: squishier and faster, with a pale airborne
## tint. Only archer towers (can_hit_flying) can target it.
func make_flying() -> void:
	is_flying = true
	max_health *= Balance.FLYER_HP_MULT
	health = max_health
	speed *= Balance.FLYER_SPEED_MULT
	color = Balance.FLYER_TINT
	_repaint_all()  # shadow<->wings on the parent, tint on the body

func _ready() -> void:
	add_to_group("enemies")
	_path = Game.active_path
	global_position = _path[0]
	# Mid + top draw layers. Added body-first so within this enemy they stack shadow (this
	# node) -> body -> overlay, matching the old single-node draw order.
	var body := EnemyLayer.new()
	body.draw_fn = _draw_body
	add_child(body)
	_body = body
	var overlay := EnemyLayer.new()
	overlay.draw_fn = _draw_overlay
	add_child(overlay)
	_overlay = overlay
	_repaint_all()

func _process(delta: float) -> void:
	if _dead:
		return
	_anim_phase += delta * 3.0
	_animate_body(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 7.0)
		_body.queue_redraw()  # the impact pop fades on the body layer
	# Continuous animation is the exception, not the rule: wings flap while flying (parent
	# layer), stun sparks spin and the regen pulse breathes while active (overlay layer).
	# Everything else repaints only on a state change, so a plain walking enemy — which is
	# most of them, most of the time — asks for zero redraws here.
	if is_flying:
		_wing_phase += delta * 10.0
		queue_redraw()
	if _stun_time > 0.0 or (regen_dps > 0.0 and _regen_block <= 0.0 and health < max_health):
		_overlay.queue_redraw()
	_tick_status(delta)
	if _dead:
		return  # poison may have killed it this frame
	_move(delta)

## Moves the body layer. Pure transform — position, rotation and scale — so none of this
## costs a redraw no matter how busy the wave is.
##
## The blob keeps the breathing wobble it was designed around. A painted creep must NOT have
## it: squashing a standing figure vertically reads as inflating, not as breathing, which is
## the one thing a ball never looked like. It gets a stride or a wingbeat instead.
##
## This is deliberately not limb animation, which one image cannot have. It is the CARRIER
## motion under the pose, and it is what makes a two-pose sprite read as moving under its own
## power rather than as a picture sliding along the road. It also has to hold up a creep with
## only ONE pose, which is why each branch below carries a fake it can drop when a second pose
## arrives.
func _animate_body(delta: float) -> void:
	if Sprites.enemy(kind) == null:
		var br := sin(_anim_phase)
		_body.scale = Vector2(_facing * (1.0 + 0.05 * br), 1.0 - 0.05 * br)
		return
	if is_flying:
		_animate_flight()
	else:
		_animate_walk(delta)

## Wingbeat. Driven by `_wing_phase`, which ticks at a FIXED rate — a dragon does not beat its
## wings slower because a frost tower slowed it, and it has no ground speed to derive a rhythm
## from in the first place. That is the whole reason this is not the walk below.
func _animate_flight() -> void:
	var beat := _wing_phase
	var poses := Sprites.pose_count(kind)
	# ONE beat per TAU — wings up at 0, fully down at PI, back up at TAU. That matters beyond
	# taste: _set_frame cuts the same TAU into however many frames were painted, so a six-frame
	# sheet drawn as one down-and-up stroke lines up with this and nothing else does. (The walk
	# below is the other case: TWO footfalls per TAU, which is why it uses abs().)
	var stroke := 0.5 - 0.5 * cos(beat)  # 0 wings up, 1 wings down
	# The creature climbs on the downstroke and settles between beats. This starts at ZERO on
	# purpose: `_overlay` is a SIBLING of `_body` and is never moved, so every pixel of lift is
	# a pixel of drift between the creature and its own health bar, status rings and crown. A
	# constant hover added to it is drift that never comes back.
	var lift: float = stroke * radius * FLIGHT_LIFT_PER_RADIUS
	# Wing sweep, faked out of the silhouette: narrow and tall with the wings up, wide and flat
	# with them down. On a ONE-POSE dragon this is the entire flap; it steps back as real
	# frames arrive, because the art is then doing the work and leaving the fake at full
	# strength makes the whole creature pump.
	var sweep := (stroke - 0.5) * 2.0 / float(maxi(poses, 1))
	var sx := 1.0 + 0.10 * sweep
	var sy := 1.0 - 0.05 * sweep
	# _body scales and rotates about its ORIGIN, which is the sprite's ground anchor — on a
	# creature painted mid-flight that is its dangling feet, so scaling there swings the head
	# around. Put the pivot back in the middle of the drawn figure, where a body pivots.
	var pivot := _head_y() * 0.5
	# Quarter-cycle ahead of the bank below, so the sway and the roll do not peak together —
	# in phase they read as one wobble rather than as a creature riding its own wingbeat.
	var side_sway := cos(beat * 0.5) * radius * 0.03 * _facing
	_body.position = Vector2(side_sway, -lift + pivot * (1.0 - sy))
	_body.rotation = sin(beat * 0.5) * 0.05 * _facing  # slow bank, so the beat is not a metronome
	_body.scale = Vector2(_facing * sx, sy)
	_set_frame(beat, poses)

## Stride. Two footfalls per cycle, at a rate taken from the creep's own speed over its own
## size: a swarmling scurries, a tank plods, and anything slowed visibly labours.
##
## The carrier is deliberately BIG here. The two ground poses differ only slightly — the legs
## are not cleanly swapped — so the swap alone reads as a twitch; the hop, the lean and the
## rock are what turn it into a run, and they cost nothing because they are all transform.
func _animate_walk(delta: float) -> void:
	# Bounded so a stun (speed 0 through _slow_factor) does not freeze the creep mid-air and a
	# late-wave sprinter does not blur.
	var walk_speed: float = speed * _slow_factor
	if _stun_time > 0.0:
		walk_speed = 0.0
	var rate := clampf(walk_speed / maxf(radius, 1.0) * 1.6, 0.0, 14.0)
	_walk_phase += delta * rate
	# abs(sin) raised to <1 gives a snappier push-off and a longer hang than the bare curve —
	# which is most of the difference between a walk and a run.
	var bounce := pow(absf(sin(_walk_phase)), 0.7)
	var hop: float = bounce * radius * WALK_HOP_PER_RADIUS
	# A runner leans into the run, and how far is how hard it is running FOR ITS SIZE — so a
	# tank stays upright and a swarmling pitches forward, off the same expression.
	var lean: float = clampf(rate / 14.0, 0.0, 1.0) * 0.13
	# `_facing` is +1 walking screen-left, the way the art is drawn. Node2D applies rotation
	# outside the mirror scale, so without this factor the lean would point backwards on the
	# return leg of the spiral.
	_body.rotation = (sin(_walk_phase * 0.5) * 0.05 + sin(_walk_phase) * 0.03 - lean) * _facing
	# Landing squash. The warning above — that squashing a standing figure reads as inflating —
	# is about a CONTINUOUS wobble; this one is pinned to the bottom of the hop, so it lands
	# with the foot and is gone by the top. Kept under 3% for the same reason.
	var squash := (1.0 - bounce) * WALK_SQUASH
	# No lateral shift here: `_visual_dx()` centres the health bar off the TEXTURE anchor and
	# cannot see a transform, so sliding the body sideways slides it out from under its bar.
	_body.position = Vector2(0.0, -hop)
	_body.scale = Vector2(_facing * (1.0 + squash), 1.0 - squash)
	_set_frame(_walk_phase, Sprites.pose_count(kind))

## Picks the pose for a point in the cycle and swaps it if it changed. The one thing in either
## cycle that costs a redraw — n times per cycle, against a transform every frame, which is
## the right way round. A no-op on an archetype painted once, since Sprites.enemy() hands back
## the same texture for every frame.
##
## The cycle is one TAU of `phase` however many frames there are, so the creature covers its
## stride in the same time whether it was painted twice or six times — only the smoothness
## changes. Both carriers are built on that: the walk's two footfalls are the two humps of
## `abs(sin(phase))` across that same TAU, and the wingbeat's two strokes likewise, so frame 1
## always lands on a footfall no matter how many frames sit between them.
func _set_frame(phase: float, poses: int) -> void:
	if poses < 2:
		return
	var f := int(fposmod(phase, TAU) / (TAU / float(poses)))
	if f != _frame:
		_frame = f
		_repaint_body()

## Advances slow / poison timers and applies poison damage over time.
func _tick_status(delta: float) -> void:
	if _regen_block > 0.0:
		_regen_block -= delta
		if _regen_block <= 0.0:
			_repaint_overlay()  # un-dim the regen marker
	elif regen_dps > 0.0 and health < max_health:
		health = minf(max_health, health + regen_dps * delta)
	if _stun_time > 0.0:
		_stun_time -= delta
		if _stun_time <= 0.0:
			_repaint_overlay()
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			_repaint_overlay()
	if _poison_time > 0.0:
		_poison_time -= delta
		take_damage(_poison_dps * delta)
		if _poison_time <= 0.0:
			_poison_dps = 0.0
			_repaint_overlay()

func _move(delta: float) -> void:
	if _stun_time > 0.0:
		return  # frozen in place
	var remaining := speed * _slow_factor * delta
	# A smoothed road has short adjacent legs. Consume the whole frame's travel across as
	# many of them as necessary; stopping after one leg capped fast enemies to one waypoint
	# per frame and made motion depend on frame rate / the 1x–3x speed setting.
	while remaining > 0.0 and _target_index < _path.size():
		var target: Vector2 = _path[_target_index]
		var to_target := target - global_position
		var distance := to_target.length()
		# Turn to face the current leg, with a dead zone for nearly vertical traced steps.
		if absf(to_target.x) > 2.0:
			var face := -1.0 if to_target.x > 0.0 else 1.0
			if face != _facing:
				_facing = face
				_repaint_overlay()
		if distance <= remaining:
			global_position = target
			_target_index += 1
			remaining -= distance
		else:
			global_position += to_target / distance * remaining
			remaining = 0.0
	if _target_index >= _path.size():
		_escape()

func take_damage(amount: float) -> void:
	if _dead:
		return
	_regen_block = Balance.REGEN_DELAY  # any hit — including a poison tick — suspends regen
	health -= amount
	_repaint_overlay()  # health bar + regen marker live on the overlay
	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	Audio.play("boss_death" if is_boss else "enemy_death", 0.1)
	# Spawn the visuals before the queue_free() below — they read the tree through `self`.
	DeathBurst.spawn(self, global_position, color, radius)
	FloatingText.spawn(self, global_position + Vector2(0, -radius),
			"+%d" % reward, Color(1, 0.85, 0.35), 13)
	if is_boss:
		Game.request_shake(Balance.SHAKE_BOSS_DEATH)
	# The per-kill bonus is added HERE rather than inside Game.add_gold, which also pays the
	# sell refund, the wave interest and the early-call bonus — none of which is a kill.
	Game.add_gold(reward + Run.bonus_gold_per_kill())
	# Splitters break into smaller children that continue from here. Emit BEFORE
	# `removed` so WaveManager adds them to the alive count first (no early clear).
	if split_into > 0:
		split_requested.emit(global_position, _target_index, split_into,
				max_health * Balance.SPLIT_HP_MULT, speed * Balance.SPLIT_SPEED_MULT,
				color, radius * Balance.SPLIT_RADIUS_MULT)
	removed.emit()
	queue_free()

func _escape() -> void:
	_dead = true
	Audio.play("leak")
	Game.request_shake(Balance.SHAKE_LEAK)  # a leak should be felt, not just seen in the HUD
	Game.lose_life(life_cost)
	removed.emit()
	queue_free()

## Under-layer (this node): the flat ground shadow, or the flyer's shadow and — where there is
## no art — its wings. Static for a ground enemy (drawn once); repainted each frame while
## flying, which is what lets the shadow breathe with the wingbeat.
func _draw() -> void:
	if is_flying:
		# The shadow is what says "this one is above the road". It breathes against the beat:
		# tight and faint at the top of the climb, wide and dark as the creature settles. That
		# contrary motion is what reads as ALTITUDE — the lift alone could just as well be a
		# creep drawn a bit higher up, and a still frame cannot tell the two apart.
		var drop := 0.5 + 0.5 * cos(_wing_phase)  # 1 at the top of the stroke, when it flies lowest
		draw_set_transform(Vector2(0, radius + 15.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, radius * (0.58 + 0.16 * drop),
				Color(0, 0, 0, 0.12 + 0.09 * drop))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_flight_streaks(drop)
		if Sprites.enemy(kind) == null:
			_draw_wings()
	else:
		# Flat ground shadow. A painted figure is hung by its feet at radius*0.22 below the
		# walked point; putting its shadow at the blob's old radius*0.85 left a visible gap
		# and made every ground runner look airborne.
		var ground_y := radius * 0.22 if Sprites.enemy(kind) != null else radius * 0.85
		draw_set_transform(Vector2(0, ground_y), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_element_ring()

## Pale air strokes trailing BEHIND a flyer. The painted Air creature currently has one pose,
## so its transform supplies the wingbeat; these arcs make that beat unmistakable at game zoom
## without drawing a second pair of wings over the sprite.
##
## Three things here are not free choices:
##
##   * They hang at a fraction of `_head_y()`, not of `radius`. `radius` is the creep's SIZE
##     and a painted figure stands 2.6 radii tall, so a streak placed off `radius` lands at its
##     ankles — beside the feet of a creature whose wings are 30px higher up.
##   * ONE side, mirrored by `_facing`. Drawn on both sides they are symmetric, and a symmetric
##     speed line carries no direction at all: half of it sits in front of the creature it is
##     supposed to be trailing. `_facing` is +1 while the creep moves screen-left (the way the
##     art is drawn), so behind it is +x — and this is the parent canvas, which the `_body`
##     mirror does NOT reach, so the flip has to be applied here by hand.
##   * Nothing while stunned. `_wing_phase` ticks at a fixed rate no matter what, which is
##     right for a wingbeat and wrong for a streak that claims the creature is moving.
func _draw_flight_streaks(drop: float) -> void:
	if _stun_time > 0.0:
		return
	# Measured at game zoom, not guessed: the 0.10-0.26 this arrived with is invisible against
	# a sunlit board — the strokes had to be drawn in magenta at 0.85 to confirm they existed
	# at all. This is the range that reads as moving air without competing with the creature.
	var speed_alpha := 0.20 + absf(sin(_wing_phase)) * 0.18
	var streak_color := Color(0.78, 0.90, 1.0, speed_alpha)
	var span := radius * (1.25 + drop * 0.32)
	# Bulge AWAY from the creature, so the stroke trails off rather than cupping it.
	var base_angle: float = 0.0 if _facing > 0.0 else PI
	for i in range(2):
		var arc_radius := radius * (0.44 + float(i) * 0.22)
		var y := _head_y() * (0.45 + float(i) * 0.22)
		draw_arc(Vector2(span * _facing, y), arc_radius,
				base_angle - PI * 0.45, base_angle + PI * 0.45,
				8, streak_color, 2.0, true)

## The armour element, as a ring on the ground the creep stands in.
##
## The blob wore its element as body colour, which a painted creep cannot do without losing
## the painting. The matchup still has to be answerable at a glance — it decides which tower
## does 1.75x and which does 0.7x — so it moves to the one place around a creep that carries
## no art: the ground. Drawn under everything, and only for elemental waves; neutral ones
## stay clean.
func _draw_element_ring() -> void:
	if armor_element == "" or Sprites.enemy(kind) == null:
		return
	var ec: Color = Game.ELEMENT_COLORS.get(armor_element, Color.WHITE)
	draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.15, Color(ec.r, ec.g, ec.b, 0.30))
	draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 20, Color(ec.r, ec.g, ec.b, 0.85), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Mid layer: the body itself, drawn onto the `_body` canvas item `ci`. Drawn at rest — the
## breathing wobble is `_body.scale`, set in _process — so this only repaints on an impact
## flash or a colour change (make_flying).
func _draw_body(ci: CanvasItem) -> void:
	# Painted creep if this archetype has been drawn; the blob below is the fallback, and it
	# is what the board still looks like everywhere the art has not landed.
	var art := Sprites.enemy(kind, _frame)
	if art != null:
		_draw_sprite(ci, art)
		return
	# Body with a soft top-left highlight for volume.
	ci.draw_circle(Vector2.ZERO, radius, color)
	var hl := color.lightened(0.25)
	ci.draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.55, Color(hl.r, hl.g, hl.b, 0.55))
	ci.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.55), 2.0, true)
	# Impact pop, over the body but under the eyes so it reads as the whole blob lighting up.
	if _flash > 0.0:
		ci.draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.55 * _flash))
	# Eyes give the blobs a bit of character. Derived from `radius` rather than fixed
	# pixels: archetypes scale the body from 0.8x to 1.35x, and a boss is bigger again,
	# so hardcoded eyes drift to the wrong size and spacing on everything but a Normal.
	var eye := Vector2(radius * 0.31, -radius * 0.19)
	ci.draw_circle(Vector2(-eye.x, eye.y), radius * 0.16, Color.WHITE)
	ci.draw_circle(eye, radius * 0.16, Color.WHITE)
	ci.draw_circle(Vector2(-eye.x, eye.y), radius * 0.075, Color.BLACK)
	ci.draw_circle(eye, radius * 0.075, Color.BLACK)

## Hangs the painted creep off its ground anchor, so its feet stand on the point that walks
## the road — the same rule the towers use, and for the same reason: centring the sprite
## would sink a tall creature's legs and float a short one.
##
## The archetype's colour is deliberately NOT applied to the art. The blob was tinted per
## archetype and per armour element because a coloured circle is all the identity it had; a
## painted creep carries its own, and multiplying a tint over it turns a colour scheme into
## mud. The element instead reads from the ring drawn on the ground beneath it (see _draw).
func _draw_sprite(ci: CanvasItem, art: Texture2D) -> void:
	var size := art.get_size()
	# Hung and scaled off the FIRST frame, not this one — one anchor and one scale for the
	# whole cycle. A cycle is cut on a single window with its frames bottom-aligned inside it
	# (cut_sprites.py `shared_boxes`), precisely so this is possible: measuring each frame
	# separately hangs the creature by whatever happens to be lowest in it, which on the frame
	# where the trailing leg reaches back is that boot, and the goblin jumps forward once per
	# stride. `figure_height` rather than the file height, because the window is as tall as the
	# LONGEST frame and the empty band above the head in the others is the bounce itself.
	var first := Sprites.enemy(kind, 0)
	var anchor := Sprites.anchor(first)
	var scale := (radius * SPRITE_HEIGHT_PER_RADIUS) / Sprites.figure_height(first)
	var where := Rect2(Vector2(-anchor.x * scale, -anchor.y * scale), size * scale)
	# Feet a little below the walked point, so the creep stands ON the road rather than
	# behind it — the towers get the same nudge, scaled here because creeps vary in size.
	where.position.y += radius * 0.22
	ci.draw_texture_rect(art, where, false)
	# Impact pop. Over-bright modulate washes every lit pixel of the sprite towards white,
	# which is the painted equivalent of the white circle the blob flashes: it lights up the
	# creep's own shape instead of stamping a ball over it.
	if _flash > 0.0:
		var w := 5.0 * _flash
		ci.draw_texture_rect(art, where, false, Color(w, w, w, 1.0))

## Y of the top of whatever is actually drawn: the blob's crown at -radius, or the painted
## creep's head, which stands far higher than that.
##
## The overlay used to hang the health bar and the crown off `radius`, which is the enemy's
## SIZE but not its HEIGHT — true of a ball and false of a figure standing on its feet. A
## painted scout reaches 2.6 radii up, so a bar 20px above -radius was drawn across its
## chest. Everything that sits "above the head" reads this instead.
func _head_y() -> float:
	if Sprites.enemy(kind) == null:
		return -radius
	return -(radius * SPRITE_HEIGHT_PER_RADIUS - radius * 0.22)

## X of the middle of the drawn creep, which is not the middle of its feet.
##
## A sprite is hung by its ground anchor, and these figures lean: a running skirmisher's
## body is well ahead of the foot it is pushing off. Centring the health bar on the anchor
## therefore hangs it off to one side of the creature it belongs to. Mirrored with the
## facing, since the lean mirrors with it.
func _visual_dx() -> float:
	var art := Sprites.enemy(kind, 0)
	if art == null:
		return 0.0
	# Same anchor and same scale the sprite itself is drawn with — see _draw_sprite. On a
	# cycle this is the middle of the shared window, which is the middle of everywhere the
	# creature goes across its stride, and is what the overlay should sit over.
	var size := art.get_size()
	var scale := (radius * SPRITE_HEIGHT_PER_RADIUS) / Sprites.figure_height(art)
	return (size.x * 0.5 - Sprites.anchor(art).x) * scale * _facing

## Middle of the drawn creature, which the status rings are struck around.
##
## Same mistake the health bar made, one layer down: the rings were centred on the node's
## origin at `radius`, which is the blob's own outline and, on a painted creep, a hoop round
## its ankles — the cc-immune ring came out threaded through the legs with half of it sunk
## into the road. A ring says "this CREATURE is slowed / immune / burning", so it follows the
## figure that is drawn, not the point that walks.
func _ring_center() -> Vector2:
	if Sprites.enemy(kind) == null:
		return Vector2.ZERO
	return Vector2(_visual_dx(), _head_y() * 0.5)

## Radius those rings are struck at. A painted figure is far taller than it is wide, so this
## is a fraction of its drawn height rather than half of it: half would hoop it at arm's
## length and read as a spell effect on the ground rather than a mark on the creature.
func _ring_radius() -> float:
	if Sprites.enemy(kind) == null:
		return radius
	return radius * SPRITE_HEIGHT_PER_RADIUS * 0.32

## Top layer: status rings, archetype/regen markers, boss crown, and the health bar, drawn
## onto the `_overlay` canvas item `ci`. Sits over the body (rings hug just outside the body
## radius; crown + regen "+" sit over it).
func _draw_overlay(ci: CanvasItem) -> void:
	# Status rings: blue = slowed, green = poisoned. Concentric, so several at once stay
	# countable; see _ring_center for why they are not struck around the origin.
	var mid := _ring_center()
	var rr := _ring_radius()
	# Drawn FIRST of everything on this layer, so the status rings, the crown and the health
	# bar all stay legible on top of it.
	if cc_immune:
		_draw_ward(ci, mid, rr)
	if _slow_time > 0.0:
		ci.draw_arc(mid, rr + 4.0, 0.0, TAU, 22, Color(0.4, 0.7, 1.0, 0.85), 3.0, true)
	if _poison_time > 0.0:
		ci.draw_arc(mid, rr + 9.0, 0.0, TAU, 22, Color(0.45, 0.9, 0.35, 0.8), 3.0, true)
	if _stun_time > 0.0:
		# Yellow ring with spinning "stunned" sparks.
		ci.draw_arc(mid, rr + 13.0, 0.0, TAU, 22, Color(1.0, 0.95, 0.3, 0.9), 3.0, true)
		for i in range(3):
			var a := _anim_phase * 4.0 + i * TAU / 3.0
			ci.draw_circle(mid + Vector2(cos(a), sin(a)) * (rr + 13.0), 3.9, Color(1.0, 0.95, 0.45))
	# Archetype markers so wave types read at a glance. (The cc_immune ward is drawn at the
	# top of this function, under everything else.)
	if regen_dps > 0.0:
		# Bright "+" and a pulsing ring only while it is actually healing; dim otherwise.
		# This makes "my damage is stopping the heal" unmistakable at a glance.
		var healing := _regen_block <= 0.0 and health < max_health
		var g := Color(0.5, 1.0, 0.55, 1.0 if healing else 0.3)
		var p := mid + Vector2(rr * 0.55, -rr * 0.55)
		ci.draw_line(p + Vector2(-4.5, 0), p + Vector2(4.5, 0), g, 3.0)
		ci.draw_line(p + Vector2(0, -4.5), p + Vector2(0, 4.5), g, 3.0)
		if healing:
			var pulse: float = 0.5 + 0.5 * sin(_anim_phase * 3.0)
			ci.draw_arc(mid, rr + 18.0 + pulse * 4.5, 0.0, TAU, 24,
					Color(0.45, 1.0, 0.5, 0.30 + 0.45 * pulse), 3.0, true)
	if is_boss:
		_draw_crown(ci)

	# Health bar above the head (scales with body size so bosses read clearly).
	var bar_w := radius * 2.2
	var bar_h := 7.0
	# 20px above whatever the top of this creep is — the gap the blob has always had, kept
	# the same for a painted one so the unpainted archetypes do not shift.
	var top := Vector2(_visual_dx() - bar_w * 0.5, _head_y() - 20.0)
	ci.draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0.15, 0.05, 0.05))
	var ratio: float = clamp(health / max_health, 0.0, 1.0)
	var hp_col := Color(0.30, 0.85, 0.30)
	if ratio < 0.3:
		hp_col = Color(0.90, 0.45, 0.20)
	ci.draw_rect(Rect2(top, Vector2(bar_w * ratio, bar_h)), hp_col)
	ci.draw_rect(Rect2(top, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5), false, 1.0)

## Gold crown sitting on a boss's head, drawn onto the overlay canvas item `ci`.
func _draw_crown(ci: CanvasItem) -> void:
	var gold := Color(1.0, 0.82, 0.2)
	var y := _head_y() + 3.0
	var wd := radius * 0.9
	var dx := _visual_dx()
	ci.draw_rect(Rect2(dx - wd, y, wd * 2.0, 7.0), gold)
	for i in range(3):
		var cx := dx - wd + wd * i
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 9, y), Vector2(cx + 9, y), Vector2(cx, y - 16),
		]), gold)
		ci.draw_circle(Vector2(cx, y - 16.0), 3.3, Color(0.9, 0.2, 0.2))  # gem tip
	ci.draw_rect(Rect2(dx - wd, y, wd * 2.0, 7.0), Color(0, 0, 0, 0.3), false, 1.5)

## The cc-immune marker: a pale daylight sphere with the creep standing INSIDE it.
##
## It was a hard steel hoop struck around the body, which said "immune" clearly enough and
## drew a 4px opaque line straight across the creature to do it. A ward is a thing you are
## inside, so it is one here: barely-there glass, brightening towards its rim the way a glass
## ball does, with the highlight up and to the left where the board's sun is. The creep is
## read THROUGH it rather than across it, and at this alpha it never competes with the sprite.
##
## Sized off the creep's own drawn height, so a boss and a swarmling each get a ward that
## contains them.
func _draw_ward(ci: CanvasItem, mid: Vector2, rr: float) -> void:
	var r := rr * 1.75  # comfortably past the head and the feet of a 2.6-radii figure
	var glow := Color(1.0, 0.97, 0.86)
	ci.draw_circle(mid, r, Color(glow.r, glow.g, glow.b, 0.07))
	# Limb brightening: three arcs hugging the edge, each fainter as it moves inward. This is
	# what separates a sphere from a flat disc without costing a shader or a texture.
	for i in range(3):
		var t := float(i) / 2.0
		ci.draw_arc(mid, r - (1.0 - t) * r * 0.09, 0.0, TAU, 32,
				Color(glow.r, glow.g, glow.b, 0.05 + 0.14 * t), 2.0, true)
	ci.draw_circle(mid + Vector2(-r * 0.34, -r * 0.40), r * 0.20, Color(1, 1, 1, 0.09))

## Flapping wings, drawn behind the blob for a flyer that has no art yet.
##
## Only Air flies now, and the Air sprite is painted mid-flight with its wings spread — so on
## a normal board these are never drawn. They are the fallback the whole art layer is built
## on: delete `air.png` and the wave has to still read as flying, which a plain tinted circle
## does not. Nothing else needs them, because nothing else leaves the ground.
func _draw_wings() -> void:
	var flap: float = sin(_wing_phase) * 9.0
	var wing_col := Color(0.90, 0.93, 1.0, 0.9)
	var left := PackedVector2Array([
		Vector2(-radius * 0.4, -3.0),
		Vector2(-radius - 18.0, -12.0 - flap),
		Vector2(-radius - 9.0, 6.0),
	])
	var right := PackedVector2Array([
		Vector2(radius * 0.4, -3.0),
		Vector2(radius + 18.0, -12.0 - flap),
		Vector2(radius + 9.0, 6.0),
	])
	draw_colored_polygon(left, wing_col)
	draw_colored_polygon(right, wing_col)
