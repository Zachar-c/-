extends SceneTree

# 无头冒烟：编译 .guitkx -> 加载 .gd -> 挂载组件 -> 统计可交互控件数。
# 验证 RUI 工具链可在无编辑器 GUI 下编译并渲染（满足「导出前先编译」与 CI 验证）。

const Guitkx = preload("res://addons/reactive_ui_toolkit/guitkx/guitkx.gd")
const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")
const ROOT := "res://"

const WIDGET_DIR := "res://ui/widgets"
const SCREEN_DIR := "res://ui/screens"

func _noop(_x = null) -> void:
	pass


func _compile_file(rel_path: String) -> bool:
	var src := FileAccess.get_file_as_string(rel_path)
	if src.is_empty():
		push_error("读不到 %s" % rel_path)
		return false
	var res := Guitkx.compile(src, rel_path.get_file().get_basename(), [], {}, rel_path, ROOT)
	if res.get("env_error", false):
		push_error("RUI 环境未就绪（词汇表未加载）: %s" % rel_path)
		return false
	if not res.get("ok", false):
		push_error("编译失败 %s: %s" % [rel_path, str(res.get("diagnostics", []))])
		return false
	var gd_path := rel_path.get_basename() + ".gd"
	var f := FileAccess.open(gd_path, FileAccess.WRITE)
	if f == null:
		push_error("写不出 %s" % gd_path)
		return false
	f.store_string(res["gd"])
	f.close()
	return true


# 同 _compile_file，但允许指定生成类名（class_base）与输出路径，避免与既有全局类重名。
func _compile_named(rel_path: String, class_base: String, out_gd: String) -> bool:
	var src := FileAccess.get_file_as_string(rel_path)
	if src.is_empty():
		push_error("读不到 %s" % rel_path)
		return false
	var res := Guitkx.compile(src, class_base, [], {}, rel_path, ROOT)
	if res.get("env_error", false):
		push_error("RUI 环境未就绪（词汇表未加载）: %s" % rel_path)
		return false
	if not res.get("ok", false):
		push_error("编译失败 %s: %s" % [rel_path, str(res.get("diagnostics", []))])
		return false
	var gd_text: String = res["gd"]
	# 规避与旧 scripts/presentation/encounter_view.gd 的全局类 EncounterView 重名（该旧类被单测引用，不可删）。
	gd_text = gd_text.replace("class_name EncounterView", "class_name EncounterViewScreen")
	var f := FileAccess.open(out_gd, FileAccess.WRITE)
	if f == null:
		push_error("写不出 %s" % out_gd)
		return false
	f.store_string(gd_text)
	f.close()
	return true


func _mount(rel_gd: String, component: String, props: Dictionary) -> int:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		quit(1)
	var container := Control.new()
	root.add_child(container)
	RuiRoot.create(container, VLib.fc(fn, props))
	return _count_buttons(container)


func _mount_children(rel_gd: String, component: String, props: Dictionary, children: Array) -> int:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		quit(1)
	var container := Control.new()
	root.add_child(container)
	RuiRoot.create(container, VLib.fc(fn, props, children))
	return _count_buttons(container)


func _count_buttons(node: Node) -> int:
	var n := 0
	if node is Button:
		n += 1
	for c in node.get_children():
		n += _count_buttons(c)
	return n


func _assert_widget(name: String, rel_gd: String, props: Dictionary, children := []) -> void:
	var count := 0
	if children.is_empty():
		count = _mount(rel_gd, "render", props)
	else:
		count = _mount_children(rel_gd, "render", props, children)
	if count < 1:
		push_error("控件 %s 按钮数 %d < 1" % [name, count])
		quit(1)
	print("OK %s buttons=%d" % [name, count])


func _sample_button() -> RuitkVNode:
	return VLib.fc(VLib.comp("res://ui/widgets/gu_button.gd", "render"), {"label": "测试", "on_press": func(): pass})


func _initialize() -> void:
	# 1) 先编译 _sample（保留既有断言）
	var sample := "res://ui/_sample.guitkx"
	if not _compile_file(sample):
		quit(1)
	var sc := _mount("res://ui/_sample.gd", "render", {})
	print("OK SampleApp buttons=%d" % sc)

	# 2) 编译 ui/widgets 下全部 .guitkx（先于挂载，确保 import 的 .gd 已存在）
	var dir := DirAccess.open(WIDGET_DIR)
	if dir == null:
		push_error("打不开 %s" % WIDGET_DIR)
		quit(1)
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.get_extension() == "guitkx":
			if not _compile_file(WIDGET_DIR.path_join(fname)):
				quit(1)
		fname = dir.get_next()
	dir.list_dir_end()

	# 3) 逐个挂载断言（编译产物已就绪，import 可解析）
	var b := _sample_button()

	_assert_widget("GuButton", "res://ui/widgets/gu_button.gd", {"label": "测试", "on_press": func(): pass})
	_assert_widget("GuResourceChip", "res://ui/widgets/gu_resource_chip.gd", {"kind": "yuanstone", "value": 12, "on_click": Callable(self, "_noop")})
	_assert_widget("GuStatBar", "res://ui/widgets/gu_stat_bar.gd",
		{"label": "生命", "value": 4, "max_value": 6, "color": GuStyle.JADE, "shield": 2, "on_inspect": Callable(self, "_noop")})
	_assert_widget("GuPanel", "res://ui/widgets/gu_panel.gd", {"title": "面板"}, [b])
	_assert_widget("GuCard", "res://ui/widgets/gu_card.gd", {"title": "卡片", "highlight": true}, [b])
	_assert_widget("GuDeathLineWarning", "res://ui/widgets/gu_death_line_warning.gd",
		{"lines": [{"name": "寿元", "value": 55, "threshold": 60}, {"name": "魂魄", "value": 4, "threshold": 4}], "on_view": Callable(self, "_noop")})
	_assert_widget("GuTopBar", "res://ui/widgets/gu_top_bar.gd",
		{
			"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
			"contracts": ["苦修契约"],
			"anomalies": ["衰运"],
			"death_lines": {"shouyuan": {"value": 55, "threshold": 60}, "hunpo": {"value": 4, "threshold": 4}, "backlash": {"value": 2, "threshold": 3}},
			"on_menu": func(): pass,
		})
	_assert_widget("GuTooltipView", "res://ui/widgets/gu_tooltip_view.gd",
		{"title": "火蛊", "quality": "稀有", "effect": "造成灼烧", "curse_warning": true, "on_detail": Callable(self, "_noop")})
	_assert_widget("GuConfirmDialog", "res://ui/widgets/gu_confirm_dialog.gd",
		{"message": "确认执行？", "on_confirm": func(): pass, "on_cancel": func(): pass})
	_assert_widget("GuScrollBox", "res://ui/widgets/gu_scroll_box.gd", {}, [b])

	# 4) 编译 ui/screens 下全部 .guitkx（widgets 已先编译，import 可解析）
	var sdir := DirAccess.open(SCREEN_DIR)
	if sdir == null:
		push_error("打不开 %s" % SCREEN_DIR)
		quit(1)
	sdir.list_dir_begin()
	var sname := sdir.get_next()
	while sname != "":
		if sname.get_extension() == "guitkx":
			if not _compile_file(SCREEN_DIR.path_join(sname)):
				quit(1)
		sname = sdir.get_next()
	sdir.list_dir_end()

	# 5) 大厅屏断言：四分支至少 4 个按钮；有存档时含「继续」共 5 个
	var cmds := {
		"continue_run": Callable(self, "_noop"),
		"new_run": Callable(self, "_noop"),
		"open_codex": Callable(self, "_noop"),
		"open_settings": Callable(self, "_noop"),
	}
	var hall_states = [
		{"has_save": true, "available_schools": ["血道", "气道", "力道", "魂道", "炼道"], "contracts": ["自苦·血祭", "节流·魂敛"], "meta_stats": {"runs": 3, "endings": 1}},
		{"has_save": false, "available_schools": ["血道"], "contracts": [], "meta_stats": {}},
	]
	for hs in hall_states:
		var cnt := _mount("res://ui/screens/hall_view.gd", "render", {"state": hs, "commands": cmds})
		if cnt < 4:
			push_error("大厅按钮数 %d < 4 (state=%s)" % [cnt, str(hs)])
			quit(1)
		print("OK HallView buttons=%d" % cnt)

	# 6) 遭遇屏断言（含空 action 兜底离开按钮）
	# 注意：旧 scripts/presentation/encounter_view.gd 仍注册全局类 EncounterView（被单测引用，不可删），
	# 故 RUI 编译产物改用非冲突类名 EncounterViewScreen，避免 hidding 报错；.guitkx 源文件名不变。
	if not _compile_named("res://ui/screens/encounter_view.guitkx", "encounter_view_screen", "res://ui/screens/encounter_view.gd"):
		quit(1)
	var enc_cmds := {
		"choose_option": Callable(self, "_noop"),
		"confirm_danger": Callable(self, "_noop"),
		"leave": Callable(self, "_noop"),
	}
	var enc_state := {
		"node": {"title": "幽林遭遇", "desc": "林中传来异响。", "type": "contact"},
		"actions": [
			{"id": "a1", "label": "探查", "detail": "仔细查看四周。", "dangerous": false},
			{"id": "a2", "label": "强夺", "detail": "消耗 5 寿元夺取宝物，触发反噬。", "dangerous": true},
			{"id": "leave", "label": "离开", "detail": "", "dangerous": false},
		],
		"intel": {},
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	var ec := _mount("res://ui/screens/encounter_view.gd", "render", {"state": enc_state, "commands": enc_cmds})
	if ec < 1:
		push_error("遭遇按钮数 %d < 1" % ec)
		quit(1)
	print("OK EncounterView buttons=%d" % ec)

	var enc_empty := {
		"node": {"title": "空径", "desc": "无甚异常。", "type": "rest"},
		"actions": [],
		"intel": {},
		"resources": {},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
	}
	var ece := _mount("res://ui/screens/encounter_view.gd", "render", {"state": enc_empty, "commands": enc_cmds})
	if ece < 1:
		push_error("遭遇空列表按钮数 %d < 1" % ece)
		quit(1)
	print("OK EncounterViewEmpty buttons=%d" % ece)

	quit()
