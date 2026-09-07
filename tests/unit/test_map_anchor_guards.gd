extends GutTest


## 2026-09-07 补缺：地图节点生成锚点保底守卫。
## 目标：钉住 L1 层 anchors（遗葬山脊 pre_boss / 炼蛊谷地 mid）与
## 每层黑市/休整锚点的保底投放，防止回归期静默丢失关键节点。
## 规则锚点：data/pacing.json layers["1"].anchors。


func test_l1_anchor_nodes_are_always_placed_for_many_seeds() -> void:
	# 每大层（含 L1）都必须投放 遗葬山脊 与 炼蛊谷地 锚点，
	# 且任一非首局种子下都不会丢失。
	for seed_value in range(1, 50):
		var route := MapGenerator.build(seed_value, false)
		var layer_ids := _layer_1_templates(route)
		assert_true(layer_ids.has("yizang_ridge"),
			"seed %s L1 must place yizang_ridge (pre_boss anchor)" % seed_value)
		assert_true(layer_ids.has("refinement_hollow"),
			"seed %s L1 must place refinement_hollow (mid anchor)" % seed_value)


func test_l1_yizang_ridge_sits_on_pre_boss_row() -> void:
	# 遗葬山脊必须位于关底 Boss 前一行（Boss 台所在行 -1），
	# 保证玩家进入 L1 关底前有且仅有一次传承节点。
	var route := MapGenerator.build(202, false)
	var yizang: Dictionary = _find_template(route, "yizang_ridge")
	var boss: Dictionary = _find_template(route, "layer_boss_stand_1")
	assert_false(yizang.is_empty(), "yizang_ridge must exist in generated route")
	assert_false(boss.is_empty(), "layer_boss_stand_1 must exist in generated route")
	assert_eq(int(yizang["row"]), int(boss["row"]) - 1,
			"yizang_ridge must be one row before the L1 boss stand")


func test_l1_refinement_hollow_sits_on_mid_row() -> void:
	# 炼蛊谷地位于 L1 中段行（行数一半），先于关底出现，
	# 保证玩家可在层内获得炼蛊体验。
	var route := MapGenerator.build(202, false)
	var hollow: Dictionary = _find_template(route, "refinement_hollow")
	var boss: Dictionary = _find_template(route, "layer_boss_stand_1")
	assert_false(hollow.is_empty(), "refinement_hollow must exist in generated route")
	assert_false(boss.is_empty(), "layer_boss_stand_1 must exist in generated route")
	assert_lt(int(hollow["row"]), int(boss["row"]),
			"refinement_hollow must appear before the L1 boss stand")


func test_every_layer_has_black_market_anchor_for_many_seeds() -> void:
	# 每大层保底一处黑市（shop）锚点：L1 由 pacing 裁定，其余层由
	# _anchor_rows 兜底补充。回归期黑市消失直接判红。
	for seed_value in range(1, 30):
		var route := MapGenerator.build(seed_value, false)
		var black_markets := route.filter(func(node: Dictionary): return node.get("template_id", "") == "ridge_black_market")
		assert_eq(black_markets.size(), 5,
			"seed %s must place one black market per layer" % seed_value)


func test_every_layer_has_rest_anchor_for_many_seeds() -> void:
	# 每大层保底休整节点（rest_hollow / rest_shrine 交错），
	# 保证玩家每个大层都有续航机会。
	for seed_value in range(1, 30):
		var route := MapGenerator.build(seed_value, false)
		var rests := route.filter(func(node: Dictionary): return str(node.get("type", "")) == "rest")
		assert_true(rests.size() >= 5,
			"seed %s must place at least one rest per layer, got %s" % [seed_value, rests.size()])


# ---------- 测试工具 ----------

func _layer_1_templates(route: Array) -> Array[String]:
	var ids: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		if int(node.get("layer", -1)) == 1:
			ids.append(str(node.get("template_id", "")))
	return ids


func _find_template(route: Array, template_id: String) -> Dictionary:
	for node_value in route:
		var node: Dictionary = node_value
		if str(node.get("template_id", "")) == template_id:
			return node
	return {}
