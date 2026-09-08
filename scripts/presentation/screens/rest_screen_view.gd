class_name RestScreenView
extends MarginContainer
## 休整 / 闭关屏（Godot 官方 .tscn 节点树版，替代 ui/screens/rest_screen.guitkx）。
##
## 强制二选一不可全拿；洗髓换骨走寿元支付二次确认（R2.3 死亡可预见）。
## 静态骨架（顶栏、标题行、主决策面、移除面板、成长面板、离开、确认弹窗）预置在节点树里；
## 数量不定的内容（休整选项、移除目标、突破成长）走代码生成。
## 本地交互状态只有三个：待确认的洗髓选项 id、待确认的 skip 选项 id、是否正在选目标。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuPanelScene := preload("res://scenes/ui/widgets/gu_panel.tscn")
const PlayerPortrait := preload("res://assets/wenzhen/hall/first-life-character.png")

@onready var _top_bar: PanelContainer = $Root/TopBar
@onready var _rest_stage: Control = $Root/RestStage
@onready var _vtitle: Label = $Backdrop/VTitle
@onready var _redline: ColorRect = $Backdrop/RedLine
@onready var _sub_label: Label = $Backdrop/SubLabel
@onready var _note_label: Label = $Root/RestStage/StageContent/NoteLabel
@onready var _primary_surface: PanelContainer = $Root/RestStage/StageContent/primary_decision_surface
@onready var _remove_panel: PanelContainer = $Root/RestStage/StageContent/RemovePanel
@onready var _growth_panel: PanelContainer = $Root/RestStage/StageContent/GrowthPanel
@onready var _leave_button: Button = $Root/RestStage/StageContent/LeaveRow/LeaveButton
@onready var _seal_panel: PanelContainer = $Root/RestStage/SealPanel
@onready var _confirm_dialog: PanelContainer = $Root/ConfirmDialog

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()，未就绪时只收数据，_ready() 里补刷新。
var _ready_done := false
## 待确认的洗髓换骨选项 id；空串表示无。
var _wash_confirm := ""
## 待确认的放弃收益选项 id；空串表示无。
var _skip_confirm := ""
## 当前目标选择面板正在收集的目标类型 id（空串表示无）。
var _target_cid := ""
## 当前目标选择面板读取的 snapshot 列表 key（upgrade_targets / remove_card_targets / imprint_targets / curse_targets）。
var _target_list_key := ""
## 是否正在选择要移除的蛊虫。
var _remove_select := false


func _ready() -> void:
	_ready_done = true
	_apply_base_fonts()
	_apply_stage_style()
	_leave_button.pressed.connect(func(): _fire("leave"))
	_primary_surface.setup("休整选项", true, true)
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
	_sub_label.text = "休整 · " + str(_snapshot.get("note", "强制二选一，不可全拿"))
	_note_label.text = "本次休整仅可择其一 · 洗髓换骨确认后须支付寿元，死亡可预见"


func _refresh_choices() -> void:
	var row := _ensure_content_host(_primary_surface, "ChoiceRow", 3)
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
	var is_skip: bool = cid == "skip"
	var needs_target: bool = cid in ["upgrade_card", "remove_card", "remove_imprint", "remove_curse"]

	var panel := GuPanelScene.instantiate()
	# 先入树再配内容：GuPanelView.content_host 是 @onready，add_child 触发 _ready() 后才有值。
	row.add_child(panel)
	panel.setup(str(c.get("label", "")), true, false)

	var detail := _body_label(str(c.get("detail", "")), GuStyle.INK_PRIMARY, 14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.content_host.add_child(detail)
	var cost := str(c.get("cost", ""))
	if cost != "":
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 4)
		var cost_icon := GuIconView.new()
		cost_icon.setup("gi_coin", GuStyle.ANOMALY_YELLOW, GuIconView.SIZE_SMALL)
		cost_row.add_child(cost_icon)
		cost_row.add_child(_body_label(cost, GuStyle.CINNABAR, 13))
		panel.content_host.add_child(cost_row)
	var reason := str(c.get("reason", ""))
	if reason != "":
		panel.content_host.add_child(_body_label(reason, GuStyle.CINNABAR, 12))

	var choose := Button.new()
	choose.text = "选择"
	choose.disabled = disabled
	MasterTheme.apply_button(choose, "danger" if is_wash else ("warning" if is_skip else "action"))
	choose.pressed.connect(func():
		# 洗髓换骨走寿元支付二次确认；skip 走通用确认弹窗；目标类先展开目标选择；其余直接下发。
		if is_wash:
			_wash_confirm = cid
			_skip_confirm = ""
			_remove_select = false
			_refresh_confirm_dialog()
		elif is_skip:
			_skip_confirm = cid
			_wash_confirm = ""
			_remove_select = false
			_refresh_confirm_dialog()
		elif needs_target:
			_wash_confirm = ""
			_skip_confirm = ""
			_remove_select = false
			_open_target_picker(cid)
		else:
			_wash_confirm = ""
			_skip_confirm = ""
			_fire("choose", cid))
	panel.content_host.add_child(choose)


# Target picker routes each new rest mode to its own snapshot target list.
# Domain rules (cursed drop block, meta_rule exclusion, curse presence) are
# already encoded in the snapshot's `disabled`/`reason`/`blocked` fields.
func _open_target_picker(cid: String) -> void:
	_target_cid = cid
	match cid:
		"upgrade_card": _target_list_key = "upgrade_targets"
		"remove_card": _target_list_key = "remove_card_targets"
		"remove_imprint": _target_list_key = "imprint_targets"
		"remove_curse": _target_list_key = "curse_targets"
		_: _target_list_key = ""
	_remove_select = true
	_refresh_remove_panel()


func _refresh_remove_panel() -> void:
	_remove_panel.visible = _remove_select
	if not _remove_select:
		return
	# Backwards compat: legacy "remove" / "remove_targets" still routes here.
	var list_key := _target_list_key if _target_list_key != "" else "remove_targets"
	# Force the legacy remove list to use the new key when removing via the
	# deprecated "remove" choice id (kept so existing calls keep working).
	if _target_cid == "remove" and _target_list_key == "":
		list_key = "remove_card_targets"
	var header_label := "选择目标"
	if _target_cid == "remove_card":
		header_label = "选择要移除的蛊"
	elif _target_cid == "upgrade_card":
		header_label = "选择要强化的蛊卡"
	elif _target_cid == "remove_imprint":
		header_label = "选择要抹除的印记"
	elif _target_cid == "remove_curse":
		header_label = "选择要拔除的反噬"
	elif _target_cid == "remove":
		header_label = "选择要移除的蛊"
	_remove_panel.title = header_label
	var host := _ensure_content_host(_remove_panel, "RemoveBody")
	_clear_children(host)
	for target in _snapshot.get(list_key, []):
		if not (target is Dictionary):
			continue
		var tid := str(target.get("id", ""))
		var blocked := bool(target.get("blocked", false))
		var reason := str(target.get("reason", ""))
		var label_text := str(target.get("name", tid))
		var layer_note := ""
		if _target_cid == "remove_curse":
			layer_note = " · " + str(int(target.get("layers", 0))) + " 层"
		if blocked:
			label_text += " · " + reason
		var pick := Button.new()
		pick.text = label_text + layer_note
		pick.disabled = blocked
		MasterTheme.apply_button(pick, "action")
		pick.pressed.connect(func(): _fire2("choose", _target_cid, tid))
		host.add_child(pick)
	var cancel := Button.new()
	cancel.text = "取消选择"
	MasterTheme.apply_button(cancel, "cancel")
	cancel.pressed.connect(func():
		_remove_select = false
		_target_cid = ""
		_target_list_key = ""
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
		panel.content_host.add_child(_body_label(cost, GuStyle.CINNABAR, 13))
	var pick := Button.new()
	pick.text = "选择"
	MasterTheme.apply_button(pick, "action")
	pick.pressed.connect(func(): _fire("choose", gid))
	panel.content_host.add_child(pick)


func _refresh_confirm_dialog() -> void:
	if _wash_confirm == "" and _skip_confirm == "":
		_confirm_dialog.close()
		return
	var choice := _choice_by_id(_wash_confirm if _wash_confirm != "" else _skip_confirm)
	if choice.is_empty():
		_wash_confirm = ""
		_skip_confirm = ""
		_confirm_dialog.close()
		return
	var is_wash := _wash_confirm != ""
	var title := "洗髓换骨 · 寿元支付" if is_wash else "放弃本次休整收益"
	var cost_line := ""
	if is_wash:
		cost_line = "代价：" + str(choice.get("cost", "")) + " · 一局一次 · 执行前预检寿元"
	else:
		cost_line = "本次休整无收益可用，确认后将记录一次放弃并解锁离场。"
	_confirm_dialog.open(
		str(choice.get("detail", "")),
		func():
			var cid := _wash_confirm if _wash_confirm != "" else _skip_confirm
			_wash_confirm = ""
			_skip_confirm = ""
			if is_wash:
				_play_seal_stamp()
				_fire("confirm_wash")
			else:
				_fire("choose", cid),
		func():
			_wash_confirm = ""
			_skip_confirm = ""
			_confirm_dialog.close(),
		title,
		cost_line,
		"确认支付" if is_wash else "确认放弃",
		"取消")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

## 面板实例的内容宿主在 .tscn 里看不到，按需建一个命名容器并挂上。
func _ensure_content_host(panel: PanelContainer, name_hint: String, columns := 0) -> Node:
	var host: Node = panel.content_host
	var existing: Node = host.get_node_or_null(name_hint)
	if existing != null:
		return existing
	var box: Container
	if columns > 0:
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		box = grid
	else:
		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", 10)
		box = hrow
	box.name = name_hint
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
	_vtitle.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_vtitle.add_theme_font_size_override("font_size", 30)
	_vtitle.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_redline.color = GuStyle.REDLINE
	_sub_label.add_theme_font_size_override("font_size", 12)
	_sub_label.add_theme_color_override("font_color", GuStyle.SUBTITLE_TEXT)
	_note_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	MasterTheme.apply_button(_leave_button, "action")


## 休整屏舞台：以大厅屏为基准——纸面 + 网点背景（公共规范），竖排标题 + 红线 + 朱砂印章。
func _apply_stage_style() -> void:
	var paper := $RestPaper as ColorRect
	paper.color = GuStyle.PAPER_HALL
	GuStyle.apply_seal(_seal_panel, 3.0)



## 朱砂盖印动效：洗髓换骨等危险操作确认时触发，复用战斗屏SealOverlay逻辑。
func _play_seal_stamp() -> void:
	var seal: ColorRect = _rest_stage.get_node_or_null("SealOverlay")
	if seal == null:
		return
	seal.visible = true
	seal.modulate = Color(1, 1, 1, 0)
	seal.scale = Vector2(1.3, 1.3)
	seal.rotation = deg_to_rad(-8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(seal, "modulate:a", 0.18, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "scale", Vector2(1, 1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.25)
	tween.tween_property(seal, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): seal.visible = false)
