extends GutTest


## 地图已迁到 Godot 官方 .tscn 节点树（scenes/ui/screens/map_screen.tscn），
## 挂载走 TscnMountHelper.instantiate + mount_snapshot。
const MAP_SCREEN_TSCN := "res://scenes/ui/screens/map_screen.tscn"

var _hosts: Array = []


func after_each() -> void:
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.queue_free()
	_hosts.clear()


func test_real_layer_rows_do_not_overlap_and_each_node_renders_once() -> void:
	var snapshot := {
		"nodes": [
			{"id": "current", "type": "event", "label": "当前", "layer": 1, "row": 3, "next_ids": ["event_a", "shop_a"], "reachable": false, "visibility": "current"},
			{"id": "event_a", "type": "event", "label": "异闻甲", "layer": 1, "row": 4, "next_ids": ["rest_a"], "reachable": true, "visibility": "reachable"},
			{"id": "shop_a", "type": "shop", "label": "黑市甲", "layer": 1, "row": 4, "next_ids": ["rest_b"], "reachable": true, "visibility": "reachable"},
			{"id": "rest_a", "type": "rest", "label": "休整甲", "layer": 1, "row": 5, "next_ids": [], "reachable": false, "visibility": "lookahead"},
			{"id": "rest_b", "type": "rest", "label": "休整乙", "layer": 1, "row": 5, "next_ids": [], "reachable": false, "visibility": "lookahead"},
		],
		"resources": {"yuanstone": 10, "shouyuan": 20, "hunpo": 3, "material": 7},
		"contracts": [], "anomalies": [], "death_lines": {}, "gu_satchel": [], "toast": "",
	}
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(MAP_SCREEN_TSCN, snapshot, {"travel": func(_id): pass}))
	for _i in 3:
		await get_tree().process_frame
	var names := ["current", "event_a", "shop_a", "rest_a", "rest_b"]
	var controls: Array[Control] = []
	for id in names:
		var node := _named(host, "map_node_" + id)
		assert_not_null(node, "node must render: %s" % id)
		if node != null:
			controls.append(node)
	for i in controls.size():
		for j in range(i + 1, controls.size()):
			assert_false(controls[i].get_global_rect().intersects(controls[j].get_global_rect()), "row/layer nodes must not overlap")
	var count := 0
	for node in host.find_children("*", "Button", true, false):
		if str(node.name).begins_with("map_node_") and str(node.name) != "map_node_":
			count += 1
	assert_eq(count, 5)


func test_reachable_event_button_submits_its_own_id() -> void:
	var submitted: Array[String] = []
	var snapshot := {
		"nodes": [
			{"id": "current", "type": "combat", "label": "此刻", "layer": 1, "row": 2, "next_ids": ["event_a"], "reachable": false, "visibility": "current"},
			{"id": "event_a", "type": "event", "label": "异闻甲", "layer": 1, "row": 3, "next_ids": [], "reachable": true, "visibility": "reachable"},
		],
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {}, "gu_satchel": [], "toast": "",
	}
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(MAP_SCREEN_TSCN, snapshot, {"travel": func(id): submitted.append(str(id))}))
	for _i in 3:
		await get_tree().process_frame
	var event_button := _named(host, "map_node_event_a") as Button
	assert_not_null(event_button)
	if event_button != null:
		event_button.pressed.emit()
	assert_eq(submitted, ["event_a"])


func test_map_hud_hides_material_but_keeps_other_global_resources() -> void:
	var snapshot := {
		"nodes": [{"id": "current", "type": "event", "label": "此刻", "layer": 1, "row": 0, "next_ids": [], "reachable": false, "visibility": "current"}],
		"resources": {"yuanstone": 10, "shouyuan": 20, "hunpo": 3, "material": 7},
		"contracts": [], "anomalies": [], "death_lines": {}, "gu_satchel": [], "toast": "",
	}
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(MAP_SCREEN_TSCN, snapshot, {}))
	for _i in 3:
		await get_tree().process_frame
	for id in ["yuanstone", "shouyuan", "hunpo"]:
		assert_not_null(_named(host, "map_resource_value_" + id))
	assert_null(_named(host, "map_resource_value_material"))
	assert_null(_named(host, "map_resource_name_material"))


func _named(node: Node, wanted: String) -> Control:
	if node is Control and node.name == wanted:
		return node as Control
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _named_controls(node: Node, prefix: String) -> Array[Control]:
	var found: Array[Control] = []
	if node is Control and str(node.name).begins_with(prefix) and str(node.name) != prefix:
		found.append(node as Control)
	for child in node.get_children():
		found.append_array(_named_controls(child, prefix))
	return found
