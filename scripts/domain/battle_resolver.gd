class_name BattleResolver
extends RefCounted

const DeckBuilderScript = preload("res://scripts/domain/deck_builder.gd")
const SeededRngScript = preload("res://scripts/domain/rng.gd")

const BATTLE_HAND_SIZE := 2

const APTITUDE_BACKLASH_FACTORS := {
	"jia": {"health_factor": 0.60, "soul_factor": 0.50},
	"yi": {"health_factor": 0.80, "soul_factor": 0.70},
	"bing": {"health_factor": 1.00, "soul_factor": 1.00},
	"ding": {"health_factor": 1.30, "soul_factor": 1.40},
	"wu": {"health_factor": 1.60, "soul_factor": 1.80},
}

const LEGACY_ENEMIES := {
	"beast_swarm": {"hp": 3, "control": 0, "intent": {"id": "bite", "label": "兽群逼近", "damage": 1}},
	"greedy_wanderer": {"hp": 4, "control": 0, "intent": {"id": "stone_palm", "label": "掌势蓄而未发", "damage": 2}},
	"faction_guard": {"hp": 3, "control": 1, "intent": {"id": "guard_strike", "label": "守卫压步", "damage": 2}},
	"resolute_elite": {"hp": 5, "control": 2, "intent": {"id": "heavy_blow", "label": "重手蓄势", "damage": 3}},
}


static func can_retreat(terrain: String, pursuit: int, enemy_control: int) -> bool:
	return terrain in ["path", "ridge", "marsh"] and pursuit <= 1 and enemy_control <= 1


static func start(encounter: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	var requested_id := str(encounter.get("enemy_kind", "beast_swarm"))
	var enemy := _enemy_definition(requested_id, catalog)
	var enemy_id := str(enemy.get("id", requested_id))
	var intent: Dictionary = enemy.get("intent", {}).duplicate(true)
	var hp := int(encounter.get("enemy_hp", enemy.get("hp", 3)))
	var deck_generation_hash := DeckBuilderScript.deck_hash(state, catalog)
	var deck_cache := DeckBuilderScript.build_card_cache(state, catalog)
	var draw_pile := _shuffled_cards(deck_cache, _battle_rng_seed(state, 0))
	var hand: Array = []
	_draw_into_hand(draw_pile, hand, BATTLE_HAND_SIZE)
	var first_turn_energy := 0
	for relic_id in state.relic_ids:
		first_turn_energy += int(catalog.get("relic_by_id", {}).get(str(relic_id), {}).get("first_turn_energy", 0))
	return {
		"battle_id": "%d-%d" % [state.seed, state.event_log.size()],
		"deck_generation_hash": deck_generation_hash,
		"deck_cache": deck_cache.duplicate(true),
		"draw_pile": draw_pile,
		"discard_pile": [],
		"hand": hand,
		"exhausted_cards": [],
		"hand_version": 0,
		"enemy_kind": enemy_id,
		"enemy_hp": hp,
		"enemy_max_hp": hp,
		"enemy_essence": int(enemy.get("essence", 0)),
		"enemy_definition": enemy,
		"objective": str(encounter.get("objective", "defeat")),
		"delay_needed": int(encounter.get("delay_needed", 0)),
		"delay_progress": 0,
		"terrain": str(encounter.get("terrain", "path")),
		"pursuit": int(encounter.get("pursuit", state.pursuit)),
		"enemy_control": int(enemy.get("control", 0)),
		"available_gu_ids": state.refined_gu_ids.duplicate(),
		"flags": [],
		"revealed_reactions": [],
		"visible_intent": intent,
		"clues": enemy.get("clues", []).duplicate(),
		"log": [{"id": "intent_revealed", "text_key": "intent_revealed", "intent": intent.get("id", "")}],
		"inheritance_uses": {},
		"first_turn_energy": first_turn_energy,
		"turn": 1,
		"phase": "player",
		"final_blow": {},
		"active_gu_instance_ids": [],
		"active_effect_registry": {},
		"pending_kill_move_state": {},
		"context": OpenRpgAdapter.create_battle_context({"enemy_kind": enemy_id}),
	}


static func apply_action_card(battle: Dictionary, state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var next := battle.duplicate(true)
	if state.is_terminal():
		return _rejected_turn(next, state, "terminal_run")
	if int(command.get("state_version", -1)) != int(next.get("hand_version", -2)):
		return _rejected_turn(next, state, "battle_hand_stale")
	if str(next.get("phase", "player")) != "player":
		return _rejected_turn(next, state, "not_player_phase")
	var action_id := str(command.get("action_id", ""))
	if action_id == "battle.end_turn":
		return _end_turn(next, state)
	if action_id == "battle.retreat":
		return _retreat(next, state)
	var card_index := _hand_card_index(next, action_id)
	if card_index < 0:
		return _rejected_turn(next, state, "battle_action_unavailable")
	var card: Dictionary = next["hand"][card_index].duplicate(true)
	var internal := _command_for_card_instance(card, catalog)
	if internal.is_empty():
		return _rejected_turn(next, state, "battle_action_unavailable")
	next["hand"].remove_at(card_index)
	next["discard_pile"].append(card)
	next["hand_version"] = int(next["hand_version"]) + 1
	return _resolve_card_instance(next, state, card, internal, catalog)


static func _resolve_card_instance(battle: Dictionary, state: RunState, card: Dictionary, internal: Dictionary, catalog: Dictionary) -> Dictionary:
	var definition: Dictionary = catalog.get("card_by_id", {}).get(str(card.get("definition_id", "")), {})
	if definition.is_empty():
		return _rejected_turn(battle, state, "battle_action_unavailable")
	var resolved := take_turn(battle, internal, state, catalog)
	if not bool(resolved.get("accepted", false)):
		return resolved
	var next_battle: Dictionary = resolved["battle"]
	var next_state: RunState = resolved["state"]
	var feeds: Array = resolved["feeds"].duplicate()
	_apply_kill_move_sequence(next_battle, definition, card, catalog)
	if int(definition.get("duration_turns", 0)) > 0:
		_register_duration_effect(next_battle, definition, card)
	var backlash := {} if next_state.is_terminal() else _backlash_for_activation(next_battle, next_state, definition, card, catalog)
	if not backlash.is_empty():
		next_state = next_state.append_event(_event(
			next_state,
			"battle_backlash",
			{"health": next_state.health, "cultivator": next_state.cultivator},
			backlash["after"],
			str(backlash["reason"]),
			backlash["targets"]
		))
		feeds.append(str(backlash["feed"]))
	if not next_state.is_terminal() and _depleted(next_state):
		next_state = next_state.finalize_death()
	resolved["battle"] = next_battle
	resolved["state"] = next_state
	resolved["feeds"] = feeds
	return resolved


static func _depleted(state: RunState) -> bool:
	return state.health <= 0 \
		or int(state.cultivator.get("lifespan", 0)) <= 0 \
		or int(state.cultivator.get("soul", 0)) <= 0


static func take_turn(
	battle: Dictionary,
	action: Dictionary,
	state: RunState,
	catalog: Dictionary,
	_expected_state_version: int = -1,
	_expected_phase: String = ""
) -> Dictionary:
	var next := battle.duplicate(true)
	if _expected_state_version >= 0 and _expected_state_version != state.event_log.size():
		return _rejected_turn(next, state, "battle_action_stale")
	if not _expected_phase.is_empty() and _expected_phase != str(next.get("phase", "")):
		return _rejected_turn(next, state, "battle_phase_stale")
	if str(next.get("phase", "player")) != "player":
		return _rejected_turn(next, state, "not_player_phase")
	match str(action.get("type", "")):
		"use_gu": return _use_gu(next, action, state, catalog)
		"use_inheritance": return _use_inheritance(next, action, state, catalog)
		"end_turn": return _end_turn(next, state)
		"retreat": return _retreat(next, state)
		_: return _result(next, state, false, "ongoing", ["unsupported_battle_action"])


static func _hand_card_index(battle: Dictionary, action_id: String) -> int:
	var prefix := "battle.%s." % str(battle.get("battle_id", ""))
	if not action_id.begins_with(prefix):
		return -1
	var card_instance_id := action_id.trim_prefix(prefix)
	var hand: Array = battle.get("hand", [])
	for index in hand.size():
		if str(hand[index].get("instance_id", "")) == card_instance_id:
			return index
	return -1


static func _command_for_card_instance(card: Dictionary, catalog: Dictionary) -> Dictionary:
	var definition: Dictionary = catalog.get("card_by_id", {}).get(str(card.get("definition_id", "")), {})
	var source_ids: Array = card.get("source_gu_instance_ids", [])
	if definition.is_empty() or source_ids.is_empty():
		return {}
	var source_definition_ids: Array = definition.get("source_gu_ids", [])
	if source_definition_ids.is_empty():
		return {}
	return {"type": "use_gu", "gu_id": str(source_definition_ids[0]), "mode": ""}


static func _use_gu(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var gu_id := str(action.get("gu_id", ""))
	if not battle.get("available_gu_ids", []).has(gu_id) or not state.refined_gu_ids.has(gu_id):
		return _result(battle, state, false, "ongoing", ["gu_not_available"])
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
	if gu.is_empty():
		return _result(battle, state, false, "ongoing", ["unknown_gu"])
	var essence_cost := int(gu.get("essence_cost", 0))
	if state.essence < essence_cost:
		return _result(battle, state, false, "ongoing", ["insufficient_essence"])
	var after := {"essence": state.essence - essence_cost}
	var mode := str(action.get("mode", ""))
	var log_entry := {"id": "gu_used", "gu_id": gu_id, "mode": mode}
	match gu_id:
		"small_light_gu":
			_add_flag(battle, "revealed")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			log_entry["id"] = "light_reveal"
		"thorn_whip_gu":
			if mode == "bind":
				_add_flag(battle, "enemy_bound")
				log_entry["id"] = "thorn_bind"
			else:
				var reaction := _reaction_for(battle, "direct_strike")
				if not reaction.is_empty() and not _reaction_countered(battle, reaction):
					_reveal_reaction(battle, reaction)
					log_entry = {"id": str(reaction.get("id", "reaction")), "reaction": true}
				else:
					battle["enemy_hp"] = maxi(0, int(battle["enemy_hp"]) - 2)
					log_entry["id"] = "thorn_strike"
		"stone_shell_gu":
			_add_flag(battle, "guarded")
			log_entry["id"] = "stone_guard"
		"mist_step_gu":
			_add_flag(battle, "retreat_preserved")
			log_entry["id"] = "mist_step"
		"blood_moss_gu":
			after["injury"] = maxi(0, state.injury - 1)
			battle["enemy_hp"] = maxi(0, int(battle["enemy_hp"]) - 1)
			log_entry["id"] = "blood_moss_relief"
		"venom_thread_gu":
			_add_flag(battle, "enemy_slowed")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			log_entry["id"] = "venom_slow"
		"pulse_drum_gu":
			_add_flag(battle, "enemy_interrupted")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			log_entry["id"] = "pulse_interrupt"
		"shadow_veil_gu":
			_add_flag(battle, "targeting_obscured")
			log_entry["id"] = "shadow_veil"
		_:
			log_entry["id"] = "gu_no_combat_effect"
	battle["log"].append(log_entry)
	var next_state := state.append_event(_event(state, "battle_use_gu", {"essence": state.essence}, after, "battle_gu_%s" % gu_id, [gu_id]))
	return _with_objective_result(battle, next_state)


static func _use_inheritance(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var move_id := str(action.get("move_id", ""))
	var move := _available_move(move_id, state, catalog)
	if move.is_empty():
		return _result(battle, state, false, "ongoing", ["inheritance_unavailable"])
	var uses: Dictionary = battle["inheritance_uses"]
	if int(uses.get(move_id, 0)) >= int(move["battle_limit"]):
		return _result(battle, state, false, "ongoing", ["inheritance_limit"])
	uses[move_id] = int(uses.get(move_id, 0)) + 1
	_add_flag(battle, "revealed")
	_add_flag(battle, str(move["special_buff"]))
	battle["log"].append({"id": "inheritance_used", "move_id": move_id})
	var next_state := state.append_event(_event(state, "battle_use_inheritance", {}, {}, "battle_inheritance_%s" % move_id, [move_id]))
	return _with_objective_result(battle, next_state)


static func _end_turn(battle: Dictionary, state: RunState) -> Dictionary:
	var intent: Dictionary = battle.get("visible_intent", {})
	var damage := int(intent.get("damage", 0))
	if battle["flags"].has("enemy_interrupted"):
		damage = 0
		battle["flags"].erase("enemy_interrupted")
	elif battle["flags"].has("enemy_slowed"):
		damage = maxi(0, damage - 1)
	if battle["flags"].has("guarded"):
		damage = maxi(0, damage - 2)
	if battle["flags"].has("targeting_obscured"):
		damage = maxi(0, damage - 1)
	var next_health := maxi(0, state.health - damage)
	battle["turn"] = int(battle["turn"]) + 1
	battle["flags"].erase("guarded")
	battle["flags"].erase("targeting_obscured")
	battle["log"].append({"id": str(intent.get("id", "enemy_action")), "damage": damage, "source": "enemy"})
	if next_health == 0 and damage > 0:
		battle["final_blow"] = {"id": str(intent.get("id", "enemy_action")), "damage": damage}
	var next_state := state.append_event(_event(state, "battle_enemy_intent", {"health": state.health}, {"health": next_health}, "battle_enemy_%s" % str(intent.get("id", "action")), [str(intent.get("id", "action"))]))
	if next_health == 0:
		return _result(battle, next_state.finalize_death(), true, "death", ["player_dead"])
	_expire_effects(battle, "end_turn")
	if not battle.get("pending_kill_move_state", {}).is_empty():
		battle["pending_kill_move_state"] = {}
	_refill_hand_after_turn(battle, next_state)
	return _result(battle, next_state, false, "ongoing", ["enemy_intent_resolved"])


static func _shuffled_cards(cards: Array, seed: int) -> Array:
	var shuffled: Array = cards.duplicate(true)
	var rng := SeededRngScript.new(seed)
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := rng.next_index(index + 1)
		var temporary: Dictionary = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = temporary
	return shuffled


static func _battle_rng_seed(state: RunState, salt: int) -> int:
	return int(state.seed) * 1000003 + state.event_log.size() * 97 + salt * 193


static func _draw_into_hand(draw_pile: Array, hand: Array, count: int) -> void:
	for _index in count:
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())


static func _refill_hand_after_turn(battle: Dictionary, state: RunState) -> void:
	var hand: Array = battle.get("hand", [])
	var discard: Array = battle.get("discard_pile", [])
	var had_cards := not hand.is_empty()
	discard.append_array(hand)
	hand.clear()
	var draw_pile: Array = battle.get("draw_pile", [])
	while hand.size() < BATTLE_HAND_SIZE:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = _shuffled_cards(discard, _battle_rng_seed(state, int(battle.get("turn", 0)) + int(battle.get("hand_version", 0))))
			discard.clear()
		_draw_into_hand(draw_pile, hand, 1)
	battle["draw_pile"] = draw_pile
	battle["discard_pile"] = discard
	battle["hand"] = hand
	if had_cards or not hand.is_empty():
		battle["hand_version"] = int(battle.get("hand_version", 0)) + 1


static func _register_duration_effect(battle: Dictionary, definition: Dictionary, card: Dictionary) -> void:
	var registry: Dictionary = battle.get("active_effect_registry", {}).duplicate(true)
	var effect_id := "effect.%s.%d" % [str(card.get("instance_id", "")), int(battle.get("turn", 0))]
	registry[effect_id] = {
		"effect_id": effect_id,
		"source_gu_id": str(definition.get("source_gu_ids", [""])[0]),
		"source_gu_instance_ids": card.get("source_gu_instance_ids", []).duplicate(),
		"remaining_turns": int(definition.get("duration_turns", 0)),
		"tick_phase": "end_turn",
		"occupies_soul_slots": bool(definition.get("occupies_soul_slots", false)),
		"soul_occupancy_gu_ids": card.get("source_gu_instance_ids", []).duplicate(),
	}
	battle["active_effect_registry"] = registry
	_recompute_active_gu_instances(battle)


static func _expire_effects(battle: Dictionary, tick_phase: String) -> void:
	var retained := {}
	for effect_id in battle.get("active_effect_registry", {}):
		var effect: Dictionary = battle["active_effect_registry"][effect_id].duplicate(true)
		if str(effect.get("tick_phase", "")) == tick_phase:
			effect["remaining_turns"] = int(effect.get("remaining_turns", 0)) - 1
		if int(effect.get("remaining_turns", 0)) > 0:
			retained[effect_id] = effect
	battle["active_effect_registry"] = retained
	_recompute_active_gu_instances(battle)


static func _recompute_active_gu_instances(battle: Dictionary) -> void:
	var occupied: Array[String] = []
	for effect in battle.get("active_effect_registry", {}).values():
		if not bool(effect.get("occupies_soul_slots", false)):
			continue
		for source_id in effect.get("soul_occupancy_gu_ids", []):
			var instance_id := str(source_id)
			if not occupied.has(instance_id):
				occupied.append(instance_id)
	battle["active_gu_instance_ids"] = occupied


static func _apply_kill_move_sequence(battle: Dictionary, definition: Dictionary, card: Dictionary, catalog: Dictionary) -> void:
	var source_gu_ids: Array = definition.get("source_gu_ids", [])
	if source_gu_ids.is_empty():
		return
	var played_gu_id := str(source_gu_ids[0])
	var pending: Dictionary = battle.get("pending_kill_move_state", {})
	if not pending.is_empty():
		var sequence: Array = pending.get("sequence", [])
		var next_index := int(pending.get("next_sequence_index", 0))
		if next_index < sequence.size() and str(sequence[next_index]) == played_gu_id:
			next_index += 1
			if next_index >= sequence.size():
				_add_flag(battle, "kill_move_%s" % str(pending.get("move_id", "")))
				battle["pending_kill_move_state"] = {}
			else:
				pending["next_sequence_index"] = next_index
				battle["pending_kill_move_state"] = pending
			return
		battle["pending_kill_move_state"] = {}
	for move_value in catalog.get("card_by_id", {}).values():
		var move: Dictionary = move_value
		var sequence: Array = move.get("kill_move_sequence", [])
		if sequence.size() < 2 or str(sequence[0]) != played_gu_id:
			continue
		battle["pending_kill_move_state"] = {
			"move_id": str(move.get("id", "")),
			"next_sequence_index": 1,
			"source_gu_instance_ids": card.get("source_gu_instance_ids", []).duplicate(),
			"sequence": sequence.duplicate(),
			"expires_at_turn": int(battle.get("turn", 0)),
		}
		return


static func _backlash_for_activation(battle: Dictionary, state: RunState, definition: Dictionary, card: Dictionary, catalog: Dictionary) -> Dictionary:
	var health_damage := 0
	var soul_damage := 0
	var targets: Array[String] = []
	var source_gu_ids: Array = definition.get("source_gu_ids", [])
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var rank := 1
	for gu_id_value in source_gu_ids:
		var gu_id := str(gu_id_value)
		rank = maxi(rank, int(gu_by_id.get(gu_id, {}).get("rank", 1)))
		targets.append(gu_id)
	var rank_gap := maxi(0, rank - int(state.cultivator.get("reincarnation", 1)))
	if rank_gap > 0:
		var factors: Dictionary = APTITUDE_BACKLASH_FACTORS.get(str(state.cultivator.get("aptitude", "bing")), APTITUDE_BACKLASH_FACTORS["bing"])
		health_damage += ceili((1.0 + rank_gap) * float(factors["health_factor"]))
		soul_damage += ceili((1.0 + rank_gap * 2.0) * float(factors["soul_factor"]))
	var active_ids: Array = battle.get("active_gu_instance_ids", [])
	if active_ids.size() > int(state.cultivator.get("soul_control_limit", 0)):
		soul_damage += active_ids.size() - int(state.cultivator.get("soul_control_limit", 0))
		if rank_gap == 0:
			return {
				"after": {
					"cultivator": _cultivator_after_backlash(state, 0, soul_damage),
				},
				"reason": "battle_soul_backlash",
				"targets": card.get("source_gu_instance_ids", []).duplicate(),
				"feed": "soul_backlash",
			}
	if health_damage <= 0 and soul_damage <= 0:
		return {}
	return {
		"after": {
			"health": maxi(0, state.health - health_damage),
			"cultivator": _cultivator_after_backlash(state, health_damage, soul_damage),
		},
		"reason": "battle_rank_backlash" if rank_gap > 0 else "battle_soul_backlash",
		"targets": targets,
		"feed": "rank_backlash" if rank_gap > 0 else "soul_backlash",
	}


static func _cultivator_after_backlash(state: RunState, _health_damage: int, soul_damage: int) -> Dictionary:
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	cultivator["soul"] = maxi(0, int(cultivator.get("soul", 0)) - soul_damage)
	return cultivator
static func _retreat(battle: Dictionary, state: RunState) -> Dictionary:
	if not _can_retreat(battle):
		return _result(battle, state, false, "ongoing", ["retreat_blocked"])
	var cost := 0 if battle["flags"].has("retreat_preserved") else 2
	if state.stone < cost:
		return _result(battle, state, false, "ongoing", ["insufficient_stone"])
	var next_state := state.append_event(_event(state, "battle_retreat", {"stone": state.stone}, {"stone": state.stone - cost}, "battle_retreat_stone_cost", []))
	battle["log"].append({"id": "retreated"})
	return _result(battle, next_state, true, "retreated", ["retreat_success"])


static func _enemy_definition(enemy_id: String, catalog: Dictionary) -> Dictionary:
	var indexed: Dictionary = catalog.get("enemy_by_id", {})
	if indexed.has(enemy_id):
		return indexed[enemy_id].duplicate(true)
	if enemy_id == "greedy_wanderer":
		return indexed.get("neutral_stone_wanderer", {}).duplicate(true)
	if enemy_id == "beast_swarm":
		return indexed.get("ridge_hound", {}).duplicate(true)
	var legacy: Dictionary = LEGACY_ENEMIES.get(enemy_id, LEGACY_ENEMIES["beast_swarm"]).duplicate(true)
	legacy["id"] = enemy_id
	legacy["clues"] = []
	legacy["reactions"] = []
	return legacy


static func _reaction_for(battle: Dictionary, trigger: String) -> Dictionary:
	var definition: Dictionary = battle.get("enemy_definition", {})
	for reaction in definition.get("reactions", []):
		if str(reaction.get("window", "")) == "before_damage" and str(reaction.get("trigger", "")) == trigger:
			return reaction.duplicate(true)
	return {}


static func _reaction_countered(battle: Dictionary, reaction: Dictionary) -> bool:
	var counter_status := str(reaction.get("counter_status", ""))
	if counter_status == "bound":
		return battle["flags"].has("enemy_bound")
	if counter_status == "guarded":
		return battle["flags"].has("guarded")
	return false


static func _reveal_reaction(battle: Dictionary, reaction: Dictionary) -> void:
	var reaction_id := str(reaction.get("id", "reaction"))
	if not battle["revealed_reactions"].has(reaction_id):
		battle["revealed_reactions"].append(reaction_id)


static func _available_move(move_id: String, state: RunState, catalog: Dictionary) -> Dictionary:
	for move in InheritanceResolver.available_moves(state.equipped_gu_ids, state.inheritance_ids, catalog):
		if move["move_id"] == move_id:
			return move
	return {}


static func _add_flag(battle: Dictionary, flag: String) -> void:
	if not battle["flags"].has(flag):
		battle["flags"].append(flag)


static func _can_retreat(battle: Dictionary) -> bool:
	return can_retreat(str(battle["terrain"]), int(battle["pursuit"]), int(battle["enemy_control"]))


static func _with_objective_result(battle: Dictionary, state: RunState) -> Dictionary:
	if str(battle["objective"]) == "delay" and int(battle["delay_progress"]) >= int(battle["delay_needed"]):
		return _result(battle, state, true, "victory", ["objective_delayed"])
	if str(battle["objective"]) == "defeat" and int(battle["enemy_hp"]) <= 0:
		return _result(battle, state, true, "victory", ["enemy_defeated"])
	return _result(battle, state, false, "ongoing", [])


static func _event(state: RunState, action: String, before: Dictionary, after: Dictionary, reason: String, targets: Array) -> Dictionary:
	return {"stage": state.stage, "time": state.event_log.size(), "node_id": state.current_node_id, "action": action, "before": before, "after": after, "reason": reason, "source": "battle_resolver", "targets": targets}


static func _result(battle: Dictionary, state: RunState, finished: bool, result: String, feeds: Array[String]) -> Dictionary:
	return {"battle": battle, "state": state, "feeds": feeds, "finished": finished, "result": result, "accepted": true}


static func _rejected_turn(battle: Dictionary, state: RunState, feed: String) -> Dictionary:
	var result := _result(battle, state, false, "ongoing", [feed])
	result["accepted"] = false
	return result
