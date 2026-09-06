extends GutTest


const FacadeScript := preload("res://scripts/domain/battle_command_facade.gd")


func test_catalog_has_gu_and_three_inheritances() -> void:
	var catalog := ContentCatalog.load_all()
	assert_eq(catalog["gu"].size(), 802)
	assert_eq(catalog["inheritances"].size(), 3)
	assert_eq(ContentCatalog.validate(catalog), [])


func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
	var catalog := ContentCatalog.load_all()
	catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
	assert_eq(ContentCatalog.validate(catalog).size(), 1)


func test_shipped_authored_locked_recipes_declare_output_rank_and_living_gu() -> void:
	var catalog := ContentCatalog.load_all()
	for rid in ["moon_shadow_locked", "blood_moon_forged"]:
		var recipe: Dictionary = catalog.get("refinement_by_id", {}).get(rid, {})
		assert_true(not recipe.is_empty(), rid)
		if recipe.is_empty():
			continue
		assert_true(int(recipe.get("output_rank", 0)) >= 2, rid)
		assert_true(catalog.get("gu_by_id", {}).has(str(recipe.get("output_gu_id", ""))), rid)


func test_validation_rejects_unknown_slice_recipe_input() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["refinement_recipes"] as Array).append({
		"id": "_probe_unknown_input", "kind": "fixed",
		"kill_move_id": "km_probe_unknown_input",
		"input_gu_ids": ["missing_input_gu"], "output_gu_id": "moon_glow_gu",
	})
	((catalog["v1_battle"] as Dictionary)["kill_moves"] as Array).append({
		"id": "km_probe_unknown_input", "recipe": ["moon_glow_gu"],
	})
	assert_true(_has_hint(ContentCatalog.validate(catalog), "unknown input gu"))


func test_validation_rejects_unknown_slice_kill_move_effect() -> void:
	var catalog := ContentCatalog.load_all()
	var battle_value = catalog.get("v1_battle")
	assert_true(battle_value is Dictionary)
	if not battle_value is Dictionary:
		return
	var kill_moves_value = (battle_value as Dictionary).get("kill_moves")
	assert_true(kill_moves_value is Array)
	if not kill_moves_value is Array:
		return
	(kill_moves_value as Array).append({"id": "bad_effect_kill_move", "recipe": ["pulse_drum_gu"], "effect": {"kind": "unknown_effect"}})
	assert_true(_has_hint(ContentCatalog.validate(catalog), "effect"))


func test_validation_rejects_invalid_slice_v1_effect() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["refinement_recipes"] as Array).append({
		"id": "_probe_bad_effect", "kind": "fixed",
		"kill_move_id": "km_probe_bad_effect",
		"input_gu_ids": ["moonlight_gu"], "output_gu_id": "moon_glow_gu",
	})
	((catalog["v1_battle"] as Dictionary)["kill_moves"] as Array).append({
		"id": "km_probe_bad_effect", "recipe": ["moon_glow_gu"],
	})
	((catalog["gu_by_id"] as Dictionary)["moon_glow_gu"] as Dictionary)["v1_effect"] = {"kind": "status", "name": "bound", "amount": -1}
	assert_true(_has_hint(ContentCatalog.validate(catalog), "v1_effect"))


func _has_hint(errors: Array[String], needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func test_validation_requires_all_five_schools() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["schools"] as Dictionary).erase("refine")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "refine"))


func test_validation_rejects_school_without_display_name() -> void:
	var catalog := ContentCatalog.load_all()
	var soul: Dictionary = (catalog["schools"] as Dictionary)["soul"]
	soul.erase("name")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "display name"))


func test_validation_rejects_cross_school_pool_entry() -> void:
	var catalog := ContentCatalog.load_all()
	var blood_pool: Array = (catalog["school_pools"] as Dictionary)["blood"]
	blood_pool.append("stone_shell_gu")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "belongs to school"))


func test_validation_rejects_gu_in_two_pools() -> void:
	var catalog := ContentCatalog.load_all()
	var pools: Dictionary = catalog["school_pools"]
	var qi_pool: Array = pools["qi"]
	qi_pool.append(str((pools["blood"] as Array)[0]))
	assert_true(_has_hint(ContentCatalog.validate(catalog), "multiple school pools"))


func test_validation_rejects_missing_pool_gu() -> void:
	var catalog := ContentCatalog.load_all()
	var soul_pool: Array = (catalog["school_pools"] as Dictionary)["soul"]
	soul_pool.append("missing_pool_gu")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "missing gu"))


func test_validation_rejects_missing_exclusive_pool() -> void:
	var catalog := ContentCatalog.load_all()
	(catalog["school_pools"] as Dictionary).erase("force")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "exclusive pool"))


func test_material_pity_config_is_validated() -> void:
	var catalog := ContentCatalog.load_all()
	var pity: Dictionary = catalog["loot_tables"]["pity"]["material_pity"]
	pity["target_material_ids"].append("missing_material_x")
	assert_true(_has_hint(ContentCatalog.validate(catalog), "unknown material"))


func test_synthesis_config_is_validated() -> void:
	var catalog := ContentCatalog.load_all()
	var recipes: Array = catalog["synthesis"]["battle_recipes"]
	(recipes[0] as Dictionary)["material_cost"] = {"missing_material_x": 1}
	assert_true(_has_hint(ContentCatalog.validate(catalog), "unknown material"))


func _enemy(catalog: Dictionary, enemy_id: String) -> Dictionary:
	for entry in catalog["enemies"]:
		if str(entry["id"]) == enemy_id:
			return entry
	push_error("missing enemy %s" % enemy_id)
	return {}


func test_shipped_phase_tables_pass_validation() -> void:
	assert_eq(ContentCatalog.validate(ContentCatalog.load_all()), [])


func test_validation_rejects_phase_threshold_outside_open_unit_range() -> void:
	var catalog := ContentCatalog.load_all()
	_enemy(catalog, "miasma_vein_lord")["phases"][1]["until_hp_ratio"] = 1.5
	assert_true(_has_hint(ContentCatalog.validate(catalog), "outside (0, 1]"))

	var zeroed := ContentCatalog.load_all()
	_enemy(zeroed, "miasma_vein_lord")["phases"][1]["until_hp_ratio"] = 0
	assert_true(_has_hint(ContentCatalog.validate(zeroed), "outside (0, 1]"))


func test_validation_rejects_unordered_phase_thresholds() -> void:
	var catalog := ContentCatalog.load_all()
	_enemy(catalog, "miasma_vein_lord")["phases"][0]["until_hp_ratio"] = 0.4
	assert_true(_has_hint(ContentCatalog.validate(catalog), "descend strictly"))


func test_validation_rejects_empty_phase_intents() -> void:
	var catalog := ContentCatalog.load_all()
	_enemy(catalog, "miasma_vein_lord")["phases"][0]["intents"] = []
	assert_true(_has_hint(ContentCatalog.validate(catalog), "non-empty intents array"))


func test_validation_rejects_bad_intent_cooldowns() -> void:
	var catalog := ContentCatalog.load_all()
	_enemy(catalog, "miasma_vein_lord")["phases"][0]["intents"][0]["cooldown"] = -1
	assert_true(_has_hint(ContentCatalog.validate(catalog), "non-negative integer"))

	var fractional := ContentCatalog.load_all()
	_enemy(fractional, "miasma_vein_lord")["phases"][0]["intents"][0]["cooldown"] = 1.5
	assert_true(_has_hint(ContentCatalog.validate(fractional), "non-negative integer"))


func test_battle_start_survives_a_degenerate_empty_intents_phase() -> void:
	var catalog := ContentCatalog.load_all()
	_enemy(catalog, "miasma_vein_lord")["phases"][0]["intents"] = []
	var run := RunState.new_run(101)

	var battle := FacadeScript.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)

	# Validation is the gate for bad tables; at runtime V1 (which ignores the
	# legacy boss phase table) must still start cleanly off the top-level
	# intent and never index into an empty array.
	var enemies: Array = battle.get("enemies", [])
	assert_eq(enemies.size(), 1)
	var boss: Dictionary = enemies[0]
	assert_eq(int(boss.get("hp", 0)), int(boss.get("max_hp", -1)),
			"V1 battle starts the boss at full hp")


func test_validation_rejects_unknown_or_duplicate_multi_enemy_node_members() -> void:
	var unknown := ContentCatalog.load_all()
	_node(unknown, "beast_swarm_pass")["enemy_kinds"] = ["ridge_hound", "missing_enemy"]
	assert_true(_has_hint(ContentCatalog.validate(unknown), "unknown enemy"))

	var duplicate := ContentCatalog.load_all()
	_node(duplicate, "beast_swarm_pass")["enemy_kinds"] = ["ridge_hound", "ridge_hound"]
	assert_true(_has_hint(ContentCatalog.validate(duplicate), "duplicate enemy"))


func _node(catalog: Dictionary, node_id: String) -> Dictionary:
	for entry in catalog["nodes"]:
		if str(entry["id"]) == node_id:
			return entry
	push_error("missing node %s" % node_id)
	return {}
