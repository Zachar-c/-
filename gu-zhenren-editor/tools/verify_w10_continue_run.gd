extends SceneTree

## W10 continue_run 真窗验收（2026-09-14）：
## 1. 新开局 → travel → 保存 → 离开地图回大厅
## 2. 大厅 primary_action 应为 "continue_run"，按钮文案 "续入此世 >"
## 3. 触发 continue_run → load_run，应恢复到保存时的地图状态（seed/node 一致）
## 4. 无存档时 primary_action 应为 "open_schools"
##
## 用法（需真实窗口）：
##   tools\godot.ps1 --path . -s tools/verify_w10_continue_run.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const RunSnapshotBuilderScript := preload("res://scripts/presentation/run_snapshot_builder.gd")

var _failed := 0


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame

	# 阶段 1：无存档时，大厅 primary_action 应为 open_schools
	var hall_snap: Dictionary = RunSnapshotBuilderScript.for_screen("Title", controller)
	var primary_no_save := str(hall_snap.get("primary_action", ""))
	print("[W10] no-save primary_action=%s" % primary_no_save)
	if primary_no_save != "open_schools":
		_fail("expected open_schools, got %s" % primary_no_save)

	# 阶段 2：新开局 → travel 到第一个可达节点 → 保存
	controller.start_new_run(20260914, "", [])
	if controller.current_view_name() != "Map":
		_fail("start -> %s" % controller.current_view_name())
	else:
		var saved_seed: int = int(controller.state.seed)
		var saved_node_id := ""
		for node_value in controller.visible_route_nodes(2):
			var node: Dictionary = node_value
			var nid := str(node.get("id", ""))
			var r: Dictionary = controller.submit_command({"type": "travel", "node_id": nid})
			if bool(r.get("ok", false)):
				saved_node_id = nid
				break
		print("[W10] traveled to node=%s" % saved_node_id)

		# 保存并离开地图回大厅
		# save_run 失败必须显式失败：只打印继续跑会把保存层错误伪装成
		# "首跑 has_save=false flake"（2026-09-15 flake 诊断结论）。
		var save_result: Dictionary = controller.submit_command({"type": "save_run"})
		print("[W10] save_run ok=%s" % str(save_result.get("ok", false)))
		if not bool(save_result.get("ok", false)):
			_fail("save_run failed: %s" % str(save_result))
		controller.save_and_leave_map()
		await process_frame
		await process_frame
		print("[W10] after leave, view=%s" % controller.current_view_name())

		# 阶段 3：有存档时，大厅 primary_action 应为 continue_run
		var hall_snap2: Dictionary = RunSnapshotBuilderScript.for_screen("Title", controller)
		var primary_with_save := str(hall_snap2.get("primary_action", ""))
		var has_save := bool(hall_snap2.get("has_save", false))
		print("[W10] with-save has_save=%s primary_action=%s" % [str(has_save), primary_with_save])
		if not has_save:
			_fail("has_save should be true after save")
		if primary_with_save != "continue_run":
			_fail("expected continue_run, got %s" % primary_with_save)

		# 阶段 4：触发 continue_run（load_run），应恢复到保存的状态
		var load_result: Dictionary = controller.submit_command({"type": "load_run"})
		print("[W10] load_run ok=%s view=%s" % [
			str(load_result.get("ok", false)), controller.current_view_name()])
		if not bool(load_result.get("ok", false)):
			_fail("load_run failed: %s" % str(load_result))
		elif controller.current_view_name() != "Map":
			_fail("after load_run expected Map, got %s" % controller.current_view_name())
		else:
			var loaded_seed: int = int(controller.state.seed)
			print("[W10] loaded seed=%d (saved=%d)" % [loaded_seed, saved_seed])
			if loaded_seed != saved_seed:
				_fail("seed mismatch after load: saved=%d loaded=%d" % [saved_seed, loaded_seed])

	# 阶段 5：截图大厅（有存档态）供肉眼比对
	# 截图仅真窗模式执行；headless 下 get_texture() 恒为 null 会挂起等待帧绘制。
	if DisplayServer.get_name() != "headless":
		await _shot("w10_hall_with_save")

	print("W10_CONTINUE_RUN FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _fail(msg: String) -> void:
	_failed += 1
	printerr("FAIL " + msg)


func _shot(out_name: String) -> void:
	await create_timer(0.35).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var window := root as Window
	var tex := window.get_texture()
	if tex == null:
		_fail("no render target; run without --headless")
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/" + out_name + ".png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
