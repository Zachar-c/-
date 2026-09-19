extends GutTest


# Task 3 P0: backlash curse system (spec R9.1/R9.2/R9.3/R9.5/R9.6/R5.15/R2.3).
# Covers: data table + catalog validation, run-scoped curse registry,
# battle projection (draw_pollution / essence_surcharge / slot_seal),
# dual-channel damage, resolver entry points, save round-trip.

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_curse_table_ships_three_entries_covering_all_effect_kinds() -> void:
	assert_eq(catalog["curse_by_id"].size(), 3)
	assert_eq(str(catalog["curse_by_id"]["gu_erosion"]["effect"]), "draw_pollution")
	assert_eq(str(catalog["curse_by_id"]["essence_bloat"]["effect"]), "essence_surcharge")
	assert_eq(str(catalog["curse_by_id"]["meridian_seal"]["effect"]), "slot_seal")
	assert_true(ContentCatalog.validate(catalog).is_empty())


func test_curse_validation_rejects_unknown_effect_and_bad_numbers() -> void:
	var tuned := catalog.duplicate(true)
	tuned["curses"] = catalog["curses"].duplicate(true)
	tuned["curses"].append({
		"id": "fake_curse",
		"name_zh": "伪蛊",
		"effect": "explode_everything",
		"base_intensity": 1,
		"escalation_per_stage": 0,
		"removal_base_cost": 1,
	})
	var errors := ContentCatalog.validate(tuned)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("unknown effect"))

	tuned["curses"] = catalog["curses"].duplicate(true)
	var bad_number: Dictionary = catalog["curses"][0].duplicate(true)
	bad_number["base_intensity"] = "2"
	tuned["curses"].append(bad_number)
	errors = ContentCatalog.validate(tuned)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("must be a positive integer"))

	tuned["curses"] = catalog["curses"].duplicate(true)
	var missing_field: Dictionary = catalog["curses"][0].duplicate(true)
	missing_field.erase("removal_base_cost")
	tuned["curses"].append(missing_field)
	errors = ContentCatalog.validate(tuned)
	assert_true(errors.size() >= 1)


func test_validation_flags_recipe_and_event_references_to_missing_curses() -> void:
	var tuned := catalog.duplicate(true)
	tuned["refinement_recipes"] = catalog["refinement_recipes"].duplicate(true)
	for recipe in tuned["refinement_recipes"]:
		if str(recipe.get("id", "")) == "free_mix":
			recipe["outcomes"] = recipe["outcomes"].duplicate(true)
			recipe["outcomes"][0]["fail_curse_id"] = "no_such_curse"
	var errors := ContentCatalog.validate(tuned)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("fail_curse_id") or errors[0].contains("unknown curse"))

	tuned = catalog.duplicate(true)
	tuned["events"] = catalog["events"].duplicate(true)
	tuned["events"].append({"id": "bad_event", "curse_id": "ghost_curse"})
	errors = ContentCatalog.validate(tuned)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("unknown curse"))


func test_gain_curse_stores_layers_source_and_snapshot_event() -> void:
	var run := RunState.new_run(101)
	var first := CurseRegistry.gain_curse(run, "gu_erosion", "test:first")
	assert_eq(first.cultivator["statuses"]["gu_erosion"]["layers"], 1)
	assert_eq(str(first.cultivator["statuses"]["gu_erosion"]["source"]), "test:first")
	var second := CurseRegistry.gain_curse(first, "gu_erosion", "test:second")
	assert_eq(second.cultivator["statuses"]["gu_erosion"]["layers"], 2)
	assert_eq(str(second.cultivator["statuses"]["gu_erosion"]["source"]), "test:first")

	var gained_event: Dictionary = second.event_log.back()
	assert_eq(str(gained_event["action"]), "curse_gained")
	assert_eq(int(gained_event["before"]["layers"]), 1)
	assert_eq(int(gained_event["after"]["cultivator"]["statuses"]["gu_erosion"]["layers"]), 2)
	# Immutable state: original run object untouched.
	assert_true(run.cultivator["statuses"].is_empty())


func test_remove_curse_erases_entry_and_writes_snapshot_event() -> void:
	var run := RunState.new_run(101)
	var gained := CurseRegistry.gain_curse(run, "meridian_seal", "test")
	var removed := CurseRegistry.remove_curse(gained, "meridian_seal")
	assert_true(removed.cultivator["statuses"].is_empty())
	var removed_event: Dictionary = removed.event_log.back()
	assert_eq(str(removed_event["action"]), "curse_removed")
	assert_eq(int(removed_event["before"]["layers"]), 1)
	assert_true(removed_event["after"]["cultivator"]["statuses"].is_empty())


func test_intensity_scales_by_stage_index_and_layers() -> void:
	var curse: Dictionary = catalog["curse_by_id"]["gu_erosion"]
	var run := RunState.new_run(101)
	run.stage = "one"
	run = CurseRegistry.gain_curse(run, "gu_erosion", "test")
	assert_eq(CurseRegistry.intensity(run, curse), 1)

	run.stage = "four"
	assert_eq(CurseRegistry.intensity(run, curse), 4)

	run.stage = "three"
	var stacked := CurseRegistry.gain_curse(run, "gu_erosion", "test")
	assert_eq(CurseRegistry.intensity(stacked, curse), 6)

	# Unknown stage strings fall back to index zero (no escalation).
	stacked.stage = "nowhere"
	assert_eq(CurseRegistry.intensity(stacked, curse), 2)


func test_statuses_survive_save_round_trip() -> void:
	var run := RunState.new_run(101)
	var gained := CurseRegistry.gain_curse(run, "essence_bloat", "test:pact")
	gained = CurseRegistry.gain_curse(gained, "gu_erosion", "test:mix")
	var payload := SaveRepository.serialize_run(gained, [], [])
	var loaded: Dictionary = SaveRepository.load_run_from_data(payload)
	assert_false(loaded.is_empty())
	var statuses: Dictionary = loaded["state"].cultivator["statuses"]
	assert_eq(int(statuses["essence_bloat"]["layers"]), 1)
	assert_eq(str(statuses["essence_bloat"]["source"]), "test:pact")
	assert_eq(int(statuses["gu_erosion"]["layers"]), 1)
	assert_eq(CurseRegistry.intensity(loaded["state"], catalog["curse_by_id"]["gu_erosion"]), 1)


func test_gain_curse_command_validates_known_curse() -> void:
	var run := RunState.new_run(101)
	var bad := Resolver.apply(run, {"type": "gain_curse", "curse_id": "ghost", "source": "t"}, catalog)
	assert_false(bad["result"]["ok"])
	assert_eq(str(bad["result"]["reason"]), "unknown_curse")
	var good := Resolver.apply(run, {"type": "gain_curse", "curse_id": "gu_erosion", "source": "t"}, catalog)
	assert_true(good["result"]["ok"])
	assert_eq(int(good["state"].cultivator["statuses"]["gu_erosion"]["layers"]), 1)


func test_remove_curse_command_charges_price_and_rejects_shortfalls() -> void:
	var run := RunState.new_run(101)
	run = CurseRegistry.gain_curse(run, "meridian_seal", "test")
	var absent := Resolver.apply(run, {"type": "remove_curse", "curse_id": "essence_bloat"}, catalog)
	assert_false(absent["result"]["ok"])
	assert_eq(str(absent["result"]["reason"]), "curse_not_present")

	# Base removal cost 8, no notoriety or revisit uplift at a plain node.
	var poor := RunState.new_run(101)
	poor.stone = 7
	poor = CurseRegistry.gain_curse(poor, "meridian_seal", "test")
	var broke := Resolver.apply(poor, {"type": "remove_curse", "curse_id": "meridian_seal"}, catalog)
	assert_false(broke["result"]["ok"])
	assert_eq(str(broke["result"]["reason"]), "insufficient_stone")

	var solvent := RunState.new_run(101)
	solvent.stone = 12
	solvent = CurseRegistry.gain_curse(solvent, "meridian_seal", "test")
	var cleared := Resolver.apply(solvent, {"type": "remove_curse", "curse_id": "meridian_seal"}, catalog)
	assert_true(cleared["result"]["ok"])
	assert_eq(int(cleared["state"].stone), 4)
	assert_true(cleared["state"].cultivator["statuses"].is_empty())
	assert_eq(str(cleared["state"].event_log[-2]["reason"]), "curse_removal_paid")
	assert_eq(str(cleared["state"].event_log[-1]["action"]), "curse_removed")


func test_remove_curse_command_applies_notoriety_uplift_to_price() -> void:
	var run := RunState.new_run(101)
	run.stone = 12
	run.cultivator["notorious"] = 2
	run = CurseRegistry.gain_curse(run, "gu_erosion", "test")
	# price_for lifts 6 by 20% -> ceil(7.2) = 8; 12 stones cover it.
	var cleared := Resolver.apply(run, {"type": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_true(cleared["result"]["ok"])
	assert_eq(int(cleared["state"].stone), 4)

	run = RunState.new_run(101)
	run.stone = 7
	run.cultivator["notorious"] = 2
	run = CurseRegistry.gain_curse(run, "gu_erosion", "test")
	var broke := Resolver.apply(run, {"type": "remove_curse", "curse_id": "gu_erosion"}, catalog)
	assert_false(broke["result"]["ok"])
	assert_eq(str(broke["result"]["reason"]), "insufficient_stone")


# B1 bucket C (2026-09-06): the five battle-projection legs below were
# deleted as domain debt - draw_pollution/essence_surcharge/slot_seal ran
# only inside battle_resolver.gd via CurseRegistry battle projection; the
# V1 engine and facade consume no curse state (verified zero references), so
# the battle-time curse channels died with the legacy engine. Run-level curse
# facts that survive stay pinned above/below: table + validation, gain/remove
# commands, intensity scaling, save round-trip, free_mix failure attach, and
# the event-outcome attach.




func test_free_mix_failure_attaches_configured_curse() -> void:
	var tuned := catalog.duplicate(true)
	tuned["refinement_recipes"] = [{
		"id": "cursed_mix",
		"kind": "free_mix",
		"min_inputs": 2,
		"outcomes": [{
			"id": "destroyed",
			"weight": 1,
			"effect": "destroy_inputs",
			"event_reason": "free_mix_destroyed",
			"fail_curse_id": "gu_erosion",
		}],
	}]
	tuned["refinement_by_id"] = {"cursed_mix": tuned["refinement_recipes"][0]}
	var run := _run_with_gu(["trail_eye_gu", "thorn_whip_gu"])
	# 槽内含起始蛊共 3 件，自由合成需魂魄并发上限 ≥3。
	run.cultivator["soul"] = 4

	var mixed := Resolver.apply(run, {"type": "refine_gu", "recipe_id": "cursed_mix"}, tuned)
	assert_true(mixed["result"]["ok"])
	assert_eq(int(mixed["state"].cultivator["statuses"]["gu_erosion"]["layers"]), 1)
	assert_eq(str(mixed["state"].cultivator["statuses"]["gu_erosion"]["source"]), "free_mix_failure:destroyed")


func test_event_outcome_option_attaches_curse_on_accept() -> void:
	var run := RunState.new_run(101)
	var accepted := Resolver.apply(run, {"type": "accept_event", "event_id": "gu_rot_pact"}, catalog)
	assert_true(accepted["result"]["ok"])
	assert_eq(int(accepted["state"].cultivator["statuses"]["essence_bloat"]["layers"]), 1)
	assert_eq(str(accepted["state"].cultivator["statuses"]["essence_bloat"]["source"]), "event:gu_rot_pact")
	assert_eq(int(accepted["state"].health), 99, "契约事件代价 -1")


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
