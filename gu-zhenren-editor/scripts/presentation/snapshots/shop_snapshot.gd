class_name ShopSnapshot
extends RefCounted


# W12 split: the Shop (black market / caravan) screen snapshot, moved verbatim
# from run_snapshot_builder.gd. Read-only projection; multi-screen shared
# helpers stay on RunSnapshotBuilder / SnapshotTextUtil.


const ResolverScript = preload("res://scripts/domain/resolver.gd")


## C3 黑市 / 商店屏快照（数据表 shops.json 真实货架 + 黑市服务）。
static func build(controller) -> Dictionary:
	var out := RunSnapshotBuilder._gui_state(controller)
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
		# E7（2026-09-10）：货要抽架 —— 只列本次货架上的货；服务（兑换/洗恶名/蛊方/真元）
		# 常驻不受影响。判定与购买门禁共用 Resolver.shop_offer_is_stocked。
		if not ResolverScript.shop_offer_is_stocked(controller.state, catalog, str(offer_key)):
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
		out["npc_name"] = SnapshotTextUtil._npc_display_name(shop_npc_id, node_type)
		out["npc_stance"] = SnapshotTextUtil._npc_stance(controller.state)
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
	var balance: Dictionary = catalog.get("balance", {})
	var removal_specs := [
		{"id": "remove_card", "name": "移除蛊虫", "base": int(balance.get("remove_card_cost", 120)), "note": "从蛊囊删除一只蛊", "target_label": "选择要移除的蛊虫"},
		{"id": "remove_imprint", "name": "移除印记", "base": int(balance.get("remove_imprint_cost", 150)), "note": "移除一枚遗物印记（规则型印记不可移除）", "target_label": "选择要移除的印记"},
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
