class_name DebugPanelView
extends PanelContainer

## D5 开发者调试面板（§16.22 硬红线）。
##
## 仅开发构建由 RunController 门控挂载（Release 下零节点存在，本组件不会被创建）。
## 视觉与正式 UI 明显区分：纸底 90% + 朱砂描边 + 红字「调试」角标；折叠态只剩把手条。
##
## 只读情报来自快照 debug 段（保底计数 / 池排除列表 / 种子 / 事件数 / DDA 分位）；
## 写操作**全部经 commands 走控制器正式校验通道**，本组件不持任何领域状态。
##
## 接口是 set_props(props: Dictionary) 而非 mount_snapshot：
## 它不是路由屏，由 RunController 直接挂到可拖动宿主上。

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")

const KIND_ITEMS := ["yuanstone", "health", "lifespan", "soul", "essence"]
const KIND_LABELS := ["元石", "生命", "寿元", "魂魄", "真元"]

@onready var _title_label: Label = $Margin/Body/HeaderRow/TitleLabel
@onready var _sub_label: Label = $Margin/Body/HeaderRow/SubLabel
@onready var _toggle_button: Button = $Margin/Body/HeaderRow/ToggleButton
@onready var _body_host: VBoxContainer = $Margin/Body/BodyHost
@onready var _feedback_toast = $Margin/Body/FeedbackToast

var _props: Dictionary = {}
var _ready_done := false

# 拖拽：面板 STOP 消费自身矩形内的事件，子控件（展开按钮/输入框）各自消费。
# 标题带（顶部 HEADER_BAND 像素，标签为 IGNORE 事件直达面板）按住即可拖动，
# 移动的是宿主 Control，整个面板随之走。
const HEADER_BAND := 44.0

var _dragging := false
var _drag_offset := Vector2()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and event.position.y <= HEADER_BAND
		if _dragging:
			var host := get_parent() as Control
			if host != null:
				_drag_offset = get_global_mouse_position() - host.global_position
	elif event is InputEventMouseMotion and _dragging:
		var host := get_parent() as Control
		if host != null:
			host.global_position = get_global_mouse_position() - _drag_offset


func _ready() -> void:
	_ready_done = true
	# 「调试」角标必须红字（§16.22 与正式 UI 明显区分），DEV 标识灰字。
	_title_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_sub_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_apply_panel_style()
	_toggle_button.pressed.connect(func(): _fire0("toggle_open"))
	_refresh()


func set_props(props: Dictionary) -> void:
	_props = props
	if _ready_done:
		_refresh()


func _refresh() -> void:
	if not _ready_done:
		return
	var open_flag := bool(_props.get("open", false))
	_toggle_button.text = "收起 ▲" if open_flag else "展开 ▼"
	MasterTheme.apply_button(_toggle_button, "action")

	var feedback := str(_props.get("feedback", ""))
	_feedback_toast.visible = feedback != ""
	if feedback != "":
		_feedback_toast.setup(feedback, "warn")

	_clear(_body_host)
	if not open_flag:
		return

	_build_add_gu()
	_build_resource_set()
	_build_travel()
	_build_pool_info()
	var dump := Button.new()
	dump.text = "打印 RunData 快照"
	MasterTheme.apply_button(dump, "action")
	dump.pressed.connect(func(): _fire0("snapshot_dump"))
	_body_host.add_child(dump)


# ————————————————————————— 各功能段 —————————————————————————

func _build_add_gu() -> void:
	_body_host.add_child(_section("加蛊"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body_host.add_child(row)

	var input := LineEdit.new()
	input.text = str(_props.get("gu_input", ""))
	input.placeholder_text = "gu_id 例: small_light_gu"
	input.custom_minimum_size = Vector2(180, 0)
	input.text_changed.connect(func(v): _fire1("set_gu_input", v))
	row.add_child(input)
	row.add_child(_action_button("加蛊", func(): _fire0("add_gu")))


func _build_resource_set() -> void:
	_body_host.add_child(_section("资源设置"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body_host.add_child(row)

	var kind := OptionButton.new()
	for l in KIND_LABELS:
		kind.add_item(l)
	var kind_index := KIND_ITEMS.find(str(_props.get("res_kind", "yuanstone")))
	kind.select(0 if kind_index < 0 else kind_index)
	kind.item_selected.connect(func(idx): _fire1("set_res_kind", KIND_ITEMS[int(idx)]))
	row.add_child(kind)

	var value := LineEdit.new()
	value.text = str(_props.get("res_value", ""))
	value.placeholder_text = "整数"
	value.custom_minimum_size = Vector2(80, 0)
	value.text_changed.connect(func(v): _fire1("set_res_value", v))
	row.add_child(value)
	row.add_child(_action_button("应用", func(): _fire0("apply_resource")))


## 跳层：只列当前可见节点，防越层破坏地图不变量。
func _build_travel() -> void:
	_body_host.add_child(_section("跳层 · 仅可见节点"))
	var options: Array = _props.get("travel_options", [])
	if options.is_empty():
		_body_host.add_child(_note("（无可跳节点）"))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body_host.add_child(row)

	var selected_id := str(_props.get("travel_selected", ""))
	var opt := OptionButton.new()
	var selected_index := 0
	for i in options.size():
		var o: Dictionary = options[i]
		opt.add_item(str(o.get("label", str(o.get("id", "")))))
		if str(o.get("id", "")) == selected_id:
			selected_index = i
	opt.select(selected_index)
	opt.item_selected.connect(func(idx):
		_fire1("set_travel_node", str(options[int(idx)].get("id", ""))))
	row.add_child(opt)
	row.add_child(_action_button("跳", func(): _fire0("travel")))


## 池情报：只读，形状对齐 query_loot_state。
func _build_pool_info() -> void:
	_body_host.add_child(_section("池情报 · 只读"))
	var info: Dictionary = _props.get("info", {})
	var pity: Dictionary = info.get("pity", {})
	_body_host.add_child(_note("保底计数 · 蛊 %d / 材料 %d" % [
			int(pity.get("loot_pity", 0)), int(pity.get("material_pity", 0))]))
	_body_host.add_child(_note("合成连败 %d" % int(pity.get("synthesis_fail_streak", 0))))

	var excluded: Array = info.get("excluded", [])
	var excluded_text := "（无）"
	if not excluded.is_empty():
		var parts: Array = []
		for ex in excluded:
			parts.append(str(ex))
		excluded_text = ", ".join(parts)
	_body_host.add_child(_note("池排除列表：" + excluded_text))
	_body_host.add_child(_note("当前种子 %d · 事件数 %d" % [
			int(info.get("seed", 0)), int(info.get("event_count", 0))]))
	if str(info.get("dda_percentile", "")) != "":
		var dda := _note("DDA 分位：" + str(info.get("dda_percentile", "")))
		dda.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
		_body_host.add_child(dda)


# ————————————————————————— 小工具 —————————————————————————

func _fire0(key: String) -> void:
	var commands: Dictionary = _props.get("commands", {})
	if commands.has(key):
		commands[key].call()


func _fire1(key: String, arg) -> void:
	var commands: Dictionary = _props.get("commands", {})
	if commands.has(key):
		commands[key].call(arg)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	return l


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _action_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	MasterTheme.apply_button(b, "action")
	b.pressed.connect(on_press)
	return b


## 立即清空：BodyHost 里的按钮可能正在发射 pressed，所以不能在信号途中 free；
## 但这里只在 refresh 开头调用（不是信号回调内），且内容是自建节点，安全。
## 保守起见仍用队列释放。
func _clear(host: Node) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()


func _apply_panel_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GuStyle.PAPER_BG, 0.9)
	box.border_color = GuStyle.CINNABAR
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", box)
