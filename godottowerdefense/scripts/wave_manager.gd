extends Node
class_name WaveManager
## Spawns waves of enemies with growing count and difficulty. Uses plain Timer
## nodes (freed automatically on scene reload) instead of coroutines so a
## restart never leaves a spawn loop running.
##
## A Standard run is Balance.STANDARD_WAVES long (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4) and
## can be WON: clearing the last wave calls Game.declare_victory() instead of queuing another.
##
## Its waves come from TWO sources and _wave_def() is the seam. Game.WAVES, the hand-authored
## seed table, teaches one archetype at a time and runs out well before the last wave;
## WaveGenerator supplies every wave after it, which at STANDARD_WAVES 50 is more than half
## the run. Game.apply_milestone() has the last word over both.

## Main swaps the board from this synchronous signal before this wave's stats are derived.
signal wave_starting(number: int)
signal wave_started(number: int)
signal wave_preview(text: String, color: Color)  ## Describes the next wave for the HUD.
signal prep_started                ## The between-waves gap began (send-early available).

const ENEMY := preload("res://scenes/Enemy.tscn")

# Wave pacing, the HP/speed/count scaling curve, the gold economy and the boss stat
# multipliers all live in the Balance autoload — see scripts/balance.gd. Which waves get
# a boss is still set per-wave in Game.WAVES ("boss": true).

## Node that spawned enemies are parented to (assigned by Main before start()).
var enemies_root: Node

var _wave: int = 0
var _to_spawn: int = 0
var _alive: int = 0
var _spawn_timer: Timer
var _prep_timer: Timer

# Parameters for the wave currently spawning.
var _hp: float = 0.0
var _spd: float = 0.0
var _reward: int = 0
var _interval: float = 0.6
var _tint: Color = Color.WHITE
var _type_def: Dictionary = {}  ## The current wave's PRIMARY WAVE_TYPES entry.
var _kind: String = ""          ## Which WAVE_TYPES key that is.
var _art_over: String = ""      ## Optional wave-level painted sprite override ("" = none).
var _base_hp: float = 0.0       ## The wave's scaling HP before any archetype multiplier.
var _base_spd: float = 0.0      ## Likewise for speed.
var _hp_over: float = 1.0       ## The wave row's own `hp` multiplier (elite waves, tuning).
## One WAVE_TYPES key per creep still to spawn, popped front-to-back by _spawn_one.
##
## A wave used to be one archetype repeated N times, which is why waves 21-50 read as the
## same eight fights on a loop. A generated wave past Balance.MIDPOINT_BOSS_WAVE may now
## carry an `escort` — a second archetype making up `escort_frac` of the count, spread
## through the line rather than blocked at one end — so the late run asks two questions at
## once and the same primary archetype makes a different wave each time it comes round.
var _plan: Array = []
var _element: String = ""       ## The current wave's armor element ("" = neutral).
var _lives_at_start: int = 0    ## Lives when the wave began (for the leak-free bonus).
## True once this wave's avatar boss has been KILLED. Reset at the start of every wave, and
## the only thing that unlocks an element for fusion. It exists because Enemy.removed fires
## for a leak exactly as it does for a death — without this flag a player who let the boss
## walk off the end would be rewarded identically to one who killed it.
var _avatar_defeated: bool = false
## Gold when the previous wave began, so --fill-board can report income per wave rather than
## a running total dominated by its own placement grant. Harness bookkeeping only.
var _gold_at_last_wave: int = 0
var _generator: WaveGenerator = null  ## Supplies every wave past the seed table.
## Cache of generated definitions, keyed by wave number. The generator is pure so this is
## only a speed-up, not a correctness fix — but a wave gets asked for at least twice (once
## as next-wave preview, once when it starts) and the preview text re-derives it again.
var _generated: Dictionary = {}

func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_spawn_one)
	add_child(_spawn_timer)

	_prep_timer = Timer.new()
	_prep_timer.one_shot = true
	_prep_timer.timeout.connect(_start_wave)
	add_child(_prep_timer)

## Begins the run. `run_seed` selects which endless waves this run will roll; the same seed
## replays the same run, which is what makes a balance complaint reproducible.
func start(run_seed: int = 0) -> void:
	_generator = WaveGenerator.new(run_seed)
	wave_preview.emit(_preview_text(1), _preview_color(1))
	_queue_next_wave()

## The definition for wave `n`: the hand-authored seed table while it lasts, the generator
## forever after, with Game.apply_milestone() having the last word either way. All three
## return the same Dictionary shape, so nothing downstream has to know which one answered —
## and a boss can land on wave 40 without WaveGenerator knowing bosses exist.
func _wave_def(n: int) -> Dictionary:
	var base: Dictionary
	if n <= Game.WAVES.size():
		base = Game.WAVES[n - 1]
	else:
		if not _generated.has(n):
			_generated[n] = _generator.wave_def(n)
		base = _generated[n]
	return Game.apply_milestone(n, base)

func _queue_next_wave() -> void:
	# No upper bound: the run is endless and ends only when the player runs out of lives.
	_prep_timer.start(_prep_time_for(_wave + 1))
	prep_started.emit()

## Build time before wave `n`. Wave 1 gets a longer gap: the player has never seen the
## palette, and the default 4 seconds is not enough to read it, drag a tower and aim.
func _prep_time_for(n: int) -> float:
	return Balance.FIRST_PREP_TIME if n <= 1 else Balance.PREP_TIME

## Skips the prep countdown and starts the next wave now, for a small bonus.
## Only valid during the between-waves gap.
func send_now() -> void:
	if _prep_timer.is_stopped():
		return
	_prep_timer.stop()
	Audio.play("send_early")
	Game.add_gold(Balance.early_call_bonus(_wave + 1))
	_start_wave()

func _start_wave() -> void:
	_wave += 1
	Game.wave_reached = _wave
	wave_starting.emit(_wave)
	var def: Dictionary = _wave_def(_wave)
	_kind = String(def["type"])
	_art_over = String(def.get("art", ""))
	_type_def = Game.WAVE_TYPES[_kind]
	# Base scaling (quadratic HP so towers must keep pace) x archetype multipliers.
	# The curve itself lives in Balance; the archetype and per-wave multipliers below
	# stack on top of it, so a single wave can be smoothed without rebalancing the whole
	# archetype (which is shared across several waves).
	_base_hp = Balance.wave_hp(_wave, Game.ruleset)
	_base_spd = Balance.wave_speed(_wave, Game.ruleset)
	_hp_over = float(def.get("hp", 1.0))
	# _hp / _spd stay the PRIMARY archetype's numbers: the boss is built from them, and so is
	# the harness line below. Every ordinary creep derives its own from _base_* and whichever
	# archetype the spawn plan hands it, which is what lets an escort be a different creature
	# rather than a recoloured copy of the primary.
	_hp = _base_hp * float(_type_def.get("hp", 1.0)) * _hp_over
	_spd = _base_spd * float(_type_def.get("spd", 1.0))
	_reward = Balance.wave_reward(_wave)
	_interval = Balance.spawn_interval(_wave)
	_to_spawn = _spawn_count(_wave, _type_def, def)
	_plan = _build_plan(def, _to_spawn)
	# Element waves colour the body by element; neutral waves keep the archetype colour.
	# An avatar-boss wave carries no `element` in the table on purpose — it takes this run's
	# draw instead (Run.boss_elements), which is what makes the four avatars arrive in a
	# different order every run. The whole wave takes that element, not just the boss, so the
	# colour of what is walking down the road tells the player which fusion is at stake.
	_element = String(def.get("element", ""))
	if _element == "" and String(def.get("boss_rule", "")) == "element_avatar":
		_element = Run.boss_element_for_wave(_wave)
	if _element != "":
		_tint = Game.ELEMENT_COLORS.get(_element, Color.WHITE)
	else:
		_tint = _type_def.get("color", Color.WHITE)
	_lives_at_start = Game.lives
	_avatar_defeated = false
	if OS.get_cmdline_user_args().has("--fill-board"):
		var art_note: String = " art=%s" % _art_over if _art_over != "" else ""
		var escort_note: String = " +%s x%d" % [String(def["escort"]),
				_plan.count(String(def["escort"]))] if def.has("escort") else ""
		# `earned` is the CHANGE since the last wave began, not Game.gold: --fill-board grants
		# a million-gold lump so placement never fails, and printing the absolute would be a
		# column of 1000119, 1000209, ... that reads like an economy and measures nothing. The
		# delta is real income — kill bounties, the leak-free bonus and interest — and since a
		# maxed board leaks nothing, it is the best upper bound the harness suite has on what a
		# run can afford — an upper bound and nothing more. For what a PLAYER earns while
		# building up gradually, and leaking, run `--play-sim` instead.
		print("wave %d: %s%s%s el=%s%s  hp=%.0f spd=%.0f count=%d  earned=%+d" % [_wave,
				String(def["type"]), art_note, escort_note,
				_element if _element != "" else "-", "  BOSS" if def.get("boss", false) else "",
				_hp, _spd, _to_spawn, Game.gold - _gold_at_last_wave])
		_gold_at_last_wave = Game.gold
	Audio.play("wave_start")
	wave_started.emit(_wave)
	wave_preview.emit(_preview_text(_wave + 1), _preview_color(_wave + 1))
	if def.get("boss", false):
		_spawn_boss(def)             # milestone centrepiece
	# A solo avatar wave has no ordinary creeps to pace out, and starting the timer for them
	# would tick once into a spawner that immediately stops itself.
	if _to_spawn > 0:
		_spawn_one()                 # first enemy immediately
		_spawn_timer.start(_interval)  # the rest on a cadence

func _spawn_one() -> void:
	if Game.is_over or _to_spawn <= 0:
		_spawn_timer.stop()
		return
	_to_spawn -= 1
	# Which creature this particular spawn is. Everything below reads `t`, not `_type_def`,
	# so the escort is a real archetype with its own HP, speed, size and traits rather than
	# the primary wearing another colour.
	var kind: String = String(_plan.pop_front()) if not _plan.is_empty() else _kind
	var t: Dictionary = Game.WAVE_TYPES[kind]
	var hp := _base_hp * float(t.get("hp", 1.0)) * _hp_over
	var spd := _base_spd * float(t.get("spd", 1.0))
	var flying: bool = t.get("air", false)
	# make_flying() overwrites the body tint, so an element colour on a flyer is silently
	# lost — armour the player cannot see. Air waves have always stayed neutral for this
	# reason; an air ESCORT on an element wave has to follow the same rule, and does it by
	# being genuinely neutral rather than by hiding an element it still carries.
	var elem := "" if flying else _element
	var tint: Color = Color.WHITE
	if elem != "":
		tint = Game.ELEMENT_COLORS.get(elem, Color.WHITE)
	else:
		tint = t.get("color", Color.WHITE)
	var art_over := _art_over if kind == _kind else ""
	var enemy := ENEMY.instantiate() as Enemy
	enemy.setup(hp, spd, _reward, tint)
	enemy.armor_element = elem
	enemy.kind = kind
	enemy.art_override = art_over
	enemy.radius = Balance.ENEMY_BASE_RADIUS * float(t.get("radius", 1.0))
	enemy.cc_immune = t.get("cc_immune", false)
	var regen := float(t.get("regen", 0.0))
	if regen > 0.0:
		enemy.regen_dps = hp * regen
	enemy.heal_aura = float(t.get("heal_aura", 0.0))
	enemy.heal_radius = float(t.get("heal_radius", 0.0))
	enemy.blink_distance = float(t.get("blink", 0.0))
	enemy.blink_every = float(t.get("blink_every", 0.0))
	enemy.split_into = int(t.get("split", 0))
	if flying:
		enemy.make_flying()
	if enemy.split_into > 0:
		# Bound, not read off the wave: with an escort in the line the splitter that just died
		# is not necessarily the wave's primary archetype, and its halves have to inherit ITS
		# picture and armour rather than the wave's.
		enemy.split_requested.connect(_spawn_child.bind(kind, art_over, elem))
	enemy.removed.connect(_on_enemy_removed)
	enemies_root.add_child(enemy)
	_alive += 1
	if _to_spawn <= 0:
		_spawn_timer.stop()

## The spawn order for this wave: one WAVE_TYPES key per creep. Plain repetition of the
## primary archetype unless the wave carries an `escort`, in which case `escort_frac` of the
## line becomes that second archetype, SPREAD EVENLY rather than blocked at one end — a block
## is two small waves in a row, which is the thing this is here to stop being.
##
## Guarded on a count of 4: below that a fraction rounds to the whole wave or to nothing, and
## a two-creep wave that is one of each reads as a bug rather than as a mixed wave.
func _build_plan(def: Dictionary, count: int) -> Array:
	var plan: Array = []
	for i in count:
		plan.append(_kind)
	var want := _escort_count(def, count)
	if want <= 0:
		return plan
	var escort := String(def["escort"])
	var step := float(count) / float(want)
	for i in want:
		plan[int(floor((float(i) + 0.5) * step))] = escort
	return plan

## How many of `count` spawns the wave's escort takes, or 0 for a single-archetype wave.
## Shared by the spawn plan and the HUD preview so the label cannot promise a mix the wave
## does not deliver — the same reason _spawn_count is shared.
func _escort_count(def: Dictionary, count: int) -> int:
	var escort := String(def.get("escort", ""))
	if escort == "" or escort == String(def["type"]) or not Game.WAVE_TYPES.has(escort):
		return 0
	if count < 4:
		return 0
	return clampi(int(round(float(count) * float(def.get("escort_frac", 0.3)))), 1, count - 1)

## Spawns a splitter's children where it died, continuing along the path. The last three
## arguments are bound at connect time (see _spawn_one) and describe the PARENT, not the wave.
func _spawn_child(pos: Vector2, progress: int, count: int, hp: float, spd: float, tint: Color, r: float,
		kind: String, art_over: String, elem: String) -> void:
	if Game.is_over:
		return
	for i in count:
		var c := ENEMY.instantiate() as Enemy
		c.setup(hp, spd, Balance.SPLIT_CHILD_REWARD, tint)
		c.armor_element = elem      # children share their parent's element
		c.kind = kind               # and its art: a splitter's halves match their parent
		c.art_override = art_over
		c.radius = r
		c.removed.connect(_on_enemy_removed)
		enemies_root.add_child(c)  # _ready puts it at PATH[0]; override below
		c.global_position = pos + Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		c.set_progress(progress)
		_alive += 1

## How many enemies wave `n` spawns: the base count scaled by the archetype's `count`
## multiplier and then the per-wave override. Shared by the spawner and the HUD preview —
## these used to be two copies of the formula, and the preview could drift from the wave
## it was describing.
##
## A wave may ask for NO ordinary creeps at all by setting `count` to 0, which is how an
## element avatar walks the road alone (Game.apply_milestone). That case has to short-circuit
## before the clamp below, whose floor of 1 exists so a rounding-down never produces an empty
## ordinary wave — it would otherwise put one creep back beside the avatar.
func _spawn_count(n: int, type_def: Dictionary, wave_def: Dictionary) -> int:
	if float(wave_def.get("count", 1.0)) <= 0.0:
		return 0
	var raw := int(round(Balance.wave_count(n, Game.ruleset)
			* float(type_def.get("count", 1.0)) * float(wave_def.get("count", 1.0))))
	return clampi(raw, 1, Balance.MAX_SPAWN_COUNT)

## HUD text describing wave `n`. Guards Balance.STANDARD_WAVES + 1 specifically: `_start_wave`
## previews wave 21 the moment wave 20 begins, and without this a Standard run would show a
## generated wave for a fight that Game.declare_victory() means will never happen.
func _preview_text(n: int) -> String:
	if n > Balance.STANDARD_WAVES:
		return tr("WAVE_FINAL")
	var def: Dictionary = _wave_def(n)
	# An avatar wave is one boss and nothing else, so "x12" would be a lie. Naming its ELEMENT
	# here is the point of the reveal: the four arrive in a random order, and this prep gap is
	# the only chance the player gets to build the counter the avatar demands.
	if String(def.get("boss_rule", "")) == "element_avatar":
		var avatar := Run.boss_element_for_wave(n)
		if avatar == "":
			return tr("WAVE_AVATAR_UNKNOWN") + "  BOSS"
		return tr("WAVE_AVATAR") % avatar.capitalize() + "  BOSS"
	var t: Dictionary = Game.WAVE_TYPES[def["type"]]
	var cnt := _spawn_count(n, t, def)
	var boss := "  BOSS" if def.get("boss", false) else ""
	# An elite wave is a per-wave HP override with no boss flag — worth calling out, since
	# the count drops at the same time and the wave would otherwise look easier, not harder.
	var elite := "  ELITE" if not def.get("boss", false) and float(def.get("hp", 1.0)) > 1.0 else ""
	var elem := String(def.get("element", ""))
	var epfx := (elem.capitalize() + " ") if elem != "" else ""
	# A mixed wave names BOTH creatures. The escort is the whole reason a late wave is not the
	# fight the player has already had with this primary, so a preview that hid it would be
	# describing the wrong wave.
	var mix := ""
	var esc := _escort_count(def, cnt)
	if esc > 0:
		var et: Dictionary = Game.WAVE_TYPES[String(def["escort"])]
		mix = " + %s x%d" % [String(et.get("name", def["escort"])), esc]
		cnt -= esc
	return tr("HUD_NEXT") % ("%s%s x%d%s%s%s" % [epfx,
			str(def.get("name", t.get("name", def["type"]))), cnt, mix, boss, elite])

## Colour for the preview label: the wave's element, or a default gold if neutral.
func _preview_color(n: int) -> Color:
	if n > Balance.STANDARD_WAVES:
		return Color(0.95, 0.9, 0.7)
	var def: Dictionary = _wave_def(n)
	var elem := String(def.get("element", ""))
	# An avatar carries no `element` in its definition — it takes this run's draw — so the
	# label would stay neutral gold on the one wave whose element matters most.
	if elem == "" and String(def.get("boss_rule", "")) == "element_avatar":
		elem = Run.boss_element_for_wave(n)
	if elem != "":
		return Game.ELEMENT_COLORS.get(elem, Color(0.95, 0.9, 0.7))
	return Color(0.95, 0.9, 0.7)

## Spawns one boss for the current wave. Not counted in _to_spawn — it is an
## extra enemy tracked via _alive, so the wave only clears once it dies too.
##
## `def["boss_rule"]` (GAME_STRATEGY_V2.md §10.4, BUILD NEXT #7) picks the boss's one rule:
## "control_immune" (Muhafız, wave 10) reuses Enemy.cc_immune directly — it already blocks
## slow/stun/knockback and already carries its own full visual (Enemy._draw_ward), so the
## boss needed no new mechanism, just the existing flag. "rotating_armor" (Uyanmış Muhafız,
## wave 20) sets Enemy.rotating_armor, which cycles armor_element on its own from there.
## "element_avatar" (waves 3/7/11/15) is the fusion ladder's gate: killing it unlocks its
## element. Its combat rule needs no code at all — its armor_element IS its element, so the
## matchup table already makes it demand the counter element and shrug off the one it beats.
func _spawn_boss(def: Dictionary) -> void:
	if Game.is_over:
		return
	var rule := String(def.get("boss_rule", ""))
	var avatar := rule == "element_avatar"
	var boss := ENEMY.instantiate() as Enemy
	# Avatar bosses are deliberately softer than the two set-piece bosses: four of them, the
	# first on wave 3, and losing one already costs an element for the whole run.
	var hp_mult := Balance.ELEMENT_BOSS_HP_MULT if avatar else Balance.BOSS_HP_MULT
	var reward_mult := Balance.ELEMENT_BOSS_REWARD_MULT if avatar else Balance.BOSS_REWARD_MULT
	boss.setup(_hp * hp_mult, _spd * Balance.BOSS_SPEED_MULT,
			_reward * reward_mult,
			Game.ELEMENT_COLORS.get(_element, Balance.BOSS_TINT) if avatar else Balance.BOSS_TINT)
	boss.armor_element = _element
	# A boss is an archetype wearing a crown — unless it is an element avatar and that
	# element's own sheet has been painted, which Enemy.art_kind() decides off avatar_element
	# below. Set that BEFORE the node enters the tree, since the art set is resolved once.
	boss.kind = _kind
	boss.art_override = _art_over
	boss.radius = Balance.BOSS_RADIUS
	boss.life_cost = Balance.ELEMENT_BOSS_LIFE_COST if avatar else Balance.BOSS_LIFE_COST
	boss.is_boss = true
	match rule:
		"control_immune": boss.cc_immune = true
		"rotating_armor": boss.rotating_armor = true
		"element_avatar": boss.avatar_element = _element
	if avatar:
		# Captured by the lambda so the handler knows WHICH enemy reported in — plain
		# `removed` says only that something left play, and a leak emits it exactly as a
		# death does. `boss` is still a live node when the signal fires (Enemy emits before
		# queue_free), which is why reading the flag here is safe.
		boss.removed.connect(func() -> void: _avatar_defeated = boss.was_killed)
	boss.removed.connect(_on_enemy_removed)
	enemies_root.add_child(boss)
	Audio.play("boss_spawn")
	_alive += 1

func _on_enemy_removed() -> void:
	_alive -= 1
	if Game.is_over:
		return
	# Wave is cleared once nothing is left to spawn and nothing is alive.
	if _to_spawn <= 0 and _alive <= 0:
		# The avatar's reward is paid on wave CLEAR, not on the boss's own death, so the
		# element arrives at the moment the player is free to spend it — during prep, with
		# the panel one tap away — rather than mid-fight.
		if _avatar_defeated:
			Run.beat_avatar(_element)
			_avatar_defeated = false
		_grant_wave_rewards()
		# Standard mode ends in a win here (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4) — no
		# next wave queued. Past this point WaveGenerator (the endless tail past Game.WAVES)
		# is unreachable from a Standard run; it stays in the codebase for the Endless mode
		# BUILD NEXT #8 adds.
		if _wave >= Balance.STANDARD_WAVES:
			Game.declare_victory()
			return
		_queue_next_wave()

## Leak-free bonus + interest on banked gold, granted when a wave is cleared.
func _grant_wave_rewards() -> void:
	Audio.play("wave_clear")
	if Game.lives == _lives_at_start:
		Game.add_gold(Balance.LEAK_FREE_BONUS)
	# Compound (GAME_STRATEGY_V2.md §6.3, BUILD NEXT #9) adds to the RATE, not the cap — the
	# cap is a pacing ceiling independent of how the run got there.
	var rate := Balance.INTEREST_RATE + Run.interest_rate_add()
	var interest := mini(Balance.INTEREST_CAP, int(Game.gold * rate))
	if interest > 0:
		Game.add_gold(interest)
