extends GutTest


## 地图已迁到 Godot 官方 .tscn 节点树（scenes/ui/screens/map_screen.tscn），
## 挂载走 TscnMountHelper.instantiate + mount_snapshot；节点命名沿用
## HTML 骨架的 snake_case，断言无需改名。
const MAP_SCREEN_TSCN := "res://scenes/ui/screens/map_screen.tscn"

var _hosts: Array = []


func after_each() -> void:
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_hosts.clear()


func _controller() -> RunController:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func test_map_snapshot_preserves_branches_and_visibility_roles() -> void:
	var controller := _controller()
	var snapshot: Dictionary = controller._snapshot_for("Map")
	var nodes: Array = snapshot.get("nodes", [])
	assert_false(nodes.is_empty())
	assert_true(nodes.all(func(node): return node.has("next_ids") and node.has("visibility")))
	assert_true(nodes.any(func(node): return str(node.get("visibility", "")) == "lookahead" and not bool(node.get("reachable", false))))


func test_map_screen_summarizes_history_and_keeps_reachable_travel_only() -> void:
	var snapshot := {
		"nodes": [
			{"id": "past_a", "type": "event", "label": "旧路", "layer": 1, "next_ids": ["current"], "reachable": false, "visited": true, "current": false, "visibility": "past"},
			{"id": "past_b", "type": "shop", "label": "岔路", "layer": 1, "next_ids": ["current"], "reachable": false, "visited": true, "current": false, "visibility": "past"},
			{"id": "current", "type": "combat", "label": "当前", "layer": 2, "next_ids": ["near"], "reachable": false, "visited": true, "current": true, "visibility": "current"},
			{"id": "near", "type": "rest", "label": "可达", "layer": 3, "next_ids": ["far"], "reachable": true, "visited": false, "current": false, "visibility": "reachable"},
			{"id": "far", "type": "event", "label": "前瞻", "layer": 4, "next_ids": [], "reachable": false, "visited": false, "current": false, "visibility": "lookahead"},
		],
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {}, "gu_satchel": [], "toast": "",
	}
	var host := _mount(snapshot)
	for _frame in 3:
		await get_tree().process_frame
	assert_true(_has_text(host, "再前一程"))
	assert_false(_has_text(host, "旧路"))
	assert_false(_has_text(host, "岔路"))
	assert_true(_has_text(host, "可达"))
	assert_true(_has_text(host, "前瞻"))


func test_map_matches_approved_focused_route_camera_composition() -> void:
	var snapshot := _route_snapshot()
	var host := _mount_with_commands(snapshot, {"travel": func(_id): pass, "view_node": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var mast := _named(host, "map_mast")
	var markers := _named(host, "map_markers")
	var title := _named(host, "map_title")
	var camera := _named(host, "map_camera")
	var world := _named(host, "map_world")
	var depth := _named(host, "map_depth")
	var paths := _named(host, "map_paths")
	var inspector := _named(host, "map_inspector")
	assert_not_null(mast, "map HTML has an absolute masthead")
	assert_not_null(markers, "map HTML has a marker row below the masthead")
	assert_not_null(title, "map HTML has a separate route title layer")
	assert_not_null(camera, "map master needs a bounded route camera")
	assert_not_null(world, "map master needs a world larger than its camera")
	assert_not_null(depth, "map HTML keeps a left depth rail inside the camera")
	assert_not_null(paths, "map master needs visible route connections")
	assert_not_null(inspector, "map master needs a quiet selected-node inspector")
	if mast == null or markers == null or title == null or camera == null or world == null or depth == null or inspector == null:
		return
	assert_almost_eq(mast.get_global_rect().position, Vector2(30, 20), Vector2(3, 3))
	assert_almost_eq(markers.get_global_rect().position, Vector2(31, 80), Vector2(3, 3))
	assert_almost_eq(title.get_global_rect().position, Vector2(host.size.x * 0.055, 110), Vector2(4, 4))
	assert_almost_eq(camera.get_global_rect().position, Vector2(host.size.x * 0.055, 158), Vector2(4, 4))
	assert_almost_eq(camera.get_global_rect().end.y, host.size.y - 92.0, 4.0)
	assert_almost_eq(world.get_global_rect().size.y, 970.0, 3.0, "route world keeps the HTML 970px topology scale")
	assert_almost_eq(world.get_global_rect().end.y, camera.get_global_rect().end.y - 1.0, 4.0, "route world is bottom-aligned inside the camera")
	assert_almost_eq(depth.get_global_rect().position, camera.get_global_rect().position, Vector2(4, 4))
	assert_almost_eq(depth.get_global_rect().size.x, 58.0, 3.0)
	assert_almost_eq(inspector.get_global_rect().position.y, host.size.y - 72.0, 4.0)
	assert_almost_eq(inspector.get_global_rect().size.y, 48.0, 3.0)
	assert_gte(_named_controls(host, "map_path_segment_").size(), 6, "route canvas exposes every visible topology link")
	assert_true(_has_text(host, "当前所在"))
	assert_true(_has_text(host, "下一程"))
	assert_true(_has_text(host, "再前一程"))


func test_map_uses_html_palette_and_circled_node_marks() -> void:
	var host := _mount_with_commands(_route_snapshot(), {"travel": func(_id): pass, "view_node": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var paper := _named(host, "map_paper") as ColorRect
	var elite_mark := _named(host, "map_node_mark_elite")
	var elite_icon := _named(host, "map_node_mark_label_elite") as Label
	var market_icon := _named(host, "map_node_mark_label_market") as Label
	var event_icon := _named(host, "map_node_mark_label_event") as Label
	var rest_icon := _named(host, "map_node_mark_label_rest") as Label
	var combat_icon := _named(host, "map_node_mark_label_current") as Label
	assert_not_null(paper, "map must own its HTML paper color instead of inheriting the global token")
	assert_not_null(elite_mark, "node marks must retain the HTML circle container")
	assert_not_null(elite_icon, "elite icon must be inspectable against the approved HTML")
	assert_not_null(market_icon, "market icon must be inspectable against the approved HTML")
	assert_not_null(event_icon, "event icon must be inspectable against the approved HTML")
	assert_not_null(rest_icon, "rest icon must be inspectable against the approved HTML")
	assert_not_null(combat_icon, "combat icon must be inspectable against the approved HTML")
	if paper == null or elite_mark == null or elite_icon == null or market_icon == null or event_icon == null or rest_icon == null or combat_icon == null:
		return
	assert_eq(paper.color, Color("e7e4da"))
	assert_almost_eq(elite_mark.get_global_rect().size, Vector2(30, 30), Vector2(1, 1))
	assert_eq(elite_icon.text, "險", "elite must keep the approved route-map mark")
	assert_eq(market_icon.text, "市", "market must keep the approved route-map mark")
	assert_eq(event_icon.text, "？", "unknown event must keep the approved route-map mark")
	assert_eq(rest_icon.text, "息", "rest must keep the approved route-map mark")
	assert_eq(combat_icon.text, "鬥", "ordinary combat must keep the approved route-map mark")


func test_map_node_rects_match_the_approved_html_icon_layout() -> void:
	var host := _mount_with_commands(_route_snapshot(), {"travel": func(_id): pass, "view_node": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var current_node := _named(host, "map_node_current")
	var candidate_node := _named(host, "map_node_elite")
	var future_node := _named(host, "map_node_rest")
	assert_not_null(current_node, "current route node must be available for master-size verification")
	assert_not_null(candidate_node, "candidate route node must be available for master-size verification")
	assert_not_null(future_node, "future route node must be available for master-size verification")
	if current_node == null or candidate_node == null or future_node == null:
		return
	assert_almost_eq(current_node.get_global_rect().size, Vector2(192, 126), Vector2(1, 1), "current node must retain the HTML height that centers its icon row")
	assert_almost_eq(candidate_node.get_global_rect().size, Vector2(192, 126), Vector2(1, 1), "candidate node must retain the HTML height that centers its icon row")
	assert_almost_eq(future_node.get_global_rect().size, Vector2(168, 108), Vector2(1, 1), "future node must retain the HTML height that centers its icon row")


func test_map_visible_nodes_in_same_layer_do_not_overlap() -> void:
	var snapshot := _route_snapshot()
	snapshot["nodes"].append_array([
		{"id": "elite_b", "type": "combat", "label": "第二精英", "layer": 63, "next_ids": [], "reachable": true, "visibility": "reachable"},
		{"id": "elite_c", "type": "combat", "label": "第三精英", "layer": 63, "next_ids": [], "reachable": true, "visibility": "reachable"},
	])
	var host := _mount_with_commands(snapshot, {"travel": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var nodes: Array[Control] = []
	for id in ["market", "elite", "event", "elite_b", "elite_c"]:
		var node := _named(host, "map_node_" + id)
		assert_not_null(node, "same-layer node must render: %s" % id)
		if node != null:
			nodes.append(node)
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			assert_false(nodes[i].get_global_rect().intersects(nodes[j].get_global_rect()), "same-layer map nodes must not overlap")


func test_map_anchors_bands_on_current_node_after_skipping_sibling() -> void:
	# 2026-09-02 地图阻塞报告：玩家跳过同层兄弟起点（如 first_run 脊柱里
	# 中立散修 / 山脊商队 二选一）后，可见行取「最小三行」会把当前节点挤进
	# 中部带、真正可达的后继顶进顶部前瞻带——那里被 map_camera
	# clip_contents 裁掉大半，玩家点不到后继（抵达被阻塞）。
	# 三条带必须锚定当前节点行：此刻=当前、下一程=可达后继、再前一程=前瞻。
	var view := preload("res://scripts/presentation/screens/map_screen_view.gd")
	var snapshot := {
		"nodes": [
			{"id": "sibling", "type": "event", "label": "中立散修", "layer": 1, "row": 0, "next_ids": [], "reachable": false, "visited": false, "current": false, "visibility": "lookahead"},
			{"id": "current", "type": "market", "label": "山脊商队", "layer": 1, "row": 1, "next_ids": ["next"], "reachable": false, "visited": true, "current": true, "visibility": "current"},
			{"id": "next", "type": "refinement", "label": "炼蛊石穴", "layer": 2, "row": 0, "next_ids": [], "reachable": true, "visited": false, "current": false, "visibility": "reachable"},
		],
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {}, "gu_satchel": [], "toast": "",
	}
	var submitted: Array[String] = []
	var host := _mount_with_commands(snapshot, {"travel": func(id): submitted.append(str(id))})
	for _frame in 3:
		await get_tree().process_frame
	var current_btn := _named(host, "map_node_current")
	var next_btn := _named(host, "map_node_next") as Button
	assert_not_null(current_btn, "current node must render")
	assert_not_null(next_btn, "reachable successor must render")
	if current_btn == null or next_btn == null:
		return
	assert_almost_eq(current_btn.position.y, view.CURRENT_Y, 2.0, "current node must stay in the now band")
	assert_almost_eq(next_btn.position.y, view.CANDIDATE_Y, 2.0, "reachable successor must stay in the clickable candidate band, not the clipped future band")
	next_btn.pressed.emit()
	assert_eq(submitted, ["next"])


func test_map_reachable_node_click_submits_travel_command() -> void:
	var submitted: Array[String] = []
	var host := _mount_with_commands(_route_snapshot(), {"travel": func(id): submitted.append(str(id))})
	for _frame in 3:
		await get_tree().process_frame
	var node := _named(host, "map_node_elite") as Button
	assert_not_null(node)
	if node != null:
		node.pressed.emit()
		node.pressed.emit()
	assert_eq(submitted, ["elite"], "one rendered route node must submit travel once per snapshot")


func test_map_routes_fill_the_route_world_at_runtime() -> void:
	var host := _mount_with_commands(_route_snapshot(), {"travel": func(_id): pass, "view_node": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var world := _named(host, "map_world")
	var routes := _named(host, "map_routes")
	assert_not_null(world, "route world must be mounted before inspecting its runtime geometry")
	assert_not_null(routes, "route container must be mounted before inspecting its runtime geometry")
	if world == null or routes == null:
		return
	assert_almost_eq(routes.get_global_rect().size.y, world.get_global_rect().size.y, 3.0, "routes must fill the HTML world height so route labels, paths, and nodes share one visible topology canvas")


func test_map_current_and_candidate_nodes_intersect_the_route_camera() -> void:
	var host := _mount_with_commands(_route_snapshot(), {"travel": func(_id): pass, "view_node": func(_id): pass})
	for _frame in 3:
		await get_tree().process_frame
	var camera := _named(host, "map_camera")
	var current_node := _named(host, "map_node_current")
	var candidate_node := _named(host, "map_node_elite")
	assert_not_null(camera, "the route camera must be mounted before visibility can be checked")
	assert_not_null(current_node, "the current route node must be mounted before visibility can be checked")
	assert_not_null(candidate_node, "a reachable route node must be mounted before visibility can be checked")
	if camera == null or current_node == null or candidate_node == null:
		return
	assert_true(current_node.get_global_rect().intersects(camera.get_global_rect()), "the HTML l62 current node must remain inside the visible route camera")
	assert_true(candidate_node.get_global_rect().intersects(camera.get_global_rect()), "the HTML l63 candidate node must remain inside the visible route camera")


func test_map_all_reachable_nodes_are_fully_visible_at_compact_viewport() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(MAP_SCREEN_TSCN, _route_snapshot(), {"travel": func(_id): pass}))
	for _frame in 3:
		await get_tree().process_frame
	var camera := _named(host, "map_camera")
	assert_not_null(camera)
	if camera == null:
		return
	for node_name in ["map_node_market", "map_node_elite", "map_node_event"]:
		var node := _named(host, node_name)
		assert_not_null(node, "%s must render" % node_name)
		if node != null:
			assert_true(camera.get_global_rect().encloses(node.get_global_rect()),
					"%s must be fully exposed for a real mouse click" % node_name)


func test_map_anomaly_badge_renders_label_not_raw_dict() -> void:
	# R14.6 险象/衰运徽章：真实快照的 anomalies 是 {id,label} 字典，map 主屏
	# 只能露玩家可读 label；sys: id 与字典结构都不得泄漏（§16.5）。
	var snapshot := _route_snapshot()
	snapshot["anomalies"] = [{"id": "sys:dda_peril", "label": "险象"}]
	var host := _mount(snapshot)
	for _frame in 3:
		await get_tree().process_frame
	assert_true(_has_text(host, "异变 · 险象"), "anomaly badge must render the readable label")
	assert_false(_has_text(host, "sys:dda_peril"), "marker id must never leak to the map")
	assert_false(_has_text(host, "{"), "raw dict structure must never leak to the map")

	# 字符串形态（旧快照/测试桩）保持兼容。
	var string_snapshot := _route_snapshot()
	string_snapshot["anomalies"] = ["衰运"]
	var string_host := _mount(string_snapshot)
	for _frame in 3:
		await get_tree().process_frame
	assert_true(_has_text(string_host, "异变 · 衰运"))


func test_map_title_binds_real_zone_depth_realm() -> void:
	# P0-4 谎言回归拦截：屏面地带/深度/境界必须来自快照（pacing.layers.title +
	# 当前层 + cultivation），快照没给就不渲染——旧硬编码「青茅山外圍 /
	# 深度 62 · 四轉初階」不得再出现。
	var snapshot := _route_snapshot()
	snapshot["zone_title"] = "落瘴岭"
	snapshot["depth_label"] = "第 2 大层"
	snapshot["realm_label"] = "二转"
	var host := _mount(snapshot)
	for _frame in 3:
		await get_tree().process_frame
	assert_true(_has_text(host, "落瘴岭"), "zone title must come from the snapshot")
	assert_true(_has_text(host, "第 2 大层 · 二转"), "depth and realm must render from the snapshot")
	assert_false(_has_text(host, "深度 62"), "hardcoded fake depth must never return")
	assert_false(_has_text(host, "四轉初階"), "hardcoded fake realm must never return")

	var bare := _route_snapshot()
	var bare_host := _mount(bare)
	for _frame in 3:
		await get_tree().process_frame
	assert_false(_has_text(bare_host, "青茅山外圍"), "no zone title may render when the snapshot ships none")
	assert_false(_has_text(bare_host, "map_depth_65"), "legacy depth numerals must stay gone")


func test_map_depth_rail_binds_visible_layer_numbers() -> void:
	# 刻度显示快照里的真实层号（底带=当前层 62、中带=下一层 63、顶带=64）；
	# 旧 65/64/63/62 死数字不再出现。
	var snapshot := _route_snapshot()
	var host := _mount(snapshot)
	for _frame in 3:
		await get_tree().process_frame
	var now_label := _named(host, "map_depth_label_now")
	var near_label := _named(host, "map_depth_label_near")
	var far_label := _named(host, "map_depth_label_far")
	assert_true(now_label != null and str((now_label as Label).text) == "62",
			"bottom rail numeral must be the current layer number from the snapshot")
	assert_true(near_label != null and str((near_label as Label).text) == "63",
			"middle rail numeral must be the next layer number")
	assert_true(far_label != null and str((far_label as Label).text) == "64",
			"top rail numeral must be the far layer number")


func _route_snapshot() -> Dictionary:
	return {
		"nodes": [
			{"id": "past", "type": "event", "label": "旧路", "layer": 61, "next_ids": ["current"], "reachable": false, "visibility": "past"},
			{"id": "current", "type": "combat", "label": "当前所在", "layer": 62, "next_ids": ["market", "elite", "event"], "reachable": false, "visibility": "current"},
			{"id": "market", "type": "market", "label": "黑市商队", "layer": 63, "next_ids": ["rest"], "reachable": true, "visibility": "reachable"},
			{"id": "elite", "type": "combat", "label": "雷泽伏杀", "layer": 63, "next_ids": ["rest", "shop"], "reachable": true, "visibility": "reachable", "enemy_kind": "resolute_elite"},
			{"id": "event", "type": "event", "label": "无名异闻", "layer": 63, "next_ids": ["shop"], "reachable": true, "visibility": "reachable"},
			{"id": "rest", "type": "rest", "label": "荒寺休整", "layer": 64, "next_ids": [], "reachable": false, "visibility": "lookahead"},
			{"id": "shop", "type": "shop", "label": "百虫黑市", "layer": 64, "next_ids": [], "reachable": false, "visibility": "lookahead"},
		],
		"resources": {"yuanstone": 128, "shouyuan": 41, "hunpo": 7},
		"contracts": ["孤注"], "anomalies": ["衰运"], "death_lines": {}, "gu_satchel": [], "toast": "",
	}


func _mount(snapshot: Dictionary) -> Control:
	return _mount_with_commands(snapshot, {})


func _mount_with_commands(snapshot: Dictionary, commands: Dictionary) -> Control:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(MAP_SCREEN_TSCN, snapshot, commands))
	return host


func _has_text(node: Node, wanted: String) -> bool:
	if node is Label and str(node.text).contains(wanted):
		return true
	if node is Button and str(node.text).contains(wanted):
		return true
	for child in node.get_children():
		if _has_text(child, wanted):
			return true
	return false


func _named(node: Node, wanted: String) -> Control:
	if node.name == wanted and node is Control:
		return node as Control
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _named_controls(node: Node, prefix: String) -> Array[Control]:
	var found: Array[Control] = []
	if node is Control and str(node.name).begins_with(prefix):
		found.append(node as Control)
	for child in node.get_children():
		found.append_array(_named_controls(child, prefix))
	return found


func _assert_label_color(host: Control, label_name: String, expected: Color) -> void:
	var label := _named(host, label_name) as Label
	assert_not_null(label, "map master needs named visible text: %s" % label_name)
	if label != null:
		assert_true(label.get_theme_color("font_color").is_equal_approx(expected), "%s must use its exact map HTML color" % label_name)
