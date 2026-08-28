extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_exchange_preview_keeps_missing_input_visible_without_mutating_state() -> void:
	var state := RunState.new_run(101)
	var before_events := state.event_log.size()
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "ridge_caravan",
		"type": "caravan",
	}, catalog)
	var card := _card(cards, "caravan.exchange.caravan_mist_exchange")

	assert_false(card["executable"])
	assert_string_contains(str(card["block_reason"]), "寻迹眼蛊")
	assert_eq(card["cost"]["gu_ids"], ["trail_eye_gu", "stone_shell_gu"])
	assert_eq(card["expected_gain"], ["获得雾步蛊。"])
	assert_false(card.get("remedy_hints", []).is_empty())
	assert_eq(state.event_log.size(), before_events)
	assert_eq(state.refined_gu_ids, ["small_light_gu"])


func test_refinement_preview_exposes_recipe_rate_and_destroy_risk() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids = ["small_light_gu", "trail_eye_gu"]
	state.gu_ids = state.refined_gu_ids.duplicate()
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "refinement_hollow",
		"type": "refinement",
	}, catalog)
	var card := _card(cards, "refine.bright_thread_risk")

	assert_true(card["executable"])
	assert_eq(card["success_rate"], 70)
	assert_eq(card["cost"]["gu_ids"], ["small_light_gu", "trail_eye_gu"])
	assert_eq(card["expected_gain"], ["获得脉冲鼓蛊。"])
	assert_string_contains(str(card["known_risk"][0]), "损毁")
	assert_eq(card["unknown_note"], "炼制成败未定。")
	assert_false(card["command"].has("roll"))


func test_cultivation_preview_reports_stone_shortfall_and_remedy() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "cultivation_spring"
	state.stone = 3
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "cultivation_spring",
		"type": "cultivation",
	}, catalog)
	var card := _card(cards, "cultivate.rank_two")

	assert_false(card["executable"])
	assert_string_contains(str(card["block_reason"]), "还差 2")
	assert_eq(card["cost"]["stone"], 5)
	assert_false(card.get("remedy_hints", []).is_empty())


func test_ledger_preview_offers_debt_when_payment_is_blocked() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "stage_one_ledger"
	state.stone = 0
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "stage_one_ledger",
		"type": "ledger",
	}, catalog)
	var payment := _card(cards, "ledger.pay")
	var debt := _card(cards, "ledger.accept_debt")

	assert_false(payment["executable"])
	assert_string_contains(str(payment["block_reason"]), "元石不足")
	assert_true(debt["executable"])
	assert_eq(debt["expected_gain"], ["以商队人情结清本阶段养蛊总账。"])


func test_battle_preview_shows_known_reaction_risk_without_revealing_hidden_counter() -> void:
	var state := _state_with_refined_gu("thorn_whip_gu", "gu_002")
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, state, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)
	var strike := _battle_card_by_definition(cards, battle, "thorn_strike")

	assert_eq(strike["cost"]["spirit"], 1)
	assert_string_contains(str(strike["known_risk"][0]), "石粉")
	assert_string_contains(str(strike["unknown_note"]), "未暴露")
	assert_false(str(strike["known_risk"][0]).contains("石甲蛊"))


func test_battle_preview_blocks_gu_when_essence_is_insufficient() -> void:
	var state := RunState.new_run(101)
	state.essence = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, state, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)
	var light := _battle_card_by_definition(cards, battle, "light_probe")

	assert_false(light["executable"])
	assert_string_contains(str(light["block_reason"]), "真元不足")


func test_battle_preview_projects_single_enemy_target_contract() -> void:
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({
		"enemy_kinds": ["ridge_hound", "neutral_stone_wanderer"],
	}, state, catalog)
	var cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)
	var light := _battle_card_by_definition(cards, battle, "light_probe")

	assert_eq(light["target_type"], "single_enemy")
	assert_eq(light["valid_target_ids"], [
		str(battle["enemies"][0]["enemy_id"]),
		str(battle["enemies"][1]["enemy_id"]),
	])


func test_preview_uses_display_text_as_the_single_name_source() -> void:
	var state := _state_with_refined_gu("blood_moss_gu", "gu_002")
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, state, catalog)
	var battle_cards := ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog)
	var gu_card := _battle_card_by_definition(battle_cards, battle, "blood_moss_relief")
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "moonlit_trail",
		"type": "hazard",
		"choices": ["scout"],
	}, catalog)
	var action_card := _card(cards, "node.scout")

	assert_eq(gu_card["title"], DisplayText.gu("blood_moss_gu"))
	assert_eq(action_card["title"], DisplayText.action("scout"))


func test_body_imprint_preview_blocks_the_imprint_already_taken_by_resolver() -> void:
	var state := RunState.new_run(101)
	state.body_imprints.append("iron_bone")
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "body_imprint_ritual",
		"type": "seclusion",
		"choices": ["take_imprint"],
	}, catalog)
	var card := _card(cards, "node.take_imprint")

	assert_false(card["executable"])
	assert_string_contains(str(card["block_reason"]), "铁骨体印")
	assert_false(card.get("remedy_hints", []).is_empty())


func test_standard_action_preview_exposes_declared_effects_before_submission() -> void:
	var state := RunState.new_run(101)
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "sealed_earth_vein",
		"type": "earth_vein",
		"choices": ["open", "withdraw"],
	}, catalog)
	var open := _card(cards, "node.open")
	var withdraw := _card(cards, "node.withdraw")

	assert_eq(open["expected_gain"], ["获得可用于升仙的地点。"])
	assert_eq(withdraw["expected_gain"], ["安全收手，保留当前资源与情报。"])
	assert_string_contains(str(withdraw["known_risk"]), "放弃")


func test_ascension_attempt_preview_uses_chinese_title_and_public_conditions() -> void:
	var state := RunState.new_run(101)
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "ascension_window",
		"type": "ascension",
		"choices": ["attempt_ascension"],
	}, catalog)
	var card := _card(cards, "node.attempt_ascension")

	assert_eq(card["title"], "冲击升仙")
	assert_string_contains(str(card["known_risk"]), "不可逆")
	assert_false(card["expected_gain"].is_empty())


func test_caravan_dispute_previews_social_actions_instead_of_market_offers() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "caravan_missing_goods"
	state.known_facts = ["ledger_evidence"]
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "caravan_missing_goods",
		"type": "caravan",
		"choices": ["probe", "trade", "leave", "fight"],
	}, catalog)
	var probe := _card(cards, "node.probe")
	var trade := _card(cards, "node.trade")
	var fight := _card(cards, "node.fight")

	assert_eq(probe["command"], {"type": "choose_action", "action_id": "probe", "npc_id": "caravan_steward"})
	assert_false(trade["executable"])
	assert_string_contains(str(trade["block_reason"]), "账册证据")
	assert_eq(fight["command"], {"type": "choose_action", "action_id": "fight", "npc_id": "caravan_steward"})
	assert_string_contains(str(fight["known_risk"]), "死亡")
	assert_false(_has_card(cards, "caravan.buy.caravan_thorn_offer"))


func test_caravan_dispute_trade_unlocks_after_probe_exposes_evidence() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "caravan_missing_goods"
	state.known_facts = ["ledger_evidence"]
	var resolved := Resolver.apply(state, {
		"type": "choose_action",
		"action_id": "probe",
		"npc_id": "caravan_steward",
	}, catalog)
	var cards := ActionPreviewServiceScript.preview_actions(resolved["state"], {
		"id": "caravan_missing_goods",
		"type": "caravan",
		"choices": ["probe", "trade", "leave", "fight"],
	}, catalog)
	var trade := _card(cards, "node.trade")

	assert_true(trade["executable"])
	assert_eq(trade["command"].get("offer", ""), "ledger_evidence")


func _state_with_refined_gu(definition_id: String, instance_id: String) -> RunState:
	var state := RunState.new_run(101)
	state.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	state.sync_legacy_gu_projections()
	return state


func _battle_card_by_definition(cards: Array, battle: Dictionary, definition_id: String) -> Dictionary:
	for instance in battle.get("hand", []):
		if str(instance.get("definition_id", "")) != definition_id:
			continue
		return _card(cards, "battle.%s.%s" % [str(battle["battle_id"]), str(instance["instance_id"])])
	push_error("Missing battle card definition: %s" % definition_id)
	return {}


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}


func _has_card(cards: Array, id: String) -> bool:
	for card in cards:
		if str(card.get("id", "")) == id:
			return true
	return false

