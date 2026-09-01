class_name FeedingRules
extends RefCounted


# Spec-v4 phase-2 (T6.1): layer-wide feeding settlement (§7.1), two-stage
# hunger (§7.2), the deterministic substitution formulas (§7.4) and the
# economy soft-cap report (§7.3). Pure static, deterministic, config-driven -
# every multiplier comes from balance.json. Feeding has no slot system at all
# (unlimited holding is accepted; the soft cap only reports). High-rank to
# low-rank feeding delegates to MaterialRules (acceptance #9).


const MaterialRulesScript = preload("res://scripts/domain/material_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")

const FEED_TIER_NAMES := ["small", "standard", "large"]


static func _b(cat: Dictionary, key: String, fallback: float) -> float:
	return float(cat.get("balance", {}).get(key, fallback))


# §7.1: standard gu consumes 1 same-rank matching material equivalent per
# layer, scaled by the feed tier (small 0.5 / standard 1.0 / large 2.0); the
# actual gu rank decides the value - a high-rank gu costs in full even in a
# low-rank hand.
static func feed_cost(definition: Dictionary, instance: Dictionary, cat: Dictionary) -> float:
	var rank := int(instance.get("rank", 1))
	var value: float = float(GuBalanceScript.rank_multiplier(maxi(1, rank), cat))
	return _feed_tier_multiplier(definition, cat) * value


static func _feed_tier_multiplier(definition: Dictionary, cat: Dictionary) -> float:
	var name := str(definition.get("feed_tier", "standard"))
	var index := maxi(0, FEED_TIER_NAMES.find(name))
	var tiers: Array = cat.get("balance", {}).get("feed_tier", [0.5, 1.0, 2.0])
	if index >= tiers.size():
		return 1.0
	return float(tiers[index])


# §7.4 mixed universal rate: sum(amount_i * rate_i) / sum(amount_i). Low
# quality always drags the mix down; extra stacking never exceeds it.
static func mixed_replacement(entries: Array) -> float:
	var total := 0.0
	var weighted := 0.0
	for entry in entries:
		var amount := float((entry as Dictionary).get("amount", 0.0))
		var rate := float((entry as Dictionary).get("rate", 0.0))
		total += amount
		weighted += amount * rate
	if total <= 0.0:
		return 0.0
	return weighted / total


# §7.4 resolution: universal food covers at most need x mixed rate; the
# remainder is a matching requirement even at 95%; matching fills it; ordinary
# mismatched materials act as emergency substitution capped at 50% of the
# need (quick_substitute_cap). Named exclusive diet goes through
# MaterialRules.named_diet_allowed at the caller (identity-bound).
static func resolve_need(need: float, matching_available: float, universal_entries: Array, emergency_materials: Dictionary, cat: Dictionary) -> Dictionary:
	var safe_need := maxf(0.0, need)
	var mixed := mixed_replacement(universal_entries)
	var universal_total := 0.0
	for entry in universal_entries:
		universal_total += float((entry as Dictionary).get("amount", 0.0))
	var universal_fulfilled := minf(universal_total, safe_need * mixed)
	var matching_required := maxf(0.0, safe_need - universal_fulfilled)
	var matching_used := minf(matching_required, maxf(0.0, matching_available))
	var remaining_after_matching := maxf(0.0, matching_required - matching_used)
	var emergency_total := 0.0
	for _material_id in emergency_materials:
		emergency_total += float(emergency_materials[_material_id])
	var emergency_cap := safe_need * _b(cat, "quick_substitute_cap", 0.5)
	var emergency_used := minf(emergency_cap, minf(emergency_total, remaining_after_matching))
	var unmet := maxf(0.0, remaining_after_matching - emergency_used)
	return {
		"matching_used": matching_used,
		"universal_used": universal_fulfilled,
		"emergency_used": emergency_used,
		"unmet": unmet,
		"matching_required": matching_required,
	}


# §7.2: a hungry gu (hunger_phase >= 1) cannot activate normally next layer.
static func can_activate(instance: Dictionary) -> bool:
	return int(instance.get("hunger_phase", 0)) < 1


# Layer-wide settlement. options may carry:
#   {"matching_material_ids": [ids] (with normal equivalents),
#    "universal_materials": {id: rate} (universal food with its own rate),
#    "emergency_material_ids": [ids] (ordinary mismatched materials),
#    "feeding_order": [instance_id, ...] (player-chosen feeding priority)}
# Returns the per-gu settlement, the pantry after deduction, and structured
# events (gu_starved entries carry the precise cause - never silent deaths).
static func layer_settle(instances: Array, pantry: Dictionary, options: Dictionary, catalog: Dictionary) -> Dictionary:
	var pantry_after := (pantry as Dictionary).duplicate(true)
	var events: Array = []
	var settled: Array = []
	var feeding_order: Array = options.get("feeding_order", [])
	var instances_by_id := {}
	for instance in instances:
		instances_by_id[str((instance as Dictionary).get("instance_id", ""))] = instance
	for instance_id in feeding_order:
		if instances_by_id.has(str(instance_id)):
			var settled_one := _settle_instance(instances_by_id[str(instance_id)], pantry_after, options, catalog)
			settled.append(settled_one["record"])
			if not (settled_one["event"] as Dictionary).is_empty():
				events.append(settled_one["event"])
			instances_by_id.erase(str(instance_id))
	for instance in instances:
		var key := str((instance as Dictionary).get("instance_id", ""))
		if not instances_by_id.has(key):
			continue
		var settled_one := _settle_instance(instances_by_id[key], pantry_after, options, catalog)
		settled.append(settled_one["record"])
		if not (settled_one["event"] as Dictionary).is_empty():
			events.append(settled_one["event"])
	return {"settled": settled, "pantry_after": pantry_after, "events": events}


static func _settle_instance(instance: Dictionary, pantry_after: Dictionary, options: Dictionary, catalog: Dictionary) -> Dictionary:
	var definition_id := str(instance.get("definition_id", ""))
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	var need := feed_cost(definition, instance, catalog)
	var matching := _available(pantry_after, options.get("matching_material_ids", []))
	var universal_entries: Array = []
	var universal: Dictionary = options.get("universal_materials", {})
	for material_id in universal:
		var amount := float(materials_count(pantry_after, str(material_id)))
		if amount > 0.0:
			universal_entries.append({"amount": amount, "rate": float(universal[material_id])})
	var emergency := _available(pantry_after, options.get("emergency_material_ids", []))
	var resolve := resolve_need(need, matching, universal_entries, {"_emergency": emergency}, catalog)
	_deduct(pantry_after, options.get("matching_material_ids", []), float(resolve["matching_used"]))
	_deduct_rate(pantry_after, universal, float(resolve["universal_used"]))
	_deduct(pantry_after, options.get("emergency_material_ids", []), float(resolve["emergency_used"]))
	var hunger := int(instance.get("hunger_phase", 0))
	var outcome := "fed"
	var event: Dictionary = {}
	if float(resolve["unmet"]) > 0.0:
		hunger += 1
		if hunger >= 2:
			outcome = "starved"
			event = {
				"action": "gu_starved",
				"instance_id": str(instance.get("instance_id", "")),
				"definition_id": definition_id,
				"cause": "starvation:second_layer_unpaid",
				"need": need,
				"unmet": float(resolve["unmet"]),
			}
		else:
			outcome = "hungry"
	else:
		hunger = 0
	var updated := instance.duplicate(true)
	updated["hunger_phase"] = hunger
	return {
		"instance": updated,
		"record": {
			"instance": updated,
			"outcome": outcome,
			"hunger_phase": hunger,
			"need": need,
		},
		"event": event,
	}


# §7.2 preview: which instances will go hungry or die this layer, before the
# player commits the feeding order.
static func preview_settle(instances: Array, pantry: Dictionary, options: Dictionary, catalog: Dictionary) -> Dictionary:
	var will_hunger: Array = []
	var will_die: Array = []
	for instance in instances:
		var definition_id := str((instance as Dictionary).get("definition_id", ""))
		var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
		var need := feed_cost(definition, instance, catalog)
		var matching := _available(pantry, options.get("matching_material_ids", []))
		var universal_entries: Array = []
		var universal: Dictionary = options.get("universal_materials", {})
		for material_id in universal:
			var amount := float(materials_count(pantry, str(material_id)))
			if amount > 0.0:
				universal_entries.append({"amount": amount, "rate": float(universal[material_id])})
		var emergency := _available(pantry, options.get("emergency_material_ids", []))
		var resolve := resolve_need(need, matching, universal_entries, {"_emergency": emergency}, catalog)
		var hunger := int((instance as Dictionary).get("hunger_phase", 0))
		if float(resolve["unmet"]) > 0.0:
			if hunger >= 1:
				will_die.append(str((instance as Dictionary).get("instance_id", "")))
			else:
				will_hunger.append(str((instance as Dictionary).get("instance_id", "")))
	return {"will_hunger": will_hunger, "will_die": will_die}


# §7.3 economy soft-cap: about 50% of remaining disposable resources can
# sustain 4-5 standard same-rank gu. This is a report only - it never
# hard-rejects anything.
static func budget_report(assets_value: float, feeding_plan_cost_per_gu: float, cat: Dictionary) -> Dictionary:
	var half := maxf(0.0, assets_value) * 0.5
	var unit_cost := feeding_plan_cost_per_gu if feeding_plan_cost_per_gu > 0.0 else 1.0
	var sustainable := int(floor(half / maxf(0.0001, unit_cost)))
	return {
		"affordable_gu_count": sustainable,
		"sustainable_at_half": sustainable,
		"note": "soft budget - ~50%% of remaining disposable value sustains 4-5 standard same-rank gu; never a hard rejection",
		"hard_rejection": false,
	}


# ---- pantry helpers ---------------------------------------------------------

static func materials_count(pantry: Dictionary, material_id: String) -> int:
	if material_id == "feed_points":
		return int(pantry.get(material_id, 0))
	return int(pantry.get(material_id, 0))


static func _available(pantry: Dictionary, ids: Array) -> float:
	var total := 0.0
	for material_id in ids:
		total += float(materials_count(pantry, str(material_id)))
	return total


static func _deduct(pantry: Dictionary, ids: Array, amount: float) -> void:
	if amount <= 0.0:
		return
	var remaining := amount
	for material_id in ids:
		if remaining <= 0.0:
			return
		var key := str(material_id)
		var count := float(materials_count(pantry, key))
		var take := minf(count, remaining)
		pantry[key] = count - take
		remaining -= take


static func _deduct_rate(pantry: Dictionary, universal: Dictionary, amount: float) -> void:
	if amount <= 0.0:
		return
	var remaining := amount
	for material_id in universal:
		if remaining <= 0.0:
			return
		var key := str(material_id)
		var count := float(materials_count(pantry, key))
		var take := minf(count, remaining)
		pantry[key] = count - take
		remaining -= take
