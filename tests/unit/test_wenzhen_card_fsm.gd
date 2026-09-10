extends GutTest


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
# 显式 preload 而非依赖 class_name 全局注册：后者的注册有时序，
# 在 GUT 收集脚本阶段可能还没就绪，会让整个测试文件 Parse Error。
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

var _roots: Array = []
var _hosts: Array = []

## 无指向性卡（target_type == "none"）：拖拽走影卡 + 定距出牌手势。
const NON_TARGET_CARD := {"id": "c2", "name": "凝气蛊", "cost": 1,
		"effect": "强化自身", "executable": true, "target_type": "none"}


func after_each() -> void:
	for root in _roots:
		if root != null and root.has_method("unmount"):
			root.unmount()
	_roots.clear()
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_hosts.clear()


func test_single_target_card_waits_for_enemy_and_can_cancel() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	assert_true(_press(host, "月光蛊"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_target_select"))
	assert_true(played.is_empty(), "choosing a card cannot submit before a target exists")
	assert_true(_press(host, "取消目标"))
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_idle"))
	assert_true(played.is_empty(), "cancel must not submit a command")


func test_single_target_card_only_submits_after_valid_enemy_selection() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	assert_true(_press(host, "月光蛊"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_press(host, "敌人1"), "invalid target is not selectable")
	assert_true(_press(host, "敌人0"))
	await get_tree().process_frame
	assert_eq(played, [["c1", "e0"]])


func test_hover_keeps_card_button_instance_clickable() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	var before_hover := _button(host, "月光蛊")
	assert_not_null(before_hover)
	before_hover.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var after_hover := _button(host, "月光蛊")
	assert_same(after_hover, before_hover,
			"hover must only update the shared tooltip; rebuilding the Button drops real mouse clicks")
	after_hover.pressed.emit()
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_target_select"))
	assert_true(played.is_empty(), "single-target cards wait for an enemy after the click")


func test_left_mouse_input_after_hover_arms_single_target_card() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var position := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, position)
	_viewport_mouse_button(viewport, position, true)
	_viewport_mouse_button(viewport, position, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_target_select"),
			"a real left click on a hovered card must arm its target selection")
	assert_true(played.is_empty())


func test_drag_card_onto_enemy_submits_with_that_target() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	# 先点击武装（敌方名称按钮只在 target_select 态存在），记录敌方矩形。
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var click_at := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, click_at)
	_viewport_mouse_button(viewport, click_at, true)
	_viewport_mouse_button(viewport, click_at, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemy_button := _button(host, "敌人0")
	assert_not_null(enemy_button)
	var to := enemy_button.get_global_rect().get_center()
	# 再做拖拽手势：按住卡牌拖到敌方卡上抬起 → 直接按该目标出牌。
	var drag_button := _button(host, "月光蛊")
	assert_not_null(drag_button)
	var from := drag_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, to)
	_viewport_mouse_button(viewport, to, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(played, [["c1", "e0"]], "drag release over an enemy must play the card on it")


func test_drag_release_off_enemies_does_not_submit() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	var to := from + Vector2(0, -60)
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, to)
	_viewport_mouse_button(viewport, to, false)
	await get_tree().process_frame
	await get_tree().process_frame
	# 抬起未命中敌方卡：不得误出牌（失败拖拽 = 无操作，可改用点击武装）。
	assert_true(played.is_empty(), "drag release off enemies must not submit")


# 用例 1：无指向卡位移超阈值出影卡；拖出不足 DRAG_CAST_DISTANCE_PX 松手
# → 回弹销毁、不出牌。
func test_drag_proxy_spawns_after_threshold_and_rebounds_off_enemies() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	# 超阈值（6px）出影卡
	_viewport_mouse_motion(viewport, from + Vector2(30, 0))  # < 64px 出牌距离
	await get_tree().process_frame
	assert_not_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"drag proxy must spawn once motion exceeds threshold")
	_viewport_mouse_button(viewport, from + Vector2(30, 0), false)
	assert_true(played.is_empty(), "release below cast distance must not submit")
	# 回弹后销毁（回弹 0.22s）
	await get_tree().create_timer(0.4).timeout
	assert_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"drag proxy must be freed after rebound")


# 用例 2：无指向卡拖出固定距离松手即出牌（空目标提交）。
func test_nontarget_card_drag_beyond_cast_distance_releases_to_play() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(140, 0))  # > 64px
	_viewport_mouse_button(viewport, from + Vector2(140, 0), false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(played, [["c2", ""]], "release beyond cast distance must play the card")


# 用例 3：指向卡按住拖动 → 瞄准线出现且无影卡；未命中敌人松手 → 取消、不出牌。
func test_target_card_aim_line_spawns_and_cancels_off_enemies() -> void:
	var played: Array = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(80, -60))
	await get_tree().process_frame
	assert_not_null(_find_viewport_child(viewport, "battle_aim_line"),
			"targeted card must spawn aim line, not a drag proxy")
	assert_null(_find_viewport_child(viewport, "battle_drag_proxy"),
			"targeted card must not spawn a drag proxy")
	_viewport_mouse_button(viewport, from + Vector2(80, -60), false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(played.is_empty(), "aim release off enemies must not submit")
	# 收线是**平滑消失**（0.18s 淡出后再释放），所以要等淡出跑完再断言节点已回收。
	await _wait_tween()
	assert_null(_find_viewport_child(viewport, "battle_aim_line"),
			"aim line must be removed after release")


## 按名前缀找覆盖层：**递归**扫视口子树——瞄准线现在挂在屏内的 AimLayer(CanvasLayer)
## 下，只扫视口直接子节点会找不到（2026-09-10 改版过）。
func _find_viewport_child(viewport: SubViewport, name_prefix: String) -> Node:
	for child in viewport.get_children():
		var found := _find_by_prefix(child, name_prefix)
		if found != null:
			return found
	return null


func _find_by_prefix(node: Node, name_prefix: String) -> Node:
	if str(node.name).begins_with(name_prefix):
		return node
	for child in node.get_children():
		var found := _find_by_prefix(child, name_prefix)
		if found != null:
			return found
	return null


# 用例 4：影卡不透明且按比例重建放大（不再是半透明原尺寸的"鬼影"）。
func test_drag_proxy_is_opaque_and_larger_than_source_card() -> void:
	var played: Array = []
	var viewport := _new_viewport()
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(30, 0))
	await get_tree().process_frame
	var proxy := _find_viewport_child(viewport, "battle_drag_proxy") as Control
	assert_not_null(proxy, "drag proxy must spawn once motion exceeds threshold")
	if proxy == null:
		return
	assert_eq(proxy.modulate.a, 1.0, "drag proxy must be opaque: the card left the hand, it is not a ghost")
	# 与源卡尺寸比较而不是写死 168：卡形会随美术方向调整（168×74 → 110×154 已发生过一次），
	# 写死数字会让这条断言在换卡形时变成噪音。
	var source_card := _named(host, "card_box_c2") as Control
	assert_not_null(source_card)
	if source_card != null:
		assert_gt(proxy.custom_minimum_size.x, source_card.custom_minimum_size.x,
				"drag proxy must be rebuilt larger than the source card")
		assert_gt(proxy.custom_minimum_size.y, source_card.custom_minimum_size.y,
				"drag proxy must be enlarged on both axes, not just widened")
	assert_eq(proxy.scale, Vector2.ONE, "proxy scale is reserved for drop feedback, not the base size")


# 用例 5：瞄准是"弧箭"而非细线——多点曲线、起点在源卡上沿、命中敌人转朱砂。
func test_aim_line_is_a_curved_arrow_from_card_top() -> void:
	var played: Array = []
	var viewport := _new_viewport()
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]))
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var card_rect := card_button.get_global_rect()
	var from := card_rect.get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(200, -100))
	await get_tree().process_frame
	var line = _find_viewport_child(viewport, "battle_aim_line")
	assert_not_null(line, "targeted card must spawn the aim overlay")
	if line == null:
		return
	var points: PackedVector2Array = line.points()
	assert_gt(points.size(), 8, "aim must be a sampled curve, not a 2-point hairline")
	assert_almost_eq(points[0].x, card_rect.get_center().x, 2.0,
			"arrow must leave from the source card top center")
	assert_almost_eq(points[0].y, card_rect.position.y, 2.0,
			"arrow must start at the source card top edge, not its middle")
	# 颜色轴 = 卡牌性质（攻击=朱砂 / 控制=青灰）；锁定与否由**线型与线宽**表达，
	# 两轴正交。所以"未命中敌人"时颜色仍是攻击卡的朱砂，只是 is_hot 为假（画虚线）。
	assert_eq(line.color(), GuStyle.CINNABAR, "攻击卡的箭必须是朱砂，与是否锁定无关")
	assert_false(line.is_hot(), "未命中敌人时不得进入锁定态（画虚线、不加粗）")
	# 移到存活敌人身上 → 转朱砂，箭身变热。
	var enemy := _named(host, "enemy_actor_e0") as Control
	assert_not_null(enemy)
	_viewport_mouse_motion(viewport, enemy.get_global_rect().get_center())
	await get_tree().process_frame
	assert_true(line.is_hot(), "aim over a living enemy must be marked hot")
	assert_eq(line.color(), GuStyle.CINNABAR, "hot aim must turn cinnabar")
	# 收尾：移开并抬起，避免落到敌人上走确认/出牌流程。
	_viewport_mouse_motion(viewport, from + Vector2(-200, -40))
	_viewport_mouse_button(viewport, from + Vector2(-200, -40), false)
	await get_tree().process_frame
	assert_true(played.is_empty(), "aiming over an enemy then releasing elsewhere must not submit")


# 用例 6：解释栏锚定被悬停卡的上方（不盖卡、不跟鼠标），拖拽期间整体收起。
func test_tooltip_anchors_above_card_and_hides_during_drag() -> void:
	var played: Array = []
	var viewport := _new_viewport()
	var host := _mount_in(viewport, func(card_id, target_id): played.append([card_id, target_id]),
			NON_TARGET_CARD)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var card_button := _button(host, "凝气蛊")
	assert_not_null(card_button)
	card_button.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var tip := _named(host, "battle_hand_tooltip_host") as Control
	assert_not_null(tip)
	if tip == null:
		return
	assert_true(tip.visible, "hovering a hand card must show the shared explanation panel")
	var card_rect := card_button.get_global_rect()
	var tip_rect := tip.get_global_rect()
	assert_true(tip_rect.end.y <= card_rect.position.y + 1.0,
			"explanation panel must sit above the hovered card (the hand hugs the bottom edge)")
	assert_false(tip_rect.intersects(card_rect),
			"explanation panel must not cover the card it explains")
	assert_true(get_viewport().get_visible_rect().grow(-GuStyle.SPACE_3).encloses(tip_rect),
			"explanation panel must stay inside the viewport")
	# 按住拖动 → 解释栏收起（否则它盖在影卡/箭上，读不出手势对象）。
	var from := card_rect.get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(0, -40))
	await get_tree().process_frame
	assert_false(tip.visible, "explanation panel must collapse while dragging or aiming")


# 用例 7：悬停抬升卡体；鼠标离开复位并收起解释栏。
func test_hover_lifts_card_and_mouse_exit_resets() -> void:
	var host := _mount(func(_card_id, _target_id): pass, NON_TARGET_CARD)
	await get_tree().process_frame
	var box := _named(host, "card_box_c2") as Control
	var card_button := _button(host, "凝气蛊")
	assert_not_null(box)
	assert_not_null(card_button)
	if box == null or card_button == null:
		return
	assert_eq(box.scale, Vector2.ONE, "card must rest at scale 1 before hover")
	card_button.mouse_entered.emit()
	# 悬停抬升是**补间**（0.16s）而非瞬时赋值：只等一帧会读到补间中途的缩放，
	# 断言会拿到 1.0x 的中间值。等补间跑完再看。
	await _wait_tween()
	assert_gt(box.scale.x, 1.0, "hovering must lift the card out of the row")
	assert_gt(box.pivot_offset.y, 0.0, "lift must pivot on the card bottom edge so it floats upward")
	var tip := _named(host, "battle_hand_tooltip_host") as Control
	assert_true(tip.visible)
	card_button.mouse_exited.emit()
	await _wait_tween()
	assert_eq(box.scale, Vector2.ONE, "leaving the card must reset the lift")
	assert_false(tip.visible, "leaving the card must collapse the explanation panel")


# 用例 8：真实形态的带点 id（`gu.gu_001`）也必须能取到卡体矩形。
# 节点名不允许含 "."，引擎会把点清洗成 "_"，因此按节点名反查会静默返回 null——
# 真机后果（2026-09-10 冒烟复现）：瞄准线起点退回鼠标位 → 曲线退化成一个点 → 整条线看不见；
# 连带影卡回弹到 (0,0)、源卡不压暗、悬停不抬升。本用例把这条钉死。
func test_dotted_card_id_resolves_rect_and_keeps_aim_line_visible() -> void:
	var dotted := {"id": "gu.gu_001", "name": "月光蛊", "cost": 1, "effect": "造成伤害",
			"executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0"]}
	var viewport := _new_viewport()
	var host := _mount_in(viewport, func(_card_id, _target_id): pass, dotted)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	# 手牌组件实例名是 "Hand"；"battle_hand" 是它外层的 VBox。
	var hand = _named(host, "Hand")
	assert_not_null(hand)
	if hand == null:
		return
	var rect: Rect2 = hand.card_rect("gu.gu_001")
	assert_gt(rect.size.x, 0.0, "带点 id 必须取得到卡体矩形（不能靠节点名反查）")
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	if card_button == null:
		return
	var from := card_button.get_global_rect().get_center()
	_viewport_mouse_motion(viewport, from)
	_viewport_mouse_button(viewport, from, true)
	_viewport_mouse_motion(viewport, from + Vector2(200, -100))
	await get_tree().process_frame
	var line = _find_viewport_child(viewport, "battle_aim_line")
	assert_not_null(line, "带点 id 的指向卡也必须出瞄准线")
	if line == null:
		return
	var points: PackedVector2Array = line.points()
	assert_gt(points[0].distance_to(points[points.size() - 1]), 50.0,
			"起点与终点必须分开：起点退回鼠标位会让曲线退化成一个点、整条线消失")
	assert_almost_eq(points[0].x, rect.get_center().x, 2.0, "起点应落在源卡上沿中点")


func _new_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child(viewport)
	_hosts.append(viewport)
	return viewport


func test_right_click_cancels_target_selection_without_submitting() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	assert_true(_press(host, "月光蛊"))
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	card_button.gui_input.emit(event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_idle"))
	assert_true(played.is_empty())


func test_escape_cancels_target_selection_without_submitting() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	assert_true(_press(host, "月光蛊"))
	await get_tree().process_frame
	var card_button := _button(host, "月光蛊")
	assert_not_null(card_button)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	card_button.gui_input.emit(event)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_idle"))
	assert_true(played.is_empty())


func test_same_card_target_pair_submits_once_per_snapshot() -> void:
	var played: Array = []
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]))
	var screen := _screen(host)
	var card: Dictionary = _state_card(screen)
	screen._submit_card(card, "e0")
	screen._submit_card(card, "e0")
	assert_eq(played, [["c1", "e0"]],
			"a repeated UI signal must not replay play_card against the same snapshot")


func test_dangerous_target_card_confirms_after_target_and_cancel_does_not_submit() -> void:
	var played: Array = []
	var danger_card := {
		"id": "c2", "name": "燃寿蛊", "cost": 1, "effect": "造成伤害",
		"executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0"],
		"dangerous": true, "known_risk": ["寿元 -1"],
	}
	var host := _mount(func(card_id, target_id): played.append([card_id, target_id]), danger_card)
	assert_true(_press(host, "燃寿蛊"))
	await get_tree().process_frame
	var confirm := _named(host, "ConfirmDialog")
	assert_not_null(confirm)
	assert_false(confirm.visible, "target selection must precede danger confirmation")
	assert_true(_press(host, "敌人0"))
	await get_tree().process_frame
	assert_true(confirm.visible)
	assert_true(played.is_empty())
	assert_true(_press(host, "取消"))
	await get_tree().process_frame
	assert_not_null(_named(host, "battle_drag_cancel"))
	assert_true(played.is_empty())


func _mount(on_play: Callable, card: Dictionary = {}) -> Control:
	var host := _mount_in(self, on_play, card)
	_hosts.append(host)
	return host


func _mount_in(parent: Node, on_play: Callable, card: Dictionary = {}) -> Control:
	var host := Control.new()
	parent.add_child(host)
	var state := {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": [
			{"id": "e0", "name": "敌人0", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
			{"id": "e1", "name": "敌人1", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
		],
		"player": {"hp": 20, "max_hp": 20, "shield": 0, "primordial": 3, "soul": 4, "statuses": []},
		"hand": [card if not card.is_empty() else {"id": "c1", "name": "月光蛊", "cost": 1, "effect": "造成伤害", "executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0"]}],
		"piles": {"draw": 0, "discard": 0, "exhausted": 0}, "soul_ops": {"cap": 1, "used": 0}, "default_target_id": "e0",
	}
	# 战斗屏已迁到 Godot 官方 .tscn（scenes/ui/screens/battle_screen.tscn）。
	var inst := TscnMountHelper.instantiate(
			"res://scenes/ui/screens/battle_screen.tscn",
			state, {"play_card": on_play})
	host.add_child(inst)
	return host


func _screen(host: Node) -> Node:
	for child in host.get_children():
		if child is BattleScreenView:
			return child
	return null


func _state_card(screen: Node) -> Dictionary:
	return screen._snapshot.get("hand", [])[0]


func _viewport_mouse_motion(viewport: SubViewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	viewport.push_input(event)


## 等补间跑完再断言终点值（组件用 create_tween）。
##
## ⚠️ 必须按**真实时间**等，不能按帧数：无头模式帧率不受限，24 帧可能只有 0.1s，
## 短于补间时长（悬停 0.16s / 收线淡出 0.18s）→ 断言读到中途值或未回收的节点，
## 表现为**单跑绿、全量跑红**的随机失败（本会话踩过）。
## 取 0.35s：比这两个补间都长，且远小于 GUT 的用例超时。
func _wait_tween() -> void:
	await get_tree().create_timer(0.35).timeout


func _viewport_mouse_button(viewport: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	viewport.push_input(event)


func _press(node: Node, text: String) -> bool:
	var button := _button(node, text)
	if button != null:
		button.pressed.emit()
		return true
	return false


func _button(node: Node, text: String) -> Button:
	# 卡面是多行文案（品质/名称/费用/效果），卡名只作为其中一行出现；先精确
	# 匹配（「取消」不得命中「取消目标」），找不到再退回 contains 匹配卡面。
	var exact := _button_match(node, text, true)
	return exact if exact != null else _button_match(node, text, false)


func _button_match(node: Node, text: String, exact: bool) -> Button:
	if node is Button:
		var label := str((node as Button).text)
		var hit := (label == text) if exact else label.contains(text)
		if hit and not (node as Button).disabled:
			return node
	for child in node.get_children():
		var found := _button_match(child, text, exact)
		if found != null:
			return found
	return null


func _named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null
