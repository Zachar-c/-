class_name GuPanelView
extends PanelContainer
## 内容边界容器（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_panel.guitkx）。
## 只提供发丝线边界与留白：无阴影、无厚边框、不嵌套卡片。
## 外部内容一律加进 content_host。

@onready var _title_label: Label = $PanelMargin/PanelBody/TitleLabel
@onready var content_host: VBoxContainer = $PanelMargin/PanelBody/ContentHost


func _ready() -> void:
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_refresh_style()


## 一次性写入面板标题并刷新。title 为空时隐藏标题行。
func setup(title: String = "", expand_h: bool = false, expand_v: bool = false) -> void:
	_title_label.text = title
	_title_label.visible = title != ""
	if expand_h:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh_style()


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", box)
