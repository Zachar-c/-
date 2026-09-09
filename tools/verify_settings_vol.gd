extends SceneTree

## 音量滑块区裁剪（对齐验证辅助，复用 verify_settings_v1_render 挂载方式）。
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
		"resolution_index": 3,
		"version_label": "BUILD 0.9.0",
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
	var img := (root as Window).get_texture().get_image()
	# 音量滑块区：面板(112,186)，内容坐标 track(110,84,550,88)→屏(222,270,662,274)
	var crop := img.get_region(Rect2i(210, 256, 500, 32))
	var out := ProjectSettings.globalize_path("res://.preview/settings_vol_crop.png")
	crop.save_png(out)
	print("CROP=" + out)
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
