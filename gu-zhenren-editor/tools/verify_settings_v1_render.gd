extends SceneTree

## 设置屏线框稿 v2 实施渲染验收（2026-09-08）：真实窗口挂载 settings_screen.tscn，
## 喂 mock snapshot（音量/分辨率/存档），force_draw 后保存整窗截图
## 到 .preview/settings_v1_render.png 供与线框稿 v2 对比。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_settings_v1_render.gd

const SettingsScene := "res://scenes/ui/screens/settings_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"resources": {"shouyuan": 41, "hunpo": 7, "yuanstone": 12},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
		"layer": 3,
		"title": "设置",
		"subtitle": "声色之调 · 存于机匣",
		"master_volume": 100,
	}
	var cmds := {
		"save": Callable(self, "_noop"),
		"load": Callable(self, "_noop"),
		"toggle_mute": Callable(self, "_noop"),
		"set_resolution": Callable(self, "_noop"),
	}
	var screen: Control = (load(SettingsScene) as PackedScene).instantiate()
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
	var out := ProjectSettings.globalize_path(dir) + "/settings_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
