extends GutTest


const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")


func test_fixed_run_reaches_stage_one_ledger_after_a_full_caravan_branch() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.start_new_run(101)
	assert_eq(controller.current_view_name(), "Map")
	controller.submit_command({"type": "travel", "node_id": "ridge_caravan"})
	assert_eq(controller.current_view_name(), "Shop")
	controller.submit_command({"type": "buy_gu", "offer_id": "caravan_thorn_offer"})
	controller.submit_command({"type": "leave_node"})
	controller.submit_command({"type": "travel", "node_id": "refinement_hollow"})
	controller.submit_command({"type": "choose_action", "action_id": "leave"})
	controller.submit_command({"type": "leave_node"})
	controller.submit_command({"type": "travel", "node_id": "toxic_mountain_path"})
	controller.submit_command({"type": "choose_action", "action_id": "scout"})
	controller.submit_command({"type": "leave_node"})
	controller.submit_command({"type": "travel", "node_id": "ridge_market"})
	controller.submit_command({"type": "choose_action", "action_id": "leave"})
	controller.submit_command({"type": "leave_node"})
	controller.submit_command({"type": "travel", "node_id": "stage_one_ledger"})
	assert_eq(controller.current_view_name(), "Encounter")
	assert_eq(controller.state.current_node_id, "stage_one_ledger")
	controller.free()


func test_caravan_dispute_fight_starts_a_faction_guard_battle() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.catalog = ContentCatalog.load_all()
	controller.state = RunState.new_run(101)
	controller.state.current_node_id = "caravan_missing_goods"
	controller.current_node = {
		"id": "caravan_missing_goods",
		"type": "caravan",
		"enemy_kind": "faction_guard",
		"choices": ["probe", "trade", "leave", "fight"],
	}
	controller.current_session = EncounterSessionResolverScript.start(controller.current_node)

	controller.submit_command({"type": "choose_action", "action_id": "fight", "npc_id": "caravan_steward"})

	assert_eq(controller.current_view_name(), "Battle")
	assert_eq(controller.current_battle["enemy_kind"], "faction_guard")
	controller.free()


func test_generic_battle_action_card_routes_once_and_replay_is_rejected() -> void:
	var controller := preload("res://scripts/presentation/run_controller.gd").new()
	controller.catalog = ContentCatalog.load_all()
	controller.state = RunState.new_run(101)
	controller.state.current_node_id = "caravan_missing_goods"
	controller.current_node = {
		"id": "caravan_missing_goods",
		"type": "caravan",
		"enemy_kind": "faction_guard",
		"choices": ["probe", "trade", "leave", "fight"],
	}
	controller.current_session = EncounterSessionResolverScript.start(controller.current_node)
	controller.submit_command({"type": "choose_action", "action_id": "fight", "npc_id": "caravan_steward"})

	var source_card: Dictionary = controller.current_battle["hand"][0]
	var command := {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [controller.current_battle["battle_id"], source_card["instance_id"]],
		"state_version": controller.current_battle["hand_version"],
		"expected_phase": str(controller.current_battle.get("phase", "player")),
		"node_id": str(controller.state.current_node_id),
		"session_node_id": str(controller.state.current_node_id),
	}
	var first := controller.submit_command(command)
	var discard_after_first: Array = controller.current_battle["discard_pile"].duplicate(true)
	var second := controller.submit_command(command)

	assert_true(first["accepted"])
	assert_true(discard_after_first.any(func(card): return card["instance_id"] == source_card["instance_id"]))
	assert_false(second["accepted"])
	assert_eq(second["feeds"], ["battle_hand_stale"])
	assert_eq(controller.current_battle["discard_pile"], discard_after_first)
	controller.free()
