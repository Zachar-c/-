extends GutTest


const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const BattleScript = preload("res://scripts/domain/battle_resolver.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_action_card_delegates_to_battle_resolver_and_preserves_hand_version_guard() -> void:
	var state := RunState.new_run(101)
	var battle := BattleScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var target_id := str(battle["enemies"][0]["enemy_id"])
	var command := {
		"type": "action_card",
		"action_id": "battle.basic.punch",
		"target_id": target_id,
		"state_version": int(battle["hand_version"]),
		"expected_phase": str(battle["phase"]),
	}
	var actual: Dictionary = FacadeScript.apply_turn(battle, state, command, catalog)
	var expected: Dictionary = BattleScript.apply_action_card(battle, state, command, catalog)

	assert_eq(actual["result"], expected["result"])
	assert_eq(actual["accepted"], expected["accepted"])
	assert_eq(actual["state"].to_save_data(), expected["state"].to_save_data())
	assert_eq(actual["battle"], expected["battle"])


func test_namespaced_basic_punch_keeps_event_version_semantics() -> void:
	var state := RunState.new_run(101)
	var battle := BattleScript.start({"enemy_kind": "wild_boar"}, state, catalog)
	battle["hand"] = []
	var target_id := str(battle["enemies"][0]["enemy_id"])
	var result := FacadeScript.apply_turn(battle, state, {
		"type": "action_card",
		"action_id": "battle.%s.basic.punch" % str(battle["battle_id"]),
		"card_id": "basic.punch",
		"target_id": target_id,
		"state_version": int(battle["hand_version"]),
		"expected_phase": "player",
	}, catalog)
	assert_true(bool(result["accepted"]))
	assert_eq(int(result["battle"]["enemy_hp"]), int(battle["enemy_hp"]) - 1)


func test_regular_turn_delegates_without_collapsing_event_version_and_phase_guards() -> void:
	var state := RunState.new_run(101)
	var battle := BattleScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var before := state.to_save_data()
	var hand_stale: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "action_card",
		"action_id": "battle.basic.dodge",
		"state_version": int(battle["hand_version"]) + 1,
		"expected_phase": str(battle["phase"]),
	}, catalog)
	var action_stale: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "end_turn",
		"state_version": state.event_log.size() + 1,
		"expected_phase": "player",
	}, catalog)

	assert_eq(hand_stale["result"], "ongoing")
	assert_eq(hand_stale["accepted"], false)
	assert_eq(hand_stale["feeds"], ["battle_hand_stale"])
	assert_eq(action_stale["result"], "ongoing")
	assert_eq(action_stale["accepted"], false)
	assert_eq(action_stale["feeds"], ["battle_action_stale"])
	assert_eq(state.to_save_data(), before)


func test_facade_rejects_empty_unknown_and_terminal_battle_without_events() -> void:
	var state := RunState.new_run(101)
	var before := state.to_save_data()
	var empty: Dictionary = FacadeScript.apply_turn({}, state, {"type": "end_turn"}, catalog)
	var unknown: Dictionary = FacadeScript.apply_turn({"phase": "player"}, state, {"type": "not_a_battle_command"}, catalog)
	state = state.finalize_death()
	var terminal_before := state.to_save_data()
	var terminal: Dictionary = FacadeScript.apply_turn({"phase": "player"}, state, {"type": "end_turn"}, catalog)

	assert_false(empty["accepted"])
	assert_eq(empty["feeds"], ["battle_missing"])
	assert_false(unknown["accepted"])
	assert_eq(unknown["feeds"], ["unsupported_battle_action"])
	assert_false(terminal["accepted"])
	assert_eq(terminal["feeds"], ["terminal_run"])
	assert_eq(state.to_save_data(), terminal_before)


func test_start_and_enemy_pre_turn_delegate_with_same_result_shape() -> void:
	var state := RunState.new_run(101)
	var encounter := {"enemy_kind": "beast_swarm", "first_mover": "enemy"}
	var actual_battle: Dictionary = FacadeScript.start(encounter, state, catalog)
	var expected_battle: Dictionary = BattleScript.start(encounter, state, catalog)
	assert_eq(actual_battle, expected_battle)

	var actual: Dictionary = FacadeScript.apply_enemy_pre_turn(actual_battle, state, catalog)
	var expected: Dictionary = BattleScript.apply_enemy_pre_turn(expected_battle, state, catalog)
	assert_eq(actual["result"], expected["result"])
	assert_eq(actual["feeds"], expected["feeds"])
	assert_eq(actual["state"].to_save_data(), expected["state"].to_save_data())
	assert_eq(actual["battle"], expected["battle"])


func test_facade_is_deterministic_for_same_seed_and_command_sequence() -> void:
	var first := _run_sequence(4242)
	var second := _run_sequence(4242)
	assert_eq(first, second)


func _run_sequence(seed_value: int) -> Dictionary:
	var state := RunState.new_run(seed_value)
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var target_id := str(battle["enemies"][0]["enemy_id"])
	var first: Dictionary = FacadeScript.apply_turn(battle, state, {
		"type": "action_card",
		"action_id": "battle.basic.punch",
		"target_id": target_id,
		"state_version": int(battle["hand_version"]),
		"expected_phase": str(battle["phase"]),
	}, catalog)
	return {
		"state": first["state"].to_save_data(),
		"battle": first["battle"],
		"result": first["result"],
		"feeds": first["feeds"],
	}
