class_name MapView
extends Control


signal node_selected(node_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render(route: Array[Dictionary], state: RunState) -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "南疆行程"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var resources := Label.new()
	resources.text = "元石 %d    真元 %d    伤势 %d    寿债 %d" % [state.stone, state.essence, state.injury, state.lifespan_debt]
	resources.add_theme_color_override("font_color", Color("b8d5cc"))
	column.add_child(resources)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var nodes := VBoxContainer.new()
	nodes.add_theme_constant_override("separation", 8)
	scroll.add_child(nodes)
	for index in route.size():
		var node: Dictionary = route[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "进入此处"
		if node["visible"]:
			button.text = "%02d  %s  [%s]" % [index + 1, _display_name(node["id"]), node["type"]]
			button.pressed.connect(func(): node_selected.emit(node["id"]))
		else:
			button.text = "%02d  未明地带" % [index + 1]
			button.disabled = true
		nodes.add_child(button)


func _display_name(node_id: String) -> String:
	return node_id.replace("_", " ")


func _clear() -> void:
	for child in get_children():
		child.queue_free()
