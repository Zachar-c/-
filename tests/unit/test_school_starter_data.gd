extends "res://addons/gut/test.gd"


# School starter data batch: five starter gu per school sourced from the
# original novel (blood/force/qi keyword indexes), plus their battle effects.


const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")


const SCHOOLS := ["blood", "qi", "force"]
const ROLES := ["attack", "defense", "movement", "healing", "logistics", "recon"]


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func make_state(run_seed: int = 2026) -> RunState:
	return RunStateScript.new_run(run_seed, null)


func test_three_schools_each_have_five_starters() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		var starters: Array = cat["schools"][school_id].get("starter_gu_ids", [])
		assert_eq(starters.size(), 5, "%s must have exactly five starters" % school_id)
		var seen := {}
		for starter in starters:
			var gu_id := str(starter)
			assert_true(cat["gu_by_id"].has(gu_id), "%s starter missing gu %s" % [school_id, gu_id])
			assert_false(seen.has(gu_id), "%s starter list has duplicates" % school_id)
			seen[gu_id] = true


func test_starters_belong_to_their_school() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			assert_eq(str(cat["gu_by_id"][str(starter)]["school"]), school_id)


func test_starter_roles_are_valid_and_cover_core_roles() -> void:
	var cat: Dictionary = catalog()
	for school_id in SCHOOLS:
		var roles := {}
		for starter in cat["schools"][school_id].get("starter_gu_ids", []):
			var role := str(cat["gu_by_id"][str(starter)]["role"])
			assert_true(ROLES.has(role), "%s starter has invalid role %s" % [school_id, role])
			roles[role] = true
		assert_true(roles.has("attack"), "%s starters need an attack role" % school_id)
	assert_true(school_has_role(cat, "blood", "healing"), "blood starters need healing")
	assert_true(school_has_role(cat, "qi", "defense"), "qi starters need defense")
	assert_true(school_has_role(cat, "qi", "recon"), "qi starters need recon")
	assert_true(school_has_role(cat, "force", "defense"), "force starters need defense")


static func school_has_role(cat: Dictionary, school_id: String, role: String) -> bool:
	for starter in cat["schools"][school_id].get("starter_gu_ids", []):
		if str(cat["gu_by_id"][str(starter)]["role"]) == role:
			return true
	return false


func test_starter_blueprints_exist_as_cards() -> void:
	var cat: Dictionary = catalog()
	for gu in cat["gu"]:
		var blueprint_ids: Array = gu.get("card_blueprint_ids", [])
		for blueprint_value in blueprint_ids:
			var blueprint := str(blueprint_value)
			var card: Dictionary = cat["card_by_id"].get(blueprint, {})
			assert_false(card.is_empty(), "gu %s references missing card %s" % [gu["id"], blueprint])
			assert_true((card.get("source_gu_ids", []) as Array).has(str(gu["id"])), "card %s must source from gu %s" % [blueprint, gu["id"]])


func test_starter_injection_grants_five_gu() -> void:
	var controller = preload("res://scripts/presentation/run_controller.gd").new()
	add_child_autofree(controller)
	controller.start_new_run(2026, "blood")
	# Default run carries the novice small_light_gu plus the five school starters.
	assert_eq(controller.state.refined_gu_ids.size(), 6)
	for starter in ["blood_moss_gu", "blood_droplet_gu", "blood_bat_gu", "blood_wing_gu", "blood_farewell_gu"]:
		assert_true(controller.state.refined_gu_ids.has(starter))


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
	qi.refined_gu_ids.append("qi_wall_gu")
	var qi_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, qi, cat)
	var qi_turn: Dictionary = BattleResolverScript.take_turn(qi_battle, {"type": "use_gu", "gu_id": "qi_wall_gu"}, qi, cat)
	assert_true((qi_turn["battle"]["flags"] as Array).has("guarded"))
	var farewell := make_state()
	farewell.refined_gu_ids.append("blood_farewell_gu")
	var farewell_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, farewell, cat)
	var farewell_turn: Dictionary = BattleResolverScript.take_turn(farewell_battle, {"type": "use_gu", "gu_id": "blood_farewell_gu"}, farewell, cat)
	assert_true((farewell_turn["battle"]["flags"] as Array).has("enemy_bound"))
	assert_eq(int(farewell_turn["battle"]["delay_progress"]), 1)
	var wing := make_state()
	wing.refined_gu_ids.append("blood_wing_gu")
	var wing_battle: Dictionary = BattleResolverScript.start({"enemy_kind": "neutral_stone_wanderer"}, wing, cat)
	var wing_turn: Dictionary = BattleResolverScript.take_turn(wing_battle, {"type": "use_gu", "gu_id": "blood_wing_gu"}, wing, cat)
	assert_true((wing_turn["battle"]["flags"] as Array).has("retreat_preserved"))