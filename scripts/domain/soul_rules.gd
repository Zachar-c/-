class_name SoulRules
extends RefCounted


# Spec-v4 phase-2 (T8.2 + P0.1): soul dao - the five soul quantities
# (§15.4), three operations, gated soul collection (§15.3, acceptance #17)
# and the bestiality endpoint gate (§16.10). Pure static, deterministic.
# Every tuning value comes from balance.json (P0.1: burst ratio, calm stage
# thresholds, beast-nature thresholds). The five quantities live under NEW
# cultivator keys and never touch the legacy soul / soul_max /
# soul_control_limit (T10.1 retirement scope). Irreversible paths
# (float-burst death, bestiality) only produce confirmation markers - no
# numeric threshold ever ends a run silently.


const SOUL_BURST_CAUSE := "soul_burst"
const BEASTIALITY_ENDPOINT := "bestiality"


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


static func quantity_names() -> Array:
	return ["soul_magnitude", "soul_safe_capacity", "soul_calm", "soul_nature", "beast_nature"]


# §15.4 snapshot of the five quantities only (coupling guard helper).
static func snapshot(cultivator: Dictionary) -> Dictionary:
	return {
		"soul_magnitude": float(cultivator.get("soul_magnitude", 0.0)),
		"soul_safe_capacity": float(cultivator.get("soul_safe_capacity", 0.0)),
		"soul_calm": int(cultivator.get("soul_calm", 0)),
		"soul_nature": str(cultivator.get("soul_nature", "human")),
		"beast_nature": float(cultivator.get("beast_nature", 0.0)),
	}


# §15.4: one nature at a time - assigning replaces, mixing is rejected.
static func set_nature(cultivator: Dictionary, nature: String) -> Dictionary:
	if str(nature).is_empty():
		return {"ok": false, "reason": "empty_nature", "cultivator": cultivator}
	var out := cultivator.duplicate(true)
	out["soul_nature"] = nature
	return {"ok": true, "reason": "", "cultivator": out}


static func validate_nature(nature_value: Variant) -> Dictionary:
	if nature_value is String:
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "nature_must_be_single"}


# §15.4 the three operations - the module owns the rules and bounds; the
# caller declares the costs / efficiencies per means.
static func strengthen_soul(cultivator: Dictionary, amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "reason": "invalid_amount", "cultivator": cultivator}
	var out := cultivator.duplicate(true)
	out["soul_magnitude"] = float(out.get("soul_magnitude", 0.0)) + amount
	return {"ok": true, "reason": "", "cultivator": out}


static func refine_soul(cultivator: Dictionary, amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "reason": "invalid_amount", "cultivator": cultivator}
	var out := cultivator.duplicate(true)
	out["soul_safe_capacity"] = float(out.get("soul_safe_capacity", 0.0)) + amount
	return {"ok": true, "reason": "", "cultivator": out}


static func calm_soul(cultivator: Dictionary, amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "reason": "invalid_amount", "cultivator": cultivator}
	var out := cultivator.duplicate(true)
	out["soul_calm"] = clampi(int(out.get("soul_calm", 0)) + int(amount), 0, 100)
	return {"ok": true, "reason": "", "cultivator": out}


# §15.3 collection gate (acceptance #17): only soulless targets yield zero
# with a reason; ordinary souls require a declared means (capacity /
# efficiency / loss); without a means, or with a full capacity, no stock is
# ever created. Beast souls drop physical cores through the four loot kinds
# (LootRules) - not through this soft-stock path.
static func collect_soul(target: Dictionary, means: Dictionary, _cultivator: Dictionary) -> Dictionary:
	if not bool(target.get("has_soul", false)):
		return {"ok": false, "reason": "soulless_target", "yield": 0.0}
	if means.is_empty():
		return {"ok": false, "reason": "no_means_declared", "yield": 0.0}
	var capacity := float(means.get("capacity", 0.0))
	var weight := float(target.get("soul_weight", 0.0))
	if weight > capacity:
		return {"ok": false, "reason": "means_capacity_full", "yield": 0.0}
	var efficiency := float(means.get("efficiency", 0.0))
	var loss := float(means.get("loss", 0.0))
	var yield_value := weight * efficiency * (1.0 - loss)
	return {"ok": true, "reason": "", "yield": yield_value}


# §15.4: floating above the safe capacity is allowed and visibly unstable.
static func float_above_capacity(cultivator: Dictionary) -> bool:
	return float(cultivator.get("soul_magnitude", 0.0)) > float(cultivator.get("soul_safe_capacity", 0.0))


# §15.4 (P0.1): a growth that would burst to death carries the
# second-confirmation marker (cause soul_burst) - never silent. The burst
# line scales off the safe capacity via balance.json.
static func soul_growth_forecast(cultivator: Dictionary, growth: float, cat: Dictionary) -> Dictionary:
	var magnitude := float(cultivator.get("soul_magnitude", 0.0)) + maxf(0.0, growth)
	var capacity := float(cultivator.get("soul_safe_capacity", 0.0))
	var burst_line := capacity * _b(cat, "soul_burst_capacity_ratio", 2.0)
	var lethal := magnitude > burst_line
	return {
		"lethal_confirm_required": lethal,
		"cause": SOUL_BURST_CAUSE if lethal else "",
		"magnitude_after": magnitude,
	}


# §15.4 composure layers (P0.1): low calm -> emotional -> beast emerging ->
# soul departure / loss of control; the stage thresholds ride balance.json.
static func composure_layers(cultivator: Dictionary, cat: Dictionary) -> Dictionary:
	var calm := int(cultivator.get("soul_calm", 0))
	return {
		"emotional": calm < _b(cat, "soul_calm_emotional_below", 40.0),
		"beast_emerging": calm < _b(cat, "soul_calm_beast_below", 25.0),
		"soul_departure_risk": calm < _b(cat, "soul_calm_departure_below", 10.0),
	}


static func beast_nature_emerging(cultivator: Dictionary, cat: Dictionary) -> bool:
	return float(cultivator.get("beast_nature", 0.0)) > _b(cat, "beast_nature_emerging_above", 0.5)


# §15.4 (P0.1): thresholds are shown ahead with the keep / use / purify
# options; the high-risk mark rides beast_nature_threshold.
static func beast_sight(cultivator: Dictionary, cat: Dictionary) -> Dictionary:
	var threshold := _b(cat, "beast_nature_threshold", 1.0)
	var current := float(cultivator.get("beast_nature", 0.0))
	return {
		"threshold": threshold,
		"current_beast": current,
		"risk_level": "high" if current >= threshold else "escalating",
		"options": ["keep", "use", "purify"],
	}


# §16.10 (P0.1): the bestiality endpoint is a non-death special ending
# requiring the player's active second confirmation - reaching the danger
# condition (beast nature above twice the threshold while composure has
# departed) only returns the trigger marker, never a terminal state.
static func bestiality_endpoint_check(cultivator: Dictionary, cat: Dictionary) -> Dictionary:
	var threshold := _b(cat, "beast_nature_threshold", 1.0)
	var triggered := float(cultivator.get("beast_nature", 0.0)) >= threshold * 2.0 \
			and int(cultivator.get("soul_calm", 0)) < _b(cat, "soul_calm_departure_below", 10.0)
	return {
		"beastiality_triggered": triggered,
		"confirm_required": triggered,
		"endpoint": BEASTIALITY_ENDPOINT if triggered else "",
		"terminal": false,
	}
