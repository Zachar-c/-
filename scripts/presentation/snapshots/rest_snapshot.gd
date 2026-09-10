class_name RestSnapshot
extends RefCounted


# W12 split: the Rest screen snapshot, moved verbatim from
# run_snapshot_builder.gd. Read-only projection; multi-screen shared helpers
# stay on RunSnapshotBuilder and are called via the global class name.


static func build(controller) -> Dictionary:
	var out := RunSnapshotBuilder._gui_state(controller)
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
	# 强化蛊卡：rest mode=upgrade_card（领域 _rest_upgrade）；无精炼蛊时禁用。
	var upgrade_targets: Array[Dictionary] = []
	if state != null:
		for card_key in state.refined_gu_ids:
			upgrade_targets.append({
				"id": str(card_key),
				"name": DisplayText.gu(str(card_key)),
				"blocked": false,
				"reason": "",
			})
	choices.append({
		"id": "upgrade_card",
		"label": "强化蛊卡",
		"detail": "永久提升一张已精炼蛊卡的强化等级（消耗本次休整）",
		"cost": "",
		"disabled": rest_used or rest_mode_used or upgrade_targets.is_empty(),
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else ("无已精炼蛊卡可强化" if upgrade_targets.is_empty() else "选中后经领域校验")),
		"curse_warning": false,
	})
	# 移除蛊虫实例：rest mode=remove_card。
	# 目标列与炼蛊拆解同源：活蛊且非 can_direct_drop=false 的诅咒禁删蛊。
	var remove_card_targets: Array[Dictionary] = []
	if state != null:
		for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
			var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
			if instance.is_empty() or str(instance.get("state", "")) == "dead":
				continue
			var remove_def: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
			var remove_blocked := ""
			if not bool(remove_def.get("can_direct_drop", true)):
				remove_blocked = "诅咒蛊不可直接移除"
			remove_card_targets.append({
				"id": str(instance_id_value),
				"name": DisplayText.gu(str(instance.get("definition_id", ""))),
				"blocked": remove_blocked != "",
				"reason": remove_blocked,
			})
	choices.append({
		"id": "remove_card",
		"label": "温养一蛊",
		"detail": "移除 1 只蛊虫实例，不返还资源（消耗本次休整）",
		"cost": "",
		"disabled": rest_used or rest_mode_used or remove_card_targets.is_empty(),
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else ("蛊囊无可移除之蛊" if remove_card_targets.is_empty() else "选中后经领域校验")),
		"curse_warning": false,
	})
	out["remove_card_targets"] = remove_card_targets
	# 抹除印记：rest mode=remove_imprint。规则类印记不可移除。
	var imprint_targets: Array[Dictionary] = []
	if state != null:
		for relic_id in state.relic_ids:
			var relic_def: Dictionary = catalog.get("relic_by_id", {}).get(str(relic_id), {})
			var blocked := str(relic_def.get("grade", "")) == "meta_rule"
			imprint_targets.append({
				"id": str(relic_id),
				"name": DisplayText.gu(str(relic_id)),
				"blocked": blocked,
				"reason": "规则类印记不可移除" if blocked else "",
			})
	choices.append({
		"id": "remove_imprint",
		"label": "抹除印记",
		"detail": "移除 1 枚非规则类印记（消耗本次休整）",
		"cost": "",
		"disabled": rest_used or rest_mode_used or imprint_targets.is_empty(),
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else ("身上无可抹除的印记" if imprint_targets.is_empty() else "选中后经领域校验")),
		"curse_warning": false,
	})
	out["imprint_targets"] = imprint_targets
	# 拔除反噬：rest mode=remove_curse。逐诅咒列出当前层级。
	var curse_targets: Array[Dictionary] = []
	if state != null:
		var curse_defs: Dictionary = catalog.get("curse_by_id", {})
		for curse_id_value in state.cultivator.get("statuses", {}):
			var def: Dictionary = curse_defs.get(str(curse_id_value), {})
			curse_targets.append({
				"id": str(curse_id_value),
				"name": str(def.get("name", curse_id_value)),
				"layers": int(state.cultivator.get("statuses", {}).get(str(curse_id_value), {}).get("layers", 0)),
				"blocked": false,
				"reason": "",
			})
	choices.append({
		"id": "remove_curse",
		"label": "拔除反噬",
		"detail": "整条拔除一种当前身上的反噬诅咒（消耗本次休整）",
		"cost": "",
		"disabled": rest_used or rest_mode_used or curse_targets.is_empty(),
		"reason": "本次已休整" if rest_used else ("温养已用" if rest_mode_used else ("身上无可拔除的反噬" if curse_targets.is_empty() else "选中后经领域校验")),
		"curse_warning": true,
	})
	out["curse_targets"] = curse_targets
	out["upgrade_targets"] = upgrade_targets
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
	# 放弃收益并离开：rest mode=skip。休整已消费后禁用；未消费时强制要求确认。
	choices.append({
		"id": "skip",
		"label": "放弃收益并离开",
		"detail": "本次休整无收益可用，确认后记录一次放弃并解锁离场",
		"cost": "",
		"disabled": rest_used,
		"reason": "本次已休整" if rest_used else "执行前将弹确认：放弃本次休整收益",
		"requires_confirm": not rest_used,
		"curse_warning": false,
	})
	# E3a 三选一（规格 §4）：rest 类节点统一暴露三族动作卡。
	# 休整=既有 choices 全集；修炼=meditate/cultivate；炼蛊=refine/free_pair。
	# 未开放的动作族 disabled + 原因直白（真元已满 / 无蛊可炼等）。E4a 消费渲染。
	var rank_two_cost := int(catalog.get("balance", {}).get("cultivate_rank_two_stone_cost", 5))
	var essence_cap := int(state.cave_aperture.get("essence_max", 4)) if state != null else 4
	var essence_now := int(state.essence) if state != null else 0
	var meditate_disabled := essence_now >= essence_cap
	var cultivate_disabled := false
	var cultivate_reason := ""
	if state != null:
		if int(state.cultivation) >= 2:
			cultivate_disabled = true
			cultivate_reason = "你已经是二转蛊师。"
		elif int(state.stone) < rank_two_cost:
			cultivate_disabled = true
			cultivate_reason = "元石不足：需要 %d 枚，还差 %d 枚。" % [rank_two_cost, rank_two_cost - int(state.stone)]
	var live_gu := 0
	if state != null:
		for live_key in state.cave_aperture.get("stored_gu_instance_ids", []):
			var live_inst: Dictionary = state.gu_instances.get(str(live_key), {})
			if not live_inst.is_empty() and str(live_inst.get("state", "")) != "dead":
				live_gu += 1
	var has_material := false
	if state != null:
		for material_key in state.materials:
			if int(state.materials.get(str(material_key), 0)) > 0:
				has_material = true
				break
	var can_refine: bool = live_gu > 0 or (state != null and not state.refined_gu_ids.is_empty()) or has_material
	# E4b 三选一门面：探访已消费（heal/upgrade/remove/meditate/refine 均会写
	# used 标记）后，修炼/炼蛊族的收益卡一并禁用——一次探访只取一份收益。
	var meditate_disabled_used := meditate_disabled or rest_used
	var cultivate_disabled_used := cultivate_disabled or rest_used
	out["mode_groups"] = {
		"休整": choices,
		"修炼": [
			{
				"id": "meditate",
				"label": "调息冥想",
				"detail": "静坐调息，真元回复 1 点",
				"cost": "",
				"disabled": meditate_disabled_used,
				"reason": "本次探访已消费" if (rest_used and not meditate_disabled) else ("真元已满" if meditate_disabled else ""),
				"curse_warning": false,
			},
			{
				"id": "cultivate",
				"label": "冲击二转",
				"detail": "借灵地静修突破空窍（一转 → 二转）",
				"cost": "%d 元石" % rank_two_cost,
				"disabled": cultivate_disabled_used,
				"reason": "本次探访已消费" if (rest_used and not cultivate_disabled) else cultivate_reason,
				"curse_warning": false,
			},
		],
		"炼蛊": [
			{
				"id": "refine",
				"label": "炼蛊合药",
				"detail": "按蛊方投料合炼新蛊（炼蛊会话）",
				"cost": "",
				"disabled": rest_used or not can_refine,
				"reason": "本次探访已消费" if (rest_used and can_refine) else ("" if can_refine else "无蛊可炼：蛊囊与材料皆空"),
				"curse_warning": false,
			},
			{
				"id": "free_pair",
				"label": "自由配对",
				"detail": "主辅两只同转蛊自由合炼，零门槛试炼",
				"cost": "",
				"disabled": rest_used or live_gu < 2,
				"reason": "本次探访已消费" if (rest_used and live_gu >= 2) else ("蛊囊活蛊不足两只" if live_gu < 2 else ""),
				"curse_warning": false,
			},
		],
	}
	out["title"] = "闭关 · 休整"
	out["note"] = "强制二选一，不可全拿"
	out["choices"] = choices
	out["is_ascension"] = false
	out["growth"] = []
	return out
