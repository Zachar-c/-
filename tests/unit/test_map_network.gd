extends GutTest


var nodes: Array


func before_each() -> void:
	var data := _load_nodes()
	nodes = data


func test_same_seed_builds_identical_network_including_next_ids() -> void:
	for seed_value in range(1, 6):
		var first := MapGenerator.build(seed_value, false)
		var second := MapGenerator.build(seed_value, false)
		assert_eq_deep(first, second)


func test_every_generated_node_can_reach_ascension_window() -> void:
	for seed_value in range(1, 21):
		var route := MapGenerator.build(seed_value, false)
		var by_id := {}
		for node in route:
			by_id[str(node["id"])] = node
		for node in route:
			assert_true(
				_can_reach(by_id, str(node["id"]), "ascension_window"),
				"seed %d node %s must converge to ascension_window" % [seed_value, node["id"]]
			)


func test_every_non_start_node_has_at_least_one_incoming_edge() -> void:
	for seed_value in range(1, 21):
		var route := MapGenerator.build(seed_value, false)
		var incoming := {}
		for node in route:
			incoming[str(node["id"])] = 0
		for node in route:
			for next_id_value in node.get("next_ids", []):
				var next_id := str(next_id_value)
				if incoming.has(next_id):
					incoming[next_id] = int(incoming[next_id]) + 1
		for node in route:
			var node_id := str(node["id"])
			if bool(node.get("start", false)) or node_id == "ascension_window":
				continue
			assert_gt(
				int(incoming.get(node_id, 0)), 0,
				"seed %d node %s must have multiple entries" % [seed_value, node_id]
			)


func test_anchor_types_are_guaranteed_every_run() -> void:
	for seed_value in range(1, 21):
		var route := MapGenerator.build(seed_value, false)
		var types: Array[String] = []
		for node in route:
			types.append(str(node.get("type", "")))
		assert_true(types.has("shop"), "seed %d must include a shop node" % seed_value)
		assert_true(types.has("rest"), "seed %d must include a rest node" % seed_value)
		# 节点收窄（2026-09-06）：普通生成不再刷出事件/接触/商队/炼蛊类模板。
		for forbidden in ["event", "contact", "caravan", "refinement", "market",
				"hazard", "inheritance", "wild_gu", "seclusion", "earth_vein",
				"cultivation", "ledger", "commission", "pursuit"]:
			assert_false(types.has(forbidden), "seed %d must not include %s" % [seed_value, forbidden])


func test_hard_anchors_remain_unique_and_terminal() -> void:
	for seed_value in range(1, 11):
		var route := MapGenerator.build(seed_value, false)
		var ids: Array[String] = []
		for node in route:
			ids.append(str(node["id"]))
		var templates: Array[String] = []
		for node in route:
			templates.append(str(node.get("template_id", "")))
		# 每层自动锚一处黑市（_anchor_rows 补 shop），全程五层恰五处。
		assert_eq(templates.count("ridge_black_market"), 5, "seed %d" % seed_value)
		assert_true(templates.has("final_boss_stand"), "seed %d" % seed_value)
		assert_true(ids.has("ascension_window"), "seed %d" % seed_value)


func test_first_run_route_stays_fixed() -> void:
	var route := MapGenerator.build(101, true)
	var expected: Array = _load_first_run()["route_ids"]
	var ids: Array[String] = []
	for node in route:
		ids.append(str(node["id"]))
	assert_eq(ids, expected)


func _can_reach(by_id: Dictionary, from_id: String, target_id: String) -> bool:
	if from_id == target_id:
		return true
	var visited := {}
	var frontier: Array[String] = [from_id]
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		if current == target_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		var node: Dictionary = by_id.get(current, {})
		if node.is_empty():
			continue
		for next_id_value in node.get("next_ids", []):
			frontier.append(str(next_id_value))
	return false


func _load_nodes() -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/nodes.json")) != OK:
		return []
	return json.data["nodes"]


func _load_first_run() -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string("res://data/first_run.json")) != OK:
		return {}
	return json.data