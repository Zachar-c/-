extends GutTest


# Spec-v4 phase-2 (T6.3): yuanstone scale (§9.1), NPC demand quotes (§9.2),
# gu prices and purchase rhythm (§9.3), identity-gated exchanges (§3.3) and
# structured information (§9.4). Pure static, deterministic, config-driven.
# Acceptance #18: selling keeps the player's knowledge, spreading decays the
# exclusive value, every buyer pays for the same fact only once.


const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func test_yuanstone_scale_anchors() -> void:
	# §9.1: 1-turn normal material buys at 10 stones; resale 50%; low
	# liquidity 30%; high-turn standard value projects through the rank
	# multiplier.
	assert_almost_eq(float(MarketRulesScript.t1_material_base_price(catalog)),
			10.0, 0.0001)
	assert_almost_eq(float(MarketRulesScript.public_resale(10.0, catalog)),
			5.0, 0.0001)
	assert_almost_eq(float(MarketRulesScript.low_liquidity_resale(10.0, catalog)),
			3.0, 0.0001)
	assert_almost_eq(float(MarketRulesScript.rank_standard_price(3, catalog)),
			40.0, 0.0001)
	var tuned := catalog.duplicate(true)
	var balance := (catalog["balance"] as Dictionary).duplicate(true)
	balance["rank_step_ratio"] = 3.0
	tuned["balance"] = balance
	assert_almost_eq(float(MarketRulesScript.rank_standard_price(3, tuned)),
			90.0, 0.0001, "rank value must follow the config")


func test_demand_quote_uses_the_three_tiers() -> void:
	# §9.2: 80% / 100% / 120% of the standard buy price, gated by the real
	# demand identity.
	var tier0 := MarketRulesScript.demand_quote(10.0, 1, 0, catalog)
	assert_almost_eq(float(tier0["unit_price"]), 8.0, 0.0001)
	var tier1 := MarketRulesScript.demand_quote(10.0, 3, 1, catalog)
	assert_almost_eq(float(tier1["unit_price"]), 10.0, 0.0001)
	assert_almost_eq(float(tier1["total"]), 30.0, 0.0001)
	var tier2 := MarketRulesScript.demand_quote(10.0, 1, 2, catalog)
	assert_almost_eq(float(tier2["unit_price"]), 12.0, 0.0001)


func test_demand_disappears_or_drops_after_fulfilment() -> void:
	# §9.2: a fulfilled demand vanishes or drops (anti-farming core).
	var demand := {"quantity": 2, "tier": 1, "material_id": "beast_bone"}
	var after_partial := MarketRulesScript.advance_demand(demand, 1)
	assert_eq(int(after_partial["quantity"]), 1)
	assert_eq(int(after_partial["tier"]), 1)
	var after_full := MarketRulesScript.advance_demand(demand, 2)
	assert_true(bool(after_full.get("closed", false)))
	assert_eq(int(after_full["quantity"]), 0)


func test_gu_prices_four_to_one_and_estimate_differs() -> void:
	# §9.3: a common base gu publicly sells at ~4 same-rank material values
	# and recycles at ~1; the reference estimate is not a purchase price.
	assert_almost_eq(float(MarketRulesScript.gu_public_price(1, catalog)),
			40.0, 0.0001)
	assert_almost_eq(float(MarketRulesScript.gu_recycle_price(1, catalog)),
			10.0, 0.0001)
	var estimate := float(MarketRulesScript.gu_estimate(1, catalog))
	assert_ne(str(estimate), str(40.0),
			"estimate must be its own number (valuation != buyable)")


func test_exchange_lists_permanent_losses_and_rejects_natures() -> void:
	# §3.3: no mechanical conversion; nature-incompatible gu are refused and
	# the trade surfaces the list of permanent losses before commit.
	var offers: Array = [
		{"instance_id": "gu_001", "definition_id": "moonlight_gu",
			"core_state": {"core": true}, "unfed_value_note": "3 layers pending"},
		{"instance_id": "gu_002", "definition_id": "ridge_hound", "ferocity": 2},
	]
	var screen := MarketRulesScript.exchange_screen(offers, catalog)
	assert_true((screen["permanent_losses"] as Array).size() >= 1,
			"permanent loss list must be surfaced for the second confirmation")
	assert_true(bool(screen["rejected_natures"].has("gu_002")),
			"a ferocious gu can be refused on nature")


func test_selling_info_keeps_knowledge_and_decays_exclusivity() -> void:
	# Acceptance #18: the seller keeps the knowledge; spreading decays the
	# exclusive value deterministically; each buyer pays once per fact.
	var info := {"id": "enemy_weakness_001", "base_value": 20.0, "fact": "ridge elite dodge window"}
	var first := MarketRulesScript.sell_info(info, "buyer_a", 0, {}, catalog)
	assert_true(bool(first["sold"]))
	assert_true(bool(first["seller_keeps_knowledge"]),
			"sale must keep the player's knowledge")
	assert_almost_eq(float(first["price"]), 20.0, 0.0001)
	var second_sale := MarketRulesScript.sell_info(
			info, "buyer_b", 1, {"buyer_a": true}, catalog)
	assert_true(float(second_sale["price"]) < 20.0,
			"spreading decays the exclusive value")
	var repeat := MarketRulesScript.sell_info(
			info, "buyer_a", 2, {"buyer_a": true, "buyer_b": true}, catalog)
	assert_false(bool(repeat["sold"]))
	assert_eq(str(repeat["reason"]), "buyer_already_paid")
	# Zero randomness audit.
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/market_rules.gd")
	for token in ["SeededRoll", "roll(", "rand", "randomize"]:
		assert_false(source.contains(token), "market_rules.gd must not reference %s" % token)


func test_stone_has_no_quality_or_face_value_fields() -> void:
	# §9.1: yuanstone is quantity only - the schema rejects quality/face-value
	# keys and the shipped balance declares none.
	var balance: Dictionary = catalog["balance"]
	assert_false(balance.has("stone_quality"))
	assert_false(balance.has("stone_face_value"))
	var bad := catalog.duplicate(true)
	var bad_balance := (catalog["balance"] as Dictionary).duplicate(true)
	bad_balance["stone_quality"] = "high"
	bad["balance"] = bad_balance
	assert_true(ContentCatalogScript.validate(bad).size() > 0)