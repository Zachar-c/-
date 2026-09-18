extends SceneTree

## 炼蛊屏线框稿 v3 实施渲染验收（2026-09-08）：真实窗口挂载 refine_screen.tscn，
## 喂 mock snapshot（三通道配方 + 空位校验 + 连击 + 拆解），force_draw 后保存整窗截图
## 到 .preview/refine_v1_render.png 供与线框稿 v3 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_refine_v1_render.gd

const RefineScene := "res://scenes/ui/screens/refine_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "炼蛊台",
		"slot_ok": true,
		"streak_note": "连击 2 次 · 一念炼蛊",
		"channels": [
			{"id": "fixed", "label": "定向"},
			{"id": "combo", "label": "组合"},
			{"id": "blind", "label": "盲盒"},
		],
		"recipes": [
			{"id": "r1", "name": "月噬", "output": "月光蛊", "fail_chance": "失败率 20%",
				"backlash": "无躁动", "curse": "", "rank_note": "一阶 · 光道",
				"channel": "fixed", "unlocked": true},
			{"id": "r2", "name": "石皮方", "output": "石皮蛊", "fail_chance": "失败率 25%",
				"backlash": "躁动：元石-2", "curse": "毒瘴缠身", "rank_note": "一阶 · 土道",
				"channel": "combo", "unlocked": true},
			{"id": "r3", "name": "生机汤", "output": "生机草", "fail_chance": "失败率 15%",
				"backlash": "无躁动", "curse": "", "rank_note": "一阶 · 木道",
				"channel": "blind", "unlocked": false},
		],
		"dismantle_slots": [
			{"id": "g1", "name": "毒瘴蛛"},
			{"id": "g2", "name": "石皮蛊"},
		],
	}
	var cmds := {
		"leave": Callable(self, "_noop"),
		"refine": Callable(self, "_noop"),
		"dismantle": Callable(self, "_noop"),
	}
	var screen: Control = (load(RefineScene) as PackedScene).instantiate()
	root.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	for n in ["Root/RefineStage/StageContent/HeaderRow/SealPanelContainer", "Root/RefineStage/StageContent/HeaderRow", "Root/RefineStage"]:
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
	var out := ProjectSettings.globalize_path(dir) + "/refine_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
