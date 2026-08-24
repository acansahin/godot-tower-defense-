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
## every tower today uses BoltBehavior, and a tower that needs a structurally different
## attack gets a new behavior rather than a conditional in here.

## Targeting is fixed to the enemy closest to the exit ("First"): that is what actually
## protects your lives — a nearly-escaped leader matters more than whatever wandered past
## the muzzle. There is no per-tower target picker (clicking a tower opens its panel).

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
var execute_chance: float = 0.0      ## chance (0..1) to kill outright on hit; never bosses (Death).
var gold_on_kill: int = 0            ## extra gold when THIS tower lands the killing blow (Money).
var life_on_kill_chance: float = 0.0 ## chance (0..1) that a kill returns one life (Life).

# --- Damage-over-time and debuff payload ----------------------------------------
# Burn is a separate DoT channel from `poison_dps`/`poison_time` above, because burn STACKS
# and poison does not — see Enemy.apply_burn / apply_poison. Lava (Fire+Earth) is the fusion
# that carries it, on top of base Fire; the stacking, spreading, crack and knockback fields
# below have no producer in Game.FUSIONS today and are kept for the same reason
# execute_chance and gold_on_kill are: a payload the data may switch on.
var burn_dps: float = 0.0
var burn_time: float = 0.0
var burn_max_stacks: int = 1
var burn_spread_radius: float = 0.0   ## Burn also applies (at half power) within this radius.
var burn_doubles_at_max: bool = false ## Burn ticks 2x once stacked to burn_max_stacks.
var burn_spreads_on_death: bool = false  ## A burning death lights its neighbours.
var poison_ignores_matchup: bool = false ## Nature's THORN: poison bypasses Game.element_mult entirely.
var poison_spreads_on_death: bool = false  ## Poison passes to the nearest survivor on death.
var crack_bonus: float = 0.0          ## Armor crack: +this fraction of damage taken from ALL sources.
var crack_time: float = 0.0
var crack_spread_radius: float = 0.0  ## Crack also spreads within this radius.
var knockback_chance: float = 0.0     ## Chance per hit to push the target back.
var knockback_distance: float = 0.0
var knockback_chill_on_land: bool = false  ## Applies this tower's slow where the target lands.
var _shots_fired: int = 0             ## Counts toward overclock_every; never resets.
# --- Fusion payload -------------------------------------------------------------------
## Every element this tower carries, its own first, in the order they were absorbed. This
## IS the tower's identity: one entry means a base Game.TOWER_DEFS tower, two/three/four mean
## the matching Game.FUSIONS row. Never shrinks — absorbing an element is permanent, the same
## rule the branch choice it replaces had (GAME_STRATEGY_V2.md §4.6).
var elements: Array[String] = []
## Clay: chance (0..1) that a hit applies the slow at all. 1.0 = every hit, which is what
## every other slow in the game does and therefore the default.
var slow_chance: float = 1.0
## Chaos-type damage (Infernal, Rainbow, Pure): Game.element_mult_best is skipped and the
## matchup is a flat 1.0 — no armour resists it and none amplifies it either.
var ignores_matchup: bool = false
## Pure only: this tower's control payload ignores Enemy.cc_immune (the wave-10 boss and the
## `immune` archetype). Passed down to the projectile and on into apply_slow/stun/knockback.
var pierces_rules: bool = false
## Flesh Golem: permanent damage added per kill this tower lands. Accumulates in `_kills`,
## which is the ONE piece of tower state _recompute() reads but does not derive — it is a
## record of what happened, not a stat, so rebuilding from the definition cannot recover it.
var damage_per_kill: float = 0.0
var _kills: int = 0

# --- Run-wide modifiers, folded from Run.mods_for() in _recompute() --------------
# Everything below arrives through the fold rather than through the DEFINITION, which is
# what separates it from every field above: a fusion changes what this tower IS, while these
# apply to whole classes of tower at once. Only the Workshop writes them today.
var overclock_every: int = 0          ## Every Nth shot deals double damage.
var groundwork: bool = false          ## Ground-only towers hit flying, splash halved.
var target_lowest_hp: bool = false    ## Target lowest HP instead of furthest along.
var burn_slow_factor: float = 1.0     ## Burn also applies this slow (1.0 = off).
var chill_burn_mult: float = 1.0      ## This tower's burn vs a chilled target.
var chill_hit_mult: float = 1.0       ## This tower's direct hits vs a chilled target.
var vs_flying_mult: float = 1.0       ## Damage multiplier vs flying targets.

## The Game.TOWER_DEFS entry this tower was built from. Read-only (TOWER_DEFS is a const
## Dictionary, so Godot rejects writes to it) and re-read on every _recompute() — it is
## the single source of truth for the tower's base stats. Fields below Lv3 come straight from
## here for an unfused tower, and from Game.FUSIONS once it carries two or more elements.
var _def: Dictionary = {}
## A working copy of `_def` — see _recompute(). A real Dictionary (not just the instance
## fields above) so a NEIGHBOUR's aura reach can read this tower's CURRENT identity, which
## for Sun and Well is a fusion row rather than the base element they were built as.
var _eff: Dictionary = {}

## Upgrade state. `level` is the ONLY upgrade state that exists: every stat above is
## derived from _def + level by _recompute(), never accumulated in place. That is what
## lets a run modifier be removed as cleanly as it was added.
var level: int = 1
var build_cost: int = 0
var total_spent: int = 0   ## Gold sunk into this tower (build + upgrades); see sell_value().
## True once this tower has fired at least one shot. Drives the two-tier sell refund
## (GAME_STRATEGY_V2.md §9, BUILD NEXT #3): a placement mistake caught before the tower ever
## did anything is free to undo, one caught after is not. Set in fire_bolt(), never cleared —
## a tower does not get to re-earn the free refund by going a while without a target.
var has_fired: bool = false

# The upgrade curve itself (max level, damage/range/speed growth, sell refund) lives in
# the Balance autoload, not here — see scripts/balance.gd.

# Upgrade hint geometry (tower-local). A slim arrow off to the LEFT, clear of the
# barrel: anything drawn on the body got run over by the barrel as it swung around to
# track targets. The upgrade action is now a click on the tower itself, so this is purely
# a signal that the tower has an affordable level waiting.
const UPGRADE_ARROW_X := -38.0  ## Left of the stone base (r=30), still inside the 96px cell.
const UPGRADE_CHEVRON_PERIOD := 1.4  ## Seconds for one chevron to drift up and fade out.

# The sell "×" that used to sit in the bottom-right of the cell is GONE. It was a 26px tap
# target inside a 96px cell — roughly 13 CSS px once the board is stretched onto a phone, the
# smallest thing in the game and the only one that could not be made bigger. Selling now
# lives on the tower panel (tower_panel.gd) along with upgrading and fusing, which is also
# the only place with room to show what a fusion would cost and what it would produce.

var _behavior: TowerBehavior = null  ## What this tower does with its frame; see tower_behavior.gd.
var _target: Enemy = null           ## Held between frames; see _find_target().
var _range_sq: float = 57600.0      ## tower_range² (240² default), cached for distance checks; setup_def/upgrade keep it in sync.
var _proj_pool: Node = null         ## Cached $Projectiles pool node; resolved once on first fire.
var _aim_dir: Vector2 = Vector2.UP  ## Barrel direction, eased toward the target.
var _recoil: float = 0.0            ## 1 → 0 kick after firing.
var _was_upgrade_ready: bool = false  ## Last frame's _upgrade_ready(); the badge redraws only when this flips.
var _highlighted: bool = false      ## Hovered by the mouse: draw the range clearly.

func _ready() -> void:
	# Painted towers carry four to seven source pixels for every screen pixel they are drawn
	# at, and plain linear filtering samples ONE of them — which is why the sprites looked
	# crunchy rather than detailed. Mipmaps are generated on import; this is the half that
	# asks for them.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# A card picked mid-run has to reach towers that are already standing. Re-resolving is
	# safe at any moment because _recompute() rebuilds from the definition rather than
	# editing the current values.
	Run.modifiers_changed.connect(_on_modifiers_changed)
	# An aura tower appearing or vanishing next door changes this tower's stats, and the
	# only way to notice is to be told the set changed. Same handler: it just re-pulls.
	Game.towers_changed.connect(_on_modifiers_changed)

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

## Configures this tower from a Game.TOWER_DEFS id. Call right after instantiate.
func setup_def(def_id: String) -> void:
	id = def_id
	element = Game.TOWER_DEFS[def_id].get("element", "")
	elements = [element] as Array[String]
	build_cost = Game.TOWER_DEFS[def_id].get("cost", 40)
	total_spent = build_cost
	_behavior = _make_behavior(String(Game.TOWER_DEFS[def_id].get("behavior", "bolt")))
	level = 1
	_recompute()
	queue_redraw()

## Builds the behavior named by a def's optional "behavior" key. This match is the only
## place a behavior name is spelled out, and it selects a strategy at CONSTRUCTION time —
## it is not a per-frame branch on tower type, which is what the rest of the code avoids.
## Almost every def omits the key and so gets a bolt turret; Magic asks for "charge".
static func _make_behavior(kind: String) -> TowerBehavior:
	match kind:
		"charge": return ChargeBehavior.new()
		_: return BoltBehavior.new()

## Absorbs `new_element` for the rest of this tower's life, turning it into the combination
## its element set now names. Public, unlike _recompute(), because writing `elements`
## without refreshing would leave the tower showing its old identity's numbers.
##
## Caller (main.gd) is responsible for the gold and for checking available_elements() first;
## this guards only against a double-add, which would corrupt the fusion key.
func add_element(new_element: String) -> void:
	if new_element == "" or elements.has(new_element):
		return
	# Booked BEFORE the append, while fusion_cost() still reads the price of this step —
	# afterwards it would quote the next one. Keeps sell_value() honest about the whole road
	# the tower travelled, not just its build and upgrades.
	total_spent += fusion_cost()
	elements.append(new_element)
	_recompute()
	queue_redraw()

## Gold to absorb the NEXT element. Indexed by how many elements the tower already has, so a
## base tower (1) pays FUSION_COSTS[0], a dual (2) pays [1], a triple (3) pays [2].
func fusion_cost() -> int:
	var i := elements.size() - 1
	if i < 0 or i >= Balance.FUSION_COSTS.size():
		return 0
	return int(Balance.FUSION_COSTS[i])

## True while this tower can still absorb something: it is short of all four elements AND at
## least one of the ones it lacks has had its avatar boss beaten.
func can_fuse() -> bool:
	return not available_elements().is_empty()

## Elements this tower could absorb right now: unlocked by an avatar boss this run, and not
## already carried. Derived on every call rather than cached, for the same reason tower stats
## are — Run.unlocked_fusions grows mid-run and a cached list would go stale silently.
func available_elements() -> Array:
	var out: Array = []
	for e in Run.unlocked_fusions:
		if not elements.has(String(e)):
			out.append(String(e))
	return out

## The FUSIONS row this tower's element set names, or {} while it is still a base tower.
func fusion_def() -> Dictionary:
	return Game.fusion_def(elements)

## Counts a kill this tower landed, for Flesh Golem's permanent growth. A no-op (beyond the
## counter) for every other tower, so projectile.gd can call it unconditionally.
func note_kill() -> void:
	_kills += 1
	if damage_per_kill > 0.0:
		_recompute()
		queue_redraw()

func can_upgrade() -> bool:
	return level < Balance.MAX_LEVEL

## True when the upgrade hint should be on screen: another level exists and it's affordable.
func _upgrade_ready() -> bool:
	return can_upgrade() and Game.gold >= upgrade_cost()

## Gold cost of the NEXT upgrade. One shared ladder for every element (Balance.TIER_COSTS:
## 40/70/120/200 past the build cost), scaled by Foreman's -20% if taken (BUILD NEXT #9).
func upgrade_cost() -> int:
	return int(round(float(Balance.upgrade_cost(build_cost, level)) * Run.upgrade_cost_mult()))

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
## The level growth is a repeated multiply rather than pow(): the map's tiers are exact
## x5 steps (x10 into Pure) and multiplying step by step keeps the result byte-identical
## to the table in docs/element-td-data.md. It runs at most four times.
func _recompute() -> void:
	# --- which tower is this? ---------------------------------------------------
	# The element SET picks the definition outright: one element is a base Game.TOWER_DEFS
	# entry, two or more is the matching Game.FUSIONS row. This REPLACES the definition
	# rather than layering over it — a Steam tower is Steam, not "Fire wearing Water", which
	# is the map's own rule and what makes Fire+Water and Water+Fire the same tower.
	#
	# `_def` is re-read here rather than held from setup_def() precisely because it changes:
	# absorbing an element is the one thing that swaps a standing tower's definition.
	var fdef := Game.fusion_def(elements)
	_def = fdef if not fdef.is_empty() else Game.TOWER_DEFS[id]
	# Cached on the instance so OTHER towers' aura reads (below) see this tower's current
	# identity, not the base element it was built as.
	_eff = _def.duplicate(true)
	# Identity follows the definition, so a fusion renames the tower and recolours it. A
	# fused tower also climbs the map's own tier names as it levels (Steam -> Vapor ->
	# Immolation), which Game.fusion_name spreads across our five levels.
	display_name = Game.fusion_name(_def, level) if not fdef.is_empty() \
			else String(_def.get("name", id))
	element_color = _def.get("color", Color.WHITE)
	# --- base: straight from the effective definition ---------------------------
	damage = _eff.get("damage", 8.0)
	# TOWER_DEFS stores range in Warcraft III units; this is the one place (with main.gd's
	# build preview) that turns them into board pixels.
	tower_range = minf(_eff.get("range", 160.0) * Balance.WC3_RANGE_SCALE,
			Balance.MAX_TOWER_RANGE)
	fire_interval = _eff.get("interval", 0.5)
	poison_dps = _eff.get("poison_dps", 0.0)
	poison_time = _eff.get("poison_time", 0.0)
	poison_ignores_matchup = _eff.get("poison_ignores_matchup", false)
	poison_spreads_on_death = _eff.get("poison_spreads_on_death", false)
	burn_dps = _eff.get("burn_dps", 0.0)
	burn_time = _eff.get("burn_time", 0.0)
	burn_max_stacks = maxi(1, int(_eff.get("burn_max_stacks", 1)))
	burn_spread_radius = _eff.get("burn_spread_radius", 0.0)
	burn_doubles_at_max = _eff.get("burn_doubles_at_max", false)
	burn_spreads_on_death = _eff.get("burn_spreads_on_death", false)
	splash_radius = _eff.get("splash_radius", 0.0)
	splash_factor = _eff.get("splash_factor", 0.5)
	slow_factor = _eff.get("slow_factor", 1.0)
	slow_time = _eff.get("slow_time", 0.0)
	stun_chance = _eff.get("stun_chance", 0.0)
	stun_time = _eff.get("stun_time", 0.0)
	execute_chance = _eff.get("execute_chance", 0.0)
	gold_on_kill = int(_eff.get("gold_on_kill", 0))
	life_on_kill_chance = _eff.get("life_on_kill_chance", 0.0)
	slow_chance = _eff.get("slow_chance", 1.0)
	ignores_matchup = _eff.get("ignores_matchup", false)
	pierces_rules = _eff.get("pierces_rules", false)
	damage_per_kill = _eff.get("damage_per_kill", 0.0)
	crack_bonus = _eff.get("crack_bonus", 0.0)
	crack_time = _eff.get("crack_time", 0.0)
	crack_spread_radius = _eff.get("crack_spread_radius", 0.0)
	knockback_chance = _eff.get("knockback_chance", 0.0)
	knockback_distance = _eff.get("knockback_distance", 0.0)
	knockback_chill_on_land = _eff.get("knockback_chill_on_land", false)
	can_hit_flying = _eff.get("can_hit_flying", true)
	# --- level growth ----------------------------------------------------------
	# An upgrade multiplies damage and NOTHING else — range and fire interval belong to the
	# definition, which is to say to the tower's element set, for as long as that set holds.
	# That is the map's rule for range/interval, extended the same way GAME_STRATEGY_V2.md
	# §2.3 extends it: level always follows this same growth curve; only a FUSION may replace
	# what a tower IS.
	#
	# A def with a `damage_tiers` table is read straight out of it — every base element and
	# every fusion row has one, so the growth-constant fallback below is now unreachable in
	# practice and kept only so a def written without a table still scales rather than
	# silently sitting at tier 1. Either way `growth` ends up as "how much stronger than tier
	# 1 this is", which is what the damage-over-time payloads ride.
	var growth := 1.0
	var tiers: Array = _eff.get("damage_tiers", [])
	if not tiers.is_empty():
		damage = float(tiers[mini(level, tiers.size()) - 1])
		growth = damage / float(tiers[0])
	else:
		for i in level - 1:
			growth *= float(Balance.TIER_DAMAGE_MULT[i])
		damage *= growth
	poison_dps *= growth  # DoT scales with the tower's damage growth
	burn_dps *= growth
	# Ice's area-slow: single-target below Lv2, then widening (was _update_slow_splash).
	# Any def may switch it on with a "slow_splash" radius.
	slow_splash_radius = 0.0
	if level >= 2:
		slow_splash_radius = float(_eff.get("slow_splash", 0.0)) \
				* (1.0 + Balance.SLOW_SPLASH_GROWTH * float(level - 2))
	# --- aura from neighbouring towers -----------------------------------------
	# PULLED, not pushed, for the same reason Run's modifiers are: an aura tower built or
	# sold next door changes this tower's stats, and a tower that accumulated the buff when
	# the neighbour appeared would have no way to give it back when it went away. Main
	# emits Game.towers_changed on build/sell/upgrade and every tower re-pulls from scratch.
	#
	# Reads `other._eff`, not `other._def`: the only aura left standing (Grove, Nature
	# branch B) exists purely as a branch override, so a plain `_def` read would never see
	# it. `other._eff` is guaranteed built by the time this runs — every Tower populates it
	# in setup_def(), before it can appear as a neighbour at all.
	#
	# O(towers) per recompute and recompute is not per-frame, so a full 40-cell board costs
	# 1600 distance checks on a build — once, not every tick.
	var aura_damage := 1.0
	var aura_speed := 1.0
	var aura_gold_add := 0
	var aura_life_chance_add := 0.0
	var parent := get_parent()
	if parent != null:
		for node in parent.get_children():
			var other := node as Tower
			if other == null or other == self or not is_instance_valid(other):
				continue
			var radius: float = float(other._eff.get("aura_radius", 0.0))
			if radius <= 0.0 or global_position.distance_squared_to(other.global_position) > radius * radius:
				continue
			# The provider's own level deepens the buff: one step per level past the first,
			# so upgrading a Grove is a real alternative to building a second one.
			var stat := String(other._eff.get("aura_stat", ""))
			if stat != "":
				var step: float = float(other._eff.get("aura_mult", 1.0)) - 1.0
				var boost := 1.0 + step * float(other.level)
				if stat == "damage":
					aura_damage *= boost
				elif stat == "attack_speed":
					aura_speed *= boost
			# Heartwood layers a SECOND aura stat (damage) on top of Grove's base
			# attack_speed grant — kept as its own field rather than overloading `aura_stat`
			# to a list, since Grove is still the only provider that needs more than one.
			# No separate level check needed: `aura_damage_mult` only appears in `_eff` at
			# all once the provider's OWN _recompute() merged its `lv5` slice in, i.e. once
			# ITS level is >= 5 — the gating already happened when `other._eff` was built.
			aura_damage *= float(other._eff.get("aura_damage_mult", 1.0))
			aura_gold_add += int(other._eff.get("aura_gold_add", 0))
			aura_life_chance_add += float(other._eff.get("aura_life_chance_add", 0.0))
	damage *= aura_damage
	poison_dps *= aura_damage
	burn_dps *= aura_damage
	fire_interval /= aura_speed
	gold_on_kill += aura_gold_add
	life_on_kill_chance = clampf(life_on_kill_chance + aura_life_chance_add, 0.0, 1.0)

	# --- Flesh Golem's accumulated kills ----------------------------------------
	# The one stat that is not derived. Applied AFTER the level growth and the aura so it is
	# a flat floor the tower has earned rather than something the multipliers compound, and
	# BEFORE the run modifiers below so the Workshop's damage bonus still covers it.
	if damage_per_kill > 0.0:
		damage += damage_per_kill * float(_kills)

	# --- run modifiers ---------------------------------------------------------
	# The payoff for rebuilding rather than accumulating: these are applied fresh every
	# time, so a modifier can be added — or, later, removed — without the tower drifting.
	var m := Run.mods_for(id, element)
	damage = (damage + m.damage_add) * m.damage_mult
	tower_range = (tower_range + m.range_add) * m.range_mult
	# Divided, never multiplied by (1 - pct) — see TowerMods.attack_speed_mult.
	fire_interval /= m.attack_speed_mult
	# Poison (and burn, the same shape of payload) ride the damage multiplier as well as
	# their own, matching how they already ride the per-level damage growth.
	poison_dps = poison_dps * m.damage_mult * m.poison_mult
	burn_dps = burn_dps * m.damage_mult * m.poison_mult
	burn_time *= m.burn_time_mult          # Wick
	if slow_time > 0.0:
		slow_time += m.slow_time_add       # Permafrost
	vs_flying_mult = m.vs_flying_mult      # Spore
	burn_slow_factor = m.burn_slow_factor  # Backdraft
	overclock_every = m.overclock_every    # Overclock
	target_lowest_hp = m.target_lowest_hp  # Deadeye
	chill_burn_mult = m.chill_burn_mult    # STEAM
	chill_hit_mult = m.chill_hit_mult      # EROSION
	# Groundwork (Earth only, its card `element` scope already guarantees this never fires
	# for another element): ignores can_hit_flying and halves splash in the same stroke.
	groundwork = m.groundwork
	if groundwork:
		can_hit_flying = true
		splash_radius *= 0.5
	splash_radius *= m.splash_mult
	# Scales the SLOW, not the speed: doubling a 0.55 factor would make enemies faster.
	slow_factor = clampf(1.0 - (1.0 - slow_factor) * m.slow_power, 0.05, 1.0)
	# --- derived ---------------------------------------------------------------
	# Floored so a future stack of attack-speed modifiers can never drive the interval to
	# zero, which would make _process fire on every single frame.
	fire_interval = maxf(Balance.MIN_FIRE_INTERVAL, fire_interval)
	_range_sq = tower_range * tower_range

## Gold returned when this tower is sold: everything sunk into it if it never got a shot
## off, most of it (Balance.SELL_REFUND) otherwise. See has_fired. `total_spent` includes
## fusion costs, so selling a Pure tower refunds against the whole road it travelled.
func sell_value() -> int:
	var refund := Balance.SELL_REFUND_UNFIRED if not has_fired else Balance.SELL_REFUND
	return int(total_spent * refund)

func _process(delta: float) -> void:
	# A behavior with no notion of a target (an aura, an economy building) skips the scan
	# entirely rather than paying for one and discarding it. Sun and Well carry auras but do
	# still shoot, so today every tower on the board takes the true branch.
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
			or element == "fire" or _behavior.wants_redraw():
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
		# "First" (closest to the exit) unless Deadeye (GAME_STRATEGY_V2.md §6.3, BUILD
		# NEXT #9) switched every tower to "Lowest" — negated health, so the SAME "highest
		# score wins" comparison below still works for both modes.
		var score := -enemy.health if target_lowest_hp else enemy.progress()
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
## `damage_mult` lets a behavior vary one shot without touching the tower's stats — Magic's
## charged shot is the only caller that passes anything but 1.0.
func fire_bolt(target: Enemy, damage_mult: float = 1.0) -> void:
	has_fired = true
	_recoil = 1.0
	Audio.play_tower_fire(id, element)
	_shots_fired += 1
	# Overclock: every Nth shot deals double damage. Folded into `damage_mult` — the SAME
	# parameter Magic's charge behavior already uses to vary one shot — rather than a
	# separate field, so the two never need to agree on
	# which wins if a future behavior someday wants both at once.
	if overclock_every > 0 and _shots_fired % overclock_every == 0:
		damage_mult *= 2.0
	# Pull a bolt from the shared $Projectiles pool instead of instantiating one per shot;
	# the pool keeps it parented off the tower so it flies independently (see projectiles.gd).
	if not is_instance_valid(_proj_pool):
		_proj_pool = get_tree().current_scene.get_node("Projectiles")
	var p := _proj_pool.acquire() as Projectile
	p.color = element_color
	p.element = element
	p.elements = elements
	p.ignores_matchup = ignores_matchup
	p.pierces_rules = pierces_rules
	p.slow_chance = slow_chance
	# Only handed over when this tower actually grows from kills, so every other bolt leaves
	# the field null and skips the validity check on the kill path entirely.
	p.source_tower = self if damage_per_kill > 0.0 else null
	p.hits_flying = can_hit_flying
	p.splash_radius = splash_radius
	p.splash_factor = splash_factor
	p.slow_factor = slow_factor
	p.slow_time = slow_time
	p.slow_splash_radius = slow_splash_radius
	p.poison_dps = poison_dps
	p.poison_time = poison_time
	p.poison_ignores_matchup = poison_ignores_matchup
	p.poison_spreads_on_death = poison_spreads_on_death
	p.burn_dps = burn_dps
	p.burn_time = burn_time
	p.burn_max_stacks = burn_max_stacks
	p.burn_spread_radius = burn_spread_radius
	p.burn_doubles_at_max = burn_doubles_at_max
	p.burn_spreads_on_death = burn_spreads_on_death
	p.crack_bonus = crack_bonus
	p.crack_time = crack_time
	p.crack_spread_radius = crack_spread_radius
	p.knockback_chance = knockback_chance
	p.knockback_distance = knockback_distance
	p.knockback_chill_on_land = knockback_chill_on_land
	p.stun_chance = stun_chance
	p.stun_time = stun_time
	p.execute_chance = execute_chance
	p.gold_on_kill = gold_on_kill
	p.life_on_kill_chance = life_on_kill_chance
	p.vs_flying_mult = vs_flying_mult
	p.burn_slow_factor = burn_slow_factor
	p.chill_burn_mult = chill_burn_mult
	p.chill_hit_mult = chill_hit_mult
	p.setup(_projectile_origin(), target, damage * damage_mult)

## Painted Fire towers have no swivelling barrel: their visible emitter is the brazier at
## the top. Launching from the Node2D origin made every fireball appear at the masonry's
## feet. Other tower families retain their established origin until their own painted
## sockets are measured.
func _projectile_origin() -> Vector2:
	if element == "fire" and Sprites.tower(element, level) != null:
		var tier := clampi(level, 1, FIRE_FLAME_BASE_Y.size()) - 1
		var socket := Vector2(0.0,
				float(FIRE_FLAME_BASE_Y[tier]) - float(FIRE_FLAME_HEIGHT[tier]) * 0.42)
		return to_global(socket)
	return global_position

const Sprites := preload("res://scripts/sprites.gd")

## How TALL the painted tower is drawn, per level, in board px.
##
## By height, not width, because these sprites get proportionally taller as they upgrade —
## the fire set runs from 1.23 to 1.67 times as tall as it is wide, all of it flame plume.
## Scaling by width let that compound: the top tier ended up 29% of the board's height, when
## a tower on the reference art is at most 19%. Fixing the height fixes the silhouette and
## leaves the widths where they belong, around 60-85px over a 60px footprint.
const SPRITE_HEIGHT: Array = [78.0, 92.0, 106.0, 120.0, 138.0]
const FIRE_EFFECT_FRAMES := 12
const FIRE_EFFECT_FPS := 12.0
## Bottom of the central brazier flame in tower-local board pixels, measured from each
## painted Fire tier. The fixed anchors keep the masonry perfectly still while only the
## flame changes pose.
const FIRE_FLAME_BASE_Y: Array = [-38.0, -52.0, -69.0, -80.0, -90.0]
const FIRE_FLAME_HEIGHT: Array = [34.0, 34.0, 34.0, 36.0, 42.0]

func _draw() -> void:
	# Range indicator in the element's colour: quiet by default so a full board stays
	# readable, clear while hovered so the player can judge coverage.
	var ec := element_color
	if _highlighted:
		draw_circle(Vector2.ZERO, tower_range, Color(ec.r, ec.g, ec.b, 0.07))
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 64, Color(ec.r, ec.g, ec.b, 0.50), 2.5, true)
	else:
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 48, Color(ec.r, ec.g, ec.b, 0.12), 2.0, true)
	# Painted sprite if this element and tier have been drawn; the code art below is the
	# fallback, and it is what the board still looks like everywhere the art has not landed.
	# Only ever for an UNFUSED tower: the painted sets are per base element, and a Steam tower
	# wearing the painted Fire art would be the one place in the game where what you see and
	# what the tower is disagree. Every fusion is code art, drawn in its own colour.
	var art := Sprites.tower(element, level) if elements.size() == 1 else null
	if art != null:
		_draw_sprite(art)
		if element == "fire":
			_draw_fire_flame()
		_draw_level_pips(element_color.lightened(0.35))
		_draw_element_dots()
		return
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
	# Drawn last so the barrel cannot swing over it.
	_draw_element_dots()

## Hangs the painted tower off its ground anchor, so the base sits on the spot the tower
## occupies and the tower grows UPWARD as it is upgraded — which is where a tall sprite has
## room, since the board is seen from slightly above.
func _draw_sprite(art: Texture2D) -> void:
	var size := art.get_size()
	var anchor := Sprites.anchor(art)
	var target: float = float(SPRITE_HEIGHT[clampi(level, 1, SPRITE_HEIGHT.size()) - 1])
	var scale := target / size.y
	# A soft contact shadow: the painting has none (it was asked for without one, so it can
	# be lit by whatever board it lands on) and without one a tower floats.
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, size.x * scale * 0.34, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var where := Rect2(Vector2(-anchor.x * scale, -anchor.y * scale), size * scale)
	# Nudged down a little: the anchor is the sprite's lowest pixel, and letting the base
	# overlap the ground point slightly is what makes it read as standing ON the board
	# rather than behind it.
	where.position.y += 10.0
	draw_texture_rect(art, where, false)

## Animated overlay for the Fire tower's central brazier. Every pose keeps the shared canvas
## produced by the cutter, so a wider flame remains wider instead of being squeezed into the
## first frame's proportions. Lightweight procedural sparks bridge the discrete poses.
func _draw_fire_flame() -> void:
	var tier := clampi(level, 1, FIRE_FLAME_BASE_Y.size()) - 1
	var height: float = FIRE_FLAME_HEIGHT[tier]
	var base_y: float = FIRE_FLAME_BASE_Y[tier]
	var frame_phase := float(get_instance_id() % FIRE_EFFECT_FRAMES)
	var frame := int(floor(Time.get_ticks_msec() * 0.001 * FIRE_EFFECT_FPS + frame_phase)) \
			% FIRE_EFFECT_FRAMES
	var flame := Sprites.effect("fire_flame", frame)
	if flame == null:
		return
	var width := height * flame.get_width() / flame.get_height()
	var where := Rect2(Vector2(-width * 0.5, base_y - height), Vector2(width, height))
	draw_circle(Vector2(0.0, base_y - height * 0.26), height * 0.36,
			Color(1.0, 0.22, 0.025, 0.10))
	draw_texture_rect(flame, where, false, Color(1.0, 1.0, 1.0, 0.88))
	var phase := float(get_instance_id() % 97) * 0.071
	var t := Time.get_ticks_msec() * 0.001 + phase
	for i in 3:
		var spark_p := fposmod(t * (0.72 + i * 0.11) + phase + i * 0.31, 1.0)
		var spark_x := sin(t * (4.2 + i) + i * 2.1) * height * (0.10 + spark_p * 0.10)
		var spark_y := base_y - height * (0.42 + spark_p * 0.88)
		draw_circle(Vector2(spark_x, spark_y), height * (0.038 - spark_p * 0.018),
				Color(1.0, 0.62 + spark_p * 0.25, 0.12, 0.85 * (1.0 - spark_p)))

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

## The elements this tower carries, as a row of coloured dots above the base — one for each,
## in absorb order, in that element's own colour. Replaces the sell "×" that used to sit in
## this corner of the cell.
##
## An unfused tower draws nothing: a single dot on every tower on the board would be noise,
## and the tower's whole silhouette is already that colour. So the row appearing at all IS
## the signal that this tower has been fused, and its length says how far.
func _draw_element_dots() -> void:
	if elements.size() < 2:
		return
	var spacing := 11.0
	var start_x := -(elements.size() - 1) * spacing * 0.5
	for i in elements.size():
		var c := Vector2(start_x + i * spacing, -34.0)
		var col: Color = Game.ELEMENT_COLORS.get(elements[i], Color.WHITE)
		draw_circle(c, 4.6, Color(0, 0, 0, 0.45))
		draw_circle(c, 3.6, col)

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
	# 10px, not 12: the ladder is five tiers deep now, and at 12 the outer pips of a Pure
	# tower reach +/-28 against a base of radius 30 — visually touching the rim. At 10 they
	# stop at +/-24 and the row still reads as five distinct dots.
	var spacing := 10.0
	var start_x := -(level - 1) * spacing * 0.5
	for i in level:
		var c := Vector2(start_x + i * spacing, 9.0)
		draw_circle(c, 4.0, col)
		draw_arc(c, 4.0, 0.0, TAU, 12, Color(0, 0, 0, 0.5), 1.5, true)
