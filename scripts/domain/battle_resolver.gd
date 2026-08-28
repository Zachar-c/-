class_name BattleResolver
extends RefCounted

const DeckBuilderScript = preload("res://scripts/domain/deck_builder.gd")
const SeededRngScript = preload("res://scripts/domain/rng.gd")
const RelicHookResolverScript = preload("res://scripts/domain/relic_hook_resolver.gd")
const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const LootResolverScript = preload("res://scripts/domain/loot_resolver.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")
const SchoolRulesScript = preload("res://scripts/domain/school_rules.gd")
const ContractRulesScript = preload("res://scripts/domain/contract_rules.gd")
const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")

const BATTLE_HAND_SIZE := 2

const APTITUDE_BACKLASH_FACTORS := {
	"jia": {"health_factor": 0.60, "soul_factor": 0.50},
	"yi": {"health_factor": 0.80, "soul_factor": 0.70},
	"bing": {"health_factor": 1.00, "soul_factor": 1.00},
	"ding": {"health_factor": 1.30, "soul_factor": 1.40},
	"wu": {"health_factor": 1.60, "soul_factor": 1.80},
}

const LEGACY_ENEMIES := {
	"beast_swarm": {"hp": 3, "control": 0, "intent": {"id": "bite", "label": "兽群逼近", "damage": 1, "speed": 0}},
	"greedy_wanderer": {"hp": 4, "control": 0, "intent": {"id": "stone_palm", "label": "掌势蓄而未发", "damage": 2, "speed": 1}},
	"faction_guard": {"hp": 3, "control": 1, "intent": {"id": "guard_strike", "label": "守卫压步", "damage": 2, "speed": 1}},
	"resolute_elite": {"hp": 5, "control": 2, "intent": {"id": "heavy_blow", "label": "重手蓄势", "damage": 3, "speed": 2}},
}


static func can_retreat(terrain: String, pursuit: int, enemy_control: int) -> bool:
	return terrain in ["path", "ridge", "marsh"] and pursuit <= 1 and enemy_control <= 1


# R-boss-no-retreat 2026-08-27 user ruling: the last-layer boss stand is a
# fight-to-the-death funnel — retreating would strand the run before a window
# it can no longer reach. Boss-tier enemies (enemies.json "tier": "boss")
# close the retreat action entirely.
static func boss_blocks_retreat(battle: Dictionary) -> bool:
	for enemy in _living_enemies(battle):
		if str((enemy.get("definition", {}) as Dictionary).get("tier", "")) == "boss":
			return true
	return str((battle.get("enemy_definition", {}) as Dictionary).get("tier", "")) == "boss"


static func start(encounter: Dictionary, state: RunState, catalog: Dictionary = {}) -> Dictionary:
	# R14.5 lever 1 (night batch): the active DDA marker may swap the enemy
	# kind (never bosses/final boss) before the definition is resolved.
	var requested_kinds := _requested_enemy_kinds(encounter)
	var requested_id := str(requested_kinds[0])
	var swapped_kind := DdaResolverScript.battle_enemy_kind(state, requested_id, catalog)
	requested_kinds[0] = swapped_kind
	var encounter_turn := int(encounter.get("turn", 0))
	var enemy := _enemy_definition(swapped_kind, catalog, encounter_turn)
	var enemy_id := str(enemy.get("id", swapped_kind))
	var intent: Dictionary = enemy.get("intent", {}).duplicate(true)
	# R5.7 boss phases: optional data-driven stage list keyed by until_hp_ratio.
	# Enemies without phases keep the single-intent legacy shape untouched.
	var phases: Array = enemy.get("phases", []).duplicate(true)
	var initial_reactions: Array = enemy.get("reactions", []).duplicate(true)
	if not phases.is_empty():
		# Catalog validation intercepts bad phase tables; this guard only keeps
		# a degenerate empty intents array from indexing out of bounds.
		var initial_intents: Array = (phases[0] as Dictionary).get("intents", [])
		if not initial_intents.is_empty():
			intent = (initial_intents[0] as Dictionary).duplicate(true)
		var phase_reactions: Array = (phases[0] as Dictionary).get("reactions", [])
		if not phase_reactions.is_empty():
			initial_reactions = phase_reactions.duplicate(true)
	var hp := int(encounter.get("enemy_hp", enemy.get("hp", 3)))
	var battle_id := "%d-%d" % [state.seed, state.event_log.size()]
	var enemies := _create_enemies(battle_id, requested_kinds, encounter, catalog)
	var deck_generation_hash := DeckBuilderScript.deck_hash(state, catalog)
	var deck_cache := DeckBuilderScript.build_card_cache(state, catalog)
	# R9.x slot_seal: curses are run-scoped in RunState; battles only project
	# them at start. Sealed gu cards never enter any battle pile.
	var curse_projections := CurseRegistryScript.project_battle_curses(state, catalog)
	var sealed_definition_ids := CurseRegistryScript.sealed_definition_ids(state, curse_projections)
	var sealed_instance_ids := _sealed_instance_ids(state, sealed_definition_ids)
	if not sealed_instance_ids.is_empty():
		var playable: Array[Dictionary] = []
		for card in deck_cache:
			if not _card_is_sealed(card, sealed_instance_ids):
				playable.append(card)
		deck_cache = playable
	var draw_pile := _shuffled_cards(deck_cache, _battle_rng_seed(state, 0))
	var hand: Array = []
	var hand_size := int(catalog.get("deck", {}).get("hand_size", BATTLE_HAND_SIZE))
	_draw_into_hand(draw_pile, hand, hand_size)
	var available_gu_ids := state.refined_gu_ids.duplicate()
	for sealed_definition_id in sealed_definition_ids:
		available_gu_ids.erase(sealed_definition_id)
	# C1-min §16.13: contract aggregates are frozen at battle start; swearing
	# only happens at the trailhead so mid-battle drift is impossible.
	var contract_mods := ContractRulesScript.aggregate(state, catalog)
	var battle := {
		"battle_id": battle_id,
		"layer": clampi(int(encounter.get("layer", 1)), 1, 5),
		"enemies": enemies,
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
		"dda_swapped_from": requested_id if enemy_id != requested_id else "",
		"enemy_essence": int(enemy.get("essence", 0)),
		"enemy_definition": enemy,
		"objective": str(encounter.get("objective", "defeat")),
		"delay_needed": int(encounter.get("delay_needed", 0)),
		"delay_progress": 0,
		"terrain": str(encounter.get("terrain", "path")),
		"pursuit": int(encounter.get("pursuit", state.pursuit)),
		"enemy_control": int(enemy.get("control", 0)),
		"available_gu_ids": available_gu_ids,
		"curses": curse_projections,
		"banished_cards": [],
		"pending_curse_damage": 0,
		"sealed_gu_definition_ids": sealed_definition_ids,
		"sealed_gu_instance_ids": sealed_instance_ids,
		"soul_ops_cap": SoulCapacityScript.battle_ops_cap(state),
		"soul_ops_used": 0,
		"first_mover": str(encounter.get("first_mover", "player")),
		"blood_stacks": 0,
		"flags": [],
		"revealed_reactions": [],
		"visible_intent": intent,
		"enemy_phases": phases,
		"enemy_phase_index": 0,
		"intent_cooldowns": {},
		"enemy_reactions": initial_reactions,
		"clues": enemy.get("clues", []).duplicate(),
		"log": [{"id": "intent_revealed", "text_key": "intent_revealed", "intent": intent.get("id", "")}],
		"inheritance_uses": {},
		# Opening fairness: a base first-turn grant guarantees the player can
		# play one card even entering the fight at 0 essence (otherwise the
		# opener degenerates into meditate-and-die vs a counter-holding enemy).
		# Relic grant_first_turn_energy hooks stack on top of this base.
		"first_turn_energy": 1,
		"action_energy": 1,
		"turn": 1,
		"phase": "player",
		"final_blow": {},
		"active_gu_instance_ids": [],
		"active_effect_registry": {},
		"pending_kill_move_state": {},
		"contract_mods": contract_mods,
		"context": OpenRpgAdapter.create_battle_context({"enemy_kind": enemy_id}),
	}
	# R14.6⑦ boss-local: precompute the counter intent once (the hall toggle is
	# run-fixed); selection prioritizes it whenever the active phase pool makes
	# it eligible. Battle-scoped: dies with the dict, never hits the run state.
	var boss_counter := DdaResolverScript.boss_counter_intent(battle, state, catalog)
	if not boss_counter.is_empty():
		battle["dda_boss_counter_id"] = boss_counter
	var battle_start := RelicHookResolverScript.apply_battle_start(battle, state, catalog)
	battle = battle_start["battle"]
	# R4.x on_backlash_gained: the moment curse layers become known to this
	# battle (the projection above) fires the hook once per layer; conversion
	# queues bonus cards for the next refill draw.
	var known_curse_layers := 0
	for status_value in state.cultivator.get("statuses", {}).values():
		known_curse_layers += maxi(0, int(status_value.get("layers", 0)))
	var backlash_start := RelicHookResolverScript.apply_backlash_gained(battle, state, catalog, known_curse_layers)
	battle = backlash_start["battle"]
	# Initial draw may be enlarged by on_draw_card hooks; the extra cards are
	# drawn with the same seeded pile so the deck order stays deterministic.
	_draw_from_hooks(battle, state, catalog)
	_sync_legacy_enemy_projection(battle)
	return battle


static func _requested_enemy_kinds(encounter: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for kind_value in encounter.get("enemy_kinds", []):
		var kind := str(kind_value)
		if not kind.is_empty():
			kinds.append(kind)
	if kinds.is_empty():
		kinds.append(str(encounter.get("enemy_kind", "beast_swarm")))
	return kinds


static func _create_enemies(battle_id: String, kinds: Array[String], encounter: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	var encounter_turn := int(encounter.get("turn", 0))
	for index in kinds.size():
		var definition := _enemy_definition(str(kinds[index]), catalog, encounter_turn)
		var kind := str(definition.get("id", kinds[index]))
		var hp := int(encounter.get("enemy_hp", definition.get("hp", 3))) if index == 0 else int(definition.get("hp", 3))
		var intent: Dictionary = definition.get("intent", {}).duplicate(true)
		var phases: Array = definition.get("phases", []).duplicate(true)
		var reactions: Array = definition.get("reactions", []).duplicate(true)
		if not phases.is_empty():
			var first_phase: Dictionary = phases[0]
			var phase_intents: Array = first_phase.get("intents", [])
			if not phase_intents.is_empty():
				intent = (phase_intents[0] as Dictionary).duplicate(true)
			var phase_reactions: Array = first_phase.get("reactions", [])
			if not phase_reactions.is_empty():
				reactions = phase_reactions.duplicate(true)
		enemies.append({
			"enemy_id": "%s:e%d" % [battle_id, index],
			"kind": kind,
			"name": DisplayText.enemy(kind),
			"hp": hp,
			"max_hp": hp,
			"shield": 0,
			"statuses": {},
			"visible_intent": intent,
			"alive": hp > 0,
			"definition": definition,
			"phases": phases,
			"phase_index": 0,
			"intent_cooldowns": {},
			"reactions": reactions,
		})
	return enemies


static func _living_enemies(battle: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			out.append(enemy)
	return out


static func _sync_legacy_enemy_projection(battle: Dictionary) -> void:
	var living := _living_enemies(battle)
	var primary: Dictionary = living[0] if not living.is_empty() else (battle.get("enemies", [{}])[0] as Dictionary)
	battle["enemy_kind"] = str(primary.get("kind", battle.get("enemy_kind", "")))
	battle["enemy_hp"] = int(primary.get("hp", 0))
	battle["enemy_max_hp"] = int(primary.get("max_hp", 1))
	battle["enemy_definition"] = primary.get("definition", battle.get("enemy_definition", {})).duplicate(true)
	battle["visible_intent"] = primary.get("visible_intent", {}).duplicate(true)
	battle["enemy_phases"] = primary.get("phases", []).duplicate(true)
	battle["enemy_phase_index"] = int(primary.get("phase_index", 0))
	battle["intent_cooldowns"] = primary.get("intent_cooldowns", {}).duplicate(true)
	battle["enemy_reactions"] = primary.get("reactions", []).duplicate(true)


# Older test and tool callers still write the former scalar battle fields.
# Accept those inputs only for a genuine single-enemy battle at the domain
# boundary, then continue with `enemies` as the sole internal authority.
static func _sync_legacy_single_enemy_inputs(battle: Dictionary) -> void:
	if battle.get("enemies", []).size() != 1:
		return
	var enemy: Dictionary = battle["enemies"][0]
	if battle.has("enemy_hp"):
		enemy["hp"] = maxi(0, int(battle["enemy_hp"]))
		enemy["alive"] = int(enemy["hp"]) > 0
	if battle.has("enemy_max_hp"):
		enemy["max_hp"] = maxi(1, int(battle["enemy_max_hp"]))
	if battle.has("visible_intent"):
		enemy["visible_intent"] = (battle["visible_intent"] as Dictionary).duplicate(true)
	if battle.has("enemy_phase_index"):
		enemy["phase_index"] = int(battle["enemy_phase_index"])
	if battle.has("intent_cooldowns"):
		enemy["intent_cooldowns"] = (battle["intent_cooldowns"] as Dictionary).duplicate(true)
	if battle.has("enemy_reactions"):
		enemy["reactions"] = (battle["enemy_reactions"] as Array).duplicate(true)


static func _enemy_by_target_id(battle: Dictionary, target_id: String) -> Dictionary:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if str(enemy.get("enemy_id", "")) == target_id:
			return enemy
	return {}


static func _draw_from_hooks(battle: Dictionary, state: RunState, catalog: Dictionary) -> void:
	var result := RelicHookResolverScript.apply_draw_card(battle, state, catalog)
	var extra := int(result.get("draw_extra", 0))
	if extra <= 0:
		return
	var hand: Array = battle.get("hand", [])
	var draw_pile: Array = battle.get("draw_pile", [])
	var before := hand.size()
	for _index in extra:
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	battle["hand"] = hand
	battle["draw_pile"] = draw_pile
	if hand.size() != before:
		battle["hand_version"] = int(battle.get("hand_version", 0)) + 1


static func apply_action_card(battle: Dictionary, state: RunState, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var next := battle.duplicate(true)
	_sync_legacy_single_enemy_inputs(next)
	if state.is_terminal():
		return _rejected_turn(next, state, "terminal_run")
	if int(command.get("state_version", -1)) != int(next.get("hand_version", -2)):
		return _rejected_turn(next, state, "battle_hand_stale")
	if str(next.get("phase", "player")) != "player":
		return _rejected_turn(next, state, "not_player_phase")
	var action_id := str(command.get("action_id", ""))
	if action_id.is_empty() and not str(command.get("card_id", "")).is_empty():
		action_id = "battle.%s.%s" % [str(next.get("battle_id", "")), str(command["card_id"])]
	if action_id == "battle.end_turn":
		return _end_turn(next, state, catalog)
	if action_id == "battle.retreat":
		return _retreat(next, state, catalog)
	if action_id == "battle.basic.punch":
		var punch_target_id := str(command.get("target_id", ""))
		if not _is_living_target(next, punch_target_id):
			return _rejected_turn(next, state, "battle_target_invalid")
		return _basic_attack(next, state, catalog, punch_target_id)
	if action_id == "battle.basic.dodge":
		return _basic_dodge(next, state)
	var card_index := _hand_card_index(next, action_id)
	if card_index < 0:
		return _rejected_turn(next, state, "battle_action_unavailable")
	var card: Dictionary = next["hand"][card_index].duplicate(true)
	var internal := _command_for_card_instance(card, catalog)
	if internal.is_empty():
		return _rejected_turn(next, state, "battle_action_unavailable")
	var target_type := _target_type_for_card(card, catalog)
	var target_id := str(command.get("target_id", ""))
	if target_type == "single_enemy":
		if target_id.is_empty() and not command.has("card_id") and _living_enemies(next).size() == 1:
			target_id = str(_living_enemies(next)[0].get("enemy_id", ""))
		var target := _enemy_by_target_id(next, target_id)
		if not _is_living_target(next, target_id):
			return _rejected_turn(next, state, "battle_target_invalid")
	internal["target_id"] = target_id
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
	var play_hook := RelicHookResolverScript.apply_play_card(next_battle, next_state, catalog, definition)
	next_battle = play_hook["battle"]
	next_state = play_hook["state"]
	feeds.append_array(play_hook["feeds"])
	_apply_kill_move_sequence(next_battle, definition, card, catalog)
	if int(definition.get("duration_turns", 0)) > 0:
		_register_duration_effect(next_battle, definition, card)
	var backlash := {} if next_state.is_terminal() else _backlash_for_activation(next_battle, next_state, definition, card, catalog)
	if not backlash.is_empty():
		next_state = next_state.append_event(_event(
			next_state,
			"battle_backlash",
			# Scalar anchors only (L1 MINOR): the full cultivator deep snapshot
			# bloated every backlash event; after still lands the new cultivator.
			{
				"health": next_state.health,
				"soul": int(next_state.cultivator.get("soul", 0)),
				"curse_layers": _total_curse_layers(next_state),
			},
			backlash["after"],
			str(backlash["reason"]),
			backlash["targets"]
		))
		feeds.append(str(backlash["feed"]))
	if not next_state.is_terminal() and _depleted(next_state):
		var depleted_end := RelicHookResolverScript.apply_battle_end(next_battle, next_state, catalog)
		next_battle = depleted_end["battle"]
		next_state = depleted_end["state"].finalize_death()
		var depleted_feeds: Array[String] = depleted_end["feeds"]
		feeds.append_array(depleted_feeds)
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
	_sync_legacy_single_enemy_inputs(next)
	if _expected_state_version >= 0 and _expected_state_version != state.event_log.size():
		return _rejected_turn(next, state, "battle_action_stale")
	if not _expected_phase.is_empty() and _expected_phase != str(next.get("phase", "")):
		return _rejected_turn(next, state, "battle_phase_stale")
	if str(next.get("phase", "player")) != "player":
		return _rejected_turn(next, state, "not_player_phase")
	var out: Dictionary = {}
	match str(action.get("type", "")):
		"use_gu": out = _use_gu(next, action, state, catalog)
		"use_inheritance": out = _use_inheritance(next, action, state, catalog)
		"basic_attack": out = _basic_attack(next, state, catalog)
		"basic_dodge": out = _basic_dodge(next, state)
		"end_turn": out = _end_turn(next, state, catalog)
		"retreat": out = _retreat(next, state, catalog)
		"refine": out = _battle_refine(next, action, state, catalog)
		_: out = _result(next, state, false, "ongoing", ["unsupported_battle_action"])
	return _dda_refresh(out, catalog)


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
	return {"type": "use_gu", "gu_id": str(source_definition_ids[0]), "mode": str(definition.get("mode", ""))}


static func _target_type_for_card(card: Dictionary, catalog: Dictionary) -> String:
	var definition: Dictionary = catalog.get("card_by_id", {}).get(str(card.get("definition_id", "")), {})
	var source_gu_ids: Array = definition.get("source_gu_ids", [])
	if source_gu_ids.is_empty():
		return "none"
	var gu_id := str(source_gu_ids[0])
	if gu_id in ["small_light_gu", "thorn_whip_gu", "blood_moss_gu", "blood_droplet_gu", "blood_bat_gu", "force_gu", "moonlight_gu", "moon_glow_gu"]:
		return "single_enemy"
	for effect_value in definition.get("combat_effects", []):
		if str((effect_value as Dictionary).get("kind", "")) == "strike":
			return "single_enemy"
	return "self" if not source_gu_ids.is_empty() else "none"


static func _basic_attack(battle: Dictionary, state: RunState, catalog: Dictionary, target_id := "") -> Dictionary:
	var punch_damage := 1 + int(state.cultivator.get("force_power", 0))
	var log_entry := {"id": "basic_punch", "damage": punch_damage}
	if target_id.is_empty() and not _living_enemies(battle).is_empty():
		target_id = str(_living_enemies(battle)[0].get("enemy_id", ""))
	var reaction := _reaction_for(battle, "direct_strike", target_id)
	if not reaction.is_empty() and not _reaction_countered(battle, reaction):
		_reveal_reaction(battle, reaction, target_id)
		log_entry = {"id": str(reaction.get("id", "reaction")), "reaction": true}
	else:
		_strike(battle, punch_damage, "attack", target_id)
	battle["log"].append(log_entry)
	var next_state := state.append_event(_event(state, "battle_basic_attack", {}, {}, "battle_basic_attack", []))
	return _with_objective_result(battle, next_state, catalog)


# R9.2/R5.15 dual-channel damage. Channel "attack" keeps the historical
# behavior exactly: enemy-facing damage plus any intel weakness bonus.
# Channel "curse" ignores every mitigation layer (guarded/dodging act as the
# run's shield equivalent) and accumulates onto pending_curse_damage, which
# _settle_curse_damage writes straight onto RunState.health at end of turn.
# C1-min: strike_damage_pct scales only the attack channel, floored at >= 0;
# the intel bonus stays a flat additive on top.
static func _strike(battle: Dictionary, amount: int, channel := "attack", target_id := "") -> void:
	if channel == "curse":
		battle["pending_curse_damage"] = int(battle.get("pending_curse_damage", 0)) + amount
		return
	var pct := int(battle.get("contract_mods", {}).get("strike_damage_pct", 0))
	var scaled := maxi(0, int(floor(float(amount) * (1.0 + float(pct) / 100.0))))
	var total := int(battle.get("intel_bonus", 0)) + scaled
	if not battle.has("enemies"):
		battle["enemy_hp"] = maxi(0, int(battle.get("enemy_hp", 0)) - total)
		return
	var targets: Array = _living_enemies(battle)
	if not target_id.is_empty():
		var target := _enemy_by_target_id(battle, target_id)
		targets = [target] if not target.is_empty() else []
	for target_value in targets:
		var target: Dictionary = target_value
		target["hp"] = maxi(0, int(target.get("hp", 0)) - total)
		target["alive"] = int(target["hp"]) > 0
	_sync_legacy_enemy_projection(battle)


static func _is_living_target(battle: Dictionary, target_id: String) -> bool:
	var target := _enemy_by_target_id(battle, target_id)
	return not target.is_empty() and bool(target.get("alive", false)) and int(target.get("hp", 0)) > 0


static func _sealed_instance_ids(state: RunState, sealed_definition_ids: Array[String]) -> Array[String]:
	var instance_ids: Array[String] = []
	if sealed_definition_ids.is_empty():
		return instance_ids
	for instance in state.refined_instances():
		if sealed_definition_ids.has(str(instance.get("definition_id", ""))):
			instance_ids.append(str(instance.get("instance_id", "")))
	# Legacy projection parity with DeckBuilder._refined_instances_with_legacy_fallback.
	if instance_ids.is_empty():
		for index in state.refined_gu_ids.size():
			if sealed_definition_ids.has(str(state.refined_gu_ids[index])):
				instance_ids.append("legacy_%03d" % index)
	return instance_ids


static func _card_is_sealed(card: Dictionary, sealed_instance_ids: Array[String]) -> bool:
	for source_id_value in card.get("source_gu_instance_ids", []):
		if sealed_instance_ids.has(str(source_id_value)):
			return true
	return false


# R9.2 concrete backlash rule (the single curse-damage rule of this task):
# at end of player turn each draw_pollution curse banishes
# min(intensity, remaining pile) cards off the top of the draw pile before
# the player draws AND deals its combined intensity as player damage through
# the "curse" channel.
static func _apply_draw_pollution(battle: Dictionary) -> String:
	var pollution := CurseRegistryScript.total_intensity(battle.get("curses", []), "draw_pollution")
	if pollution <= 0:
		return ""
	var draw_pile: Array = battle.get("draw_pile", [])
	var banished: Array = battle.get("banished_cards", [])
	var removed := mini(pollution, draw_pile.size())
	for _index in removed:
		banished.append(draw_pile.pop_back())
	battle["draw_pile"] = draw_pile
	battle["banished_cards"] = banished
	_strike(battle, pollution, "curse")
	battle["log"].append({"id": "draw_pollution", "banished": removed, "damage": pollution})
	return "draw_pollution"


static func _settle_curse_damage(battle: Dictionary, state: RunState) -> RunState:
	var damage := int(battle.get("pending_curse_damage", 0))
	battle["pending_curse_damage"] = 0
	if damage <= 0:
		return state
	var next_health := maxi(0, state.health - damage)
	if next_health == 0:
		battle["final_blow"] = {"id": "backlash_curse", "damage": damage}
	battle["log"].append({"id": "backlash_curse", "damage": damage, "source": "curse"})
	return state.append_event(_event(
		state,
		"battle_curse_strike",
		{"health": state.health},
		{"health": next_health},
		"backlash_curse_damage",
		[]
	))


static func _basic_dodge(battle: Dictionary, state: RunState) -> Dictionary:
	_add_flag(battle, "dodging")
	battle["log"].append({"id": "basic_dodge"})
	var next_state := state.append_event(_event(state, "battle_basic_dodge", {}, {}, "battle_basic_dodge", []))
	return _result(battle, next_state, false, "ongoing", ["dodge_readied"])


static func _player_dodge_speed(state: RunState) -> int:
	return int(state.cultivator.get("speed", 2))


static func _use_gu(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var gu_id := str(action.get("gu_id", ""))
	var target_id := str(action.get("target_id", ""))
	if not battle.get("available_gu_ids", []).has(gu_id) or not state.refined_gu_ids.has(gu_id):
		return _result(battle, state, false, "ongoing", ["gu_not_available"])
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
	if gu.is_empty():
		return _result(battle, state, false, "ongoing", ["unknown_gu"])
	# 魂魄并发预算：每回合打出的蛊虫数受 soul_ops_cap 限制（数量取舍）。
	# 魂道超载（overchannel）豁免预算门——它由燃魂的 mercy 逻辑自行结算。
	var soul_ops_used := int(battle.get("soul_ops_used", 0))
	var overchannel_claim := SchoolRulesScript.is_soul(state) and int(action.get("overchannel", 0)) > 0
	if soul_ops_used >= int(battle.get("soul_ops_cap", 1)) and not overchannel_claim:
		return _result(battle, state, false, "ongoing", ["soul_ops_exhausted"])
	# R9.2 essence_surcharge: each intensity point beyond the free allowance
	# of 2 adds +1 to every play; unpaid plays take the existing rejection.
	# 同名蛊阶费：蛊虫每进一阶，催动消耗的真元 +1（质量取舍）。
	var rank_bonus := maxi(0, state.highest_owned_rank(gu_id) - 1)
	var surcharge := CurseRegistryScript.essence_surcharge(battle.get("curses", []))
	var essence_cost := int(gu.get("essence_cost", 0)) + surcharge + rank_bonus
	var action_energy := int(battle.get("action_energy", 0))
	if state.essence + action_energy < essence_cost:
		return _result(battle, state, false, "ongoing", ["insufficient_essence"])
	var overchannel := {}
	if SchoolRulesScript.is_soul(state):
		var oc_level := int(action.get("overchannel", 0))
		if oc_level > 0:
			overchannel = SchoolRulesScript.apply_overchannel_soul(
					state.cultivator, clampi(oc_level, 1, 3),
					not battle.get("flags", {}).has("soul_mercy_used"))
			if overchannel.is_empty():
				return _rejected_turn(battle, state, "soul_exhausted")
	var paid_from_energy := mini(essence_cost, action_energy)
	var paid_from_essence := essence_cost - paid_from_energy
	battle["action_energy"] = action_energy - paid_from_energy
	battle["soul_ops_used"] = soul_ops_used + 1
	var after := {"essence": state.essence - paid_from_essence}
	var mode := str(action.get("mode", ""))
	var log_entry := {"id": "gu_used", "gu_id": gu_id, "mode": mode}
	match gu_id:
		"small_light_gu":
			_add_flag(battle, "revealed")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			_strike(battle, 1 + rank_bonus, "attack", target_id)
			log_entry = {"id": "light_probe", "gu_id": "small_light_gu", "damage": 1 + rank_bonus}
		"thorn_whip_gu":
			if mode == "bind":
				_add_flag(battle, "enemy_bound")
				log_entry["id"] = "thorn_bind"
			else:
				var reaction := _reaction_for(battle, "direct_strike", target_id)
				if not reaction.is_empty() and not _reaction_countered(battle, reaction):
					_reveal_reaction(battle, reaction, target_id)
					log_entry = {"id": str(reaction.get("id", "reaction")), "reaction": true}
				else:
					_strike(battle, 2 + rank_bonus, "attack", target_id)
					log_entry["id"] = "thorn_strike"
		"stone_shell_gu":
			_add_flag(battle, "guarded")
			log_entry["id"] = "stone_guard"
		"mist_step_gu":
			_add_flag(battle, "retreat_preserved")
			log_entry["id"] = "mist_step"
		"blood_moss_gu":
			after["injury"] = maxi(0, state.injury - 1)
			_strike(battle, 1 + rank_bonus, "attack", target_id)
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
		"blood_droplet_gu":
			_strike(battle, 2 + rank_bonus, "attack", target_id)
			log_entry["id"] = "blood_droplet_shot"
		"blood_bat_gu":
			after["injury"] = maxi(0, state.injury - 1)
			_strike(battle, 1 + rank_bonus, "attack", target_id)
			log_entry["id"] = "blood_bat_bite"
		"blood_wing_gu":
			_add_flag(battle, "retreat_preserved")
			log_entry["id"] = "blood_wing_escape"
		"blood_farewell_gu":
			_add_flag(battle, "enemy_bound")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			log_entry["id"] = "farewell_grip"
		"force_gu":
			_strike(battle, 2 + rank_bonus, "attack", target_id)
			log_entry["id"] = "power_blow"
		"bear_strength_gu":
			after["injury"] = maxi(0, state.injury - 1)
			log_entry["id"] = "bear_vitality"
		"qi_wall_gu":
			_add_flag(battle, "guarded")
			log_entry["id"] = "qi_bulwark"
		"moonlight_gu":
			_strike(battle, 2 + rank_bonus, "attack", target_id)
			log_entry["id"] = "moonlight_strike"
		"moon_glow_gu":
			_strike(battle, 3 + rank_bonus, "attack", target_id)
			log_entry["id"] = "moon_glow_flare"
		"trail_eye_gu":
			_add_flag(battle, "revealed")
			battle["delay_progress"] = int(battle["delay_progress"]) + 1
			log_entry["id"] = "scout_eye"
		_:
			var data_effects: Array = gu.get("combat_effects", [])
			if data_effects.is_empty():
				log_entry["id"] = "gu_no_combat_effect"
			else:
				for effect_value in data_effects:
					var effect: Dictionary = effect_value
					match str(effect.get("kind", "")):
						"strike":
							_strike(battle, maxi(1, int(effect.get("amount", 1))) + rank_bonus, "attack", target_id)
						"heal_injury":
							after["injury"] = maxi(0, state.injury - maxi(1, int(effect.get("amount", 1))))
						"add_flag":
							_add_flag(battle, str(effect.get("flag", "")))
						"delay_progress":
							battle["delay_progress"] = int(battle["delay_progress"]) + maxi(0, int(effect.get("amount", 1)))
				log_entry = {"id": str(gu.get("combat", "data_pattern")), "gu_id": gu_id}
	if not overchannel.is_empty():
		var oc_level := int(action.get("overchannel", 0))
		var benefit := SchoolRulesScript.overchannel_benefit(oc_level)
		_strike(battle, int(benefit.get("damage", 0)), "attack", target_id)
		battle["pending_extra_draws"] = int(battle.get("pending_extra_draws", 0)) \
				+ int(benefit.get("draws", 0))
		if bool(benefit.get("bound", false)):
			_add_flag(battle, "enemy_bound")
		if bool(overchannel["mercy_used"]):
			_add_flag(battle, "soul_mercy_used")
			log_entry["mercy"] = true
		log_entry["overchannel"] = oc_level
		var soulful := state.cultivator.duplicate(true)
		soulful["soul"] = int(overchannel["soul"])
		after["cultivator"] = soulful
	battle["log"].append(log_entry)
	var next_state := state.append_event(_event(state, "battle_use_gu", {"essence": state.essence}, after, "battle_gu_%s" % gu_id, [gu_id]))
	return _with_objective_result(battle, next_state, catalog)


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
	return _with_objective_result(battle, next_state, catalog)


static func _battle_refine(battle: Dictionary, action: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	# S2 refine-school trait: battle-local light synthesis. Fixed recipes turn
	# materials into a temp card; the blind box rolls a random temp card and
	# explodes into a curse on failure. Consecutive failures add a capped
	# success bonus that never reaches 100 and dies with the run.
	var synthesis: Dictionary = catalog.get("synthesis", {})
	if synthesis.is_empty():
		return _rejected_turn(battle, state, "synthesis_unavailable")
	if state.school != "refine":
		return _rejected_turn(battle, state, "synthesis_requires_refine_school")
	var blind := bool(action.get("blind", false)) or str(action.get("recipe_id", "")) == "battle_blind"
	var recipe := {}
	if blind:
		recipe = synthesis.get("battle_blind", {})
	else:
		for entry_value in synthesis.get("battle_recipes", []):
			if str(entry_value.get("id", "")) == str(action.get("recipe_id", "")):
				recipe = entry_value
				break
	if recipe.is_empty():
		return _rejected_turn(battle, state, "synthesis_recipe_required")
	var cost: Dictionary = recipe.get("material_cost", {})
	if not _has_materials(state, cost):
		return _rejected_turn(battle, state, "missing_synthesis_materials")
	var cfg: Dictionary = synthesis.get("battle", {})
	var base := clampi(int(cfg.get("success_base_pct", 60)), 0, 99)
	var per_fail := maxi(1, int(cfg.get("per_fail_bonus_pct", 10)))
	var max_bonus := clampi(int(cfg.get("max_bonus_pct", 30)), 0, 99)
	var penalty := clampi(int(cfg.get("blind_penalty_pct", 20)), 0, base) if blind else 0
	var bonus := mini(int(state.synthesis_fail_streak) * per_fail, max_bonus)
	var chance := clampi(base + bonus - penalty, 0, 99)
	var roll_seed := _battle_rng_seed(state, 1213 if blind else 1109)
	var rng := SeededRngScript.new(roll_seed)
	var succeeded := rng.next_index(100) < chance
	var paid := _spend_battle_materials(state, cost)
	var streak := int(state.synthesis_fail_streak)
	var next_streak := 0 if succeeded else streak + 1
	var next_state := paid.append_event(_event(
		paid,
		"battle_synthesize",
		{"synthesis_fail_streak": int(paid.synthesis_fail_streak)},
		{"materials": paid.materials, "synthesis_fail_streak": next_streak},
		"battle_synthesis_succeeded" if succeeded else "battle_synthesis_failed",
		cost.keys() as Array
	))
	var next_battle := battle.duplicate(true)
	var temp_card_id := ""
	if succeeded:
		temp_card_id = str(recipe.get("temp_card_id", ""))
		if blind:
			var blind_pool: Array = recipe.get("blind_pool", [])
			if not blind_pool.is_empty():
				temp_card_id = str(blind_pool[rng.next_index(blind_pool.size())])
		if not temp_card_id.is_empty():
			next_battle = _gain_temp_card(next_battle, next_state, temp_card_id, catalog)
	if blind and not succeeded:
		var curse_id := str(cfg.get("blind_fail_curse_id", ""))
		if not curse_id.is_empty():
			next_state = CurseRegistryScript.gain_curse(next_state, curse_id, "battle_blind_synthesis")
	next_battle["log"].append({
		"id": "battle_synthesis",
		"kind": "blind" if blind else "fixed",
		"success": succeeded,
		"chance": chance,
		"card": temp_card_id,
	})
	return _with_objective_result(next_battle, next_state, catalog)


static func _has_materials(state: RunState, cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for material_id_value in cost:
		if int(state.materials.get(str(material_id_value), 0)) < int(cost[material_id_value]):
			return false
	return true


static func _spend_battle_materials(state: RunState, cost: Dictionary) -> RunState:
	var remaining := state.materials.duplicate(true)
	for material_id_value in cost:
		var material_id := str(material_id_value)
		remaining[material_id] = maxi(0, int(remaining.get(material_id, 0)) - int(cost[material_id_value]))
	var targets: Array = []
	for material_id_value in cost:
		targets.append(str(material_id_value))
	var next := state.append_event(_event(
		state,
		"battle_synthesize",
		{},
		{"materials": remaining},
		"battle_synthesis_materials_spent",
		targets
	))
	next.materials = remaining
	return next


static func _gain_temp_card(battle: Dictionary, state: RunState, temp_card_id: String, catalog: Dictionary) -> Dictionary:
	var hand: Array = battle.get("hand", []).duplicate()
	var discard: Array = battle.get("discard_pile", []).duplicate()
	var card := {
		"instance_id": "synth.%s.%d" % [str(temp_card_id), state.event_log.size()],
		"definition_id": temp_card_id,
		"temp": true,
	}
	var hand_size := int(catalog.get("deck", {}).get("hand_size", BATTLE_HAND_SIZE))
	if hand.size() < hand_size:
		hand.append(card)
	else:
		discard.append(card)
	var next := battle.duplicate(true)
	next["hand"] = hand
	next["discard_pile"] = discard
	next["hand_version"] = int(next.get("hand_version", 0)) + 1
	return next


static func _end_turn(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var enemy := _apply_enemy_intents(battle, state, catalog)
	var next_battle: Dictionary = enemy["battle"]
	var next_state: RunState = enemy["state"]
	# Every living enemy owns its intent cooldown and the next deterministic pick.
	for enemy_value in _living_enemies(next_battle):
		var enemy_data: Dictionary = enemy_value
		_register_enemy_intent_cooldown(enemy_data, enemy_data.get("visible_intent", {}), int(next_battle["turn"]))
	next_battle["turn"] = int(next_battle["turn"]) + 1
	for enemy_value in _living_enemies(next_battle):
		_select_enemy_intent_for(enemy_value, next_battle, next_state, int(next_battle["turn"]))
	_sync_legacy_enemy_projection(next_battle)
	next_battle["action_energy"] = 0
	next_battle["soul_ops_used"] = 0
	next_battle["flags"].erase("guarded")
	next_battle["flags"].erase("targeting_obscured")
	if bool(enemy["death"]):
		return _death_over(next_battle, next_state, catalog, ["player_dead"])
	_expire_effects(next_battle, "end_turn")
	if not next_battle.get("pending_kill_move_state", {}).is_empty():
		next_battle["pending_kill_move_state"] = {}
	var feeds: Array[String] = ["enemy_intent_resolved"]
	var pollution_feed := _apply_draw_pollution(next_battle)
	if not pollution_feed.is_empty():
		feeds.append(pollution_feed)
	next_state = _settle_curse_damage(next_battle, next_state)
	if _depleted(next_state):
		return _death_over(next_battle, next_state, catalog, ["player_dead"])
	# 收势回气：wire the previously dead cave_aperture.essence_regen_per_turn
	# into battle pacing. Without it a long fight (final boss) stalls: the
	# basic attack is swallowed by reactions and probe budget runs dry, so a
	# floor build can neither win nor retreat -- the turn loop never ends.
	var regen := maxi(0, int(next_state.cave_aperture.get("essence_regen_per_turn", 0)))
	if regen > 0:
		var regen_cap := maxi(int(next_state.essence), int(next_state.essence_capacity))
		var recovered := mini(next_state.essence + regen, regen_cap)
		if recovered != next_state.essence:
			next_state = next_state.append_event(_event(
				next_state,
				"battle_essence_regen",
				{"essence": next_state.essence},
				{"essence": recovered},
				"battle_essence_regen",
				[]
			))
	# C1-min §16.13: turn_essence_bonus grants its essence at every player
	# turn start (the transition out of end turn); turn 1 keeps battle-start
	# resources untouched so opening hand math stays stable.
	var tide := int(next_battle.get("contract_mods", {}).get("turn_essence_bonus", 0))
	if tide > 0:
		# N1 §16.13 MINOR: the tide may never push essence past the cave
		# aperture cap; overfill is silently clipped at the cap.
		var capped := mini(next_state.essence + tide, maxi(0, int(next_state.cave_aperture.get("essence_max", next_state.essence + tide))))
		next_state = next_state.append_event(_event(
			next_state,
			"contract_essence_tide",
			{"essence": next_state.essence},
			{"essence": capped},
			"contract_turn_essence",
			[]
		))
	_refill_hand_after_turn(next_battle, next_state, catalog)
	return _result(next_battle, next_state, false, "ongoing", feeds)


static func _apply_enemy_intents(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var next_battle := battle
	var next_state := state
	for enemy_value in _living_enemies(next_battle):
		var enemy: Dictionary = enemy_value
		var resolved := _apply_enemy_intent(next_battle, next_state, catalog, enemy)
		next_battle = resolved["battle"]
		next_state = resolved["state"]
		if bool(resolved["death"]):
			return {"battle": next_battle, "state": next_state, "death": true}
	return {"battle": next_battle, "state": next_state, "death": false}


static func _apply_enemy_intent(battle: Dictionary, state: RunState, catalog: Dictionary, enemy: Dictionary) -> Dictionary:
	var intent: Dictionary = enemy.get("visible_intent", {})
	# R5.7 essence_burn drains player essence directly; an interrupted intent
	# cancels both its damage and its burn.
	var burn := maxi(0, int(intent.get("essence_burn", 0)))
	var damage := int(intent.get("damage", 0))
	if battle["flags"].has("enemy_interrupted"):
		damage = 0
		burn = 0
		battle["flags"].erase("enemy_interrupted")
	elif battle["flags"].has("enemy_slowed"):
		damage = maxi(0, damage - 1)
	if battle["flags"].has("guarded"):
		damage = maxi(0, damage - 2)
	if battle["flags"].has("targeting_obscured"):
		damage = maxi(0, damage - 1)
	var dodged := false
	if battle["flags"].has("dodging"):
		battle["flags"].erase("dodging")
		if _player_dodge_speed(state) > int(intent.get("speed", 0)):
			damage = 0
			dodged = true
	var damage_hook := RelicHookResolverScript.apply_take_damage(battle, state, catalog, damage)
	battle = damage_hook["battle"]
	var next_state: RunState = damage_hook["state"]
	damage = int(damage_hook["damage"])
	# C1-min §16.13: enemy_damage_pct scales the final post-mitigation intent
	# damage (floored at >= 0), so dodge/guard reductions keep their weight.
	var enemy_pct := int(battle.get("contract_mods", {}).get("enemy_damage_pct", 0))
	if enemy_pct != 0:
		damage = maxi(0, int(floor(float(damage) * (1.0 + float(enemy_pct) / 100.0))))
	var next_health := maxi(0, next_state.health - damage)
	var log_entry := {"id": str(intent.get("id", "enemy_action")), "damage": damage, "source": "enemy", "enemy_id": str(enemy.get("enemy_id", "")), "dodged": dodged}
	var after_payload := {"health": next_health}
	if burn > 0:
		after_payload["essence"] = maxi(0, next_state.essence - burn)
		log_entry["burned"] = burn
	battle["log"].append(log_entry)
	if next_health == 0 and damage > 0:
		battle["final_blow"] = {"id": str(intent.get("id", "enemy_action")), "damage": damage}
	next_state = next_state.append_event(_event(
		next_state,
		"battle_enemy_intent",
		{"health": next_state.health, "essence": next_state.essence},
		after_payload,
		"battle_enemy_%s" % str(intent.get("id", "action")),
		[str(intent.get("id", "action"))]
	))
	return {"battle": battle, "state": next_state, "death": next_health == 0}


static func apply_enemy_pre_turn(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	var enemy := _apply_enemy_intents(battle, state, catalog)
	if bool(enemy["death"]):
		return _death_over(enemy["battle"], enemy["state"], catalog, ["player_dead"])
	return _dda_refresh(_result(enemy["battle"], enemy["state"], false, "ongoing", ["enemy_first_move"]), catalog)


# R14.6 (night batch): DDA marker lifecycle. Evaluates the run's band on the
# state this turn produced and appends a dda_marker event whenever the active
# sys: marker changes (at most one; newest replaces older — R14.6②).
# Evaluation is pure (DdaResolver); only the event append happens here.
static func _dda_refresh(out: Dictionary, catalog: Dictionary) -> Dictionary:
	if not out.has("state"):
		return out
	var next: RunState = out["state"]
	if next.is_terminal():
		return out
	var refresh := DdaResolverScript.refresh(next, catalog)
	if refresh.is_empty():
		return out
	var next_state := next.append_event(_event(
		next,
		"dda_marker",
		{"meta_rules": next.meta_rules},
		{"meta_rules": refresh["after"]},
		str(refresh["reason"]),
		[str(refresh["marker"])]
	))
	out["state"] = next_state
	return out


@warning_ignore("shadowed_global_identifier")
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
	return SeededRollScript.mixed_seed_int(int(state.seed), salt, state.event_log.size())


static func _draw_into_hand(draw_pile: Array, hand: Array, count: int) -> void:
	for _index in count:
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())


static func _refill_hand_after_turn(battle: Dictionary, state: RunState, catalog: Dictionary) -> void:
	var hand: Array = battle.get("hand", [])
	var discard: Array = battle.get("discard_pile", [])
	var had_cards := not hand.is_empty()
	discard.append_array(hand)
	hand.clear()
	var draw_pile: Array = battle.get("draw_pile", [])
	var hand_size := int(catalog.get("deck", {}).get("hand_size", BATTLE_HAND_SIZE))
	while hand.size() < hand_size:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = _shuffled_cards(discard, _battle_rng_seed(state, int(battle.get("turn", 0)) + int(battle.get("hand_version", 0))))
			discard.clear()
		_draw_into_hand(draw_pile, hand, 1)
	# R4.x convert_backlash_to_draw consumption: queued bonus cards are drawn
	# exactly once at the next refill; leftovers vanish if both piles run dry.
	var queued_extra := int(battle.get("pending_extra_draws", 0))
	battle["pending_extra_draws"] = 0
	var drawn_extra := 0
	while drawn_extra < queued_extra:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = _shuffled_cards(discard, _battle_rng_seed(state, int(battle.get("turn", 0)) + int(battle.get("hand_version", 0)) + drawn_extra))
			discard.clear()
		hand.append(draw_pile.pop_back())
		drawn_extra += 1
	battle["draw_pile"] = draw_pile
	battle["discard_pile"] = discard
	battle["hand"] = hand
	if drawn_extra > 0:
		battle["log"].append({"id": "relic_backlash_draw", "extra": drawn_extra})
		battle["hand_version"] = int(battle.get("hand_version", 0)) + 1
	if had_cards or not hand.is_empty():
		battle["hand_version"] = int(battle.get("hand_version", 0)) + 1
	_draw_from_hooks(battle, state, catalog)


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
	var ops_cap := SoulCapacityScript.battle_ops_cap(state)
	if active_ids.size() > ops_cap:
		soul_damage += active_ids.size() - ops_cap
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


static func _total_curse_layers(state: RunState) -> int:
	var layers := 0
	for status_value in state.cultivator.get("statuses", {}).values():
		layers += maxi(0, int((status_value as Dictionary).get("layers", 0)))
	return layers
static func _retreat(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	if not _can_retreat(battle):
		return _result(battle, state, false, "ongoing", ["retreat_blocked"])
	var cost := 0 if battle["flags"].has("retreat_preserved") else 2
	if state.stone < cost:
		return _result(battle, state, false, "ongoing", ["insufficient_stone"])
	var next_state := state.append_event(_event(state, "battle_retreat", {"stone": state.stone}, {"stone": state.stone - cost}, "battle_retreat_stone_cost", []))
	battle["log"].append({"id": "retreated"})
	return _battle_over(battle, next_state, catalog, true, "retreated", ["retreat_success"])


static func _enemy_definition(enemy_id: String, catalog: Dictionary, encounter_turn := 0) -> Dictionary:
	var definition := _base_enemy_definition(enemy_id, catalog)
	# 五转梯度：遭遇层转数高于敌人基准转数时按 pacing 曲线抬升 HP 与意图伤害。
	var delta := encounter_turn - int(definition.get("turn", 1))
	if delta > 0:
		var scaling: Dictionary = catalog.get("pacing", {}).get("turn_scaling", {})
		var hp_add := int(scaling.get("hp_add_per_turn", 2)) * delta
		var damage_add := int(scaling.get("damage_add_per_turn", 1)) * delta
		definition["hp"] = int(definition.get("hp", 3)) + hp_add
		var base_intent: Dictionary = definition.get("intent", {})
		if int(base_intent.get("damage", 0)) > 0:
			base_intent["damage"] = int(base_intent["damage"]) + damage_add
			definition["intent"] = base_intent
		for phase_value in definition.get("phases", []):
			var phase: Dictionary = phase_value
			for phase_intent_value in phase.get("intents", []):
				var phase_intent: Dictionary = phase_intent_value
				if int(phase_intent.get("damage", 0)) > 0:
					phase_intent["damage"] = int(phase_intent["damage"]) + damage_add
	return definition


static func _base_enemy_definition(enemy_id: String, catalog: Dictionary) -> Dictionary:
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


static func _reaction_for(battle: Dictionary, trigger: String, target_id := "") -> Dictionary:
	var enemy := _enemy_by_target_id(battle, target_id)
	if enemy.is_empty() and not _living_enemies(battle).is_empty():
		enemy = _living_enemies(battle)[0]
	# Phase-aware source: a boss's active phase may swap its reaction set.
	var source: Array = enemy.get("reactions", [])
	if source.is_empty():
		source = (enemy.get("definition", {}) as Dictionary).get("reactions", [])
	for reaction_value in source:
		var reaction: Dictionary = reaction_value
		if str(reaction.get("window", "")) == "before_damage" and str(reaction.get("trigger", "")) == trigger:
			return reaction.duplicate(true)
	return {}


# ---- R5.7 boss phase machinery ----

static func _active_phase(battle: Dictionary) -> Dictionary:
	if _living_enemies(battle).is_empty():
		return {}
	return _active_enemy_phase(_living_enemies(battle)[0])


static func _active_enemy_phase(enemy: Dictionary) -> Dictionary:
	var phases: Array = enemy.get("phases", [])
	if phases.is_empty():
		return {}
	var index := clampi(int(enemy.get("phase_index", 0)), 0, phases.size() - 1)
	return phases[index]


static func _phase_index_for_ratio(ratio: float, phases: Array) -> int:
	for index in range(phases.size() - 1, -1, -1):
		var threshold := float((phases[index] as Dictionary).get("until_hp_ratio", 1.0))
		if ratio <= threshold:
			return index
	return 0


# Forward-only phase sync; called wherever enemy hp may have just changed.
# Crossing a threshold appends exactly one boss_phase_shift event whose after
# payload carries only _from/_to info keys, then redraws the visible intent
# from the new phase set (respecting cooldowns).
static func _sync_boss_phases(battle: Dictionary, state: RunState) -> RunState:
	_sync_legacy_single_enemy_inputs(battle)
	var next_state := state
	for enemy_value in _living_enemies(battle):
		next_state = _sync_enemy_phase(enemy_value as Dictionary, battle, next_state)
	_sync_legacy_enemy_projection(battle)
	return next_state


static func _sync_enemy_phase(enemy: Dictionary, battle: Dictionary, state: RunState) -> RunState:
	var phases: Array = enemy.get("phases", [])
	if phases.is_empty():
		return state
	var ratio := float(int(enemy.get("hp", 0))) / float(maxi(1, int(enemy.get("max_hp", 1))))
	var desired := _phase_index_for_ratio(ratio, phases)
	var current := int(enemy.get("phase_index", 0))
	if desired <= current:
		return state
	enemy["phase_index"] = desired
	var phase_reactions: Array = (phases[desired] as Dictionary).get("reactions", [])
	if not phase_reactions.is_empty():
		enemy["reactions"] = phase_reactions.duplicate(true)
	var shifted := state.append_event(_event(
		state,
		"boss_phase_shift",
		{},
		{"_from": current, "_to": desired},
		"boss_phase_shift",
		[str(enemy.get("kind", ""))]
	))
	_select_enemy_intent_for(enemy, battle, shifted, int(battle.get("turn", 1)))
	return shifted


# Picks the next visible intent from the active phase set. An intent fired on
# turn T with "cooldown":n is next selectable from turn T+n+1; while every
# intent of the phase is resting, the boss shows a harmless cooldown_wait and
# attacks nothing that turn (no earliest-release fallback). Selection is seeded.
static func _select_enemy_intent(battle: Dictionary, state: RunState, exec_turn: int) -> void:
	_sync_legacy_single_enemy_inputs(battle)
	if _living_enemies(battle).is_empty():
		return
	_select_enemy_intent_for(_living_enemies(battle)[0], battle, state, exec_turn)
	_sync_legacy_enemy_projection(battle)


static func _select_enemy_intent_for(enemy: Dictionary, battle: Dictionary, state: RunState, exec_turn: int) -> void:
	var intents: Array = (_active_enemy_phase(enemy).get("intents", []) as Array)
	if intents.is_empty():
		intents = (enemy.get("definition", {}) as Dictionary).get("intents", [])
	if intents.is_empty():
		var singular_intent: Dictionary = (enemy.get("definition", {}) as Dictionary).get("intent", {})
		if not singular_intent.is_empty():
			intents = [singular_intent]
	if intents.is_empty():
		return
	var cooldowns: Dictionary = enemy.get("intent_cooldowns", {})
	var available: Array = []
	for intent_value in intents:
		var intent: Dictionary = intent_value
		if int(cooldowns.get(str(intent.get("id", "")), 0)) <= exec_turn:
			available.append(intent)
	if available.is_empty():
		enemy["visible_intent"] = COOLDOWN_WAIT_INTENT.duplicate(true)
		return
	# R14.6⑦ (night batch): boss-local adapt — when the precomputed counter
# intent is eligible it IS the pick (intent switch, seeded draw still
# consumed via index(1) so the stream stays stable); battle-scoped flag/hint
# die with the battle dict (never leak into the run or the map layer).
	var counter_intent := str(battle.get("dda_boss_counter_id", "")) if str(enemy.get("enemy_id", "")).ends_with(":e0") else ""
	if not counter_intent.is_empty():
		for index in available.size():
			if str(available[index].get("id", "")) == counter_intent:
				var prioritized: Dictionary = available[index]
				available.remove_at(index)
				enemy["visible_intent"] = prioritized.duplicate(true)
				battle["dda_boss_adapted"] = true
				battle["dda_boss_hint"] = "boss_senses_gu_power"
				_seeded_index(1, state, "boss.intent")
				return
	var salt := "boss.intent" if str(enemy.get("enemy_id", "")).ends_with(":e0") else "boss.intent.%s" % str(enemy.get("enemy_id", ""))
	var picked: Dictionary = available[_seeded_index(available.size(), state, salt)]
	enemy["visible_intent"] = picked.duplicate(true)


const COOLDOWN_WAIT_INTENT := {
	"id": "cooldown_wait",
	"label": "蛰伏回气",
	"damage": 0,
	"speed": 0,
}


# A fired intent with "cooldown":n stores its next usable turn (execution
# turn + window + 1), so the gap always covers exactly n full turns.
static func _register_intent_cooldown(battle: Dictionary, intent: Dictionary, exec_turn: int) -> void:
	if _living_enemies(battle).is_empty():
		return
	_register_enemy_intent_cooldown(_living_enemies(battle)[0], intent, exec_turn)
	_sync_legacy_enemy_projection(battle)


static func _register_enemy_intent_cooldown(enemy: Dictionary, intent: Dictionary, exec_turn: int) -> void:
	var cooldown := maxi(0, int(intent.get("cooldown", 0)))
	if cooldown <= 0:
		return
	var cooldowns: Dictionary = enemy.get("intent_cooldowns", {}).duplicate()
	cooldowns[str(intent.get("id", ""))] = exec_turn + cooldown + 1
	enemy["intent_cooldowns"] = cooldowns


static func _seeded_index(bound: int, state: RunState, salt: String) -> int:
	# P2a C: formula lives in SeededRoll; salt strings and call order unchanged.
	return SeededRollScript.index(bound, int(state.seed), salt, state.event_log.size())


static func _reaction_countered(battle: Dictionary, reaction: Dictionary) -> bool:
	var counter_status := str(reaction.get("counter_status", ""))
	if counter_status == "bound":
		return battle["flags"].has("enemy_bound")
	if counter_status == "guarded":
		return battle["flags"].has("guarded")
	return false


static func _reveal_reaction(battle: Dictionary, reaction: Dictionary, target_id := "") -> void:
	var reaction_id := str(reaction.get("id", "reaction"))
	if not target_id.is_empty() and battle.get("enemies", []).size() > 1:
		reaction_id = "%s:%s" % [target_id, reaction_id]
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
	if boss_blocks_retreat(battle):
		return false
	return can_retreat(str(battle["terrain"]), int(battle["pursuit"]), int(battle["enemy_control"]))


static func _with_objective_result(battle: Dictionary, state: RunState, catalog: Dictionary) -> Dictionary:
	# R5.7 phase re-evaluation happens the moment enemy hp changed but only
	# while the battle can continue (no shift events for a dying boss).
	_sync_legacy_enemy_projection(battle)
	var enemy_down := str(battle["objective"]) == "defeat" and _living_enemies(battle).is_empty()
	var delayed := str(battle["objective"]) == "delay" and int(battle["delay_progress"]) >= int(battle["delay_needed"])
	if not enemy_down and not delayed:
		state = _sync_boss_phases(battle, state)
	if str(battle["objective"]) == "delay" and int(battle["delay_progress"]) >= int(battle["delay_needed"]):
		return _victory_with_loot(battle, state, catalog, ["objective_delayed"])
	if str(battle["objective"]) == "defeat" and _living_enemies(battle).is_empty():
		return _victory_with_loot(battle, state, catalog, ["enemy_defeated"])
	return _result(battle, state, false, "ongoing", [])


static func _victory_with_loot(battle: Dictionary, state: RunState, catalog: Dictionary, feeds: Array[String]) -> Dictionary:
	var settled := LootResolverScript.settle_victory(battle, state, catalog)
	var with_loot := battle.duplicate(true)
	with_loot["loot"] = settled["loot"]
	# Elite victories bind a cost; it rides the finished battle so the
	# presentation layer can surface it to the player.
	if not (settled.get("cost", {}) as Dictionary).is_empty():
		with_loot["cost"] = (settled["cost"] as Dictionary).duplicate(true)
	return _battle_over(with_loot, settled["state"], catalog, true, "victory", feeds)


static func _event(state: RunState, action: String, before: Dictionary, after: Dictionary, reason: String, targets: Array) -> Dictionary:
	return {"stage": state.stage, "time": state.event_log.size(), "node_id": state.current_node_id, "action": action, "before": before, "after": after, "reason": reason, "source": "battle_resolver", "targets": targets}


# R4.x single battle-finalization funnel: victory, retreat and death paths all
# pass through here exactly once so on_battle_end relic hooks fire once per
# finished battle regardless of how it ended.
static func _battle_over(battle: Dictionary, state: RunState, catalog: Dictionary, finished: bool, result_kind: String, feeds: Array[String]) -> Dictionary:
	var end_hook := RelicHookResolverScript.apply_battle_end(battle, state, catalog)
	var hook_feeds: Array[String] = end_hook["feeds"]
	feeds.append_array(hook_feeds)
	return _result(end_hook["battle"], end_hook["state"], finished, result_kind, feeds)


# Death variant: hooks MUST evaluate on the pre-finalization state because
# finalize_death() clears run collections (including relic_ids); the stone
# grant event lands while the run is alive, then run_ended closes it out.
static func _death_over(battle: Dictionary, state: RunState, catalog: Dictionary, feeds: Array[String]) -> Dictionary:
	var end_hook := RelicHookResolverScript.apply_battle_end(battle, state, catalog)
	var hook_feeds: Array[String] = end_hook["feeds"]
	feeds.append_array(hook_feeds)
	return _result(end_hook["battle"], end_hook["state"].finalize_death(), true, "death", feeds)


static func _result(battle: Dictionary, state: RunState, finished: bool, result: String, feeds: Array[String]) -> Dictionary:
	return {"battle": battle, "state": state, "feeds": feeds, "finished": finished, "result": result, "accepted": true}


static func _rejected_turn(battle: Dictionary, state: RunState, feed: String) -> Dictionary:
	var result := _result(battle, state, false, "ongoing", [feed])
	result["accepted"] = false
	return result
