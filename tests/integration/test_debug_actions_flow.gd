extends GutTest


# DBG1 integration: debug-written state (add_gu + set_resources) must flow
# through the formal systems — deck projection, battle turns, death
# settlement and the save round-trip — while keeping its audit trail.


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")


func test_debug_writes_survive_formal_battle_and_death_settlement() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(2026)
	var added := DebugActionsScript.apply(controller.state, controller.catalog,
			{"op": "add_gu", "definition_id": "force_gu"}, true, controller.route)
	assert_true(bool(added["ok"]), "debug add_gu accepted in a live run")
	controller.state = added["state"]
	var tuned := DebugActionsScript.apply(controller.state, controller.catalog,
			{"op": "set_resources", "stones": 40, "health": 5}, true)
	assert_true(bool(tuned["ok"]), "debug set_resources accepted in a live run")
	controller.state = tuned["state"]
	assert_true(controller.state.refined_gu_ids.has("force_gu"),
			"formal legacy projections see the debug gu")
	assert_eq(int(controller.state.stone), 40, "absolute stone write applied")
	var battle := BattleResolverScript.start(
			{"enemy_kind": "ridge_hound", "enemy_hp": 12}, controller.state, controller.catalog)
	var turned := BattleResolverScript.take_turn(
			battle, {"type": "basic_attack"}, controller.state, controller.catalog)
	assert_true(bool(turned.get("accepted", false)),
			"battle accepts actions with debug-gained cards in the deck")
	controller.state = turned["state"]
	controller.force_death_for_test("debug_probe_blow")
	assert_eq(str(controller.state.terminal_state), "dead",
			"death settlement finalizes over the debug-touched run")
	var debug_actions := []
	for entry in controller.state.event_log:
		if str(entry.get("source", "")) == "debug":
			debug_actions.append(str(entry.get("action", "")))
	assert_true(debug_actions.has("debug_add_gu"), "audit trail keeps debug_add_gu")
	assert_true(debug_actions.has("debug_set_resources"), "audit trail keeps debug_set_resources")
	var data := SaveRepositoryScript.serialize_run(controller.state, [], [])
	var loaded := SaveRepositoryScript.load_run_from_data(data)
	assert_false(loaded.is_empty(), "debug-touched run still round-trips the save repository")
	assert_eq(int(loaded["state"].gu_instances.size()), int(controller.state.gu_instances.size()),
			"saved gu instances survive the round trip")
