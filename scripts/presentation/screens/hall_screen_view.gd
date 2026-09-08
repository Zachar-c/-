class_name HallScreenView
extends MarginContainer

## 大厅家族（规格 v3 §4.2/§5）：问眞主页 + 流派 + 契约 + 图鉴 + 设置 + 手记。
##
## 子视图由**快照的 hall_subview 驱动**（权威源），本屏不持有子视图状态——
## 与结算/图鉴一致：状态在领域侧，UI 只跟随。
##
## 六个子视图全部预置在节点树里靠 visible 切换（种类固定），
## 列表内容才走代码生成（数量不定）。见 UI_RULES §5。

const GameVersionScript := preload("res://scripts/domain/game_version.gd")
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
@onready var _schools_view: Control = $SchoolsView
@onready var _contracts_view: VBoxContainer = $Root/ContractsView

# 主界面（v8 线框稿：左/中/右三栏 + 印章 + 红线连接黑线）
@onready var _hall_paper: ColorRect = $Root/MainView/HallPaper
@onready var _hall_title: Label = $Root/MainView/HallSheet/HallIdentity/HallTitle
@onready var _title_rule: ColorRect = $Root/MainView/HallSheet/HallIdentity/TitleRule
@onready var _prev_life: RichTextLabel = $Root/MainView/HallSheet/HallIdentity/HallPrevLife
@onready var _prev_note: RichTextLabel = $Root/MainView/HallSheet/HallIdentity/HallPrevNote
@onready var _epoch: Label = $Root/MainView/HallSheet/HallPrimary/HallEpoch
@onready var _primary_action: Button = $Root/MainView/HallSheet/HallPrimary/HallPrimaryAction
@onready var _primary_note: Label = $Root/MainView/HallSheet/HallPrimary/HallPrimaryNote
@onready var _stat_val1: Label = $Root/MainView/HallSheet/HallPrimary/HallStatsRow/StatVal1
@onready var _stat_val2: Label = $Root/MainView/HallSheet/HallPrimary/HallStatsRow/StatVal2
@onready var _stat_val3: Label = $Root/MainView/HallSheet/HallPrimary/HallStatsRow/StatVal3
@onready var _stat_val4: Label = $Root/MainView/HallSheet/HallPrimary/HallStatsRow/StatVal4
@onready var _status1: Label = $Root/MainView/HallSheet/HallPrimary/HallStatusRow/StatusItem1
@onready var _status2: Label = $Root/MainView/HallSheet/HallPrimary/HallStatusRow/StatusItem2
@onready var _status3: Label = $Root/MainView/HallSheet/HallPrimary/HallStatusRow/StatusItem3
@onready var _build_ver: Label = $Root/MainView/HallSheet/HallArchive/HallBuildVer
@onready var _journal_link: Button = $Root/MainView/HallSheet/HallArchive/JournalLink
@onready var _codex_link: Button = $Root/MainView/HallSheet/HallArchive/CodexLink
@onready var _kill_link: Button = $Root/MainView/HallSheet/HallArchive/KillLink
@onready var _settings_link: Button = $Root/MainView/HallSheet/HallArchive/SettingsLink
@onready var _quit_link: Button = $Root/MainView/HallSheet/HallArchive/QuitLink

# 图鉴
@onready var _codex_completion: Label = $Root/CodexView/CodexTitleRow/CodexCompletion
@onready var _codex_list: VBoxContainer = $Root/CodexView/CodexScroll/CodexList
@onready var _codex_back: Button = $Root/CodexView/CodexBackButton

# 设置
@onready var _version_host: VBoxContainer = $Root/SettingsView/VersionHost
@onready var _display_panel = $Root/SettingsView/DisplayPanel
@onready var _difficulty_panel = $Root/SettingsView/DifficultyPanel
@onready var _save_panel = $Root/SettingsView/SavePanel
@onready var _about_panel = $Root/SettingsView/AboutPanel
@onready var _settings_back: Button = $Root/SettingsView/SettingsBackButton
@onready var _settings_quit: Button = $Root/SettingsView/SettingsQuitButton

# 手记
@onready var _journal_list: VBoxContainer = $Root/JournalView/JournalScroll/JournalList
@onready var _journal_back: Button = $Root/JournalView/JournalBackButton

# 流派（2026-09-08 线框稿 v1：全屏左栏 + 4×5 卡片网格 + Buff 复选 + 底部操作行）
@onready var _school_grid: Control = $SchoolsView/SchoolGrid
@onready var _school_buff_row: HBoxContainer = $SchoolsView/SchoolBuffRow
@onready var _confirm_school: Button = $SchoolsView/SchoolOpRow/ConfirmSchoolButton
@onready var _schools_back: Button = $SchoolsView/SchoolSide/SchoolsBackButton
@onready var _schools_op_back: Button = $SchoolsView/SchoolOpRow/SchoolOpBack

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
## v8（2026-09-07）：纸面 + 网点层 + 标题墨色 + 竖线/印章朱砂系。
## v10（2026-09-08 审计第一批）：全元素色值对齐基准图采样（副题/右栏/说明/属性名/版本/角落/状态语义色）。
func _apply_paper_colors() -> void:
	_hall_paper.color = GuStyle.PAPER_HALL
	_title_rule.color = Color("82463e")
	# 标题：基准图纯墨黑 #101810（INK_PRIMARY 即近黑墨色）
	_hall_title.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_hall_title.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_hall_title.add_theme_constant_override("line_spacing", 6)
	# 左上角（叁宫·南盟）：基准灰绿 #707870
	var folio: Label = $Root/MainView/HallFolio
	if folio != null:
		folio.add_theme_font_override("font", GuStyle.BODY_FONT)
		folio.add_theme_color_override("font_color", GuStyle.CORNER_TEXT)
	# 上一世/札记（RichTextLabel）：基准字体
	for rtl in [_prev_life, _prev_note]:
		if rtl != null:
			rtl.add_theme_font_override("normal_font", GuStyle.BODY_FONT)
	# 说明文字：基准绿灰 #607060
	if _primary_note != null:
		_primary_note.add_theme_font_override("font", GuStyle.BODY_FONT)
		_primary_note.add_theme_font_size_override("font_size", 13)
		_primary_note.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	# 属性名（修为/寿元/蛊囊/节点）：基准绿灰 #606860
	var stats_labels: Node = $Root/MainView/HallSheet/HallPrimary/HallStatsLabels
	if stats_labels != null:
		for child in stats_labels.get_children():
			if child is Label:
				child.add_theme_font_override("font", GuStyle.BODY_FONT)
				child.add_theme_color_override("font_color", GuStyle.STAT_NAME_TEXT)
	# 版本号：基准灰 #888880
	if _build_ver != null:
		_build_ver.add_theme_font_override("font", GuStyle.BODY_FONT)
		_build_ver.add_theme_color_override("font_color", GuStyle.VER_TEXT)
	# 状态行三标签：按类型语义色（契约蓝灰 / 异变橄榄黄 / 诅咒砖红）
	for label in [_status1, _status2, _status3]:
		if label != null:
			label.add_theme_font_override("font", GuStyle.BODY_FONT)
	_sync_status_color(_status1, GuStyle.STATUS_CONTRACT)
	_sync_status_color(_status2, GuStyle.STATUS_MUTATE)
	_sync_status_color(_status3, GuStyle.STATUS_CURSE)
	# 流派屏（线框稿 v1）：纸底 + 竖排標題 + 红线
	var school_paper: ColorRect = $SchoolsView/SchoolPaper
	if school_paper != null:
		school_paper.color = GuStyle.PAPER_HALL
	var school_title: Label = $SchoolsView/SchoolSide/SchoolTitle
	if school_title != null:
		school_title.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
		school_title.add_theme_font_override("font", GuStyle.TITLE_FONT)
	var school_redline: ColorRect = $SchoolsView/SchoolSide/SchoolRedline
	if school_redline != null:
		school_redline.color = Color("82463e")
	# 公用印章组件（v9）：透明底 + 朱砂细框 + 墨字 + 微斜 -3°。
	GuStyle.apply_seal($Root/MainView/HallSeal)
	GuStyle.apply_seal($SchoolsView/SchoolSeal)
	# 副题（v9 同步字体；v10 色值对齐基准 #707060）。
	_sync_subtitle($Root/MainView/HallSheet/HallIdentity/HallSubtitle)
	_sync_subtitle($SchoolsView/SchoolSide/SchoolSub)
	_apply_school_back_style(_schools_back)
	_apply_school_back_style(_schools_op_back)
	_apply_continue_style(_primary_action)
	_apply_menu_style(_journal_link)
	_apply_menu_style(_codex_link)
	_sync_build_ver()
	_apply_menu_style(_kill_link)
	_apply_menu_style(_settings_link)
	_apply_menu_style(_quit_link)


## v10：状态标签语义色（契约蓝 / 异变橄榄黄 / 诅咒砖红，基准图实测）。
func _sync_status_color(label: Label, color: Color) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)


## v9：副题（标题下方一行）与按钮文字同字体；v10 色值对齐基准 #707060 灰褐。
func _sync_subtitle(label: Label) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", GuStyle.BODY_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GuStyle.SUBTITLE_TEXT)


## v10（第三批 2026-09-08）：续入此世按钮 = 透明底 + 墨色大字 + 双色描边
## （基准图实测：黑字芯 + 蓝 #3880b8 描边 + 铁锈橙红 #803810 左投影）；hover 文字转朱砂。
func _apply_continue_style(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_font_override("font", GuStyle.TITLE_FONT)
	btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_focus_color", GuStyle.INK_PRIMARY)
	# 双色描边：蓝环绕 + 铁锈橙红左侧投影（近似基准左橙右蓝立体字）
	btn.add_theme_color_override("font_outline_color", GuStyle.BTN_OUTLINE_BLUE)
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_color_override("font_shadow_color", GuStyle.BTN_SHADOW_RUST)
	btn.add_theme_constant_override("shadow_offset_x", -1)
	btn.add_theme_constant_override("shadow_offset_y", 0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = GuStyle.HAIRLINE_COLOR
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0)
	hover.border_color = GuStyle.CINNABAR
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = GuStyle.HAIRLINE_COLOR
	focus.set_border_width_all(0)
	focus.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("focus", focus)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## v9：右栏菜单 = 纯文字（flat）；v10 色值对齐基准 #505040 灰褐。
## 版本号单源：schools 屏版本标签也读 GameVersion（SemVer 2.0）。
func _sync_build_ver() -> void:
	var school_ver: Label = $SchoolsView/SchoolSide/SchoolVer
	if school_ver != null:
		school_ver.text = GameVersionScript.display()


func _apply_menu_style(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_font_override("font", GuStyle.BODY_FONT)
	btn.add_theme_color_override("font_color", GuStyle.NAV_TEXT)
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_focus_color", GuStyle.NAV_TEXT)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(0, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## 线框稿 v1：ghost 返回按钮 = 透明底 + 1px 描边（纸墨一致，hover 转朱砂描边）。
func _apply_school_back_style(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color("56564c"))
	btn.add_theme_color_override("font_hover_color", Color("82463e"))
	btn.add_theme_color_override("font_pressed_color", Color("82463e"))
	btn.add_theme_color_override("font_focus_color", Color("56564c"))
	var ghost := StyleBoxFlat.new()
	ghost.bg_color = Color(0, 0, 0, 0)
	ghost.border_color = Color("b7b7ab")
	ghost.set_border_width_all(1)
	ghost.set_corner_radius_all(2)
	ghost.content_margin_left = 10
	ghost.content_margin_right = 10
	ghost.content_margin_top = 5
	ghost.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", ghost)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0)
	hover.border_color = Color("82463e")
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 5
	hover.content_margin_bottom = 5
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", ghost)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## 大厅屏淡青茅山背景层已随 v8 网点纸面退役（参考图为纯网点背景，无山水层）。


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
	_kill_link.pressed.connect(func(): _fire("open_kill"))
	_settings_link.pressed.connect(func(): _fire("open_settings"))
	_quit_link.pressed.connect(func(): _fire("quit"))
	_codex_back.pressed.connect(func(): _fire("back_to_hall"))
	_settings_back.pressed.connect(func(): _fire("back_to_hall"))
	_settings_quit.pressed.connect(func(): _fire("quit"))
	_journal_back.pressed.connect(func(): _fire("back_to_hall"))
	# S 减法：契约系统冻结，开局流收敛为 流派(+Buff) → 出发；契约屏不再占主路径。
	_confirm_school.pressed.connect(func(): _fire("new_run"))
	_schools_back.pressed.connect(func(): _fire("back_to_hall"))
	_schools_op_back.pressed.connect(func(): _fire("back_to_hall"))
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

	# v8：竖排大标题「問眞命簿」两行，品牌取快照（默认問眞）。
	_hall_title.text = str(_snapshot.get("brand_title", "問眞")) + "\n命簿"
	_hall_title.add_theme_font_override("font", GuStyle.TITLE_FONT)

	# 左栏：上一世止于 / 札记新得（v10 起 RichText bbcode 分段高亮：地点橙棕·境界蓝灰·札记青蓝）
	_prev_life.text = _prev_life_bbcode(str(_snapshot.get("prev_life", "上一世止于：—")))
	_prev_note.text = _prev_note_bbcode(str(_snapshot.get("prev_note", "札记新得：—")))

	# 中栏：今世劫数 + 续入此世
	_epoch.text = str(_snapshot.get("hall_epoch", "今世·第一劫"))
	var primary_label := "续入此世" if primary_action == "continue_run" else "开始此世"
	_primary_action.text = primary_label + " >"
	_apply_continue_style(_primary_action)
	# primary_action 是动态的，重绑前先断开旧连接避免重复触发。
	_rebind(_primary_action, func(): _fire(primary_action))

	var route := str(run_summary.get("route", "流派选择"))
	_primary_note.text = ("将从 " + route + " 继续。此世没有回溯。" if has_save
			else "将开始新的一世。此世没有回溯。")

	# 数值四列（修为/寿元/蛊囊/节点）
	_stat_val1.text = str(run_summary.get("rank", "0转"))
	_stat_val2.text = str(run_summary.get("lifespan", "0年"))
	_stat_val3.text = str(run_summary.get("gu_count", 0))
	_stat_val4.text = str(run_summary.get("node_count", 0))

	# 状态行三段（竖线分隔）：契约 / 异变 / 诅咒蛊
	_status1.text = "契约·%s" % _first_name(_snapshot.get("contracts", []), "—")
	_status2.text = "异变·%s" % _first_name(_snapshot.get("anomalies", []), "—")
	_status3.text = "%d只诅咒蛊" % int(run_summary.get("curse_count", 0))

	_build_ver.text = str(run_summary.get("build_label", "BUILD 0.9.0 · LOCAL"))


## v10：上一世行 bbcode——前缀墨色；值按「地点·境界」分段：地点橙棕、境界蓝灰；
## 无数据（—/未载入/空）整段灰。
func _prev_life_bbcode(raw: String) -> String:
	var prefix := "上一世止于："
	var value := raw.trim_prefix(prefix)
	if value == "" or value == "—" or value == "未载入":
		return "[color=%s]%s[/color][color=%s]%s[/color]" % [
			GuStyle.INK_PRIMARY.to_html(false), prefix,
			GuStyle.INK_SOFT.to_html(false), value if value != "" else "—"]
	var parts := value.split("·")
	if parts.size() >= 2:
		var body := "[color=%s]%s[/color][color=%s]·%s[/color]" % [
			GuStyle.HILITE_PLACE.to_html(false), parts[0],
			GuStyle.HILITE_REALM.to_html(false), "·".join(parts.slice(1))]
		return "[color=%s]%s[/color]%s" % [GuStyle.INK_PRIMARY.to_html(false), prefix, body]
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [
		GuStyle.INK_PRIMARY.to_html(false), prefix,
		GuStyle.HILITE_PLACE.to_html(false), value]


## v10：札记行 bbcode——前缀墨色，札记名青蓝；无数据整段灰。
func _prev_note_bbcode(raw: String) -> String:
	var prefix := "札记新得："
	var value := raw.trim_prefix(prefix)
	if value == "" or value == "—":
		return "[color=%s]%s[/color][color=%s]%s[/color]" % [
			GuStyle.INK_PRIMARY.to_html(false), prefix,
			GuStyle.INK_SOFT.to_html(false), "—"]
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [
		GuStyle.INK_PRIMARY.to_html(false), prefix,
		GuStyle.HILITE_NOTE.to_html(false), value]


## 从条目数组取首个可读名称（Dictionary 取 name/id，String 直接取）。
func _first_name(arr: Array, fallback: String) -> String:
	for e in arr:
		if e is Dictionary:
			return str(e.get("name", e.get("id", fallback)))
		return str(e)
	return fallback


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
	_build_about_panel()
	MasterTheme.apply_button(_settings_back, "action")
	MasterTheme.apply_button(_settings_quit, "danger")


## A-2 HIGH：游戏内「关于」署名界面。CC BY 3.0（game-icons.net 图标）要求
## 游戏内署名，仅 CREDITS.md 不够。静态文本随 SettingsView 呈现，不引入命令。
func _build_about_panel() -> void:
	if _about_panel == null:
		return
	_about_panel.setup("关于与署名", true, false)
	var host: Node = _about_panel.content_host
	_clear(host)
	host.add_child(_label("© 2026《蛊路求生》· 同人习作（原著《蛊真人》）",
			GuStyle.INK_HALL, 14))
	host.add_child(_label("第三方开源素材按各自许可证使用，来源如下：",
			GuStyle.INK_HALL, 13))
	host.add_child(_label("· 图标：game-icons.net（CC BY 3.0）——lorc、delapouite、",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("  carl-olsen 等作者，见 assets/wenzhen/icons/game-icons/",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("· 场景音乐：OpenGameArt（CC BY 4.0 / CC BY 3.0 / CC0），",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("  Tri-Tachyon 等作者，见 assets/audio/music/",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("· 音效：Kenney.nl（CC0，无需署名）",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("详细素材署名清单见项目 CREDITS.md。",
			GuStyle.INK_SOFT, 12))
	host.add_child(_label("CC BY 3.0：creativecommons.org/licenses/by/3.0/",
			GuStyle.INK_SOFT, 12))


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

## 线框稿 v1（2026-09-08）：4 列 × 5 行卡片网格 + 底部 Buff 复选 + 操作行。
## 卡片自建（Panel + VBox），选中态 = 朱砂描边 + 右上「已选」小印章。
func _refresh_schools() -> void:
	_build_school_grid()
	_build_school_buffs()

	var selected := str(_snapshot.get("selected_school", ""))
	var selected_name := str(_snapshot.get("selected_school_name", ""))
	_confirm_school.text = ("以%s入世 >" % selected_name) if selected != "" else "择定流派后入世 >"
	_apply_school_confirm_style(selected != "")


func _build_school_grid() -> void:
	_clear(_school_grid)
	var schools: Array = _snapshot.get("available_schools", [])
	var selected := str(_snapshot.get("selected_school", ""))
	var order := 1
	for index in schools.size():
		var s: Dictionary = schools[index]
		var sid := str(s.get("id", ""))
		var is_selected := sid == selected
		_school_grid.add_child(_school_card(s, sid, is_selected, order))
		order += 1


func _school_card(s: Dictionary, sid: String, is_selected: bool, order: int) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(218, 88)
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.SCHOOL_CARD_BG_SELECTED if is_selected else GuStyle.SCHOOL_CARD_BG_IDLE
	box.border_color = GuStyle.SCHOOL_CARD_BORDER_SELECTED if is_selected else GuStyle.SCHOOL_CARD_BORDER_IDLE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", box)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	card.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10.0
	body.offset_right = -10.0
	body.offset_top = 7.0
	body.offset_bottom = -5.0

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	body.add_child(name_row)
	var name_label := Label.new()
	name_label.text = str(s.get("name", sid))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	name_row.add_child(name_label)
	var order_label := Label.new()
	order_label.text = _school_order_text(order)
	order_label.add_theme_font_size_override("font_size", 9)
	order_label.add_theme_color_override("font_color", GuStyle.CORNER_TEXT)
	name_row.add_child(order_label)

	var summary := Label.new()
	summary.text = str(s.get("summary", ""))
	summary.add_theme_font_size_override("font_size", 9)
	summary.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(summary)

	var starters := Label.new()
	var starter_names: Array = s.get("starter_gu_names", [])
	var starter_text := "初始蛊 "
	if not starter_names.is_empty():
		var parts: Array[String] = []
		for n in starter_names:
			parts.append(str(n))
		starter_text += "、".join(parts)
	else:
		starter_text += "—"
	starters.text = starter_text
	starters.add_theme_font_size_override("font_size", 9)
	starters.add_theme_color_override("font_color", GuStyle.STAT_NAME_TEXT)
	starters.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(starters)

	if is_selected:
		var mark := Label.new()
		mark.text = "已选"
		mark.add_theme_font_size_override("font_size", 8)
		mark.add_theme_color_override("font_color", Color("82463e"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var mark_box := StyleBoxFlat.new()
		mark_box.border_color = Color("82463e")
		mark_box.set_border_width_all(1)
		mark_box.set_corner_radius_all(2)
		mark_box.content_margin_left = 4
		mark_box.content_margin_right = 4
		mark_box.content_margin_top = 1
		mark_box.content_margin_bottom = 1
		mark.add_theme_stylebox_override("normal", mark_box)
		card.add_child(mark)
		# 右上角「已选」小印章：锚定卡片右上。
		mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -34.0
		mark.offset_top = 0.0
		mark.offset_right = -1.0
		mark.offset_bottom = 17.0

	var click := Button.new()
	click.flat = true
	click.text = ""
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.pressed.connect(func(): _fire1("select_school", sid))
	card.add_child(click)
	return card


func _school_order_text(order: int) -> String:
	var digits := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
			"十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十"]
	if order >= 1 and order <= digits.size():
		return digits[order - 1]
	return str(order)


## 开局加成 Buff 复选（ghost）：目录投影为复选项，toggle 走命令面，UI 不写状态。
func _build_school_buffs() -> void:
	for child in _school_buff_row.get_children():
		if child.name != "SchoolBuffLabel":
			_school_buff_row.remove_child(child)
			child.queue_free()
	var selected_buffs: Array = _snapshot.get("selected_buffs", [])
	for b in _snapshot.get("available_buffs", []):
		var bid := str(b.get("id", "")) if b is Dictionary else str(b)
		var bname := str(b.get("name", bid)) if b is Dictionary else bid
		var bsum := str(b.get("summary", "")) if b is Dictionary else ""
		var check := CheckButton.new()
		check.text = bname + ("：" + bsum if bsum != "" else "")
		check.set_pressed_no_signal(selected_buffs.has(bid))
		check.toggled.connect(func(_on: bool): _fire1("toggle_buff", bid))
		_apply_school_check_style(check)
		_school_buff_row.add_child(check)


## 确认按钮（2026-09-08 基准同步）：选中流派 = 透明底墨字 + 蓝/橙红双色描边（对齐大厅主按钮）；
## 未选中 = 透明底灰字。
func _apply_school_confirm_style(active: bool) -> void:
	_confirm_school.add_theme_font_size_override("font_size", 22)
	_confirm_school.add_theme_font_override("font", GuStyle.TITLE_FONT)
	var fg := GuStyle.INK_PRIMARY if active else GuStyle.INK_SOFT
	_confirm_school.add_theme_color_override("font_color", fg)
	_confirm_school.add_theme_color_override("font_focus_color", fg)
	_confirm_school.add_theme_color_override("font_hover_color", GuStyle.CINNABAR if active else GuStyle.INK_SOFT)
	_confirm_school.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR if active else GuStyle.INK_SOFT)
	if active:
		_confirm_school.add_theme_color_override("font_outline_color", GuStyle.BTN_OUTLINE_BLUE)
		_confirm_school.add_theme_constant_override("outline_size", 1)
		_confirm_school.add_theme_color_override("font_shadow_color", GuStyle.BTN_SHADOW_RUST)
		_confirm_school.add_theme_constant_override("shadow_offset_x", -1)
		_confirm_school.add_theme_constant_override("shadow_offset_y", 0)
	else:
		_confirm_school.add_theme_constant_override("outline_size", 0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	_confirm_school.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0)
	hover.border_color = GuStyle.CINNABAR if active else GuStyle.HAIRLINE_COLOR
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	_confirm_school.add_theme_stylebox_override("hover", hover)
	_confirm_school.add_theme_stylebox_override("pressed", hover)
	_confirm_school.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_school_check_style(check: CheckButton) -> void:
	check.add_theme_font_size_override("font_size", 10)
	check.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	check.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	check.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	check.add_theme_color_override("font_focus_color", GuStyle.INK_SOFT)
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


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
