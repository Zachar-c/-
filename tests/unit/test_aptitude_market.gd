extends "res://addons/gut/test.gd"


# Aptitude acquisition path (P9 data port) and the M5 anti-farming price rise.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript := preload("res://scripts/domain/encounter_session_resolver.gd")
const ActionPreviewServiceScript := preload("res://scripts/domain/action_preview_service.gd")
const EssenceCapacityScript := preload("res://scripts/domain/essence_capacity.gd")
const ResolverScript := preload("res://scripts/domain/resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_aptitude_paths_are_present_and_valid() -> void:
	var cat: Dictionary = catalog()
	assert_eq(ContentCatalogScript.validate(cat), [])
	var paths: Array = cat["aptitude"].get("paths", [])
	assert_eq(paths.size(), 1)
	var path: Dictionary = paths[0]
	assert_eq(str(path.get("id", "")), "essence_refinement")
	assert_true(int(path.get("cost_lifespan", 0)) > 0)


func test_raise_aptitude_lifts_bing_to_yi_and_refreshes_essence_max() -> void:
	var state := make_state()
	state.cultivation = 2
	state.cave_aperture["essence_max"] = EssenceCapacityScript.essence_max_for(state, catalog(), 2)
	state.cultivator["lifespan"] = 30
	state.stone = 10
	var before_max := int(state.cave_aperture["essence_max"])
	var raised: Dictionary = ResolverScript.apply(state, {"type": "raise_aptitude", "node_id": "body_imprint_ritual"}, catalog())
	assert_true(bool(raised["result"].get("ok", false)))
	assert_eq(str(raised["state"].aptitude), "yi")
	assert_eq(int(raised["state"].cultivator.get("lifespan", 0)), 20)
	assert_eq(raised["state"].stone, 2)
	assert_true(int(raised["state"].cave_aperture["essence_max"]) > before_max)
	assert_eq(str(raised["state"].event_log.back().get("reason", "")), "aptitude_raised")


func test_raise_aptitude_once_per_run() -> void:
	var state := make_state()
	state.cultivator["lifespan"] = 30
	state.stone = 10
	var first: Dictionary = ResolverScript.apply(state, {"type": "raise_aptitude", "node_id": "body_imprint_ritual"}, catalog())
	var second: Dictionary = ResolverScript.apply(first["state"], {"type": "raise_aptitude", "node_id": "body_imprint_ritual"}, catalog())
	assert_true(bool(first["result"].get("ok", false)))
	assert_false(bool(second["result"].get("ok", false)))
	assert_eq(str(second["result"].get("reason", "")), "aptitude_raised_once")


func test_raise_aptitude_rejects_death_deal_and_wrong_nodes() -> void:
	var state := make_state()
	state.cultivator["lifespan"] = 10
	state.stone = 10
	var doomed: Dictionary = ResolverScript.apply(state, {"type": "raise_aptitude", "node_id": "body_imprint_ritual"}, catalog())
	assert_false(bool(doomed["result"].get("ok", false)))
	assert_eq(str(doomed["result"].get("reason", "")), "lifespan_trade_warning")
	var state2 := make_state()
	state2.cultivator["lifespan"] = 30
	state2.stone = 10
	var wrong_node: Dictionary = ResolverScript.apply(state2, {"type": "raise_aptitude", "node_id": "ridge_caravan"}, catalog())
	assert_false(bool(wrong_node["result"].get("ok", false)))
	assert_eq(str(wrong_node["result"].get("reason", "")), "aptitude_path_unavailable")


func test_preview_shows_aptitude_card_only_at_path_nodes() -> void:
	var state := make_state()
	state.cultivator["lifespan"] = 30
	state.stone = 10
	var seclusion_cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, {"id": "body_imprint_ritual", "type": "seclusion"}, catalog())
	var found := false
	for card in seclusion_cards:
		if str(card.get("id", "")) == "raise_aptitude":
			found = true
			assert_true(bool(card.get("executable", false)))
	assert_true(found)
	var shop_cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(state, {"id": "ridge_black_market", "type": "shop"}, catalog())
	for card in shop_cards:
		assert_ne(str(card.get("id", "")), "raise_aptitude")


func test_market_revisit_raises_prices_and_lowers_sell_offers() -> void:
	var state := make_state()
	assert_eq(ResolverScript.price_for(catalog(), state, 8), 8)
	state.node_flags["shop_visits"] = 2
	assert_eq(ResolverScript.price_for(catalog(), state, 8), 10)
	assert_eq(ResolverScript.sell_price_for(catalog(), state, 2), 1)


func test_market_visits_are_counted_on_begin() -> void:
	var state := make_state()
	var begun: Dictionary = EncounterSessionResolverScript.begin(state, {"id": "ridge_black_market", "type": "shop"}, catalog())
	assert_eq(int(begun["state"].node_flags.get("shop_visits", 0)), 1)
	assert_eq(str(begun["state"].event_log.back().get("reason", "")), "encounter_started")