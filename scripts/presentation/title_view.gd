class_name TitleView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")
const SaveRepositoryScript := preload("res://scripts/domain/save_repository.gd")


signal start_requested
signal quit_requested
signal school_selected(school: String)
signal continue_requested
signal codex_requested
signal settings_requested
signal contract_placeholder_requested


var _stub_panel: PanelContainer


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

	var title := UiTheme.label("蛊 路 求 生", 64, Color("e7c883"))
	column.add_child(title)
	var subtitle := UiTheme.label("夜入密林，蛊路求生 · 南疆篇", 24, Color("b8d5cc"))
	column.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	column.add_child(spacer)

	var school_row := HBoxContainer.new()
	school_row.add_theme_constant_override("separation", 10)
	column.add_child(school_row)
	var school_hint := UiTheme.label("流派", 18, Color("b8d5cc"))
	school_row.add_child(school_hint)
	for school in ["血道", "气道", "力道"]:
		var school_button := UiTheme.button(school, true)
		school_button.custom_minimum_size = Vector2(120, 40)
		school_button.tooltip_text = _school_hint(school)
		school_button.pressed.connect(func(choice: String = school): school_selected.emit(choice))
		school_row.add_child(school_button)

	var contract_button := UiTheme.button("契约（未启用）", true)
	contract_button.custom_minimum_size = Vector2(170, 36)
	contract_button.tooltip_text = "开局全局规则修改器：收益与对等代价成对，本局尚未接入。"
	contract_button.pressed.connect(func(): _toggle_stub("契约：本局 0 / 6 条（待接入）"))
	school_row.add_child(contract_button)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	column.add_child(menu)

	var has_save := FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH)
	_append_menu_button(menu, "继续上次冒险", has_save, "无进行中的冒险存档。")
	_append_menu_button(menu, "开始游戏", true, "")
	_append_menu_button(menu, "图鉴", true, "")
	_append_menu_button(menu, "设定", true, "")
	_append_menu_button(menu, "统计内容", false, "尚未开放：先完成南疆篇冒烟切片。")
	_append_menu_button(menu, "退出", true, "")


func _toggle_stub(text: String) -> void:
	contract_placeholder_requested.emit()
	if is_instance_valid(_stub_panel) and is_instance_valid(_stub_panel.get_parent()):
		_stub_panel.queue_free()
		_stub_panel = null
		return
	var panel := PanelContainer.new()
	panel.add_theme_constant_override("margin_left", 16)
	panel.add_theme_constant_override("margin_right", 16)
	panel.add_theme_constant_override("margin_top", 10)
	panel.add_theme_constant_override("margin_bottom", 10)
	var lbl := UiTheme.label(text, 16, Color("b8d5cc"))
	panel.add_child(lbl)
	panel.position = Vector2(150, 300)
	add_child(panel)
	_stub_panel = panel


func _school_hint(school: String) -> String:
	match school:
		"血道": return "低阶堆叠、气血博弈：量变替代质变，以血换爆发。"
		"气道": return "材料化用、工具爆发：耗材换效果，用完即毁。"
		"力道": return "低费高频、永久增强：肉身增益绑定角色，后期碾压。"
	return ""


func _append_menu_button(menu: VBoxContainer, text: String, enabled: bool, hint: String) -> void:
	var button := UiTheme.button(text, enabled)
	button.custom_minimum_size = Vector2(260, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	match text:
		"开始游戏":
			button.pressed.connect(func(): start_requested.emit())
		"退出":
			button.pressed.connect(func(): quit_requested.emit())
		"继续上次冒险":
			if not enabled:
				button.tooltip_text = hint
			button.pressed.connect(func(): continue_requested.emit())
		"图鉴":
			button.pressed.connect(func(): codex_requested.emit(); _toggle_stub("图鉴：建设中（遭遇即解锁，大厅只读）"))
		"设定":
			button.pressed.connect(func(): settings_requested.emit(); _toggle_stub("设定：建设中"))
		_:
			button.disabled = true
			button.tooltip_text = hint
	menu.add_child(button)
