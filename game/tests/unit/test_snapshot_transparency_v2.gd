extends GutTest


# Spec-v4 phase-2 (T9.1): snapshot transparency v2 - the §17.2 eight groups
# of snapshot keys, each projected from its owning rule module. Every key is
# asserted to be identical to a direct module call (projective same-source,
# §17.3 landing on the snapshot layer). The builder stays read-only: the new
# section must contain no state-writing path.


const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const RecipeRulesScript = preload("res://scripts/domain/recipe_rules.gd")
const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const BodyRulesScript = preload("res://scripts/domain/body_rules.gd")
const ActionResolverScript = preload("res://scripts/domain/action_resolver.gd")
const SoulRulesScript = preload("res://scripts/domain/soul_rules.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _controller() -> Dictionary:
	var state: RunState = RunStateScript.new_run(41)
	state.current_node_layer = 2
	state.route_progress = ["n1", "n2", "n3", "n4"]
	for index in range(4):
		state.route_progress.append("n%02d" % (index + 5))
	state.gu_instances["gu_001"] = {
		"instance_id": "gu_001", "definition_id": "small_light_gu", "state": "refined",
		"rank": 1, "core_state": {}, "hunger_phase": 0, "next_feed_need": {},
		"lifecycle": "long", "loyal": false, "ferocity": 0, "parasitic": false,
		"flee": false, "sealed": false, "modifications": [],
	}
	return {
		"state": state,
		"catalog": catalog,
		"current_node": {"id": "beast_swarm_pass"},
		"meta": null,
	}


func test_group1_ledger_projection_is_same_source() -> void:
	var ledger := Battle2TurnEngineScript.new_turn(5)
	ledger = Battle2TurnEngineScript.consume(ledger, 2)
	ledger = Battle2TurnEngineScript.enact(ledger,
			{"kind": "activate_gu", "instance_id": "gu_001", "thought": 1})["ledger"]
	var ctrl := _controller()
	ctrl["state"].battle2_ledger = ledger
	var snap := RunSnapshotBuilderScript.transparency_v2(ctrl)
	var group: Dictionary = snap["group1_gu_ledger"]
	assert_true(bool(group["active"]))
	assert_eq(int(group["thoughts_left"]), int(ledger["thoughts_left"]))
	assert_eq(int(group["thought_used"]), int(ledger["thought_used"]))
	assert_eq(int(group["reserved"]), int(ledger["reserved"]))
	assert_true(bool(group["gu_used"].get("gu_001", false)))
	assert_eq(str(group["phase"]), str(ledger["phase"]))


func test_group1_absent_battle_projects_inactive_not_faked() -> void:
	var ctrl := _controller()
	ctrl["state"].battle2_ledger = {}
	var snap := RunSnapshotBuilderScript.transparency_v2(ctrl)
	var group: Dictionary = snap["group1_gu_ledger"]
	assert_false(bool(group["active"]), "no battle must project inactive, not a fresh turn")
	assert_eq(int(group["thoughts_left"]), 0)
	assert_eq(str(group["phase"]), "")
	assert_true((group["gu_used"] as Dictionary).is_empty())
	assert_true((group["ongoing"] as Array).is_empty())


func test_group2_core_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group2_core"]
	assert_eq(str(group["depth"]),
			str(CoreGuRulesScript.core_depth(catalog["gu_by_id"]["small_light_gu"], catalog)))
	assert_true(group["tilt_suggestions"] is Dictionary)
	assert_true(group["hub_evidence"] is Dictionary)


func test_group3_recipe_projection_is_same_source() -> void:
	# The 802-gu rebuild curates recipes to the advance/fixed/free_mix model,
	# so identity/tag demo recipes are no longer shipped as data. Inject them
	# as local fixtures into a catalog copy so the group-3 projection branch
	# (identity_requirements / candidate_pool) stays same-source tested.
	var cat: Dictionary = catalog.duplicate(true)
	var identity_recipe := _identity_fixture()
	var tag_recipe := _tag_fixture()
	for recipe in [identity_recipe, tag_recipe]:
		(cat["refinement_recipes"] as Array).append(recipe)
		cat["refinement_by_id"][str(recipe["id"])] = recipe
	var ctrl := _controller()
	ctrl["catalog"] = cat
	var snap := RunSnapshotBuilderScript.transparency_v2(ctrl)
	var group: Array = snap["group3_recipes"]
	var found_identity := false
	var found_pool := false
	for entry in group:
		var recipe_id := str(entry["id"])
		if recipe_id == "essence_thorn_identity":
			found_identity = true
			assert_eq(str(entry["identity_requirements"]),
					str(identity_recipe["identity_requirements"]))
			assert_false(entry.has("candidate_pool"),
				"identity recipes carry no candidate pool")
		if recipe_id == "tagged_moon_candidates":
			found_pool = true
			assert_eq(str(entry["candidate_pool"]),
					str(RecipeRulesScript.resolve_candidates(tag_recipe, cat)))
	assert_true(found_identity and found_pool, str(group))


func test_group4_feeding_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group4_feeding"]
	var state: RunState = _controller()["state"]
	var direct := FeedingRulesScript.preview_settle(
			[state.gu_instances["gu_001"]], state.materials, {}, catalog)
	assert_eq(str(group["preview"]), str(direct))
	assert_true(group["budget_report"] is Dictionary)


func test_group5_market_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group5_market"]
	assert_almost_eq(float(group["t1_base"]),
			float(MarketRulesScript.t1_material_base_price(catalog)), 0.0001)
	assert_almost_eq(float(group["resale_50"]),
			float(MarketRulesScript.public_resale(10.0, catalog)), 0.0001)
	assert_almost_eq(float(group["gu_public_1"]),
			float(MarketRulesScript.gu_public_price(1, catalog)), 0.0001)
	assert_eq(str(group["blood_trade_public_reason"]), "refused_public_channel")


func test_group6_body_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group6_body"]
	var state: RunState = _controller()["state"]
	var body := CultivatorRulesScript.body(state.cultivator, catalog)
	assert_almost_eq(float(group["safe_strength"]),
			float(BodyRulesScript.safe_strength(float(body["body_capacity"]))), 0.0001)
	var preflight := BodyRulesScript.strike_preflight(
			float(body["strength"]), float(body["body_capacity"]), float(state.health), catalog)
	assert_almost_eq(float(group["overload_self_damage"]),
			float(BodyRulesScript.overload_self_damage(
					float(body["strength"]), float(body["body_capacity"]), catalog)), 0.0001)
	assert_eq(bool(group["lethal_confirm_required"]), bool(preflight["lethal_confirm_required"]))


func test_group7_action_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group7_action"]
	assert_eq(str(group["conflict_order"]),
			str(ActionResolverScript.conflict_order("quick", 3, "quick", 3)))
	assert_eq(str(group["reaction_check"]["reason"]),
			str(ActionResolverScript.reaction_allowed(true, "grapple")["reason"]))
	assert_eq(str(group["distances"]),
			str(["far", "medium", "close", "touch"]))


func test_group8_soul_projection_is_same_source() -> void:
	var snap := RunSnapshotBuilderScript.transparency_v2(_controller())
	var group: Dictionary = snap["group8_soul"]
	var state: RunState = _controller()["state"]
	assert_eq(str(group["snapshot"]), str(SoulRulesScript.snapshot(state.cultivator)))
	assert_eq(str(group["composure"]), str(SoulRulesScript.composure_layers(state.cultivator, catalog)))
	assert_eq(bool(group["float_above_capacity"]),
			bool(SoulRulesScript.float_above_capacity(state.cultivator)))
	assert_eq(str(group["beast_sight"]), str(SoulRulesScript.beast_sight(state.cultivator, catalog)))


func test_builder_has_no_state_writing_path() -> void:
	# Snapshot read-only: the builder's new section must not assign into run
	# state or call any setter.
	var source: String = FileAccess.get_file_as_string("res://scripts/presentation/run_snapshot_builder.gd")
	var section := source.substr(
			source.find("static func transparency_v2"),
			maxi(0, source.length() - source.find("static func transparency_v2")))
	assert_false(section.contains("state["), "no direct state indexing writes")
	assert_false(section.contains(".set("), "no setter calls in the v2 section")
	assert_false(section.contains("controller.state ="), "no controller state assignment")


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
		"candidate_pool": ["moon_glow_gu", "moon_shadow_gu"],
		"output_gu_id": "moon_shadow_gu",
	}