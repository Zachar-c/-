extends SceneTree

## 调试：打印地图节点实际全局 rect 与 camera rect，确认再前行是否在镜头内。
const MapScene := "res://scenes/ui/screens/map_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"zone_title": "青茅山外围", "depth_label": "第 3 大层", "realm_label": "四转",
		"resources": {"yuanstone": 12, "shouyuan": 78, "hunpo": 5},
		"contracts": [], "anomalies": [], "gu_satchel": [], "inventory": {}, "toast": "",
		"current_node_id": "rest_hollow",
		"nodes": [
			{"id": "rest_hollow", "type": "rest", "label": "休整", "layer": 3, "row": 1, "next_ids": ["sentinel", "black_market", "refine_hollow"], "reachable": false, "visited": true, "current": true, "visibility": "current"},
			{"id": "sentinel", "type": "combat", "label": "巡哨", "layer": 4, "row": 0, "next_ids": ["yizang"], "reachable": true, "visited": false, "current": false, "visibility": "reachable"},
			{"id": "black_market", "type": "market", "label": "黑市", "layer": 4, "row": 0, "next_ids": ["hazard_trail"], "reachable": true, "visited": false, "current": false, "visibility": "reachable"},
			{"id": "refine_hollow", "type": "refinement", "label": "炼蛊洞", "layer": 4, "row": 0, "next_ids": ["moss_grove"], "reachable": true, "visited": false, "current": false, "visibility": "reachable"},
			{"id": "yizang", "type": "inheritance", "label": "遗葬", "layer": 5, "row": 0, "next_ids": [], "reachable": false, "visited": false, "current": false, "visibility": "lookahead"},
			{"id": "hazard_trail", "type": "hazard", "label": "毒瘴山路", "layer": 5, "row": 0, "next_ids": [], "reachable": false, "visited": false, "current": false, "visibility": "lookahead"},
			{"id": "moss_grove", "type": "wild_gu", "label": "血苔林", "layer": 5, "row": 0, "next_ids": [], "reachable": false, "visited": false, "current": false, "visibility": "lookahead"},
		],
	}
	var cmds := {"travel": Callable(self, "_noop"), "view_node": Callable(self, "_noop"), "save_run": Callable(self, "_noop"), "back_to_hall": Callable(self, "_noop")}
	var map: Control = (load(MapScene) as PackedScene).instantiate()
	root.add_child(map)
	map.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	await process_frame
	var camera := _find(map, "map_camera")
	var world := _find(map, "map_world")
	print("CAMERA rect=" + str(camera.get_global_rect()))
	print("WORLD  rect=" + str(world.get_global_rect()))
	for n in ["map_node_rest_hollow", "map_node_sentinel", "map_node_black_market", "map_node_refine_hollow", "map_node_yizang", "map_node_hazard_trail", "map_node_moss_grove"]:
		var node := _find(map, n)
		if node == null:
			print(n + " = NULL")
		else:
			print(n + " rect=" + str(node.get_global_rect()) + " visible=" + str(camera.get_global_rect().intersects(node.get_global_rect())))
	var ver := _find(map, "map_build_ver")
	if ver == null:
		print("map_build_ver = NULL")
	else:
		print("map_build_ver rect=" + str(ver.get_global_rect()) + " visible=" + str(ver.visible) + " text=" + str((ver as Label).text))
	var rule := _find(map, "map_title_rule")
	if rule == null:
		print("map_title_rule = NULL")
	else:
		print("map_title_rule rect=" + str(rule.get_global_rect()))
	var rootn := _find(map, "map_root")
	print("map_root rect=" + str(rootn.get_global_rect()) + " size=" + str(rootn.size))
	var div := _find(map, "map_divider_r")
	if div == null:
		print("map_divider_r = NULL")
	else:
		print("map_divider_r rect=" + str(div.get_global_rect()))
	quit(0)


func _find(root: Node, name: String) -> Control:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n.name == name:
			return n as Control
		for c in n.get_children():
			stack.append(c)
	return null


func _noop(_arg: Variant = null) -> void:
	pass
