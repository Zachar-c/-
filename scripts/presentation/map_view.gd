class_name MapView
extends Control


const ROUTE_TREE_CANVAS := preload("res://scripts/presentation/route_tree_canvas.gd")


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
	resources.text = "一转 %d 阶  丙等资质  真元 %d/%d  元石 %d  伤势 %d  下次养护：预计 %d 元石" % [state.cultivation, state.essence, state.essence_capacity, state.stone, state.injury, state.estimate_feeding(ContentCatalog.load_all())]
	resources.add_theme_color_override("font_color", Color("b8d5cc"))
	column.add_child(resources)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var tree: Control = ROUTE_TREE_CANVAS.new()
	scroll.add_child(tree)
	tree.node_selected.connect(func(node_id: String): node_selected.emit(node_id))
	tree.configure(route, state)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
