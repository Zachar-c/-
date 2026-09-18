extends SceneTree

## 杀招屏线框稿 v2 实施渲染验收（2026-09-08）：真实窗口挂载 kill_screen.tscn，
## 喂 mock snapshot（研习录 3 卡 + 战斗栏位 3 槽），force_draw 后保存整窗截图
## 到 .preview/kill_v1_render.png 供与线框稿 v2 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_kill_v1_render.gd

const KillScene := "res://scenes/ui/screens/kill_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "杀招",
		"subtitle": "研习于战 · 一场一用",
		"kill_moves": [
			{"name": "月噬", "sequence_display": "光月 Ⅱ", "intro": "以月为刃，噬其血气",
				"source": "毒瘴蛛", "cost": "6"},
			{"name": "霜刃", "sequence_display": "寒刃 Ⅰ", "intro": "寒气入骨，凝滞敌势",
				"source": "石皮蛊", "cost": "4"},
		],
		"study_slots": 3,
		"slots": [
			{"name": "月噬", "sequence_display": "光月 Ⅱ", "cost": "6"},
			{},
			{},
		],
	}
	var cmds := {
		"close": Callable(self, "_noop"),
	}
	var screen: Control = (load(KillScene) as PackedScene).instantiate()
	root.add_child(screen)
	screen.mount_snapshot(snapshot, cmds)
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
	var out := ProjectSettings.globalize_path(dir) + "/kill_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
