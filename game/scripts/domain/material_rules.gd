class_name MaterialRules
extends RefCounted


# Spec-v4 phase-2 (T5.1): unified material rules - high-rank to low-rank
# feeding equivalence (§6.2) and lossy step-by-step refining (§6.3).
# Pure static, deterministic, config-driven: every multiplier comes from
# balance.json through GuBalance projections. No behavior is switched here -
# use_material / feeding / trading still run their legacy paths.


const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# §6.2/§6.3 turn value ratio 2^steps through the GuBalance rank projection -
# the balance key stays single-source inside gu_balance.gd (drift gate), so no
# key-name literals live here.
static func _turn_ratio(steps: int, cat: Dictionary) -> float:
	if steps >= 0:
		return float(GuBalanceScript.rank_multiplier(steps + 1, cat))
	return 1.0 / float(GuBalanceScript.rank_multiplier(-steps + 1, cat))


# §6.2: a material's feeding equivalence at the target turn level. One unit of
# a material with reference_value V at rank R is worth V * (central turn
# ratio) ^ (R - need_rank) units of need_rank feeding. Below the target rank
# the equivalence drops below 1 (a low-rank material cannot cover a high-rank
# need by itself).
static func downscale_equivalent(material: Dictionary, need_rank: int, cat: Dictionary) -> float:
	var rank := int(material.get("rank", 1))
	var steps := rank - maxi(1, need_rank)
	return float(material.get("reference_value", 1)) * _turn_ratio(steps, cat)


# §6.2 feeding resolution:
# - divisible materials deduct precisely: only the needed equivalent share is
#   consumed, the remainder stays in the material (no waste);
# - indivisible materials (complete bones, soul cores) are consumed in full;
#   the value beyond the current need is wasted and never refunded.
# prerequisite: the caller has already satisfied any named diet requirement
# (see named_diet_allowed).
static func downscale_feed(material: Dictionary, need_rank: int, need_units: float, cat: Dictionary) -> Dictionary:
	var equivalent := downscale_equivalent(material, need_rank, cat)
	if bool(material.get("divisible", false)):
		var taken := minf(maxf(0.0, need_units), equivalent)
		var fraction := 1.0 if equivalent <= 0.0 else taken / equivalent
		return {
			"ok": true, "equivalent": equivalent,
			"consumed_fraction": fraction,
			"remaining_fraction": maxf(0.0, 1.0 - fraction),
			"wasted": 0.0,
		}
	var wasted := maxf(0.0, equivalent - maxf(0.0, need_units))
	return {
		"ok": true, "equivalent": equivalent,
		"consumed_fraction": 1.0,
		"remaining_fraction": 0.0,
		"wasted": wasted,
	}


# §6.2: named exclusive diets must match by exact material name; value or rank
# never substitute (feeding diets are identity-bound, not value-bound).
static func named_diet_allowed(material_id: String, required_material_id: String) -> bool:
	return str(material_id) == str(required_material_id) and not str(material_id).is_empty()


# §6.3 lossy refining: each step multiplies by material_refine_efficiency
# (0.5 today) when ascending, and by the central turn value ratio (2.0 per
# step) when descending. Multi-step moves always resolve step by step - there
# are no lossless jumps. Equivalent quantity ratio today: 4:1 (four 1-turn
# units refine into one 3-turn unit: 4 * 0.5 * 0.5 = 1).
static func refine_up(input_value: float, from_rank: int, to_rank: int, cat: Dictionary) -> float:
	var out := input_value
	var efficiency := _b(cat, "material_refine_efficiency", 0.5)
	var downward_value := _turn_ratio(1, cat)
	if to_rank >= from_rank:
		for _step in range(from_rank, to_rank):
			out *= efficiency
	else:
		for _step in range(to_rank, from_rank):
			out *= downward_value
	return out
