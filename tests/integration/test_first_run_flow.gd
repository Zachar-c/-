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

	# V1 契约（无牌库/手牌/弃牌——禁止字段）：蛊行动按 instance_id 直催；
	# 「一回合一次」由使用权账本保证——同一蛊同一回合重复提交被拒。
	var slot: Dictionary = (controller.current_battle["gu_slots"] as Array)[0]
	var command := {
		"type": "use_gu",
		"instance_id": str(slot["instance_id"]),
		"state_version": controller.state.event_log.size(),
	}
	var first := controller.submit_command(command)
	var hp_before_fight: int = int((controller.current_battle["player"] as Dictionary)["hp"])
	var second := controller.submit_command(command)

	assert_true(bool(first.get("accepted", false)), "first use_gu must be accepted")
	# 第一发蛊已结算（敌方被打掉血或玩家动作生效）——同蛊重提不改战场。
	assert_false(bool(second.get("accepted", false)), "replayed use_gu must be rejected (used_this_turn ledger)")
	assert_eq(str(second.get("result", "")), "rejected")
	assert_true((second.get("feeds", []) as Array).size() > 0, "rejection must carry a feed reason")
	assert_eq(int((controller.current_battle["player"] as Dictionary)["hp"]), hp_before_fight, "rejected replay must not mutate the battle")
	controller.free()
