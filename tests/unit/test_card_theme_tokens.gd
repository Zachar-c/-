extends GutTest

# gu_theme.tres token 锚定测试：样式唯一真值 = GuStyle 浅色问眞 token。
# 主题每个色值必须逐项等于 GuStyle 常量（float32 精度：.tres 十进制小数与
# Color("hex") 解析存在 ~1e-6 差异，故用 is_equal_approx，不用 ==）。
# 同时锚定 T1 字体、T2 disabled 决策、T3 费用色决策、T5 查找链可达性。

const HAND_PANEL := "res://scenes/ui/hand_panel.tscn"
var CARD_THEME: Theme = load("res://gu_theme.tres")

var _panel: MarginContainer


func before_each() -> void:
	var packed: PackedScene = load(HAND_PANEL)
	if packed == null:
		return
	_panel = packed.instantiate() as MarginContainer
	if _panel != null:
		add_child(_panel)
		await get_tree().process_frame


func after_each() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.free()
		_panel = null


func _box() -> HBoxContainer:
	return _panel.get_node("%HandBox") as HBoxContainer


func _card_data(id: String) -> Dictionary:
	return {"id": id, "name": "蛊" + id, "cost": 1, "rank_text": "一阶", "desc": "效果。"}


func _color_ok(actual: Color, expected: Color, note: String) -> void:
	assert_true(actual.is_equal_approx(expected), "%s: got %s want %s" % [note, actual, expected])


func _card_sb(state: String) -> StyleBoxFlat:
	return CARD_THEME.get_stylebox(state, "CardView") as StyleBoxFlat


func test_card_button_five_states_use_wenzhen_tokens() -> void:
	assert_not_null(CARD_THEME, "gu_theme.tres must load")
	if CARD_THEME == null:
		return
	_color_ok(_card_sb("normal").bg_color, GuStyle.PAPER_BG, "normal bg")
	_color_ok(_card_sb("normal").border_color, GuStyle.HAIRLINE_COLOR, "normal border")
	_color_ok(_card_sb("hover").bg_color, GuStyle.PAPER_RAISED, "hover bg")
	_color_ok(_card_sb("hover").border_color, GuStyle.CINNABAR, "hover border")
	_color_ok(_card_sb("pressed").bg_color, GuStyle.PAPER_DEEP, "pressed bg")
	_color_ok(_card_sb("pressed").border_color, GuStyle.CINNABAR, "pressed border")
	_color_ok(_card_sb("disabled").bg_color, GuStyle.PAPER_DEEP, "disabled bg")
	_color_ok(_card_sb("disabled").border_color, GuStyle.HAIRLINE_COLOR, "disabled border")
	_color_ok(_card_sb("focus").bg_color, GuStyle.PAPER_BG, "focus bg")
	_color_ok(_card_sb("focus").border_color, GuStyle.CINNABAR, "focus border")


func test_label_colors_anchor_documented_decisions() -> void:
	assert_not_null(CARD_THEME, "gu_theme.tres must load")
	if CARD_THEME == null:
		return
	_color_ok(CARD_THEME.get_color("font_color", "TitleLabel"), GuStyle.INK_PRIMARY, "TitleLabel")
	_color_ok(CARD_THEME.get_color("font_color", "TypeLabel"), GuStyle.INK_MUTED, "TypeLabel")
	_color_ok(CARD_THEME.get_color("font_color", "DescLabel"), GuStyle.INK_SOFT, "DescLabel")
	# T3 既定决策：费用=真元催动，token 体系无专用色，ANOMALY_YELLOW 已被 DDA/异变
	# 占用，故就近采用 CONTRACT_BLUE（唯一低饱和蓝）；引入真元专用 token 时随迁。
	_color_ok(CARD_THEME.get_color("font_color", "CostLabel"), GuStyle.CONTRACT_BLUE, "CostLabel（T3 费用色裁定）")


func test_default_font_is_wenzhen_body_face() -> void:
	assert_not_null(CARD_THEME.default_font, "T1: default_font must be bound")
	if CARD_THEME.default_font == null:
		return
	assert_eq(CARD_THEME.default_font, GuStyle.TITLE_FONT, "default_font must be the same resource as GuStyle.TITLE_FONT")
	assert_eq(CARD_THEME.default_font_size, 13, "default_font_size must be 13")


func test_disabled_state_anchors_affordability() -> void:
	# T2 决策：禁用态底色与 master card 角色一致（PAPER_DEEP + 发丝线）；
	# 文字压暗走 XxxDim 变体（test_card_view_api 锁定），此处只锚底。
	assert_not_null(CARD_THEME, "gu_theme.tres must load")
	if CARD_THEME == null:
		return
	_color_ok(_card_sb("disabled").bg_color, GuStyle.PAPER_DEEP, "disabled bg")


func test_hand_panel_theme_lookup_chain_reachable() -> void:
	# T5：修复后 HandScroll/HandBox/ScrollBar 三条目真可达（不再死条目）。
	assert_not_null(_panel, "scene must instantiate")
	if _panel == null:
		return
	assert_eq(_panel.theme, CARD_THEME, "HandPanel must attach gu_theme.tres")
	var scroll := _panel.get_node_or_null("HandScroll") as ScrollContainer
	assert_not_null(scroll, "HandScroll must exist")
	if scroll == null:
		return
	assert_true(scroll.theme_type_variation == &"HandScroll", "HandScroll variation anchored")
	var panel_sb: StyleBox = scroll.get_theme_stylebox("panel")
	assert_not_null(panel_sb, "HandScroll/panel must resolve from theme (was unreachable before T5)")
	if panel_sb != null:
		assert_true(panel_sb is StyleBoxEmpty, "HandScroll panel must be the theme's transparent empty stylebox")
	assert_eq(_box().theme_type_variation, &"HandBox", "HandBox variation anchored")
	assert_eq(_box().get_theme_constant("separation"), 12, "HandBox separation must resolve 12 from theme variation")
	# 滚动条 grabber 命中 HAIRLINE（SHOW_ALWAYS 下滚动条必在）
	scroll.custom_minimum_size = Vector2(120, 256)
	_panel.show_hand([_card_data("a"), _card_data("b")])
	await get_tree().process_frame
	var hsb := scroll.get_h_scroll_bar()
	assert_not_null(hsb, "narrow area + 2 cards must expose HScrollBar")
	if hsb == null:
		return
	var grabber: StyleBox = hsb.get_theme_stylebox("grabber")
	assert_not_null(grabber, "HScrollBar grabber must resolve from theme")
	if grabber is StyleBoxFlat:
		_color_ok((grabber as StyleBoxFlat).bg_color, GuStyle.HAIRLINE_COLOR, "grabber")