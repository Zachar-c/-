extends GutTest


# Spec-v4 phase-2 (T6.2): four loot kinds (§8.1), generation-only budget
# (§8.2), surviving-gu collection with deterministic remanence refinement
# (§8.3), pre-declared carrying conditions (§8.4) and world-bound release /
# destruction with declared extraction (§8.5). Acceptance #12: post-battle
# survivors are never trimmed by the budget - the two data paths are fully
# decoupled.


const LootRulesScript = preload("res://scripts/domain/loot_rules.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const GuInstanceScript = preload("res://scripts/domain/gu_instance.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalogScript.load_all()


func _instance(instance_id: String, definition_id: String, rank: int, extra: Dictionary = {}) -> Dictionary:
	var instance := GuInstanceScript.new_instance(definition_id, instance_id, catalog)
	instance["rank"] = rank
	for key in extra:
		instance[key] = extra[key]
	return instance


func test_loot_classifies_into_four_kinds() -> void:
	# §8.1: gu / material / stone / info; services and opportunities are
	# actions, not persistent loot.
	for kind in ["gu", "material", "stone", "info"]:
		assert_true(LootRulesScript.is_persistent_loot_kind(kind), kind)
	for kind in ["service", "opportunity", "transformation"]:
		assert_false(LootRulesScript.is_persistent_loot_kind(kind), kind)


func test_budget_profile_is_generation_only() -> void:
	# §8.2: the budget shapes enemies and scenes, never post-battle returns.
	var profile := LootRulesScript.budget_profile([{"rank": 3}], {}, catalog)
	assert_true(float(profile["total_budget"]) > 0.0)
	assert_eq(str(profile["scope"]), "generation_only")
	assert_false(profile.has("survivors"),
			"budget never reads the survivor set")


func test_post_battle_survivors_are_never_trimmed_by_budget() -> void:
	# Acceptance #12: whatever the budget says, every surviving gu whose
	# conditions are met is collected in full; the budget has no input pipe
	# into the collection result (decoupled data paths).
	var state: RunState = RunStateScript.new_run(11)
	var survivors: Array = [
		_instance("sur_001", "moonlight_gu", 3),
		_instance("sur_002", "stone_shell_gu", 1),
		_instance("sur_003", "ridge_hound", 2),
	]
	var collected := LootRulesScript.collect_surviving_gu(survivors, state,
			{"safe_and_time_available": true, "satisfied_conditions": {}}, catalog)
	assert_eq(collected["collected"].size(), 3,
			"full survivor accounting regardless of any budget")
	# A different budget revision must not alter the collected result.
	var rich_budget := LootRulesScript.budget_profile([{"rank": 3}], {"loot_wealth": 999}, catalog)
	assert_ne(str(rich_budget["total_budget"]), str(collected["collected"].size()))
	var again := LootRulesScript.collect_surviving_gu(survivors, state,
			{"safe_and_time_available": true, "satisfied_conditions": {}}, catalog)
	assert_eq(str(again["collected"]), str(collected["collected"]),
			"collection is budget-independent")


func test_safe_refinement_is_deterministic_and_rank_gated() -> void:
	# §8.3: with safety and time, ordinary same/lower-rank gu refine with
	# certainty (no roll, no swallowed inputs); above the cultivator's rank
	# they are held but cannot activate (true-yuan quality).
	var state: RunState = RunStateScript.new_run(11)
	var cultivator_rank := 2
	var survivors: Array = [
		_instance("sur_001", "small_light_gu", 1),
		_instance("sur_002", "moonlight_gu", 5),
	]
	var collected := LootRulesScript.collect_surviving_gu(survivors, state,
			{"safe_and_time_available": true, "cultivator_rank": cultivator_rank,
			"satisfied_conditions": {}}, catalog)
	var by_id := {}
	for entry in collected["collected"]:
		by_id[str(entry["instance_id"])] = entry
	assert_eq(str(by_id["sur_001"]["status"]), "refined")
	var high: Dictionary = by_id["sur_002"]
	assert_eq(str(high["status"]), "held_only")
	assert_false(CultivatorRulesScript.can_activate(cultivator_rank, 5),
			"a held high-rank gu is outside the quality gate")
	# Source audit: no dice anywhere in the module.
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/loot_rules.gd")
	for token in ["SeededRoll", "roll(", "rand", "randomize"]:
		assert_false(source.contains(token), "loot_rules.gd must not reference %s" % token)


func test_pre_declared_carrying_conditions_gate_collection() -> void:
	# §8.4: ferocious / loyal / parasitic / fleeing gu need their pre-declared
	# extra conditions; there is no post-battle 'it does not drop' verdict.
	var state: RunState = RunStateScript.new_run(11)
	var tricky := _instance("sur_001", "ridge_hound", 2, {"ferocity": 1})
	var collected := LootRulesScript.collect_surviving_gu([tricky], state,
			{"safe_and_time_available": true, "satisfied_conditions": {"sur_001": true}}, catalog)
	assert_true(bool(collected["collected"][0]["ok"]), str(collected))
	var unmet := LootRulesScript.collect_surviving_gu([tricky], state,
			{"safe_and_time_available": true, "satisfied_conditions": {}}, catalog)
	assert_false(bool(unmet["collected"][0]["ok"]))
	assert_eq(str(unmet["collected"][0]["reason"]), "pre_declared_condition_not_met")


func test_release_returns_public_consequences() -> void:
	# §8.5: release is a world-bound act; the consequences are stated before
	# release, a harmless gu simply escapes.
	var harmless := _instance("sur_001", "small_light_gu", 1)
	var out := LootRulesScript.release_gu(harmless, {}, catalog)
	assert_true(bool(out["released"]))
	assert_true((out["consequences"] as Array).has("escaped"))
	var loyal := _instance("sur_002", "moonlight_gu", 1, {"loyal": true})
	var loyal_out := LootRulesScript.release_gu(loyal, {}, catalog)
	assert_true((loyal_out["consequences"] as Array).has("returns_to_owner"))
	var dangerous := _instance("sur_003", "venom_thread_gu", 1, {"ferocity": 2})
	var danger_out := LootRulesScript.release_gu(dangerous, {}, catalog)
	assert_true((danger_out["consequences"] as Array).has("exposes_player"))


func test_destroy_extracts_by_declaration_not_fixed_ratio() -> void:
	# §8.5: destruction never returns a fixed proportion; extraction follows
	# the gu kind's declared death drops.
	var normal := _instance("sur_001", "small_light_gu", 1)
	var normal_out := LootRulesScript.destroy_gu(normal, "killed", "alchemy", catalog)
	assert_eq((normal_out["extracted"] as Dictionary).size(), 0,
			"no fixed ratio refund without a declared extraction")
	var tuned := catalog.duplicate(true)
	(tuned["gu_by_id"] as Dictionary)["declared_prey_gu"] = {
		"id": "declared_prey_gu", "rank": 1, "death_drops": {"beast_bone": 2}}
	var declared := _instance("sur_002", "declared_prey_gu", 1)
	var declared_out := LootRulesScript.destroy_gu(declared, "dissected", "dao", tuned)
	assert_almost_eq(float(declared_out["extracted"].get("beast_bone", 0.0)), 2.0, 0.0001,
			"a declared extraction yields its stated materials")