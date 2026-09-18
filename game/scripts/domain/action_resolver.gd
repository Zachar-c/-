class_name ActionResolver
extends RefCounted


# Spec-v4 phase-2 (T4.2): battle2 basic actions, distance bands, speed
# conflicts and the §10.4 defense pipeline. Pure domain / pure data, zero
# dice. Every beast number projects through GuBalance - no hand-written
# copies, no continuous time units, no fractional progress.


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const ConstantsScript = preload("res://scripts/domain/battle2/combat_constants.gd")


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# ---- §13.3 distance bands ------------------------------------------------

static func distance_index(distance: String) -> int:
	return maxi(0, ConstantsScript.DISTANCES.find(distance))


# Basic move changes exactly one band per action; edges stay put.
static func move_one_band(current: String, direction: String) -> String:
	var index := distance_index(current)
	if direction == "closer":
		return ConstantsScript.DISTANCES[mini(index + 1, ConstantsScript.DISTANCES.size() - 1)]
	return ConstantsScript.DISTANCES[maxi(index - 1, 0)]


# §13.3: an ordinary unarmed strike is only initiated and landed at contact.
static func strike_possible(attacker_distance: String, target_distance: String) -> bool:
	return attacker_distance == ConstantsScript.DISTANCE_TOUCH and target_distance == ConstantsScript.DISTANCE_TOUCH


# §14.2 unarmed raw damage via GuBalance (thin projection).
static func unarmed_strike_power(strength: float, action_multiplier: float, cat: Dictionary) -> float:
	return GuBalanceScript.unarmed_raw_damage(strength, action_multiplier, cat)


# §13.2/§13.3: strikes land at completion; if the target already left contact
# the strike stops - the spent thought is not refunded and nothing is paid.
static func strike_resolution(target_distance: String, striker_distance: String, power: float) -> Dictionary:
	if not strike_possible(striker_distance, target_distance):
		return {
			"status": "stopped_target_left_contact",
			"thought_refunded": false,
			"damage": 0.0,
		}
	return {
		"status": "hit",
		"thought_refunded": false,
		"damage": power,
	}


# ---- §13.4 disengage reaction window --------------------------------------

# Moving from touch to close opens exactly one disengage reaction window.
static func disengage_window(from_distance: String, to_distance: String) -> Dictionary:
	return {"open": from_distance == ConstantsScript.DISTANCE_TOUCH and to_distance == ConstantsScript.DISTANCE_CLOSE}


static func is_legal_disengage_reaction(action: String) -> bool:
	return ConstantsScript.DISENGAGE_REACTIONS.has(action)


# §13.4: a reaction needs reserved thought AND a legal reaction; there is no
# free attack when someone leaves contact.
static func reaction_allowed(has_reserved_thought: bool, action: String) -> Dictionary:
	if not has_reserved_thought:
		return {"ok": false, "reason": "no_reserved_thought"}
	if not is_legal_disengage_reaction(action):
		return {"ok": false, "reason": "not_a_legal_reaction"}
	return {"ok": true, "reason": ""}


# ---- §13.5 speed conflicts -------------------------------------------------

static func conflict_speed(current_speed: int, action_speed_modifier: int) -> int:
	return current_speed + action_speed_modifier


static func _phase_order(phase: String) -> int:
	# instant=0 < quick=1 < standard=2 < windup=3; declare/end never race.
	match phase:
		"instant":
			return 0
		"quick":
			return 1
		"standard":
			return 2
		"windup":
			return 3
	return 99


# §13.5: only same-phase same-round direct conflicts race; phase beats speed;
# equal speed resolves simultaneously (mutual annihilation allowed). Returns
# the side that resolves first: "a_first" / "b_first" / "simultaneous".
static func conflict_order(phase_a: String, speed_a: int, phase_b: String, speed_b: int) -> String:
	var order_a := _phase_order(phase_a)
	var order_b := _phase_order(phase_b)
	if order_a != order_b:
		return "a_first" if order_a < order_b else "b_first"
	if speed_a != speed_b:
		return "a_first" if speed_a > speed_b else "b_first"
	return "simultaneous"


# ---- §10.4 defense order -----------------------------------------------------
#
# raw -> temporary absorb -> body fixed defense -> ratio reduction -> health.
# Fixed defense may reduce to zero; there is no forced minimum damage.

static func resolve_damage(raw: float, temporary_absorb: float, fixed_defense: float, ratio_pct: float) -> Dictionary:
	var remaining := raw
	var absorbed := minf(remaining, maxf(0.0, temporary_absorb))
	remaining -= absorbed
	var temporary_left := maxf(0.0, temporary_absorb - absorbed)
	# Fixed defense is body armor: subtracts directly, never below zero.
	remaining = maxf(0.0, remaining - maxf(0.0, fixed_defense))
	# Ratio reduction applies to what is left.
	var ratio := clampi(int(ratio_pct), 0, 100)
	remaining = remaining * (1.0 - float(ratio) / 100.0)
	return {
		"damage": remaining,
		"temporary_left": temporary_left,
		"absorbed": absorbed,
		"order": "temp,fixed,ratio",
	}


# ---- §14.3 beasts through GuBalance ----------------------------------------

# §14.3: beast health/strength/capacity share beast_scale(rank); same-rank
# heavy = strength * unarmed_damage_ratio; natural fixed defense =
# GuBalance.fixed_defense(rank). Every value projects - nothing is copied.
static func beast_stats(rank: int, cat: Dictionary) -> Dictionary:
	var scale := float(GuBalanceScript.beast_scale(rank, cat))
	return {
		"health": scale,
		"strength": scale,
		"body_capacity": scale,
		"heavy": unarmed_strike_power(scale, 1.0, cat),
		"fixed_defense": float(GuBalanceScript.fixed_defense(rank, cat)),
	}
