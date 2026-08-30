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

	# V1（2026-08-30 全量替换）：战斗蛊行动制，无手牌/弃牌堆。
	var instance_id := str(controller.current_battle["gu_slots"][0]["instance_id"])
	var first := controller.submit_command({"type": "use_gu", "instance_id": instance_id})
	var second := controller.submit_command({"type": "use_gu", "instance_id": instance_id})

	assert_eq(first["result"], "ongoing")
	assert_eq(first["feeds"], [])
	# 同回合同一蛊只能释放一次（usedThisTurn）。
	assert_eq(second["result"], "rejected")
	assert_eq(second["feeds"], ["gu_used_this_turn"])
	controller.free()
