extends SceneTree

## 调试弹窗线框稿 v2 实施渲染验证（2026-09-08）：挂载真实 RunController，
## 展开调试面板（加蛊已改为流派 + 蛊虫中文名联动下拉），force_draw 后保存
## 整窗截图到 .preview/debug_v2_render.png 供与线框稿 v2 比对。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_debug_v2_render.gd

const ControllerScript = preload("res://scripts/presentation/run_controller.gd")


func _initialize() -> void:
	var controller: RunController = ControllerScript.new()
	controller.name = "VerifyController"
	controller._debug_enabled_for_test = true
	root.add_child(controller)
	controller.start_new_run(101)
	# 展开面板并切一个非默认流派验证联动。
	controller._set_debug_gu_school("bone")
	controller._debug_panel_open = true
	controller._render_debug_panel()
	await process_frame
	await process_frame
	await process_frame

	# DBG：打印宿主尺寸与下拉控件实际值。
	var host := controller.get_node_or_null("DebugPanelHost")
	if host:
		print("DBG host pos=", host.position, " size=", host.size)
		var panel := host.get_child(0)
		if panel:
			var schools_opt: Array = []
			var gus_opt: Array = []
			var btns: Array = []
			_collect_controls(panel, schools_opt, gus_opt, btns)
			if not schools_opt.is_empty():
				var so: OptionButton = schools_opt[0]
				print("DBG school selected=", so.get_item_text(so.selected),
						" item_count=", so.item_count)
			if not gus_opt.is_empty():
				var go: OptionButton = gus_opt[0]
				print("DBG gu selected=", go.get_item_text(go.selected),
						" item_count=", go.item_count)
	var props: Dictionary = controller._debug_props()
	print("DBG props gu_schools=", (props["gu_schools"] as Array).size(),
			" gu_options=", (props["gu_options"] as Array).size(),
			" gu_selected=", props["gu_selected"])

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
	var out := ProjectSettings.globalize_path(dir) + "/debug_v2_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _collect_controls(node: Node, schools_opt: Array, gus_opt: Array, btns: Array) -> void:
	for c in node.get_children():
		if c is OptionButton:
			if schools_opt.is_empty():
				schools_opt.append(c)
			else:
				gus_opt.append(c)
		elif c is Button:
			btns.append(c)
		_collect_controls(c, schools_opt, gus_opt, btns)
