extends GutTest


# 十转杀蛊（测试专用）最终章 E2E（2026-08-31 用户验收）：
# 月光道开局 → 直装十转杀蛊（0 真元、1 行动值、999 点群体伤害、不乘转数因子）→
# L1→L5 逐大层击败关底 Boss（一发清场）→ 每大层 Boss 只记录通关旗标，
# 不直接改修为或真元 → 第五大层瘴脉之主（miasma_vein_lord）
# 落全局 boss_defeated 旗标 → 升仙窗解锁 → attempt_ascension 出飞升结局评价。
#
# 十转杀蛊仅通过测试夹具入袋，不进任何随机池（§16.4 未解锁内容不入池）；
# 名字带"杀"是用户术语，显示名"十转杀蛊"与目录 id 无转数语义耦合
# （rank 字段 10 仅作标注，factor 一律 clamp 到 1..5）。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const SLAY_GU_ID := "test_slay_gu"
const BOSS_KINDS := {
	1: "crag_serpent_matriarch",
	2: "marrow_gu_adept",
	3: "thunder_crown_sovereign",
	4: "blood_vein_bishop",
	5: "miasma_vein_lord",
}


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func _route_node(id: String, template_id: String, type: String, layer: int, row: int, next_ids: Array, extra: Dictionary = {}) -> Dictionary:
	var node := {
		"id": id,
		"template_id": template_id,
		"type": type,
		"layer": layer,
		"row": row,
		"next_ids": next_ids,
	}
	for key in extra:
		node[key] = extra[key]
	return node


func _build_route() -> Array[Dictionary]:
	# 线性实例链：每大层一行入口 + 一行关底 Boss；第五大层关底后接升仙窗。
	var route: Array[Dictionary] = [
		_route_node("L1R0N0", "beast_swarm_pass", "combat", 1, 0, ["L1R1N0"],
				{"start": true, "enemy_kind": "ridge_hound", "choices": ["fight", "retreat"]}),
	]
	for layer in range(1, 6):
		var entrance_next: Array = []
		var boss_id := "L%dR1N0" % layer
		var boss_extra := {
			"enemy_kind": str(BOSS_KINDS[layer]),
			"layer_boss": layer,
			"choices": ["fight"],
		}
		var next_layer := layer + 1
		entrance_next = ["L%dR1N0" % layer]
		if next_layer <= 5:
			boss_extra["next_ids"] = ["L%dR0N0" % next_layer]
		else:
			boss_extra["next_ids"] = ["ascension_window"]
		if layer == 1:
			route[0]["next_ids"] = ["L1R1N0"]
		else:
			var entrance := _route_node("L%dR0N0" % layer, "toxic_mountain_path", "hazard",
					layer, 0, entrance_next, {"choices": ["scout", "leave"]})
			route.append(entrance)
		var template := "layer_boss_stand_%d" % layer if layer < 5 else "final_boss_stand"
		route.append(_route_node(boss_id, template, "combat", layer, 1, [], boss_extra))
	route.append(_route_node("ascension_window", "ascension_window", "ascension", 5, 2, [],
			{"choices": ["attempt_ascension", "prepare", "retreat"]}))
	# 补齐 next_ids（构造函数里 boss_extra 的 next_ids 已带，这里兜底校验链完整）
	return route


func _start_run_with_slay_gu() -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(4242, "moonlight", ["enemy_vitality_trial"])
	controller.route = _build_route()
	# 测试夹具：十转杀蛊直装入袋（不走随机池、不走商店）。
	var state := controller.state
	state.gu_instances["gu_slay_001"] = {
		"instance_id": "gu_slay_001",
		"definition_id": SLAY_GU_ID,
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append("gu_slay_001")
	state.refined_gu_ids.append(SLAY_GU_ID)
	state.equipped_gu_ids.append(SLAY_GU_ID)
	state.sync_legacy_gu_projections()
	return controller


func _slay_slot(battle: Dictionary) -> Dictionary:
	# V1 契约：战斗蛊在 gu_slots（不再有 hand 卡蓝谱）。
	for slot_value in battle.get("gu_slots", []):
		var slot: Dictionary = slot_value
		if str(slot.get("definition_id", "")) == SLAY_GU_ID:
			return slot
	return {}


func _fight_to_victory_with_slay(controller: RunController, max_steps: int = 40) -> void:
	# V1：每回合优先施放十转杀蛊（v1_effect 999 伤害一发清场）；本回合已用
	# 或念头耗尽则收势换回合。40 步内必然清完单场 Boss。
	var steps := 0
	while controller.current_view_name() == "Battle" and steps < max_steps:
		steps += 1
		var battle: Dictionary = controller.current_battle
		var slot := _slay_slot(battle)
		if not slot.is_empty() and not bool(slot.get("used_this_turn", false)) and not bool(slot.get("is_sealed", false)):
			var res := controller.submit_command({
				"type": "use_gu",
				"instance_id": str(slot.get("instance_id", "")),
				"state_version": controller.state.event_log.size(),
			})
			if bool(res.get("accepted", false)):
				continue
		controller.submit_command({
			"type": "end_turn",
			"state_version": controller.state.event_log.size(),
		})


func test_slay_gu_catalog_entry_is_test_only() -> void:
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(SLAY_GU_ID, {})
	assert_false(gu.is_empty(), "十转杀蛊已入目录")
	assert_eq(int(gu.get("essence_cost", -1)), 0, "催动 0 真元")
	var effects: Array = gu.get("combat_effects", [])
	assert_eq(effects.size(), 1)
	assert_eq(str((effects[0] as Dictionary).get("kind", "")), "aoe_strike")
	assert_eq(int((effects[0] as Dictionary).get("amount", 0)), 999, "999 点群体伤害")
	# B2 卡层退役：杀蛊的 V1 战斗效果由 v1_effect 表达（蓝谱卡已随卡层删除）。
	var v1: Dictionary = gu.get("v1_effect", {})
	assert_eq(str(v1.get("kind", "")), "strike")
	assert_eq(int(v1.get("amount", 0)), 999, "V1 效果 999 点伤害")
	assert_eq(DisplayText.gu(SLAY_GU_ID), "十转杀蛊", "显示名十转杀蛊")
	# 不进任何掉落/商店池：仅按 id 直查命中
	for table_value in catalog.get("loot_tables", {}).values():
		var table: Dictionary = table_value
		for bucket_value in table.get("by_rarity", {}).values():
			assert_false(SLAY_GU_ID in (bucket_value as Array), "杀蛊不进稀有度桶")


func test_slay_gu_one_shots_full_boss_ladder_to_ascension() -> void:
	var controller := _start_run_with_slay_gu()
	assert_eq(controller.current_view_name(), "Map", "开局进 Map")
	assert_eq(int(controller.state.cultivation), 1, "开局一转")
	var initial_cultivation := int(controller.state.cultivation)
	var initial_capacity := int(controller.state.essence_capacity)

	for layer in range(1, 6):
		# ---- 进入本层 Boss 台（第 1 层先过入口战斗节点）----
		if layer == 1:
			controller.submit_command({"type": "travel", "node_id": "L1R0N0"})
			assert_eq(controller.current_view_name(), "Battle", "入口战斗自动开战")
			_fight_to_victory_with_slay(controller)
			assert_true(controller.current_view_name() in ["Reward", "Encounter"],
					"L1 入口战胜利（实际=%s）" % controller.current_view_name())
			controller.submit_command({"type": "leave_encounter"})
			assert_eq(controller.current_view_name(), "Map")
		else:
			var entrance := controller.submit_command({"type": "travel", "node_id": "L%dR0N0" % layer})
			assert_ne(str((entrance.get("result", entrance) as Dictionary).get("reason", "")),
					"unreachable_route_node", "第 %d 层入口可达" % layer)
			controller.submit_command({"type": "leave_encounter"})
			assert_eq(controller.current_view_name(), "Map")

		var travel := controller.submit_command({"type": "travel", "node_id": "L%dR1N0" % layer})
		assert_eq(controller.current_view_name(), "Battle", "第 %d 层 Boss 台自动开战" % layer)
		# 流程夹具：Boss 每回合意图伤害累积，杀蛊上牌前先保证不被磨死。
		controller.state.health = 80
		controller.state.max_health = 80
		controller.state.cultivator["health"] = 80
		_fight_to_victory_with_slay(controller)
		assert_true(controller.current_view_name() in ["Reward", "Encounter"],
				"第 %d 层 Boss 被十转杀蛊一发清场（实际=%s）" % [layer, controller.current_view_name()])
		assert_eq(str(controller.state.node_flags.get("boss_defeated_L%d" % layer, "")), "true",
				"boss_defeated_L%d 旗标落账" % layer)
		assert_eq(int(controller.state.cultivation), initial_cultivation,
				"击败第 %d 层 Boss 不直接改变修为" % layer)
		assert_eq(int(controller.state.essence_capacity), initial_capacity,
				"击败第 %d 层 Boss 不直接改变真元上限" % layer)
		controller.submit_command({"type": "leave_encounter"})
		assert_eq(controller.current_view_name(), "Map")

	# ---- 第五大层 Boss（瘴脉之主）落全局旗标 → 升仙窗解锁 ----
	assert_eq(str(controller.state.node_flags.get("boss_defeated", "")), "true",
			"全局 boss_defeated 旗标（miasma_vein_lord）")
	assert_eq(int(controller.state.cultivation), initial_cultivation, "五层通关旗标不替代修为成长")

	var gate := controller.submit_command({"type": "travel", "node_id": "ascension_window"})
	assert_ne(str((gate.get("result", gate) as Dictionary).get("reason", "")), "boss_undefeated",
			"升仙窗门禁已开")
	var ascend := controller.submit_command({"type": "attempt_ascension", "choice": "now"})
	var ascend_result := (ascend.get("result", ascend) as Dictionary)
	assert_true(bool(ascend_result.get("ok", false)), "冲击升仙受理")
	var outcome := str(ascend_result.get("outcome", ""))
	assert_true(outcome in ["ascension_special", "ascension_high", "ascension_medium", "ascension_low"],
			"飞升结局评价落账（实际=%s）" % outcome)
	assert_eq(str(controller.state.ascension.get("outcome", "")), outcome, "结局写入 ascension")
	assert_true(int(controller.state.ascension.get("conditions_met", -1)) >= 0, "五项准备入评价")
	controller.free()
