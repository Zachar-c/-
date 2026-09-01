class_name GuResourceChipView
extends PanelContainer
## 资源徽章（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_resource_chip.guitkx）。
## 运行时名称与别名统一走 ResourceVocabulary（经 GuStyle），不在此硬编码中文名。

@onready var _label: Label = $ChipMargin/ChipLabel

var _on_click: Callable = Callable()


func _ready() -> void:
	_refresh_style()
	_label.add_theme_font_size_override("font_size", 14)


## 写入资源种类与数值。meta 种类走纸底（与顶栏 chip 区分）。
func setup(kind: String, value: int, on_click: Callable = Callable()) -> void:
	var canonical := GuStyle.resource_normalize(kind)
	var name_text := "见闻" if kind == "meta" else GuStyle.resource_label(canonical)
	_label.text = "%s: %d%s" % [name_text, value, GuStyle.resource_suffix(canonical)]
	var color := GuStyle.PAPER_BG if kind == "meta" else GuStyle.resource_color(canonical)
	_label.add_theme_color_override("font_color", color)
	if on_click.is_valid():
		# 复用节点时先解绑，否则多次 setup 会叠加回调。
		for conn in gui_input.get_connections():
			gui_input.disconnect(conn.callable)
		_on_click = on_click
		gui_input.connect(func(_event): _on_click.call())
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.INK_PRIMARY
	box.border_color = GuStyle.PAPER_BG
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", box)
