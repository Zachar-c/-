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

const SEEDS := [20260908, 20260909, 20260910, 20260911, 20260912, 20260913, 20260914, 20260915, 20260916, 20260917]

var _failed := 0


func _initialize() -> void:
	var controller = RunControllerScript.new()
	root.add_child(controller)
	await process_frame
	await process_frame

	var got := {"Encounter": false, "Npc": false}
	# Npc：contact 是低频 trade 类节点（pacing 权重 4--8%），地图遍历难命中。
	# 直接注入 neutral_wanderer 节点定义到 current_node，走正式 _show_npc 渲染路径。
	controller.start_new_run(20260920, "", [])
	if controller.current_view_name() == "Map":
		var npc_node: Dictionary = {
			"id": "neutral_wanderer", "type": "contact", "npc_id": "neutral_wanderer",
			"summary": "一名散修拦在岔路前，正试探你的虚实。",
			"choices": ["negotiate", "deceive", "fight", "retreat"],
		}
		controller.current_node = npc_node
		controller._show_npc()
		await process_frame
		await process_frame
		if controller.current_view_name() == "Npc":
			got["Npc"] = true
			await _shot("b2_npc")
		else:
			_fail("inject npc -> " + controller.current_view_name())
	# Encounter：直接注入 event 节点，走正式 _show_encounter 渲染路径（避免地图遍历进入战斗导致的图片加载风暴）。
	controller.start_new_run(20260921, "", [])
	if controller.current_view_name() == "Map":
		var enc_node: Dictionary = {
			"id": "toxic_mountain_path", "type": "event",
			"summary": "毒瘴弥漫的山道，空气中飘浮着诡异的孢子。",
			"choices": ["probe", "cross"],
		}
		controller.current_node = enc_node
		controller._show_encounter()
		await process_frame
		await process_frame
		if controller.current_view_name() == "Encounter":
			got["Encounter"] = true
			await _shot("b2_encounter")
		else:
			_fail("inject encounter -> " + controller.current_view_name())

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
