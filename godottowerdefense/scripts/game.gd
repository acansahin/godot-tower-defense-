extends Node
## Global game state + shared constants.
## Registered as the "Game" autoload (see project.godot), so every script can
## read the shared map layout and the current gold/lives without passing
## references around.

signal gold_changed(amount: int)
signal lives_changed(amount: int)
## The run ended — lives hit zero. There is no `victory` counterpart: waves are endless, so
## a run is always ended by the player running out of lives, and `wave_reached` is the score.
signal game_over
## Camera kick in pixels. Broadcast here so an Enemy can ask for one without knowing
## anything about the level's camera; Main owns the actual Camera2D.
signal shake_requested(amount: float)

const SCREEN_SIZE := Vector2(1280, 720)

# Waypoints that define the S-shaped road. Enemies walk these in order.
# First point is off-screen left (spawn), last is off-screen right (exit).
#
# The two bend x's (840, 232) are not round numbers, and the exact values matter:
# each one is placed so that TWO columns of cells fit on the narrow outer side of
# the turn instead of one. Cells tile outward from a bend at ROAD_HALF +
# CELL_WIDTH*0.5 = 88 and then step by 96, and grid.gd drops any that would fall
# off the board, so the second column lands exactly on the boundary — 840 puts it
# at 1024, whose right edge is PLAY_RIGHT; 232 puts it at 48, whose left edge is 0.
# Move either bend 8px the wrong way and that outer column silently disappears.
const PATH: Array = [
	Vector2(-144, 112),
	Vector2(840, 112),
	Vector2(840, 368),
	Vector2(232, 368),
	Vector2(232, 624),
	Vector2(1424, 624),
]

# Grid placement: towers snap to cells drawn faintly on the grass, flush against
# the road. The whole board is sized for touch: on a landscape phone the 1280x720
# design viewport stretches by ~0.5, so a 96x88 cell lands at ~48x44 CSS px —
# right at the minimum comfortable tap target. Everything else in the game is
# drawn to match that scale.
const CELL_WIDTH := 96.0         ## Column width (px); columns step by this.
const ROAD_HALF := 40.0          ## Road stone half-width; cell edges tile flush to this.
## Min distance from a cell centre to the road centre-line. A cell flush BESIDE a
## vertical road sits at ROAD_HALF + CELL_WIDTH*0.5 = 88; one flush ABOVE or BELOW a
## horizontal road sits at ROAD_HALF + cell_height*0.5 = 84. This has to clear the
## smaller of the two, with a little slack — the check is `>=` and leaning on float
## equality would be fragile. Nothing is generated between 82 and 84, so the slack
## costs nothing.
const ROAD_CLEARANCE := 82.0
## Right edge of the buildable area. The tower palette is anchored to the right of
## the screen, so the grid stops short of it — otherwise cells sit under the panel
## where they cannot be seen and (because the panel eats the click) the towers on
## them could never be upgraded or sold.
const PLAY_RIGHT := 1072.0

# Build-grid rows as Vector2(centre_y, cell_height). The three horizontal roads sit
# at y = 112 / 368 / 624, and the rows come in PAIRS filling the gap between them.
#
# The pairing is the whole point: a bend's vertical leg runs from one horizontal road
# to the next, so the number of rows it passes is the number of cells you get down the
# narrow outer side of that turn. One row per gap gave a 2x1 corner; two gives 2x2.
#
# The vertical budget is exact and leaves no room to be generous. Between the HUD bar
# (ends at 40) and the bottom-corner buttons (start at 664) there are 624px, and
# 4 rows x 88 + 3 roads x 80 = 592 uses all but 32 of it. That last 32 is grass above
# the top road, and it is load-bearing: without it a boss on the top road would draw
# its health bar up behind the HUD. Rows are 88 rather than 96 tall to pay for it —
# still ~44 CSS px on a phone, so the tap target survives.
const GRID_ROWS: Array = [
	Vector2(196.0, 88.0), Vector2(284.0, 88.0),  # between the top & middle roads
	Vector2(452.0, 88.0), Vector2(540.0, 88.0),  # between the middle & bottom roads
]
## Column bounds for a row NO vertical road crosses. Every row in the current layout is
## crossed by a bend and so tiles outward from it instead; these stay for a row placed
## clear of both bends.
const GRID_COL_START := 64.0     ## First column centre.
const GRID_COL_END := 1024.0     ## Last column centre (= PLAY_RIGHT - CELL_WIDTH * 0.5).

# START_GOLD / START_LIVES moved to the Balance autoload with the rest of the economy —
# see scripts/balance.gd. This file keeps the map geometry and the data tables.

# --- Element tower definitions -------------------------------------------------
# Every tower (base element or dual combination) is just a data entry.
#
# The six base elements carry the ORIGINAL Element TD v2.0 numbers — see
# docs/element-td-data.md, re-derivable with tools/extract_w3x.py. Two things about
# that data drive everything else:
#
#   * `range` is in WARCRAFT III units, not pixels. Read sites multiply by
#     Balance.WC3_RANGE_SCALE (tower.gd `_recompute`, main.gd's range preview), so
#     retuning the board scale is one constant rather than six literals.
#   * The six sit at nearly equal DPS and differ only in range and cadence. Fire is
#     short and quick, Water is a stream of tiny hits, Light and Darkness reach four
#     times as far as Fire, and Darkness buys the biggest single hit with a 2.75s
#     wind-up. Do not "fix" one of these to match the others — the spread IS the design.
#
# DEPARTURE FROM THE MAP: in the original the six base elements are plain attackers,
# and slow / poison / splash arrive only with the dual towers (Ice, Poison, Lava...).
# Eight duals now exist, but they arrive mid-run behind two element cards — stripping
# the effects off Water, Nature and Earth would leave the opening waves with no crowd
# control at all. They keep their effects; the numbers are faithful, the payloads ours.
#
# `damage_tiers` lists the damage at each of the five tiers EXPLICITLY rather than
# deriving them from a growth multiplier. Tiers 1-4 are exact x5 steps and Pure is x10,
# but the map's Pure row was clearly hand-typed and lands a few points short of its own
# rule (Pure Water is 12491 where x10 would give 12500). A multiplier cannot reproduce
# that, and a faithful port reproduces the map including its typos. A def without this
# key falls back to Balance.TIER_DAMAGE_MULT.
#
# Fields: name, cost, color, damage / damage_tiers, range, interval, can_hit_flying,
#   splash_radius/splash_factor (AoE), slow_factor/slow_time (0..1 = slower),
#   slow_splash (Lv2+ radius the slow ALSO spreads to — slow only, no damage),
#   poison_dps/poison_time (damage over time),
#   stun_chance/stun_time (chance to freeze the enemy in place). Missing = "off".
const TOWER_DEFS := {
	"fire": {
		"name": "Fire", "cost": 50, "color": Color(0.95, 0.45, 0.18), "element": "fire",
		"damage_tiers": [23, 115, 575, 2875, 28750],
		"range": 500.0, "interval": 0.33,
	},
	"water": {
		"name": "Water", "cost": 50, "color": Color(0.30, 0.60, 0.95), "element": "water",
		"damage_tiers": [10, 50, 250, 1250, 12491],
		"range": 750.0, "interval": 0.17,
		"slow_factor": 0.55, "slow_time": 1.4,
	},
	"nature": {
		"name": "Nature", "cost": 50, "color": Color(0.35, 0.80, 0.35), "element": "nature",
		"damage_tiers": [66, 330, 1650, 8250, 82490],
		"range": 750.0, "interval": 0.99,
		"poison_dps": 10.0, "poison_time": 3.0,
	},
	"earth": {
		"name": "Earth", "cost": 50, "color": Color(0.72, 0.55, 0.34), "element": "earth",
		"damage_tiers": [55, 275, 1375, 6875, 68741],
		"range": 750.0, "interval": 1.0, "can_hit_flying": false,
		"splash_radius": 108.0, "splash_factor": 0.5,
	},
	## Reaches four times as far as Fire for the same DPS. On our board that is over
	## half the width — the map's boards are much larger, so this is the number whose
	## meaning changes most in the port. Measure before tuning.
	"light": {
		"name": "Light", "cost": 50, "color": Color(1.0, 0.96, 0.72), "element": "light",
		"damage_tiers": [50, 250, 1250, 6250, 62491],
		"range": 2000.0, "interval": 0.99,
	},
	## Same reach as Light, and the largest single hit in the game — but it lands once
	## every 2.75s, so a leaker that walks out of range between shots costs a full cycle.
	"darkness": {
		"name": "Darkness", "cost": 50, "color": Color(0.45, 0.28, 0.62), "element": "darkness",
		"damage_tiers": [165, 825, 4125, 20625, 206241],
		"range": 2000.0, "interval": 2.75,
	},
	# --- Dual towers ---------------------------------------------------------------
	# Not in TOWER_ORDER: a dual becomes buildable when the player owns both of its
	# elements deeply enough (see DUAL_RECIPES and Run.buildable_towers). Costs and
	# damage are the map's tier-1 dual numbers.
	#
	# Range and interval are OURS, not the map's. Most duals inherit those two fields
	# from their Warcraft III base unit instead of overriding them, so the object data
	# simply does not contain them — resolving them would mean reading war3.mpq's own
	# unit table. Damage, cost and recipe are ported; reach and cadence are set to sit
	# between the two parent elements, which is what they read as in play.
	"ice": {  # Water + Light
		"name": "Ice", "cost": 275, "color": Color(0.60, 0.90, 0.98),
		"damage": 150.0, "range": 900.0, "interval": 0.75,
		"slow_factor": 0.4, "slow_time": 2.0,
		"splash_radius": 96.0, "splash_factor": 0.5,
		"slow_splash": 135.0,  # from Lv2 the chill spreads to enemies within this radius
	},
	"steam": {  # Fire + Water
		"name": "Steam", "cost": 275, "color": Color(0.70, 0.82, 0.95),
		"damage": 150.0, "range": 625.0, "interval": 0.4,
		"splash_radius": 120.0, "splash_factor": 0.6,
		"poison_dps": 40.0, "poison_time": 2.5,  # "gradually reduces health"
	},
	"lava": {  # Fire + Earth
		"name": "Lava", "cost": 275, "color": Color(0.92, 0.35, 0.20),
		"damage": 751.0, "range": 625.0, "interval": 1.4, "can_hit_flying": false,
		"splash_radius": 132.0, "splash_factor": 0.6,
		"poison_dps": 90.0, "poison_time": 2.5,  # incinerate
	},
	"poison": {  # Water + Darkness
		"name": "Poison", "cost": 275, "color": Color(0.55, 0.75, 0.30),
		"damage": 500.0, "range": 1375.0, "interval": 1.2,
		"slow_factor": 0.6, "slow_time": 1.6,
		"poison_dps": 160.0, "poison_time": 3.0,
	},
	"clay": {  # Water + Earth — the map gives this one an explicit 1.05s cooldown
		"name": "Clay", "cost": 275, "color": Color(0.80, 0.62, 0.45),
		"damage": 600.0, "range": 750.0, "interval": 1.05,
		"slow_factor": 0.7, "slow_time": 1.2,
	},
	"tech": {  # Earth + Darkness — explicit 0.50s cooldown in the map; "rapidfire"
		"name": "Tech", "cost": 275, "color": Color(0.62, 0.66, 0.72),
		"damage": 350.0, "range": 1375.0, "interval": 0.5,
	},
	"roots": {  # Earth + Nature — explicit 8.10s cooldown; entangles, ground only
		"name": "Roots", "cost": 275, "color": Color(0.45, 0.60, 0.28),
		"damage": 100.0, "range": 750.0, "interval": 2.2, "can_hit_flying": false,
		"slow_factor": 0.25, "slow_time": 2.6,
	},
	"electricity": {  # Light + Fire — the map's only dual with an explicit range (1200)
		"name": "Electricity", "cost": 275, "color": Color(1.0, 0.9, 0.25),
		"damage": 570.0, "range": 1200.0, "interval": 0.8,
		"stun_chance": 0.2, "stun_time": 0.8,
	},

	# --- Locked: Lightning -----------------------------------------------------
	# NOT BUILDABLE and not a map tower: the map has no neutral stunner, it has Lightning
	# as tier 2 of Light + Fire (our `electricity`). This entry is ours, kept because the
	# roguelite pool can still grant it. Range is in WC3 units like everything else.
	"lightning": {  # chance to stun; the map has Lightning as tier 2 of Light + Fire
		"name": "Lightning", "cost": 70, "color": Color(1.0, 0.9, 0.25),
		"damage": 14.0, "range": 794.0, "interval": 0.7,
		"stun_chance": 0.25, "stun_time": 1.2,
	},
}
## The buildable roster, in palette order. The six elements ARE the game's identity, so
## the palette is exactly them — no duals, no Lightning. Anything not listed here cannot be
## built, previewed or paid for, even though TOWER_DEFS still describes it.
## Ordered around the damage circle (see ELEMENT_BEATS) rather than alphabetically, so the
## palette itself teaches which element answers which.
const TOWER_ORDER: Array = ["light", "darkness", "water", "fire", "nature", "earth"]

# --- Dual recipes ---------------------------------------------------------------
# All fifteen pairs of the six elements, with the map's own names. The towers state
# their recipe in their own tooltips ("( Water + Light )"), so this is read data, not
# a guess — `python tools/extract_w3x.py <map> recipes` prints it.
#
# The map gates towers by ELEMENT OWNERSHIP, not by combining two placed towers: each
# element is a research track you level up (war3map.j's `Element_Upgrade[0..5]`, raised
# by killing bosses), and owning the elements is what makes a recipe buildable. Run
# mirrors that — see Run.elements and Run.buildable_towers().
#
# Only the ids that also have a TOWER_DEFS entry can actually be built. The other seven
# are listed because the recipe is real and the table should be complete; each needs a
# TowerBehavior that does not exist yet:
#   moon / sun   (Light+Darkness, Fire+Nature) — buff an adjacent tower
#   well         (Water+Nature)                — attack-speed aura
#   money        (Light+Earth)                 — bounty on kill
#   life         (Light+Nature)                — kills restore lives
#   death        (Nature+Darkness)             — chance to instantly kill
#   magic        (Fire+Darkness)               — banks mana into burst damage
const DUAL_RECIPES := {
	"moon": ["light", "darkness"],
	"electricity": ["light", "fire"],
	"ice": ["light", "water"],
	"money": ["light", "earth"],
	"life": ["light", "nature"],
	"steam": ["fire", "water"],
	"lava": ["fire", "earth"],
	"sun": ["fire", "nature"],
	"magic": ["fire", "darkness"],
	"clay": ["water", "earth"],
	"well": ["water", "nature"],
	"poison": ["water", "darkness"],
	"roots": ["earth", "nature"],
	"tech": ["earth", "darkness"],
	"death": ["nature", "darkness"],
}
## Element level at which an element counts toward a recipe. Every element starts the run
## at 1 so all six towers are buildable from the first wave; a dual therefore needs BOTH of
## its elements raised once past the start, which is what the choice screen's element cards
## are for. The map starts you at zero elements and hands them out for boss kills — we keep
## the opening playable instead, the same class of departure as Balance.START_GOLD.
const DUAL_ELEMENT_LEVEL := 2

# --- Wave definitions ----------------------------------------------------------
# Each wave picks an archetype from WAVE_TYPES; its stats = the base scaling
# (quadratic HP etc. in wave_manager) times the archetype's multipliers. Fields
# (all optional, default 1.0 / false / 0):
#   name, color, hp, spd, count, radius, cc_immune, regen (frac of max hp/s),
#   split (children on death), air (all flyers).
const WAVE_TYPES := {
	## Wave 1 only. Few, slow and soft enough that a single tower clears it comfortably —
	## its job is to let the player watch a tower acquire, fire and kill without pressure
	## while the tutorial hints run. Never picked by the generator.
	"tutorial": {"name": "Scout", "color": Color(0.80, 0.55, 0.45),
			"hp": 0.45, "spd": 0.7, "count": 0.5},
	"normal": {"name": "Normal", "color": Color(0.85, 0.30, 0.30)},
	"fast":   {"name": "Fast",   "color": Color(0.95, 0.85, 0.25), "hp": 0.6, "spd": 1.7, "count": 1.3, "radius": 0.85},
	"swarm":  {"name": "Swarm",  "color": Color(0.90, 0.50, 0.75), "hp": 0.35, "spd": 1.15, "count": 2.6, "radius": 0.8},
	"tank":   {"name": "Tank",   "color": Color(0.45, 0.50, 0.55), "hp": 3.0, "spd": 0.6, "count": 0.4, "radius": 1.35},
	"immune": {"name": "Immune", "color": Color(0.60, 0.62, 0.70), "hp": 1.15, "count": 0.85, "cc_immune": true},
	"regen":  {"name": "Regen",  "color": Color(0.35, 0.75, 0.40), "hp": 1.0, "count": 0.8, "regen": 0.035},
	"air":    {"name": "Air",    "color": Color(0.72, 0.78, 0.96), "air": true},
	"split":  {"name": "Splitter","color": Color(0.85, 0.55, 0.25), "hp": 1.0, "count": 0.6, "split": 2, "radius": 1.15},
}

## The SEED TABLE: the hand-authored opening of a run. A run does not end here — past the
## last entry, WaveGenerator takes over and produces waves forever (see wave_generator.gd).
## These exist so the first minutes are *taught* rather than rolled: each new mechanic
## arrives on its own wave, in a deliberate order, instead of whenever the dice say.
##
## Wave 1 is the tutorial. Then one idea at a time: speed, numbers, the element matchup,
## flyers, CC immunity, regeneration, splitting — and the first boss on 10, which is the
## cadence the generator keeps forever after.
##
## "element" (optional) is the wave's armor element (empty/absent = neutral); early waves
## and all Air waves stay neutral so element colour doesn't clash with the archetype tint.
const WAVES: Array = [
	{"type": "tutorial"},                              # 1  — learn to build
	{"type": "normal"},                                # 2  — a real wave, still gentle
	{"type": "fast"},                                  # 3  — speed
	{"type": "swarm"},                                 # 4  — numbers
	{"type": "normal", "element": "fire"},             # 5  — first armour element
	{"type": "air"},                                   # 6  — flyers: ground-only towers miss
	{"type": "immune", "element": "nature"},           # 7  — slow/stun stop working
	{"type": "fast", "element": "earth"},              # 8
	{"type": "regen", "element": "water"},             # 9  — must out-damage the heal
	{"type": "tank", "boss": true, "element": "water"},# 10 — FIRST BOSS
	{"type": "split", "element": "nature"},            # 11 — splitters
	{"type": "tank", "element": "earth"},              # 12
	{"type": "air"},                                   # 13
	{"type": "immune", "element": "water"},            # 14
	{"type": "fast", "element": "fire"},               # 15
	{"type": "regen", "element": "nature"},            # 16
	{"type": "split", "element": "earth"},             # 17
	{"type": "swarm", "element": "water"},             # 18
	{"type": "tank", "element": "fire", "hp": 0.85},   # 19 — mild trim so 20 reads as the spike
	{"type": "swarm", "boss": true, "element": "fire"},# 20 — SECOND BOSS, then the generator
]

# --- Roguelite upgrade pool ----------------------------------------------------
# Offered three at a time between waves; the player keeps one, and it lasts the run.
# Adding an upgrade is a row here — Run folds the effects generically and the choice
# screen renders whatever it is handed, so neither needs to know this one exists.
#
# Fields:
#   id          unique; also the key stacking is counted against
#   name/desc   what the card shows. `desc` must state the real number — a card whose
#               text and effect disagree is worse than no card
#   rarity      common | rare | epic | legendary (weights live in Balance)
#   effects     list of {stat, op, value}; see TowerMods.fold for the stats
#   element     optional — restrict to towers of this damage element
#   tower       optional — restrict to this exact tower id
#   unlock      optional — grants a tower id instead of applying effects
#   max_stacks  optional (default 1) — how many times it may be taken in one run
#   min_wave    optional — not offered before this wave
#
# An entry with neither `element` nor `tower` applies to every tower, which is why the
# global ones cost a higher rarity than their single-element equivalents.
const UPGRADE_POOL: Array = [
	# --- Common: one element, one stat -----------------------------------------
	{"id": "fire_dmg", "name": "Ember Focus", "rarity": "common", "max_stacks": 4,
		"element": "fire", "desc": "Fire towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "water_dmg", "name": "Deep Current", "rarity": "common", "max_stacks": 4,
		"element": "water", "desc": "Water towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "nature_dmg", "name": "Thornbloom", "rarity": "common", "max_stacks": 4,
		"element": "nature", "desc": "Nature towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "earth_dmg", "name": "Bedrock", "rarity": "common", "max_stacks": 4,
		"element": "earth", "desc": "Earth towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "light_dmg", "name": "Sunspear", "rarity": "common", "max_stacks": 4,
		"element": "light", "desc": "Light towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "darkness_dmg", "name": "Umbral Weight", "rarity": "common", "max_stacks": 4,
		"element": "darkness", "desc": "Darkness towers deal +25% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.25}]},
	{"id": "all_range", "name": "Long Sight", "rarity": "common", "max_stacks": 3,
		"desc": "All towers gain +18 range",
		"effects": [{"stat": "range", "op": "add", "value": 18.0}]},
	{"id": "gold_kill", "name": "Scavenger", "rarity": "common", "max_stacks": 5,
		"desc": "+2 gold for every enemy killed",
		"effects": [{"stat": "gold_per_kill", "op": "add", "value": 2.0}]},

	# --- Rare: a mechanic rather than a flat stat -------------------------------
	{"id": "fire_speed", "name": "Wildfire", "rarity": "rare", "max_stacks": 3,
		"element": "fire", "desc": "Fire towers attack 25% faster",
		"effects": [{"stat": "attack_speed", "op": "mult", "value": 1.25}]},
	{"id": "nature_poison", "name": "Virulence", "rarity": "rare", "max_stacks": 3,
		"element": "nature", "desc": "Nature poison deals +50% damage",
		"effects": [{"stat": "poison", "op": "mult", "value": 1.5}]},
	{"id": "water_slow", "name": "Undertow", "rarity": "rare", "max_stacks": 2,
		"element": "water", "desc": "Water slows 30% harder",
		"effects": [{"stat": "slow_power", "op": "mult", "value": 1.3}]},
	{"id": "earth_splash", "name": "Shockwave", "rarity": "rare", "max_stacks": 3,
		"element": "earth", "desc": "Earth splash radius +35%",
		"effects": [{"stat": "splash", "op": "mult", "value": 1.35}]},
	{"id": "all_dmg_small", "name": "Attunement", "rarity": "rare", "max_stacks": 3,
		"desc": "All towers deal +15% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.15}]},

	# --- Epic: the first tower unlocks, and real global power -------------------
	# --- Element cards ----------------------------------------------------------
	# These grant no stats. They raise an element track, and every dual recipe the new
	# level completes becomes buildable (Game.DUAL_RECIPES, Run.dual_available). Two
	# cards therefore open between one and four towers depending on which pair is hit,
	# which is the decision the map's element research is built around.
	#
	# max_stacks 1: a second level in the same element unlocks nothing further, so
	# offering it again would be a dead card.
	{"id": "elem_light", "name": "Light Elemental", "rarity": "epic",
		"raise_element": "light", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Light. Unlocks its duals once the partner element is raised too"},
	{"id": "elem_darkness", "name": "Darkness Elemental", "rarity": "epic",
		"raise_element": "darkness", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Darkness. Unlocks its duals once the partner element is raised too"},
	{"id": "elem_water", "name": "Water Elemental", "rarity": "epic",
		"raise_element": "water", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Water. Unlocks its duals once the partner element is raised too"},
	{"id": "elem_fire", "name": "Fire Elemental", "rarity": "epic",
		"raise_element": "fire", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Fire. Unlocks its duals once the partner element is raised too"},
	{"id": "elem_nature", "name": "Nature Elemental", "rarity": "epic",
		"raise_element": "nature", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Nature. Unlocks its duals once the partner element is raised too"},
	{"id": "elem_earth", "name": "Earth Elemental", "rarity": "epic",
		"raise_element": "earth", "min_wave": 3, "max_stacks": 1,
		"desc": "Raise Earth. Unlocks its duals once the partner element is raised too"},
	{"id": "all_speed", "name": "Quickening", "rarity": "epic", "max_stacks": 2,
		"desc": "All towers attack 20% faster",
		"effects": [{"stat": "attack_speed", "op": "mult", "value": 1.2}]},
	{"id": "all_dmg_big", "name": "Convergence", "rarity": "epic", "max_stacks": 2,
		"desc": "All towers deal +35% damage",
		"effects": [{"stat": "damage", "op": "mult", "value": 1.35}]},

	# --- Legendary: run-defining ------------------------------------------------
	{"id": "unlock_lightning", "name": "Lightning", "rarity": "legendary",
		"unlock": "lightning", "min_wave": 12,
		"desc": "Unlocks the Lightning tower — 25% chance to freeze an enemy in place"},
	{"id": "overcharge", "name": "Overcharge", "rarity": "legendary", "max_stacks": 1,
		"desc": "All towers: +50% damage, +25 range, 15% faster",
		"effects": [
			{"stat": "damage", "op": "mult", "value": 1.5},
			{"stat": "range", "op": "add", "value": 25.0},
			{"stat": "attack_speed", "op": "mult", "value": 1.15},
		]},
]

# --- Workshop: permanent upgrades ----------------------------------------------
# Bought with Essence between runs and applied at the start of every run afterwards.
# Levels are cumulative: owning level 3 folds the entry's `effects` three times, which is
# why every effect here has to be a per-level step rather than a total.
#
# Tower-stat effects go through exactly the same TowerMods.fold as the roguelite cards —
# permanent and temporary power share one path, so there is one place to reason about how
# they stack. `start_gold` and `start_lives` are run-start values instead and are read
# directly by Meta; they are not tower stats and must not be folded.
#
# Fields: id, name, desc (%s is replaced by the per-level step), max_level, base_cost,
#         cost_growth (cost of level n = base_cost * cost_growth^n), effects.
const WORKSHOP_DEFS: Array = [
	{"id": "forge", "name": "Forge", "desc": "+6% tower damage per level",
		"max_level": 10, "base_cost": 20, "cost_growth": 1.55,
		"effects": [{"stat": "damage", "op": "mult", "value": 1.06}]},
	{"id": "tempo", "name": "Tempo", "desc": "+4% attack speed per level",
		"max_level": 8, "base_cost": 30, "cost_growth": 1.65,
		"effects": [{"stat": "attack_speed", "op": "mult", "value": 1.04}]},
	{"id": "lens", "name": "Lens", "desc": "+6 tower range per level",
		"max_level": 8, "base_cost": 25, "cost_growth": 1.5,
		"effects": [{"stat": "range", "op": "add", "value": 6.0}]},
	{"id": "treasury", "name": "Treasury", "desc": "+20 starting gold per level",
		"max_level": 10, "base_cost": 18, "cost_growth": 1.45,
		"effects": [{"stat": "start_gold", "op": "add", "value": 20.0}]},
	{"id": "ramparts", "name": "Ramparts", "desc": "+2 starting lives per level",
		"max_level": 8, "base_cost": 35, "cost_growth": 1.7,
		"effects": [{"stat": "start_lives", "op": "add", "value": 2.0}]},
]

# --- Element matchup -----------------------------------------------------------
# A tower's damage element vs an enemy's armour element gives a multiplier (see
# element_mult). Neutral ("") on either side = x1, so Lightning / dual towers and
# early/air waves are unaffected.
## The damage circle from Element TD: Light -> Darkness -> Water -> Fire -> Nature ->
## Earth -> Light. Each element beats the next one round; being beaten is the weak side.
## With six elements every element still has exactly one strength and one weakness, so
## the shape of the matchup is unchanged from the four-element version — there are just
## more armour types a wave can wear, and two more answers to carry.
const ELEMENT_BEATS := {
	"light": "darkness", "darkness": "water", "water": "fire",
	"fire": "nature", "nature": "earth", "earth": "light",
}
const ELEMENT_COLORS := {
	"fire": Color(0.95, 0.45, 0.18), "water": Color(0.30, 0.60, 0.95),
	"nature": Color(0.35, 0.80, 0.35), "earth": Color(0.72, 0.55, 0.34),
	"light": Color(1.0, 0.96, 0.72), "darkness": Color(0.45, 0.28, 0.62),
}
const ELEMENT_STRONG := 1.75
## Mismatched element damage. Kept fairly gentle on purpose: at 0.6 a wave whose armour
## countered the player's main element (notably the water waves vs. the cheap, popular
## Fire tower) inflated its effective HP by 67%, which read as a difficulty spike rather
## than a prompt to diversify.
const ELEMENT_WEAK := 0.7

## Damage multiplier for attacker element `atk` hitting armour element `def`.
func element_mult(atk: String, def: String) -> float:
	if atk == "" or def == "":
		return 1.0
	if ELEMENT_BEATS.get(atk, "") == def:
		return ELEMENT_STRONG
	if ELEMENT_BEATS.get(def, "") == atk:
		return ELEMENT_WEAK
	return 1.0

var gold: int = 0
var lives: int = 0
var is_over: bool = false
## Highest wave this run actually started. The run summary's headline number, and the basis
## for the permanent-currency award once meta progression lands.
var wave_reached: int = 0
# The all-time best wave now lives in Meta, where it is persisted along with the rest of
# the permanent progression — see Meta.best_wave.

## Cumulative distance from PATH[0] to each waypoint, built once in _ready(). Towers
## rank enemies by how far along the road they are (the First / Last targeting modes)
## off this table, so no enemy has to carry its own odometer.
var _path_cum: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_path_cum.resize(PATH.size())
	for i in range(1, PATH.size()):
		_path_cum[i] = _path_cum[i - 1] + (PATH[i] as Vector2).distance_to(PATH[i - 1])

## How far along the road a walker is, in pixels — higher means closer to the exit.
## `target_index` is the waypoint it is currently heading for, `pos` where it is now.
## Since enemies walk each leg in a straight line, the distance back to the previous
## waypoint is exactly how far into that leg they are.
func path_progress(target_index: int, pos: Vector2) -> float:
	var i: int = clampi(target_index, 1, PATH.size() - 1)
	return _path_cum[i - 1] + pos.distance_to(PATH[i - 1])

## Shortest distance from `p` to the road centre-line. Shared because two very
## different things need it: the build grid rejects cells that would sit on the
## stone, and the map scatters its flora only where the road is not.
func dist_to_road(p: Vector2) -> float:
	var best := INF
	for i in range(PATH.size() - 1):
		best = minf(best, _dist_point_segment(p, PATH[i], PATH[i + 1]))
	return best

func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func reset() -> void:
	# The Workshop's Treasury / Ramparts levels land here rather than in Balance: they are
	# permanent progression, not a tuning constant, and this is the one place a run begins.
	gold = Balance.START_GOLD + Meta.bonus_start_gold()
	lives = Balance.START_LIVES + Meta.bonus_start_lives()
	is_over = false
	wave_reached = 0

## Asks the level for a short camera kick (boss deaths, leaks).
func request_shake(amount: float) -> void:
	shake_requested.emit(amount)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func lose_life(amount: int = 1) -> void:
	lives = max(0, lives - amount)
	lives_changed.emit(lives)
	if lives == 0 and not is_over:
		is_over = true
		game_over.emit()
