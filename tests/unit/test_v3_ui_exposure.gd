extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_bind_card_enables_kill_of_stone_wanderer_through_action_cards() -> void:
	var state := _run_with_gu(["thorn_whip_gu", "stone_shell_gu"])
	var current := {"battle": BattleResolver.start({"enemy_kind": "neutral_stone_wanderer", "objective": "defeat"}, state, catalog), "state": state}
	var strikes_landed := 0
	# thorn_bind 的束缚只持续一回合（effect 过期后敌方石甲反应恢复，直接
	# 打击重新被挡）——补 bind 的判据是「敌方当前未被束缚」，不是只绑一次。
	for _cycle in range(12):
		var preview := ActionPreviewServiceScript.preview_battle_actions(current["battle"], current["state"], catalog)
		var enemy_bound := (current["battle"].get("flags", []) as Array).has("enemy_bound")
		var target := ""
		if not enemy_bound:
			target = _hand_card_id(preview, "thorn_bind")
		if target.is_empty() and strikes_landed < 2:
			target = _hand_card_id(preview, "thorn_strike")
		if target.is_empty():
			# 手牌满时 refill 不抽新牌：打出一张可执行牌（守护）让手牌轮转，
			# 否则抽牌堆里的打击牌永远出不来。
			target = _hand_card_id(preview, "stone_guard")
		var turn: Dictionary
		if target.is_empty():
			turn = BattleResolver.apply_action_card(current["battle"], current["state"], {
				"type": "action_card", "action_id": "battle.end_turn",
				"state_version": int(current["battle"]["hand_version"]),
			}, catalog)
		else:
			turn = BattleResolver.apply_action_card(current["battle"], current["state"], {
				"type": "action_card", "action_id": target,
				"state_version": int(current["battle"]["hand_version"]),
			}, catalog)
			assert_true(bool(turn["accepted"]), str(turn))
			if str(target).ends_with(":thorn_strike:0"):
				strikes_landed += 1
				assert_eq(int(turn["battle"]["enemy_hp"]), 4 - 2 * strikes_landed)
				if strikes_landed == 2:
					assert_true(bool(turn["finished"]))
					assert_eq(str(turn["result"]), "victory")
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
	assert_true(by_id.has("ridge_black_market"))
	assert_true(by_id.has("echo_cave"))
	var market_next: Array = by_id["village_short_work"]["next_ids"]
	assert_true(market_next.has("ridge_black_market"))
	var cave_next: Array = by_id["flooded_cave"]["next_ids"]
	assert_true(cave_next.has("echo_cave"))
	var black_next: Array = by_id["ridge_black_market"]["next_ids"]
	assert_true(black_next.has("stage_one_ledger"))


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
