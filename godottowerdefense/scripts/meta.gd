extends Node
## "Meta" autoload: everything that OUTLIVES a run — the Essence wallet, Workshop levels,
## the best wave ever reached, and the timestamp the offline reward is measured from.
##
## The line against Run is the important one and it is drawn on lifetime, not on subject:
## Run holds what dies when you lose, Meta holds what does not. Both feed the same
## TowerMods fold, so a permanent +6% damage and a roguelite +25% damage stack through one
## code path rather than two that have to be kept agreeing.
##
## Every mutation persists immediately (see Save.flush). Progress that only exists in RAM is
## progress a killed app silently deletes, and on mobile the app is killed constantly.

signal essence_changed(amount: int)
signal workshop_changed

const SECTION := "meta"

var essence: int = 0
var best_wave: int = 0
var total_runs: int = 0
## Workshop entry id -> level owned.
var levels: Dictionary = {}
## Ruleset id ("normal"/"easy") -> best star count (0-3) ever earned on it
## (GAME_STRATEGY_V2.md §12.4, §13.2, BUILD NEXT #8). Phase 1 has one map, so this is the
## whole of "stars" for now; a future second/third map would key this by (board, ruleset)
## instead of ruleset alone.
var stars: Dictionary = {}
## Unix seconds when the game was last seen. Drives the offline reward.
var last_seen: int = 0
## Essence granted by the last offline calculation, for the menu to report. Not persisted —
## it describes this launch only.
var pending_offline: int = 0

func _ready() -> void:
	_load()
	_collect_offline()

# --- Persistence ---------------------------------------------------------------

func _load() -> void:
	var d := Save.get_section(SECTION)
	essence = int(d.get("essence", 0))
	best_wave = int(d.get("best_wave", 0))
	total_runs = int(d.get("total_runs", 0))
	last_seen = int(d.get("last_seen", 0))
	# JSON gives back a plain Dictionary with float values; levels are re-read as ints at
	# the point of use (level_of), so no conversion pass is needed here.
	levels = d.get("levels", {})
	stars = d.get("stars", {})

func _persist() -> void:
	Save.put_section(SECTION, {
		"essence": essence,
		"best_wave": best_wave,
		"total_runs": total_runs,
		"last_seen": last_seen,
		"levels": levels,
		"stars": stars,
	})
	Save.flush()

## Stamps "the player was here just now". Called on quit and after every meta change, so the
## offline clock starts from the last real interaction rather than from app launch.
func touch() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	_persist()

# --- Offline -------------------------------------------------------------------

## Awards Essence for the time since `last_seen`, capped by Balance. Runs once, at startup.
func _collect_offline() -> void:
	if Save.is_fresh or last_seen <= 0:
		touch()  # brand new player: start the clock, award nothing
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed := float(now - last_seen)
	# A clock that moved backwards (timezone change, manual clock edit, NTP correction)
	# would otherwise produce a negative or absurd reward. Treat it as no time passed.
	if elapsed <= 0.0:
		touch()
		return
	pending_offline = Balance.offline_essence(elapsed, best_wave)
	if pending_offline > 0:
		essence += pending_offline
		essence_changed.emit(essence)
	touch()

# --- Wallet --------------------------------------------------------------------

func add_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence += amount
	essence_changed.emit(essence)
	_persist()

## Banks the result of a finished run. Returns the Essence awarded so the summary can show it.
func finish_run(wave_reached: int) -> int:
	total_runs += 1
	best_wave = maxi(best_wave, wave_reached)
	var earned := Balance.run_essence(wave_reached)
	essence += earned
	essence_changed.emit(essence)
	touch()  # persists everything above
	return earned

## Best star count ever earned on `ruleset` (0 if never won there).
func stars_for(ruleset: String) -> int:
	return int(stars.get(ruleset, 0))

## Records a win's star count (GAME_STRATEGY_V2.md §12.4: ★ finish, ★★ ≤5 lives lost,
## ★★★ no lives lost) — keeps the best, same rule as best_wave. Only called on an actual
## victory (main.gd's _on_victory); a loss never reaches this, so there is no 0-star entry
## to record — "never won it" and "won it for 1 star" both start from an absent key.
func record_stars(ruleset: String, count: int) -> void:
	if count <= stars_for(ruleset):
		return
	stars[ruleset] = count
	_persist()

# --- Workshop ------------------------------------------------------------------

func level_of(id: String) -> int:
	return int(levels.get(id, 0))

func def_of(id: String) -> Dictionary:
	for d in Game.WORKSHOP_DEFS:
		if String((d as Dictionary)["id"]) == id:
			return d
	return {}

## Cost of the next level, or -1 when the entry is already maxed.
func next_cost(id: String) -> int:
	var d := def_of(id)
	if d.is_empty():
		return -1
	var lv := level_of(id)
	if lv >= int(d.get("max_level", 1)):
		return -1
	return Balance.workshop_cost(int(d["base_cost"]), float(d["cost_growth"]), lv)

func can_buy(id: String) -> bool:
	var cost := next_cost(id)
	return cost >= 0 and essence >= cost

## Buys one level. Returns false (changing nothing) if maxed or unaffordable.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	essence -= next_cost(id)
	levels[id] = level_of(id) + 1
	essence_changed.emit(essence)
	workshop_changed.emit()
	_persist()
	return true

# --- Applying to a run ---------------------------------------------------------

## The Workshop's tower-stat effects, expanded one entry per owned level, in the same shape
## Run folds roguelite cards from. Run applies these as its permanent baseline at run start.
##
## `start_gold` / `start_lives` are filtered out here: they are run-start values rather than
## tower stats, and folding them into TowerMods would only produce an "unknown stat" warning.
## Typed as Array[Dictionary] to match Run.permanent: GDScript refuses to assign an untyped
## Array to a typed one, and it fails at RUNTIME rather than at parse time — the effect was
## that every Workshop tower upgrade silently did nothing while start gold/lives still
## worked, which is exactly the half-broken state that survives a playtest.
func run_start_modifiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in Game.WORKSHOP_DEFS:
		var def := d as Dictionary
		var lv := level_of(String(def["id"]))
		if lv <= 0:
			continue
		var tower_effects: Array[Dictionary] = []
		for e in def.get("effects", []):
			if not _is_run_start_stat(String((e as Dictionary).get("stat", ""))):
				tower_effects.append(e)
		if tower_effects.is_empty():
			continue
		# One pseudo-card per owned level: level 3 of a +6% entry folds 1.06 three times,
		# which is the compounding the Workshop UI advertises.
		for _i in lv:
			out.append({"id": "workshop_" + String(def["id"]), "effects": tower_effects})
	return out

## Extra starting gold from the Workshop.
func bonus_start_gold() -> int:
	return _run_start_total("start_gold")

## Extra starting lives from the Workshop.
func bonus_start_lives() -> int:
	return _run_start_total("start_lives")

func _run_start_total(stat: String) -> int:
	var total := 0.0
	for d in Game.WORKSHOP_DEFS:
		var def := d as Dictionary
		var lv := level_of(String(def["id"]))
		if lv <= 0:
			continue
		for e in def.get("effects", []):
			var effect := e as Dictionary
			if String(effect.get("stat", "")) == stat:
				total += float(effect.get("value", 0.0)) * float(lv)
	return int(total)

func _is_run_start_stat(stat: String) -> bool:
	return stat == "start_gold" or stat == "start_lives"
