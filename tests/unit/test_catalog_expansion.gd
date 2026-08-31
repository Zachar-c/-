extends "res://addons/gut/test.gd"


# Task C1: gu catalog expanded to 200 total (40 per school), data-driven
# combat effects for every generated entry, deterministic generator rerun.


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")

const SCHOOLS := ["blood", "qi", "force", "soul", "refine"]
const RARITY_TARGETS := {"common": 24, "rare": 12, "epic": 4}


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func test_total_gu_is_200() -> void:
	assert_gte(catalog()["gu"].size(), 200)


func test_each_school_has_40_gu() -> void:
	var counts := {}
	for gu in catalog()["gu"]:
		counts[gu["school"]] = int(counts.get(gu["school"], 0)) + 1
	for school in SCHOOLS:
		assert_gte(int(counts.get(school, 0)), 40, "school %s" % school)


func test_per_school_rarity_targets_met() -> void:
	var counts := {}
	for gu in catalog()["gu"]:
		var key := "%s|%s" % [gu["school"], gu["rarity"]]
		counts[key] = int(counts.get(key, 0)) + 1
	for school in SCHOOLS:
		for rarity in RARITY_TARGETS:
			assert_gte(int(counts.get("%s|%s" % [school, rarity], 0)),
					RARITY_TARGETS[rarity], "%s %s" % [school, rarity])


func test_no_duplicate_ids_in_real_catalog() -> void:
	var errors: Array[String] = ContentCatalogScript.validate(catalog())
	for error in errors:
		assert_false(error.contains("duplicate"), error)


func test_validate_flags_synthetic_duplicate_gu_id() -> void:
	var fake := catalog()
	fake["gu"].append(fake["gu"][0].duplicate(true))
	var errors: Array[String] = ContentCatalogScript.validate(fake)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("duplicate gu id")))


func test_every_generated_gu_is_data_driven_with_one_card() -> void:
	var cat := catalog()
	var card_by_id: Dictionary = cat["card_by_id"]
	for gu in cat["gu"]:
		if not gu.has("combat_effects"):
			continue
		var blueprints: Array = gu.get("card_blueprint_ids", [])
		assert_gte(blueprints.size(), 1, "gu %s" % gu["id"])
		assert_true(card_by_id.has(str(blueprints[0])), "gu %s blueprint exists" % gu["id"])
		var card: Dictionary = card_by_id[str(blueprints[0])]
		assert_true((card.get("source_gu_ids", []) as Array).has(gu["id"]),
				"card %s back-references gu" % card["id"])


func test_generated_attack_gu_deals_damage_in_battle() -> void:
	var cat := catalog()
	var attacker := {}
	for gu in cat["gu"]:
		if str(gu.get("id", "")).begins_with("gen_") and gu["role"] == "attack":
			attacker = gu
			break
	assert_false(attacker.is_empty(), "generated attack gu exists")
	var state := RunStateScript.new_run(4242)
	state.school = str(attacker["school"])
	state.gu_instances["gu_100"] = {
		"instance_id": "gu_100",
		"definition_id": str(attacker["id"]),
		"state": "refined",
	}
	state.cave_aperture["stored_gu_instance_ids"].append("gu_100")
	state.sync_legacy_gu_projections()
	var battle := BattleResolverScript.start({"enemy_kind": "ridge_hound"}, state, cat)
	var enemy_hp_before := int(battle["enemy_hp"])
	var turn := BattleResolverScript.take_turn(battle,
			{"type": "use_gu", "gu_id": str(attacker["id"])}, state, cat)
	assert_eq(str(turn["result"]), "ongoing")
	assert_lt(int(turn["battle"]["enemy_hp"]), enemy_hp_before)


func test_generator_rerun_is_idempotent() -> void:
	var before_gu: Array = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/gu.json"))
	var output := []
	OS.execute("python", ["tools/generate_gu_catalog.py",
			"--harvest", "..\\..\\.superpowers\\sdd\\gu-name-harvest.txt"], output, true)
	var after_gu: Array = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/gu.json"))
	assert_gte(after_gu.size(), before_gu.size())
	assert_gte(JSON.stringify(after_gu), JSON.stringify(before_gu))
