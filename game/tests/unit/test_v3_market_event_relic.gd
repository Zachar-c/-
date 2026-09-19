extends GutTest


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_lifespan_market_deal_shows_known_cost_and_blocks_death_trade() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 1
	var card := _card(ActionPreviewServiceScript.preview_actions(run, _shop_node(), catalog), "shop.lifespan.pulse_drum")
	assert_eq(int(card["cost"]["lifespan"]), 1)
	assert_false(bool(card["executable"]))
	var shop_node := _shop_node()
	run.current_node_id = str(shop_node["id"])
	var session := EncounterSessionResolverScript.start(shop_node)
	var result := EncounterSessionResolverScript.apply(
		run,
		session,
		{"type": "action_card", "action_id": card["id"], "state_version": card["state_version"], "node_id": str(shop_node["id"]), "session_node_id": str(session["node_id"])},
		catalog,
		shop_node
	)
	assert_eq(str(result["state"].terminal_state), "active")
	assert_eq(int(result["state"].cultivator["lifespan"]), 1)


func test_barter_preview_keeps_reward_unknown_but_shows_observable_trader_clue() -> void:
	var card := _card(ActionPreviewServiceScript.preview_actions(RunState.new_run(101), _shop_node(), catalog), "shop.barter.unknown_gu")
	assert_string_contains(str(card["unknown_note"]), "结果未明")
	assert_false(card["known_risk"].is_empty())
	assert_false(card["command"].has("reward_id"))


func test_hungry_vine_relic_adds_next_node_feeding_pressure() -> void:
	var run := RunState.new_run(101)
	var result := Resolver.apply(run, {"type": "gain_relic", "relic_id": "hungry_vine_token"}, catalog)
	assert_eq(int(result["state"].estimate_feeding_materials(catalog)["feed_points"]), 2)


func test_echo_cave_accept_pays_known_health_and_delays_hidden_soul_drain() -> void:
	var run := RunState.new_run(101)
	var accepted := Resolver.apply(run, {"type": "accept_event", "event_id": "echo_cave"}, catalog)
	assert_true(accepted["result"]["ok"])
	assert_eq(int(accepted["state"].health), 99)
	assert_eq(int(accepted["state"].node_flags.get("pending_delayed_soul_drain", 0)), 1)
	var traveled := Resolver.apply(accepted["state"], {"type": "travel", "node_id": "ridge_market"}, catalog)
	assert_eq(int(traveled["state"].cultivator["soul"]), 0)
	assert_eq(int(traveled["state"].node_flags.get("pending_delayed_soul_drain", 0)), 0)


func _shop_node() -> Dictionary:
	return {"id": "ridge_black_market", "type": "shop", "choices": []}


func _card(cards: Array[Dictionary], id: String) -> Dictionary:
	for card in cards:
		if str(card.get("id", "")) == id:
			return card
	push_error("Missing action card: %s" % id)
	return {}
