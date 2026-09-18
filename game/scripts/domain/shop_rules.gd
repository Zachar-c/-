class_name ShopRules
extends RefCounted

const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")

static func selected_input_instance_ids(state: RunState, command: Dictionary, inputs: Array) -> Array[String]:
	var remaining: Array[String] = []
	for value in state.cave_aperture.get("stored_gu_instance_ids", []):
		remaining.append(str(value))
	var selected: Array[String] = []
	var requested: Array = command.get("input_instance_ids", [])
	if not requested.is_empty():
		if requested.size() != inputs.size():
			return []
		for value in requested:
			var instance_id := str(value)
			if not remaining.has(instance_id) or selected.has(instance_id):
				return []
			selected.append(instance_id)
			remaining.erase(instance_id)
		var definitions: Array[String] = []
		for instance_id in selected:
			definitions.append(str(state.gu_instances.get(instance_id, {}).get("definition_id", "")))
		if not _same_multiset(definitions, inputs):
			return []
		return selected
	for required_value in inputs:
		var required_id := str(required_value)
		var found := ""
		for value in remaining:
			var candidate: Dictionary = state.gu_instances.get(str(value), {})
			if str(candidate.get("definition_id", "")) == required_id and str(candidate.get("state", "")) == "refined":
				found = str(value)
				break
		if found.is_empty():
			return []
		selected.append(found)
		remaining.erase(found)
	return selected

static func barter_plan(state: RunState, command: Dictionary, offer: Dictionary, can_gain_relic: Callable) -> Dictionary:
	if str(offer.get("kind", "")) != "barter":
		return {"error": "unknown_shop_offer"}
	var inputs: Array = offer.get("input_gu_ids", [])
	var selected := selected_input_instance_ids(state, command, inputs)
	if selected.is_empty():
		return {"error": "missing_barter_input"}
	var rewards: Array = offer.get("rewards", [])
	if rewards.is_empty():
		return {"error": "unknown_shop_offer"}
	var total := 0
	for reward_value in rewards:
		total += maxi(1, int(reward_value.get("weight", 1)))
	var roll := SeededRollScript.index(total, int(state.seed), "+".join(selected), state.event_log.size()) + 1
	var chosen: Dictionary = {}
	var cursor := 0
	for reward_value in rewards:
		chosen = reward_value
		cursor += maxi(1, int(reward_value.get("weight", 1)))
		if roll <= cursor:
			break
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	for value in selected:
		var consumed_id := str(value)
		var consumed: Dictionary = instances[consumed_id].duplicate(true)
		consumed["state"] = "dead"
		instances[consumed_id] = consumed
		stored.erase(consumed_id)
	var relics := state.relic_ids.duplicate()
	var meta_rules := state.meta_rules.duplicate(true)
	var result_feeds: Array[String] = []
	if chosen.has("gu_id"):
		var instance_id := RunState.next_gu_instance_id(instances)
		instances[instance_id] = {"instance_id": instance_id, "definition_id": str(chosen["gu_id"]), "state": "refined"}
		stored.append(instance_id)
	elif chosen.has("relic_id"):
		var relic_id := str(chosen["relic_id"])
		var gate: Variant = can_gain_relic.call(relic_id) if can_gain_relic.is_valid() else {"reason": "unknown_relic", "grade": ""}
		var gate_data: Dictionary = gate if gate is Dictionary else {"reason": str(gate), "grade": ""}
		var blocked_reason := str(gate_data.get("reason", ""))
		if blocked_reason.is_empty():
			relics.append(relic_id)
			if str(gate_data.get("grade", "")) == "meta_rule":
				meta_rules[relic_id] = true
				result_feeds.append("meta_rule_recorded")
		else:
			result_feeds.append("relic_reward_blocked_%s" % blocked_reason)
	aperture["stored_gu_instance_ids"] = stored
	return {"selected": selected, "chosen": chosen, "gu_instances": instances, "cave_aperture": aperture, "relic_ids": relics, "meta_rules": meta_rules, "result_feeds": result_feeds}

static func _same_multiset(actual: Array[String], expected: Array) -> bool:
	var remaining := actual.duplicate()
	for value in expected:
		var index := remaining.find(str(value))
		if index < 0:
			return false
		remaining.remove_at(index)
	return remaining.is_empty()
