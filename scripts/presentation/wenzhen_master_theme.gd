class_name WenzhenMasterTheme
extends RefCounted


static func button_style(role: String = "action", size: String = "normal") -> Dictionary:
	var spec := _spec(role, size)
	return {
		"custom_minimum_size": spec["min_size"],
		"font_size": spec["font_size"],
		"colors": {
			"font_color": spec["font_normal"],
			"font_hover_color": spec["font_hover"],
			"font_pressed_color": spec["font_pressed"],
			"font_focus_color": spec["font_normal"],
			"font_disabled_color": GuStyle.INK_MUTED,
		},
		"bg_color": spec["normal_bg"],
		"border_color": spec["normal_border"],
		"border_width_all": spec["normal_width"],
		"border_width_left": spec["normal_left"],
		"corner_radius_all": spec["radius"],
		"hover": {
			"bg_color": spec["hover_bg"],
			"border_color": spec["hover_border"],
			"border_width_all": spec["hover_width"],
			"corner_radius_all": spec["radius"],
		},
		"pressed": {
			"bg_color": spec["pressed_bg"],
			"border_color": GuStyle.CINNABAR if role != "primary" else GuStyle.HAIRLINE_COLOR,
			"border_width_all": spec["pressed_width"] + 1,
			"corner_radius_all": spec["radius"],
		},
		"focus": {
			"bg_color": spec["normal_bg"],
			"border_color": GuStyle.CINNABAR,
			"border_width_all": 2,
			"corner_radius_all": spec["radius"],
		},
		"disabled": {
			"bg_color": GuStyle.PAPER_DEEP,
			"border_color": GuStyle.HAIRLINE_COLOR,
			"border_width_all": 1,
			"corner_radius_all": spec["radius"],
		},
	}


static func apply_button(button: Button, role: String = "action", size: String = "normal") -> void:
	if button == null:
		return
	var spec := _spec(role, size)
	button.custom_minimum_size = spec["min_size"]
	button.add_theme_font_size_override("font_size", spec["font_size"])
	button.add_theme_color_override("font_color", spec["font_normal"])
	button.add_theme_color_override("font_hover_color", spec["font_hover"])
	button.add_theme_color_override("font_pressed_color", spec["font_pressed"])
	button.add_theme_color_override("font_focus_color", spec["font_normal"])
	button.add_theme_color_override("font_disabled_color", GuStyle.INK_MUTED)
	button.add_theme_stylebox_override("normal", _box(spec["normal_bg"], spec["normal_border"], spec["normal_width"], spec["normal_left"], spec["radius"], spec["content_margin"]))
	button.add_theme_stylebox_override("hover", _box(spec["hover_bg"], spec["hover_border"], spec["hover_width"], 0, spec["radius"], spec["content_margin"]))
	button.add_theme_stylebox_override("pressed", _box(spec["pressed_bg"], spec["pressed_border"], spec["pressed_width"], 0, spec["radius"], spec["content_margin"]))
	button.add_theme_stylebox_override("focus", _box(spec["normal_bg"], GuStyle.CINNABAR, 2, 0, spec["radius"], spec["content_margin"]))
	button.add_theme_stylebox_override("disabled", _box(GuStyle.PAPER_DEEP, GuStyle.HAIRLINE_COLOR, 1, 0, spec["radius"], spec["content_margin"]))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 第18批：按钮点击音效（用元数据标记避免重复连接）
	if not button.has_meta("sfx_connected"):
		button.set_meta("sfx_connected", true)
		button.pressed.connect(func(): AudioManager.play_sfx("ui_click"))
	# 第19批 V-F-04：hover 轻微放大 + 按下回弹（公共组件统一动效，meta 防重复连接）
	if not button.has_meta("scale_connected"):
		button.set_meta("scale_connected", true)
		button.pivot_offset = button.size * 0.5
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
		button.mouse_entered.connect(func(): _tween_scale(button, 1.03))
		button.mouse_exited.connect(func(): _tween_scale(button, 1.0))
		button.button_down.connect(func(): _tween_scale(button, 0.97))
		button.button_up.connect(func(): _tween_scale(button, 1.03 if button.is_hovered() else 1.0))


static func _box(bg: Color, border: Color, width: int, left: int, radius: int, content := Vector4i(-1, -1, -1, -1)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.border_width_left = left if left > 0 else width
	box.set_corner_radius_all(radius)
	if content.x >= 0:
		box.set_content_margin(SIDE_LEFT, content.x)
		box.set_content_margin(SIDE_TOP, content.y)
		box.set_content_margin(SIDE_RIGHT, content.z)
		box.set_content_margin(SIDE_BOTTOM, content.w)
	return box


## V-F-04：hover/按下缩放的统一 tween（绑定按钮生命周期，随节点释放自动清理）。
static func _tween_scale(button: Button, target: float) -> void:
	var tween: Tween = null
	if button.has_meta("scale_tween"):
		tween = button.get_meta("scale_tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	tween = button.create_tween()
	button.set_meta("scale_tween", tween)
	tween.tween_property(button, "scale", Vector2(target, target), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _spec(role: String, size: String) -> Dictionary:
	var primary := role == "primary"
	var danger := role == "danger"
	var cancel := role == "cancel"
	var archive := role == "archive"
	var node := role in ["node_current", "node_reachable", "node_future"]
	var target := role == "target"
	var card := role == "card"
	var large := size == "large" or danger
	var min_size := Vector2(120, 64 if primary else (44 if large else (32 if not node and not card else (126 if node else 96))))
	if node:
		min_size = Vector2(192, 126) if role != "node_future" else Vector2(168, 108)
	elif target:
		min_size = Vector2(0, 36)
	elif card:
		min_size = Vector2(120, 110)
	var normal_bg := GuStyle.PAPER_RAISED if role == "action" else GuStyle.PAPER_BG
	var normal_border := GuStyle.HAIRLINE_COLOR
	var normal_fg := GuStyle.INK_PRIMARY
	var hover_bg := GuStyle.PAPER_BG
	var hover_border := GuStyle.CINNABAR
	var pressed_bg := GuStyle.PAPER_DEEP
	var pressed_fg := GuStyle.CINNABAR
	var radius := 4
	var normal_width := 1
	var normal_left := 1
	var hover_width := 1
	var pressed_width := 1
	var content_margin := Vector4i(-1, -1, -1, -1)
	match role:
		"primary":
			# shadcn/ui default风格：品牌色背景 + 高对比度浅色文字
			normal_bg = GuStyle.BTN_PRIMARY_BG
			normal_border = GuStyle.BTN_PRIMARY_BG
			normal_fg = GuStyle.BTN_PRIMARY_FG
			hover_bg = GuStyle.BTN_PRIMARY_HOVER
			hover_border = GuStyle.BTN_PRIMARY_HOVER
			pressed_bg = GuStyle.BTN_PRIMARY_PRESSED
			pressed_fg = GuStyle.BTN_PRIMARY_FG
			normal_left = 0
			hover_width = 1
			pressed_width = 1
		"danger":
			# shadcn/ui destructive风格：危险色背景 + 高对比度浅色文字
			normal_bg = GuStyle.BTN_DANGER_BG
			normal_border = GuStyle.BTN_DANGER_BG
			normal_fg = GuStyle.BTN_DANGER_FG
			hover_bg = GuStyle.BTN_DANGER_HOVER
			hover_border = GuStyle.BTN_DANGER_HOVER
			pressed_bg = GuStyle.BTN_DANGER_PRESSED
			pressed_fg = GuStyle.BTN_DANGER_FG
			hover_width = 1
			pressed_width = 1
		"cancel":
			# shadcn/ui outline风格：透明背景 + 边框 + 深色文字
			normal_bg = Color(0, 0, 0, 0)
			normal_border = GuStyle.HAIRLINE_COLOR
			normal_fg = GuStyle.INK_SOFT
			hover_bg = GuStyle.PAPER_RAISED
			hover_border = GuStyle.INK_SOFT
		"archive":
			# shadcn/ui ghost风格：透明背景 + 软墨色文字
			normal_bg = Color(0, 0, 0, 0)
			normal_border = Color(0, 0, 0, 0)
			normal_fg = GuStyle.INK_SOFT
			hover_bg = GuStyle.PAPER_RAISED
			radius = 4
		"node_current":
			# v1 线框稿：透明底 + 墨框；朱砂左标线由屏层 ColorRect 叠加（StyleBoxFlat 无单边色）
			normal_bg = Color(0, 0, 0, 0)
			normal_border = GuStyle.NODE_CURRENT_BORDER
			normal_fg = GuStyle.INK_MAP
		"node_reachable":
			# v1 线框稿：浅纸底 + 清晰墨框
			normal_bg = GuStyle.NODE_REACH_BG
			normal_border = GuStyle.NODE_REACH_BORDER
			normal_fg = GuStyle.INK_MAP
			hover_bg = GuStyle.PAPER_BG
			pressed_bg = GuStyle.PAPER_RAISED
		"node_future":
			# v1 线框稿：透明底 + 淡墨边（Godot 无虚线，以淡实框近似虚线感）
			normal_bg = Color(0, 0, 0, 0)
			normal_border = GuStyle.NODE_FUTURE_BORDER
			normal_fg = GuStyle.NODE_FUTURE_INK
		"target":
			normal_bg = Color(0, 0, 0, 0)
			normal_fg = GuStyle.INK_PRIMARY
			hover_border = GuStyle.JADE
		"card":
			normal_bg = GuStyle.PAPER_BG
			normal_fg = GuStyle.INK_PRIMARY
			hover_bg = GuStyle.PAPER_RAISED
			pressed_bg = GuStyle.PAPER_DEEP
	if node:
		# 线框稿节点卡内边距：左 12 / 上 9 / 右 10 / 下 7
		content_margin = Vector4i(12, 9, 10, 7)
	if cancel:
		pressed_fg = GuStyle.CINNABAR
	return {
		"min_size": min_size,
		"font_size": 30 if primary else (16 if large else (18 if target else (16 if card else 14))),
		"font_normal": normal_fg,
		"font_hover": GuStyle.CINNABAR if archive or danger else normal_fg,
		"font_pressed": pressed_fg,
		"normal_bg": normal_bg,
		"normal_border": normal_border,
		"normal_width": normal_width,
		"normal_left": normal_left,
		"content_margin": content_margin,
		"hover_bg": hover_bg,
		"hover_border": hover_border,
		"hover_width": hover_width,
		"pressed_bg": pressed_bg,
		"pressed_border": GuStyle.CINNABAR,
		"pressed_width": pressed_width,
		"radius": radius,
	}


## 双色描边主按钮（基准图实测：黑字芯 + 蓝 #3880b8 描边 + 铁锈橙红 #803810 左投影；
## hover 文字转朱砂）——大厅「续入此世」/流派确认/结算「继续」共用。
static func apply_primary_outline(btn: Button, font_size: int = 22) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_font_override("font", GuStyle.TITLE_FONT)
	btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	btn.add_theme_color_override("font_hover_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_pressed_color", GuStyle.CINNABAR)
	btn.add_theme_color_override("font_focus_color", GuStyle.INK_PRIMARY)
	btn.add_theme_color_override("font_outline_color", GuStyle.BTN_OUTLINE_BLUE)
	btn.add_theme_constant_override("outline_size", 1)
	# 文字阴影已按 2026-09-11 用户裁定全量移除（高锐度文本样式收敛）。
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0)
	hover.border_color = GuStyle.CINNABAR
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	hover.content_margin_top = 5
	hover.content_margin_bottom = 5
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0, 0, 0, 0)
	pressed.border_color = GuStyle.CINNABAR
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(2)
	pressed.content_margin_left = 14
	pressed.content_margin_right = 14
	pressed.content_margin_top = 5
	pressed.content_margin_bottom = 5
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", pressed)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
