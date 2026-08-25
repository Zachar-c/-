class_name StatBar
extends Control


# Labeled progress bar for 生命 / 护盾 / 真元 etc. Read-only: configure once and
# refresh with set_value. Always shows explicit "cur/max" text. The fill color is
# a per-instance variant so the same component can render health (red), shield
# (jade) or essence (gold) without separate scenes.


const THEME := preload("res://assets/theme/gu_theme.tres")
const UiThemeScript := preload("res://scripts/presentation/components/ui_theme.gd")


var _label: Label
var _value_label: Label
var _bar: ProgressBar
var _pending: Dictionary = {}


func _ready() -> void:
	theme = THEME
	var vbox := VBoxContainer.new()
	vbox.theme = THEME
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	var top := HBoxContainer.new()
	top.theme = THEME
	top.add_theme_constant_override("separation", 8)
	vbox.add_child(top)
	_label = Label.new()
	_label.theme = THEME
	top.add_child(_label)
	_value_label = Label.new()
	_value_label.theme = THEME
	top.add_child(_value_label)
	_bar = ProgressBar.new()
	_bar.theme = THEME
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(_bar)
	if not _pending.is_empty():
		configure(_pending["label"], _pending["current"], _pending["maximum"], _pending["color"])


func configure(label_text: String, current: int, maximum: int, color: Color) -> void:
	if _bar == null:
		_pending = {"label": label_text, "current": current, "maximum": maximum, "color": color}
		return
	_label.text = label_text
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", color)
	_bar.add_theme_stylebox_override("fill", _fill_style(color))
	_bar.add_theme_stylebox_override("background", _bg_style())
	set_value(current, maximum)


func set_value(current: int, maximum: int) -> void:
	if _bar == null:
		_pending["current"] = current
		_pending["maximum"] = maximum
		return
	var mx := maxi(1, maximum)
	_bar.max_value = mx
	_bar.value = clampi(current, 0, mx)
	_value_label.text = "%d/%d" % [current, maximum]
	_value_label.add_theme_font_size_override("font_size", 14)
	_value_label.add_theme_color_override("font_color", UiThemeScript.JADE)


static func _fill_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	return sb


static func _bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiThemeScript.BG_DEEP
	sb.set_corner_radius_all(3)
	return sb
