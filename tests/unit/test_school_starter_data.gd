extends "res://addons/gut/test.gd"


# School starter data batch: every dao-mark school declares a starter pack
# (1..4 rank-one gu, from the C2 2026-09-05 214-gu remap) plus their effects.


const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
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


func test_new_starter_battle_effects_resolve() -> void:
	var cat: Dictionary = catalog()
	var cases := [
		{"gu_id": "blood_droplet_gu", "check": "damage2", "hp_delta": -2, "injury_delta": 0},
		{"gu_id": "blood_bat_gu", "check": "damage1_heal1", "hp_delta": -1, "injury_delta": -1},
		{"gu_id": "force_gu", "check": "damage2", "hp_delta": -2, "injury_delta": 0},
		{"gu_id": "bear_strength_gu", "check": "heal1", "hp_delta": 0, "injury_delta": -1},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		var state := make_state()
		state.refined_gu_ids.append(str(case["gu_id"]))
		state.injury = 2
		var battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, state, cat)
		var hp_before := int(battle["enemy_hp"])
		var turn: Dictionary = BattleResolverScript.take_turn(
			battle, {"type": "use_gu", "gu_id": str(case["gu_id"])}, state, cat
		)
		assert_eq(int(turn["battle"]["enemy_hp"]), hp_before + int(case["hp_delta"]), "gu %s damage" % str(case["gu_id"]))
		assert_eq(int(turn["state"].injury), 2 + int(case["injury_delta"]), "gu %s heal" % str(case["gu_id"]))
	var qi := make_state()
	qi.refined_gu_ids.append("stone_shell_gu")
	var qi_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, qi, cat)
	var qi_turn: Dictionary = BattleResolverScript.take_turn(qi_battle, {"type": "use_gu", "gu_id": "stone_shell_gu"}, qi, cat)
	assert_true((qi_turn["battle"]["flags"] as Array).has("guarded"))
	var farewell := make_state()
	farewell.refined_gu_ids.append("blood_farewell_gu")
	var farewell_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, farewell, cat)
	var farewell_turn: Dictionary = BattleResolverScript.take_turn(farewell_battle, {"type": "use_gu", "gu_id": "blood_farewell_gu"}, farewell, cat)
	assert_true((farewell_turn["battle"]["flags"] as Array).has("enemy_bound"))
	assert_eq(int(farewell_turn["battle"]["delay_progress"]), 1)