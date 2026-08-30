class_name CommandSpecRegistry
extends RefCounted


const CommandSpecScript = preload("res://scripts/domain/command_spec.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


const _SPECS := {
	"encounter.action_card": {
		"id": "encounter.action_card",
		"scope": "encounter",
		"freshness_kind": "event_log",
		"required_fields": ["action_id", "state_version", "node_id", "session_node_id"],
	},
	"battle.action_card": {
		"id": "battle.action_card",
		"scope": "battle",
		"freshness_kind": "battle_hand",
		"required_fields": ["action_id", "state_version", "expected_phase"],
	},
	"battle.turn": {
		"id": "battle.turn",
		"scope": "battle",
		"freshness_kind": "event_log",
		"required_fields": ["type", "state_version", "expected_phase"],
	},
	"battle.enemy_pre_turn": {
		"id": "battle.enemy_pre_turn",
		"scope": "battle",
		"freshness_kind": "internal",
		"required_fields": [],
	},
}


static func spec(spec_id: String) -> Dictionary:
	var entry: Dictionary = _SPECS.get(spec_id, {})
	return entry.duplicate(true)


static func all_specs() -> Dictionary:
	return _SPECS.duplicate(true)


static func preflight(
	spec_id: String,
	state: RunState,
	battle: Dictionary,
	session: Dictionary,
	command: Dictionary,
	catalog: Dictionary,
	node: Dictionary = {}
) -> Dictionary:
	var definition := spec(spec_id)
	if definition.is_empty():
		return CommandSpecScript.reject("unsupported_command_spec")
	var freshness_kind := str(definition.get("freshness_kind", ""))
	for required_value in definition.get("required_fields", []):
		var required := str(required_value)
		if not command.has(required):
			return CommandSpecScript.reject("command_context_missing", freshness_kind)
	if spec_id == "encounter.action_card":
		return _preflight_encounter(state, session, command, catalog, node)
	if spec_id == "battle.action_card":
		return _preflight_battle_card(state, battle, command, catalog)
	if spec_id == "battle.turn":
		return _preflight_battle_turn(state, battle, command)
	return CommandSpecScript.ok(freshness_kind)


static func _preflight_encounter(
	state: RunState,
	session: Dictionary,
	command: Dictionary,
	catalog: Dictionary,
	node: Dictionary
) -> Dictionary:
	var expected_version := state.event_log.size()
	var actual_version := int(command.get("state_version", -1))
	if actual_version != expected_version:
		return CommandSpecScript.reject("action_preview_stale", "event_log", expected_version, actual_version, ["刷新当前遭遇后重试。"])
	var node_id := str(state.current_node_id)
	if str(command.get("node_id", "")) != node_id or str(command.get("session_node_id", "")) != node_id:
		return CommandSpecScript.reject("encounter_context_stale", "event_log", node_id, str(command.get("node_id", "")), ["返回当前节点后重新选择行动。"])
	if not session.is_empty() and str(session.get("node_id", "")) != node_id:
		return CommandSpecScript.reject("encounter_context_stale", "event_log", node_id, str(session.get("node_id", "")), ["刷新当前遭遇后重试。"])
	if node.is_empty():
		return CommandSpecScript.reject("missing_action_node", "event_log", node_id, node_id)
	var card := ActionPreviewServiceScript.find_card(state, node, str(command.get("action_id", "")), catalog)
	if card.is_empty():
		return CommandSpecScript.reject("unknown_action_card", "event_log", expected_version, actual_version)
	var result := CommandSpecScript.ok("event_log")
	result["cost"] = card.get("cost", {}).duplicate(true)
	result["remedy_hints"] = card.get("remedy_hints", []).duplicate()
	if not bool(card.get("executable", false)):
		result["ok"] = false
		result["reason"] = "action_not_executable"
		result["remaining"] = {"block_reason": str(card.get("block_reason", ""))}
	return result


static func _preflight_battle_card(
	state: RunState,
	battle: Dictionary,
	command: Dictionary,
	catalog: Dictionary
) -> Dictionary:
	var expected_version := int(battle.get("hand_version", -1))
	var actual_version := int(command.get("state_version", -1))
	if actual_version != expected_version:
		return CommandSpecScript.reject("battle_hand_stale", "battle_hand", expected_version, actual_version, ["刷新战斗手牌后重试。"])
	var expected_phase := str(battle.get("phase", "player"))
	var actual_phase := str(command.get("expected_phase", ""))
	if actual_phase != expected_phase:
		return CommandSpecScript.reject("battle_phase_stale", "battle_hand", expected_phase, actual_phase, ["刷新当前战斗后重试。"])
	var action_id := str(command.get("action_id", ""))
	if action_id.is_empty() and not str(command.get("card_id", "")).is_empty():
		action_id = "battle.%s.%s" % [str(battle.get("battle_id", "")), str(command.get("card_id", ""))]
	var card: Dictionary = {}
	for candidate in ActionPreviewServiceScript.preview_battle_actions(battle, state, catalog):
		if str(candidate.get("id", "")) == action_id:
			card = candidate
			break
	if card.is_empty():
		return CommandSpecScript.reject("battle_action_unavailable", "battle_hand", expected_version, actual_version)
	if not bool(card.get("executable", false)):
		return _with_card_block(card, "action_not_executable", "battle_hand", expected_version, actual_version)
	var target_type := str(card.get("target_type", "none"))
	if target_type == "single_enemy":
		var target_id := str(command.get("target_id", ""))
		var valid_target_ids: Array = card.get("valid_target_ids", [])
		if target_id.is_empty() and not command.has("card_id") and valid_target_ids.size() == 1:
			target_id = str(valid_target_ids[0])
		if not valid_target_ids.has(target_id):
			return CommandSpecScript.reject("battle_target_invalid", "battle_hand", expected_version, actual_version)
	var result := CommandSpecScript.ok("battle_hand")
	result["cost"] = card.get("cost", {}).duplicate(true)
	result["remedy_hints"] = card.get("remedy_hints", []).duplicate()
	return result


static func _with_card_block(
	card: Dictionary,
	reason: String,
	freshness_kind: String,
	expected: Variant,
	actual: Variant
) -> Dictionary:
	var result := CommandSpecScript.reject(reason, freshness_kind, expected, actual, card.get("remedy_hints", []))
	result["cost"] = card.get("cost", {}).duplicate(true)
	result["remaining"] = {"block_reason": str(card.get("block_reason", ""))}
	return result


static func _preflight_battle_turn(
	_state: RunState,
	battle: Dictionary,
	command: Dictionary
) -> Dictionary:
	var expected_version := _state.event_log.size()
	var actual_version := int(command.get("state_version", -1))
	if actual_version != expected_version:
		return CommandSpecScript.reject("battle_action_stale", "event_log", expected_version, actual_version, ["刷新当前战斗后重试。"])
	var expected_phase := str(battle.get("phase", "player"))
	var actual_phase := str(command.get("expected_phase", ""))
	if actual_phase != expected_phase:
		return CommandSpecScript.reject("battle_phase_stale", "event_log", expected_phase, actual_phase, ["刷新当前战斗后重试。"])
	return CommandSpecScript.ok("event_log")
