extends "res://addons/gut/test.gd"


# School starter data batch: every dao-mark school declares a starter pack
# (1..4 rank-one gu, from the C2 2026-09-05 214-gu remap) plus their effects.
# (The in-battle effect legs of the starters once ran through the legacy
# engine and died with the V1 convergence, B1 bucket C.)


const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


# C2: the full declared dao-mark set (was the five legacy novelschools).
const SCHOOLS: Array = ContentCatalogScript.SCHOOL_IDS
const ROLES := ["attack", "defense", "movement", "healing", "logistics", "recon"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_each_declared_school_has_starters() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		var starters: Array = cat["schools"][school_id].get("starter_gu_ids", [])
		assert_false(starters.is_empty(), "%s must declare a non-empty starter pack" % school_id)
		var seen := {}
		for starter in starters:
			var gu_id := str(starter)
			assert_true(cat["gu_by_id"].has(gu_id), "%s starter missing gu %s" % [school_id, gu_id])
			assert_false(seen.has(gu_id), "%s starter list has duplicates" % school_id)
			seen[gu_id] = true


func test_every_school_has_display_name_and_summary() -> void:
	var cat: Dictionary = catalog()
	assert_eq((cat["schools"] as Dictionary).size(), SCHOOLS.size(), "all declared schools must exist")
	for school_id in SCHOOLS:
		var entry: Dictionary = cat["schools"].get(school_id, {})
		assert_false(entry.is_empty(), "school %s must be declared" % school_id)
		assert_false(str(entry.get("name", "")).is_empty(), "school %s needs a display name" % school_id)
		assert_false(str(entry.get("summary", "")).is_empty(), "school %s needs a summary" % school_id)


func test_starters_belong_to_their_school() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			assert_eq(str(cat["gu_by_id"][str(starter)]["school"]), school_id)


func test_starter_roles_are_valid() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			var role := str(cat["gu_by_id"][str(starter)]["role"])
			assert_true(ROLES.has(role), "%s starter %s has invalid role %s" % [school_id, starter, role])


func test_starter_blueprints_exist_as_cards() -> void:
	var cat: Dictionary = catalog()
	for gu in cat["gu"]:
		var blueprint_ids: Array = gu.get("card_blueprint_ids", [])
		for blueprint_value in blueprint_ids:
			var blueprint := str(blueprint_value)
			var card: Dictionary = cat["card_by_id"].get(blueprint, {})
			assert_false(card.is_empty(), "gu %s references missing card %s" % [gu["id"], blueprint])
			assert_true((card.get("source_gu_ids", []) as Array).has(str(gu["id"])), "card %s must source from gu %s" % [blueprint, gu["id"]])


func test_school_starter_injection_grants_novice_plus_pack() -> void:
	var cat: Dictionary = catalog()
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	controller.start_new_run(2026, "blood")
	# Default run carries the novice small_light_gu plus the blood starter pack.
	var pack: Array = cat["schools"]["blood"].get("starter_gu_ids", [])
	assert_eq(controller.state.refined_gu_ids.size(), pack.size() + 1)
	for starter in pack:
		assert_true(controller.state.refined_gu_ids.has(str(starter)), "blood run must start with %s" % str(starter))


func test_refine_starter_injection_grants_novice_plus_pack() -> void:
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	controller.start_new_run(2026, "refine")
	# Default run carries the novice small_light_gu plus the refine starter pack.
	var pack: Array = catalog()["schools"]["refine"]["starter_gu_ids"]
	assert_eq(controller.state.refined_gu_ids.size(), pack.size() + 1)
	for starter in pack:
		assert_true(controller.state.refined_gu_ids.has(str(starter)), "refine run must start with %s" % str(starter))


func test_school_pools_are_isolated_and_school_matched() -> void:
	var cat: Dictionary = catalog()
	var pools: Dictionary = cat.get("school_pools", {})
	var seen_globally := {}
	for school_id in SCHOOLS:
		var pool: Array = pools.get(school_id, [])
		assert_false(pool.is_empty(), "%s must declare a non-empty exclusive pool" % school_id)
		for gu_id_value in pool:
			var gu_id := str(gu_id_value)
			assert_true(cat["gu_by_id"].has(gu_id), "%s pool references missing gu %s" % [school_id, gu_id])
			assert_eq(str(cat["gu_by_id"][gu_id]["school"]), school_id, "%s pool must not contain other-school gu %s" % [school_id, gu_id])
			assert_false(seen_globally.has(gu_id), "gu %s appears in more than one school pool" % gu_id)
			seen_globally[gu_id] = true


func test_school_pool_entries_have_display_names() -> void:
	var cat: Dictionary = catalog()
	var pools: Dictionary = cat.get("school_pools", {})
	var gu_names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/gu_names.json"))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/names.json"))
	var legacy_gu: Dictionary = legacy.get("gu", {})
	for school_id in pools:
		for gu_id_value in pools[school_id]:
			var gu_id := str(gu_id_value)
			var named := gu_names.has(gu_id) or legacy_gu.has(gu_id)
			assert_true(named, "pool gu %s needs a Chinese display name" % gu_id)
