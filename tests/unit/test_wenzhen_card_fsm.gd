extends GutTest


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
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


func _mount(on_play: Callable) -> Control:
	var fn = VLib.comp("res://ui/screens/battle_screen.gd", "render")
	assert_true(fn is Callable)
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	var state := {
		"resources": {}, "contracts": [], "anomalies": [], "death_lines": {},
		"enemies": [
			{"id": "e0", "name": "敌人0", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
			{"id": "e1", "name": "敌人1", "hp": 20, "max_hp": 20, "shield": 0, "statuses": [], "intent": {"type": "attack", "value": 4, "detail": "冲撞"}, "alive": true},
		],
		"player": {"hp": 20, "max_hp": 20, "shield": 0, "primordial": 3, "soul": 4, "statuses": []},
		"hand": [{"id": "c1", "name": "月光蛊", "cost": 1, "effect": "造成伤害", "executable": true, "target_type": "single_enemy", "valid_target_ids": ["e0"]}],
		"piles": {"draw": 0, "discard": 0, "exhausted": 0}, "soul_ops": {"cap": 1, "used": 0}, "default_target_id": "e0",
	}
	_roots.append(RuiRoot.create(host, VLib.fc(fn, {"state": state, "commands": {"play_card": on_play}})))
	return host


func _press(node: Node, text: String) -> bool:
	var button := _button(node, text)
	if button != null:
		button.pressed.emit()
		return true
	return false


func _button(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text and not (node as Button).disabled:
		return node
	for child in node.get_children():
		var found := _button(child, text)
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
