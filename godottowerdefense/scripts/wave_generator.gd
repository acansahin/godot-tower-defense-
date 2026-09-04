extends RefCounted
class_name WaveGenerator
## Produces wave definitions past the end of Game.WAVES, so a run never runs out of waves.
## Returns the same Dictionary shape the hand-authored seed table uses, which is what lets
## WaveManager consume both without caring where a wave came from.
##
## PURITY IS THE WHOLE CONTRACT: wave_def(n) must return the same thing every time it is
## called for the same n, in any order. The HUD asks for wave n+1 while wave n is still
## spawning, and a run summary may ask again afterwards — a generator that advanced an
## internal RNG per call would hand out a different wave than the one it previewed. So the
## RNG is re-seeded from (run_seed, n) on every call and nothing is remembered between them.

## Archetypes the generator may roll, with the wave number each becomes eligible. The seed
## table introduces every one of these by hand first; these are the reappearances, so the
## thresholds only need to keep an idea from returning before it was taught.
##
## `weight` is the roll weight where the generator takes over and `late` the weight it drifts
## to by LATE_FULL, lerped in between (see _weight). The two differ because a fifty-wave run
## generated from ONE weight table reads as the same handful of waves on a loop: normal and
## fast are the commonest things a player meets early, and they should not still be the
## commonest thing at wave 45 — by then the archetypes that ask a QUESTION rather than raise
## a number are what a late wave should mostly be made of.
const POOL: Array = [
	{"type": "normal", "from": 1,  "weight": 3.0, "late": 0.5},
	{"type": "fast",   "from": 3,  "weight": 2.5, "late": 2.0},
	{"type": "swarm",  "from": 4,  "weight": 2.0, "late": 1.5},
	{"type": "air",    "from": 6,  "weight": 1.5, "late": 2.2},
	{"type": "immune", "from": 7,  "weight": 1.5, "late": 2.2},
	{"type": "regen",  "from": 9,  "weight": 1.5, "late": 1.5},
	{"type": "tank",   "from": 10, "weight": 2.0, "late": 2.4},
	{"type": "split",  "from": 11, "weight": 1.5, "late": 2.0},
	{"type": "warden", "from": 22, "weight": 1.5, "late": 3.0},
	{"type": "wisp",   "from": 24, "weight": 1.5, "late": 2.5},
	{"type": "gale",   "from": 27, "weight": 1.2, "late": 2.0},
	{"type": "roc",    "from": 28, "weight": 1.0, "late": 1.8},
]

## Where the late weights begin taking over and where they are fully in force. The first is
## the wave after the seed table's last teaching wave; the second sits before the run's end,
## so the closing stretch is played at the finished mix rather than still drifting into it.
const LATE_FROM := 25
const LATE_FULL := 34

## How many previous waves an archetype may not repeat from. At 0 the generator rolled the
## same creature three waves running often enough to read as the game being stuck — which is
## exactly the complaint this file exists to answer, and no amount of weight tuning fixes it,
## because independent rolls are SUPPOSED to clump.
const REPEAT_WINDOW := 2

## A boss lands on every Nth wave, forever. The seed table's own bosses sit on 10 and 20 so
## the cadence never changes when the generator takes over.
const BOSS_EVERY := 10

## Armour elements, cycled rather than rolled. Rolling produced runs with the same element
## three waves running, which reads as the game being stuck rather than as variety — and a
## player who built to counter it gets a free ride. Cycling guarantees the counter-building
## decision comes up evenly.
## Ordered around Game.ELEMENT_BEATS, so consecutive waves ask for adjacent answers on the
## damage circle rather than jumping across it.
const ELEMENT_CYCLE: Array = ["water", "fire", "nature", "earth"]

## An elite wave trades count for individual strength. Deliberately rare: it is a spike, and
## a spike stops reading as one if it happens often.
const ELITE_EVERY := 7
## 2.0 (was 1.6). The elite wave is the run's spike and it landed softer than the archetype
## multipliers around it — a x1.6 elite is a smaller step than the x3.4 a tank already brings.
## At 2.0 the four elite waves (28/35/42/49) are the ones a board has to be BUILT for.
const ELITE_HP := 1.75
const ELITE_COUNT := 0.55

## A MIXED wave: a second archetype makes up ESCORT_FRAC of the line, spread through the
## spawn order by WaveManager._build_plan.
##
## This is the biggest single source of variety in this file — ten archetypes make ten kinds
## of wave, ten archetypes with an escort make ninety — and the only one that changes the
## FIGHT rather than the roster: two questions at once is a different problem from either
## question on its own, so a primary the player has met five times still arrives as something
## new. Held back to ESCORT_FROM so the first half of the run keeps teaching one thing at a
## time, and kept off boss waves, where the boss is already the wave's second question.
const ESCORT_FROM := 26
## 0.70 / 0.38 (were 0.55 / 0.32). Two archetypes at once is the variety knob that changes the
## FIGHT rather than the roster, and after the late weights above were re-aimed at the
## question-asking archetypes it is also how those questions arrive together — a warden knot
## escorting a fast line asks for damage and for time in the same wave.
const ESCORT_CHANCE := 0.70
const ESCORT_FRAC := 0.38

var _run_seed: int = 0
## Memo of the archetype chosen per wave. The anti-repeat rule has to know what the PREVIOUS
## waves actually rolled, and the chain is walked forward from the first generated wave rather
## than recursed backwards — so purity still holds: the same seed gives the same answer, in
## any order, however many times it is asked.
var _types: Dictionary = {}

func _init(run_seed: int = 0) -> void:
	_run_seed = run_seed

## The wave definition for wave `n`, in Game.WAVES' format. Only called for n past the seed
## table; WaveManager serves earlier waves from the table itself.
func wave_def(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# Mixed rather than added so neighbouring waves in the same run, and the same wave in
	# neighbouring runs, don't land on adjacent seeds and roll near-identical waves.
	rng.seed = hash(str(_run_seed) + ":" + str(n))

	var def := {"type": _type_for(n)}
	# Air waves stay neutral: make_flying() overwrites the body tint, so an element colour
	# on a flyer would be silently lost (see enemy.gd make_flying). This asks the archetype's
	# own `air` flag, not the literal name "air" — gale and roc are flyers too, and giving
	# either an element would put a colour in the wave PREVIEW that the neutral creeps never
	# wear (WaveManager drops the element for any flyer at spawn, so it would be a lie).
	if not bool(Game.WAVE_TYPES[String(def["type"])].get("air", false)):
		def["element"] = String(ELEMENT_CYCLE[n % ELEMENT_CYCLE.size()])
	if n % BOSS_EVERY == 0:
		def["boss"] = true
	elif n >= ESCORT_FROM and rng.randf() < ESCORT_CHANCE:
		# Not on a boss wave: the boss IS that wave's second question, and a mixed escort
		# behind it buries the one thing the wave is there to teach.
		var escort := _pick_escort(rng, n, String(def["type"]))
		if escort != "":
			def["escort"] = escort
			def["escort_frac"] = ESCORT_FRAC
	if n % ELITE_EVERY == 0 and n % BOSS_EVERY != 0 and (n - 1) % BOSS_EVERY != 0:
		# Elite, but never on a boss wave (the boss IS that wave's spike) and never on the
		# wave straight AFTER one. Without the second guard the very first generated wave —
		# 21, right off the wave-20 boss — is always elite, which playtested as a wall:
		# the player has just spent everything surviving a boss and immediately meets a
		# 1.6x-HP wave. The wave before a boss may still be elite; that ramps in, which is
		# the opposite problem and reads fine.
		def["hp"] = ELITE_HP
		def["count"] = ELITE_COUNT
	return def

## The archetype for wave `n`, with the anti-repeat rule applied.
##
## Walks the chain forward from the first generated wave, memoising as it goes, because the
## rule is about what the NEIGHBOURING waves actually rolled and a wave's own seed cannot know
## that on its own. Bounded work — a Standard run generates about thirty waves — and asked at
## most twice per wave in practice, since WaveManager caches the finished definition too.
func _type_for(n: int) -> String:
	if _types.has(n):
		return String(_types[n])
	var recent: Array = []
	for i in range(Game.WAVES.size() + 1, n + 1):
		if not _types.has(i):
			var r := RandomNumberGenerator.new()
			# A separate stream from wave_def's own rng. Sharing one would tie which
			# archetype a wave rolls to whether it also rolled an escort.
			r.seed = hash(str(_run_seed) + ":type:" + str(i))
			_types[i] = _pick_type(r, i, recent)
		recent.append(_types[i])
		if recent.size() > REPEAT_WINDOW:
			recent.pop_front()
	return String(_types.get(n, "normal"))

## This archetype's roll weight at wave `n`: its early `weight` drifting to its `late` one
## across LATE_FROM..LATE_FULL.
func _weight(entry: Dictionary, n: int) -> float:
	var t: float = clampf((float(n) - float(LATE_FROM))
			/ float(maxi(LATE_FULL - LATE_FROM, 1)), 0.0, 1.0)
	return lerpf(float(entry["weight"]), float(entry.get("late", entry["weight"])), t)

## Weighted pick from the archetypes unlocked by wave `n`, skipping anything in `exclude` —
## the last REPEAT_WINDOW waves' archetypes, or the primary when picking an escort.
##
## The exclusion is DROPPED rather than enforced when it would empty the pool. That cannot
## happen at REPEAT_WINDOW 2 against ten entries, but a floor that silently returns "normal"
## forever is exactly what a future `from` threshold would trip over.
func _pick_type(rng: RandomNumberGenerator, n: int, exclude: Array = []) -> String:
	var total := 0.0
	for entry in POOL:
		if n >= int(entry["from"]) and not exclude.has(entry["type"]):
			total += _weight(entry, n)
	if total <= 0.0:
		return _pick_type(rng, n)
	var roll := rng.randf() * total
	for entry in POOL:
		if n < int(entry["from"]) or exclude.has(entry["type"]):
			continue
		roll -= _weight(entry, n)
		if roll <= 0.0:
			return String(entry["type"])
	return "normal"  # unreachable while POOL has a "from": 1 entry; a safe floor regardless

## The second archetype in a mixed wave, or "" if none is eligible. Excludes the primary — an
## escort of the same creature is just a longer wave — and rolls off the same late-weighted
## table, so an escort is usually one of the archetypes that asks a question rather than more
## Normals walking behind the ones already there.
func _pick_escort(rng: RandomNumberGenerator, n: int, primary: String) -> String:
	var pick := _pick_type(rng, n, [primary])
	return "" if pick == primary else pick
