class_name NpcSnapshot
extends RefCounted


# W12 split: the Npc (contact negotiation) screen snapshot, moved verbatim
# from run_snapshot_builder.gd. Read-only projection; multi-screen shared
# helpers stay on RunSnapshotBuilder / SnapshotTextUtil.


const ResolverScript = preload("res://scripts/domain/resolver.gd")


## C8 NPC 交涉屏快照（contact 节点真实交涉选项 + 立场/恶名）。
## C 批修复：节点未声明 npc_id 时不兜底 npcs[0]（旧逻辑把散修节点伪装成商队货架，
## buy 发空 npc_id 必被拒——「这里没有可交易的人」误报根因）；无 NPC 则空货架+提示。
static func build(controller) -> Dictionary:
	var out := RunSnapshotBuilder._gui_state(controller)
	var catalog: Dictionary = controller.catalog if controller.catalog != null else {}
	var npcs: Array = catalog.get("npcs", [])
	var npc_id := str(controller.current_node.get("npc_id", ""))
	var has_npc := not npc_id.is_empty()
	var npc_name := SnapshotTextUtil._npc_display_name(npc_id, str(controller.current_node.get("type", "")))
	var state = controller.state
	var notoriety := 0
	if state != null:
		notoriety = ResolverScript.notoriety(state)
	var stance := SnapshotTextUtil._npc_stance(state)
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
		"node.scheme": "暗中标算", "node.claim": "争取机缘", "node.claim_recon": "以侦察蛊探秘", "node.claim_token": "以信物感应", "node.accept": "接下委托",
		"node.ally": "结临时盟", "node.attempt_ascension": "冲击升仙",
	}
	var talk_options: Array[Dictionary] = []
	for a in RunSnapshotBuilder._node_actions(controller):
		var aid := str(a.get("id", ""))
		if aid in ["leave", "node.leave"]:
			continue
		var label := str(_talk_labels.get(aid, str(a.get("title", aid))))
		talk_options.append({
			"id": aid,
			"label": label,
			"detail": str(a.get("summary", "")),
			"cost": str(a.get("cost", "")),
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
