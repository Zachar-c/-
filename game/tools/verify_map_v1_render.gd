extends SceneTree

## 地图屏 v1 线框稿实施渲染验证（2026-09-07）：真实窗口挂载 map_screen.tscn，
## 喂合成快照（此刻=休整，下一程=巡哨/黑市/炼蛊，再前=遗葬/毒瘴/血苔），
## force_draw 后保存整窗截图到 .preview/map_v1_render.png 供与线框稿比对。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_map_v1_render.gd

const MapScene := "res://scenes/ui/screens/map_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"zone_title": "青茅山外围",
		"depth_label": "第 3 大层",
		"realm_label": "四转",
		"resources": {"yuanstone": 12, "shouyuan": 78, "hunpo": 5},
		"contracts": [],
		"anomalies": [],
		"gu_satchel": [],
		"inventory": {},
		"toast": "",
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
	var cmds := {
		"travel": Callable(self, "_noop"),
		"view_node": Callable(self, "_noop"),
		"save_run": Callable(self, "_noop"),
		"to_hall": Callable(self, "_noop"),
		"save_and_to_hall": Callable(self, "_noop"),
		"cancel_to_hall": Callable(self, "_noop"),
	}
	var map: Control = (load(MapScene) as PackedScene).instantiate()
	root.add_child(map)
	map.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var window := root as Window
	var tex := window.get_texture()
	if tex == null:
		push_error("no render target; run without --headless")
		quit(1)
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/map_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
