extends GutTest

# scenes/ui/hand_panel.tscn + scripts/ui/hand_panel.gd 守卫：BottomWide 宿主、
# 横向滚动、卡牌由脚本 spawn 进 %HandBox、MAX_HAND 10、card_played/card_inspected
# 聚合上报、refresh_affordable 不重建节点、换回合整表重建。

const HAND_PANEL := "res://scenes/ui/hand_panel.tscn"
const CARD_VIEW := "res://scenes/ui/card_view.tscn"
var CARD_THEME: Theme = load("res://gu_theme.tres")

var _panel: MarginContainer
var _emitted: Array = []


func before_each() -> void:
	var packed: PackedScene = load(HAND_PANEL)
	if packed == null:
		return
	_panel = packed.instantiate() as MarginContainer
	if _panel != null:
		add_child(_panel)
		await get_tree().process_frame
	_emitted = []


func after_each() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.free()
		_panel = null


func _box() -> HBoxContainer:
	return _panel.get_node("%HandBox") as HBoxContainer


func _card_data(id: String) -> Dictionary:
	return {"id": id, "name": "蛊" + id, "cost": 1, "rank_text": "一阶", "desc": "效果。"}


func test_theme_resource_has_card_view_items() -> void:
	assert_not_null(CARD_THEME, "res://gu_theme.tres must load as Theme")
	if CARD_THEME == null:
		return
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(CARD_THEME.has_stylebox(state, "CardView"), "CardView must define %s stylebox" % state)
	assert_true(CARD_THEME.has_font_size("font_size", "TitleLabel"), "TitleLabel font_size must exist")
	assert_true(CARD_THEME.has_color("font_color", "CostLabel"), "CostLabel font_color must exist")
	assert_true(CARD_THEME.has_color("font_color", "TypeLabel"), "TypeLabel font_color must exist")
	assert_true(CARD_THEME.has_color("font_color", "DescLabel"), "DescLabel font_color must exist")
	assert_true(CARD_THEME.has_constant("separation", "HandBox"), "HandBox separation must exist")
	assert_true(CARD_THEME.has_constant("margin_left", "Content"), "Content margin_left must exist")
	assert_not_null(CARD_THEME.default_font, "T1: theme must bind the WenZhen body font (engine default is sans, breaks 宣纸/宋体 rule)")
	if CARD_THEME.default_font == null:
		return
	assert_true(
		CARD_THEME.default_font.resource_path.contains("LXGWZhiSongCL"),
		"T1: default_font must be the same LXGW WenZhen face as GuStyle.TITLE_FONT"
	)
	for dim in ["TitleLabelDim", "CostLabelDim", "TypeLabelDim", "DescLabelDim"]:
		assert_true(CARD_THEME.has_color("font_color", dim), "T2: %s must dim card text when unaffordable" % dim)
		assert_true(CARD_THEME.has_font_size("font_size", dim), "T2: %s must keep its font size" % dim)


func test_panel_wires_theme_and_container_variations() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	assert_eq(_panel.theme, CARD_THEME, "T5: HandPanel must attach gu_theme.tres so HandBox/HandScroll entries are reachable")
	var scroll := _panel.get_node_or_null("HandScroll")
	assert_not_null(scroll, "HandScroll must exist")
	if scroll == null:
		return
	assert_eq(scroll.theme_type_variation, &"HandScroll", "T5: HandScroll must anchor its theme type")
	assert_eq(_box().theme_type_variation, &"HandBox", "T5: HandBox must anchor its theme type")


func test_panel_structure_bottom_wide_scroll() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	assert_eq(_panel.anchor_left, 0.0, "BottomWide anchor_left 0")
	assert_eq(_panel.anchor_top, 1.0, "BottomWide anchor_top 1")
	assert_eq(_panel.anchor_right, 1.0, "BottomWide anchor_right 1")
	assert_eq(_panel.anchor_bottom, 1.0, "BottomWide anchor_bottom 1")
	assert_eq(_panel.grow_vertical, Control.GROW_DIRECTION_BEGIN, "BottomWide must grow upward")
	assert_eq(_panel.get_theme_constant("margin_bottom"), 24, "bottom margin 24")
	var scroll := _panel.get_node_or_null("HandScroll")
	assert_true(scroll is ScrollContainer, "HandScroll must be ScrollContainer")
	if not scroll is ScrollContainer:
		return
	assert_eq((scroll as ScrollContainer).custom_minimum_size, Vector2(0, 256), "★ scroll area must set explicit height, not content-driven")
	assert_eq((scroll as ScrollContainer).horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "horizontal always scrollable")
	assert_eq((scroll as ScrollContainer).vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "vertical scrolling disabled")
	assert_true(_panel.get_node("%HandBox") is HBoxContainer, "%HandBox must be HBoxContainer")
	assert_eq((_box() as HBoxContainer).get_theme_constant("separation"), 12, "HandBox separation 12")
	assert_eq(_panel.theme, CARD_THEME, "HandPanel must carry gu_theme.tres")
	assert_eq((scroll as ScrollContainer).theme_type_variation, &"HandScroll", "HandScroll variation anchored")


func test_show_hand_spawns_at_most_max_hand() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	var cards: Array = []
	for i in range(12):
		cards.append(_card_data("gu_%02d" % i))
	_panel.show_hand(cards)
	await get_tree().process_frame
	assert_eq(_box().get_child_count(), 10, "show_hand must cap at MAX_HAND=10")
	var first := _box().get_child(0)
	assert_eq(first.get_script().get_global_name(), "GuCardView", "spawned children must be GuCardView")
	assert_eq(first.call("card_id"), &"gu_00", "children bound with card id")
	assert_eq(first.theme, CARD_THEME, "spawned cards must carry gu_theme.tres")


func test_card_played_aggregates_pressed() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	_panel.card_played.connect(func(id: StringName) -> void: _emitted.append(id))
	_panel.show_hand([_card_data("a"), _card_data("b"), _card_data("c")])
	await get_tree().process_frame
	(_box().get_child(1)).emit_signal("pressed")
	assert_eq(_emitted, [&"b"], "card_played must forward the pressed card id")


func test_card_inspected_aggregates_hover() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	_panel.card_inspected.connect(func(id: StringName, hovered: bool) -> void: _emitted.append([id, hovered]))
	_panel.show_hand([_card_data("a")])
	await get_tree().process_frame
	(_box().get_child(0)).emit_signal("mouse_entered")
	(_box().get_child(0)).emit_signal("mouse_exited")
	assert_eq(_emitted, [[&"a", true], [&"a", false]], "card_inspected must forward hover enter/exit")


func test_refresh_affordable_updates_without_rebuild() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	_panel.show_hand([_card_data("a"), _card_data("b"), _card_data("c")])
	await get_tree().process_frame
	var box := _box()
	var before := box.get_child_count()
	_panel.refresh_affordable([&"a", &"c"])
	assert_eq(box.get_child_count(), before, "refresh_affordable must not rebuild cards")
	assert_false(box.get_child(0).disabled, "a affordable")
	assert_true(box.get_child(1).disabled, "b unaffordable")
	assert_false(box.get_child(2).disabled, "c affordable")


func test_show_hand_replaces_previous_views() -> void:
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	_panel.show_hand([_card_data("a"), _card_data("b")])
	await get_tree().process_frame
	assert_eq(_box().get_child_count(), 2, "first batch spawned")
	_panel.show_hand([_card_data("x"), _card_data("y"), _card_data("z")])
	await get_tree().process_frame
	assert_eq(_box().get_child_count(), 3, "second batch must replace the first (old views freed)")