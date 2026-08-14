extends Node
## "Run" autoload: the state that belongs to ONE run and dies with it — the roguelite
## upgrades picked, the towers unlocked along the way, and the folded totals they produce.
##
## Towers PULL from here rather than being pushed to. Pushing a copy of each modifier into
## every placed tower would mean a tower built after a card was picked silently misses it,
## and removing a modifier would mean reversing a mutation in 40 places. Instead a tower
## re-derives its stats from Run whenever `modifiers_changed` fires, and any tower built
## later reads the same source on its first _recompute(). Per-frame cost is zero either way.
##
## Deliberately NOT the owner of gold/lives: those still live in Game, which every script
## already reads. Splitting them across two autoloads mid-refactor would churn every call
## site for no behavioural gain — that move belongs with the save system, when there is
## finally a reason to draw the line between run state and permanent state.

signal modifiers_changed  ## The modifier set changed; towers re-resolve their stats.
signal roster_changed     ## A tower was unlocked; the palette gains a slot.

## Every upgrade taken this run, in pick order.
var taken: Array[Dictionary] = []
## The Workshop's permanent effects, seeded at run start. Kept separate from `taken` so the
## run summary can honestly say what was picked THIS run, and so permanent power can never
## be mistaken for a card and re-offered. Folded through exactly the same path.
var permanent: Array[Dictionary] = []
## Tower ids unlocked this run, on top of Game.TOWER_ORDER.
var unlocked: Array[String] = []
## Element level per element id. Every element starts at 1, so the six base towers are
## buildable immediately; raising one to Game.DUAL_ELEMENT_LEVEL is what makes its dual
## recipes available. This is the map's own gate — it levels six research tracks and asks
## which ones you own — rather than a merge-two-towers mechanic, which the map does not have.
var elements: Dictionary = {}

## Folded TowerMods per "id|element" key, cleared whenever the modifier set changes. The
## fold is cheap, but a wave with 40 towers all re-resolving would otherwise repeat the
## same walk of the modifier list once per tower.
var _cache: Dictionary = {}
## How many times each upgrade id has been taken, for max_stacks.
var _stacks: Dictionary = {}
## Folded global (non-tower) effects, e.g. gold per kill.
var _gold_per_kill: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	reset(0)

## Clears everything for a new run. `run_seed` makes the card offers reproducible, the same
## way the wave seed makes the waves reproducible.
func reset(run_seed: int) -> void:
	taken.clear()
	unlocked.clear()
	elements.clear()
	for e in Game.TOWER_ORDER:
		elements[String(e)] = 1
	_cache.clear()
	_stacks.clear()
	_gold_per_kill = 0
	_rng.seed = run_seed
	# The Workshop's permanent power enters the run here, as the baseline every card then
	# stacks on top of. Re-read each run rather than cached, so a level bought between runs
	# is live on the next one with nothing to invalidate.
	permanent = Meta.run_start_modifiers()
	modifiers_changed.emit()
	roster_changed.emit()

# --- Reading -------------------------------------------------------------------

## The folded modifiers that apply to a tower with this id and damage element. Cached, so
## the modifier list is walked once per distinct (id, element) pair rather than per tower.
func mods_for(id: String, element: String) -> TowerMods:
	var key := id + "|" + element
	var hit = _cache.get(key)  # untyped: get() returns null for a missing key
	if hit != null:
		return hit
	var m := TowerMods.new()
	# Permanent first, then this run's cards. Order is irrelevant to the result (the folds
	# commute) but reads as what it is: the Workshop is the floor a run builds from.
	for up in permanent:
		_fold_into(m, up, id, element)
	for up in taken:
		_fold_into(m, up, id, element)
	_cache[key] = m
	return m

func _fold_into(m: TowerMods, up: Dictionary, id: String, element: String) -> void:
	if not _applies_to(up, id, element):
		return
	for effect in up.get("effects", []):
		# Global effects are folded separately in _refold_globals; skip them here so a
		# "+2 gold per kill" card cannot also land on a tower stat.
		if String((effect as Dictionary).get("stat", "")) == "gold_per_kill":
			continue
		m.fold(effect)

## Extra gold per enemy killed. Queried at the kill site rather than inside Game.add_gold,
## which also pays sell refunds, wave interest and the early-call bonus — a per-kill bonus
## must not leak into any of those.
func bonus_gold_per_kill() -> int:
	return _gold_per_kill

## Element level for `id`, or 0 for an element this run does not have.
func element_level(id: String) -> int:
	return int(elements.get(id, 0))

## True when both elements of `dual_id`'s recipe are raised far enough to build it. A recipe
## with no TOWER_DEFS entry is never buildable however deep its elements go — the seven
## unported duals are listed in DUAL_RECIPES for completeness, not as content.
func dual_available(dual_id: String) -> bool:
	if not Game.TOWER_DEFS.has(dual_id):
		return false
	var recipe: Array = Game.DUAL_RECIPES.get(dual_id, [])
	if recipe.is_empty():
		return false
	for e in recipe:
		if element_level(String(e)) < Game.DUAL_ELEMENT_LEVEL:
			return false
	return true

## Every tower the player may currently build: the six elements, every dual whose recipe
## the current element levels satisfy, and anything granted outright by a card.
##
## Derived on every call rather than maintained as a list, for the same reason tower stats
## are recomputed rather than accumulated: there is no separate state to fall out of step
## with the element levels, so lowering one (a future card, a reset) cannot strand a tower
## in the palette that its recipe no longer supports.
func buildable_towers() -> Array:
	var out: Array = Game.TOWER_ORDER.duplicate()
	for id in Game.DUAL_RECIPES:
		var dual := String(id)
		if dual_available(dual) and not out.has(dual):
			out.append(dual)
	for id in unlocked:
		if not out.has(id):
			out.append(id)
	return out

## True if `up` targets a tower with this id/element. An upgrade with neither an `element`
## nor a `tower` key is global and applies to everything.
func _applies_to(up: Dictionary, id: String, element: String) -> bool:
	var want_el := String(up.get("element", ""))
	if want_el != "" and want_el != element:
		return false
	var want_id := String(up.get("tower", ""))
	return want_id == "" or want_id == id

# --- Granting ------------------------------------------------------------------

## Applies a chosen upgrade for the rest of the run.
func grant(up: Dictionary) -> void:
	var id := String(up.get("id", ""))
	_stacks[id] = int(_stacks.get(id, 0)) + 1
	# An element card raises one element track. It carries no `effects`, because the power
	# it grants is access: every dual whose recipe this completes appears in the palette,
	# which buildable_towers() re-derives on its own.
	var raise := String(up.get("raise_element", ""))
	if raise != "":
		elements[raise] = element_level(raise) + 1
		roster_changed.emit()
		return
	var unlock := String(up.get("unlock", ""))
	if unlock != "":
		if not unlocked.has(unlock):
			unlocked.append(unlock)
			roster_changed.emit()
		return
	taken.append(up)
	_cache.clear()
	_refold_globals()
	modifiers_changed.emit()

## Recomputes the non-tower totals from scratch. Rebuilt rather than incremented for the
## same reason tower stats are: a total that is only ever added to cannot be undone.
func _refold_globals() -> void:
	_gold_per_kill = 0
	for up in taken:
		for e in up.get("effects", []):
			var effect := e as Dictionary
			if String(effect.get("stat", "")) == "gold_per_kill":
				_gold_per_kill += int(float(effect.get("value", 0.0)))

# --- Offering ------------------------------------------------------------------

## Rolls the cards to offer after `wave`. Returns up to Balance.CHOICE_COUNT distinct
## upgrades, weighted by rarity. Returns fewer only if the pool genuinely runs dry, which
## the caller must handle rather than assume away.
func roll_choices(wave: int) -> Array:
	var pool := _eligible(wave)
	var out: Array = []
	for _i in Balance.CHOICE_COUNT:
		if pool.is_empty():
			break
		var picked := _weighted_pick(pool, wave)
		out.append(pool[picked])
		pool.remove_at(picked)  # no duplicate cards within one offer
	return out

## Everything still offerable at `wave`: under its stack limit, past its min_wave, and —
## for unlocks — not already owned.
func _eligible(wave: int) -> Array:
	var out: Array = []
	for u in Game.UPGRADE_POOL:
		var up := u as Dictionary
		if wave < int(up.get("min_wave", 0)):
			continue
		var unlock := String(up.get("unlock", ""))
		if unlock != "" and unlocked.has(unlock):
			continue
		if int(_stacks.get(String(up.get("id", "")), 0)) >= int(up.get("max_stacks", 1)):
			continue
		out.append(up)
	return out

## Index of a rarity-weighted pick from `pool`.
func _weighted_pick(pool: Array, wave: int) -> int:
	var total := 0.0
	for up in pool:
		total += Balance.rarity_weight(String((up as Dictionary).get("rarity", "common")), wave)
	var roll := _rng.randf() * total
	for i in pool.size():
		roll -= Balance.rarity_weight(String((pool[i] as Dictionary).get("rarity", "common")), wave)
		if roll <= 0.0:
			return i
	return pool.size() - 1  # float drift only; the loop above normally returns
