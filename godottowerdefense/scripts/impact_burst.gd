extends Node2D
## The short elemental animation a bolt makes where it lands. The four base towers each have
## their own material response; fusion and chaos shots retain the generic tinted burst.
## Pooled by Effects.
##
## This was `fire_impact.gd`, and it was fire's alone because Fire was the first element
## painted and the only one whose shot did not simply cease to exist on the frame damage was
## applied. Every other element's hit was a floating number and nothing else — a Water bolt
## crossed the board and then was not there any more. A later tinted version fixed that
## absence but still made every material behave like the same circular explosion. Base
## elements now branch by style while that tintable burst remains the fusion fallback.
##
## Three knobs keep the fire look byte-for-byte where it matters and give the rest something
## quieter: `scale`, because a hit that fires four times a second should not stamp the same
## bloom a fireball does; `gravity`, because embers falling out of the burst read as
## burning debris and are wrong for a splash of water; and `shards`, which swaps the ember
## spray for the counter-rotating splinters Infernal, Rainbow and Pure throw. That last one is
## not decoration — see the call site in projectile.gd for why chaos, alone among the
## payloads, has nothing else on the board saying it happened.
##
## The palette is DERIVED from one colour rather than passed in five parts. Fire's
## hand-tuned constants sat within a few hundredths of `darkened`/`lightened` steps off its
## core, so keeping five colours per caller bought nothing.

const LIFETIME := 0.32
const EMBERS := 10

var pool: Node = null
var _age: float = 0.0
var _lifetime: float = LIFETIME
var _color: Color = Color(1.0, 0.43, 0.035)
var _scale: float = 1.0
var _gravity: float = 0.0
var _shards: bool = false
var _style: String = "generic"
var _angles: PackedFloat32Array = PackedFloat32Array()
static var _effects: Node = null

## Spawns one in the level's Effects layer, drawn from the pool. `ctx` is any node in the
## tree. `scale` sizes the whole burst against Fire's original (1.0), and `gravity` is how
## far the embers sag over the burst's life, in px — 0 for anything that is not on fire.
static func spawn(ctx: Node, pos: Vector2, color: Color, scale: float = 1.0,
		gravity: float = 0.0, shards: bool = false, style: String = "generic") -> void:
	if not is_instance_valid(_effects):
		_effects = ctx.get_tree().current_scene.get_node_or_null("Effects")
		if _effects == null:
			return
	var impact = _effects.acquire_impact()
	impact.global_position = pos
	impact.setup(color, scale, gravity, shards, style)

func setup(color: Color, scale: float, gravity: float, shards: bool = false,
		style: String = "generic") -> void:
	_age = 0.0
	_color = color
	_scale = scale
	_gravity = gravity
	_shards = shards
	_style = style
	match style:
		"water": _lifetime = 0.38
		"nature": _lifetime = 0.46
		"earth": _lifetime = 0.40
		"clay", "steam", "well": _lifetime = 0.44
		"lava", "sun": _lifetime = 0.40
		"roots": _lifetime = 0.52
		"dinosaur", "flesh_golem": _lifetime = 0.46
		"infernal", "rainbow", "pure": _lifetime = 0.48
		_: _lifetime = LIFETIME
	_angles.resize(EMBERS)
	for i in EMBERS:
		_angles[i] = TAU * i / EMBERS + randf_range(-0.18, 0.18)
	queue_redraw()

func _recycle() -> void:
	if pool != null:
		pool.recycle_impact(self)
	else:
		queue_free()

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		_recycle()
		return
	queue_redraw()

func _draw() -> void:
	match _style:
		"fire": _draw_fire()
		"water": _draw_water()
		"nature": _draw_nature()
		"earth": _draw_earth()
		"clay": _draw_clay()
		"lava": _draw_lava()
		"sun": _draw_sun()
		"steam": _draw_steam()
		"well": _draw_well()
		"roots": _draw_roots()
		"dinosaur": _draw_dinosaur()
		"flesh_golem": _draw_flesh_golem()
		"infernal": _draw_infernal()
		"rainbow": _draw_rainbow()
		"pure": _draw_pure()
		_: _draw_generic()

## The fallback used by fusion and chaos shots. Base elements deliberately do not come
## through here: merely tinting this one radial bloom was what made four different towers
## feel as if they fired the same projectile.
func _draw_generic() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var glow := _color.darkened(0.25)
	# Two different lightenings on purpose. The CENTRE is the blown-out heart of the flash
	# and goes most of the way to white; the sparks keep their element's colour, because at
	# the fire palette's 0.72 a Water hit threw a spray of near-white dots that read as grey
	# gravel bouncing off the road.
	var hot := _color.lightened(0.70)
	var spark := _color.lightened(0.12)
	var smoke := _color.darkened(0.68)
	var core_radius := lerpf(7.0, 25.0, sin(p * PI)) * _scale
	draw_circle(Vector2.ZERO, core_radius * 1.45,
			Color(glow.r, glow.g, glow.b, 0.18 * fade))
	draw_circle(Vector2.ZERO, core_radius,
			Color(_color.r, _color.g, _color.b, 0.76 * fade))
	draw_circle(Vector2(-2.0, -2.0) * _scale, core_radius * 0.48,
			Color(hot.r, hot.g, hot.b, 0.88 * fade))
	var ring_radius := lerpf(5.0, 34.0, p) * _scale
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 28,
			Color(smoke.r, smoke.g, smoke.b, 0.46 * fade), 3.5 * fade * _scale, true)
	for i in EMBERS:
		var a: float = _angles[i]
		var distance := lerpf(6.0, 42.0 + float(i % 3) * 5.0, p) * _scale
		# Flattened on y, so the burst sits on the ground plane the board is drawn in.
		var ember_pos := Vector2(cos(a), sin(a) * 0.72) * distance
		ember_pos.y += p * p * _gravity
		if not _shards:
			draw_circle(ember_pos, lerpf(3.0, 0.8, p) * _scale,
					Color(spark.r, spark.g, spark.b, 0.92 * fade))
			continue
		# Chaos: the same ten pieces, thrown as splinters that keep turning on their way out.
		# Turned OPPOSITE to the direction they fly, which is the whole reading — everything
		# else on the board that spins, spins with its motion.
		var turn := a - p * 6.0
		var size := lerpf(4.2, 1.0, p) * _scale
		draw_colored_polygon(PackedVector2Array([
			ember_pos + Vector2(0.0, -size * 0.8).rotated(turn),
			ember_pos + Vector2(size, 0.0).rotated(turn),
			ember_pos + Vector2(0.0, size * 0.8).rotated(turn),
		]), Color(spark.r, spark.g, spark.b, 0.92 * fade))

## Fire blooms upward: a white-hot flash, licking flame tongues and embers that sag as they
## cool. Its silhouette stays tall and ragged instead of becoming another perfect circle.
func _draw_fire() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var pulse := sin(p * PI)
	var hot := Color(1.0, 0.92, 0.52, 0.96 * fade)
	var orange := Color(1.0, 0.31, 0.025, 0.78 * fade)
	var red := Color(0.62, 0.055, 0.01, 0.52 * fade)
	draw_circle(Vector2.ZERO, lerpf(8.0, 31.0, pulse) * _scale,
			Color(1.0, 0.18, 0.01, 0.16 * fade))
	for i in 7:
		var a: float = _angles[i]
		var side := Vector2(cos(a), sin(a) * 0.62)
		var reach := lerpf(5.0, 28.0 + float(i % 3) * 5.0, p) * _scale
		var root := side * reach * 0.25
		var tip := side * reach + Vector2(0.0, -8.0 * pulse * _scale)
		var width := lerpf(7.0, 1.0, p) * _scale
		var normal := side.orthogonal().normalized() * width
		draw_colored_polygon(PackedVector2Array([root - normal, tip, root + normal]), red)
		draw_colored_polygon(PackedVector2Array([
			root - normal * 0.48, tip * 0.82, root + normal * 0.48,
		]), orange)
	draw_circle(Vector2(0.0, -2.0) * _scale, lerpf(8.0, 2.0, p) * _scale, hot)
	for i in EMBERS:
		var a: float = _angles[i]
		var distance := lerpf(8.0, 42.0 + float(i % 3) * 4.0, p) * _scale
		var ember := Vector2(cos(a), sin(a) * 0.58) * distance
		ember.y += p * p * _gravity
		draw_circle(ember, lerpf(2.8, 0.55, p) * _scale,
				Color(1.0, 0.58, 0.08, 0.95 * fade))

## Water collapses outward along the ground: two elliptical ripples and a crown of droplets
## thrown up from the contact point. There is no glowing radial core, which keeps it from
## reading as blue fire.
func _draw_water() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var c := _color
	var pale := c.lightened(0.62)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.48))
	var outer := lerpf(4.0, 43.0, p) * _scale
	draw_arc(Vector2.ZERO, outer, 0.0, TAU, 36,
			Color(pale.r, pale.g, pale.b, 0.82 * fade), 3.2 * fade * _scale, true)
	if p > 0.16:
		var inner_p := (p - 0.16) / 0.84
		draw_arc(Vector2.ZERO, lerpf(3.0, 29.0, inner_p) * _scale, 0.0, TAU, 30,
				Color(c.r, c.g, c.b, 0.46 * (1.0 - inner_p)), 2.0 * _scale, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A brief flattened contact sheet underneath the droplets.
	draw_circle(Vector2.ZERO, lerpf(11.0, 21.0, p) * _scale,
			Color(c.r, c.g, c.b, 0.24 * fade))
	for i in 8:
		var a: float = _angles[i]
		var lateral := cos(a) * lerpf(5.0, 35.0 + float(i % 2) * 5.0, p) * _scale
		var depth := sin(a) * 0.30 * lerpf(5.0, 28.0, p) * _scale
		var lift := sin(p * PI) * (15.0 + float(i % 3) * 5.0) * _scale
		var drop := Vector2(lateral, depth - lift)
		var rr := lerpf(3.5, 1.1, p) * _scale
		draw_circle(drop, rr, Color(pale.r, pale.g, pale.b, 0.92 * fade))

## Nature releases living matter rather than energy: leaves spiral away, pale spores hang
## behind them, and short vines curl over the ground. The motion is deliberately slow and
## organic beside Fire's snap and Water's ballistic splash.
func _draw_nature() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var c := _color
	var dark := c.darkened(0.48)
	var light := c.lightened(0.48)
	for arm in 4:
		var a := TAU * float(arm) / 4.0 + p * 0.65
		var points := PackedVector2Array()
		for j in 4:
			var t := float(j) / 3.0
			var reach := lerpf(4.0, 33.0, p) * t * _scale
			points.append(Vector2(cos(a + t * 0.42), sin(a + t * 0.42) * 0.68) * reach)
		draw_polyline(points, Color(dark.r, dark.g, dark.b, 0.66 * fade),
				lerpf(3.2, 1.0, p) * _scale, true)
	for i in 7:
		var a: float = _angles[i] + p * (1.6 if i % 2 == 0 else -1.3)
		var distance := lerpf(5.0, 38.0 + float(i % 3) * 3.0, p) * _scale
		var at := Vector2(cos(a), sin(a) * 0.68) * distance
		var leaf_len := lerpf(6.5, 3.0, p) * _scale
		var leaf_w := leaf_len * 0.42
		var facing := a + p * 3.0
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(leaf_len, 0.0).rotated(facing),
			at + Vector2(0.0, -leaf_w).rotated(facing),
			at + Vector2(-leaf_len, 0.0).rotated(facing),
			at + Vector2(0.0, leaf_w).rotated(facing),
		]), Color(c.r, c.g, c.b, 0.90 * fade))
		draw_circle(at * 0.72 + Vector2(0.0, -5.0 * p), lerpf(2.2, 0.7, p) * _scale,
				Color(light.r, light.g, light.b, 0.74 * fade))

## Earth hits as mass: cracks race across the ground first, angular chips tumble out, then a
## low dust cloud overtakes them. Nothing glows and every edge is hard.
func _draw_earth() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var c := _color
	var dark := c.darkened(0.58)
	var dust := c.lightened(0.22)
	# Cracks arrive early and stay put while the debris travels beyond them.
	var crack_p := minf(1.0, p * 4.0)
	for arm in 5:
		var a: float = _angles[arm]
		var reach := (20.0 + float(arm % 3) * 5.0) * crack_p * _scale
		var side := Vector2(cos(a), sin(a) * 0.54)
		var bend := side.orthogonal() * (3.0 if arm % 2 == 0 else -3.0) * _scale
		draw_polyline(PackedVector2Array([
			Vector2.ZERO, side * reach * 0.48 + bend, side * reach,
		]), Color(dark.r, dark.g, dark.b, 0.72 * fade), 2.0 * _scale, true)
	for i in 8:
		var a: float = _angles[i]
		var distance := lerpf(3.0, 38.0 + float(i % 3) * 5.0, p) * _scale
		var at := Vector2(cos(a), sin(a) * 0.56) * distance
		at.y -= sin(p * PI) * (10.0 + float(i % 2) * 5.0) * _scale
		var size := lerpf(5.0, 1.6, p) * _scale
		var turn := a + p * (4.0 + float(i % 3))
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(size, 0.0).rotated(turn),
			at + Vector2(-size * 0.55, -size * 0.72).rotated(turn),
			at + Vector2(-size * 0.72, size * 0.62).rotated(turn),
		]), Color(c.r, c.g, c.b, 0.92 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.46))
	draw_arc(Vector2.ZERO, lerpf(10.0, 48.0, p) * _scale, PI, TAU, 24,
			Color(dust.r, dust.g, dust.b, 0.38 * fade), 8.0 * fade * _scale, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Clay lands wet and heavy: a broad mud splat holds to the floor while drops peel upward.
func _draw_clay() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var mud := _color.darkened(0.34)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.48))
	for i in 7:
		var a: float = _angles[i]
		var at := Vector2(cos(a), sin(a)) * lerpf(4.0, 31.0 + float(i % 2) * 5.0, p) * _scale
		draw_circle(at, lerpf(8.0, 2.2, p) * _scale,
				Color(mud.r, mud.g, mud.b, 0.72 * fade))
	draw_circle(Vector2.ZERO, lerpf(12.0, 25.0, p) * _scale,
			Color(_color.r, _color.g, _color.b, 0.34 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 5:
		var a: float = _angles[i]
		var at := Vector2(cos(a), sin(a) * 0.46) * lerpf(5.0, 34.0, p) * _scale
		at.y -= sin(p * PI) * (9.0 + float(i % 2) * 5.0) * _scale
		draw_circle(at, lerpf(4.0, 1.0, p) * _scale,
				Color(_color.r, _color.g, _color.b, 0.82 * fade))

## Lava combines Earth's fracture with Fire's heat: a black crust splits open, molten lines
## flare through it, and hot chips keep burning as they fly.
func _draw_lava() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var pulse := sin(p * PI)
	draw_circle(Vector2.ZERO, lerpf(9.0, 34.0, pulse) * _scale,
			Color(1.0, 0.18, 0.015, 0.20 * fade))
	for i in 7:
		var a: float = _angles[i]
		var dir := Vector2(cos(a), sin(a) * 0.62)
		var at := dir * lerpf(5.0, 42.0 + float(i % 3) * 4.0, p) * _scale
		var size := lerpf(6.0, 1.4, p) * _scale
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(size, 0.0).rotated(a + p * 4.0),
			at + Vector2(-size, -size * 0.65).rotated(a + p * 4.0),
			at + Vector2(-size * 0.55, size * 0.72).rotated(a + p * 4.0),
		]), Color(0.16, 0.07, 0.05, 0.94 * fade))
		draw_circle(at * 0.88, lerpf(2.8, 0.6, p) * _scale,
				Color(1.0, 0.62, 0.10, 0.94 * fade))
		draw_line(Vector2.ZERO, dir * lerpf(8.0, 27.0, minf(1.0, p * 3.0)) * _scale,
				Color(1.0, 0.38, 0.04, 0.60 * fade), 2.2 * _scale)
	draw_circle(Vector2.ZERO, lerpf(8.0, 2.0, p) * _scale,
			Color(1.0, 0.88, 0.42, 0.96 * fade))

## Sun does not throw debris. It flashes as concentric light with long rotating rays, then
## leaves a soft halo instead of smoke or dust.
func _draw_sun() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var rays := 1.0 - absf(p * 2.0 - 1.0)
	for i in 12:
		var a := TAU * float(i) / 12.0 + p * 0.45
		var dir := Vector2(cos(a), sin(a))
		var length := (24.0 if i % 2 == 0 else 15.0) + rays * 20.0
		draw_line(dir * 7.0 * _scale, dir * length * _scale,
				Color(1.0, 0.82, 0.26, 0.72 * fade), lerpf(3.4, 1.0, p) * _scale)
	draw_circle(Vector2.ZERO, lerpf(10.0, 30.0, sin(p * PI)) * _scale,
			Color(1.0, 0.74, 0.14, 0.18 * fade))
	draw_circle(Vector2.ZERO, lerpf(9.0, 2.0, p) * _scale,
			Color(1.0, 1.0, 0.88, 0.96 * fade))
	draw_arc(Vector2.ZERO, lerpf(7.0, 43.0, p) * _scale, 0.0, TAU, 40,
			Color(1.0, 0.92, 0.50, 0.66 * fade), 2.4 * fade * _scale, true)

## Steam blooms into overlapping translucent curls. The cloud rises and separates instead
## of exploding radially, preserving the tower's rapid, low-weight identity.
func _draw_steam() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var pale := _color.lightened(0.64)
	for i in 8:
		var a: float = _angles[i]
		var drift := Vector2(cos(a) * 24.0, sin(a) * 10.0 - 18.0) * p * _scale
		var at := drift + Vector2(sin(p * 5.0 + float(i)) * 3.0, 0.0)
		var radius := lerpf(5.0, 15.0 + float(i % 3) * 2.0, p) * _scale
		draw_circle(at, radius, Color(pale.r, pale.g, pale.b, 0.19 * fade))
		draw_arc(at, radius * 0.78, -1.0, 2.4, 14,
				Color(1.0, 1.0, 1.0, 0.26 * fade), 1.4 * _scale, true)

## Well lands as an ordered spring: clean water rings carry four green motes outward while
## a bright droplet rebounds from the centre.
func _draw_well() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.50))
	for ring in 2:
		var rp := clampf((p - float(ring) * 0.15) / (1.0 - float(ring) * 0.15), 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(4.0, 40.0 - float(ring) * 9.0, rp) * _scale,
				0.0, TAU, 34, Color(_color.r, _color.g, _color.b, 0.68 * (1.0 - rp)),
				(3.0 - float(ring)) * _scale, true)
	draw_set_transform(Vector2.ZERO, p * 1.8, Vector2.ONE)
	for i in 4:
		var a := TAU * float(i) / 4.0
		var at := Vector2(cos(a), sin(a) * 0.62) * lerpf(7.0, 29.0, p) * _scale
		draw_circle(at, lerpf(3.4, 1.1, p) * _scale,
				Color(0.48, 1.0, 0.70, 0.84 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, -sin(p * PI) * 18.0) * _scale,
			lerpf(5.0, 1.5, p) * _scale, Color(0.82, 1.0, 1.0, 0.90 * fade))

## Roots visibly bind the point of impact: barbed vines grow out, curl back toward the
## target, and leave a tightening green ring that echoes the actual stun payload.
func _draw_roots() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var grow := minf(1.0, p * 2.8)
	var c := _color.lightened(0.16)
	for arm in 7:
		var a: float = _angles[arm]
		var dir := Vector2(cos(a), sin(a) * 0.62)
		var side := dir.orthogonal() * sin(p * 8.0 + float(arm)) * 5.0 * _scale
		var tip := dir * (29.0 + float(arm % 2) * 5.0) * grow * _scale
		draw_polyline(PackedVector2Array([Vector2.ZERO, tip * 0.55 + side, tip]),
				Color(c.r, c.g, c.b, 0.82 * fade), 3.0 * fade * _scale, true)
		var thorn := dir.orthogonal().normalized() * 4.0 * _scale
		draw_line(tip * 0.70, tip * 0.70 + thorn, Color(0.72, 0.92, 0.42, 0.70 * fade), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, lerpf(27.0, 16.0, p) * _scale, 0.0, TAU, 28,
			Color(0.54, 0.76, 0.28, 0.62 * fade), 2.8 * _scale, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Dinosaur's jaws finish the motion the projectile began: they snap shut around the hit
## while acidic saliva spatters past the target.
func _draw_dinosaur() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var gape := lerpf(15.0, 1.0, minf(1.0, p * 2.4)) * _scale
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-20.0 * _scale, s * gape), Vector2(21.0 * _scale, s * gape * 0.55),
			Vector2(12.0 * _scale, s * (gape + 7.0 * _scale)),
			Vector2(-14.0 * _scale, s * (gape + 5.0 * _scale)),
		]), Color(_color.r, _color.g, _color.b, 0.74 * fade))
		for tooth in 4:
			var x := -9.0 + float(tooth) * 8.0
			draw_line(Vector2(x, s * gape) * _scale,
					Vector2(x + 2.0, s * (gape - 4.0)) * _scale,
					Color(1.0, 0.96, 0.76, 0.86 * fade), 1.6 * _scale)
	for i in 6:
		var a: float = _angles[i]
		var at := Vector2(cos(a), sin(a) * 0.55) * lerpf(5.0, 39.0, p) * _scale
		draw_circle(at, lerpf(3.0, 0.8, p) * _scale,
				Color(0.52, 0.90, 0.20, 0.78 * fade))

## Flesh Golem hits with a living pulse: sinew stretches from the centre and the mass beats
## once before collapsing, distinct from both a magical flash and a conventional explosion.
func _draw_flesh_golem() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var beat := pow(sin(p * PI), 2.0)
	for i in 8:
		var a: float = _angles[i]
		var dir := Vector2(cos(a), sin(a) * 0.64)
		var tip := dir * lerpf(6.0, 34.0 + float(i % 3) * 4.0, p) * _scale
		var bend := dir.orthogonal() * sin(p * 7.0 + float(i)) * 5.0 * _scale
		draw_polyline(PackedVector2Array([Vector2.ZERO, tip * 0.55 + bend, tip]),
				Color(0.62, 0.10, 0.18, 0.72 * fade), 3.8 * fade * _scale, true)
	draw_circle(Vector2.ZERO, (9.0 + beat * 15.0) * _scale,
			Color(_color.r, _color.g, _color.b, 0.30 * fade))
	draw_circle(Vector2.ZERO, (5.0 + beat * 6.0) * _scale,
			Color(1.0, 0.68, 0.65, 0.70 * fade))

## Infernal collapses inward before throwing black shards outward. The reversed motion and
## hot cracks are its chaos tell, now unique instead of shared with Rainbow and Pure.
func _draw_infernal() -> void:
	var p := _age / _lifetime
	var fade := 1.0 - p
	var core := lerpf(20.0, 3.0, p) * _scale
	draw_circle(Vector2.ZERO, core * 1.6, Color(0.88, 0.08, 0.16, 0.20 * fade))
	draw_circle(Vector2.ZERO, core, Color(0.05, 0.01, 0.02, 0.92 * fade))
	for i in EMBERS:
		var a: float = _angles[i] - p * 2.5
		var dir := Vector2(cos(a), sin(a) * 0.66)
		var at := dir * lerpf(5.0, 47.0 + float(i % 3) * 4.0, p) * _scale
		var size := lerpf(6.0, 1.0, p) * _scale
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(size, 0.0).rotated(a),
			at + Vector2(-size, -size * 0.52).rotated(a),
			at + Vector2(-size, size * 0.52).rotated(a),
		]), Color(0.12, 0.015, 0.03, 0.94 * fade))
		draw_line(Vector2.ZERO, dir * 24.0 * minf(1.0, p * 4.0) * _scale,
				Color(1.0, 0.25, 0.16, 0.54 * fade), 1.5 * _scale)

## Rainbow refracts into six coloured arcs and motes. Its broad, clean spectrum is visually
## opposite Infernal's dark implosion even though both use the same damage rule.
func _draw_rainbow() -> void:
	const SPECTRUM: Array = [
		Color(1.0, 0.25, 0.28), Color(1.0, 0.65, 0.16), Color(0.96, 0.92, 0.24),
		Color(0.24, 0.90, 0.44), Color(0.24, 0.62, 1.0), Color(0.76, 0.34, 1.0),
	]
	var p := _age / _lifetime
	var fade := 1.0 - p
	for i in 6:
		var start := TAU * float(i) / 6.0 + p * 0.55
		var radius := lerpf(7.0, 42.0, p) * _scale
		draw_arc(Vector2.ZERO, radius, start, start + 0.72, 10,
				Color(SPECTRUM[i], 0.82 * fade), 4.0 * fade * _scale, true)
		var at := Vector2(cos(start + 0.72), sin(start + 0.72) * 0.72) * radius
		draw_circle(at, lerpf(3.8, 1.0, p) * _scale, Color(SPECTRUM[i], 0.92 * fade))
	draw_circle(Vector2.ZERO, lerpf(10.0, 2.0, p) * _scale,
			Color(1.0, 1.0, 1.0, 0.90 * fade))

## Pure resolves all four elements at once: a white diamond shockwave leads four coloured
## fragments, one for each base tower. It is precise and symmetric because nothing resists it.
func _draw_pure() -> void:
	const ELEMENT_COLORS: Array = [
		Color(0.28, 0.66, 1.0), Color(1.0, 0.34, 0.08),
		Color(0.30, 0.86, 0.38), Color(0.76, 0.58, 0.36),
	]
	var p := _age / _lifetime
	var fade := 1.0 - p
	draw_set_transform(Vector2.ZERO, p * 1.3, Vector2.ONE)
	var radius := lerpf(7.0, 46.0, p) * _scale
	var diamond := PackedVector2Array([
		Vector2(0.0, -radius), Vector2(radius, 0.0),
		Vector2(0.0, radius), Vector2(-radius, 0.0), Vector2(0.0, -radius),
	])
	draw_polyline(diamond, Color(1.0, 1.0, 0.96, 0.78 * fade),
			3.0 * fade * _scale, true)
	for i in 4:
		var a := TAU * float(i) / 4.0 - p * 0.8
		var at := Vector2(cos(a), sin(a) * 0.72) * radius * 0.82
		draw_circle(at, lerpf(4.8, 1.2, p) * _scale, Color(ELEMENT_COLORS[i], 0.90 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, lerpf(11.0, 2.0, p) * _scale,
			Color(1.0, 1.0, 1.0, 0.96 * fade))
