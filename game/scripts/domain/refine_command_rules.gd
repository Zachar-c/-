extends RefCounted

# W11 measure 3, atomic A4 (2026-09-10): the refine / gu / card / service
# command family moved out of resolver.gd. Extracted verbatim - behavior
# unchanged.
#
# Shared low-level helpers (_accepted/_rejected/_event) and cross-family
# helpers still owned by resolver (_finalize_if_dead / price_for /
# sell_price_for / _complete_node / _spend_lifespan, most of which graduate
# to social_command_rules in A5) are reached via the global Resolver class
# name. resolver.gd preloads this script (one-way), so there is no preload
# cycle. GuInstance / GuBalance / RunState are global class_name modules.

const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const ShopRulesScript = preload("res://scripts/domain/shop_rules.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const EconomyRulesScript = preload("res://scripts/domain/economy_rules.gd")
# 一转一突破（2026-09-15）：领域侧自查探访是否已消费（勿依赖 UI 禁用卡片）。
const RestRulesScript = preload("res://scripts/domain/rest_rules.gd")


static func _buy_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer := _offer(catalog, str(command.get("offer_id", "")), "buy")
	if offer.is_empty():
		return Resolver._rejected(state, "unknown_buy_offer")
	var cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	return _add_gu_transaction(state, str(offer["output_gu_id"]), cost, [], "caravan_bought_gu", [], catalog)


static func _sell_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var gu_id := str(command.get("gu_id", ""))
	if not state.refined_gu_ids.has(gu_id):
		return Resolver._rejected(state, "gu_not_refined")
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
	if gu.is_empty():
		return Resolver._rejected(state, "unknown_gu")
	# 2026-09-04 中央计价 + 2026-09-22 市价对齐：实例转数取 gu_value_by_rank，
	# 再叠 sell_price_for；预览 caravan.sell 走同一 EconomyRules.gu_sell_price。
	var instance_rank := maxi(int(gu.get("rank", 1)), GuInstance.max_refined_rank(state.gu_instances, gu_id))
	var value := EconomyRulesScript.gu_sell_price(catalog, state, gu, instance_rank)
	# 2026-09-03 修复：卖出必须同步销毁实例，否则下次 sync 会把卖掉的蛊
	# 复活（元石已到手、蛊又回来 → 无限刷钱）。
	var instances := state.gu_instances.duplicate(true)
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	GuInstance.consume_definition_instances(instances, stored, [gu_id])
	aperture["stored_gu_instance_ids"] = stored
	var next_gu := _without_gu(state.refined_gu_ids, [gu_id])
	var next_equipped := _without_gu(state.equipped_gu_ids, [gu_id])
	var next := state.append_event(Resolver._event(
		state,
		"sell_gu",
		{"stone": state.stone, "gu_ids": state.gu_ids, "refined_gu_ids": state.refined_gu_ids, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"stone": state.stone + value, "gu_ids": next_gu, "refined_gu_ids": next_gu, "equipped_gu_ids": next_equipped, "gu_instances": instances, "cave_aperture": aperture},
		"caravan_sold_gu",
		state.current_node_id,
		[gu_id]
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


static func _exchange_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var offer := _offer(catalog, str(command.get("offer_id", "")), "exchange")
	if offer.is_empty():
		return Resolver._rejected(state, "unknown_exchange_offer")
	var inputs: Array = offer.get("input_gu_ids", [])
	if not _has_all_gu(state.refined_gu_ids, inputs):
		return Resolver._rejected(state, "missing_exchange_input")
	var cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	return _add_gu_transaction(state, str(offer["output_gu_id"]), cost, inputs, "caravan_exchanged_gu", [], catalog)


static func _refine_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var recipe: Dictionary = catalog.get("refinement_by_id", {}).get(str(command.get("recipe_id", "")), {})
	if recipe.is_empty():
		return Resolver._rejected(state, "unknown_refinement_recipe")
	match str(recipe.get("kind", "combine")):
		"fixed", "advance":
			return _apply_fixed_recipe(state, command, catalog, recipe)
		"promotion":
			return _apply_promotion_recipe(state, command, catalog, recipe)
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
	var next := state.append_event(Resolver._event(
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
	# 与 fixed/advance 同门禁（2026-08-30 裁定）：蛊方图鉴未持有则拒绝，不烧材料。
	if not recipe_unlocked(state, recipe):
		return Resolver._rejected(state, "refinement_recipe_locked")
	var inputs: Array = recipe.get("input_gu_ids", [])
	var material_cost: Dictionary = recipe.get("materials", {})
	if inputs.size() + _recipe_material_pieces(material_cost) > SoulCapacityScript.craft_cap(state):
		return Resolver._rejected(state, "refinement_capacity_exceeded")
	if not _has_all_gu(state.refined_gu_ids, inputs):
		return Resolver._rejected(state, "missing_refinement_input")
	if not _has_all_materials(state, material_cost):
		return Resolver._rejected(state, "missing_refinement_material")
	var paid := _spend_materials(state, material_cost)
	# The result is determined from the run seed and immutable event position.
	# Commands never accept client supplied dice values.
	# 2026-08-28 设计修正：蛊方的「转数」只由产出蛊的转数表达（advance 链
	# 与产出 rank），与炼蛊成功率无直接关系。
	var roll := _refinement_roll(paid, str(recipe.get("id", "")))
	if roll > int(recipe.get("success_roll_max", 100)):
		# 失败摧毁输入：实例与 legacy 投影同步销毁，避免下次 sync 复活。
		var instances := paid.gu_instances.duplicate(true)
		var aperture := paid.cave_aperture.duplicate(true)
		var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
		GuInstance.consume_definition_instances(instances, stored, inputs)
		aperture["stored_gu_instance_ids"] = stored
		var destroyed := _without_gu(paid.refined_gu_ids, inputs)
		var unequipped := _without_gu(paid.equipped_gu_ids, inputs)
		var failed := paid.append_event(Resolver._event(
			paid,
			"refine_gu",
			{"gu_ids": paid.gu_ids, "refined_gu_ids": paid.refined_gu_ids, "gu_instances": paid.gu_instances, "cave_aperture": paid.cave_aperture},
			{"gu_ids": destroyed, "refined_gu_ids": destroyed, "equipped_gu_ids": unequipped, "gu_instances": instances, "cave_aperture": aperture},
			"refinement_failed_destroyed_inputs",
			paid.current_node_id,
			inputs
		))
		failed.sync_legacy_gu_projections()
		return Resolver._accepted(failed)
	return _add_gu_transaction(paid, str(recipe["output_gu_id"]), 0, inputs, "refinement_succeeded", ["recipe:%s" % str(recipe["id"])], catalog, int(recipe.get("output_rank", 0)))


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
		return Resolver._rejected(state, "refinement_recipe_locked")
	var is_advance := str(recipe.get("kind", "")) == "advance"
	var inputs: Array = recipe.get("input_gu_ids", [])
	if is_advance and (inputs.size() != 1 or str(recipe.get("output_gu_id", "")) != str(inputs[0])):
		return Resolver._rejected(state, "invalid_advance_recipe")
	var stone_cost := int(recipe.get("stone_cost", 0))
	if stone_cost > 0 and state.stone < stone_cost:
		return Resolver._rejected(state, "insufficient_stone")
	var material_cost: Dictionary = recipe.get("materials", {})
	# 缺料先于容量：玩家应先看到"缺什么"，而不是被并发上限挡住。
	var preselected := _selected_input_instance_ids(state, command, inputs)
	if preselected.is_empty() and not inputs.is_empty():
		return Resolver._rejected(state, "missing_refinement_input")
	if inputs.size() + _recipe_material_pieces(material_cost) > SoulCapacityScript.craft_cap(state):
		return Resolver._rejected(state, "refinement_capacity_exceeded")
	if not _has_all_materials(state, material_cost):
		return Resolver._rejected(state, "missing_refinement_material")
	# 转数门禁（2026-08-31）：input_min_rank 校验提前到烧材料前，拒绝不烧。
	var min_rank := int(recipe.get("input_min_rank", 0))
	if min_rank > 0:
		for instance_id_value in preselected:
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if int(instance.get("rank", 1)) < min_rank:
				return Resolver._rejected(state, "refinement_input_rank_insufficient")
	# 升阶封顶同属转数门禁，必须同样在烧材料之前判定：材料一旦扣除事件即写入，
	# 事后拒绝会留下"拒绝却仍消耗"的状态。
	if is_advance:
		var advance_rank := int(state.gu_instances.get(str(preselected[0]), {}).get("rank", 1))
		if mini(advance_rank + 1, 5) <= advance_rank:
			return Resolver._rejected(state, "advance_capped")
	var paid := _spend_materials(state, material_cost)
	var instances := paid.gu_instances.duplicate(true)
	var aperture := paid.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	for instance_id_value in preselected:
		var instance_id := str(instance_id_value)
		var consumed: Dictionary = instances[instance_id].duplicate(true)
		consumed["state"] = "consumed"
		instances[instance_id] = consumed
		stored.erase(instance_id)
	var output_instance_id := RunState.next_gu_instance_id(instances)
	var output_instance := {
		"instance_id": output_instance_id,
		"definition_id": str(recipe["output_gu_id"]),
		"state": "refined",
	}
	if is_advance:
		# 同名升阶：本体进阶不换名，阶数 +1（封顶五转）；封顶可达性已在
		# 烧材料前判定，这里只推进阶数。
		output_instance["rank"] = mini(int(instances[str(preselected[0])].get("rank", 1)) + 1, 5)
	else:
		# 定向合炼：产出转数 = 配方 output_rank（缺省回退产出蛊本体定义）。
		var fallback_rank := int(catalog.get("gu_by_id", {}).get(str(recipe["output_gu_id"]), {}).get("rank", 1))
		output_instance["rank"] = clampi(int(recipe.get("output_rank", fallback_rank)), 1, 5)
	instances[output_instance_id] = output_instance
	stored.append(output_instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var next := paid.append_event(Resolver._event(
		paid,
		"refine_gu",
		{"stone": paid.stone, "gu_instances": paid.gu_instances, "cave_aperture": paid.cave_aperture},
		{"stone": paid.stone - stone_cost, "gu_instances": instances, "cave_aperture": aperture},
		"refinement_succeeded",
		paid.current_node_id,
		preselected + [output_instance_id, "recipe:%s" % str(recipe["id"])]
	))
	next.sync_legacy_gu_projections()
	if stone_cost > 0:
		next.stone = paid.stone - stone_cost
	return Resolver._accepted(next)


## Stage 1（2026-09-17）：炼化 —— 把一只野生蛊（state=wild）压成本人的蛊（state=refined）。
##
## 原文依据 `docs/superpowers/reports/2026-09-17-lianhua-corpus-research.md`：
## 炼化是「以真元抹去蛊虫意志」的消耗战，**唯一被点名的消耗物是真元**
## （精血/寿元 × 炼化 同句命中 0 次；魂魄只作"底蕴"上限，不是付款项）。
## 量级锚点（行 1866）：祭炼 1/12 ≈ 3 成真元；一转普通蛊 5–8 元石，珍稀蛊 11–16 元石
## ⇒ 转数越高越贵，取 `4 + 2 × (rank - 1)`。
## 本切片**不做**进度条：原文的"持续祭炼 + 中断即前功尽弃"需要新状态字段与离开节点
## 清进度，超出切片范围；改为一次性扣真元 + 真元不足即拒，代价在文案里明说。
static func _attune_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var requested: Array = command.get("input_instance_ids", [])
	if requested.size() != 1:
		return Resolver._rejected(state, "attune_target_missing")
	var instance_id := str(requested[0])
	var instance: Dictionary = state.gu_instances.get(instance_id, {})
	if instance.is_empty() or str(instance.get("state", "")) != "wild":
		return Resolver._rejected(state, "attune_target_not_wild")
	var definition_id := str(instance.get("definition_id", ""))
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	var rank := clampi(int(definition.get("rank", 1)), 1, 5)
	var cost := 4 + 2 * (rank - 1)
	# 门禁先于扣费：真元不足时一只真元都不扣，也不改动实例状态。
	if int(state.essence) < cost:
		return Resolver._rejected(state, "insufficient_essence")
	var instances: Dictionary = state.gu_instances.duplicate(true)
	var attuned: Dictionary = (instances[instance_id] as Dictionary).duplicate(true)
	attuned["state"] = "refined"
	instances[instance_id] = attuned
	# 本命蛊 = 第一只炼化的蛊（原文定义句）。只落事件，不给槽位、不给加成
	# —— Stage 0 裁定 natal_gu = remove（禁止后置任意核心蛊槽）。
	var is_first := true
	for event_value in state.event_log:
		if str((event_value as Dictionary).get("action", "")) == "attune_gu":
			is_first = false
			break
	var next := state.append_event(Resolver._event(
		state,
		"attune_gu",
		{"essence": state.essence, "gu_instances": state.gu_instances},
		{"essence": state.essence - cost, "gu_instances": instances},
		"first_gu_attuned" if is_first else "gu_attuned",
		state.current_node_id,
		[instance_id, definition_id]
	))
	next.essence = state.essence - cost
	next.gu_instances = instances
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


## Q8-G Batch 1-A：promotion = 跨 definition 的定向晋升（Rank N → Rank N+1 的**另一个**蛊）。
## 与 advance 的语义边界（Gate 7）：
##   advance   → 同 definition，实例 rank +1
##   promotion → 消耗输入实例，产出**不同** definition，rank = 输入 rank + 1
## 数据层由 content_catalog 静态锁死 `output_gu_id != input_gu_ids[0]`（Gate 1）。
static func _apply_promotion_recipe(state: RunState, command: Dictionary, catalog: Dictionary, recipe: Dictionary) -> Dictionary:
	var inputs: Array = recipe.get("input_gu_ids", [])
	if inputs.size() != 1:
		return Resolver._rejected(state, "invalid_promotion_recipe")
	var input_gu_id := str(inputs[0])
	var output_gu_id := str(recipe.get("output_gu_id", ""))
	# 语义隔离硬门禁：output 必须是另一个 definition，否则这就是 advance。
	if output_gu_id.is_empty() or output_gu_id == input_gu_id:
		return Resolver._rejected(state, "invalid_promotion_recipe")
	if not recipe_unlocked(state, recipe):
		return Resolver._rejected(state, "refinement_recipe_locked")
	var stone_cost := int(recipe.get("stone_cost", 0))
	if stone_cost > 0 and state.stone < stone_cost:
		return Resolver._rejected(state, "insufficient_stone")
	var material_cost: Dictionary = recipe.get("materials", {})
	# 与 fixed 同序：定位输入 → 容量 → 缺料，全部拒绝都发生在烧材料之前。
	var preselected := _selected_input_instance_ids(state, command, inputs)
	if preselected.is_empty():
		return Resolver._rejected(state, "missing_refinement_input")
	if inputs.size() + _recipe_material_pieces(material_cost) > SoulCapacityScript.craft_cap(state):
		return Resolver._rejected(state, "refinement_capacity_exceeded")
	if not _has_all_materials(state, material_cost):
		return Resolver._rejected(state, "missing_refinement_material")
	# 转数门禁同样先于扣料：输入 rank 必须等于配方声明的 input_min_rank（缺省 1），
	# 且输入 rank 不能已是 5（+1 后无处可去）。事后拒绝会留下"拒绝却仍消耗"。
	var input_instance_id := str(preselected[0])
	var input_rank := int(state.gu_instances.get(input_instance_id, {}).get("rank", 1))
	var min_rank := int(recipe.get("input_min_rank", 1))
	if input_rank < min_rank:
		return Resolver._rejected(state, "refinement_input_rank_insufficient")
	if input_rank >= 5:
		return Resolver._rejected(state, "promotion_capped")
	var paid := _spend_materials(state, material_cost)
	# 产出的定义转数必须与"输入 rank + 1"一致，否则链会脱轨。
	var output_rank := input_rank + 1
	# 复用 _add_gu_transaction：它经 GuInstance.transaction_ledger 统一落
	# gu_instances + cave_aperture（含显式 output_rank），并消费输入实例。
	# consume_instance_ids 传**选中那只**：promotion 的转数门禁是按它算的，
	# 若只传 definition 会让 ledger 退回"首个同名实例"，出现"校验 A 消耗 B"。
	return _add_gu_transaction(paid, output_gu_id, stone_cost, [input_gu_id], "promotion_succeeded", ["recipe:%s" % str(recipe["id"])], catalog, output_rank, [input_instance_id])


static func _selected_input_instance_ids(state: RunState, command: Dictionary, inputs: Array) -> Array[String]:
	return ShopRulesScript.selected_input_instance_ids(state, command, inputs)


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
				return Resolver._rejected(state, "missing_refinement_input")
			if not selected.has(instance_id):
				selected.append(instance_id)
	if selected.size() < min_inputs:
		return Resolver._rejected(state, "missing_refinement_input")
	if selected.size() > SoulCapacityScript.craft_cap(state):
		return Resolver._rejected(state, "refinement_capacity_exceeded")
	var outcomes: Array = recipe.get("outcomes", [])
	if outcomes.is_empty():
		return Resolver._rejected(state, "unknown_refinement_recipe")
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
	var next := state.append_event(Resolver._event(
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
	return Resolver._finalize_if_dead(next)


## 转数上限（境内最高五转）。与 `aptitude.json.cultivation_factor` 的 1–5 档、
## `pacing.layers[N].enemy_rank_max` 的 1..5 梯度同源。
const MAX_CULTIVATION := 5
# 境界中文名。领域层是本表的唯一来源（转数语义归本模块，且本模块已持有
# 「元石不足」等中文拒绝文案）；表现层经 `cultivation_label` 读取，
# 不允许反向依赖表现层的 DisplayText。
const CULTIVATION_LABELS := {
	1: "一转", 2: "二转", 3: "三转", 4: "四转", 5: "五转",
}
const CULTIVATE_COST_BALANCE_KEYS := {
	2: "cultivate_rank_two_stone_cost",
	3: "cultivate_rank_three_stone_cost",
	4: "cultivate_rank_four_stone_cost",
	5: "cultivate_rank_five_stone_cost",
}


## 突破至 target_rank 的元石成本（0 = 该档未配置/越界）。快照、预览与本模块共用。
static func cultivate_stone_cost(catalog: Dictionary, target_rank: int) -> int:
	var key := str(CULTIVATE_COST_BALANCE_KEYS.get(target_rank, ""))
	if key.is_empty():
		return 0
	return int((catalog.get("balance", {}) as Dictionary).get(key, 0))


## 转数 → 中文境界名。越界回退为「N 转」。
static func cultivation_label(rank: int) -> String:
	var value := maxi(1, int(rank))
	return str(CULTIVATION_LABELS.get(value, "%d 转" % value))


## 一转一突破（2026-09-15 用户裁定：聚焦剑道、打造局内成长空间）。
##
## 背景：`aptitude.json.cultivation_factor = {1:1, 2:3, 3:9, 4:27, 5:81}` 与
## `pacing.layers[N].enemy_rank_max = 1..5` **早已把 1→5 的成长曲线设计完**，
## 但领域只实现了硬编码的二转（且 `>= 2` 直接拒绝）⇒ 转数永久封顶 2 转。
## 后果：门禁 `can_activate(cultivation >= gu_rank)` 让全库 52% 的蛊（rank ≥3）
## **永远无法催动**；剑道 40 只蛊里 20 只是死内容，22 条杀招中配方含 4–5 转蛊的
## 全部不可达，promotion 链 1→5 也永远走不完。
##
## 现改为逐档突破（不可跳档、不可超上限），每层关底后开放下一档。
## 目标档缺省 = 当前转数 + 1，由领域自行判定，UI 不需要知道档位公式。
static func _breakthrough(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# E3a：修炼族并入休息类三选一——rest/refinement/cultivation 节点均可冲阶
	# （原 cultivation_spring 字面闸门放宽为休息类；seclusion 等仍拒绝）。
	if not Resolver._is_rest_class_node(catalog, state.current_node_id) \
			and not Resolver._is_rest_class_node(catalog, str(state.current_node_template_id)):
		return Resolver._rejected(state, "not_cultivation_window")
	# 一次探访只取一份收益（领域自查）：否则四档突破可在一个休整点连跳。
	if RestRulesScript.rest_visit_consumed(state):
		return Resolver._rejected(state, "rest_visit_already_used")
	var current := maxi(1, int(state.cultivation))
	if current >= MAX_CULTIVATION:
		return Resolver._rejected(state, "cultivation_already_max")
	var target := int(command.get("target_rank", current + 1))
	if target < 2 or target > MAX_CULTIVATION:
		return Resolver._rejected(state, "cultivation_rank_out_of_range")
	if target <= current:
		return Resolver._rejected(state, "cultivation_already_rank_two" if current >= 2 else "cultivation_already_rank_one")
	# 不可跳档：一转一突破，保证成长是四拍而不是一次跃升。
	if target != current + 1:
		return Resolver._rejected(state, "cultivation_step_too_far")
	var cost := cultivate_stone_cost(catalog, target)
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var aperture := state.cave_aperture.duplicate(true)
	aperture["essence_max"] = maxi(int(aperture.get("essence_max", 0)),
			EssenceCapacityScript.essence_max_for(state, catalog, target))
	# 玩家等级曲线（2026-08-29 设计点）：转数只抬真元总量上限，不加 HP/攻击。
	# 2026-08-28 验收批：上限值从公式取（aptitude.json tier 表唯一真值），
	# 不再硬编码 3 + 2。现值随目标档走（×3 一档）。
	var next_capacity := maxi(state.essence_capacity, EssenceCapacityScript.essence_max_for(state, catalog, target))
	var next := state.append_event(Resolver._event(
		state,
		"breakthrough",
		{"cultivation": state.cultivation, "stone": state.stone, "essence": state.essence, "cave_aperture": state.cave_aperture},
		{"cultivation": target, "stone": state.stone - cost, "essence": state.essence_capacity, "essence_capacity": next_capacity, "cave_aperture": aperture},
		"rank_%d_breakthrough" % target,
		state.current_node_id
	))
	return Resolver._accepted(next)


## 历史命令名（`cultivate_rank_two`）。保留为薄包装：旧存档、旧测试与
## 既有领域命令面继续可用；行为等价于 `_breakthrough` 指定目标 2 转。
static func _cultivate_rank_two(state: RunState, catalog: Dictionary) -> Dictionary:
	return _breakthrough(state, {"target_rank": 2}, catalog)


static func _disable_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return Resolver._rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["disabled_for_run"] = true
	overrides[card_key] = override
	var next := state.append_event(Resolver._event(
		state,
		"disable_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_disabled",
		state.current_node_id,
		[card_key]
	))
	return Resolver._accepted(next)


static func _upgrade_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return Resolver._rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["upgrade_level"] = int(override.get("upgrade_level", 0)) + 1
	overrides[card_key] = override
	var next := state.append_event(Resolver._event(
		state,
		"upgrade_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_upgraded",
		state.current_node_id,
		[card_key]
	))
	return Resolver._accepted(next)


static func _copy_card(state: RunState, command: Dictionary) -> Dictionary:
	var card_key := str(command.get("card_key", ""))
	if card_key.is_empty():
		return Resolver._rejected(state, "missing_card_key")
	var overrides := state.gu_card_overrides.duplicate(true)
	var override: Dictionary = overrides.get(card_key, {}).duplicate(true)
	override["extra_copies"] = int(override.get("extra_copies", 0)) + 1
	overrides[card_key] = override
	var next := state.append_event(Resolver._event(
		state,
		"copy_card",
		{"gu_card_overrides": state.gu_card_overrides},
		{"gu_card_overrides": overrides},
		"battle_card_copied",
		state.current_node_id,
		[card_key]
	))
	return Resolver._accepted(next)


static func _destroy_gu(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return Resolver._rejected(state, "gu_instance_unavailable")
	var blocked := _cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	var payload := _destroyed_gu_payload(state, instance_id, LootRules.destroy_gu(existing, str(command.get("method", "")), str(command.get("means", "")), catalog).get("extracted", {}))
	var next := state.append_event(Resolver._event(
		state,
		"destroy_gu",
		{"gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture, "materials": state.materials},
		{"gu_instances": payload["instances"], "cave_aperture": payload["aperture"], "materials": payload["materials"]},
		"gu_destroyed",
		state.current_node_id,
		[instance_id]
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


# Section 16.15: a can_direct_drop=false gu refuses every direct destroy path.
# The refusal still appends a backlash consequence (one gu_erosion layer) so it
# is never silent; the returned rejection carries the curse-gained state.
static func _cursed_drop_block(state: RunState, catalog: Dictionary, definition_id: String) -> Dictionary:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	if bool(definition.get("can_direct_drop", true)):
		return {}
	return Resolver._rejected(
		CurseRegistryScript.gain_curse(state, Resolver.FORCED_DROP_CURSE_ID, "forced_drop"),
		"cursed_gu_not_directly_droppable"
	)


static func _destroyed_gu_payload(state: RunState, instance_id: String, extracted: Dictionary = {}) -> Dictionary:
	var instances := state.gu_instances.duplicate(true)
	instances[instance_id] = instances.get(instance_id, {}).duplicate(true)
	instances[instance_id]["state"] = "dead"
	var aperture := state.cave_aperture.duplicate(true)
	var stored: Array = aperture.get("stored_gu_instance_ids", []).duplicate()
	stored.erase(instance_id)
	aperture["stored_gu_instance_ids"] = stored
	var materials := state.materials.duplicate(true)
	for material_id in extracted:
		materials[str(material_id)] = int(materials.get(str(material_id), 0)) + int(extracted[material_id])
	return {"instances": instances, "aperture": aperture, "materials": materials}


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
	var key := EconomyRulesScript.SERVICE_USE_FLAG_PREFIX + service_id
	flags[key] = str(int(str(flags.get(key, "0"))) + 1)


static func _remove_card_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var instance_id := str(command.get("instance_id", ""))
	var existing: Dictionary = state.gu_instances.get(instance_id, {})
	if existing.is_empty() or str(existing.get("state", "")) == "dead":
		return Resolver._rejected(state, "gu_instance_unavailable")
	var blocked := _cursed_drop_block(state, catalog, str(existing.get("definition_id", "")))
	if not blocked.is_empty():
		return blocked
	if service_use_count(state, "remove_card") >= service_limit(catalog, "remove_card"):
		return Resolver._rejected(state, "service_limit_exceeded")
	var cost := service_price_for(catalog, state, "remove_card", int(catalog.get("balance", {}).get("remove_card_cost", 120)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	_bump_service_flag(flags, "remove_card")
	var payload := _destroyed_gu_payload(state, instance_id)
	var next := state.append_event(Resolver._event(
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
	return Resolver._accepted(next)


# R4.8 contracts-tier meta rules are rule changers, not droppable items, so
# they can never be removed through this service.
static func _remove_imprint_command(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var relic_id := str(command.get("relic_id", ""))
	if not catalog.get("relic_by_id", {}).has(relic_id):
		return Resolver._rejected(state, "unknown_relic")
	if not state.relic_ids.has(relic_id):
		return Resolver._rejected(state, "relic_not_owned")
	if str(catalog["relic_by_id"][relic_id].get("grade", "")) == "meta_rule":
		return Resolver._rejected(state, "meta_rule_not_removable")
	if service_use_count(state, "remove_imprint") >= service_limit(catalog, "remove_imprint"):
		return Resolver._rejected(state, "service_limit_exceeded")
	var cost := service_price_for(catalog, state, "remove_imprint", int(catalog.get("balance", {}).get("remove_imprint_cost", 150)))
	if state.stone < cost:
		return Resolver._rejected(state, "insufficient_stone")
	var flags := state.node_flags.duplicate(true)
	_bump_service_flag(flags, "remove_imprint")
	var relics := state.relic_ids.duplicate()
	relics.erase(relic_id)
	var meta_rules := state.meta_rules.duplicate(true)
	meta_rules.erase(relic_id)
	var next := state.append_event(Resolver._event(
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
	return Resolver._accepted(next)


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
	var next := state.append_event(Resolver._event(
		state,
		"settle_node_feeding",
		{"materials": state.materials, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"materials": materials, "gu_instances": instances, "cave_aperture": aperture},
		reason,
		state.current_node_id,
		stored
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


static func _settle_feeding(state: RunState, catalog: Dictionary) -> Dictionary:
	if state.current_node_id != "stage_one_ledger":
		return Resolver._rejected(state, "not_stage_ledger")
	var cost := state.estimate_feeding(catalog)
	if state.stone < cost:
		return Resolver._rejected(state, "feeding_shortfall")
	var flags := state.node_flags.duplicate(true)
	var already_paid := str(flags.get("stage_one_ledger", "")) == "paid"
	flags["stage_one_ledger"] = "paid"
	var next := state.append_event(Resolver._event(
		state,
		"settle_feeding",
		{"stone": state.stone, "node_flags": state.node_flags},
		{"stone": state.stone - cost, "node_flags": flags},
		"stage_one_feeding_paid",
		state.current_node_id
	))
	if not already_paid:
		next = Resolver._grant_lifespan_milestone(next, catalog, "stage_one_ledger")
	return Resolver._accepted(next)



static func _offer(catalog: Dictionary, offer_id: String, kind: String) -> Dictionary:
	var offer: Dictionary = catalog.get("caravan_offer_by_id", {}).get(offer_id, {})
	if str(offer.get("kind", "")) != kind:
		return {}
	return offer


static func _add_gu_transaction(state: RunState, output_gu_id: String, stone_cost: int, inputs: Array, reason: String, extra_targets: Array = [], catalog: Dictionary = {}, output_rank: int = 0, consume_instance_ids: Array = []) -> Dictionary:
	# 2026-09-03 修复：实例记账见 GuInstance.transaction_ledger（产出蛊必须
	# 落 gu_instances + 洞天，否则 V1 战斗看不见且会被下次 sync 抹掉）。
	var ledger := GuInstance.transaction_ledger(state.gu_instances, state.cave_aperture, output_gu_id, catalog, inputs, output_rank, consume_instance_ids)
	# 2026-09-05 切片护栏：未知产出定义在原石/原蛊/事件落地之前直接拒绝，避免
	# 下游 sync_legacy_gu_projections 把一个不存在的 gu_id 复活进 legacy 投影。
	if not str(ledger.get("error", "")).is_empty():
		return Resolver._rejected(state, str(ledger["error"]))
	var next_gu := _without_gu(state.refined_gu_ids, inputs)
	next_gu.append(output_gu_id)
	var next_equipped := _without_gu(state.equipped_gu_ids, inputs)
	var next := state.append_event(Resolver._event(
		state,
		"gu_transaction",
		{"stone": state.stone, "gu_ids": state.gu_ids, "refined_gu_ids": state.refined_gu_ids, "gu_instances": state.gu_instances, "cave_aperture": state.cave_aperture},
		{"stone": state.stone - stone_cost, "gu_ids": next_gu, "refined_gu_ids": next_gu, "equipped_gu_ids": next_equipped, "gu_instances": ledger["instances"], "cave_aperture": ledger["aperture"]},
		reason,
		state.current_node_id,
		inputs + [output_gu_id] + extra_targets
	))
	next.sync_legacy_gu_projections()
	return Resolver._accepted(next)


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
		return Resolver._rejected(state, "boss_undefeated")
	var boss: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get("boss", {})
	if str(boss.get("scavenge_recipe", "")).is_empty() and not (boss.get("scavenge_recipe", "") is Array):
		return Resolver._rejected(state, "no_scavenge_recipe")
	var pending := scavenge_pending_recipes(state, catalog)
	if pending.is_empty():
		return Resolver._rejected(state, "scavenge_already_done")
	var codex_after: Array[String] = state.global_codex_ids.duplicate()
	for recipe_id in pending:
		codex_after.append(recipe_id)
	var next := state.append_event(Resolver._event(
		state,
		"scavenge",
		{"global_codex_ids": state.global_codex_ids},
		{"global_codex_ids": codex_after},
		"scavenge_recipe_unlocked",
		state.current_node_id,
		pending
	))
	next.global_codex_ids = codex_after
	return Resolver._accepted(next)


static func _sell_material(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var material_id := str(command.get("material_id", ""))
	var materials: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	if not materials.has(material_id):
		return Resolver._rejected(state, "unknown_material")
	var owned := int(state.materials.get(material_id, 0))
	if owned <= 0:
		return Resolver._rejected(state, "no_material_to_sell")
	var base := int(materials[material_id].get("value", 1))
	var price := EconomyRulesScript.material_sell_price(catalog, state, material_id)
	if price <= 0:
		price = Resolver.sell_price_for(catalog, state, base)
	var stone_after := state.stone + price * owned
	var remaining := state.materials.duplicate(true)
	remaining[material_id] = 0
	var next := state.append_event(Resolver._event(
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
	return Resolver._accepted(next)


static func _use_material(state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# 材料第四通路「直接使用」：数据侧 loot_tables.materials.*.use 声明
	# health/essence 增量与文案；负向增量受死亡可预见红线约束（执行前预检）。
	var material_id := str(command.get("material_id", ""))
	var materials: Dictionary = catalog.get("loot_tables", {}).get("materials", {})
	if not materials.has(material_id):
		return Resolver._rejected(state, "unknown_material")
	var use: Dictionary = materials[material_id].get("use", {})
	if use.is_empty():
		return Resolver._rejected(state, "material_not_usable")
	var owned := int(state.materials.get(material_id, 0))
	if owned <= 0:
		return Resolver._rejected(state, "no_material_to_use")
	var health_delta := int(use.get("health", 0))
	var essence_delta := int(use.get("essence", 0))
	if health_delta < 0 and state.health + health_delta <= 0:
		return Resolver._rejected(state, "material_use_lethal")
	var health_after := mini(state.max_health, maxi(0, state.health + health_delta)) if health_delta != 0 else state.health
	var essence_after := mini(state.essence_capacity, maxi(0, state.essence + essence_delta)) if essence_delta != 0 else state.essence
	var remaining := state.materials.duplicate(true)
	remaining[material_id] = owned - 1
	var next := state.append_event(Resolver._event(
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
	return Resolver._accepted(next)

