extends RefCounted
class_name TowerMods
## The folded total of every run modifier that applies to ONE (tower id, element) pair.
##
## Towers never walk the modifier list themselves: Run folds it down to one of these and
## caches it, so a card pick costs one fold per distinct pair (at most a handful) rather
## than one per placed tower (up to 40).
##
## Multiplicative fields start at 1.0 and additive ones at 0.0, so an unmodified tower
## folds to the identity and `_recompute()` needs no special case for "no modifiers".

var damage_mult: float = 1.0
var damage_add: float = 0.0
var range_mult: float = 1.0
var range_add: float = 0.0
## Attack speed is a DIVISOR on fire_interval, not a multiplier on it. Two "+50% attack
## speed" cards written as `interval *= (1.0 - 0.5)` would reach zero and then go negative,
## and a non-positive interval makes the cooldown branch fire every single frame. Dividing
## can only ever approach zero, and Balance.MIN_FIRE_INTERVAL catches the rest.
var attack_speed_mult: float = 1.0
var poison_mult: float = 1.0
var splash_mult: float = 1.0
## Pulls slow_factor toward 0 (a harder slow); 1.0 leaves it alone. Applied as
## `1 - (1 - factor) * slow_power` so it scales the SLOW rather than the speed — doubling
## a 0.55 factor would make the enemy faster, which is the opposite of what the card says.
var slow_power: float = 1.0

# --- BUILD NEXT #9 card pool (GAME_STRATEGY_V2.md §6.3) -------------------------
var burn_time_mult: float = 1.0   ## Wick: burn duration.
var slow_time_add: float = 0.0    ## Permafrost: seconds added to every chill.
var vs_flying_mult: float = 1.0   ## Spore: damage multiplier vs flying targets only.
## Backdraft: burn ALSO applies this slow factor (1.0 = no slow) — read at hit time in
## projectile.gd, not baked into a static stat, since it rides whichever hit actually lands.
var burn_slow_factor: float = 1.0
## Aftershock: fraction of splash damage re-dealt 0.3s later at the same point (0 = off).
var splash_echo_mult: float = 0.0
## Overclock: every Nth shot deals double damage (0 = off).
var overclock_every: int = 0
## Groundwork: Earth ignores can_hit_flying and hits half splash radius (both toggle
## together — it is one card, not two independent stats).
var groundwork: bool = false
## Deadeye: targets lowest CURRENT health instead of furthest along the road.
var target_lowest_hp: bool = false
## STEAM (Fire+Water overlap): Fire's burn deals extra damage to a target Water has chilled.
var chill_burn_mult: float = 1.0
## EROSION (Water+Earth overlap): Earth's hits deal extra damage to a chilled target.
var chill_hit_mult: float = 1.0

## Folds one effect record from an upgrade definition into these totals.
func fold(effect: Dictionary) -> void:
	var stat := String(effect.get("stat", ""))
	var additive := String(effect.get("op", "mult")) == "add"
	var v := float(effect.get("value", 1.0))
	match stat:
		"damage":
			if additive: damage_add += v
			else: damage_mult *= v
		"range":
			if additive: range_add += v
			else: range_mult *= v
		"attack_speed": attack_speed_mult *= v
		"poison": poison_mult *= v
		"splash": splash_mult *= v
		"slow_power": slow_power *= v
		"burn_time": burn_time_mult *= v
		"slow_time": slow_time_add += v
		"vs_flying": vs_flying_mult *= v
		"burn_slow": burn_slow_factor *= v
		"splash_echo": splash_echo_mult = v
		"overclock_every": overclock_every = int(v)
		"groundwork": groundwork = true
		"target_lowest_hp": target_lowest_hp = true
		"chill_burn": chill_burn_mult *= v
		"chill_hit": chill_hit_mult *= v
		_:
			# Loud on purpose. A misspelled stat would otherwise fold into nothing and the
			# card would silently do exactly zero — the hardest kind of balance bug to see,
			# because the upgrade still appears, still gets picked, and still reads fine.
			push_warning("TowerMods: unknown stat '%s' in effect %s" % [stat, effect])
