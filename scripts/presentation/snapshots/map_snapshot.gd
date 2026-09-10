class_name MapSnapshot
extends RefCounted


# W12 split: the Map screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; multi-screen shared helpers
# stay on RunSnapshotBuilder and are called via the global class name.


const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")


static func build(controller) -> Dictionary:
	var state = controller.state
	var route: Array = controller.route
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var nodes: Array[Dictionary] = []
	# 2026-08-28 验收批 P0-4：地带/深度/境界改由真实状态导出（旧屏面是
	# 「青茅山外圍 / 深度 62 · 四轉初階」硬编码谎言）。zone_title 取
	# pacing.layers[当前层].title，缺失为空串由屏面隐藏。
	var current_id := str(state.current_node_id)
	var current_layer := 0
	var visible_by_id := {}
	for n in MapGeneratorScript.visible_nodes(route, state, 2):
		visible_by_id[str(n.get("id", ""))] = n
	# 当前节点可能尚未完成、不在 visited 中，确保它始终进入快照。
	if not visible_by_id.has(current_id):
		for route_node in route:
			if str(route_node.get("id", "")) == current_id:
				visible_by_id[current_id] = route_node.duplicate(true)
				visible_by_id[current_id]["reachable"] = false
				break
	for node_id in visible_by_id:
		var n: Dictionary = visible_by_id[node_id]
		if node_id == current_id:
			current_layer = int(n.get("layer", 0))
		nodes.append({
			"id": node_id,
			"type": str(n.get("type", "")),
			"label": RunSnapshotBuilder._node_label(n),
			"layer": int(n.get("layer", 0)),
			"row": int(n.get("row", 0)),
			"next_ids": Array(n.get("next_ids", [])).duplicate(),
			"reachable": bool(n.get("reachable", false)),
			"visited": state.node_flags.has(node_id),
			"current": node_id == current_id,
			"visibility": _map_visibility(n, state),
			"revealed": bool(n.get("revealed", true)),
		})
	nodes.sort_custom(func(a, b): return int(a.get("layer", 0)) * 1000 + int(a.get("row", 0)) < int(b.get("layer", 0)) * 1000 + int(b.get("row", 0)))
	var reach: Array[String] = []
	for n in MapGeneratorScript.reachable_nodes(route, state):
		reach.append(str(n["id"]))
	var gu_satchel: Array[Dictionary] = []
	for inst_key in state.gu_instances:
		var inst: Dictionary = state.gu_instances[inst_key]
		gu_satchel.append({
			"id": str(inst_key),
			"name": DisplayText.gu(str(inst.get("definition_id", ""))),
		})
	var zone_title := ""
	var depth_label := ""
	if current_layer > 0:
		zone_title = str(catalog.get("pacing", {}).get("layers", {}).get(str(current_layer), {}).get("title", ""))
		depth_label = "第 %d 大层" % current_layer
	var realm_label := ""
	var cultivation := int(state.cultivation) if state != null else 0
	if cultivation >= 1 and cultivation <= 5:
		realm_label = "%s转" % ["一", "二", "三", "四", "五"][cultivation - 1]
	return {
		"nodes": nodes,
		"current_node_id": str(state.current_node_id),
		"reachable_ids": reach,
		"gu_satchel": gu_satchel,
		"inventory": RunSnapshotBuilder._inventory(state, catalog),
		"zone_title": zone_title,
		"depth_label": depth_label,
			"realm_label": realm_label,
			# D4 存档 Toast（R1.5）：文本来自控制器反馈，空串则不渲染。
			"toast": str(controller.last_feedback),
			"resources": RunSnapshotBuilder._resources(state),
			"contracts": RunSnapshotBuilder._contracts(state, catalog),
			"anomalies": DdaResolverScript.marker_meta(state, catalog),
			"death_lines": RunSnapshotBuilder._death_lines(state),
			"leave_confirm": bool(controller.get("_map_leave_confirm")) if controller != null else false,

	}


static func _map_visibility(node: Dictionary, state) -> String:
	var node_id := str(node.get("id", ""))
	if node_id == str(state.current_node_id):
		return "current"
	if state.node_flags.has(node_id):
		return "past"
	if bool(node.get("reachable", false)):
		return "reachable"
	return "lookahead"
