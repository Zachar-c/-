extends GutTest


# Playable Core Loop（2026-09-15）Phase 1 单测：
# 「当前构筑目标」只读投影的目标选择规则、契约形状与信息纪律。
#
# 纪律断言（任务书 Phase 1）：
#   - 目标选择是纯函数、确定性、可测试；
#   - 不显示内部保底计数；
#   - 不复制领域判断（可执行性经 refine_command_rules 同源门禁）；
#   - 不反推未揭示节点内容。

const BuildGoalProjectionScript = preload("res://scripts/presentation/snapshots/build_goal_projection.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const FORCE_FIRST_PROMOTION := "promote_force_atk_1_05_to_force_atk_2_06"
const SWORD_FIRST_PROMOTION := "promote_sword_def_1_07_to_sword_atk_2_20"


func _controller(seed_value: int, school: String) -> Node:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	await get_tree().process_frame
	controller.start_new_run(seed_value, school)
	await get_tree().process_frame
	return controller


# --- 目标选择规则 ---

func test_fresh_force_run_targets_first_promotion_in_school_chain() -> void:
	var controller = await _controller(101, "force")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	assert_true(bool(goal["available"]), "a fresh force run must expose a build goal")
	assert_eq(str(goal["recipe_id"]), FORCE_FIRST_PROMOTION,
			"goal must be the first unfinished promotion of the school chain")
	assert_eq(str(goal["recipe_kind"]), "promotion")
	assert_eq(str(goal["school"]), "force")
	# 开局蛊含 force_atk_1_05_gu（data/schools.json starter_gu_ids）
	assert_true(bool(goal["input_gu_ready"]), "starter Gu must satisfy the promotion input")
	assert_eq(int(goal["chain_length"]), 4, "force promotion chain has 4 steps")
	assert_eq(int(goal["chain_index"]), 1, "fresh run sits on chain step 1")


func test_fresh_sword_run_targets_first_promotion_in_school_chain() -> void:
	var controller = await _controller(101, "sword")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	assert_eq(str(goal["recipe_id"]), SWORD_FIRST_PROMOTION)
	assert_eq(int(goal["stone_required"]), 6, "sword step 1 costs 6 stones")
	assert_true(bool(goal["input_gu_ready"]))


func test_goal_reports_exact_material_requirement_and_shortfall() -> void:
	var controller = await _controller(101, "force")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	var rows: Array = goal["materials"]
	assert_eq(rows.size(), 1, "force step 1 needs exactly one material line")
	var row: Dictionary = rows[0]
	assert_eq(str(row["id"]), "mat_force_1", "force step 1 consumes the school's crude band")
	assert_eq(int(row["required"]), 1)
	assert_false(bool(row["complete"]), "a fresh run does not own the crude material yet")
	assert_eq(goal["missing_materials"].size(), 1)
	# 开局 12 元石 >= 10，故元石不构成缺口（缺口来自材料）
	assert_eq(int(goal["stone_owned"]), 12, "fresh run starts with 12 stones")
	assert_eq(int(goal["missing_stone"]), 0)
	assert_false(bool(goal["ready"]), "goal is not ready before the material drops")
	assert_true(str(goal["missing_summary"]).contains(str(row["name"])),
			"missing_summary must name the missing material")


func test_goal_advances_to_next_chain_step_once_output_is_owned() -> void:
	var controller = await _controller(101, "force")
	var first: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	# 夹具：把第一步的产出蛊放进蛊仓（模拟玩家已完成第一步）。
	var state = controller.state
	var instance_id: String = state.next_gu_instance_id(state.gu_instances)
	state.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": str(first["output_gu_id"]),
		"state": "refined",
		"rank": 2,
	}
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	var second: Dictionary = BuildGoalProjectionScript.build_goal(state, controller.catalog)
	assert_eq(str(second["recipe_id"]), "promote_force_atk_2_06_to_force_atk_3_07",
			"goal must roll forward to the next unfinished promotion")
	assert_eq(int(second["chain_index"]), 2)


func test_goal_becomes_ready_when_material_and_input_are_satisfied() -> void:
	var controller = await _controller(101, "force")
	var state = controller.state
	state.materials["mat_force_1"] = int(state.materials.get("mat_force_1", 0)) + 1
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(state, controller.catalog)
	assert_true(bool(goal["ready"]), "goal must report ready once every requirement is met")
	assert_eq(goal["missing_materials"].size(), 0)
	assert_eq(int(goal["missing_stone"]), 0)
	assert_true(str(goal["missing_summary"]).contains("可前往炼蛊台"))
	assert_true(str(goal["progress_text"]).contains("已就绪"))


func test_goal_is_deterministic_for_same_seed_and_school() -> void:
	var a = await _controller(4242, "force")
	var b = await _controller(4242, "force")
	var goal_a: Dictionary = BuildGoalProjectionScript.build_goal(a.state, a.catalog)
	var goal_b: Dictionary = BuildGoalProjectionScript.build_goal(b.state, b.catalog)
	assert_eq(str(goal_a), str(goal_b), "same seed + school must project an identical goal")


func test_no_goal_when_school_is_empty() -> void:
	var controller = await _controller(101, "")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	assert_false(bool(goal["available"]))
	assert_eq(str(goal["title"]), "暂无可执行构筑目标")
	assert_eq(goal["recommended_node_types"].size(), 0)


# --- 信息纪律 ---

func test_goal_block_never_exposes_internal_pity_counters() -> void:
	var controller = await _controller(101, "force")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	for key in goal.keys():
		assert_false(str(key).contains("pity"),
				"build_goal must not expose internal pity counters (offending key: %s)" % key)
	var serialized := str(goal)
	assert_false(serialized.contains("pity"), "serialized build_goal must be free of pity data")


func test_goal_block_shape_matches_the_declared_contract() -> void:
	var controller = await _controller(101, "force")
	var goal: Dictionary = BuildGoalProjectionScript.build_goal(controller.state, controller.catalog)
	for key in ["school", "title", "recipe_id", "recipe_name", "input_gu_ready", "materials",
			"stone_owned", "stone_required", "ready", "missing_summary",
			"recommended_node_types", "progress_text"]:
		assert_true(goal.has(key), "build_goal must carry the declared key `%s`" % key)
	assert_true(goal["materials"] is Array)
	assert_true(goal["recommended_node_types"] is Array)
	for material_row in goal["materials"]:
		for key in ["id", "name", "owned", "required", "complete"]:
			assert_true((material_row as Dictionary).has(key),
					"materials[] must carry `%s`" % key)


# --- 节点相关性 ---

func test_node_relevance_never_leaks_unrevealed_node_content() -> void:
	var controller = await _controller(101, "force")
	var node := {"id": "L3R1N0", "type": "combat", "revealed": false}
	var relevance: Dictionary = BuildGoalProjectionScript.node_relevance(
			node, controller.state, controller.catalog)
	assert_eq(str(relevance["code"]), "unknown")
	assert_false(str(relevance["text"]).contains("材料"),
			"unrevealed nodes must not hint at loot potential")


func test_node_relevance_flags_combat_as_possible_material_source() -> void:
	var controller = await _controller(101, "force")
	var node := {"id": "L1R2N0", "type": "combat", "revealed": true}
	var relevance: Dictionary = BuildGoalProjectionScript.node_relevance(
			node, controller.state, controller.catalog)
	assert_eq(str(relevance["code"]), "advance")
	assert_true(str(relevance["text"]).contains("可能"), "combat hint must stay non-committal")
	assert_false(str(relevance["text"]).contains("必定"),
			"relevance text must never promise a specific drop")


func test_node_relevance_flags_refinement_as_execution_site() -> void:
	var controller = await _controller(101, "force")
	var node := {"id": "L1R4N0", "type": "refinement", "revealed": true}
	var relevance: Dictionary = BuildGoalProjectionScript.node_relevance(
			node, controller.state, controller.catalog)
	assert_eq(str(relevance["code"]), "execute")
	assert_true(str(relevance["text"]).contains("炼蛊台"))


func test_node_relevance_is_neutral_for_unrelated_node_types() -> void:
	var controller = await _controller(101, "force")
	var node := {"id": "L1R1N0", "type": "seclusion", "revealed": true}
	var relevance: Dictionary = BuildGoalProjectionScript.node_relevance(
			node, controller.state, controller.catalog)
	assert_eq(str(relevance["code"]), "none")
	assert_eq(str(relevance["text"]), "与当前目标无直接关系")
