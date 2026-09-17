extends GutTest


# V1 battle2 ledger lifecycle probe (this fix batch): the per-battle ledger
# must be created at battle start, advanced by each accepted turn through
# the controller's submit_command seam, and finalised through the
# _battle2_ledger info key on the resolved battle-exit event. The probe
# covers the vertical flow only - no rewrite of V1 battle logic.

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const EncounterSessionResolverScript = preload("res://scripts/domain/encounter_session_resolver.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var catalog: Dictionary


func before_all() -> void:
	catalog = ContentCatalogScript.load_all()


func _two_enemy_combat_controller() -> RunController:
	var controller: RunController = RunControllerScript.new()
	controller.catalog = catalog
	controller.state = RunState.new_run(2031)
	controller.state.current_node_id = "beast_swarm_pass"
	controller.current_node = {
		"id": "beast_swarm_pass",
		"type": "combat",
		"enemy_kind": "ridge_hound",
		"enemy_kinds": ["ridge_hound", "ridge_hound"],
		"layer": 1,
		"stage": "one",
		"layer_boss": 0,
		"choices": ["fight", "retreat"],
	}
	controller.state.current_node_template_id = "beast_swarm_pass"
	controller.state.current_node_layer = 1
	controller.state.encounter_session = EncounterSessionResolverScript.start(controller.current_node)
	return controller


func _fire_fight(controller: RunController) -> Dictionary:
	var card := ActionPreviewServiceScript.find_card(
		controller.state, controller.current_node, "node.fight", catalog)
	assert_false(card.is_empty(), "node.fight preview must exist on the combat node")
	assert_true(bool(card.get("executable", false)), "node.fight preview must be executable")
	return controller.submit_command({
		"type": "action_card",
		"action_id": "node.fight",
		"state_version": int(card.get("state_version", controller.state.event_log.size())),
		"node_id": str(controller.current_node.get("id", "")),
		"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
	})


func _submit_one_accepted_turn(controller: RunController) -> void:
	var version_before := controller.state.event_log.size()
	var snap: Dictionary = controller._snapshot_for("Battle")
	var executed := false
	for card_value in snap.get("hand", []):
		var card: Dictionary = card_value
		if not bool(card.get("executable", false)):
			continue
		var instance_id := str(card.get("id", "")).trim_prefix("gu.")
		var result := controller.submit_command({
			"type": "use_gu",
			"instance_id": instance_id,
			"state_version": controller.state.event_log.size(),
		})
		if bool(result.get("accepted", false)):
			executed = true
			break
	if not executed:
		var dodged := controller.submit_command({
			"type": "basic_dodge",
			"state_version": controller.state.event_log.size(),
		})
		assert_true(bool(dodged.get("accepted", false)),
			"dodge must be accepted on the two-enemy combat fixture")
	assert_gt(controller.state.event_log.size(), version_before,
		"accepted turn must append to the immutable event log")


func _retreat_out(controller: RunController) -> void:
	var retreated := controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	assert_true(bool(retreated.get("accepted", false)),
		"two-enemy combat must allow a retreat exit")


func test_battle2_ledger_lifecycle_creation_advance_finalisation() -> void:
	var controller: RunController = _two_enemy_combat_controller()
	# No battle yet -> the per-battle ledger must be empty (runtime-only field).
	assert_true(controller.state.current_battle2_ledger.is_empty(),
		"no battle in progress must mean an empty per-battle ledger")

	_fire_fight(controller)
	assert_eq(controller.current_view_name(), "Battle",
		"two-enemy combat must open the Battle screen")
	# Battle start hook: ledger sized by thought_capacity(cultivator, catalog).
	var capacity := CultivatorRulesScript.thought_capacity(controller.state.cultivator, catalog)
	assert_gt(capacity, 0, "test fixture must produce a positive thought capacity")
	var started_ledger: Dictionary = controller.state.current_battle2_ledger
	assert_false(started_ledger.is_empty(),
		"_start_battle must seed the per-battle ledger before play begins")
	assert_eq(int(started_ledger.get("thoughts_left", -1)), capacity,
		"fresh ledger's thoughts_left must equal the cultivator's thought capacity")
	assert_eq(int(started_ledger.get("thought_used", -2)), 0,
		"fresh ledger must start with zero thought usage")

	_submit_one_accepted_turn(controller)
	# Accepted turn hook: thoughts_left decremented by exactly one, thought_used
	# mirrored by the ledger convention - the state still survives the command.
	var after_turn_ledger: Dictionary = controller.state.current_battle2_ledger
	assert_false(after_turn_ledger.is_empty(),
		"the ledger must persist on RunState after an accepted turn")
	assert_eq(int(after_turn_ledger.get("thoughts_left", -1)), capacity - 1,
		"each accepted turn must spend exactly one thought on the ledger")
	assert_eq(int(after_turn_ledger.get("thought_used", -2)), 1,
		"thought_used must mirror the spend count")

	_retreat_out(controller)
	# Exit hook: the controller wrote the ledger snapshot through the
	# _battle2_ledger info key on the final battle event, then cleared the
	# per-battle handle on the surviving state.
	assert_true(controller.state.current_battle2_ledger.is_empty(),
		"the controller exit must clear the per-battle ledger handle")
	var ledger_info_found := false
	for event_value in controller.state.event_log:
		var event: Dictionary = event_value
		var info: Dictionary = event.get("info", {})
		if not info.has("_battle2_ledger"):
			continue
		var snapshot: Dictionary = info.get("_battle2_ledger", {})
		assert_false(snapshot.is_empty(),
			"the ledger snapshot must be the consumed post-turn ledger, not empty")
		assert_eq(int(snapshot.get("thought_used", -1)), 1,
			"snapshot must record the one thought spent by the accepted turn")
		ledger_info_found = true
	assert_true(ledger_info_found,
		"the final battle event must carry the ledger snapshot under _battle2_ledger")
	# Task 4: the lifecycle layer owns the close-out - exactly one battle_finished.
	var finished_events := 0
	for event_value in controller.state.event_log:
		if str((event_value as Dictionary).get("action", "")) == "battle_finished":
			finished_events += 1
	assert_eq(finished_events, 1,
		"a battle must be closed by exactly one lifecycle battle_finished event")
	controller.free()