extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_duration_effect_releases_its_source_gu_after_end_turn_expiry() -> void:
	var run := _run_with_gu(["stone_shell_gu"])
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var guarded := BattleResolver.apply_action_card(battle, run, _command_for_definition(battle, "stone_guard"), catalog)

	assert_true(guarded["accepted"])
	assert_eq(guarded["battle"]["active_effect_registry"].size(), 1)
	assert_eq(guarded["battle"]["active_gu_instance_ids"], ["gu_002"])

	var expired := BattleResolver.apply_action_card(guarded["battle"], guarded["state"], {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": guarded["battle"]["hand_version"],
	}, catalog)

	assert_true(expired["accepted"])
	assert_true(expired["battle"]["active_effect_registry"].is_empty())
	assert_true(expired["battle"]["active_gu_instance_ids"].is_empty())


func test_soul_control_overflow_applies_backlash_but_keeps_duration_effect_active() -> void:
	var run := _run_with_gu(["stone_shell_gu"])
	run.cultivator["soul_control_limit"] = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var result := BattleResolver.apply_action_card(battle, run, _command_for_definition(battle, "stone_guard"), catalog)

	assert_true(result["accepted"])
	assert_lt(int(result["state"].cultivator["soul"]), 4)
	assert_eq(result["battle"]["active_gu_instance_ids"], ["gu_002"])
	assert_true(result["feeds"].has("soul_backlash"))


func test_low_rank_cultivator_using_higher_rank_gu_applies_defined_backlash_factors() -> void:
	var tuned_catalog := catalog.duplicate(true)
	tuned_catalog["gu_by_id"]["small_light_gu"]["rank"] = 2
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned_catalog)
	var result := BattleResolver.apply_action_card(battle, run, _command_for_definition(battle, "light_probe"), tuned_catalog)

	assert_true(result["accepted"])
	assert_eq(result["state"].health, 4)
	assert_eq(result["state"].cultivator["soul"], 1)
	assert_true(result["feeds"].has("rank_backlash"))


func test_kill_move_sequence_tracks_pending_sources_then_resolves_in_order() -> void:
	var run := _run_with_gu(["moonlight_gu"])
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var first := BattleResolver.apply_action_card(battle, run, _command_for_definition(battle, "moonlight_strike"), catalog)

	assert_true(first["accepted"])
	assert_eq(first["battle"]["pending_kill_move_state"]["move_id"], "moonlight_return")
	assert_eq(first["battle"]["pending_kill_move_state"]["next_sequence_index"], 1)

	var completed := BattleResolver.apply_action_card(first["battle"], first["state"], _command_for_definition(first["battle"], "light_probe"), catalog)

	assert_true(completed["accepted"])
	assert_true(completed["battle"]["pending_kill_move_state"].is_empty())
	assert_true(completed["battle"]["flags"].has("kill_move_moonlight_return"))


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
	return run


func _command_for_definition(battle: Dictionary, definition_id: String) -> Dictionary:
	for instance in battle["hand"]:
		if str(instance["definition_id"]) == definition_id:
			return {
				"type": "action_card",
				"action_id": "battle.%s.%s" % [battle["battle_id"], instance["instance_id"]],
				"state_version": battle["hand_version"],
			}
	push_error("Missing card definition in hand: %s" % definition_id)
	return {}
