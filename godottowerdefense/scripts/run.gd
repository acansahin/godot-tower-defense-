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
## Element level per element id. Every element starts at 1, so all four base towers are
## buildable immediately. Left over from the six-element build's dual-recipe gate (BUILD
## NEXT #2 removed the last card that raised it — see game.gd's UPGRADE_POOL note); kept
## because `grant()`'s `raise_element` branch and `element_level()` are cheap, general
## infrastructure a future card could use again, not because anything reads it today.
var elements: Dictionary = {}

## Folded TowerMods per "id|element" key, cleared whenever the modifier set changes. The
## fold is cheap, but a wave with 40 towers all re-resolving would otherwise repeat the
## same walk of the modifier list once per tower.
var _cache: Dictionary = {}
## How many times each upgrade id has been taken, for max_stacks.
var _stacks: Dictionary = {}
## Folded global (non-tower) effects, e.g. gold per kill.
var _gold_per_kill: int = 0
var _kill_gold_mult: float = 1.0  ## Frontload's -25%, see kill_gold_mult().
var _upgrade_cost_mult: float = 1.0  ## Foreman's -20%, see upgrade_cost_mult().
var _interest_rate_add: float = 0.0  ## Compound's +3%, see interest_rate_add().
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
	_kill_gold_mult = 1.0
	_upgrade_cost_mult = 1.0
	_interest_rate_add = 0.0
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

## Stats that are NOT a per-tower TowerMods field — folded separately in _refold_globals
## instead, so e.g. "+2 gold per kill" cannot also land on a tower stat (TowerMods.fold has
## no case for any of these and would push_warning on an "unknown stat" otherwise).
const GLOBAL_STATS := ["gold_per_kill", "kill_gold_mult", "upgrade_cost_mult", "interest_rate_add"]

func _fold_into(m: TowerMods, up: Dictionary, id: String, element: String) -> void:
	for effect in up.get("effects", []):
		var eff := effect as Dictionary
		if not _effect_applies(up, eff, id, element):
			continue
		if GLOBAL_STATS.has(String(eff.get("stat", ""))):
			continue
		m.fold(eff)

## True if this ONE effect (inside card `up`) targets a tower with this id/element. A
## per-effect `element`/`tower` key overrides the card-level one, falling back to it when
## absent — every card but one only ever sets scope at the card level, so this reproduces
## the old card-only behaviour exactly for them. Monoculture (GAME_STRATEGY_V2.md §6.3,
## BUILD NEXT #9) is the one card that needs the override: a single pick with one effect at
## +50% for the chosen element and three more at -20% each for the others.
func _effect_applies(up: Dictionary, eff: Dictionary, id: String, element: String) -> bool:
	var want_el := String(eff.get("element", up.get("element", "")))
	if want_el != "" and want_el != element:
		return false
	var want_id := String(eff.get("tower", up.get("tower", "")))
	return want_id == "" or want_id == id

## Extra gold per enemy killed. Queried at the kill site rather than inside Game.add_gold,
## which also pays sell refunds, wave interest and the early-call bonus — a per-kill bonus
## must not leak into any of those.
func bonus_gold_per_kill() -> int:
	return _gold_per_kill

## Multiplier on a kill's base bounty (Frontload's -25%, GAME_STRATEGY_V2.md §6.3, BUILD
## NEXT #9). Separate from bonus_gold_per_kill because that is a flat ADD on top of the
## bounty (Scavenger) while this scales the bounty ITSELF — folding them into one number
## would apply Frontload's penalty to Scavenger's bonus too, which nothing asks for.
func kill_gold_mult() -> float:
	return _kill_gold_mult

## Multiplier on the next upgrade's gold cost (Foreman's -20%).
func upgrade_cost_mult() -> float:
	return _upgrade_cost_mult

## Added directly to Balance.INTEREST_RATE for this run (Compound's +3%, i.e. 5%->8%).
func interest_rate_add() -> float:
	return _interest_rate_add

## True if the player took card `id` this run (not the Workshop's permanent effects — those
## have no `id` a card offer could match). For binary global toggles (Deadeye, Groundwork,
## EMBERSEED) that would be awkward to express as a per-(tower,element) TowerMods field
## since they are not really a stat delta so much as "is this rule active".
func has_card(id: String) -> bool:
	for up in taken:
		if String(up.get("id", "")) == id:
			return true
	return false

## Element level for `id`, or 0 for an element this run does not have.
func element_level(id: String) -> int:
	return int(elements.get(id, 0))

## Every tower the player may currently build: the four elements, plus anything granted
## outright by a card. The dual-recipe gate (owned-element level -> extra tower) that used
## to live here went with the dual roster in BUILD NEXT #2 — see GAME_STRATEGY_V2.md §2 and
## §6; cross-element play is now a card effect, not a second tier of buildable towers.
##
## Derived on every call rather than maintained as a list, for the same reason tower stats
## are recomputed rather than accumulated: there is no separate state to fall out of step,
## so a future card that grants and later revokes a tower id cannot strand it in the palette.
func buildable_towers() -> Array:
	var out: Array = Game.TOWER_ORDER.duplicate()
	for id in unlocked:
		if not out.has(id):
			out.append(id)
	return out

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
	# Instant one-time grants (Bulwark's +5 lives, Frontload's +300 gold, GAME_STRATEGY_V2.md
	# §6.3, BUILD NEXT #9) pay out immediately rather than through the fold below — a single
	# payment, not a recurring stat. Both cards ALSO carry a recurring penalty in `effects`
	# (Bulwark's -10% damage, Frontload's kill_gold_mult), so this falls through to the
	# normal taken.append() rather than returning early like raise/unlock above.
	var grant_lives := int(up.get("grant_lives", 0))
	if grant_lives > 0:
		Game.add_life(grant_lives)
	var grant_gold := int(up.get("grant_gold", 0))
	if grant_gold > 0:
		Game.add_gold(grant_gold)
	taken.append(up)
	_cache.clear()
	_refold_globals()
	modifiers_changed.emit()

## Recomputes the non-tower totals from scratch. Rebuilt rather than incremented for the
## same reason tower stats are: a total that is only ever added to cannot be undone.
func _refold_globals() -> void:
	_gold_per_kill = 0
	_kill_gold_mult = 1.0
	_upgrade_cost_mult = 1.0
	_interest_rate_add = 0.0
	for up in taken:
		for e in up.get("effects", []):
			var effect := e as Dictionary
			var stat := String(effect.get("stat", ""))
			var v := float(effect.get("value", 0.0))
			match stat:
				"gold_per_kill": _gold_per_kill += int(v)
				"kill_gold_mult": _kill_gold_mult *= v
				"upgrade_cost_mult": _upgrade_cost_mult *= v
				"interest_rate_add": _interest_rate_add += v

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
