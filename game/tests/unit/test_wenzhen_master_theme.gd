extends GutTest


const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
## 全部屏已迁 Godot 官方 .tscn（MASTER_SCENE_PATHS 即唯一路由表）；
## wenzhen_battle/map_master 与 ui/screens/{battle,map}_screen.guitkx 生成层
## 已于 2026-09-06 退役（ui_masters 收官），本文件只保留按钮三态契约。

var _rui_hosts: Array = []


func after_each() -> void:
	for host in _rui_hosts:
		if host != null and is_instance_valid(host):
			host.queue_free()
	_rui_hosts.clear()


func test_button_style_has_distinct_normal_hover_pressed_states() -> void:
	for role in ["primary", "action", "danger", "cancel", "archive", "target", "card", "node_reachable"]:
		var spec: Dictionary = MasterTheme.button_style(role)
		var normal: Dictionary = spec
		var hover: Dictionary = spec.get("hover", {})
		var pressed: Dictionary = spec.get("pressed", {})
		assert_ne(normal["bg_color"], hover["bg_color"], "%s must change background on hover" % role)
		assert_ne(hover.get("bg_color", hover.get("border_color")), pressed.get("bg_color", pressed.get("border_color")), "%s hover/pressed must differ visually" % role)
		assert_ne(normal["bg_color"], pressed["bg_color"], "%s must change background on press" % role)
		# shadcn 实心按钮以背景深浅表达按下态，press 时文字保持高对比白字不变
		# （fg 必变断言是旧线框按钮的实现细节）。仅当按下态未改背景时才要求
		# 文字色变化，保证任意实现下按下态都视觉可辨。
		if normal["bg_color"] == pressed["bg_color"]:
			assert_ne(spec["colors"]["font_color"], spec["colors"]["font_pressed_color"], "%s must change text color on press" % role)
		var primary_btn := Button.new()
		add_child(primary_btn)
		MasterTheme.apply_button(primary_btn, role)
		_rui_hosts.append(primary_btn)
		assert_not_null(primary_btn.get_theme_stylebox("normal"), "%s missing normal stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("hover"), "%s missing hover stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("pressed"), "%s missing pressed stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("disabled"), "%s missing disabled stylebox" % role)
		assert_not_null(primary_btn.get_theme_stylebox("focus"), "%s missing focus stylebox" % role)
		assert_eq(primary_btn.get_theme_color("font_color"), spec["colors"]["font_color"], "%s font_color mismatch" % role)
		assert_eq(primary_btn.get_theme_color("font_hover_color"), spec["colors"]["font_hover_color"], "%s font_hover_color mismatch" % role)
		assert_eq(primary_btn.get_theme_color("font_pressed_color"), spec["colors"]["font_pressed_color"], "%s font_pressed_color mismatch" % role)
