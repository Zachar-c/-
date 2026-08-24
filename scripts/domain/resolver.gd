class_name Resolver
extends RefCounted


const SeededRngScript = preload("res://scripts/domain/rng.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const DeckCapacityScript = preload("res://scripts/domain/deck_capacity.gd")


const BODY_IMPRINTS := {
	"iron_bone": {
		"facts": ["iron_bone_defense", "iron_bone_stealth_drawback"],
		"reason": "body_imprint_stealth_drawback",
	},
	"ice_skin": {
		"facts": ["ice_skin_cold_resistance", "ice_skin_cold_injury"],
		"injury": 1,
		"reason": "body_imprint_injury_cost",
	},
	"three_watch": {
		"facts": ["three_watch_vigilance"],
		"lifespan_debt": 1,
		"reason": "body_imprint_cost",
	},
}

const OPPORTUNITY_TYPES := ["gu", "information", "service", "favor", "escape_condition"]

const STANDARD_ACTIONS := [
	"accept", "ally", "buy_information", "claim", "cross", "deceive", "harvest",
	"inspect", "leave", "lure", "meditate", "open", "prepare", "retreat", "scout",
	"scheme", "take_imprint", "trade", "withdraw", "work",
]


static func apply(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, "terminal_run")
	match command.get("type", ""):
		"travel":
			return _travel(state, command)
		"resolve_contact":
			return _resolve_contact(state, command)
		"complete_node":
			return _complete_node(state, command)
		"buy_gu":
			return _buy_gu(state, command, catalog)
		"sell_gu":
			return _sell_gu(state, command, catalog)
		"exchange_gu":
			return _exchange_gu(state, command, catalog)
		"refine_gu":
			return _refine_gu(state, command, catalog)
		"cultivate_rank_two":
			return _cultivate_rank_two(state)
		"settle_feeding":
			return _settle_feeding(state, catalog)
		"settle_node_feeding":
			return _settle_node_feeding(state, catalog)
		"disable_card":
			return _disable_card(state, command)
		"upgrade_card":
			return _upgrade_card(state, command)
		"copy_card":
			return _copy_card(state, command)
		"destroy_gu":
			return _destroy_gu(state, command)
		"spend_lifespan":
			return _spend_lifespan(state, command)
		"accept_debt":
			return _accept_debt(state, catalog)
		"use_gu":
			return _use_gu(state, command, catalog)
		"buy_opportunity":
			return _buy_opportunity(state, command)
		"take_body_imprint":
			return _take_body_imprint(state, command)
		"choose_action":
			return _choose_action(state, command, catalog)
		"retreat":
			return _retreat(state)
		"attempt_ascension":
			return _attempt_ascension(state, command)
		"gain_relic":
			return _gain_relic(state, command, catalog)
		"shop_purchase":
			return _shop_purchase(state, command, catalog)
		"shop_lifespan_deal":
			return _shop_lifespan_deal(state, command, catalog)
		"shop_barter":
			return _shop_barter(state, command, catalog)
		"record_neutral_npc_kill":
			return _record_neutral_npc_kill(state, catalog)
		"wash_notoriety":
			return _wash_notoriety(state, catalog)
		"record_boss_defeated":
			return _record_boss_defeated(state, catalog)
		"rest":
			return _rest(state, catalog)
		"accept_event":
			return _accept_event(state, command, catalog)
		_:
			return _rejected(state, "unsupported_command")


static func _resolve_contact(state: RunState, command: Dictionary) -> Dictionary:
	if str(command.get("node_id", "")) != "neutral_wanderer":
		return _rejected(state, "unknown_contact")
	var approach := str(command.get("approach", ""))
	var known_facts := state.known_facts.duplicate()
	var node_flags := state.node_flags.duplicate(true)
	var before := {"stone": state.stone, "known_facts": state.known_facts, "node_flags": state.node_flags}
	var after := {"known_facts": known_facts, "node_flags": node_flags}
	var result := {"ok": true, "approach": approach}
	match approach:
		"deceive":
			_add_fact(known_facts, "wanderer_misdirected")
			after["stone"] = state.stone + 2
			result["reward"] = "stone"
		"negotiate":
			_add_fact(known_facts, "caravan_friendly_prices")
			result["reward"] = "caravan_discount"
		"retreat":
			if state.stone < 1:
				return _rejected(state, "insufficient_stone")
			_add_fact(known_facts, "wanderer_alerted")
			after["stone"] = state.stone - 1
		"fight":
			_add_fact(known_facts, "wanderer_challenged")
			result["start_battle"] = true
		_:
			return _rejected(state, "invalid_contact_approach")
	var next := state.append_event(_event(
		state,
		"contact_%s" % approach,
		before,
		after,
		"neutral_wanderer_%s" % approach,
		"neutral_wanderer"
	))
	return {"state": next, "result": result}


static func _complete_node(state: RunState, command: Dictionary) -> Dictionary:
	var node_id := str(command.get("node_id", state.current_node_id))
	if node_id.is_empty() or node_id != state.current_node_id:
		return _rejected(state, "invalid_node_completion")
	if state.node_flags.has(node_id):
		return _accepted(state)
	var flags := state.node_flags.duplicate(true)
	flags[node_id] = str(command.get("outcome", "completed"))
	var next := state.append_event(_event(
		state,
		"complete_node",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"node_completed",
		node_id
	))
	return _accepted(next)


static func _buy_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer := _offer(catalog, str(command.get("offer_id", "")), "buy")
	if offer.is_empty():
		return _rejected(state, "unknown_buy_offer")
	var cost := price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var blocked := _reject_deck_full(state, catalog, [str(offer["output_gu_id"])], [])
	if not blocked.is_empty():
		return blocked
	return _add_gu_transaction(state, str(offer["output_gu_id"]), cost, [], "caravan_bought_gu")


static func _sell_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(command.get("gu_id", ""))
	if not state.refined_gu_ids.has(gu_id):
		return _rejected(state, "gu_not_refined")
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
	if gu.is_empty():
		return _rejected(state, "unknown_gu")
	var value := int(gu.get("value", 0))
	var next_gu := _without_gu(state.refined_gu_ids, [gu_id])
	var next_equipped := _without_gu(state.equipped_gu_ids, [gu_id])
	var next := state.append_event(_event(
		state,
		"sell_gu",
		{"stone": state.stone, "gu_ids": state.gu_ids, "refined_gu_ids": state.refined_gu_ids},
		{"stone": state.stone + value, "gu_ids": next_gu, "refined_gu_ids": next_gu, "equipped_gu_ids": next_equipped},
		"caravan_sold_gu",
		state.current_node_id,
		[gu_id]
	))
	return _accepted(next)


static func _exchange_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer := _offer(catalog, str(command.get("offer_id", "")), "exchange")
	if offer.is_empty():
		return _rejected(state, "unknown_exchange_offer")
	var inputs: Array = offer.get("input_gu_ids", [])
	if not _has_all_gu(state.refined_gu_ids, inputs):
		return _rejected(state, "missing_exchange_input")
	var cost := price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var blocked := _reject_deck_full(state, catalog, [str(offer["output_gu_id"])], inputs)
	if not blocked.is_empty():
		return blocked
	return _add_gu_transaction(state, str(offer["output_gu_id"]), cost, inputs, "caravan_exchanged_gu")


static func _refine_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var recipe: Dictionary = catalog.get("refinement_by_id", {}).get(str(command.get("recipe_id", "")), {})
	if recipe.is_empty():
		return _rejected(state, "unknown_refinement_recipe")
	match str(recipe.get("kind", "combine")):
		"fixed":
			return _apply_fixed_recipe(state, command, catalog, recipe)
		"free_mix":
			return _apply_free_mix(state, command, catalog, recipe)
	return _apply_combine_recipe(state, command, catalog, recipe)


static func _apply_combine_recipe(state: RunState, command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	var inputs: Array = recipe.get("input_gu_ids", [])
	if inputs.size() > SoulCapacityScript.craft_cap(state):
		return _rejected(state, "refinement_capacity_exceeded")
	if not _has_all_gu(state.refined_gu_ids, inputs):
		return _rejected(state, "missing_refinement_input")
	# The result is determined from the run seed and immutable event position.
	# Commands never accept client supplied dice values.
	var roll := _refinement_roll(state, str(recipe.get("id", "")))
	if roll > int(recipe.get("success_roll_max", 100)):
		var destroyed := _without_gu(state.refined_gu_ids, inputs)
		var unequipped := _without_gu(state.equipped_gu_ids, inputs)
		var failed := state.append_event(_event(
			state,
			"refine_gu",
			{"gu_ids": state.gu_ids, "refined_gu_ids": state.refined_gu_ids},
			{"gu_ids": destroyed, "refined_gu_ids": destroyed, "equipped_gu_ids": unequipped},
			"refinement_failed_destroyed_inputs",
			state.current_node_id,
			inputs
		))
		return _accepted(failed)
	var blocked := _reject_deck_full(state, catalog, [str(recipe["output_gu_id"])], inputs)
	if not blocked.is_empty():
		return blocked
	return _add_gu_transaction(state, str(recipe["output_gu_id"]), 0, inputs, "refinement_succeeded", ["recipe:%s" % str(recipe["id"])])


static func _codex_unlocks_recipe(state: RunState, recipe: Dictionary) -> bool:
	return state.global_codex_ids.has(str(recipe.get("id", ""))) \
		or state.global_codex_ids.has(str(recipe.get("output_gu_id", "")))


static func _apply_fixed_recipe(state: RunState, command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	if bool(recipe.get("locked", false)) and not _codex_unlocks_recipe(state, recipe):
		return _rejected(state, "refinement_recipe_locked")
	var inputs: Array = recipe.get("input_gu_ids", [])
	if inputs.size() > SoulCapacityScript.craft_cap(state):
		return _rejected(state, "refinement_capacity_exceeded")
	var blocked := _reject_deck_full(state, catalog, [str(recipe["output_gu_id"])], inputs)
	if not blocked.is_empty():
		return blocked
	var selected := _selected_input_instance_ids(state, command, inputs)
	if selected.is_empty():
		return _rejected(state, "missing_refinement_input")
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	for instance_id_value in selected:
		var instance_id := str(instance_id_value)
		var consumed: Dictionary = instances[instance_id].duplicate(true)
		consumed["state"] = "consumed"
		instances[instance_id] = consumed
		stored.erase(instance_id)
	var output_instance_id := _next_gu_instance_id(instances)
	instances[output_instance_id] = {
		"instance_id": output_instance_id,
		"definition_id": str(recipe["output_gu_id"]),
		"state": "refined",
	}
	stored.append(output_instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(_event(
		state,
		"refine_gu",
		{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"gu_instances": instances, "cave_aperture": aperture},
		"refinement_succeeded",
		state.current_node_id,
		selected + [output_instance_id, "recipe:%s" % str(recipe["id"])]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


static func _selected_input_instance_ids(state: RunState, command: Dictionary, inputs: Array) -> Array[String]:
	var remaining: Array[String] = []
	for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
		remaining.append(str(instance_id_value))
	var selected: Array[String] = []
	var requested: Array = command.get("input_instance_ids", [])
	if not requested.is_empty():
		if requested.size() != inputs.size():
			return []
		for instance_id_value in requested:
			var instance_id := str(instance_id_value)
			if not remaining.has(instance_id):
				return []
			selected.append(instance_id)
			remaining.erase(instance_id)
		var definitions: Array[String] = []
		for instance_id_value in selected:
			definitions.append(str(state.gu_instances[str(instance_id_value)]["definition_id"]))
		return definitions if _same_multiset(definitions, inputs) else ([] as Array[String])
	for required_id_value in inputs:
		var required_id := str(required_id_value)
		var found := ""
		for instance_id_value in remaining:
			var candidate: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if str(candidate.get("definition_id", "")) == required_id and str(candidate.get("state", "")) == "refined":
				found = str(instance_id_value)
				break
		if found.is_empty():
			return []
		selected.append(found)
		remaining.erase(found)
	return selected


static func _same_multiset(actual: Array[String], expected: Array) -> bool:
	var remaining := actual.duplicate()
	for value in expected:
		var index := remaining.find(str(value))
		if index < 0:
			return false
		remaining.remove_at(index)
	return remaining.is_empty()


static func _next_gu_instance_id(instances: Dictionary) -> String:
	var highest := 0
	for key_value in instances:
		var text := str(key_value)
		if text.begins_with("gu_"):
			highest = maxi(highest, int(text.trim_prefix("gu_")))
	return "gu_%03d" % (highest + 1)


static func _refinement_roll(state: RunState, recipe_id: String) -> int:
	var recipe_hash := 0
	for character in recipe_id:
		recipe_hash = recipe_hash * 31 + character.unicode_at(0)
	var rng := SeededRngScript.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + recipe_hash)
	return rng.next_index(100) + 1


static func _apply_free_mix(state: RunState, command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	var min_inputs := int(recipe.get("min_inputs", 2))
	var requested: Array = command.get("input_instance_ids", [])
	var selected: Array[String] = []
	if requested.is_empty():
		for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
			var candidate: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if str(candidate.get("state", "")) == "refined":
				selected.append(str(instance_id_value))
	else:
		for instance_id_value in requested:
			var instance_id := str(instance_id_value)
			var candidate: Dictionary = state.gu_instances.get(instance_id, {})
			if candidate.is_empty() or str(candidate.get("state", "")) != "refined":
				return _rejected(state, "missing_refinement_input")
			if not selected.has(instance_id):
				selected.append(instance_id)
	if selected.size() < min_inputs:
		return _rejected(state, "missing_refinement_input")
	if selected.size() > SoulCapacityScript.craft_cap(state):
		return _rejected(state, "refinement_capacity_exceeded")
	var outcomes: Array = recipe.get("outcomes", [])
	if outcomes.is_empty():
		return _rejected(state, "unknown_refinement_recipe")
	# The outcome is drawn from the run seed and immutable event position;
	# commands never accept client supplied dice values.
	var total := 0
	for outcome_value in outcomes:
		total += maxi(1, int(outcome_value.get("weight", 1)))
	var roll := SeededRngScript.new(_free_mix_seed(state, selected)).next_index(total) + 1
	var chosen: Dictionary = {}
	var cursor := 0
	for outcome_value in outcomes:
		chosen = outcome_value
		cursor += maxi(1, int(outcome_value.get("weight", 1)))
		if roll <= cursor:
			break
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var next_cultivator := state.cultivator.duplicate(true)
	var next_health := state.health
	match str(chosen.get("effect", "")):
		"mutate_to":
			var mutated_id := str(selected[0])
			var mutated: Dictionary = instances[mutated_id].duplicate(true)
			mutated["definition_id"] = str(chosen.get("target_gu_id", ""))
			instances[mutated_id] = mutated
			for index in range(1, selected.size()):
				var other_id := str(selected[index])
				var other: Dictionary = instances[other_id].duplicate(true)
				other["state"] = "dead"
				instances[other_id] = other
				stored.erase(other_id)
		"explosion":
			next_health = maxi(0, next_health - int(chosen.get("health_cost", 0)))
			next_cultivator["soul"] = maxi(0, int(next_cultivator.get("soul", 0)) - int(chosen.get("soul_cost", 0)))
			next_cultivator["lifespan"] = maxi(0, int(next_cultivator.get("lifespan", 0)) - int(chosen.get("lifespan_cost", 0)))
			for instance_id_value in selected:
				var destroyed_id := str(instance_id_value)
				var destroyed: Dictionary = instances[destroyed_id].duplicate(true)
				destroyed["state"] = "dead"
				instances[destroyed_id] = destroyed
				stored.erase(destroyed_id)
		_:
			for instance_id_value in selected:
				var consumed_id := str(instance_id_value)
				var consumed: Dictionary = instances[consumed_id].duplicate(true)
				consumed["state"] = "dead"
				instances[consumed_id] = consumed
				stored.erase(consumed_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(_event(
		state,
		"refine_gu",
		{
			"health": state.health,
			"cultivator": state.cultivator,
			"gu_instances": state.gu_instances,
			"cave_aperture": state.cave_aperture,
		},
		{
			"health": next_health,
			"cultivator": next_cultivator,
			"gu_instances": instances,
			"cave_aperture": aperture,
		},
		str(chosen.get("event_reason", "free_mix_destroyed")),
		state.current_node_id,
		selected
	))
	next.sync_legacy_gu_projections()
	return _finalize_if_dead(next)


static func _free_mix_seed(state: RunState, instance_ids: Array[String]) -> int:
	var text := "+".join(instance_ids)
	var hash := 0
	for character in text:
		hash = hash * 31 + character.unicode_at(0)
	return int(state.seed) * 1000003 + state.event_log.size() * 97 + hash


static func _cultivate_rank_two(state: RunState) -> Dictionary:
	if state.current_node_id != "cultivation_spring":
		return _rejected(state, "not_cultivation_window")
	if state.cultivation >= 2:
		return _rejected(state, "cultivation_already_rank_two")
	if state.stone < 5:
		return _rejected(state, "insufficient_stone")
	var next := state.append_event(_event(
		state,
		"cultivate_rank_two",
		{"cultivation": state.cultivation, "stone": state.stone, "essence": state.essence},
		{"cultivation": 2, "stone": state.stone - 5, "essence": state.essence_capacity},
		"rank_two_breakthrough",
		state.current_node_id
	))
	return _accepted(next)


static func _disable_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return _rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["disabled_for_run"] = true
	overrides[card_key] = override
	var next := state.append_event(_event(
		state,
		"disable_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_disabled",
		state.current_node_id,
		[card_key]
	))
	return _accepted(next)


static func _upgrade_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return _rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["upgrade_level"] = int(override.get("upgrade_level", 0)) + 1
	overrides[card_key] = override
	var next := state.append_event(_event(
		state,
		"upgrade_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_upgraded",
		state.current_node_id,
		[card_key]
	))
	return _accepted(next)


static func _copy_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return _rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["extra_copies"] = int(override.get("extra_copies", 0)) + 1
	overrides[card_key] = override
	var next := state.append_event(_event(
		state,
		"copy_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_copied",
		state.current_node_id,
		[card_key]
	))
	return _accepted(next)


static func _destroy_gu(state: RunState, command: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return _rejected(state, "gu_instance_unavailable")
	var instances := state.gu_instances.duplicate(true)
	var destroyed := existing.duplicate(true)
	destroyed["state"] = "dead"
	instances[instance_id] = destroyed
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	stored.erase(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(_event(
		state,
		"destroy_gu",
		{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"gu_instances": instances, "cave_aperture": aperture},
		"gu_destroyed",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


static func _settle_node_feeding(state: RunState, catalog: Dictionary) -> Dictionary:
	var needed: Dictionary = state.estimate_feeding_materials(catalog)
	var materials := state.materials.duplicate(true)
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var deficits: Dictionary = {}
	for material_id_value in needed:
		var material_id := str(material_id_value)
		var cost := int(needed[material_id_value])
		var available := int(materials.get(material_id, 0))
		materials[material_id] = maxi(0, available - cost)
		if available < cost:
			deficits[material_id] = cost - available
	if not deficits.is_empty():
		for instance_id_value in stored.duplicate():
			var instance_id := str(instance_id_value)
			var instance: Dictionary = instances.get(instance_id, {}).duplicate(true)
			if instance.is_empty() or str(instance.get("state", "")) == "dead":
				continue
			var definition: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			var needs_deficit := false
			for material_id_value in definition.get("feeding_need", {}):
				if deficits.has(str(material_id_value)):
					needs_deficit = true
			if not needs_deficit:
				continue
			if str(instance.get("state", "")) == "weakened":
				instance["state"] = "dead"
				stored.erase(instance_id)
			else:
				instance["state"] = "weakened"
			instances[instance_id] = instance
	aperture["stored_gu_instance_ids"] = stored
	var reason := "node_feeding_paid" if deficits.is_empty() else "node_feeding_shortfall"
	var next := state.append_event(_event(
		state,
		"settle_node_feeding",
		{"materials": state.materials, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"materials": materials, "gu_instances": instances, "cave_aperture": aperture},
		reason,
		state.current_node_id,
		stored
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


static func _spend_lifespan(state: RunState, command: Dictionary) -> Dictionary:
	var amount := int(command.get("amount", 0))
	if amount <= 0:
		return _rejected(state, "invalid_lifespan_cost")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = maxi(0, int(cultivator.get("lifespan", 0)) - amount)
	var next := state.append_event(_event(
		state,
		"spend_lifespan",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"lifespan_spent",
		state.current_node_id
	))
	return _finalize_if_dead(next)


static func _finalize_if_dead(state: RunState) -> Dictionary:
	if state.health > 0 and int(state.cultivator.get("lifespan", 0)) > 0 and int(state.cultivator.get("soul", 0)) > 0:
		return _accepted(state)
	return _accepted(state.finalize_death())


static func _settle_feeding(state: RunState, catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "stage_one_ledger":
		return _rejected(state, "not_stage_ledger")
	var cost := state.estimate_feeding(catalog)
	if state.stone < cost:
		return _rejected(state, "feeding_shortfall")
	var flags := state.node_flags.duplicate(true)
	var already_paid := str(flags.get("stage_one_ledger", "")) == "paid"
	flags["stage_one_ledger"] = "paid"
	var next := state.append_event(_event(
		state,
		"settle_feeding",
		{"stone": state.stone, "node_flags": state.node_flags},
		{"stone": state.stone - cost, "node_flags": flags},
		"stage_one_feeding_paid",
		state.current_node_id
	))
	if not already_paid:
		next = _grant_lifespan_milestone(next, catalog, "stage_one_ledger")
	return _accepted(next)


static func _accept_debt(state: RunState, catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "stage_one_ledger":
		return _rejected(state, "not_stage_ledger")
	if state.known_facts.has("caravan_favor_debt"):
		return _rejected(state, "debt_already_accepted")
	var facts := _facts_with(state, "caravan_favor_debt")
	var flags := state.node_flags.duplicate(true)
	flags["stage_one_ledger"] = "debt"
	var next := state.append_event(_event(
		state,
		"accept_debt",
		{"known_facts": state.known_facts, "node_flags": state.node_flags},
		{"known_facts": facts, "node_flags": flags},
		"caravan_feeding_debt",
		state.current_node_id
	))
	return _accepted(next)


static func _offer(catalog: Dictionary, offer_id: String, kind: String) -> Dictionary:
	var offer: Dictionary = catalog.get("caravan_offer_by_id", {}).get(offer_id, {})
	if str(offer.get("kind", "")) != kind:
		return {}
	return offer


static func _add_gu_transaction(state: RunState, output_gu_id: String, stone_cost: int, inputs: Array, reason: String, extra_targets: Array = []) -> Dictionary:
	var next_gu := _without_gu(state.refined_gu_ids, inputs)
	next_gu.append(output_gu_id)
	var next_equipped := _without_gu(state.equipped_gu_ids, inputs)
	var next := state.append_event(_event(
		state,
		"gu_transaction",
		{"stone": state.stone, "gu_ids": state.gu_ids, "refined_gu_ids": state.refined_gu_ids},
		{"stone": state.stone - stone_cost, "gu_ids": next_gu, "refined_gu_ids": next_gu, "equipped_gu_ids": next_equipped},
		reason,
		state.current_node_id,
		inputs + [output_gu_id] + extra_targets
	))
	return _accepted(next)


static func _has_all_gu(owned: Array[String], required: Array) -> bool:
	var remaining := owned.duplicate()
	for gu_id in required:
		var index := remaining.find(str(gu_id))
		if index < 0:
			return false
		remaining.remove_at(index)
	return true


static func _without_gu(owned: Array[String], removed: Array) -> Array[String]:
	var next := owned.duplicate()
	for gu_id in removed:
		var index := next.find(str(gu_id))
		if index >= 0:
			next.remove_at(index)
	return next


static func _gain_relic(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	if not catalog.get("relic_by_id", {}).has(relic_id):
		return _rejected(state, "unknown_relic")
	if state.relic_ids.has(relic_id):
		return _rejected(state, "relic_already_owned")
	var relics := state.relic_ids.duplicate()
	relics.append(relic_id)
	var next := state.append_event(_event(
		state,
		"gain_relic",
		{"relic_ids": state.relic_ids},
		{"relic_ids": relics},
		"relic_gained",
		state.current_node_id,
		[relic_id]
	))
	return _accepted(next)


static func _shop_purchase(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	if str(offer.get("kind", "")) != "purchase":
		return _rejected(state, "unknown_shop_offer")
	var blocked := _reject_deck_full(state, catalog, [str(offer["gu_id"])], [])
	if not blocked.is_empty():
		return blocked
	var cost := price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	var instance_id := _next_gu_instance_id(instances)
	instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": str(offer["gu_id"]),
		"state": "refined",
	}
	stored.append(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(_event(
		state,
		"shop_purchase",
		{"stone": state.stone, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"stone": state.stone - cost, "gu_instances": instances, "cave_aperture": aperture},
		"shop_purchase_completed",
		state.current_node_id,
		[str(offer["gu_id"])]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


static func _shop_lifespan_deal(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	if str(offer.get("kind", "")) != "lifespan_deal":
		return _rejected(state, "unknown_shop_offer")
	var cost := int(offer.get("lifespan_cost", 0))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	# Trade deaths must be predictable: paying to zero is rejected up front.
	if lifespan - cost < 1:
		return _rejected(state, "lifespan_trade_warning")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = lifespan - cost
	var next := state.append_event(_event(
		state,
		"shop_lifespan_deal",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"shop_lifespan_deal_paid",
		state.current_node_id,
		[str(offer["gu_id"])]
	))
	return _finalize_if_dead(next)


static func _shop_barter(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	if str(offer.get("kind", "")) != "barter":
		return _rejected(state, "unknown_shop_offer")
	var inputs: Array = offer.get("input_gu_ids", [])
	var selected := _selected_input_instance_ids(state, command, inputs)
	if selected.is_empty():
		return _rejected(state, "missing_barter_input")
	var rewards: Array = offer.get("rewards", [])
	if rewards.is_empty():
		return _rejected(state, "unknown_shop_offer")
	# The reward is drawn from the run seed and immutable event position;
	# commands never carry the reward id from the UI.
	var total := 0
	for reward_value in rewards:
		total += maxi(1, int(reward_value.get("weight", 1)))
	var roll := SeededRngScript.new(_free_mix_seed(state, selected)).next_index(total) + 1
	var chosen: Dictionary = {}
	var cursor := 0
	for reward_value in rewards:
		chosen = reward_value
		cursor += maxi(1, int(reward_value.get("weight", 1)))
		if roll <= cursor:
			break
	if chosen.has("gu_id"):
		var removed_defs: Array[String] = []
		for instance_id_value in selected:
			removed_defs.append(str(state.gu_instances[str(instance_id_value)].get("definition_id", "")))
		var blocked := _reject_deck_full(state, catalog, [str(chosen["gu_id"])], removed_defs)
		if not blocked.is_empty():
			return blocked
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	for instance_id_value in selected:
		var consumed_id := str(instance_id_value)
		var consumed: Dictionary = instances[consumed_id].duplicate(true)
		consumed["state"] = "dead"
		instances[consumed_id] = consumed
		stored.erase(consumed_id)
	var relics := state.relic_ids.duplicate()
	if chosen.has("gu_id"):
		var instance_id := _next_gu_instance_id(instances)
		instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(chosen["gu_id"]),
			"state": "refined",
		}
		stored.append(instance_id)
	elif chosen.has("relic_id") and not relics.has(str(chosen["relic_id"])):
		relics.append(str(chosen["relic_id"]))
	aperture["stored_gu_instance_ids"] = stored
	var next := state.append_event(_event(
		state,
		"shop_barter",
		{
			"gu_instances": state.gu_instances,
			"cave_aperture": state.cave_aperture,
			"relic_ids": state.relic_ids,
		},
		{
			"gu_instances": instances,
			"cave_aperture": aperture,
			"relic_ids": relics,
		},
		"shop_barter_resolved",
		state.current_node_id,
		[str(chosen.get("id", ""))]
	))
	next.sync_legacy_gu_projections()
	var result := _accepted(next)
	result["outcome"] = str(chosen.get("id", ""))
	return result


static func _accept_event(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var event: Dictionary = catalog.get("event_by_id", {}).get(str(command.get("event_id", "")), {})
	if event.is_empty():
		return _rejected(state, "unknown_event")
	var health_cost := int(event.get("health_cost", 0))
	if state.health <= health_cost:
		return _rejected(state, "insufficient_health")
	var flags := state.node_flags.duplicate(true)
	flags["pending_delayed_soul_drain"] = int(flags.get("pending_delayed_soul_drain", 0)) + int(event.get("delayed_soul_cost", 0))
	var next := state.append_event(_event(
		state,
		"accept_event",
		{"health": state.health, "node_flags": state.node_flags},
		{"health": state.health - health_cost, "node_flags": flags},
		"event_accepted_delayed_cost",
		state.current_node_id,
		[str(event["id"])]
	))
	return _accepted(next)


static func _travel(state: RunState, command: Dictionary) -> Dictionary:
	var node_id := str(command.get("node_id", ""))
	if node_id.is_empty():
		return _rejected(state, "missing_node_id")
	var next := state.append_event(_event(
		state,
		"travel",
		{"current_node_id": state.current_node_id},
		{"current_node_id": node_id},
		"travel",
		node_id
	))
	var pending := int(state.node_flags.get("pending_delayed_soul_drain", 0))
	if pending > 0:
		var cultivator := next.cultivator.duplicate(true)
		cultivator["soul"] = maxi(0, int(cultivator.get("soul", 0)) - pending)
		var flags := next.node_flags.duplicate(true)
		flags["pending_delayed_soul_drain"] = 0
		next = next.append_event(_event(
			next,
			"delayed_cost",
			{"cultivator": next.cultivator, "node_flags": next.node_flags},
			{"cultivator": cultivator, "node_flags": flags},
			"delayed_soul_drain",
			node_id
		))
		return _finalize_if_dead(next)
	return _accepted(next)


static func _use_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(command.get("gu_id", ""))
	if not state.equipped_gu_ids.has(gu_id):
		return _rejected(state, "gu_not_equipped")
	if not catalog.get("gu_by_id", {}).has(gu_id):
		return _rejected(state, "unknown_gu")
	var essence_cost: int = catalog["gu_by_id"][gu_id]["essence_cost"]
	if state.essence < essence_cost:
		return _rejected(state, "insufficient_essence")
	var next := state.append_event(_event(
		state,
		"use_gu",
		{"essence": state.essence},
		{"essence": state.essence - essence_cost},
		"gu_action",
		state.current_node_id,
		[gu_id]
	))
	return _accepted(next)


static func _buy_opportunity(state: RunState, command: Dictionary) -> Dictionary:
	var offer_type := str(command.get("offer_type", ""))
	var cost := int(command.get("cost", 0))
	if not OPPORTUNITY_TYPES.has(offer_type):
		return _rejected(state, "invalid_opportunity_type")
	if cost <= 0 or cost > state.stone:
		return _rejected(state, "invalid_opportunity_cost")
	var known_facts := state.known_facts.duplicate()
	known_facts.append("bought_%s" % offer_type)
	var next := state.append_event(_event(
		state,
		"buy_opportunity",
		{"stone": state.stone, "known_facts": state.known_facts},
		{"stone": state.stone - cost, "known_facts": known_facts},
		"declared_opportunity",
		state.current_node_id
	))
	return _accepted(next)


static func _take_body_imprint(state: RunState, command: Dictionary) -> Dictionary:
	var imprint_id := str(command.get("imprint_id", ""))
	if not BODY_IMPRINTS.has(imprint_id):
		return _rejected(state, "unknown_body_imprint")
	if state.body_imprints.has(imprint_id):
		return _rejected(state, "body_imprint_already_taken")
	var imprint: Dictionary = BODY_IMPRINTS[imprint_id]
	var body_imprints := state.body_imprints.duplicate()
	body_imprints.append(imprint_id)
	var known_facts := state.known_facts.duplicate()
	for fact in imprint["facts"]:
		if not known_facts.has(fact):
			known_facts.append(fact)
	var after := {
		"body_imprints": body_imprints,
		"known_facts": known_facts,
		"injury": state.injury + int(imprint.get("injury", 0)),
		"lifespan_debt": state.lifespan_debt + int(imprint.get("lifespan_debt", 0)),
	}
	var next := state.append_event(_event(
		state,
		"take_body_imprint",
		{"body_imprints": state.body_imprints, "known_facts": state.known_facts},
		after,
		imprint["reason"],
		state.current_node_id,
		[imprint_id]
	))
	return _accepted(next)


static func _choose_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var action_id := str(command.get("action_id", ""))
	# NPC-scoped actions own their route even when their verbs overlap generic actions.
	# Generic commands never carry npc_id, so their legacy path remains unchanged.
	if command.has("npc_id"):
		return apply_social_action(state, command, catalog)
	if action_id.is_empty():
		return _rejected(state, "missing_action_id")
	if not STANDARD_ACTIONS.has(action_id):
		return _rejected(state, "unsupported_standard_action")
	var transition := _standard_action_transition(state, action_id)
	if not bool(transition.get("ok", true)):
		return _rejected(state, str(transition.get("reason", "action_unavailable")))
	var next := state.append_event(_event(
		state,
		"choose_action",
		transition["before"],
		transition["after"],
		str(transition["reason"]),
		state.current_node_id
	))
	return {
		"state": next,
		"result": {
			"ok": true,
			"action_id": action_id,
			"effect_id": str(transition["effect_id"]),
		},
	}


static func _standard_action_transition(state: RunState, action_id: String) -> Dictionary:
	match action_id:
		"work":
			return _resource_transition(state, "stone", 3, "action_work_paid")
		"harvest":
			return _resource_transition(state, "stone", 2, "action_harvest_stone")
		"buy_information":
			return _spend_stone_for_fact(state, "bought_information", "action_bought_information")
		"trade":
			return _spend_stone_for_fact(state, "bought_service", "action_trade_service")
		"cross":
			if state.essence < 1:
				return {"ok": false, "reason": "insufficient_essence"}
			return _resource_transition(state, "essence", -1, "action_cross_cost")
		"meditate":
			return _resource_transition(state, "essence", 1, "action_meditate_essence")
		"deceive":
			return _resource_transition(state, "pursuit", 1, "action_deceive_pursuit")
		"retreat":
			return _resource_transition(state, "pursuit", 1, "action_retreat_pursuit")
		"open":
			return _ascension_transition(state, "site", true, "action_open_site")
		"prepare":
			return _ascension_transition(state, "protection", true, "action_prepare_protection")
		"scheme":
			return _ascension_transition(state, "external_interference", false, "action_scheme_interference")
		"take_imprint":
			if state.body_imprints.has("iron_bone"):
				return {"ok": false, "reason": "body_imprint_already_taken"}
			var facts := _facts_with(state, "iron_bone_defense")
			facts = _facts_with_values(facts, "iron_bone_stealth_drawback")
			return {
				"before": {"body_imprints": state.body_imprints, "known_facts": state.known_facts},
				"after": {"body_imprints": state.body_imprints + ["iron_bone"], "known_facts": facts},
				"reason": "action_take_iron_bone",
				"effect_id": "action_take_imprint",
			}
		"accept": return _fact_transition(state, "commission_accepted", "action_accept_commission")
		"ally": return _fact_transition(state, "temporary_ally", "action_ally_support")
		"claim": return _fact_transition(state, "claimed_opportunity", "action_claim_opportunity")
		"inspect": return _fact_transition(state, "site_clue", "action_inspect_clue")
		"leave": return _fact_transition(state, "route_left_behind", "action_leave_route")
		"lure": return _fact_transition(state, "lured_threat", "action_lure_threat")
		"scout": return _fact_transition(state, "route_scouted", "action_scout_route")
		"withdraw": return _fact_transition(state, "withdrawn_safely", "action_withdraw_safely")
	return {"ok": false, "reason": "unsupported_standard_action"}


static func _resource_transition(state: RunState, key: String, delta: int, effect_id: String) -> Dictionary:
	var before_value := int(state.get(key))
	return {
		"before": {key: before_value},
		"after": {key: before_value + delta},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _spend_stone_for_fact(state: RunState, fact_id: String, effect_id: String) -> Dictionary:
	if state.stone < 2:
		return {"ok": false, "reason": "insufficient_stone"}
	return {
		"before": {"stone": state.stone, "known_facts": state.known_facts},
		"after": {"stone": state.stone - 2, "known_facts": _facts_with(state, fact_id)},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _ascension_transition(state: RunState, key: String, value: bool, effect_id: String) -> Dictionary:
	var ascension := state.ascension.duplicate(true)
	ascension[key] = value
	return {
		"before": {"ascension": state.ascension},
		"after": {"ascension": ascension},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _fact_transition(state: RunState, fact_id: String, effect_id: String) -> Dictionary:
	return {
		"before": {"known_facts": state.known_facts},
		"after": {"known_facts": _facts_with(state, fact_id)},
		"reason": effect_id,
		"effect_id": effect_id,
	}


static func _facts_with(state: RunState, fact_id: String) -> Array[String]:
	return _facts_with_values(state.known_facts, fact_id)


static func _facts_with_values(existing: Array[String], fact_id: String) -> Array[String]:
	var facts := existing.duplicate()
	_add_fact(facts, fact_id)
	return facts


static func _add_fact(facts: Array[String], fact_id: String) -> void:
	if not facts.has(fact_id):
		facts.append(fact_id)


static func apply_social_action(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var npc := _npc_by_id(catalog, str(command.get("npc_id", "")))
	if npc.is_empty():
		return _rejected(state, "unknown_npc")
	var action_id := str(command.get("action_id", ""))
	if not ["probe", "trade", "pressure", "deceive", "leave", "fight"].has(action_id):
		return _rejected(state, "invalid_social_action")
	var social: Dictionary = state.relations.get("caravan_steward", {
		"stance": "neutral",
		"round": 0,
		"evidence": [],
		"concession": 0,
		"threat": 0,
		"escape_route": false,
		"deadline_days": 3,
		"npc_disposition": "neutral",
	}).duplicate(true)
	var known_facts := state.known_facts.duplicate()
	var npc_reaction := _npc_reaction(state, npc)
	var reason := "caravan_%s" % action_id
	var surrendered := false
	match action_id:
		"probe":
			if not social["evidence"].has("ledger_evidence") and known_facts.has("ledger_evidence"):
				social["evidence"].append("ledger_evidence")
			social["npc_disposition"] = "examining"
		"trade":
			if command.get("offer", "") == "ledger_evidence" and social["evidence"].has("ledger_evidence"):
				social["stance"] = "helpful"
				social["concession"] += 1
				if not known_facts.has("earth_vein_entry"):
					known_facts.append("earth_vein_entry")
				reason = "caravan_trade_evidence"
			else:
				return _rejected(state, "missing_trade_evidence")
		"pressure":
			social["threat"] += 1
			social["npc_disposition"] = npc_reaction
			surrendered = social["threat"] >= int(npc["will"]) + 1 and social["evidence"].size() > 0
		"leave":
			social["stance"] = "suspicious"
			social["escape_route"] = true
			if not known_facts.has("caravan_suspicion"):
				known_facts.append("caravan_suspicion")
		"deceive", "fight":
			social["npc_disposition"] = "guarded"
	social["round"] += 1
	social["deadline_days"] = maxi(0, int(social["deadline_days"]) - 1)
	if social["deadline_days"] == 0 and not known_facts.has("caravan_reinforcements_arrived"):
		known_facts.append("caravan_reinforcements_arrived")
	var relations := state.relations.duplicate(true)
	relations["caravan_steward"] = social
	var next := state.append_event(_event(
		state,
		"social_%s" % action_id,
		{"relations": state.relations, "known_facts": state.known_facts},
		{"relations": relations, "known_facts": known_facts},
		reason,
		state.current_node_id,
		["caravan_steward"]
	))
	return {
		"state": next,
		"result": {
			"ok": true,
			"action_id": action_id,
			"npc_reaction": npc_reaction,
			"surrendered": surrendered,
		},
	}


static func _npc_by_id(catalog: Dictionary, npc_id: String) -> Dictionary:
	for npc in catalog.get("npcs", []):
		if npc["id"] == npc_id:
			return npc
	return {}


static func _npc_reaction(state: RunState, npc: Dictionary) -> String:
	if state.injury >= 2:
		return npc["injury_reaction"]
	return "caution"


static func _retreat(state: RunState) -> Dictionary:
	var next := state.append_event(_event(
		state,
		"retreat",
		{"pursuit": state.pursuit},
		{"pursuit": state.pursuit + 1},
		"retreat_pressure",
		state.current_node_id
	))
	return _accepted(next)


static func _grant_lifespan_milestone(state: RunState, catalog: Dictionary, milestone_id: String) -> RunState:
	var milestones: Dictionary = catalog.get("pacing", {}).get("lifespan_milestones", {})
	if not milestones.has(milestone_id):
		return state
	var amount := int(milestones[milestone_id])
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = int(cultivator.get("lifespan", 0)) + amount
	return state.append_event(_event(
		state,
		"lifespan_milestone",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"lifespan_milestone_gained",
		state.current_node_id,
		[milestone_id]
	))


static func _rest(state: RunState, catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "rest_hollow":
		return _rejected(state, "not_rest_node")
	if str(state.node_flags.get("rest_hollow", "")) == "used":
		return _rejected(state, "rest_already_used")
	var flags := state.node_flags.duplicate(true)
	flags["rest_hollow"] = "used"
	var next_health := mini(state.max_health, state.health + 2)
	var essence_max := int(state.cave_aperture.get("essence_max", 4))
	var next_essence := mini(essence_max, state.essence + 2)
	var next := state.append_event(_event(
		state,
		"rest",
		{"health": state.health, "essence": state.essence, "node_flags": state.node_flags},
		{"health": next_health, "essence": next_essence, "node_flags": flags},
		"rest_recovered",
		state.current_node_id,
		[]
	))
	return _accepted(next)


static func _record_boss_defeated(state: RunState, catalog: Dictionary) -> Dictionary:
	var flags := state.node_flags.duplicate(true)
	var already_defeated := str(flags.get("boss_defeated", "")) == "true"
	if not already_defeated:
		flags["boss_defeated"] = "true"
	var next := state.append_event(_event(
		state,
		"record_boss_defeated",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"boss_defeated_recorded",
		state.current_node_id,
		[]
	))
	if not already_defeated:
		next = _grant_lifespan_milestone(next, catalog, "boss_defeated")
	return _accepted(next)


static func _attempt_ascension(state: RunState, command: Dictionary) -> Dictionary:
	if str(state.node_flags.get("boss_defeated", "")) != "true":
		return _rejected(state, "boss_undefeated")
	if command.get("choice", "") != "now":
		return _rejected(state, "unsupported_ascension_choice")
	var conditions := _ascension_conditions(state)
	var all_ready := true
	for condition in conditions.values():
		if not condition:
			all_ready = false
	var risk := state.pursuit + state.injury + state.lifespan_debt
	var outcome := "survived_failure"
	if all_ready and risk <= 1:
		outcome = "success"
	elif all_ready and risk <= 3:
		outcome = "risky_success"
	var ascension := state.ascension.duplicate(true)
	ascension["outcome"] = outcome
	ascension["conditions"] = conditions.duplicate(true)
	var next := state.append_event(_event(
		state,
		"attempt_ascension",
		{"ascension": state.ascension},
		{"ascension": ascension},
		"ascension_%s" % outcome,
		"ascension_window"
	))
	return {"state": next, "result": {"ok": true, "outcome": outcome, "conditions": conditions, "risk": risk}}


static func _ascension_conditions(state: RunState) -> Dictionary:
	return {
		"aperture_foundation": state.ascension.get("aperture_foundation", false),
		"heaven_earth_qi": state.ascension.get("heaven_earth_qi", false),
		"site": state.ascension.get("site", false),
		"protection": state.ascension.get("protection", false),
		"external_interference": not state.ascension.get("external_interference", true),
	}


static func _event(
	state: RunState,
	action: String,
	before: Dictionary,
	after: Dictionary,
	reason: String,
	node_id: String,
	targets: Array = []
) -> Dictionary:
	return {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": node_id,
		"action": action,
		"before": before,
		"after": after,
		"reason": reason,
		"source": "resolver",
		"targets": targets,
	}


static func notoriety(state: RunState) -> int:
	return int(state.cultivator.get("notorious", 0))


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	var bound := clampi(pct, 0, 100)
	if bound <= 0:
		return false
	if bound >= 100:
		return true
	var salt_hash := 0
	for character in salt:
		salt_hash = salt_hash * 31 + character.unicode_at(0)
	var rng := SeededRngScript.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + salt_hash)
	return rng.next_index(100) < bound


static func price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	if notoriety(state) <= 0:
		return maxi(0, base)
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var pct := int(effects.get("price_pct_per_point", 10))
	var cap := int(effects.get("price_cap_pct", 60))
	var uplift := mini(cap, pct * notoriety(state))
	return ceili(float(base) * (1.0 + float(uplift) / 100.0))


static func _reject_deck_full(state: RunState, catalog: Dictionary, added_gu_ids: Array, removed_gu_ids: Array) -> Dictionary:
	if DeckCapacityScript.projected_count(state, catalog, added_gu_ids, removed_gu_ids) > DeckCapacityScript.capacity(catalog):
		return _rejected(state, "deck_capacity_exceeded")
	return {}


static func gain_notoriety(state: RunState, amount: int, reason_key: String) -> RunState:
	if amount <= 0:
		return state
	var cultivator := state.cultivator.duplicate(true)
	cultivator["notorious"] = int(cultivator.get("notorious", 0)) + amount
	return state.append_event(_event(
		state,
		"gain_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_gained",
		state.current_node_id,
		[reason_key]
	))


static func _record_neutral_npc_kill(state: RunState, catalog: Dictionary) -> Dictionary:
	var gains: Dictionary = catalog.get("reputation", {}).get("gains", {})
	return _accepted(gain_notoriety(state, int(gains.get("kill_neutral_npc", 0)), "kill_neutral_npc"))


static func _wash_notoriety(state: RunState, catalog: Dictionary) -> Dictionary:
	if notoriety(state) <= 0:
		return _rejected(state, "nothing_to_wash")
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var cost := int(effects.get("wash_lifespan_cost", 10))
	var reduce := int(effects.get("wash_reduce", 2))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	if lifespan - cost < 1:
		return _rejected(state, "lifespan_trade_warning")
	var cultivator := state.cultivator.duplicate(true)
	cultivator["lifespan"] = lifespan - cost
	cultivator["notorious"] = maxi(0, notoriety(state) - reduce)
	var next := state.append_event(_event(
		state,
		"wash_notoriety",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"notoriety_washed",
		state.current_node_id,
		[]
	))
	return _accepted(next)


static func _accepted(next: RunState) -> Dictionary:
	return {"state": next, "result": {"ok": true}}


static func _rejected(state: RunState, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}
