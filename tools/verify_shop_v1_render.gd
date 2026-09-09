extends SceneTree

## 商店屏线框稿 v2 实施渲染验收（2026-09-08）：真实窗口挂载 shop_screen.tscn，
## 喂 mock snapshot（货架 2×2 + 服务 + 立场/通胀），force_draw 后保存整窗截图
## 到 .preview/shop_v1_render.png 供与线框稿 v2 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_shop_v1_render.gd

const ShopScene := "res://scenes/ui/screens/shop_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "黑市",
		"inflation_note": "（已至 3 次涨价）",
		"npc_name": "黑市商人",
		"npc_stance": "冷淡",
		"emergency_note": "元石不足时可用寿元代付",
		"pool_fallback_note": "",
		"offers": [
			{"id": "o1", "name": "毒瘴蛛", "meta": "毒道 · 一阶", "desc": "瘴气缠身，攻其不备",
				"price_label": "6 元石", "sold_out": false},
			{"id": "o2", "name": "生机草", "meta": "木道 · 一阶", "desc": "净化一层负面",
				"price_label": "3 元石", "sold_out": false},
			{"id": "o3", "name": "石皮蛊", "meta": "土道 · 一阶", "desc": "获得护盾",
				"price_label": "5 元石", "sold_out": false},
			{"id": "o4", "name": "缘蛊匣", "meta": "？？？", "desc": "已售罄",
				"price_label": "—", "sold_out": true},
		],
		"services": [
			{"id": "s1", "name": "疗伤", "desc": "恢复 30 点气血", "price_label": "8 元石"},
			{"id": "s2", "name": "情报", "desc": "揭示下一节点", "price_label": "5 元石"},
		],
		"stance_note": "购货越多越热络",
	}
	var cmds := {
		"leave": Callable(self, "_noop"),
		"buy": Callable(self, "_noop"),
		"service": Callable(self, "_noop"),
	}
	var screen: Control = (load(ShopScene) as PackedScene).instantiate()
	root.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	for n in ["Root/ShopStage/StageContent/TitleRow/SealPanelContainer", "Root/ShopStage/StageContent/TitleRow"]:
		var node := screen.get_node_or_null(n)
		if node:
			print("DBG ", n, " pos=", node.position, " size=", node.size)
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
	var out := ProjectSettings.globalize_path(dir) + "/shop_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
