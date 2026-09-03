extends GutTest


func test_seed_101_caravan_branch_requires_a_full_field_route_before_stage_ledger() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["neutral_wanderer", "ridge_caravan"])
	state = Resolver.apply(state, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), [])
	state = Resolver.apply(state, {"type": "buy_gu", "offer_id": "caravan_thorn_offer"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), [])
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "ridge_caravan", "outcome": "abandoned"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["refinement_hollow", "cultivation_spring", "village_short_work"])
	state = Resolver.apply(state, {"type": "travel", "node_id": "refinement_hollow"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "choose_action", "action_id": "leave"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "refinement_hollow", "outcome": "left"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["toxic_mountain_path"])
	state = Resolver.apply(state, {"type": "travel", "node_id": "toxic_mountain_path"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "choose_action", "action_id": "scout"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "toxic_mountain_path", "outcome": "scouted"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["ridge_market"])
	state = Resolver.apply(state, {"type": "travel", "node_id": "ridge_market"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "choose_action", "action_id": "leave"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "ridge_market", "outcome": "left"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["stage_one_ledger"])


func test_tree_columns_group_branches_by_graph_depth() -> void:
	var route := MapGenerator.build(101, true)
	var columns := MapGenerator.tree_columns(route)
	assert_eq(_ids(columns[0]), ["neutral_wanderer", "ridge_caravan"])
	assert_eq(_ids(columns[1]), ["beast_swarm_pass", "moonlit_trail", "refinement_hollow", "cultivation_spring", "village_short_work"])
	assert_eq(_ids(columns[2]), ["toxic_mountain_path", "blood_moss_grove", "flooded_cave", "ridge_black_market", "body_imprint_ritual"])
	assert_eq(_ids(columns[3]), ["ridge_market", "echo_cave", "stage_one_ledger"])


func test_controller_rejects_travel_to_a_node_outside_current_branch() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	_boot_teaching_route(controller)
	var result := controller.submit_command({"type": "travel", "node_id": "stage_one_ledger"})
	assert_false(result["ok"])
	assert_eq(result.get("reason", ""), "unreachable_route_node")
	controller.free()


func test_controller_returns_to_map_after_explicit_node_leave() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	_boot_teaching_route(controller)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	var result := controller.submit_command({"type": "leave_node"})
	assert_true(result["result"]["ok"])
	assert_eq(controller.current_view_name(), "Map")
	assert_eq(_ids(MapGenerator.reachable_nodes(controller.route, controller.state)), ["refinement_hollow", "cultivation_spring", "village_short_work"])
	controller.free()


func test_controller_leaving_an_encounter_abandons_the_node_and_keeps_route_playable() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	_boot_teaching_route(controller)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	var result := controller.submit_command({"type": "leave_encounter"})
	assert_true(result["result"]["ok"])
	assert_eq(controller.current_view_name(), "Map")
	assert_eq(controller.state.node_flags.get("ridge_caravan", ""), "abandoned")
	assert_eq(_ids(MapGenerator.reachable_nodes(controller.route, controller.state)), ["refinement_hollow", "cultivation_spring", "village_short_work"])
	controller.free()


func test_standard_encounter_action_stays_in_the_active_session() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	_boot_teaching_route(controller)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	controller.submit_command({"type": "leave_encounter"})
	controller.submit_command({"type": "travel", "node_id": "cultivation_spring"})
	var result := controller.submit_command({"type": "choose_action", "action_id": "meditate"})
	assert_true(result["result"]["ok"])
	assert_eq(controller.current_view_name(), "Encounter")
	assert_false(controller.state.node_flags.has("cultivation_spring"))
	assert_eq(controller.state.encounter_session.get("node_id", ""), "cultivation_spring")
	controller.free()


func test_battle_victory_returns_to_the_encounter_for_post_battle_handling() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	_boot_teaching_route(controller)
	controller.submit_command({"type": "travel", "node_id": "neutral_wanderer"})
	# 遭遇命令信封：node.fight 必须携带 node_id/session_node_id（A1 修复后的契约）。
	controller.submit_command({
		"type": "action_card",
		"action_id": "node.fight",
		"state_version": controller.state.event_log.size(),
		"node_id": str(controller.state.current_node_id),
		"session_node_id": str(controller.state.current_node_id),
	})
	# 流程夹具：敌方行 HP 压到 1，任一伤害蛊一击致胜（V1 战斗状态为唯一契约源，
	# 无旧投影标量 enemy_hp）。
	for enemy_row_value in controller.current_battle.get("enemies", []):
		var enemy_row: Dictionary = enemy_row_value
		enemy_row["hp"] = 1
	var played: Array[String] = []
	var result: Dictionary = {}
	for _step in 6:
		if controller.current_view_name() != "Battle":
			break
		var battle: Dictionary = controller.current_battle
		var target_id := ""
		for enemy_value in battle.get("enemies", []):
			var enemy: Dictionary = enemy_value
			if bool(enemy.get("alive", false)) and int(enemy.get("hp", 0)) > 0:
				target_id = str(enemy.get("id", ""))
				break
		result = {}
		for slot_value in battle.get("gu_slots", []):
			var slot: Dictionary = slot_value
			var instance_id := str(slot.get("instance_id", ""))
			if instance_id in played:
				continue
			# V1 蛊行动制：直接以 use_gu 施放（每回合一次、耗 1 念头）。
			result = controller.submit_command({
				"type": "use_gu",
				"instance_id": instance_id,
				"state_version": controller.state.event_log.size(),
			})
			played.append(instance_id)
			break
		if result.is_empty() or not bool(result.get("accepted", false)):
			# 无蛊可放（本回合已用或念头耗尽）则收势换回合。
			controller.submit_command({
				"type": "end_turn",
				"state_version": controller.state.event_log.size(),
			})
			played.clear()

	assert_eq(result["result"], "victory")
	# D3 战利品弹窗（流程图 G3）：victory 且有 loot 时进 Reward 屏确认，关闭后回地图。
	assert_eq(controller.current_view_name(), "Reward")
	var loot_rows: int = (controller.last_battle_loot.get("material_ids", []) as Array).size()
	if str(controller.last_battle_loot.get("gu_id", "")) != "":
		loot_rows += 1
	assert_gt(loot_rows, 0, "victory loot was settled by LootResolver")
	assert_eq(controller.current_session.get("phase", ""), "post_battle")
	assert_false(controller.current_session.get("completed", true))
	controller.submit_command({"type": "leave_encounter"})
	assert_eq(controller.current_view_name(), "Map")
	controller.free()


## 2026-09-03 裁定后 start_new_run 不再把 101 当教学种子：需要手写教学路线的
## controller 测试统一走此夹具——先正常开局，再显式注入 MapGenerator.build(101, true)。
func _boot_teaching_route(controller) -> void:
	controller.start_new_run(101)
	controller.route = MapGenerator.build(101, true)


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
