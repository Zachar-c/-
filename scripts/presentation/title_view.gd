class_name TitleView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")


signal start_requested
signal quit_requested
signal school_selected(school: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.7)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "蛊 路 求 生"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("e7c883"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "夜入密林，蛊路求生 · 南疆篇"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color("b8d5cc"))
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	column.add_child(spacer)

	var school_row := HBoxContainer.new()
	school_row.add_theme_constant_override("separation", 10)
	column.add_child(school_row)
	var school_hint := Label.new()
	school_hint.text = "流派"
	school_hint.add_theme_font_size_override("font_size", 18)
	school_hint.add_theme_color_override("font_color", Color("b8d5cc"))
	school_row.add_child(school_hint)
	for school in ["血道", "气道", "力道"]:
		var school_button := Button.new()
		school_button.text = school
		school_button.custom_minimum_size = Vector2(120, 40)
		school_button.tooltip_text = _school_hint(school)
		school_button.pressed.connect(func(choice: String = school): school_selected.emit(choice))
		school_row.add_child(school_button)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	column.add_child(menu)
	_append_menu_button(menu, "开始游戏", true)
	_append_menu_button(menu, "图鉴", false)
	_append_menu_button(menu, "统计内容", false)
	_append_menu_button(menu, "设定", false)
	_append_menu_button(menu, "退出", true)


func _school_hint(school: String) -> String:
	match school:
		"血道": return "低阶堆叠、气血博弈：量变替代质变，以血换爆发。"
		"气道": return "材料化用、工具爆发：耗材换效果，用完即毁。"
		"力道": return "低费高频、永久增强：肉身增益绑定角色，后期碾压。"
	return ""


func _append_menu_button(menu: VBoxContainer, text: String, enabled: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if text == "开始游戏":
		button.pressed.connect(func(): start_requested.emit())
	elif text == "退出":
		button.pressed.connect(func(): quit_requested.emit())
	else:
		button.disabled = true
		button.tooltip_text = "尚未开放：先完成南疆篇冒烟切片。"
	menu.add_child(button)
