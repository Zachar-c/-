extends GutTest


# 拓扑 v2 契约（2026-08-29 裁定）：五大层扇形收敛图。
# - 每大层 8–11 行；首行 1–2 入口、末行 1 个关底 Boss、中间行 2–6 节点。
# - 边只连下一行 1–2 个节点，下行每节点 ≥1 入边，无反向边。
# - 关底 Boss 击败（boss_defeated_L{n}）前，Boss 台无路可走。
# - 全节点沿前向边可达 ascension_window；同种子确定性。
# - 实例携带 template_id/layer/row；锚点每局恰一次。

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")

static var _pacing_cache: Dictionary = {}


static func _pacing_layers() -> Dictionary:
	if not _pacing_cache.is_empty():
		return _pacing_cache
	var handle := FileAccess.open("res://data/pacing.json", FileAccess.READ)
	if handle == null:
		return {}
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	if parsed is Dictionary:
		_pacing_cache = (parsed as Dictionary).get("layers", {})
	return _pacing_cache


## 黑市数量以 pacing 为准：anchors 显式声明几个就是几个，未声明则生成器自动补 1。
## 别把数字硬编码回测试——2026-09-07 把「每层 1 个黑市」调成 2 个时，这里硬编码的 1 全红。
static func _expected_black_markets(layer_key: String) -> int:
	var cfg: Dictionary = _pacing_layers().get(layer_key, {})
	var count := 0
	for anchor_value in cfg.get("anchors", []):
		if str((anchor_value as Dictionary).get("template", "")) == "ridge_black_market":
			count += 1
	return maxi(1, count)

var route: Array[Dictionary] = []


func before_each() -> void:
	route = MapGeneratorScript.build(4242, false)


func _by_id() -> Dictionary:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	return by_id


func _boss_of_layer(layer: int) -> Dictionary:
	for node in route:
		if int(node.get("layer_boss", 0)) == layer:
			return node
	return {}


func test_five_big_layers_with_8_to_11_rows_each() -> void:
	var by_id := _by_id()
	for layer in range(1, 6):
		var rows := {}
		for node in route:
			if str(node.get("id", "")) == "ascension_window":
				continue
			if int(node.get("layer", 0)) == layer:
				rows[int(node.get("row", -1))] = true
		assert_between(rows.size(), 8, 11, "layer %d must have 8..11 rows" % layer)
		assert_true(by_id.has("L%dR0N0" % layer), "layer %d must own its entry row" % layer)


func test_row_widths_follow_the_ruling() -> void:
	var by_id := _by_id()
	for node in route:
		var row := int(node.get("row", 0))
		var layer := int(node.get("layer", 0))
		var same_row := 0
		for other in route:
			if int(other.get("layer", 0)) == layer and int(other.get("row", -1)) == row:
				same_row += 1
		var boss_row := str(node.get("id", "")) == "L%dR%dN0" % [layer, _row_count(by_id, layer) - 1]
		if boss_row:
			assert_eq(same_row, 1, "the boss row holds exactly the layer boss")
		elif row == 0:
			assert_between(same_row, 1, 2, "entry row holds 1..2 nodes")
		else:
			assert_between(same_row, 2, 6, "mid rows hold 2..6 nodes")


func _row_count(by_id: Dictionary, layer: int) -> int:
	var max_row := 0
	for node in route:
		if int(node.get("layer", 0)) == layer:
			max_row = maxi(max_row, int(node.get("row", 0)))
	return max_row + 1


func test_edges_only_point_forward_one_row_with_coverage() -> void:
	var by_id := _by_id()
	for node in route:
		var layer := int(node.get("layer", 0))
		var row := int(node.get("row", 0))
		for next_id in node.get("next_ids", []):
			var target: Dictionary = by_id.get(str(next_id), {})
			if target.is_empty():
				continue
			var t_layer := int(target.get("layer", 0))
			var t_row := int(target.get("row", 0))
			var is_seam := int(node.get("layer_boss", 0)) > 0 and t_layer == layer + 1
			var is_window := str(next_id) == "ascension_window"
			if is_seam or is_window:
				continue
			assert_eq(t_layer, layer, "within a layer, edges never change big layer")
			assert_eq(t_row, row + 1, "edges always advance exactly one row")
	# 下行每节点 ≥1 入边（大层入口行由上一层接缝喂给）。
	for layer in range(1, 6):
		var row_count := _row_count(by_id, layer)
		for row in range(1, row_count):
			for node in route:
				if int(node.get("layer", 0)) != layer or int(node.get("row", -1)) != row:
					continue
				var incoming := 0
				var node_id := str(node["id"])
				for other in route:
					if ((other.get("next_ids", []) as Array).has(node_id)):
						incoming += 1
				assert_gt(incoming, 0, "%s must keep at least one incoming edge" % node_id)


func test_layer_boss_gates_the_next_layer() -> void:
	var state = RunStateScript.new_run(4242)
	state.current_node_id = "L1R%dN0" % (_row_count(_by_id(), 1) - 1)
	state.node_flags[state.current_node_id] = "abandoned"
	assert_eq(MapGeneratorScript.reachable_nodes(route, state).size(), 0,
		"an unbeaten layer boss leaves no way forward, even after a retreat")
	state.node_flags["boss_defeated_L1"] = "true"
	assert_gt(MapGeneratorScript.reachable_nodes(route, state).size(), 0,
		"defeating the layer boss opens the next layer")


func test_every_node_reaches_the_ascension_window_forward() -> void:
	var by_id := _by_id()
	for node in route:
		var seen := {}
		var queue: Array[String] = [str(node["id"])]
		var found := false
		while not queue.is_empty():
			var current: String = queue.pop_front()
			if seen.has(current):
				continue
			seen[current] = true
			if current == "ascension_window":
				found = true
				break
			for next_id in by_id.get(current, {}).get("next_ids", []):
				queue.append(str(next_id))
		assert_true(found, "%s must reach the ascension window forward" % str(node["id"]))


func test_generation_is_deterministic_per_seed() -> void:
	var again := MapGeneratorScript.build(4242, false)
	assert_eq(route.size(), again.size())
	for index in route.size():
		assert_eq(str(route[index]["id"]), str(again[index]["id"]))
		assert_eq(route[index].get("next_ids", []), again[index].get("next_ids", []))


func test_instances_carry_template_layer_and_row() -> void:
	var by_id := _by_id()
	for node in route:
		if str(node["id"]) == "ascension_window":
			continue
		assert_false(str(node.get("template_id", "")).is_empty(), "%s needs a template id" % str(node["id"]))
		assert_between(int(node.get("layer", 0)), 1, 5)
		assert_true(int(node.get("row", -1)) >= 0)
	# E2a（2026-09-09）：4 分类权重生成，17 种节点类型均合法（见
	# test_map_generator.gd 同注释）。只要求节点携带非空 type。
	for node in route:
		if str(node["id"]) == "ascension_window":
			continue
		var template_kind := str(node.get("type", ""))
		assert_true(template_kind != "",
			"instance %s carries empty kind" % str(node["id"]))
	var market_count := 0
	for node in route:
		if str(node.get("template_id", "")) == "ridge_black_market":
			market_count += 1
	var expected_markets := 0
	for layer_key in ["1", "2", "3", "4", "5"]:
		expected_markets += _expected_black_markets(layer_key)
	assert_eq(market_count, expected_markets, "black markets materialize per pacing anchors")


# pacing 的黑市/炼蛊由 anchors 显式声明，休整由生成器自动补锚（每三行一处）。
# 多种子契约：每层黑市数 == pacing anchors 声明数、每层休整 ≥1、层末 Boss 恰 1。
func test_auto_anchors_materialize_for_many_seeds() -> void:
	for seed_value in range(1, 101):
		var generated: Array[Dictionary] = MapGeneratorScript.build(seed_value, false)
		var markets := {}
		var rests := {}
		var bosses := {}
		for node in generated:
			var layer := str(node.get("layer", ""))
			var template_id := str(node.get("template_id", ""))
			if template_id == "ridge_black_market":
				markets[layer] = int(markets.get(layer, 0)) + 1
			elif template_id == "rest_hollow" or template_id == "rest_shrine":
				rests[layer] = int(rests.get(layer, 0)) + 1
			elif template_id == "final_boss_stand" or template_id.begins_with("layer_boss_stand_"):
				bosses[layer] = int(bosses.get(layer, 0)) + 1
		for layer_key in ["1", "2", "3", "4", "5"]:
			assert_eq(markets.get(layer_key, 0), _expected_black_markets(layer_key),
				"seed %d layer %s black-market count must match pacing anchors" % [seed_value, layer_key])
			assert_gt(rests.get(layer_key, 0), 0,
				"seed %d layer %s must keep at least one rest stop" % [seed_value, layer_key])
			assert_eq(bosses.get(layer_key, 0), 1,
				"seed %d layer %s must own exactly one boss stand" % [seed_value, layer_key])


func test_layer_bosses_exist_in_all_five_layers() -> void:
	for layer in range(1, 6):
		var boss := _boss_of_layer(layer)
		assert_false(boss.is_empty(), "layer %d must own a boss stand" % layer)
		if layer < 5:
			assert_eq(str(boss.get("id", "")), "L%dR%dN0" % [layer, _row_count(_by_id(), layer) - 1],
				"the layer boss sits on the last row of its layer")
