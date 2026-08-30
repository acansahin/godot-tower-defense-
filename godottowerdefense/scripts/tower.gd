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
## Whether this tower's current art_key/level has a painted set. Kept by _recompute(); read
## by _process() to decide whether the idle pulse needs a repaint out of an idle tower.
var _painted: bool = false

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

## The name `sprites.gd` looks its painted set up under: the element for a base tower, and
## the combination's FIRST name for a fused one — "Steam", never "Vapor", so one set of five
## files covers all five levels the way every element's does. Multi-word names take an
## underscore ("flesh_golem"), which is what cut_sprites.py's own prefix argument produces.
##
## An unpainted combination simply has no files, Sprites.tower() returns null, and the code
## art draws instead — the same fallback that let the six element sets land one at a time.
func art_key() -> String:
	if elements.size() < 2:
		return element
	return String(_def.get("name", "")).to_lower().replace(" ", "_")

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
	# The board holds 9 towers where it used to hold 47, so each one hits harder. Applied
	# here, at the end of the fold, so it lands on the same three payloads the run modifiers
	# do and nothing can pick it up twice — see Balance.GLOBAL_DAMAGE_MULT.
	damage *= Balance.GLOBAL_DAMAGE_MULT
	poison_dps *= Balance.GLOBAL_DAMAGE_MULT
	burn_dps *= Balance.GLOBAL_DAMAGE_MULT
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
	# Cached here because it is _process(), not _draw(), that has to know: an idle painted
	# tower has an animation to run and so cannot skip its repaint. Both inputs to it change
	# only through this function — `level` on upgrade, `art_key()` on fusion.
	_painted = Sprites.tower(art_key(), level) != null

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
	# Read BEFORE the decay: the frame recoil reaches exactly 0 is the frame that has to
	# repaint, or a tower whose target died mid-kick stays parked in its squashed pose.
	var kicking := _recoil > 0.0
	if kicking:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
	# An idle tower never repaints on its own, so the animated hint needs to ask for it.
	# The `ready != _was_upgrade_ready` term gives a single repaint when affordability
	# flips (gold spent/earned) so the affordable-upgrade hint clears/appears on its own.
	# Every term here assumes a turret that tracks a target, so a behavior that animates
	# without one gets its own say via wants_redraw().
	var up_ready := _upgrade_ready()
	# `_painted` replaces what used to be `element == "fire"` here. That term existed for the
	# brazier, the one painted set with a life of its own; every painted tower has an idle
	# pulse now, so the term generalised rather than grew a second clause beside it.
	if target != null or kicking or up_ready or up_ready != _was_upgrade_ready \
			or _painted or _behavior.wants_redraw():
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
	# What the bolt DRAWS as, and it is art_key() rather than `element` on purpose: `element`
	# is what this tower was BUILT as and never changes when it fuses, so passing it made a
	# Steam tower raised out of Fire throw a flame leaf while the one raised out of Water threw
	# a water slug. art_key() is the tower's current identity — the same key its painted set is
	# filed under, so the shot and the building can never name different towers.
	p.shape = art_key()
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

## A painted tower has no swivelling barrel, so its shot has to be given a start point.
## Launching from the Node2D origin puts it at the masonry's FEET — invisible while sprites
## were short, and a clear mistake at 96px, where every bolt but Fire's crawled out from
## under the building that fired it. `_emitter_local()` now answers for every set, measured
## off each sprite, so an unpainted combination is the only caller left on the origin.
func _projectile_origin() -> Vector2:
	var art := Sprites.tower(art_key(), level)
	if art == null:
		return global_position
	return to_global(_emitter_local(art))

const Sprites := preload("res://scripts/sprites.gd")

## How TALL a painted tower is drawn. ONE height for every level: an upgrade changes what the
## tower looks like, never how much board it occupies.
##
## Held by HEIGHT rather than width, which keeps the BASE from growing as a tower is
## upgraded: every painted set gets proportionally taller as it climbs (water runs 1.25 ->
## 0.97 wide-over-tall), so at a fixed height the drawn width falls slightly with each tier.
## Fixing the width would have done the opposite.
##
## The number itself lives in `Game.TOWER_SPRITE_HEIGHT`, because the PLACEMENT RULE has to
## see it - a tower is hung from its ground anchor and drawn upward, so its height decides
## both how far it must stand from the road and how near the top of the board it may go. See
## that constant for the pair it forms with Game.TOWER_GAP and for what a size change costs.
const SPRITE_HEIGHT := Game.TOWER_SPRITE_HEIGHT
# --- The brazier ----------------------------------------------------------------------
## Radius of the glow pool in the bowl, as a fraction of FIRE_FLAME_HEIGHT — the height of the
## painted flame that used to stand here, so the overlay is sized against a measurement rather
## than against a fresh number with nothing behind it.
const FIRE_GLOW_WIDTH := 0.30
const FIRE_EMBERS := 3
## Bottom of the central brazier flame per painted Fire tier, as a FRACTION of the drawn
## sprite height, so the flame keeps sitting on its own brazier whatever SPRITE_HEIGHT is.
## They were measured in board px against the old per-level ladder (-38/78, -52/92, -69/106,
## -80/120, -90/138) and divided by it; the fixed anchors keep the masonry perfectly still
## while only the flame changes pose.
const FIRE_FLAME_BASE_Y: Array = [-0.487, -0.565, -0.651, -0.667, -0.652]
const FIRE_FLAME_HEIGHT: Array = [0.436, 0.370, 0.321, 0.300, 0.304]

# --- Water's pool and Nature's rune circle -------------------------------------------
# The painted feature each of those two sets is built around, per tier, as
# [cx, cy, rx, ry] FRACTIONS of the drawn sprite height measured from the ground anchor —
# the same convention FIRE_FLAME_BASE_Y uses and for the same reason: the masonry stays
# perfectly still while only the effect moves, and the numbers survive a change to
# SPRITE_HEIGHT.
#
# MEASURED BY HAND off the sheets, as Fire's brazier was, and only after three attempts at
# reading them automatically failed in three different ways. Worth writing down, because the
# obvious tool here does not work: a classifier keyed on "blue" or "green" cannot tell the
# pool from the tower's own banners and spillways, which are painted the same colour; one
# keyed on the widest run is broken by the rim highlights that chop the pool into stripes;
# and one keyed on row density lands on the CRYSTAL — dense, bright, exactly the right colour
# and entirely the wrong object — at two tiers of five. What settled it was drawing candidate
# rings onto the sheet and looking at them, which took one pass.
const WATER_POOL: Array = [
	[0.000, -0.630, 0.245, 0.058],
	[0.000, -0.605, 0.220, 0.060],
	[0.000, -0.720, 0.140, 0.040],
	[-0.020, -0.758, 0.165, 0.045],
	[0.010, -0.752, 0.158, 0.044],
]
const NATURE_RUNE: Array = [
	[0.000, -0.650, 0.150, 0.045],
	[0.000, -0.718, 0.170, 0.042],
	[0.000, -0.740, 0.140, 0.038],
	[0.000, -0.800, 0.130, 0.036],
	[0.000, -0.790, 0.130, 0.036],
]

const WATER_RIPPLE_RINGS := 3
const WATER_RIPPLE_PERIOD := 2.9  ## Seconds for one ring to travel from the middle to the rim.
const NATURE_MOTES := 5
const NATURE_MOTE_PERIOD := 3.4   ## Seconds for one spore to rise and fade out.
const NATURE_RUNE_PERIOD := 6.5   ## Seconds for the rune glow to travel once around the ring.
## How far a spore climbs, as a fraction of the drawn height. Kept just under the gap between
## the rune ring and the top of the sprite: past that the motes leave the tower's own bounds,
## and a tower on the top row of pads would sprinkle them into the HUD.
const NATURE_MOTE_RISE := 0.20

## How far the drawn sprite is nudged below its ground anchor, so the base overlaps the spot
## the tower occupies rather than sitting behind it. Named because the emitter socket has to
## agree with it: a muzzle flash measured off the sprite and drawn 10px above where the
## sprite actually is floats free of the building it belongs to.
const SPRITE_NUDGE_Y := 10.0

# --- Showing that a painted tower fired ------------------------------------------------
# EVERY painted tower was frozen while it shot. `_recoil` has always decayed 1 -> 0 after a
# shot, but the only thing reading it was draw_barrel() — the CODE-ART fallback — and all 17
# sets are painted now, so nothing on the board consumed it. A tower firing and a tower idle
# were the same picture.
#
# The obvious fix, and the one tried first, was to move the BODY: shove the sprite back along
# its aim and squash it into the base. Rejected on sight — these are stone buildings, and a
# keep that rocks when it shoots reads as cardboard however small the offset is. The masonry
# stays still and only the LIGHT moves, which is also what the painted Fire brazier does.

## Recoil above which the muzzle flash is drawn — the same threshold draw_barrel() uses for
## its own flash, so the painted path and the code-art path flash for the same handful of
## frames.
const MUZZLE_FROM := 0.55

# --- The idle pulse -----------------------------------------------------------------
# Fire has had a life of its own since its brazier was painted: it flickers whether or not
# anything is on the road. Beside it the other sixteen sets read as statuary — a board with
# nothing walking on it was a still photograph. This is a slow breath at the same emitter
# the muzzle flash uses, so it reads as the tower's own crystal/font/forge being lit rather
# than as a decoration stuck on top of it.
#
# Deliberately far below the flash: this must never be mistaken for a shot. It is the
# difference between a lit building and a firing one, and if the two are confusable the
# flash stops carrying information.
const IDLE_PULSE_PERIOD := 2.6   ## Seconds for one full breath.
const IDLE_PULSE_ALPHA := 0.15   ## Peak alpha of the glow, against the flash's 0.55.
const IDLE_PULSE_RADIUS := 11.0  ## Peak radius in px.
## Where a shot leaves a painted tower, as a fraction of how tall the sprite actually STANDS.
## Measured off the art rather than written down per set: `Sprites.figure_height()` already
## knows the drawn height of each texture, so a squat mound fires low and a spire fires high,
## and a repaint re-derives it with nothing here to update. Fire is the exception — its
## emitter is the brazier, whose height it already carries per tier above.
const EMITTER_FRACTION := 0.72

func _draw() -> void:
	# Range indicator in the element's colour: quiet by default so a full board stays
	# readable, clear while hovered so the player can judge coverage.
	var ec := element_color
	if _highlighted:
		draw_circle(Vector2.ZERO, tower_range, Color(ec.r, ec.g, ec.b, 0.07))
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 64, Color(ec.r, ec.g, ec.b, 0.50), 2.5, true)
	else:
		draw_arc(Vector2.ZERO, tower_range, 0.0, TAU, 48, Color(ec.r, ec.g, ec.b, 0.12), 2.0, true)
	# Sun and Well only: their aura reach, on the ground with the range arc rather than up at
	# the emitter with the rest of the ambient. See _draw_aura_ring.
	_draw_aura_ring()
	# Painted sprite if this tower's art has been drawn; the code art below is the fallback,
	# and it is what the board still looks like everywhere the art has not landed.
	var art := Sprites.tower(art_key(), level)
	if art != null:
		# Ground first, in the order light actually reaches it: the building's OCCLUSION,
		# then whatever light the building throws back onto the grass, then the masonry. The
		# glow used to be laid down before the shadow and was then partly painted over by
		# it, which is why FUSION_GLOW_WIDTH carried a note about having to out-reach a
		# disc it could not see. This ordering removes that coupling instead of re-tuning
		# it, and is also the truthful one — a tower lights ground it is itself shading.
		_draw_contact_shadow(_drawn_width(art))
		# A fusion's light pools on the board it stands on, so it is laid down BEFORE the
		# masonry — a tower standing in its own glow, not wearing it. See _draw_fusion_ground.
		if elements.size() > 1:
			_draw_fusion_ground()
		_draw_sprite(art)
		# Each painted base set is built around ONE feature that should be alive: Fire's
		# brazier, Water's pool, Nature's rune circle. Earth has none — it is a quarry, and
		# the right answer for a pile of rock is that it sits there.
		#
		# Gated on a single element, never on the element field alone. A Steam tower built out
		# of a Fire tower still reports element == "fire", so the looser test would light a
		# fire on top of a waterworks — and now also ripple a pool on top of a forge.
		var ambient := element if elements.size() == 1 else ""
		match ambient:
			"fire": _draw_fire_flame()
			"water": _draw_water_ripples()
			"nature": _draw_nature_motes()
		# Fire's own fire IS its idle animation, and the pulse sits on the very brazier the
		# flame stands in — on that one set the two are the same light drawn twice.
		if elements.size() > 1:
			# The other half, over the sprite: spores climbing past the building.
			_draw_fusion_motes()
		elif ambient != "fire":
			_draw_idle_pulse(art)
		_draw_muzzle_flash(art)
		_draw_level_pips(element_color.lightened(0.35))
		_draw_element_dots()
		return
	# Flat drop shadow under the base.
	draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, Game.GROUND_SQUASH))
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
	var scale := SPRITE_HEIGHT / size.y
	var where := Rect2(Vector2(-anchor.x * scale, -anchor.y * scale), size * scale)
	# Nudged down a little: the anchor is the sprite's lowest pixel, and letting the base
	# overlap the ground point slightly is what makes it read as standing ON the board
	# rather than behind it.
	where.position.y += SPRITE_NUDGE_Y
	# Nothing here reads _recoil: the building itself never moves. See MUZZLE_FROM.
	# Game.ART_TINT is WHITE unless a board and the roster have drifted apart — see it for
	# why the knob exists here, at the one call every painted set passes through.
	draw_texture_rect(art, where, false, Game.ART_TINT)

## The shadow the sheets deliberately ship without, so a set can be lit by whatever board it
## lands on (docs/tower-art-prompt.md: "NO drop shadow — the game draws its own").
##
## It was one hard-edged disc at alpha 0.28, and a disc is the one thing a soft outdoor
## shadow never looks like: with no falloff the eye reads a dark COIN under the building
## rather than the building occluding the ground, which is most of why the towers read as
## stickers. Three stacked ellipses give a cheap penumbra — dense and small at the footing,
## broad and faint at the edge — for two extra draw_circle calls and no texture.
##
## OFFSET DOWN AND SLIGHTLY RIGHT, because the sheets are lit from the upper left. That is
## measured, not assumed: across the roster a sprite's top half runs 11-29 luminance above
## its bottom and its left half 2-15 above its right (tools/art_match.py's method, run per
## half). A shadow thrown the other way fights the painting it belongs to.
const SHADOW_OFFSET := Vector2(2.5, 7.0)
## Widest ring as a fraction of the drawn sprite width. The old 0.34 was sized against the
## disc; a penumbra has to start wider than the footing to read as one.
const SHADOW_WIDTH := 0.46
## Ring radii and alphas, outermost first. They sum to roughly the old single disc's weight
## at the centre while fading to nothing at the rim.
const SHADOW_RINGS: Array = [[1.00, 0.10], [0.74, 0.13], [0.48, 0.16]]

## How wide the sprite is actually drawn. Every set is scaled to one HEIGHT, so this is the
## only thing that varies between them, and both the shadow and _draw_sprite need it.
func _drawn_width(art: Texture2D) -> float:
	var size := art.get_size()
	return size.x * (SPRITE_HEIGHT / size.y)


func _draw_contact_shadow(drawn_width: float) -> void:
	var full := drawn_width * SHADOW_WIDTH
	draw_set_transform(SHADOW_OFFSET, 0.0, Vector2(1.0, Game.GROUND_SQUASH))
	for ring in SHADOW_RINGS:
		draw_circle(Vector2.ZERO, full * float(ring[0]), Color(0, 0, 0, float(ring[1])))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Water's basin, kept moving: rings expand from the middle of the pool and fade at the rim.
##
## This is the painting continuing rather than a new thing laid over it — every Water tier has
## concentric ripples drawn into its pool already, and the still image was of a fountain that
## had stopped. The pool is a circle seen in perspective, so the whole draw is squashed on y
## and the rings themselves are plain arcs; `draw_arc` can do that and cannot do an ellipse.
func _draw_water_ripples() -> void:
	var row: Array = WATER_POOL[clampi(level, 1, WATER_POOL.size()) - 1]
	var centre := Vector2(float(row[0]), float(row[1])) * SPRITE_HEIGHT
	var rx := float(row[2]) * SPRITE_HEIGHT
	var ry := float(row[3]) * SPRITE_HEIGHT
	draw_set_transform(centre, 0.0, Vector2(1.0, ry / rx))
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 61) * 0.047
	for i in WATER_RIPPLE_RINGS:
		var p := fposmod(t / WATER_RIPPLE_PERIOD + float(i) / WATER_RIPPLE_RINGS, 1.0)
		# Fades IN off the middle as well as out at the rim. A ring that arrived at full
		# strength on a point read as a drip landing, which is a different fountain.
		draw_arc(Vector2.ZERO, rx * p, 0.0, TAU, 30,
				Color(0.78, 0.94, 1.0, sin(p * PI) * 0.34), maxf(1.0, 2.6 * (1.0 - p)), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Nature's rune circle, kept turning, and the spores coming off it.
##
## Two motions rather than one, because the ring on its own reads as a lamp on a timer. What
## says "alive" is something LEAVING the tower, so the drifting motes are the point and the
## sweeping rune is the thing that gives them somewhere to come from.
func _draw_nature_motes() -> void:
	var row: Array = NATURE_RUNE[clampi(level, 1, NATURE_RUNE.size()) - 1]
	var centre := Vector2(float(row[0]), float(row[1])) * SPRITE_HEIGHT
	var rx := float(row[2]) * SPRITE_HEIGHT
	var ry := float(row[3]) * SPRITE_HEIGHT
	var phase := float(get_instance_id() % 83) * 0.0757
	var t := Time.get_ticks_msec() * 0.001 + phase
	# A bright fifth of the ring, sweeping round the rune the art already painted there.
	draw_set_transform(centre, 0.0, Vector2(1.0, ry / rx))
	var head := fposmod(t / NATURE_RUNE_PERIOD, 1.0) * TAU
	draw_arc(Vector2.ZERO, rx * 0.82, head, head + TAU * 0.22, 18,
			Color(0.62, 1.0, 0.48, 0.30), 2.4, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in NATURE_MOTES:
		var p := fposmod(t / NATURE_MOTE_PERIOD + float(i) / NATURE_MOTES, 1.0)
		var around := phase * 7.0 + float(i) * TAU / NATURE_MOTES
		var from := Vector2(cos(around) * rx * 0.7, sin(around) * ry * 0.7)
		var drift := sin(t * 1.3 + float(i) * 2.2) * SPRITE_HEIGHT * 0.035
		# Fades in as well as out: a mote that appeared at full strength on the stonework
		# read as a dead pixel on the screen rather than as something the tower let go of.
		draw_circle(centre + from + Vector2(drift, -p * SPRITE_HEIGHT * NATURE_MOTE_RISE),
				lerpf(2.4, 0.7, p), Color(0.66, 1.0, 0.52, sin(p * PI) * 0.75))

# --- The fusion ambient -----------------------------------------------------------------
# The eleven combination towers were the only sets on the board with no life of their own:
# Fire's brazier breathes, Water's pool ripples, Nature's rune sweeps, and all eleven fusions
# got the generic idle pulse and nothing else. Earth got the pulse too, and still does — a
# quarry sitting there is the right answer for a pile of rock.
#
# A fusion cannot use the base towers' trick, because that trick is a hand measurement: each
# of those three is anchored onto a specific painted feature (WATER_POOL, NATURE_RUNE,
# FIRE_FLAME_BASE_Y), and eleven more sets at five tiers each is fifty-five rectangles to read
# off the sheets by hand — after three automated attempts already failed on two sets.
#
# So a fusion's ambient is drawn on the GROUND the tower stands on, at the same contact point
# _draw_sprite() puts its shadow, and it says the one thing about a fused tower that its art
# cannot: WHAT IT IS MADE OF. One motion per element in the recipe, in the fusion's own
# colour, so Steam pools light and ripples in pale blue while Roots only drifts in olive.
# Earth contributes nothing, exactly as it contributes nothing to the base board, which is
# why Clay is the quietest dual and Rainbow the busiest.
#
# THE GROUND IS THE WHOLE POINT, and it was arrived at the expensive way. The first version
# drew all of this at the emitter, where the muzzle flash and the idle pulse already sit —
# and every painted set has its own bright feature painted at exactly that height, because
# that is where a building puts its crystal. Measured by diffing two frames a second apart,
# a glow there moved 37 pixels on Infernal against base Water's 1265: light in the tower's
# own colour, laid over the brightest part of a sprite painted in that colour, is nothing.
# On the grass at its feet the same light has something to be brighter than.
const FUSION_RINGS := 2
const FUSION_MOTES := 4
## Ring reach and mote spread on the ground, as fractions of drawn height. The ring has to
## clear the painted FOOTING (TOWER_BASE_HALF, ~0.45 of a sprite's height) or it never leaves
## the masonry — and has to stay inside half of Game.TOWER_GAP, or two neighbours' ambients
## overlap. 0.50 is the room between those two, and there is not much of it.
const FUSION_RING_RX := 0.50
const FUSION_RING_RY := 0.19
## How far a fusion spore climbs. Well past the base, so it reads as something the building
## LETS GO OF, and short of the top, so a tower on the top row never sprinkles into the HUD —
## the same bound NATURE_MOTE_RISE is written against.
const FUSION_MOTE_RISE := 0.55
## Radius of the light pooling on the ground, as a fraction of drawn height.
##
## This used to have to be WIDER than the contact shadow, because the shadow was drawn after
## it: at 0.30 the glow sat entirely inside a flat black disc and Lava photographed with no
## ambient at all — light drawn and then painted over. `_draw()` now lays the shadow down
## FIRST, so the constraint is gone and this number only has to answer to the board: 0.36
## puts the pool on open grass and stays inside half of Game.TOWER_GAP, so two neighbouring
## fusions never bleed into one another.
const FUSION_GLOW_WIDTH := 0.36

## Sun's and Well's reach. This is the only tower effect in the game that happens somewhere
## other than where the tower shoots, and until now NOTHING on the board said so — an aura
## tower was indistinguishable from a weak damage tower, and which of your towers were inside
## it was a thing you could only work out by reading the description and estimating.
##
## Read the same way the range circle is, and it sits comfortably inside it (170px against
## Sun's 195 and Well's 215), so the two rings never lie on top of each other.
const AURA_RING_PERIOD := 3.2  ## Seconds for one ring to travel from the tower out to the edge.

func _draw_aura_ring() -> void:
	var radius: float = float(_eff.get("aura_radius", 0.0))
	if radius <= 0.0:
		return
	# Brighter than the range arc it sits inside (0.12) by more than a hair: at 0.16 the two
	# read as one indecisive circle, which is worse than having drawn neither.
	var ec := element_color.lightened(0.25)
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 53) * 0.0604
	# The standing edge: quiet, but always there. The travelling ring alone would only answer
	# "how far does this reach" during the fraction of a second it happens to be passing the
	# spot you are looking at, and the question is asked while PLACING a neighbour.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(ec.r, ec.g, ec.b, 0.26), 2.0, true)
	# One ring travelling out, fading in off the tower as well as out at the edge — the same
	# reason Water's ripples do: a ring that arrives at full strength on a point reads as an
	# impact landing rather than as something spreading.
	var p := fposmod(t / AURA_RING_PERIOD, 1.0)
	draw_arc(Vector2.ZERO, radius * p, 0.0, TAU, 48,
			Color(ec.r, ec.g, ec.b, sin(p * PI) * 0.34), maxf(1.0, 3.0 * (1.0 - p)), true)

## How many of the three motions this tower actually has. Earth is silent, so a fusion
## carrying it is one motion quieter than its element count, and Clay and Lava and Roots are
## single-motion towers despite being duals.
func _ambient_motions() -> int:
	var n := 0
	for e in elements:
		if String(e) != "earth":
			n += 1
	return n

## Each motion is quieter the more company it has on one 96px sprite. Square-rooted rather
## than divided by the count: at a flat third a triple's ambient vanished altogether, which is
## the opposite of what a triple should look like.
func _ambient_share() -> float:
	var n := _ambient_motions()
	return 0.0 if n == 0 else 1.0 / sqrt(float(n))

## The half of a fusion's ambient that belongs UNDER the building: light pooling on the board
## and rings spreading from its feet. Drawn before the sprite, so the tower stands in it
## rather than wearing it.
func _draw_fusion_ground() -> void:
	var share := _ambient_share()
	if share <= 0.0:
		return
	var c := element_color.lightened(0.35)
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 97) * 0.0644
	# The same contact point _draw_sprite() hangs its shadow from, so the light and the
	# shadow agree about where the building actually meets the ground.
	var at := Vector2(0.0, SPRITE_NUDGE_Y)
	if elements.has("fire"):
		# Nudged forward of the contact point, so the pool spills onto the grass IN FRONT of
		# the building rather than under it, where the shadow would have it.
		_ambient_glow(at + Vector2(0.0, 4.0), SPRITE_HEIGHT * FUSION_GLOW_WIDTH, c, t, share)
	if elements.has("water"):
		_ambient_rings(at, SPRITE_HEIGHT * FUSION_RING_RX, SPRITE_HEIGHT * FUSION_RING_RY,
				c, t + 1.7, share)

## The half that belongs OVER it: spores climbing past the building. The one motion here that
## LEAVES the tower, which is what stops the other two reading as a lamp on a timer — and the
## reason it is drawn after the sprite rather than with the rest.
func _draw_fusion_motes() -> void:
	if not elements.has("nature"):
		return
	var share := _ambient_share()
	if share <= 0.0:
		return
	# Flesh Golem is the only tower in the game whose stats change while it stands there, and
	# nothing on the board said so either. Its spores thicken as it feeds. Saturating on
	# purpose: the signal worth carrying is "this one has been fed", not a count, and an
	# unbounded glow would end the run as the brightest thing on the map.
	var fed := 1.0
	if damage_per_kill > 0.0:
		fed = 1.0 + 0.9 * (1.0 - exp(-float(_kills) / 40.0))
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 97) * 0.0644 + 3.1
	_ambient_motes(Vector2(0.0, SPRITE_NUDGE_Y),
			SPRITE_HEIGHT * FUSION_RING_RX * 0.7, SPRITE_HEIGHT * FUSION_RING_RY * 0.7,
			element_color.lightened(0.35), t, share * fed)

# The three primitives below are deliberately NOT the base towers' ambients refactored into
# shared functions. Those three are measured onto one painted feature apiece and tuned against
# it in two hardcoded colours each; pulling a common function out of them would have moved
# three shipped, hand-tuned drawings to buy nothing. These are the same IDEAS, parameterised.

## Fire's contribution: a pool of light on the ground, breathing. Squashed hard, because it
## lies ON the board and the board is seen from slightly above. Two rates that do not divide
## into one another, as the brazier uses, so a row of fused towers never settles into one beat.
func _ambient_glow(at: Vector2, width: float, tint: Color, t: float, share: float) -> void:
	var breath := 0.72 + 0.18 * sin(t * 2.3) + 0.10 * sin(t * 5.7)
	draw_set_transform(at, 0.0, Vector2(1.0, Game.GROUND_SQUASH))
	draw_circle(Vector2.ZERO, width * 1.75 * breath,
			Color(tint.r, tint.g, tint.b, 0.28 * share))
	draw_circle(Vector2.ZERO, width * 0.98 * breath,
			Color(tint.r, tint.g, tint.b, 0.44 * share))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Water's contribution: rings opening across the ground and fading at the rim, in perspective.
##
## Brightest LATE rather than in the middle, which is where every other fade in this file
## peaks. The middle of this one is still inside the tower's own footing; a ring only has
## something to be seen against once it is out on the grass.
func _ambient_rings(at: Vector2, rx: float, ry: float, tint: Color, t: float,
		share: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, ry / rx))
	for i in FUSION_RINGS:
		var p := fposmod(t / WATER_RIPPLE_PERIOD + float(i) / FUSION_RINGS, 1.0)
		draw_arc(Vector2.ZERO, rx * p, 0.0, TAU, 28,
				Color(tint.r, tint.g, tint.b, sin(p * p * PI) * 0.60 * share),
				maxf(1.2, 3.2 * (1.0 - p)), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Nature's contribution: specks the tower lets go of, climbing from the ground past the
## building. Fades in as well as out — a mote that appears at full strength on the stonework
## reads as a dead pixel on the screen rather than as something the tower released.
func _ambient_motes(at: Vector2, rx: float, ry: float, tint: Color, t: float,
		share: float) -> void:
	for i in FUSION_MOTES:
		var p := fposmod(t / NATURE_MOTE_PERIOD + float(i) / FUSION_MOTES, 1.0)
		var around := t * 0.4 + float(i) * TAU / FUSION_MOTES
		var from := Vector2(cos(around) * rx, sin(around) * ry)
		var drift := sin(t * 1.3 + float(i) * 2.2) * SPRITE_HEIGHT * 0.035
		draw_circle(at + from + Vector2(drift, -p * SPRITE_HEIGHT * FUSION_MOTE_RISE),
				lerpf(2.6, 0.7, p),
				Color(tint.r, tint.g, tint.b, sin(p * PI) * 0.85 * share))

## The slow breath at the emitter that keeps an idle painted tower from reading as a statue.
## Phase-shifted by the instance id so a row of towers does not pulse in unison — which is
## the failure the same trick already guards against in _draw_fire_flame().
func _draw_idle_pulse(art: Texture2D) -> void:
	var phase := float(get_instance_id() % 71) * 0.0885
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU / IDLE_PULSE_PERIOD
			+ phase)
	var ec := element_color
	var at := _emitter_local(art)
	draw_circle(at, IDLE_PULSE_RADIUS * (0.62 + 0.38 * breath),
			Color(ec.r, ec.g, ec.b, IDLE_PULSE_ALPHA * (0.45 + 0.55 * breath)))

## The shot leaving a painted tower: a bloom of the element's own colour at the emitter,
## over the handful of frames after firing. The code-art fallback has always had one (see
## draw_barrel), so this is the painted path catching up rather than a new idea.
func _draw_muzzle_flash(art: Texture2D) -> void:
	if _recoil <= MUZZLE_FROM:
		return
	var f: float = (_recoil - MUZZLE_FROM) / (1.0 - MUZZLE_FROM)
	var at := _emitter_local(art)
	var ec := element_color
	draw_circle(at, 9.0 + 15.0 * f, Color(ec.r, ec.g, ec.b, 0.22 * f))
	draw_circle(at, 5.0 + 7.0 * f, Color(ec.r, ec.g, ec.b, 0.55 * f))
	draw_circle(at, 2.5 + 3.0 * f, Color(1.0, 1.0, 1.0, 0.65 * f))

## Where this tower's shot leaves it, in tower-local pixels. One answer shared by the muzzle
## flash and by the projectile's own start point, so the bolt and the flash cannot drift
## apart — which is exactly what happened while only Fire had a socket and every other
## element launched from `global_position`, i.e. from the tower's feet.
func _emitter_local(art: Texture2D) -> Vector2:
	# Painted Fire's visible emitter is the brazier, whose height is measured per tier.
	if elements.size() == 1 and element == "fire":
		var tier := clampi(level, 1, FIRE_FLAME_BASE_Y.size()) - 1
		return Vector2(0.0, (float(FIRE_FLAME_BASE_Y[tier])
				- float(FIRE_FLAME_HEIGHT[tier]) * 0.42) * SPRITE_HEIGHT)
	var scale := SPRITE_HEIGHT / art.get_size().y
	return Vector2(0.0,
			SPRITE_NUDGE_Y - Sprites.figure_height(art) * scale * EMITTER_FRACTION)

## The Fire tower's brazier.
##
## Far less is drawn here than either the painted twelve-frame flame or the code-drawn tongues
## that first replaced it, and the reason is worth writing down because it is invisible from
## the code: THE FIRE TOWER SPRITE ALREADY HAS A FIRE PAINTED INTO IT. Every tier's bowl
## carries a burning flame and a white smoke plume, in the art. So the painted animation was a
## second flame stacked on the first — and so were the tongues — which is why Fire kept reading
## as hotter than every other tower no matter what the overlay's size was set to. The overlay
## was never the problem; drawing a flame at all was.
##
## What is left is the one thing a painting cannot do: make the light MOVE. A breathing pool of
## glow in the bowl and a few embers off the top — the same weight as Water's ripples on its
## painted pool and Nature's sweep on its painted rune. In all three the ART says what the
## element is, and the code only says it is alive.
##
## FIRE_FLAME_BASE_Y and FIRE_FLAME_HEIGHT survive every one of these rewrites: they measure
## where each tier's brazier sits and how much room its fire has, which is a fact about the
## masonry rather than about whatever is filling it this month.
func _draw_fire_flame() -> void:
	var tier := clampi(level, 1, FIRE_FLAME_BASE_Y.size()) - 1
	var full: float = float(FIRE_FLAME_HEIGHT[tier]) * SPRITE_HEIGHT
	var base_y: float = float(FIRE_FLAME_BASE_Y[tier]) * SPRITE_HEIGHT
	var width := full * FIRE_GLOW_WIDTH
	var phase := float(get_instance_id() % 89) * 0.0706
	var t := Time.get_ticks_msec() * 0.001 + phase
	# Two rates that do not divide into one another, so the bowl never settles into the
	# obvious beat a single sine gives it.
	var breath := 0.72 + 0.18 * sin(t * 2.3) + 0.10 * sin(t * 5.7)
	# Squashed, so the light lies IN the bowl rather than hovering as a ball above it.
	draw_set_transform(Vector2(0.0, base_y), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, width * 1.75 * breath, Color(1.0, 0.30, 0.04, 0.15))
	draw_circle(Vector2.ZERO, width * 0.98 * breath, Color(1.0, 0.58, 0.12, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Embers, on the same rise-and-fade the Nature spores use — which is the point: the three
	# ambients are one idea in three colours.
	for i in FIRE_EMBERS:
		var p := fposmod(t * 0.55 + float(i) / FIRE_EMBERS, 1.0)
		var x := sin(t * (3.1 + float(i)) + float(i) * 2.4) * width * 0.5
		# Kept low. Reaching further cleared the tower's own height and read as a plume
		# standing over the brazier — next to the one the art already paints there.
		draw_circle(Vector2(x, base_y - full * (0.40 + p * 0.45)),
				lerpf(1.8, 0.6, p), Color(1.0, 0.66, 0.16, sin(p * PI) * 0.85))

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
