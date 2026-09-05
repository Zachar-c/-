extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_bind_gu_enables_kill_of_stone_wanderer_through_basic_attacks() -> void:
	# thorn_whip 于 802 重建删去、荆棘束缚/抽击手牌卡不再产出；改以现存束缚蛊
	# blood_farewell_gu 锚定同一验收：束缚挡下石甲反制后，拳脚直击可击杀石行者。
	var state := _run_with_gu(["blood_farewell_gu"])
	var current := {"battle": BattleResolver.start({"enemy_kind": "neutral_stone_wanderer", "objective": "defeat", "enemy_hp": 2}, state, catalog), "state": state}
	var hp0 := int(current["battle"]["enemy_hp"])
	for _cycle in range(16):
		var enemy_bound := (current["battle"].get("flags", []) as Array).has("enemy_bound")
		var actions_left := int(current["battle"].get("actions_left", 0))
		var turn: Dictionary
		if not enemy_bound:
			turn = BattleResolver.take_turn(current["battle"],
					{"type": "use_gu", "gu_id": "blood_farewell_gu"}, current["state"], catalog)
			assert_true(bool(turn.get("accepted", false)), "bind must be accepted: %s" % str(turn))
		elif actions_left < 1:
			turn = BattleResolver.take_turn(current["battle"],
					{"type": "end_turn"}, current["state"], catalog)
		else:
			turn = BattleResolver.take_turn(current["battle"],
					{"type": "basic_attack"}, current["state"], catalog)
		if bool(turn.get("finished", false)):
			assert_eq(str(turn.get("result", "")), "victory")
			assert_lt(int(turn["battle"]["enemy_hp"]), hp0)
			return
		current = {"battle": turn["battle"], "state": turn["state"]}
	fail_test("Wanderer was not defeated within the cycle budget")


func _hand_card_id(cards: Array[Dictionary], definition_id: String) -> String:
	for card_value in cards:
		var card: Dictionary = card_value
		if str(card["id"]).ends_with(":%s:0" % definition_id) and bool(card.get("executable", false)):
			return str(card["id"])
	return ""


func test_first_run_route_wires_black_market_and_echo_cave() -> void:
	var route := MapGenerator.build(101, true)
	var by_id := {}
	for node in route:
		by_id[str(node["id"])] = node
	# 节点收窄（2026-09-06）：骨架链 = 战斗/休息/Boss/商店，黑市仍在列，
	# 事件类 echo_cave / 台账类 stage_one_ledger 不再由 first_run 生成。
	assert_true(by_id.has("ridge_black_market"), "骨架链保留商店（黑市）补给点")
	assert_false(by_id.has("echo_cave"), "事件类模板不再由 first_run 链生成")
	# 线性骨架：iron_hide_ambush（战斗）→ 黑市（商店）。
	var ambush_next: Array = by_id["iron_hide_ambush"]["next_ids"]
	assert_true(ambush_next.has("ridge_black_market"))
	assert_true(by_id.has("layer_boss_stand_1"), "链中含层关底 Boss 台")
	assert_true(by_id.has("rest_hollow"), "链中含休息补给点")
	assert_true(by_id.has("final_boss_stand"), "链终点前为终局 Boss")


func test_black_market_offers_moonlight_for_stone() -> void:
	var state := RunState.new_run(101)
	var node := {"id": "ridge_black_market", "type": "shop", "choices": []}
	var card := _card(ActionPreviewServiceScript.preview_actions(state, node, catalog), "shop.purchase.moonlight")
	assert_false(card.is_empty())
	assert_eq(int(card["cost"]["stone"]), 6)
	assert_true(bool(card["executable"]))


func _run_with_gu(definition_ids: Array[String]) -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	for index in definition_ids.size():
		var instance_id := "gu_%03d" % (index + 1)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": definition_ids[index],
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	return run


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}
