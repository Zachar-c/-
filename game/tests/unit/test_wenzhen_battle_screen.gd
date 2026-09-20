extends GutTest


const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const BATTLE_SCREEN_TSCN := "res://scenes/ui/screens/battle_screen.tscn"


var _roots: Array = []
var _hosts: Array = []
var _last_state: Dictionary = {}


func after_each() -> void:
	for root in _roots:
		if root != null and root.has_method("unmount"):
			root.unmount()
	_roots.clear()
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_hosts.clear()
	_last_state = {}


func test_battle_screen_has_fixed_hud_field_and_hand_regions() -> void:
	var host := _mount(_snapshot_with_enemies(3))
	assert_not_null(_named(host, "battle_hud"))
	assert_not_null(_named(host, "battle_field"))
	assert_not_null(_named(host, "battle_hand"))
	assert_not_null(_named(host, "player_actor"))
	assert_not_null(_named(host, "enemy_group"))


func test_three_enemies_keep_individual_intent_hp_shield_and_status() -> void:
	var host := _mount(_snapshot_with_enemies(3))
	for enemy_id in ["e0", "e1", "e2"]:
		assert_not_null(_named(host, "enemy_actor_" + enemy_id), "actor for %s" % enemy_id)
		assert_not_null(_named(host, "enemy_intent_" + enemy_id), "intent for %s" % enemy_id)
		assert_not_null(_named(host, "enemy_hp_" + enemy_id), "hp for %s" % enemy_id)
		assert_not_null(_named(host, "enemy_shield_" + enemy_id), "shield for %s" % enemy_id)
		assert_not_null(_named(host, "enemy_status_" + enemy_id), "status for %s" % enemy_id)


func test_dangerous_health_stays_on_existing_player_stat_bar() -> void:
	var state := _snapshot_with_enemies(1)
	state["death_lines"] = {
		"health": {"danger": true, "detail": "气血将竭"},
	}
	var host := _mount(state)
	var player_actor := _named(host, "player_actor")
	assert_not_null(player_actor)
	# The narrative-layer portrait was added as the actor's first child (A-1
	# landing, batch 8+); the danger detail lives on the explicitly named hp
	# stat bar, so reach it by name instead of assuming child index 0.
	var health_bar: Control = player_actor.get_node("hp")
	assert_not_null(health_bar)
	assert_eq(health_bar.tooltip_text, "气血将竭")
	assert_eq(health_bar.get_node("ValueRow/ValueLabel").get_theme_color("font_color"), GuStyle.CINNABAR)


func test_four_or_more_enemies_keep_first_three_and_expose_remainder() -> void:
	var host := _mount(_snapshot_with_enemies(4))
	assert_not_null(_named(host, "enemy_actor_e0"))
	assert_not_null(_named(host, "enemy_actor_e1"))
	assert_not_null(_named(host, "enemy_actor_e2"))
	assert_not_null(_named(host, "enemy_remainder"))
	assert_null(_named(host, "enemy_actor_e3"), "fourth enemy starts in the compact remainder view")


func _mount(state: Dictionary) -> Control:
	_last_state = state
	# 战斗屏已迁到 Godot 官方 .tscn（scenes/ui/screens/battle_screen.tscn）。
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	host.add_child(TscnMountHelper.instantiate(BATTLE_SCREEN_TSCN, state, {}))
	return host


## 右栏操作按钮的**可达性**回归（2026-09-10 真机反馈）。
##
## 症状：行动值耗尽后「结束回合 / 炼蛊 / 撤退」看着置灰、点了没反应。
## 根因不是 `disabled`——手牌区是**通栏透明面板**，而 Control 默认 `mouse_filter = STOP`，
## 它横向铺满、纵向覆盖到屏幕下沿，正好把右栏按钮带包在里面，于是吃掉按钮的 hover 与点击。
## 按钮自身 `disabled=false`、`modulate=1`、父链无压暗、无覆盖层——查状态一律正常，
## 只有"中心点上盖着谁"能看出问题，所以这条断言测的是**GUI 命中**而不是属性。
##
## 为什么值得专门钉一条：手牌区高度一变（本次竖长卡 132→206）就会改变覆盖范围，
## 而交互闭环审计只查"有没有接线"，查不出"够不够得着"。
func test_ops_buttons_accept_real_clicks_despite_transparent_hand_containers() -> void:
	# 必须带上真实战斗命令面：三个按钮都是按 `_commands.has(...)` 条件创建的，
	# 只给 {} 的话「炼蛊/撤退」根本不建，断言会退化成"没这个按钮"。
	var state := _snapshot_with_enemies(1)
	state["hand"] = []
	state["flee_available"] = true
	# 几何/点击断言必须在**有确定尺寸**的视口里做：挂到零尺寸的裸 Control 上时，
	# 容器会把子树排到屏幕外（实测 x 变成负值），一切命中都失真。
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var fired: Array = []
	var screen := TscnMountHelper.instantiate(BATTLE_SCREEN_TSCN, state, {
		"end_turn": func(): fired.append("end_turn"),
		"refine": func(_id = ""): fired.append("refine"),
		"flee": func(): fired.append("flee"),
	})
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# 逐按钮**真的按下去再松开**（走引擎 GUI 命中管线），断言命令真的被触发。
	# 只断言"没被别的控件盖住"不够：那只是代理指标，而且代理本身容易写错
	# （早先版本只查 STOP、又用先序近似，PASS 的 HandMargin 因此漏网两次）。
	for pair in [["结束回合", "end_turn"], ["炼蛊", "refine"], ["撤退", "flee"]]:
		var btn := _find_button_by_text(screen, pair[0])
		assert_not_null(btn, "右栏操作按钮「%s」必须存在" % pair[0])
		if btn == null:
			continue
		assert_false(btn.disabled, "「%s」不该被禁用（行动值为 0 也不该禁用）" % pair[0])
		fired.clear()
		var point: Vector2 = btn.get_global_rect().get_center()
		_viewport_mouse_motion(viewport, point)
		await get_tree().process_frame
		_viewport_mouse_button(viewport, point, true)
		_viewport_mouse_button(viewport, point, false)
		await get_tree().process_frame
		assert_eq(fired, [pair[1]],
				"「%s」中心点按下+松开必须触发 %s；实际触发=%s，该点命中者=%s"
				% [pair[0], pair[1], str(fired), _occluder_of(btn, screen)])


func _viewport_mouse_motion(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2.ZERO
	viewport.push_input(event)


func _viewport_mouse_button(viewport: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	viewport.push_input(event)


## 按钮中心点上的**实际命中者**（仅供失败时诊断）。
## 按引擎规则算：**子节点逆序**深度优先，先递归子树、再判自身；IGNORE 自身不作为命中。
## 命中者若既非按钮、也非其祖先，事件就到不了按钮 → 点了没反应。
func _occluder_of(button: Control, root: Node) -> String:
	if not button.is_visible_in_tree():
		return "（按钮不可见）"
	var hit := _find_control_at_pos(root, button.get_global_rect().get_center())
	if hit == null:
		return "（无控件命中）"
	var cursor: Node = hit
	while cursor != null:
		if cursor == button:
			return ""
		cursor = cursor.get_parent()
	var c := hit as Control
	return "%s(%s mf=%d rect=%s)" % [c.name, c.get_class(), c.mouse_filter,
			str(c.get_global_rect())]


func _find_control_at_pos(node: Node, point: Vector2) -> Node:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(i)
		if not (child is CanvasItem):
			continue
		if not (child as CanvasItem).is_visible_in_tree():
			continue
		var sub := _find_control_at_pos(child, point)
		if sub != null:
			return sub
		if child is Control:
			var c := child as Control
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and c.get_global_rect().has_point(point):
				return c
	return null


func _walk_nodes(node: Node) -> Array:
	var acc: Array = [node]
	for child in node.get_children():
		acc.append_array(_walk_nodes(child))
	return acc


func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_by_text(child, text)
		if found != null:
			return found
	return null


func _mount_with_hand(cards: Array) -> Control:
	var state := _snapshot_with_enemies(1)
	state["hand"] = cards
	return _mount(state)


func _host_state(_host: Node) -> Dictionary:
	return _last_state


func _snapshot_with_enemies(count: int) -> Dictionary:
	var enemies: Array = []
	for index in count:
		enemies.append({
			"id": "e%d" % index,
			"name": "敌人%d" % index,
			"hp": 12 + index,
			"max_hp": 20,
			"shield": 2,
			"statuses": [{"name": "流血", "stacks": 1}],
			"intent": {"type": "attack", "value": 6, "detail": "扑咬"},
			"alive": true,
		})
	return {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": enemies,
		"player": {"hp": 24, "max_hp": 30, "shield": 1, "primordial": 3, "soul": 4,
				"thoughts": 2, "used_this_turn": 0, "statuses": []},
		"actions": {"max": 2, "left": 2, "used": 0},
		"hand": [], "piles": {}, "default_target_id": "e0",
	}


func _named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _count_descendants_of_class(node: Node, class_filter: String) -> int:
	if node == null:
		return 0
	var count := 0
	if node.is_class(class_filter):
		count += 1
	for child in node.get_children():
		count += _count_descendants_of_class(child, class_filter)
	return count


func _count_labels_with_text(node: Node, text: String) -> int:
	if node == null:
		return 0
	var count := 0
	if node is Label and str(node.text) == text:
		count += 1
	for child in node.get_children():
		count += _count_labels_with_text(child, text)
	return count


func _count_buttons_with_text(node: Node, text: String) -> int:
	if node == null:
		return 0
	var count := 0
	# 2026-09-11 卡面层级重构：卡名从 Button.text 迁到 `card_name` meta，两处都匹配。
	if node is Button:
		var btn := node as Button
		if str(btn.text).contains(text) or str(btn.get_meta("card_name", "")).contains(text):
			count += 1
	for child in node.get_children():
		count += _count_buttons_with_text(child, text)
	return count


func _find_label_containing(node: Node, text: String) -> Label:
	if node == null:
		return null
	if node is Label and str(node.text).contains(text):
		return node
	for child in node.get_children():
		var found := _find_label_containing(child, text)
		if found != null:
			return found
	return null


func test_battle_hand_renders_no_permanent_tooltip_children() -> void:
	var cards: Array = [
		{"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害", "curse_warning": false, "executable": true, "block_reason": ""},
		{"id": "c1", "name": "闭息蛊", "quality": "稀有", "cost": "2", "effect": "本回合护盾 +6", "curse_warning": false, "executable": true, "block_reason": ""},
	]
	var host := _mount_with_hand(cards)
	var hand := _named(host, "battle_hand")
	assert_not_null(hand)
	# 2026-09-11 卡面层级重构（与横卡 gu_card 同步）：卡面常驻
	# 标题 / 费用徽章 / 品质标签 / 描述槽；详细段（联动/代价/不可用）仍归共享 tooltip。
	assert_eq(_count_labels_with_text(hand, "血牙蛊"), 1, "card title label exists exactly once")
	assert_not_null(_named(hand, "card_title_c0"), "title label node present")
	assert_not_null(_named(hand, "card_tag_c0"), "quality tag row present on face")
	assert_eq(_count_buttons_with_text(hand, "血牙蛊"), 1, "card body Button exists once (name via card_name meta)")
	assert_eq(_count_buttons_with_text(hand, "闭息蛊"), 1, "card body Button exists once (name via card_name meta)")
	assert_not_null(_named(hand, "card_desc_c0"), "desc slot present on face")
	var desc := _named(hand, "card_desc_c0") as RichTextLabel
	assert_not_null(desc, "effect renders in the RichTextLabel desc slot")
	if desc != null:
		assert_true(str(desc.text).contains("造成 4 点伤害"), "desc slot carries the effect summary")
	assert_not_null(_named(hand, "card_cost_c0"), "cost badge present on face")
	assert_null(_find_label_containing(hand, "造成 4 点伤害"),
			"effect lives in the desc RichTextLabel, not a plain Label")


func test_battle_hand_blocked_cards_remain_hoverable_and_carry_block_reason() -> void:
	var cards: Array = [
		{"id": "c0", "name": "月光蛊", "quality": "史诗", "cost": "3", "effect": "对单体造成 8 点伤害", "curse_warning": false, "executable": false, "block_reason": "真元不足：需要 3 点，当前仅有 1 点。"},
	]
	var host := _mount_with_hand(cards)
	var card_body := _named(host, "card_body_c0")
	assert_not_null(card_body, "disabled cards still render a hoverable card body so players see why")
	assert_null(_named(host, "card_press_c0"), "do not render a second disabled Button inside the card")
	var state := _host_state(host)
	assert_eq(str(state["hand"][0]["block_reason"]), "真元不足：需要 3 点，当前仅有 1 点。")


func test_battle_hand_hover_renders_shared_tooltip_host() -> void:
	var cards: Array = [
		{"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害", "curse_warning": false, "executable": true, "block_reason": ""},
	]
	var host := _mount_with_hand(cards)
	var body := _named(host, "card_body_c0")
	assert_not_null(body)
	# Drive the hover pipeline through the actual mouse_enter signal so the
	# RUI reconciler rerenders the screen with mode='hover' next frame.
	if body != null and body.has_signal("mouse_entered"):
		body.emit_signal("mouse_entered")
	# Pump frames until the screen rerenders the hand tooltip host.
	var overlay: Node = null
	for _i in range(4):
		await get_tree().process_frame
		overlay = _named(host, "battle_hand_tooltip_host")
		if overlay != null:
			break
	assert_not_null(overlay, "BattleScreen must own a shared tooltip host for the hand")
	assert_not_null(_named(overlay, "hand_tooltip_title"))


func test_battle_hand_tooltip_is_a_mouse_ignored_floating_overlay() -> void:
	var cards: Array = [
		{"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害", "curse_warning": false, "executable": true, "block_reason": ""},
	]
	var host := _mount_with_hand(cards)
	var body := _named(host, "card_body_c0")
	assert_not_null(body)
	if body != null and body.has_signal("mouse_entered"):
		body.emit_signal("mouse_entered")
	var overlay: Control = null
	for _i in range(4):
		await get_tree().process_frame
		overlay = _named(host, "battle_hand_tooltip_host") as Control
		if overlay != null:
			break
	assert_not_null(overlay)
	if overlay != null:
		assert_true(overlay.top_level, "Tooltip must not reserve vertical battle layout space")
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_battle_hand_tooltip_uses_fixed_segments_and_block_reason() -> void:
	var cards: Array = [
		{"id": "c0", "name": "月光蛊", "quality": "史诗", "cost": "3", "cost_ex": "真元 ×3", "effect": "对单体造成 8 点伤害", "synergy": "月华联动", "curse_warning": false, "executable": false, "block_reason": "真元不足。"},
	]
	var host := _mount_with_hand(cards)
	var body := _named(host, "card_body_c0")
	assert_not_null(body)
	if body != null and body.has_signal("mouse_entered"):
		body.emit_signal("mouse_entered")
	var tooltip: Node = null
	for _i in range(4):
		await get_tree().process_frame
		tooltip = _named(host, "battle_hand_tooltip_host")
		if tooltip != null:
			break
	assert_not_null(tooltip)
	assert_not_null(_find_label_containing(tooltip, "效果："))
	assert_not_null(_find_label_containing(tooltip, "联动："))
	assert_not_null(_find_label_containing(tooltip, "代价："))
	assert_not_null(_find_label_containing(tooltip, "不可用："))


func test_battle_hand_tooltip_exposes_known_risk_as_a_warning_segment() -> void:
	var cards: Array = [
		{"id": "c0", "name": "燃寿蛊", "quality": "稀有", "cost": "1", "effect": "造成 6 点伤害", "curse_warning": false, "executable": true, "known_risk": ["寿元 -1"], "block_reason": ""},
	]
	var host := _mount_with_hand(cards)
	var body := _named(host, "card_body_c0")
	assert_not_null(body)
	if body != null and body.has_signal("mouse_entered"):
		body.emit_signal("mouse_entered")
	var tooltip: Node = null
	for _i in range(4):
		await get_tree().process_frame
		tooltip = _named(host, "battle_hand_tooltip_host")
		if tooltip != null:
			break
	assert_not_null(tooltip)
	assert_not_null(_find_label_containing(tooltip, "风险：寿元 -1"))


func test_card_button_children_do_not_eat_mouse_clicks() -> void:
	var cards: Array = [
		{"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害",
				"curse_warning": false, "executable": true, "block_reason": ""},
	]
	var host := _mount_with_hand(cards)
	var btn := _named(host, "card_body_c0") as Button
	assert_not_null(btn)
	# Every descendant of the card Button must be MOUSE_FILTER_IGNORE so that
	# the Button itself is the deepest STOP control at the card center — real
	# mouse clicks must reach the Button's pressed signal.
	var blockers: Array = _stop_descendants(btn, btn)
	assert_eq(blockers.size(), 0, "card Button descendants must not be STOP: %s" % str(blockers))


func _stop_descendants(root: Control, button: Button) -> Array:
	var found: Array = []
	if root != button and root is Control:
		var c: Control = root
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			found.append(c.name)
	for child in root.get_children():
		if child is Control:
			found.append_array(_stop_descendants(child, button))
	return found
