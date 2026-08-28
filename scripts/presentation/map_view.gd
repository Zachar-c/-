class_name MapView
extends Control


const ROUTE_TREE_CANVAS := preload("res://scripts/presentation/route_tree_canvas.gd")

const TOOLTIP_SCENE := preload("res://scenes/ui/gu_tooltip.tscn")
const GuOrbScript := preload("res://scripts/presentation/gu_orb.gd")


signal node_selected(node_id: String)
signal action_submitted(command: Dictionary)


const TOAST_FADE_SECONDS := 1.6


var _toast: Label
var _tooltip: GuTooltip


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast = Label.new()
	_toast.name = "map_toast"
	_toast.visible = false
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color("e7c883"))
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 12.0
	add_child(_toast)
	# One shared tooltip host for the whole map view. It follows the mouse and
	# is protected from _clear so it survives re-renders (freed with the view).
	_tooltip = TOOLTIP_SCENE.instantiate()
	_tooltip.z_index = 100
	add_child(_tooltip)


func render(route: Array[Dictionary], state: RunState, catalog: Dictionary, meta: RefCounted = null, feedback: String = "") -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_append_header(column, state)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	_append_brand(column, state)
	_append_route(body, route, state)
	var panel := _append_panel(body, state, catalog, meta)
	_append_command_bar(column, panel, feedback)


func _append_header(column: VBoxContainer, _state: RunState) -> void:
	var title := Label.new()
	title.text = "南疆行程"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)


func _append_brand(_column: VBoxContainer, _state: RunState) -> void:
	return


func _append_route(parent: HBoxContainer, route: Array[Dictionary], state: RunState) -> HBoxContainer:
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	var tree: Control = ROUTE_TREE_CANVAS.new()
	scroll.add_child(tree)
	tree.tooltip = _tooltip
	tree.node_selected.connect(func(node_id: String): node_selected.emit(node_id))
	tree.configure(route, state, _empty_pool_ids(route, state))
	return center


func _empty_pool_ids(route: Array[Dictionary], state: RunState) -> Array[String]:
	var ids: Array[String] = []
	for node in route:
		var node_id := str(node["id"])
		var flag: Variant = state.node_flags.get(node_id, null)
		if flag is Dictionary and bool(flag.get("empty_pool", false)):
			ids.append(node_id)
	return ids


func _append_panel(parent: HBoxContainer, state: RunState, catalog: Dictionary, meta: RefCounted = null) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(288, 0)
	panel.add_theme_constant_override("separation", 8)
	parent.add_child(panel)
	_append_panel_title(panel, "蛊囊")
	var instances: Array[Dictionary] = state.refined_instances()
	if instances.is_empty():
		_append_line(panel, "空无一蛊。")
	for instance in instances:
		_append_gu_row(panel, state, catalog, instance)
	if not state.relic_ids.is_empty():
		_append_panel_title(panel, "遗物")
		for relic_id in state.relic_ids:
			_append_line(panel, DisplayText.gu(str(relic_id)))
	var meta_data: Dictionary = meta.to_save_data() if meta != null else {}
	var codex: Array = meta_data.get("gu_codex_ids", [])
	var knowledge: Dictionary = meta_data.get("unlocked_random_outcomes", {})
	_append_panel_title(panel, "图鉴")
	_append_line(panel, "已见蛊虫 %d 种" % codex.size())
	_append_line(panel, "跨局解锁 %d 种" % state.global_codex_ids.size())
	if not knowledge.is_empty():
		_append_line(panel, "乱炼见闻 %d 条" % knowledge.size())
	return panel


func _append_command_bar(column: VBoxContainer, panel: VBoxContainer, feedback: String) -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	column.add_child(bar)
	var codex_button := Button.new()
	codex_button.text = "图鉴"
	codex_button.custom_minimum_size = Vector2(88, 34)
	codex_button.tooltip_text = "展开或收起右侧蛊囊/图鉴面板。"
	codex_button.toggled.connect(func(toggled: bool): panel.visible = toggled)
	bar.add_child(codex_button)
	_append_command_button(bar, "存档", {"type": "save_run"})
	_append_command_button(bar, "读档", {"type": "load_run"})
	if not feedback.is_empty():
		var feedback_label := Label.new()
		feedback_label.text = feedback
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.add_theme_color_override("font_color", Color("b8d5cc"))
		bar.add_child(feedback_label)


func _append_panel_title(panel: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("e7c883"))
	panel.add_child(label)


func _append_line(panel: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)


func _append_gu_row(panel: VBoxContainer, state: RunState, _catalog: Dictionary, instance: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var orb := GuOrbScript.new()
	orb.gu_id = str(instance.get("definition_id", ""))
	orb.tooltip_text = DisplayText.gu(str(instance.get("definition_id", "")))
	row.add_child(orb)
	var name_label := Label.new()
	name_label.text = DisplayText.gu(str(instance.get("definition_id", "")))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var destroy := Button.new()
	destroy.text = "销毁"
	destroy.custom_minimum_size = Vector2(64, 30)
	destroy.disabled = state.gu_instances.size() <= 1
	destroy.tooltip_text = "封印销毁后不再占用养护，但该蛊的卡牌一并失去。"
	var instance_id := str(instance.get("instance_id", ""))
	destroy.pressed.connect(func(): _request_seal(instance_id))
	row.add_child(destroy)


func _request_seal(instance_id: String) -> void:
	show_toast("蛊已封印")
	action_submitted.emit({"type": "destroy_gu", "instance_id": instance_id})


func show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = true
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS)
	tween.tween_callback(func(): _toast.visible = false)


func _append_command_button(container: HBoxContainer, text: String, command: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 34)
	button.pressed.connect(func(): action_submitted.emit(command))
	container.add_child(button)


func _clear() -> void:
	for child in get_children():
		if child == _toast or child == _tooltip:
			continue
		child.queue_free()
