class_name RunSnapshotBuilder
extends RefCounted


# Builds the read-only snapshots the RUI screens render. Inputs come from the
# RunController; this class never mutates run state, only projects it.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")


static func for_screen(screen: String, controller) -> Dictionary:
	match screen:
		"Title": return hall(controller)
		"Map": return map(controller)
		"Encounter": return encounter(controller)
		"Battle": return battle(controller)
	return {}


static func hall(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var meta = controller.meta
	var schools: Dictionary = catalog.get("schools", {})
	var school_list: Array[Dictionary] = []
	for school_id in schools:
		var sdata: Dictionary = schools[school_id]
		var starters: Array = sdata.get("starter_gu_ids", [])
		var starter_names: Array[String] = []
		for sid in starters:
			starter_names.append(DisplayText.gu(str(sid)))
		school_list.append({
			"id": str(school_id),
			"name": str(sdata.get("name", str(school_id))),
			"summary": str(sdata.get("summary", "")),
			"starter_gu_ids": starters,
			"starter_gu_names": starter_names,
		})
	var runs := 0
	var endings := 0
	var won := 0
	var deaths := 0
	if meta != null:
		runs = int(meta.statistics.get("runs_started", 0))
		endings = meta.gu_codex_ids.size() + meta.recipe_codex_ids.size() + meta.inheritance_codex_ids.size()
		won = int(meta.statistics.get("runs_won", 0))
		deaths = int(meta.statistics.get("deaths", 0))
	return {
		"has_save": FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
		"hall_subview": str(controller._hall_subview),
		"selected_school": str(controller._selected_school),
		"available_schools": school_list,
		"contracts": [],
		"meta_stats": {"runs": runs, "endings": endings, "won": won, "deaths": deaths},
		"codex": _codex(catalog, meta),
		"journal": _journal(meta),
	}


## A5 图鉴数据（只读）：蛊 / 敌人 / 配方 / 传承 / 遗物 五类，每类带 unlocked 标记。
## 遭遇即解锁（meta.codex ids）；未解锁只显剪影（§16.20）。
static func _codex(catalog: Dictionary, meta) -> Dictionary:
	var unlocked_gu: Array = meta.gu_codex_ids if meta != null else []
	var unlocked_recipes: Array = meta.recipe_codex_ids if meta != null else []
	var unlocked_relics: Array = meta.relic_codex_ids if meta != null else []
	var unlocked_inheritance: Array = meta.inheritance_codex_ids if meta != null else []

	var gu_entries: Array[Dictionary] = []
	for g in catalog.get("gu", []):
		var gid := str(g.get("id", ""))
		gu_entries.append({
			"id": gid,
			"name": DisplayText.gu(gid),
			"school": str(g.get("school", "")),
			"rarity": str(g.get("rarity", "common")),
			"unlocked": unlocked_gu.has(gid),
		})

	var enemy_entries: Array[Dictionary] = []
	for e in catalog.get("enemies", []):
		var eid := str(e.get("id", ""))
		enemy_entries.append({
			"id": eid,
			"name": eid,
			"tier": str(e.get("tier", "")),
			"unlocked": unlocked_gu.has(eid),
		})

	var recipe_entries: Array[Dictionary] = []
	for r in catalog.get("refinement", {}).get("recipes", []):
		var rid := str(r.get("id", ""))
		recipe_entries.append({
			"id": rid,
			"kind": str(r.get("kind", "")),
			"output_gu": DisplayText.gu(str(r.get("output_gu_id", ""))),
			"unlocked": unlocked_recipes.has(rid),
		})

	var relic_entries: Array[Dictionary] = []
	for r in catalog.get("relics", []):
		var rid := str(r.get("id", ""))
		relic_entries.append({"id": rid, "name": rid, "unlocked": unlocked_relics.has(rid)})

	var inheritance_entries: Array[Dictionary] = []
	for ih in catalog.get("inheritances", []):
		var iid := str(ih.get("id", ""))
		inheritance_entries.append({"id": iid, "name": iid, "unlocked": unlocked_inheritance.has(iid)})

	return {
		"gu": gu_entries,
		"enemies": enemy_entries,
		"recipes": recipe_entries,
		"relics": relic_entries,
		"inheritances": inheritance_entries,
	}


## A7 手记库（§16.9 叙事沉淀）。当前 meta 仅统计战绩；手记条目在后续结算沉淀时
## 写入，现展示空态 + 轮回概览占位（诚实呈现，不编造叙事）。
static func _journal(meta) -> Dictionary:
	var entries: Array[Dictionary] = []
	if meta != null:
		var stats: Dictionary = meta.statistics
		entries.append({
			"title": "轮回纪要",
			"body": "开悟 %d 局 · 通关 %d · 身死 %d。碎片手记将在此沉淀。" % [
				int(stats.get("runs_started", 0)),
				int(stats.get("runs_won", 0)),
				int(stats.get("deaths", 0)),
			],
		})
	return {"entries": entries, "count": entries.size()}


static func map(controller) -> Dictionary:
	var state = controller.state
	var route: Array = controller.route
	var nodes: Array[Dictionary] = []
	for n in MapGeneratorScript.visible_nodes(route, state, 2):
		nodes.append({
			"id": str(n.get("id", "")),
			"type": str(n.get("type", "")),
			"label": _node_label(n),
			"layer": int(n.get("layer", 0)),
		})
	var reach: Array[String] = []
	for n in MapGeneratorScript.reachable_nodes(route, state):
		reach.append(str(n["id"]))
	var gu_satchel: Array[Dictionary] = []
	for inst_key in state.gu_instances:
		var inst: Dictionary = state.gu_instances[inst_key]
		gu_satchel.append({
			"id": str(inst_key),
			"name": DisplayText.gu(str(inst.get("definition_id", ""))),
		})
	return {
		"nodes": nodes,
		"current_node_id": str(state.current_node_id),
		"reachable_ids": reach,
		"gu_satchel": gu_satchel,
		"resources": _resources(state),
		"contracts": _contracts(state),
		"anomalies": [],
		"death_lines": _death_lines(state),
	}


static func encounter(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var meta = controller.meta
	var current_node: Dictionary = controller.current_node
	var knowledge: Dictionary = {}
	if meta != null:
		knowledge = meta.unlocked_random_outcomes
	var actions: Array[Dictionary] = []
	for c in ActionPreviewServiceScript.preview_actions(state, current_node, catalog, knowledge):
		actions.append(_enc_action(c))
	var intel: Dictionary = {}
	if state.known_facts.has("procured_weakness"):
		intel = {"weakness": "已探明弱点，战斗增伤", "cost": "情报"}
	return {
		"node": {
			"title": _node_label(current_node),
			"desc": str(current_node.get("summary", current_node.get("desc", ""))),
			"type": str(current_node.get("type", "")),
		},
		"actions": actions,
		"intel": intel,
		"player": _player_panel(state),
		"resources": _resources(state),
		"contracts": _contracts(state),
		"anomalies": [],
		"death_lines": _death_lines(state),
	}


## C4 侧边自身状态面板（§16.5 事件侧边快捷查看气血/魂魄/元石/蛊虫）。
static func _player_panel(state) -> Dictionary:
	var cult: Dictionary = state.cultivator
	var gu_names: Array[String] = []
	for inst_key in state.gu_instances:
		var inst: Dictionary = state.gu_instances[inst_key]
		gu_names.append(DisplayText.gu(str(inst.get("definition_id", ""))))
	return {
		"hp": int(cult.get("health", state.health)),
		"max_hp": maxi(1, int(cult.get("max_health", state.max_health))),
		"primordial": int(state.essence),
		"soul": int(cult.get("soul", 0)),
		"stone": int(state.stone),
		"gu_names": gu_names,
	}


static func battle(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var battle_data: Dictionary = controller.current_battle
	var enemy_kind := str(battle_data.get("enemy_kind", ""))
	var flags: Array = battle_data.get("flags", [])
	var guarded: bool = flags.has("guarded")
	var enemies: Array[Dictionary] = [{
		"id": str(battle_data.get("battle_id", "")),
		"name": DisplayText.enemy(enemy_kind),
		"hp": int(battle_data.get("enemy_hp", 0)),
		"max_hp": maxi(1, int(battle_data.get("enemy_max_hp", 1))),
		"shield": 2 if guarded else 0,
		"intent": _intent_to_screen(battle_data.get("visible_intent", {})),
	}]
	var cult: Dictionary = state.cultivator
	var player := {
		"hp": int(cult.get("health", state.health)),
		"max_hp": maxi(1, int(cult.get("max_health", state.max_health))),
		"shield": 2 if guarded else 0,
		"primordial": int(state.essence),
		"soul": int(cult.get("soul", 0)),
		"statuses": _statuses_to_list(cult.get("statuses", {})),
	}
	var hand: Array[Dictionary] = []
	for c in ActionPreviewServiceScript.preview_battle_actions(battle_data, state, catalog):
		hand.append(_battle_card(c))
	return {
		"enemies": enemies,
		"player": player,
		"hand": hand,
		"synthesis": _synthesis_options(state, catalog),
		"can_ultimate": false,
		"resources": _resources(state),
		"contracts": _contracts(state),
		"anomalies": [],
		"death_lines": _death_lines(state),
	}


static func ending(controller, outcome: Dictionary, journal: Array[Dictionary], run_data: Dictionary) -> Dictionary:
	var state = controller.state
	var otype := str(outcome.get("outcome", "survived_failure"))
	var etype := "retreat"
	match otype:
		"success": etype = "success"
		"risky_success": etype = "risky"
		"survived_failure": etype = "retreat"
		"death": etype = "death"
		"gu_fall": etype = "gu_fall"
		"true_ending": etype = "true_ending"
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
	var death_cause_id := ""
	if otype == "death":
		death_cause_id = _death_cause_from_state(state)
	return {
		"title": DisplayText.outcome(otype),
		"ending_type": etype,
		"death_cause_id": death_cause_id,
		"death_cause": DisplayText.death_cause(death_cause_id),
		"key_decisions": decisions,
		"gains_losses": gains,
		"resource_balance": {"yuanstone": int(state.stone) if state != null else 0, "shouyuan": int(cult.get("lifespan", 0))},
		"unlocks": unlocks,
		"aftermath": "修行札记已留存，可于大厅图鉴查阅本次所得。",
	}


static func blow_text(id: String) -> String:
	match id:
		"stone_palm": return "石掌"
		"pounce": return "伏身扑咬"
		_: return "敌手攻势"


static func _enc_action(c: Dictionary) -> Dictionary:
	return {
		"id": str(c.get("id", "")),
		"label": str(c.get("title", "")),
		"detail": str(c.get("summary", "")),
		"dangerous": _is_dangerous(c),
		"quality": "",
		"effect": str(c.get("summary", "")),
		"cost": c.get("cost", {}),
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
	}


static func _battle_card(c: Dictionary) -> Dictionary:
	var cost_dict: Dictionary = c.get("cost", {})
	var cost_num := 0
	for key in cost_dict:
		cost_num += int(cost_dict[key])
	return {
		"id": str(c.get("id", "")),
		"name": str(c.get("title", "")),
		"cost": cost_num,
		"cost_ex": "",
		"effect": str(c.get("summary", "")),
		"quality": "普通",
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
	}


static func _intent_to_screen(i: Dictionary) -> Dictionary:
	var dmg := int(i.get("damage", 0))
	var def := int(i.get("defense", 0))
	if dmg > 0:
		return {"type": "attack", "value": dmg, "detail": str(i.get("label", "造成物理伤害"))}
	if def > 0:
		return {"type": "defend", "value": def, "detail": str(i.get("label", "凝防御"))}
	return {"type": "charge", "value": 0, "detail": "蓄势待发"}


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


static func _synthesis_option(recipe: Dictionary, cfg: Dictionary, streak: int, state, catalog: Dictionary, blind: bool) -> Dictionary:
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
	var mat := 0
	if state != null and state.materials is Dictionary:
		for key in state.materials:
			mat += int(state.materials[key])
	return {
		"yuanstone": int(state.stone) if state != null else 0,
		"shouyuan": int(cult.get("lifespan", 0)),
		"hunpo": int(cult.get("soul", 0)),
		"material": mat,
	}


static func _contracts(state) -> Array:
	var out: Array = []
	if state != null and state.body_imprints is Array:
		for x in state.body_imprints:
			out.append(DisplayText.fact(str(x)))
	return out


static func _death_lines(state) -> Dictionary:
	var cult: Dictionary = state.cultivator if state != null else {}
	var life := int(cult.get("lifespan", 0))
	var soul := int(cult.get("soul", 0))
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
	var backlash_danger := backlash >= backlash_max
	return {
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


static func _node_label(n: Dictionary) -> String:
	return str(n.get("label", DisplayText.node(str(n.get("id", "")))))