extends GutTest

# 发布阻断修复 5：seed 101 的手工 first_run 网络此前止步于 stage_one_ledger
# （断头：清完后无下一节点 → 冒烟 no_route）。迁移为直达 ascension_window
# 的完整脊柱——手工网保留（AGENTS），但不再断头。

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


func test_seed_101_first_run_route_completes_to_ascension() -> void:
	var catalog := ContentCatalogScript.load_all()
	var route: Array = MapGeneratorScript.build(101, true, catalog)
	assert_gt(route.size(), 20, "手工网必须被迁移为足够的脊柱（原 15 节点止于台账断头）")
	var last_id := str(route.back()["id"])
	assert_eq(last_id, "ascension_window", "first_run 路线终点必须是 ascension_window，而不是断头台账")
	# first_run 保留模板定义的分支语义，但边必须闭合在本次路线内。
	var route_ids := {}
	for node_value in route:
		route_ids[str((node_value as Dictionary)["id"])] = true
	for index in range(route.size() - 1):
		var node: Dictionary = route[index]
		var next_ids: Array = node.get("next_ids", [])
		assert_gt(next_ids.size(), 0, "非终点 first_run 节点不得断头: %s" % node.get("id", ""))
		for next_id_value in next_ids:
			assert_true(route_ids.has(str(next_id_value)), "后继必须属于 first_run 路线: %s -> %s" % [node.get("id", ""), next_id_value])
	assert_eq((route.back() as Dictionary).get("next_ids", []), [])


func test_first_run_filters_template_edges_outside_declared_route() -> void:
	var catalog := ContentCatalogScript.load_all()
	var custom_catalog: Dictionary = catalog.duplicate(true)
	var nodes_data: Dictionary = custom_catalog["nodes_data"]
	var nodes: Array = nodes_data["nodes"]
	for index in nodes.size():
		var node: Dictionary = nodes[index]
		if str(node.get("id", "")) == "neutral_wanderer":
			var altered := node.duplicate(true)
			altered["next_ids"] = ["outside_branch"]
			nodes[index] = altered
			break
	custom_catalog["nodes_data"] = nodes_data
	var first_run: Dictionary = (custom_catalog["first_run"] as Dictionary).duplicate(true)
	first_run["route_ids"] = ["neutral_wanderer", "ridge_caravan"]
	custom_catalog["first_run"] = first_run

	var route: Array[Dictionary] = MapGeneratorScript.build(101, true, custom_catalog)
	assert_eq((route[0] as Dictionary).get("next_ids", []), ["ridge_caravan"], "场外模板边必须过滤，并保留路线内兜底边")
	assert_eq((route[1] as Dictionary).get("next_ids", []), [])
