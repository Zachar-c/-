extends GutTest


# Task 4 P0: imprint/relic-hook expansion (spec R4.8/R4.9/R11.7).
# B1 bucket C: the in-battle relic triggers (on_backlash_gained/on_battle_end/
# on_battle_start effects) were retired with battle_resolver.gd - see NOTE at
# the top of the battle-hook section below. This file now pins the surviving
# run-level relic/imprint contracts: imprint capacity slots (R4.9), meta-grade
# cap <=2 per run (R4.8), meta_rules save round-trip, relic codex unlock at run
# end (R11.7), barter grants, and catalog validation of grade + imprint_capacity.

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


# B1 bucket C (2026-09-06): the five in-battle relic-hook legs below were
# deleted as domain debt - on_backlash_gained/on_battle_end/on_battle_start
# triggers (convert_backlash_to_draw, grant_stone_on_battle_end,
# reduce_curse_intensity) fired only inside battle_resolver.gd; the V1
# engine and facade have no relic battle hooks (zero references), so the
# battle-time relic effects died with the legacy engine. Surviving run-level
# relic/imprint contracts stay pinned below: imprint capacity, meta-grade
# cap, meta_rules save round-trip, codex unlock, barter and catalog
# validation.



func test_imprint_capacity_rejection_leaves_state_untouched() -> void:
	var tuned := catalog.duplicate(true)
	for index in range(5):
		_add_test_relic(tuned, {"id": "filler_relic_%d" % index, "hooks": [], "rarity": "common"})
	var run := RunState.new_run(101)
	run.relic_ids = ["filler_relic_0", "filler_relic_1", "filler_relic_2", "filler_relic_3"]
	var baseline := run.event_log.size()

	var rejected := Resolver.apply(run, {"type": "gain_relic", "relic_id": "filler_relic_4"}, tuned)
	assert_false(rejected["result"]["ok"])
	assert_eq(str(rejected["result"]["reason"]), "imprint_capacity_exceeded")
	assert_eq(rejected["state"].event_log.size(), baseline)
	assert_eq(rejected["state"].relic_ids.size(), 4)

	# Rejection is a no-op, so the same run can free a slot and try again.
	var freed := RunState.new_run(101)
	freed.relic_ids = ["filler_relic_0", "filler_relic_1", "filler_relic_2"]
	var accepted := Resolver.apply(freed, {"type": "gain_relic", "relic_id": "filler_relic_4"}, tuned)
	assert_true(accepted["result"]["ok"])
	assert_eq(accepted["state"].relic_ids.size(), 4)


func test_meta_grade_cap_allows_two_then_rejects_third() -> void:
	var tuned := catalog.duplicate(true)
	for index in range(3):
		_add_test_relic(tuned, {"id": "meta_relic_%d" % index, "grade": "meta_rule", "hooks": [], "rarity": "epic"})
	_add_test_relic(tuned, {"id": "plain_relic", "hooks": [], "rarity": "common"})
	var run := RunState.new_run(101)

	var first := Resolver.apply(run, {"type": "gain_relic", "relic_id": "meta_relic_0"}, tuned)
	assert_true(first["result"]["ok"])
	assert_eq(first["state"].meta_rules, {"meta_relic_0": true})
	assert_true(first["result"].get("feeds", []).has("meta_rule_recorded"))
	assert_eq(int(first["state"].event_log.back()["after"]["meta_rules"].size()), 1)

	var second := Resolver.apply(first["state"], {"type": "gain_relic", "relic_id": "meta_relic_1"}, tuned)
	assert_true(second["result"]["ok"])
	assert_eq(second["state"].meta_rules.size(), 2)

	var baseline: int = second["state"].event_log.size()
	var third := Resolver.apply(second["state"], {"type": "gain_relic", "relic_id": "meta_relic_2"}, tuned)
	assert_false(third["result"]["ok"])
	assert_eq(str(third["result"]["reason"]), "meta_rule_cap_reached")
	assert_eq(third["state"].event_log.size(), baseline)
	assert_eq(third["state"].meta_rules.size(), 2)

	var normal := Resolver.apply(third["state"], {"type": "gain_relic", "relic_id": "plain_relic"}, tuned)
	assert_true(normal["result"]["ok"])
	assert_false(normal["result"].get("feeds", []).has("meta_rule_recorded"))
	assert_eq(normal["state"].meta_rules.size(), 2)


func test_meta_rules_survive_run_save_round_trip() -> void:
	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {"id": "meta_relic_x", "grade": "meta_rule", "hooks": [], "rarity": "rare"})
	var run := RunState.new_run(101)
	var gained := Resolver.apply(run, {"type": "gain_relic", "relic_id": "meta_relic_x"}, tuned)
	assert_true(gained["result"]["ok"])

	var payload := SaveRepository.serialize_run(gained["state"], [], [])
	var loaded: Dictionary = SaveRepository.load_run_from_data(payload)
	assert_false(loaded.is_empty())
	assert_eq(loaded["state"].meta_rules, {"meta_relic_x": true})


func test_real_jade_cicada_shell_is_meta_rule_and_catalog_stays_valid() -> void:
	assert_eq(str(catalog["relic_by_id"]["jade_cicada_shell"].get("grade", "")), "meta_rule")
	assert_eq(ContentCatalog.validate(catalog), [])


func test_validate_rejects_unknown_grade_and_missing_imprint_capacity() -> void:
	var bad_grade := catalog.duplicate(true)
	bad_grade["relics"][0]["grade"] = "legendary_rule"
	var errors := ContentCatalog.validate(bad_grade)
	assert_true("\n".join(errors).contains("unknown grade"), "\n".join(errors))

	var missing_capacity := catalog.duplicate(true)
	missing_capacity["balance"] = (missing_capacity["balance"] as Dictionary).duplicate(true)
	(missing_capacity["balance"] as Dictionary).erase("imprint_capacity")
	errors = ContentCatalog.validate(missing_capacity)
	assert_true("\n".join(errors).contains("imprint_capacity"), "\n".join(errors))


func test_record_run_end_unlocks_relic_codex_and_round_trips() -> void:
	var run := RunState.new_run(101)
	var gained := Resolver.apply(run, {"type": "gain_relic", "relic_id": "jade_cicada_shell"}, catalog)
	assert_true(gained["result"]["ok"])
	assert_eq(gained["state"].meta_rules, {"jade_cicada_shell": true})

	var meta: RefCounted = MetaProgress.new_empty()
	var ended: RefCounted = meta.record_run_end(gained["state"], "dead")
	assert_true(ended.relic_codex_ids.has("jade_cicada_shell"))

	var loaded: RefCounted = SaveRepository.load_meta_from_data(SaveRepository.serialize_meta(ended))
	assert_not_null(loaded)
	assert_true(loaded.relic_codex_ids.has("jade_cicada_shell"))


func test_barter_relic_reward_blocked_at_full_imprint_capacity_resolves_without_relic() -> void:
	var tuned := catalog.duplicate(true)
	for index in range(5):
		_add_test_relic(tuned, {"id": "filler_relic_%d" % index, "hooks": [], "rarity": "common"})
	_add_test_relic(tuned, {"id": "meta_overflow_relic", "grade": "meta_rule", "hooks": [], "rarity": "epic"})
	_add_test_barter_offer(tuned, "barter_relic_offer", {"id": "reward_filler_4", "relic_id": "filler_relic_4", "weight": 1})
	_add_test_barter_offer(tuned, "barter_meta_overflow", {"id": "reward_meta_overflow", "relic_id": "meta_overflow_relic", "weight": 1})

	var run := _run_with_gu(["trail_eye_gu"])
	run.relic_ids = ["filler_relic_0", "filler_relic_1", "filler_relic_2", "filler_relic_3"]

	var blocked := Resolver.apply(run, {"type": "shop_barter", "offer_id": "barter_relic_offer"}, tuned)
	assert_true(blocked["result"]["ok"])
	assert_eq(blocked["state"].relic_ids.size(), 4)
	assert_false(blocked["state"].relic_ids.has("filler_relic_4"))
	assert_eq(int(_count_events(blocked["state"], "shop_barter_resolved")), 1)
	assert_eq(str(blocked["state"].gu_instances["gu_002"]["state"]), "dead")
	var feeds: Array = blocked["result"].get("feeds", [])
	assert_true(feeds.has("relic_reward_blocked_imprint_capacity_exceeded"), str(feeds))

	# Capacity was the binding gate above; the meta cap must also block barter
	# once two meta rules are held.
	var capped_run := _run_with_gu(["trail_eye_gu"])
	capped_run.relic_ids = ["filler_relic_0"]
	capped_run.meta_rules = {"meta_a": true, "meta_b": true}
	var capped := Resolver.apply(capped_run, {"type": "shop_barter", "offer_id": "barter_meta_overflow"}, tuned)
	assert_true(capped["result"]["ok"])
	assert_eq(capped["state"].meta_rules.size(), 2)
	assert_false(capped["state"].relic_ids.has("meta_overflow_relic"))
	var capped_feeds: Array = capped["result"].get("feeds", [])
	assert_true(capped_feeds.has("relic_reward_blocked_meta_rule_cap_reached"), str(capped_feeds))


func test_barter_granting_meta_rule_relic_records_meta_rules_and_feed() -> void:
	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {"id": "meta_barter_relic", "grade": "meta_rule", "hooks": [], "rarity": "epic"})
	_add_test_barter_offer(tuned, "barter_meta_offer", {"id": "reward_meta_barter", "relic_id": "meta_barter_relic", "weight": 1})
	var run := _run_with_gu(["trail_eye_gu"])

	var granted := Resolver.apply(run, {"type": "shop_barter", "offer_id": "barter_meta_offer"}, tuned)
	assert_true(granted["result"]["ok"])
	assert_true(granted["state"].relic_ids.has("meta_barter_relic"))
	assert_eq(granted["state"].meta_rules, {"meta_barter_relic": true})
	var last_event: Dictionary = granted["state"].event_log.back()
	assert_eq(last_event.get("after", {}).get("meta_rules", {}), {"meta_barter_relic": true})
	var feeds: Array = granted["result"].get("feeds", [])
	assert_true(feeds.has("meta_rule_recorded"), str(feeds))
	assert_false(feeds.any(func(feed): return str(feed).begins_with("relic_reward_blocked")))


func test_meta_rule_result_feed_appends_instead_of_overwrites() -> void:
	var resolver_script: Variant = load("res://scripts/domain/resolver.gd")
	var helper_script: Variant = load("res://scripts/domain/resolver_helpers.gd")
	var seeded := {"state": null, "result": {"ok": true, "feeds": ["prior_feed"]}}
	var merged: Variant = helper_script.call("append_result_feed", seeded, "meta_rule_recorded")
	assert_true(merged["result"]["feeds"].has("prior_feed"))
	assert_true(merged["result"]["feeds"].has("meta_rule_recorded"))

	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {"id": "meta_relic_append", "grade": "meta_rule", "hooks": [], "rarity": "epic"})
	var gained := Resolver.apply(RunState.new_run(101), {"type": "gain_relic", "relic_id": "meta_relic_append"}, tuned)
	assert_true(gained["result"]["ok"])
	assert_eq(gained["result"]["feeds"], ["meta_rule_recorded"])


func test_record_run_end_skips_relic_targets_missing_from_catalog_when_provided() -> void:
	var run := RunState.new_run(101)
	run.event_log.append({
		"action": "gain_relic",
		"reason": "relic_gained",
		"before": {},
		"after": {},
		"targets": ["ghost_relic_not_in_catalog"],
	})
	var meta: RefCounted = MetaProgress.new_empty()
	var filtered: RefCounted = meta.record_run_end(run, "dead", catalog)
	assert_false(filtered.relic_codex_ids.has("ghost_relic_not_in_catalog"))

	# Without the catalog argument the historical permissive scan stays intact.
	var unfiltered: RefCounted = meta.record_run_end(run, "dead")
	assert_true(unfiltered.relic_codex_ids.has("ghost_relic_not_in_catalog"))


func _add_test_relic(target: Dictionary, relic: Dictionary) -> void:
	target["relics"].append(relic)
	target["relic_by_id"][str(relic["id"])] = relic


func _add_test_barter_offer(target: Dictionary, offer_id: String, reward: Dictionary) -> void:
	target["shop_offer_by_id"][offer_id] = {
		"id": offer_id,
		"kind": "barter",
		"input_gu_ids": ["trail_eye_gu"],
		"rewards": [reward],
	}


func _run_with_gu(definition_ids: Array[String]) -> RunState:
	var run := RunState.new_run(101)
	for index in definition_ids.size():
		var instance_id := "gu_%03d" % (index + 2)
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": definition_ids[index],
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
	run.equipped_gu_ids = run.refined_gu_ids.duplicate()
	return run


func _count_events(state: RunState, reason: String) -> int:
	var total := 0
	for entry in state.event_log:
		if str(entry.get("reason", "")) == reason:
			total += 1
	return total
