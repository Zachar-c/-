extends SceneTree

## 大厅屏网点密度/颜色校准验证（2026-09-08）：挂载 hall_screen.tscn 主视图快照，
## 真窗截图 .preview/hall_dots_v2.png（1280×720）供与 Codex 基准图比对网点 5x7 与点色。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_hall_dots.gd

const HallScene := "res://scenes/ui/screens/hall_screen.tscn"


func _initialize() -> void:
	var controller := {
		"state": null,
		"catalog": ContentCatalog.load_all(),
		"meta": MetaProgress.new(),
		"_hall_subview": "main",
		"_selected_school": "",
		"_selected_buffs": [],
		"app_settings": null,
	}
	var snapshot: Dictionary = RunSnapshotBuilder.hall(controller)
	print("SUBVIEW=%s PRIMARY=%s" % [
		str(snapshot.get("hall_subview", "")),
		str(snapshot.get("primary_action", ""))])
	var cmds := {
		"open_codex": Callable(self, "_noop"),
		"open_journal": Callable(self, "_noop"),
		"open_settings": Callable(self, "_noop"),
		"back_to_hall": Callable(self, "_noop"),
		"new_run": Callable(self, "_noop"),
		"continue_run": Callable(self, "_noop"),
		"select_school": Callable(self, "_noop"),
		"toggle_buff": Callable(self, "_noop"),
		"quit": Callable(self, "_noop"),
	}
	var hall: Control = (load(HallScene) as PackedScene).instantiate()
	root.add_child(hall)
	hall.mount_snapshot(snapshot, cmds)
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await process_frame
	RenderingServer.force_draw()
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if DisplayServer.get_name() == "headless":
			break
	await create_timer(0.3).timeout
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var window := root as Window
	var tex := window.get_texture()
	if tex == null or tex.get_image() == null:
		push_error("no render target; run without --headless")
		quit(1)
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/hall_dots_v2.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	print("OK HallDotsV2")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass
