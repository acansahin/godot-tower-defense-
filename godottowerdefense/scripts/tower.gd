extends Node2D
class_name Tower
## Generic element tower, configured from a Game.TOWER_DEFS entry via setup_def().
## Fires a Projectile that applies whichever effects the definition sets (damage,
## splash, slow, poison). New tower types are just new data entries — no subclass.

const PROJECTILE := preload("res://scenes/Projectile.tscn")

var id: String = ""
var display_name: String = ""
var element: String = ""      ## Damage element for the matchup ("" = neutral).
var element_color: Color = Color.WHITE

var tower_range: float = 160.0
var fire_interval: float = 0.4
var damage: float = 8.0
var can_hit_flying: bool = true

# Effect payload passed to each projectile (0/1 defaults = "off").
var splash_radius: float = 0.0
var splash_factor: float = 0.5
var slow_factor: float = 1.0    ## < 1 slows; 1 = no slow.
var slow_time: float = 0.0
var poison_dps: float = 0.0
var poison_time: float = 0.0
var stun_chance: float = 0.0    ## chance (0..1) to freeze enemies on hit.
var stun_time: float = 0.0

## Upgrade state. setup_def() seeds build_cost / total_spent; upgrade() applies
## growth on top of the base stats.
var level: int = 1
var build_cost: int = 0
var total_spent: int = 0   ## Gold sunk into this tower (build + upgrades); half is refunded on sell.

const MAX_LEVEL := 3
const DAMAGE_GROWTH := 1.6   ## damage multiplier per level
const RANGE_GROWTH := 20.0   ## flat range added per level
const FIRE_SPEEDUP := 0.82   ## fire_interval multiplier per level (lower = faster)
const SELL_REFUND := 0.5     ## fraction of total_spent returned when sold

# Badge geometry (tower-local). The sell badge is tucked into the bottom-right corner —
# far from the body, so upgrading can't sell by accident. The upgrade hint is a slim
# arrow off to the LEFT, clear of the barrel: anything drawn on the body got run over by
# the barrel as it swung around to track targets.
const SELL_BADGE_POS := Vector2(22, 24)
const SELL_BADGE_R := 8.0
const UPGRADE_ARROW_X := -26.0  ## Left of the stone base (r=20), still inside the 64px cell.
const UPGRADE_CHEVRON_PERIOD := 1.4  ## Seconds for one chevron to drift up and fade out.

var _cooldown: float = 0.0
var _aim_dir: Vector2 = Vector2.UP  ## Barrel direction, eased toward the target.
var _recoil: float = 0.0            ## 1 → 0 kick after firing.
var _highlighted: bool = false      ## Hovered by the mouse: draw the range clearly.

## Turns the clear range indicator on/off (Main drives this from mouse hover). Only
## repaints on an actual change — an idle tower with no target never redraws on its
## own (see _process), so without this the ring would not appear until it fired.
func set_highlighted(value: bool) -> void:
	if _highlighted == value:
		return
	_highlighted = value
	queue_redraw()

## Configures this tower from a Game.TOWER_DEFS id. Call right after instantiate.
func setup_def(def_id: String) -> void:
	id = def_id
	var d: Dictionary = Game.TOWER_DEFS[def_id]
	display_name = d.get("name", def_id)
	element = d.get("element", "")
	element_color = d.get("color", Color.WHITE)
	damage = d.get("damage", 8.0)
	tower_range = d.get("range", 160.0)
	fire_interval = d.get("interval", 0.5)
	can_hit_flying = d.get("can_hit_flying", true)
	splash_radius = d.get("splash_radius", 0.0)
	splash_factor = d.get("splash_factor", 0.5)
	slow_factor = d.get("slow_factor", 1.0)
	slow_time = d.get("slow_time", 0.0)
	poison_dps = d.get("poison_dps", 0.0)
	poison_time = d.get("poison_time", 0.0)
	stun_chance = d.get("stun_chance", 0.0)
	stun_time = d.get("stun_time", 0.0)
	build_cost = d.get("cost", 40)
	total_spent = build_cost
	queue_redraw()

func can_upgrade() -> bool:
	return level < MAX_LEVEL

## True when the upgrade hint should be on screen: another level exists and it's affordable.
func _upgrade_ready() -> bool:
	return can_upgrade() and Game.gold >= upgrade_cost()

## Gold cost of the NEXT upgrade (build_cost x current level: e.g. 40, 80).
func upgrade_cost() -> int:
	return build_cost * level

func upgrade() -> void:
	if not can_upgrade():
		return
	total_spent += upgrade_cost()  # uses current level, before the increment below
	level += 1
	damage *= DAMAGE_GROWTH
	tower_range += RANGE_GROWTH
	fire_interval *= FIRE_SPEEDUP
	poison_dps *= DAMAGE_GROWTH  # DoT scales with the tower's damage growth
	queue_redraw()

## Gold returned when this tower is sold (half of everything sunk into it).
func sell_value() -> int:
	return int(total_spent * SELL_REFUND)

## True if a tower-local click landed on the sell (✕) badge. Kept tight so only a
## deliberate corner click sells.
func is_sell_hit(local_pos: Vector2) -> bool:
	return local_pos.distance_to(SELL_BADGE_POS) <= SELL_BADGE_R + 1.0

func _process(delta: float) -> void:
	var target := _find_target()
	# Ease the barrel toward the target every frame (independent of the cooldown).
	if target != null:
		var to := target.global_position - global_position
		if to.length() > 0.1:
			_aim_dir = Vector2.from_angle(lerp_angle(_aim_dir.angle(), to.angle(), 0.2))
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
	# An idle tower never repaints on its own, so the animated hint needs to ask for it.
	if target != null or _recoil > 0.0 or _upgrade_ready():
		queue_redraw()
	if _cooldown > 0.0:
		_cooldown -= delta
	elif target != null:
		_fire(target)
		_cooldown = fire_interval

func _find_target() -> Enemy:
	var best: Enemy = null
	var best_dist := tower_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null:
			continue
		if enemy.is_flying and not can_hit_flying:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d <= best_dist:
			best_dist = d
			best = enemy
	return best

## Container that new projectiles are added to (kept off the tower so they
## keep flying independently).
func _projectiles() -> Node:
	return get_tree().current_scene.get_node("Projectiles")

func _fire(target: Enemy) -> void:
	_recoil = 1.0
	Audio.play_tower_fire(id, element)
	var p := PROJECTILE.instantiate() as Projectile
	_projectiles().add_child(p)
	p.setup(global_position, target, damage)
	p.color = element_color
	p.element = element
	p.hits_flying = can_hit_flying
	p.splash_radius = splash_radius
	p.splash_factor = splash_factor
	p.slow_factor = slow_factor
	p.slow_time = slow_time
	p.poison_dps = poison_dps
	p.poison_time = poison_time
	p.stun_chance = stun_chance
	p.stun_time = stun_time

func _draw() -> void:
	# Range indicator in the element's colour: quiet by default so a full board stays
	# readable, clear while hovered so the player can judge coverage.
	var ec := element_color
	if _highlighted:
		draw_circle(Vector2.ZERO, tower_range, Color(ec.r, ec.g, ec.b, 0.07))
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 64, Color(ec.r, ec.g, ec.b, 0.50), 2.5, true)
	else:
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 48, Color(ec.r, ec.g, ec.b, 0.12), 2.0, true)
	# Flat drop shadow under the base.
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Layered stone base for depth.
	draw_circle(Vector2.ZERO, 20.0, Color(0.20, 0.19, 0.23))
	draw_circle(Vector2.ZERO, 15.0, Color(0.30, 0.28, 0.33))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, Color(0, 0, 0, 0.4), 1.5, true)
	# Drawn BEFORE the barrel: the badge sits at (0,-12) with r=12, exactly where the
	# barrel points when aiming up, and on top it hid the barrel completely — towers
	# firing at the upper road looked stubby. Underneath, its sides still read clearly.
	_draw_upgrade_badge()
	# Barrel + element orb, aimed at the target and kicked back while firing.
	var back := _aim_dir * (-_recoil * 4.0)
	var tip := _aim_dir * 24.0 + back
	draw_line(back, tip, Color(0.30, 0.28, 0.33), 10.0)
	draw_circle(tip, 15.0, Color(element_color.r, element_color.g, element_color.b, 0.28))  # glow
	draw_circle(tip, 11.0, element_color)
	draw_arc(tip, 11.0, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 2.0, true)
	draw_circle(tip + Vector2(-3, -3), 3.5, Color(1, 1, 1, 0.5))  # highlight
	# Element initial on the orb.
	var font := ThemeDB.fallback_font
	if font != null and display_name != "":
		draw_string(font, tip + Vector2(-5, 5), display_name.substr(0, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.08, 0.08, 0.10))
	_draw_level_pips(element_color.lightened(0.35))
	# Sell badge stays ON TOP: unlike the upgrade badge it is a click target, so it must
	# never end up hidden under the barrel.
	_draw_sell_badge()

## Upgrade hint, shown only while another level exists and is affordable: a slim green
## arrow bobbing gently to the tower's left, with the cost to its right. Clicking the
## tower anywhere upgrades it (see Main), so this is purely a signal — which is why it can
## sit off the body, clear of the swinging barrel.
func _draw_upgrade_badge() -> void:
	if not _upgrade_ready():
		return
	# A SHARED clock, not a per-tower timer: towers are built at different moments, so
	# per-tower phases drifted apart and a row of hints looked like scattered noise.
	# Off the engine clock every tower animates in lockstep.
	var t := Time.get_ticks_msec() / 1000.0
	# Two chevrons half a cycle apart, each drifting upward as it fades — reads as a soft
	# continuous "up" without anything snapping back to its start.
	for i in 2:
		var p := fposmod(t / UPGRADE_CHEVRON_PERIOD + i * 0.5, 1.0)
		_draw_chevron(Vector2(UPGRADE_ARROW_X, lerpf(6.0, -8.0, p)), sin(p * PI))
	var font := ThemeDB.fallback_font
	if font != null:
		# Steady (not animated) on the right, where it clears both the HUD bar and neighbours.
		draw_string(font, Vector2(16, -7), "%d g" % upgrade_cost(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.6))

## One soft chevron ("^") at `o`, faded to `alpha`. draw_line has no round-cap option, so
## dots at the ends and the apex do the rounding — that is what keeps it friendly rather
## than a hard triangle.
func _draw_chevron(o: Vector2, alpha: float) -> void:
	var col := Color(0.45, 1.0, 0.55, alpha)
	var edge := Color(0.0, 0.0, 0.0, 0.30 * alpha)
	var l := o + Vector2(-6.0, 4.0)
	var m := o + Vector2(0.0, -3.0)
	var r := o + Vector2(6.0, 4.0)
	# Dark silhouette underneath keeps it legible over light grass.
	draw_line(l, m, edge, 6.0, true)
	draw_line(m, r, edge, 6.0, true)
	draw_line(l, m, col, 3.5, true)
	draw_line(m, r, col, 3.5, true)
	for p in [l, m, r]:
		draw_circle(p, 1.75, col)

## Red ✕ badge (always shown) to sell the tower for half its invested gold; the
## refund amount is printed just below it.
func _draw_sell_badge() -> void:
	var c := SELL_BADGE_POS
	draw_circle(c, SELL_BADGE_R, Color(0.72, 0.16, 0.16))
	draw_arc(c, SELL_BADGE_R, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 2.0, true)
	var d := 3.5
	draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, 2.0)
	draw_line(c + Vector2(-d, d), c + Vector2(d, -d), Color.WHITE, 2.0)
	var font := ThemeDB.fallback_font
	if font != null:
		# Refund printed to the left of the badge.
		draw_string(font, Vector2(-34, c.y + 4), "+%d g" % sell_value(),
				HORIZONTAL_ALIGNMENT_RIGHT, 46, 13, Color(1, 0.85, 0.4))

## Small dots under the tower base, one per level, so the player can read the
## current upgrade tier at a glance. Called from each subclass's _draw().
func _draw_level_pips(col: Color) -> void:
	var spacing := 8.0
	var start_x := -(level - 1) * spacing * 0.5
	for i in level:
		var c := Vector2(start_x + i * spacing, 6.0)
		draw_circle(c, 2.6, col)
		draw_arc(c, 2.6, 0.0, TAU, 12, Color(0, 0, 0, 0.5), 1.0, true)
