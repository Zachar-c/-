extends RefCounted

## A7：战斗会话生命周期（开局敌先手 / 回合命令 / 战后结算）外提。
## controller 保持同名一行包装；本模块直接读写 controller 上的
## current_battle / state（含 encounter_session）/ catalog / current_node。


const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const Battle2TurnEngineScript = preload("res://scripts/domain/battle2/turn_engine.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")


static func submit_battle_command(controller, command: Dictionary) -> Dictionary:
	var turn: Dictionary = BattleCommandFacadeScript.apply_turn(
			controller.current_battle, controller.state, command, controller.catalog)
	controller.state = turn["state"]
	controller.current_battle = turn["battle"]
	sync_battle_hp_to_state(controller)
	controller.last_result = {"battle_result": turn.get("result", "ongoing"), "feeds": turn.get("feeds", [])}
	if bool(turn.get("finished", false)):
		if str(turn.get("result", "")) == "death":
			controller._show_death(DeathReportBuilderScript.build(controller.current_battle, controller.state))
		else:
			finish_battle_in_session(controller, str(turn.get("result", "")))
	else:
		controller._show_battle()
	return turn


static func sync_battle_hp_to_state(controller) -> void:
	var state = controller.state
	if controller.current_battle.is_empty():
		return
	var player: Dictionary = controller.current_battle.get("player", {})
	if player.is_empty():
		return
	var hp := maxi(0, int(player.get("hp", state.health)))
	var max_hp := maxi(1, int(player.get("max_hp", state.max_health)))
	state.health = hp
	state.max_health = max_hp
	var cultivator: Dictionary = state.cultivator.duplicate(true)
	cultivator["health"] = hp
	cultivator["max_health"] = max_hp
	state.cultivator = cultivator


static func start_battle(controller) -> void:
	var state = controller.state
	var current_node: Dictionary = controller.current_node
	var current_session: Dictionary = controller.state.encounter_session
	var catalog: Dictionary = controller.catalog
	var enemy_kind := str(current_node.get("enemy_kind", "beast_swarm"))
	var first_mover := "player"
	var notorious := Resolver.notoriety(state)
	var stance := str(current_session.get("stance", "neutral"))
	var hostile_flag := stance in ["hostile", "extreme_hostile"] \
			or bool(current_session.get("flags", {}).get("reputation_hostile", false))
	if notorious > 0 or hostile_flag:
		if hostile_flag:
			first_mover = "enemy"
		else:
			var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
			var pct := notorious * int(effects.get("first_move_chance_pct_per_point", 10))
			if Resolver.roll_chance(state, pct, "reputation_first_move"):
				first_mover = "enemy"
	var kill_source := ""
	if str(current_session.get("kind", "")) in ["contact", "caravan", "market", "shop", "wild_gu"]:
		kill_source = "neutral_npc"
	var encounter := {
		"turn": int(current_node.get("layer", MapGeneratorScript.layer_index(str(current_node.get("stage", ""))))),
		"layer": int(current_node.get("layer", 1)),
		"layer_boss": int(current_node.get("layer_boss", 0)),
		"terrain": battle_terrain(controller),
		"first_mover": first_mover,
		"kill_source": kill_source,
	}
	if current_node.has("enemy_roll"):
		encounter["enemy_roll"] = (current_node.get("enemy_roll", []) as Array).duplicate()
	elif current_node.has("enemy_kinds"):
		encounter["enemy_kinds"] = (current_node.get("enemy_kinds", []) as Array).duplicate()
	else:
		encounter["enemy_kind"] = enemy_kind
	state.current_battle2_ledger = Battle2TurnEngineScript.new_turn(
		CultivatorRulesScript.thought_capacity(state.cultivator, catalog)
	)
	controller.current_battle = BattleCommandFacadeScript.start(encounter, state, catalog)
	if state.known_facts.has("procured_weakness"):
		controller.current_battle["intel_bonus"] = 1
	if first_mover == "enemy":
		var opening_damage := 0
		for enemy_value in controller.current_battle.get("enemies", []):
			opening_damage += maxi(0, int(((enemy_value as Dictionary).get("intent", {}) as Dictionary).get("damage", 0)))
		var lethal_opening: bool = opening_damage > 0 and state.health <= opening_damage
		if lethal_opening:
			(controller.current_battle["flags"] as Dictionary)["opening_lethal"] = true
			controller.current_battle["log"].append({"id": "opening_lethal_warning", "damage": opening_damage})
			controller._show_battle()
			return
		var pre := BattleCommandFacadeScript.apply_enemy_pre_turn(controller.current_battle, state, catalog)
		controller.state = pre["state"]
		controller.current_battle = pre["battle"]
		sync_battle_hp_to_state(controller)
		if bool(pre["finished"]):
			if str(pre["result"]) == "death":
				controller._show_death(DeathReportBuilderScript.build(controller.current_battle, controller.state))
			else:
				finish_battle_in_session(controller, str(pre["result"]))
			return
	controller._show_battle()


static func battle_terrain(controller) -> String:
	if controller.current_node.get("id", "") == "greedy_wanderer":
		return "ridge"
	return "path"


static func finish_battle_in_session(controller, outcome: String) -> void:
	var state = controller.state
	var current_session: Dictionary = controller.state.encounter_session.duplicate(true)
	var kill_source := str(controller.current_battle.get("kill_source", ""))
	var enemy_kind := str(controller.current_battle.get("enemy_kind", ""))
	var battle_loot: Dictionary = controller.current_battle.get("loot", {})
	var battle_cost: Dictionary = controller.current_battle.get("cost", {})
	controller.current_battle = {}
	current_session["phase"] = "post_battle"
	current_session["stance"] = "neutral"
	if current_session.has("flags") and current_session["flags"] is Dictionary:
		current_session["flags"].erase("reputation_hostile")
		current_session["flags"].erase("reputation_extreme")
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results: Array = state.encounter_results.duplicate(true)
	var ledger_snapshot: Dictionary = {}
	if not state.current_battle2_ledger.is_empty():
		ledger_snapshot = state.current_battle2_ledger.duplicate(true)
	if outcome == "victory" and not battle_loot.is_empty():
		var loot_labels: Array[String] = []
		for material_value in battle_loot.get("material_ids", []):
			loot_labels.append(DisplayTextScript.material(str(material_value)))
		var loot_gu := str(battle_loot.get("gu_id", ""))
		if not loot_gu.is_empty():
			loot_labels.append(DisplayTextScript.gu(loot_gu))
		if not loot_labels.is_empty():
			results.append(ResultFeedScript.entry("battle", "battle_loot",
					{"loot_display": "、".join(loot_labels)}, []))
	if outcome == "victory" and not battle_cost.is_empty():
		results.append(ResultFeedScript.entry(
			"battle",
			"elite_cost_applied",
			{"cost_display": DisplayTextScript.elite_cost(battle_cost),
					"cost_kind": str(battle_cost.get("kind", ""))},
			[]
		))
	if outcome == "victory" and enemy_kind == "miasma_vein_lord":
		results.append(ResultFeedScript.entry("battle", "lifespan_milestone_gained", {}, []))
	results.append(feed)
	var finished_event: Dictionary = {
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": state.current_node_id,
		"action": "battle_finished",
		"before": {},
		"after": {"encounter_session": current_session, "encounter_results": results},
		"reason": "battle_%s" % outcome,
		"source": "run_controller",
		"targets": [],
	}
	if not ledger_snapshot.is_empty():
		finished_event["info"] = {"_battle2_ledger": ledger_snapshot.duplicate(true)}
	state = state.append_event(finished_event)
	state.current_battle2_ledger = {}
	controller.state = state
	if outcome == "victory" and kill_source == "neutral_npc":
		controller.state = Resolver.apply(state, {"type": "record_neutral_npc_kill"}, controller.catalog)["state"]
	if outcome == "victory":
		var layer_boss := int(controller.current_node.get("layer_boss", 0))
		if layer_boss > 0:
			controller.state = Resolver.apply(controller.state,
					{"type": "record_layer_boss_defeated", "layer": layer_boss}, controller.catalog)["state"]
			# 收官抉择（2026-09-15 用户裁定）：此处**不再**强制收官。
			# `pacing.ending_after_stage` 改为「收官可选起始层」——击败该层关底后
			# 玩家继续深入（本函数照常走 Reward → Map），收官按钮在地图屏常驻
			# （`close_run` 命令，判据 SocialCommandRules.closure_available）。
			# 原实现直接置 terminal_state=success 并跳 Ending，导致生产局只有
			# L1（约 3–12 场战斗）就收官，转数永远停在 1–2，局内毫无成长空间。
		if enemy_kind == "miasma_vein_lord":
			controller.state = Resolver.apply(controller.state,
					{"type": "record_boss_defeated"}, controller.catalog)["state"]
	controller.last_battle_loot = battle_loot
	controller.last_battle_cost = battle_cost if outcome == "victory" else {}
	if outcome == "victory" and (not battle_loot.is_empty() or not controller.last_battle_cost.is_empty()):
		controller._show_reward()
		return
	controller._show_encounter()
