extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_body_imprint_changes_rule_and_logs_its_lifespan_cost() -> void:
	var result := Resolver.apply(RunState.new_run(101), {"type": "take_body_imprint", "imprint_id": "three_watch"}, catalog)
	assert_true(result["state"].body_imprints.has("three_watch"))
	assert_eq(result["state"].lifespan_debt, 1)
	assert_eq(result["state"].event_log.back()["reason"], "body_imprint_cost")
	assert_true(result["state"].known_facts.has("three_watch_vigilance"))


func test_iron_bone_defense_has_authored_stealth_drawback() -> void:
	var result := Resolver.apply(RunState.new_run(101), {"type": "take_body_imprint", "imprint_id": "iron_bone"}, catalog)
	assert_true(result["state"].body_imprints.has("iron_bone"))
	assert_true(result["state"].known_facts.has("iron_bone_defense"))
	assert_true(result["state"].known_facts.has("iron_bone_stealth_drawback"))


func test_buy_opportunity_rejects_generic_attribute_purchase() -> void:
	var before := RunState.new_run(101)
	var result := Resolver.apply(before, {"type": "buy_opportunity", "offer_type": "cultivation", "cost": 3}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["state"].stone, before.stone)
	assert_eq(result["state"].event_log.size(), before.event_log.size())
