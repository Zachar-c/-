extends GutTest


const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_battle_ops_cap_equals_soul_value_with_floor_one() -> void:
	var run := RunState.new_run(101)
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 4)
	run.cultivator["soul"] = 1
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)
	run.cultivator["soul"] = 0
	assert_eq(SoulCapacityScript.battle_ops_cap(run), 1)


func test_craft_cap_steps_follow_approved_table() -> void:
	assert_eq(SoulCapacityScript.craft_cap_for_soul(1), 2)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(2), 2)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(3), 3)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(4), 3)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(5), 4)
	assert_eq(SoulCapacityScript.craft_cap_for_soul(9), 4)


func test_craft_cap_reads_cultivator_soul() -> void:
	var run := RunState.new_run(101)
	assert_eq(SoulCapacityScript.craft_cap(run), 3)
	run.cultivator["soul"] = 5
	assert_eq(SoulCapacityScript.craft_cap(run), 4)


func test_battle_dict_exposes_soul_ops_cap_for_preview_parity() -> void:
	var run := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	assert_eq(int(battle["soul_ops_cap"]), 4)


func test_backlash_over_limit_uses_soul_value_as_cap() -> void:
	var run := RunState.new_run(101)
	run.cultivator["soul"] = 4
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, run, catalog)
	battle["active_gu_instance_ids"] = ["gu_001", "gu_002", "gu_003", "gu_004", "gu_005"]
	var definition: Dictionary = catalog["gu_by_id"]["small_light_gu"]
	var backlash := BattleResolver._backlash_for_activation(
		battle, run, definition, {"source_gu_instance_ids": []}, catalog
	)
	assert_eq(int(backlash["after"]["cultivator"]["soul"]), 3)
	assert_eq(backlash["reason"], "battle_soul_backlash")


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
	var tuned := catalog.duplicate(true)
	var recipe: Dictionary = tuned["refinement_by_id"]["bright_thread_risk"].duplicate(true)
	var inputs: Array = recipe.get("input_gu_ids", []).duplicate()
	inputs.append("stone_shell_gu")
	recipe["input_gu_ids"] = inputs
	tuned["refinement_by_id"]["bright_thread_risk"] = recipe
	for candidate in tuned["refinement_recipes"]:
		if candidate["id"] == "bright_thread_risk":
			candidate["input_gu_ids"] = inputs
	var run := RunState.new_run(101)
	run.cultivator["soul"] = 2
	var result := ResolverScript.apply(run, {"type": "refine_gu", "recipe_id": "bright_thread_risk"}, tuned)
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