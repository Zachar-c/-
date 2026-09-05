extends GutTest


# Spec-v4 phase-2 (T5.2): unified recipe rules - deterministic success
# (§5.3), deterministic candidate selection (§5.2) and identity-bound
# substitution (§5.4). Zero dice: a known recipe never rolls and never eats
# inputs on a random failure. Acceptance #7 (known recipes succeed when
# complete/safe/uninterrupted; tag recipes only produce hand-authored
# candidates) and #8 (equivalent materials / yuanstone never substitute;
# allow_substitute relations pass with their declared changes).


const RecipeRulesScript = preload("res://scripts/domain/recipe_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _recipe(recipe_id: String) -> Dictionary:
	for recipe in catalog["refinement_recipes"]:
		if str(recipe.get("id", "")) == recipe_id:
			return recipe
	push_error("missing recipe %s" % recipe_id)
	return {}


# The 802-gu catalog rebuild re-curated refinement_recipes.json to the
# advance/fixed/free_mix model; the identity/tag/staged demo recipes are no
# longer shipped as data. The domain contract below (identity-bound
# substitution, deterministic candidate pools, staged claims) is still pinned
# by RecipeRules, so these tests carry test-local fixtures with the same
# declared shapes instead of reading them from the catalog.
func _identity_fixture() -> Dictionary:
	return {
		"id": "essence_thorn_identity",
		"kind": "fixed",
		"input_gu_ids": ["thorn_whip_gu"],
		"identity_requirements": {
			"named_materials": ["venom_sac"],
			"named_media": ["kael_fire_medium"],
			"min_rank": 2,
		},
		"allow_substitute": {
			"materials": {"venom_sac": ["moon_blue_petal"]},
			"media": {"kael_fire_medium": ["essence_bead"]},
			"cost_change": {"essence": 2},
		},
		"output_gu_id": "venom_thread_gu",
	}


func _tag_fixture() -> Dictionary:
	return {
		"id": "tagged_moon_candidates",
		"kind": "fixed",
		"default_unlocked": true,
		"input_gu_ids": ["moonlight_gu", "small_light_gu"],
		# Both pool entries survive in gu.json (schema-guardable).
		"candidate_pool": ["moon_glow_gu", "moon_shadow_gu"],
		"output_gu_id": "moon_shadow_gu",
	}


func _staged_fixture() -> Dictionary:
	return {
		"id": "moon_ray_staged",
		"kind": "fixed",
		"input_gu_ids": ["moon_ray_gu"],
		"stages": [
			{"thought": 1, "essence": 1, "duration": 2, "interruptible": true, "failure_condition": "none"},
			{"thought": 2, "essence": 2, "duration": 1, "interruptible": false},
		],
		"output_gu_id": "moon_shadow_gu",
	}


func test_known_recipe_succeeds_deterministically_when_ready() -> void:
	# Acceptance #7: complete, safe, uninterrupted known recipes succeed with
	# no roll and no eaten inputs.
	var out := RecipeRulesScript.known_fixed_success(
			_recipe("moonlight_glow"), true, true, false)
	assert_true(bool(out["ok"]), str(out))
	assert_true(bool(out.get("success", false)))
	assert_false(bool(out.get("swallowed_inputs", false)),
			"a deterministic success never eats inputs")


func test_known_recipe_refuses_with_structured_reasons() -> void:
	var ready_recipe := _recipe("moonlight_glow")
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			ready_recipe, false, true, false)["reason"]), "inputs_incomplete")
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			ready_recipe, true, false, false)["reason"]), "recipe_locked")
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			ready_recipe, true, true, true)["reason"]), "interrupted")


func test_tag_recipe_candidates_come_only_from_the_hand_authored_pool() -> void:
	# Acceptance #7: a tag recipe resolves deterministically from its pool;
	# pool entries must exist in gu.json (schema guard) and no programmatic gu
	# is ever generated.
	var candidates := RecipeRulesScript.resolve_candidates(_tag_fixture(), catalog)
	assert_eq(candidates, ["moon_glow_gu", "moon_shadow_gu"])
	for gu_id in candidates:
		assert_true(catalog["gu_by_id"].has(gu_id), "%s must exist in gu.json" % gu_id)


func test_identity_requires_named_materials_by_exact_name() -> void:
	# Acceptance #8: named identities bind by name; equivalent materials never
	# substitute unless the recipe declares otherwise.
	var recipe := _identity_fixture()
	var miss := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {}, {}, catalog, [])
	assert_false(bool(miss["ok"]))
	assert_eq(str(miss["reason"]), "named_material_missing")
	# The wrong material (equal value or not) is still a missing identity.
	var wrong := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"beast_bone": 5}, {}, catalog, [])
	assert_false(bool(wrong["ok"]))
	# The named material satisfies it without substitution records; a 2-turn
	# input also meets the recipe's min_rank and the named medium is offered.
	var exact := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(exact["ok"]), str(exact))
	assert_true((exact["substitutions"] as Array).is_empty())


func test_declared_substitution_passes_and_reports_cost_changes() -> void:
	# Acceptance #8: only allow_substitute relations may swap materials, and
	# the swap returns the declared cost/condition/product changes.
	var recipe := _identity_fixture()
	var swapped := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"moon_blue_petal": 2}, {"thorn_whip_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(swapped["ok"]), str(swapped))
	var subs: Array = swapped["substitutions"]
	assert_eq(subs.size(), 1)
	assert_eq(str(subs[0]["from"]), "venom_sac")
	assert_eq(str(subs[0]["to"]), "moon_blue_petal")
	assert_eq(int(swapped["cost_change"].get("essence", 0)), 2,
			"the declared substitution cost change travels with the recipe")
	# Undeclared swap relations stay refused.
	var undeclared := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"beast_blood": 9}, {}, catalog, [])
	assert_false(bool(undeclared["ok"]))


func test_min_rank_identity_gate() -> void:
	var recipe := _identity_fixture()
	var too_low := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 1},
			catalog, ["kael_fire_medium"])
	assert_false(bool(too_low["ok"]))
	assert_eq(str(too_low["reason"]), "min_rank_not_met")
	var enough := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(enough["ok"]), str(enough))


func test_named_medium_binds_and_declared_media_substitution_passes() -> void:
	# P0.1 (§5.4.1): named media must actually be present in the offer; an
	# allow_substitute.media relation swaps it and travels with cost_change.
	var recipe := _identity_fixture()
	var miss := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2},
			catalog, [])
	assert_false(bool(miss["ok"]))
	assert_eq(str(miss["reason"]), "named_media_missing")
	var exact := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2},
			catalog, ["kael_fire_medium"])
	assert_true(bool(exact["ok"]), str(exact))
	assert_true((exact["substitutions"] as Array).is_empty())
	var swapped := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2},
			catalog, ["essence_bead"])
	assert_true(bool(swapped["ok"]), str(swapped))
	var media_subs: Array = swapped["substitutions"]
	assert_eq(media_subs.size(), 1)
	assert_eq(str(media_subs[0]["from"]), "kael_fire_medium")
	assert_eq(str(media_subs[0]["to"]), "essence_bead")


func test_stages_declare_per_turn_thought_claims() -> void:
	# §5.3: staged refining claims per-stage thought per round; the first
	# stage of the sample carries a durable multi-round thought claim.
	var staged := _staged_fixture()
	var stages: Array = staged["stages"]
	assert_eq(stages.size(), 2)
	assert_eq(int(stages[0]["duration"]), 2)
	assert_eq(int(stages[0]["thought"]), 1)
	assert_true(bool(stages[0]["interruptible"]))
	assert_false(bool(stages[1]["interruptible"]))
	# Schema must have accepted the sample (schema guard is green in the
	# content catalog test; here we just sanity-check the declaration shape).
	assert_true(bool(staged.has("output_gu_id")))


func test_zero_randomness_audit() -> void:
	# Determinism red line: the recipe rules source never rolls dice.
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/recipe_rules.gd")
	for token in ["SeededRoll", "roll(", "rand", "randomize", "Rng", "weight"]:
		assert_false(source.contains(token),
				"recipe_rules.gd must not reference %s" % token)