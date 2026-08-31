extends GutTest


func test_catalog_has_twenty_gu_and_three_inheritances() -> void:
	var catalog := ContentCatalog.load_all()
	assert_eq(catalog["gu"].size(), 212)
	assert_eq(catalog["inheritances"].size(), 3)
	assert_eq(ContentCatalog.validate(catalog), [])


func test_catalog_rejects_missing_inheritance_gu_reference() -> void:
	var catalog := ContentCatalog.load_all()
	catalog["inheritances"][0]["required_gu_ids"] = ["missing_gu"]
	assert_eq(ContentCatalog.validate(catalog).size(), 1)


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
