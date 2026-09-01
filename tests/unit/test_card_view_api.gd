extends GutTest

# scenes/ui/card_view.tscn 业务 API 守卫：根节点挂 GuCardView 脚本，提供
# bind_card（快照数据绑定）/ set_affordable（本地 disabled）/ card_pressed 与
# card_hovered 信号 / card_id() 取回器。键契约按计划：
# id/name/cost/rank_text/desc/texture/affordable；样式走 gu_theme.tres
# （根节点 _ready 自挂主题）。

const CARD_VIEW := "res://scenes/ui/card_view.tscn"
var CARD_THEME: Theme = load("res://gu_theme.tres")
var CARD_VIEW_SCRIPT: Script = load("res://scripts/ui/card_view.gd")

var _root: Button
var _emitted: Array = []


func before_each() -> void:
	var packed: PackedScene = load(CARD_VIEW)
	if packed == null:
		return
	_root = packed.instantiate() as Button
	if _root != null:
		add_child(_root)
		await get_tree().process_frame
	_emitted = []


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.free()
		_root = null


func test_root_carries_gu_card_view_script() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var script: Script = _root.get_script()
	assert_not_null(script, "root Button must carry the card_view script")
	if script == null:
		return
	assert_true(script is GDScript, "attached script must be GDScript")
	assert_eq(script.get_global_name(), "GuCardView", "script class_name must be GuCardView")
	assert_eq(script, CARD_VIEW_SCRIPT, "attached script must be res://scripts/ui/card_view.gd")


func test_bind_card_populates_labels_and_card_id() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.bind_card({
		"id": "moon_glow_gu",
		"name": "月芒蛊",
		"cost": 2,
		"rank_text": "炼道",
		"desc": "造成 3 点伤害。",
		"affordable": true,
	})
	assert_eq(_root.get_node("%TitleLabel").text, "月芒蛊", "TitleLabel must show card name")
	assert_eq(_root.get_node("%CostLabel").text, "2", "CostLabel must show cost")
	assert_eq(_root.get_node("%TypeLabel").text, "炼道", "TypeLabel must show rank_text")
	assert_eq(_root.get_node("%DescLabel").text, "造成 3 点伤害。", "DescLabel must show desc")
	assert_eq(_root.tooltip_text, "造成 3 点伤害。", "tooltip_text must mirror desc")
	assert_eq(_root.call("card_id"), &"moon_glow_gu", "card_id() must return bound StringName id")


func test_bind_card_missing_fields_are_defaulted() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.bind_card({"id": "stone_shell_gu", "name": "石甲蛊"})
	assert_eq(_root.get_node("%CostLabel").text, "0", "missing cost must default to 0")
	assert_eq(_root.get_node("%TypeLabel").text, "", "missing rank_text must default to empty")
	assert_eq(_root.get_node("%DescLabel").text, "", "missing desc must default to empty")
	assert_eq(_root.tooltip_text, "", "missing desc must default empty tooltip")
	assert_false(_root.disabled, "missing affordable must default to enabled")


func test_affordable_toggles_disabled() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.bind_card({"id": "gu_1", "name": "蛊甲", "affordable": false})
	assert_true(_root.disabled, "bind affordable=false must disable the button")
	_root.bind_card({"id": "gu_2", "name": "蛊乙", "affordable": true})
	assert_false(_root.disabled, "bind affordable=true must enable the button")
	_root.set_affordable(false)
	assert_true(_root.disabled, "set_affordable(false) must disable")
	_root.set_affordable(true)
	assert_false(_root.disabled, "set_affordable(true) must re-enable")


func test_card_pressed_forwards_bound_id() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.card_pressed.connect(func(id: StringName) -> void: _emitted.append(id))
	_root.bind_card({"id": "light_probe", "name": "小光蛊"})
	_root.emit_signal("pressed")
	assert_eq(_emitted, [&"light_probe"], "pressed must forward bound card_id via card_pressed")


func test_card_hovered_reports_enter_and_exit() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.card_hovered.connect(func(id: StringName, hovered: bool) -> void: _emitted.append([id, hovered]))
	_root.bind_card({"id": "gu_h", "name": "悬停蛊"})
	_root.emit_signal("mouse_entered")
	_root.emit_signal("mouse_exited")
	assert_eq(_emitted, [[&"gu_h", true], [&"gu_h", false]], "hover must report enter and exit with bound id")


func test_bind_card_without_texture_keeps_art_empty() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	var art := _root.get_node("%ArtRect") as TextureRect
	_root.bind_card({"id": "gu_x", "name": "无图蛊"})
	assert_eq(art.texture, null, "bind_card without texture must leave ArtRect empty")


func test_root_self_attaches_gu_theme() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	assert_eq(_root.theme, CARD_THEME, "root must self-attach res://gu_theme.tres so instances share one style source")


func test_card_text_uses_wenzhen_default_font() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	assert_not_null(CARD_THEME.default_font, "T1: gu_theme.tres must bind the WenZhen body font")
	if CARD_THEME.default_font == null:
		return
	var title := _root.get_node("%TitleLabel") as Label
	assert_eq(title.get_theme_font("font"), CARD_THEME.default_font, "T1: card labels must resolve to the theme default (LXGW 宋体), not engine sans")


func test_unaffordable_dims_labels_and_restores() -> void:
	assert_not_null(_root, "scene must instantiate")
	if _root == null:
		return
	_root.bind_card({"id": "gu_dim", "name": "蛊", "affordable": false})
	var title := _root.get_node("%TitleLabel") as Label
	assert_eq(title.theme_type_variation, &"TitleLabelDim", "T2: unaffordable must switch title to dim theme variation")
	assert_true(title.get_theme_color("font_color").is_equal_approx(GuStyle.INK_MUTED), "T2: unaffordable title text must dim to muted ink")
	_root.set_affordable(true)
	assert_eq(title.theme_type_variation, &"TitleLabel", "T2: affordable must restore the base theme variation")
	assert_true(title.get_theme_color("font_color").is_equal_approx(GuStyle.INK_PRIMARY), "T2: affordable title text must restore full ink")


func test_cost_label_blue_is_documented_decision() -> void:
	# T3 语义裁定：费用=真元催动。token 体系无“费用/真元”专用色，GuStyle.resource_color
	# 的 essence 归 ANOMALY_YELLOW（已被 DDA/异变占用），两处权威层均无费用色；
	# 故就近采用 CONTRACT_BLUE（唯一低饱和蓝）。引入真元专用 token 时应同步迁此断言。
	assert_not_null(CARD_THEME, "gu_theme.tres must load")
	if CARD_THEME == null:
		return
	assert_true(
		CARD_THEME.get_color("font_color", "CostLabel").is_equal_approx(GuStyle.CONTRACT_BLUE),
		"CostLabel color is the recorded CONTRACT_BLUE decision"
	)