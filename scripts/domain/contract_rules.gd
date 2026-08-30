class_name ContractRules
extends RefCounted


# C1-min §16.13: contracts are opening global rule modifiers. Aggregation is
# the single read path every consumer uses; numeric rule values are summed by
# key so paired gains and costs can cancel each other out.


static func aggregate(state: RunState, catalog: Dictionary) -> Dictionary:
	var totals := {}
	var by_id := _entry_by_id(catalog)
	for id_value in state.contracts:
		var entry: Dictionary = by_id.get(str(id_value), {})
		for rule_value in entry.get("rules", []):
			var rule: Dictionary = rule_value
			var key := str(rule.get("key", ""))
			totals[key] = int(totals.get(key, 0)) + int(rule.get("value", 0))
	return totals


static func enemy_hp(base_hp: int, state: RunState, catalog: Dictionary) -> int:
	var pct := int(aggregate(state, catalog).get("enemy_hp_pct", 0))
	var scaled := int(floor(float(maxi(1, base_hp)) * (1.0 + float(pct) / 100.0)))
	return maxi(1, scaled)


static func _entry_by_id(catalog: Dictionary) -> Dictionary:
	var indexed: Dictionary = catalog.get("contract_entry_by_id", {})
	if not indexed.is_empty():
		return indexed
	for entry_value in catalog.get("contracts", {}).get("entries", []):
		var entry: Dictionary = entry_value
		indexed[str(entry.get("id", ""))] = entry
	return indexed
