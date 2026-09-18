extends GutTest


const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_lifespan_deal_to_zero_is_rejected_without_spend() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 1
	var result := ResolverScript.apply(run, {
		"type": "shop_lifespan_deal",
		"offer_id": "lifespan_pulse_drum",
	}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "lifespan_trade_warning")
	assert_eq(int(result["state"].cultivator["lifespan"]), 1)


func test_lifespan_deal_keeping_one_is_accepted_and_logged() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 2
	var result := ResolverScript.apply(run, {
		"type": "shop_lifespan_deal",
		"offer_id": "lifespan_pulse_drum",
	}, catalog)

	assert_true(result["result"]["ok"])
	assert_eq(int(result["state"].cultivator["lifespan"]), 1)
	assert_eq(result["state"].event_log.back()["reason"], "shop_lifespan_deal_paid")


func test_lifespan_deal_preview_blocks_death_trade_and_shows_projection() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 1
	var node := {"id": "ridge_black_market", "type": "shop", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var card := _card(cards, "shop.lifespan.pulse_drum")

	assert_false(bool(card["executable"]))
	assert_string_contains(str(card["block_reason"]), "寿元")
	assert_string_contains(str(card["known_risk"]), "剩余 0")


func test_lifespan_deal_preview_allows_trade_that_keeps_one() -> void:
	var run := RunState.new_run(101)
	run.cultivator["lifespan"] = 2
	var node := {"id": "ridge_black_market", "type": "shop", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, catalog)
	var card := _card(cards, "shop.lifespan.pulse_drum")

	assert_true(bool(card["executable"]))
	assert_string_contains(str(card["known_risk"]), "剩余 1")


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}