extends GutTest


# Playthrough finding (night batch): plain combat nodes without npc_id could
# never start a battle — "fight" was only wired for social (npc-scoped)
# actions, so beast_swarm_pass / faction_guard_checkpoint / greedy_wanderer /
# final_boss_stand were unfightable and the game was unbeatable.
# These pins lock the generic fight path (controller-level, UI-shaped).


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")


func _combat_controller(node_id: String, enemy_kind: String) -> RunController:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	controller.state = RunState.new_run(101)
	controller.state.current_node_id = node_id
	controller.current_node = {
		"id": node_id,
		"type": "combat",
		"enemy_kind": enemy_kind,
		"choices": ["fight", "deceive", "retreat"],
	}
	controller.state.encounter_session = EncounterSessionResolverScript.start(controller.current_node)
	return controller


func _fire_fight(controller: RunController) -> Dictionary:
	var card := ActionPreviewServiceScript.find_card(controller.state, controller.current_node, "node.fight", controller.catalog)
	assert_false(card.is_empty())
	assert_true(bool(card.get("executable", false)), "node.fight preview must be executable")
	return controller.submit_command({
		"type": "action_card",
		"action_id": "node.fight",
		"state_version": int(card.get("state_version", controller.state.event_log.size())),
		"node_id": str(controller.current_node.get("id", "")),
		"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
	})


func test_plain_combat_node_fight_starts_the_battle() -> void:
	var controller := _combat_controller("faction_guard_checkpoint", "faction_guard")
	var fired := _fire_fight(controller)
	assert_eq(controller.current_view_name(), "Battle")
	assert_false(controller.current_battle.is_empty())
	assert_eq(str(controller.current_battle["enemy_kind"]), "faction_guard")
	controller.free()


func test_start_nodes_fight_starts_ridge_hound_battle() -> void:
	var controller := _combat_controller("beast_swarm_pass", "ridge_hound")
	_fire_fight(controller)
	assert_eq(controller.current_view_name(), "Battle")
	assert_eq(str(controller.current_battle["enemy_kind"]), "ridge_hound")
	controller.free()


func test_final_boss_stand_fight_is_possible() -> void:
	var controller := _combat_controller("final_boss_stand", "miasma_vein_lord")
	_fire_fight(controller)
	assert_eq(controller.current_view_name(), "Battle")
	assert_eq(str(controller.current_battle["enemy_kind"]), "miasma_vein_lord")
	controller.free()


func test_direct_choose_action_fight_reports_start_battle() -> void:
	var controller := _combat_controller("faction_guard_checkpoint", "faction_guard")
	var direct := controller.submit_command({"type": "choose_action", "action_id": "fight"})
	assert_true(bool(direct.get("start_battle", false)))
	assert_eq(controller.current_view_name(), "Battle")
	controller.free()


func test_choose_action_fight_event_is_recorded_once() -> void:
	var controller := _combat_controller("faction_guard_checkpoint", "faction_guard")
	var before := controller.state.event_log.size()
	_fire_fight(controller)
	var events := controller.state.event_log
	assert_eq(events.size(), before + 2, "session wrapper + choose_action event")
	var saw_fight_start := false
	for event in events:
		if str(event.get("reason", "")) == "node_fight_started":
			saw_fight_start = true
	assert_true(saw_fight_start)
	controller.free()