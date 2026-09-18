extends GutTest


const RegistryScript = preload("res://scripts/domain/command_spec_registry.gd")
const FacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const PreviewScript = preload("res://scripts/domain/action_preview_service.gd")
const SnapshotScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const BuilderScript = preload("res://scripts/presentation/run_command_builder.gd")


var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()


func test_registry_exposes_encounter_and_battle_specs_with_distinct_freshness() -> void:
	var encounter: Dictionary = RegistryScript.spec("encounter.action_card")
	var battle_card: Dictionary = RegistryScript.spec("battle.action_card")
	var battle_turn: Dictionary = RegistryScript.spec("battle.turn")
	var enemy_pre: Dictionary = RegistryScript.spec("battle.enemy_pre_turn")

	assert_false(encounter.is_empty())
	assert_eq(encounter["freshness_kind"], "event_log")
	assert_eq(battle_card["freshness_kind"], "battle_hand")
	assert_eq(battle_turn["freshness_kind"], "event_log")
	assert_eq(enemy_pre["scope"], "battle")
	assert_true(encounter["required_fields"].has("node_id"))
	assert_true(battle_card["required_fields"].has("expected_phase"))


func test_registry_rejects_missing_context_without_mutating_state() -> void:
	var state := RunState.new_run(101)
	var before := state.to_save_data()
	var result: Dictionary = RegistryScript.preflight("encounter.action_card", state, {}, {}, {}, catalog)

	assert_false(result["ok"])
	assert_eq(result["reason"], "command_context_missing")
	assert_eq(state.to_save_data(), before)
	assert_eq(result["freshness"]["kind"], "event_log")


func test_registry_distinguishes_encounter_and_battle_stale_versions() -> void:
	var state := RunState.new_run(101)
	var encounter: Dictionary = RegistryScript.preflight("encounter.action_card", state, {}, {}, {
		"type": "action_card",
		"action_id": "node.leave",
		"state_version": state.event_log.size() + 1,
		"node_id": state.current_node_id,
		"session_node_id": state.current_node_id,
	}, catalog)

	assert_false(encounter["ok"])
	assert_eq(encounter["reason"], "action_preview_stale")
	assert_eq(encounter["freshness"]["expected"], state.event_log.size())


## V1（2026-08-30 全量替换）：战斗命令不再走 CommandSpecRegistry 的新鲜度
## 预检（蛊行动制无手牌版本号），旧 battle_hand/battle_action_stale 语义废除。
func test_battle_facade_does_not_require_freshness_for_v1_turn() -> void:
	var state := RunState.new_run(101)
	var before := state.to_save_data()
	var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
	var result: Dictionary = FacadeScript.apply_turn(battle, state, {"type": "end_turn"}, catalog)

	assert_eq(result["result"], "ongoing")
	assert_eq(state.to_save_data(), before)


func test_encounter_snapshot_preserves_command_context_and_builder_forwards_it() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "cultivation_spring"
	var controller: RunController = preload("res://scripts/presentation/run_controller.gd").new()
	controller.state = state
	controller.catalog = catalog
	controller.current_node = {"id": "cultivation_spring", "type": "cultivation"}
	controller.state.encounter_session = {"node_id": "cultivation_spring"}
	var snapshot: Dictionary = SnapshotScript.encounter(controller)
	var found := false
	for action in snapshot["actions"]:
		if str(action.get("id", "")) != "node.meditate":
			continue
		found = true
		assert_true(action.has("command"))
		assert_eq(action["state_version"], state.event_log.size())
		assert_eq(action["node_id"], state.current_node_id)
		assert_eq(action["session_node_id"], "cultivation_spring")
	assert_true(found)

	var command: Dictionary = BuilderScript._encounter_action_command(controller, "node.meditate")
	assert_eq(command["type"], "action_card")
	assert_eq(command["state_version"], state.event_log.size())
	assert_eq(command["node_id"], state.current_node_id)
	assert_eq(command["session_node_id"], "cultivation_spring")
	controller.free()


func test_preview_card_command_carries_encounter_context_for_direct_submission() -> void:
	var state := RunState.new_run(101)
	state.current_node_id = "cultivation_spring"
	var node := {"id": "cultivation_spring", "type": "cultivation", "choices": ["meditate", "leave"]}
	var started: Dictionary = EncounterSessionResolver.begin(state, node, catalog)
	state = started["state"]
	var cards: Array[Dictionary] = PreviewScript.preview_actions(state, node, catalog)
	var meditate: Dictionary = {}
	for card in cards:
		if str(card.get("id", "")) == "node.meditate":
			meditate = card
			break
	assert_false(meditate.is_empty())
	var command: Dictionary = meditate["command"].duplicate(true)
	command["action_id"] = str(meditate["id"])
	command["type"] = "action_card"
	var result: Dictionary = EncounterSessionResolver.apply(state, started["session"], command, catalog, node)
	assert_true(result["result"]["ok"], str(result["result"]))


func _controller_stub(state: RunState, node: Dictionary) -> Dictionary:
	return {
		"state": state,
		"current_node": node,
		"catalog": catalog,
	}

