class_name HallScreenView
extends MarginContainer

## 大厅家族（规格 v3 §4.2/§5）：问眞主页 + 流派 + 契约 + 图鉴 + 设置 + 手记。
##
## 子视图由**快照的 hall_subview 驱动**（权威源），本屏不持有子视图状态——
## 与结算/图鉴一致：状态在领域侧，UI 只跟随。
##
## 六个子视图全部预置在节点树里靠 visible 切换（种类固定），
## 列表内容才走代码生成（数量不定）。见 UI_RULES §5。

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")
const GuCardScene := preload("res://scenes/ui/widgets/gu_card.tscn")
const GuToastScene := preload("res://scenes/ui/widgets/gu_toast.tscn")

const CODEX_TAB_KEYS := ["gu", "enemies", "recipes", "inheritances", "relics"]
const CODEX_TAB_NAMES := {
	"gu": "蛊", "enemies": "敌人", "recipes": "配方",
	"inheritances": "传承", "relics": "遗物",
}

@onready var _main_view: Control = $Root/MainView
@onready var _codex_view: VBoxContainer = $Root/CodexView
@onready var _settings_view: VBoxContainer = $Root/SettingsView
@onready var _journal_view: VBoxContainer = $Root/JournalView
@onready var _schools_view: VBoxContainer = $Root/SchoolsView
@onready var _contracts_view: VBoxContainer = $Root/ContractsView

# 主界面
@onready var _hall_paper: ColorRect = $Root/MainView/HallPaper
@onready var _title_rule: ColorRect = $Root/MainView/HallSheet/HallIdentity/TitleRule
@onready var _primary_rule: ColorRect = $Root/MainView/HallSheet/HallPrimaryRule
@onready var _archive_rule: ColorRect = $Root/MainView/HallSheet/HallArchiveRule
@onready var _hall_title: Label = $Root/MainView/HallSheet/HallIdentity/HallTitle
@onready var _volume_label: Label = $Root/MainView/HallSheet/HallPrimary/VolumeLabel
@onready var _primary_action: Button = $Root/MainView/HallSheet/HallPrimary/HallPrimaryAction
@onready var _primary_note: Label = $Root/MainView/HallSheet/HallPrimary/PrimaryNote
@onready var _no_save_host: VBoxContainer = $Root/MainView/HallSheet/HallPrimary/NoSaveHost
@onready var _summary_host: VBoxContainer = $Root/MainView/HallSheet/HallPrimary/SummaryHost
@onready var _meta_host: HBoxContainer = $Root/MainView/HallSheet/HallPrimary/MetaHost
@onready var _journal_link: Button = $Root/MainView/HallSheet/HallArchive/JournalLink
@onready var _codex_link: Button = $Root/MainView/HallSheet/HallArchive/CodexLink
@onready var _settings_link: Button = $Root/MainView/HallSheet/HallArchive/SettingsLink

# 图鉴
@onready var _codex_completion: Label = $Root/CodexView/CodexTitleRow/CodexCompletion
@onready var _codex_list: VBoxContainer = $Root/CodexView/CodexScroll/CodexList
@onready var _codex_back: Button = $Root/CodexView/CodexBackButton

# 设置
@onready var _version_host: VBoxContainer = $Root/SettingsView/VersionHost
@onready var _display_panel = $Root/SettingsView/DisplayPanel
@onready var _difficulty_panel = $Root/SettingsView/DifficultyPanel
@onready var _save_panel = $Root/SettingsView/SavePanel
@onready var _settings_back: Button = $Root/SettingsView/SettingsBackButton
@onready var _settings_quit: Button = $Root/SettingsView/SettingsQuitButton

# 手记
@onready var _journal_list: VBoxContainer = $Root/JournalView/JournalScroll/JournalList
@onready var _journal_back: Button = $Root/JournalView/JournalBackButton

# 流派
@onready var _schools_selected: Label = $Root/SchoolsView/SchoolsSelected
@onready var _schools_list: VBoxContainer = $Root/SchoolsView/SchoolsScroll/SchoolsList
@onready var _confirm_school: Button = $Root/SchoolsView/SchoolsButtonRow/ConfirmSchoolButton
@onready var _schools_back: Button = $Root/SchoolsView/SchoolsButtonRow/SchoolsBackButton

# 契约
@onready var _contracts_note: Label = $Root/ContractsView/ContractsNote
@onready var _contracts_list: VBoxContainer = $Root/ContractsView/ContractsScroll/ContractsList
@onready var _start_run: Button = $Root/ContractsView/ContractsButtonRow/StartRunButton
@onready var _contracts_back: Button = $Root/ContractsView/ContractsButtonRow/ContractsBackButton

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_paper_colors()
	_wire_static_buttons()
	_refresh()


## 大厅场景中 .tscn 硬编码的颜色统一走 GuStyle token（2026-09-06 视觉审计修复）。
## 同时添加淡青茅山背景层和标题对比度修复。
func _apply_paper_colors() -> void:
	_hall_paper.color = GuStyle.PAPER_HALL
	_title_rule.color = GuStyle.CINNABAR
	_primary_rule.color = GuStyle.RULE_HALL
	_archive_rule.color = GuStyle.RULE_HALL
	# 标题对比度修复：問眞标题使用墨色，避免白色低对比度
	_hall_title.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_hall_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.15))
	_hall_title.add_theme_constant_override("shadow_offset_x", 1)
	_hall_title.add_theme_constant_override("shadow_offset_y", 1)
	# 淡青茅山背景层：半透明，营造命簿背后的南疆山水氛围
	_apply_hall_backdrop()


## 大厅屏淡青茅山背景：在纸面之上添加半透明山水层，营造命簿背后的南疆氛围。
func _apply_hall_backdrop() -> void:
	if _hall_paper == null or not is_instance_valid(_hall_paper):
		return
	# 检查是否已添加背景层，避免重复
	if _hall_paper.get_node_or_null("HallBackdrop") != null:
		return
	var backdrop := TextureRect.new()
	backdrop.name = "HallBackdrop"
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 大厅屏是规则层浅色命簿，背景使用极淡的山水（透明度0.08），不影响可读性
	backdrop.modulate = GuStyle.HALL_BACKDROP_DIM
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 作为HallPaper的子节点，显示在纸面之上、UI之下
	_hall_paper.add_child(backdrop)


## run_controller 的挂载入口（与各屏同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


## 主界面的按钮是常驻节点，接线只需要做一次。
func _wire_static_buttons() -> void:
	_journal_link.pressed.connect(func(): _fire("open_journal"))
	_codex_link.pressed.connect(func(): _fire("open_codex"))
	_settings_link.pressed.connect(func(): _fire("open_settings"))
	_codex_back.pressed.connect(func(): _fire("back_to_hall"))
	_settings_back.pressed.connect(func(): _fire("back_to_hall"))
	_settings_quit.pressed.connect(func(): _fire("quit"))
	_journal_back.pressed.connect(func(): _fire("back_to_hall"))
	_confirm_school.pressed.connect(func(): _fire("open_contracts"))
	_schools_back.pressed.connect(func(): _fire("back_to_hall"))
	_start_run.pressed.connect(func(): _fire("new_run"))
	_contracts_back.pressed.connect(func(): _fire("open_schools"))


func _refresh() -> void:
	if not _ready_done:
		return
	var subview := str(_snapshot.get("hall_subview", "main"))
	_main_view.visible = subview == "main"
	_codex_view.visible = subview == "codex"
	_settings_view.visible = subview == "settings"
	_journal_view.visible = subview == "journal"
	_schools_view.visible = subview == "schools"
	_contracts_view.visible = subview == "contracts"

	match subview:
		"main":
			_refresh_main()
		"codex":
			_refresh_codex()
		"settings":
			_refresh_settings()
		"journal":
			_refresh_journal()
		"schools":
			_refresh_schools()
		"contracts":
			_refresh_contracts()


# ————————————————————————— 主界面 —————————————————————————

func _refresh_main() -> void:
	var has_save := bool(_snapshot.get("has_save", false))
	var primary_action := str(_snapshot.get("primary_action",
			"continue_run" if has_save else "open_schools"))
	var run_summary: Dictionary = _snapshot.get("run_summary", {})

	_hall_title.text = str(_snapshot.get("brand_title", "問眞"))
	_hall_title.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_volume_label.text = "命蠱 · 第 %s 卷" % ("六十三" if has_save else "新")

	var primary_label := "续入此世" if primary_action == "continue_run" else "开始此世"
	_primary_action.text = primary_label + " ›"
	MasterTheme.apply_button(_primary_action, "primary")
	# primary_action 是动态的，重绑前先断开旧连接避免重复触发。
	_rebind(_primary_action, func(): _fire(primary_action))

	var route := str(run_summary.get("route", "流派选择"))
	_primary_note.text = "将从 " + route + (" 继续。此世没有回溯。" if has_save else " 开始，随后进入南疆。")

	_clear(_no_save_host)
	if not has_save:
		var note := Label.new()
		note.text = "新一世不会继承修为、蛊虫或元石。已解锁的蛊方、手记与契约仍可查阅。"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(0, 54)
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		_no_save_host.add_child(note)

	_clear(_summary_host)
	if has_save:
		for key in ["route", "rank", "hp"]:
			var value := str(run_summary.get(key, ""))
			if value == "":
				continue
			var prefixes: Dictionary = {"route": "行路：", "rank": "转数：", "hp": "气血："}
			var prefix := str(prefixes.get(key, ""))
			var summary_label := _label(prefix + value, GuStyle.INK_HALL, 15)
			# 主可见命名标签：验收按名定位（hall_summary_route/rank/hp）。
			summary_label.name = "hall_summary_" + key
			_summary_host.add_child(summary_label)

	_clear(_meta_host)
	for c in _snapshot.get("contracts", []):
		var cname := str(c.get("name", c.get("id", "契约"))) if c is Dictionary else str(c)
		_meta_host.add_child(_badged_label("契约 · " + cname, GuStyle.CONTRACT_BLUE))
	for a in _snapshot.get("anomalies", []):
		var aname := str(a.get("label", a.get("id", "异变"))) if a is Dictionary else str(a)
		_meta_host.add_child(_badged_label("异变 · " + aname, GuStyle.ANOMALY_YELLOW))


# ————————————————————————— 图鉴 —————————————————————————

func _refresh_codex() -> void:
	var codex: Dictionary = _snapshot.get("codex", {})
	var total_entries := 0
	var total_unlocked := 0
	_clear(_codex_list)
	for k in CODEX_TAB_KEYS:
		var entries: Array = codex.get(k, [])
		var panel = GuPanelScene.instantiate()
		_codex_list.add_child(panel)
		panel.setup(str(CODEX_TAB_NAMES.get(k, k)), true, false)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.content_host.add_child(box)

		for e in entries:
			if not (e is Dictionary):
				continue
			total_entries += 1
			var unlocked := bool(e.get("unlocked", false))
			if unlocked:
				total_unlocked += 1
			var ename := str(e.get("name", str(e.get("id", "?"))))
			var card = GuCardScene.instantiate()
			box.add_child(card)
			if unlocked:
				var school := str(e.get("school", ""))
				var school_name := str(e.get("school_name", school))
				var eid := str(e.get("id", ""))
				card.setup(ename, str(e.get("rarity", "")), false, false, false, "")
				if int(e.get("rank", 0)) > 0:
					# 2026-09-04：图鉴蛊条目透出转数与效果（数据见 _codex）。
					var rank_no := int(e.get("rank", 1))
					var rank_label := "%s转" % ["一", "二", "三", "四", "五"][clampi(rank_no, 1, 5) - 1]
					card.content_host.add_child(_label("转数：" + rank_label, GuStyle.INK_SOFT, 12))
					var effect_text := str(e.get("effect", ""))
					if effect_text != "":
						card.content_host.add_child(_label("效果：" + effect_text, GuStyle.INK_PRIMARY, 12))
				# C2 2026-09-05：图鉴透出中文流派名（schools.json v2）。
				card.content_host.add_child(_label(
						("流派：" + school_name) if school_name != "" else eid, GuStyle.INK_SOFT, 12))
			else:
				card.setup(ename, "", false, false, true, "")
				card.content_host.add_child(_label("尚未遭遇 · 剪影", GuStyle.INK_SOFT, 12))

		if entries.is_empty():
			box.add_child(_label("（本类暂无条目）", GuStyle.INK_SOFT, 14))
	_codex_completion.text = "完成度 %d/%d" % [total_unlocked, total_entries]
	MasterTheme.apply_button(_codex_back, "action")


# ————————————————————————— 设置 —————————————————————————

func _refresh_settings() -> void:
	var warning := str(_snapshot.get("hall_version_warning", ""))
	_clear(_version_host)
	if warning != "":
		var toast = GuToastScene.instantiate()
		_version_host.add_child(toast)
		toast.setup(warning, "warn")

	_build_display_panel()
	_build_difficulty_panel()
	_build_save_panel()
	MasterTheme.apply_button(_settings_back, "action")
	MasterTheme.apply_button(_settings_quit, "danger")


func _build_display_panel() -> void:
	_display_panel.setup("显示与声音", true, false)
	var host: Node = _display_panel.content_host
	_clear(host)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	host.add_child(vol_row)
	var master_volume := int(_snapshot.get("master_volume", 100))
	vol_row.add_child(_label("音量 %d%%" % master_volume, GuStyle.INK_HALL, 14))
	vol_row.add_child(_action_button("−10", func(): _fire1("step_volume", -10)))
	vol_row.add_child(_action_button("+10", func(): _fire1("step_volume", 10)))
	host.add_child(_label("音量作用于全局主音轨；0 即静音。", GuStyle.INK_SOFT, 12))

	var options: Array = _snapshot.get("resolution_options",
			["全屏", "1920×1080 · 窗口", "1600×900 · 窗口", "1280×720 · 窗口"])
	var idx := int(_snapshot.get("resolution_index", 0))
	var res_label := "全屏"
	if idx >= 0 and idx < options.size():
		res_label = str(options[idx])
	host.add_child(_action_button("分辨率：" + res_label + " ›",
			func(): _fire("cycle_resolution")))
	host.add_child(_label("切换立即生效；全屏与窗口尺寸随上一档记忆。", GuStyle.INK_SOFT, 12))

	# 第18批：关于本游戏（开源素材署名，CC BY 3.0 要求游戏内署名）
	host.add_child(_action_button("关于本游戏 · 开源素材署名 ›",
			func(): _show_credits_dialog()))


func _build_difficulty_panel() -> void:
	_difficulty_panel.setup("难度", true, false)
	var host: Node = _difficulty_panel.content_host
	_clear(host)
	host.add_child(_label("本局状态自适应难度（R14.6）", GuStyle.INK_HALL, 14))
	var enabled := bool(_snapshot.get("dda_state_adaptive_enabled", true))
	host.add_child(_action_button("当前：" + ("开启" if enabled else "关闭"),
			func(): _fire("toggle_dda")))


func _build_save_panel() -> void:
	_save_panel.setup("存档", true, false)
	var host: Node = _save_panel.content_host
	_clear(host)
	host.add_child(_label("清除大厅存档需二次确认（规格 §16.22）", GuStyle.INK_SOFT, 14))


## 第18批：开源素材署名弹窗（CC BY 3.0 要求游戏内署名）
func _show_credits_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "关于本游戏 · 开源素材署名"
	dlg.dialog_text = """《蛊路求生》基于《蛊真人》IP的肉鸽游戏 Demo。

【开源图标】
game-icons.net — CC BY 3.0
来源: https://game-icons.net/
作者: lorc, delapouite, carl-olsen 等多位作者
使用: 53个SVG图标，覆盖蛊虫/状态/资源/动作/界面

【自绘图标】
问眞命簿图标集 — 项目自有
24个程序化自绘SVG图标（真元石/寿元/魂魄/生命/攻击等）

【美术资产】
青茅山背景图、主角立绘、5张蛊虫插画、4张敌人立绘
来源: AI生成（豆包AI / seedream），项目自有

【第三方代码】
GDQuest Open RPG — MIT
GUT (Godot Unit Test) — MIT

完整署名见项目根目录 CREDITS.md"""
	dlg.unresizable = false
	dlg.min_size = Vector2(520, 480)
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())


# ————————————————————————— 手记库 —————————————————————————

func _refresh_journal() -> void:
	var journal: Dictionary = _snapshot.get("journal", {"entries": []})
	_clear(_journal_list)
	var entries: Array = journal.get("entries", [])
	for je in entries:
		if not (je is Dictionary):
			continue
		var panel = GuPanelScene.instantiate()
		_journal_list.add_child(panel)
		panel.setup(str(je.get("title", "")), true, false)
		panel.content_host.add_child(_label(str(je.get("body", "")), GuStyle.INK_HALL, 14))
	if entries.is_empty():
		_journal_list.add_child(_label("（尚无手记。轮回碎片将在结算后沉淀于此。）",
				GuStyle.INK_SOFT, 14))
	MasterTheme.apply_button(_journal_back, "action")


# ————————————————————————— 流派 —————————————————————————

func _refresh_schools() -> void:
	var selected := str(_snapshot.get("selected_school", ""))
	_schools_selected.text = "当前选中：" + str(_snapshot.get("selected_school_name", selected))
	_clear(_schools_list)
	for s in _snapshot.get("available_schools", []):
		var sid := ""
		var sname := str(s)
		var ssum := ""
		var starters: Array = []
		if s is Dictionary:
			sid = str(s.get("id", ""))
			sname = str(s.get("name", sname))
			ssum = str(s.get("summary", ""))
			starters = s.get("starter_gu_names", [])
		var is_selected := sid == selected
		var card = GuCardScene.instantiate()
		_schools_list.add_child(card)
		# setup(title, quality, danger, curse_warning, sealed, cost, highlight)
		card.setup(sname, "", false, false, false, "", is_selected)
		if ssum != "":
			card.content_host.add_child(_label(ssum, GuStyle.INK_SOFT, 13))
		if not starters.is_empty():
			card.content_host.add_child(_label("初始蛊：" + "、".join(starters),
					GuStyle.INK_HALL, 13))
		var sel_label := ("选中 · " + sname) if is_selected else "选择"
		card.content_host.add_child(_action_button(sel_label,
				func(): _fire1("select_school", sid)))
	MasterTheme.apply_button(_confirm_school, "action")
	MasterTheme.apply_button(_schools_back, "action")


# ————————————————————————— 契约 —————————————————————————

func _refresh_contracts() -> void:
	var contracts: Array = _snapshot.get("contracts", [])
	_clear(_contracts_list)
	for c in contracts:
		if not (c is Dictionary):
			continue
		var cid := str(c.get("id", ""))
		var cname := str(c.get("name", cid))
		var locked := bool(c.get("locked", false))
		var selected := bool(c.get("selected", false))
		var card = GuCardScene.instantiate()
		_contracts_list.add_child(card)
		# setup(title, quality, danger, curse_warning, sealed, cost, highlight)
		card.setup(cname, "", false, false, false, "", selected)
		card.content_host.add_child(_label(str(c.get("desc", "")), GuStyle.CONTRACT_BLUE, 13))

		var toggle_label := "已勾选 · 点击取消" if selected else ("未解锁" if locked else "勾选")
		var btn := _action_button(toggle_label,
				func(): _fire1("toggle_contract", cid))
		btn.disabled = locked
		card.content_host.add_child(btn)

	_contracts_note.text = ("勾选将于开局立誓生效；同时启用软上限 5–6 条，普通手段不可撤销。"
			if contracts.size() > 0 else "当前无可用契约数据，直接以所选流派开始冒险。")
	MasterTheme.apply_button(_start_run, "action")
	MasterTheme.apply_button(_contracts_back, "action")


# ————————————————————————— 小工具 —————————————————————————

func _fire(key: String) -> void:
	if _commands.has(key):
		_commands[key].call()


func _fire1(key: String, arg) -> void:
	if _commands.has(key):
		_commands[key].call(arg)


## 常驻按钮每次 refresh 都要重绑（回调可能捕获了新快照），先断开旧的避免堆积。
func _rebind(btn: Button, cb: Callable) -> void:
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c.callable)
	btn.pressed.connect(cb)


func _label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _badged_label(text: String, color: Color) -> Label:
	var l := _label(text, color, 12)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = color
	box.border_width_left = 2
	box.content_margin_left = 8
	l.add_theme_stylebox_override("normal", box)
	return l


func _action_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	MasterTheme.apply_button(b, "action")
	b.pressed.connect(on_press)
	return b


func _clear(host: Node) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
