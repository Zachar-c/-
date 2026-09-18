class_name GuInventoryView
extends PanelContainer

## 运行内行囊只展示快照投影；不持有 RunState，也不提交领域命令。

@onready var _materials: VBoxContainer = $Margin/Body/InventoryMaterials
@onready var _gu_instances: VBoxContainer = $Margin/Body/InventoryGuInstances
@onready var _loot: VBoxContainer = $Margin/Body/InventoryLoot
@onready var _intel: VBoxContainer = $Margin/Body/InventoryIntel
@onready var _empty_state: Label = $Margin/Body/EmptyState


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", box)


func setup(inventory: Dictionary) -> void:
	var materials: Array = inventory.get("materials", [])
	var gu_instances: Array = inventory.get("gu_instances", [])
	var loot: Array = inventory.get("loot", [])
	var intel: Array = inventory.get("intel", [])
	_empty_state.visible = materials.is_empty() and gu_instances.is_empty() and loot.is_empty() and intel.is_empty()
	_set_section(_materials, "材料", materials, func(item):
		return "%s ×%d" % [str(item.get("name", "材料")), int(item.get("quantity", 0))])
	_set_section(_gu_instances, "蛊虫", gu_instances, func(item):
		var rank := int(item.get("rank", 0))
		var rank_names := ["", "一", "二", "三", "四", "五"]
		var rank_text: String = rank_names[rank] + "转" if rank > 0 and rank < rank_names.size() else ("%d转" % rank if rank > 0 else "未定品")
		var quality := str(item.get("quality", ""))
		return "%s · %s%s" % [str(item.get("name", "蛊虫")), rank_text, " · " + quality if quality != "" else ""])
	_set_section(_loot, "收获", loot, func(item): return str(item.get("name", "收获")))
	_set_section(_intel, "已知情报", intel, func(item): return str(item.get("name", "情报")))


func _set_section(host: VBoxContainer, title: String, items: Array, formatter: Callable) -> void:
	for child in host.get_children():
		if child.name != "Title":
			child.queue_free()
	host.visible = not items.is_empty()
	if items.is_empty():
		return
	var heading := host.get_node_or_null("Title") as Label
	if heading != null:
		heading.text = title
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "· " + str(formatter.call(item_value))
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		host.add_child(label)
