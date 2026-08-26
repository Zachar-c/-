extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_battle_makes_every_refined_gu_available_without_slot_cap() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids = ["small_light_gu", "thorn_whip_gu", "stone_shell_gu", "mist_step_gu", "blood_moss_gu"]
	var battle := BattleResolver.start({"enemy_kind": "greedy_wanderer"}, state)
	assert_eq(battle["available_gu_ids"], state.refined_gu_ids)


func test_deceiving_neutral_wanderer_changes_future_reward_without_battle() -> void:
	var result := Resolver.apply(RunState.new_run(101), {"type": "resolve_contact", "approach": "deceive", "node_id": "neutral_wanderer"}, catalog)
	assert_true(result["result"]["ok"])
	assert_true(result["state"].known_facts.has("wanderer_misdirected"))
	assert_eq(result["state"].stone, 14)


func test_battle_rejects_action_card_from_stale_state_version() -> void:
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, state, catalog)

	var result := BattleResolver.take_turn(battle, {"type": "end_turn"}, state, catalog, state.event_log.size() - 1)

	assert_false(result["accepted"])
	assert_eq(result["feeds"], ["battle_action_stale"])
	assert_eq(result["state"], state)


func test_battle_rejects_action_when_expected_phase_has_changed() -> void:
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "ridge_hound"}, state, catalog)
	battle["phase"] = "enemy"

	var result := BattleResolver.take_turn(battle, {"type": "end_turn"}, state, catalog, state.event_log.size(), "player")

	assert_false(result["accepted"])
	assert_eq(result["feeds"], ["battle_phase_stale"])
