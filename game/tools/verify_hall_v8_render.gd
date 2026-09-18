extends SceneTree

## 大厅 v8 实施渲染验证（2026-09-07）：真实窗口挂载 hall_screen.tscn，
## 喂 v8 参考快照（四转/41年/7蛊/63节点/契约/异变/2诅咒蛊），force_draw 后
## 保存整窗截图到 .preview/hall_v8_render.png 供肉眼比对参考图。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_hall_v8_render.gd

const HallScene := "res://scenes/ui/screens/hall_screen.tscn"


func _initialize() -> void:
	var snapshot := {
		"has_save": true,
		"brand_title": "問眞",
		"primary_action": "continue_run",
		"run_summary": {
			"route": "黑市交易后", "rank": "四转", "hp": "27",
			"lifespan": "41年", "gu_count": 7, "node_count": 63,
			"curse_count": 2, "build_label": "BUILD 0.9.0 · LOCAL",
		},
		"contracts": [{"id": "孤注", "name": "孤注"}],
		"anomalies": [{"id": "衰运", "label": "衰运"}],
		"meta_stats": {"runs": 3, "endings": 1},
		"hall_epoch": "今世·第六十三劫",
		"prev_life": "上一世止于：青茅山·三转",
		"prev_note": "札记新得：血海遗痕",
	}
	var cmds := {
		"open_codex": Callable(self, "_noop"),
		"open_journal": Callable(self, "_noop"),
		"open_settings": Callable(self, "_noop"),
		"back_to_hall": Callable(self, "_noop"),
		"new_run": Callable(self, "_noop"),
		"continue_run": Callable(self, "_noop"),
		"quit": Callable(self, "_noop"),
	}
	var hall: Control = (load(HallScene) as PackedScene).instantiate()
	root.add_child(hall)
	hall.mount_snapshot(snapshot, cmds)
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
	var out := ProjectSettings.globalize_path(dir) + "/hall_v8_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
