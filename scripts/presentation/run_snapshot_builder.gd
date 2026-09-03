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
const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const ActionPointsScript = preload("res://scripts/domain/action_points.gd")
const CultivatorRulesScript = preload("res://scripts/domain/cultivator_rules.gd")
const CoreGuRulesScript = preload("res://scripts/domain/core_gu_rules.gd")
const RecipeRulesScript = preload("res://scripts/domain/recipe_rules.gd")
const FeedingRulesScript = preload("res://scripts/domain/feeding_rules.gd")
const MarketRulesScript = preload("res://scripts/domain/market_rules.gd")
const Battle2BodyRulesScript = preload("res://scripts/domain/battle2/body_rules.gd")
const Battle2ActionResolverScript = preload("res://scripts/domain/battle2/action_resolver.gd")
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
		_: return {}
	return _with_v2(base, controller)


# Every real screen snapshot carries the eight §17.2 transparency groups as a
# conservative additive merge (per-screen keys already take precedence).
static func _with_v2(snapshot: Dictionary, controller) -> Dictionary:
	var merged := snapshot.duplicate(true)
	merged.merge(transparency_v2(controller), true)
	return merged


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
	# 2026-08-28 验收批：服务面板改由领域真值导出（旧表 4 条假服务与领域
	# 计价/限额全对不上，且 block/use_service 命令在 resolver 无 handler）。
	out["services"] = _shop_services(controller)
	out["emergency_note"] = "元石不足可用气血 / 寿元 / 反噬 / 销毁组件应急支付（R6.7）"
	# T6-E 空池回退显示槽位：商店侧暂无可推导的回退信号（货架非奖励池），恒空占位；
	# 领域侧落地 fallback 标记后在此注入（报告已披露该数据源缺口）。
	out["pool_fallback_note"] = ""
	return out


## 2026-08-28 验收批：黑市服务面板领域导出。价格/剩余次数全部来自
## service_price_for/service_limit/service_use_count（与 resolver 扣费同源），
## 移除类服务携带 candidates 目标清单供屏内选择；无领域支持的服务（池屏蔽、
## 净化躁动）不再出现——宁可少一项，不出死按钮。
static func _shop_services(controller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var state = controller.state
	if state == null:
		return out
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var deck: Dictionary = catalog.get("deck", {})
	var removal_specs := [
		{"id": "remove_card", "name": "移除蛊虫", "base": int(deck.get("remove_card_cost", 120)), "note": "从蛊囊删除一只蛊", "target_label": "选择要移除的蛊虫"},
		{"id": "remove_imprint", "name": "移除印记", "base": int(deck.get("remove_imprint_cost", 150)), "note": "移除一枚遗物印记（规则型印记不可移除）", "target_label": "选择要移除的印记"},
	]
	for spec_value in removal_specs:
		var spec: Dictionary = spec_value
		var sid := str(spec["id"])
		var limit := ResolverScript.service_limit(catalog, sid)
		var remaining := maxi(0, limit - ResolverScript.service_use_count(state, sid))
		var candidates: Array[Dictionary] = []
		if sid == "remove_card":
			for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
				var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
				if instance.is_empty() or str(instance.get("state", "")) == "dead":
					continue
				var candidate_gu: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
				if not bool(candidate_gu.get("can_direct_drop", true)):
					continue
				candidates.append({"id": str(instance_id_value), "name": DisplayText.gu(str(instance.get("definition_id", ""))), "price": ""})
		else:
			for relic_id_value in state.relic_ids:
				var relic: Dictionary = catalog.get("relic_by_id", {}).get(str(relic_id_value), {})
				if str(relic.get("grade", "")) == "meta_rule":
					continue
				candidates.append({"id": str(relic_id_value), "name": str(relic.get("name_zh", str(relic_id_value))), "price": ""})
		var block_reason := ""
		if remaining <= 0:
			block_reason = "本局次数已用完"
		elif candidates.is_empty():
			block_reason = "没有可移除的目标"
		out.append({
			"id": sid,
			"name": str(spec["name"]),
			"price": "%d 元石" % ResolverScript.service_price_for(catalog, state, sid, int(spec["base"])),
			"remaining": remaining,
			"note": "%s · 本局剩 %d/%d 次 · 每次使用涨价" % [str(spec["note"]), remaining, limit],
			"candidates": candidates,
			"target_label": str(spec["target_label"]),
			"executable": block_reason.is_empty(),
			"block_reason": block_reason,
		})
	# 诅咒净化：按各诅咒 removal_base_cost 分别计价。
	var curse_candidates: Array[Dictionary] = []
	var statuses: Dictionary = state.cultivator.get("statuses", {})
	for curse_id_value in statuses:
		var curse_id := str(curse_id_value)
		var layers := int((statuses[curse_id] as Dictionary).get("layers", 0))
		if layers <= 0:
			continue
		var curse: Dictionary = catalog.get("curse_by_id", {}).get(curse_id, {})
		curse_candidates.append({
			"id": curse_id,
			"name": "%s ×%d" % [DisplayText.curse(curse_id), layers],
			"price": "%d 元石" % ResolverScript.service_price_for(catalog, state, "remove_curse", int(curse.get("removal_base_cost", 1))),
		})
	var curse_limit := ResolverScript.service_limit(catalog, "remove_curse")
	var curse_remaining := maxi(0, curse_limit - ResolverScript.service_use_count(state, "remove_curse"))
	var curse_block := ""
	if curse_remaining <= 0:
		curse_block = "本局次数已用完"
	elif curse_candidates.is_empty():
		curse_block = "没有可净化的诅咒"
	out.append({
		"id": "remove_curse",
		"name": "净化诅咒",
		"price": "按诅咒定价",
		"remaining": curse_remaining,
		"note": "清除一层诅咒 · 本局剩 %d/%d 次 · 每次使用涨价" % [curse_remaining, curse_limit],
		"candidates": curse_candidates,
		"target_label": "选择要净化的诅咒",
		"executable": curse_block.is_empty(),
		"block_reason": curse_block,
	})
	# 洗刷恶名：真实命令 wash_notoriety（寿元计价，无次数上限）。
	var reputation: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var wash_cost := int(reputation.get("wash_lifespan_cost", 10))
	var wash_reduce := int(reputation.get("wash_reduce", 2))
	var lifespan := int(state.cultivator.get("lifespan", 0))
	var wash_block := ""
	if ResolverScript.notoriety(state) <= 0:
		wash_block = "当前没有恶名可洗"
	elif lifespan - wash_cost < 1:
		wash_block = "寿元不足（预检拒绝）"
	out.append({
		"id": "wash_notoriety",
		"name": "洗刷恶名",
		"price": "%d 寿元" % wash_cost,
		"remaining": -1,
		"note": "恶名 -%d · 消耗寿元 · 无次数上限" % wash_reduce,
		"candidates": [],
		"target_label": "",
		"executable": wash_block.is_empty(),
		"block_reason": wash_block,
	})
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
	# 温养一蛊：免费移除一只蛊（领域 rest remove_card 需选实例）。
	# 目标列与炼蛊拆解同源：活蛊且非 can_direct_drop=false 的诅咒禁删蛊。
	var remove_targets: Array[Dictionary] = []
	if state != null:
		for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if instance.is_empty() or str(instance.get("state", "")) == "dead":
				continue
			var remove_def: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			var remove_blocked := ""
			if not bool(remove_def.get("can_direct_drop", true)):
				remove_blocked = "诅咒蛊不可直接移除"
			remove_targets.append({
				"id": str(instance_id_value),
				"name": DisplayText.gu(str(instance.get("definition_id", ""))),
				"blocked": remove_blocked != "",
				"reason": remove_blocked,
			})
	choices.append({
		"id": "remove",
		"label": "温养一蛊",
		"detail": "移除一只蛊（免费 · 消耗本次休整）",
		"cost": "",
		"disabled": rest_used or rest_mode_used or remove_targets.is_empty(),
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else ("蛊囊无可移除之蛊" if remove_targets.is_empty() else "选中后经领域校验")),
		"curse_warning": false,
	})
	# UI 目标选择只展示领域可接受的活蛊实例；被诅咒直接丢弃限制的实例带原因并禁用。
	out["remove_targets"] = remove_targets
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
## 2026-08-28 验收批：配方行带 channel 标签供屏内过滤（通道切换是展示层状态，
## 不再发幽灵命令 refine_channel）；slot_ok 用 DeckCapacity 真实空位校验
## （旧值恒 false，确认按钮永久禁用）；拆解槽列真实蛊囊（destroy_gu）；
## 盲盒通道即 free_mix 真实配方（空选择时领域自动投入全部已炼成蛊）。
static func refine(controller) -> Dictionary:
	var out := _gui_state(controller)
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var recipe_by_id: Dictionary = catalog.get("refinement_by_id", {})
	var rec_rows: Array[Dictionary] = []
	for recipe_key in recipe_by_id:
		var r: Dictionary = recipe_by_id[recipe_key]
		var kind := str(r.get("kind", "combine"))
		var inputs: Array = r.get("input_gu_ids", [])
		var in_names: Array[String] = []
		for iid in inputs:
			in_names.append(DisplayText.gu(str(iid)))
		var output := DisplayText.gu(str(r.get("output_gu_id", "")))
		var fail := "成功配方"
		if r.has("success_roll_max"):
			fail = "失败率 %d%%" % (100 - int(r.get("success_roll_max", 100)))
		# 产出转数标注：advance 跟输入蛊走（+1 封顶五转），其余优先配方
		# output_rank，缺省回退产出蛊本体定义。
		var rank_note := ""
		if kind == "advance":
			rank_note = "产出转数 = 输入转数 + 1（封顶五转）"
		else:
			var output_gu: Dictionary = catalog.get("gu_by_id", {}).get(str(r.get("output_gu_id", "")), {})
			var out_rank := int(r.get("output_rank", int(output_gu.get("rank", 1))))
			rank_note = "产出 %s" % _rank_label(clampi(out_rank, 1, 5))
		# 解锁旗标与执行/预览共用 Resolver.recipe_unlocked：fixed/combine 须持有
		# 蛊方（default_unlocked 豁免，advance/free_mix 不设门禁）。
		var recipe_unlocked: bool = state != null \
				and ResolverScript.recipe_unlocked(state, r)
		if state == null:
			recipe_unlocked = str(r.get("kind", "combine")) == "advance" \
					or bool(r.get("default_unlocked", false))
		rec_rows.append({
			"id": str(recipe_key),
			"channel": "combine" if kind == "combine" else "fixed",
			"name": " + ".join(in_names) + " → " + output,
			"output": output,
			"rank_note": rank_note,
			"quality": "稀有",
			"fail_chance": fail,
			"backlash": "失败毁材 · 躁动 +1" if kind == "combine" else "无躁动",
			"curse": "",
			"unlocked": recipe_unlocked,
		})
	var free_mix: Dictionary = recipe_by_id.get("free_mix", {})
	if not free_mix.is_empty():
		var blind_fail := "成功配方"
		if free_mix.has("success_roll_max"):
			blind_fail = "失败率 %d%%" % (100 - int(free_mix.get("success_roll_max", 100)))
		rec_rows.append({
			"id": "free_mix",
			"channel": "blind",
			"name": "盲盒 · 自由组合（随机产物）",
			"output": "未知蛊",
			"quality": "随机",
			"fail_chance": blind_fail,
			"backlash": "炸炉按结果表结算（气血/魂魄/寿元）",
			"curse": "诅咒继承⚠",
			"unlocked": true,
		})
	out["title"] = "炼蛊台"
	out["channels"] = [
		{"id": "fixed", "label": "定向配方"},
		{"id": "combine", "label": "组合标签"},
		{"id": "blind", "label": "盲盒随机"},
	]
	out["slot_ok"] = true
	out["blind_note"] = "盲盒自动投入全部已炼成蛊虫（至少 %d 只），产物与炸炉代价按种子结算。" % int(free_mix.get("min_inputs", 2))
	out["recipes"] = rec_rows
	var dismantle_slots: Array[Dictionary] = []
	if state != null:
		for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if instance.is_empty() or str(instance.get("state", "")) == "dead":
				continue
			var dismantle_gu: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			if not bool(dismantle_gu.get("can_direct_drop", true)):
				continue
			dismantle_slots.append({"id": str(instance_id_value), "name": DisplayText.gu(str(instance.get("definition_id", "")))})
	out["dismantle_slots"] = dismantle_slots
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
		"route": _run_route_label(controller),
		"rank": "%d 转" % int(state.cultivation) if state != null else "0 转",
		"hp": "%d" % int(state.health) if state != null else "0",
	}


	return out


static func _run_route_label(controller) -> String:
	var state = controller.state
	if state == null:
		return "未载入"
	var node_id := str(state.current_node_id)
	if node_id.is_empty():
		return "流派选择"
	var node: Dictionary = controller._node_by_id(node_id) if controller.has_method("_node_by_id") else {}
	var template_id := str(state.current_node_template_id)
	if template_id.is_empty() and not node.is_empty():
		template_id = str(node.get("template_id", ""))
	if template_id.is_empty():
		template_id = node_id
	var catalog_node: Dictionary = controller.catalog.get("node_by_id", {}).get(template_id, {}) if controller.catalog != null else {}
	if not catalog_node.is_empty():
		var display_name := DisplayText.node(template_id)
		if display_name == "未知地点":
			display_name = DisplayText.type(str(catalog_node.get("type", "")))
		return display_name
	if not node.is_empty():
		return str(node.get("label", DisplayText.node(template_id)))
	return DisplayText.node(template_id)


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
	var recipe_rows: Array = catalog.get("refinement_recipes", [])
	if recipe_rows.is_empty():
		recipe_rows = catalog.get("refinement", {}).get("recipes", [])
	for r_value in recipe_rows:
		var r: Dictionary = r_value
		var rid := str(r.get("id", ""))
		recipe_entries.append({
			"id": rid,
			"kind": str(r.get("kind", "")),
			"output_gu": DisplayText.gu(str(r.get("output_gu_id", ""))),
			# 默认配方（default_unlocked）初始即持有，随 Hall 首屏可见。
			"unlocked": unlocked_recipes.has(rid) or bool(r.get("default_unlocked", false)),
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


static func content_error(controller) -> Dictionary:
	var errors: Array = controller.get("_content_errors") if controller != null else []
	return {
		"title": "内容配置无法加载",
		"error_count": errors.size(),
		"errors": errors.duplicate(),
	}


static func map(controller) -> Dictionary:
	var state = controller.state
	var route: Array = controller.route
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var nodes: Array[Dictionary] = []
	# 2026-08-28 验收批 P0-4：地带/深度/境界改由真实状态导出（旧屏面是
	# 「青茅山外圍 / 深度 62 · 四轉初階」硬编码谎言）。zone_title 取
	# pacing.layers[当前层].title，缺失为空串由屏面隐藏。
	var current_id := str(state.current_node_id)
	var current_layer := 0
	var visible_by_id := {}
	for n in MapGeneratorScript.visible_nodes(route, state, 2):
		visible_by_id[str(n.get("id", ""))] = n
	# 当前节点可能尚未完成、不在 visited 中，确保它始终进入快照。
	if not visible_by_id.has(current_id):
		for route_node in route:
			if str(route_node.get("id", "")) == current_id:
				visible_by_id[current_id] = route_node.duplicate(true)
				visible_by_id[current_id]["reachable"] = false
				break
	for node_id in visible_by_id:
		var n: Dictionary = visible_by_id[node_id]
		if node_id == current_id:
			current_layer = int(n.get("layer", 0))
		nodes.append({
			"id": node_id,
			"type": str(n.get("type", "")),
			"label": _node_label(n),
			"layer": int(n.get("layer", 0)),
			"row": int(n.get("row", 0)),
			"next_ids": Array(n.get("next_ids", [])).duplicate(),
			"reachable": bool(n.get("reachable", false)),
			"visited": state.node_flags.has(node_id),
			"current": node_id == current_id,
			"visibility": _map_visibility(n, state),
		})
	nodes.sort_custom(func(a, b): return int(a.get("layer", 0)) * 1000 + int(a.get("row", 0)) < int(b.get("layer", 0)) * 1000 + int(b.get("row", 0)))
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
	var zone_title := ""
	var depth_label := ""
	if current_layer > 0:
		zone_title = str(catalog.get("pacing", {}).get("layers", {}).get(str(current_layer), {}).get("title", ""))
		depth_label = "第 %d 大层" % current_layer
	var realm_label := ""
	var cultivation := int(state.cultivation) if state != null else 0
	if cultivation >= 1 and cultivation <= 5:
		realm_label = "%s转" % ["一", "二", "三", "四", "五"][cultivation - 1]
	return {
		"nodes": nodes,
		"current_node_id": str(state.current_node_id),
		"reachable_ids": reach,
		"gu_satchel": gu_satchel,
		"inventory": _inventory(state, catalog),
		"zone_title": zone_title,
		"depth_label": depth_label,
			"realm_label": realm_label,
			# D4 存档 Toast（R1.5）：文本来自控制器反馈，空串则不渲染。
			"toast": str(controller.last_feedback),
			"resources": _resources(state),
			"contracts": _contracts(state, catalog),
			"anomalies": DdaResolverScript.marker_meta(state, catalog),
			"death_lines": _death_lines(state),
			"leave_confirm": bool(controller.get("_map_leave_confirm")) if controller != null else false,

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
	var actions: Array[Dictionary] = _node_actions(controller)
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
		"inventory": _inventory(state, catalog),
	}


## C4 侧边自身状态面板（§16.5 事件侧边快捷查看气血/魂魄/元石/蛊虫）。
static func _player_panel(state) -> Dictionary:
	var cult: Dictionary = state.cultivator
	var gu_names: Array[String] = []
	for inst_key in state.gu_instances:
		var inst: Dictionary = state.gu_instances[inst_key]
		gu_names.append(DisplayText.gu(str(inst.get("definition_id", ""))))
	return {
		# RunState.health 是唯一真值（battle 回合结算后由 run_controller 同步
		# 写回 state.health + cultivator 镜像；旧路径 shop/rest 也写它）。
		"hp": int(state.health),
		"max_hp": maxi(1, int(state.max_health)),
		"primordial": int(state.essence),
		"soul": int(cult.get("soul", 0)),
		"stone": int(state.stone),
		"gu_names": gu_names,
	}


## 战斗屏快照：唯一 V1 战斗 Schema 投影（BattleCommandFacade → V1BattleResolver）。
## 领域状态只有 "battle/player/gu_slots/enemies/kill_moves/flags(Dictionary)" 一套，
## 本函数只做字段搬运与文字拼装，绝不重算领域结果；旧卡牌字段
## （draw_pile/actions_max/visible_intent/Array flags）一律不再读取。
static func battle(controller) -> Dictionary:
	var state = controller.state
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var battle_data: Dictionary = controller.current_battle
	var out := _gui_state(controller)
	out["enemies"] = _v1_enemies(battle_data)
	out["player"] = _v1_player(battle_data)
	out["hand"] = _v1_hand(battle_data, catalog)
	out["piles"] = {}
	out["actions"] = _v1_actions(battle_data)
	out["default_target_id"] = _first_living_enemy_id(out["enemies"])
	out["kill_moves"] = _v1_kill_moves(battle_data, catalog)
	# R-boss-no-retreat：门禁以 V1 flags(Dictionary) 判定（facade 与 resolver 同源），
	# UI 只镜像展示结果，不自行判断敌人定义。
	out["flee_available"] = not BattleCommandFacadeScript.boss_blocks_retreat(battle_data)
	out["synthesis"] = _synthesis_options(state, catalog)
	out["can_ultimate"] = false
	out["dda_boss_hint"] = str(battle_data.get("dda_boss_hint", ""))
	out["first_battle"] = not state.event_log.any(func(event): return str(event.get("action", "")) == "battle_finished")
	# 手牌版本 = 领域 event_log 大小（与 use_gu 命令 state_version 同源），供 UI 判断
	# 快照是否推进：相同版本重挂载不清重复提交缓存，避免同命令被重放。
	out["hand_version"] = int(state.event_log.size())
	return out


static func _v1_enemies(battle_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy_value in battle_data.get("enemies", []):
		var enemy: Dictionary = enemy_value
		var raw_label := str(enemy.get("label", ""))
		var enemy_id := str(enemy.get("id", ""))
		# label 为原始 kind/缺省时用 DisplayText 翻译；自定义 label 直通。
		var name := raw_label
		if raw_label.is_empty() or raw_label == enemy_id:
			name = DisplayText.enemy(enemy_id)
		out.append({
			"id": enemy_id,
			"name": name,
			"hp": int(enemy.get("hp", 0)),
			"max_hp": maxi(1, int(enemy.get("max_hp", 1))),
			"shield": int(enemy.get("shield", 0)),
			"statuses": _statuses_to_list(enemy.get("statuses", {})),
			"intent": _v1_intent_to_screen(enemy.get("intent", {})),
			"alive": bool(enemy.get("alive", true)),
			"counter_revealed": (enemy.get("counter_revealed", []) as Array).duplicate(),
		})
	return out


## V1 敌人意图（kind 直映，不套旧引擎的 damage/defense 推断）。
static func _v1_intent_to_screen(i: Dictionary) -> Dictionary:
	var kind := str(i.get("kind", "attack"))
	var base := {
		"type": kind,
		"value": 0,
		"detail": str(i.get("label", "蓄力")),
		"speed": int(i.get("speed", 0)),
	}
	match kind:
		"attack":
			base["value"] = int(i.get("damage", 0))
		"seal":
			base["value"] = int(i.get("seal_turns", 0))
		"soul_drain":
			base["value"] = int(i.get("soul_drain", 0))
		"life_cost":
			base["value"] = int(i.get("life_cost", 0))
		"counter":
			base["value"] = 0
			base["tag"] = str(i.get("counter_tag", ""))
	return base


static func _v1_player(battle_data: Dictionary) -> Dictionary:
	var p: Dictionary = battle_data.get("player", {})
	return {
		"hp": int(p.get("hp", 0)),
		"max_hp": maxi(1, int(p.get("max_hp", 1))),
		"shield": int(p.get("shield", 0)),
		"primordial": int(p.get("true_qi", 0)),
		"primordial_max": maxi(1, int(p.get("true_qi_max", 1))),
		"soul": int(p.get("soul", 0)),
		"life_time": int(p.get("life_time", 0)),
		"thoughts": int(p.get("thoughts", 0)),
		"used_this_turn": int(p.get("used_this_turn", 0)),
		"statuses": _v1_buffs_to_statuses(p.get("buffs", {})),
		"buffs": (p.get("buffs", {}) as Dictionary).duplicate(true),
	}


## 行动点（V1 念头预算）投影：max=魂魄底蕴分档，left=预算-已用。
static func _v1_actions(battle_data: Dictionary) -> Dictionary:
	var p: Dictionary = battle_data.get("player", {})
	var budget := ActionPointsScript.per_turn(int(p.get("soul", 1)))
	var used := clampi(int(p.get("used_this_turn", 0)), 0, budget)
	return {"max": budget, "left": budget - used, "used": used}


static func _v1_buffs_to_statuses(buffs: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in buffs:
		var stacks := int(buffs[key])
		if stacks > 0:
			out.append({"name": _buff_label(str(key)), "stacks": stacks})
	return out


static func _buff_label(key: String) -> String:
	match key:
		"force": return "力道"
		"yi_zhang": return "仪仗"
	return key


## V1 手牌：每个蛊槽一张卡（id "gu.<instance_id>"）+ 拳脚（肉体搏斗）。
## 可执行性直接复用 V1 领域门禁 can_play_gu/basic_attack_reason，禁止 UI 自算。
static func _v1_hand(battle_data: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	for i in (battle_data.get("gu_slots", []) as Array).size():
		var slot: Dictionary = battle_data["gu_slots"][i]
		var def_id := str(slot.get("definition_id", ""))
		var definition: Dictionary = gu_by_id.get(def_id, {})
		var reason := V1BattleResolverScript.can_play_gu(battle_data, i)
		var note := _v1_slot_note(slot)
		var effect := _v1_effect_text(slot)
		var summary := effect if note == "" else "%s（%s）" % [effect, note]
		if bool(slot.get("is_permanent", false)):
			summary = "%s · 常驻 %s" % [summary, str(slot.get("durability_mode", ""))]
		var card := {
			"id": "gu.%s" % str(slot.get("instance_id", "")),
			"name": DisplayText.gu(def_id),
			"summary": summary,
			"effect": summary,
			"quality": _gu_quality(definition),
			"cost": _v1_cost_text(slot, "thought_cost", "true_qi_cost", "life_cost"),
			"cost_ex": "",
			"executable": reason.is_empty(),
			"block_reason": _v1_reject_text(reason),
			"known_risk": _v1_life_cost_risk(slot),
			"target_type": "single_enemy" if str(slot.get("effect", {}).get("kind", "")) == "strike" else "none",
			"valid_target_ids": _living_enemy_ids_v1(battle_data),
			"curse_warning": false,
			"state_version": int(battle_data.get("turn", 1)),
			"expected_phase": str(battle_data.get("phase", "player_action")),
		}
		out.append(card)
	var punch_reason := V1BattleResolverScript.basic_attack_reason(battle_data)
	var fight_damage := int(battle_data.get("cfg", {}).get("fight_damage_base", 1))
	out.append({
		"id": "basic_attack",
		"name": "拳脚",
		"summary": "肉体搏斗：基础 %d 伤 + 力道 + 仪仗，耗 1 念头。" % fight_damage,
		"effect": "基础 %d 伤 + 力道 + 仪仗" % fight_damage,
		"quality": "普通",
		"cost": "念头 1",
		"cost_ex": "",
		"executable": punch_reason.is_empty(),
		"block_reason": _v1_reject_text(punch_reason),
		"known_risk": [],
		"target_type": "single_enemy",
		"valid_target_ids": _living_enemy_ids_v1(battle_data),
		"curse_warning": false,
		"state_version": int(battle_data.get("turn", 1)),
		"expected_phase": str(battle_data.get("phase", "player_action")),
	})
	return out


static func _v1_slot_note(slot: Dictionary) -> String:
	if bool(slot.get("is_sealed", false)):
		return "封印 %d 回合" % int(slot.get("seal_turns", 0))
	if bool(slot.get("consumed", false)):
		return "已消耗"
	if bool(slot.get("used_this_turn", false)):
		return "本回合已用"
	return ""


static func _v1_effect_text(source: Dictionary) -> String:
	var effect: Dictionary = source.get("effect", {})
	var kind := str(effect.get("kind", ""))
	match kind:
		"strike":
			return "造成 %d 伤害" % int(effect.get("amount", 0))
		"shield":
			return "获得 %d 护盾" % int(effect.get("amount", 0))
		"buff":
			return "%s +%d" % [_buff_label(str(effect.get("name", "force"))), int(effect.get("amount", 0))]
		"heal":
			return "恢复 %d 气血" % int(effect.get("amount", 0))
		"heal_and_strike":
			return "恢复 %d 气血并造成 %d 伤害" % [int(effect.get("heal", 0)), int(effect.get("amount", 0))]
		"status":
			return "%s %d 层" % [_status_label(str(effect.get("name", ""))), int(effect.get("amount", 0))]
		"shift":
			return "位移 %d 格" % int(effect.get("amount", 1))
	return "效果未明"


static func _status_label(status_name: String) -> String:
	match status_name:
		"marked": return "标记"
		"bound": return "束缚"
		"poison": return "中毒"
	return status_name if not status_name.is_empty() else "状态"


static func _v1_cost_text(slot: Dictionary, thought_key: String, qi_key: String, life_key: String) -> String:
	var parts: Array[String] = []
	if int(slot.get(qi_key, 0)) > 0:
		parts.append("真元 %d" % int(slot.get(qi_key, 0)))
	parts.append("念头 %d" % int(slot.get(thought_key, 1)))
	if int(slot.get(life_key, 0)) > 0:
		parts.append("寿元 %d" % int(slot.get(life_key, 0)))
	return " · ".join(parts)


static func _v1_life_cost_risk(slot: Dictionary) -> Array[String]:
	if int(slot.get("life_cost", 0)) <= 0:
		return []
	return ["释放此蛊消耗寿元 %d，寿元归零将当场陨落。" % int(slot.get("life_cost", 0))]


static func _gu_quality(definition: Dictionary) -> String:
	match str(definition.get("rarity", "")):
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary", "legacy": return "传说"
	return ""


static func _v1_reject_text(reason: String) -> String:
	match reason:
		"unknown_gu": return "未知蛊虫"
		"gu_consumed": return "此蛊已在战斗中被消耗"
		"gu_sealed": return "此蛊正被封印"
		"gu_used_this_turn": return "此蛊本回合已释放"
		"action_limit_reached": return "本回合行动次数已用完"
		"insufficient_thought": return "念头不足（每次行动耗 1 念头）"
		"insufficient_true_qi": return "真元不足"
		"kill_move_recipe_sealed": return "配方蛊被封印，杀招不可用"
		"unknown_kill_move": return "未知杀招"
	return reason


## V1 杀招：配方实例 → 蛊名（只读拼装），可释放性复用 kill_move_reason 门禁。
static func _v1_kill_moves(battle_data: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for km_value in battle_data.get("kill_moves", []):
		var km: Dictionary = km_value
		var recipe_names: Array[String] = []
		for instance_id_value in km.get("recipe", []):
			var slot := _find_v1_slot(battle_data, str(instance_id_value))
			if not slot.is_empty():
				recipe_names.append(DisplayText.gu(str(slot.get("definition_id", ""))))
			else:
				recipe_names.append(str(instance_id_value))
		var reason := V1BattleResolverScript.kill_move_reason(battle_data, str(km.get("id", "")))
		var costs: Array[String] = []
		if int(km.get("true_qi_cost", 0)) > 0:
			costs.append("真元 %d" % int(km.get("true_qi_cost", 0)))
		costs.append("念头 %d" % int(km.get("thought_cost", 1)))
		if int(km.get("life_cost", 0)) > 0:
			costs.append("寿元 %d" % int(km.get("life_cost", 0)))
		out.append({
			"id": str(km.get("id", "")),
			"name": str(km.get("label", str(km.get("id", "")))),
			"sequence_display": " · ".join(recipe_names) if not recipe_names.is_empty() else "配方缺失",
			"progress": 0,
			"next_name": "",
			"total": 0,
			"cost": " · ".join(costs),
			"effect": _v1_effect_text(km),
			"executable": reason.is_empty(),
			"block_reason": _v1_reject_text(reason),
		})
	return out


static func _find_v1_slot(battle_data: Dictionary, instance_id: String) -> Dictionary:
	for slot in battle_data.get("gu_slots", []):
		if str(slot.get("instance_id", "")) == instance_id:
			return slot
	return {}


static func _living_enemy_ids_v1(battle_data: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for enemy_value in battle_data.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			ids.append(str(enemy.get("id", "")))
	return ids


static func _first_living_enemy_id(enemies: Array[Dictionary]) -> String:
	for enemy in enemies:
		if bool(enemy.get("alive", false)):
			return str(enemy.get("id", ""))
	return ""


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
	var preflight := Battle2BodyRulesScript.strike_preflight(strength, capacity, float(state.health), cat)
	return {
		"safe_strength": float(Battle2BodyRulesScript.safe_strength(capacity)),
		"actual_strength": strength,
		"outward_damage": float(Battle2BodyRulesScript.unarmed_strike_damage(strength, 1.0, cat)),
		"overload_self_damage": float(Battle2BodyRulesScript.overload_self_damage(strength, capacity, cat)),
		"lethal_confirm_required": bool(preflight.get("lethal_confirm_required", false)),
		"death_cause": str(preflight.get("cause", "")),
	}


# Group 7: enemy intent window / distance bands / speed conflict / reaction
# readiness (projections over the deterministic action rules).
static func _v2_group7(cat: Dictionary) -> Dictionary:
	return {
		"distances": ["far", "medium", "close", "touch"],
		"conflict_order": str(Battle2ActionResolverScript.conflict_order("quick", 3, "quick", 3)),
		"reaction_check": Battle2ActionResolverScript.reaction_allowed(true, "grapple"),
		"disengage_open": bool(Battle2ActionResolverScript.disengage_window("touch", "close").get("open", false)),
		"strike_only_at_contact": bool(Battle2ActionResolverScript.strike_possible("touch", "touch")),
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
