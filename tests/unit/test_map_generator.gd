extends GutTest


func test_first_run_contains_required_skeleton_nodes() -> void:
	var route := MapGenerator.build(101, true)
	var ids := route.map(func(node: Dictionary): return node["id"])
	# 节点收窄（2026-09-06）：地图只产 战斗/休息/Boss/商店 四类，first_run
	# 同步收窄为 13 节点去重骨架链（旧 31 节点教程含大量事件/商队/炼蛊模板）。
	assert_eq(route.size(), 13)
	assert_true(ids.has("beast_swarm_pass"))
	assert_true(ids.has("rest_hollow"))
	assert_true(ids.has("ridge_black_market"))
	assert_true(ids.has("layer_boss_stand_1"), "层关底 Boss 台仍须在列")
	assert_true(ids.has("final_boss_stand"))
	assert_eq(ids.back(), "ascension_window")


func test_same_seed_builds_same_non_first_route() -> void:
	assert_eq(MapGenerator.build(202, false), MapGenerator.build(202, false))
	assert_false(MapGenerator.build(202, false).is_empty())


func test_generated_route_places_black_markets_per_pacing_anchors() -> void:
	# 节点收窄（2026-09-06）：生成地图只产 combat/rest/shop/layer_boss。
	# 2026-09-07：黑市由 pacing anchors 显式声明数量（每层 mid + pre_boss 各一），
	# 期望值从 pacing 读取，别硬编码——否则一调密度就红。
	var expected := 0
	var handle := FileAccess.open("res://data/pacing.json", FileAccess.READ)
	if handle != null:
		var parsed: Variant = JSON.parse_string(handle.get_as_text())
		handle.close()
		if parsed is Dictionary:
			for layer_value in (parsed as Dictionary).get("layers", {}).values():
				var declared := 0
				for anchor_value in (layer_value as Dictionary).get("anchors", []):
					if str((anchor_value as Dictionary).get("template", "")) == "ridge_black_market":
						declared += 1
				expected += maxi(1, declared)
	if expected == 0:
		expected = 5
	for seed_value in range(1, 40):
		var route := MapGenerator.build(seed_value, false)
		var black_markets := route.filter(func(node: Dictionary): return node.get("template_id", "") == "ridge_black_market").size()
		assert_eq(black_markets, expected, "seed %s must place %d black markets" % [seed_value, expected])
		for node in route:
			if str(node.get("id", "")) == "ascension_window":
				continue
			# E2a（2026-09-09）：地图由 4 分类权重生成，17 种节点类型均合法
			# （combat/pursuit/rest/refinement/cultivation/shop/contact/caravan/market/
			# commission/hazard/event/inheritance/earth_vein/wild_gu/seclusion/ledger）。
			var kind := str(node.get("type", ""))
			assert_true(kind != "", "seed %s node %s must carry a type" % [seed_value, str(node.get("id", ""))])


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
	assert_eq(ids, ["beast_swarm_pass"])


func test_fog_reveals_current_choice_layer_and_one_layer_ahead() -> void:
	var catalog := ContentCatalog.load_all()
	var state := RunState.new_run(101)
	var route := MapGenerator.build(101, true)
	# 教学骨架链可见性：起点战斗（选择层）→ 一层前瞻只见关底 Boss 台；
	# 补给休整在两跳之外，须击败 Boss（boss_defeated_L1）后才纳入可见。
	assert_eq(_ids(MapGenerator.visible_nodes(route, state)), [
		"beast_swarm_pass", "layer_boss_stand_1",
	])
	state = Resolver.apply(state, {"type": "travel", "node_id": "beast_swarm_pass"}, catalog)["state"]
	state = Resolver.apply(state, {"type": "complete_node", "node_id": "beast_swarm_pass", "outcome": "abandoned"}, catalog)["state"]
	assert_true(MapGenerator.visible_node_ids(route, state).has("rest_hollow"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("stage_one_ledger"))
	assert_false(MapGenerator.visible_node_ids(route, state).has("black_mud_marsh"))


func _ids(nodes: Array) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(str(node["id"]))
	return ids
