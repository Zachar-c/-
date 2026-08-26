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
	for hs in hall_states:
		var cnt := _mount("res://ui/screens/hall_view.gd", "render", {"state": hs, "commands": cmds})
		if cnt < 4:
			push_error("大厅按钮数 %d < 4 (state=%s)" % [cnt, str(hs)])
			quit(1)
		print("OK HallView buttons=%d" % cnt)

	# 6) 遭遇屏断言（含空 action 兜底离开按钮）
	# 命名 EncounterScreen 以避开旧 scripts/presentation/encounter_view.gd 的全局类 EncounterView（被单测引用）。
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
	var ec_container := _mount_component("res://ui/screens/encounter_screen.gd", "render", {"state": enc_state, "commands": enc_cmds})
	var ec := _count_buttons(ec_container)
	if ec < 1:
		push_error("遭遇按钮数 %d < 1" % ec)
		quit(1)
	if _find_button_by_text(ec_container, "☠ 寿元 60/60") == null:
		push_error("遭遇屏危险死线行应整行可点（☠ 前缀按钮）")
		quit(1)
	print("OK EncounterScreen buttons=%d" % ec)

	var enc_empty := {
		"node": {"title": "空径", "desc": "无甚异常。", "type": "rest"},
		"actions": [],
		"intel": {},
		"resources": {},
		"contracts": [],
		"anomalies": [],
		"death_lines": {},
	}
	var ece := _mount("res://ui/screens/encounter_screen.gd", "render", {"state": enc_empty, "commands": enc_cmds})
	if ece < 1:
		push_error("遭遇空列表按钮数 %d < 1" % ece)
		quit(1)
	print("OK EncounterScreenEmpty buttons=%d" % ece)

	# 7) 地图屏断言（网状收敛地图，按层分组；至少 1 个节点按钮；T5-A：含存档按钮 + Toast 行）
	# 命名 MapScreen 以避开旧 scripts/presentation/map_view.gd 的全局类 MapView（被单测引用）。
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
	var map_container := _mount_component("res://ui/screens/map_screen.gd", "render", {"state": map_state, "commands": map_cmds})
	var mc := _count_buttons(map_container)
	if mc < 1:
		push_error("地图按钮数 %d < 1" % mc)
		quit(1)
	if _find_button_by_text(map_container, "存档") == null:
		push_error("地图屏缺少「存档」按钮")
		quit(1)
	print("OK MapScreen buttons=%d" % mc)

	# 8) 战斗屏断言（敌方意图数值+效果、生命护盾分条、手牌 tooltip、操作按钮）
	# 命名 BattleScreen 以避开旧 scripts/presentation/battle_view.gd 的全局类 BattleView（被单测引用）。
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
		"player": {"hp": 24, "max_hp": 30, "shield": 6, "primordial": 3, "soul": 4, "statuses": [{"name": "灼烧", "stacks": 2}]},
		"hand": [
			{"id": "c1", "name": "火蛊", "cost": 1, "effect": "灼烧", "quality": "普通", "curse_warning": false},
			{"id": "c2", "name": "血祭蛊", "cost": 2, "cost_ex": "消耗3寿元", "effect": "吸血", "quality": "稀有", "curse_warning": true},
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
	var bc_container := _mount_component("res://ui/screens/battle_screen.gd", "render", {"state": battle_state, "commands": battle_cmds})
	var bc := _count_buttons(bc_container)
	if bc < 1:
		push_error("战斗按钮数 %d < 1" % bc)
		quit(1)
	if _find_button_by_text(bc_container, "☠ 魂魄 4/4") == null:
		push_error("战斗屏危险死线行应整行可点（☠ 前缀按钮）")
		quit(1)
	print("OK BattleScreen buttons=%d" % bc)

	# 9) 结算屏断言（统一结算模块，由 ending_type 驱动；T5-C 三变体：普通胜利 / 死亡 / 无记录极简）
	# 命名 EndingScreen 以避开旧 scripts/presentation/ending_view.gd 的全局类 EndingView。
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
	var esc_container := _mount_component("res://ui/screens/ending_screen.gd", "render", {"state": ending_success, "commands": ending_cmds})
	var esc := _count_buttons(esc_container)
	if esc < 1:
		push_error("结算(成功)按钮数 %d < 1" % esc)
		quit(1)
	if _host_has_label_text(esc_container, "死因 · "):
		push_error("非死亡结局不得渲染死因徽章")
		quit(1)
	if not _host_has_label_text(esc_container, "达成：" + str(ending_success["achievement"])):
		push_error("结算屏缺少达成条件链行")
		quit(1)
	if not (_host_has_label_text(esc_container, "第1层 接触·黑市") and _host_has_label_text(esc_container, "第2层 交锋")):
		push_error("结算屏路线缩略图缺少分层短标")
		quit(1)
	var boss_chip := _find_label_exact(esc_container, "第2层 交锋")
	if boss_chip == null or not boss_chip.get_theme_color("font_color").is_equal_approx(GuStyle.EMBER):
		push_error("路线缩略图 Boss 层必须 EMBER 高亮")
		quit(1)
	if not _host_has_label_text(esc_container, "战斗合成：2 次 · 成 1 / 败 1"):
		push_error("结算本局记录缺少合成计数行")
		quit(1)
	if not _host_has_label_text(esc_container, "Boss 阶段切换：1 次"):
		push_error("结算本局记录缺少 Boss 阶段切换行")
		quit(1)
	if _host_has_label_text(esc_container, "DDA 触发"):
		push_error("DDA 预留位无数据时必须整行隐藏")
		quit(1)
	var new_chip := _find_label_exact(esc_container, "★新 图鉴：火蛊")
	if new_chip == null or not new_chip.get_theme_color("font_color").is_equal_approx(GuStyle.GOLD):
		push_error("解锁列表项必须带 ★新 前缀（GOLD）")
		quit(1)
	if not _host_has_label_text(esc_container, "离局清零"):
		push_error("资源结余面板缺少「离局清零」小字标注")
		quit(1)
	print("OK EndingScreen buttons=%d" % esc)

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
	var edc_container := _mount_component("res://ui/screens/ending_screen.gd", "render", {"state": ending_death, "commands": ending_cmds})
	var edc := _count_buttons(edc_container)
	if edc < 1:
		push_error("结算(死亡)按钮数 %d < 1" % edc)
		quit(1)
	if not _host_has_label_text(edc_container, "死因 · 反噬爆发"):
		push_error("死亡结局应在结局类型面板顶部并列死因徽章（BLOOD 色）")
		quit(1)
	if not _host_has_label_text(edc_container, "达成：" + str(ending_death["achievement"])):
		push_error("死亡结局同样渲染达成条件链")
		quit(1)
	print("OK EndingScreenDeath buttons=%d" % edc)

	# T5-C 无记录极简 run：无 route_summary/run_record 字段 → 路线与本局记录整块隐藏，
	# 但达成条件链照常；结算仍只有 返回大厅 / 查看图鉴 两个动作（§16.6 无读档回溯）。
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
	var emn_container := _mount_component("res://ui/screens/ending_screen.gd", "render", {"state": ending_minimal, "commands": ending_cmds})
	var emn := _count_buttons(emn_container)
	if emn != 2:
		push_error("极简结算应只有 返回大厅/查看图鉴 两个按钮，实得 %d" % emn)
		quit(1)
	if _find_button_by_text(emn_container, "返回大厅") == null or _find_button_by_text(emn_container, "查看图鉴") == null:
		push_error("结算动作必须是 返回大厅 与 查看图鉴（不得出现读档/回溯）")
		quit(1)
	if _host_has_label_text(emn_container, "路线") or _host_has_label_text(emn_container, "本局记录"):
		push_error("无记录极简 run 不得渲染路线条与本局记录块")
		quit(1)
	if not _host_has_label_text(emn_container, "达成：" + str(ending_minimal["achievement"])):
		push_error("极简结算仍须渲染达成条件链")
		quit(1)
	print("OK EndingScreenMinimal buttons=%d" % emn)

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
			{"id": "s1", "name": "刷新货架", "cost": "120 元石", "remaining": 2, "note": "本局剩余 2 次 · 通胀叠加"},
			{"id": "s2", "name": "移除蛊虫", "cost": "150 元石", "remaining": 2, "note": "本局剩余 2 次 · 价格递增"},
		],
		"emergency_note": "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付",
	})
	var shop_cmds := {"buy": Callable(self, "_noop"), "block": Callable(self, "_noop"), "use_service": Callable(self, "_noop"), "leave": Callable(self, "_noop")}
	var shc := _mount("res://ui/screens/shop_screen.gd", "render", {"state": shop_state, "commands": shop_cmds})
	if shc < 1:
		push_error("黑市按钮数 %d < 1" % shc)
		quit(1)
	print("OK ShopScreen buttons=%d" % shc)

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
	var rsc := _mount("res://ui/screens/rest_screen.gd", "render", {"state": rest_state, "commands": rest_cmds})
	if rsc < 1:
		push_error("休整按钮数 %d < 1" % rsc)
		quit(1)
	print("OK RestScreen buttons=%d" % rsc)

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
	var rfc := _mount("res://ui/screens/refine_screen.gd", "render", {"state": refine_state, "commands": refine_cmds})
	if rfc < 1:
		push_error("炼蛊按钮数 %d < 1" % rfc)
		quit(1)
	print("OK RefineScreen buttons=%d" % rfc)

	var reward_state := gui_state.duplicate()
	reward_state.merge({
		"title": "战利品",
		"rewards": [
			{"id": "r1", "name": "月光蛊", "kind": "蛊 · 战斗奖励", "quality": "稀有", "effect": "造成月光伤害并附加「月息」层", "cost": "获取即入蛊囊", "curse_warning": false},
			{"id": "r2", "name": "元石 +15", "kind": "货币", "quality": "普通", "effect": "直接入账", "cost": "", "curse_warning": false},
		],
		"full_satchel": false,
		"pool_fallback_note": "（空池回退：已切至基础池）",
		"pity_note": "（保底：连续普通后，下次掉落品质有较大概率提升）",
	})
	var reward_cmds := {"take": Callable(self, "_noop"), "replace_and_take": Callable(self, "_noop"), "skip": Callable(self, "_noop"), "close": Callable(self, "_noop")}
	var rwc := _mount("res://ui/screens/reward_screen.gd", "render", {"state": reward_state, "commands": reward_cmds})
	if rwc < 1:
		push_error("奖励按钮数 %d < 1" % rwc)
		quit(1)
	print("OK RewardScreen buttons=%d" % rwc)

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
	var npc := _mount("res://ui/screens/npc_screen.gd", "render", {"state": npc_state, "commands": npc_cmds})
	if npc < 1:
		push_error("NPC 按钮数 %d < 1" % npc)
		quit(1)
	print("OK NpcScreen buttons=%d" % npc)

	quit()
