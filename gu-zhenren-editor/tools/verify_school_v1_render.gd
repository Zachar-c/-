extends SceneTree

## 流派选择界面 v1 实施渲染验证（2026-09-08）：真实窗口挂载 hall_screen.tscn，
## 喂 RunSnapshotBuilder.hall() 真实快照（20 流派 + 3 Buff + 选中血道/凡敌一滴血），
## force_draw 后保存整窗截图到 .preview/school_v1_render.png 供与线框稿比对。
## 断言：SchoolGrid 为 GridContainer 且 20 卡；「已选」印章 1 枚；
##       确认按钮文案「以血道入世 >」；Buff 复选 3 项。
## 用法（非 headless）：tools\godot.ps1 --path . -s tools/verify_school_v1_render.gd

const HallScene := "res://scenes/ui/screens/hall_screen.tscn"


func _initialize() -> void:
	var controller := {
		"state": null,
		"catalog": ContentCatalog.load_all(),
		"meta": MetaProgress.new(),
		"_hall_subview": "schools",
		"_selected_school": "blood",
		"_selected_buffs": ["lesser_one_hp"],
		"app_settings": null,
	}
	var snapshot: Dictionary = RunSnapshotBuilder.hall(controller)
	print("SCHOOLS=%d BUFFS=%d SELECTED=%s" % [
		(snapshot.get("available_schools", []) as Array).size(),
		(snapshot.get("available_buffs", []) as Array).size(),
		str(snapshot.get("selected_school_name", ""))])
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
	RenderingServer.force_draw()
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if DisplayServer.get_name() == "headless":
			break
	await process_frame

	# 断言 1：SchoolGrid = GridContainer，恰 20 卡（4 列 × 5 行）
	var grid: Control = hall.get_node("SchoolsView/SchoolGrid")
	var card_count := grid.get_child_count()
	print("GRID_IS_GRID=%s CARDS=%d" % [str(grid is GridContainer), card_count])
	if not (grid is GridContainer) or card_count != 20:
		push_error("流派网格应为 GridContainer 20 卡，实际 %d" % card_count)
		quit(1)
		return

	# 断言 2：「已选」印章恰 1 枚（血道）
	var label_texts: Array[String] = []
	_walk(hall, func(n: Node) -> void:
		if n is Label:
			var t := (n as Label).text
			if t.length() < 12:
				label_texts.append(t)
	)
	var mark_count := label_texts.count("已选")
	print("SELECTED_MARKS=%d" % mark_count)
	if mark_count != 1:
		push_error("选中印章应恰 1 枚，实际 %d" % mark_count)
		quit(1)
		return

	# 断言 3：确认按钮文案与 Buff 复选数量
	var confirm: Button = hall.get_node("SchoolsView/SchoolOpRow/ConfirmSchoolButton")
	print("CONFIRM_TEXT=%s" % confirm.text)
	if not confirm.text.contains("以血道续入此世"):
		push_error("确认按钮应为「以血道续入此世 >」，实际 %s" % confirm.text)
		quit(1)
		return
	var buff_row: HBoxContainer = hall.get_node("SchoolsView/SchoolBuffRow")
	var checks := 0
	for child in buff_row.get_children():
		if child is CheckButton:
			checks += 1
	print("BUFF_CHECKS=%d" % checks)
	if checks != 3:
		push_error("Buff 复选应 3 项，实际 %d" % checks)
		quit(1)
		return

	# 截图留证
	var window := root as Window
	var tex := window.get_texture()
	if tex == null or tex.get_image() == null:
		push_error("no render target; run without --headless")
		quit(1)
		return
	var img := tex.get_image()
	var dir := "res://.preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out := ProjectSettings.globalize_path(dir) + "/school_v1_render.png"
	img.save_png(out)
	print("SAVED=" + out + " SIZE=%dx%d" % [img.get_width(), img.get_height()])
	print("OK SchoolV1Render")
	quit(0)


func _noop(_arg: Variant = null) -> void:
	pass


func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_walk(child, fn)
