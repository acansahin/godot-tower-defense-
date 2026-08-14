extends Node2D
class_name Tower
## Generic element tower, configured from a Game.TOWER_DEFS entry via setup_def().
## Fires a Projectile that applies whichever effects the definition sets (damage,
## splash, slow, poison). New tower types are just new data entries — no subclass.
##
## Stats are never accumulated in place: _recompute() rebuilds them from the definition
## plus the level every time either changes, so a run-scoped modifier can be added and
## removed without the tower drifting.
##
## What a tower DOES with its frame lives behind TowerBehavior (see tower_behavior.gd) —
## every tower today uses BoltBehavior, and an element that needs a structurally different
## attack gets a new behavior rather than a branch in here.

## Targeting is fixed to the enemy closest to the exit ("First"): that is what actually
## protects your lives — a nearly-escaped leader matters more than whatever wandered past
## the muzzle. There is no per-tower target picker (clicking a tower upgrades it instead).

var id: String = ""
var display_name: String = ""
var element: String = ""      ## Damage element for the matchup ("" = neutral).
var element_color: Color = Color.WHITE

var tower_range: float = 240.0
var fire_interval: float = 0.4
var damage: float = 8.0
var can_hit_flying: bool = true

# Effect payload passed to each projectile (0/1 defaults = "off").
var splash_radius: float = 0.0
var splash_factor: float = 0.5
var slow_factor: float = 1.0    ## < 1 slows; 1 = no slow.
var slow_time: float = 0.0
var slow_splash_radius: float = 0.0  ## Active radius the slow ALSO spreads to (0 = single target); enabled from Lv2.
var poison_dps: float = 0.0
var poison_time: float = 0.0
var stun_chance: float = 0.0    ## chance (0..1) to freeze enemies on hit.
var stun_time: float = 0.0

## The Game.TOWER_DEFS entry this tower was built from. Read-only (TOWER_DEFS is a const
## Dictionary, so Godot rejects writes to it) and re-read on every _recompute() — it is
## the single source of truth for the tower's base stats.
var _def: Dictionary = {}

## Upgrade state. `level` is the ONLY upgrade state that exists: every stat above is
## derived from _def + level by _recompute(), never accumulated in place. That is what
## lets a run modifier be removed as cleanly as it was added.
var level: int = 1
var build_cost: int = 0
var total_spent: int = 0   ## Gold sunk into this tower (build + upgrades); half is refunded on sell.

# The upgrade curve itself (max level, damage/range/speed growth, sell refund) lives in
# the Balance autoload, not here — see scripts/balance.gd.

# Upgrade hint geometry (tower-local). A slim arrow off to the LEFT, clear of the
# barrel: anything drawn on the body got run over by the barrel as it swung around to
# track targets. The upgrade action is now a click on the tower itself, so this is purely
# a signal that the tower has an affordable level waiting.
const UPGRADE_ARROW_X := -38.0  ## Left of the stone base (r=30), still inside the 96px cell.
const UPGRADE_CHEVRON_PERIOD := 1.4  ## Seconds for one chevron to drift up and fade out.

# Sell button geometry (tower-local): a small red "×" tucked into the bottom-right corner
# of the cell. Tapping it sells the tower; tapping anywhere else on the tower upgrades it.
# Kept in the corner, clear of the barrel's swing and the level pips, and sized for touch.
const SELL_BTN_POS := Vector2(30.0, 28.0)  ## Bottom-right of the base, inside the 96px cell.
const SELL_BTN_RADIUS := 14.0              ## Drawn disc radius.
## Tap radius, deliberately well past the drawn disc. This is the smallest target in the
## game and it cannot get much bigger: it is a sub-region of a 96px cell, which is itself
## only ~48 CSS px once the board is stretched onto a phone. If mis-taps (sell instead of
## upgrade, or the reverse) prove annoying in play, the fix is a confirm step, not more px.
const SELL_BTN_HIT := 26.0

var _behavior: TowerBehavior = null  ## What this tower does with its frame; see tower_behavior.gd.
var _target: Enemy = null           ## Held between frames; see _find_target().
var _range_sq: float = 57600.0      ## tower_range² (240² default), cached for distance checks; setup_def/upgrade keep it in sync.
var _proj_pool: Node = null         ## Cached $Projectiles pool node; resolved once on first fire.
var _aim_dir: Vector2 = Vector2.UP  ## Barrel direction, eased toward the target.
var _recoil: float = 0.0            ## 1 → 0 kick after firing.
var _was_upgrade_ready: bool = false  ## Last frame's _upgrade_ready(); the badge redraws only when this flips.
var _highlighted: bool = false      ## Hovered by the mouse: draw the range clearly.

func _ready() -> void:
	# A card picked mid-run has to reach towers that are already standing. Re-resolving is
	# safe at any moment because _recompute() rebuilds from the definition rather than
	# editing the current values.
	Run.modifiers_changed.connect(_on_modifiers_changed)

func _on_modifiers_changed() -> void:
	# Guard against firing before setup_def(): Run.reset() emits during its own _ready, and
	# a tower whose _def is still empty would resolve every stat to its fallback.
	if _def.is_empty():
		return
	_recompute()
	queue_redraw()

## Turns the clear range indicator on/off (Main drives this from mouse hover). Only
## repaints on an actual change — an idle tower with no target never redraws on its
## own (see _process), so without this the ring would not appear until it fired.
func set_highlighted(value: bool) -> void:
	if _highlighted == value:
		return
	_highlighted = value
	queue_redraw()

## True when `world_pos` lands on the sell "×" (bottom-right corner). Main tests this on a
## click to decide sell vs. upgrade. No rotation/scale on the tower, so world = pos + local.
func is_sell_hit(world_pos: Vector2) -> bool:
	return world_pos.distance_to(global_position + SELL_BTN_POS) <= SELL_BTN_HIT

## Configures this tower from a Game.TOWER_DEFS id. Call right after instantiate.
func setup_def(def_id: String) -> void:
	id = def_id
	_def = Game.TOWER_DEFS[def_id]
	# Identity + things that never scale with level.
	display_name = _def.get("name", def_id)
	element = _def.get("element", "")
	element_color = _def.get("color", Color.WHITE)
	can_hit_flying = _def.get("can_hit_flying", true)
	build_cost = _def.get("cost", 40)
	total_spent = build_cost
	_behavior = _make_behavior(String(_def.get("behavior", "bolt")))
	level = 1
	_recompute()
	queue_redraw()

## Builds the behavior named by a def's optional "behavior" key. This match is the only
## place a behavior name is spelled out, and it selects a strategy at CONSTRUCTION time —
## it is not a per-frame branch on tower type, which is what the rest of the code avoids.
## Every def today omits the key and so gets a bolt turret.
static func _make_behavior(kind: String) -> TowerBehavior:
	match kind:
		_: return BoltBehavior.new()

func can_upgrade() -> bool:
	return level < Balance.MAX_LEVEL

## True when the upgrade hint should be on screen: another level exists and it's affordable.
func _upgrade_ready() -> bool:
	return can_upgrade() and Game.gold >= upgrade_cost()

## Gold cost of the NEXT upgrade (build_cost x current level: e.g. 40, 80).
func upgrade_cost() -> int:
	return Balance.upgrade_cost(build_cost, level)

func upgrade() -> void:
	if not can_upgrade():
		return
	total_spent += upgrade_cost()  # uses current level, before the increment below
	level += 1
	_recompute()
	queue_redraw()

## Rebuilds every scaling stat from `_def` and `level`. Nothing is mutated in place, so
## the base stats are never lost — which is what will let a run-scoped modifier be added
## AND removed later without the tower drifting. Runs on build and on upgrade, never per
## frame.
##
## The level growth is a repeated multiply rather than pow(): it reproduces the exact
## floating-point result of the old destructive upgrade() chain, so this refactor is
## provably number-for-number identical. It runs at most twice.
func _recompute() -> void:
	# --- base: straight from the definition ------------------------------------
	damage = _def.get("damage", 8.0)
	tower_range = _def.get("range", 160.0)
	fire_interval = _def.get("interval", 0.5)
	poison_dps = _def.get("poison_dps", 0.0)
	poison_time = _def.get("poison_time", 0.0)
	splash_radius = _def.get("splash_radius", 0.0)
	splash_factor = _def.get("splash_factor", 0.5)
	slow_factor = _def.get("slow_factor", 1.0)
	slow_time = _def.get("slow_time", 0.0)
	stun_chance = _def.get("stun_chance", 0.0)
	stun_time = _def.get("stun_time", 0.0)
	# --- level growth ----------------------------------------------------------
	for _i in level - 1:
		damage *= Balance.DAMAGE_GROWTH
		tower_range += Balance.RANGE_GROWTH
		fire_interval *= Balance.FIRE_SPEEDUP
		poison_dps *= Balance.DAMAGE_GROWTH  # DoT scales with the tower's damage growth
	# Ice's area-slow: single-target below Lv2, then widening (was _update_slow_splash).
	slow_splash_radius = 0.0
	if level >= 2:
		slow_splash_radius = float(_def.get("slow_splash", 0.0)) \
				* (1.0 + Balance.SLOW_SPLASH_GROWTH * float(level - 2))
	# --- run modifiers ---------------------------------------------------------
	# The payoff for rebuilding rather than accumulating: these are applied fresh every
	# time, so a modifier can be added — or, later, removed — without the tower drifting.
	var m := Run.mods_for(id, element)
	damage = (damage + m.damage_add) * m.damage_mult
	tower_range = (tower_range + m.range_add) * m.range_mult
	# Divided, never multiplied by (1 - pct) — see TowerMods.attack_speed_mult.
	fire_interval /= m.attack_speed_mult
	# Poison rides the damage multiplier as well as its own, matching how it already rides
	# the per-level damage growth.
	poison_dps = poison_dps * m.damage_mult * m.poison_mult
	splash_radius *= m.splash_mult
	# Scales the SLOW, not the speed: doubling a 0.55 factor would make enemies faster.
	slow_factor = clampf(1.0 - (1.0 - slow_factor) * m.slow_power, 0.05, 1.0)
	# --- derived ---------------------------------------------------------------
	# Floored so a future stack of attack-speed modifiers can never drive the interval to
	# zero, which would make _process fire on every single frame.
	fire_interval = maxf(Balance.MIN_FIRE_INTERVAL, fire_interval)
	_range_sq = tower_range * tower_range

## Gold returned when this tower is sold (half of everything sunk into it).
func sell_value() -> int:
	return int(total_spent * Balance.SELL_REFUND)

func _process(delta: float) -> void:
	# A behavior with no notion of a target (an aura, an economy building) skips the scan
	# entirely rather than paying for one and discarding it.
	var target: Enemy = _find_target() if _behavior.wants_target() else null
	# Ease the barrel toward the target every frame (independent of the cooldown).
	if target != null:
		var to := target.global_position - global_position
		if to.length() > 0.1:
			_aim_dir = Vector2.from_angle(lerp_angle(_aim_dir.angle(), to.angle(), 0.2))
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
	# An idle tower never repaints on its own, so the animated hint needs to ask for it.
	# The `ready != _was_upgrade_ready` term gives a single repaint when affordability
	# flips (gold spent/earned) so the affordable-upgrade hint clears/appears on its own.
	# Every term here assumes a turret that tracks a target, so a behavior that animates
	# without one gets its own say via wants_redraw().
	var up_ready := _upgrade_ready()
	if target != null or _recoil > 0.0 or up_ready or up_ready != _was_upgrade_ready \
			or _behavior.wants_redraw():
		queue_redraw()
	_was_upgrade_ready = up_ready
	_behavior.tick(self, delta, target)

## Picks this frame's target. Deliberately sticky: while the current one is still
## valid the tower keeps it, which stops the barrel twitching between equally-good
## enemies AND skips the scan on most frames. When a scan IS needed it goes through
## EnemyIndex (a shared per-frame spatial hash), so it inspects only enemies near this
## tower rather than the whole group — what used to be an O(enemies)-per-tower cost.
func _find_target() -> Enemy:
	# is_instance_valid() must be tested out here rather than inside _is_targetable:
	# once the held enemy is freed, the typed `enemy: Enemy` parameter check rejects it
	# and raises before the function body could ever guard against it.
	if is_instance_valid(_target) and _is_targetable(_target):
		return _target
	var best: Enemy = null
	var best_score := -INF
	# Only enemies in cells overlapping our range, not the whole group (see enemy_index.gd).
	for e in EnemyIndex.query(global_position, tower_range):
		var enemy := e as Enemy
		if not _is_targetable(enemy):
			continue
		# "First": rank by how far along the path the enemy is — closest to the exit wins.
		var score := enemy.progress()
		if score > best_score:
			best_score = score
			best = enemy
	_target = best
	return best

## True if `enemy` is still alive, in range, and not a flyer this tower cannot reach.
## Callers must have already ruled out freed instances (see _find_target).
func _is_targetable(enemy: Enemy) -> bool:
	if enemy == null or not enemy.is_alive():
		return false
	if enemy.is_flying and not can_hit_flying:
		return false
	return global_position.distance_squared_to(enemy.global_position) <= _range_sq

## Launches one homing bolt at `target` with this tower's full effect payload. Public
## because BoltBehavior drives it; any future behavior that wants a projectile reuses it
## rather than duplicating the payload stamping below.
func fire_bolt(target: Enemy) -> void:
	_recoil = 1.0
	Audio.play_tower_fire(id, element)
	# Pull a bolt from the shared $Projectiles pool instead of instantiating one per shot;
	# the pool keeps it parented off the tower so it flies independently (see projectiles.gd).
	if not is_instance_valid(_proj_pool):
		_proj_pool = get_tree().current_scene.get_node("Projectiles")
	var p := _proj_pool.acquire() as Projectile
	p.setup(global_position, target, damage)
	p.color = element_color
	p.element = element
	p.hits_flying = can_hit_flying
	p.splash_radius = splash_radius
	p.splash_factor = splash_factor
	p.slow_factor = slow_factor
	p.slow_time = slow_time
	p.slow_splash_radius = slow_splash_radius
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
	draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 27.0, Color(0, 0, 0, 0.20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Layered stone base for depth.
	draw_circle(Vector2.ZERO, 30.0, Color(0.20, 0.19, 0.23))
	draw_circle(Vector2.ZERO, 22.0, Color(0.30, 0.28, 0.33))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, Color(0, 0, 0, 0.4), 2.0, true)
	# Drawn BEFORE the barrel: the badge sits where the barrel points when aiming up,
	# and on top it hid the barrel completely — towers firing at the upper road looked
	# stubby. Underneath, its sides still read clearly.
	_draw_upgrade_badge()
	# The moving part is the behavior's: a bolt turret draws a barrel, an aura would draw
	# something else entirely. Everything above and below is common to every tower.
	_behavior.draw_turret(self)
	_draw_level_pips(element_color.lightened(0.35))
	# Drawn last so it stays tappable even when the barrel swings over the corner.
	_draw_sell_button()

## The classic turret: barrel + element orb, aimed at the target and kicked back while
## firing. Public because BoltBehavior draws it; kept here rather than in the behavior
## because it reads a lot of tower state (aim, recoil, element colour, name).
func draw_barrel() -> void:
	var back := _aim_dir * (-_recoil * 6.0)
	var tip := _aim_dir * 36.0 + back
	draw_line(back, tip, Color(0.30, 0.28, 0.33), 15.0)
	draw_circle(tip, 22.0, Color(element_color.r, element_color.g, element_color.b, 0.28))  # glow
	draw_circle(tip, 16.0, element_color)
	draw_arc(tip, 16.0, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 3.0, true)
	draw_circle(tip + Vector2(-4, -4), 5.0, Color(1, 1, 1, 0.5))  # highlight
	# Muzzle flash on the handful of frames right after firing. _recoil already decays
	# 1 -> 0 for the barrel kick, so this rides along for free.
	if _recoil > 0.55:
		var flash: float = (_recoil - 0.55) / 0.45
		draw_circle(tip, 22.0 + 16.0 * flash, Color(1, 1, 1, 0.35 * flash))
	# Element initial on the orb.
	var font := ThemeDB.fallback_font
	if font != null and display_name != "":
		draw_string(font, tip + Vector2(-7, 7), display_name.substr(0, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.08, 0.08, 0.10))

## Small red "×" at the bottom-right corner: the sell control. A tap here sells the tower
## (Main routes it via is_sell_hit); a tap anywhere else on the tower upgrades it.
func _draw_sell_button() -> void:
	var c := SELL_BTN_POS
	draw_circle(c, SELL_BTN_RADIUS, Color(0.70, 0.16, 0.16, 0.95))
	draw_arc(c, SELL_BTN_RADIUS, 0.0, TAU, 16, Color(0, 0, 0, 0.45), 2.0, true)
	var s := 5.4
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(1, 1, 1, 0.95), 3.0, true)
	draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Color(1, 1, 1, 0.95), 3.0, true)

## Upgrade hint, shown only while another level exists and is affordable: a slim green
## arrow bobbing gently to the tower's left. Purely a signal — the upgrade action is a
## click on the tower itself, so nothing here is a click target and it can sit off the
## body, clear of the swinging barrel.
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
		_draw_chevron(Vector2(UPGRADE_ARROW_X, lerpf(9.0, -12.0, p)), sin(p * PI))

## One soft chevron ("^") at `o`, faded to `alpha`. draw_line has no round-cap option, so
## dots at the ends and the apex do the rounding — that is what keeps it friendly rather
## than a hard triangle.
func _draw_chevron(o: Vector2, alpha: float) -> void:
	var col := Color(0.45, 1.0, 0.55, alpha)
	var edge := Color(0.0, 0.0, 0.0, 0.30 * alpha)
	var l := o + Vector2(-9.0, 6.0)
	var m := o + Vector2(0.0, -4.5)
	var r := o + Vector2(9.0, 6.0)
	# Dark silhouette underneath keeps it legible over light grass.
	draw_line(l, m, edge, 9.0, true)
	draw_line(m, r, edge, 9.0, true)
	draw_line(l, m, col, 5.0, true)
	draw_line(m, r, col, 5.0, true)
	for p in [l, m, r]:
		draw_circle(p, 2.6, col)

## Small dots under the tower base, one per level, so the player can read the
## current upgrade tier at a glance.
func _draw_level_pips(col: Color) -> void:
	var spacing := 12.0
	var start_x := -(level - 1) * spacing * 0.5
	for i in level:
		var c := Vector2(start_x + i * spacing, 9.0)
		draw_circle(c, 4.0, col)
		draw_arc(c, 4.0, 0.0, TAU, 12, Color(0, 0, 0, 0.5), 1.5, true)
