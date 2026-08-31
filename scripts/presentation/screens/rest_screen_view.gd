class_name RestScreenView
extends MarginContainer
## 休整 / 闭关屏（Godot 官方 .tscn 节点树版，替代 ui/screens/rest_screen.guitkx）。
##
## 强制二选一不可全拿；洗髓换骨走寿元支付二次确认（R2.3 死亡可预见）。
## 静态骨架（顶栏、标题行、主决策面、移除面板、成长面板、离开、确认弹窗）预置在节点树里；
## 数量不定的内容（休整选项、移除目标、突破成长）走代码生成。
## 本地交互状态只有两个：待确认的洗髓选项 id、是否正在选移除目标。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _title_label: Label = $Root/HeaderRow/TitleLabel
@onready var _note_label: Label = $Root/HeaderRow/NoteLabel
@onready var _primary_surface: PanelContainer = $Root/primary_decision_surface
@onready var _remove_panel: PanelContainer = $Root/RemovePanel
@onready var _growth_panel: PanelContainer = $Root/GrowthPanel
@onready var _leave_button: Button = $Root/LeaveButton
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false
## 待确认的洗髓换骨选项 id；空串表示无。
var _wash_confirm := ""
## 是否正在选择要移除的蛊虫。
var _remove_select := false


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_leave_button.pressed.connect(func(): _fire("leave"))
	_primary_surface.setup("休整选项", true, false)
	_remove_panel.setup("选择要移除的蛊", true, false)
	_growth_panel.setup("突破成长 · 多选一", false, true)
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
	_refresh_choices()
	_refresh_remove_panel()
	_refresh_growth_panel()
	_refresh_confirm_dialog()


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
	_title_label.text = str(_snapshot.get("title", "闭关 · 休整"))
	_note_label.text = str(_snapshot.get("note", "强制二选一，不可全拿"))


func _refresh_choices() -> void:
	var row := _ensure_content_host(_primary_surface, "ChoiceRow")
	_clear_children(row)
	var choices: Array = _snapshot.get("choices", [])
	for c in choices:
		if not (c is Dictionary):
			continue
		_build_choice_card(row, c)
	if choices.is_empty():
		row.add_child(_note_label_of("（当前无休整选项）"))


func _build_choice_card(row: Node, c: Dictionary) -> void:
	var cid := str(c.get("id", ""))
	var disabled := bool(c.get("disabled", false))
	var is_wash: bool = cid == "wash"

	var panel := GuPanelScene.instantiate()
	# 先入树再配内容：GuPanelView.content_host 是 @onready，add_child 触发 _ready() 后才有值。
	row.add_child(panel)
	panel.setup(str(c.get("label", "")), true, false)

	var detail := _body_label(str(c.get("detail", "")), GuStyle.INK_PRIMARY, 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.content_host.add_child(detail)
	var cost := str(c.get("cost", ""))
	if cost != "":
		panel.content_host.add_child(_body_label(cost, GuStyle.ANOMALY_YELLOW, 13))
	var reason := str(c.get("reason", ""))
	if reason != "":
		panel.content_host.add_child(_body_label(reason, GuStyle.ANOMALY_YELLOW, 12))

	var choose := Button.new()
	choose.text = "选择"
	choose.disabled = disabled
	MasterTheme.apply_button(choose, "danger" if is_wash else "action")
	choose.pressed.connect(func():
		# 洗髓换骨走寿元支付二次确认；移除蛊先展开目标选择；其余直接下发。
		if is_wash:
			_wash_confirm = cid
			_remove_select = false
			_refresh_confirm_dialog()
		elif cid == "remove":
			_wash_confirm = ""
			_remove_select = true
			_refresh_confirm_dialog()
			_refresh_remove_panel()
		else:
			_fire("choose", cid))
	panel.content_host.add_child(choose)


func _refresh_remove_panel() -> void:
	_remove_panel.visible = _remove_select
	if not _remove_select:
		return
	var host := _ensure_content_host(_remove_panel, "RemoveBody")
	_clear_children(host)
	for target in _snapshot.get("remove_targets", []):
		if not (target is Dictionary):
			continue
		var tid := str(target.get("id", ""))
		var blocked := bool(target.get("blocked", false))
		var reason := str(target.get("reason", ""))
		var pick := Button.new()
		pick.text = str(target.get("name", tid)) + (" · " + reason if blocked else "")
		pick.disabled = blocked
		MasterTheme.apply_button(pick, "action")
		pick.pressed.connect(func(): _fire2("choose", "remove", tid))
		host.add_child(pick)
	var cancel := Button.new()
	cancel.text = "取消选择"
	MasterTheme.apply_button(cancel, "cancel")
	cancel.pressed.connect(func():
		_remove_select = false
		_refresh_remove_panel())
	host.add_child(cancel)


func _refresh_growth_panel() -> void:
	var growth: Array = _snapshot.get("growth", [])
	var show_growth: bool = bool(_snapshot.get("is_ascension", false)) and growth.size() > 0
	_growth_panel.visible = show_growth
	if not show_growth:
		return
	var row := _ensure_content_host(_growth_panel, "GrowthRow")
	_clear_children(row)
	for g in growth:
		if not (g is Dictionary):
			continue
		_build_growth_card(row, g)


func _build_growth_card(row: Node, g: Dictionary) -> void:
	var gid := str(g.get("id", ""))
	var panel := GuPanelScene.instantiate()
	row.add_child(panel)
	panel.setup(str(g.get("label", "")), true, false)
	panel.content_host.add_child(_body_label(str(g.get("detail", "")), GuStyle.INK_PRIMARY, 14))
	var cost := str(g.get("cost", ""))
	if cost != "":
		panel.content_host.add_child(_body_label(cost, GuStyle.ANOMALY_YELLOW, 13))
	var pick := Button.new()
	pick.text = "选择"
	MasterTheme.apply_button(pick, "action")
	pick.pressed.connect(func(): _fire("choose", gid))
	panel.content_host.add_child(pick)


func _refresh_confirm_dialog() -> void:
	if _wash_confirm == "":
		_confirm_dialog.close()
		return
	var choice := _choice_by_id(_wash_confirm)
	if choice.is_empty():
		_wash_confirm = ""
		_confirm_dialog.close()
		return
	_confirm_dialog.open(
		str(choice.get("detail", "")),
		func():
			var cid := _wash_confirm
			_wash_confirm = ""
			_fire("confirm_wash"),
		func():
			_wash_confirm = ""
			_confirm_dialog.close(),
		"洗髓换骨 · 寿元支付",
		"代价：" + str(choice.get("cost", "")) + " · 一局一次 · 执行前预检寿元",
		"确认支付", "取消")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

## 面板实例的内容宿主在 .tscn 里看不到，按需建一个命名容器并挂上。
func _ensure_content_host(panel: PanelContainer, name_hint: String) -> Node:
	var host: Node = panel.content_host
	var existing: Node = host.get_node_or_null(name_hint)
	if existing != null:
		return existing
	var box := HBoxContainer.new()
	box.name = name_hint
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(box)
	return box


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _fire2(key: String, arg1, arg2) -> void:
	if _commands.has(key):
		_commands[key].call(arg1, arg2)


func _choice_by_id(choice_id: String) -> Dictionary:
	for c in _snapshot.get("choices", []):
		if c is Dictionary and str(c.get("id", "")) == choice_id:
			return c
	return {}


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _body_label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _note_label_of(text: String) -> Label:
	return _body_label(text, GuStyle.INK_SOFT, 14)


func _apply_base_fonts() -> void:
	_title_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_note_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	MasterTheme.apply_button(_leave_button, "action")
