class_name GuDeathCauseOverlayView
extends PanelContainer
## 死因查看浮层（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_death_cause_overlay.guitkx）。
## 展示单条死线的 名称 / 当前值 / 上限 / 一句成因说明。
## 信息型浮层，**非确认语义**（不用 GuConfirmDialog）；关闭只改宿主本地状态，不动领域。

@onready var _title_label: Label = $OverlayMargin/OverlayBody/HeaderRow/TitleLabel
@onready var _close_button: Button = $OverlayMargin/OverlayBody/HeaderRow/CloseButton
@onready var _value_label: Label = $OverlayMargin/OverlayBody/ValueLabel
@onready var _detail_label: Label = $OverlayMargin/OverlayBody/DetailLabel


func _ready() -> void:
	_refresh_style()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value_label.add_theme_font_size_override("font_size", 15)
	_value_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_close_button.custom_minimum_size = Vector2(64, 30)


## 写入死线条目并绑定关闭回调。
func setup(line: Dictionary, on_close: Callable = Callable()) -> void:
	_title_label.text = "死因 · %s" % str(line.get("name", ""))
	_value_label.text = "当前值：%d / 上限：%d" % [
		int(line.get("current", 0)), int(line.get("max", 0))]
	_detail_label.text = "成因：%s" % str(line.get("detail", ""))
	if on_close.is_valid():
		_close_button.pressed.connect(on_close)


## 关闭浮层。
## 必须清空文本：浮层是预置在节点树里的常驻节点，只设 visible=false 会让
## 「成因：…」这类文本留在树中，被按文本查找的断言误判为仍然可见。
## 见 UI_RULES §5 空值不渲染。同时解绑回调，避免重复 setup 时堆积连接。
func close() -> void:
	visible = false
	_title_label.text = ""
	_value_label.text = ""
	_detail_label.text = ""
	for c in _close_button.pressed.get_connections():
		if c.signal.get_name() == "pressed":
			_close_button.pressed.disconnect(c.callable)


func _refresh_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = GuStyle.CINNABAR
	add_theme_stylebox_override("panel", box)
