extends SceneTree

## 路由接线集成 smoke（2026-09-08）：真实窗口挂载 run_controller，
## 走完整 _ready → ensure_ui → 屏切换链路，验证 Kill/Settings 两新屏
## 已入 MASTER_SCENE_PATHS 且能从大厅/地图进入、能返回。
## 输出两张截图：.preview/route_settings_render.png / route_kill_render.png。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_route_overlay.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame
	# 1) 大厅 → 设置独立屏
	controller._show_settings()
	await process_frame
	await process_frame
	var out1 := await _snapshot_window("settings")
	print("SHOT_SETTINGS=" + out1)
	# 2) 返回 → 大厅（back_from_overlay 默认 Title）
	controller.back_from_overlay()
	if controller.current_view_name() != "Title":
		printerr("FAIL back_from_overlay -> " + controller.current_view_name())
		quit(2)
		return
	# 3) 大厅 → 杀招独立屏
	controller._show_kill()
	await process_frame
	await process_frame
	var out2 := await _snapshot_window("kill")
	print("SHOT_KILL=" + out2)
	# 4) 开局后从地图进设置 → 返回应回 Map
	controller.start_new_run(101, "", [])
	if controller.current_view_name() != "Map":
		printerr("FAIL start_new_run -> " + controller.current_view_name())
		quit(2)
		return
	controller._show_settings()
	if controller.current_view_name() != "Settings":
		printerr("FAIL map->settings: " + controller.current_view_name())
		quit(2)
		return
	controller.back_from_overlay()
	if controller.current_view_name() != "Map":
		printerr("FAIL settings back -> " + controller.current_view_name())
		quit(2)
		return
	# 5) 设置屏命令：静音 + 分辨率
	controller._show_settings()
	controller.toggle_mute()
	if controller.app_settings.master_volume != 0:
		printerr("FAIL toggle_mute")
		quit(2)
		return
	controller.set_resolution_index(3)
	if controller.app_settings.resolution_index != 3:
		printerr("FAIL set_resolution_index")
		quit(2)
		return
	print("ROUTE_SMOKE_OK views=%s/%s muted=%d res=%d" % [
		controller.current_view_name(),
		controller._view_name,
		controller.app_settings.master_volume,
		controller.app_settings.resolution_index])
	quit(0)


func _snapshot_window(kind: String) -> String:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var tex := (root as Window).get_texture()
	if tex == null:
		push_error("no render target")
		return ""
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + ("/route_settings_render.png" if kind == "settings" else "/route_kill_render.png")
	img.save_png(out)
	return out
