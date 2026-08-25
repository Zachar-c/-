extends GutTest


# Task 4 P0: imprint/relic-hook expansion (spec R4.8/R4.9/R11.7).
# Covers: on_backlash_gained / on_battle_end triggers, convert_backlash_to_draw /
# reduce_curse_intensity / grant_stone_on_battle_end effects, imprint capacity
# slots (R4.9), meta-grade cap <=2 per run (R4.8), meta_rules save round-trip,
# relic codex unlock at run end (R11.7), catalog validation of grade +
# imprint_capacity.

const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_backlash_gained_queues_next_turn_draw_once_per_curse_layer() -> void:
	var tuned := _zero_enemy_damage(catalog.duplicate(true))
	_add_test_relic(tuned, {
		"id": "test_backlash_relic",
		"hooks": [{"trigger": "on_backlash_gained", "effect": {"kind": "convert_backlash_to_draw", "amount": 1}}],
	})
	var run := _run_with_gu(["small_light_gu", "thorn_whip_gu", "stone_shell_gu", "mist_step_gu"])
	run = CurseRegistry.gain_curse(run, "essence_bloat", "test:a")
	run = CurseRegistry.gain_curse(run, "essence_bloat", "test:b")
	run.relic_ids = ["test_backlash_relic"]

	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned)
	assert_eq(int(battle.get("pending_extra_draws", 0)), 2)

	var first := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": int(battle["hand_version"]),
	}, tuned)
	assert_eq(first["battle"]["hand"].size(), 4)
	assert_eq(int(first["battle"].get("pending_extra_draws", 0)), 0)
	assert_true(_log_has(first["battle"], "relic_backlash_draw"))

	var second := BattleResolver.apply_action_card(first["battle"], first["state"], {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": int(first["battle"]["hand_version"]),
	}, tuned)
	assert_eq(second["battle"]["hand"].size(), 2)
	assert_eq(_log_count(second["battle"], "relic_backlash_draw"), 1)


func test_apply_backlash_gained_reports_conversion_feed_and_stacks_pending() -> void:
	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {
		"id": "test_backlash_relic",
		"hooks": [{"trigger": "on_backlash_gained", "effect": {"kind": "convert_backlash_to_draw", "amount": 1}}],
	})
	var run := RunState.new_run(101)
	run.relic_ids = ["test_backlash_relic"]
	var first := RelicHookResolverScript.apply_backlash_gained({"curses": []}, run, tuned, 1)
	assert_true(first["feeds"].has("relic_backlash_converted"))
	assert_eq(int(first["battle"]["pending_extra_draws"]), 1)
	var second := RelicHookResolverScript.apply_backlash_gained(first["battle"], run, tuned, 1)
	assert_eq(int(second["battle"]["pending_extra_draws"]), 2)


func test_battle_end_stone_grant_fires_once_on_retreat_with_feed() -> void:
	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {
		"id": "test_bounty_relic",
		"hooks": [{"trigger": "on_battle_end", "effect": {"kind": "grant_stone_on_battle_end", "amount": 2}}],
	})
	var run := RunState.new_run(101)
	run.stone = 12
	run.relic_ids = ["test_bounty_relic"]
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound", "terrain": "path"}, run, tuned)
	var retreated := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.retreat",
		"state_version": int(battle["hand_version"]),
	}, tuned)
	assert_true(retreated["accepted"])
	assert_eq(str(retreated["result"]), "retreated")
	assert_true(retreated["feeds"].has("relic_battle_stone"))
	assert_eq(int(retreated["state"].stone), 12)
	assert_eq(str(retreated["state"].event_log.back()["reason"]), "relic_stone_on_battle_end")
	assert_eq(_count_events(retreated["state"], "relic_stone_on_battle_end"), 1)


func test_battle_end_stone_grant_fires_exactly_once_on_death_path() -> void:
	var tuned := _zero_enemy_damage(catalog.duplicate(true))
	_add_test_relic(tuned, {
		"id": "test_bounty_relic",
		"hooks": [{"trigger": "on_battle_end", "effect": {"kind": "grant_stone_on_battle_end", "amount": 3}}],
	})
	var run := _run_with_gu(["small_light_gu"])
	run.health = 1
	run.relic_ids = ["test_bounty_relic"]
	run = CurseRegistry.gain_curse(run, "gu_erosion", "test")
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned)
	var ended := BattleResolver.apply_action_card(battle, run, {
		"type": "action_card",
		"action_id": "battle.end_turn",
		"state_version": int(battle["hand_version"]),
	}, tuned)
	assert_eq(str(ended["result"]), "death")
	assert_true(ended["feeds"].has("player_dead"))
	assert_true(ended["feeds"].has("relic_battle_stone"))
	assert_eq(str(ended["state"].terminal_state), "dead")
	assert_eq(int(ended["state"].stone), 15)
	assert_eq(_count_events(ended["state"], "relic_stone_on_battle_end"), 1)


func test_reduce_curse_intensity_floors_projection_at_battle_start_only() -> void:
	var tuned := catalog.duplicate(true)
	_add_test_relic(tuned, {
		"id": "test_calming_relic",
		"hooks": [{"trigger": "on_battle_start", "effect": {"kind": "reduce_curse_intensity", "amount": 3}}],
	})
	var run := RunState.new_run(101)
	run.relic_ids = ["test_calming_relic"]
	run = CurseRegistry.gain_curse(run, "meridian_seal", "test:a")
	run = CurseRegistry.gain_curse(run, "meridian_seal", "test:b")

	var direct := RelicHookResolverScript.apply_battle_start(
		{"curses": [{"id": "meridian_seal", "effect": "slot_seal", "intensity": 2}], "log": []},
		run,
		tuned
	)
	assert_eq(int(direct["battle"]["curses"][0]["intensity"]), 0)
	assert_true(direct["feeds"].has("relic_curse_reduced"))

	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, tuned)
	assert_eq(int(battle["curses"][0]["intensity"]), 0)
	assert_eq(CurseRegistry.intensity(run, tuned["curse_by_id"]["meridian_seal"]), 2)


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
	missing_capacity["deck"] = {"capacity": 12}
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


func _zero_enemy_damage(tuned: Dictionary) -> Dictionary:
	tuned["enemy_by_id"]["ridge_hound"]["intent"]["damage"] = 0
	return tuned


func _add_test_relic(target: Dictionary, relic: Dictionary) -> void:
	target["relics"].append(relic)
	target["relic_by_id"][str(relic["id"])] = relic


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


func _log_has(battle: Dictionary, log_id: String) -> bool:
	return _log_count(battle, log_id) > 0


func _log_count(battle: Dictionary, log_id: String) -> int:
	var total := 0
	for entry in battle.get("log", []):
		if str(entry.get("id", "")) == log_id:
			total += 1
	return total


func _count_events(state: RunState, reason: String) -> int:
	var total := 0
	for entry in state.event_log:
		if str(entry.get("reason", "")) == reason:
			total += 1
	return total
