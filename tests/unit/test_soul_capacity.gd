extends GutTest


const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_battle_ops_cap_equals_soul_value_with_floor_one() -> void:
	var run := RunState.new_run(101)
	# 9/1 batch: new runs start at soul=1 (run_state.gd); cap is 1:1 with soul.
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)
	run.cultivator["soul"] = 1
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)
	run.cultivator["soul"] = 0
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)
	run.cultivator["soul"] = 4
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 4)


func test_craft_cap_steps_follow_approved_table() -> void:
	assert_eq(SoulCapacityScript.craft_cap_for_soul(1), 2)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(2), 2)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(3), 3)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(4), 3)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(5), 4)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(9), 4)


func test_craft_cap_reads_cultivator_soul() -> void:
	var run := RunState.new_run(101)
	# 9/1 batch: new runs start at soul=1 -> craft cap tier 2.
	assert_eq(SoulCapacityScript.craft_cap(run), 2)
	run.cultivator["soul"] = 5
	assert_eq(SoulCapacityScript.craft_cap(run), 4)


func test_battle_dict_exposes_soul_ops_cap_for_preview_parity() -> void:
	var run := RunState.new_run(101)
	# 9/1 batch: the battle dict no longer snapshots soul_ops_cap; preview
	# capacity is derived live from SoulCapacity.battle_ops_cap(state) in
	# action_preview_service. Pin the derivable parity instead.
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_false(battle.has("soul_ops_cap"), "legacy snapshot key removed")
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)


# Removed (9/1 legacy clean): BattleResolver._backlash_for_activation was
# deleted when the V1 battle moved backlash onto enemy-intent soul_drain data
# (battle_command_facade passes it through); the stale round-trip assertion
# referenced a function that no longer exists and failed at parse time.


func test_free_mix_inputs_over_craft_cap_are_rejected() -> void:
	var run := _run_with_n_gu(3, "stone_shell_gu")
	run.cultivator["soul"] = 2
	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "free_mix",
		"input_instance_ids": ["gu_002", "gu_003", "gu_004"],
	}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_capacity_exceeded")


func test_free_mix_inputs_within_craft_cap_are_accepted() -> void:
	var run := _run_with_n_gu(2, "stone_shell_gu")
	run.cultivator["soul"] = 2
	var result := ResolverScript.apply(run, {
		"type": "refine_gu",
		"recipe_id": "free_mix",
		"input_instance_ids": ["gu_002", "gu_003"],
	}, catalog)
	assert_true(result["result"]["ok"])


func test_fixed_recipe_over_craft_cap_rejected_then_allowed_at_higher_soul() -> void:
	var run := RunState.new_run(101)
	_add_instance(run, "gu_002", "moonlight_gu")
	_add_instance(run, "gu_003", "small_light_gu")
	run.cultivator["soul"] = 2
	var blocked := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
	assert_false(blocked["result"]["ok"])
	assert_eq(blocked["result"]["reason"], "refinement_capacity_exceeded")
	run.cultivator["soul"] = 3
	var allowed := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
	assert_true(allowed["result"]["ok"])
	assert_eq(allowed["state"].event_log.back()["reason"], "refinement_succeeded")


func test_combine_recipe_over_craft_cap_rejected_before_input_validation() -> void:
	# Catalog-rebuild 2026-09: the authored bright_thread_risk (dead-gu) recipe
	# is gone; moon_glow_fixed anchors the same gate - at soul 2 the craft cap
	# is 2, so the capacity rejection must preempt the missing-input verdict.
	var run := RunState.new_run(101)
	_add_instance(run, "gu_002", "moonlight_gu")
	_add_instance(run, "gu_003", "small_light_gu")
	run.cultivator["soul"] = 2
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "moon_glow_fixed"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "refinement_capacity_exceeded")


func _run_with_n_gu(count: int, definition_id: String) -> RunState:
	var run := RunState.new_run(101)
	for index in range(count):
		_add_instance(run, "gu_%03d" % (index + 2), definition_id)
	return run


func _add_instance(run: RunState, instance_id: String, gu_id: String) -> void:
	run.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": gu_id,
		"state": "refined",
	}
	run.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	run.sync_legacy_gu_projections()