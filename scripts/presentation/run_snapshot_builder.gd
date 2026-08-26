class_name RunSnapshotBuilder
extends RefCounted


# Builds the read-only snapshots the RUI screens render. Inputs come from the
# RunController; this class never mutates run state, only projects it.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


static func for_screen(screen: String, controller) -> Dictionary:
	match screen:
		"Title": return hall(controller)
		"Map": return map(controller)
		"Encounter": return encounter(controller)
		"Battle": return battle(controller)
		"Shop": return shop(controller)
		"Rest": return rest(controller)
		"Refine": return refine(controller)
		"Reward": return reward(controller)
		"Npc": return npc(controller)
	return {}


## T5-D 调试面板只读段（§16.22）：保底计数 / 池排除列表 / 当前种子 / 事件数 / DDA 分位。
## 仅由 debug_panel 渲染，绝不反向写入状态。池排除列表域内尚未落地（DisplayText
## 标注「尚未实装」）、DDA 未实装——两者恒空占位，诚实呈现不编造。
static func debug(controller) -> Dictionary:
	var state = controller.state
	if state == null:
		return {}
	return {
		"loot_pity": int(state.loot_pity),
		"material_pity": int(state.material_pity),
		"pool_excluded_ids": [] as Array[String],
		"seed": int(state.seed),
		"event_count": state.event_log.size(),
		"dda_percentile": "",
	}


## 局内节点屏公共骨架（顶栏资源/契约/异变/死线）。
static func _gui_state(controller) -> Dictionary:
	var state = controller.state
	return {
		"resources": _resources(state),
		"contracts": _contracts(state),
		"anomalies": [],
		"death_lines": _death_lines(state),
	}


## 真实节点可行动作（复用 Encounter 屏的 preview_actions，保证数据一致）。
static func _node_actions(controller) -> Array[Dictionary]:
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var knowledge: Dictionary = {}
	if controller.meta != null:
		knowledge = controller.meta.unlocked_random_outcomes
	var actions: Array[Dictionary] = []
	for c in ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, catalog, knowledge):
		actions.append(_enc_action(c))
	return actions


## C3 黑市 / 商店屏快照（数据表 shops.json 真实货架 + 黑市服务）。
static func shop(controller) -> Dictionary:
	var out := _gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var offer_by_id: Dictionary = catalog.get("shop_offer_by_id", {})
	# R6.7 应急支付预览（只读推导）：元石定价高于持有元石的货架项将触发应急支付，
	# UI 据此弹 D1 确认；寿元定价项（无 stone_cost）不参与该判定。
	var stones := int(controller.state.stone)
	var offers: Array[Dictionary] = []
	for offer_key in offer_by_id:
		var o: Dictionary = offer_by_id[offer_key]
		var gid := str(o.get("gu_id", ""))
		var name := DisplayText.gu(gid) if gid != "" else str(o.get("card_key", "货物"))
		var price := str(o.get("stone_cost", 0)) + " 元石"
		var kind := str(o.get("kind", ""))
		if o.has("lifespan_cost"):
			price = str(o.get("lifespan_cost", 0)) + " 寿元"
		offers.append({
			"id": str(offer_key),
			"name": name,
			"kind": kind,
			"price": price,
			"desc": str(o.get("clue", o.get("card_key", ""))),
			"quality": "史诗" if kind == "soul_boost" else ("稀有" if kind in ["purchase", "barter"] else "普通"),
			"curse_warning": kind == "lifespan_deal",
			"will_emergency_pay": int(o.get("stone_cost", 0)) > stones,
		})
	var node_type := str(controller.current_node.get("type", ""))
	out["title"] = "黑市 · 寨市" if node_type == "shop" else ("商队开市" if node_type == "caravan" else "临时寨市")
	out["npc_name"] = "地脉游商" if node_type != "caravan" else "商队执事"
	out["npc_stance"] = "中立"
	out["inflation_note"] = "层数提升物价微涨 · 二次访问 +25%/次 封顶 +100%"
	out["offers"] = offers
	out["services"] = [
		{"id": "remove_gu", "name": "移除蛊虫", "cost": "150 元石", "remaining": 2, "note": "本局剩余 2 次 · 价格递增"},
		{"id": "pool_block", "name": "池屏蔽", "cost": "200 元石", "remaining": 1, "note": "本局剩余 1 次 · 移除≠池排除"},
		{"id": "wash", "name": "洗炼", "cost": "80 元石", "remaining": 3, "note": "重骰一条被动"},
		{"id": "calm", "name": "净化躁动", "cost": "40 元石", "remaining": 3, "note": "清除蛊躁动"},
	]
	out["emergency_note"] = "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付（R6.7）"
	# T6-E 空池回退显示槽位：商店侧暂无可推导的回退信号（货架非奖励池），恒空占位；
	# 领域侧落地 fallback 标记后在此注入（报告已披露该数据源缺口）。
	out["pool_fallback_note"] = ""
	return out


## C5 休整 / 闭关屏快照（rest_hollow 真实休整 + aptitude 洗髓换骨）。
static func rest(controller) -> Dictionary:
	var out := _gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var state = controller.state
	var node_flags: Dictionary = state.node_flags if state != null else {}
	# P2a B: visit/mode flags are scoped per node id, not a hard-coded literal.
	var rest_node_id := str(controller.current_node.get("id", ""))
	var rest_used := str(node_flags.get("%s_used" % rest_node_id, "")) == "used"
	var rest_mode_used := str(node_flags.get("%s_mode" % rest_node_id, "")) == "true"
	var aptitude_raised := str(node_flags.get("aptitude_raised", "")) == "true"

	var choices: Array[Dictionary] = []
	# 调息回血：rest 节点真实命令（rest mode=heal），用后禁用。
	choices.append({
		"id": "heal",
		"label": "调息回血",
		"detail": "回复气血与真元，消耗本次休整",
		"cost": "",
		"disabled": rest_used,
		"reason": "本次已休整" if rest_used else "",
		"curse_warning": false,
	})
	# 温养一蛊：移除负面卡（领域需选蛊实例，UI 暂为占位）。
	choices.append({
		"id": "remove",
		"label": "温养一蛊",
		"detail": "移除一张负面卡 / 免费移除",
		"cost": "",
		"disabled": rest_used or rest_mode_used,
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else "休整二选一"),
		"curse_warning": false,
	})
	# 洗髓换骨：仅闭关/传承节点可用（aptitude.json paths.node_kinds）。
	var node_kind := str(controller.current_node.get("type", ""))
	var apt: Dictionary = catalog.get("aptitude", {})
	var paths: Array = apt.get("paths", []) if apt is Dictionary else []
	var wash_available := false
	var wash_cost := ""
	if paths.size() > 0:
		var p: Dictionary = paths[0]
		var kinds: Array = p.get("node_kinds", [])
		if kinds.has(node_kind):
			wash_available = true
			wash_cost = str(p.get("cost_lifespan", 10)) + " 寿元 + " + str(p.get("cost_stone", 8)) + " 元石"
	if wash_available:
		var at_peak := str(state.aptitude) == "jia" if state != null else false
		choices.append({
			"id": "wash",
			"label": "洗髓换骨",
			"detail": "真元上限 +1（实时刷新）",
			"cost": wash_cost,
			"disabled": aptitude_raised or at_peak,
			"reason": "一局一次 · 已使用" if aptitude_raised else ("资质已至巅峰" if at_peak else "一局一次 · 执行前预检寿元"),
			"curse_warning": false,
		})
	out["title"] = "闭关 · 休整"
	out["note"] = "强制二选一，不可全拿"
	out["choices"] = choices
	out["is_ascension"] = false
	out["growth"] = []
	return out


## C6 炼蛊 / 合成屏快照（refinement_by_id 真实配方 + 盲盒）。
static func refine(controller) -> Dictionary:
	var out := _gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var recipe_by_id: Dictionary = catalog.get("refinement_by_id", {})
	var rec_rows: Array[Dictionary] = []
	for recipe_key in recipe_by_id:
		var r: Dictionary = recipe_by_id[recipe_key]
		var inputs: Array = r.get("input_gu_ids", [])
		var in_names: Array[String] = []
		for iid in inputs:
			in_names.append(DisplayText.gu(str(iid)))
		var output := DisplayText.gu(str(r.get("output_gu_id", "")))
		var fail := "成功配方"
		if r.has("success_roll_max"):
			fail = "失败率 %d%%" % (100 - int(r.get("success_roll_max", 100)))
		rec_rows.append({
			"id": str(recipe_key),
			"name": " + ".join(in_names) + " → " + output,
			"output": output,
			"quality": "稀有",
			"fail_chance": fail,
			"backlash": "失败毁材 · 躁动 +1" if str(r.get("kind", "")) == "combine" else "无躁动",
			"curse": "",
			"unlocked": not bool(r.get("locked", false)),
		})
	rec_rows.append({"id": "blind", "name": "盲盒（随机）", "output": "未知蛊", "quality": "随机", "fail_chance": "失败率 50% · 毁材", "backlash": "躁动 +2", "curse": "诅咒继承⚠", "unlocked": true})
	out["title"] = "炼蛊台"
	out["channels"] = [
		{"id": "fixed", "label": "定向配方"},
		{"id": "combine", "label": "组合标签"},
		{"id": "blind", "label": "盲盒随机"},
	]
	out["active_channel"] = "fixed"
	out["inputs"] = []
	out["slot_ok"] = false
	out["recipes"] = rec_rows
	out["dismantle_slots"] = []
	out["streak_note"] = "连续失败计数 Run 内清零，成功率加成永不到 100%"
	return out


## C2 奖励 / 战利品屏快照（三选一 + 保底/回退小字）。
static func reward(controller) -> Dictionary:
	var out := _gui_state(controller)
	out["title"] = "战利品"
	out["rewards"] = [
		{"id": "r1", "name": "月光蛊", "kind": "蛊 · 战斗奖励", "quality": "稀有", "effect": "造成月光伤害并附加「月息」层", "cost": "获取即入蛊囊", "curse_warning": false},
		{"id": "r2", "name": "石甲蛊", "kind": "蛊 · 精英奖励", "quality": "史诗", "effect": "护盾 +8", "cost": "代价：躁动 +1", "curse_warning": false},
		{"id": "r3", "name": "元石 +15", "kind": "货币", "quality": "普通", "effect": "直接入账", "cost": "", "curse_warning": false},
	]
	out["full_satchel"] = false
	out["pity_note"] = "（保底：连续普通后，下次掉落品质有较大概率提升）"
	# T6-E 空池回退小字：领域暂无回退标记，按简报裁定以既有「奖励列表为空」信号
	# 只读推导；非空不展示，杜绝常驻假提示。领域侧落地 fallback 标记后替换此推导。
	out["pool_fallback_note"] = _reward_fallback_note(out["rewards"])
	return out


## 空池回退小字推导（只读）：奖励列表为空视作空池回退信号，否则不展示。
static func _reward_fallback_note(rewards: Array) -> String:
	if rewards.is_empty():
		return "（空池回退：已切至基础池）"
	return ""


## C8 NPC 交涉屏快照（contact 节点真实交涉选项 + 立场/恶名）。
static func npc(controller) -> Dictionary:
	var out := _gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var npcs: Array = catalog.get("npcs", [])
	var npc_id := str(controller.current_node.get("npc_id", ""))
	if npc_id == "" and npcs.size() > 0:
		npc_id = str(npcs[0].get("id", ""))
	var npc_name := "无名散修"
	if npc_id == "caravan_steward":
		npc_name = "商队执事"
	elif npc_id == "earth_vein_scout":
		npc_name = "地脉斥候"
	elif npc_id == "wandering_healer":
		npc_name = "游方医修"
	elif npc_id == "ridge_extortionist":
		npc_name = "山岭索贿者"
	elif str(controller.current_node.get("type", "")) == "contact":
		npc_name = "拦路散修"
	var state = controller.state
	var notoriety := 0
	if state != null:
		notoriety = ResolverScript.notoriety(state)
	var stance := "中立"
	if state != null and state.node_flags != null:
		if str(state.node_flags.get("reputation_extreme_stance", "")) == "true":
			stance = "极度仇恨"
		elif str(state.node_flags.get("reputation_hostile", "")) == "true":
			stance = "敌视"
	# 真实交涉选项：contact 节点 neutral_wanderer 的 negotiate/deceive/fight/retreat
	var talk_options: Array[Dictionary] = []
	for a in _node_actions(controller):
		var aid := str(a.get("id", ""))
		if aid in ["leave", "fight", "retreat", "negotiate", "deceive"]:
			var label := str(a.get("label", aid))
			var detail := str(a.get("detail", ""))
			talk_options.append({
				"id": aid,
				"label": label,
				"detail": detail,
				"danger": aid in ["fight", "deceive"],
			})
	if talk_options.is_empty():
		talk_options = [
			{"id": "negotiate", "label": "友善攀谈", "detail": "了解情报与需求", "danger": false},
			{"id": "deceive", "label": "诈言诓骗", "detail": "恶名威慑 · 可能翻脸", "danger": true},
			{"id": "fight", "label": "出手试探", "detail": "直接开战", "danger": true},
			{"id": "retreat", "label": "退避三舍", "detail": "花 1 元石改道", "danger": false},
		]
	out["npc_name"] = npc_name
	out["stance"] = stance
	out["stance_note"] = "交涉失败将种子化翻转敌视" if stance == "中立" else ("高恶名使对方戒备" if stance == "敌视" else "极度仇恨：无法撤退")
	out["notoriety"] = notoriety
	out["notoriety_note"] = "恶名高亮：威慑部分路线 / 关闭部分交易"
	out["offers"] = [
		{"id": "o1", "name": "回购货物", "price": "5 元石", "desc": "出手一批闲置物资"},
		{"id": "o2", "name": "情报买卖", "price": "3 元石", "desc": "换取下一片区域线索"},
	]
	out["barter"] = [
		{"id": "b1", "name": "迹眼蛊 换 雾步蛊", "give": "迹眼蛊", "take": "雾步蛊", "note": "以物易物 · 需空位校验"},
	]
	out["talk_options"] = talk_options
	out["can_flee"] = stance != "极度仇恨"
	return out


static func hall(controller) -> Dictionary:
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
		"contracts": _available_contracts(meta, catalog),
		"meta_stats": {"runs": runs, "endings": endings, "won": won, "deaths": deaths},
		# D4 预留（§16.22）：SaveRepository.load_meta_file 在版本不符时返回 null，与无档/损坏
		# 不可区分；待领域侧暴露版本冲突标记后在此注入提示文案，hall_view 已预留 warn Toast 槽位。
		"hall_version_warning": "",
		"codex": _codex(catalog, meta),
		"journal": _journal(meta, catalog),
	}


# C1-min §16.13: the hall lists every contract with its exact numbers;
# ending-locked entries are marked so the UI can gate its checkboxes.
static func _available_contracts(meta, catalog: Dictionary) -> Array:
	var unlocked: Array[String] = []
	if meta != null and meta.has_method("unlocked_contracts"):
		unlocked = meta.unlocked_contracts(catalog)
	var by_id: Dictionary = catalog.get("contract_entry_by_id", {})
	var out: Array = []
	for id in unlocked:
		var entry: Dictionary = by_id.get(str(id), {})
		out.append("%s：%s" % [str(entry.get("label", str(id))), str(entry.get("desc", ""))])
	for entry_id in by_id:
		if unlocked.has(str(entry_id)):
			continue
		var locked_entry: Dictionary = by_id[entry_id]
		out.append("%s（未解锁）" % str(locked_entry.get("label", str(entry_id))))
	return out


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


## A7 手记库（§16.9 叙事沉淀）：只渲染已解锁条目；ending 页结局短句优先取
## journal.json ending_texts（缺 key 回退硬编码）；解锁判定在 MetaProgress。
## 外层 dict 兼容新旧两代消费端：entries 内每条同时携带新端键
## id/title/text 与旧端键 title/body（body 为 text 的同值别名）。
static func _journal(meta, catalog: Dictionary) -> Dictionary:
	var by_id: Dictionary = catalog.get("journal_entry_by_id", {})
	var entries: Array[Dictionary] = []
	if meta != null:
		for jid in meta.journal_unlocked:
			var entry: Dictionary = by_id.get(str(jid), {})
			if not entry.is_empty():
				var text := str(entry.get("text", ""))
				entries.append({
					"id": str(jid),
					"title": str(entry.get("title", "")),
					"text": text,
					"body": text,
				})
	var total := (catalog.get("journal", {}).get("entries", []) as Array).size()
	return {
		"entries": entries,
		"count": entries.size(),
		"journal_locked_count": maxi(0, total - entries.size()),
	}


static func map(controller) -> Dictionary:
	var state = controller.state
	var route: Array = controller.route
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
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
		# D4 存档 Toast（R1.5）：文本来自控制器反馈，空串则不渲染。
		"toast": str(controller.last_feedback),
		"resources": _resources(state),
		"contracts": _contracts(state, catalog),
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
		"contracts": _contracts(state, catalog),
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
		"contracts": _contracts(state, catalog),
		"anomalies": [],
		"death_lines": _death_lines(state),
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


# Shared outcome→ending-type vocabulary (snapshot display and MetaProgress
# contract unlocks must agree on the same ids).
static func ending_type_for(outcome_name: String) -> String:
	match outcome_name:
		"success": return "success"
		"risky_success": return "risky"
		"survived_failure": return "retreat"
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
	return {
		"id": str(c.get("id", "")),
		"label": str(c.get("title", "")),
		"detail": str(c.get("summary", "")),
		"dangerous": _is_dangerous(c),
		"quality": "",
		"effect": str(c.get("summary", "")),
		# T6-E tooltip 一致性（§16.5 缺段隐藏）：cost 段以玩家可读短文输出，
		# 空代价输出空串让段落隐藏；绝不把原始 Dictionary str 进文案。
		"cost": _cost_note(c.get("cost", {})),
		"curse_warning": ("反噬" in str(c.get("known_risk", ""))) or ("反噬" in str(c.get("summary", ""))),
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