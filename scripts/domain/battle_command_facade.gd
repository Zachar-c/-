class_name BattleCommandFacade
extends RefCounted


const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const CommandSpecRegistryScript = preload("res://scripts/domain/command_spec_registry.gd")


const BATTLE_COMMAND_TYPES := [
	"use_gu",
	"use_inheritance",
	"end_turn",
	"retreat",
	"basic_attack",
	"basic_dodge",
	"refine",
]


static func start(encounter: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	return BattleResolverScript.start(encounter, state, catalog)


static func apply_turn(battle: Dictionary, state: RunState, command: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	if battle.is_empty():
		return _rejected({}, state, "battle_missing")
	if state.is_terminal():
		return _rejected(battle, state, "terminal_run")
	var command_type := str(command.get("type", ""))
	# R3.6 hand freshener: any direct combat verb that the resolver exposes
	# through `take_turn` (basic_attack, basic_dodge, retreat, end_turn) is
	# routable through `action_card` only when the action_id carries the
	# current battle_id prefix. The canonical `battle.basic.punch` form is
	# reserved for the resolver's own dispatch so facade parity tests stay
	# exact-equivalent. Namespaced ids (`battle.<battle_id>.basic.punch` etc.)
	# are how callers like the player-view smoke can express a basic combat
	# action through the action-card envelope without losing the hand-version
	# + phase guards the resolver applies uniformly.
	if command_type == "action_card":
		var action_id := str(command.get("action_id", ""))
		var battle_id := str(battle.get("battle_id", ""))
		var passthrough_basic := ""
		if battle_id != "" and action_id == "battle.%s.basic.punch" % battle_id:
			passthrough_basic = "basic_attack"
		elif battle_id != "" and action_id == "battle.%s.basic.dodge" % battle_id:
			passthrough_basic = "basic_dodge"
		elif battle_id != "" and action_id == "battle.%s.end_turn" % battle_id:
			passthrough_basic = "end_turn"
		elif battle_id != "" and action_id == "battle.%s.retreat" % battle_id:
			passthrough_basic = "retreat"
		if passthrough_basic != "":
			var forward := command.duplicate(true)
			forward.erase("action_id")
			forward.erase("card_id")
			forward["type"] = passthrough_basic
			forward["state_version"] = state.event_log.size()
			return apply_turn(battle, state, forward, catalog)
	if command_type == "action_card":
		var card_preflight: Dictionary = CommandSpecRegistryScript.preflight("battle.action_card", state, battle, {}, command, catalog)
		if not bool(card_preflight.get("ok", false)):
			return _rejected(battle, state, str(card_preflight.get("reason", "battle_action_unavailable")), card_preflight)
		return BattleResolverScript.apply_action_card(battle, state, command, catalog)
	if BATTLE_COMMAND_TYPES.has(command_type):
		var turn_preflight: Dictionary = CommandSpecRegistryScript.preflight("battle.turn", state, battle, {}, command, catalog)
		if not bool(turn_preflight.get("ok", false)):
			return _rejected(battle, state, str(turn_preflight.get("reason", "unsupported_battle_action")), turn_preflight)
		return BattleResolverScript.take_turn(
			battle,
			command,
			state,
			catalog,
			int(command.get("state_version", -1)),
			str(command.get("expected_phase", ""))
		)
	return _rejected(battle, state, "unsupported_battle_action")


static func apply_enemy_pre_turn(battle: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	if battle.is_empty():
		return _rejected({}, state, "battle_missing")
	if state.is_terminal():
		return _rejected(battle, state, "terminal_run")
	return BattleResolverScript.apply_enemy_pre_turn(battle, state, catalog)


static func _rejected(battle: Dictionary, state: RunState, reason: String, details: Dictionary = {}) -> Dictionary:
	var result := {
		"battle": battle.duplicate(true),
		"state": state,
		"feeds": [reason],
		"finished": false,
		"result": "ongoing",
		"accepted": false,
	}
	if not details.is_empty():
		result["preflight"] = details.duplicate(true)
	return result
