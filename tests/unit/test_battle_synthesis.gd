extends "res://addons/gut/test.gd"


# S2 refine-school trait: battle-local synthesis. Fixed recipes turn
# materials into a temp card; the blind box rolls a random temp card and
# explodes into a curse on failure. Consecutive failures add a capped
# success bonus that never reaches 100 and dies with the run.


const BattleResolverScript := preload("res://scripts/domain/battle_resolver.gd")
const ContentCatalogScript := preload("res://scripts/domain/content_catalog.gd")
const CurseRegistryScript := preload("res://scripts/domain/curse_registry.gd")
const RunStateScript := preload("res://scripts/domain/run_state.gd")

const ENCOUNTER := {"enemy_kind": "neutral_stone_wanderer"}


func make_state(run_seed: int = 2026) -> RunState:
	var state := RunStateScript.new_run(run_seed, null)
	state.school = "refine"
	return state


func catalog() -> Dictionary:
	return ContentCatalogScript.load_all()


func _cards_with_definition(battle: Dictionary, definition_id: String) -> Array:
	var found: Array = []
	for card in battle.get("hand", []) + battle.get("discard_pile", []):
		if str(card.get("definition_id", "")) == definition_id:
			found.append(card)
	return found


func _log_entry(battle: Dictionary, entry_id: String) -> Dictionary:
	for entry in battle.get("log", []):
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _refine(battle: Dictionary, state: RunState, command: Dictionary) -> Dictionary:
	return BattleResolverScript.take_turn(battle, command, state, catalog())


func test_fixed_synthesis_success_grants_temp_card_and_spends_materials() -> void:
	var cat := catalog()
	var saw_success := false
	for run_seed in range(2026, 2060):
		var state := make_state(run_seed)
		state.materials["venom_sac"] = 1
		var battle := BattleResolverScript.start(ENCOUNTER, state, cat)
		var result := _refine(battle, state, {"type": "refine", "recipe_id": "battle_venom_coat"})
		if not bool(result.get("accepted", false)):
			continue
		var entry: Dictionary = _log_entry(result["battle"], "battle_synthesis")
		if not bool(entry.get("success", false)):
			continue
		saw_success = true
		assert_true(_cards_with_definition(result["battle"], "thorn_bind").size() > 0,
				"seed %d: success must place the temp card thorn_bind" % run_seed)
		assert_eq(int(result["state"].materials.get("venom_sac", 0)), 0, "seed %d: materials spent" % run_seed)
		assert_eq(int(result["state"].synthesis_fail_streak), 0, "seed %d: streak resets on success" % run_seed)
		break
	assert_true(saw_success, "expected at least one synthesis success across seeds")


func test_fixed_synthesis_failure_consumes_materials_and_raises_streak() -> void:
	var cat := catalog()
	var saw_failure := false
	for run_seed in range(2026, 2060):
		var state := make_state(run_seed)
		state.materials["venom_sac"] = 1
		var battle := BattleResolverScript.start(ENCOUNTER, state, cat)
		var result := _refine(battle, state, {"type": "refine", "recipe_id": "battle_venom_coat"})
		if not bool(result.get("accepted", false)):
			continue
		var entry: Dictionary = _log_entry(result["battle"], "battle_synthesis")
		if bool(entry.get("success", false)):
			continue
		saw_failure = true
		assert_eq(_cards_with_definition(result["battle"], "thorn_bind").size(), 0,
				"seed %d: failure must not grant the card" % run_seed)
		assert_eq(int(result["state"].materials.get("venom_sac", 0)), 0, "seed %d: materials still spent" % run_seed)
		assert_eq(int(result["state"].synthesis_fail_streak), 1, "seed %d: streak advances on failure" % run_seed)
		break
	assert_true(saw_failure, "expected at least one synthesis failure across seeds")


func test_streak_bonus_is_capped_and_never_reaches_hundred() -> void:
	var cat := catalog()
	var fresh_state := make_state(3030)
	fresh_state.materials["venom_sac"] = 1
	var fresh_battle := BattleResolverScript.start(ENCOUNTER, fresh_state, cat)
	var fresh: Dictionary = _refine(fresh_battle, fresh_state, {"type": "refine", "recipe_id": "battle_venom_coat"})
	var stacked_state := make_state(3030)
	stacked_state.materials["venom_sac"] = 1
	stacked_state.synthesis_fail_streak = 50
	var stacked_battle := BattleResolverScript.start(ENCOUNTER, stacked_state, cat)
	var stacked: Dictionary = _refine(stacked_battle, stacked_state, {"type": "refine", "recipe_id": "battle_venom_coat"})
	assert_eq(int(_log_entry(fresh["battle"], "battle_synthesis").get("chance", -1)), 60)
	assert_eq(int(_log_entry(stacked["battle"], "battle_synthesis").get("chance", -1)), 90,
			"bonus is capped at max_bonus_pct, never reaching 100")


func test_blind_synthesis_failure_gains_erosion_curse() -> void:
	var cat := catalog()
	var saw_failure := false
	for run_seed in range(2026, 2080):
		var state := make_state(run_seed)
		state.materials["beast_blood"] = 2
		state.materials["beast_bone"] = 1
		var battle := BattleResolverScript.start(ENCOUNTER, state, cat)
		var result := _refine(battle, state, {"type": "refine", "recipe_id": "battle_blind"})
		if not bool(result.get("accepted", false)):
			continue
		var entry: Dictionary = _log_entry(result["battle"], "battle_synthesis")
		if bool(entry.get("success", false)):
			continue
		saw_failure = true
		assert_gte(CurseRegistryScript.layers_of(result["state"], "gu_erosion"), 1,
				"seed %d: blind box failure must attach the erosion curse" % run_seed)
		assert_eq(int(result["state"].materials.get("beast_blood", 0)), 0, "seed %d: blind cost spent" % run_seed)
		assert_eq(int(result["state"].materials.get("beast_bone", 0)), 0, "seed %d: blind cost spent" % run_seed)
		break
	assert_true(saw_failure, "expected at least one blind failure across seeds")


func test_missing_materials_are_rejected() -> void:
	var state := make_state(7)
	var battle := BattleResolverScript.start(ENCOUNTER, state, catalog())
	var result := _refine(battle, state, {"type": "refine", "recipe_id": "battle_venom_coat"})
	assert_false(bool(result.get("accepted", false)))
	assert_true((result.get("feeds", []) as Array).has("missing_synthesis_materials"))


func test_non_refine_school_is_rejected() -> void:
	var state: RunState = RunStateScript.new_run(9, null)
	state.school = "blood"
	state.materials["venom_sac"] = 1
	var battle := BattleResolverScript.start(ENCOUNTER, state, catalog())
	var result := _refine(battle, state, {"type": "refine", "recipe_id": "battle_venom_coat"})
	assert_false(bool(result.get("accepted", false)))
	assert_true((result.get("feeds", []) as Array).has("synthesis_requires_refine_school"))


func test_unknown_recipe_is_rejected() -> void:
	var state := make_state(5)
	state.materials["venom_sac"] = 1
	var battle := BattleResolverScript.start(ENCOUNTER, state, catalog())
	var result := _refine(battle, state, {"type": "refine", "recipe_id": "no_such_recipe"})
	assert_false(bool(result.get("accepted", false)))
	assert_true((result.get("feeds", []) as Array).has("synthesis_recipe_required"))


func test_synthesis_tables_pass_catalog_validation() -> void:
	assert_eq(ContentCatalogScript.validate(catalog()), [])