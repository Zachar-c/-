extends GutTest


# Task 5 P0: dual removal channels (spec R4.3/R6.8/R8.1, section 16.15).
# Black-market paid services share one limit/escalation accounting family;
# rest-node removal is free but consumes the visit; cursed gu refuse direct
# drops and attach a backlash curse instead.


const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_remove_card_destroys_instance_charges_and_counts() -> void:
	var run := _run_with_instances([])
	run.stone = 200
	var result := ResolverScript.apply(run, {"type": "remove_card", "instance_id": "gu_001"}, catalog)

	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(str(next.gu_instances["gu_001"]["state"]), "dead")
	assert_true(next.cave_aperture["stored_gu_instance_ids"].is_empty())
	assert_eq(int(next.stone), 80)
	assert_eq(str(next.node_flags.get("svc_used_remove_card", "")), "1")
	assert_eq(str(next.event_log.back()["action"]), "svc_remove_card")
	assert_eq(str(next.event_log.back()["reason"]), "gu_removed_by_service")


func test_remove_card_price_escalates_then_hits_limit() -> void:
	var run := _run_with_instances(["thorn_whip_gu", "venom_thread_gu"])
	run.stone = 1000
	var first := ResolverScript.apply(run, {"type": "remove_card", "instance_id": "gu_001"}, catalog)
	assert_true(first["result"]["ok"])
	assert_eq(int(first["state"].stone), 880)

	var second := ResolverScript.apply(first["state"], {"type": "remove_card", "instance_id": "gu_002"}, catalog)
	assert_true(second["result"]["ok"])
	# Second use lifts 120 by 25% -> 150.
	assert_eq(int(second["state"].stone), 730)
	assert_eq(str(second["state"].node_flags.get("svc_used_remove_card", "")), "2")

	var third := ResolverScript.apply(second["state"], {"type": "remove_card", "instance_id": "gu_003"}, catalog)
	assert_false(third["result"]["ok"])
	assert_eq(str(third["result"]["reason"]), "service_limit_exceeded")
	assert_eq(int(third["state"].stone), 730)
	assert_eq(str(third["state"].node_flags.get("svc_used_remove_card", "")), "2")


func test_remove_card_rejects_unknown_instance_and_short_stone() -> void:
	var run := _run_with_instances([])
	run.stone = 119
	var unknown := ResolverScript.apply(run, {"type": "remove_card", "instance_id": "gu_999"}, catalog)
	assert_false(unknown["result"]["ok"])
	assert_eq(str(unknown["result"]["reason"]), "gu_instance_unavailable")

	var broke := ResolverScript.apply(run, {"type": "remove_card", "instance_id": "gu_001"}, catalog)
	assert_false(broke["result"]["ok"])
	assert_eq(str(broke["result"]["reason"]), "insufficient_stone")
	assert_eq(int(broke["state"].stone), 119)
	assert_false(broke["state"].node_flags.has("svc_used_remove_card"))


func test_remove_imprint_removes_non_meta_relic_and_cleans_stale_meta_rules() -> void:
	var run := _gained_relic("hungry_vine_token")
	run.stone = 300
	run.meta_rules["hungry_vine_token"] = true

	var result := ResolverScript.apply(run, {"type": "remove_imprint", "relic_id": "hungry_vine_token"}, catalog)
	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(next.relic_ids, [] as Array[String])
	assert_false(next.meta_rules.has("hungry_vine_token"))
	assert_eq(int(next.stone), 150)
	assert_eq(str(next.node_flags.get("svc_used_remove_imprint", "")), "1")
	assert_eq(str(next.event_log.back()["action"]), "svc_remove_imprint")


func test_remove_imprint_rejects_meta_grade_and_unowned() -> void:
	var run := _gained_relic("jade_cicada_shell")
	run.stone = 500
	var meta := ResolverScript.apply(run, {"type": "remove_imprint", "relic_id": "jade_cicada_shell"}, catalog)
	assert_false(meta["result"]["ok"])
	assert_eq(str(meta["result"]["reason"]), "meta_rule_not_removable")
	assert_true(meta["state"].relic_ids.has("jade_cicada_shell"))
	assert_eq(int(meta["state"].stone), 500)

	var unowned := ResolverScript.apply(run, {"type": "remove_imprint", "relic_id": "hungry_vine_token"}, catalog)
	assert_false(unowned["result"]["ok"])
	assert_eq(str(unowned["result"]["reason"]), "relic_not_owned")


func test_remove_curse_shares_service_pool_and_escalates() -> void:
	var run := RunState.new_run(101)
	run.stone = 500
	run = CurseRegistry.gain_curse(run, "meridian_seal", "test")
	var first := ResolverScript.apply(run, {"type": "remove_curse", "curse_id": "meridian_seal"}, catalog)
	assert_true(first["result"]["ok"])
	assert_eq(int(first["state"].stone), 492)
	assert_eq(str(first["state"].node_flags.get("svc_used_remove_curse", "")), "1")
	assert_eq(str(first["state"].event_log[-2]["action"]), "svc_remove_curse")
	assert_eq(str(first["state"].event_log[-2]["reason"]), "curse_removal_paid")
	assert_eq(str(first["state"].event_log[-1]["action"]), "curse_removed")

	var second_run := CurseRegistry.gain_curse(first["state"], "essence_bloat", "test")
	var second := ResolverScript.apply(second_run, {"type": "remove_curse", "curse_id": "essence_bloat"}, catalog)
	assert_true(second["result"]["ok"])
	# Second use lifts base 5 by 25% -> ceil(6.25) = 7.
	assert_eq(int(second["state"].stone), 485)
	assert_eq(str(second["state"].node_flags.get("svc_used_remove_curse", "")), "2")

	var third_run := CurseRegistry.gain_curse(second["state"], "gu_erosion", "test")
	var third := ResolverScript.apply(third_run, {"type": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_false(third["result"]["ok"])
	assert_eq(str(third["result"]["reason"]), "service_limit_exceeded")


func test_rest_mode_removes_gu_free_and_consumes_visit() -> void:
	var run := _run_with_instances([])
	run.health = 4
	run.essence = 2
	run.current_node_id = "rest_hollow"
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "remove_card", "instance_id": "gu_001"}, catalog)

	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(str(next.gu_instances["gu_001"]["state"]), "dead")
	assert_eq(int(next.stone), run.stone)
	assert_eq(int(next.health), 4)
	assert_eq(int(next.essence), 2)
	assert_false(next.node_flags.has("svc_used_remove_card"))
	assert_eq(str(next.node_flags.get("rest_hollow", "")), "used")
	assert_eq(str(next.node_flags.get("rest_mode_used", "")), "true")
	assert_eq(str(next.event_log[-1]["reason"]), "rest_removed_gu")

	var second_mode := ResolverScript.apply(next, {"type": "rest", "mode": "remove_card", "instance_id": "gu_001"}, catalog)
	assert_false(second_mode["result"]["ok"])
	assert_eq(str(second_mode["result"]["reason"]), "rest_mode_already_used")

	var heal_after := ResolverScript.apply(next, {"type": "rest"}, catalog)
	assert_false(heal_after["result"]["ok"])
	assert_eq(str(heal_after["result"]["reason"]), "rest_already_used")


func test_rest_mode_removes_imprint_free() -> void:
	var run := _gained_relic("hungry_vine_token")
	run.current_node_id = "rest_hollow"
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "remove_imprint", "relic_id": "hungry_vine_token"}, catalog)

	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_eq(next.relic_ids, [] as Array[String])
	assert_eq(int(next.stone), run.stone)
	assert_false(next.node_flags.has("svc_used_remove_imprint"))
	assert_eq(str(next.event_log[-1]["reason"]), "rest_removed_imprint")


func test_rest_mode_removes_curse_free() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_hollow"
	run = CurseRegistry.gain_curse(run, "gu_erosion", "test")
	var result := ResolverScript.apply(run, {"type": "rest", "mode": "remove_curse", "curse_id": "gu_erosion"}, catalog)

	assert_true(result["result"]["ok"])
	var next: RunState = result["state"]
	assert_true(next.cultivator["statuses"].is_empty())
	assert_eq(int(next.stone), run.stone)
	assert_false(next.node_flags.has("svc_used_remove_curse"))


func test_rest_mode_validates_targets_before_consuming_visit() -> void:
	var run := RunState.new_run(101)
	run.current_node_id = "rest_hollow"
	var missing_curse := ResolverScript.apply(run, {"type": "rest", "mode": "remove_curse", "curse_id": "essence_bloat"}, catalog)
	assert_false(missing_curse["result"]["ok"])
	assert_eq(str(missing_curse["result"]["reason"]), "curse_not_present")
	assert_eq(str(missing_curse["state"].node_flags.get("rest_hollow", "")), "")

	var bad_mode := ResolverScript.apply(run, {"type": "rest", "mode": "teleport"}, catalog)
	assert_false(bad_mode["result"]["ok"])
	assert_eq(str(bad_mode["result"]["reason"]), "unsupported_rest_mode")


func test_cursed_gu_blocks_destroy_and_gain_backlash_curse() -> void:
	var run := _run_with_instances(["blood_farewell_gu"])
	var result := ResolverScript.apply(run, {"type": "destroy_gu", "instance_id": "gu_002"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "cursed_gu_not_directly_droppable")
	var next: RunState = result["state"]
	assert_eq(str(next.gu_instances["gu_002"]["state"]), "refined")
	assert_eq(int(CurseRegistry.layers_of(next, "gu_erosion")), 1)
	assert_eq(str(next.cultivator["statuses"]["gu_erosion"]["source"]), "forced_drop")
	assert_eq(str(next.event_log.back()["action"]), "curse_gained")


func test_cursed_gu_blocks_paid_removal_without_charge_or_count() -> void:
	var run := _run_with_instances(["blood_farewell_gu"])
	run.stone = 500
	var result := ResolverScript.apply(run, {"type": "remove_card", "instance_id": "gu_002"}, catalog)

	assert_false(result["result"]["ok"])
	assert_eq(str(result["result"]["reason"]), "cursed_gu_not_directly_droppable")
	var next: RunState = result["state"]
	assert_eq(int(next.stone), 500)
	assert_eq(str(next.gu_instances["gu_002"]["state"]), "refined")
	assert_false(next.node_flags.has("svc_used_remove_card"))
	assert_eq(int(CurseRegistry.layers_of(next, "gu_erosion")), 1)


func test_catalog_validates_service_limits_and_can_direct_drop() -> void:
	assert_eq(ContentCatalog.validate(catalog), [])

	var bad_limit := ContentCatalog.load_all()
	bad_limit["deck"]["service_limits"]["remove_card"] = 0
	assert_eq(ContentCatalog.validate(bad_limit).size(), 1)

	var missing_limit := ContentCatalog.load_all()
	missing_limit["deck"]["service_limits"].erase("remove_imprint")
	assert_eq(ContentCatalog.validate(missing_limit).size(), 1)

	var bad_flag := ContentCatalog.load_all()
	bad_flag["gu"][0]["can_direct_drop"] = "yes"
	assert_eq(ContentCatalog.validate(bad_flag).size(), 1)


func test_display_text_distinguishes_removal_from_pool_exclusion() -> void:
	assert_gt(DisplayText.REMOVAL_LABEL.length(), 0)
	assert_gt(DisplayText.POOL_EXCLUSION_LABEL.length(), 0)
	assert_ne(DisplayText.REMOVAL_LABEL, DisplayText.POOL_EXCLUSION_LABEL)
	assert_true(DisplayText.REMOVAL_LABEL.begins_with("移除"))
	assert_true(DisplayText.POOL_EXCLUSION_LABEL.begins_with("池排除"))


func _run_with_instances(extra_definitions: Array) -> RunState:
	var run := RunState.new_run(101)
	var next_index := 2
	for definition_id in extra_definitions:
		var instance_id := "gu_%03d" % next_index
		run.gu_instances[instance_id] = {
			"instance_id": instance_id,
			"definition_id": str(definition_id),
			"state": "refined",
		}
		run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
		next_index += 1
	run.sync_legacy_gu_projections()
	return run


func _gained_relic(relic_id: String) -> RunState:
	var run := RunState.new_run(101)
	return ResolverScript.apply(run, {"type": "gain_relic", "relic_id": relic_id}, catalog)["state"]
