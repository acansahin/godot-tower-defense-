extends Node2D
## Wires the level together: grid-based tower placement (drag from the palette
## onto a cell), click-to-upgrade / tap-the-× to sell, and the HUD, then kicks off
## the waves.

const TOWER := preload("res://scenes/Tower.tscn")
const SHAKE_DECAY := 26.0  ## Pixels of camera shake bled off per second.

@onready var grid = $Grid
@onready var map = $Map
@onready var enemies_root: Node2D = $Enemies
@onready var towers_root: Node2D = $Towers
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: HUD = $UI/HUD
@onready var palette = $UI/TowerPalette
@onready var end_screen: EndScreen = $UI/EndScreen
@onready var tower_panel: TowerPanel = $UI/TowerPanel
@onready var camera: Camera2D = $Camera2D
@onready var preview = $Preview  ## Drag ghost.

var _drag_kind: String = ""  ## Tower type being dragged from the palette ("" = none).
var _hovered: Tower = null   ## Tower under the mouse, drawn with a clear range ring.
var _shake: float = 0.0      ## Current camera shake magnitude in px; decays to 0.
## Harness only (--fill-board/--auto-pick): buy every fusion a tower is offered as soon as it
## is affordable, so an unattended run exercises the whole ladder up to Pure.
var _auto_pick: bool = false
## Harness only (`--play-sim`): drives the simulated player. See _play_sim().
var _play_sim_on: bool = false
var _sim_spend_clock: float = 0.0
var _sim_next_element: int = 0
## How often the simulated player checks whether it can afford anything, in game seconds.
const SIM_SPEND_EVERY := 0.5
## Standard mode's one board (GAME_STRATEGY_V2.md §28 Phase 1: "1 harita", BUILD NEXT #8).
## `Game.use_board_for_wave()`'s 10-wave winding->spiral->s rotation (Game.BOARD_SEQUENCE)
## is now Endless-only infrastructure, unreached from here — same treatment step 4 gave
## WaveGenerator. A Standard run stays on this board from wave 1 through Balance.STANDARD_WAVES.
const STANDARD_BOARD := "winding"

## Harness only (`--map:s`): holds one board for a focused playtest instead of the default.
var _board_override: String = ""

func _ready() -> void:
	get_tree().paused = false
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--map:"):
			_board_override = String(arg).trim_prefix("--map:")
	Game.use_board(STANDARD_BOARD if _board_override == "" else _board_override)
	# One seed drives both the waves and the card offers, so a whole run — what it throws at
	# you and what it lets you answer with — replays from a single number.
	var run_seed := randi()
	Game.reset()
	Run.reset(run_seed)

	hud.set_gold(Game.gold)
	hud.set_lives(Game.lives)
	palette.set_gold(Game.gold)

	Game.gold_changed.connect(hud.set_gold)
	Game.gold_changed.connect(palette.set_gold)
	Game.lives_changed.connect(hud.set_lives)
	Game.game_over.connect(_on_game_over)
	Game.victory.connect(_on_victory)
	wave_manager.wave_starting.connect(_on_wave_starting)
	wave_manager.wave_started.connect(hud.set_wave)
	wave_manager.wave_preview.connect(hud.set_next)
	wave_manager.prep_started.connect(hud.enable_send)
	hud.send_pressed.connect(wave_manager.send_now)
	palette.drag_started.connect(_on_drag_started)
	Game.shake_requested.connect(_add_shake)
	# The pad overlay hides the pad a tower stands on, so it has to redraw whenever the set
	# of towers changes — built, sold, or moved by a board swap.
	grid.towers = towers_root
	Game.towers_changed.connect(grid.queue_redraw)

	# The tower panel only reports what was pressed; spending the gold and changing the board
	# stays here, so there is exactly one place that mutates a tower.
	tower_panel.upgrade_pressed.connect(_on_panel_upgrade)
	tower_panel.fusion_pressed.connect(_on_panel_fusion)
	tower_panel.sell_pressed.connect(_on_panel_sell)
	Run.avatar_beaten.connect(_on_avatar_beaten)

	# Frame the WHOLE world, once. There is no panning: a tower defense you have to scroll
	# is one where the leak that just cost you a life happened somewhere you were not
	# looking. The world is a 16:9 box like the viewport, so a single zoom fits it exactly
	# on both axes with nothing cropped and no letterboxing.
	camera.position = Game.WORLD_SIZE * 0.5
	camera.zoom = Vector2.ONE * minf(Game.SCREEN_SIZE.x / Game.WORLD_SIZE.x,
			Game.SCREEN_SIZE.y / Game.WORLD_SIZE.y)

	wave_manager.enemies_root = enemies_root
	wave_manager.start(run_seed)
	if OS.get_cmdline_user_args().has("--show-road"):
		map.show_road = true
		map.queue_redraw()

	# Must run BEFORE any dump. Meta's Workshop levels feed Run.permanent, which feeds every
	# tower stat — so a --dump-stats taken against a save with purchases in it is measuring
	# something different from one taken against a clean save. Wipe first when comparing to
	# a stored baseline.
	if OS.get_cmdline_user_args().has("--wipe-save"):
		Save.clear()
		Meta._load()
		Run.reset(0)
		Game.reset()
	if OS.get_cmdline_user_args().has("--dump-stats"):
		_dump_tower_stats()
	if _fill_board_requested():
		_fill_board()
	if OS.get_cmdline_user_args().has("--air-pose"):
		_air_pose()
	if OS.get_cmdline_user_args().has("--boss-pose"):
		_boss_pose()
	if OS.get_cmdline_user_args().has("--avatar-pose"):
		_avatar_pose()
	if OS.get_cmdline_user_args().has("--bolt-pose"):
		_bolt_pose()
	if OS.get_cmdline_user_args().has("--hit-pose"):
		_hit_pose()
	# TEMPORARY: buys every fusion the moment it is unlocked and affordable, so an unattended
	# run climbs the ladder to Pure instead of finishing on four base towers. Nothing pauses
	# the tree any more (the three popups that did are gone), so unlike the old card screen
	# this is no longer required just to keep a delayed `--shot:N` alive.
	if OS.get_cmdline_user_args().has("--auto-pick"):
		_auto_pick = true
	if OS.get_cmdline_user_args().has("--play-sim"):
		_play_sim()
	if OS.get_cmdline_user_args().has("--dump-waves"):
		_dump_waves()
	if OS.get_cmdline_user_args().has("--dump-board"):
		_dump_board()
	if OS.get_cmdline_user_args().has("--dump-fusions"):
		_dump_fusions()
	if OS.get_cmdline_user_args().has("--dump-ladder"):
		_dump_ladder()
	if OS.get_cmdline_user_args().has("--dump-bosses"):
		_dump_bosses()
	if OS.get_cmdline_user_args().has("--dump-matchup"):
		_dump_matchup()
	if OS.get_cmdline_user_args().has("--dump-meta"):
		_dump_meta()
	# TEMPORARY: rewinds the "last seen" stamp so the NEXT launch collects an offline
	# reward. The only way to exercise _collect_offline without waiting hours or changing
	# the system clock — and offline is a feature whose bugs are all in the time arithmetic.
	if OS.get_cmdline_user_args().has("--go-back"):
		Meta.last_seen -= 4 * 3600
		Meta._persist()
		print("--- clock rewound 4h; relaunch to collect ---")
	if OS.get_cmdline_user_args().has("--show-fusion-panel"):
		call_deferred("_show_fusion_panel", true)
	# The same board, left unfused at Lv2 with its own element locked: the state that draws
	# the dim "beat the Fire avatar" row next to the fusion rows.
	if OS.get_cmdline_user_args().has("--show-locked-upgrade"):
		call_deferred("_show_fusion_panel", false)
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shot"):
			# `--shot` grabs the opening board; `--shot:20` waits 20 seconds first, which is
			# how you photograph a wave in flight rather than an empty map. Several may be
			# passed at once — each lands in its own file — which is how you watch a run
			# through several waves without relaunching once per wave.
			var parts := String(arg).split(":")
			if parts.size() > 1:
				_save_screenshot(float(parts[1]), "shot_%s.png" % parts[1])
			else:
				_save_screenshot(1.0)

## WaveManager emits this before deriving stats or creating the first enemy. Used to also
## rotate the board by wave chapter; a Standard run now stays on STANDARD_BOARD for its whole
## length (see _ready()), so this is a no-op every wave (Game.use_board() already short-
## circuits on the board it is already showing) except to keep the `number` parameter's
## signal shape intact for whatever Endless mode reconnects here later.
func _on_wave_starting(number: int) -> void:
	var previous_board := Game.active_board_id
	Game.use_board(STANDARD_BOARD if _board_override == "" else _board_override)
	grid.queue_redraw()
	if previous_board == Game.active_board_id:
		return
	var moved := _relocate_towers_for_board()
	Game.towers_changed.emit()
	hud.set_hint(tr("HUD_NEW_MAP") % Game.active_board_id.capitalize()
			+ (tr("HUD_TOWERS_MOVED") % moved if moved > 0 else ""))
	_clear_map_hint_later()
	if _fill_board_requested():
		print("--- MAP CHANGE @ wave %d: %s (%d towers moved) ---"
				% [number, Game.active_board_id, moved])

## Keeps the player's investment through a chapter change without leaving a tower standing
## in the new road, water or blocked scenery. Legal towers stay exactly where the player put
## them; only invalid ones move to the nearest open position on a fine placement sweep.
func _relocate_towers_for_board() -> int:
	var occupied: Array = []
	var displaced: Array[Tower] = []
	for child in towers_root.get_children():
		var tower := child as Tower
		if tower == null:
			continue
		if Game.can_build_at(tower.position):
			occupied.append(tower.position)
		else:
			displaced.append(tower)
	var candidates := _buildable_lattice(Game.TOWER_GAP * 0.5)
	var moved := 0
	for tower in displaced:
		var best := Vector2.ZERO
		var best_distance := INF
		var found := false
		for candidate in candidates:
			if not _far_enough(candidate, occupied):
				continue
			var distance := tower.position.distance_squared_to(candidate)
			if distance < best_distance:
				best = candidate
				best_distance = distance
				found = true
		if not found:
			push_warning("No legal relocation position for tower at %s" % tower.position)
			continue
		tower.position = best
		occupied.append(best)
		moved += 1
	return moved

func _clear_map_hint_later() -> void:
	await get_tree().create_timer(4.0).timeout
	hud.set_hint("")

## TEMPORARY: saves one frame of the running game to `user://shot.png` and prints where it
## landed. Every other harness here prints numbers, and numbers cannot see a board — the
## grid overlapping the HUD, a road drawn behind the tower palette, a marker that vanishes
## at phone scale. `--headless` never calls _draw(), so this one must run WITHOUT it:
##
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 150 -- --shot
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 4000 -- --shot:60 --shot:120
##
## The wait is not decoration: the viewport texture is only complete after a frame has been
## drawn, and grabbing it in _ready gives back an empty image.
func _save_screenshot(delay: float, file := "shot.png") -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://" + file
	var err := image.save_png(path)
	if err != OK:
		print("--- SHOT FAILED: ", error_string(err))
		return
	print("--- SHOT: ", ProjectSettings.globalize_path(path))

## TEMPORARY verification harness for the fusion ladder. Replaces the old --dump-mods, which
## measured the roguelite card pool that no longer exists.
##
## Prints every one of Game.FUSIONS' eleven rows at every level, plus the base tower it grew
## from, so the whole table can be read as a ladder rather than eleven unrelated entries. The
## DPS-vs-base column is the one that matters for balance: a dual should sit meaningfully
## above a base tower of the same level, a triple above a dual, and Pure above everything —
## if that ordering ever breaks, it breaks here rather than three hours into a playtest.
##
## Also asserts every FUSIONS key actually resolves. A typo'd key ("earth+watr") would make
## Tower._recompute silently fall back to the base definition, so the tower would keep
## working, keep its old stats, and pocket the player's gold — the hardest kind of bug to see
## by playing.
func _dump_fusions() -> void:
	print("--- FUSION DUMP BEGIN ---")
	# Reference DPS per level for a plain base tower, averaged over the four elements. Every
	# fusion below is reported as a multiple of this, which is what makes the numbers
	# comparable at all — the four elements have very different interval/damage shapes.
	var base_dps := PackedFloat32Array()
	var per_element: Array = []
	for _lv in Balance.MAX_LEVEL:
		base_dps.append(0.0)
	for tid in Game.TOWER_ORDER:
		# ONE tower per element, walked up its levels — not a fresh tower per level. A fresh
		# one per level leaves the earlier ones parented (queue_free only takes effect at the
		# end of the frame) and every probe sits at the same position, so they end up inside
		# each other's aura radius and the "base" reference reads high. That is exactly the
		# kind of quiet 4% the DPS ratios below would then be measured against.
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def(String(tid))
		var row := String(tid).rpad(21)
		for lv in Balance.MAX_LEVEL:
			t.level = lv + 1
			t._recompute()
			var dps := _tower_dps(t)
			base_dps[lv] += dps / float(Game.TOWER_ORDER.size())
			row += "  L%d %7.1f" % [lv + 1, dps]
		per_element.append(row)
		towers_root.remove_child(t)
		t.queue_free()
	for row in per_element:
		print(row)
	var base_line := "base (mean of 4)     ".rpad(21)
	for lv in Balance.MAX_LEVEL:
		base_line += "  L%d %7.1f" % [lv + 1, base_dps[lv]]
	print(base_line)

	# Sorted so duals, then triples, then Pure come out in a stable order run to run —
	# Dictionary iteration order is insertion order here, but sorting makes the output
	# diffable against a stored baseline even if the table is later reordered.
	var keys: Array = Game.FUSIONS.keys()
	keys.sort()
	for key in keys:
		var els: Array = String(key).split("+")
		var def: Dictionary = Game.FUSIONS[key]
		var t := TOWER.instantiate() as Tower
		# Parked far off the board and detached below, for the same reason the base loop is
		# careful: Sun and Well ARE auras, and eleven probes stacked at the origin would buff
		# each other into numbers no real board could produce.
		t.position = Vector2(-9000.0, -9000.0)
		towers_root.add_child(t)
		t.setup_def(String(els[0]))
		for i in range(1, els.size()):
			t.add_element(String(els[i]))
		# The key round-trip: if fusion_key() disagrees with the table's own key, the tower
		# just built is NOT the tower this row describes.
		if Game.fusion_key(t.elements) != String(key):
			push_error("FUSION KEY MISMATCH: table '%s' vs tower '%s'"
					% [key, Game.fusion_key(t.elements)])
		if t.fusion_def().is_empty():
			push_error("FUSION UNRESOLVED: '%s' fell back to the base definition" % key)
		var line := ("%d %s" % [els.size(), String(key)]).rpad(21)
		for lv in range(1, Balance.MAX_LEVEL + 1):
			t.level = lv
			t._recompute()
			line += "  L%d %7.1f x%.1f" % [lv, _tower_dps(t), _tower_dps(t) / base_dps[lv - 1]]
		t.level = 1
		t._recompute()
		print(line)
		print("      %s  rng=%.0f int=%.2f fly=%s%s%s"
				% [Game.fusion_display_name(def).rpad(14), t.tower_range, t.fire_interval,
					"y" if t.can_hit_flying else "n",
					"  CHAOS" if t.ignores_matchup else "",
					"  PIERCES" if t.pierces_rules else ""])
		# The five columns above are what the row COULD do; this is the one it will ever
		# actually do. A fusion's level is fixed by its depth (Balance.FUSED_LEVELS), so
		# exactly one of those tiers is live and the rest are unread — printing which one
		# keeps that visible here rather than only in --dump-ladder.
		var fixed: int = int(Balance.FUSED_LEVELS.get(els.size(), Balance.MAX_LEVEL))
		t.level = fixed
		t._recompute()
		# Pure sits ON MAX_LEVEL, so it is the one row with nothing unread — say so rather
		# than printing the empty range "6..5", which reads as an off-by-one in this dump.
		var dead_tiers := "none"
		if fixed < Balance.MAX_LEVEL:
			dead_tiers = "%d..%d" % [fixed + 1, Balance.MAX_LEVEL]
		var dead_names: Array = Array(def.get("names", [])).slice(1)
		var names_txt := "none"
		if not dead_names.is_empty():
			names_txt = ", ".join(PackedStringArray(dead_names))
		print("      fixed at L%d -> %.1f dps  (unread tiers: %s; unread names: %s)"
				% [fixed, _tower_dps(t), dead_tiers, names_txt])
		t.level = 1
		t._recompute()
		towers_root.remove_child(t)
		t.queue_free()
	print("--- FUSION DUMP END ---")

## Damage per second including the damage-over-time channels, which is the only honest way to
## compare Roots (huge interval, tiny damage, all control) against Infernal (raw damage) or
## Steam (half its output is a poison tick).
func _tower_dps(t: Tower) -> float:
	var dps := t.damage / maxf(t.fire_interval, 0.001)
	return dps + t.poison_dps + t.burn_dps

## TEMPORARY verification harness (`--dump-ladder`): the two roads a tower can walk, side by
## side, with what each step costs and what it buys.
##
## This is the table the avatar gate has to be balanced against, and no other dump shows it.
## --dump-stats reports every tower at all five levels and --dump-fusions reports every
## fusion at all five, because both were written when all five were reachable. Since
## Balance.FREE_LEVEL_CAP and Balance.FUSED_LEVELS landed most of those cells are dead: a
## base tower stops at Lv2 until its OWN avatar falls, and a fusion never levels at all. What
## a player actually chooses between is the two ROADS below, and this prints exactly those.
##
## Both are walked on a real Tower through the real can_upgrade() / can_fuse() / upgrade() /
## add_element(), never by arithmetic over the tables — which is the only reason this dump is
## able to DISAGREE with the game, and so the only reason it is worth reading.
##
##   Godot.exe --headless --path <project> res://scenes/Main.tscn --quit-after 60 -- --wipe-save --dump-ladder
func _dump_ladder() -> void:
	print("--- LADDER DUMP BEGIN ---")
	print("gold is CUMULATIVE from an empty board; dps includes the DoT channels")
	var beaten_before: Array = Run.avatars_beaten.duplicate()
	for tid in Game.TOWER_ORDER:
		var el := String(tid)
		print("")
		print("%s" % el.to_upper())
		# --- depth: its own avatar is down, so it climbs to MAX_LEVEL and never fuses -------
		Run.avatars_beaten.clear()
		Run.beat_avatar(el)
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def(el)
		var spent := t.build_cost
		print("  depth   (its own avatar; fusion closes at Lv%d)" % Balance.FREE_LEVEL_CAP)
		print("    L%d  %-16s %6.0f dmg  %7.1f dps  %6dg"
				% [t.level, t.display_name, t.damage, _tower_dps(t), spent])
		while t.can_upgrade():
			spent += t.upgrade_cost()
			t.upgrade()
			print("    L%d  %-16s %6.0f dmg  %7.1f dps  %6dg"
					% [t.level, t.display_name, t.damage, _tower_dps(t), spent])
		towers_root.remove_child(t)
		t.queue_free()
		# --- breadth: everyone ELSE's avatar is down, so it stops at Lv2 and fuses upward ---
		# Every avatar beaten (not just the others): the depth road above already proved the own
		# element gate, and what this road needs is simply for every absorb to be legal.
		for e2 in Game.TOWER_ORDER:
			Run.beat_avatar(String(e2))
		var f := TOWER.instantiate() as Tower
		towers_root.add_child(f)
		f.setup_def(el)
		var fspent := f.build_cost
		while f.level < Balance.FREE_LEVEL_CAP and f.can_upgrade():
			fspent += f.upgrade_cost()
			f.upgrade()
		print("  breadth (any other avatar; upgrades close on the first fusion)")
		print("    L%d  %-16s %6.0f dmg  %7.1f dps  %6dg"
				% [f.level, f.display_name, f.damage, _tower_dps(f), fspent])
		# Absorb in a rotation that starts one PAST the base element, so the four elements do
		# not all walk the same three combinations — the same trick --fill-board uses.
		var base_at := Game.TOWER_ORDER.find(el)
		for k in Game.TOWER_ORDER.size():
			var cand := String(Game.TOWER_ORDER[(base_at + 1 + k) % Game.TOWER_ORDER.size()])
			if f.elements.has(cand) or not f.can_fuse():
				continue
			fspent += f.fusion_cost()
			f.add_element(cand)
			print("    L%d  %-16s %6.0f dmg  %7.1f dps  %6dg  +%s"
					% [f.level, f.display_name, f.damage, _tower_dps(f), fspent, cand])
		towers_root.remove_child(f)
		f.queue_free()
	print("")
	print("every FUSIONS row at the ONE level it can ever fire at:")
	var keys: Array = Game.FUSIONS.keys()
	keys.sort()
	for key in keys:
		var els: Array = String(key).split("+")
		var p := TOWER.instantiate() as Tower
		towers_root.add_child(p)
		p.setup_def(String(els[0]))
		for j in range(1, els.size()):
			p.elements.append(String(els[j]))
		p.level = int(Balance.FUSED_LEVELS.get(els.size(), Balance.MAX_LEVEL))
		p._recompute()
		# A row whose key does not resolve falls back to the base element and would print a
		# perfectly plausible line, so say so out loud rather than trusting the numbers.
		if p.fusion_def().is_empty():
			push_error("LADDER: '%s' did not resolve to a FUSIONS row" % key)
		print("  %d %-24s L%d  %-16s %6.0f dmg  %7.1f dps"
				% [els.size(), String(key), p.level, p.display_name, p.damage, _tower_dps(p)])
		towers_root.remove_child(p)
		p.queue_free()
	# Left as it was found: this harness is usually run alongside others in one launch, and a
	# ledger it quietly filled would change what every later dump measures.
	Run.avatars_beaten.assign(beaten_before)
	print("--- LADDER DUMP END ---")

## TEMPORARY verification harness for the avatar boss draw. Prints Run.boss_elements for a
## spread of run seeds and checks the two properties the fusion ladder depends on: every
## element appears exactly once (so no element is unreachable and none is offered twice), and
## the seed actually determines the order.
##
## The second one is the reason this exists. Array.shuffle() uses the GLOBAL RNG, so an
## implementation that reached for it would still print four distinct elements — it would just
## print a DIFFERENT four every launch for the same seed, and nothing else in the game would
## ever notice.
func _dump_bosses() -> void:
	print("--- BOSS ORDER DUMP BEGIN ---")
	var first_pass: Array = []
	for seed_value in range(20):
		Run.reset(seed_value)
		var order: Array = Run.boss_elements.duplicate()
		first_pass.append(order)
		var seen := {}
		for e in order:
			seen[e] = true
		var ok := order.size() == Game.TOWER_ORDER.size() \
				and seen.size() == Game.TOWER_ORDER.size()
		if not ok:
			push_error("BOSS ORDER: seed %d produced %s" % [seed_value, str(order)])
		var waves := PackedStringArray()
		for i in Balance.ELEMENT_BOSS_WAVES.size():
			waves.append("w%d=%s" % [int(Balance.ELEMENT_BOSS_WAVES[i]),
					Run.boss_element_for_wave(int(Balance.ELEMENT_BOSS_WAVES[i]))])
		print("seed %-3d %s" % [seed_value, " ".join(waves)])
	# Replay: same seeds, same orders, or the run seed is not really driving this.
	for seed_value in range(20):
		Run.reset(seed_value)
		if Run.boss_elements != first_pass[seed_value]:
			push_error("BOSS ORDER NOT REPRODUCIBLE: seed %d gave %s then %s"
					% [seed_value, str(first_pass[seed_value]), str(Run.boss_elements)])
	print("--- BOSS ORDER DUMP END ---")

## TEMPORARY verification harness for the matchup half of the fusion ladder. Prints
## Game.element_mult_best for every element set against every armour element.
##
## This is the table that has to be read before arguing about Pure's balance: it is the proof
## that a four-element tower is never resisted, and the place a broken ring shows up as a 0.85
## in a row that should have none.
func _dump_matchup() -> void:
	print("--- MATCHUP DUMP BEGIN ---")
	var header := "set".rpad(28)
	for armor in Game.TOWER_ORDER:
		header += "vs %-8s" % String(armor)
	print(header + "vs neutral")
	var sets: Array = []
	for e in Game.TOWER_ORDER:
		sets.append([String(e)])
	var keys: Array = Game.FUSIONS.keys()
	keys.sort()
	for key in keys:
		sets.append(Array(String(key).split("+")))
	for s in sets:
		var line := ("+".join(PackedStringArray(s))).rpad(28)
		var worst := 99.0
		for armor in Game.TOWER_ORDER:
			var m := Game.element_mult_best(s, String(armor))
			worst = minf(worst, m)
			line += "%-11.2f" % m
		line += "%.2f" % Game.element_mult_best(s, "")
		print(line)
		# A four-element set covers the whole ring by construction; anything less cannot.
		if s.size() == Game.TOWER_ORDER.size() and worst < Game.ELEMENT_STRONG:
			push_error("PURE RESISTED: full set fell to x%.2f, expected x%.2f"
					% [worst, Game.ELEMENT_STRONG])
	print("--- MATCHUP DUMP END ---")

## TEMPORARY verification harness: stands one tower on an empty board, unlocks three elements
## and opens its panel, so the panel's _draw() can be photographed without playing to an
## avatar boss first. Pair with --shot and WITHOUT --headless — _draw never runs headless.
##   Godot.exe --path <project> res://scenes/Main.tscn -- --show-fusion-panel --shot:1
##
## `--show-locked-upgrade` photographs the OTHER half of the same rule from the same setup:
## it leaves the tower unfused at Lv2 with its own element still locked, which is the state
## that draws the dim, unpressable "beat the Fire avatar" row. Two flags rather than two
## harnesses, because the interesting difference between them is three lines.
func _show_fusion_panel(fused: bool = true) -> void:
	wave_manager.set_process(false)
	Game.add_gold(2000)
	var t := TOWER.instantiate() as Tower
	t.setup_def("fire")
	t.position = Vector2(Game.WORLD_SIZE.x * 0.42, Game.WORLD_SIZE.y * 0.62)
	towers_root.add_child(t)
	# upgrade(), not `t.level = 2`: level alone leaves total_spent at the build cost, and the
	# panel's sell row would then quote a refund no real Lv2 tower would ever offer. ONE
	# upgrade now, not two — Lv2 is where fusion branches from, and a Lv3 tower would have no
	# fusion rows left to photograph (Tower.can_fuse).
	t.upgrade()
	# Three unlocked and FIRE deliberately left out, so the panel shows offered fusion rows,
	# the locked footer, AND — because the tower's own element is the locked one — the dim
	# locked-upgrade row. All three states of the gate in one screenshot.
	Run.beat_avatar("nature")
	Run.beat_avatar("water")
	Run.beat_avatar("earth")
	# Fusing once is the more interesting state for the fusion rows: it proves the painted set
	# of a COMBINATION is picked up (Tower.art_key) rather than the base element's, that the
	# dual is born at Lv3, and that the rows above it are the triples rather than the duals.
	if fused:
		t.add_element("water")
	tower_panel.open_for(t)

## TEMPORARY verification harness for meta progression. Checks the things that only show up
## across an app restart or a wall-clock change, neither of which is testable by playing:
## the essence curve, workshop costs, that a bought level actually reaches a tower via the
## SAME fold the roguelite cards use, and that start gold/lives move.
##
## Pass `--wipe-save` first to start from a clean slate; without it this runs against the
## real save, which is the point when checking that a purchase survived a relaunch.
func _dump_meta() -> void:
	print("--- META DUMP BEGIN ---")
	print("fresh=%s essence=%d best=%d runs=%d offline_collected=%d levels=%s"
			% [Save.is_fresh, Meta.essence, Meta.best_wave, Meta.total_runs,
				Meta.pending_offline, str(Meta.levels)])
	print("run essence by wave: 5=%d 10=%d 20=%d 40=%d 80=%d" % [
			Balance.run_essence(5), Balance.run_essence(10), Balance.run_essence(20),
			Balance.run_essence(40), Balance.run_essence(80)])
	print("offline (best=20): 1min=%d 1h=%d 4h=%d 8h=%d 48h(capped)=%d" % [
			Balance.offline_essence(60.0, 20), Balance.offline_essence(3600.0, 20),
			Balance.offline_essence(4.0 * 3600.0, 20), Balance.offline_essence(8.0 * 3600.0, 20),
			Balance.offline_essence(48.0 * 3600.0, 20)])
	print("forge cost by level: %s" % str(_costs("forge")))

	var probe := func(label: String) -> void:
		Run.reset(1)  # re-seeds `permanent` from Meta
		Game.reset()
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def("fire")
		print("%s fire dmg=%.4f rng=%.2f int=%.5f | start gold=%d lives=%d"
				% [label.rpad(20), t.damage, t.tower_range, t.fire_interval, Game.gold, Game.lives])
		t.queue_free()

	probe.call("no workshop")
	Meta.add_essence(100000)
	for i in 3:
		Meta.buy("forge")
	probe.call("forge x3")
	Meta.buy("lens")
	Meta.buy("tempo")
	probe.call("+lens +tempo")
	for i in 2:
		Meta.buy("treasury")
	Meta.buy("ramparts")
	probe.call("+treasury x2 +ramp")
	print("essence left=%d levels=%s" % [Meta.essence, str(Meta.levels)])
	# Settings round-trip. The mute flag was the one piece of state the game already had a
	# UI for and still forgot on every launch, so it is worth asserting it now persists.
	print("muted loaded as=%s -> writing true" % Audio.is_muted())
	Audio.set_muted(true)
	print("settings section now=%s" % str(Save.get_section("settings")))
	print("--- META DUMP END ---")

func _costs(id: String) -> Array:
	var d := Meta.def_of(id)
	var out: Array = []
	for lv in 5:
		out.append(Balance.workshop_cost(int(d["base_cost"]), float(d["cost_growth"]), lv))
	return out

## TEMPORARY verification harness for the endless wave generator. Prints the definition of
## each wave, marks where the hand-authored seed table hands over, and — the part that
## matters — asks for every wave TWICE to prove wave_def(n) is pure. The HUD previews wave
## n+1 while wave n is spawning, so a generator that drifted between calls would advertise
## a different wave than the one that arrives, and nothing else would catch it.
func _dump_waves() -> void:
	var gen := WaveGenerator.new(12345)
	var seed_count: int = Game.WAVES.size()
	var impure := 0
	print("--- WAVE DUMP BEGIN (seed table = waves 1-%d) ---" % seed_count)
	for n in range(1, 61):
		var def: Dictionary
		var src: String
		if n <= seed_count:
			def = Game.WAVES[n - 1]
			src = "table"
		else:
			def = gen.wave_def(n)
			src = "gen"
			if str(gen.wave_def(n)) != str(def):
				impure += 1
		var flags := ""
		if def.get("boss", false):
			flags += " BOSS"
		if float(def.get("hp", 1.0)) != 1.0:
			flags += " hp=%.2f" % float(def.get("hp", 1.0))
		if float(def.get("count", 1.0)) != 1.0:
			flags += " count=%.2f" % float(def.get("count", 1.0))
		print("w%02d [%s] %-8s el=%-6s%s" % [n, src, String(def["type"]),
				String(def.get("element", "-")), flags])
	print("--- WAVE DUMP END (impure generated waves: %d) ---" % impure)

## TEMPORARY verification harness: parks a row of Air creeps along the road with an empty
## board, so the flyer's own drawing can be photographed. `--fill-board` cannot do this — it
## buries the road under towers and kills every creep at its spawn point — and a normal run
## does not reach the Air wave (6) without leaking away all twenty lives first.
##
## What it is for is the half of enemy.gd that numbers cannot check: the wingbeat carrier,
## the trailing air strokes, and whether the health bar still sits over the creature once the
## body is lifted off its anchor. Pair it with --shot, and WITHOUT --headless:
##   Godot.exe --path <project> res://scenes/Main.tscn -- --air-pose --shot:3
## Delete this and its call above once the flyer art lands.
func _air_pose() -> void:
	wave_manager.set_process(false)
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var def: Dictionary = Game.WAVE_TYPES["air"]
	# Spread along the path so several headings are on screen at once — the sprite is drawn
	# facing screen-left and mirrored for the other way, and the streaks mirror with it, so
	# one heading proves nothing about the other.
	for i in range(8):
		var e := enemy_scene.instantiate() as Enemy
		e.setup(400.0, 30.0, 5, Color(def["color"]))
		e.kind = "air"
		# The same expression WaveManager._spawn_one uses. Hardcoding the base radius made this
		# harness lie about size the moment the archetype was given a multiplier.
		e.radius = Balance.ENEMY_BASE_RADIUS * float(def.get("radius", 1.0))
		e.make_flying()
		enemies_root.add_child(e)
		var step := int(float(Game.active_path.size() - 2) * float(i) / 8.0) + 1
		e.set_progress(step)
		e.global_position = Game.active_path[step]
		# Half of them damaged, so the health bar is visible against the lifted body.
		if i % 2 == 1:
			e.take_damage(150.0)

## TEMPORARY verification harness: stages all THREE boss rules on an empty board so
## cc_immune's ward, rotating_armor's icon/ring and the avatar's element sigil can be
## photographed without playing to their waves first. Pair with --shot, WITHOUT --headless:
##   Godot.exe --path <project> res://scenes/Main.tscn -- --boss-pose --shot --shot:6
## (the second shot is timed past ROTATING_ARMOR_PERIOD so the ring/icon is caught having
## already turned over at least once). Delete this and its call above once photographed.
func _boss_pose() -> void:
	wave_manager.set_process(false)
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var rules := [
		{"element": "water", "rule": "control_immune"},
		{"element": "fire", "rule": "rotating_armor"},
		# The avatar is the one whose mark the player MUST read — it names a reward that is
		# lost if the boss walks off the end — so it is the one most worth photographing.
		{"element": "nature", "rule": "element_avatar"},
	]
	for i in rules.size():
		var e := enemy_scene.instantiate() as Enemy
		var avatar := String(rules[i]["rule"]) == "element_avatar"
		e.setup(2000.0, 20.0, 50,
				Game.ELEMENT_COLORS.get(rules[i]["element"], Balance.BOSS_TINT) if avatar
				else Balance.BOSS_TINT)
		e.kind = "tank"
		e.radius = Balance.BOSS_RADIUS
		e.is_boss = true
		e.armor_element = String(rules[i]["element"])
		match String(rules[i]["rule"]):
			"control_immune": e.cc_immune = true
			"rotating_armor": e.rotating_armor = true
			"element_avatar": e.avatar_element = String(rules[i]["element"])
		enemies_root.add_child(e)
		var step := int(float(Game.active_path.size() - 2) * float(i + 1) / float(rules.size() + 1)) + 1
		e.set_progress(step)
		e.global_position = Game.active_path[step]
		e.take_damage(2000.0 * 0.35)  # dent the health bar so it reads against a full boss

## TEMPORARY verification harness: walks all FOUR element avatars down an empty road at once,
## so the boss sheets can be photographed and compared side by side.
##
## The avatars are the one creature a run cannot show you on demand: they arrive on waves
## 10/20/30/40 in an order the RUN SEED picks (Run.boss_element_for_wave), so photographing all
## four means four wave-40 runs and getting a different order each time. `--boss-pose` does not
## cover it either — it stages one avatar to photograph the SIGIL, in whatever element, on the
## `tank` art every boss used to wear.
##
## Set up so a MISSING sheet is visible rather than silent: each avatar prints the art set it
## resolved to (Enemy.art_kind), so `boss_fire` against `normal` says the sheet is not being
## picked up — which was the whole failure mode before the lookup existed, and it looks exactly
## like a boss that was never painted.
##
## Pair with --shot and WITHOUT --headless — _draw never runs headless:
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 600 -- --avatar-pose --shot:3
func _avatar_pose() -> void:
	wave_manager.set_process(false)
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	print("--- AVATAR POSE ---")
	for i in Game.TOWER_ORDER.size():
		var element := String(Game.TOWER_ORDER[i])
		var e := enemy_scene.instantiate() as Enemy
		# The same fields WaveManager._spawn_boss sets for an avatar, and in its order: the
		# art set is resolved from `avatar_element`, so a harness that set it later than the
		# spawner does would photograph a creature the game never produces.
		# The REAL speed an avatar walks at, not a slow one chosen to make photography easy.
		# It was 24 px/s, and that is worth writing down because it produced a wrong verdict on
		# the art: the walk cycle is played at the creep's own pace, so at 24 the twelve frames
		# ran at 1.9 fps and the first painted boss was judged — by eye, correctly — to be
		# stepping. At the first avatar wave's real speed the same art plays at 5.2.
		var real_speed := Balance.wave_speed(int(Balance.ELEMENT_BOSS_WAVES[0])) * Balance.BOSS_SPEED_MULT
		e.setup(4000.0, real_speed, 50, Game.ELEMENT_COLORS.get(element, Balance.BOSS_TINT))
		e.kind = "normal"   # what an avatar wave pins its archetype to (Game.apply_milestone)
		e.radius = Balance.BOSS_RADIUS
		e.is_boss = true
		e.armor_element = element
		e.avatar_element = element
		enemies_root.add_child(e)
		# Spread across the MIDDLE of the road, not evenly along the whole of it: the last
		# leg runs off to the right behind the tower palette (Game.PLAY_RIGHT), and an even
		# split put the fourth avatar under the panel where it cannot be photographed.
		var span := float(Game.active_path.size() - 2)
		var step := int(span * (0.12 + 0.52 * float(i) / float(Game.TOWER_ORDER.size() - 1))) + 1
		e.set_progress(step)
		e.global_position = Game.active_path[step]
		e.take_damage(4000.0 * 0.3)  # dent the bar so it reads against a full boss
		print("    %-7s art=%s" % [element, e.art_kind()])
	print("--- AVATAR POSE END ---")

## TEMPORARY verification harness: flies one of EVERY bolt drawing across an empty board at a
## crawl, so all fifteen can be photographed side by side and compared.
##
## Neither of the other two ways works. A normal run only ever has the four base shots in the
## air — a fusion needs an avatar boss to unlock its second element first — and `--fill-board`
## buries the road, so every creep dies at its spawn point and its bolts exist for a handful
## of frames in one corner of the map. This was written when the eleven fusions stopped
## throwing their build origin's shot and started throwing their own; the thing it checks is
## the half of projectile.gd that no number can reach, which is whether the fifteen drawings
## are actually told apart by SILHOUETTE at the size they fly at.
##
## Rows run top to bottom in the order printed to stdout. Pair with --shot, WITHOUT --headless
## (a headless run does no drawing at all, so it passes this silently):
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 900 -- --bolt-pose --shot:4
## Delete this and its call above once the fusion bolts have been checked.
func _bolt_pose() -> void:
	wave_manager.set_process(false)
	# Built from the tables rather than listed, so a new fusion row appears here for free —
	# and, more to the point, a row whose `shape` does not match a case in Projectile._draw()
	# shows up as a plain bolt in the photograph instead of passing unnoticed.
	var rows: Array = []
	for el in Game.TOWER_ORDER:
		rows.append({"shape": String(el), "color": Game.TOWER_DEFS[el]["color"],
				"elements": [String(el)]})
	for key in Game.FUSIONS:
		var def: Dictionary = Game.FUSIONS[key]
		# The same expression Tower.art_key() uses. Derived, not written down, so the harness
		# cannot drift from the key the game actually passes.
		rows.append({"shape": String(def["name"]).to_lower().replace(" ", "_"),
				"color": def["color"], "elements": Array(String(key).split("+"))})
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var pool := get_node("Projectiles")
	var top := 120.0
	var gap := (Game.WORLD_SIZE.y - 200.0) / float(rows.size())
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := top + gap * float(i)
		# A stationary dummy far off the right edge. The bolt homes on it, so it never
		# arrives, never recycles and keeps animating for the whole run — which is the only
		# way to hold a shot that normally lives for a third of a second still enough to look
		# at. Speed 0 rather than a paused node: an Enemy that stops processing also stops
		# being a valid target, and the bolt would recycle itself on the next frame.
		var e := enemy_scene.instantiate() as Enemy
		e.setup(1.0e9, 0.0, 0, Color(1, 1, 1, 0))
		e.kind = "normal"
		e.radius = 1.0
		enemies_root.add_child(e)
		e.set_progress(1)
		e.global_position = Vector2(Game.WORLD_SIZE.x + 2400.0, y)
		var p := pool.acquire() as Projectile
		p.color = row["color"]
		p.shape = String(row["shape"])
		p.elements = row["elements"]
		p.speed = 34.0
		p.setup(Vector2(110.0, y), e, 0.0)
		print("bolt row %2d  y=%4d  %s" % [i, int(y), row["shape"]])

## TEMPORARY verification harness: stands one REAL tower of each impact-relevant identity in
## front of a creep it cannot kill, so every kind of impact lands over and over in a known
## spot and can be photographed.
##
## Real towers firing real bolts, deliberately. The impact branch lives in Projectile._hit()
## and reads five payload fields; a harness that spawned bolts itself would have to set those
## fields the way Tower.fire_bolt() does, and would then be free to disagree with it — which
## is exactly the bug such a harness exists to catch. So this builds towers the way
## _fill_board() does and lets the game decide what a hit looks like. It bypasses the PAD rule
## (it places on a fixed grid, not by the placement rule) because what is photographed is the impact,
## not the placement.
##
## `--fill-board` cannot do this: a maxed board kills every creep in the first frame or two
## after it spawns, so all seventeen kinds of impact happen on top of one another in one
## corner of the map, and catching a chosen one is down to luck with `--shot:N`.
##
## Pair with --shot, WITHOUT --headless (a headless run does no drawing, so it passes this
## silently), and take two so a burst caught mid-life in one is caught early in the other:
##   Godot.exe --path <project> res://scenes/Main.tscn --quit-after 700 -- --hit-pose --shot:6 --shot:7
## Delete this and its call above once the impact effects have been checked.
func _hit_pose() -> void:
	wave_manager.set_process(false)
	Game.add_gold(1000000)
	# Built from the tables, so a row that stops splashing — or starts — shows up here without
	# this list being edited. The three columns are the three things the impact branch keys
	# on: a splash radius, a burn payload, and chaos.
	var rows: Array = [
		["fire", ["fire"]],                                  # burn, no splash: embers only
		["water", ["water"]],                                # neither: the quiet reference
		["earth", ["earth"]],                                # splash 90, no burn
		["lava", ["earth", "fire"]],                         # splash 110 AND burn
		["steam", ["fire", "water"]],                        # splash 80, fires 2.5x/s
		["roots", ["earth", "nature"]],                      # neither, and the slowest tower
		["infernal", ["earth", "fire", "water"]],            # chaos
		["rainbow", ["fire", "nature", "water"]],            # chaos, another colour
		["earth+fire+nature+water", ["earth", "fire", "nature", "water"]],  # Pure
	]
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	# Same reason --fill-board opens this way: an impact's payload scales with the firing
	# tower's level, and without the avatars beaten every base row below would stand at Lv2
	# (Tower.can_upgrade) and quietly photograph a weaker splash/burn than the one shipped.
	for e in Game.TOWER_ORDER:
		Run.beat_avatar(String(e))
	var xs: Array = [280.0, 700.0, 1120.0]
	var ys: Array = [220.0, 480.0, 740.0]
	for i in rows.size():
		var elems: Array = rows[i][1]
		var at := Vector2(float(xs[i % 3]), float(ys[i / 3]))
		var t := TOWER.instantiate() as Tower
		# Every tower is BUILT as its first element and then absorbs the rest, which is the
		# only route a real tower has to a fusion — and the route that used to leave the shot
		# and the impact reading off the build origin instead of the result.
		t.setup_def(String(elems[0]))
		t.position = at
		towers_root.add_child(t)
		while t.can_upgrade():
			t.upgrade()
		for j in range(1, elems.size()):
			t.add_element(String(elems[j]))
		# A creep it cannot kill, parked inside its reach. Speed 0 rather than a paused node:
		# an Enemy that stops processing also stops being a valid target, and the bolt in the
		# air would recycle itself instead of landing.
		var e := enemy_scene.instantiate() as Enemy
		e.setup(1.0e9, 0.0, 0, Color(0.85, 0.85, 0.85))
		e.kind = "normal"
		e.radius = Balance.ENEMY_BASE_RADIUS
		enemies_root.add_child(e)
		e.set_progress(1)
		e.global_position = at + Vector2(120.0, 0.0)
		print("hit row %d  tower=%-12s at (%4d,%4d)  target +120x  splash=%.0f" % [
				i, t.display_name, int(at.x), int(at.y),
				float(t._eff.get("splash_radius", 0.0))])

## TEMPORARY verification harness: covers every buildable cell with towers, cycling the
## roster, so a headless run actually exercises targeting, firing, the projectile pool and
## the effect payloads. Without it a headless run has no towers and proves nothing about
## the combat path. Gold is granted rather than spent so placement never fails.
##   Godot.exe --headless --path <project> res://scenes/Main.tscn --quit-after 900 -- --fill-board
## Delete this and its call above once the refactor has landed and been verified.
## True for either --fill-board or its real-time timing variant --fill-board:1x (BUILD
## NEXT #10) — `.has()` alone only matches the bare flag exactly, so both call sites need
## this rather than one `.has("--fill-board")` check.
func _fill_board_requested() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--fill-board") or args.has("--fill-board:1x")

func _fill_board() -> void:
	# Headless runs one frame at a time regardless of wall clock, so the only way to cover
	# many waves in a bounded frame budget is to make each frame simulate more time. Skipped
	# by `--fill-board:1x` (BUILD NEXT #10's "GERÇEK BİR RUN'I ÖLÇ") — timing how long a
	# Standard run actually takes needs REAL wall-clock pacing, which is the one thing this
	# acceleration exists to avoid everywhere else.
	if not OS.get_cmdline_user_args().has("--fill-board:1x"):
		Engine.time_scale = 8.0
	_auto_pick = true
	Game.add_gold(999999)
	# Real WALL-CLOCK elapsed time (not scaled by Engine.time_scale — Time.get_ticks_msec is
	# an OS clock, unaffected by it either way), for --fill-board:1x's job of answering
	# GAME_STRATEGY_V2.md §11.2's own unmeasured guess: does a 20-wave Standard run actually
	# take ~10.5 minutes? (BUILD NEXT #10.) Meaningless at the default 8x speed, printed
	# regardless since it costs nothing extra to include.
	var start_ms := Time.get_ticks_msec()
	# The end screen pauses the tree, so a run that ends looks exactly like a hang from the
	# outside. Say so explicitly instead. Standard mode can now be WON (BUILD NEXT #4) — a
	# fully maxed board plausibly clears all 20 waves, so both outcomes need a line or a win
	# would silently look identical to the harness just hanging at frame budget.
	var report := func(outcome: String) -> void:
		# Deferred: _on_game_over/_on_victory bank the run, and reading Meta before that has
		# happened would report the wallet as it was a moment BEFORE the reward landed.
		await get_tree().process_frame
		var elapsed_s := float(Time.get_ticks_msec() - start_ms) / 1000.0
		print("--- RUN %s: wave %d | best %d | essence %d | runs %d | elapsed %.1fs (%.1fmin) ---"
				% [outcome, Game.wave_reached, Meta.best_wave, Meta.essence, Meta.total_runs,
					elapsed_s, elapsed_s / 60.0])
		# The avatar ORDER this seed drew, which is still worth printing — it is what
		# decides which combinations the board below could have been built out of.
		#
		# What this line canNOT report any more is whether the four avatars were actually
		# KILLED: this harness beats all four at wave 0 so it can build a maxed board, so
		# avatars_beaten is full before the first creep walks. That check lives in
		# `--play-sim` now, which unlocks them the only honest way — by fighting them.
		print("--- AVATAR ORDER: %s (all four pre-unlocked at wave 0) ---"
				% str(Run.boss_elements))
	Game.game_over.connect(func() -> void: report.call("OVER"))
	Game.victory.connect(func() -> void: report.call("WON"))
	# Every avatar, beaten, before a single tower is placed. This is not decoration: the whole
	# point of this harness is the CEILING a board can reach, and both roads to that ceiling
	# now run through Run.avatars_beaten — a base tower stops at Balance.FREE_LEVEL_CAP
	# without its own element's avatar (Tower.can_upgrade), and no tower can fuse at all
	# without somebody else's. Skip this and the harness quietly builds a board of Lv2 towers
	# and still prints a cheerful summary, which is the exact failure it exists to catch.
	# (Same call the --show-fusion-panel scenario uses, for the same reason.)
	for e in Game.TOWER_ORDER:
		Run.beat_avatar(String(e))
	var i := 0
	# No cells to walk any more: sweep the play area on the tower spacing and take every
	# spot the placement rule allows, which is the closest thing to "a full board" that free
	# placement has.
	for spot in _buildable_lattice():
		var kind := String(Game.TOWER_ORDER[i % Game.TOWER_ORDER.size()])
		var t := TOWER.instantiate() as Tower
		t.setup_def(kind)
		t.position = spot
		towers_root.add_child(t)
		# Every fourth tower is walked all the way up the fusion ladder to Pure, and the rest
		# are spread across base / dual / triple, so one run exercises every row of
		# Game.FUSIONS rather than the four base elements over and over.
		# Divided by the roster size, NOT `i % 4`: the element above is picked with `i % 4` too,
		# so sharing the modulus locked each element to one depth forever — Water was always
		# left unfused and Fire/Nature/Earth were never seen maxed in their own painted art.
		var depth := (i / Game.TOWER_ORDER.size()) % 4  # 0 base, 1 dual, 2 triple, 3 Pure
		# Depth is chosen BEFORE any upgrading now, because the two roads no longer compose:
		# a tower that is going to fuse must stop at FREE_LEVEL_CAP (past it Tower.can_fuse
		# refuses, and rightly — a Lv5 absorbed into a Lv3 dual is a downgrade), while a tower
		# that is staying base climbs to MAX_LEVEL. Either way it ends at ITS ceiling, which is
		# what "a full board" means now. Fusing does the rest of the levelling by itself:
		# add_element() sets the level from Balance.FUSED_LEVELS.
		#
		# Lv2 is also still past the area-slow threshold (and the frost ring it spawns), so
		# that path is exercised on every tower here regardless of which road it took.
		while t.can_upgrade() and (depth == 0 or t.level < Balance.FREE_LEVEL_CAP):
			t.upgrade()
		# WHICH extra elements, not just how many: scanning TOWER_ORDER from its start always
		# took the first element the tower was missing, so every dual came out Steam, Well or
		# Clay and every triple Rainbow or Infernal -- half the roster, including all of Lava,
		# Sun, Roots, Dinosaur and Flesh Golem, was never built by the harness that claims to
		# exercise every row. Start the scan one past the base element and rotate that start
		# every fourth ROW (16 towers), which is independent of both the element and the depth:
		var rot := i / (Game.TOWER_ORDER.size() * 4)
		var added := 0
		for k in Game.TOWER_ORDER.size():
			if added >= depth:
				break
			var at_k := (i + 1 + rot + k) % Game.TOWER_ORDER.size()
			var candidate := String(Game.TOWER_ORDER[at_k])
			if not t.elements.has(candidate):
				t.add_element(candidate)
				added += 1
		i += 1
	print("--- FILL BOARD: placed %d towers, each at ITS ceiling (base Lv%d, fusions Lv%s) ---"
			% [i, Balance.MAX_LEVEL, str(Balance.FUSED_LEVELS.values())])
	# Which SETS are standing there, and whether each one is painted. --shot photographs a
	# board of 47 towers where a single new set is three of them, so "did the art land?" was
	# being answered by hunting through a screenshot. `art*` means assets/art/towers has the
	# files and Sprites.tower() will find them; `art-` means the code art draws.
	var tally: Dictionary = {}
	for child in towers_root.get_children():
		var tw := child as Tower
		if tw == null:
			continue
		var key := tw.art_key()
		tally[key] = int(tally.get(key, 0)) + 1
	var keys := tally.keys()
	keys.sort()
	for key in keys:
		var painted := ResourceLoader.exists("res://assets/art/towers/%s_5.png" % key)
		print("    %-12s x%d  art%s" % [key, int(tally[key]), "*" if painted else "-"])

## Harness (`--play-sim`): plays the run the way a PLAYER does, and fills the one hole the
## rest of the suite has always had. `--fill-board` grants itself a million gold and stands a
## maxed tower on every pad, which measures the ceiling; nothing measured the thing the game
## is actually tuned for, which is whether a run that has to EARN its board survives. Every
## HP and cost note in `Balance` that says "sized against a budget, not a played run" was
## written against this gap.
##
## It buys through the same functions a tap does — the placement rule, `_upgrade_tower()`,
## `_fuse_tower()` — so the simulated player cannot do anything the real one cannot, and
## cannot miss a rule they are subject to. It starts on START_GOLD, it leaks lives, and it
## loses.
##
## THE POLICY IS DELIBERATELY MODEST, and reading a result means remembering which player it
## is: cheapest useful purchase first, board before depth. It buys a base tower whenever a
## pad is free, then the cheapest upgrade, then the cheapest fusion. It does not choose
## elements against the wave's armour, it does not place for coverage (the pad it takes is
## simply the first free one), and it never sells. So it is a FLOOR, not an average: a human
## who reads the next wave and picks the matchup beats it. Tune so this player finishes
## around the last wave and a good one finishes with room.
func _play_sim() -> void:
	_play_sim_on = true
	_auto_pick = true
	Engine.time_scale = 8.0
	var start_ms := Time.get_ticks_msec()
	var report := func(outcome: String) -> void:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - start_ms) / 1000.0
		print("--- PLAY-SIM %s: wave %d | lives %d | gold %d | %s | %.0fs ---"
				% [outcome, Game.wave_reached, Game.lives, Game.gold, _sim_board(), elapsed])
		# The avatar-kill check, which used to live in --fill-board and cannot any more (that
		# harness pre-unlocks all four). This one earns them: it fights the avatars with the
		# board it managed to afford, so a run that passed an avatar wave without the element
		# appearing here means the boss LEAKED — a real outcome for this player, and also
		# what a broken was_killed / wave-clear path would look like. Compare with the order:
		# the elements missing are the ones it could neither deepen nor fuse.
		print("--- AVATARS BEATEN: %s of order %s ---"
				% [str(Run.avatars_beaten), str(Run.boss_elements)])
	Game.game_over.connect(func() -> void: report.call("LOST"))
	Game.victory.connect(func() -> void: report.call("WON"))
	wave_manager.wave_starting.connect(func(n: int) -> void:
		print("  w%02d lives=%2d gold=%5d %s" % [n, Game.lives, Game.gold, _sim_board()]))

## One line describing what the simulated player has built: how many towers, their total
## levels, and how deep the fusion ladder has gone.
func _sim_board() -> String:
	var n := 0
	var levels := 0
	var elements := 0
	for c in towers_root.get_children():
		var t := c as Tower
		if t == null:
			continue
		n += 1
		levels += t.level
		elements += t.elements.size()
	return "towers=%d lv=%d el=%d" % [n, levels, elements]

## Spends everything affordable, cheapest first, until nothing else can be bought. Called on
## a clock rather than per wave because gold arrives from kills mid-wave, and a player does
## not wait for the wave to end before spending it.
func _sim_spend() -> void:
	if Game.is_over:
		return
	for _i in 40:            # bounded: one tick cannot loop forever on a rounding bug
		if not _sim_buy_one():
			return

## The single cheapest useful purchase, or false when nothing is affordable. Board first,
## then depth — see the policy note on _play_sim().
func _sim_buy_one() -> bool:
	# 1. an empty pad, if one is left. Elements are cycled so the board does not come out
	#    monochrome, which would make the armour matchup meaningless.
	var kind := String(Game.TOWER_ORDER[_sim_next_element % Game.TOWER_ORDER.size()])
	if Game.gold >= _cost(kind):
		for spot in _buildable_lattice():
			if not Game.can_build_at(spot, towers_root.get_children()):
				continue
			if not Game.spend_gold(_cost(kind)):
				break
			var t := TOWER.instantiate() as Tower
			t.setup_def(kind)
			t.position = spot
			towers_root.add_child(t)
			Game.towers_changed.emit()
			_sim_next_element += 1
			return true
	# 2. the cheapest upgrade.
	var best: Tower = null
	var best_cost := 0
	for c in towers_root.get_children():
		var t := c as Tower
		if t == null or not t.can_upgrade():
			continue
		var cost := t.upgrade_cost()
		if cost <= Game.gold and (best == null or cost < best_cost):
			best = t
			best_cost = cost
	if best != null:
		_upgrade_tower(best)
		return true
	# 3. the cheapest fusion the avatar bosses have unlocked.
	var fuse: Tower = null
	var fuse_cost := 0
	for c in towers_root.get_children():
		var t := c as Tower
		if t == null or not t.can_fuse():
			continue
		var cost := t.fusion_cost()
		if cost <= Game.gold and (fuse == null or cost < fuse_cost):
			fuse = t
			fuse_cost = cost
	if fuse != null:
		_fuse_tower(fuse, String(fuse.available_elements()[0]))
		return true
	return false

## Every position a tower could stand, swept on the tower spacing. Used by --fill-board and
## by --dump-board, which need "the set of places you may build".
##
## Placement is free, so that set is CONTINUOUS and this is a sample of it rather than an
## enumeration: it sweeps at half the tower spacing and keeps whatever clears `_far_enough`,
## which is one plausible packing. A player placing by hand will fit a slightly different
## number, so read the count as a capacity estimate and not as a board specification.
func _buildable_lattice(step := -1.0) -> Array:
	var pitch: float = Game.TOWER_GAP if step <= 0.0 else step
	var out: Array = []
	var y := Game.PLAY_TOP + Game.TOWER_RADIUS
	while y <= Game.WORLD_SIZE.y - Game.TOWER_RADIUS:
		var x := Game.TOWER_RADIUS
		while x <= Game.PLAY_RIGHT - Game.TOWER_RADIUS:
			var at := Vector2(x, y)
			if Game.can_build_at(at) and _far_enough(at, out):
				out.append(at)
			x += pitch * 0.5
		y += pitch * 0.5
	return out

func _far_enough(at: Vector2, taken: Array) -> bool:
	for other in taken:
		if at.distance_to(other) < Game.TOWER_GAP:
			return false
	return true

## Measures the BOARD rather than the towers: how much of the road one tower can watch,
## and how many towers it takes to watch all of it.
##
## This exists because "Light covers half the board" was an assertion nobody had checked.
## Tower ranges are now the source map's, and that map's boards are far larger than ours,
## so the ratio of range to road length is the number that actually moved — not any single
## stat. Redesigning the path by eye cannot tell you whether it improved; this can.
##
## `cover` is the honest headline: the number of towers of that element, placed greedily on
## the best cells, needed to bring 95% of the road inside somebody's range. A board where
## two towers cover everything has no placement decisions left in it.
##
## `raw` is the same "best 1" measured with Balance.MAX_TOWER_RANGE lifted — the ported
## range as the source map wrote it. That column judges the SHAPE of the board rather than
## our cap, which is what makes it comparable with the original's own arena as printed by
## `python tools/extract_w3x.py "<map>.w3x" pathing`. Everything left of it is the board
## you actually play on.
##
##   Godot.exe --headless --path <project> res://scenes/Main.tscn --quit-after 5 -- --dump-board
func _dump_board() -> void:
	print("--- BOARD DUMP BEGIN ---")
	# Sample the road evenly. 12px is well under the smallest range (Fire, 175px), so the
	# sampling grain never decides the answer.
	const STEP := 12.0
	var samples: Array[Vector2] = []
	var path: Array = Game.active_path
	var total := 0.0
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg := a.distance_to(b)
		total += seg
		# A smoothed path has many segments shorter than STEP. Each still needs one sample;
		# dropping them made a denser, better route look shorter to the coverage harness.
		var n := maxi(1, ceili(seg / STEP))
		for k in n:
			samples.append(a.lerp(b, float(k) / float(n)))
	# The candidate set is every legal STANDING SPOT, swept on the tower spacing — the board
	# keeps no cell list any more. Coverage therefore answers the question free placement
	# actually poses: how much road can one tower watch from the best place it may stand.
	var spots: Array = _buildable_lattice()
	print("  road length      : %.0f px over %d waypoints" % [total, path.size()])
	print("  buildable spots  : %d (free placement, sampled every %.0fpx)"
			% [spots.size(), Game.TOWER_GAP * 0.5])
	print("  road samples     : %d (every %.0f px)" % [samples.size(), STEP])
	print("  %-10s %7s %8s %8s  %-12s %7s %8s"
			% ["element", "range", "best 1", "median", "cover 95%", "raw", "raw best"])
	for tid in Game.TOWER_ORDER:
		var def: Dictionary = Game.TOWER_DEFS[String(tid)]
		# Same formula as Tower._recompute, cap included — the columns that describe the
		# board you play on must measure the range you actually get.
		var raw: float = float(def.get("range", 0.0)) * Balance.WC3_RANGE_SCALE
		var r: float = minf(raw, Balance.MAX_TOWER_RANGE)
		var r_sq := r * r
		# Which samples each cell can see. Built once, then reused for both statistics.
		var seen: Array[PackedInt32Array] = []
		for centre in spots:
			var hit := PackedInt32Array()
			for s in samples.size():
				if centre.distance_squared_to(samples[s]) <= r_sq:
					hit.append(s)
			seen.append(hit)
		var counts: Array[int] = []
		for h in seen:
			counts.append(h.size())
		counts.sort()
		var best := counts[counts.size() - 1] if not counts.is_empty() else 0
		var median := counts[counts.size() / 2] if not counts.is_empty() else 0
		# Greedy set cover to 95%: repeatedly take the cell that adds the most new road.
		var covered := {}
		var target := int(float(samples.size()) * 0.95)
		var used := 0
		while covered.size() < target and used < spots.size():
			var best_gain := 0
			var best_i := -1
			for i in seen.size():
				var gain := 0
				for s in seen[i]:
					if not covered.has(s):
						gain += 1
				if gain > best_gain:
					best_gain = gain
					best_i = i
			if best_i < 0:
				break  # nothing left can add road; the rest is out of everyone's reach
			for s in seen[best_i]:
				covered[s] = true
			used += 1
		var cover_txt := "%d towers" % used if covered.size() >= target \
				else "%d towers (only %.0f%% reachable)" % [used,
					100.0 * float(covered.size()) / float(samples.size())]
		print("  %-10s %7.0f %7.0f%% %7.0f%%  %-12s %7.0f %7.0f%%" % [tid, r,
				100.0 * float(best) / float(samples.size()),
				100.0 * float(median) / float(samples.size()), cover_txt,
				raw, 100.0 * float(_best_seen(spots, samples, raw)) / float(samples.size())])
	print("--- BOARD DUMP END ---")

## Road samples visible from the single best cell at radius `r`. Used for the `raw` column,
## which repeats the "best 1" measurement with the cap lifted.
func _best_seen(spots: Array, samples: Array[Vector2], r: float) -> int:
	var r_sq := r * r
	var best := 0
	for centre in spots:
		var n := 0
		for s in samples:
			if centre.distance_squared_to(s) <= r_sq:
				n += 1
		best = maxi(best, n)
	return best

## TEMPORARY verification harness for the tower-stats refactor. Prints every tower's
## resolved stats at each level so a pure refactor can be proved byte-identical against a
## saved baseline — there are no tests, and playing the game cannot catch a 6th-decimal
## drift. Gated behind a user arg so it never runs in a normal session; everything after
## the bare `--` is passed through to OS.get_cmdline_user_args():
##   Godot.exe --headless --path <project> res://scenes/Main.tscn -- --dump-stats
## Delete this and its call above once the refactor has landed and been verified.
func _dump_tower_stats() -> void:
	print("--- TOWER STATS DUMP BEGIN ---")
	# What this dump measures is the STAT TABLE, not who is allowed to reach it, so every
	# avatar is beaten first and all five levels stay walkable (Tower.can_upgrade now stops a
	# base tower at Balance.FREE_LEVEL_CAP without its own element's boss). Without this the
	# loop below re-prints L2 three times — and since it prints t.level rather than the loop
	# counter, it does so without any error, which would quietly hollow out the byte-for-byte
	# before/after diff that CLAUDE.md leans on for every "no behaviour change" refactor.
	for e in Game.TOWER_ORDER:
		Run.beat_avatar(String(e))
	for tid in Game.TOWER_ORDER:
		var t := TOWER.instantiate() as Tower
		towers_root.add_child(t)
		t.setup_def(String(tid))
		for _lv in Balance.MAX_LEVEL:
			print("%s L%d dmg=%.6f rng=%.4f rsq=%.4f int=%.6f pdps=%.6f ptime=%.4f " \
					% [tid, t.level, t.damage, t.tower_range, t._range_sq,
						t.fire_interval, t.poison_dps, t.poison_time] \
				+ "slowf=%.6f slowt=%.4f sslash=%.6f splr=%.4f splf=%.4f stunc=%.4f stunt=%.4f " \
					% [t.slow_factor, t.slow_time, t.slow_splash_radius, t.splash_radius,
						t.splash_factor, t.stun_chance, t.stun_time] \
				+ "cost=%d upcost=%d spent=%d sell=%d flying=%s" \
					% [t.build_cost, t.upgrade_cost(), t.total_spent, t.sell_value(),
						t.can_hit_flying])
			t.upgrade()
		t.queue_free()
	print("--- TOWER STATS DUMP END ---")

# --- Camera shake --------------------------------------------------------------

## Kept deliberately small: the mouse position is read back through the camera
## transform, so a violent shake would also drag the cursor's world position around
## and make clicks feel imprecise mid-shake.
func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _process(delta: float) -> void:
	if _play_sim_on:
		_sim_spend_clock -= delta
		if _sim_spend_clock <= 0.0:
			_sim_spend_clock = SIM_SPEND_EVERY
			_sim_spend()
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	camera.offset = Vector2.ZERO if _shake <= 0.0 \
			else Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

# --- Placement: drag a palette item onto a grid cell ---------------------------

func _on_drag_started(kind: String) -> void:
	if Game.is_over:
		return
	_drag_kind = kind
	grid.set_showing(true)  # closed ground is only worth showing while something is being placed
	_set_hovered(null)  # the drag preview takes over; don't compete with a hover ring
	_update_ghost(get_global_mouse_position())

## While a drag is active this runs before the GUI so the ghost tracks the mouse
## and the drop is caught wherever the button is released. With no drag, mouse
## motion instead highlights whichever tower is under the cursor.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _drag_kind == "":
			_update_hover(get_global_mouse_position())
		else:
			_update_ghost(get_global_mouse_position())
		return
	if _drag_kind == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_drop(get_global_mouse_position())
		get_viewport().set_input_as_handled()

## Highlights the tower under the cursor (if any) so its range reads clearly.
func _update_hover(world_pos: Vector2) -> void:
	_set_hovered(_tower_at(world_pos))

## Single place that swaps the highlight, guarding against a tower that has been
## sold (queue_free'd) while it was still the hovered one.
func _set_hovered(tower: Tower) -> void:
	if _hovered == tower:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(false)
	_hovered = tower
	if is_instance_valid(_hovered):
		_hovered.set_highlighted(true)

## Where a tower dropped at `world_pos` would actually stand: the cursor itself, since
## placement is free and `Game.can_build_at()` is the whole rule.
##
## Kept as a named function rather than inlined, because it is the one place placement could
## ever be snapped, quantised or nudged again, and the ghost and the drop MUST agree about
## it — a preview that answers a different question from the drop is worse than no preview.
func _placement_point(world_pos: Vector2) -> Vector2:
	return world_pos

func _update_ghost(world_pos: Vector2) -> void:
	var d: Dictionary = Game.TOWER_DEFS[_drag_kind]
	# The ghost is shown even where a tower cannot go — in red. A ghost that vanishes over
	# bad ground tells the player nothing about WHY, and the board has to keep answering
	# "can I build here" continuously.
	#
	# It sits under the cursor, so the answer the ghost gives is the answer the drop gives;
	# `grid.gd` shades the closed ground behind it, so a red ghost has a visible reason.
	# TOWER_DEFS stores range in Warcraft III units — scale to pixels, exactly as
	# tower.gd's _recompute does, or the ghost circle lies about the tower's reach.
	var at := _placement_point(world_pos)
	var legal := at.is_finite() 			and Game.can_build_at(at, towers_root.get_children()) 			and Game.gold >= _cost(_drag_kind)
	preview.show_at(at if at.is_finite() else world_pos, legal,
			minf(d.get("range", 160.0) * Balance.WC3_RANGE_SCALE, Balance.MAX_TOWER_RANGE))

func _drop(world_pos: Vector2) -> void:
	var kind := _drag_kind
	_drag_kind = ""
	preview.hide()
	grid.set_showing(false)
	var center := _placement_point(world_pos)
	if not center.is_finite() or not Game.can_build_at(center, towers_root.get_children()):
		Audio.play("denied")
		return
	if not Game.spend_gold(_cost(kind)):
		Audio.play("denied")
		return
	var tower := TOWER.instantiate() as Tower
	tower.setup_def(kind)
	tower.position = center
	towers_root.add_child(tower)
	# Aura towers buff their neighbours, so every standing tower re-pulls its surroundings
	# whenever the set changes. Emitted after the add_child so the new tower is included.
	Game.towers_changed.emit()
	Audio.play("build")

func _cost(kind: String) -> int:
	return int(Game.TOWER_DEFS[kind]["cost"])

## True if no tower already sits on the cell centred at this point.
## The tower under this point, or null. Hit-testing uses Game.PICK_RADIUS rather than the
## TOWER_RADIUS that placement uses: the painted body is drawn much wider than the
## footprint, so aiming at what you see used to miss on everything but the tower's middle.
func _tower_at(world_pos: Vector2) -> Tower:
	var best: Tower = null
	var best_d := Game.PICK_RADIUS
	for c in towers_root.get_children():
		var t := c as Tower
		if t == null:
			continue
		var d := t.position.distance_to(world_pos)
		if d <= best_d:
			best_d = d
			best = t
	return best

# --- Click a tower: open its panel ---------------------------------------------

## A left click / tap on a tower opens the tower panel above it (upgrade / fuse / sell).
## Clicking bare ground does nothing here — the panel handles its own dismissal, and it
## accepts the click that closes it so this never runs for the same press.
func _unhandled_input(event: InputEvent) -> void:
	if Game.is_over or _drag_kind != "":
		return
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_handle_tower_click(get_global_mouse_position())

func _handle_tower_click(world: Vector2) -> void:
	var tower := _tower_at(world)
	if tower == null:
		tower_panel.close()
		return
	tower_panel.open_for(tower)

## Upgrades the tower if another level exists and the gold is there; a denied buzz otherwise,
## so a mistap on a maxed / too-expensive tower gives feedback instead of doing nothing.
func _upgrade_tower(tower: Tower) -> void:
	if not tower.can_upgrade() or not Game.spend_gold(tower.upgrade_cost()):
		Audio.play("denied")
		return
	tower.upgrade()
	# An aura deepens with its provider's level, so upgrading one has to reach the towers
	# around it — not just the tower that was tapped.
	Game.towers_changed.emit()
	Audio.play("upgrade")

## Absorbs `element` into `tower`, turning it into whatever combination its element set now
## names. The gold and the board-wide refresh live here rather than in Tower.add_element for
## the same reason upgrading does: one place mutates a tower, and the panel only reports.
## can_fuse() as well as available_elements(): the first is the LEVEL gate (Lv2 for a base
## tower) and the second is the AVATAR gate, and a guard holding only the second would let a
## maxed Lv5 tower be fused down into a Lv3 dual. The panel already refuses to draw the row,
## but the panel is a view — this is the function that must be impossible to get wrong.
func _fuse_tower(tower: Tower, element: String) -> void:
	if not tower.can_fuse() or not tower.available_elements().has(element) \
			or not Game.spend_gold(tower.fusion_cost()):
		Audio.play("denied")
		return
	tower.add_element(element)
	# Sun and Well ARE auras, and a tower that just became one has to reach its neighbours
	# immediately — the same reason upgrading emits this.
	Game.towers_changed.emit()
	Audio.play("upgrade")

# --- Tower panel callbacks ------------------------------------------------------

func _on_panel_upgrade(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	_upgrade_tower(tower)

func _on_panel_fusion(tower: Tower, element: String) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	_fuse_tower(tower, element)

func _on_panel_sell(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	_sell_tower(tower)

## An avatar boss went down. The banner is the whole announcement — there is no popup and
## nothing to dismiss, because the reward is not a choice: both roads simply open from now on.
##
## Two of them, and the banner has to say both: every tower may now fuse this element, AND
## this element's own towers come off Balance.FREE_LEVEL_CAP and can climb to Lv5. A player
## told only about fusion would never look at their Fire towers again.
##
## towers_changed is emitted because the upgrade HINT drawn on a tower reads can_upgrade(),
## which just changed for every tower of this element without any of them being touched.
func _on_avatar_beaten(element: String) -> void:
	hud.set_hint(tr("HINT_AVATAR_DOWN")
			% [element.capitalize(), element.capitalize(), Balance.MAX_LEVEL,
				element.capitalize()])
	Game.towers_changed.emit()
	Audio.play("upgrade")

## Removes the tower and refunds the gold sunk into it — all of it if the tower never fired,
## most of it otherwise (see Tower.sell_value / Tower.has_fired).
func _sell_tower(tower: Tower) -> void:
	Audio.play("sell")
	Game.add_gold(tower.sell_value())
	if _hovered == tower:
		_hovered = null  # it is about to be freed; never keep a dangling reference
	tower.queue_free()
	# queue_free() only takes effect at the end of the frame, so the sold tower is still a
	# child right now — drop it from the tree first or the neighbours would re-pull an aura
	# from a tower that no longer exists.
	towers_root.remove_child(tower)
	Game.towers_changed.emit()

func _on_game_over() -> void:
	Audio.play("gameover")
	# Bank the run BEFORE the summary draws: finish_run updates the best-wave record and
	# the wallet, both of which the summary reports.
	var earned := Meta.finish_run(Game.wave_reached)
	end_screen.show_summary(earned, false)

## Standard mode's win path (GAME_STRATEGY_V2.md §11.1, BUILD NEXT #4) — same bookkeeping as
## a loss (bank the run, show the summary), framed as a win rather than a result. audio.gd
## already synthesizes a "victory" jingle distinct from "gameover"; nothing played it before
## there was a way to win.
func _on_victory() -> void:
	Audio.play("victory")
	var earned := Meta.finish_run(Game.wave_reached)
	# Stars (GAME_STRATEGY_V2.md §12.4, BUILD NEXT #8): ★ for finishing at all — true here,
	# since this only runs on Game.victory — ★★ for ≤5 lives lost, ★★★ for a flawless clear.
	# Compared against the RULESET's own starting lives, not a hardcoded 20, so Easy's extra
	# lives do not make ★★★ easier to reach than Normal's.
	var lives_lost := Balance.ruleset_start_lives(Game.ruleset) - Game.lives
	var stars := 3 if lives_lost <= 0 else (2 if lives_lost <= 5 else 1)
	Meta.record_stars(Game.ruleset, stars)
	end_screen.show_summary(earned, true, stars)
