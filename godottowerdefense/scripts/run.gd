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
## An avatar boss went down and its element is now fusable. Main raises the banner; the
## tower panel re-reads unlocked_fusions on its own the next time it opens.
signal fusion_unlocked(element: String)

## Every upgrade taken this run, in pick order. The roguelite card pool that used to fill
## this is gone (cross-element power comes off avatar bosses now — see unlocked_fusions
## below), so today only the Workshop feeds the fold, through `permanent`. Kept because it
## is the generic path a future run-scoped effect would use, and it costs nothing empty.
var taken: Array[Dictionary] = []
## The Workshop's permanent effects, seeded at run start. Kept separate from `taken` so the
## run summary can honestly say what was earned THIS run, and so permanent power can never
## be mistaken for something the run granted. Folded through exactly the same path.
var permanent: Array[Dictionary] = []
## Tower ids unlocked this run, on top of Game.TOWER_ORDER.
var unlocked: Array[String] = []

# --- The fusion ladder's run state ---------------------------------------------
## The four elements in the order their avatar bosses arrive, drawn per run from the run
## seed. Index 0 is the wave-3 boss, index 3 the wave-15 one — see boss_element_for_wave.
var boss_elements: Array[String] = []
## Elements whose avatar boss has actually been KILLED (not merely survived — see
## wave_manager's `was_killed` check). A tower may absorb any element in here that it does
## not already carry; this is the only gate on the whole fusion ladder.
var unlocked_fusions: Array[String] = []

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

## Clears everything for a new run. `run_seed` makes the avatar boss order reproducible, the
## same way the wave seed makes the waves reproducible — one number replays a whole run,
## both what it throws at you and which elements it lets you answer with.
func reset(run_seed: int) -> void:
	taken.clear()
	unlocked.clear()
	unlocked_fusions.clear()
	_rng.seed = run_seed
	_shuffle_boss_elements()
	_cache.clear()
	_stacks.clear()
	_gold_per_kill = 0
	_kill_gold_mult = 1.0
	_upgrade_cost_mult = 1.0
	_interest_rate_add = 0.0
	# The Workshop's permanent power enters the run here, as the baseline everything else
	# stacks on top of. Re-read each run rather than cached, so a level bought between runs
	# is live on the next one with nothing to invalidate.
	permanent = Meta.run_start_modifiers()
	modifiers_changed.emit()
	roster_changed.emit()

## Draws this run's avatar boss order: the four elements, each exactly once, in a random
## order. Fisher-Yates against `_rng` rather than Array.shuffle(), which uses the GLOBAL
## RNG — with shuffle() the run seed would replay the waves but not the boss order, and a
## "same seed, same run" promise that holds for one half and not the other is worse than
## none. Every element appears exactly once by construction, so no element can be missed
## and none can be drawn twice.
func _shuffle_boss_elements() -> void:
	boss_elements.clear()
	for e in Game.TOWER_ORDER:
		boss_elements.append(String(e))
	for i in range(boss_elements.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := boss_elements[i]
		boss_elements[i] = boss_elements[j]
		boss_elements[j] = tmp

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

# --- The fusion ladder ---------------------------------------------------------

## The element of the avatar boss on `wave`, or "" if that wave carries no avatar. Reads
## Balance.ELEMENT_BOSS_WAVES positionally: the Nth entry there gets the Nth element of this
## run's shuffled order, which is what makes wave 3's boss reproducible from the run seed.
func boss_element_for_wave(wave: int) -> String:
	var i := Balance.ELEMENT_BOSS_WAVES.find(wave)
	if i < 0 or i >= boss_elements.size():
		return ""
	return boss_elements[i]

## Records that an avatar boss went down. Idempotent, so a double-call (a boss dying at the
## exact moment the wave clears, say) cannot double-announce.
func unlock_fusion(element: String) -> void:
	if element == "" or unlocked_fusions.has(element):
		return
	unlocked_fusions.append(element)
	fusion_unlocked.emit(element)

## True once `element`'s avatar boss has been beaten this run.
func is_fusion_unlocked(element: String) -> bool:
	return unlocked_fusions.has(element)

## Every tower the player may currently build: the four elements, plus anything granted
## outright. Cross-element towers are NOT here and never will be — they are grown out of a
## tower already on the board (Tower.add_element), so the palette stays four slots wide from
## wave 1 to wave 20 no matter how far the fusion ladder has been climbed.
##
## Derived on every call rather than maintained as a list, for the same reason tower stats
## are recomputed rather than accumulated: there is no separate state to fall out of step.
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
	# Element-track and tower-unlock grants used to branch here; both were card-only and both
	# went with the pool. What is left is the generic path — an instant payout if the entry
	# asks for one, then the fold — and today only the Workshop reaches it, via `permanent`.
	#
	# An instant grant pays out immediately rather than through the fold: it is a single
	# payment, not a recurring stat. It deliberately does NOT return early, so an entry may
	# carry both a one-off payout and a lasting effect.
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
