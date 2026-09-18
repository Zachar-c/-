extends GutTest


func test_seed_101_caravan_branch_requires_a_full_field_route_before_stage_ledger() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var route := _synthetic_branch_route()
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), ["neutral_wanderer", "ridge_caravan"])
	state = Resolver.apply(state, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	assert_eq(_ids(MapGenerator.reachable_nodes(route, state)), [])
	state = Resolver.apply(state, {"type": "buy_gu", "offer_id": "buy_force_blow"}, catalog)["state"]
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
	var route := _synthetic_branch_route()
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
	# E4a 三选一（规格 §4）：cultivation 统一落在 Rest 屏，成功执行后留在
	# 同一探访会话内，由玩家显式离开。
	assert_eq(controller.current_view_name(), "Rest")
	# E3a 三选一（规格 §4）：休息类节点（含 cultivation）成功执行修炼即消费
	# 本次探访（裸 id "used" 标记），会话保持 active，离开需玩家显式操作。
	assert_eq(str(controller.state.node_flags.get("cultivation_spring", "")), "used")
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
				"expected_phase": str(controller.current_battle.get("phase", "player_action")),
			})
			played.append(instance_id)
			break
		if result.is_empty() or not bool(result.get("accepted", false)):
			# 无蛊可放（本回合已用或念头耗尽）则收势换回合。
			controller.submit_command({
				"type": "end_turn",
				"state_version": controller.state.event_log.size(),
				"expected_phase": str(controller.current_battle.get("phase", "player_action")),
			})
			played.clear()

	assert_eq(result["result"], "victory")
	# D3 战利品弹窗（流程图 G3）：victory 且有 loot 时进 Reward 屏确认，关闭后回地图。
	assert_eq(controller.current_view_name(), "Reward")
	var loot_rows: int = (controller.last_battle_loot.get("material_ids", []) as Array).size()
	if str(controller.last_battle_loot.get("gu_id", "")) != "":
		loot_rows += 1
	assert_gt(loot_rows, 0, "victory loot was settled by LootResolver")
	assert_eq(controller.state.encounter_session.get("phase", ""), "post_battle")
	assert_false(controller.state.encounter_session.get("completed", true))
	controller.submit_command({"type": "leave_encounter"})
	assert_eq(controller.current_view_name(), "Map")
	controller.free()


## 2026-09-06 节点收窄后 first_run 不再含商队/修习/事件等模板；本文件各用例
## 测试的是「分支图可达性 / 树列分组 / 离开语义」等纯图契约，与地图内容来源
## 无关，故统一注入本地合成分支路线（模板由 nodes.json 提供）。
func _boot_teaching_route(controller) -> void:
	controller.start_new_run(101)
	controller.route = _synthetic_branch_route()


## 复刻旧教学链的分支拓扑（15 节点 4 列扇形图），仅用 nodes.json 现存模板：
##  col0  [neutral_wanderer, ridge_caravan]                    （双 start）
##  col1  [beast_swarm_pass, moonlit_trail, refinement_hollow, cultivation_spring, village_short_work]
##  col2  [toxic_mountain_path, blood_moss_grove, flooded_cave, ridge_black_market, body_imprint_ritual]
##  col3  [ridge_market, echo_cave, stage_one_ledger]
## next_ids 由用例逐步断言驱动（refinement→toxic、toxic→ridge_market、
## ridge_market→stage_one_ledger 等），重复供入节点不会改变列序。
func _synthetic_branch_route() -> Array[Dictionary]:
	var catalog: Dictionary = ContentCatalog.load_all()
	var by_id := {}
	for node_value in catalog.get("nodes_data", {}).get("nodes", []):
		by_id[str((node_value as Dictionary).get("id", ""))] = node_value
	var order := [
		"neutral_wanderer", "ridge_caravan",
		"beast_swarm_pass", "moonlit_trail", "refinement_hollow", "cultivation_spring", "village_short_work",
		"toxic_mountain_path", "blood_moss_grove", "flooded_cave", "ridge_black_market", "body_imprint_ritual",
		"ridge_market", "echo_cave", "stage_one_ledger",
	]
	var next_by_id := {
		"neutral_wanderer": ["beast_swarm_pass", "moonlit_trail"],
		"ridge_caravan": ["refinement_hollow", "cultivation_spring", "village_short_work"],
		"beast_swarm_pass": ["toxic_mountain_path"],
		"moonlit_trail": ["blood_moss_grove", "flooded_cave"],
		"refinement_hollow": ["toxic_mountain_path"],
		"cultivation_spring": ["ridge_black_market"],
		"village_short_work": ["body_imprint_ritual"],
		"toxic_mountain_path": ["ridge_market"],
		"blood_moss_grove": ["echo_cave"],
		"flooded_cave": ["stage_one_ledger"],
		"ridge_black_market": ["stage_one_ledger"],
		"body_imprint_ritual": ["stage_one_ledger"],
		"ridge_market": ["stage_one_ledger"],
		"echo_cave": [],
		"stage_one_ledger": [],
	}
	var route: Array[Dictionary] = []
	for index in order.size():
		var node: Dictionary = (by_id[order[index]] as Dictionary).duplicate(true)
		node["start"] = index < 2
		node["visible"] = index <= 1
		node["template_id"] = order[index]
		node["layer"] = 1
		node["row"] = index
		node["next_ids"] = next_by_id.get(order[index], [])
		route.append(node)
	return route


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
