extends GutTest


const DeckCapacityScript = preload("res://scripts/domain/deck_capacity.gd")
const DeckBuilderScript = preload("res://scripts/domain/deck_builder.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_card_count_matches_deck_cache_and_default_capacity_is_twelve() -> void:
	var run := _run_with_n_instances(3, "small_light_gu")
	assert_eq(DeckCapacityScript.card_count(run, catalog), DeckBuilderScript.build_card_cache(run, catalog).size())
	assert_eq(DeckCapacityScript.capacity(catalog), 12)


func test_buying_at_capacity_is_rejected_without_state_change() -> void:
	var tuned := _capacity_three()
	var run := _run_with_n_instances(3, "small_light_gu")
	assert_eq(DeckCapacityScript.card_count(run, tuned), 3)

	var result := ResolverScript.apply(run, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, tuned)
	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "deck_capacity_exceeded")
	assert_eq(result["state"].refined_gu_ids, run.refined_gu_ids)


func test_buying_below_capacity_is_accepted() -> void:
	var tuned := _capacity_three()
	var run := _run_with_n_instances(2, "small_light_gu")
	var result := ResolverScript.apply(run, {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, tuned)
	assert_true(result["result"]["ok"])
	assert_true(result["state"].refined_gu_ids.has("moonlight_gu"))


func test_consume_type_recipe_stays_allowed_at_capacity_net_delta() -> void:
	var tuned := _capacity_three()
	var run := _fresh_run()
	_add_refined(run, "gu_001", "small_light_gu")
	_add_refined(run, "gu_002", "moonlight_gu")
	_add_refined(run, "gu_003", "small_light_gu")
	assert_eq(DeckCapacityScript.card_count(run, tuned), 3)
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, tuned)
	assert_true(result["result"]["ok"])
	assert_eq(result["result"].get("reason", ""), "")


func test_destroying_a_gu_frees_capacity_for_buying() -> void:
	var tuned := _capacity_three()
	var run := _run_with_n_instances(3, "small_light_gu")
	var destroyed := ResolverScript.apply(run, {"type": "destroy_gu", "instance_id": "gu_001"}, tuned)
	assert_true(destroyed["result"]["ok"])
	var bought := ResolverScript.apply(destroyed["state"], {"type": "shop_purchase", "offer_id": "purchase_moonlight"}, tuned)
	assert_true(bought["result"]["ok"])
	assert_true(bought["state"].refined_gu_ids.has("moonlight_gu"))


func test_preview_blocks_purchase_card_when_deck_is_full() -> void:
	var tuned := _capacity_three()
	var run := _run_with_n_instances(3, "small_light_gu")
	var node := {"id": "ridge_black_market", "type": "shop", "choices": []}
	var cards: Array = ActionPreviewServiceScript.preview_actions(run, node, tuned)
	var card := _card(cards, "shop.purchase.moonlight")

	assert_false(bool(card["executable"]))
	assert_string_contains(str(card["block_reason"]), "牌组已满")


func _capacity_three() -> Dictionary:
	var tuned := catalog.duplicate(true)
	var deck: Dictionary = tuned.get("deck", {}).duplicate(true)
	deck["capacity"] = 3
	tuned["deck"] = deck
	return tuned


func _fresh_run() -> RunState:
	var run := RunState.new_run(101)
	run.gu_instances.clear()
	run.cave_aperture["stored_gu_instance_ids"] = []
	run.gu_ids = []
	run.refined_gu_ids = []
	run.equipped_gu_ids = []
	return run


func _run_with_n_instances(count: int, gu_id: String) -> RunState:
	var run := _fresh_run()
	for index in range(count):
		_add_refined(run, "gu_%03d" % (index + 1), gu_id)
	return run


func _add_refined(run: RunState, instance_id: String, gu_id: String) -> void:
	run.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": gu_id,
		"state": "refined",
	}
	run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()


func _card(cards: Array, id: String) -> Dictionary:
	for card in cards:
		if str(card["id"]) == id:
			return card
	push_error("Missing card %s" % id)
	return {}