extends SceneTree

## B2 四屏真窗渲染验收（2026-09-11）：Encounter / Npc / Ending / ContentError。
##
## 全部走真实 RunController 状态：Encounter / Npc 用多种子 travel 抵达真实会话
## （leave_encounter 退出后继续找），Ending 用 surrender_run 进统一结算，
## ContentError 注入 _content_errors 后走 _show_content_error。
## 每屏 force_draw 后整窗截图到 .preview/b2_<screen>.png，供肉眼级真窗比对。
##
## 用法（需真实窗口，不能 --headless）：
##   tools\godot.ps1 --path . -s tools/verify_b2_four_screens_render.gd

const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")

const SEEDS := [20260908, 20260909, 20260910, 20260911, 20260912]

var _failed := 0


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame

	var got := {"Encounter": false, "Npc": false}
	# Npc：contact 是低频节点，且 travel 在会话未关时会被拒——从全新地图
	# 直达 visible 的 contact 节点（多种子，2026-09-11 诊断探针实证 7/8 种子可达）。
	for seed in SEEDS:
		if got["Npc"]:
			break
		controller.start_new_run(int(seed), "", [])
		if controller.current_view_name() != "Map":
			continue
		for node_value in controller.visible_route_nodes(6):
			if str(node_value.get("type", "")) != "contact":
				continue
			var r: Dictionary = controller.submit_command(
					{"type": "travel", "node_id": str(node_value.get("id", ""))})
			if bool(r.get("ok", false)):
				got["Npc"] = true
				await _shot("b2_npc")
				controller.submit_command({"type": "leave_encounter"})
			break
	# Encounter：逐节点遍历（离开战斗/休息会话后同层兄弟支路仍可达）。
	for seed in SEEDS:
		if got["Encounter"]:
			break
		controller.start_new_run(int(seed), "", [])
		if controller.current_view_name() != "Map":
			_fail("seed %d start -> %s" % [seed, controller.current_view_name()])
			break
		var visited := {}
		var guard := 0
		while guard < 500:
			guard += 1
			var moved := false
			for node_value in controller.visible_route_nodes(5):
				var node: Dictionary = node_value
				var nid := str(node.get("id", ""))
				if visited.has(nid):
					continue
				var r: Dictionary = controller.submit_command({"type": "travel", "node_id": nid})
				if not bool(r.get("ok", false)):
					continue
				visited[nid] = true
				moved = true
				var view := controller.current_view_name()
				if view == "Encounter" and not bool(got["Encounter"]):
					got["Encounter"] = true
					await _shot("b2_encounter")
				if view == "Rest":
					# rest_choice_required 门禁：先 skip 再离开（真实 UI 流程）。
					controller.submit_command({"type": "rest", "mode": "skip"})
					await process_frame
					await process_frame
				if view == "Battle" or view == "Rest":
					controller.submit_command({"type": "leave_encounter"})
					await process_frame
					await process_frame
					if controller.current_view_name() == "Battle":
						controller.submit_command({"type": "leave_encounter"})
						await process_frame
						await process_frame
					break
			if bool(got["Encounter"]) or not moved:
				break

	if not (got["Encounter"] and got["Npc"]):
		_fail("views not reached: " + str(got))

	# Ending：主动投降进统一结算（ending_type: abandoned）。
	controller.start_new_run(20260913, "", [])
	await process_frame
	controller.surrender_run()
	await process_frame
	await process_frame
	if controller.current_view_name() != "Ending":
		_fail("surrender -> " + controller.current_view_name())
	else:
		await _shot("b2_ending")

	# ContentError：注入内容校验错误后走正式显示路径。
	var errs: Array[String] = ["probe: synthetic missing id 'example_enemy'"]
	controller._content_errors = errs
	controller._show_content_error()
	await process_frame
	await process_frame
	if controller.current_view_name() != "ContentError":
		_fail("content error -> " + controller.current_view_name())
	else:
		await _shot("b2_contenterror")

	print("B2_FOUR_SCREENS FAILED=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _fail(msg: String) -> void:
	_failed += 1
	printerr("FAIL " + msg)


func _shot(out_name: String) -> void:
	# 等跨屏一次性淡入（§3.4 140ms）播完再采，否则截到半透明中间态。
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
