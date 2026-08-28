extends GutTest


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_small_light_gu_spends_essence_and_reveals_hidden_enemy_bonus() -> void:
	var state := RunState.new_run(101)
	var battle := _started_battle(state)
	battle["action_energy"] = 0  # isolate essence math from the base first-turn grant
	var turn := BattleResolver.take_turn(battle, {"type": "use_gu", "gu_id": "small_light_gu"}, state, catalog)
	assert_eq(turn["state"].essence, 2)
	assert_true(turn["battle"]["flags"].has("revealed"))
	assert_eq(turn["result"], "ongoing")


func test_retreat_is_available_but_costs_a_declared_resource() -> void:
	var state := RunState.new_run(101)
	state.stone = 5
	var turn := BattleResolver.take_turn(_pursuit_battle(state), {"type": "retreat"}, state, catalog)
	assert_eq(turn["result"], "retreated")
	assert_eq(turn["state"].stone, 3)
	assert_eq(turn["state"].event_log.back()["reason"], "battle_retreat_stone_cost")


func test_moonlit_trace_requires_equipped_condition_and_applies_reveal_buff() -> void:
	var state := RunState.new_run(101)
	state.gu_ids.append("trail_eye_gu")
	state.equipped_gu_ids.append("trail_eye_gu")
	state.inheritance_ids = ["moonlit_trace"]
	var turn := BattleResolver.take_turn(_started_battle(state), {"type": "use_inheritance", "move_id": "moonlit_trace"}, state, catalog)
	assert_true(turn["battle"]["flags"].has("revealed"))
	assert_eq(turn["battle"]["inheritance_uses"]["moonlit_trace"], 1)
	assert_true(turn["battle"]["flags"].has("enemy_bonus_revealed"))


func test_contest_battle_can_end_by_delaying_enemy_without_killing() -> void:
	var state := RunState.new_run(101)
	var battle := BattleResolver.start({"enemy_kind": "faction_guard", "objective": "delay", "delay_needed": 1}, state)
	var turn := BattleResolver.take_turn(battle, {"type": "use_gu", "gu_id": "small_light_gu"}, state, catalog)
	assert_true(turn["finished"])
	assert_eq(turn["result"], "victory")
	assert_eq(turn["battle"]["enemy_hp"], 2)


func test_declared_irreversible_hazard_is_only_source_of_lethal_result() -> void:
	var state := RunState.new_run(101)
	var turn := BattleResolver.take_turn(_started_battle(state), {"type": "invalid"}, state, catalog)
	assert_ne(turn["result"], "dead")


func _started_battle(state: RunState) -> Dictionary:
	return BattleResolver.start({"enemy_kind": "beast_swarm"}, state)


func _pursuit_battle(state: RunState) -> Dictionary:
	return BattleResolver.start({"enemy_kind": "greedy_wanderer", "terrain": "ridge", "pursuit": 1}, state)
