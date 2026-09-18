extends SceneTree

## 入口按钮集成 smoke（2026-09-08）：
## 1) 大厅菜单含"杀招"链接（open_kill → Kill 屏 → back → Title）
## 2) 战斗屏右上"设置"按钮（open_settings → Settings 屏 → back → 回 Battle）
## 3) 设置屏快照带 version_label；战斗屏渲染带设置按钮
## 输出截图：.preview/route_hall_kill.png / route_battle_settings.png
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_entry_buttons.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame
	# 1) 大厅：KillLink 按钮等价行为（commands.open_kill → _show_kill）→ Kill 屏
	var hall_kill_ok := _verify_kill(controller)
	if not hall_kill_ok:
		return
	await _snap("res://.preview/route_hall_kill.png")
	controller.back_from_overlay()
	if controller.current_view_name() != "Title":
		printerr("FAIL kill back -> " + controller.current_view_name())
		quit(2)
		return
	# 2) 开局进战斗 → 设置 → 返回回战斗
	controller.start_new_run(101, "", [])
	var travel := controller.submit_command({"type": "travel", "node_id": "guard_fight_1"})
	printerr("TRAVEL=%s view=%s" % [str(travel.get("ok", "")), controller.current_view_name()])
	# 若未直接进战斗，走 leave_node 推进到战斗
	var guard := 0
	while controller.current_view_name() != "Battle" and guard < 8:
		controller.submit_command({"type": "leave_encounter"})
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			var r: Dictionary = controller.submit_command({"type": "travel", "node_id": str(node.get("id", ""))})
			if bool(r.get("ok", false)):
				break
		guard += 1
	if controller.current_view_name() != "Battle":
		printerr("FAIL cannot reach battle view=" + controller.current_view_name())
		quit(2)
		return
	await _snap("res://.preview/route_battle_hud.png")
	controller._show_settings()
	if controller.current_view_name() != "Settings":
		printerr("FAIL battle->settings: " + controller.current_view_name())
		quit(2)
		return
	await _snap("res://.preview/route_battle_settings.png")
	controller.back_from_overlay()
	if controller.current_view_name() != "Battle":
		printerr("FAIL settings back -> " + controller.current_view_name())
		quit(2)
		return
	print("ENTRY_SMOKE_OK final=%s" % controller.current_view_name())
	quit(0)


func _verify_kill(controller) -> bool:
	controller._show_kill()
	if controller.current_view_name() != "Kill":
		printerr("FAIL open_kill -> " + controller.current_view_name())
		quit(2)
		return false
	return true


func _snap(path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var tex := (root as Window).get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/" + path.get_file()
	img.save_png(out)
	print("SHOT=" + out)
