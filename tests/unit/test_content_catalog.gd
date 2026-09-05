extends GutTest


func test_catalog_has_twenty_gu_and_three_inheritances() -> void:
	var catalog := ContentCatalog.load_all()
	assert_eq(catalog["gu"].size(), 214)
	assert_eq(catalog["inheritances"].size(), 3)
	assert_eq(ContentCatalog.validate(catalog), [])


func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
	var catalog := ContentCatalog.load_all()
	catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
	assert_eq(ContentCatalog.validate(catalog).size(), 1)


func test_shipped_synthesis_kill_move_contract_is_explicit() -> void:
	var catalog := ContentCatalog.load_all()
	var refinement_by_id: Dictionary = catalog.get("refinement_by_id", {})
	var recipe_value = refinement_by_id.get("slice_bright_thread")
	assert_true(recipe_value is Dictionary)
	if not recipe_value is Dictionary:
		return
	var recipe: Dictionary = recipe_value
	var kill_move_id := str(recipe.get("kill_move_id", ""))
	assert_false(kill_move_id.is_empty())
	var battle_value = catalog.get("v1_battle")
	assert_true(battle_value is Dictionary)
	if not battle_value is Dictionary:
		return
	var kill_moves_value = (battle_value as Dictionary).get("kill_moves")
	assert_true(kill_moves_value is Array)
	if not kill_moves_value is Array:
		return
	var kill_move: Dictionary = {}
	for value in kill_moves_value:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == kill_move_id:
			kill_move = value
			break
	assert_false(kill_move.is_empty())
	var output_gu_id := str(recipe.get("output_gu_id", ""))
	assert_false(output_gu_id.is_empty())
	var kill_recipe_value = kill_move.get("recipe", [])
	assert_true(kill_recipe_value is Array)
	if not kill_recipe_value is Array:
		return
	assert_true((kill_recipe_value as Array).has(output_gu_id))
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var output_value = gu_by_id.get(output_gu_id)
	assert_true(output_value is Dictionary)
	if not output_value is Dictionary:
		return
	var output: Dictionary = output_value
	var effect_value = output.get("v1_effect")
	assert_true(effect_value is Dictionary)
	if not effect_value is Dictionary:
		return
	var effect: Dictionary = effect_value
	assert_true(effect.has("kind"))


func test_validation_rejects_unknown_slice_recipe_input() -> void:
	var catalog := ContentCatalog.load_all()
	var refinement_by_id: Dictionary = catalog.get("refinement_by_id",{})
	var recipe_value = refinement_by_id.get("slice_bright_thread")
	assert_true(recipe_value is Dictionary)
	if not recipe_value is Dictionary:
		return
	(recipe_value as Dictionary)["input_gu_ids"] = ["missing_input_gu"]
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
	var gu_by_id_value = catalog.get("gu_by_id",{})
	if not gu_by_id_value is Dictionary:
		assert_true(false)
		return
	var pulse_drum_value = (gu_by_id_value as Dictionary).get("pulse_drum_gu")
	if not pulse_drum_value is Dictionary:
		assert_true(false)
		return
	(pulse_drum_value as Dictionary)["v1_effect"] = {"kind": "status", "name": "bound", "amount": -1}
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

	var battle := BattleResolver.start({"enemy_kind": "miasma_vein_lord"}, run, catalog)

	# Validation is the gate for bad tables; at runtime the legacy intent keeps
	# the engine from indexing into an empty array.
	assert_eq(str(battle["visible_intent"].get("id", "")), "miasma_burst")
	assert_eq(int(battle["enemy_hp"]), int(battle["enemy_max_hp"]))


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
