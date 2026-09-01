extends GutTest

# scenes/ui/card_view.tscn 结构守卫：按已批准节点树逐项断言。
# 锁定：根 Button（TopLeft + 168x232 + 非 toggle）、Content 全矩形边距并将鼠标
# 事件让给 Button、Body 纵向容器、Header 标题/费用同行、ArtRect 图不反推尺寸、
# TypeLabel/DescLabel 占位与换行行为、全部 %unique_name 可解析；样式一律走
# gu_theme.tres（theme_type_variation 锚点）。
# 本测试不加入场景树，纯结构断言。

const CARD_VIEW := "res://scenes/ui/card_view.tscn"

var _root: Button


func before_each() -> void:
	var packed: PackedScene = load(CARD_VIEW)
	if packed == null:
		return
	_root = packed.instantiate() as Button
	if _root != null:
		# 场景与主题重复的 override 已删（margin/separation 由 theme variation 承载）。
		# 非树状态下子节点 theme_owner 不建立、根主题不参与解析（探针实证），
		# 故本测试显式挂主题并入树，让常量断言从主题解析（断言值不变）。
		_root.theme = load("res://gu_theme.tres")
		add_child(_root)
		await get_tree().process_frame


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.free()
		_root = null


func _names(container: Node) -> Array:
	var names: Array = []
	for child in container.get_children():
		names.append(String(child.name))
	return names


func test_scene_loads_and_root_is_topleft_button() -> void:
	var packed: PackedScene = load(CARD_VIEW)
	assert_not_null(packed, "%s must load as PackedScene" % CARD_VIEW)
	if packed == null:
		return
	var root := packed.instantiate()
	assert_true(root is Button, "card_view root must be a Button (native five-state + click/hover)")
	if not root is Button:
		root.free()
		return
	assert_eq(root.custom_minimum_size, Vector2(168, 232), "custom_minimum_size must be 168x232")
	assert_false(root.toggle_mode, "toggle_mode must stay false (plain click semantics)")
	assert_eq(root.anchor_left, 0.0, "root must be TopLeft (anchor_left 0)")
	assert_eq(root.anchor_top, 0.0, "root must be TopLeft (anchor_top 0)")
	assert_eq(root.anchor_right, 0.0, "root must be TopLeft (anchor_right 0)")
	assert_eq(root.anchor_bottom, 0.0, "root must be TopLeft (anchor_bottom 0)")
	root.free()


func test_theme_type_variations_anchor_theme_items() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	assert_eq(_root.theme_type_variation, &"CardView", "root must pick CardView theme type")
	assert_eq(_root.get_node("Content").theme_type_variation, &"Content", "Content must pick Content theme type")
	assert_eq(_root.get_node("Content/Body").theme_type_variation, &"Body", "Body must pick Body theme type")
	assert_eq(_root.get_node("%TitleLabel").theme_type_variation, &"TitleLabel", "TitleLabel must pick its theme type")
	assert_eq(_root.get_node("%CostLabel").theme_type_variation, &"CostLabel", "CostLabel must pick its theme type")
	assert_eq(_root.get_node("%TypeLabel").theme_type_variation, &"TypeLabel", "TypeLabel must pick its theme type")
	assert_eq(_root.get_node("%DescLabel").theme_type_variation, &"DescLabel", "DescLabel must pick its theme type")
	assert_eq(_root.get_node("%ArtRect").theme_type_variation, &"", "ArtRect must keep default theme type")


func test_content_fills_button_and_ignores_mouse() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var content := _root.get_node_or_null("Content")
	assert_true(content is MarginContainer, "Content must be MarginContainer")
	if not content is MarginContainer:
		return
	var margin := content as MarginContainer
	assert_eq(margin.mouse_filter, Control.MOUSE_FILTER_IGNORE, "★ Content must not intercept mouse, or Button loses hover/press")
	assert_eq(margin.anchor_right, 1.0, "Content must be FullRect (anchor_right 1)")
	assert_eq(margin.anchor_bottom, 1.0, "Content must be FullRect (anchor_bottom 1)")
	for side in ["left", "top", "right", "bottom"]:
		assert_eq(
			margin.get_theme_constant("margin_%s" % side), 10,
			"Content margin_%s must be 10" % side
		)


func test_body_vbox_separation_and_child_order() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var body := _root.get_node_or_null("Content/Body")
	assert_true(body is VBoxContainer, "Body must be VBoxContainer")
	if not body is VBoxContainer:
		return
	assert_eq((body as VBoxContainer).get_theme_constant("separation"), 6, "Body separation must be 6")
	assert_eq(
		_names(body), ["Header", "ArtRect", "TypeLabel", "DescLabel"],
		"Body child order must be Header/ArtRect/TypeLabel/DescLabel"
	)


func test_header_keeps_title_then_cost() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var header := _root.get_node_or_null("Content/Body/Header")
	assert_true(header is HBoxContainer, "Header must be HBoxContainer")
	if not header is HBoxContainer:
		return
	assert_eq(_names(header), ["TitleLabel", "CostLabel"], "Header must hold TitleLabel then CostLabel")


func test_unique_names_resolvable_from_owner() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	for unique_name in ["TitleLabel", "CostLabel", "ArtRect", "TypeLabel", "DescLabel"]:
		assert_not_null(_root.get_node_or_null("%" + unique_name), "%%%s must be unique_name_in_owner" % unique_name)


func test_title_label_expands_clips_and_ellipsizes() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var title := _root.get_node_or_null("%TitleLabel")
	assert_true(title is Label, "TitleLabel must be Label")
	if not title is Label:
		return
	assert_eq(title.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "TitleLabel must expand+fill horizontally")
	assert_true(title.clip_text, "TitleLabel must clip_text")
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "TitleLabel must trim with ellipsis")


func test_cost_label_is_plain_label() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var cost := _root.get_node_or_null("%CostLabel")
	assert_true(cost is Label, "CostLabel must be Label")


func test_art_rect_keeps_aspect_and_never_drives_card_size() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var art := _root.get_node_or_null("%ArtRect")
	assert_true(art is TextureRect, "ArtRect must be TextureRect")
	if not art is TextureRect:
		return
	assert_eq(art.size_flags_vertical, Control.SIZE_EXPAND_FILL, "ArtRect must expand+fill vertically")
	assert_eq(art.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "★ ArtRect must not push card size from texture")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "ArtRect must keep aspect centered")


func test_type_label_present_without_expand() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var type_label := _root.get_node_or_null("%TypeLabel")
	assert_true(type_label is Label, "TypeLabel must be Label")
	assert_eq(
		type_label.size_flags_vertical & Control.SIZE_EXPAND, 0,
		"TypeLabel must not expand (fixed small line)"
	)


func test_desc_label_expands_wraps_and_ellipsizes() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var desc := _root.get_node_or_null("%DescLabel")
	assert_true(desc is Label, "DescLabel must be Label")
	if not desc is Label:
		return
	assert_eq(desc.size_flags_vertical, Control.SIZE_EXPAND_FILL, "DescLabel must fill remaining height")
	assert_eq(desc.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "★ autowrap must pair with expand flag or text bursts the card")
	assert_eq(desc.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "DescLabel must trim with ellipsis")