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
		_:
			# Loud on purpose. A misspelled stat would otherwise fold into nothing and the
			# card would silently do exactly zero — the hardest kind of balance bug to see,
			# because the upgrade still appears, still gets picked, and still reads fine.
			push_warning("TowerMods: unknown stat '%s' in effect %s" % [stat, effect])
