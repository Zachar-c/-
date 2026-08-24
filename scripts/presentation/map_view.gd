class_name MapView
extends Control


const ROUTE_TREE_CANVAS := preload("res://scripts/presentation/route_tree_canvas.gd")
const THEME := preload("res://assets/theme/gu_theme.tres")


signal node_selected(node_id: String)
signal action_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME


func render(route: Array[Dictionary], state: RunState, catalog: Dictionary, meta: RefCounted = null, feedback: String = "") -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)
	var title := Label.new()
	title.text = "南疆行程"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)
	var resources := Label.new()
	resources.text = "一转 %d 阶  丙等资质  真元 %d/%d  元石 %d  伤势 %d  下次养护：预计 %d 元石" % [state.cultivation, state.essence, state.essence_capacity, state.stone, state.injury, state.estimate_feeding(ContentCatalog.load_all())]
	resources.add_theme_color_override("font_color", Color("b8d5cc"))
	left.add_child(resources)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var tree: Control = ROUTE_TREE_CANVAS.new()
	scroll.add_child(tree)
	tree.node_selected.connect(func(node_id: String): node_selected.emit(node_id))
	tree.configure(route, state)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_constant_override("separation", 8)
	hbox.add_child(panel)
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
	if not knowledge.is_empty():
		_append_line(panel, "乱炼见闻 %d 条" % knowledge.size())
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	panel.add_child(controls)
	_append_command_button(controls, "存档", {"type": "save_run"})
	_append_command_button(controls, "读档", {"type": "load_run"})
	if not feedback.is_empty():
		var feedback_label := Label.new()
		feedback_label.text = feedback
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.add_theme_color_override("font_color", Color("b8d5cc"))
		panel.add_child(feedback_label)


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


func _append_gu_row(panel: VBoxContainer, state: RunState, catalog: Dictionary, instance: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var name := Label.new()
	name.text = DisplayText.gu(str(instance.get("definition_id", "")))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var destroy := Button.new()
	destroy.text = "销毁"
	destroy.custom_minimum_size = Vector2(64, 30)
	destroy.disabled = state.gu_instances.size() <= 1
	destroy.tooltip_text = "销毁后不再占用养护，但该蛊的卡牌一并失去。"
	destroy.pressed.connect(func(): action_submitted.emit({"type": "destroy_gu", "instance_id": str(instance.get("instance_id", ""))}))
	row.add_child(destroy)


func _append_command_button(container: HBoxContainer, text: String, command: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 34)
	button.pressed.connect(func(): action_submitted.emit(command))
	container.add_child(button)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
