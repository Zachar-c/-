class_name EncounterScreenView
extends MarginContainer
## 遭遇屏（Godot 官方 .tscn 节点树版，替代 ui/screens/encounter_screen.guitkx）。
##
## 只读快照 + commands（choose_option / confirm_danger / leave）；危险行动走二次确认。
## 静态骨架预置在节点树里，行动卡 / 情报 / 状态 / 蛊囊走代码生成。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")
const GuTipScene := preload("res://scenes/ui/widgets/gu_tooltip_view.tscn")
const PlayerPortrait := preload("res://assets/wenzhen/hall/first-life-character.png")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _encounter_stage: PanelContainer = $Root/EncounterStage
@onready var _feedback_label: Label = $Root/EncounterStage/StageContent/FeedbackLabel
@onready var _brief_panel: PanelContainer = $Root/EncounterStage/StageContent/primary_decision_surface/MainColumn/BriefPanel
@onready var _action_list: VBoxContainer = $Root/EncounterStage/StageContent/primary_decision_surface/MainColumn/ActionScroll/ActionList
@onready var _leave_button: Button = $Root/EncounterStage/StageContent/primary_decision_surface/MainColumn/LeaveButton
@onready var _status_panel: PanelContainer = $Root/EncounterStage/StageContent/primary_decision_surface/SideColumn/StatusPanel
@onready var _satchel_panel: PanelContainer = $Root/EncounterStage/StageContent/primary_decision_surface/SideColumn/SatchelPanel
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false
## 待确认的危险行动 id；空串表示无。
var _confirming := ""


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_style()
	_leave_button.pressed.connect(func(): _fire("leave"))
	_brief_panel.setup("遭遇", true, false)
	_status_panel.setup("自身状态", false, false)
	_satchel_panel.setup("蛊囊", false, false)
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
	_refresh_brief()
	_refresh_actions()
	_refresh_side()
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


func _refresh_brief() -> void:
	var feedback := str(_snapshot.get("feedback", ""))
	_feedback_label.text = feedback
	_feedback_label.visible = feedback != ""

	var node: Dictionary = _snapshot.get("node", {})
	_brief_panel.setup("遭遇 · %s" % str(node.get("type", "")), true, false)
	var host := _ensure_box(_brief_panel, "BriefBody")
	_clear_children(host)
	host.add_child(_label_of(str(node.get("title", "")), GuStyle.ANOMALY_YELLOW, 18))
	host.add_child(_label_of(str(node.get("desc", "")), GuStyle.INK_PRIMARY, 14))
	var intel: Dictionary = _snapshot.get("intel", {})
	if not intel.is_empty():
		host.add_child(_build_intel_tip(intel))


func _build_intel_tip(intel: Dictionary) -> Node:
	var tip := GuTipScene.instantiate()
	var weakness := str(intel.get("weakness", ""))
	var intel_cost := str(intel.get("cost", ""))
	var intel_curse := bool(intel.get("curse_warning", false))
	# BriefBody owns attachment. Setup runs after this tooltip's @onready fields exist.
	tip.ready.connect(func(): tip.setup(
			"情报 / 弱点", "", weakness, "", intel_cost, "", intel_curse), CONNECT_ONE_SHOT)
	return tip


func _refresh_actions() -> void:
	_clear_children(_action_list)
	var actions: Array = _snapshot.get("actions", [])
	var has_leave := false
	for a in actions:
		if not (a is Dictionary):
			continue
		if str(a.get("id", "")) == "leave":
			has_leave = true
		_build_action_card(a)
	if actions.is_empty():
		_action_list.add_child(_label_of("（当前无可用行动）", GuStyle.INK_SOFT, 14))
	# 行动列表里若已含 leave 项，就不再额外给一个离开按钮。
	_leave_button.visible = not has_leave


func _build_action_card(a: Dictionary) -> void:
	var aid := str(a.get("id", ""))
	var dangerous := bool(a.get("dangerous", false))
	var is_leave: bool = aid == "leave"
	var panel := GuPanelScene.instantiate()
	_action_list.add_child(panel)
	panel.setup(str(a.get("label", "")), true, false)

	var detail_color := GuStyle.CINNABAR if dangerous else GuStyle.INK_SOFT
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 4)
	var detail_icon := GuIconView.new()
	detail_icon.setup("gi_scroll", detail_color, GuIconView.SIZE_SMALL)
	detail_row.add_child(detail_icon)
	detail_row.add_child(_label_of(str(a.get("detail", "")), detail_color, 14))
	panel.content_host.add_child(detail_row)

	var has_tip: bool = (a.has("quality") or a.has("effect") or a.has("synergy")
			or a.has("cost") or bool(a.get("curse_warning", false)))
	if has_tip:
		var tip := GuTipScene.instantiate()
		panel.content_host.add_child(tip)
		# 拆出中间变量：嵌套 str(a.get(...)) 层层套括号极易漏配，可读性也差。
		var tip_quality := str(a.get("quality", ""))
		var tip_effect := str(a.get("effect", ""))
		var tip_synergy := str(a.get("synergy", ""))
		var tip_cost := str(a.get("cost", ""))
		var tip_curse := bool(a.get("curse_warning", false))
		tip.setup(tip_quality, tip_quality, tip_effect, tip_synergy, tip_cost, "", tip_curse)

	var btn := Button.new()
	btn.text = "离开" if is_leave else ("确认此危险行动" if dangerous else "选择")
	MasterTheme.apply_button(btn, "danger" if dangerous else "action")
	btn.pressed.connect(func():
		# 危险行动先二次确认；其余（含离开）直接下发。
		if dangerous:
			_confirming = aid
			_refresh_confirm_dialog()
		elif is_leave:
			_fire("leave")
		else:
			_fire("choose_option", aid))
	panel.content_host.add_child(btn)


func _refresh_side() -> void:
	var player: Dictionary = _snapshot.get("player", {})
	var status_box := _ensure_box(_status_panel, "StatusBody")
	_clear_children(status_box)
	status_box.add_child(_label_of("气血 %d/%d" % [
			int(player.get("hp", 0)), maxi(int(player.get("max_hp", 1)), 1)], GuStyle.JADE, 14))
	status_box.add_child(_label_of("魂魄 %d" % int(player.get("soul", 0)), GuStyle.JADE, 14))
	status_box.add_child(_label_of("真元 %d" % int(player.get("primordial", 0)),
			GuStyle.ANOMALY_YELLOW, 14))
	status_box.add_child(_label_of("元石 %d" % int(player.get("stone", 0)),
			GuStyle.ANOMALY_YELLOW, 14))

	var satchel_box := _ensure_box(_satchel_panel, "SatchelBody")
	_clear_children(satchel_box)
	var gu_names: Array = player.get("gu_names", [])
	for g in gu_names:
		satchel_box.add_child(_label_of("· " + str(g), GuStyle.INK_PRIMARY, 13))
	if gu_names.is_empty():
		satchel_box.add_child(_label_of("（蛊囊空空）", GuStyle.INK_SOFT, 13))


func _refresh_confirm_dialog() -> void:
	if _confirming == "":
		_confirm_dialog.close()
		return
	var action := _action_by_id(_confirming)
	if action.is_empty():
		_confirming = ""
		_confirm_dialog.close()
		return
	_confirm_dialog.open(
		str(action.get("detail", "")),
		func():
			var aid := _confirming
			_confirming = ""
			_fire("confirm_danger", aid),
		func():
			_confirming = ""
			_confirm_dialog.close(),
		"⚠ 危险行动",
		"危险行动可能损耗寿元 / 魂魄 / 触发反噬，执行前请确认余量。")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

## 面板内容宿主里按需建一个命名 VBoxContainer（各面板内容每次重建，容器只建一次）。
func _ensure_box(panel: PanelContainer, name_hint: String) -> Node:
	var host: Node = panel.content_host
	var existing: Node = host.get_node_or_null(name_hint)
	if existing != null:
		return existing
	var box := VBoxContainer.new()
	box.name = name_hint
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	host.add_child(box)
	return box


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _action_by_id(action_id: String) -> Dictionary:
	for a in _snapshot.get("actions", []):
		if a is Dictionary and str(a.get("id", "")) == action_id:
			return a
	return {}


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _label_of(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_base_fonts() -> void:
	_feedback_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MasterTheme.apply_button(_leave_button, "action")


## 遭遇屏舞台：以大厅屏为基准——纸面 + 网点背景（公共规范），面板透明透出纸底。
func _apply_stage_style() -> void:
	var paper := $EncounterPaper as ColorRect
	paper.color = GuStyle.PAPER_HALL
	var stage_box := StyleBoxFlat.new()
	stage_box.bg_color = Color(0, 0, 0, 0)
	stage_box.set_border_width_all(GuStyle.HAIRLINE)
	stage_box.border_color = GuStyle.HAIRLINE_COLOR
	stage_box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	_encounter_stage.add_theme_stylebox_override("panel", stage_box)
