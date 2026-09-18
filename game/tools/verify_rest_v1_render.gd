extends SceneTree

## 休息屏线框稿 v1 实施渲染验收（2026-09-08）：真实窗口挂载 rest_screen.tscn，
## 喂 mock snapshot（6 卡休整选项），force_draw 后保存整窗截图
## 到 .preview/rest_v1_render.png 供与线框稿 v1 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_rest_v1_render.gd

const RestScene := "res://scenes/ui/screens/rest_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 94, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "闭关 · 休整",
		"note": "强制二选一，不可全拿",
		"choices": [
			{"id": "heal", "label": "调息回血", "detail": "闭目调息，恢复气血至八成", "cost": ""},
			{"id": "upgrade_card", "label": "强化蛊卡", "detail": "温养一张本命蛊，强化其效果", "cost": ""},
			{"id": "remove_card", "label": "温养一蛊", "detail": "择一蛊温养，抹除负面印记", "cost": ""},
			{"id": "remove_imprint", "label": "抹除印记", "detail": "剔除体内残留的异变印记", "cost": ""},
			{"id": "remove_curse", "label": "拔除反噬", "detail": "拔除缠身的诅咒与反噬", "cost": ""},
			{"id": "wash", "label": "洗髓换骨", "detail": "重塑根骨，重选流派",
				"cost": "寿元 12 年", "reason": "一生一次 · 不可逆"},
		],
	}
	var cmds := {
		"close": Callable(self, "_noop"),
		"choose": Callable(self, "_noop"),
	}
	var screen: Control = (load(RestScene) as PackedScene).instantiate()
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
	var out := ProjectSettings.globalize_path(dir) + "/rest_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
