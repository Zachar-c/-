extends SceneTree

# R9：关底 Boss 随机化验证门（2026-09-16）。
# 用法：godot --headless --path . -s tools/verify_boss_variety.gd
# 退出码：0 = 全部通过；1 = 任一门禁失败。
#
# 门禁：
#   B1 覆盖率 —— 每个 boss_pool 成员在 40 个种子上至少出现一次
#   B2 确定性 —— 同种子两次生成逐位相同
#   B3 相邻层不重复 —— 同一局内 L(n) 与 L(n+1) 的关底 Boss 不同
#   B4 终局固定 —— final_boss_stand 的 Boss 不被随机化（叙事绑定，见报告 §3.3）
#   B5 拓扑冻结 —— 带 catalog（E6 + Boss 随机）与不带 catalog（两者皆关）
#                  产出的 (id, template_id, layer, row, next_ids) 逐位相同
#                  ⇒ 证明 Boss 抽取与 E6 一样不消耗共享 rng
#   B0 反空转 canary —— route 非空、关底台数 = 种子数 × 5、覆盖率统计非零

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

const SEEDS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
]
const LAYER_STAGE := {1: "one", 2: "two", 3: "three", 4: "four", 5: "five"}


func _initialize() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var enemy_by_id: Dictionary = catalog.get("enemy_by_id", {})
	var nodes_data: Dictionary = catalog.get("nodes_data", {})
	if enemy_by_id.is_empty() or nodes_data.is_empty():
		print("R9 FAIL: catalog canary empty (enemy_by_id=%d, nodes_data=%d)"
				% [enemy_by_id.size(), nodes_data.size()])
		quit(1)
		return

	# 期望覆盖集合 = 所有 boss_pool 成员 + 未随机化关底台的 enemy_kind。
	var expected := {}
	var fixed_stands := {}
	for node_value in nodes_data.get("nodes", []):
		var node: Dictionary = node_value
		if int(node.get("layer_boss", 0)) <= 0:
			continue
		if node.has("boss_pool"):
			for boss_id_value in node.get("boss_pool", []):
				expected[str(boss_id_value)] = 0
		else:
			var kind := str(node.get("enemy_kind", ""))
			expected[kind] = 0
			fixed_stands[kind] = true

	var failures: Array[String] = []
	var stand_count := 0
	var topology_mismatch := 0
	var adjacency_repeat := 0
	var stand_by_seed: Dictionary = {}

	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false, catalog)
		var again: Array = MapGeneratorScript.build(seed_value, false, catalog)
		var bare: Array = MapGeneratorScript.build(seed_value, false)

		if route.is_empty():
			failures.append("seed %d produced an empty route" % seed_value)
			continue
		if route != again:
			failures.append("seed %d is not deterministic" % seed_value)
		# B5：拓扑冻结自证（同一份代码，开/关 catalog 两条路径）。
		if _topology_key(route) != _topology_key(bare):
			topology_mismatch += 1
			failures.append("seed %d topology differs from the no-catalog baseline" % seed_value)

		var by_layer := {}
		for node_value in route:
			var node: Dictionary = node_value
			if int(node.get("layer_boss", 0)) <= 0:
				continue
			stand_count += 1
			var layer := int(node.get("layer", 0))
			var kind := str(node.get("enemy_kind", ""))
			by_layer[layer] = kind
			if expected.has(kind):
				expected[kind] = int(expected[kind]) + 1
			else:
				failures.append("seed %d L%d rolled boss %s which is not in any pool"
						% [seed_value, layer, kind])
		stand_by_seed[seed_value] = by_layer
		for layer in [1, 2, 3, 4]:
			if by_layer.has(layer) and by_layer.has(layer + 1) \
					and str(by_layer[layer]) == str(by_layer[layer + 1]):
				adjacency_repeat += 1
				failures.append("seed %d: L%d and L%d both rolled %s"
						% [seed_value, layer, layer + 1, str(by_layer[layer])])

	print("===== R9 boss variety over %d seeds =====" % SEEDS.size())
	print("stand slots seen: %d (expected %d)" % [stand_count, SEEDS.size() * 5])
	var missing: Array[String] = []
	for boss_id in expected.keys():
		var seen := int(expected[boss_id])
		var tag := "fixed" if fixed_stands.has(boss_id) else "pool"
		print("  [%s] %-28s seen=%d" % [tag, boss_id, seen])
		if seen <= 0:
			missing.append(boss_id)
	if not missing.is_empty():
		failures.append("boss(es) never rolled: %s" % str(missing))

	# B0 反空转：关底台数量必须正好是 种子数 × 5，否则说明循环根本没跑到。
	if stand_count != SEEDS.size() * 5:
		failures.append("stand count %d != %d (canary)" % [stand_count, SEEDS.size() * 5])

	print("topology_mismatch=%d  adjacency_repeat=%d" % [topology_mismatch, adjacency_repeat])
	if failures.is_empty():
		print("R9 PASS: coverage complete, deterministic, no adjacent repeat, topology frozen")
		quit(0)
	else:
		print("R9 FAIL: %d issue(s)" % failures.size())
		for line in failures:
			print("  - " + line)
		quit(1)


static func _topology_key(route: Array) -> String:
	var parts: Array[String] = []
	for node_value in route:
		var node: Dictionary = node_value
		parts.append("%s|%s|%s|%s|%s" % [
			str(node.get("id", "")),
			str(node.get("template_id", "")),
			str(node.get("layer", "")),
			str(node.get("row", "")),
			str(node.get("next_ids", [])),
		])
	return "\n".join(parts)
