extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_caravan_exchange_replaces_two_low_rank_gu_with_a_rare_gu() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids = ["small_light_gu", "trail_eye_gu", "stone_shell_gu"]
	state.gu_ids = state.refined_gu_ids.duplicate()
	var result := Resolver.apply(state, {"type": "exchange_gu", "offer_id": "caravan_mist_exchange"}, catalog)
	assert_true(result["result"]["ok"])
	assert_true(result["state"].refined_gu_ids.has("mist_step_gu"))
	assert_false(result["state"].refined_gu_ids.has("trail_eye_gu"))


func test_refinement_roll_is_determined_by_run_state_not_by_client_command() -> void:
	var state := RunState.new_run(101)
	state.refined_gu_ids = ["small_light_gu", "trail_eye_gu"]
	state.gu_ids = state.refined_gu_ids.duplicate()
	var low_roll_command := Resolver.apply(state, {"type": "refine_gu", "recipe_id": "bright_thread_risk", "roll": 1}, catalog)
	var high_roll_command := Resolver.apply(state, {"type": "refine_gu", "recipe_id": "bright_thread_risk", "roll": 99}, catalog)

	assert_true(low_roll_command["result"]["ok"])
	assert_eq(low_roll_command["state"].refined_gu_ids, high_roll_command["state"].refined_gu_ids)
	assert_eq(low_roll_command["state"].event_log.back()["reason"], high_roll_command["state"].event_log.back()["reason"])


func test_refinement_roll_uses_project_seeded_rng_sequence() -> void:
	var state := RunState.new_run(101)
	var recipe_id := "bright_thread_risk"
	var recipe_hash := 0
	for character in recipe_id:
		recipe_hash = recipe_hash * 31 + character.unicode_at(0)
	var seeded_rng := SeededRng.new(int(state.seed) * 1000003 + state.event_log.size() * 97 + recipe_hash)

	assert_eq(Resolver._refinement_roll(state, recipe_id), seeded_rng.next_index(100) + 1)


func test_cultivation_window_spends_stone_and_breaks_through_to_rank_two() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "cultivation_spring"
	var result := Resolver.apply(state, {"type": "cultivate_rank_two"}, catalog)
	assert_true(result["result"]["ok"])
	assert_eq(result["state"].cultivation, 2)
	assert_eq(result["state"].stone, 7)
	assert_eq(result["state"].essence, 20)


func test_stage_ledger_blocks_progress_until_paid_or_adjusted() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "stage_one_ledger"
	state.stone = 0
	var result := Resolver.apply(state, {"type": "settle_feeding"}, catalog)
	assert_false(result["result"]["ok"])
	assert_eq(result["result"]["reason"], "feeding_shortfall")
	assert_eq(result["state"].event_log.size(), state.event_log.size())
