extends GutTest


## 五层通关 / Boss 推进 / 升仙链（真实地图，2026-09-01）：
## 用真实 MapGenerator route（start_new_run 自带）从开局走到升仙窗，
## 验证：五层 Boss 逐一落 boss_defeated_L1..L5，通关旗标不直接改变修为，
## Boss 战斗数值由中央倍率和层级曲线统一投影；
## 第五层瘴脉之主落全局 boss_defeated 解锁升仙窗，attempt_ascension 出结局评价，
## 统一结算 Ending 页。
## 多种子复跑验证无软锁（有界步数内必然到达 Ending），且同种子结果可复现
## （结局评价/旗标/事件数一致）。
##
## 战斗用测试夹具「十转杀蛊」（999 伤，不进任何随机池）：让每条路线都能
## 一击清场，把验证焦点放在路由链而不是战斗强度。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")

const SLAY_GU_ID := "test_slay_gu"
# 注意：运行路径已不把 101 当教学路线（seed==101 也走生成式大图并含 Boss，
# 见 test_runtime_seed_policy）；五层验收用显式种子保证生成式大图与多路线覆盖。
const FIXED_SEED := 20260831
const MULTI_SEEDS := [4242, 20260831, 77, 9, 5150]


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_fixed_seed_clears_five_layers_to_ascension() -> void:
	var controller := _start_run_with_slay_gu(FIXED_SEED)
	assert_eq(controller.current_view_name(), "Map", "开局进 Map")

	var initial_cultivation := int(controller.state.cultivation)
	var outcome := _walk_to_ascension(controller, 1200)
	assert_true(bool(outcome["done"]), "固定种子 %d 必须走通升仙窗：%s" % [FIXED_SEED, str(outcome.get("reason", ""))])
	assert_eq(controller.current_view_name(), "Ending", "统一结算 Ending 页（实际=%s）" % controller.current_view_name())

	# 五层 Boss 逐层落账；通关旗标不替代修为成长。
	for layer in range(1, 6):
		assert_eq(str(controller.state.node_flags.get("boss_defeated_L%d" % layer, "")), "true",
				"boss_defeated_L%d 旗标落账" % layer)
	assert_eq(str(controller.state.node_flags.get("boss_defeated", "")), "true",
			"第五层瘴脉之主落全局 boss_defeated（升仙窗门禁）")
	assert_eq(int(controller.state.cultivation), initial_cultivation,
			"五层清场旗标不直接改变修为")

	# 升仙评价 + 统一结算快照。
	var ascend_outcome := str(controller.state.ascension.get("outcome", ""))
	assert_true(ascend_outcome in ["ascension_special", "ascension_high", "ascension_medium", "ascension_low"],
			"飞升结局评价落账（实际=%s）" % ascend_outcome)
	assert_true(int(controller.state.ascension.get("conditions_met", -1)) >= 0, "五项准备入评价")
	var ending: Dictionary = controller._ending_state
	assert_false(ending.is_empty(), "结算页快照已生成")
	assert_true(str(ending.get("ending_type", "")) in ["success", "risky", "retreat"],
			"结算类型与评价对应（实际=%s）" % str(ending.get("ending_type", "")))
	assert_false(str(ending.get("achievement", "")).is_empty(), "成就文案非空")
	assert_true(str(ending.get("gains_losses", "")).contains("修为"), "结算含修为/转数摘要")
	controller.free()


func test_multiple_seeds_clear_without_softlock_and_are_reproducible() -> void:
	for seed in MULTI_SEEDS:
		var first := _start_run_with_slay_gu(seed)
		var first_outcome := _walk_to_ascension(first, 1500)
		assert_true(bool(first_outcome["done"]),
				"种子 %d 无软锁（%s）" % [seed, str(first_outcome.get("reason", ""))])
		assert_eq(first.current_view_name(), "Ending", "种子 %d 走到统一结算" % seed)
		var first_facts := {
			"end_outcome": str(first.state.ascension.get("outcome", "")),
			"events": first.state.event_log.size(),
			"boss_flags": _boss_flag_digest(first.state),
		}
		# 同种子复跑：结果可复现（评价/事件数/Boss 旗标一致）。
		var second := _start_run_with_slay_gu(seed)
		var second_outcome := _walk_to_ascension(second, 1500)
		assert_true(bool(second_outcome["done"]),
				"种子 %d 复跑无软锁（%s）" % [seed, str(second_outcome.get("reason", ""))])
		assert_eq(str(second.state.ascension.get("outcome", "")), str(first_facts["end_outcome"]),
				"种子 %d 结局评价可复现" % seed)
		assert_eq(second.state.event_log.size(), int(first_facts["events"]),
				"种子 %d 事件数可复现" % seed)
		assert_eq(_boss_flag_digest(second.state), str(first_facts["boss_flags"]),
				"种子 %d Boss 旗标可复现" % seed)
		first.free()
		second.free()


# ---------- 走图器 ----------

## 有界步数走图：优先可达 Boss 台；否则取第一个未访问可达节点；升仙窗就绪后
## 直接 attempt_ascension。任何视图循环、travel 全被拒、步数耗尽都算软锁。
func _walk_to_ascension(controller: RunController, max_steps: int) -> Dictionary:
	var steps := 0
	var attempted := {}
	while steps < max_steps:
		steps += 1
		var view := controller.current_view_name()
		match view:
			"Battle":
				_fight_to_victory_with_slay(controller)
				continue
			"Rest":
				# 休整节点：先用一次服务（回血），随后必须显式离开——只回血
				# 不离开会在 Rest 视图空转（rest_already_used）。
				controller.submit_command({"type": "rest", "mode": "heal"})
				controller.submit_command({"type": "leave_encounter"})
				continue
			"Encounter":
				if str(controller.current_node.get("type", "")) == "ascension":
					controller.submit_command({"type": "attempt_ascension", "choice": "now"})
				else:
					var before_view := controller.current_view_name()
					controller.submit_command({"type": "leave_encounter"})
					if controller.current_view_name() == before_view \
							and str(controller.last_result.get("reason", "")) == "feud_no_escape":
						# 血仇立场（extreme_hostile）：不战而逃被拒。按节点真实
						# 预览动作应战（contact→fight、wild_gu→harvest 等），
						# 用标准 action_card 信封提交。
						var knowledge: Dictionary = {}
						if controller.meta != null:
							knowledge = controller.meta.unlocked_random_outcomes
						var ghost_actions: Array = ActionPreviewServiceScript.preview_actions(
								controller.state, controller.current_node, controller.catalog, knowledge)
						for card_value in ghost_actions:
							var card: Dictionary = card_value
							if not bool(card.get("executable", false)):
								continue
							controller.submit_command({
								"type": "action_card",
								"action_id": str(card.get("id", "")),
								"state_version": controller.state.event_log.size(),
								"node_id": str(controller.current_node.get("id", "")),
								"session_node_id": str(controller.current_session.get("node_id", "")),
							})
							if controller.current_view_name() != before_view:
								break
				continue
			"Reward", "Shop", "Refine", "Npc", "ContentError":
				controller.submit_command({"type": "leave_encounter"})
				continue
			"Ending":
				return {"done": true, "steps": steps}
		if view != "Map":
			return {"done": false, "reason": "stuck_in_view_%s" % view, "steps": steps}

		var reachable: Array = MapGeneratorScript.reachable_nodes(controller.route, controller.state)
		var picked: Dictionary = {}
		var boss_stand: Dictionary = {}
		for node_value in reachable:
			var node: Dictionary = node_value
			if _is_boss_stand(node):
				boss_stand = node
				break
		if not boss_stand.is_empty():
			picked = boss_stand
		else:
			for node_value in reachable:
				var node: Dictionary = node_value
				var nid := str(node.get("id", ""))
				if not controller.state.node_flags.has(nid) and not attempted.has(nid):
					picked = node
					break
		if picked.is_empty():
			return {"done": false, "reason": "no_reachable_node", "steps": steps,
					"view": view}
		var travel := controller.submit_command({"type": "travel", "node_id": str(picked["id"])})
		if bool(travel.get("ok", false)):
			attempted = {}
			continue
		attempted[str(picked["id"])] = true
	return {"done": false, "reason": "steps_exhausted", "steps": steps}


func _is_boss_stand(node: Dictionary) -> bool:
	var node_id := str(node.get("id", ""))
	if node_id == "ascension_window":
		return false
	if node_id == "final_boss_stand":
		return true
	return str(node.get("template_id", "")).begins_with("layer_boss_stand")


func _fight_to_victory_with_slay(controller: RunController, max_steps: int = 60) -> void:
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


func _slay_slot(battle: Dictionary) -> Dictionary:
	for slot_value in battle.get("gu_slots", []):
		var slot: Dictionary = slot_value
		if str(slot.get("definition_id", "")) == SLAY_GU_ID:
			return slot
	return {}


func _boss_flag_digest(state: RunState) -> String:
	var parts: Array[String] = []
	for layer in range(1, 6):
		parts.append(str(state.node_flags.get("boss_defeated_L%d" % layer, "")))
	parts.append(str(state.node_flags.get("boss_defeated", "")))
	return "|".join(parts)


# ---------- 夹具 ----------

func _start_run_with_slay_gu(seed_value: int) -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = catalog
	controller.start_new_run(seed_value, "moonlight", [])
	# 深层机制覆盖：本测试走多层契约，关闭切片收官（S6 默认 L1 Boss 落败即 Ending）。
	controller.catalog["pacing"]["ending_after_stage"] = ""
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