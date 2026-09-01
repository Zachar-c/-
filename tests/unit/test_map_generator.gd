extends GutTest


func test_first_run_contains_required_anchor_nodes() -> void:
	var route := MapGenerator.build(101, true)
	var ids := route.map(func(node: Dictionary): return node["id"])
	# 修复 5：手工网从 15 节点断头（止步 stage_one_ledger）迁移为直达
	# ascension_window 的完整脊柱。
	assert_eq(route.size(), 31)
	assert_true(ids.has("ridge_caravan"))
	assert_true(ids.has("blood_moss_grove"))
	assert_true(ids.has("ridge_black_market"))
	assert_true(ids.has("echo_cave"))
	assert_true(ids.has("stage_one_ledger"), "台账里程碑节点仍须在列")
	assert_eq(ids.back(), "ascension_window")


func test_same_seed_builds_same_non_first_route() -> void:
	assert_eq(MapGenerator.build(202, false), MapGenerator.build(202, false))
	assert_false(MapGenerator.build(202, false).is_empty())


func test_generated_route_does_not_repeat_required_contest() -> void:
	for seed_value in range(1, 40):
		var route := MapGenerator.build(seed_value, false)
		var contest_count := route.filter(func(node: Dictionary): return node.get("template_id", "") == "earth_vein_contest").size()
		assert_eq(contest_count, 1, "seed %s repeats earth vein contest" % seed_value)


func test_first_run_only_reveals_current_and_next_node() -> void:
	var route := MapGenerator.build(101, true)
	assert_true(route[0]["visible"])
	assert_true(route[1]["visible"])
	assert_false(route[2]["visible"])


func test_only_connected_visible_nodes_are_reachable() -> void:
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	var ids: Array[String] = []
	for node in MapGenerator.reachable_nodes(route, state):
		ids.append(str(node["id"]))
	assert_eq(ids, ["neutral_wanderer", "ridge_caravan"])


func test_fog_reveals_current_choice_layer_and_one_layer_ahead() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	assert_eq(_ids(MapGenerator.visible_nodes(route, state)), [
		"neutral_wanderer", "ridge_caravan", "beast_swarm_pass", "moonlit_trail", "refinement_hollow",
		"cultivation_spring", "village_short_work",
	])
	state = Resolver.apply(state, {"type": "travel", "node_id": "ridge_caravan"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "ridge_caravan", "outcome": "abandoned"}, catalog)["state"]
	assert_true(MapGenerator.visible_node_ids(route, state).has("toxic_mountain_path"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("stage_one_ledger"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("black_mud_marsh"))


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
