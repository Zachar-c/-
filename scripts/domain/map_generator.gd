class_name MapGenerator
extends RefCounted


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")

# R-layering 2026-08-27: a run is exactly five layers (one..five). The last
# layer funnels through final_boss_stand; ascension_window is only reachable
# from the boss stand, so beating the boss is the sole path to ascend.
const LAYER_ORDER: Array[String] = ["one", "two", "three", "four", "five"]
const BOSS_NODE_ID := "final_boss_stand"
const ASCENSION_NODE_ID := "ascension_window"

# 休整节点行间距。2026-09-08 由 3 收紧到 2（玩家反馈重复打怪、续航点太少，
# 生成图里战斗占比一度 82%）。测试以它为唯一事实来源，别在测试里另写数字。
const REST_ROW_STRIDE := 2


static func layer_index(stage: String) -> int:
	return LAYER_ORDER.find(str(stage)) + 1


static func build(seed_value: int, first_run: bool, catalog: Dictionary = {}) -> Array[Dictionary]:
	var data: Dictionary = catalog.get("nodes_data", {}) if not catalog.is_empty() else _load_json_fallback("build/nodes", "res://data/nodes.json")
	var node_by_id := _index_nodes(data.get("nodes", []))
	var ascension_node: Dictionary = data.get("ascension_node", {})
	if not ascension_node.is_empty():
		node_by_id[ascension_node.get("id", "")] = ascension_node
	if first_run:
		var first_run_cfg: Dictionary = catalog.get("first_run", {}) if not catalog.is_empty() else _load_json_fallback("build/first_run", "res://data/first_run.json")
		var route_ids: Array = first_run_cfg.get("route_ids", [])
		return _route_from_ids(route_ids, node_by_id)
	return _generate_instance_route(seed_value, node_by_id, catalog.get("pacing", {}) if not catalog.is_empty() else {})


## v2 拓扑（2026-08-29 裁定）：五大层扇形收敛图。每大层 8–11 行 ×
## 每行 2–6 节点（首行 1–2 入口、末行 1 个关底 Boss），行进边只连
## 下一行 1–2 个节点且下行每节点 ≥1 入边；关底 Boss 击败后解锁
## 下一大层。层形状/锚点/模板池来自 pacing.json 的 layers 裁定表。
static func _generate_instance_route(seed_value: int, node_by_id: Dictionary, pacing_override: Dictionary = {}) -> Array[Dictionary]:
	var pacing: Dictionary = pacing_override if not pacing_override.is_empty() else _load_json_fallback("route/pacing", "res://data/pacing.json")
	var layers_cfg: Dictionary = pacing.get("layers", {})
	var category_pools: Dictionary = pacing.get("category_pools", {})
	var rng := SeededRng.new(seed_value)
	var route: Array[Dictionary] = []
	var prev_boss_node: Dictionary = {}
	for layer_number in range(1, 6):
		var cfg: Dictionary = layers_cfg.get(str(layer_number), {})
		var row_bounds: Array = cfg.get("rows", [8, 11])
		var row_count := int(row_bounds[0]) + rng.next_index(maxi(1, int(row_bounds[1]) - int(row_bounds[0]) + 1))
		var anchor_rows := _anchor_rows(cfg, row_count, rng)
		var reserved_templates: Array = []
		for anchor_queue_value in anchor_rows.values():
			for template_value in anchor_queue_value:
				var reserved_template := str(template_value)
				if not reserved_templates.has(reserved_template):
					reserved_templates.append(reserved_template)
		var rows: Array = []
		var layer_category_counts := {}
		for row in range(row_count):
			var count := _row_node_count(rng, cfg, row, row_count)
			var anchor_queue: Array = anchor_rows.get(row, [])
			count = maxi(count, anchor_queue.size())
			var row_nodes: Array = []
			var used_in_row: Array = []
			for index in range(count):
				var template_id := ""
				var revealed := true
				var instance_anchor := false
				if row == row_count - 1:
					template_id = BOSS_NODE_ID if layer_number == 5 else "layer_boss_stand_%d" % layer_number
					instance_anchor = true
				elif not anchor_queue.is_empty():
					template_id = str(anchor_queue.pop_front())
					instance_anchor = true
				else:
					# E2a：分类抽取（层概率 → 分类池 → 层难度过滤 → 伪随机 + 层保底）。
					# 未知类节点地图上迷雾（revealed=false，进入揭示）；锚点保持可见。
					var pick: Dictionary = _pick_category_template(rng, cfg, category_pools,
							node_by_id, layer_number, used_in_row, reserved_templates, layer_category_counts)
					template_id = str(pick.get("id", ""))
					revealed = bool(pick.get("revealed", true))
					var pick_cat := str(pick.get("category", "battle"))
					layer_category_counts[pick_cat] = int(layer_category_counts.get(pick_cat, 0)) + 1
					layer_category_counts["_slots"] = int(layer_category_counts.get("_slots", 0)) + 1
				used_in_row.append(template_id)
				var template: Dictionary = node_by_id.get(template_id, {})
				var instance: Dictionary = template.duplicate(true)
				instance["id"] = instance_id_for(layer_number, row, index)
				instance["template_id"] = template_id
				instance["layer"] = layer_number
				instance["row"] = row
				instance["visible"] = false
				instance["revealed"] = revealed
				# 锚点/行尾固定位标记：地图 UI 与测试据此区分「刻意摆放（保持
				# 可见）」与「随机抽中的未知类（迷雾）」——遗藏等模板两者皆可。
				instance["anchor"] = instance_anchor
				instance["next_ids"] = []
				if layer_number == 1 and row == 0:
					instance["start"] = true
				row_nodes.append(instance)
			rows.append(row_nodes)
		# 行进边：每节点连下一行 1–2 个；下行每节点 ≥1 入边（确定性捐赠）。
		for row in range(row_count - 1):
			var current_row: Array = rows[row]
			var next_row: Array = rows[row + 1]
			for node_value in current_row:
				var node: Dictionary = node_value
				var links := 1
				if next_row.size() > 1 and rng.next_index(100) < 50:
					links = 2
				var picked := {}
				for _link in range(links):
					var pick := rng.next_index(next_row.size())
					while picked.has(pick) and picked.size() < next_row.size():
						pick = (pick + 1) % next_row.size()
					picked[pick] = true
				for pick_key in picked.keys():
					var target_id := str((next_row[int(pick_key)] as Dictionary)["id"])
					if not (node["next_ids"] as Array).has(target_id):
						node["next_ids"].append(target_id)
			for target_value in next_row:
				var target: Dictionary = target_value
				var target_id := str(target["id"])
				var fed := false
				for source_value in current_row:
					if ((source_value as Dictionary)["next_ids"] as Array).has(target_id):
						fed = true
						break
				if not fed and not current_row.is_empty():
					var donor: Dictionary = current_row[_node_rng(seed_value, target_id).next_index(current_row.size())]
					(donor["next_ids"] as Array).append(target_id)
		# 大层接缝：关底 Boss → 下一大层入口行（boss_defeated 门禁在可达层）。
		var boss_node: Dictionary = rows[row_count - 1][0]
		if not prev_boss_node.is_empty():
			for entry_value in rows[0]:
				prev_boss_node["next_ids"].append(str((entry_value as Dictionary)["id"]))
		if layer_number == 5:
			boss_node["next_ids"].append(ASCENSION_NODE_ID)
		prev_boss_node = boss_node
		for row in rows:
			for node_value in row:
				route.append(node_value)
	var window: Dictionary = node_by_id[ASCENSION_NODE_ID].duplicate(true)
	window["visible"] = false
	window["next_ids"] = []
	window["layer"] = 5
	route.append(window)
	return route


static func instance_id_for(layer_number: int, row: int, index: int) -> String:
	return "L%dR%dN%d" % [layer_number, row, index]


static func _rand_between(rng: SeededRng, bounds: Array) -> int:
	var low := int(bounds[0]) if bounds.size() > 0 else 8
	var high := int(bounds[1]) if bounds.size() > 1 else low
	return low + rng.next_index(maxi(1, high - low + 1))


static func _row_node_count(rng: SeededRng, cfg: Dictionary, row: int, row_count: int) -> int:
	if row == row_count - 1:
		return 1
	if row == 0:
		return _rand_between(rng, cfg.get("entry_nodes", [1, 2]))
	return _rand_between(rng, cfg.get("row_nodes", [2, 6]))


## 锚点行分配：裁定表 anchors + 每大层一处黑市 + 每大层一处休整。
## row 语义："mid"=中段行，"pre_boss"=关底 Boss 前一行。
static func _anchor_rows(cfg: Dictionary, row_count: int, rng: SeededRng) -> Dictionary:
	var anchor_rows := {}
	var shop_present := false
	for anchor_value in cfg.get("anchors", []):
		var anchor: Dictionary = anchor_value
		var template_id := str(anchor.get("template", ""))
		if template_id == "ridge_black_market":
			shop_present = true
		var row := _anchor_row_index(str(anchor.get("row", "mid")), row_count)
		if not anchor_rows.has(row):
			anchor_rows[row] = []
		(anchor_rows[row] as Array).append(template_id)
	if not shop_present:
		var row := _anchor_row_index("mid", row_count)
		if not anchor_rows.has(row):
			anchor_rows[row] = []
		(anchor_rows[row] as Array).append("ridge_black_market")
	# 每两行一处休整（第 1、3、5… 行），不占用末端 Boss 行。
	# 2026-09-08：玩家反馈「重复打怪、没提升、摸不到 Boss」——生成图里战斗占比
	# 一度高达 82%，续航/补给密度过低。休整由每三行加密到每两行。
	# 同层交错取两张休整模板，保证长层也有续航节点。
	var rest_index := 0
	for rest_row in range(1, row_count - 1, REST_ROW_STRIDE):
		var rest_template := "rest_hollow" if rest_index % 2 == 0 else "rest_shrine"
		rest_index += 1
		if not anchor_rows.has(rest_row):
			anchor_rows[rest_row] = []
		(anchor_rows[rest_row] as Array).append(rest_template)
	return anchor_rows


static func _anchor_row_index(slot: String, row_count: int) -> int:
	match slot:
		"pre_boss":
			return maxi(1, row_count - 2)
		"quarter":
			return maxi(1, row_count / 4)
		"mid", _:
			return maxi(1, row_count / 2)


## E2a：分类抽取——按本层 category_weights 抽分类 → 分类池按层 stage 过滤 +
## 行内去重/锚点保留 → 均匀伪随机。未知类返回 revealed=false（地图迷雾），
## 锚点/其余分类 true。旧 pool 直选保留为兼容回退（权重表缺失或池为空时）。
## 层保底：随机槽累计 ≥5 时，若某正权重分类本层尚未出现则强制补足，
## 保证每层四分类都有（规格 E2 验收）。
static func _pick_category_template(rng: SeededRng, cfg: Dictionary, category_pools: Dictionary,
		node_by_id: Dictionary, layer_number: int, used_in_row: Array, reserved_templates: Array,
		used_categories: Dictionary) -> Dictionary:
	var cats: Array[String] = ["battle", "rest", "unknown", "trade"]
	var weights: Dictionary = cfg.get("category_weights", {})
	var total := 0
	for cat in cats:
		total += maxi(0, int(weights.get(cat, 0)))
	if total <= 0 or category_pools.is_empty():
		return {"id": _pick_pool_template(rng, cfg.get("pool", []), used_in_row, reserved_templates), "revealed": true, "category": "battle"}
	var picked := "battle"
	var slots_so_far: int = int(used_categories.get("_slots", 0))
	var forced := false
	if slots_so_far >= 5:
		for cat in ["unknown", "rest", "trade", "battle"]:
			if int(weights.get(cat, 0)) > 0 and int(used_categories.get(cat, 0)) == 0:
				picked = cat
				forced = true
				break
	if not forced:
		var roll := rng.next_index(total)
		for cat in cats:
			var w := maxi(0, int(weights.get(cat, 0)))
			if roll < w:
				picked = cat
				break
			roll -= w
	var pool: Array = category_pools.get(picked, [])
	var available: Array = []
	for tid_value in pool:
		var tid := str(tid_value)
		if layer_index(str(node_by_id.get(tid, {}).get("stage", "one"))) > layer_number:
			continue
		if not used_in_row.has(tid) and not reserved_templates.has(tid):
			available.append(tid)
	if available.is_empty():
		for tid_value in pool:
			var tid := str(tid_value)
			if layer_index(str(node_by_id.get(tid, {}).get("stage", "one"))) > layer_number:
				continue
			if not reserved_templates.has(tid):
				available.append(tid)
	if available.is_empty():
		return {"id": _pick_pool_template(rng, cfg.get("pool", []), used_in_row, reserved_templates), "revealed": true, "category": "battle"}
	return {"id": str(available[rng.next_index(available.size())]), "revealed": picked != "unknown", "category": picked}


## 层内模板池抽取；同层内避免重复（池不小于行宽时）。
static func _pick_pool_template(rng: SeededRng, pool: Array, used_in_row: Array, reserved_templates: Array = []) -> String:
	if pool.is_empty():
		return "echo_cave"
	var candidates: Array = []
	for candidate_value in pool:
		var candidate := str(candidate_value)
		if not used_in_row.has(candidate) and not reserved_templates.has(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		for candidate_value in pool:
			var candidate := str(candidate_value)
			if not reserved_templates.has(candidate):
				candidates.append(candidate)
	if candidates.is_empty():
		candidates = pool
	return str(candidates[rng.next_index(candidates.size())])


static func _node_rng(seed_value: int, node_id: String) -> SeededRng:
	return SeededRng.new(SeededRollScript.mixed_seed(seed_value, node_id, 0))


static func _route_from_ids(route_ids: Array, node_by_id: Dictionary) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	var route_id_set := {}
	for route_id_value in route_ids:
		route_id_set[str(route_id_value)] = true
	for index in route_ids.size():
		var node: Dictionary = node_by_id[route_ids[index]].duplicate(true)
		node["visible"] = index <= 1
		# 节点收窄后（2026-09-06）教学链为单入口线性链：仅链首作为
		# trailhead 的 start 节点（旧模板自带双入口 start 契约已移除）。
		node["start"] = index == 0
		node["template_id"] = str(route_ids[index])
		node["layer"] = layer_index(str(node.get("stage", "one")))
		node["row"] = index
		var closed_next_ids: Array = []
		for next_id_value in node.get("next_ids", []):
			var next_id := str(next_id_value)
			if route_id_set.has(next_id) and not closed_next_ids.has(next_id):
				closed_next_ids.append(next_id)
		if index < route_ids.size() - 1:
			if closed_next_ids.is_empty():
				closed_next_ids.append(str(route_ids[index + 1]))
			node["next_ids"] = closed_next_ids
		else:
			node["next_ids"] = []
		route.append(node)
	return route


static func reachable_nodes(route: Array[Dictionary], state: RunState) -> Array[Dictionary]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var origin_id := state.current_node_id
	if origin_id == "trailhead":
		var starts: Array[Dictionary] = []
		for node in route:
			if bool(node.get("start", false)):
				starts.append(node.duplicate(true))
		return starts
	if not by_id.has(origin_id):
		return []
	if not state.node_flags.has(origin_id):
		return []
	# 关底 Boss 门禁：boss_defeated_L{n} 未落账前，Boss 台无路可走
	# （撤退完成节点也不放行——进入下一大层必须真胜）。
	var current_node: Dictionary = by_id[origin_id]
	var layer_boss := int(current_node.get("layer_boss", 0))
	if layer_boss > 0 and not state.node_flags.has("boss_defeated_L%d" % layer_boss):
		return []
	var reachable: Array[Dictionary] = []
	for next_id in by_id[origin_id].get("next_ids", []):
		if by_id.has(str(next_id)):
			reachable.append(by_id[str(next_id)].duplicate(true))
	return reachable


static func visible_nodes(route: Array[Dictionary], state: RunState, forward_layers: int = 1) -> Array[Dictionary]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var visible_ids := {}
	var reachable_ids := {}
	for node in route:
		var node_id := str(node["id"])
		if bool(node.get("start", false)) or state.node_flags.has(node_id):
			visible_ids[node_id] = true
	var frontier: Array[Dictionary] = reachable_nodes(route, state)
	for node in frontier:
		var frontier_id := str(node["id"])
		visible_ids[frontier_id] = true
		# R-map-visibility 2026-08-27: only immediate neighbors are travelable;
		# deeper lookahead stays advisory so the map can dim what is out of
		# reach instead of inviting rejected travel commands.
		reachable_ids[frontier_id] = true
	for _layer in forward_layers:
		var next_frontier: Array[Dictionary] = []
		for node in frontier:
			for next_id_value in node.get("next_ids", []):
				var next_id := str(next_id_value)
				if not by_id.has(next_id):
					continue
				visible_ids[next_id] = true
				next_frontier.append(by_id[next_id])
		frontier = next_frontier
	var visible: Array[Dictionary] = []
	for node in route:
		if visible_ids.has(str(node["id"])):
			var shown := node.duplicate(true)
			shown["reachable"] = reachable_ids.has(str(node["id"]))
			visible.append(shown)
	return visible


static func visible_node_ids(route: Array[Dictionary], state: RunState, forward_layers: int = 1) -> Array[String]:
	var ids: Array[String] = []
	for node in visible_nodes(route, state, forward_layers):
		ids.append(str(node["id"]))
	return ids


static func tree_columns(route: Array[Dictionary]) -> Array[Array]:
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	var columns: Array[Array] = []
	var visited := {}
	var frontier: Array[String] = []
	for node in route:
		if bool(node.get("start", false)):
			frontier.append(str(node["id"]))
	while not frontier.is_empty():
		var column: Array = []
		var next_frontier: Array[String] = []
		for node_id in frontier:
			if visited.has(node_id) or not by_id.has(node_id):
				continue
			visited[node_id] = true
			var node: Dictionary = by_id[node_id]
			column.append(node.duplicate(true))
			for next_id in node.get("next_ids", []):
				var next_key := str(next_id)
				if not visited.has(next_key) and not next_frontier.has(next_key):
					next_frontier.append(next_key)
		if not column.is_empty():
			columns.append(column)
		frontier = next_frontier
	return columns


static func _load_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data


# W7（2026-09-09）：无 catalog 时直读文件属绕过内容目录的旁路（可能取到未经
# ContentCatalog.validate 校验的数据，且与目录侧两份数据源不一致时无人报警）。
# 生产路径总是经 build(catalog=...) 传入；此告警只会在测试/工具裸调静态函数时出现。
static func _load_json_fallback(via: String, path: String) -> Dictionary:
	push_warning("MapGenerator.%s fell back to a direct file read (no catalog passed): %s" % [via, path])
	return _load_json(path)


static func _index_nodes(nodes: Array) -> Dictionary:
	var indexed := {}
	for node in nodes:
		indexed[node["id"]] = node
	return indexed
