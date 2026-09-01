class_name Battle2BodyRules
extends RefCounted


# Spec-v4 phase-2 (T4.3): deterministic dodge (§13.6), deterministic grapple
# (§13.7) and strength overload (§14.2) with a lethal preflight marker.
# Pure domain / pure data, zero dice: dodge and grapple succeed or fail purely
# from declared conditions - there is no hit roll anywhere in this module.
# Overload numbers project through GuBalance (thin delegation only).


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")

const DISTANCE_TOUCH := "touch"


# ---- §13.6 deterministic dodge ---------------------------------------------
#
# Succeeds whenever the declared conditions hold: the attack allowed a basic
# dodge and opened a window, the dodger pays 1 thought, and is not grappled /
# bound / terrain-restricted. Failure only comes from unmet conditions or a
# lost direct conflict. Never by dice; the distance band is unchanged.

static func dodge_resolution(conditions: Dictionary, has_thought: bool) -> Dictionary:
	if not has_thought:
		return {"ok": false, "reason": "no_thought", "status": "failed"}
	if not bool(conditions.get("allow_dodge", false)):
		return {"ok": false, "reason": "dodge_not_allowed", "status": "failed"}
	if not bool(conditions.get("window_open", false)):
		return {"ok": false, "reason": "window_closed", "status": "failed"}
	if bool(conditions.get("grappled", false)):
		return {"ok": false, "reason": "grappled_blocks_dodge", "status": "failed"}
	if bool(conditions.get("bound", false)):
		return {"ok": false, "reason": "bound_blocks_dodge", "status": "failed"}
	if bool(conditions.get("restricted", false)):
		return {"ok": false, "reason": "terrain_restricted", "status": "failed"}
	return {"ok": true, "reason": "", "status": "dodged"}


# §13.6: basic dodge stays inside the current distance band.
static func dodge_changes_band() -> bool:
	return false


# ---- §13.7 deterministic grapple -------------------------------------------
#
# Contact-only, 1 thought, standard phase by default. The target may dodge in
# the reaction window; otherwise a strength contest resolves: no resisted
# thought means the hold establishes; with resistance the attacker must be
# strictly stronger - equal strength favours the defender.

static func grapple_preflight(attacker_distance: String, target_distance: String, has_thought: bool) -> Dictionary:
	if not (attacker_distance == DISTANCE_TOUCH and target_distance == DISTANCE_TOUCH):
		return {"ok": false, "reason": "not_at_contact"}
	if not has_thought:
		return {"ok": false, "reason": "no_thought"}
	return {"ok": true, "reason": ""}


static func grapple_contest(attacker_strength: float, target_strength: float, target_resists: bool) -> Dictionary:
	if not target_resists:
		return {"ok": true, "reason": "", "established": true}
	if attacker_strength > target_strength:
		return {"ok": true, "reason": "", "established": true}
	return {"ok": false, "reason": "not_stronger", "established": false}


# §13.7: being grappled never auto-forbids gu activation or other actions.
static func grapple_blocks_gu_activation() -> bool:
	return false


static func grapple_blocks_basic_actions() -> bool:
	return false


# §13.7: the holder pays 1 thought per round while keeping the hold; stopping
# the payment releases automatically. The grapple usage slot is the same
# basic-action slot tracked by the turn ledger.
static func hold_thought_per_round() -> int:
	return 1


static func hold_state(paying_thought: bool, _hold: Dictionary) -> Dictionary:
	if not paying_thought:
		return {"status": "released_not_paid"}
	return {"status": "held"}


# §13.7: escaping is another grapple action re-running the same contest.
static func escape_uses_grapple_contest() -> bool:
	return true


# ---- §14.2 strength overload ------------------------------------------------

# Basic move keys off body capacity; exceeding it is voluntary.
static func safe_strength(body_capacity: float) -> float:
	return body_capacity


static func unarmed_strike_damage(strength: float, action_multiplier: float, cat: Dictionary) -> float:
	return GuBalanceScript.unarmed_raw_damage(strength, action_multiplier, cat)


# §14.2: self damage only for the part above body capacity (thin delegate).
static func overload_self_damage(actual_strength: float, body_capacity: float, cat: Dictionary) -> float:
	return GuBalanceScript.overload_self_damage(actual_strength, body_capacity, cat)


# Overload preflight: marks a foreseeable death so the command surface can
# force the second confirmation - silent death is never allowed. Ordinary
# hp loss does not lower capacity/strength/speed (the projections are
# health-independent, enforced by the acceptance test).
static func strike_preflight(actual_strength: float, body_capacity: float, current_health: float, cat: Dictionary) -> Dictionary:
	var self_damage := overload_self_damage(actual_strength, body_capacity, cat)
	var lethal := self_damage >= current_health
	return {
		"lethal_confirm_required": lethal,
		"cause": "strength_overload" if lethal else "",
		"self_damage": self_damage,
	}