class_name Resolver
extends RefCounted


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const DeckCapacityScript = preload("res://scripts/domain/deck_capacity.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")


const APTITUDE_LADDER := ["ding", "bing", "yi", "jia"]

# R4.8: meta-rule grade imprints are rule changers; cap per run lives in deck.json.
# Removal service base prices (Task 5, R6.8) live in deck.json.

# Forced drop of a can_direct_drop=false gu attaches this configured curse.
const FORCED_DROP_CURSE_ID := "gu_erosion"
# Per-run usage counters live in node_flags as string values ("1", "2", ...).
const SERVICE_USE_FLAG_PREFIX := "svc_used_"
const REST_REMOVAL_MODES := ["remove_card", "remove_imprint", "remove_curse"]
# P2a B: rest visit/mode flags are scoped per node id ("<id>_used"/"<id>_mode")
# so nodes.json may declare more than one rest node. Every consumed visit also
# refreshes the bare "<id>" visited marker (_complete_node idempotency +
# MapGenerator.reachable_nodes, matching every other completed node).
const REST_NODE_TYPE := "rest"


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
	"accept", "ally", "buy_information", "claim", "cross", "deceive", "fight", "harvest",
	"inspect", "leave", "lure", "meditate", "open", "prepare", "retreat", "scout",
	"scheme", "take_imprint", "trade", "withdraw", "work",
]


static func apply(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if state.is_terminal():
		return _rejected(state, "terminal_run")
	var handler: Variant = _handler_for(str(command.get("type", "")))
	if handler == null:
		return _rejected(state, "unsupported_command")
	return handler.call(state, command, catalog)


static var _dispatch: Dictionary = {}


static func _handler_for(command_type: String) -> Variant:
	if _dispatch.is_empty():
		_dispatch = {
			"travel": func(state, command, catalog): return _travel(state, command, catalog),
			"resolve_contact": func(state, command, catalog): return _resolve_contact(state, command, catalog),
			"complete_node": func(state, command, _catalog): return _complete_node(state, command),
			"buy_gu": func(state, command, catalog): return _buy_gu(state, command, catalog),
			"sell_gu": func(state, command, catalog): return _sell_gu(state, command, catalog),
			"exchange_gu": func(state, command, catalog): return _exchange_gu(state, command, catalog),
			"refine_gu": func(state, command, catalog): return _refine_gu(state, command, catalog),
			"cultivate_rank_two": func(state, _command, catalog): return _cultivate_rank_two(state, catalog),
			"settle_feeding": func(state, _command, catalog): return _settle_feeding(state, catalog),
			"settle_node_feeding": func(state, _command, catalog): return _settle_node_feeding(state, catalog),
			"disable_card": func(state, command, _catalog): return _disable_card(state, command),
			"upgrade_card": func(state, command, _catalog): return _upgrade_card(state, command),
			"copy_card": func(state, command, _catalog): return _copy_card(state, command),
			"destroy_gu": func(state, command, catalog): return _destroy_gu(state, command, catalog),
			"remove_card": func(state, command, catalog): return _remove_card_command(state, command, catalog),
			"remove_imprint": func(state, command, catalog): return _remove_imprint_command(state, command, catalog),
			"spend_lifespan": func(state, command, _catalog): return _spend_lifespan(state, command),
			"accept_debt": func(state, _command, catalog): return _accept_debt(state, catalog),
			"use_gu": func(state, command, catalog): return _use_gu(state, command, catalog),
			"buy_opportunity": func(state, command, _catalog): return _buy_opportunity(state, command),
			"take_body_imprint": func(state, command, _catalog): return _take_body_imprint(state, command),
			"choose_action": func(state, command, catalog): return _choose_action(state, command, catalog),
			"retreat": func(state, _command, _catalog): return _retreat(state),
			"attempt_ascension": func(state, command, _catalog): return _attempt_ascension(state, command),
			"gain_relic": func(state, command, catalog): return _gain_relic(state, command, catalog),
			"shop_purchase": func(state, command, catalog): return _shop_purchase(state, command, catalog),
			"shop_lifespan_deal": func(state, command, catalog): return _shop_lifespan_deal(state, command, catalog),
			"shop_barter": func(state, command, catalog): return _shop_barter(state, command, catalog),
			"npc_trade": func(state, command, catalog): return _npc_trade(state, command, catalog),
			"scavenge": func(state, command, catalog): return _scavenge(state, command, catalog),
			"sell_material": func(state, command, catalog): return _sell_material(state, command, catalog),
			"use_material": func(state, command, catalog): return _use_material(state, command, catalog),
			"raise_aptitude": func(state, command, catalog): return _raise_aptitude(state, command, catalog),
			"record_neutral_npc_kill": func(state, _command, catalog): return _record_neutral_npc_kill(state, catalog),
			"wash_notoriety": func(state, _command, catalog): return _wash_notoriety(state, catalog),
			"record_boss_defeated": func(state, _command, catalog): return _record_boss_defeated(state, catalog),
			"record_layer_boss_defeated": func(state, command, catalog): return _record_layer_boss_defeated(state, command, catalog),
			"rest": func(state, command, catalog): return _rest(state, command, catalog),
			"gain_force_power": func(state, command, catalog): return _gain_force_power(state, command, catalog),
			"accept_event": func(state, command, catalog): return _accept_event(state, command, catalog),
			"gain_curse": func(state, command, catalog): return _gain_curse_command(state, command, catalog),
			"remove_curse": func(state, command, catalog): return _remove_curse_command(state, command, catalog),
			"swear_contracts": func(state, command, catalog): return _swear_contracts(state, command, catalog),
		}
	return _dispatch.get(command_type, null)


static func _resolve_contact(state: RunState, command: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	var node_id := str(command.get("node_id", ""))
	# Contact approaches are node-generic: any contact template may be
	# approached; fight drills the node's own enemy_kind via start_battle.
	# neutral_wanderer keeps its legacy effect set unchanged (pinned by tests).
	var node_type := ""
	for node_value in catalog.get("nodes", []):
		if str((node_value as Dictionary).get("id", "")) == node_id:
			node_type = str((node_value as Dictionary).get("type", ""))
			break
	if node_id != "neutral_wanderer" and node_type != "contact":
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
		"%s_%s" % [node_id, approach],
		node_id
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
	# 真元是节点内资源（2026-08-28 设计点）：节点完成即回满——跨节点不
	# 携带消耗，真元永远是「本节点的预算」。
	var next := state.append_event(_event(
		state,
		"complete_node",
		{"node_flags": state.node_flags, "essence": state.essence},
		{"node_flags": flags, "essence": state.essence_capacity},
		"node_completed",
		node_id
	))
	next.essence = next.essence_capacity
	next.cave_aperture["essence"] = next.essence_capacity
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
		"fixed", "advance":
			return _apply_fixed_recipe(state, command, catalog, recipe)
		"free_mix":
			return _apply_free_mix(state, command, catalog, recipe)
	return _apply_combine_recipe(state, command, catalog, recipe)


static func _recipe_material_pieces(material_cost: Dictionary) -> int:
	var total := 0
	for material_id in material_cost:
		total += int(material_cost[material_id])
	return total


static func _has_all_materials(state: RunState, material_cost: Dictionary) -> bool:
	for material_id in material_cost:
		if int(state.materials.get(str(material_id), 0)) < int(material_cost[material_id]):
			return false
	return true


static func _spend_materials(state: RunState, material_cost: Dictionary) -> RunState:
	if material_cost.is_empty():
		return state
	var remaining := state.materials.duplicate(true)
	var targets: Array[String] = []
	for material_id_value in material_cost:
		var material_id := str(material_id_value)
		remaining[material_id] = int(remaining.get(material_id, 0)) - int(material_cost[material_id_value])
		targets.append(material_id)
	var next := state.append_event(_event(
		state,
		"refine_gu",
		{"materials": state.materials},
		{"materials": remaining},
		"refinement_materials_spent",
		state.current_node_id,
		targets
	))
	next.materials = remaining
	return next


static func _apply_combine_recipe(state: RunState, _command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	var inputs: Array = recipe.get("input_gu_ids", [])
	var material_cost: Dictionary = recipe.get("materials", {})
	if inputs.size() + _recipe_material_pieces(material_cost) > SoulCapacityScript.craft_cap(state):
		return _rejected(state, "refinement_capacity_exceeded")
	if not _has_all_gu(state.refined_gu_ids, inputs):
		return _rejected(state, "missing_refinement_input")
	if not _has_all_materials(state, material_cost):
		return _rejected(state, "missing_refinement_material")
	var paid := _spend_materials(state, material_cost)
	# The result is determined from the run seed and immutable event position.
	# Commands never accept client supplied dice values.
	# 2026-08-28 设计修正：蛊方的「转数」只由产出蛊的转数表达（advance 链
	# 与产出 rank），与炼蛊成功率无直接关系。
	var roll := _refinement_roll(paid, str(recipe.get("id", "")))
	if roll > int(recipe.get("success_roll_max", 100)):
		var destroyed := _without_gu(paid.refined_gu_ids, inputs)
		var unequipped := _without_gu(paid.equipped_gu_ids, inputs)
		var failed := paid.append_event(_event(
			paid,
			"refine_gu",
			{"gu_ids": paid.gu_ids, "refined_gu_ids": paid.refined_gu_ids},
			{"gu_ids": destroyed, "refined_gu_ids": destroyed, "equipped_gu_ids": unequipped},
			"refinement_failed_destroyed_inputs",
			paid.current_node_id,
			inputs
		))
		return _accepted(failed)
	var blocked := _reject_deck_full(paid, catalog, [str(recipe["output_gu_id"])], inputs)
	if not blocked.is_empty():
		return blocked
	return _add_gu_transaction(paid, str(recipe["output_gu_id"]), 0, inputs, "refinement_succeeded", ["recipe:%s" % str(recipe["id"])])


static func _codex_unlocks_recipe(state: RunState, recipe: Dictionary) -> bool:
	return state.global_codex_ids.has(str(recipe.get("id", ""))) \
		or state.global_codex_ids.has(str(recipe.get("output_gu_id", "")))


## 蛊方图鉴门禁（2026-08-30 裁定，预览/执行/快照共用同一函数）：
## fixed/combine 须持有蛊方，advance/free_mix 豁免；default_unlocked 初始持有。
static func recipe_unlocked(state: RunState, recipe: Dictionary) -> bool:
	if str(recipe.get("kind", "combine")) == "advance":
		return true
	if bool(recipe.get("default_unlocked", false)):
		return true
	return _codex_unlocks_recipe(state, recipe)


static func _apply_fixed_recipe(state: RunState, command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	if not recipe_unlocked(state, recipe):
		return _rejected(state, "refinement_recipe_locked")
	var is_advance := str(recipe.get("kind", "")) == "advance"
	var inputs: Array = recipe.get("input_gu_ids", [])
	if is_advance and (inputs.size() != 1 or str(recipe.get("output_gu_id", "")) != str(inputs[0])):
		return _rejected(state, "invalid_advance_recipe")
	var stone_cost := int(recipe.get("stone_cost", 0))
	if stone_cost > 0 and state.stone < stone_cost:
		return _rejected(state, "insufficient_stone")
	var material_cost: Dictionary = recipe.get("materials", {})
	# 缺料先于容量：玩家应先看到"缺什么"，而不是被并发上限挡住。
	var preselected := _selected_input_instance_ids(state, command, inputs)
	if preselected.is_empty() and not inputs.is_empty():
		return _rejected(state, "missing_refinement_input")
	if inputs.size() + _recipe_material_pieces(material_cost) > SoulCapacityScript.craft_cap(state):
		return _rejected(state, "refinement_capacity_exceeded")
	if not _has_all_materials(state, material_cost):
		return _rejected(state, "missing_refinement_material")
	# 转数门禁（2026-08-31）：input_min_rank 校验提前到烧材料前，拒绝不烧。
	var min_rank := int(recipe.get("input_min_rank", 0))
	if min_rank > 0:
		for instance_id_value in preselected:
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if int(instance.get("rank", 1)) < min_rank:
				return _rejected(state, "refinement_input_rank_insufficient")
	var paid := _spend_materials(state, material_cost)
	var blocked := _reject_deck_full(paid, catalog, [str(recipe["output_gu_id"])], inputs)
	if not blocked.is_empty():
		return blocked
	var selected := preselected
	var instances := paid.gu_instances.duplicate(true)
	var aperture := paid.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	for instance_id_value in selected:
		var instance_id := str(instance_id_value)
		var consumed: Dictionary = instances[instance_id].duplicate(true)
		consumed["state"] = "consumed"
		instances[instance_id] = consumed
		stored.erase(instance_id)
	var output_instance_id := _next_gu_instance_id(instances)
	var output_instance := {
		"instance_id": output_instance_id,
		"definition_id": str(recipe["output_gu_id"]),
		"state": "refined",
	}
	if is_advance:
		# 同名升阶：本体进阶不换名，阶数 +1（封顶五转）；是否可达由
		# 转数/阶顶决定，否则拒绝而不烧材料。
		var consumed_rank := int(instances[str(selected[0])].get("rank", 1))
		var new_rank := mini(consumed_rank + 1, 5)
		if new_rank <= consumed_rank:
			return _rejected(paid, "advance_capped")
		output_instance["rank"] = new_rank
	else:
		# 定向合炼：产出转数 = 配方 output_rank（缺省回退产出蛊本体定义）。
		var fallback_rank := int(catalog.get("gu_by_id", {}).get(str(recipe["output_gu_id"]), {}).get("rank", 1))
		output_instance["rank"] = clampi(int(recipe.get("output_rank", fallback_rank)), 1, 5)
	instances[output_instance_id] = output_instance
	stored.append(output_instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := paid.append_event(_event(
		paid,
		"refine_gu",
		{"stone": paid.stone, "gu_instances": paid.gu_instances, "cave_aperture": paid.cave_aperture},
		{"stone": paid.stone - stone_cost, "gu_instances": instances, "cave_aperture": aperture},
		"refinement_succeeded",
		paid.current_node_id,
		selected + [output_instance_id, "recipe:%s" % str(recipe["id"])]
	))
	next.sync_legacy_gu_projections()
	if stone_cost > 0:
		next.stone = paid.stone - stone_cost
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
		if not _same_multiset(definitions, inputs):
			return ([] as Array[String])
		return selected
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
	return RunState.next_gu_instance_id(instances)


static func _refinement_roll(state: RunState, recipe_id: String) -> int:
	return SeededRollScript.index(100, int(state.seed), recipe_id, state.event_log.size()) + 1


static func _apply_free_mix(state: RunState, command: Dictionary, _catalog: Dictionary, recipe: Dictionary) -> Dictionary:
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
	var roll := SeededRollScript.index(total, int(state.seed), "+".join(selected), state.event_log.size()) + 1
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
	# R9.1 free-mix failure entry point: junk outcomes (anything but a
	# mutation) may carry an optional fail_curse_id backlash attachment.
	var fail_curse_id := str(chosen.get("fail_curse_id", ""))
	if not fail_curse_id.is_empty() and str(chosen.get("effect", "")) != "mutate_to":
		next = CurseRegistryScript.gain_curse(next, fail_curse_id, "free_mix_failure:%s" % str(chosen.get("id", "")))
	return _finalize_if_dead(next)


static func _cultivate_rank_two(state: RunState, catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "cultivation_spring":
		return _rejected(state, "not_cultivation_window")
	if state.cultivation >= 2:
		return _rejected(state, "cultivation_already_rank_two")
	if state.stone < 5:
		return _rejected(state, "insufficient_stone")
	var aperture := state.cave_aperture.duplicate(true)
	aperture["essence_max"] = EssenceCapacityScript.essence_max_for(state, catalog, 2)
	# 玩家等级曲线（2026-08-29 设计点）：转数只抬真元总量上限，不加 HP/攻击。
	# 2026-08-28 验收批：上限值从公式取（aptitude.json tier 表唯一真值），
	# 不再硬编码 3 + 2。
	var next_capacity := maxi(state.essence_capacity, EssenceCapacityScript.essence_max_for(state, catalog, 2))
	var next := state.append_event(_event(
		state,
		"cultivate_rank_two",
		{"cultivation": state.cultivation, "stone": state.stone, "essence": state.essence, "cave_aperture": state.cave_aperture},
		{"cultivation": 2, "stone": state.stone - 5, "essence": state.essence_capacity, "essence_capacity": next_capacity, "cave_aperture": aperture},
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


static func _destroy_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return _rejected(state, "gu_instance_unavailable")
	var blocked := _cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	var payload := _destroyed_gu_payload(state, instance_id)
	var next := state.append_event(_event(
		state,
		"destroy_gu",
		{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"gu_instances": payload["instances"], "cave_aperture": payload["aperture"]},
		"gu_destroyed",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


# Section 16.15: a can_direct_drop=false gu refuses every direct destroy path.
# The refusal still appends a backlash consequence (one gu_erosion layer) so it
# is never silent; the returned rejection carries the curse-gained state.
static func _cursed_drop_block(state: RunState, catalog: Dictionary, definition_id: String) -> Dictionary:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	if bool(definition.get("can_direct_drop", true)):
		return {}
	return _rejected(
		CurseRegistryScript.gain_curse(state, FORCED_DROP_CURSE_ID, "forced_drop"),
		"cursed_gu_not_directly_droppable"
	)


static func _destroyed_gu_payload(state: RunState, instance_id: String) -> Dictionary:
	var instances := state.gu_instances.duplicate(true)
	var destroyed: Dictionary = instances.get(instance_id, {}).duplicate(true)
	destroyed["state"] = "dead"
	instances[instance_id] = destroyed
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	stored.erase(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	return {"instances": instances, "aperture": aperture}


# Task 5 black-market removal services share one accounting family: per-run
# usage counters in node_flags, escalating price per prior use of the SAME
# service, hard per-run limits. Rest-node removal bypasses both (R8.1).
static func service_use_count(state: RunState, service_id: String) -> int:
	return EconomyRulesScript.service_use_count(state, service_id)


static func service_limit(catalog: Dictionary, service_id: String) -> int:
	return EconomyRulesScript.service_limit(catalog, service_id)


static func service_price_for(catalog: Dictionary, state: RunState, service_id: String, base: int) -> int:
	return EconomyRulesScript.service_price_for(catalog, state, service_id, base)


static func _bump_service_flag(flags: Dictionary, service_id: String) -> void:
	var key := SERVICE_USE_FLAG_PREFIX + service_id
	flags[key] = str(int(str(flags.get(key, "0"))) + 1)


static func _remove_card_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return _rejected(state, "gu_instance_unavailable")
	var blocked := _cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	if service_use_count(state, "remove_card") >= service_limit(catalog, "remove_card"):
		return _rejected(state, "service_limit_exceeded")
	var cost := service_price_for(catalog, state, "remove_card", int(catalog.get("deck", {}).get("remove_card_cost", 120)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	_bump_service_flag(flags, "remove_card")
	var payload := _destroyed_gu_payload(state, instance_id)
	var next := state.append_event(_event(
		state,
		"svc_remove_card",
		{
			"stone": state.stone,
			"gu_instances": state.gu_instances,
			"cave_aperture": state.cave_aperture,
			"node_flags": state.node_flags,
		},
		{
			"stone": state.stone - cost,
			"gu_instances": payload["instances"],
			"cave_aperture": payload["aperture"],
			"node_flags": flags,
		},
		"gu_removed_by_service",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


# R4.8 contracts-tier meta rules are rule changers, not droppable items, so
# they can never be removed through this service.
static func _remove_imprint_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	if not catalog.get("relic_by_id", {}).has(relic_id):
		return _rejected(state, "unknown_relic")
	if not state.relic_ids.has(relic_id):
		return _rejected(state, "relic_not_owned")
	if str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule":
		return _rejected(state, "meta_rule_not_removable")
	if service_use_count(state, "remove_imprint") >= service_limit(catalog, "remove_imprint"):
		return _rejected(state, "service_limit_exceeded")
	var cost := service_price_for(catalog, state, "remove_imprint", int(catalog.get("deck", {}).get("remove_imprint_cost", 150)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	_bump_service_flag(flags, "remove_imprint")
	var relics := state.relic_ids.duplicate()
	relics.erase(relic_id)
	var meta_rules := state.meta_rules.duplicate(true)
	meta_rules.erase(relic_id)
	var next := state.append_event(_event(
		state,
		"svc_remove_imprint",
		{
			"stone": state.stone,
			"relic_ids": state.relic_ids,
			"meta_rules": state.meta_rules,
			"node_flags": state.node_flags,
		},
		{
			"stone": state.stone - cost,
			"relic_ids": relics,
			"meta_rules": meta_rules,
			"node_flags": flags,
		},
		"imprint_removed_by_service",
		state.current_node_id,
		[relic_id]
	))
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


static func _accept_debt(state: RunState, _catalog: Dictionary) -> Dictionary:
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


static func _can_gain_relic(state: RunState, catalog: Dictionary, relic_id: String) -> String:
	# Shared gate for every relic-granting path (direct gain and shop barter).
	# Returns "" when the relic may be gained, else the rejection reason.
	var relic: Dictionary = catalog.get("relic_by_id", {}).get(relic_id, {})
	if relic.is_empty():
		return "unknown_relic"
	if state.relic_ids.has(relic_id):
		return "relic_already_owned"
	# R4.9 imprint slots: the hard cap forces build trade-offs.
	if state.relic_ids.size() >= DeckCapacityScript.imprint_capacity(catalog):
		return "imprint_capacity_exceeded"
	# Order locked by brief: capacity rejection wins before the meta cap (R4.8).
	# R14.6 (night batch): system DDA markers (sys: keys) never count against
	# the player meta-rule cap.
	if str(relic.get("grade", "")) == "meta_rule" and DdaResolverScript.player_rule_count(state.meta_rules) >= int(catalog.get("deck", {}).get("meta_rule_cap", 2)):
		return "meta_rule_cap_reached"
	return ""


static func _gain_relic(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	var blocked_reason := _can_gain_relic(state, catalog, relic_id)
	# R4.9 rejection is a pure no-op so callers can offer swaps without losing
	# state.
	if not blocked_reason.is_empty():
		return _rejected(state, blocked_reason)
	var meta_grade := str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule"
	var relics := state.relic_ids.duplicate()
	relics.append(relic_id)
	var before := {"relic_ids": state.relic_ids}
	var after := {"relic_ids": relics}
	if meta_grade:
		var meta_rules := state.meta_rules.duplicate(true)
		meta_rules[relic_id] = true
		before["meta_rules"] = state.meta_rules
		after["meta_rules"] = meta_rules
	var next := state.append_event(_event(
		state,
		"gain_relic",
		before,
		after,
		"relic_gained",
		state.current_node_id,
		[relic_id]
	))
	var result := _accepted(next)
	if meta_grade:
		result = _append_result_feed(result, "meta_rule_recorded")
	return result


## 统一裁定表：当前大层的黑市参数（货阶上限 / 价格乘数%）。
static func _current_shop_layer(state: RunState, catalog: Dictionary) -> int:
	var layer := clampi(int(state.current_node_layer), 1, 5)
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	if layer == 0 or not layers_cfg.has(str(layer)):
		return 1
	return layer


static func shop_layer_price(catalog: Dictionary, state: RunState, base: int) -> int:
	var price := price_for(catalog, state, base)
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(_current_shop_layer(state, catalog)), {})
	var pct := int(layer_cfg.get("shop_price_pct", 0))
	return price + int(price * pct / 100.0)


static func shop_max_tier(state: RunState, catalog: Dictionary) -> int:
	var layers_cfg: Dictionary = catalog.get("pacing", {}).get("layers", {})
	var layer_cfg: Dictionary = layers_cfg.get(str(_current_shop_layer(state, catalog)), {})
	return int(layer_cfg.get("shop_max_tier", 1))


static func _shop_purchase(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(str(command.get("offer_id", "")), {})
	var kind := str(offer.get("kind", ""))
	if kind == "soul_boost":
		return _shop_soul_boost(state, command, catalog, offer)
	if kind == "material_purchase":
		return _shop_material_purchase(state, offer, catalog)
	if kind == "recipe_unlock":
		return _shop_recipe_unlock(state, offer, catalog)
	if kind == "resource_trade":
		return _shop_resource_trade(state, offer, catalog)
	if str(offer.get("kind", "")) != "purchase":
		return _rejected(state, "unknown_shop_offer")
	var blocked := _reject_deck_full(state, catalog, [str(offer["gu_id"])], [])
	if not blocked.is_empty():
		return blocked
	# 黑市分层上架：货阶高于当前大层时拒绝（层越深货越贵且稀有度越高）。
	if int(offer.get("tier", 1)) > _current_shop_layer(state, catalog):
		return _rejected(state, "shop_tier_locked")
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
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


static func _shop_material_purchase(state: RunState, offer: Dictionary, catalog: Dictionary) -> Dictionary:
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var material_id := str(offer.get("material_id", ""))
	var materials := state.materials.duplicate(true)
	materials[material_id] = int(materials.get(material_id, 0)) + 1
	var next := state.append_event(_event(state, "shop_purchase", {"stone": state.stone, "materials": state.materials}, {"stone": state.stone - cost, "materials": materials}, "shop_material_purchase_completed", state.current_node_id, [material_id]))
	next.stone = state.stone - cost
	next.materials = materials
	return _accepted(next)


static func _shop_recipe_unlock(state: RunState, offer: Dictionary, catalog: Dictionary) -> Dictionary:
	var recipe_id := str(offer.get("recipe_id", ""))
	if state.global_codex_ids.has(recipe_id):
		return _rejected(state, "recipe_already_unlocked")
	var cost := shop_layer_price(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var codex := state.global_codex_ids.duplicate()
	codex.append(recipe_id)
	var next := state.append_event(_event(state, "shop_recipe_unlocked", {"stone": state.stone, "global_codex_ids": state.global_codex_ids}, {"stone": state.stone - cost, "global_codex_ids": codex}, "shop_recipe_unlock_completed", state.current_node_id, [recipe_id]))
	next.stone = state.stone - cost
	next.global_codex_ids = codex
	return _accepted(next)


static func _shop_soul_boost(state: RunState, _command: Dictionary, catalog: Dictionary, offer: Dictionary) -> Dictionary:
	var cost := price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var soul := int(state.cultivator.get("soul", 0))
	var soul_max := int(state.cultivator.get("soul_max", soul))
	if soul >= soul_max:
		return _rejected(state, "soul_at_max")
	var soul_after := soul + int(offer.get("soul_gain", 1))
	var next := state.append_event(_event(
		state,
		"shop_purchase",
		{"stone": state.stone, "soul": soul},
		{"stone": state.stone - cost, "soul": soul_after},
		"shop_soul_pill",
		state.current_node_id,
		["soul_pill"]
	))
	next.stone = state.stone - cost
	next.cultivator["soul"] = soul_after
	return _accepted(next)


static func _shop_resource_trade(state: RunState, offer: Dictionary, _catalog: Dictionary) -> Dictionary:
	# 一次门禁：以 offer_id 为 key 写在 node_flags，第二次访问拒且不改 state。
	var offer_id := str(offer.get("id", ""))
	if offer_id.is_empty():
		return _rejected(state, "resource_trade_unknown")
	if str(state.node_flags.get(offer_id, "")) == "used":
		return _rejected(state, "resource_trade_already_used")
	var cost_kind := str(offer.get("cost_kind", ""))
	var gain_kind := str(offer.get("gain_kind", ""))
	var cost_amount := int(offer.get("cost_amount", 0))
	var gain_amount := int(offer.get("gain_amount", 0))
	var cultivator := state.cultivator.duplicate(true)
	var before_cultivator := state.cultivator.duplicate(true)
	var health_after := int(state.health)
	var max_health_after := int(state.max_health)
	# 预检并扣减代价
	if cost_kind == "lifespan":
		var lifespan := int(cultivator.get("lifespan", 0))
		if lifespan - cost_amount < 1:
			return _rejected(state, "insufficient_lifespan")
		cultivator["lifespan"] = lifespan - cost_amount
	elif cost_kind == "soul":
		var soul := int(cultivator.get("soul", 0))
		if soul - cost_amount < 1:
			return _rejected(state, "insufficient_soul")
		cultivator["soul"] = soul - cost_amount
	elif cost_kind == "health":
		if int(state.health) - cost_amount <= 0:
			return _rejected(state, "insufficient_health")
		health_after = int(state.health) - cost_amount
	else:
		return _rejected(state, "resource_trade_unknown")
	# 收入：lifespan/soul/health（+max_health 同写）
	var after: Dictionary = {
		"cultivator": cultivator,
		"node_flags": state.node_flags.duplicate(true),
		"health": health_after,
		"max_health": max_health_after,
	}
	var flags: Dictionary = state.node_flags.duplicate(true)
	flags[offer_id] = "used"
	after["node_flags"] = flags
	if gain_kind == "lifespan":
		cultivator["lifespan"] = int(cultivator.get("lifespan", 0)) + gain_amount
	elif gain_kind == "soul":
		var soul := int(cultivator.get("soul", 0))
		var soul_max := int(cultivator.get("soul_max", soul + gain_amount))
		cultivator["soul"] = mini(soul + gain_amount, soul_max)
	elif gain_kind == "health":
		max_health_after = int(state.max_health) + gain_amount
		health_after = min(max_health_after, health_after + gain_amount)
	else:
		return _rejected(state, "resource_trade_unknown")
	after["health"] = health_after
	after["max_health"] = max_health_after
	after["cultivator"] = cultivator
	var next := state.append_event(_event(
		state,
		"shop_resource_trade",
		{"cultivator": before_cultivator, "health": int(state.health), "max_health": int(state.max_health), "node_flags": state.node_flags},
		after,
		"shop_resource_trade_completed",
		state.current_node_id,
		[offer_id]
	))
	next.cultivator = cultivator
	next.health = health_after
	next.max_health = max_health_after
	next.node_flags = (after.get("node_flags", {}) as Dictionary).duplicate(true)
	return _accepted(next)


static func _raise_aptitude(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var paths: Array = catalog.get("aptitude", {}).get("paths", [])
	if paths.is_empty():
		return _rejected(state, "no_aptitude_path")
	var path: Dictionary = paths[0]
	var node_id := str(command.get("node_id", state.current_node_id))
	var node_kind := ""
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == node_id:
			node_kind = str(node.get("type", ""))
			break
	if not (path.get("node_kinds", []) as Array).has(node_kind):
		return _rejected(state, "aptitude_path_unavailable")
	if str(state.node_flags.get("aptitude_raised", "")) == "true":
		return _rejected(state, "aptitude_raised_once")
	if str(state.aptitude) == "jia":
		return _rejected(state, "aptitude_at_peak")
	var lifespan_cost := int(path.get("cost_lifespan", 0))
	var stone_cost := int(path.get("cost_stone", 0))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	# Deaths must stay predictable: paying lifespan down to zero is rejected.
	if lifespan - lifespan_cost < 1:
		return _rejected(state, "lifespan_trade_warning")
	if state.stone < stone_cost:
		return _rejected(state, "insufficient_stone")
	var ladder: Array = APTITUDE_LADDER
	var index := ladder.find(str(state.aptitude))
	var raised := str(ladder[mini(ladder.size() - 1, index + 1)])
	var flags := state.node_flags.duplicate(true)
	flags["aptitude_raised"] = "true"
	var next := state.append_event(_event(
		state,
		"raise_aptitude",
		{"aptitude": state.aptitude, "lifespan": lifespan, "stone": state.stone},
		{"aptitude": raised, "lifespan": lifespan - lifespan_cost, "stone": state.stone - stone_cost},
		"aptitude_raised",
		node_id,
		[raised]
	))
	next.aptitude = raised
	next.cultivator["lifespan"] = lifespan - lifespan_cost
	next.node_flags = flags
	next.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max(next, catalog)
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
	var roll := SeededRollScript.index(total, int(state.seed), "+".join(selected), state.event_log.size()) + 1
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
	var meta_rules := state.meta_rules.duplicate(true)
	var result_feeds: Array = []
	if chosen.has("gu_id"):
		var instance_id := _next_gu_instance_id(instances)
		instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(chosen["gu_id"]),
			"state": "refined",
		}
		stored.append(instance_id)
	elif chosen.has("relic_id"):
		# Relic rewards ride the same gate as direct gains (R4.9/R4.8); a
		# blocked reward resolves the barter without it instead of failing.
		var relic_id := str(chosen["relic_id"])
		var blocked_reason := _can_gain_relic(state, catalog, relic_id)
		if blocked_reason.is_empty():
			relics.append(relic_id)
			if str(catalog.get("relic_by_id", {}).get(relic_id, {}).get("grade", "")) == "meta_rule":
				meta_rules[relic_id] = true
				result_feeds.append("meta_rule_recorded")
		else:
			result_feeds.append("relic_reward_blocked_%s" % blocked_reason)
	aperture["stored_gu_instance_ids"] = stored
	var before := {
		"gu_instances": state.gu_instances,
		"cave_aperture": state.cave_aperture,
		"relic_ids": state.relic_ids,
	}
	var after := {
		"gu_instances": instances,
		"cave_aperture": aperture,
		"relic_ids": relics,
	}
	if meta_rules != state.meta_rules:
		before["meta_rules"] = state.meta_rules
		after["meta_rules"] = meta_rules
	var next := state.append_event(_event(
		state,
		"shop_barter",
		before,
		after,
		"shop_barter_resolved",
		state.current_node_id,
		[str(chosen.get("id", ""))]
	))
	next.sync_legacy_gu_projections()
	var result := _accepted(next)
	result["outcome"] = str(chosen.get("id", ""))
	for feed_value in result_feeds:
		result = _append_result_feed(result, str(feed_value))
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
	var curse_id := str(event.get("curse_id", ""))
	if not curse_id.is_empty():
		next = CurseRegistryScript.gain_curse(next, curse_id, "event:%s" % str(event.get("id", "")))
	return _accepted(next)


static func _gain_curse_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return _rejected(state, "unknown_curse")
	var source := str(command.get("source", "command"))
	return _accepted(CurseRegistryScript.gain_curse(state, curse_id, source))


# C1-min §16.13: opening contracts are global rule modifiers sworn exactly
# once, at the trailhead. The controller passes allowed_ids from the hall
# save; the domain validates shape (unknown/duplicate/cap/mutual exclusion)
# and applies the immediate hp_max cost behind a lethal precheck so swearing
# can never kill.
static func _swear_contracts(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if str(state.current_node_id) != "trailhead":
		return _rejected(state, "contracts_trailhead_only")
	if str(state.node_flags.get("contracts_sworn", "")) == "true":
		return _rejected(state, "contracts_already_sworn")
	var requested: Array[String] = []
	for value in command.get("ids", []):
		var id := str(value)
		if requested.has(id):
			return _rejected(state, "duplicate_contract")
		requested.append(id)
	if requested.is_empty():
		return _rejected(state, "no_contracts_selected")
	var cfg: Dictionary = catalog.get("contracts", {})
	var entry_by_id := _contract_entry_by_id(cfg)
	var allowed: Array = command.get("allowed_ids", [])
	for id in requested:
		if not entry_by_id.has(id):
			return _rejected(state, "unknown_contract")
		if not allowed.has(id):
			return _rejected(state, "contract_locked")
	if requested.size() > int(cfg.get("contract_cap", 0)):
		return _rejected(state, "contract_cap_exceeded")
	for id in requested:
		for excluded_value in entry_by_id[id].get("mutual_exclusive", []):
			if requested.has(str(excluded_value)):
				return _rejected(state, "contract_mutual_exclusive")
	var hp_delta := 0
	for id in requested:
		for rule_value in entry_by_id[id].get("rules", []):
			var rule: Dictionary = rule_value
			if str(rule.get("key", "")) == "hp_max_penalty":
				hp_delta += int(rule.get("value", 0))
	if state.max_health + hp_delta < 1:
		return _rejected(state, "contract_hp_max_lethal")
	var flags := state.node_flags.duplicate(true)
	flags["contracts_sworn"] = "true"
	var after := {"contracts": requested.duplicate(), "node_flags": flags}
	if hp_delta != 0:
		var new_max := state.max_health + hp_delta
		var cultivator := state.cultivator.duplicate(true)
		cultivator["max_health"] = new_max
		after["max_health"] = new_max
		# Clamping keeps health <= max and can never reach 0 because of the
		# lethal precheck above (new_max >= 1).
		after["health"] = mini(state.health, new_max)
		after["cultivator"] = cultivator
	var next := state.append_event(_event(
		state,
		"contracts_sworn",
		{"node_flags": state.node_flags},
		after,
		"contracts_sworn",
		state.current_node_id,
		requested.duplicate()
	))
	return _accepted(next)


static func _contract_entry_by_id(cfg: Dictionary) -> Dictionary:
	var indexed := {}
	for entry_value in cfg.get("entries", []):
		var entry: Dictionary = entry_value
		indexed[str(entry.get("id", ""))] = entry
	return indexed


# R9.3: the black-market paid service. Pricing uses the shared M5 uplift plus
# the Task 5 per-service use escalation, and consumes the same limit pool as
# remove_card/remove_imprint so all three services share one accounting family.
static func _remove_curse_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return _rejected(state, "unknown_curse")
	if CurseRegistryScript.layers_of(state, curse_id) <= 0:
		return _rejected(state, "curse_not_present")
	if service_use_count(state, "remove_curse") >= service_limit(catalog, "remove_curse"):
		return _rejected(state, "service_limit_exceeded")
	var base := int(catalog["curse_by_id"][curse_id].get("removal_base_cost", 1))
	var cost := service_price_for(catalog, state, "remove_curse", base)
	if state.stone < cost:
		return _rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	_bump_service_flag(flags, "remove_curse")
	var paid := state.append_event(_event(
		state,
		"svc_remove_curse",
		{"stone": state.stone, "node_flags": state.node_flags},
		{"stone": state.stone - cost, "node_flags": flags},
		"curse_removal_paid",
		state.current_node_id,
		[curse_id]
	))
	return _accepted(CurseRegistryScript.remove_curse(paid, curse_id))


static func _is_rest_node(catalog: Dictionary, node_id: String) -> bool:
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id and str(node.get("type", "")) == REST_NODE_TYPE:
			return true
	return false


static func _rest_visit_key(node_id: String) -> String:
	return "%s_used" % node_id


static func _rest_mode_key(node_id: String) -> String:
	return "%s_mode" % node_id


static func _rest_visit_consumed(state: RunState) -> bool:
	return str(state.node_flags.get(_rest_visit_key(state.current_node_id), "")) == "used"


static func _travel(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var node_id := str(command.get("node_id", ""))
	if node_id.is_empty():
		return _rejected(state, "missing_node_id")
	# R8.1 hard choice (P2a B generalized to every type=="rest" node): entering
	# a rest node commits the player to exactly one benefit; leaving without
	# consuming the visit is refused (skip only means never entering the node).
	if (_is_rest_node(catalog, state.current_node_id) or _is_rest_node(catalog, str(state.current_node_template_id))) and not _rest_visit_consumed(state):
		return _rejected(state, "rest_choice_required")
	# R-layering hard gate: the ascension window only opens after the final
	# layer's boss falls. Topology already funnels it behind final_boss_stand;
	# this guard keeps the rule true even against out-of-band travel commands.
	if node_id == "ascension_window" and str(state.node_flags.get("boss_defeated", "")) != "true":
		return _rejected(state, "boss_undefeated")
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
	# Ascension grants (升仙五项): a node may declare that performing one of
	# its actions secures one of the five ascension conditions. The mapping
	# lives on the node in nodes.json (ascension_grants); without it the two
	# flow-granted conditions (heaven_earth_qi, aperture_foundation) had no
	# source and ascension could never succeed outside of tests.
	var grant_flag := _ascension_grant_for(state, action_id, catalog)
	if not grant_flag.is_empty():
		var grant := _ascension_transition(state, grant_flag, true, "ascension_grant_%s" % grant_flag)
		next = next.append_event(_event(
			next,
			"choose_action",
			grant["before"],
			grant["after"],
			str(grant["reason"]),
			state.current_node_id
		))
	var result := {
		"ok": true,
		"action_id": action_id,
		"effect_id": str(transition["effect_id"]),
	}
	# Playthrough finding (night batch): generic combat nodes (no npc_id) could
	# never start a battle because "fight" was only wired for social actions.
	# The standard fight transition signals the controller to open the battle.
	if bool(transition.get("start_battle", false)):
		result["start_battle"] = true
	return {
		"state": next,
		"result": result,
	}


static func _standard_action_transition(state: RunState, action_id: String) -> Dictionary:
	match action_id:
		"work":
			return _resource_transition(state, "stone", 3, "action_work_paid")
		"harvest":
			return _resource_transition(state, "stone", 2, "action_harvest_stone")
		"fight":
			# Generic combat-node fight: no resource exchange, just the battle
			# trigger; the controller opens BattleResolver via start_battle.
			return {
				"ok": true,
				"before": {},
				"after": {},
				"reason": "node_fight_started",
				"effect_id": "fight",
				"start_battle": true,
			}
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


## The five ascension conditions of the smoke design's 终局资格 ledger.
const ASCENSION_CONDITION_KEYS := [
	"aperture_foundation", "heaven_earth_qi", "site", "protection", "external_interference",
]


static func _record_layer_boss_defeated(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var layer := int(command.get("layer", 0))
	if layer < 1 or layer > 5:
		return _rejected(state, "invalid_layer_boss")
	var flags := state.node_flags.duplicate(true)
	flags["boss_defeated_L%d" % layer] = "true"
	# 2026-08-31 用户裁定：击败每大层 Boss 自动升转（"击败敌人获得经验、
	# 经验自动提升等级"的过渡实现）；转数只抬真元上限并回满，不加 HP/攻击。
	var target_rank := mini(5, layer + 1)
	var next_cultivation := maxi(int(state.cultivation), target_rank)
	var next_capacity := EssenceCapacityScript.essence_max_for(state, catalog, next_cultivation)
	var aperture := state.cave_aperture.duplicate(true)
	aperture["essence_max"] = next_capacity
	var next := state.append_event(_event(
		state,
		"record_layer_boss_defeated",
		{"node_flags": state.node_flags, "cultivation": state.cultivation, "essence": state.essence,
			"essence_capacity": state.essence_capacity, "cave_aperture": state.cave_aperture},
		{"node_flags": flags, "cultivation": next_cultivation, "essence": next_capacity,
			"essence_capacity": next_capacity, "cave_aperture": aperture},
		"layer_boss_%d_defeated" % layer,
		state.current_node_id
	))
	next.node_flags = flags
	return _accepted(next)


static func _ascension_grant_for(state: RunState, action_id: String, catalog: Dictionary) -> String:
	# 拓扑 v2：实例 id 与模板 id 分离；旧实例（first_run/测试）回退用节点 id。
	var node_id := str(state.current_node_template_id) if not str(state.current_node_template_id).is_empty() else str(state.current_node_id)
	for node_value in catalog.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) != node_id:
			continue
		var grants: Dictionary = node.get("ascension_grants", {})
		var flag := str(grants.get(action_id, ""))
		return flag if flag in ASCENSION_CONDITION_KEYS else ""
	return ""


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
			if not known_facts.has("procured_weakness"):
				known_facts.append("procured_weakness")
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


# N-candidate (night batch): NPC personal inventories. npc_trade reuses the
# shop handlers verbatim after the NPC-scoped gates, so prices (price_for:
# inflation/contracts/notoriety), deck capacity, soul/lifespan deals and the
# seeded barter roll stay byte-identical with shop purchases.
static func _npc_trade(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var npc := _npc_by_id(catalog, str(command.get("npc_id", "")))
	if npc.is_empty():
		return _rejected(state, "unknown_npc")
	var offer_id := str(command.get("offer_id", ""))
	var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(offer_id, {})
	if offer.is_empty():
		return _rejected(state, "unknown_shop_offer")
	var stock: Array = npc.get("stock", [])
	if not stock.has(offer_id):
		return _rejected(state, "npc_stock_missing")
	if not _current_node_declares_npc(state, catalog, str(npc.get("id", "unknown"))):
		return _rejected(state, "npc_not_present")
	match str(offer.get("kind", "")):
		"purchase":
			return _shop_purchase(state, {"offer_id": offer_id}, catalog)
		"soul_boost":
			return _shop_soul_boost(state, {}, catalog, offer)
		"lifespan_deal":
			return _shop_lifespan_deal(state, {"offer_id": offer_id}, catalog)
		"barter":
			return _shop_barter(state, {"offer_id": offer_id, "input_instance_ids": command.get("input_instance_ids", [])}, catalog)
		_:
			return _rejected(state, "unknown_shop_offer")


static func _current_node_declares_npc(state: RunState, catalog: Dictionary, npc_id: String) -> bool:
	for node in catalog.get("nodes", []):
		if str(node.get("id", "")) == state.current_node_id:
			return str(node.get("npc_id", "")) == npc_id
	return false


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


static func _gain_force_power(state: RunState, command: Dictionary, _catalog: Dictionary) -> Dictionary:
	var source_id := str(command.get("source_id", ""))
	if source_id.is_empty():
		return _rejected(state, "missing_force_source")
	var cultivator := state.cultivator.duplicate(true)
	var imprints: Array = cultivator.get("force_imprints", []).duplicate()
	if imprints.has(source_id):
		return _rejected(state, "force_imprint_repeated")
	imprints.append(source_id)
	cultivator["force_imprints"] = imprints
	cultivator["force_power"] = int(cultivator.get("force_power", 0)) + int(command.get("amount", 1))
	var next := state.append_event(_event(
		state,
		"gain_force_power",
		{"cultivator": state.cultivator},
		{"cultivator": cultivator},
		"force_power_gained",
		state.current_node_id,
		[source_id]
	))
	return _accepted(next)


static func _rest(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# 地图实例 id（L1R1N0）与目录模板 id 不同——休整门禁必须双查：
	# 实例 id 直命中，或实例的 template_id 指向休整模板。
	if not _is_rest_node(catalog, state.current_node_id) \
			and not _is_rest_node(catalog, str(state.current_node_template_id)):
		return _rejected(state, "not_rest_node")
	var mode := str(command.get("mode", "heal"))
	if mode == "heal":
		return _rest_heal(state)
	if mode == "upgrade_card":
		return _rest_upgrade(state, command)
	return _rest_removal(state, command, catalog, mode)


# R8.1 hard choice adds the upgrade option to the rest menu: it reuses the
# standalone upgrade accounting (which is free) and pays with the visit
# instead. Target validation happens before the visit is consumed.
static func _rest_upgrade(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return _rejected(state, "missing_card_key")
	if str(state.node_flags.get(_rest_mode_key(state.current_node_id), "")) == "true":
		return _rejected(state, "rest_mode_already_used")
	if _rest_visit_consumed(state):
		return _rejected(state, "rest_already_used")
	var consumed := _consume_rest_visit(state)
	return _upgrade_card(consumed, {"card_key": card_key})


static func _rest_heal(state: RunState) -> Dictionary:
	if _rest_visit_consumed(state):
		return _rejected(state, "rest_already_used")
	var flags := state.node_flags.duplicate(true)
	flags[_rest_visit_key(state.current_node_id)] = "used"
	# Bare-id marker rides along so _complete_node stays an idempotent no-op
	# when leaving (keeps the seeded event stream aligned with the baseline).
	flags[state.current_node_id] = "used"
	var next_health := mini(state.max_health, state.health + maxi(1, int(floor(float(state.max_health) * 0.30))))
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


# R8.1 rest removal is free but consumes the visit (opportunity cost instead
# of money). It never touches the black-market service counters and allows a
# single removal mode per node.
static func _rest_removal(state: RunState, command: Dictionary, catalog: Dictionary, mode: String) -> Dictionary:
	if not REST_REMOVAL_MODES.has(mode):
		return _rejected(state, "unsupported_rest_mode")
	if str(state.node_flags.get(_rest_mode_key(state.current_node_id), "")) == "true":
		return _rejected(state, "rest_mode_already_used")
	if _rest_visit_consumed(state):
		return _rejected(state, "rest_already_used")
	var consumed := _consume_rest_visit(state)
	match mode:
		"remove_card":
			return _rest_remove_card(state, command, catalog, consumed)
		"remove_imprint":
			return _rest_remove_imprint(state, command, catalog, consumed)
		"remove_curse":
			return _rest_remove_curse(state, command, catalog, consumed)
	return _rejected(state, "unsupported_rest_mode")


static func _consume_rest_visit(state: RunState) -> RunState:
	var flags := state.node_flags.duplicate(true)
	flags[_rest_visit_key(state.current_node_id)] = "used"
	flags[_rest_mode_key(state.current_node_id)] = "true"
	# Same bare-id marker contract as _rest_heal (see comment there).
	flags[state.current_node_id] = "used"
	return state.append_event(_event(
		state,
		"rest",
		{"node_flags": state.node_flags},
		{"node_flags": flags},
		"rest_visit_consumed",
		state.current_node_id,
		[]
	))


static func _rest_remove_card(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return _rejected(state, "gu_instance_unavailable")
	var blocked := _cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	var payload := _destroyed_gu_payload(state, instance_id)
	var next := consumed.append_event(_event(
		consumed,
		"rest",
		{},
		{"gu_instances": payload["instances"], "cave_aperture": payload["aperture"]},
		"rest_removed_gu",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return _accepted(next)


static func _rest_remove_imprint(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	if not catalog.get("relic_by_id", {}).has(relic_id):
		return _rejected(state, "unknown_relic")
	if not state.relic_ids.has(relic_id):
		return _rejected(state, "relic_not_owned")
	if str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule":
		return _rejected(state, "meta_rule_not_removable")
	var relics := state.relic_ids.duplicate()
	relics.erase(relic_id)
	var meta_rules := state.meta_rules.duplicate(true)
	meta_rules.erase(relic_id)
	var next := consumed.append_event(_event(
		consumed,
		"rest",
		{"relic_ids": state.relic_ids, "meta_rules": state.meta_rules},
		{"relic_ids": relics, "meta_rules": meta_rules},
		"rest_removed_imprint",
		state.current_node_id,
		[relic_id]
	))
	return _accepted(next)


static func _rest_remove_curse(state: RunState, command: Dictionary, catalog: Dictionary, consumed: RunState) -> Dictionary:
	var curse_id := str(command.get("curse_id", ""))
	if not catalog.get("curse_by_id", {}).has(curse_id):
		return _rejected(state, "unknown_curse")
	if CurseRegistryScript.layers_of(state, curse_id) <= 0:
		return _rejected(state, "curse_not_present")
	return _accepted(CurseRegistryScript.remove_curse(consumed, curse_id))


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
	var met := 0
	for condition in conditions.values():
		if condition:
			met += 1
	var risk := state.pursuit + state.injury + state.lifespan_debt
	# 升仙评价制（2026-08-28 裁定）：五项准备不再是一票否决的硬门槛，而是与
	# 风险共同折算四等评价。score = 达成条件数 - 风险罚分（risk<=1: 0，
	# risk<=3: 1，risk>3: 3）——5 特等 / 4 上等 / 2-3 中等 / 其余下等。
	# Boss 获胜仍是硬前置；冲仙本身不再因缺条件而失败。
	var penalty := 0
	if risk > 3:
		penalty = 3
	elif risk > 1:
		penalty = 1
	var score := met - penalty
	var outcome := "ascension_low"
	if score >= 5:
		outcome = "ascension_special"
	elif score == 4:
		outcome = "ascension_high"
	elif score >= 2:
		outcome = "ascension_medium"
	var ascension := state.ascension.duplicate(true)
	ascension["outcome"] = outcome
	ascension["conditions"] = conditions.duplicate(true)
	ascension["conditions_met"] = met
	ascension["risk"] = risk
	var next := state.append_event(_event(
		state,
		"attempt_ascension",
		{"ascension": state.ascension},
		{"ascension": ascension},
		"ascension_%s" % outcome,
		"ascension_window"
	))
	return {"state": next, "result": {"ok": true, "outcome": outcome, "conditions": conditions, "conditions_met": met, "risk": risk}}


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
	return EconomyRulesScript.notoriety(state)


static func roll_chance(state: RunState, pct: int, salt: String) -> bool:
	return EconomyRulesScript.roll_chance(state, pct, salt)


static func price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.price_for(catalog, state, base)


static func sell_price_for(catalog: Dictionary, state: RunState, base: int) -> int:
	return EconomyRulesScript.sell_price_for(catalog, state, base)


## 搜刮候选蛊方（预览与执行共用的唯一配方选择函数，2026-09-01）：
## scavenge_recipe 兼容单串与数组；过滤出「存在且尚未持有」的配方。
## 持有判定与图鉴门禁同源：global_codex_ids 命中 recipe id 或产出蛊 id。
static func scavenge_pending_recipes(state: RunState, catalog: Dictionary) -> Array[String]:
	var boss: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get("boss", {})
	var raw: Variant = boss.get("scavenge_recipe", "")
	var pending: Array[String] = []
	var recipe_ids: Array[String] = []
	if raw is Array:
		for value in raw:
			recipe_ids.append(str(value))
	elif not str(raw).is_empty():
		recipe_ids.append(str(raw))
	for recipe_id in recipe_ids:
		var recipe: Dictionary = catalog.get("refinement_by_id", {}).get(recipe_id, {})
		if recipe.is_empty():
			continue
		if not _codex_unlocks_recipe(state, recipe):
			pending.append(recipe_id)
	return pending


static func _scavenge(state: RunState, _command: Dictionary, catalog: Dictionary) -> Dictionary:
	if str(state.node_flags.get("boss_defeated", "")) != "true":
		return _rejected(state, "boss_undefeated")
	var boss: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get("boss", {})
	if str(boss.get("scavenge_recipe", "")).is_empty() and not (boss.get("scavenge_recipe", "") is Array):
		return _rejected(state, "no_scavenge_recipe")
	var pending := scavenge_pending_recipes(state, catalog)
	if pending.is_empty():
		return _rejected(state, "scavenge_already_done")
	var codex_after: Array[String] = state.global_codex_ids.duplicate()
	for recipe_id in pending:
		codex_after.append(recipe_id)
	var next := state.append_event(_event(
		state,
		"scavenge",
		{"global_codex_ids": state.global_codex_ids},
		{"global_codex_ids": codex_after},
		"scavenge_recipe_unlocked",
		state.current_node_id,
		pending
	))
	next.global_codex_ids = codex_after
	return _accepted(next)


static func _sell_material(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var material_id := str(command.get("material_id", ""))
	var materials: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	if not materials.has(material_id):
		return _rejected(state, "unknown_material")
	var owned := int(state.materials.get(material_id, 0))
	if owned <= 0:
		return _rejected(state, "no_material_to_sell")
	var base := int(materials[material_id].get("value", 1))
	var price := sell_price_for(catalog, state, base)
	var stone_after := state.stone + price * owned
	var remaining := state.materials.duplicate(true)
	remaining[material_id] = 0
	var next := state.append_event(_event(
		state,
		"sell_material",
		{"stone": state.stone, "materials": state.materials},
		{"stone": stone_after, "materials": remaining},
		"material_sold",
		state.current_node_id,
		[material_id]
	))
	next.stone = stone_after
	next.materials = remaining
	return _accepted(next)


static func _use_material(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# 材料第四通路「直接使用」：数据侧 loot_tables.materials.*.use 声明
	# health/essence 增量与文案；负向增量受死亡可预见红线约束（执行前预检）。
	var material_id := str(command.get("material_id", ""))
	var materials: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	if not materials.has(material_id):
		return _rejected(state, "unknown_material")
	var use: Dictionary = materials[material_id].get("use", {})
	if use.is_empty():
		return _rejected(state, "material_not_usable")
	var owned := int(state.materials.get(material_id, 0))
	if owned <= 0:
		return _rejected(state, "no_material_to_use")
	var health_delta := int(use.get("health", 0))
	var essence_delta := int(use.get("essence", 0))
	if health_delta < 0 and state.health + health_delta <= 0:
		return _rejected(state, "material_use_lethal")
	var health_after := mini(state.max_health, maxi(0, state.health + health_delta)) if health_delta != 0 else state.health
	var essence_after := mini(state.essence_capacity, maxi(0, state.essence + essence_delta)) if essence_delta != 0 else state.essence
	var remaining := state.materials.duplicate(true)
	remaining[material_id] = owned - 1
	var next := state.append_event(_event(
		state,
		"use_material",
		{"health": state.health, "essence": state.essence, "materials": state.materials},
		{"health": health_after, "essence": essence_after, "materials": remaining},
		"material_used",
		state.current_node_id,
		[material_id]
	))
	next.health = health_after
	next.essence = essence_after
	next.materials = remaining
	return _accepted(next)


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


static func _append_result_feed(result: Dictionary, feed: String) -> Dictionary:
	# Append semantics: feeds already on the result must survive alongside the
	# new entry instead of being overwritten.
	var inner: Dictionary = result.get("result", {})
	var feeds: Array = inner.get("feeds", [])
	feeds = feeds.duplicate()
	if not feeds.has(feed):
		feeds.append(feed)
	inner["feeds"] = feeds
	result["result"] = inner
	return result


static func _rejected(state: RunState, reason: String) -> Dictionary:
	return {"state": state, "result": {"ok": false, "reason": reason}}
