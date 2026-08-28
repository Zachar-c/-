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
	var fn = VLib.comp("res://ui/screens/battle_screen.gd", "render")
	assert_true(fn is Callable)
	var host := Control.new()
	add_child(host)
	_hosts.append(host)
	_roots.append(RuiRoot.create(host, VLib.fc(fn, {"state": state, "commands": {}})))
	return host


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
