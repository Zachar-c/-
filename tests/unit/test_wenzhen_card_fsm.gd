extends GutTest


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
# 显式 preload 而非依赖 class_name 全局注册：后者的注册有时序，
# 在 GUT 收集脚本阶段可能还没就绪，会让整个测试文件 Parse Error。
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

var _roots: Array = []
var _hosts: Array = []


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
