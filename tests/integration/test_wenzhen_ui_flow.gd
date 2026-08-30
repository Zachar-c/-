extends GutTest


const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const ACTION_PREVIEW_SERVICE = preload("res://scripts/domain/action_preview_service.gd")


func test_hall_map_multi_enemy_battle_and_ending_flow() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(101, "force", [])
	assert_eq(controller.current_view_name(), "Map")

	_travel_to_combat(controller)
	assert_eq(controller.current_view_name(), "Battle")
	var battle_snapshot: Dictionary = controller._snapshot_for("Battle")
	assert_eq(battle_snapshot.get("enemies", []).size(), 2)

	_play_valid_target_card(controller, battle_snapshot)
	assert_eq(controller.current_view_name(), "Battle")

	_finish_battle_and_resolve_ending(controller)
	assert_eq(controller.current_view_name(), "Ending")


func _travel_to_combat(controller: RunController) -> void:
	var entered := controller.submit_command({"type": "travel", "node_id": "neutral_wanderer"})
	assert_true(bool(entered.get("ok", false)), "fixed route must enter the opening contact")
	var negotiated := controller.submit_command({
		"type": "action_card",
		"action_id": "node.negotiate",
		"state_version": controller.state.event_log.size(),
		"node_id": str(controller.current_node.get("id", "")),
		"session_node_id": str(controller.current_session.get("node_id", "")),
	})
	assert_true(bool(negotiated.get("result", {}).get("ok", false)), "opening contact action must resolve")
	var left := controller.submit_command({"type": "leave_node"})
	assert_true(bool(left.get("result", {}).get("ok", false)), "completed contact must return to the map")
	var travelled := controller.submit_command({"type": "travel", "node_id": "beast_swarm_pass"})
	assert_true(bool(travelled.get("ok", false)), "fixed route must enter the two-enemy combat")


func _play_valid_target_card(controller: RunController, snapshot: Dictionary) -> void:
	var enemies: Array = snapshot.get("enemies", [])
	var target_id := str(enemies[1].get("id", ""))
	var version_before := controller.state.event_log.size()
	var cards := ACTION_PREVIEW_SERVICE.preview_battle_actions(controller.current_battle, controller.state, controller.catalog)
	if not _has_playable_target_card(cards, target_id):
		var ended := controller.submit_command({
			"type": "end_turn",
			"state_version": controller.state.event_log.size(),
			"expected_phase": str(controller.current_battle.get("phase", "")),
		})
		assert_true(bool(ended.get("accepted", false)), "first-turn resource guard must advance through the formal end-turn command")
		snapshot = controller._snapshot_for("Battle")
		cards = ACTION_PREVIEW_SERVICE.preview_battle_actions(controller.current_battle, controller.state, controller.catalog)
	var chosen: Dictionary = {}
	for card_value in cards:
		var card: Dictionary = card_value
		if bool(card.get("executable", false)) and (card.get("valid_target_ids", []) as Array).has(target_id):
			chosen = card
			break
	assert_false(chosen.is_empty(), "battle snapshot must expose a playable card for the selected enemy")
	if chosen.is_empty():
		return
	var result := controller.submit_command({
		"type": "action_card",
		"action_id": str(chosen.get("id", "")),
		"card_id": str(chosen.get("id", "")).trim_prefix("battle.%s." % str(controller.current_battle.get("battle_id", ""))),
		"target_id": target_id,
		"state_version": int(chosen.get("state_version", -1)),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	assert_true(bool(result.get("accepted", false)), "targeted card command must be accepted")
	var after: Dictionary = controller._snapshot_for("Battle")
	var target_after := _enemy_by_id(after.get("enemies", []), target_id)
	assert_false(target_after.is_empty(), "selected enemy must remain addressable after a non-lethal card")
	assert_gt(controller.state.event_log.size(), version_before, "accepted card command must advance state version")


func _has_playable_target_card(cards: Array, target_id: String) -> bool:
	for card_value in cards:
		var card: Dictionary = card_value
		if bool(card.get("executable", false)) and (card.get("valid_target_ids", []) as Array).has(target_id):
			return true
	return false


func _finish_battle_and_resolve_ending(controller: RunController) -> void:
	var retreated := controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	assert_true(bool(retreated.get("accepted", false)), "ordinary combat must allow a formal retreat")
	assert_eq(controller.current_view_name(), "Encounter")
	var left := controller.submit_command({"type": "leave_node"})
	assert_true(bool(left.get("result", {}).get("ok", false)), "post-battle encounter must return to map")
	assert_eq(controller.current_view_name(), "Map")
	var map_commands: Dictionary = controller._build_commands("Map")
	assert_true(map_commands.has("surrender"), "map command surface must expose the protected ending route")
	map_commands["surrender"].call()


func _enemy_by_id(enemies: Array, enemy_id: String) -> Dictionary:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		if str(enemy.get("id", "")) == enemy_id:
			return enemy
	return {}
