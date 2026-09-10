class_name RunSnapshotBuilder
extends RefCounted


# Builds the read-only snapshots the RUI screens render. Inputs come from the
# RunController; this class never mutates run state, only projects it.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const RecipeRulesScript = preload("res://scripts/domain/recipe_rules.gd")
const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const BodyRulesScript = preload("res://scripts/domain/body_rules.gd")
const ActionResolverScript = preload("res://scripts/domain/action_resolver.gd")
const SoulRulesScript = preload("res://scripts/domain/soul_rules.gd")
const BloodQiRulesScript = preload("res://scripts/domain/blood_qi_rules.gd")


static func for_screen(screen: String, controller) -> Dictionary:
	var base: Dictionary
	match screen:
		"Title": base = hall(controller)
		"Map": base = map(controller)
		"Encounter": base = encounter(controller)
		"Battle": base = battle(controller)
		"Shop": base = shop(controller)
		"Rest": base = rest(controller)
		"Refine": base = refine(controller)
		"Reward": base = reward(controller)
		"Npc": base = npc(controller)
		"ContentError": base = content_error(controller)
		"Kill": base = kill(controller)
		"Settings": base = settings(controller)
		_: return {}
	return _with_v2(base, controller)


# Every real screen snapshot carries the eight §17.2 transparency groups as a
# conservative additive merge (per-screen keys already take precedence).
static func _with_v2(snapshot: Dictionary, controller) -> Dictionary:
	var merged := snapshot.duplicate(true)
	merged.merge(transparency_v2(controller), true)
	return merged


## W12 split: debug snapshot moved to snapshots/debug_snapshot.gd. Forwarder
## kept for direct callers (unit tests and verify tools).
static func debug(controller) -> Dictionary:
	return DebugSnapshot.build(controller)


## 局内节点屏公共骨架（顶栏资源/契约/异变/死线）。
static func _gui_state(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	return {
		"resources": _resources(state),
		"contracts": _contracts(state),
		# R14.6① (night batch): DDA 系统标记与契约分区（黄红系），由 UI 会话渲染。
		"anomalies": DdaResolverScript.marker_meta(state, catalog),
		"death_lines": _death_lines(state),
		"inventory": _inventory(state, catalog),
		# B 批反馈基建：last_feedback 由 submit_command 统一维护（命令后一拍可见，
		# 下一条命令即清空）；快照只读搬运，各屏 toast 槽消费。
		"feedback": str(controller.last_feedback) if controller.get("last_feedback") != null else "",
	}


## 真实节点可行动作（复用 Encounter 屏的 preview_actions，保证数据一致）。
static func _node_actions(controller) -> Array[Dictionary]:
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var knowledge: Dictionary = {}
	if controller.meta != null:
		knowledge = controller.meta.unlocked_random_outcomes
	var actions: Array[Dictionary] = []
	var node_id := str(controller.current_node.get("id", ""))
	var session_node_id := node_id
	var current_session: Variant = controller.get("current_session") if controller != null else null
	if current_session is Dictionary and not (current_session as Dictionary).is_empty():
		session_node_id = str((current_session as Dictionary).get("node_id", node_id))
	for c in ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, catalog, knowledge):
		var enriched := c.duplicate(true)
		enriched["node_id"] = node_id
		enriched["session_node_id"] = session_node_id
		if enriched.get("command", {}) is Dictionary and not (enriched["command"] as Dictionary).is_empty():
			enriched["command"]["state_version"] = int(enriched.get("state_version", controller.state.event_log.size()))
			enriched["command"]["node_id"] = node_id
			enriched["command"]["session_node_id"] = session_node_id
		actions.append(_enc_action(enriched))
	return actions


## W12 split: shop snapshot moved to snapshots/shop_snapshot.gd.
static func shop(controller) -> Dictionary:
	return ShopSnapshot.build(controller)


## C5 休整 / 闭关屏快照（rest_hollow 真实休整 + aptitude 洗髓换骨）。
# BUG-001 contract: every mode the resolver can consume on a rest node must
# appear in snapshot.choices with target lists and disabling driven from the
# domain state. The skip choice stays enabled until the visit is consumed so
# the leave gate never traps a player with no executable benefit.
## W12 split: rest snapshot moved to snapshots/rest_snapshot.gd.
static func rest(controller) -> Dictionary:
	return RestSnapshot.build(controller)


## W12 split: refine snapshot moved to snapshots/refine_snapshot.gd.
static func refine(controller) -> Dictionary:
	return RefineSnapshot.build(controller)


## W12 split: reward snapshot moved to snapshots/reward_snapshot.gd. Forwarder
## kept for direct callers (unit tests and verify tools).
static func reward(controller) -> Dictionary:
	return RewardSnapshot.build(controller)


## W12 split: npc snapshot moved to snapshots/npc_snapshot.gd. Forwarder kept
## for direct callers (unit tests and verify tools).
static func npc(controller) -> Dictionary:
	return NpcSnapshot.build(controller)


## W12 split: hall snapshot moved to snapshots/hall_snapshot.gd. Forwarders kept
## for direct callers (unit tests and verify tools).
static func hall(controller) -> Dictionary:
	return HallSnapshot.build(controller)


static func _codex(catalog: Dictionary, meta) -> Dictionary:
	return HallSnapshot._codex(catalog, meta)


static func _v1_effect_text(source: Dictionary) -> String:
	return SnapshotTextUtil._v1_effect_text(source)


## W12 split: direct test caller (test_central_gu_economy) keeps the forwarder.
static func _v1_hand(battle_data: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	return BattleSnapshot._v1_hand(battle_data, catalog)


## W12 split: content_error snapshot moved to snapshots/content_error_snapshot.gd.
static func content_error(controller) -> Dictionary:
	return ContentErrorSnapshot.build(controller)


## W12 split: map snapshot moved to snapshots/map_snapshot.gd.
static func map(controller) -> Dictionary:
	return MapSnapshot.build(controller)


## W12 split: encounter snapshot moved to snapshots/encounter_snapshot.gd.
## Forwarder kept for direct callers (unit tests and verify tools).
static func encounter(controller) -> Dictionary:
	return EncounterSnapshot.build(controller)


## 战斗屏快照：唯一 V1 战斗 Schema 投影（BattleCommandFacade → V1BattleResolver）。
## 领域状态只有 "battle/player/gu_slots/enemies/kill_moves/flags(Dictionary)" 一套，
## 本函数只做字段搬运与文字拼装，绝不重算领域结果；旧卡牌字段
## （draw_pile/actions_max/visible_intent/Array flags）一律不再读取。
## W12 split: battle/kill snapshots moved to snapshots/battle_snapshot.gd.
## battle_turn_supports keeps a forwarder (direct test caller).
static func battle(controller) -> Dictionary:
	return BattleSnapshot.build_battle(controller)


static func battle_turn_supports(battle_data: Dictionary) -> Dictionary:
	return BattleSnapshot.battle_turn_supports(battle_data)


static func kill(controller) -> Dictionary:
	return BattleSnapshot.build_kill(controller)


## W12 split: settings snapshot moved to snapshots/settings_snapshot.gd.
## Forwarder kept for direct callers (unit tests and verify tools).
static func settings(controller) -> Dictionary:
	return SettingsSnapshot.build(controller)


## 2 低血进敌方先手战：致死开场已延后到玩家首个回合结束，把意图伤害与
## 文案暴露给战斗屏（缺失时返回空 dict，屏面无碎片）。
static func _lethal_warning(battle_data: Dictionary) -> Dictionary:
	var flags = battle_data.get("flags", {})
	# V1 契约：flags 是 Dictionary；意图伤害按全部存活敌人求和（围攻叠伤）。
	if not flags.has("opening_lethal"):
		return {}
	var damage := 0
	for enemy_value in battle_data.get("enemies", []):
		damage += maxi(0, int(((enemy_value as Dictionary).get("intent", {}) as Dictionary).get("damage", 0)))
	return {
		"damage": damage,
		"message": "敌方先手一击 %d 点伤害：当前气血会在出手前被击穿，务必在出手前守护、闪避或治疗。" % damage,
	}


static func ending(controller, outcome: Dictionary, journal: Array[Dictionary], run_data: Dictionary) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var otype := str(outcome.get("outcome", "survived_failure"))
	var etype := ending_type_for(otype)
	var decisions: Array[String] = []
	for entry in journal:
		decisions.append(DisplayText.journal_heading(str(entry.get("heading", ""))))
	var gains := "最高修为/转数：%s/%s；流派：%s；资产结余：元石 %d" % [
		str(run_data.get("cultivation", "-")),
		str(run_data.get("stage", "-")),
		str(run_data.get("school", "未定")),
		int(run_data.get("stone", 0)),
	]
	var codex: Array = run_data.get("global_codex_ids", [])
	var unlocks: Array[String] = []
	for x in codex:
		unlocks.append("图鉴：%s" % str(x))
	var cult: Dictionary = state.cultivator if state != null else {}
	var cause := {"id": "", "short": "", "text": ""}
	if otype == "death":
		cause = death_cause_fields(state)
	var out := {
		"title": DisplayText.outcome(otype),
		"ending_type": etype,
		"death_cause_id": str(cause["id"]),
		"death_cause": str(cause["text"]),
		"death_cause_short": str(cause["short"]),
		"key_decisions": decisions,
		"gains_losses": gains,
		"resource_balance": {"yuanstone": int(state.stone) if state != null else 0, "shouyuan": int(cult.get("lifespan", 0))},
		"unlocks": unlocks,
		"contracts_recap": _contracts_recap(state, catalog),
		"contracts_sworn_count": _contracts_sworn_count(state),
		# R14.6⑧ (night batch): DDA 触发记录（事件日志为唯一真值源, 去重保序）。
		"dda_triggers": _dda_trigger_count(state),
		"dda_markers": _dda_marker_recap(state, catalog),
		"aftermath": str(catalog.get("journal", {}).get("ending_texts", {}).get(etype, "修行札记已留存，可于大厅图鉴查阅本次所得。")),
	}
	out.merge(settlement_extras(controller))
	out["achievement"] = DisplayText.ending_achievement(etype)
	return out


## T5-C 结算复盘只读投影（路线缩略图 / 本局记录 / 最高转数）。
## builder `ending()` 与战斗死亡 `_show_death` 内联结算共用，保证两条路径同形。
## 只读扫描 route/node_flags/event_log；不重算任何领域结果。
static func settlement_extras(controller) -> Dictionary:
	return {
		"route_summary": _route_summary(controller),
		"run_record": _run_record(controller),
		"max_rank": _max_rank(controller),
	}


## 路线缩略图：按 stage 分组已访问节点（state.node_flags 标记），types 为中文
## 类型短标；boss=该层含 catalog 中 tier=boss 敌人的节点，供 EMBER 高亮。
static func _route_summary(controller) -> Array[Dictionary]:
	var state = controller.state
	var route = controller.get("route") if controller != null else null
	if state == null or state.node_flags == null or route == null:
		return []
	var boss_enemies: Dictionary = {}
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	for enemy_id in catalog.get("enemy_by_id", {}):
		var entry: Dictionary = catalog["enemy_by_id"][enemy_id]
		if str(entry.get("tier", "")) == "boss":
			boss_enemies[str(enemy_id)] = true
	var groups: Array[Dictionary] = []
	for node_value in route:
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if not state.node_flags.has(node_id):
			continue
		var stage := str(node.get("stage", ""))
		var type_label := DisplayText.type(str(node.get("type", "")))
		var is_boss := boss_enemies.has(str(node.get("enemy_kind", "")))
		if not groups.is_empty() and str(groups[-1]["stage"]) == stage:
			groups[-1]["types"].append(type_label)
			groups[-1]["boss"] = bool(groups[-1]["boss"]) or is_boss
		else:
			groups.append({"stage": stage, "types": [type_label], "boss": is_boss})
	var out: Array[Dictionary] = []
	for index in groups.size():
		out.append({
			"layer": index + 1,
			"types": groups[index]["types"],
			"boss": bool(groups[index]["boss"]),
		})
	return out


## 本局记录：event_log 只读计数。合成按结果 reason 计数（材料扣减簿记事件
## battle_synthesis_materials_spent 不计为尝试）；DDA 未实装，恒 0 占位。
## 保底触发：事件日志无任何含 pity 的 action（pity 仅以 before/after 数值随
## battle_loot 位移），无法在不重算领域结果的前提下确认口径，故本批不渲染该行。
static func _run_record(controller) -> Dictionary:
	var record := {
		"synthesis_attempts": 0,
		"synthesis_ok": 0,
		"synthesis_fail": 0,
		"boss_phase_shifts": 0,
		"dda_triggers": 0,
	}
	var state = controller.state
	if state == null:
		return record
	for event in state.event_log:
		match str(event.get("action", "")):
			"battle_synthesize":
				match str(event.get("reason", "")):
					"battle_synthesis_succeeded":
						record["synthesis_attempts"] += 1
						record["synthesis_ok"] += 1
					"battle_synthesis_failed":
						record["synthesis_attempts"] += 1
						record["synthesis_fail"] += 1
			"boss_phase_shift":
				record["boss_phase_shifts"] += 1
	return record


## §16.17 结算统计行：最高转数取自 cultivator.reincarnation（转数轨唯一成长轴）。
static func _max_rank(controller) -> int:
	var state = controller.state
	var cult: Dictionary = state.cultivator if state != null else {}
	return maxi(1, int(cult.get("reincarnation", 1)))


static func _rank_label(rank: int) -> String:
	var names := ["一转", "二转", "三转", "四转", "五转"]
	return names[clampi(rank, 1, 5) - 1]


# P2a §16.13/§16.5 ending recap: sworn contracts only, in state.contracts
# order; desc already carries hard-coded numbers and is passed through.
static func _contracts_recap(state, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null or not (state.contracts is Array):
		return out
	var by_id: Dictionary = catalog.get("contract_entry_by_id", {})
	for x in state.contracts:
		var id := str(x)
		var entry: Dictionary = by_id.get(id, {})
		out.append({
			"id": id,
			"label": str(entry.get("label", id)),
			"desc": str(entry.get("desc", "")),
			"rules": (entry.get("rules", []) as Array).duplicate(true),
		})
	return out


static func _contracts_sworn_count(state) -> int:
	if state == null or not (state.contracts is Array):
		return 0
	return (state.contracts as Array).size()


# R14.6⑧ (night batch): DDA recap — event log is the single source of truth
# for marker triggers; markers keep appearance order, deduped.
static func _dda_trigger_count(state) -> int:
	if state == null or state.event_log == null:
		return 0
	var count := 0
	for event in state.event_log:
		if str(event.get("action", "")) == "dda_marker":
			count += 1
	return count


static func _dda_marker_recap(state, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null or state.event_log == null:
		return out
	var seen := {}
	for event in state.event_log:
		if str(event.get("action", "")) != "dda_marker":
			continue
		for marker_value in event.get("targets", []):
			var marker := str(marker_value)
			if seen.has(marker):
				continue
			seen[marker] = true
			out.append({"id": marker, "label": DdaResolverScript.marker_label(marker, catalog)})
	return out


# Shared outcome→ending-type vocabulary (snapshot display and MetaProgress
# contract unlocks must agree on the same ids).
static func ending_type_for(outcome_name: String) -> String:
	match outcome_name:
		"success", "ascension_special", "ascension_high": return "success"
		"risky_success", "ascension_medium": return "risky"
		"survived_failure", "ascension_low": return "retreat"
		"death": return "death"
		"gu_fall": return "gu_fall"
		"true_ending": return "true_ending"
	return "retreat"


static func blow_text(id: String) -> String:
	match id:
		"stone_palm": return "石掌"
		"pounce": return "伏身扑咬"
		_: return "敌手攻势"


static func _enc_action(c: Dictionary) -> Dictionary:
	var command: Dictionary = c.get("command", {}).duplicate(true)
	var state_version := int(c.get("state_version", -1))
	var node_id := str(c.get("node_id", command.get("node_id", "")))
	var session_node_id := str(c.get("session_node_id", command.get("session_node_id", node_id)))
	if not command.is_empty() and str(command.get("type", "")) == "action_card":
		command["state_version"] = state_version
		command["node_id"] = node_id
		command["session_node_id"] = session_node_id
	return {
		"id": str(c.get("id", "")),
		"label": str(c.get("title", "")),
		"detail": str(c.get("summary", "")),
		"dangerous": _is_dangerous(c),
		"quality": str(c.get("quality", "")),
		"effect": str(c.get("summary", "")),
		# T6-E tooltip 一致性（§16.5 缺段隐藏）：cost 段以玩家可读短文输出，
		# 空代价输出空串让段落隐藏；绝不把原始 Dictionary str 进文案。
		"cost": _cost_note(c.get("cost", {})),
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
		"executable": bool(c.get("executable", true)),
		"block_reason": str(c.get("block_reason", "")),
		"expected_gain": c.get("expected_gain", []).duplicate(),
		"known_risk": c.get("known_risk", []).duplicate(),
		"unknown_note": str(c.get("unknown_note", "")),
		"remedy_hints": c.get("remedy_hints", []).duplicate(),
		"command": command,
		"state_version": state_version,
		"node_id": node_id,
		"session_node_id": session_node_id,
	}


## T6-E：行动代价字典 → 固定数值短文（§16.5 数值写死禁模糊）；空代价返回空串。
static func _cost_note(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array[String] = []
	var labels := {"stone": "元石", "lifespan": "寿元", "spirit": "真元", "hp": "气血", "time": "时辰"}
	for key in labels:
		if int(cost.get(str(key), 0)) > 0:
			parts.append("%s ×%d" % [str(labels[key]), int(cost[str(key)])])
	if cost.has("gu_ids"):
		var gu_names: Array[String] = []
		for gid_value in cost["gu_ids"]:
			gu_names.append(DisplayText.gu(str(gid_value)))
		if not gu_names.is_empty():
			parts.append("耗蛊：" + "、".join(gu_names))
	return " · ".join(parts)


static func _statuses_to_list(statuses: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for curse_id in statuses:
		var entry = statuses[curse_id]
		var layers := 0
		if entry is Dictionary:
			layers = int(entry.get("layers", 0))
		else:
			layers = int(entry)
		out.append({"name": DisplayText.fact(str(curse_id)), "stacks": layers})
	return out


static func _is_dangerous(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	if int(cost.get("lifespan", 0)) > 0:
		return true
	if int(cost.get("soul", 0)) > 0:
		return true
	var risk := str(card.get("known_risk", ""))
	return "反噬" in risk or "魂魄" in risk or "寿元" in risk


static func _synthesis_options(state, catalog: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if str(state.school) != "refine":
		return options
	var synthesis: Dictionary = catalog.get("synthesis", {})
	if synthesis.is_empty():
		return options
	var cfg: Dictionary = synthesis.get("battle", {})
	var streak := int(state.synthesis_fail_streak)
	for entry_value in synthesis.get("battle_recipes", []):
		var entry: Dictionary = entry_value
		options.append(_synthesis_option(entry, cfg, streak, state, catalog, false))
	if synthesis.has("battle_blind"):
		options.append(_synthesis_option(synthesis.get("battle_blind", {}), cfg, streak, state, catalog, true))
	return options


static func _synthesis_option(recipe: Dictionary, cfg: Dictionary, streak: int, state, _catalog: Dictionary, blind: bool) -> Dictionary:
	var cost: Dictionary = recipe.get("material_cost", {})
	var affordable := true
	for material_id_value in cost:
		if int(state.materials.get(str(material_id_value), 0)) < int(cost[material_id_value]):
			affordable = false
			break
	var base := clampi(int(cfg.get("success_base_pct", 60)), 0, 99)
	var per_fail := maxi(1, int(cfg.get("per_fail_bonus_pct", 10)))
	var max_bonus := clampi(int(cfg.get("max_bonus_pct", 30)), 0, 99)
	var penalty := clampi(int(cfg.get("blind_penalty_pct", 20)), 0, base) if blind else 0
	var chance := clampi(base + mini(streak * per_fail, max_bonus) - penalty, 0, 99)
	return {
		"id": str(recipe.get("id", "battle_blind")),
		"blind": blind,
		"cost": cost,
		"chance": chance,
		"affordable": affordable,
		"temp_card": str(recipe.get("temp_card_id", "")),
	}


static func _resources(state) -> Dictionary:
	var cult: Dictionary = state.cultivator if state != null else {}
	return {
		"yuanstone": int(state.stone) if state != null else 0,
		"shouyuan": int(cult.get("lifespan", 0)),
		"hunpo": int(cult.get("soul", 0)),
	}


## 局内行囊是 RunState 的只读投影。材料、蛊虫、已结算收获与已知情报在此
## 统一呈现，避免 HUD 以一个误导性的“材料总数”替代真实库存。
static func _inventory(state, catalog: Dictionary) -> Dictionary:
	var materials: Array[Dictionary] = []
	var material_defs: Dictionary = catalog.get("material_by_id", {})
	if state != null:
		for material_id_value in state.materials.keys():
			var material_id := str(material_id_value)
			var quantity := int(state.materials[material_id_value])
			if quantity <= 0:
				continue
			var definition: Dictionary = material_defs.get(material_id, {})
			materials.append({
				"id": material_id,
				"name": str(definition.get("name", definition.get("name_zh", DisplayText.material(material_id)))),
				"quantity": quantity,
			})
	materials.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))

	var gu_instances: Array[Dictionary] = []
	var gu_defs: Dictionary = catalog.get("gu_by_id", {})
	if state != null:
		for instance_id_value in state.gu_instances.keys():
			var instance_id := str(instance_id_value)
			var instance: Dictionary = state.gu_instances[instance_id_value]
			var definition_id := str(instance.get("definition_id", ""))
			var definition: Dictionary = gu_defs.get(definition_id, {})
			gu_instances.append({
				"id": instance_id,
				"definition_id": definition_id,
				"name": str(definition.get("name", definition.get("name_zh", DisplayText.gu(definition_id)))),
				"state": str(instance.get("state", "")),
				"rank": int(instance.get("rank", definition.get("rank", 0))),
				"quality": str(instance.get("quality", definition.get("quality", ""))),
			})
	gu_instances.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))

	var loot: Array[Dictionary] = []
	if state != null:
		for result_value in state.encounter_results:
			if not (result_value is Dictionary):
				continue
			var result: Dictionary = result_value
			loot.append({
				"id": str(result.get("id", result.get("action_id", "result"))),
				"name": DisplayText.result(result),
			})
		if loot.is_empty():
			for event_value in state.event_log.slice(maxi(0, state.event_log.size() - 8)):
				if event_value is Dictionary and str((event_value as Dictionary).get("action", "")).contains("loot"):
					var event: Dictionary = event_value
					loot.append({"id": str(event.get("action", "loot")), "name": str(event.get("reason", "获得收获"))})

	var intel: Array[Dictionary] = []
	if state != null:
		for fact_id_value in state.known_facts:
			var fact_id := str(fact_id_value)
			intel.append({"id": fact_id, "name": DisplayText.fact(fact_id)})
	return {"materials": materials, "gu_instances": gu_instances, "loot": loot, "intel": intel}


# C1-min §16.13: real sworn contracts (labels via the catalog) instead of the
# old body-imprint placeholder.
static func _contracts(state, catalog: Dictionary = {}) -> Array:
	var out: Array = []
	if state == null or not (state.contracts is Array):
		return out
	var by_id: Dictionary = catalog.get("contract_entry_by_id", {})
	for x in state.contracts:
		var id := str(x)
		out.append(str(by_id.get(id, {}).get("label", id)))
	return out


static func _death_lines(state) -> Dictionary:
	var cult: Dictionary = state.cultivator if state != null else {}
	var life := int(cult.get("lifespan", 0))
	var soul := int(cult.get("soul", 0))
	var health := int(state.health) if state != null else 0
	var health_max := int(state.max_health) if state != null else 0
	if health_max <= 0:
		health_max = maxi(health, 1)
	var life_max := int(cult.get("lifespan_max", life))
	if life_max <= 0:
		life_max = maxi(life, 1)
	var soul_max := int(cult.get("soul_max", soul))
	if soul_max <= 0:
		soul_max = maxi(soul, 1)
	var backlash := 0
	var statuses: Dictionary = cult.get("statuses", {})
	for cid in statuses:
		var e = statuses[cid]
		backlash += int(e.get("layers", 0)) if e is Dictionary else int(e)
	var backlash_max := 3
	# 进度语义：value=朝死亡推进量（寿元/魂魄用「已消耗」，反噬用「层数」）；
	# threshold=危险临界，value>=threshold 即预警。寿元/魂魄剩余越低越危险。
	var life_floor := 5
	var soul_floor := 2
	var life_consumed := maxi(0, life_max - life)
	var soul_consumed := maxi(0, soul_max - soul)
	var life_danger := life <= life_floor
	var soul_danger := soul <= soul_floor
	var health_floor := maxi(1, ceili(float(health_max) * 0.25))
	var health_danger := health <= health_floor
	var backlash_danger := backlash >= backlash_max
	return {
		"health": {
			"id": "health",
			"name": "气血",
			"value": health,
			"threshold": health_floor,
			"remaining": health,
			"max": health_max,
			"danger": health_danger,
			"cause_id": "death_cause_battle",
			"detail": DisplayText.death_cause("death_cause_battle"),
		},
		"shouyuan": {
			"id": "shouyuan",
			"name": DisplayText.death_line("shouyuan"),
			"value": life_consumed,
			"threshold": life_max - life_floor,
			"remaining": life,
			"max": life_max,
			"danger": life_danger,
			"cause_id": "death_cause_lifespan",
			"detail": DisplayText.death_line_detail("shouyuan"),
		},
		"hunpo": {
			"id": "hunpo",
			"name": DisplayText.death_line("hunpo"),
			"value": soul_consumed,
			"threshold": soul_max - soul_floor,
			"remaining": soul,
			"max": soul_max,
			"danger": soul_danger,
			"cause_id": "death_cause_soul",
			"detail": DisplayText.death_line_detail("hunpo"),
		},
		"backlash": {
			"id": "backlash",
			"name": DisplayText.death_line("backlash"),
			"value": backlash,
			"threshold": backlash_max,
			"remaining": backlash,
			"max": backlash_max,
			"danger": backlash_danger,
			"cause_id": "death_cause_backlash",
			"detail": DisplayText.death_line_detail("backlash"),
		},
	}


static func _death_cause_from_state(state) -> String:
	var cult: Dictionary = state.cultivator if state != null else {}
	var life := int(cult.get("lifespan", 0))
	var soul := int(cult.get("soul", 0))
	var backlash := 0
	var statuses: Dictionary = cult.get("statuses", {})
	for cid in statuses:
		var e = statuses[cid]
		backlash += int(e.get("layers", 0)) if e is Dictionary else int(e)
	if life <= 0:
		return "death_cause_lifespan"
	if soul <= 0:
		return "death_cause_soul"
	if backlash >= 3:
		return "death_cause_backlash"
	return "death_cause_battle"


## 精准死因只读三字段（T5-B 结算联动）：id / 结算徽章短句 / 完整成因文案。
## 数据源为 state 终局字段（finalize_death 只落 terminal 标记，不记死因），
## 只读扫描，不改写任何状态；恒返回非空 id（战斗兜底）。非死亡结局由调用方
## 传空（见 ending()）。
static func death_cause_fields(state) -> Dictionary:
	var id := _death_cause_from_state(state)
	return {
		"id": id,
		"short": DisplayText.death_cause_short(id),
		"text": DisplayText.death_cause(id),
	}


static func _node_label(n: Dictionary) -> String:
	return str(n.get("label", DisplayText.node(str(n.get("id", "")))))

# T9.1: snapshot transparency v2 (spec 17.2, eight groups). Every group
# projects straight from its owning rule module - the snapshot carries the
# module's own output, never a copy. The section is strictly read-only: it
# never assigns into run state and never calls setters. `_`-prefixed info
# keys never enter a snapshot.
static func transparency_v2(controller) -> Dictionary:
	var state = controller.state
	if state == null:
		return {}
	var cat: Dictionary = controller.catalog if controller.catalog != null else {}
	return {
		"group1_gu_ledger": _v2_group1(state, cat),
		"group2_core": _v2_group2(state, cat),
		"group3_recipes": _v2_group3(cat),
		"group4_feeding": _v2_group4(state, cat),
		"group5_market": _v2_group5(cat),
		"group6_body": _v2_group6(state, cat),
		"group7_action": _v2_group7(cat),
		"group8_soul": _v2_group8(state, cat),
	}


# Group 1: gu actual yuan/thoughts/turn-usage/maintenance from the battle2
# ledger (contract 6). The ledger is read from authoritative RunState; when no
# battle is active it projects an empty inactive ledger shape - it never
# fabricates a fresh full-capacity turn.
static func _v2_group1(state, cat: Dictionary) -> Dictionary:
	var ledger: Dictionary = state.battle2_ledger
	if ledger.is_empty():
		return {
			"active": false,
			"phase": "",
			"thoughts_left": 0,
			"thought_used": 0,
			"reserved": 0,
			"gu_used": {},
			"actions_used": {"move": false, "strike": false, "dodge": false, "grapple": false},
			"maintained": [],
			"ongoing": [],
		}
	return {
		"active": true,
		"phase": str(ledger.get("phase", "")),
		"thoughts_left": int(ledger.get("thoughts_left", 0)),
		"thought_used": int(ledger.get("thought_used", 0)),
		"reserved": int(ledger.get("reserved", 0)),
		"gu_used": (ledger.get("gu_used", {}) as Dictionary).duplicate(true),
		"actions_used": (ledger.get("actions_used", {}) as Dictionary).duplicate(true),
		"maintained": (ledger.get("maintained", []) as Array).duplicate(),
		"ongoing": (ledger.get("ongoing", []) as Array).duplicate(true),
	}


# Group 2: core type / depth / evidence / tilt suggestion / replacement
# cost sources.
static func _v2_group2(state, cat: Dictionary) -> Dictionary:
	var core_definition: Dictionary = {}
	var core_id := ""
	for instance_id in state.gu_instances:
		var instance: Dictionary = state.gu_instances[str(instance_id)]
		if not (instance.get("core_state", {}) as Dictionary).is_empty():
			core_id = str(instance_id)
			core_definition = cat.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			break
	var title := "common_core"
	var evidence := {}
	if not core_definition.is_empty():
		title = CoreGuRulesScript.core_depth(core_definition, cat)
		evidence = CoreGuRulesScript.hub_evidence(core_definition, cat)
	var tilt := CoreGuRulesScript.tilt_pool(
			cat.get("school_pools", {}), {"definition_id": str(core_definition.get("id", ""))}, cat)
	return {
		"confirmed_instance": core_id,
		"depth": title,
		"hub_evidence": evidence,
		"tilt_suggestions": tilt.get("suggestions", {}),
	}


# Group 3: recipe identity / stages / candidates / success conditions.
static func _v2_group3(cat: Dictionary) -> Array:
	var out: Array = []
	for recipe in cat.get("refinement_recipes", []):
		var entry := {
			"id": str(recipe.get("id", "")),
			"kind": str(recipe.get("kind", "")),
			"product_rule": str(recipe.get("product_rule", "")),
			"aux_core_warning": bool(recipe.get("aux_core_warning", false)),
		}
		if recipe.has("identity_requirements"):
			entry["identity_requirements"] = (recipe["identity_requirements"] as Dictionary).duplicate(true)
		if recipe.has("allow_substitute"):
			entry["allow_substitute"] = (recipe["allow_substitute"] as Dictionary).duplicate(true)
		if recipe.has("stages"):
			entry["stages"] = (recipe["stages"] as Array).duplicate(true)
		if recipe.has("candidate_pool"):
			entry["candidate_pool"] = RecipeRulesScript.resolve_candidates(recipe, cat)
		out.append(entry)
	return out


# Group 4: feeding need / matching / substitution / hunger & death preview,
# plus the soft budget report.
static func _v2_group4(state, cat: Dictionary) -> Dictionary:
	var instances: Array = []
	for instance_id in state.gu_instances:
		instances.append(state.gu_instances[str(instance_id)])
	var preview := FeedingRulesScript.preview_settle(instances, state.materials, {}, cat)
	var report := FeedingRulesScript.budget_report(0.0, 0.0, cat)
	return {"preview": preview, "budget_report": report}


# Group 5: market prices / demand / estimates / refusal reasons.
static func _v2_group5(cat: Dictionary) -> Dictionary:
	var blood: Dictionary = cat.get("loot_tables", {}).get("materials", {}).get("beast_blood", {})
	return {
		"t1_base": float(MarketRulesScript.t1_material_base_price(cat)),
		"rank3_value": float(MarketRulesScript.rank_standard_price(3, cat)),
		"resale_50": float(MarketRulesScript.public_resale(10.0, cat)),
		"low_liquidity_30": float(MarketRulesScript.low_liquidity_resale(10.0, cat)),
		"demand_quote": float(MarketRulesScript.demand_quote(10.0, 1, 1, cat)["unit_price"]),
		"gu_public_1": float(MarketRulesScript.gu_public_price(1, cat)),
		"gu_recycle_1": float(MarketRulesScript.gu_recycle_price(1, cat)),
		"gu_estimate_1": float(MarketRulesScript.gu_estimate(1, cat)),
		"blood_trade_public_reason": str(BloodQiRulesScript.trade_gate(blood, "public", cat).get("reason", "")),
	}


# Group 6: safe/actual strength, outward damage, overload self damage and the
# death warning from the body preflight.
static func _v2_group6(state, cat: Dictionary) -> Dictionary:
	var body := CultivatorRulesScript.body(state.cultivator, cat)
	var strength := float(body["strength"])
	var capacity := float(body["body_capacity"])
	var preflight := BodyRulesScript.strike_preflight(strength, capacity, float(state.health), cat)
	return {
		"safe_strength": float(BodyRulesScript.safe_strength(capacity)),
		"actual_strength": strength,
		"outward_damage": float(BodyRulesScript.unarmed_strike_damage(strength, 1.0, cat)),
		"overload_self_damage": float(BodyRulesScript.overload_self_damage(strength, capacity, cat)),
		"lethal_confirm_required": bool(preflight.get("lethal_confirm_required", false)),
		"death_cause": str(preflight.get("cause", "")),
	}


# Group 7: enemy intent window / distance bands / speed conflict / reaction
# readiness (projections over the deterministic action rules).
static func _v2_group7(cat: Dictionary) -> Dictionary:
	return {
		"distances": ["far", "medium", "close", "touch"],
		"conflict_order": str(ActionResolverScript.conflict_order("quick", 3, "quick", 3)),
		"reaction_check": ActionResolverScript.reaction_allowed(true, "grapple"),
		"disengage_open": bool(ActionResolverScript.disengage_window("touch", "close").get("open", false)),
		"strike_only_at_contact": bool(ActionResolverScript.strike_possible("touch", "touch")),
	}


# Group 8: soul five quantities and the loss-of-control thresholds.
static func _v2_group8(state, cat: Dictionary) -> Dictionary:
	return {
		"snapshot": SoulRulesScript.snapshot(state.cultivator),
		"composure": SoulRulesScript.composure_layers(state.cultivator, cat),
		"beast_sight": SoulRulesScript.beast_sight(state.cultivator, cat),
		"float_above_capacity": bool(SoulRulesScript.float_above_capacity(state.cultivator)),
		"growth_forecast": SoulRulesScript.soul_growth_forecast(state.cultivator, 0.0, cat),
	}
