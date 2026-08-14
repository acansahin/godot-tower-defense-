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
const POOL: Array = [
	{"type": "normal", "from": 1,  "weight": 3.0},
	{"type": "fast",   "from": 3,  "weight": 2.5},
	{"type": "swarm",  "from": 4,  "weight": 2.0},
	{"type": "air",    "from": 6,  "weight": 1.5},
	{"type": "immune", "from": 7,  "weight": 1.5},
	{"type": "regen",  "from": 9,  "weight": 1.5},
	{"type": "tank",   "from": 10, "weight": 2.0},
	{"type": "split",  "from": 11, "weight": 1.5},
]

## A boss lands on every Nth wave, forever. The seed table's own bosses sit on 10 and 20 so
## the cadence never changes when the generator takes over.
const BOSS_EVERY := 10

## Armour elements, cycled rather than rolled. Rolling produced runs with the same element
## three waves running, which reads as the game being stuck rather than as variety — and a
## player who built to counter it gets a free ride. Cycling guarantees the counter-building
## decision comes up evenly.
const ELEMENT_CYCLE: Array = ["fire", "water", "nature", "earth"]

## An elite wave trades count for individual strength. Deliberately rare: it is a spike, and
## a spike stops reading as one if it happens often.
const ELITE_EVERY := 7
const ELITE_HP := 1.6
const ELITE_COUNT := 0.55

var _run_seed: int = 0

func _init(run_seed: int = 0) -> void:
	_run_seed = run_seed

## The wave definition for wave `n`, in Game.WAVES' format. Only called for n past the seed
## table; WaveManager serves earlier waves from the table itself.
func wave_def(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# Mixed rather than added so neighbouring waves in the same run, and the same wave in
	# neighbouring runs, don't land on adjacent seeds and roll near-identical waves.
	rng.seed = hash(str(_run_seed) + ":" + str(n))

	var def := {"type": _pick_type(rng, n)}
	# Air waves stay neutral: make_flying() overwrites the body tint, so an element colour
	# on a flyer would be silently lost (see enemy.gd make_flying).
	if def["type"] != "air":
		def["element"] = String(ELEMENT_CYCLE[n % ELEMENT_CYCLE.size()])
	if n % BOSS_EVERY == 0:
		def["boss"] = true
	elif n % ELITE_EVERY == 0 and (n - 1) % BOSS_EVERY != 0:
		# Elite, but never on a boss wave (the boss IS that wave's spike) and never on the
		# wave straight AFTER one. Without the second guard the very first generated wave —
		# 21, right off the wave-20 boss — is always elite, which playtested as a wall:
		# the player has just spent everything surviving a boss and immediately meets a
		# 1.6x-HP wave. The wave before a boss may still be elite; that ramps in, which is
		# the opposite problem and reads fine.
		def["hp"] = ELITE_HP
		def["count"] = ELITE_COUNT
	return def

## Weighted pick from the archetypes unlocked by wave `n`.
func _pick_type(rng: RandomNumberGenerator, n: int) -> String:
	var total := 0.0
	for entry in POOL:
		if n >= int(entry["from"]):
			total += float(entry["weight"])
	var roll := rng.randf() * total
	for entry in POOL:
		if n < int(entry["from"]):
			continue
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return String(entry["type"])
	return "normal"  # unreachable while POOL has a "from": 1 entry; a safe floor regardless
