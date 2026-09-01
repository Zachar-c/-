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
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			_recipe("moonlight_glow"), false, true, false)["reason"]), "inputs_incomplete")
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			_recipe("phantom_moon_locked"), true, false, false)["reason"]), "recipe_locked")
	assert_eq(str(RecipeRulesScript.known_fixed_success(
			_recipe("moonlight_glow"), true, true, true)["reason"]), "interrupted")


func test_tag_recipe_candidates_come_only_from_the_hand_authored_pool() -> void:
	# Acceptance #7: a tag recipe resolves deterministically from its pool;
	# pool entries must exist in gu.json (schema guard) and no programmatic gu
	# is ever generated.
	var candidates := RecipeRulesScript.resolve_candidates(_recipe("tagged_moon_candidates"), catalog)
	assert_eq(candidates, ["phantom_moon_gu", "moon_shadow_gu"])
	for gu_id in candidates:
		assert_true(catalog["gu_by_id"].has(gu_id), "%s must exist in gu.json" % gu_id)


func test_identity_requires_named_materials_by_exact_name() -> void:
	# Acceptance #8: named identities bind by name; equivalent materials never
	# substitute unless the recipe declares otherwise.
	var recipe := _recipe("essence_thorn_identity")
	var miss := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {}, {}, catalog)
	assert_false(bool(miss["ok"]))
	assert_eq(str(miss["reason"]), "named_material_missing")
	# The wrong material (equal value or not) is still a missing identity.
	var wrong := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"beast_bone": 5}, {}, catalog)
	assert_false(bool(wrong["ok"]))
	# The named material satisfies it without substitution records; a 2-turn
	# input also meets the recipe's min_rank.
	var exact := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2}, catalog)
	assert_true(bool(exact["ok"]), str(exact))
	assert_true((exact["substitutions"] as Array).is_empty())


func test_declared_substitution_passes_and_reports_cost_changes() -> void:
	# Acceptance #8: only allow_substitute relations may swap materials, and
	# the swap returns the declared cost/condition/product changes.
	var recipe := _recipe("essence_thorn_identity")
	var swapped := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"moon_blue_petal": 2}, {"thorn_whip_gu": 2}, catalog)
	assert_true(bool(swapped["ok"]), str(swapped))
	var subs: Array = swapped["substitutions"]
	assert_eq(subs.size(), 1)
	assert_eq(str(subs[0]["from"]), "venom_sac")
	assert_eq(str(subs[0]["to"]), "moon_blue_petal")
	assert_eq(int(swapped["cost_change"].get("essence", 0)), 2,
			"the declared substitution cost change travels with the recipe")
	# Undeclared swap relations stay refused.
	var undeclared := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"beast_blood": 9}, {}, catalog)
	assert_false(bool(undeclared["ok"]))


func test_min_rank_identity_gate() -> void:
	var recipe := _recipe("essence_thorn_identity")
	var too_low := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 1}, catalog)
	assert_false(bool(too_low["ok"]))
	assert_eq(str(too_low["reason"]), "min_rank_not_met")
	var enough := RecipeRulesScript.check_identity(
			recipe, ["thorn_whip_gu"], {"venom_sac": 1}, {"thorn_whip_gu": 2}, catalog)
	assert_true(bool(enough["ok"]), str(enough))


func test_stages_declare_per_turn_thought_claims() -> void:
	# §5.3: staged refining claims per-stage thought per round; the first
	# stage of the sample carries a durable multi-round thought claim.
	var staged := _recipe("moon_ray_staged")
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