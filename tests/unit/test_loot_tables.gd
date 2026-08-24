extends "res://addons/gut/test.gd"


# B2 loot loop: victory drops (materials/gu), boss scavenge unlocks the
# recipe into the global codex, materials can be sold and fed into refining.
# All rolls are seeded and reproducible from the run seed.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const LootResolverScript := preload("res://scripts/domain/loot_resolver.gd")
const ResolverScript := preload("res://scripts/domain/resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_real_loot_tables_pass_catalog_validation() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog())
	assert_eq(errors, [])


func test_common_victory_always_grants_one_material() -> void:
	var battle := {"enemy_kind": "ridge_hound"}
	var one: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	var two: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	assert_eq(one["loot"].get("material_ids", []).size(), 1)
	assert_eq(str(one["loot"].get("gu_id", "")), "")
	assert_eq_deep(one["loot"], two["loot"])


func test_same_seed_same_position_yields_identical_loot() -> void:
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var one: Dictionary = LootResolverScript.settle_victory(battle, make_state(424242), catalog())
	var two: Dictionary = LootResolverScript.settle_victory(battle, make_state(424242), catalog())
	assert_eq_deep(one["loot"], two["loot"])


func test_elite_loot_grants_material_and_may_be_gu() -> void:
	var battle := {"enemy_kind": "ridge_elite_scout"}
	var table: Dictionary = catalog().get("loot_tables", {}).get("loot", {}).get("elite", {})
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	var loot: Dictionary = rolled["loot"]
	assert_eq(loot.get("material_ids", []).size(), int(table.get("material_count", 0)))
	var gu_id := str(loot.get("gu_id", ""))
	if not gu_id.is_empty():
		assert_true((table.get("gu_pool", []) as Array).has(gu_id))


func test_boss_loot_grants_two_materials_no_gu() -> void:
	var battle := {"enemy_kind": "miasma_vein_lord"}
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, make_state(), catalog())
	var loot: Dictionary = rolled["loot"]
	assert_eq(loot.get("material_ids", []).size(), 2)
	assert_eq(str(loot.get("gu_id", "")), "")


func test_loot_materials_are_added_to_state_and_logged() -> void:
	var battle := {"enemy_kind": "ridge_hound"}
	var before: RunState = make_state()
	var rolled: Dictionary = LootResolverScript.settle_victory(battle, before, catalog())
	var after: RunState = rolled["state"]
	var gained: Array = rolled["loot"].get("material_ids", [])
	assert_true(int(after.materials.get(str(gained[0]), 0)) > 0)
	assert_eq(after.event_log.size(), before.event_log.size() + 1)


func test_scavenge_requires_boss_defeated() -> void:
	var resolved: Dictionary = ResolverScript.apply(
		make_state(),
		{"type": "scavenge", "node_id": "final_boss_stand"},
		catalog()
	)
	assert_false(bool(resolved["result"].get("ok", false)))
	assert_eq(str(resolved["result"].get("reason", "")), "boss_undefeated")


func test_scavenge_unlocks_recipe_in_global_codex() -> void:
	var state := make_state()
	state.node_flags["boss_defeated"] = "true"
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "scavenge", "node_id": "final_boss_stand"},
		catalog()
	)
	assert_true(bool(resolved["result"].get("ok", false)))
	assert_true(resolved["state"].global_codex_ids.has("phantom_moon_locked"))
	assert_eq(str(resolved["state"].event_log.back().get("reason", "")), "scavenge_recipe_unlocked")


func test_scavenge_is_once_only() -> void:
	var state := make_state()
	state.node_flags["boss_defeated"] = "true"
	var first: Dictionary = ResolverScript.apply(state, {"type": "scavenge", "node_id": "final_boss_stand"}, catalog())
	var second: Dictionary = ResolverScript.apply(first["state"], {"type": "scavenge", "node_id": "final_boss_stand"}, catalog())
	assert_true(bool(first["result"].get("ok", false)))
	assert_false(bool(second["result"].get("ok", false)))
	assert_eq(str(second["result"].get("reason", "")), "scavenge_already_done")


func test_sell_material_pays_stone_and_consumes() -> void:
	var state := make_state()
	state.materials["beast_blood"] = 2
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	assert_true(bool(resolved["result"].get("ok", false)))
	assert_eq(resolved["state"].stone, state.stone + 4)
	assert_eq(int(resolved["state"].materials.get("beast_blood", 0)), 0)


func test_sell_material_respects_notoriety_discount() -> void:
	var state := make_state()
	state.materials["beast_blood"] = 2
	state.cultivator["notorious"] = 5
	var resolved: Dictionary = ResolverScript.apply(
		state,
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	# base 2, uplift capped at 50% -> floor(2 * 0.5) = 1 per unit.
	assert_eq(resolved["state"].stone, state.stone + 2)


func test_sell_material_rejects_empty() -> void:
	var resolved: Dictionary = ResolverScript.apply(
		make_state(),
		{"type": "sell_material", "material_id": "beast_blood"},
		catalog()
	)
	assert_false(bool(resolved["result"].get("ok", false)))


func test_refinement_consumes_materials_and_respects_capacity() -> void:
	var cat: Dictionary = catalog()
	var recipe: Dictionary = cat["refinement_by_id"]["moon_glow_fixed"]
	recipe["materials"] = {"beast_blood": 1}
	# Soul 4 -> craft cap 3; three gu inputs plus one material piece = 4 > 3.
	var state := make_state()
	state.materials["beast_blood"] = 1
	_state_gu_instances(state)
	var blocked: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_eq(str(blocked["result"].get("reason", "")), "refinement_capacity_exceeded")
	# Soul 5 -> craft cap 4; now the same refine passes and spends the material.
	state.cultivator["soul"] = 5
	state.materials["beast_blood"] = 1
	var passed: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_true(bool(passed["result"].get("ok", false)))
	assert_eq(int(passed["state"].materials.get("beast_blood", 0)), 0)


func test_refinement_missing_material_is_rejected() -> void:
	var cat: Dictionary = catalog()
	var recipe: Dictionary = cat["refinement_by_id"]["moon_glow_fixed"]
	recipe["materials"] = {"beast_blood": 1}
	var state := make_state()
	state.cultivator["soul"] = 5
	_state_gu_instances(state)
	var resolved: Dictionary = ResolverScript.apply(state, {
		"type": "refine_gu",
		"recipe_id": "moon_glow_fixed",
		"input_instance_ids": ["gu_001", "gu_002", "gu_003"],
	}, cat)
	assert_false(bool(resolved["result"].get("ok", false)))
	assert_eq(str(resolved["result"].get("reason", "")), "missing_refinement_material")


func _state_gu_instances(state: RunState) -> void:
	# new_run seeds one small_light_gu instance (gu_001). Add one more
	# small_light and one moonlight so moon_glow_fixed inputs are satisfied.
	var second := _add_instance(state, "small_light_gu")
	var third := _add_instance(state, "moonlight_gu")
	assert_ne(second, third)


func _add_instance(state: RunState, definition_id: String) -> String:
	var instance_id := "gu_%03d" % (state.gu_instances.size() + 1)
	state.gu_instances[instance_id] = {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append(instance_id)
	state.sync_legacy_gu_projections()
	return instance_id