extends RefCounted

## A7：resolver 拒绝 reason → 玩家可见中文（§16.5 数值明确、不模糊）。
## 未收录的 reason 走通用兜底并保留原始键（可追溯，不静默）。


const TEXT := {
	"insufficient_stone": "元石不足。",
	"insufficient_lifespan": "寿元不足。",
	"insufficient_soul": "魂魄不足。",
	"insufficient_material": "材料不足。",
	"unknown_shop_offer": "该商品不在货架上。",
	"npc_stock_missing": "该货物已被买空。",
	"npc_not_present": "对方不在此地。",
	"unknown_npc": "这里没有可交易的人。",
	"npc_missing": "这里没有可交易的人。",
	"contract_locked": "该契约尚未解锁。",
	"contract_sworn": "该契约已立誓。",
	"contract_soft_cap": "契约数量已达上限。",
	"gu_slot_full": "蛊槽已满，请先取舍。",
	"refine_input_missing": "炼蛊材料不足：先投入至少两味材料。",
	"refine_slot_invalid": "炼蛊空位校验未通过。",
	"refine_recipe_locked": "该配方尚未解锁。",
	"retreat_forbidden": "此战不可撤退。",
	"invalid_action": "当前阶段不能执行该操作。",
	"invalid_action_card": "这张牌当前不能打出。",
	"stale_state_version": "局面已变化，操作已过期，请重试。",
	"not_enough_essence": "真元不足。",
	"no_actions_left": "行动值已用完，结束回合恢复。",
	"dodge_exhausted": "本回合已闪避过。",
	"not_enough_hp": "生命不足，不能支付该代价。",
	"lifespan_trade_warning": "这笔交易将耗尽寿元，被拒绝。",
	"already_completed": "该节点已完成。",
	"invalid_node_completion": "节点状态已变化。",
	"unknown_contact": "此人无可交涉的选项。",
	"invalid_contact_approach": "该交涉方式不可用。",
	"unknown_command": "未知指令。",
	"unknown_dialogue_branch": "无法理解这段对话的选择，局面没有改变。",
	"dialogue_branch_used": "这项对话选择已经处理过了。",
	"dialogue_adapter_unavailable": "对话暂时无法回应，局面没有改变。",
	"unknown_gu": "没有这只蛊。",
	"unknown_card": "没有这张卡。",
	"unknown_node": "无法前往该地点。",
	"node_not_reachable": "该地点与当前位置不连通。",
	"unknown_material": "没有这种材料。",
	"material_not_usable": "这种材料不能直接使用。",
	"no_material_to_use": "身上没有这种材料。",
	"material_use_lethal": "直接使用会耗尽气血，被拒绝。",
	"too_early_first_layer": "尚在第一大层前段，稍后才能确认核心。",
	"core_already_confirmed": "本局已有一只核心蛊。",
	"instance_missing": "没有这只蛊实例。",
	"replace_limit_reached": "本局核心更换次数已达上限。",
	"guarantee_replaced_with_peer_reward": "已更换过核心，此处改发同级收益。",
	"no_token_on_node": "此处没有核心更换凭证。",
	"buyer_already_paid": "这位买家已为这条消息付过费。",
	"insufficient_thought": "念头不足。",
	"gu_already_used_this_turn": "这只蛊本回合已催动过。",
	"maintenance_blocks_activation": "维持中的蛊本回合不可再催动。",
	"action_already_used_this_turn": "这个基础动作本回合已用过。",
	"unknown_action": "未知的基础动作。",
	"unknown_proposal_kind": "未知的编排提案。",
	"parallel_group_repeats_action": "并行组重复了动作种类。",
	"parallel_group_repeats_instance": "并行组重复了蛊实例。",
	"no_thought": "没有可用的念头。",
	"window_closed": "反应窗口已关闭。",
	"dodge_not_allowed": "这次攻击不容许闪避。",
	"grappled_blocks_dodge": "被擒抱时无法闪避。",
	"bound_blocks_dodge": "被束缚时无法闪避。",
	"terrain_restricted": "地形限制无法闪避。",
	"not_at_contact": "不在接触距离，无法发起擒抱。",
	"not_stronger": "力量不足，擒抱未能成立。",
	"no_reserved_thought": "没有预留念头发起反应。",
	"not_a_legal_reaction": "这不是合法的脱离反应。",
	"insufficient_health": "气血不足，不能支付该代价。",
	"bleed_rank_exceeds_cultivator": "不能凝炼高于自身转数的血气。",
	"soulless_target": "这个目标没有魂魄。",
	"no_means_declared": "没有声明收魂手段。",
	"means_capacity_full": "收魂手段容量已满。",
	"soul_yield_zero": "此次收魂没有收益。",
	"free_pair_failed": "合炼失败：主蛊受伤（休整可愈），元石已耗。",
	"pair_invalid": "这对蛊虫无法入炉（预检未通过）。",
	"gu_fang_already_unlocked": "你已持有该古方。",
	"gu_fang_unknown": "没有这张古方对应的蛊。",
	"refinement_capacity_exceeded": "炼蛊需要至少保留两处空位，当前不足。",
	"rest_choice_required": "休整尚未选定：请先执行一项（调息/强化/移除/跳过）。",
	"rest_already_used": "本次休整已经消耗过了。",
	"rest_mode_already_used": "这类休整已经用过一次。",
	"not_rest_node": "这里不是可休整之处。",
}


static func text(reason: String) -> String:
	if reason.is_empty() or reason == "unknown":
		return "该操作暂时无法执行。"
	return TEXT.get(reason, "无法执行：%s" % reason)


static func summarize_changes(changes) -> String:
	if changes == null or not (changes is Array):
		return ""
	var parts: Array[String] = []
	for c in changes:
		var msg := str(c.get("message", "")) if c is Dictionary else ""
		if not msg.is_empty():
			parts.append(msg)
	return "、".join(parts)
