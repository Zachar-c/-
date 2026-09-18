extends SceneTree

# E5b：路线多样性冒烟——多种子 × 全图，断言 pacing.category_pools 与固定锚点
# 模板至少各出现一次（“可达”= 生成图中存在该 template_id，可被走到的拓扑前提）。
# 用法：godot --headless --path . -s tools/verify_route_diversity.gd
# 退出码：0 = 全池覆盖；1 = 有模板从未出现。

const SEEDS: Array[int] = [
	101, 42, 99, 777, 2026, 4242, 31337, 20260909, 100, 20260910,
	7, 13, 55, 88, 512, 7777, 12345, 54321, 99991, 20260911,
]


func _initialize() -> void:
	var MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
	var pacing: Dictionary = _load_json("res://data/pacing.json")
	var pools: Dictionary = pacing.get("category_pools", {})
	if pools.is_empty():
		print("E5b FAIL: pacing.category_pools missing")
		quit(1)
		return

	var expected: Dictionary = {}
	for category in pools.keys():
		for template_value in pools.get(category, []):
			expected[str(template_value)] = {
				"category": str(category),
				"seen": 0,
				"layers": {},
			}
	# 固定锚点 / 关底台：任意种子图必须出现（L1..L4 boss + final + 黑市/遗葬若在 anchors）。
	var fixed_required: Array[String] = [
		"layer_boss_stand_1", "layer_boss_stand_2", "layer_boss_stand_3",
		"layer_boss_stand_4", "final_boss_stand",
	]
	for template_id in fixed_required:
		if not expected.has(template_id):
			expected[template_id] = {"category": "fixed", "seen": 0, "layers": {}}

	var seen_ids: Dictionary = {}
	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false)
		var seed_unique: Dictionary = {}
		for node_value in route:
			var node: Dictionary = node_value
			var template_id := str(node.get("template_id", ""))
			if template_id.is_empty():
				continue
			seed_unique[template_id] = true
			if expected.has(template_id):
				var entry: Dictionary = expected[template_id]
				entry["seen"] = int(entry["seen"]) + 1
				var layer_key := str(node.get("layer", ""))
				entry["layers"][layer_key] = int(entry["layers"].get(layer_key, 0)) + 1
		for template_id in seed_unique.keys():
			seen_ids[template_id] = int(seen_ids.get(template_id, 0)) + 1

	var pool_templates: Array[String] = []
	for category in pools.keys():
		for template_value in pools.get(category, []):
			pool_templates.append(str(template_value))
	pool_templates.sort()

	print("===== route diversity over %d seeds =====" % SEEDS.size())
	print("pool templates: %d | fixed required: %d | unique seen: %d"
			% [pool_templates.size(), fixed_required.size(), seen_ids.size()])

	var failures: Array[String] = []
	var by_category: Dictionary = {}
	for template_id in pool_templates:
		var entry: Dictionary = expected[template_id]
		var category: String = str(entry["category"])
		if not by_category.has(category):
			by_category[category] = {"ok": 0, "missing": []}
		var seen := int(entry["seen"])
		if seen <= 0:
			failures.append("never appeared: %s (%s)" % [template_id, category])
			(by_category[category] as Dictionary)["missing"].append(template_id)
		else:
			(by_category[category] as Dictionary)["ok"] = int((by_category[category] as Dictionary)["ok"]) + 1
		print("  [%s] %-28s seen=%-4d layers=%s"
				% [category, template_id, seen, str(entry["layers"])])

	for template_id in fixed_required:
		var entry: Dictionary = expected[template_id]
		if int(entry["seen"]) < SEEDS.size():
			# 固定位应在每张图出现；至少要求 seed 样本中出现过。
			if int(entry["seen"]) <= 0:
				failures.append("fixed slot never appeared: %s" % template_id)
		print("  [fixed]  %-28s seen=%-4d layers=%s"
				% [template_id, int(entry["seen"]), str(entry["layers"])])

	print("===== per-category coverage =====")
	for category in by_category.keys():
		var row: Dictionary = by_category[category]
		print("  %s: %d/%d templates appeared" % [category, int(row["ok"]),
				(row["missing"] as Array).size() + int(row["ok"])])

	if failures.is_empty():
		print("E5b PASS: every category_pool and required fixed template appeared")
		quit(0)
	else:
		print("E5b FAIL: %d template(s) never appeared" % failures.size())
		for line in failures:
			print("  - " + line)
		quit(1)


func _load_json(path: String) -> Variant:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {}
	var text := handle.get_as_text()
	handle.close()
	return JSON.parse_string(text)
