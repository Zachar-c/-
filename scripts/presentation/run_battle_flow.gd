extends RefCounted

## A7：战斗会话生命周期（开局敌先手 / 回合命令 / 战后结算）外提。
## controller 保持同名一行包装；本模块直接读写 controller 上的
## current_battle / state（含 encounter_session）/ catalog / current_node。


const DeathReportBuilderScript = preload("res://scripts/domain/death_report_builder.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const DisplayTextScript = preload("res://scripts/presentation/display_text.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const M0RewardResolverScript = preload("res://scripts/domain/m0_reward_resolver.gd")


static func submit_battle_command(controller, command: Dictionary) -> Dictionary:
	var turn: Dictionary = BattleCommandFacadeScript.apply_turn(
			controller.current_battle, controller.state, command, controller.catalog)
	controller.state = turn["state"]
	controller.current_battle = turn["battle"]
	sync_battle_hp_to_state(controller)
	controller.last_result = {"battle_result": turn.get("result", "ongoing"), "feeds": turn.get("feeds", [])}
	# 第三阶段 Task 4：终局只有一条收口路径——胜利/撤离/战死一律交给
	# finish_battle_in_session（它负责落唯一的 battle_finished 与清场后再分派屏）。
	if bool(turn.get("finished", false)):
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
	# 第三阶段 Task 2：开局与会话账本一并由门面 start_session 建立，
	# 表现层不再自行 new_turn()。
	var session: Dictionary = BattleCommandFacadeScript.start_session(encounter, state, catalog)
	controller.state = session["state"]
	controller.current_battle = session["battle"]
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
			finish_battle_in_session(controller, str(pre["result"]))
			return
	controller._show_battle()


static func battle_terrain(controller) -> String:
	if controller.current_node.get("id", "") == "greedy_wanderer":
		return "ridge"
	return "path"


static func finish_battle_in_session(controller, outcome: String) -> void:
	var state = controller.state
	# 第三阶段 Task 4：战死也走同一条收口，落唯一的 battle_finished（带账本快照）。
	# 死亡复盘沿用收口前的战斗现场构建（既有契约读 current_battle 归因最后一击）。
	var death_report: Dictionary = {}
	if outcome == "death":
		death_report = DeathReportBuilderScript.build(controller.current_battle, controller.state)
	var current_session: Dictionary = controller.state.encounter_session.duplicate(true)
	var kill_source := str(controller.current_battle.get("kill_source", ""))
	var enemy_kind := str(controller.current_battle.get("enemy_kind", ""))
	var battle_loot: Dictionary = controller.current_battle.get("loot", {})
	var battle_cost: Dictionary = controller.current_battle.get("cost", {})
	# 第三阶段 Task 2：会话收口（交出账本快照并清场）归门面 finalize_session。
	var finalized: Dictionary = BattleCommandFacadeScript.finalize_session(
			controller.current_battle, state, outcome)
	state = finalized["state"]
	var ledger_snapshot: Dictionary = finalized["ledger"]
	# 战死保留战斗现场：死因归因与既有死亡复盘通路都读它（run 已终结，不会再续战）。
	if outcome != "death":
		controller.current_battle = {}
	current_session["phase"] = "post_battle"
	current_session["stance"] = "neutral"
	if current_session.has("flags") and current_session["flags"] is Dictionary:
		current_session["flags"].erase("reputation_hostile")
		current_session["flags"].erase("reputation_extreme")
	var feed := ResultFeedScript.entry("battle", "battle_%s" % outcome, {}, [])
	var results: Array = state.encounter_results.duplicate(true)
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
	if controller.m0_mode and outcome == "victory":
		var m0_count := int(controller.state.node_flags.get("m0_battles_completed", 0)) + 1
		var m0_flags: Dictionary = controller.state.node_flags.duplicate(true)
		m0_flags["m0_battles_completed"] = m0_count
		controller.state = controller.state.append_event({
			"stage": controller.state.stage,
			"time": controller.state.event_log.size(),
			"node_id": controller.state.current_node_id,
			"action": "m0_battle_completed",
			"before": {"node_flags": controller.state.node_flags},
			"after": {"node_flags": m0_flags},
			"reason": "m0_battle_completed",
			"source": "m0_run_flow",
			"targets": [str(controller.current_node.get("id", ""))],
		})
		if str(controller.current_node.get("id", "")) == "m0_boss":
			controller.state = controller.state.append_event({
				"stage": controller.state.stage,
				"time": controller.state.event_log.size(),
				"node_id": controller.state.current_node_id,
				"action": "m0_boss_defeated",
				"before": {},
				"after": {"node_flags": controller.state.node_flags},
				"reason": "m0_boss_defeated",
				"source": "m0_run_flow",
				"targets": ["m0_boss"],
			})
			controller._show_ending({
				"outcome": "m0_boss_defeated",
				"conditions": {"m0_battles": m0_count},
			})
			return
		controller.m0_reward_options = M0RewardResolverScript.build_options(
			controller.state, m0_count, controller.catalog)
		controller.m0_reward_selected = false
		controller._show_reward()
		return
	if outcome == "victory" and (not battle_loot.is_empty() or not controller.last_battle_cost.is_empty()):
		controller._show_reward()
		return
	if outcome == "death":
		controller._show_death(death_report)
		return
	controller._show_encounter()
