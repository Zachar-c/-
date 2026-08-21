class_name BattleResolver
extends RefCounted


const ENEMIES := {
	"beast_swarm": {"hp": 3, "control": 0},
	"greedy_wanderer": {"hp": 4, "control": 0},
	"faction_guard": {"hp": 3, "control": 1},
	"resolute_elite": {"hp": 5, "control": 2},
}

const GU_EFFECTS := {
	"reveal_hidden_bonus": {"flags": ["revealed"], "delay": 1},
	"mark_enemy_route": {"flags": ["enemy_route_marked"], "delay": 1},
	"heal_and_bleed": {"injury_delta": -1, "damage": 1},
	"bind_and_strike": {"flags": ["enemy_bound"], "damage": 1},
	"shift_position": {"flags": ["position_shifted"]},
	"poison_and_slow": {"flags": ["enemy_slowed"], "delay": 1},
	"guard_against_hit": {"flags": ["guarded"]},
	"obscure_targeting": {"flags": ["targeting_obscured"]},
	"interrupt_enemy": {"flags": ["enemy_interrupted"], "delay": 1},
}


static func start(encounter: Dictionary, state: RunState) -> Dictionary:
	var enemy_kind := str(encounter.get("enemy_kind", "beast_swarm"))
	var enemy: Dictionary = ENEMIES.get(enemy_kind, ENEMIES["beast_swarm"])
	var equipped_slots: Array[String] = []
	for gu_id in state.equipped_gu_ids:
		if equipped_slots.size() >= 4:
			break
		equipped_slots.append(gu_id)
	var config := {"enemy_kind": enemy_kind}
	return {
		"enemy_kind": enemy_kind,
		"enemy_hp": int(encounter.get("enemy_hp", enemy["hp"])),
		"objective": str(encounter.get("objective", "defeat")),
		"delay_needed": int(encounter.get("delay_needed", 0)),
		"delay_progress": 0,
		"terrain": str(encounter.get("terrain", "path")),
		"pursuit": int(encounter.get("pursuit", state.pursuit)),
		"enemy_control": int(encounter.get("enemy_control", enemy["control"])),
		"slots": equipped_slots,
		"flags": [],
		"inheritance_uses": {},
		"turn": 0,
		"context": OpenRpgAdapter.create_battle_context(config),
	}


static func take_turn(
	battle: Dictionary,
	action: Dictionary,
	state: RunState,
	catalog: Dictionary
) -> Dictionary:
	var next_battle := battle.duplicate(true)
	match str(action.get("type", "")):
		"use_gu":
			return _use_gu(next_battle, action, state, catalog)
		"use_inheritance":
			return _use_inheritance(next_battle, action, state, catalog)
		"retreat":
			return _retreat(next_battle, state)
		_:
			return _result(next_battle, state, false, "ongoing")


static func _use_gu(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var gu_id := str(action.get("gu_id", ""))
	if not battle["slots"].has(gu_id) or not state.equipped_gu_ids.has(gu_id):
		return _result(battle, state, false, "ongoing")
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	if not gu_by_id.has(gu_id):
		return _result(battle, state, false, "ongoing")
	var gu: Dictionary = gu_by_id[gu_id]
	var essence_cost := int(gu["essence_cost"])
	if state.essence < essence_cost:
		return _result(battle, state, false, "ongoing")
	var effect: Dictionary = GU_EFFECTS.get(str(gu["combat"]), {})
	_apply_effect(battle, effect)
	battle["turn"] = int(battle["turn"]) + 1
	var after := {"essence": state.essence - essence_cost}
	if effect.has("injury_delta"):
		after["injury"] = maxi(0, state.injury + int(effect["injury_delta"]))
	var next_state := state.append_event(_event(
		state,
		"battle_use_gu",
		{"essence": state.essence},
		after,
		"battle_gu_%s" % gu_id,
		[gu_id]
	))
	return _with_objective_result(battle, next_state)


static func _use_inheritance(
	battle: Dictionary,
	action: Dictionary,
	state: RunState,
	catalog: Dictionary
) -> Dictionary:
	var move_id := str(action.get("move_id", ""))
	var move := _available_move(move_id, state, catalog)
	if move.is_empty():
		return _result(battle, state, false, "ongoing")
	var uses: Dictionary = battle["inheritance_uses"]
	if int(uses.get(move_id, 0)) >= int(move["battle_limit"]):
		return _result(battle, state, false, "ongoing")
	uses[move_id] = int(uses.get(move_id, 0)) + 1
	_add_flag(battle, "revealed")
	_add_flag(battle, str(move["special_buff"]))
	battle["turn"] = int(battle["turn"]) + 1
	var next_state := state.append_event(_event(
		state,
		"battle_use_inheritance",
		{},
		{},
		"battle_inheritance_%s" % move_id,
		[move_id]
	))
	return _with_objective_result(battle, next_state)


static func _retreat(battle: Dictionary, state: RunState) -> Dictionary:
	if not _can_retreat(battle):
		return _result(battle, state, false, "ongoing")
	var cost := 0 if battle["flags"].has("retreat_preserved") else 2
	if state.stone < cost:
		return _result(battle, state, false, "ongoing")
	battle["turn"] = int(battle["turn"]) + 1
	var next_state := state.append_event(_event(
		state,
		"battle_retreat",
		{"stone": state.stone},
		{"stone": state.stone - cost},
		"battle_retreat_stone_cost",
		[]
	))
	return _result(battle, next_state, true, "retreated")


static func _available_move(move_id: String, state: RunState, catalog: Dictionary) -> Dictionary:
	for move in InheritanceResolver.available_moves(state.equipped_gu_ids, state.inheritance_ids, catalog):
		if move["move_id"] == move_id:
			return move
	return {}


static func _apply_effect(battle: Dictionary, effect: Dictionary) -> void:
	for flag in effect.get("flags", []):
		_add_flag(battle, str(flag))
	battle["delay_progress"] = int(battle["delay_progress"]) + int(effect.get("delay", 0))
	battle["enemy_hp"] = maxi(0, int(battle["enemy_hp"]) - int(effect.get("damage", 0)))


static func _add_flag(battle: Dictionary, flag: String) -> void:
	if not battle["flags"].has(flag):
		battle["flags"].append(flag)


static func _can_retreat(battle: Dictionary) -> bool:
	var terrain := str(battle["terrain"])
	var pursuit := int(battle["pursuit"])
	var control := int(battle["enemy_control"])
	return terrain in ["path", "ridge", "marsh"] and pursuit <= 1 and control <= 1


static func _with_objective_result(battle: Dictionary, state: RunState) -> Dictionary:
	if str(battle["objective"]) == "delay" and int(battle["delay_progress"]) >= int(battle["delay_needed"]):
		return _result(battle, state, true, "victory")
	if str(battle["objective"]) == "defeat" and int(battle["enemy_hp"]) <= 0:
		return _result(battle, state, true, "victory")
	return _result(battle, state, false, "ongoing")


static func _event(
	state: RunState,
	action: String,
	before: Dictionary,
	after: Dictionary,
	reason: String,
	targets: Array
) -> Dictionary:
	return {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": action,
		"before": before,
		"after": after,
		"reason": reason,
		"source": "battle_resolver",
		"targets": targets,
	}


static func _result(battle: Dictionary, state: RunState, finished: bool, result: String) -> Dictionary:
	return {"battle": battle, "state": state, "finished": finished, "result": result}
