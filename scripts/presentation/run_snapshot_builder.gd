class_name RunSnapshotBuilder
extends RefCounted


# Builds the read-only snapshots the RUI screens render. Inputs come from the
# RunController; this class never mutates run state, only projects it.


const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const DdaResolverScript = preload("res://scripts/domain/dda_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const AppSettingsScript = preload("res://scripts/domain/app_settings.gd")


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
## 数据形状对齐 DebugActions.query_loot_state 返回的 pity/excluded 结构。
## 仅由 debug_panel 渲染，绝不反向写入状态。
static func debug(controller) -> Dictionary:
	var state = controller.state
	if state == null:
		return {}
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	return {
		"pity": {
			"loot_pity": int(state.loot_pity),
			"material_pity": int(state.material_pity),
			"synthesis_fail_streak": int(state.synthesis_fail_streak),
		},
		"excluded": [] as Array,
		"seed": int(state.seed),
		"event_count": state.event_log.size(),
		"dda_percentile": DdaResolverScript.score_label(state, catalog),
	}


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
	var max_tier := ResolverScript.shop_max_tier(controller.state, catalog)
	var offers: Array[Dictionary] = []
	for offer_key in offer_by_id:
		var o: Dictionary = offer_by_id[offer_key]
		# 黑市分层上架：货阶高于当前大层的货不露面（层越深货越贵且稀有）。
		if int(o.get("tier", 1)) > max_tier:
			continue
		var gid := str(o.get("gu_id", ""))
		var name := DisplayText.gu(gid) if gid != "" else str(o.get("card_key", "货物"))
		var price := str(ResolverScript.shop_layer_price(catalog, controller.state, int(o.get("stone_cost", 0)))) + " 元石"
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
	var shop_npc_id := str(controller.current_node.get("npc_id", ""))
	out["title"] = "黑市 · 寨市" if node_type == "shop" else ("商队开市" if node_type == "caravan" else "临时寨市")
	# Shop 屏与 Npc 屏共用 NPC 名/立场推导；无 npc_id 的寨市回落通用游商名。
	if shop_npc_id.is_empty():
		out["npc_name"] = "地脉游商" if node_type != "caravan" else "商队执事"
		out["npc_stance"] = "中立"
	else:
		out["npc_name"] = _npc_display_name(shop_npc_id, node_type)
		out["npc_stance"] = _npc_stance(controller.state)
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


## C2/D3 战利品确认屏快照：真实已入账 loot（settle_victory 结果）+ 精英绑定代价
## + 真实保底计数。规格口径：战后战利品自动入账（§16.4 来源隔离由 loot_tables 承担），
## 本屏为确认展示而非再抽取——假三选一快照已删除。
static func reward(controller) -> Dictionary:
	var out := _gui_state(controller)
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var loot: Dictionary = controller.get("last_battle_loot") if controller.get("last_battle_loot") != null else {}
	var elite_cost: Dictionary = controller.get("last_battle_cost") if controller.get("last_battle_cost") != null else {}
	out["title"] = "战利品"
	var rows: Array[Dictionary] = []
	for material_value in loot.get("material_ids", []):
		rows.append({
			"name": DisplayText.material(str(material_value)),
			"kind": "素材 · 已入账",
			"quality": "普通",
			"effect": "本局材料 +1，用于炼蛊与事件支付。",
			"cost": "",
		})
	var loot_gu := str(loot.get("gu_id", ""))
	if not loot_gu.is_empty():
		var gu_entry: Dictionary = catalog.get("gu_by_id", {}).get(loot_gu, {})
		rows.append({
			"name": DisplayText.gu(loot_gu),
			"kind": "蛊 · 已入蛊囊",
			"quality": str(gu_entry.get("rarity", "普通")),
			"effect": str(gu_entry.get("summary", "获得蛊虫，可在炼蛊台合成。")),
			"cost": "",
		})
	if not elite_cost.is_empty():
		rows.append({
			"name": "精英代价（强制绑定）",
			"kind": "代价 · 已生效",
			"quality": "史诗",
			"effect": DisplayText.elite_cost(elite_cost),
			"cost": "",
			"curse_warning": true,
		})
	out["rewards"] = rows
	out["full_satchel"] = false
	out["pity_note"] = "蛊掉落保底计数：%d · 材料保底计数：%d" % [int(state.loot_pity), int(state.material_pity)]
	# T6-E 空池回退小字：真实 loot 为空即空池回退信号。
	# T6-E 空池回退小字：仅在真实结算过的战斗（loot 字典非空）且未掉落任何条目时
	# 展示；未开战（loot 为空字典）不发常驻假提示。
	out["pool_fallback_note"] = "（空池回退：本场未掉落战利品）" if (not loot.is_empty() and rows.is_empty()) else ""
	return out


## C8 NPC 交涉屏快照（contact 节点真实交涉选项 + 立场/恶名）。
## C 批修复：节点未声明 npc_id 时不兜底 npcs[0]（旧逻辑把散修节点伪装成商队货架，
## buy 发空 npc_id 必被拒——「这里没有可交易的人」误报根因）；无 NPC 则空货架+提示。
static func npc(controller) -> Dictionary:
	var out := _gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var npcs: Array = catalog.get("npcs", [])
	var npc_id := str(controller.current_node.get("npc_id", ""))
	var has_npc := not npc_id.is_empty()
	var npc_name := _npc_display_name(npc_id, str(controller.current_node.get("type", "")))
	var state = controller.state
	var notoriety := 0
	if state != null:
		notoriety = ResolverScript.notoriety(state)
	var stance := _npc_stance(state)
	# 真实交涉选项：contact 节点 neutral_wanderer 的 negotiate/deceive/fight/retreat
	# C 批修复：talk_options 直接镜像领域动作卡（含完整 command 与 state_version），
	# UI 发 choose_action 同遭遇屏通道——不再构造领域不存在的 negotiate/deceive 裸 id
	# （resolve_contact 只认 neutral_wanderer，商队发它 100% 静默被拒，走查断点）。
	# 标题中文化（§16.5）：动作卡 id 的动词段映射中文，裸 id 不漏给玩家。
	var _talk_labels := {
		"node.negotiate": "友善攀谈", "node.deceive": "诈言诓骗", "node.fight": "出手试探",
		"node.retreat": "退避三舍", "node.leave": "离开",
		"node.probe": "打探消息", "node.trade": "交易服务", "node.work": "帮工换石",
		"node.harvest": "采撷元石", "node.buy_information": "购买情报", "node.cross": "强行穿越",
		"node.meditate": "吐纳调息", "node.open": "开启险地", "node.prepare": "布局防护",
		"node.scheme": "暗中标算", "node.claim": "争取机缘", "node.accept": "接下委托",
		"node.ally": "结临时盟", "node.attempt_ascension": "冲击升仙",
	}
	var talk_options: Array[Dictionary] = []
	for a in _node_actions(controller):
		var aid := str(a.get("id", ""))
		if aid in ["leave", "node.leave"]:
			continue
		var label := str(_talk_labels.get(aid, str(a.get("title", aid))))
		talk_options.append({
			"id": aid,
			"label": label,
			"detail": str(a.get("summary", "")),
			"danger": aid.contains("fight") or aid.contains("deceive") or not str(a.get("block_reason", "")).is_empty(),
			"executable": bool(a.get("executable", true)),
			"block_reason": str(a.get("block_reason", "")),
			"command": a.get("command", {}),
			"state_version": int(a.get("state_version", -1)),
		})
	if talk_options.is_empty():
		talk_options = [
			{"id": "node.leave", "label": "离开", "detail": "结束当前遭遇", "danger": false, "executable": true, "block_reason": "", "command": {"type": "leave_node"}, "state_version": -1},
		]
	out["npc_name"] = npc_name
	out["stance"] = stance
	out["stance_note"] = "交涉失败将种子化翻转敌视" if stance == "中立" else ("高恶名使对方戒备" if stance == "敌视" else "极度仇恨：无法撤退")
	out["notoriety"] = notoriety
	out["notoriety_note"] = "恶名高亮：威慑部分路线 / 关闭部分交易"
	# N-candidate (night batch): real per-NPC stock from npcs.json "stock",
	# projected in the offer/barter shapes the UI already consumes. Prices use
	# Resolver.price_for so inflation/contracts/notoriety show honestly.
	# C 批：无 NPC 节点（如拦路散修）不给货架，UI 显提示而非空面板。
	out["has_npc"] = has_npc
	out["no_npc_note"] = "" if has_npc else "此人没有可交易的货物，试试交涉选项。"
	out["offers"] = []
	out["barter"] = []
	var stock: Array = []
	if has_npc:
		for npc_value in npcs:
			if str(npc_value.get("id", "")) == npc_id:
				stock = npc_value.get("stock", [])
				break
	for offer_id_value in stock:
		var oid := str(offer_id_value)
		var offer: Dictionary = catalog.get("shop_offer_by_id", {}).get(oid, {})
		if offer.is_empty():
			continue
		var kind := str(offer.get("kind", ""))
		if kind == "barter":
			var inputs: Array = offer.get("input_gu_ids", [])
			var take_id := ""
			for reward_value in offer.get("rewards", []):
				var reward: Dictionary = reward_value
				if reward.has("gu_id"):
					take_id = str(reward["gu_id"])
					break
			var give_id := str(inputs[0]) if not inputs.is_empty() else ""
			var give_name := DisplayText.gu(give_id) if not give_id.is_empty() else "一物"
			# §16.5 后果预览：面板标注玩家持有的可交付数量，未持有即禁点，
			# 不等 resolver 的 missing_barter_input 拒绝才知道。
			var owned := 0
			if state != null and not give_id.is_empty():
				for instance_value in state.gu_instances.values():
					var instance: Dictionary = instance_value
					if str(instance.get("definition_id", "")) == give_id and str(instance.get("state", "")) == "refined":
						owned += 1
			out["barter"].append({
				"id": oid,
				"name": DisplayText.gu(take_id) if not take_id.is_empty() else str(offer.get("card_key", oid)),
				"give": give_name,
				"take": DisplayText.gu(take_id) if not take_id.is_empty() else "一物",
				"note": "消耗 %s×1 · 需蛊位空位" % give_name,
				"owned": owned,
				"executable": owned > 0,
				"block_reason": "" if owned > 0 else "未持有可交付的%s" % give_name,
			})
		else:
			var raw_cost := int(offer.get("stone_cost", 0))
			var price := ""
			# 展示价必须等于实收价：purchase 与 _shop_purchase 同走
			# shop_layer_price（层加价），soul_boost 与 _shop_soul_boost 同走
			# price_for，lifespan_deal 直接标寿元——三条分支逐字对齐。
			if offer.has("lifespan_cost"):
				price = str(offer.get("lifespan_cost", 0)) + " 寿元"
			elif kind == "purchase":
				price = "%d 元石" % (ResolverScript.shop_layer_price(catalog, state, raw_cost) if state != null else raw_cost)
			else:
				price = "%d 元石" % (ResolverScript.price_for(catalog, state, raw_cost) if state != null else raw_cost)
			# 黑市分层上架（§16.4）：货阶高于当前大层的货保留展示但禁点，
			# 给出原因而不是让玩家点了才知道 shop_tier_locked。
			var block_reason := ""
			if state != null and int(offer.get("tier", 1)) > ResolverScript.shop_max_tier(state, catalog):
				block_reason = "货阶超出当前大层"
			var offer_desc := str(offer.get("clue", ""))
			if offer_desc.is_empty() or offer_desc.contains(".") or offer_desc.contains("_"):
				# card_key/裸 ID 不漏给玩家（§16.5）：无 clue 时给通用货名。
				offer_desc = "商队公开出售的蛊虫。"
			var offer_entry := {
				"id": oid,
				"name": DisplayText.gu(str(offer.get("gu_id", ""))),
				"kind": kind,
				"quality": "史诗" if kind == "soul_boost" else ("稀有" if kind == "purchase" else "普通"),
				"price": price,
				"desc": offer_desc,
				"executable": block_reason.is_empty(),
				"block_reason": block_reason,
				"curse_warning": kind == "lifespan_deal",
			}
			if kind == "lifespan_deal":
				# 红线：消耗寿元的交易执行前必须预检并给出明确文案。
				var lifespan_cost := int(offer.get("lifespan_cost", 0))
				var lifespan_now := int(state.cultivator.get("lifespan", 0)) if state != null else 0
				offer_entry["precheck"] = "当前寿元 %d · 支付 %d 后余 %d；寿元不足将被拒绝。" % [lifespan_now, lifespan_cost, lifespan_now - lifespan_cost]
			out["offers"].append(offer_entry)
	out["talk_options"] = talk_options
	out["can_flee"] = stance != "极度仇恨"
	return out


# NPC 展示名与立场的单一来源：Npc 屏与 Shop 屏共用，玩家在两屏看到的
# 必须是同一个人（§16.5 一致性）；无 npc_id 的节点回落各自的通用名。
static func _npc_display_name(npc_id: String, node_type: String) -> String:
	match npc_id:
		"caravan_steward":
			return "商队执事"
		"earth_vein_scout":
			return "地脉斥候"
		"wandering_healer":
			return "游方医修"
		"ridge_extortionist":
			return "山岭索贿者"
		"wandering_peddler":
			return "散修货郎"
	return "拦路散修" if node_type == "contact" else "无名散修"


static func _npc_stance(state: Variant) -> String:
	if state != null and state.node_flags != null:
		if str(state.node_flags.get("reputation_extreme_stance", "")) == "true":
			return "极度仇恨"
		if str(state.node_flags.get("reputation_hostile", "")) == "true":
			return "敌视"
	return "中立"


static func hall(controller) -> Dictionary:
	var state = controller.get("state")
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
	var out := {
		"has_save": FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
		"hall_subview": str(controller._hall_subview),
		"selected_school": str(controller._selected_school),
		"available_schools": school_list,
		"contracts": _available_contracts(meta, catalog, _contract_selection_state(controller)),
		"selected_school_name": _school_display_name(catalog, str(controller._selected_school)),
		"meta_stats": {"runs": runs, "endings": endings, "won": won, "deaths": deaths},
		# D4 预留（§16.22）：SaveRepository.load_meta_file 在版本不符时返回 null，与无档/损坏
		# 不可区分；待领域侧暴露版本冲突标记后在此注入提示文案，hall_view 已预留 warn Toast 槽位。
		"hall_version_warning": "",
		"codex": _codex(catalog, meta),
		"journal": _journal(meta, catalog),
		"dda_state_adaptive_enabled": bool(meta.dda_state_adaptive_enabled) if meta != null else true,
		# A6 设置接线：客户端偏好只投影数值与选项标签，绝不写回（只读快照）。
		"master_volume": AppSettingsScript.clamp_volume(int(controller.app_settings.master_volume)) if controller.get("app_settings") != null else 100,
		"resolution_index": int(controller.app_settings.resolution_index) if controller.get("app_settings") != null else 0,
		"resolution_options": AppSettingsScript.resolution_labels(),
	}
	out["brand_title"] = "問眞"
	out["primary_action"] = "continue_run" if out["has_save"] else "open_schools"
	out["run_summary"] = {
		"route": str(state.current_node_id) if state != null else "",
		"rank": int(state.cultivation) if state != null else 0,
		"hp": int(state.health) if state != null else 0,
	}
	return out


## 流派显示名（只读）：大厅选中态展示中文名，禁止裸 ID 漏给玩家。
static func _school_display_name(catalog: Dictionary, school_id: String) -> String:
	if school_id.is_empty():
		return "无（散修开局）"
	var entry: Dictionary = catalog.get("schools", {}).get(school_id, {})
	return str(entry.get("name", school_id))


## 勾选草稿 ∪ 已立誓（去重）：契约 selected 态的单一真值来源。
## StubController（测试）可能缺字段，逐项防御读取；注意 RunState 覆写了 get()，
## 不能对 state 调 .get("contracts")，须直接属性访问。
static func _contract_selection_state(controller) -> Array:
	var merged: Array = []
	var draft: Variant = controller.get("_selected_contracts")
	if draft != null:
		for v in draft:
			if not merged.has(str(v)):
				merged.append(str(v))
	var run_state: Variant = controller.get("state")
	if run_state != null and "contracts" in run_state:
		for v in run_state.contracts:
			if not merged.has(str(v)):
				merged.append(str(v))
	return merged


# C1-min §16.13: the hall lists every contract with its exact numbers;
# ending-locked entries are marked so the UI can gate its checkboxes.
# Structured rows (id/name/desc/locked/selected) drive hall_view checkboxes;
# `selected` mirrors the controller's pre-run checkbox state.
static func _available_contracts(meta, catalog: Dictionary, selected: Array = []) -> Array:
	## selected 语义 = 大厅勾选草稿 ∪ 本局已立誓（state.contracts），由调用方合并传入；
	## Run 结束后草稿清空，仅剩已立誓 id 供结算/复盘对照。
	var unlocked: Array[String] = []
	if meta != null and meta.has_method("unlocked_contracts"):
		unlocked = meta.unlocked_contracts(catalog)
	var by_id: Dictionary = catalog.get("contract_entry_by_id", {})
	var out: Array = []
	for entry_id in by_id:
		var entry: Dictionary = by_id[entry_id]
		out.append({
			"id": str(entry_id),
			"name": str(entry.get("label", str(entry_id))),
			"desc": str(entry.get("desc", "")),
			"locked": not unlocked.has(str(entry_id)),
			"selected": selected.has(str(entry_id)),
		})
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
		var node_id := str(n.get("id", ""))
		nodes.append({
			"id": node_id,
			"type": str(n.get("type", "")),
			"label": _node_label(n),
			"layer": int(n.get("layer", 0)),
			"next_ids": Array(n.get("next_ids", [])).duplicate(),
			"reachable": bool(n.get("reachable", false)),
			"visited": state.node_flags.has(node_id),
			"current": node_id == str(state.current_node_id),
			"visibility": _map_visibility(n, state),
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
		"anomalies": DdaResolverScript.marker_meta(state, catalog),
		"death_lines": _death_lines(state),
	}


static func _map_visibility(node: Dictionary, state) -> String:
	var node_id := str(node.get("id", ""))
	if node_id == str(state.current_node_id):
		return "current"
	if state.node_flags.has(node_id):
		return "past"
	if bool(node.get("reachable", false)):
		return "reachable"
	return "lookahead"


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
		"anomalies": DdaResolverScript.marker_meta(state, catalog),
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
	var flags: Array = battle_data.get("flags", [])
	var guarded: bool = flags.has("guarded")
	var enemies: Array[Dictionary] = []
	for enemy_value in battle_data.get("enemies", []):
		var enemy: Dictionary = enemy_value
		enemies.append({
			"id": str(enemy.get("enemy_id", "")),
			"name": str(enemy.get("name", DisplayText.enemy(str(enemy.get("kind", ""))))),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": maxi(1, int(enemy.get("max_hp", 1))),
			"shield": int(enemy.get("shield", 0)),
			"statuses": _statuses_to_list(enemy.get("statuses", {})),
			"intent": _intent_to_screen(enemy.get("visible_intent", {})),
			"alive": bool(enemy.get("alive", false)),
		})
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
	# R5.21 杀招（条件触发式）：进度=组合序列已按序打出的段数；available=序列全部
	# 就绪（本次出牌即触发）。快照只读镜像 pending_kill_move_state + 卡表定义，
	# 显示串（序列中文/下一手）在此拼好，UI 不做 id 翻译。
	var kill_moves: Array[Dictionary] = []
	var pending_km: Dictionary = battle_data.get("pending_kill_move_state", {})
	for card_value in catalog.get("card_by_id", {}).values():
		var seq: Array = card_value.get("kill_move_sequence", [])
		if seq.size() < 2:
			continue
		var km_id := str(card_value.get("id", ""))
		var done := 0
		if str(pending_km.get("move_id", "")) == km_id:
			done = clampi(int(pending_km.get("next_sequence_index", 0)), 0, seq.size())
		var seq_names: Array[String] = []
		for seq_gu in seq:
			seq_names.append(DisplayText.gu(str(seq_gu)))
		var km_name := str(card_value.get("name", ""))
		if km_name.is_empty():
			km_name = "、".join(seq_names)
		kill_moves.append({
			"id": km_id,
			"name": km_name,
			"sequence_display": " → ".join(seq_names),
			"progress": done,
			"next_name": DisplayText.gu(str(seq[done])) if done < seq.size() else "",
			"total": seq.size(),
			"cost": str(card_value.get("summary", "")),
		})
	return {
		"enemies": enemies,
		"player": player,
		"hand": hand,
		"piles": {
			"draw": (battle_data.get("draw_pile", []) as Array).size(),
			"discard": (battle_data.get("discard_pile", []) as Array).size(),
			"exhausted": (battle_data.get("exhausted_cards", []) as Array).size(),
		},
		"soul_ops": {"cap": int(battle_data.get("soul_ops_cap", 0)), "used": (battle_data.get("active_gu_instance_ids", []) as Array).size()},
		"default_target_id": _first_living_enemy_id(enemies),
		"kill_moves": kill_moves,
		# R-boss-no-retreat: the flee button disappears entirely on boss-tier
		# battles (resolver refuses the command anyway; UI mirrors it).
		"flee_available": not BattleResolver.boss_blocks_retreat(battle_data),
		"synthesis": _synthesis_options(state, catalog),
		"can_ultimate": false,
		"resources": _resources(state),
		"contracts": _contracts(state, catalog),
		"anomalies": DdaResolverScript.marker_meta(state, catalog),
		"dda_boss_hint": str(battle_data.get("dda_boss_hint", "")),
		"death_lines": _death_lines(state),
	}


static func _first_living_enemy_id(enemies: Array[Dictionary]) -> String:
	for enemy in enemies:
		if bool(enemy.get("alive", false)):
			return str(enemy.get("id", ""))
	return ""


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
