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
	# 断头守卫：除终点外每个节点至少保留一条指路由内存在的边（模板自带边
	# 或线性补链皆可），终点（升仙窗）无出边属正常。
	for index in range(route.size() - 1):
		var node: Dictionary = route[index]
		var next: Array = node.get("next_ids", [])
		assert_false(next.is_empty(), "节点 %s 不得断头" % str(node.get("id", "")))
		var resolved := false
		for node_value in route:
			if next.has(str((node_value as Dictionary)["id"])):
				resolved = true
				break
		assert_true(resolved, "节点 %s 的 next_ids 必须指向路由内节点" % str(node.get("id", "")))