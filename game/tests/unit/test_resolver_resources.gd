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


func test_every_standard_encounter_action_returns_a_visible_consequence() -> void:
	var actions := [
		"accept", "ally", "buy_information", "claim", "cross", "deceive", "harvest",
		"inspect", "leave", "lure", "meditate", "open", "prepare", "retreat", "scout",
		"scheme", "take_imprint", "trade", "withdraw", "work",
	]
	for action_id in actions:
		var before := RunState.new_run(101)
		before.current_node_id = "village_short_work"
		var resolved := Resolver.apply(before, {"type": "choose_action", "action_id": action_id}, catalog)
		assert_true(resolved["result"]["ok"], action_id)
		assert_eq(resolved["result"].get("action_id", ""), action_id, action_id)
		assert_false(str(resolved["result"].get("effect_id", "")).is_empty(), action_id)
		assert_false(resolved["state"].event_log.back()["after"].is_empty(), action_id)
