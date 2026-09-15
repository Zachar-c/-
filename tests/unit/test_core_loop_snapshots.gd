extends GutTest


# Playable Core Loop（2026-09-15）Phase 2–4 快照契约测试：
# 三屏新增键的形状、跨屏一致性，以及「显示必须与真实库存一致」。
#
# 纪律断言：
#   - Map 的 build_goal / 每节点 build_relevance；
#   - Reward 的 build_progress 由**已入账** loot 派生，before/after 自洽；
#   - Refine 每条配方点击前即可见成本，且目标配方排首位；
#   - 三屏的 build_goal 都不含内部保底计数。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")

const FORCE_FIRST_PROMOTION := "promote_force_atk_1_05_to_force_atk_2_06"


func _controller_in_run() -> Node:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	await get_tree().process_frame
	controller.start_new_run(404, "force")
	await get_tree().process_frame
	return controller


# --- Map ---

func test_map_snapshot_exposes_build_goal_and_per_node_relevance() -> void:
	var controller = await _controller_in_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Map", controller)
	assert_true(snap.has("build_goal"), "Map must carry build_goal (Phase 2)")
	var goal: Dictionary = snap["build_goal"]
	assert_true(bool(goal.get("available", false)))
	var nodes: Array = snap.get("nodes", [])
	assert_true(nodes.size() > 0)
	for node_value in nodes:
		var node: Dictionary = node_value
		assert_true(node.has("build_relevance"), "every map node must carry build_relevance")
		var relevance: Dictionary = node["build_relevance"]
		assert_true(relevance.has("code") and relevance.has("text"))


# --- Reward ---

func test_reward_progress_is_absent_without_a_settled_battle() -> void:
	var controller = await _controller_in_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Reward", controller)
	var progress: Dictionary = snap.get("build_progress", {})
	assert_false(bool(progress.get("available", false)),
			"build_progress must stay unavailable when no battle loot was banked")


func test_reward_progress_derives_before_after_from_banked_loot() -> void:
	var controller = await _controller_in_run()
	# 夹具：模拟一场刚结算的 Common 胜利（真实字段 last_battle_loot 由 run_battle_flow 写入）。
	controller.last_battle_loot = {
		"material_ids": ["mat_force_1"],
		"gu_id": "",
		"stone_reward": 7,
	}
	controller.state.materials["mat_force_1"] = int(controller.state.materials.get("mat_force_1", 0)) + 1
	var stone_after: int = int(controller.state.stone)
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Reward", controller)
	var progress: Dictionary = snap.get("build_progress", {})
	assert_true(bool(progress.get("available", false)), "build_progress must be available after a battle")
	assert_eq(str(progress.get("recipe_id", "")), FORCE_FIRST_PROMOTION)
	# before = after − 本场入账
	assert_eq(int(progress.get("stone_before", -1)), stone_after - 7,
			"stone_before must be derived by subtracting this battle's stone reward")
	assert_eq(int(progress.get("stone_after", -1)), stone_after)
	var lines: Array = progress.get("lines", [])
	assert_eq(lines.size(), 1)
	var line: Dictionary = lines[0]
	assert_eq(str(line.get("id", "")), "mat_force_1")
	assert_eq(int(line.get("gained", 0)), 1, "the banked material must be attributed to this battle")
	assert_eq(int(line.get("owned_before", -1)), int(line.get("owned_after", -2)) - 1)
	assert_true(str(progress.get("next_step_text", "")) != "")


func test_reward_progress_reports_becoming_ready() -> void:
	var controller = await _controller_in_run()
	# 目标：1 份 mat_force_1 + 10 元石 + 输入蛊（开局已持有）。
	controller.last_battle_loot = {"material_ids": ["mat_force_1"], "gu_id": "", "stone_reward": 0}
	controller.state.materials["mat_force_1"] = int(controller.state.materials.get("mat_force_1", 0)) + 1
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Reward", controller)
	var progress: Dictionary = snap.get("build_progress", {})
	assert_true(bool(progress.get("ready_before", true)) == false,
			"goal must not have been ready before this battle's material drop")
	assert_true(bool(progress.get("ready_after", false)), "goal must be ready after the drop")
	assert_true(bool(progress.get("became_ready", false)), "became_ready must flag the transition")


# --- Refine ---

func test_refine_snapshot_carries_goal_and_phase4_recipe_fields() -> void:
	var controller = await _controller_in_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Refine", controller)
	assert_true(snap.has("build_goal"), "Refine must carry build_goal (Phase 4)")
	assert_eq(str(snap.get("goal_recipe_id", "")), FORCE_FIRST_PROMOTION)
	var recipes: Array = snap.get("recipes", [])
	assert_true(recipes.size() > 0)
	var first: Dictionary = recipes[0]
	assert_eq(str(first.get("id", "")), FORCE_FIRST_PROMOTION,
			"the goal recipe must sort first (Phase 4 priority)")
	assert_true(bool(first.get("is_goal", false)))
	for key in ["executable", "materials", "missing", "missing_summary", "stone_owned",
			"stone_required", "input_gu_id", "input_gu_name", "input_owned", "recipe_kind"]:
		assert_true(first.has(key), "goal recipe row must carry `%s`" % key)


func test_refine_recipe_rows_expose_cost_before_clicking() -> void:
	var controller = await _controller_in_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Refine", controller)
	for row_value in snap.get("recipes", []):
		var row: Dictionary = row_value
		assert_true(row.has("stone_required"),
				"every recipe row must expose its stone cost before the player clicks")
		assert_true(row.has("materials"), "every recipe row must expose its material requirement")
		for material_value in row.get("materials", []):
			var material: Dictionary = material_value
			for key in ["id", "name", "owned", "required", "complete"]:
				assert_true(material.has(key), "recipe material row must carry `%s`" % key)


func test_refine_recipe_material_owned_matches_real_inventory() -> void:
	var controller = await _controller_in_run()
	controller.state.materials["mat_force_1"] = 3
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Refine", controller)
	for row_value in snap.get("recipes", []):
		var row: Dictionary = row_value
		if str(row.get("id", "")) != FORCE_FIRST_PROMOTION:
			continue
		var material: Dictionary = (row.get("materials", []) as Array)[0]
		assert_eq(int(material["owned"]), 3, "displayed owned count must match the real inventory")
		assert_true(bool(material["complete"]), "3 >= 1 means the material requirement is complete")
		assert_true(bool(row["executable"]), "the recipe must report executable")


func test_refine_goal_recipe_is_not_executable_before_materials() -> void:
	var controller = await _controller_in_run()
	var snap: Dictionary = RunSnapshotBuilderScript.for_screen("Refine", controller)
	var goal_row: Dictionary = {}
	for row_value in snap.get("recipes", []):
		var row: Dictionary = row_value
		if str(row.get("id", "")) == FORCE_FIRST_PROMOTION:
			goal_row = row
			break
	assert_false(goal_row.is_empty(), "goal recipe must be listed")
	assert_false(bool(goal_row.get("executable", true)),
			"a fresh run must not report the first promotion as executable")
	assert_true((goal_row.get("missing", []) as Array).size() > 0,
			"the missing list must name what is absent")


# --- 跨屏信息纪律 ---

func test_no_screen_leaks_internal_pity_counters_through_build_goal() -> void:
	var controller = await _controller_in_run()
	for screen in ["Map", "Refine", "Reward"]:
		var snap: Dictionary = RunSnapshotBuilderScript.for_screen(screen, controller)
		var goal: Dictionary = snap.get("build_goal", {})
		if goal.is_empty():
			continue
		for key in goal.keys():
			assert_false(str(key).contains("pity"),
					"%s.build_goal must not expose pity keys (offending: %s)" % [screen, key])
		assert_false(str(goal).contains("pity"),
				"%s.build_goal serialization must be free of pity data" % screen)
