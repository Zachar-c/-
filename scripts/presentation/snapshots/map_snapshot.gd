class_name MapSnapshot
extends RefCounted


# W12 split: the Map screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; multi-screen shared helpers
# stay on RunSnapshotBuilder and are called via the global class name.


const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
const SocialCommandRulesScript = preload("res://scripts/domain/social_command_rules.gd")
const BuildGoalProjectionScript = preload("res://scripts/presentation/snapshots/build_goal_projection.gd")


static func build(controller) -> Dictionary:
	var state = controller.state
	var route: Array = controller.route
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	# Playable Core Loop（2026-09-15）Phase 2：构筑目标只读投影 + 逐节点相关性。
	# 目标只算一次，逐节点复用，避免 O(nodes × recipes)。
	var build_goal: Dictionary = BuildGoalProjectionScript.build_goal(state, catalog)
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
			# Phase 2：与当前构筑目标的关系（只读派生，不承诺掉落、不泄露未揭示内容）。
			"build_relevance": BuildGoalProjectionScript.node_relevance(n, state, catalog, build_goal),
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
		# Playable Core Loop Phase 2：地图上的「当前构筑目标」区（只读投影）。
		"build_goal": build_goal,
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
			# 收官抉择（2026-09-15）：判据直调领域层唯一实现，避免按钮与规则漂移。
			"closure_available": SocialCommandRulesScript.closure_available(state, catalog),
			"closure_hint": _closure_hint(state, catalog),

	}


## 收官提示文案（只读）。层名取 pacing.layers.<stage>.title，缺失时回退空串。
static func _closure_hint(state, catalog: Dictionary) -> String:
	if not SocialCommandRulesScript.closure_available(state, catalog):
		return ""
	var stage := str((catalog.get("pacing", {}) as Dictionary).get("ending_after_stage", ""))
	if stage.is_empty():
		stage = "one"
	# pacing.layers 以层序数字为键（"1".."5"），ending_after_stage 存层名
	# （"one".."five"）——必须经 layer_index 换算，不能直接拿层名索引。
	var layers: Dictionary = ((catalog.get("pacing", {}) as Dictionary).get("layers", {}) as Dictionary)
	var stage_index := MapGeneratorScript.layer_index(stage)
	var layer_title := str((layers.get(str(stage_index), {}) as Dictionary).get("title", ""))
	if layer_title.is_empty():
		return "已可主动收官——继续深入，或就此了结本局。"
	return "「%s」已平定——可继续深入，或就此收官了结本局。" % layer_title


static func _map_visibility(node: Dictionary, state) -> String:
	var node_id := str(node.get("id", ""))
	if node_id == str(state.current_node_id):
		return "current"
	if state.node_flags.has(node_id):
		return "past"
	if bool(node.get("reachable", false)):
		return "reachable"
	return "lookahead"
