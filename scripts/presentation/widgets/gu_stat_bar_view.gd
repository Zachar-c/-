class_name GuStatBarView
extends VBoxContainer
## 状态条（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_stat_bar.guitkx）。
## 语义色由 color 驱动（生命 JADE / 真元 ANOMALY_YELLOW 等）；护盾独立分条。

@onready var _name_label: Label = $ValueRow/NameLabel
@onready var _value_label: Label = $ValueRow/ValueLabel
@onready var _shield_label: Label = $ValueRow/ShieldLabel
@onready var _inspect_button: Button = $ValueRow/InspectButton
@onready var _bar: ProgressBar = $Bar
@onready var _shield_bar: ProgressBar = $ShieldBar


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_name_label.custom_minimum_size = Vector2(56, 0)
	_value_label.add_theme_font_size_override("font_size", 14)
	_shield_label.add_theme_font_size_override("font_size", 14)
	_shield_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_inspect_button.add_theme_font_size_override("font_size", 14)
	_inspect_button.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_bar.custom_minimum_size = Vector2(0, 14)
	_shield_bar.custom_minimum_size = Vector2(0, 8)
	_shield_bar.modulate = GuStyle.INK_SOFT


## 写入状态条。护盾为 0 时隐藏护盾分条与文案。
func setup(label: String, value: int, max_value: int, color: Color,
		shield: int = 0, on_inspect: Callable = Callable(), danger: bool = false,
		danger_detail: String = "") -> void:
	_name_label.text = label
	_name_label.add_theme_color_override("font_color", GuStyle.CINNABAR if danger else GuStyle.INK_SOFT)
	_value_label.text = "%d / %d" % [value, max_value]
	var tone := GuStyle.CINNABAR if danger else color
	_value_label.add_theme_color_override("font_color", tone)
	_bar.max_value = maxi(1, max_value)
	_bar.value = value
	_bar.modulate = tone
	tooltip_text = danger_detail if danger else ""

	var has_shield: bool = shield > 0
	_shield_label.visible = has_shield
	_shield_label.text = "(盾 %d)" % shield if has_shield else ""
	_shield_bar.visible = has_shield
	if has_shield:
		_shield_bar.max_value = maxi(1, max_value)
		_shield_bar.value = shield

	_inspect_button.visible = on_inspect.is_valid()
	if on_inspect.is_valid():
		# 复用节点时先解绑，避免多次 setup 叠加回调。
		for conn in _inspect_button.pressed.get_connections():
			if conn.signal.get_name() == "pressed":
				_inspect_button.pressed.disconnect(conn.callable)
		_inspect_button.pressed.connect(on_inspect)
