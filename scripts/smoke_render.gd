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


# 新屏统一以 Screen 后缀命名（如 EncounterScreen），
# 避开 scripts/presentation/*_view.gd 的 XxxView 类；无需改写生成产物类名。

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


## 只数**可见**按钮。顶栏把死线行 / 菜单按钮预置在节点树里（靠 visible 控制），
## _count_buttons 会把这些隐藏节点也算进去，断言"只有 N 个动作"时必须用这个。
func _count_visible_buttons(node: Node) -> int:
	var n := 0
	if node is Button and (node as Button).is_visible_in_tree():
		n += 1
	for c in node.get_children():
		n += _count_visible_buttons(c)
	return n


func _find_button_by_text(node: Node, wanted: String) -> Button:
	if node is Button and node.text == wanted:
		return node
	for c in node.get_children():
		var found := _find_button_by_text(c, wanted)
		if found != null:
			return found
	return null


func _host_has_label_text(node: Node, wanted: String) -> bool:
	if node is Label and str(node.text).contains(wanted):
		return true
	for c in node.get_children():
		if _host_has_label_text(c, wanted):
			return true
	return false


# T5-C：精确匹配标签（供配色断言取回具体 Label 节点）。
func _find_label_exact(node: Node, wanted: String) -> Label:
	if node is Label and str(node.text) == wanted:
		return node
	for c in node.get_children():
		var found := _find_label_exact(c, wanted)
		if found != null:
			return found
	return null


# T6-E：取子树第一个 PanelContainer（读 stylebox 断言底色/描边用）。
func _find_first_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node
	for c in node.get_children():
		var found := _find_first_panel(c)
		if found != null:
			return found
	return null


func _collect_labels(node: Node, out_labels: Array) -> void:
	if node is Label:
		out_labels.append(node)
	for c in node.get_children():
		_collect_labels(c, out_labels)


func _index_with_prefix(texts: Array[String], prefix: String) -> int:
	for i in texts.size():
		if texts[i].begins_with(prefix):
			return i
	return -1


# T6-E：从角标字符向上爬到最近的 PanelContainer 祖先（角标实底容器）。
func _nearest_panel_ancestor(node: Node) -> PanelContainer:
	var cur := node.get_parent()
	while cur != null:
		if cur is PanelContainer:
			return cur
		cur = cur.get_parent()
	return null


func _mount_component(rel_gd: String, component: String, props: Dictionary) -> Control:
	var fn = VLib.comp(rel_gd, component)
	if not (fn is Callable):
		push_error("%s 无组件 %s" % [rel_gd, component])
		quit(1)
	var container := Control.new()
	root.add_child(container)
	RuiRoot.create(container, VLib.fc(fn, props))
	return container


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
	# T6-E：危险蛊强红变体——「咒」角标必须朱砂底 + 墨字（R4.10），描边朱砂加粗。
	# 术语注：规格旧稿称 BONE / DANGER；这两组别名已随主题迁移移除，
	# 现分别对应 INK_PRIMARY / CINNABAR（见 test_wenzhen_theme_migration）。
	var gc_danger := _mount_component("res://ui/widgets/gu_card.gd", "render",
		{"title": "血祭蛊", "curse_warning": true})
	var curse_glyph := _find_label_exact(gc_danger, "咒")
	if curse_glyph == null:
		push_error("GuCard 危险变体缺少「咒」角标")
		quit(1)
	if not curse_glyph.get_theme_color("font_color").is_equal_approx(GuStyle.INK_PRIMARY):
		push_error("GuCard「咒」角标字符必须墨色（朱砂底 + 墨字）")
		quit(1)
	var curse_chip := _nearest_panel_ancestor(curse_glyph)
	if curse_chip == null:
		push_error("GuCard「咒」角标必须是实底角标容器（PanelContainer）")
		quit(1)
	var curse_sb := curse_chip.get_theme_stylebox("panel") as StyleBoxFlat
	if curse_sb == null or not curse_sb.bg_color.is_equal_approx(GuStyle.CINNABAR):
		push_error("GuCard「咒」角标底色必须 DANGER 强红")
		quit(1)
	var gc_danger_panel := _find_first_panel(gc_danger)
	var danger_card_sb := gc_danger_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if danger_card_sb == null or not danger_card_sb.border_color.is_equal_approx(GuStyle.CINNABAR):
		push_error("GuCard 危险变体描边必须 DANGER")
		quit(1)
	print("OK GuCardDanger buttons=%d" % _count_buttons(gc_danger))
	# T6-E：封印态——保留「锁」标 + 整卡暗淡。
	var gc_sealed := _mount_component("res://ui/widgets/gu_card.gd", "render",
		{"title": "石甲蛊", "sealed": true})
	if _find_label_exact(gc_sealed, "锁") == null:
		push_error("GuCard 封印态缺少「锁」标")
		quit(1)
	if not is_equal_approx(_find_first_panel(gc_sealed).modulate.a, 0.55):
		push_error("GuCard 封印态必须整卡暗淡（modulate a=0.55）")
		quit(1)
	print("OK GuCardSealed buttons=%d" % _count_buttons(gc_sealed))
	# T5-B D2：死线预警危险行强化（☠ 前缀 + 加大字号 + 半透明血锈底条 + 整行可点）。
	# 混合用例：寿元/反噬危险（可点），魂魄安全（纯文本）。
	var dlw_lines := {
		"shouyuan": {"name": "寿元", "remaining": 3, "max": 60, "danger": true, "detail": "寿元将尽", "cause_id": "death_cause_lifespan"},
		"hunpo": {"name": "魂魄", "remaining": 9, "max": 10, "danger": false},
		"backlash": {"name": "反噬", "remaining": 3, "max": 3, "danger": true, "detail": "反噬临界", "cause_id": "death_cause_backlash"},
	}
	var dlw := _mount_component("res://ui/widgets/gu_death_line_warning.gd", "render",
		{"death_lines": dlw_lines, "on_view": Callable(self, "_noop")})
	var skull_btn := _find_button_by_text(dlw, "☠ 寿元 3/60")
	if skull_btn == null:
		push_error("GuDeathLineWarning 危险行缺少 ☠ 前缀整行按钮")
		quit(1)
	var dl_sb := skull_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if dl_sb == null or not dl_sb.bg_color.is_equal_approx(Color(0.55, 0.18, 0.15, 0.25)):
		push_error("GuDeathLineWarning 危险行缺少半透明血锈底条样式键 bg_color")
		quit(1)
	if not skull_btn.has_theme_font_size_override("font_size") or skull_btn.get_theme_font_size("font_size") != 15:
		push_error("GuDeathLineWarning 危险行字号必须为 15（基础 13 + 2）")
		quit(1)
	if _count_buttons(dlw) != 2:
		push_error("GuDeathLineWarning 只有 danger 行可点，期望 2 个按钮，实得 %d" % _count_buttons(dlw))
		quit(1)
	if not _host_has_label_text(dlw, "· 魂魄 9/10"):
		push_error("GuDeathLineWarning 安全行应保留 · 前缀纯文本")
		quit(1)
	print("OK GuDeathLineWarning buttons=%d" % _count_buttons(dlw))
	# 未接线 on_view 的宿主（map/shop 等）：危险行降级为静态底条，不出按钮。
	var dlw_bare := _mount_component("res://ui/widgets/gu_death_line_warning.gd", "render", {"death_lines": dlw_lines})
	if _count_buttons(dlw_bare) != 0:
		push_error("GuDeathLineWarning 未接线时不应出现任何按钮")
		quit(1)
	if not _host_has_label_text(dlw_bare, "☠ 寿元 3/60"):
		push_error("GuDeathLineWarning 未接线时危险行仍须显示 ☠ 标记")
		quit(1)
	print("OK GuDeathLineWarningBare buttons=%d" % _count_buttons(dlw_bare))
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
	# T6-E：tooltip 宣纸卷轴底（PAPER）+ 深字 INK + 五段固定顺序（§16.5）。
	var tip := _mount_component("res://ui/widgets/gu_tooltip_view.gd", "render",
		{"title": "血祭蛊", "quality": "稀有", "effect": "吸取气血", "synergy": "与血道蛊联动",
			"cost": "消耗 3 寿元", "curse_warning": true})
	var tip_panel := _find_first_panel(tip)
	var tip_sb := tip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if tip_sb == null or not tip_sb.bg_color.is_equal_approx(GuStyle.PAPER_BG):
		push_error("GuTooltipView 底色必须 PAPER 卷轴感（禁深底金字回潮）")
		quit(1)
	var tip_labels: Array = []
	_collect_labels(tip_panel, tip_labels)
	var tip_texts: Array[String] = []
	for tl in tip_labels:
		tip_texts.append(str((tl as Label).text))
	var idx_effect := _index_with_prefix(tip_texts, "效果：")
	var idx_synergy := _index_with_prefix(tip_texts, "联动：")
	var idx_cost := _index_with_prefix(tip_texts, "代价：")
	var idx_curse := _index_with_prefix(tip_texts, "诅咒警示：")
	if idx_effect < 0 or not (idx_effect < idx_synergy and idx_synergy < idx_cost and idx_cost < idx_curse):
		push_error("GuTooltipView 五段顺序必须恒定：效果→联动→代价→诅咒警示")
		quit(1)
	if not (tip_labels[idx_effect] as Label).get_theme_color("font_color").is_equal_approx(GuStyle.INK_PRIMARY):
		push_error("GuTooltipView 正文必须 INK 深字")
		quit(1)
	if not (tip_labels[idx_curse] as Label).get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR):
		push_error("GuTooltipView 诅咒警示行必须 DANGER 红字")
		quit(1)
	print("OK GuTooltipPaper labels=%d" % tip_texts.size())
	_assert_widget("GuConfirmDialog", "res://ui/widgets/gu_confirm_dialog.gd",
		{"message": "确认执行？", "on_confirm": func(): pass, "on_cancel": func(): pass})
	# T5-A D1：带语义化 title / warning_note 的确认弹窗变体
	_assert_widget("GuConfirmDialogTitled", "res://ui/widgets/gu_confirm_dialog.gd",
		{"message": "确认洗髓换骨？", "title": "⚠ 危险行动", "warning_note": "代价：10 寿元 + 8 元石 · 执行前预检寿元",
		"on_confirm": func(): pass, "on_cancel": func(): pass})
	# T5-B D2：死因查看浮层（L2 信息浮层，非确认语义；右上「关闭」；Fix1 移除余量行）
	var dco := _mount_component("res://ui/widgets/gu_death_cause_overlay.gd", "render",
		{"line": {"name": "寿元", "current": 12, "max": 60, "detail": "寿元耗尽即死。"}, "on_close": func(): pass})
	if _find_button_by_text(dco, "关闭") == null:
		push_error("GuDeathCauseOverlay 缺少「关闭」按钮")
		quit(1)
	if not (_host_has_label_text(dco, "死因 · 寿元") and _host_has_label_text(dco, "当前值：12 / 上限：60")
			and _host_has_label_text(dco, "成因：寿元耗尽即死。")):
		push_error("GuDeathCauseOverlay 缺少 名称/当前值/上限/成因 文案行")
		quit(1)
	if _host_has_label_text(dco, "距离死线余量"):
		push_error("GuDeathCauseOverlay 不应再渲染「距离死线余量」行（恒为 0）")
		quit(1)
	print("OK GuDeathCauseOverlay buttons=%d" % _count_buttons(dco))
	# T5-A D4：GuToast 纯展示组件（buttons>=0，控件必须存在）
	var toast_info := _mount_component("res://ui/widgets/gu_toast.gd", "render",
		{"text": "进度已保存 · 关闭游戏后可继续本次冒险", "tone": "info"})
	if toast_info.get_child_count() == 0:
		push_error("GuToast(info) 未渲染出任何控件")
		quit(1)
	print("OK GuToast buttons=%d" % _count_buttons(toast_info))
	var toast_warn := _mount_component("res://ui/widgets/gu_toast.gd", "render",
		{"text": "大厅存档版本差异较大，建议在设置中清除后重新开始", "tone": "warn"})
	if toast_warn.get_child_count() == 0:
		push_error("GuToast(warn) 未渲染出任何控件")
		quit(1)
	print("OK GuToastWarn buttons=%d" % _count_buttons(toast_warn))
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
	# 大厅已迁到 Godot 官方 .tscn（六个子视图预置在树里靠 visible 切换）。
	for hs in hall_states:
		var hall := _mount_tscn_screen(HALL_SCREEN_TSCN, hs, cmds)
		await process_frame
		var cnt := _count_buttons(hall)
		if cnt < 4:
			push_error("大厅按钮数 %d < 4 (state=%s)" % [cnt, str(hs)])
			quit(1)
		print("OK TscnHallScreen buttons=%d" % cnt)

		# 遭遇屏断言（含空 action 兜底离开按钮）。当前实现为 RUI EncounterScreen。

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
		# T5-B：快照死线条目全形（value/threshold 进度语义 + remaining/max 实际值 + detail 成因）；
		# 危险判定与顶栏一致（value>=threshold），此处寿元已触线。
		"death_lines": {
			"shouyuan": {"id": "shouyuan", "name": "寿元", "value": 60, "threshold": 60,
				"remaining": 0, "max": 60, "danger": true, "cause_id": "death_cause_lifespan", "detail": "寿元耗尽即死。"},
		},
	}
	# 遭遇屏已整体迁到 Godot 官方 .tscn（scenes/ui/screens/encounter_screen.tscn），
	# 旧的 ui/screens/encounter_screen.guitkx 实现已删除。等价断言见 _verify_tscn_encounter()。

		# 地图屏断言（网状收敛地图，按层分组；至少 1 个节点按钮；含存档按钮 + Toast 行）。

	var map_cmds := {
		"travel": Callable(self, "_noop"),
		"view_node": Callable(self, "_noop"),
		"save_run": Callable(self, "_noop"),
	}
	var map_state := {
		"nodes": [
			{"id": "n1", "type": "start", "label": "起始", "layer": 0},
			{"id": "n2", "type": "combat", "label": "战", "layer": 1},
			{"id": "n3", "type": "event", "label": "事件", "layer": 1},
			{"id": "n4", "type": "boss", "label": "突破", "layer": 3},
		],
		"current_node_id": "n1",
		"reachable_ids": ["n2", "n3"],
		"toast": "进度已保存 · 关闭游戏后可继续本次冒险",
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}
	# 地图已迁到 Godot 官方 .tscn（镜头/拓扑是绝对定位，_ready() 后才有布局）。
	var map_container := _mount_tscn_screen(MAP_SCREEN_TSCN, map_state, map_cmds)
	await process_frame
	var mc := _count_buttons(map_container)
	if mc < 1:
		push_error("地图按钮数 %d < 1" % mc)
		quit(1)
	if _find_button_by_text(map_container, "存档") == null:
		push_error("地图屏缺少「存档」按钮")
		quit(1)
	var map_node_count := 0
	for node in map_container.find_children("map_node_*", "Button", true, false):
		map_node_count += 1
	if map_node_count != map_state["nodes"].size():
		push_error("地图节点按钮数 %d != 快照节点数 %d" % [map_node_count, map_state["nodes"].size()])
		quit(1)
	print("OK TscnMapScreen buttons=%d nodes=%d" % [mc, map_node_count])

		# 战斗屏断言（敌方意图数值+效果、生命护盾分条、手牌 tooltip、操作按钮）。

	var battle_cmds := {
		"play_card": Callable(self, "_noop"),
		"end_turn": Callable(self, "_noop"),
		"ultimate": Callable(self, "_noop"),
		"refine": Callable(self, "_noop"),
		"flee": Callable(self, "_noop"),
	}
	var battle_state := {
		"enemies": [
			{"id": "e1", "name": "铁皮山猪", "hp": 20, "max_hp": 30, "shield": 4, "intent": {"type": "attack", "value": 12, "detail": "造成物理伤害"}},
			{"id": "e2", "name": "雷冠头狼", "hp": 15, "max_hp": 15, "intent": {"type": "charge", "value": 0, "detail": "蓄力"}},
		],
		"player": {"hp": 24, "max_hp": 30, "shield": 6, "primordial": 3, "soul": 4,
				"thoughts": 2, "used_this_turn": 0, "statuses": [{"name": "灼烧", "stacks": 2}]},
		"actions": {"max": 2, "left": 2, "used": 0},
		"hand": [
			{"id": "c1", "name": "火蛊", "cost": 1, "effect": "灼烧", "quality": "普通", "curse_warning": false},
			# dangerous：走「弹确认后再下发」分支。
			{"id": "c2", "name": "血祭蛊", "cost": 2, "cost_ex": "消耗3寿元", "effect": "吸血", "quality": "稀有", "curse_warning": true, "dangerous": true},
			# target_type=single_enemy：走「先选敌人再下发」分支。
			{"id": "c3", "name": "月芒蛊", "cost": 1, "effect": "穿透", "quality": "史诗", "curse_warning": false, "target_type": "single_enemy", "valid_target_ids": ["e1", "e2"]},
		],
		"can_ultimate": true,
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		# T5-B：快照死线条目全形（同遭遇屏）；魂魄触线为危险行，其余两行安全行。
		"death_lines": {
			"shouyuan": {"id": "shouyuan", "name": "寿元", "value": 55, "threshold": 60,
				"remaining": 5, "max": 60, "danger": false, "cause_id": "death_cause_lifespan", "detail": "寿元耗尽即死。"},
			"hunpo": {"id": "hunpo", "name": "魂魄", "value": 4, "threshold": 4,
				"remaining": 1, "max": 6, "danger": true, "cause_id": "death_cause_soul", "detail": "魂魄耗尽即死。"},
			"backlash": {"id": "backlash", "name": "反噬", "value": 2, "threshold": 3,
				"remaining": 2, "max": 3, "danger": false, "cause_id": "death_cause_backlash", "detail": "反噬达上限即死。"},
		},
	}
	# 战斗屏已整体迁到 Godot 官方 .tscn（scenes/ui/screens/battle_screen.tscn），
	# 旧的 ui/screens/battle_screen.guitkx 已删除。等价断言见 _verify_tscn_battle()。

		# 结算屏断言（统一结算模块，由 ending_type 驱动；三种结局数据形态）。

	var ending_cmds := {
		"to_hall": Callable(self, "_noop"),
		"to_codex": Callable(self, "_noop"),
	}
	var ending_success := {
		"title": "险中求胜",
		"ending_type": "success",
		"achievement": "五转功成，渡劫飞升，完整走完晋升之路",
		"max_rank": 2,
		"route_summary": [
			{"layer": 1, "types": ["接触", "黑市"], "boss": false},
			{"layer": 2, "types": ["交锋"], "boss": true},
		],
		"run_record": {"synthesis_attempts": 2, "synthesis_ok": 1, "synthesis_fail": 1, "boss_phase_shifts": 1, "dda_triggers": 0},
		"key_decisions": ["放弃强攻，改为诈降", "以魂魄强行镇压反噬"],
		"gains_losses": "夺得《血道真解》残卷，损耗寿元 8",
		"resource_balance": {"yuanstone": 20, "shouyuan": 52},
		"unlocks": ["图鉴：火蛊", "契约：自苦·血祭"],
		"aftermath": "可于大厅图鉴查阅本次所得",
	}
	# 结算屏已整体迁到 Godot 官方 .tscn（scenes/ui/screens/ending_screen.tscn），
	# 旧的 ui/screens/ending_screen.guitkx 实现已删除。等价断言见 _verify_tscn_ending()。

	# 10) T4 剩余节点屏断言（C2 奖励 / C3 黑市 / C5 休整 / C6 炼蛊 / C8 NPC）
	var gui_state := {
		"resources": {"yuanstone": 12, "shouyuan": 60, "hunpo": 4, "material": 3},
		"contracts": ["自苦·血祭"],
		"anomalies": ["衰运"],
		"death_lines": {"shouyuan": {"value": 55, "threshold": 60}},
	}

	var shop_state := gui_state.duplicate()
	shop_state.merge({
		"title": "黑市 · 寨市",
		"npc_name": "地脉游商",
		"npc_stance": "中立",
		"inflation_note": "层数提升物价微涨 · 二次访问 +25%/次",
		"offers": [
			{"id": "o1", "name": "石甲蛊", "kind": "purchase", "price": "6 元石", "desc": "护盾 +8", "quality": "稀有", "curse_warning": false},
			{"id": "o2", "name": "魂丹", "kind": "soul_boost", "price": "6 元石", "desc": "魂魄 +1", "quality": "史诗", "curse_warning": false},
			{"id": "o3", "name": "寿元·脉冲鼓", "kind": "lifespan_deal", "price": "1 寿元", "desc": "高回报代价交易", "quality": "稀有", "curse_warning": true},
		],
		"services": [
			{"id": "remove_card", "name": "移除蛊虫", "price": "120 元石", "remaining": 2, "note": "从蛊囊删除一只蛊 · 本局剩 2/2 次 · 每次使用涨价", "candidates": [], "target_label": "选择要移除的蛊虫", "executable": false, "block_reason": "没有可移除的目标"},
			{"id": "wash_notoriety", "name": "洗刷恶名", "price": "10 寿元", "remaining": -1, "note": "恶名 -2 · 消耗寿元 · 无次数上限", "candidates": [], "target_label": "", "executable": false, "block_reason": "当前没有恶名可洗"},
		],
		"emergency_note": "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付",
	})
	var shop_cmds := {"buy": Callable(self, "_noop"), "service": Callable(self, "_noop"), "leave": Callable(self, "_noop")}
	# 黑市已整体迁到 Godot 官方 .tscn（scenes/ui/screens/shop_screen.tscn），
	# 旧的 ui/screens/shop_screen.guitkx 实现已删除。等价断言见 _verify_tscn_screens()。

	var rest_state := gui_state.duplicate()
	rest_state.merge({
		"title": "闭关 · 休整",
		"note": "强制二选一，不可全拿",
		"choices": [
			{"id": "heal", "label": "调息回血", "detail": "回复 30 气血", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "nurture", "label": "温养一蛊", "detail": "强化一张卡 / 移除负面", "cost": "", "disabled": false, "reason": "", "curse_warning": false},
			{"id": "wash", "label": "洗髓换骨", "detail": "真元上限 +1（实时刷新）", "cost": "10 寿元 + 8 元石", "disabled": false, "reason": "一局一次 · 执行前预检寿元", "curse_warning": false},
		],
		"is_ascension": false,
		"growth": [],
		"confirming": "",
		"confirm_msg": "",
	})
	var rest_cmds := {"choose": Callable(self, "_noop"), "confirm_wash": Callable(self, "_noop"), "cancel_confirm": Callable(self, "_noop"), "leave": Callable(self, "_noop")}
	# 休整已整体迁到 Godot 官方 .tscn（scenes/ui/screens/rest_screen.tscn），
	# 旧的 ui/screens/rest_screen.guitkx 实现已删除。等价断言见 _verify_tscn_screens()。

	var refine_state := gui_state.duplicate()
	refine_state.merge({
		"title": "炼蛊台",
		"channels": [
			{"id": "fixed", "label": "定向配方"},
			{"id": "combine", "label": "组合标签"},
			{"id": "blind", "label": "盲盒随机"},
		],
		"active_channel": "fixed",
		"inputs": ["月光蛊", "小光蛊"],
		"slot_ok": true,
		"recipes": [
			{"id": "r1", "name": "月光蛊 + 小光蛊 → 月辉蛊", "output": "月辉蛊", "quality": "稀有", "fail_chance": "成功配方", "backlash": "无躁动", "curse": "", "unlocked": true},
			{"id": "r2", "name": "盲盒（随机）", "output": "未知蛊", "quality": "随机", "fail_chance": "失败率 50% · 毁材", "backlash": "躁动 +2", "curse": "诅咒继承⚠", "unlocked": true},
		],
		"dismantle_slots": ["石甲蛊"],
		"streak_note": "连续失败第 2 次，下次成功率 +5%",
		"confirming": "",
		"confirm_msg": "",
	})
	var refine_cmds := {"set_channel": Callable(self, "_noop"), "refine": Callable(self, "_noop"), "toggle_input": Callable(self, "_noop"), "dismantle": Callable(self, "_noop"), "confirm": Callable(self, "_noop"), "cancel_confirm": Callable(self, "_noop"), "leave": Callable(self, "_noop")}
	# 炼蛊屏已整体迁到 Godot 官方 .tscn（scenes/ui/screens/refine_screen.tscn），
	# 旧的 ui/screens/refine_screen.guitkx 实现已删除。等价断言见 _verify_tscn_refine()。

	var reward_state := gui_state.duplicate()
	reward_state.merge({
		"title": "战利品",
		"rewards": [
			{"id": "r1", "name": "月光蛊", "kind": "蛊 · 战斗奖励", "quality": "稀有", "effect": "造成月光伤害并附加「月息」层", "cost": "获取即入蛊囊", "curse_warning": false},
			{"id": "r2", "name": "元石 +15", "kind": "货币", "quality": "普通", "effect": "直接入账", "cost": "", "curse_warning": false},
			{"id": "r3", "name": "血祭蛊", "kind": "蛊 · 诅咒蛊", "quality": "稀有", "effect": "吸取气血", "cost": "每次使用反噬 +1", "curse_warning": true},
		],
		"full_satchel": false,
		"pool_fallback_note": "（空池回退：已切至基础池）",
		"pity_note": "（保底：连续普通后，下次掉落品质有较大概率提升）",
	})
	var reward_cmds := {"take": Callable(self, "_noop"), "replace_and_take": Callable(self, "_noop"), "skip": Callable(self, "_noop"), "close": Callable(self, "_noop")}
	# 战利品已整体迁到 Godot 官方 .tscn（scenes/ui/screens/reward_screen.tscn），
	# 旧的 ui/screens/reward_screen.guitkx 实现已删除。等价断言见 _verify_tscn_reward()。

	var npc_state := gui_state.duplicate()
	npc_state.merge({
		"npc_name": "游方医修",
		"stance": "中立",
		"stance_note": "交涉失败将种子化翻转敌视",
		"notoriety": 12,
		"notoriety_note": "恶名高亮：威慑部分路线",
		"offers": [
			{"id": "o1", "name": "回购货物", "price": "5 元石", "desc": "出手一批闲置物资"},
		],
		"barter": [
			{"id": "b1", "name": "迹眼蛊 换 雾步蛊", "give": "迹眼蛊", "take": "雾步蛊", "note": "以物易物 · 需空位校验"},
		],
		"talk_options": [
			{"id": "t1", "label": "友善攀谈", "detail": "了解情报与需求", "danger": false},
			{"id": "t3", "label": "威胁勒索", "detail": "恶名威慑 · 可能翻脸", "danger": true},
		],
		"can_flee": true,
	})
	var npc_cmds := {"talk": Callable(self, "_noop"), "buy": Callable(self, "_noop"), "barter": Callable(self, "_noop"), "flee": Callable(self, "_noop"), "leave": Callable(self, "_noop")}
	# NPC 交涉屏已整体迁到 Godot 官方 .tscn（scenes/ui/screens/npc_screen.tscn），
	# 旧的 ui/screens/npc_screen.guitkx 实现已删除。等价断言见 _verify_tscn_npc()。

	# 11) T5-D D5：开发者调试面板（直接 mount 组件，不走控制器门控）。
	# 展开态：红字「调试」角标 + 加蛊/资源/跳层/池情报/快照打印；折叠态：只剩把手条。
	var dp_cmds := {
		"toggle_open": Callable(self, "_noop"),
		"set_gu_input": Callable(self, "_noop"),
		"add_gu": Callable(self, "_noop"),
		"set_res_kind": Callable(self, "_noop"),
		"set_res_value": Callable(self, "_noop"),
		"apply_resource": Callable(self, "_noop"),
		"set_travel_node": Callable(self, "_noop"),
		"travel": Callable(self, "_noop"),
		"snapshot_dump": Callable(self, "_noop"),
	}
	var dp_info := {"pity": {"loot_pity": 2, "material_pity": 1, "synthesis_fail_streak": 0}, "excluded": [], "seed": 101, "event_count": 7, "dda_percentile": ""}
	var dp_open := {
		"open": true,
		"feedback": "",
		"info": dp_info,
		"gu_input": "",
		"res_kind": "yuanstone",
		"res_value": "",
		"travel_options": [{"id": "n1", "label": "[n1] 拦路散修"}],
		"travel_selected": "",
		"commands": dp_cmds,
	}
	var dpc := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_open)
	await process_frame
	if _find_label_exact(dpc, "调试") == null:
		push_error("DebugPanel 缺少红字「调试」角标")
		quit(1)
	var dp_badge := _find_label_exact(dpc, "调试")
	if not dp_badge.get_theme_color("font_color").is_equal_approx(GuStyle.CINNABAR):
		push_error("DebugPanel「调试」角标必须 DANGER 红字（§16.22 视觉区分）")
		quit(1)
	for wanted in ["加蛊", "应用", "跳", "打印 RunData 快照"]:
		if _find_button_by_text(dpc, wanted) == null:
			push_error("DebugPanel 展开态缺少按钮 %s" % wanted)
			quit(1)
	if not _host_has_label_text(dpc, "保底计数 · 蛊 2 / 材料 1"):
		push_error("DebugPanel 池情报缺少保底计数行")
		quit(1)
	if not _host_has_label_text(dpc, "当前种子 101 · 事件数 7"):
		push_error("DebugPanel 缺少种子/事件数行")
		quit(1)
	print("OK DebugPanelOpen buttons=%d" % _count_buttons(dpc))
	var dp_closed := dp_open.duplicate(true)
	dp_closed["open"] = false
	var dpcc := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_closed)
	await process_frame
	if _count_buttons(dpcc) != 1:
		push_error("DebugPanel 折叠态只剩把手条，期望 1 个按钮，实得 %d" % _count_buttons(dpcc))
		quit(1)
	if not _host_has_label_text(dpcc, "DEV ONLY"):
		push_error("DebugPanel 折叠态把手条须保留 DEV 标识")
		quit(1)
	print("OK DebugPanelCollapsed buttons=%d" % _count_buttons(dpcc))
	var dp_feedback := dp_open.duplicate(true)
	dp_feedback["feedback"] = "调试失败：蛊囊已满（12/12），无法加入 月光蛊"
	var dpcf := _mount_tscn_props(DEBUG_PANEL_TSCN, dp_feedback)
	await process_frame
	if not _host_has_label_text(dpcf, "蛊囊已满"):
		push_error("DebugPanel 操作反馈必须经 Toast 行展示")
		quit(1)
	print("OK DebugPanelFeedback buttons=%d" % _count_buttons(dpcf))

	# Godot 官方 .tscn 节点树屏（过渡期与 .guitkx 双轨并存，全部转完后合并）。
	# 表驱动：每个已迁屏给一组 {name: [state, cmds]}，新增屏只加一行。
	await _verify_tscn_screens({
		"shop": [shop_state, shop_cmds],
		"rest": [rest_state, rest_cmds],
		"reward": [reward_state, reward_cmds],
		"npc": [npc_state, npc_cmds],
		"encounter": [enc_state, enc_cmds],
		"refine": [refine_state, refine_cmds],
		"ending": [ending_success, ending_cmds],
		"battle": [battle_state, battle_cmds],
	})

	quit()


## Godot 官方 .tscn 节点树屏的挂载回归。与上方 .guitkx 断言并列，
## 保证过渡期两套实现都不会悄悄坏掉。
## cases: { 屏名: [state, commands] }，屏名与 _verify_tscn_<name> 一一对应。
func _verify_tscn_screens(cases: Dictionary) -> void:
	var shop_state: Dictionary = cases["shop"][0]
	var shop_cmds: Dictionary = cases["shop"][1]
	var shop := _mount_tscn_screen(
			"res://scenes/ui/screens/shop_screen.tscn", shop_state, shop_cmds)
	# .tscn 屏靠 @onready 绑定节点，而 -s 模式下 _ready() 推迟到首帧，必须等一帧再断言。
	await process_frame
	var buttons := _count_buttons(shop)
	if buttons < 1:
		push_error("tscn 黑市按钮数 %d < 1" % buttons)
		quit(1)

	var offer_list := shop.get_node(
			"Root/PrimarySurface/OfferColumn/OfferScroll/OfferList")
	var expected_offers: int = shop_state["offers"].size()
	if offer_list.get_child_count() != expected_offers:
		push_error("tscn 黑市货架卡数 %d != %d" % [offer_list.get_child_count(), expected_offers])
		quit(1)

	# 重复项卡片必须直接挂在货架列表下，不得再套一层带框的决策面板
	# （旧 test_wenzhen_secondary_screens 的文本断言平移到真实节点树上）。
	if expected_offers > 0 and offer_list.get_child(0).get_parent() != offer_list:
		push_error("tscn 黑市货架卡不得嵌套在其他面板里")
		quit(1)

	var service_path := ("Root/PrimarySurface/ServiceColumn/ServicePanel/ServicePanelMargin"
			+ "/ServicePanelBox/ServiceScroll/ServiceList")
	var service_list := shop.get_node(service_path)
	var expected_services: int = shop_state["services"].size()
	if service_list.get_child_count() != expected_services:
		push_error("tscn 黑市服务行数 %d != %d" % [service_list.get_child_count(), expected_services])
		quit(1)

	# 初始态不得自行弹出确认弹窗；危险交易要等玩家点购买才弹。
	var dialog := shop.get_node("Root/ConfirmDialog")
	if dialog.visible:
		push_error("tscn 黑市初始不得展示确认弹窗")
		quit(1)

	# 空池回退小字为条件槽位：未标记不渲染，标记后按 13px INK_SOFT 出现。
	# 这两条是旧 ui/screens/shop_screen.guitkx 实现删除后平移过来的等价覆盖。
	var fallback_label: Label = shop.get_node(
			"Root/PrimarySurface/OfferColumn/PoolFallbackLabel")
	if fallback_label.visible:
		push_error("tscn 黑市未标记回退时不得渲染回退小字")
		quit(1)
	var marked_state := shop_state.duplicate(true)
	marked_state["pool_fallback_note"] = "（空池回退：已切至基础池）"
	var marked := _mount_tscn_screen(
			"res://scenes/ui/screens/shop_screen.tscn", marked_state, shop_cmds)
	await process_frame
	var marked_label: Label = marked.get_node(
			"Root/PrimarySurface/OfferColumn/PoolFallbackLabel")
	if not marked_label.visible or marked_label.text != "（空池回退：已切至基础池）":
		push_error("tscn 黑市标记回退后必须渲染小字槽位")
		quit(1)
	if (marked_label.get_theme_font_size("font_size") != 13
			or not marked_label.get_theme_color("font_color").is_equal_approx(GuStyle.INK_SOFT)):
		push_error("tscn 黑市回退小字必须 INK_SOFT 13px")
		quit(1)
	print("OK TscnShopScreen buttons=%d offers=%d services=%d"
			% [buttons, expected_offers, expected_services])
	# 含 await 的函数必须 await 调用：裸调用会在第一个 await 处挂起，
	# 后面的断言被静默跳过（进程照常退出 0，看不出问题）。
	await _verify_tscn_rest(cases["rest"][0], cases["rest"][1])
	await _verify_tscn_reward(cases["reward"][0], cases["reward"][1])
	await _verify_tscn_npc(cases["npc"][0], cases["npc"][1])
	await _verify_tscn_encounter(cases["encounter"][0], cases["encounter"][1])
	await _verify_tscn_refine(cases["refine"][0], cases["refine"][1])
	await _verify_tscn_ending(cases["ending"][0], cases["ending"][1])
	await _verify_tscn_battle(cases["battle"][0], cases["battle"][1])



## 战斗屏（.tscn 版）挂载回归：出牌三分支 + 选敌 + 操作按钮。
## 出牌判定顺序是核心契约：需选目标 → 进选敌；危险 → 弹确认；其余 → 直接下发。
func _verify_tscn_battle(battle_state: Dictionary, battle_cmds: Dictionary) -> void:
	var log: Array = []
	var cmds := {
		"play_card": func(cid = "", tid = ""): log.append("play_card:%s/%s" % [cid, tid]),
		"end_turn": func(): log.append("end_turn"),
		"refine": func(): log.append("refine"),
		"flee": func(): log.append("flee"),
	}
	var battle := _mount_tscn_screen(
			"res://scenes/ui/screens/battle_screen.tscn", battle_state, cmds)
	await process_frame

	var ops := battle.get_node("Root/battle_hand/OpsRow")
	if ops.get_child_count() < 3:
		push_error("tscn 战斗屏操作按钮不足（应有 结束回合 / 炼蛊 / 撤退）")
		quit(1)
	# mode 用空 Label 的 name 承载（test_wenzhen_card_fsm 按此定位），初始为 idle。
	var mode_host := battle.get_node("Root/ModeHost")
	if mode_host.get_child_count() != 1 or mode_host.get_child(0).name != "battle_idle":
		push_error("tscn 战斗屏初始 mode 应为 battle_idle")
		quit(1)

	# 1) 危险卡 → 只弹确认，不下发
	var danger_btn := _find_button_by_text(battle, "血祭蛊")
	if danger_btn == null:
		push_error("tscn 战斗屏手牌未渲染「血祭蛊」")
		quit(1)
	danger_btn.pressed.emit()
	await process_frame
	if not battle.get_node("Root/ConfirmDialog").visible:
		push_error("tscn 战斗屏危险卡必须弹确认")
		quit(1)
	if not log.is_empty():
		push_error("tscn 战斗屏危险卡确认前不得下发命令: " + str(log))
		quit(1)
	var confirm_btn := _find_button_by_text(battle.get_node("Root/ConfirmDialog"), "确认")
	if confirm_btn == null:
		push_error("tscn 战斗屏确认弹窗缺少「确认」")
		quit(1)
	confirm_btn.pressed.emit()
	await process_frame
	if log != ["play_card:c2/"]:
		push_error("tscn 战斗屏确认后应下发 play_card:c2/: " + str(log))
		quit(1)

	# 2) 需选目标的卡 → 进入 target_select，敌人变可选
	log.clear()
	var target_btn := _find_button_by_text(battle, "月芒蛊")
	if target_btn == null:
		push_error("tscn 战斗屏手牌未渲染「月芒蛊」")
		quit(1)
	target_btn.pressed.emit()
	await process_frame
	if mode_host.get_child_count() != 1 or mode_host.get_child(0).name != "battle_target_select":
		push_error("tscn 战斗屏选目标卡应进入 battle_target_select")
		quit(1)
	if not log.is_empty():
		push_error("tscn 战斗屏选敌阶段不得下发命令: " + str(log))
		quit(1)
	var enemy_btn := _find_button_by_text(battle, "铁皮山猪")
	if enemy_btn == null or not enemy_btn.visible:
		push_error("tscn 战斗屏选敌时敌人应变为可选按钮")
		quit(1)
	enemy_btn.pressed.emit()
	await process_frame
	if log != ["play_card:c3/e1"]:
		push_error("tscn 战斗屏选中敌人后应带目标下发: " + str(log))
		quit(1)

	# 3) 操作按钮
	log.clear()
	for t in ["结束回合", "炼蛊", "撤退"]:
		var b := _find_button_by_text(battle, t)
		if b != null:
			b.pressed.emit()
	if log != ["end_turn", "refine", "flee"]:
		push_error("tscn 战斗屏操作按钮未全部接线: " + str(log))
		quit(1)
	print("OK TscnBattleScreen ops=%d" % ops.get_child_count())
## 结算屏（.tscn 版）挂载回归：成功 / 死亡 / 极简三种形态。
## 死亡与极简两份快照只在本函数用到，就地定义以免污染 _initialize。
func _verify_tscn_ending(ending_success: Dictionary, ending_cmds: Dictionary) -> void:
	var ending_death := {
		"title": "命丧密林",
		"ending_type": "death",
		"death_cause_id": "death_cause_backlash",
		"death_cause": "反噬爆发而亡——诅咒层数越过临界，真元与魂魄俱溃。",
		"death_cause_short": "反噬爆发",
		"achievement": "寿元、魂魄或反噬一线归零，身死道消",
		"key_decisions": ["孤身追猎未探虚实"],
		"gains_losses": "反噬爆发，真元枯竭而亡",
		"resource_balance": {"yuanstone": 0, "shouyuan": 0},
		"unlocks": [],
		"aftermath": "残魂归于大地，修行札记已留存",
	}
	var ending_minimal := {
		"title": "保命而退",
		"ending_type": "retreat",
		"achievement": "机缘未至而主动抽身，保命另寻出路",
		"key_decisions": [],
		"gains_losses": "",
		"resource_balance": {},
		"unlocks": [],
		"aftermath": "",
	}
	var success := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_success, ending_cmds)
	await process_frame
	if _count_visible_buttons(success) < 1:
		push_error("tscn 结算(成功)按钮数 < 1")
		quit(1)
	# 非死亡结局不得出现死因徽章，也不展开精准死因面板。
	if _host_has_label_text(success, "死因 · "):
		push_error("tscn 非死亡结局不得渲染死因徽章")
		quit(1)
	if success.get_node("primary_decision_surface/DeathCausePanel").visible:
		push_error("tscn 非死亡结局不得展开精准死因面板")
		quit(1)
	if not _host_has_label_text(success, "达成：" + str(ending_success["achievement"])):
		push_error("tscn 结算缺少达成条件链行")
		quit(1)
	# 路线缩略图：Boss 层必须 EMBER 高亮。
	var boss_chip := _find_label_exact(success, "第2层 交锋")
	if boss_chip == null or not boss_chip.get_theme_color("font_color").is_equal_approx(GuStyle.RARITY_EPIC):
		push_error("tscn 路线缩略图 Boss 层必须 EMBER 高亮")
		quit(1)
	if not _host_has_label_text(success, "战斗合成：2 次 · 成 1 / 败 1"):
		push_error("tscn 结算缺少合成计数行")
		quit(1)
	if _host_has_label_text(success, "DDA 触发"):
		push_error("tscn DDA 预留位无数据时必须整行隐藏")
		quit(1)
	var new_chip := _find_label_exact(success, "★新 图鉴：火蛊")
	if new_chip == null or not new_chip.get_theme_color("font_color").is_equal_approx(GuStyle.ANOMALY_YELLOW):
		push_error("tscn 解锁列表项必须带 ★新 前缀")
		quit(1)
	if not _host_has_label_text(success, "离局清零"):
		push_error("tscn 资源结余面板缺少「离局清零」小字")
		quit(1)

	# 死亡结局：死因徽章并列 + 精准死因面板展开。
	var death := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_death, ending_cmds)
	await process_frame
	if not _host_has_label_text(death, "死因 · 反噬爆发"):
		push_error("tscn 死亡结局须并列死因徽章")
		quit(1)
	if not death.get_node("primary_decision_surface/DeathCausePanel").visible:
		push_error("tscn 死亡结局须展开精准死因面板")
		quit(1)

	# 极简 run：只有两个动作，路线与本局记录整块隐藏。
	var minimal := _mount_tscn_screen("res://scenes/ui/screens/ending_screen.tscn",
			ending_minimal, ending_cmds)
	await process_frame
	if _count_visible_buttons(minimal) != 2:
		push_error("tscn 极简结算应只有两个按钮，实得 %d" % _count_visible_buttons(minimal))
		quit(1)
	if (_find_button_by_text(minimal, "返回大厅") == null
			or _find_button_by_text(minimal, "查看图鉴") == null):
		push_error("tscn 结算动作必须是 返回大厅 与 查看图鉴（无读档回溯）")
		quit(1)
	if minimal.get_node("primary_decision_surface/RoutePanel").visible:
		push_error("tscn 无记录 run 不得渲染路线条")
		quit(1)
	if minimal.get_node("primary_decision_surface/RecordPanel").visible:
		push_error("tscn 无记录 run 不得渲染本局记录块")
		quit(1)
	print("OK TscnEndingScreen buttons=%d" % _count_visible_buttons(success))


## 炼蛊屏（.tscn 版）挂载回归。
func _verify_tscn_refine(refine_state: Dictionary, refine_cmds: Dictionary) -> void:
	var refine := _mount_tscn_screen(
			"res://scenes/ui/screens/refine_screen.tscn", refine_state, refine_cmds)
	await process_frame
	var buttons := _count_buttons(refine)
	if buttons < 1:
		push_error("tscn 炼蛊按钮数 %d < 1" % buttons)
		quit(1)
	var recipe_list: Node = refine.get_node(
			"Root/primary_decision_surface/MainColumn/RecipePanel").content_host.get_node(
			"RecipeScroll/List")
	var expected: int = refine_state["recipes"].size()
	if recipe_list.get_child_count() != expected:
		push_error("tscn 炼蛊配方数 %d != %d" % [recipe_list.get_child_count(), expected])
		quit(1)
	# 通道 Tab 是纯屏内过滤：切到「盲盒随机」后配方列表应为空并给出提示。
	var blind_tab := _find_button_by_text(refine, "盲盒随机")
	if blind_tab == null:
		push_error("tscn 炼蛊必须有通道 Tab")
		quit(1)
	blind_tab.pressed.emit()
	await process_frame
	if not _host_has_label_text(refine, "（无可用配方）"):
		push_error("tscn 炼蛊切到无配方通道时必须给出空态提示")
		quit(1)
	print("OK TscnRefineScreen buttons=%d recipes=%d" % [buttons, expected])


## 遭遇屏（.tscn 版）挂载回归。
func _verify_tscn_encounter(enc_state: Dictionary, enc_cmds: Dictionary) -> void:
	var enc := _mount_tscn_screen(
			"res://scenes/ui/screens/encounter_screen.tscn", enc_state, enc_cmds)
	await process_frame
	var buttons := _count_buttons(enc)
	if buttons < 1:
		push_error("tscn 遭遇按钮数 %d < 1" % buttons)
		quit(1)
	# 危险死线行应整行可点（☠ 前缀按钮），而不是纯文本。
	if _find_button_by_text(enc, "☠ 寿元 60/60") == null:
		push_error("tscn 遭遇屏危险死线行应整行可点（☠ 前缀按钮）")
		quit(1)
	var list: Node = enc.get_node(
			"Root/primary_decision_surface/MainColumn/ActionScroll/ActionList")
	if list.get_child_count() != enc_state["actions"].size():
		push_error("tscn 遭遇行动卡数 %d != %d" % [list.get_child_count(), enc_state["actions"].size()])
		quit(1)
	# 空行动列表：仍要给出离开出口（否则玩家卡死在遭遇节点）。
	var empty_state := {
		"node": {"title": "空径", "desc": "无甚异常。", "type": "rest"},
		"actions": [], "intel": {}, "resources": {},
		"contracts": [], "anomalies": [], "death_lines": {},
	}
	var empty := _mount_tscn_screen(
			"res://scenes/ui/screens/encounter_screen.tscn", empty_state, enc_cmds)
	await process_frame
	if _count_buttons(empty) < 1:
		push_error("tscn 遭遇空列表必须保留离开出口")
		quit(1)
	print("OK TscnEncounterScreen buttons=%d actions=%d"
			% [buttons, enc_state["actions"].size()])


## 休整屏（.tscn 版）挂载回归。
func _verify_tscn_rest(rest_state: Dictionary, rest_cmds: Dictionary) -> void:
	var rest := _mount_tscn_screen(
			"res://scenes/ui/screens/rest_screen.tscn", rest_state, rest_cmds)
	await process_frame
	var buttons := _count_buttons(rest)
	if buttons < 1:
		push_error("tscn 休整按钮数 %d < 1" % buttons)
		quit(1)
	var choice_row := rest.get_node(
			"Root/primary_decision_surface/PanelMargin/PanelBody/ContentHost/ChoiceRow")
	var expected: int = rest_state["choices"].size()
	if choice_row.get_child_count() != expected:
		push_error("tscn 休整选项卡数 %d != %d" % [choice_row.get_child_count(), expected])
		quit(1)
	# 移除目标面板是条件槽位，未点「温养一蛊」前不得展开。
	if rest.get_node("Root/RemovePanel").visible:
		push_error("tscn 休整初始不得展开移除目标面板")
		quit(1)
	print("OK TscnRestScreen buttons=%d choices=%d" % [buttons, expected])


## 战利品屏（.tscn 版）挂载回归。
func _verify_tscn_reward(reward_state: Dictionary, reward_cmds: Dictionary) -> void:
	var reward := _mount_tscn_screen(
			"res://scenes/ui/screens/reward_screen.tscn", reward_state, reward_cmds)
	await process_frame
	var buttons := _count_buttons(reward)
	if buttons < 1:
		push_error("tscn 战利品按钮数 %d < 1" % buttons)
		quit(1)
	var row := reward.get_node("Root/primary_decision_surface/RewardRow")
	var expected: int = reward_state["rewards"].size()
	if row.get_child_count() != expected:
		push_error("tscn 战利品卡数 %d != %d" % [row.get_child_count(), expected])
		quit(1)
	# 诅咒蛊同样走 GuCard 强红角标（R4.10）。
	if _find_label_exact(reward, "咒") == null:
		push_error("tscn 战利品诅咒蛊缺少「咒」角标")
		quit(1)
	# 标记回退时渲染 13px INK_SOFT 小字。
	var note: Label = reward.get_node("Root/NoteRow/PoolFallbackLabel")
	if not note.visible:
		push_error("tscn 战利品标记回退后必须渲染小字")
		quit(1)
	if (note.get_theme_font_size("font_size") != 13
			or not note.get_theme_color("font_color").is_equal_approx(GuStyle.INK_SOFT)):
		push_error("tscn 战利品回退小字必须 INK_SOFT 13px")
		quit(1)
	# 未标记时不得出现常驻假提示。
	var clean := reward_state.duplicate(true)
	clean.erase("pool_fallback_note")
	var clean_screen := _mount_tscn_screen(
			"res://scenes/ui/screens/reward_screen.tscn", clean, reward_cmds)
	await process_frame
	if clean_screen.get_node("Root/NoteRow/PoolFallbackLabel").visible:
		push_error("tscn 战利品未标记回退时不得渲染回退小字")
		quit(1)
	print("OK TscnRewardScreen buttons=%d rewards=%d" % [buttons, expected])


## NPC 交涉屏（.tscn 版）挂载回归。
func _verify_tscn_npc(npc_state: Dictionary, npc_cmds: Dictionary) -> void:
	var npc := _mount_tscn_screen(
			"res://scenes/ui/screens/npc_screen.tscn", npc_state, npc_cmds)
	await process_frame
	var buttons := _count_buttons(npc)
	if buttons < 1:
		push_error("tscn NPC 按钮数 %d < 1" % buttons)
		quit(1)
	var surface := "Root/primary_decision_surface/"
	var offer_list: Node = npc.get_node(
			surface + "TradeColumn/TradePanel").content_host.get_node("OfferScroll/List")
	var barter_list: Node = npc.get_node(
			surface + "TradeColumn/BarterPanel").content_host.get_node("BarterScroll/List")
	var talk_list: Node = npc.get_node(
			surface + "TalkColumn/TalkPanel").content_host.get_node("TalkScroll/List")
	if offer_list.get_child_count() != npc_state["offers"].size():
		push_error("tscn NPC 交易项数 %d != %d" % [offer_list.get_child_count(), npc_state["offers"].size()])
		quit(1)
	if barter_list.get_child_count() != npc_state["barter"].size():
		push_error("tscn NPC 易物项数不符")
		quit(1)
	if talk_list.get_child_count() != npc_state["talk_options"].size():
		push_error("tscn NPC 交涉项数不符")
		quit(1)
	# 极度仇恨禁逃：撤退按钮整体隐藏，不留"能点但注定失败"的死按钮。
	var no_flee := npc_state.duplicate(true)
	no_flee["can_flee"] = false
	var caged := _mount_tscn_screen(
			"res://scenes/ui/screens/npc_screen.tscn", no_flee, npc_cmds)
	await process_frame
	if caged.get_node(surface + "TalkColumn/FleeButton").visible:
		push_error("tscn NPC 禁逃时不得展示撤退按钮")
		quit(1)
	print("OK TscnNpcScreen buttons=%d offers=%d talks=%d"
			% [buttons, npc_state["offers"].size(), npc_state["talk_options"].size()])


## 挂载走 set_props 的 .tscn 组件（调试面板这类非路由组件）。
## 与 _mount_tscn_screen 的区别只在注入方式：路由屏是 mount_snapshot，
## 调试面板是 set_props（它不是路由屏，由 RunController 直接挂到可拖动宿主上）。
const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"
const MAP_SCREEN_TSCN := "res://scenes/ui/screens/map_screen.tscn"
const DEBUG_PANEL_TSCN := "res://scenes/ui/widgets/debug_panel.tscn"

func _mount_tscn_props(path: String, props: Dictionary) -> Control:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("tscn 组件无法加载 %s" % path)
		quit(1)
	var inst := scene.instantiate()
	root.add_child(inst)
	if inst.has_method("set_props"):
		inst.set_props(props)
	return inst


func _mount_tscn_screen(path: String, snapshot: Dictionary, commands: Dictionary) -> Control:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("tscn 场景无法加载 %s" % path)
		quit(1)
	var inst := scene.instantiate()
	root.add_child(inst)
	if inst.has_method("mount_snapshot"):
		inst.mount_snapshot(snapshot, commands)
	return inst
