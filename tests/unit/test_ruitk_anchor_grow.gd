extends GutTest

# 守卫测试：RUITK style.gd 应用锚点预设时必须补设生长方向。
# set_anchors_and_offsets_preset 按"调用时刻"的最小尺寸计算偏移；RUITK 在节点刚创建
# （最小尺寸为零）时应用 style，内容到达后控件沿默认方向（右下）生长，角预设会被
# 顶出视口外——debug_panel 把手条整体不可见的根因（PRESET_BOTTOM_RIGHT gp=(1920,1080)）。

const StyleScript = preload("res://addons/reactive_ui_toolkit/core/style.gd")


func _panel_with_anchor(anchor_value: String) -> Control:
	# 顺序对齐真实 reconcile：style 在节点创建（最小尺寸为零）时应用，内容后到。
	var parent := Control.new()
	parent.size = Vector2(1920, 1080)
	add_child_autofree(parent)
	var panel := PanelContainer.new()
	parent.add_child(panel)
	StyleScript.apply(panel, {}, {"anchors_preset": anchor_value})
	var label := Label.new()
	label.text = "probe"
	panel.add_child(label)
	return panel


func test_bottom_right_anchor_grows_inward() -> void:
	var panel := _panel_with_anchor("PRESET_BOTTOM_RIGHT")
	assert_eq(panel.grow_horizontal, Control.GROW_DIRECTION_BEGIN, "h grow inward")
	assert_eq(panel.grow_vertical, Control.GROW_DIRECTION_BEGIN, "v grow inward")


func test_bottom_right_anchor_stays_inside_parent() -> void:
	var panel := _panel_with_anchor("PRESET_BOTTOM_RIGHT")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(panel.position.x >= 0.0 and panel.position.y >= 0.0, "top-left inside parent")
	assert_true(panel.position.x + panel.size.x <= 1921.0, "right edge inside parent")
	assert_true(panel.position.y + panel.size.y <= 1081.0, "bottom edge inside parent")


func test_full_rect_anchor_still_fills_parent() -> void:
	var panel := _panel_with_anchor("PRESET_FULL_RECT")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(panel.position, Vector2.ZERO, "full rect at origin")
	assert_true(panel.size.x >= 1919.0 and panel.size.y >= 1079.0, "full rect fills parent")
