extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


## Retired 2026-09-06 (B1 bucket C): the four battle-preview tests below drove
## `BattleResolver.start`/`take_turn` on the legacy `battle.hand` envelope and
## asserted `enemy_hp` / `revealed_reactions` — both legacy fields dead under
## the V1 facade. Equivalent V1-path coverage now lives in
## test_wenzhen_battle_screen.gd's mount/refresh legs, which drive a real
## wenzhen battle through `BattleCommandFacade`. The non-battle preview tests
## (caravan/refinement/cultivation/ledger/event/rest/standard/ascension) stay
## as the live regression surface for action_preview_service.

func test_exchange_preview_keeps_missing_input_visible_without_mutating_state() -> void:
	var state := RunState.new_run(101)
	var before_events := state.event_log.size()
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "ridge_caravan",
		"type": "caravan",
	}, catalog)
	var card := _card(cards, "caravan.exchange.caravan_mist_exchange")

	assert_false(card["executable"])
	assert_string_contains(str(card["block_reason"]), "月光蛊")
	assert_eq(card["cost"]["gu_ids"], ["small_light_gu", "moonlight_gu"])
	assert_eq(card["expected_gain"], ["获得雾蛊。"])
	assert_false(card.get("remedy_hints", []).is_empty())
	assert_eq(state.event_log.size(), before_events)
	assert_eq(state.refined_gu_ids, ["small_light_gu"])


func test_refinement_preview_exposes_recipe_cost_and_gain() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids = ["small_light_gu", "moonlight_gu"]
	state.gu_ids = state.refined_gu_ids.duplicate()
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "refinement_hollow",
		"type": "refinement",
	}, catalog)
	var card := _card(cards, "refine.moon_ray_forged")

	assert_true(card["executable"])
	assert_eq(card["cost"]["gu_ids"], ["moonlight_gu", "small_light_gu"])
	assert_eq(card["expected_gain"], ["获得月痕蛊。"])
	assert_eq(str(card["unknown_note"]), "")
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

	assert_eq(str(probe["command"].get("type", "")), "choose_action")
	assert_eq(str(probe["command"].get("action_id", "")), "probe")
	assert_eq(str(probe["command"].get("npc_id", "")), "caravan_steward")
	assert_eq(str(fight["command"].get("type", "")), "choose_action")
	assert_eq(str(fight["command"].get("action_id", "")), "fight")
	assert_eq(str(fight["command"].get("npc_id", "")), "caravan_steward")
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


func test_extreme_hostile_caravan_exposes_one_executable_fight_card() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "ridge_caravan"
	state.encounter_session = {
		"node_id": "ridge_caravan",
		"phase": "active",
		"completed": false,
		"stance": "extreme_hostile",
		"offers_fight": true,
	}
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "ridge_caravan",
		"type": "caravan",
	}, catalog)
	var fight_cards: Array[Dictionary] = []
	for card_value in cards:
		var card: Dictionary = card_value
		var command: Dictionary = card.get("command", Dictionary())
		if str(command.get("action_id", "")) == "fight":
			fight_cards.append(card)

	assert_eq(fight_cards.size(), 1)
	assert_eq(str(fight_cards[0]["id"]), "node.fight")
	assert_true(bool(fight_cards[0]["executable"]))
	var fight_command: Dictionary = fight_cards[0]["command"]
	assert_eq(str(fight_command.get("type", "")), "choose_action")
	assert_eq(str(fight_command.get("action_id", "")), "fight")
	assert_eq(str(fight_command.get("npc_id", "")), "caravan_steward")


func test_neutral_caravan_does_not_expose_fight_card() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "ridge_caravan"
	state.encounter_session = {
		"node_id": "ridge_caravan",
		"phase": "active",
		"completed": false,
		"stance": "neutral",
		"offers_fight": true,
	}
	var cards := ActionPreviewServiceScript.preview_actions(state, {
		"id": "ridge_caravan",
		"type": "caravan",
	}, catalog)

	assert_false(_has_card(cards, "node.fight"))


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

