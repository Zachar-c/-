extends GutTest


# Spec-v4 phase-2 (T7.1): core gu confirmation (§1.1), depth markup (§1.1),
# pool tilt as a distribution-only benefit (§1.2) and same-identity
# ascension (§1.2). Acceptance #1: any combat gu can be confirmed; common vs
# hub markings are correct and hub evidence is enumerable; one core per run;
# no automatic confirmation; tilt never touches any GuBalance output.


const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const GuBalanceScript = preload("res://scripts/domain/gu_balance.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _instance_with(state: RunState, instance_id: String, definition_id: String, rank: int) -> void:
	state.gu_instances[instance_id] = GuInstanceScript.new_instance(definition_id, instance_id, catalog)
	state.gu_instances[instance_id]["rank"] = rank


func test_any_combat_gu_can_be_confirmed_after_the_first_layer_midpoint() -> void:
	# Acceptance #1: every combat gu qualifies; confirmation opens from the
	# first-layer midpoint (layer >= 1).
	var state: RunState = RunStateScript.new_run(17)
	state.current_node_layer = 1
	_instance_with(state, "gu_001", "small_light_gu", 1)
	var out := CoreGuRulesScript.can_confirm(state, "gu_001", catalog)
	assert_true(bool(out["ok"]), str(out))


func test_confirmation_is_refused_before_the_midpoint_and_missing_instances() -> void:
	var state: RunState = RunStateScript.new_run(17)
	state.current_node_layer = 0
	_instance_with(state, "gu_001", "small_light_gu", 1)
	var early := CoreGuRulesScript.can_confirm(state, "gu_001", catalog)
	assert_false(bool(early["ok"]))
	assert_eq(str(early["reason"]), "too_early_first_layer")
	var missing := CoreGuRulesScript.can_confirm(state, "gu_999", catalog)
	assert_false(bool(missing["ok"]))


func test_one_core_per_run_and_no_automatic_confirmation() -> void:
	# §1.1: one core at a time; the system never auto-confirms (confirm must
	# be an explicit call with state).
	var state: RunState = RunStateScript.new_run(17)
	state.current_node_layer = 1
	_instance_with(state, "gu_001", "small_light_gu", 1)
	_instance_with(state, "gu_002", "moonlight_gu", 2)
	var first := CoreGuRulesScript.confirm(state, "gu_001", catalog)
	assert_true(bool(first["ok"]), str(first))
	# The command surface (T9.2) writes the updated instance back and appends
	# the returned event; the test simulates exactly that.
	state.gu_instances["gu_001"] = first["updated_instance"]
	var second := CoreGuRulesScript.can_confirm(state, "gu_002", catalog)
	assert_false(bool(second["ok"]))
	assert_eq(str(second["reason"]), "core_already_confirmed")
	# The event carries the confirmation facts.
	var event: Dictionary = first["event"]
	assert_eq(str(event["action"]), "core_confirmed")
	assert_eq(int(first["updated_instance"]["core_state"]["confirmed_layer"]), 1)
	assert_true(str(event["reason"]).contains("player_confirmed"))


func test_depth_markup_common_and_hub_with_enumerable_evidence() -> void:
	# Acceptance #1: ordinary gu are common cores; a hub gu declares its
	# branch recipes / exclusive refining evidence, and that evidence is
	# enumerable from the catalog.
	var common := CoreGuRulesScript.core_depth(
			catalog["gu_by_id"]["small_light_gu"], catalog)
	assert_eq(common, "common_core")
	var hub_definition: Dictionary = catalog["gu_by_id"]["phantom_moon_gu"]
	assert_eq(CoreGuRulesScript.core_depth(hub_definition, catalog), "hub_core")
	var evidence := CoreGuRulesScript.hub_evidence(hub_definition, catalog)
	assert_true((evidence["branch_recipes"] as Array).size() >= 1)
	for recipe_id in evidence["branch_recipes"]:
		assert_true(catalog["refinement_by_id"].has(str(recipe_id)),
				"hub evidence must resolve in the recipe catalog")
	var moon: Dictionary = catalog["gu_by_id"]["moonlight_gu"]
	assert_eq(CoreGuRulesScript.core_depth(moon, catalog), "common_core")


func test_tilt_only_improves_distribution_and_never_touches_gu_balance() -> void:
	# §1.2 red line: tilt is a distribution suggestion; every GuBalance
	# projection is bit-identical before and after tilting.
	var before := _balance_snapshot()
	var core := {"definition_id": "phantom_moon_gu", "tags": []}
	var tilt := CoreGuRulesScript.tilt_pool(catalog.get("school_pools", {}), core, catalog)
	assert_true(tilt is Dictionary)
	assert_true(tilt.has("suggestions"))
	# Boost signals only name candidates and their pools - no numbers change.
	var after := _balance_snapshot()
	assert_eq(after, before,
			"tilting must not alter a single GuBalance output")


func test_ascension_keeps_the_gu_identity() -> void:
	# §1.2: same-name ascension keeps definition_id and instance id - the
	# identity, tracks or core never silently change.
	var state: RunState = RunStateScript.new_run(17)
	_instance_with(state, "gu_001", "small_light_gu", 1)
	var instance: Dictionary = state.gu_instances["gu_001"]
	instance["rank"] = 3
	state.gu_instances["gu_001"] = instance
	assert_eq(str(state.gu_instances["gu_001"]["definition_id"]), "small_light_gu")
	assert_eq(str(state.gu_instances["gu_001"]["instance_id"]), "gu_001")
	assert_eq(int(state.highest_owned_rank("small_light_gu")), 3,
			"ascension only raises the rank projection, never the identity")


func _balance_snapshot() -> Dictionary:
	var snap := {}
	snap["rank_multiplier"] = GuBalanceScript.rank_multiplier(5, catalog)
	snap["standard_gu_power"] = GuBalanceScript.standard_gu_power(5, catalog)
	snap["beast_scale"] = GuBalanceScript.beast_scale(5, catalog)
	snap["fixed_defense"] = GuBalanceScript.fixed_defense(5, catalog)
	snap["heal"] = GuBalanceScript.human_standard_heal(5, catalog)
	snap["cost"] = GuBalanceScript.actual_cost_percent(0.1, 1, 2, catalog)
	snap["recovery"] = GuBalanceScript.natural_recovery(50.0, catalog)
	snap["unarmed"] = GuBalanceScript.unarmed_raw_damage(100.0, 1.0, catalog)
	snap["overload"] = GuBalanceScript.overload_self_damage(130.0, 100.0, catalog)
	return snap