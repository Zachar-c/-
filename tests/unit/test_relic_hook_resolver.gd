extends GutTest


const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_no_relics_makes_battle_and_feeding_noops() -> void:
	var run := RunState.new_run(101)
	assert_eq(RelicHookResolverScript.feeding_extra(run, catalog), 0)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	# Opening fairness: every battle starts with a BASE first-turn grant of 1;
	# with no relics the hooks must add nothing on top of that base.
	assert_eq(int(battle.get("first_turn_energy", 0)), 1)
	assert_eq(int(battle.get("action_energy", 0)), 1)


func test_real_relics_pass_catalog_validation() -> void:
	assert_eq(ContentCatalog.validate(catalog), [])


func test_hungry_vine_token_adds_feeding_pressure_through_query() -> void:
	var run := RunState.new_run(101)
	run.relic_ids = ["hungry_vine_token"]
	assert_eq(RelicHookResolverScript.feeding_extra(run, catalog), 1)
	assert_eq(int(run.estimate_feeding_materials(catalog)["feed_points"]), 2)


func test_battle_start_grant_first_turn_energy_sets_real_energy_pool() -> void:
	var run := RunState.new_run(101)
	run.relic_ids = ["jade_cicada_shell"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_eq(int(battle["first_turn_energy"]), 2, "relic grant stacks on the base 1")
	assert_eq(int(battle["action_energy"]), 2)


func test_first_turn_energy_lets_player_spend_one_card_beyond_essence_then_blocks() -> void:
	# With the base grant this scenario no longer needs a relic: an essence-0
	# player can act exactly once on turn 1, then costs need real essence.
	var run := RunState.new_run(101)
	run.essence = 0
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var first := BattleResolver.take_turn(battle, {"type": "use_gu", "gu_id": "small_light_gu"}, run, catalog)
	assert_eq(first["result"], "ongoing")
	assert_eq(int(first["state"].essence), 0)
	assert_eq(int(first["battle"]["action_energy"]), 0)
	var second := BattleResolver.take_turn(first["battle"], {"type": "use_gu", "gu_id": "small_light_gu"}, first["state"], catalog)
	assert_true(second["feeds"].has("insufficient_essence"))
	assert_eq(int(second["state"].essence), 0)


func test_end_turn_clears_action_energy_after_first_turn() -> void:
	var run := RunState.new_run(101)
	run.relic_ids = ["jade_cicada_shell"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var turn := BattleResolver.take_turn(battle, {"type": "end_turn"}, run, catalog)
	assert_eq(int(turn["battle"]["action_energy"]), 0)


func test_draw_extra_card_hook_increases_hand_on_draw() -> void:
	var run := RunState.new_run(101)
	_add_test_relic(catalog, {
		"id": "test_draw_relic",
		"hooks": [{"trigger": "on_draw_card", "effect": {"kind": "draw_extra_card", "amount": 1}}],
	})
	_add_refined_instance(run, "gu_002", "thorn_whip_gu")
	run.relic_ids = ["test_draw_relic"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_eq(battle["hand"].size(), 3)
	assert_gt(int(battle["hand_version"]), 0)


func test_play_card_gain_essence_hook_refunds_through_event_log() -> void:
	var run := RunState.new_run(101)
	_add_test_relic(catalog, {
		"id": "test_play_relic",
		"hooks": [{"trigger": "on_play_card", "effect": {"kind": "gain_essence_on_play", "amount": 2}}],
	})
	run.relic_ids = ["test_play_relic"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	var card_id := "battle.%s.%s" % [str(battle["battle_id"]), str(battle["hand"][0]["instance_id"])]
	var turn := BattleResolver.apply_action_card(
		battle,
		run,
		{"action_id": card_id, "state_version": int(battle["hand_version"])},
		catalog
	)
	assert_eq(int(turn["state"].essence), 5, "cost 1 is paid from the base energy first, so essence 3 stays and the +2 refund lands")
	assert_eq(str(turn["state"].event_log.back()["reason"]), "relic_gain_essence_on_play")


func test_take_damage_reduction_prevents_harm_and_ignores_final_blow() -> void:
	var run := RunState.new_run(101)
	_add_test_relic(catalog, {
		"id": "test_armor_relic",
		"hooks": [{"trigger": "on_take_damage", "effect": {"kind": "reduce_incoming_damage", "amount": 5}}],
	})
	run.relic_ids = ["test_armor_relic"]
	var battle := BattleResolver.start({"enemy_kind": "neutral_stone_wanderer"}, run, catalog)
	var before := run.health
	var turn := BattleResolver.apply_action_card(
		battle,
		run,
		{"action_id": "battle.end_turn", "state_version": int(battle["hand_version"])},
		catalog
	)
	assert_eq(int(turn["state"].health), before)
	assert_true(turn["battle"]["final_blow"].is_empty())


func test_multiple_relics_accumulate_in_stable_relic_order() -> void:
	var run := RunState.new_run(101)
	_add_test_relic(catalog, {
		"id": "aaa_relic",
		"hooks": [{"trigger": "on_battle_start", "effect": {"kind": "grant_first_turn_energy", "amount": 1}}],
	})
	_add_test_relic(catalog, {
		"id": "zzz_relic",
		"hooks": [{"trigger": "on_battle_start", "effect": {"kind": "grant_first_turn_energy", "amount": 1}}],
	})
	run.relic_ids = ["zzz_relic", "aaa_relic"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_eq(int(battle["first_turn_energy"]), 3, "base 1 + two stacked relic grants")


func test_validate_rejects_unknown_trigger_and_effect_kind() -> void:
	var bad := catalog.duplicate(true)
	bad["relics"] = [{
		"id": "bad_relic",
		"hooks": [
			{"trigger": "on_unknown", "effect": {"kind": "grant_first_turn_energy", "amount": 1}},
			{"trigger": "on_battle_start", "effect": {"kind": "explode_universe", "amount": 1}},
		],
	}]
	bad["relic_by_id"] = {"bad_relic": bad["relics"][0]}
	var errors := ContentCatalog.validate(bad)
	var joined := "\n".join(errors)
	assert_true(joined.contains("unknown trigger on_unknown"), joined)
	assert_true(joined.contains("unknown effect kind explode_universe"), joined)


func test_validate_rejects_non_integer_effect_amount() -> void:
	var bad := catalog.duplicate(true)
	bad["relics"] = [{
		"id": "bad_relic",
		"hooks": [{"trigger": "on_battle_start", "effect": {"kind": "grant_first_turn_energy", "amount": "one"}}],
	}]
	bad["relic_by_id"] = {"bad_relic": bad["relics"][0]}
	var errors := ContentCatalog.validate(bad)
	assert_true("\n".join(errors).contains("non-negative integer"), "\n".join(errors))


func _add_test_relic(target: Dictionary, relic: Dictionary) -> void:
	target["relics"].append(relic)
	target["relic_by_id"][str(relic["id"])] = relic


func _add_refined_instance(run: RunState, instance_id: String, gu_id: String) -> void:
	run.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": gu_id,
		"state": "refined",
	}
	run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()
