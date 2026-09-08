class_name KillScreenView
extends MarginContainer
## 杀招屏（线框稿 v2：研习录 3 卡 + 战斗栏位 3 槽）。
## 静态骨架（顶栏/标题行/印章/分区）预置在节点树里；研习卡与战斗槽走代码生成。
## 只读快照，写操作经 commands 出口。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _paper: ColorRect = $KillPaper
@onready var _seal_box: PanelContainer = $Root/HeaderRow/SealPanelContainer
@onready var _title_label: Label = $Root/HeaderRow/TitleLabel
@onready var _title_rule: ColorRect = $Root/HeaderRow/TitleRule
@onready var _sub_label: Label = $Root/HeaderRow/SubLabel
@onready var _study_row: HBoxContainer = $Root/KillStage/StageContent/StudyRow
@onready var _slot_row: HBoxContainer = $Root/KillStage/StageContent/SlotRow
@onready var _foot_note: Label = $Root/KillStage/StageContent/FootNote
@onready var _back_button: Button = $Root/BackRow/BackButton

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_back_button.pressed.connect(func(): _fire("back"))
	if not _snapshot.is_empty():
		_refresh()


## run_controller 的挂载入口（与各 master 场景同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	if _ready_done:
		_refresh()


func _refresh() -> void:
	_refresh_top_bar()
	_refresh_header()
	_refresh_study()
	_refresh_slots()


func _refresh_top_bar() -> void:
	if not _top_bar.has_method("set_data"):
		return
	_top_bar.set_data(
		_snapshot.get("resources", {}),
		_snapshot.get("contracts", []),
		_snapshot.get("anomalies", []),
		_snapshot.get("death_lines", {}),
		int(_snapshot.get("layer", -1)))


func _refresh_header() -> void:
	_title_label.text = _vertical_title(str(_snapshot.get("title", "杀招")))
	_sub_label.text = str(_snapshot.get("subtitle", "研习于战 · 一场一用"))


## 研习录：已研习实框卡 + 未研习虚框占位。
func _refresh_study() -> void:
	_clear_children(_study_row)
	var learned: Array = _snapshot.get("kill_moves", [])
	for m in learned:
		if not (m is Dictionary):
			continue
		_study_card(_study_row, m, true)
	var missing := int(_snapshot.get("study_slots", 3)) - learned.size()
	for i in missing:
		_study_card(_study_row, {}, false)


func _study_card(parent: Node, m: Dictionary, learned: bool) -> PanelContainer:
	var panel := GuPanelScene.instantiate()
	parent.add_child(panel)
	panel.custom_minimum_size = Vector2(300, 170)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.setup(str(m.get("name", "")), true, false)
	if not learned:
		var host: Node = panel.content_host
		var note := Label.new()
		note.text = "未研习\n（来源：战斗后研习）"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		host.add_child(note)
		return panel
	var host: Node = panel.content_host
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	host.add_child(box)
	if str(m.get("sequence_display", "")) != "":
		var seq := Label.new()
		seq.text = str(m.get("sequence_display", ""))
		seq.add_theme_font_size_override("font_size", 12)
		seq.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
		box.add_child(seq)
	var intro := Label.new()
	intro.text = str(m.get("intro", ""))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	box.add_child(intro)
	var meta := Label.new()
	meta.text = "研习自 · %s" % str(m.get("source", ""))
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	box.add_child(meta)
	var cost := Label.new()
	cost.text = "念头 %s" % str(m.get("cost", ""))
	cost.add_theme_font_size_override("font_size", 12)
	cost.add_theme_color_override("font_color", GuStyle.CINNABAR)
	cost.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(cost)
	return panel


## 战斗栏位：装备的杀招 + 空槽。
func _refresh_slots() -> void:
	_clear_children(_slot_row)
	var slots: Array = _snapshot.get("slots", [])
	for i in 3:
		if i < slots.size() and (slots[i] is Dictionary):
			_slot_card(_slot_row, slots[i])
		else:
			_slot_card(_slot_row, {})


func _slot_card(parent: Node, m: Dictionary) -> PanelContainer:
	var panel := GuPanelScene.instantiate()
	parent.add_child(panel)
	panel.custom_minimum_size = Vector2(300, 96)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var host: Node = panel.content_host
	if m.is_empty():
		panel.setup("", false, false)
		var empty := Label.new()
		empty.text = "空栏位"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", GuStyle.INK_MUTED)
		host.add_child(empty)
		return panel
	panel.setup(str(m.get("name", "")), true, false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	host.add_child(box)
	if str(m.get("sequence_display", "")) != "":
		var seq := Label.new()
		seq.text = str(m.get("sequence_display", ""))
		seq.add_theme_font_size_override("font_size", 11)
		seq.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
		box.add_child(seq)
	var cost := Label.new()
	cost.text = "念头 %s" % str(m.get("cost", ""))
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", GuStyle.CINNABAR)
	box.add_child(cost)
	return panel


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


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


func _vertical_title(flat: String) -> String:
	if flat == "":
		return ""
	var lines: Array[String] = []
	for ch in flat:
		lines.append(str(ch))
	return "\n".join(lines)


func _apply_base_fonts() -> void:
	_title_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_title_rule.color = Color("82463e")
	_title_rule.custom_minimum_size = Vector2(2, 0)
	_sub_label.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	_foot_note.add_theme_color_override("font_color", GuStyle.NOTE_TEXT)
	_paper.color = GuStyle.PAPER_HALL
	GuStyle.apply_seal(_seal_box, 3.0)
	_apply_menu_style(_back_button)
