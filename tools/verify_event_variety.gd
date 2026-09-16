extends SceneTree

# D4：事件池随机化验证门（2026-09-16）。
# 用法：godot --headless --path . -s tools/verify_event_variety.gd
# 退出码：0 = 全部通过；1 = 任一门禁失败。
#
# 门禁：
#   E1 覆盖率 —— event_pool 每个成员在 40 个种子上至少出现一次
#   E2 确定性 —— 同种子两次生成逐位相同（含实例 event_id / dialogue_title / summary）
#   E3 文案随事件走 —— 事件实例的 summary 必须等于目录里该事件的 summary
#                        （否则会出现"点位说回声、实际是兽潮"的错位）
#   E4 对话可解析 —— 每条被抽中的事件都必须在 data/dialogues/events.dialogue 里
#                    有 `~ <event_id>` 菜单块，以及 `<event_id>_accept` /
#                    `<event_id>_leave` 两个跳转目标（否则气球点了会悬空）
#   E5 拓扑冻结 —— 同一份代码下，"带 event_pool"与"剥掉 event_pool"两条路径产出的
#                   (id, template_id, layer, row, next_ids) 逐位相同
#                   ⇒ 证明事件抽取与 E6/R9 一样用独立派生流、不消耗共享 rng
#   E0 反空转 canary —— 事件槽总数 > 0、观察到的事件种类 ≥ 2、对话标题解析非空

const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")

const SEEDS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
]
const DIALOGUE_PATH := "res://data/dialogues/events.dialogue"


func _initialize() -> void:
	var catalog: Dictionary = ContentCatalogScript.load_all()
	var event_by_id: Dictionary = catalog.get("event_by_id", {})
	var nodes_data: Dictionary = catalog.get("nodes_data", {})
	if event_by_id.is_empty() or nodes_data.is_empty():
		print("D4 FAIL: catalog canary empty (event_by_id=%d, nodes_data=%d)"
				% [event_by_id.size(), nodes_data.size()])
		quit(1)
		return
	# E0' 目录校验 canary：新键（event_pool / stone_gain / 文案字段）若有笔误，
	# 这里必须当场报出来，而不是留到运行时静默失效。
	var catalog_errors: Array = ContentCatalogScript.validate(catalog)
	if not catalog_errors.is_empty():
		print("D4 FAIL: content catalog validation reported %d error(s):" % catalog_errors.size())
		for line in catalog_errors:
			print("  - " + str(line))
		quit(1)
		return

	var titles := _dialogue_titles()
	if titles.is_empty():
		print("D4 FAIL: could not parse any dialogue title from %s (canary)" % DIALOGUE_PATH)
		quit(1)
		return

	# 期望覆盖集合 = 所有 event_pool 成员。
	var expected := {}
	for node_value in nodes_data.get("nodes", []):
		var node: Dictionary = node_value
		for event_id_value in node.get("event_pool", []):
			expected[str(event_id_value)] = 0
	if expected.is_empty():
		print("D4 FAIL: no node declares event_pool (canary)")
		quit(1)
		return

	var stripped: Dictionary = _catalog_without_event_pool(catalog)
	var failures: Array[String] = []
	var event_slots := 0
	var topology_mismatch := 0

	for seed_value in SEEDS:
		var route: Array = MapGeneratorScript.build(seed_value, false, catalog)
		var again: Array = MapGeneratorScript.build(seed_value, false, catalog)
		var bare: Array = MapGeneratorScript.build(seed_value, false, stripped)

		if route.is_empty():
			failures.append("seed %d produced an empty route" % seed_value)
			continue
		if route != again:
			failures.append("seed %d is not deterministic" % seed_value)
		# E5：拓扑冻结自证（同一份代码，带/不带 event_pool 两条路径）。
		if _topology_key(route) != _topology_key(bare):
			topology_mismatch += 1
			failures.append("seed %d topology differs from the no-event-pool baseline" % seed_value)

		for node_value in route:
			var node: Dictionary = node_value
			if str(node.get("type", "")) != "event":
				continue
			event_slots += 1
			var event_id := str(node.get("event_id", node.get("id", "")))
			if not expected.has(event_id):
				failures.append("seed %d event node %s rolled %s which is not in any pool"
						% [seed_value, str(node.get("id", "")), event_id])
				continue
			expected[event_id] = int(expected[event_id]) + 1
			# E3：地图/遭遇面文案必须跟着宿主事件走。
			var want_summary := str((event_by_id.get(event_id, {}) as Dictionary).get("summary", ""))
			if str(node.get("summary", "")) != want_summary:
				failures.append("seed %d event node %s summary does not follow %s"
						% [seed_value, str(node.get("id", "")), event_id])
			# E4：气球标题与跳转目标必须齐备。
			for wanted in [event_id, "%s_accept" % event_id, "%s_leave" % event_id]:
				if not titles.has(wanted):
					failures.append("%s is missing dialogue title '%s'" % [DIALOGUE_PATH, wanted])

	print("===== D4 event variety over %d seeds =====" % SEEDS.size())
	print("event slots seen: %d" % event_slots)
	var missing: Array[String] = []
	var observed := 0
	for event_id in expected.keys():
		var seen := int(expected[event_id])
		if seen > 0:
			observed += 1
		print("  %-24s seen=%d" % [event_id, seen])
		if seen <= 0:
			missing.append(str(event_id))
	if not missing.is_empty():
		failures.append("event(s) never rolled: %s" % str(missing))

	# E0 反空转：零事件槽 / 只有一种事件 = 抽取实际没工作。
	if event_slots <= 0:
		failures.append("event slot count is 0 (canary: the loop never reached an event node)")
	if observed < 2:
		failures.append("only %d distinct event(s) observed (canary: no variety at all)" % observed)

	print("dialogue titles parsed=%d  topology_mismatch=%d" % [titles.size(), topology_mismatch])
	if failures.is_empty():
		print("D4 PASS: coverage complete, deterministic, summaries follow events, "
				+ "dialogue resolvable, topology frozen")
		quit(0)
	else:
		print("D4 FAIL: %d issue(s)" % failures.size())
		for line in failures:
			print("  - " + line)
		quit(1)


## 副本目录：把所有 event_pool 从 node 模板里剥掉，其余逐位相同。
## 用于 E5 拓扑冻结自证（对照路径只关事件抽取，不关别的）。
static func _catalog_without_event_pool(catalog: Dictionary) -> Dictionary:
	var copy: Dictionary = catalog.duplicate(true)
	var nodes_data: Dictionary = copy.get("nodes_data", {})
	for node_value in nodes_data.get("nodes", []):
		(node_value as Dictionary).erase("event_pool")
	return copy


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


## 解析 Dialogue Manager 文件里的所有 `~ title` 行。
static func _dialogue_titles() -> Dictionary:
	var titles := {}
	var text := FileAccess.get_file_as_string(DIALOGUE_PATH)
	if text.is_empty():
		return titles
	for raw_line in text.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("~ "):
			var title := line.substr(2).strip_edges()
			if not title.is_empty():
				titles[title] = true
	return titles
