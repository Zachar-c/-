class_name NpcScreenView
extends MarginContainer
## NPC 交涉屏（Godot 官方 .tscn 节点树版，替代 ui/screens/npc_screen.guitkx）。
##
## 三立场徽章（中立 / 敌视 / 极度仇恨）；恶名高亮；极度仇恨禁逃；
## 交易项 + 以物易物 + 交涉选项三栏。寿元代价交易走二次确认（死亡可预见）。
## 静态骨架预置在节点树里，三个滚动列表走代码生成。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _feedback_label: Label = $Root/FeedbackLabel
@onready var _npc_name_label: Label = $Root/HeaderRow/NpcNameLabel
@onready var _stance_label: Label = $Root/HeaderRow/StanceLabel
@onready var _stance_note_label: Label = $Root/HeaderRow/StanceNoteLabel
@onready var _notoriety_label: Label = $Root/HeaderRow/NotorietyLabel
@onready var _notoriety_note_label: Label = $Root/HeaderRow/NotorietyNoteLabel
@onready var _trade_panel: PanelContainer = $Root/primary_decision_surface/TradeColumn/TradePanel
@onready var _barter_panel: PanelContainer = $Root/primary_decision_surface/TradeColumn/BarterPanel
@onready var _talk_panel: PanelContainer = $Root/primary_decision_surface/TalkColumn/TalkPanel
@onready var _flee_button: Button = $Root/primary_decision_surface/TalkColumn/FleeButton
@onready var _leave_button: Button = $Root/primary_decision_surface/TalkColumn/LeaveButton
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false
## 待确认的寿元交易 offer id；空串表示无。
var _confirm_offer := ""


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_backdrop()
	_trade_panel.setup("交易", true, true)
	_barter_panel.setup("以物易物", true, true)
	_talk_panel.setup("交涉", false, true)
	_flee_button.pressed.connect(func(): _fire("flee"))
	_leave_button.pressed.connect(func(): _fire("leave"))
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
	_refresh_trade()
	_refresh_barter()
	_refresh_talk()
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
	var feedback := str(_snapshot.get("feedback", ""))
	_feedback_label.text = feedback
	_feedback_label.visible = feedback != ""

	_npc_name_label.text = str(_snapshot.get("npc_name", "无名散修"))
	var stance := str(_snapshot.get("stance", "中立"))
	_stance_label.text = "立场·" + stance
	_stance_label.add_theme_color_override("font_color", _stance_color(stance))
	_stance_note_label.text = str(_snapshot.get("stance_note", ""))
	_notoriety_label.text = "恶名 " + str(int(_snapshot.get("notoriety", 0)))
	_notoriety_note_label.text = str(_snapshot.get("notoriety_note", ""))
	# 极度仇恨禁逃：撤退按钮整体隐藏而非置灰，避免出现"能点但注定失败"的死按钮。
	_flee_button.visible = bool(_snapshot.get("can_flee", true))


func _refresh_trade() -> void:
	var has_npc := bool(_snapshot.get("has_npc", true))
	_barter_panel.visible = has_npc
	var list := _ensure_scroll_list(_trade_panel, "OfferScroll")
	_clear_children(list)
	if not has_npc:
		list.add_child(_label_of(str(_snapshot.get("no_npc_note", "")), GuStyle.INK_SOFT, 13))
		return
	var offers: Array = _snapshot.get("offers", [])
	for o in offers:
		if o is Dictionary:
			_build_offer_row(list, o)
	if offers.is_empty():
		list.add_child(_label_of("（无交易项）", GuStyle.INK_SOFT, 14))


func _refresh_barter() -> void:
	if not bool(_snapshot.get("has_npc", true)):
		return
	var list := _ensure_scroll_list(_barter_panel, "BarterScroll")
	_clear_children(list)
	var barter: Array = _snapshot.get("barter", [])
	for b in barter:
		if b is Dictionary:
			_build_barter_row(list, b)
	if barter.is_empty():
		list.add_child(_label_of("（无易物项）", GuStyle.INK_SOFT, 14))


func _refresh_talk() -> void:
	var list := _ensure_scroll_list(_talk_panel, "TalkScroll")
	_clear_children(list)
	var options: Array = _snapshot.get("talk_options", [])
	for t in options:
		if t is Dictionary:
			_build_talk_row(list, t)
	if options.is_empty():
		list.add_child(_label_of("（无交涉选项）", GuStyle.INK_SOFT, 14))


# ---------------------------------------------------------------------------
# 动态行构建
# ---------------------------------------------------------------------------

func _build_offer_row(list: Node, o: Dictionary) -> void:
	var oid := str(o.get("id", ""))
	var oexec := bool(o.get("executable", true))
	var ocursed := bool(o.get("curse_warning", false))
	var panel := GuPanelScene.instantiate()
	# 先入树再配内容：GuPanelView.content_host 是 @onready，add_child 触发 _ready() 后才有值。
	list.add_child(panel)
	panel.setup("", true, false)
	var row := _row_body(panel)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	text_col.add_child(_label_of(str(o.get("name", "")), GuStyle.INK_PRIMARY, 15))
	text_col.add_child(_label_of(str(o.get("desc", "")), GuStyle.INK_SOFT, 12))
	text_col.add_child(_label_of("价格：" + str(o.get("price", "")), GuStyle.ANOMALY_YELLOW, 13))
	var block := str(o.get("block_reason", ""))
	if block != "":
		text_col.add_child(_label_of("不可用 · " + block, GuStyle.CINNABAR, 12))

	var trade := Button.new()
	trade.text = str(o.get("name", "交易"))
	trade.disabled = not oexec
	MasterTheme.apply_button(trade, "danger" if ocursed else "action")
	trade.pressed.connect(func():
		# 寿元代价走二次确认；其余直接下单（均已由领域给出 executable/block_reason）。
		if ocursed and oexec:
			_confirm_offer = oid
			_refresh_confirm_dialog()
		elif oexec:
			_fire("buy", oid))
	row.add_child(trade)


func _build_barter_row(list: Node, b: Dictionary) -> void:
	var bid := str(b.get("id", ""))
	var bexec := bool(b.get("executable", true))
	var panel := GuPanelScene.instantiate()
	list.add_child(panel)
	panel.setup("", true, false)
	var row := _row_body(panel)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	text_col.add_child(_label_of(
			"%s 换 %s" % [str(b.get("give", "")), str(b.get("take", ""))],
			GuStyle.ANOMALY_YELLOW, 14))
	text_col.add_child(_label_of(str(b.get("note", "")), GuStyle.INK_SOFT, 12))
	text_col.add_child(_label_of("持有可交付：%d" % int(b.get("owned", 0)), GuStyle.INK_SOFT, 12))
	var block := str(b.get("block_reason", ""))
	if block != "":
		text_col.add_child(_label_of("不可用 · " + block, GuStyle.CINNABAR, 12))

	var swap := Button.new()
	swap.text = str(b.get("name", "交换"))
	swap.disabled = not bexec
	MasterTheme.apply_button(swap, "action")
	swap.pressed.connect(func(): _fire("barter", bid))
	row.add_child(swap)


func _build_talk_row(list: Node, t: Dictionary) -> void:
	var tid := str(t.get("id", ""))
	var texec := bool(t.get("executable", true))
	var tdanger := bool(t.get("danger", false))
	var tblock := str(t.get("block_reason", ""))
	var panel := GuPanelScene.instantiate()
	list.add_child(panel)
	panel.setup(str(t.get("label", "")), true, false)
	panel.content_host.add_child(_label_of(str(t.get("detail", "")), GuStyle.INK_PRIMARY, 13))
	if tblock != "":
		panel.content_host.add_child(_label_of("不可用 · " + tblock, GuStyle.CINNABAR, 12))
	var talk := Button.new()
	talk.text = str(t.get("label", "交涉"))
	talk.disabled = not texec
	MasterTheme.apply_button(talk, "danger" if tdanger else "action")
	talk.pressed.connect(func(): _fire("talk", tid))
	panel.content_host.add_child(talk)


func _refresh_confirm_dialog() -> void:
	if _confirm_offer == "":
		_confirm_dialog.close()
		return
	var offer := _offer_by_id(_confirm_offer)
	if offer.is_empty():
		_confirm_offer = ""
		_confirm_dialog.close()
		return
	var precheck := str(offer.get("precheck", ""))
	if precheck == "":
		precheck = "价格：" + str(offer.get("price", "")) + " · 执行前请确认余量"
	_confirm_dialog.open(
		str(offer.get("name", "")) + "：" + str(offer.get("desc", "")),
		func():
			var oid := _confirm_offer
			_confirm_offer = ""
			_fire("buy", oid),
		func():
			_confirm_offer = ""
			_confirm_dialog.close(),
		"⚠ 寿元交易 · 预检", precheck, "确认支付", "取消")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

## 在面板内容宿主里按需建一个滚动列表（ScrollContainer + List），返回 List。
func _ensure_scroll_list(panel: PanelContainer, name_hint: String) -> Node:
	var host: Node = panel.content_host
	var scroll: Node = host.get_node_or_null(name_hint)
	if scroll != null:
		return scroll.get_node("List")
	var new_scroll := ScrollContainer.new()
	new_scroll.name = name_hint
	new_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(new_scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	new_scroll.add_child(list)
	return list


## 给无标题内容面板铺一层横向行容器（名称/描述 + 右侧动作按钮）。
func _row_body(panel: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.content_host.add_child(row)
	return row


func _fire(key: String, arg = null) -> void:
	if not _commands.has(key):
		return
	if arg == null:
		_commands[key].call()
	else:
		_commands[key].call(arg)


func _offer_by_id(offer_id: String) -> Dictionary:
	for o in _snapshot.get("offers", []):
		if o is Dictionary and str(o.get("id", "")) == offer_id:
			return o
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


func _stance_color(stance: String) -> Color:
	match stance:
		"敌视": return GuStyle.ANOMALY_YELLOW
		"极度仇恨": return GuStyle.CINNABAR
		_: return GuStyle.JADE


func _apply_stage_backdrop() -> void:
	var paper := $NpcPaper as ColorRect
	paper.color = GuStyle.PAPER_HALL

func _apply_base_fonts() -> void:
	_npc_name_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_stance_note_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_notoriety_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_notoriety_note_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_feedback_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MasterTheme.apply_button(_flee_button, "cancel")
	MasterTheme.apply_button(_leave_button, "action")
