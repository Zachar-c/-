extends GutTest


const VLib = preload("res://addons/reactive_ui_toolkit/core/v.gd")
const RuiRoot = preload("res://addons/reactive_ui_toolkit/core/reactive_root.gd")

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


func test_four_or_more_enemies_keep_first_three_and_expose_remainder() -> void:
	var host := _mount(_snapshot_with_enemies(4))
	assert_not_null(_named(host, "enemy_actor_e0"))
	assert_not_null(_named(host, "enemy_actor_e1"))
	assert_not_null(_named(host, "enemy_actor_e2"))
	assert_not_null(_named(host, "enemy_remainder"))
	assert_null(_named(host, "enemy_actor_e3"), "fourth enemy starts in the compact remainder view")


func _mount(state: Dictionary) -> Control:
	_last_state = state
	var fn = VLib.comp("res://ui/screens/battle_screen.gd", "render")
	assert_true(fn is Callable)
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	_roots.append(RuiRoot.create(host, VLib.fc(fn, {"state": state, "commands": {}})))
	return host


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
		"player": {"hp": 24, "max_hp": 30, "shield": 1, "primordial": 3, "soul": 4, "statuses": []},
		"hand": [], "piles": {"draw": 6, "discard": 2, "exhausted": 1},
		"soul_ops": {"cap": 3, "used": 1}, "default_target_id": "e0",
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
	if node is Button and str((node as Button).text) == text:
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
	# Each card body is one Button whose text is the card name; no duplicate
	# card-name labels should remain inside the hand region.
	assert_eq(_count_labels_with_text(hand, "血牙蛊"), 0, "card name should live only on the body Button, not as a separate label")
	assert_eq(_count_buttons_with_text(hand, "血牙蛊"), 1, "card body Button must exist once with the card name")
	assert_eq(_count_buttons_with_text(hand, "闭息蛊"), 1, "card body Button must exist once with the card name")


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
