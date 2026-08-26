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
	controller.start_new_run(101)
	var result := controller.submit_command({"type": "travel", "node_id": "stage_one_ledger"})
	assert_false(result["ok"])
	assert_eq(result.get("reason", ""), "unreachable_route_node")
	controller.free()


func test_controller_returns_to_map_after_explicit_node_leave() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	var result := controller.submit_command({"type": "leave_node"})
	assert_true(result["result"]["ok"])
	assert_eq(controller.current_view_name(), "Map")
	assert_eq(_ids(MapGenerator.reachable_nodes(controller.route, controller.state)), ["refinement_hollow", "cultivation_spring", "village_short_work"])
	controller.free()


func test_controller_leaving_an_encounter_abandons_the_node_and_keeps_route_playable() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	var result := controller.submit_command({"type": "leave_encounter"})
	assert_true(result["result"]["ok"])
	assert_eq(controller.current_view_name(), "Map")
	assert_eq(controller.state.node_flags.get("ridge_caravan", ""), "abandoned")
	assert_eq(_ids(MapGenerator.reachable_nodes(controller.route, controller.state)), ["refinement_hollow", "cultivation_spring", "village_short_work"])
	controller.free()


func test_standard_encounter_action_stays_in_the_active_session() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
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
	controller.start_new_run(101)
	controller.submit_command({"type": "travel", "node_id": "neutral_wanderer"})
	controller.submit_command({
		"type": "action_card",
		"action_id": "node.fight",
		"state_version": controller.state.event_log.size(),
	})
	controller.current_battle["enemy_hp"] = 1
	controller.state.refined_gu_ids.append("thorn_whip_gu")
	controller.current_battle["available_gu_ids"].append("thorn_whip_gu")
	var result := controller.submit_command({"type": "use_gu", "gu_id": "thorn_whip_gu", "mode": "bind"})
	result = controller.submit_command({"type": "use_gu", "gu_id": "thorn_whip_gu", "mode": "strike"})

	assert_eq(result["result"], "victory")
	assert_eq(controller.current_view_name(), "Encounter")
	assert_eq(controller.current_session.get("phase", ""), "post_battle")
	assert_false(controller.current_session.get("completed", true))
	controller.free()


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
