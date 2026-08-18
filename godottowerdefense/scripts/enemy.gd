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
	_path = Game.PATH
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
## the one thing a ball never looked like. It gets a walk cycle instead — a hop at every
## footfall, and a slow roll of the shoulders across the stride.
##
## This is deliberately not limb animation, which one image cannot have. It is the carrier
## motion under the step, and it is what makes a two-pose sprite read as walking rather than
## as a picture sliding along the road.
func _animate_body(delta: float) -> void:
	if Sprites.enemy(kind) == null:
		var br := sin(_anim_phase)
		_body.scale = Vector2(_facing * (1.0 + 0.05 * br), 1.0 - 0.05 * br)
		return
	# Stride rate from the creep's own speed over its own size: a swarmling scurries, a tank
	# plods, and anything slowed visibly labours. Bounded so a stun (speed 0 through
	# _slow_factor) does not freeze mid-air and a late-wave sprinter does not blur.
	var walk_speed: float = speed * _slow_factor
	if _stun_time > 0.0:
		walk_speed = 0.0
	_walk_phase += delta * clampf(walk_speed / maxf(radius, 1.0) * 1.6, 0.0, 14.0)
	# abs(sin) — two footfalls per cycle, and the bounce never dips below the ground.
	var hop: float = absf(sin(_walk_phase)) * radius * 0.10
	_body.position = Vector2(0.0, -hop)
	_body.rotation = sin(_walk_phase * 0.5) * 0.05 * _facing
	_body.scale = Vector2(_facing, 1.0)
	# Opposite leg forward on every footfall, if this archetype has been painted twice.
	var f := int(_walk_phase / PI) % 2
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
	if _target_index >= _path.size():
		_escape()
		return
	var target: Vector2 = _path[_target_index]
	var to_target := target - global_position
	# Turn to face the way we are walking, with a dead zone: the traced road has plenty of
	# near-vertical steps, and flipping on their pixel of horizontal drift makes a creep
	# shimmy down the screen.
	if absf(to_target.x) > 2.0:
		var face := -1.0 if to_target.x > 0.0 else 1.0
		if face != _facing:
			_facing = face
			# The overlay hangs off _visual_dx(), which mirrors with the facing, and it
			# otherwise only repaints on a state change — so a creep that turned around
			# would wear its health bar on the wrong side until something hit it.
			_repaint_overlay()
	var step := speed * _slow_factor * delta
	if to_target.length() <= step:
		global_position = target
		_target_index += 1
	else:
		global_position += to_target.normalized() * step

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

## Under-layer (this node): the flat ground shadow, or the flyer's wings + shadow. Static
## for a ground enemy (drawn once); repainted each frame only while flying, for the flap.
func _draw() -> void:
	if is_flying:
		# The shadow is what says "this one is above the road", so every flyer keeps it.
		draw_circle(Vector2(0, radius + 15.0), radius * 0.7, Color(0, 0, 0, 0.18))
		if Sprites.enemy(kind) == null:
			_draw_wings()
	else:
		# Flat ground shadow.
		draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_element_ring()

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
	var anchor := Sprites.anchor(art)
	# Scale from the FIRST pose's height, not this one's. The poses of a walk cycle differ
	# in height — a leg reaching forward lowers the figure, which is the bob of the step —
	# and fitting each pose to the same drawn height would cancel exactly that, leaving a
	# creature that pulses in size instead of walking.
	var scale := (radius * SPRITE_HEIGHT_PER_RADIUS) / Sprites.enemy(kind, 0).get_size().y
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
	var art := Sprites.enemy(kind)
	if art == null:
		return 0.0
	var size := art.get_size()
	var scale := (radius * SPRITE_HEIGHT_PER_RADIUS) / size.y
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
	# Archetype markers so wave types read at a glance.
	if cc_immune:
		ci.draw_arc(mid, rr + 3.0, 0.0, TAU, 26, Color(0.78, 0.82, 0.9, 0.9), 4.0, true)
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
