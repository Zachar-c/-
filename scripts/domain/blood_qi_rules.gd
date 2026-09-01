class_name BloodQiRules
extends RefCounted


# Spec-v4 phase-2 (T8.1): blood-qi dual-tag single inventory (§15.1) and qi
# accumulation (§15.2). Pure static, deterministic, zero dice. Blood qi is
# one divisible material carrying both dao tags; the blood and qi paths
# contest the SAME RunState.materials stock - the single-source invariant.
# The legacy use_material "+N health" semantics is re-declared here as the
# pure consume_blood_qi entry (resolver keeps its old path until T9.2).


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# §15.1 single-stock claim: whichever path (blood / qi) deducts, the other
# immediately sees the same reduced inventory - there is exactly one stock.
static func claim_inventory(materials: Dictionary, material_id: String, amount: float, _claiming_path: String) -> Dictionary:
	var remaining := float(materials.get(material_id, 0.0))
	if amount <= 0.0 or remaining < amount:
		return {"ok": false, "reason": "insufficient_inventory", "materials": materials}
	var out := materials.duplicate(true)
	out[material_id] = remaining - amount
	return {"ok": true, "reason": "", "materials": out}


# §15.1 blood yield: target health x ratio x rank multiplier x death-method
# multiplier. Skim keeps the basic harvest; deep extraction spends time and
# tools and leaves a blood trail (world-consistency hook for §16).
static func blood_yield(target_health: float, target_rank: int, death_multiplier: float, means: String, cat: Dictionary) -> Dictionary:
	var ratio := _b(cat, "blood_yield_ratio", 0.01)
	var base := maxf(0.0, target_health) * ratio * float(
			GuBalanceScript.rank_multiplier(maxi(1, target_rank), cat)) * maxf(0.0, death_multiplier)
	var extra := {}
	if means == "deep":
		base += base * _b(cat, "deep_blood_multiplier", 0.5)
		extra = {"time_cost": 1, "tool_required": true, "blood_trail": 1}
	return {"yield": base, "means": means, "extra": extra}


# §15.1 self-bleed: the player sacrifices health to condense blood qi,
# never above their own turn. A foreseeable death carries the
# second-confirmation marker (battle2 strike_preflight pattern) - silent
# death is not allowed.
static func self_bleed(cultivator_health: float, cultivator_rank: int, target_rank: int, amount: float, cat: Dictionary) -> Dictionary:
	if target_rank > cultivator_rank:
		return {"ok": false, "reason": "bleed_rank_exceeds_cultivator", "lethal_confirm_required": false}
	if amount <= 0.0 or cultivator_health < amount:
		return {"ok": false, "reason": "insufficient_health", "lethal_confirm_required": false}
	return {
		"ok": true,
		"reason": "",
		"health_cost": amount,
		"blood_amount": amount,
		"lethal_confirm_required": amount >= cultivator_health,
		"cause": "self_bleed" if amount >= cultivator_health else "",
		"rank_multiplier": float(GuBalanceScript.rank_multiplier(maxi(1, target_rank), cat)),
	}


# §15.1 legacy semantic takeover (pure version): consuming blood-qi material
# applies the material's declared use effect (e.g. "+N health"). The table's
# use-effect maps power this; resolver's old path stays untouched until the
# T9.2 command surface and T10.1 cleanup.
static func consume_blood_qi(materials: Dictionary, material_id: String, amount: float, use_effect: Dictionary) -> Dictionary:
	var claim := claim_inventory(materials, material_id, amount, "consume")
	if not bool(claim["ok"]):
		return {"ok": false, "reason": claim["reason"], "materials": materials, "effect_events": []}
	return {
		"ok": true,
		"reason": "",
		"materials": claim["materials"],
		"consumed": amount,
		"effect": use_effect.duplicate(true),
		"effect_events": [{"kind": "material_consumed", "material_id": material_id, "amount": amount}],
	}


# §15.1 trade gate: blood-path resources refuse the public channel (the
# market low-liquidity / refusal continuity) and enter gated secret channels
# with declared world consequences for §16 events.
static func trade_gate(material: Dictionary, channel: String, _cat: Dictionary) -> Dictionary:
	if channel == "public":
		return {"ok": false, "reason": "refused_public_channel"}
	if channel == "secret":
		return {
			"ok": true,
			"reason": "",
			"requires": "secret_market_gate",
			"consequences": ["attack_risk", "pursuit_risk", "faction_hostility"],
			"material_id": str(material.get("id", "")),
		}
	return {"ok": false, "reason": "unknown_channel"}


# §15.2 qi accumulation: more input, stronger effect - but the curve, cap
# and minimum unit must be declared by a specific gu effect. Without a
# declared curve the accumulation refuses: there is no universal
# material-to-damage conversion anywhere.
static func accumulate_qi(inputs: Dictionary, effect_curve: Dictionary) -> Dictionary:
	if effect_curve.is_empty():
		return {"ok": false, "reason": "no_declared_curve"}
	var min_units := float(effect_curve.get("min_units", 1.0))
	var total_input := 0.0
	for _material_id in inputs:
		total_input += float(inputs[_material_id])
	if total_input < min_units:
		return {"ok": false, "reason": "below_min_units"}
	var cap := float(effect_curve.get("cap", INF))
	var units_per := float(effect_curve.get("units_per_step", 1.0))
	var consumed := minf(total_input, maxf(0.0, cap))
	return {
		"ok": true,
		"reason": "",
		"consumed": consumed,
		"effect_units": consumed * units_per,
		"capped": total_input > cap,
	}
