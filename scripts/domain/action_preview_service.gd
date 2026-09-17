class_name ActionPreviewService
extends RefCounted

const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
const InheritanceClaimRulesScript = preload("res://scripts/domain/inheritance_claim_rules.gd")
const V1BattleResolver = preload("res://scripts/domain/v1_battle_resolver.gd")
# 一转一突破（2026-09-15）：档位、成本、境界名单一来源（领域层）。
const RefineCommandRulesScript = preload("res://scripts/domain/refine_command_rules.gd")
const EssenceCapacityScript = preload("res://scripts/domain/essence_capacity.gd")
const RestRulesScript = preload("res://scripts/domain/rest_rules.gd")


# This service is read-only: it must never append events, mutate RunState, or use RNG.
static func preview_actions(state: RunState, node: Dictionary, catalog: Dictionary, knowledge: Dictionary = {}) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if state.is_terminal():
		return cards
	_append_scavenge_card_if_due(cards, state, node, catalog)
	_append_aptitude_card_if_available(cards, state, node, catalog)
	if str(node.get("id", "")) == "caravan_missing_goods":
		_append_caravan_dispute_cards(cards, state)
		_append_leave_card(cards, state)
	else:
		match str(node.get("type", "")):
			"caravan":
				_append_caravan_cards(cards, state, catalog)
			"refinement":
				_append_refinement_cards(cards, state, catalog, knowledge)
			"cultivation":
				_append_cultivation_cards(cards, state, catalog)
			"ledger":
				_append_ledger_cards(cards, state, catalog)
			"shop":
				_append_shop_cards(cards, state, catalog)
			"event":
				_append_event_cards(cards, state, node, catalog)
			"rest":
				_append_rest_cards(cards, state, node, catalog)
			_:
				_append_standard_cards(cards, state, node, catalog)
		if not str(node.get("type", "")) in ["caravan", "refinement", "cultivation", "ledger", "shop", "event", "rest"]:
			_append_leave_card(cards, state)
	_apply_stance_card_filter(cards, state, node)
	_inject_encounter_context(cards, state, node)
	_mark_consumed_cards(cards, state)
	_assert_unique_ids(cards)
	return cards


static func _apply_stance_card_filter(cards: Array[Dictionary], state: RunState, node: Dictionary) -> void:
	if str(state.encounter_session.get("stance", "neutral")) != "extreme_hostile":
		return
	# 与 _leave 的 feud_no_escape 门禁同语义（规格 2026-09-01-v1-battle-schema：
	# "有仗必须打，无仗可打允许离开"）：血仇过滤只作用于有战斗对象的节点
	# （choices 含 fight 或 caravan 特例，与 EncounterSessionResolver.begin 的
	# offers_fight 公式同源）。rest/refinement/cultivation/shop 等服务类节点
	# 无仗可打，服务照常提供，否则恶名玩家无法休整/炼蛊形成死亡螺旋。
	var offers_fight: bool = "fight" in (node.get("choices", []) as Array) \
		or str(node.get("type", "")) == "caravan"
	if not offers_fight:
		return
	var kept: Array[Dictionary] = []
	for card in cards:
		var command: Dictionary = card.get("command", {})
		var is_fight := _is_fight_command(command)
		var is_leave := str(command.get("type", "")) == "leave_node"
		if is_fight or is_leave:
			kept.append(card)
		else:
			card["executable"] = false
			card["block_reason"] = "对方已血仇上脸，非战不可。"
			card["remedy_hints"] = []
			kept.append(card)
	cards.clear()
	for card in kept:
		cards.append(card)


static func _is_fight_command(command: Dictionary) -> bool:
	return str(command.get("action_id", "")) == "fight" \
		or (str(command.get("type", "")) == "resolve_contact" and str(command.get("approach", "")) == "fight")


static func _mark_consumed_cards(cards: Array[Dictionary], state: RunState) -> void:
	var used: Array = state.encounter_session.get("used_action_ids", [])
	if used.is_empty():
		return
	for card in cards:
		if used.has(str(card.get("id", ""))):
			card["executable"] = false
			card["block_reason"] = "已在此处处置过，局势不会再次因此变化。"
			card["remedy_hints"] = []


static func find_card(state: RunState, node: Dictionary, action_id: String, catalog: Dictionary) -> Dictionary:
	for card in preview_actions(state, node, catalog):
		if str(card["id"]) == action_id:
			return card
	return {}


## 战斗行动预览（第三阶段 Task 3，2026-09-17）：**战斗行动的唯一投影来源**。
## 蛊虫卡（gu.<instance_id>）/ 拳脚（basic_attack）/ 杀招（kill_move.<id>）/
## 收势（battle.end_turn）/ 撤离（battle.retreat）都产出结构化命令，可执行性与
## 禁用原因一律取自 V1BattleResolver 的同一套门禁（can_play_gu /
## basic_attack_reason / kill_move_reason）。表现层只准转呈 `command`，不得自行
## 判定；run_command_builder 按 ID 构造命令仅作兼容包装。
static func preview_battle_actions(battle: Dictionary, state: RunState, catalog: Dictionary) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if battle.is_empty() or state.is_terminal():
		return cards
	# 终局（victory/defeat）或已收场（retreat 落 flags.session_closed）后不再产出
	# 可提交行动——与门面 apply_turn 的 battle_over 拦截同源，UI 由此天然置灰。
	if str(battle.get("phase", "player_action")) != "player_action" \
			or bool((battle.get("flags", {}) as Dictionary).get("session_closed", false)):
		return cards
	for slot_index in (battle.get("gu_slots", []) as Array).size():
		_append_battle_gu_card(cards, battle, state, slot_index)
	cards.append(_battle_basic_attack_card(battle, state))
	for km_value in battle.get("kill_moves", []):
		_append_battle_kill_card(cards, battle, state, km_value)
	_append_battle_retreat_card(cards, battle, state, catalog)
	cards.append(_battle_end_turn_card(battle, state))
	_assert_unique_ids(cards)
	return cards


static func _append_battle_gu_card(cards: Array[Dictionary], battle: Dictionary, state: RunState, slot_index: int) -> void:
	var slot: Dictionary = (battle.get("gu_slots", []) as Array)[slot_index]
	var instance_id := str(slot.get("instance_id", ""))
	var reason := V1BattleResolver.can_play_gu(battle, slot_index)
	cards.append(_battle_command_card(battle, state, {
		"id": "gu.%s" % instance_id,
		"type": "use_gu",
		"title": DisplayText.gu(str(slot.get("definition_id", ""))),
		"summary": "催发此蛊。",
		"executable": reason.is_empty(),
		"reason": reason,
		"cost": _battle_gu_cost(slot),
		# 指向规则与快照同口径（仅 strike 类需要选敌），Task 3 不改拖拽交互。
		"target_type": "single_enemy" if str((slot.get("effect", {}) as Dictionary).get("kind", "")) == "strike" else "none",
		"valid_target_ids": _living_enemy_ids(battle),
		"command": {
			"type": "use_gu",
			"instance_id": instance_id,
			"target_id": "",
			"state_version": state.event_log.size(),
		},
	}))


static func _battle_basic_attack_card(battle: Dictionary, state: RunState) -> Dictionary:
	var reason := V1BattleResolver.basic_attack_reason(battle)
	return _battle_command_card(battle, state, {
		"id": "basic_attack",
		"type": "basic_attack",
		"title": "拳脚",
		"summary": "零消耗的基础打击，任何战况都可用。",
		"executable": reason.is_empty(),
		"reason": reason,
		"cost": {"thought": 1},
		"known_risk": _counter_swallow_risk(battle),
		"expected_gain": ["造成 1 点基础伤害。"],
		"target_type": "single_enemy",
		"valid_target_ids": _living_enemy_ids(battle),
		"command": {"type": "basic_attack", "state_version": state.event_log.size()},
	})


static func _append_battle_kill_card(cards: Array[Dictionary], battle: Dictionary, state: RunState, km_value: Variant) -> void:
	var km: Dictionary = km_value
	var kill_move_id := str(km.get("id", ""))
	var reason := V1BattleResolver.kill_move_reason(battle, kill_move_id)
	cards.append(_battle_command_card(battle, state, {
		"id": "kill_move.%s" % kill_move_id,
		"type": "play_kill_move",
		"title": str(km.get("label", kill_move_id)),
		"summary": "预制杀招，一场一用。",
		"executable": reason.is_empty(),
		"reason": reason,
		"cost": _battle_kill_move_cost(km),
		"command": {
			"type": "play_kill_move",
			"kill_move_id": kill_move_id,
			"confirmed": false,
			"state_version": state.event_log.size(),
		},
	}))


static func _append_battle_retreat_card(cards: Array[Dictionary], battle: Dictionary, state: RunState, catalog: Dictionary) -> void:
	var retreat_cost := 0 if battle.get("flags", []).has("retreat_preserved") \
			else int(catalog.get("balance", {}).get("retreat_stone_cost", 2))
	var retreat_open := _battle_retreat_open(battle)
	# R-boss-no-retreat: the window only exists behind this fight, so boss-tier
	# enemies close it for good — shown with the reason, never silently.
	var boss_no_retreat: bool = _boss_blocks_retreat(battle)
	if boss_no_retreat:
		retreat_open = false
	var retreat_ready := retreat_open and state.stone >= retreat_cost
	cards.append(_battle_command_card(battle, state, {
		"id": "battle.retreat",
		"type": "retreat",
		"title": "撤离",
		"summary": "趁交锋间隙抽身。",
		"executable": retreat_ready,
		"reason": "" if retreat_ready else "retreat_blocked",
		"block_reason": "敌方为首领：此战退无可退。" if boss_no_retreat \
			else "当前地形、追击或敌方控制不允许撤离。" if not retreat_open \
			else "元石不足：需要 %d 枚。" % retreat_cost if state.stone < retreat_cost else "",
		"cost": {"stone": retreat_cost} if retreat_cost > 0 else {},
		"known_risk": ["撤离成功后会放弃本次战利品。"],
		"remedy_hints": [] if boss_no_retreat else (
			["可先催发雾步蛊保留撤离机会。"] if not retreat_open else _stone_remedies(retreat_cost - state.stone)),
		"command": {
			"type": "retreat",
			"state_version": state.event_log.size(),
			"expected_phase": str(battle.get("phase", "player_action")),
		},
	}))


static func _battle_end_turn_card(battle: Dictionary, state: RunState) -> Dictionary:
	return _battle_command_card(battle, state, {
		"id": "battle.end_turn",
		"type": "end_turn",
		"title": "收势",
		"summary": "结束本轮，敌方将执行已公开意图。",
		"executable": true,
		"reason": "",
		"cost": {},
		"known_risk": ["敌方将执行：%s。" % _living_intent_labels(battle)],
		"command": {
			"type": "end_turn",
			"state_version": state.event_log.size(),
			"expected_phase": str(battle.get("phase", "player_action")),
		},
	})


## 战斗行动卡成型处（Task 3 十键契约：id/type/executable/block_reason/costs/
## target_type/valid_target_ids/command/state_version/expected_phase）。
## cost/costs 同值双写：既有消费面读 cost，计划契约读 costs。
static func _battle_command_card(battle: Dictionary, state: RunState, values: Dictionary) -> Dictionary:
	var reason := str(values.get("reason", ""))
	var card := _card(state, values)
	card["type"] = str(values.get("type", ""))
	card["reason"] = reason
	if not values.has("block_reason"):
		card["block_reason"] = _battle_block_text(reason)
	card["costs"] = card["cost"].duplicate(true)
	card["expected_phase"] = str(battle.get("phase", "player_action"))
	if not card.has("target_type"):
		card["target_type"] = "none"
	if not card.has("valid_target_ids"):
		card["valid_target_ids"] = []
	return card


## 战斗禁用原因 → 玩家可见文案（唯一一份）。此前 battle_snapshot._v1_reject_text
## 与本服务各持一套，Task 3 收敛到预览侧，快照只透传。
static func _battle_block_text(reason: String) -> String:
	match reason:
		"unknown_gu": return "未知蛊虫"
		"gu_consumed": return "此蛊已在战斗中被消耗"
		"gu_sealed": return "此蛊正被封印"
		"gu_used_this_turn": return "此蛊本回合已释放"
		"action_limit_reached": return "本回合行动次数已用完"
		"insufficient_thought": return "念头不足（每次行动耗 1 念头）"
		"insufficient_true_qi": return "真元不足"
		"insufficient_qi_quality": return "真元质量不足，无法催动此转数的蛊虫"
		"kill_move_recipe_sealed": return "配方蛊被封印，杀招不可用"
		"unknown_kill_move": return "未知杀招"
	return reason


static func _battle_gu_cost(slot: Dictionary) -> Dictionary:
	var cost := {}
	if int(slot.get("true_qi_cost", 0)) > 0:
		cost["true_qi"] = int(slot.get("true_qi_cost", 0))
	cost["thought"] = int(slot.get("thought_cost", 1))
	if int(slot.get("life_cost", 0)) > 0:
		cost["life_time"] = int(slot.get("life_cost", 0))
	return cost


static func _battle_kill_move_cost(km: Dictionary) -> Dictionary:
	var cost := {}
	if int(km.get("true_qi_cost", 0)) > 0:
		cost["true_qi"] = int(km.get("true_qi_cost", 0))
	cost["thought"] = int(km.get("thought_cost", 1))
	if int(km.get("life_cost", 0)) > 0:
		cost["life_time"] = int(km.get("life_cost", 0))
	return cost


static func _living_enemy_ids(battle: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			ids.append(str(enemy.get("id", "")))
	return ids


static func _living_intent_labels(battle: Dictionary) -> String:
	var labels: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			# V1 敌人意图键是 intent；visible_intent 只作旧形状回退。
			var intent: Dictionary = enemy.get("intent", enemy.get("visible_intent", {}))
			labels.append(str(intent.get("label", "已公开意图")))
	return "、".join(labels) if not labels.is_empty() else "已公开意图"


## §16.5 counter forewarning: labels of live direct-strike reactions the
## resolver would actually swallow. Mirrors the legacy _reaction_countered
## flag semantics (bound -> enemy_bound, guarded -> guarded); a countered or
## already-bound enemy clears the warning. Only strike paths the resolver
## checks (basic punch, thorn whip strike) may present this risk.
static func _live_counter_labels(battle: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	# flags 兼容两代形状：V1 Dictionary / 旧引擎 Array（has 双向可用）。
	var flags: Variant = battle.get("flags", [])
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("alive", false)) or int(enemy.get("hp", 0)) <= 0:
			continue
		for reaction_value in enemy.get("counter_revealed", enemy.get("reactions", [])):
			var reaction: Dictionary = reaction_value
			if str(reaction.get("trigger", "")) != "direct_strike" or str(reaction.get("window", "")) != "before_damage":
				continue
			var status := str(reaction.get("counter_status", ""))
			if status == "bound" and flags.has("enemy_bound"):
				continue
			if status == "guarded" and flags.has("guarded"):
				continue
			labels.append(str(reaction.get("label", "临阵反制")))
	return labels


static func _counter_swallow_risk(battle: Dictionary) -> Array[String]:
	var risk: Array[String] = []
	var labels := _live_counter_labels(battle)
	if not labels.is_empty():
		risk.append("敌方蓄势「%s」：这次的直接攻伐会被吞下，不造成伤害；可先以束缚/守护类蛊虫破解。" % "、".join(labels))
	return risk


static func _battle_retreat_open(battle: Dictionary) -> bool:
	if _boss_blocks_retreat(battle):
		return false
	return _retreat_terrain_open(battle)


## 两代战斗形状的 Boss 判定，与 V1 运行时撤退 gate（flags.boss_battle，
## facade.start 对 tier=="boss" 敌人落账）同源：
## - V1 形状：flags.boss_battle（Dictionary）。
## - 旧信封形状（存量测试 battle，敌人可能内嵌 definition/顶层 enemy_definition）：
##   按敌人 tier=="boss" 兜底。
## 曾是 legacy class BattleResolver（boss_blocks_retreat 全局名）的调用——旧实现在 V1
## battle 上查 enemy_definition/enemies[].definition.tier，恒 false，导致预览
## 错误放行 Boss 战撤退（SS16.5 无静默放行回归，2026-09-06 桶 B 修复）。
static func _boss_blocks_retreat(battle: Dictionary) -> bool:
	if (battle.get("flags", {}) is Dictionary) \
			and bool((battle.get("flags", {}) as Dictionary).get("boss_battle", false)):
		return true
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", true)) and int(enemy.get("hp", 0)) > 0:
			if str((enemy.get("definition", {}) as Dictionary).get("tier", "")) == "boss":
				return true
	return str((battle.get("enemy_definition", {}) as Dictionary).get("tier", "")) == "boss"


## 旧版 can_retreat(terrain, pursuit, enemy_control) 的本地等价：V1 battle 携带
## terrain（encounter 透传），pursuit/enemy_control 在 V1 形状缺省为 0。
static func _retreat_terrain_open(battle: Dictionary) -> bool:
	return str(battle.get("terrain", "")) in ["path", "ridge", "marsh"] \
		and int(battle.get("pursuit", 0)) <= 1 \
		and int(battle.get("enemy_control", 0)) <= 1


static func _append_caravan_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	for offer in catalog.get("caravan_offers", []):
		match str(offer.get("kind", "")):
			"buy":
				var cost := int(offer.get("stone_cost", 0))
				var executable := state.stone >= cost
				cards.append(_card(state, {
					"id": "caravan.buy.%s" % str(offer["id"]),
					"title": "购买%s" % DisplayText.gu(str(offer["output_gu_id"])),
					"summary": "商队公开出售的蛊虫。",
					"executable": executable,
					"block_reason": "元石不足：需要 %d 枚，当前仅有 %d 枚。" % [cost, state.stone] if not executable else "",
					"cost": {"stone": cost},
					"expected_gain": ["获得%s。" % DisplayText.gu(str(offer["output_gu_id"]))],
					"remedy_hints": _stone_remedies(cost - state.stone) if not executable else [],
					"command": {"type": "buy_gu", "offer_id": str(offer["id"])},
				}))
			"exchange":
				var inputs: Array = offer.get("input_gu_ids", [])
				var missing := _missing_gu(state.refined_gu_ids, inputs)
				var stone_cost := int(offer.get("stone_cost", 0))
				var executable := missing.is_empty() and state.stone >= stone_cost
				cards.append(_card(state, {
					"id": "caravan.exchange.%s" % str(offer["id"]),
					"title": "以蛊换%s" % DisplayText.gu(str(offer["output_gu_id"])),
					"summary": "交出%s，换取%s。" % [_gu_names(inputs), DisplayText.gu(str(offer["output_gu_id"]))],
					"executable": executable,
					"block_reason": _requirements_reason(missing, state.stone, stone_cost),
					"cost": _cost(stone_cost, inputs),
					"expected_gain": ["获得%s。" % DisplayText.gu(str(offer["output_gu_id"]))],
					"remedy_hints": _gu_remedies(missing) + (_stone_remedies(stone_cost - state.stone) if state.stone < stone_cost else []),
					"command": {"type": "exchange_gu", "offer_id": str(offer["id"])},
				}))
	# R-instance-dup 2026-08-27: owning several instances of one definition
	# must not emit duplicate card ids; one sell card per definition and the
	# next visit (or replay) moves the remaining copies.
	var sell_seen := {}
	for gu_id in state.refined_gu_ids:
		if sell_seen.has(gu_id):
			continue
		sell_seen[gu_id] = true
		var gu: Dictionary = catalog.get("gu_by_id", {}).get(gu_id, {})
		if gu.is_empty():
			continue
		cards.append(_card(state, {
			"id": "caravan.sell.%s" % gu_id,
			"title": "出售%s" % DisplayText.gu(gu_id),
			"summary": "商队按估值收购已炼化的蛊虫。",
			"executable": true,
			"cost": {"gu_ids": [gu_id]},
			"expected_gain": ["获得元石 %d 枚。" % int(gu.get("value", 0))],
			"command": {"type": "sell_gu", "gu_id": gu_id},
		}))
	_append_leave_card(cards, state)
	if str(state.encounter_session.get("stance", "neutral")) == "extreme_hostile":
		cards.append(_card(state, {
			"id": "node.fight",
			"title": "斗蛊夺路",
			"summary": "与商队护卫正面交锋，强行夺取通路。",
			"executable": true,
			"cost": {},
			"known_risk": ["斗蛊失败会当场死亡，本局结束。"],
			"command": {"type": "choose_action", "action_id": "fight", "npc_id": "caravan_steward"},
		}))

static func _append_caravan_dispute_cards(cards: Array[Dictionary], state: RunState) -> void:
	var social: Dictionary = state.relations.get("caravan_steward", {})
	var evidence_visible: bool = social.get("evidence", []).has("ledger_evidence")
	cards.append(_card(state, {
		"id": "node.probe",
		"title": "试探管事",
		"summary": "围绕失货账册试探管事的知情范围与底线。",
		"executable": true,
		"cost": {"time": 1},
		"expected_gain": ["让对方注意到账册证据，开放举证交易。"],
		"unknown_note": "管事仍可能隐瞒援军、退路或其他盘算。",
		"command": {"type": "choose_action", "action_id": "probe", "npc_id": "caravan_steward"},
	}))
	cards.append(_card(state, {
		"id": "node.trade",
		"title": "递出账册证据",
		"summary": "以已确认的账册证据换取商队通往地脉的照看。",
		"executable": evidence_visible,
		"block_reason": "管事尚未确认账册证据，无法以此提出交易。" if not evidence_visible else "",
		"cost": {},
		"expected_gain": ["获得商队照看与地脉入口情报。"],
		"remedy_hints": ["先试探管事，使账册证据进入双方可见的交涉桌面。"] if not evidence_visible else [],
		"command": {"type": "choose_action", "action_id": "trade", "npc_id": "caravan_steward", "offer": "ledger_evidence"},
	}))
	cards.append(_card(state, {
		"id": "node.fight",
		"title": "斗蛊夺路",
		"summary": "与商队护卫正面交锋，强行夺取通路。",
		"executable": true,
		"cost": {},
		"known_risk": ["斗蛊失败会当场死亡，本局结束。", "对方可能仍藏有未暴露的护身或反制蛊虫。"],
		"expected_gain": ["击败对方后可强行通过当前关口。"],
		"unknown_note": "只能从护卫的站位与已露出的异状判断其后手。",
		"command": {"type": "choose_action", "action_id": "fight", "npc_id": "caravan_steward"},
	}))


static func _append_refinement_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary, knowledge: Dictionary = {}) -> void:
	for recipe in catalog.get("refinement_recipes", []):
		match str(recipe.get("kind", "combine")):
			"free_mix":
				_append_free_mix_card(cards, state, recipe, knowledge, catalog)
			_:
				# fixed / advance / promotion 共用配方卡：三者的成本与门禁形状一致，
				# 差异只在执行分支（见 refine_command_rules._apply_*）。promotion 的
				# 产出转数由输入实例 rank 决定，故卡片沿用同一渲染即可。
				_append_recipe_card(cards, state, recipe, catalog)
	_append_leave_card(cards, state)


static func _append_recipe_card(cards: Array[Dictionary], state: RunState, recipe: Dictionary, catalog: Dictionary) -> void:
	var inputs: Array = recipe.get("input_gu_ids", [])
	var missing := _missing_gu(state.refined_gu_ids, inputs)
	var destroys_inputs := str(recipe.get("failure", "")) == "destroy_inputs"
	# 蛊方图鉴门禁（2026-08-30）：与执行/快照共用 Resolver.recipe_unlocked，
	# fixed/combine 须持有蛊方，advance 豁免，default_unlocked 配方初始持有。
	var codex_ok := ResolverScript.recipe_unlocked(state, recipe)
	var is_fixed := str(recipe.get("kind", "combine")) == "fixed"
	var success_rate: Variant = null
	if not is_fixed:
		success_rate = int(recipe.get("success_roll_max", 0))
	var executable := missing.is_empty() and codex_ok
	var reason := ""
	if not codex_ok:
		reason = str(recipe.get("locked_reason", "尚未获得该蛊方，无法按此配方合炼。"))
	elif not missing.is_empty():
		reason = "缺少%s。" % _gu_names(missing)
	# 2026-09-12（透明度红线）：配方卡必须把**元石与蛊材**成本一并摊开，并让
	# `executable` 反映可负担性。旧实现只报蛊（`_cost(0, ...)`）且不看元石/材料，
	# 于是同名升阶（advance，剑道成长曲线的核心）会显示成「可执行」，
	# 玩家点了才被告知 insufficient_stone / missing_refinement_material。
	var stone_cost := int(recipe.get("stone_cost", 0))
	var materials: Dictionary = recipe.get("materials", {})
	var missing_materials: Array[String] = []
	for material_id_value in materials:
		var material_id := str(material_id_value)
		if int(state.materials.get(material_id, 0)) < int(materials[material_id]):
			missing_materials.append(material_id)
	var affordable := int(state.stone) >= stone_cost
	# 2026-09-12（Q8-G Batch 1-A Gate 3）：转数门禁必须与执行侧同形。执行侧在
	# _apply_fixed_recipe / _apply_promotion_recipe 里先判 input_min_rank 再扣料，
	# 预览若不看它，rank 不足的配方会显示成「可执行」，玩家点了才被拒——
	# 正是"看得见做不到"。这里按同一规则算，并把最缺的那只实例转数报出来。
	var min_rank := int(recipe.get("input_min_rank", 0))
	var rank_short := false
	var observed_rank := 1
	if min_rank > 0:
		observed_rank = _lowest_selected_rank(state, inputs)
		rank_short = observed_rank < min_rank
	if not codex_ok:
		reason = str(recipe.get("locked_reason", "尚未获得该蛊方，无法按此配方合炼。"))
	elif not missing.is_empty():
		reason = "缺少%s。" % _gu_names(missing)
	elif rank_short:
		executable = false
		reason = "输入蛊转数不足（需 %d 转，现有 %d 转）。" % [min_rank, observed_rank]
	if executable and not missing_materials.is_empty():
		executable = false
		reason = "缺少材料%s。" % _material_names(missing_materials)
	elif executable and not affordable:
		executable = false
		reason = "元石不足（需 %d，现有 %d）。" % [stone_cost, int(state.stone)]
	var cost := _cost(stone_cost, inputs, 1)
	if not materials.is_empty():
		cost["materials"] = materials.duplicate()
	cards.append(_card(state, {
		"id": "refine.%s" % str(recipe["id"]),
		"title": "炼制%s" % DisplayText.gu(str(recipe["output_gu_id"])),
		"summary": "以%s合炼。" % _gu_names(inputs),
		"executable": executable,
		"block_reason": reason,
		"cost": cost,
		"known_risk": ["失败会损毁输入蛊虫：%s。" % _gu_names(inputs)] if destroys_inputs else [],
		"expected_gain": ["获得%s。" % DisplayText.gu(str(recipe["output_gu_id"]))],
		"unknown_note": "" if is_fixed else "炼制成败未定。",
		"success_rate": success_rate,
		"remedy_hints": ["可在传承或奇遇中获得对应炼制知识。"] if not codex_ok else _gu_remedies(missing),
		"command": {"type": "refine_gu", "recipe_id": str(recipe["id"])},
	}))


static func _append_free_mix_card(cards: Array[Dictionary], state: RunState, recipe: Dictionary, knowledge: Dictionary, catalog: Dictionary) -> void:
	var min_inputs := int(recipe.get("min_inputs", 2))
	var usable := free_mix_input_instance_ids(state)
	var enough := usable.size() >= min_inputs
	var known_risks: Array[String] = []
	var ominous_hint := ""
	if knowledge.has(_free_mix_combination_key(state, usable)):
		for outcome_id_value in knowledge[_free_mix_combination_key(state, usable)]:
			var line := _known_outcome_line(str(outcome_id_value))
			if not line.is_empty() and not known_risks.has(line):
				known_risks.append(line)
	elif enough:
		ominous_hint = _free_mix_risk_hint(recipe, state, usable, catalog)
	cards.append(_card(state, {
		"id": "refine.%s" % str(recipe["id"]),
		"title": "乱炼一炉",
		"summary": "将两只以上已炼化蛊虫投入同一炉中乱炼，成败祸福全凭天意。",
		"executable": enough,
		"block_reason": "已炼化蛊虫不足 %d 只，无法乱炼。" % min_inputs if not enough else "",
		"cost": {"time": 1},
		"known_risk": known_risks,
		"expected_gain": [],
		"unknown_note": "" if not known_risks.is_empty() else (ominous_hint if not ominous_hint.is_empty() else "乱炼的结果未明：可能蛊虫尽毁、催生畸变，也可能炸炉伤身。"),
		"remedy_hints": ["可先通过交易、搜寻或炼制获取更多蛊虫。"] if not enough else [],
		"command": {"type": "refine_gu", "recipe_id": str(recipe["id"]), "input_instance_ids": usable},
	}))


static func free_mix_input_instance_ids(state: RunState) -> Array[String]:
	var result: Array[String] = []
	for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
		result.append(str(instance_id_value))
	return result


static func _free_mix_risk_hint(recipe: Dictionary, state: RunState, instance_ids: Array, catalog: Dictionary) -> String:
	var tags: Array[String] = []
	for instance_id_value in instance_ids:
		var instance: Dictionary = state.gu_instances.get(str(instance_id_value), {})
		var gu: Dictionary = catalog.get("gu_by_id", {}).get(str(instance.get("definition_id", "")), {})
		for tag_value in gu.get("tags", []):
			var tag := str(tag_value)
			if not tags.has(tag):
				tags.append(tag)
	for rule_value in recipe.get("risk_hints", []):
		var rule: Dictionary = rule_value
		var matched := true
		for required_tag in rule.get("tags", []):
			if not tags.has(str(required_tag)):
				matched = false
				break
		if matched:
			return str(rule.get("text", ""))
	return ""


static func _free_mix_combination_key(state: RunState, instance_ids: Array) -> String:
	var definition_ids: Array[String] = []
	for instance_id_value in instance_ids:
		var definition_id := str(state.gu_instances.get(str(instance_id_value), {}).get("definition_id", ""))
		if not definition_id.is_empty() and not definition_ids.has(definition_id):
			definition_ids.append(definition_id)
	definition_ids.sort()
	return "+".join(definition_ids)


static func _known_outcome_line(outcome_id: String) -> String:
	match outcome_id:
		"destroyed": return "已知：这类组合很可能让所有输入蛊虫尽毁。"
		"mutation_venom": return "已知：这类组合可能催生含毒畸变。"
		"explosion": return "已知：这类组合可能炸炉，损伤气血魂魄与寿元。"
	return ""


static func _append_shop_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	for offer in catalog.get("shop_offers", []):
		_append_shop_offer_card(cards, state, catalog, offer)
	_append_material_sell_cards(cards, state, catalog)
	_append_leave_card(cards, state)


static func _append_shop_offer_card(cards: Array[Dictionary], state: RunState, catalog: Dictionary, offer: Dictionary) -> void:
	match str(offer.get("kind", "")):
		"soul_boost":
			var pill_cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
			var soul := int(state.cultivator.get("soul", 0))
			var soul_max := int(state.cultivator.get("soul_max", soul))
			var can_boost := soul < soul_max
			var executable := state.stone >= pill_cost and can_boost
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "购得魂丹",
				"summary": "补益魂魄，暂缓心神损耗。",
				"executable": executable,
				"block_reason": "魂魄已满，丹力无从安放。" if not can_boost else "元石不足：需要 %d 枚，当前仅有 %d 枚。" % [pill_cost, state.stone] if not executable else "",
				"cost": {"stone": pill_cost},
				"expected_gain": ["魂魄 +%d" % int(offer.get("soul_gain", 1))],
				"remedy_hints": _stone_remedies(pill_cost - state.stone) if not executable and can_boost else [],
				"command": {"type": "shop_purchase", "offer_id": str(offer["id"])},
			}))
		"gu_fang_unlock":
			var fang_cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
			var fang_owned := state.global_codex_ids.has(str(offer.get("gu_id", "")))
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "购得%s古方" % DisplayText.gu(str(offer["gu_id"])),
				"summary": "持方即知：以对应输入合炼时，产物当场可视，免未知损失。",
				"executable": state.stone >= fang_cost and not fang_owned,
				"block_reason": "你已持有该古方。" if fang_owned else ("元石不足：需要 %d 枚。" % fang_cost if state.stone < fang_cost else ""),
				"cost": {"stone": fang_cost},
				"expected_gain": ["获得%s的古方（图鉴永久记录）。" % DisplayText.gu(str(offer["gu_id"]))],
				"command": {"type": "shop_purchase", "offer_id": str(offer["id"])},
			}))
		"purchase":
			var cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
			var executable := state.stone >= cost
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "购入%s" % DisplayText.gu(str(offer["gu_id"])),
				"summary": "黑市明码标价，钱货两讫。",
				"executable": executable,
				"block_reason": "" if executable else "元石不足：需要 %d 枚，当前仅有 %d 枚。" % [cost, state.stone],
				"cost": {"stone": cost},
				"expected_gain": ["获得%s。" % DisplayText.gu(str(offer["gu_id"]))],
				"remedy_hints": _stone_remedies(cost - state.stone) if not executable else [],
				"command": {"type": "shop_purchase", "offer_id": str(offer["id"])},
			}))
		"lifespan_deal":
			var lifespan_cost := int(offer.get("lifespan_cost", 0))
			var lifespan := int(state.cultivator.get("lifespan", 0))
			var kept := lifespan - lifespan_cost
			var executable := kept >= 1
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "以寿元换%s" % DisplayText.gu(str(offer["gu_id"])),
				"summary": "商人只收寿元，不收元石。",
				"executable": executable,
				"block_reason": "支付后寿元将耗尽（剩余 %d），交易被禁止。" % kept if not executable else "",
				"cost": {"lifespan": lifespan_cost},
				"known_risk": ["支付 %d 寿元（支付后剩余 %d）；寿元归零会当场死亡。" % [lifespan_cost, kept]],
				"expected_gain": ["获得%s。" % DisplayText.gu(str(offer["gu_id"]))],
				"remedy_hints": ["可先恢复寿元，或改用元石购买其他蛊虫。"] if not executable else [],
				"command": {"type": "shop_lifespan_deal", "offer_id": str(offer["id"])},
			}))
		"wash_notoriety":
			var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
			var wash_cost := int(effects.get("wash_lifespan_cost", 10))
			var reduce := int(effects.get("wash_reduce", 2))
			var kept := int(state.cultivator.get("lifespan", 0)) - wash_cost
			var has_notoriety := Resolver.notoriety(state) > 0
			var executable := has_notoriety and kept >= 1
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "洗去恶名",
				"summary": "献上寿元，抚平恶名；修行路的眼线会按人情办事。",
				"executable": executable,
				"block_reason": "暂无恶名可洗。" if not has_notoriety else "支付后寿元将耗尽（剩余 %d），交易被禁止。" % kept,
				"cost": {"lifespan": wash_cost},
				"known_risk": ["支付 %d 寿元（支付后剩余 %d）。" % [wash_cost, kept]],
				"expected_gain": ["恶名减少 %d。" % reduce],
				"command": {"type": "wash_notoriety"},
			}))
		"barter":
			var inputs: Array = offer.get("input_gu_ids", [])
			var missing := _missing_gu(state.refined_gu_ids, inputs)
			var executable := missing.is_empty()
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "以%s换取笼中物" % _gu_names(inputs),
				"summary": "商人封着笼子，只肯让你观察，不肯说明里面是什么。",
				"executable": executable,
				"block_reason": "缺少%s。" % _gu_names(missing) if not missing.is_empty() else "",
				"cost": _cost(0, inputs),
				"known_risk": ["可见线索：商人封笼之前，先往笼中喂了一枚暗色石子。"],
				"expected_gain": [],
				"unknown_note": "换到手的东西结果未明。",
				"remedy_hints": _gu_remedies(missing),
				"command": {"type": "shop_barter", "offer_id": str(offer["id"])},
			}))


# R8.1 hard choice: the rest node offers exactly one benefit per visit and
# the leave card stays locked until one option consumes the visit. Option
# executability mirrors the domain preconditions; commands that need a target
# carry "expects_target" so the UI knows to attach it on submission.
static func _append_rest_cards(cards: Array[Dictionary], state: RunState, node: Dictionary, catalog: Dictionary) -> void:
	# P2a B: visit flags are scoped per node id ("<id>_used").
	var used := str(state.node_flags.get("%s_used" % str(node.get("id", "")), "")) == "used"
	var summary := str(node.get("summary", ""))
	_append_rest_option(cards, state, used, {
		"id": "node.rest_heal",
		"title": "歇脚恢复",
		"summary": summary,
		"available": true,
		"unavailable_reason": "",
		"expected_gain": ["恢复气血 2 点。", "恢复真元 2 点。"],
		"command": {"type": "rest"},
	})
	_append_rest_option(cards, state, used, {
		"id": "node.rest_upgrade",
		"title": "强化一张蛊卡",
		"summary": summary,
		"available": _any_upgradable_card(state),
		"unavailable_reason": "没有可强化的蛊卡。",
		"expected_gain": ["选定一张蛊卡，永久提升一级强化。"],
		"command": {"type": "rest", "mode": "upgrade_card"},
		"expects_target": "card_key",
	})
	_append_rest_option(cards, state, used, {
		"id": "node.rest_remove_card",
		"title": "移除一只蛊",
		"summary": summary,
		"available": _any_removable_instance(state, catalog),
		"unavailable_reason": "没有可移除的蛊虫（受诅咒的蛊拒绝直接丢弃）。",
		"expected_gain": ["选定一只蛊，将其从蛊囊中移除。"],
		"command": {"type": "rest", "mode": "remove_card"},
		"expects_target": "instance_id",
	})
	_append_rest_option(cards, state, used, {
		"id": "node.rest_remove_imprint",
		"title": "抹除一枚印记",
		"summary": summary,
		"available": _any_removable_relic(state, catalog),
		"unavailable_reason": "没有可抹除的印记。",
		"expected_gain": ["选定一枚非规则类印记，将其抹除。"],
		"command": {"type": "rest", "mode": "remove_imprint"},
		"expects_target": "relic_id",
	})
	_append_rest_option(cards, state, used, {
		"id": "node.rest_remove_curse",
		"title": "拔除一层反噬",
		"summary": summary,
		"available": _any_removable_curse(state, catalog),
		"unavailable_reason": "身上没有可拔除的反噬诅咒。",
		"expected_gain": ["选定一种反噬诅咒，整条拔除。"],
		"command": {"type": "rest", "mode": "remove_curse"},
		"expects_target": "curse_id",
	})
	cards.append(_card(state, {
		"id": "node.leave",
		"title": "离开休整",
		"summary": "结束休整，返回地图选择下一条路线。",
		"executable": used,
		"block_reason": "" if used else "休整抉择未定：须先选择恢复、强化或移除其一，才能离开。",
		"cost": {},
		"expected_gain": ["结束当前遭遇。"],
		"command": {"type": "leave_node"},
	}))


static func _append_rest_option(
	cards: Array[Dictionary],
	state: RunState,
	used: bool,
	option: Dictionary
) -> void:
	var available := bool(option["available"])
	cards.append(_card(state, {
		"id": str(option["id"]),
		"title": str(option["title"]),
		"summary": str(option["summary"]),
		"executable": not used and available,
		"block_reason": "本次休整已处置完毕。" if used else str(option["unavailable_reason"]) if not available else "",
		"cost": {},
		"known_risk": [],
		"expected_gain": option.get("expected_gain", []),
		"unknown_note": "",
		"remedy_hints": [],
		"command": option.get("command", {}).duplicate(true),
		"expects_target": str(option.get("expects_target", "")),
	}))


static func _any_upgradable_card(state: RunState) -> bool:
	return not state.refined_gu_ids.is_empty()


static func _any_removable_instance(state: RunState, catalog: Dictionary) -> bool:
	for instance in state.refined_instances():
		if _cursed_drop_block_reason(catalog, str(instance.get("definition_id", ""))).is_empty():
			return true
	return false


static func _any_removable_relic(state: RunState, catalog: Dictionary) -> bool:
	for relic_id in state.relic_ids:
		var grade := str(catalog.get("relic_by_id", {}).get(str(relic_id), {}).get("grade", ""))
		if grade != "meta_rule":
			return true
	return false


static func _any_removable_curse(state: RunState, catalog: Dictionary) -> bool:
	for curse_id_value in catalog.get("curse_by_id", {}):
		if CurseRegistry.layers_of(state, str(curse_id_value)) > 0:
			return true
	return false


static func _cursed_drop_block_reason(catalog: Dictionary, definition_id: String) -> String:
	var definition: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	if definition.is_empty() or bool(definition.get("can_direct_drop", true)):
		return ""
	return "cursed_gu_not_directly_droppable"


## D4（2026-09-16）：事件卡片**只渲染本点位宿主的那一条事件**。
## 此前该函数遍历 catalog.events 全表：池子只有 2 条时看不出来，一旦扩容到 12 条
## 就会在每个事件点位铺出 12 张卡 —— 所以扩容前必须先修掉这个行为。
## 宿主事件 = `node.event_id`，缺省回退 `node.id`（与 `run_travel_flow.gd:43`
## 的对话标题回退同源）；两者都命中不到时退化为"此地无事件可应答"，仅保留离场卡。
## 文案：`title/summary/unknown_note/flavor_gain` 取自事件数据（自描述），
## 而**代价与收益条目由数值杠杆派生**（不是再抄一份文案），从而保证预检提示与
## `SocialCommandRules._accept_event` 的真实结算**同源**、不会漂移。
static func _append_event_cards(cards: Array[Dictionary], state: RunState, node: Dictionary,
		catalog: Dictionary) -> void:
	var event_id := str(node.get("event_id", node.get("id", "")))
	var event: Dictionary = catalog.get("event_by_id", {}).get(event_id, {})
	if not event.is_empty():
		cards.append(_event_accept_card(state, event, catalog))
	_append_leave_card(cards, state)


static func _event_accept_card(state: RunState, event: Dictionary, catalog: Dictionary) -> Dictionary:
	var health_cost := int(event.get("health_cost", 0))
	var delayed_soul_cost := int(event.get("delayed_soul_cost", 0))
	var stone_gain := int(event.get("stone_gain", 0))
	var curse_id := str(event.get("curse_id", ""))
	# 与领域层同一判据（`state.health > health_cost`），代价永不为致命级。
	var executable := state.health > health_cost
	var known_risk: Array[String] = []
	if health_cost > 0:
		known_risk.append("立即损失 %d 点气血。" % health_cost)
	if delayed_soul_cost > 0:
		known_risk.append("下一次赶路时失去 %d 点魂魄。" % delayed_soul_cost)
	if not curse_id.is_empty():
		known_risk.append("从此被「%s」缠身。" % _curse_label(catalog, curse_id))
	var expected_gain: Array[String] = []
	if stone_gain > 0:
		expected_gain.append("得到 %d 枚元石。" % stone_gain)
	var flavor := str(event.get("flavor_gain", ""))
	if not flavor.is_empty():
		expected_gain.append(flavor)
	return _card(state, {
		"id": "event.%s.accept" % str(event.get("id", "")),
		"title": str(event.get("title", event.get("id", "异闻"))),
		"summary": str(event.get("summary", "")),
		"executable": executable,
		"block_reason": "当前气血不足以承受已知代价。" if not executable else "",
		"cost": {"hp": health_cost},
		"known_risk": known_risk,
		"expected_gain": expected_gain,
		"unknown_note": str(event.get("unknown_note", "")),
		"remedy_hints": ["可先恢复气血，再回来应答。"] if not executable else [],
		"command": {"type": "accept_event", "event_id": str(event.get("id", ""))},
	})


static func _curse_label(catalog: Dictionary, curse_id: String) -> String:
	var curse: Dictionary = catalog.get("curse_by_id", {}).get(curse_id, {})
	var label := str(curse.get("name_zh", ""))
	return label if not label.is_empty() else curse_id


static func _append_cultivation_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	# 一转一突破（2026-09-15）：档位与成本单一来源在 RefineCommandRules
	# （`cultivate_stone_cost` 读 balance 的升转成本键表）。
	var current := maxi(1, int(state.cultivation))
	var max_rank := RefineCommandRulesScript.MAX_CULTIVATION
	var target := mini(current + 1, max_rank)
	var required_stone := RefineCommandRulesScript.cultivate_stone_cost(catalog, target)
	# 领域侧硬门禁（RestRules.rest_visit_consumed）必须同步反映到可执行性，
	# 否则会出现「卡可点、提交被拒」的空按钮（交互闭环契约禁止）。
	var visit_used := RestRulesScript.rest_visit_consumed(state)
	var executable := current < max_rank and state.stone >= required_stone and not visit_used
	var reason := ""
	if visit_used:
		reason = "此处已取过收益，换个地方再修行。"
	elif current >= max_rank:
		reason = "你已是五转蛊师，境内再无更高境界。"
	elif state.stone < required_stone:
		reason = "元石不足：需要 %d 枚，还差 %d 枚。" % [required_stone, required_stone - state.stone]
	cards.append(_card(state, {
		"id": "cultivate.rank_%d" % target,
		"title": "冲击%s" % RefineCommandRulesScript.cultivation_label(target),
		"summary": "借泉眼静修，尝试突破空窍。",
		"executable": executable,
		"block_reason": reason,
		"cost": {"stone": required_stone, "time": 1},
		"expected_gain": ["由%s晋为%s，真元上限扩张至 %d。" % [
				RefineCommandRulesScript.cultivation_label(current),
				RefineCommandRulesScript.cultivation_label(target),
				EssenceCapacityScript.essence_max_for(state, catalog, target)]],
		"remedy_hints": _stone_remedies(required_stone - state.stone) if state.stone < required_stone else [],
		"command": {"type": "breakthrough", "target_rank": target},
	}))
	_append_standard_card(cards, state, "meditate")
	_append_leave_card(cards, state)


static func _append_ledger_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	var cost := state.estimate_feeding(catalog)
	var executable := state.stone >= cost
	cards.append(_card(state, {
		"id": "ledger.pay",
		"title": "结清养蛊总账",
		"summary": "本阶段已养蛊虫的养护费用统一结算。",
		"executable": executable,
		"block_reason": "元石不足：需要 %d 枚，还差 %d 枚。" % [cost, cost - state.stone] if not executable else "",
		"cost": {"stone": cost},
		"known_risk": ["结算后元石减少，后续交易余裕下降。"],
		"expected_gain": ["已养蛊虫维持稳定，可继续催发。"],
		"remedy_hints": _stone_remedies(cost - state.stone) if not executable else [],
		"command": {"type": "settle_feeding"},
	}))
	var debt_taken := state.known_facts.has("caravan_favor_debt")
	cards.append(_card(state, {
		"id": "ledger.accept_debt",
		"title": "向商队欠下人情",
		"summary": "以未来的势力代价结清当前养蛊总账。",
		"executable": not debt_taken,
		"block_reason": "你已经欠下商队人情，不能再以此结算。" if debt_taken else "",
		"cost": {},
		"known_risk": ["商队会记下这笔人情，后续可能要求回报。"],
		"expected_gain": ["以商队人情结清本阶段养蛊总账。"],
		"remedy_hints": ["可出售已炼化蛊虫，改以元石结清。"] if debt_taken else [],
		"command": {"type": "accept_debt"},
	}))
	_append_leave_card(cards, state)


static func _append_standard_cards(cards: Array[Dictionary], state: RunState, node: Dictionary, catalog: Dictionary = {}) -> void:
	for action_id in node.get("choices", []):
		if str(action_id) != "leave":
			_append_standard_card(cards, state, str(action_id), node, catalog)


static func _append_standard_card(cards: Array[Dictionary], state: RunState, action_id: String, node: Dictionary = {}, catalog: Dictionary = {}) -> void:
	var executable := true
	var reason := ""
	var cost := {}
	var risk: Array[String] = []
	var gain: Array[String] = []
	var unknown_note := ""
	var remedies: Array[String] = []
	match action_id:
		"accept":
			gain.append("接受委托，获得后续势力往来的资格。")
		"ally":
			gain.append("获得临时盟友支持，后续争夺中可借势。")
		"attempt_ascension":
			gain.append("以当前已备条件冲击升仙，结果将成为本局终局。")
			risk.append("一旦踏入升仙考验便不可逆转，成败都会留下终局后果。")
			unknown_note = "天地二气与外扰的最终碰撞只能在考验中见分晓。"
			if str(state.node_flags.get("boss_defeated", "")) != "true":
				executable = false
				reason = "终局强敌未除，升仙窗口尚不安全。"
				remedies = ["先击破瘴脉蛊主，再谈升仙。"]
		"claim":
			gain.append("争取当前机缘，获得后续升仙准备。")
			risk.append("会暴露争夺意图，可能引来他人干预。")
		"cross":
			cost = {"spirit": 1}
			gain.append("消耗真元强行穿越，保住前行时机。")
			if state.essence < 1:
				executable = false
				reason = "真元不足：需要 1 点。"
				remedies = ["可先选择静修或其他恢复真元的路线。"]
		"buy_information", "trade":
			cost = {"stone": 2}
			gain.append("获得%s。" % ("一条可用情报" if action_id == "buy_information" else "一次明确服务"))
			if state.stone < 2:
				executable = false
				reason = "元石不足：需要 2 枚，还差 %d 枚。" % (2 - state.stone)
				remedies = _stone_remedies(2 - state.stone)
		"retreat":
			risk.append("撤离会增加追击压力。")
			gain.append("脱离当前冲突，避免继续消耗。")
		"deceive":
			gain.append("以话术争取眼前的行动余地。")
			risk.append("对方会提高警惕，追击压力增加。")
			unknown_note = "对方是否完全相信，取决于其尚未暴露的判断。"
		"harvest":
			gain.append("获得元石 2 枚。")
		"fight":
			gain.append("正面击破当前威胁，战利品归胜者。")
			var enemy: Dictionary = catalog.get("enemy_by_id", {}).get(str(node.get("enemy_kind", "")), {})
			if not enemy.is_empty():
				var intent: Dictionary = enemy.get("intent", {})
				var intent_damage := int(intent.get("damage", 0))
				if intent_damage > 0:
					risk.append("敌手招式「%s」伤害 %d 点。" % [str(intent.get("label", "未知")), intent_damage])
				if intent_damage >= 3:
					risk.append("伤害可观：气血或手段不足时优先考虑撤离。")
					remedies.append("可先购入攻防蛊虫、恢复气血，或选择撤离绕开。")
				var reactions: Array = enemy.get("reactions", [])
				if not reactions.is_empty():
					var labels: Array[String] = []
					for reaction_value in reactions:
						var reaction: Dictionary = reaction_value
						labels.append(str(reaction.get("label", "临阵反制")))
					risk.append("敌手有临阵反制（%s）：零消耗拳脚会被其吞下。" % "、".join(labels))
					remedies.append("需要绑定/守护类蛊虫配合破解，否则普攻不造成伤害。")
		"inspect":
			gain.append("获得一条地点线索。")
		"lure":
			gain.append("诱使威胁改变位置，为后续行动创造机会。")
		"meditate":
			gain.append("恢复 1 点真元。")
		"open":
			gain.append("获得可用于升仙的地点。")
		"prepare":
			gain.append("获得一层护道准备。")
		"scheme":
			gain.append("削减终局中的外部干扰。")
		"scout":
			gain.append("查明前路的已知征兆。")
		"take_imprint":
			gain.append("承受铁骨体印，获得明确的护身根基。")
			risk.append("铁骨体印会让潜行与伪装更难。")
			if state.body_imprints.has("iron_bone"):
				executable = false
				reason = "你已经承受铁骨体印，无法重复取得。"
				remedies = ["可选择静修，或离开此处寻找其他根基机缘。"]
		"withdraw":
			gain.append("安全收手，保留当前资源与情报。")
			risk.append("放弃此处机缘，之后无法再从当前路线取得。")
		"claim_recon", "claim_token":
			var site: Dictionary = catalog.get("inheritance_site_by_id", {}).get(str(node.get("id", "")), {})
			if site.is_empty():
				site = catalog.get("inheritance_site_by_id", {}).get(str(node.get("template_id", "")), {})
			var claimed := str(state.node_flags.get("%s_claimed" % str(node.get("id", "")), "")) == "true"
			if site.is_empty():
				executable = false
				reason = "此处没有可继承的遗葬传承。"
			elif claimed:
				executable = false
				reason = "该遗葬的传承已被继承，另寻他处吧。"
			else:
				risk.append("继承结果按遗葬等级随机判定：残破（1--2 只蛊）/普通（3--4 只蛊+1--2 份蛊方）/稀有（5--8 只蛊+3--4 份蛊方）。")
				if action_id == "claim_recon":
					var needed := int(site.get("level", 1))
					gain.append("侦察蛊探得传承秘地，直接继承该遗葬的传承。")
					if not InheritanceClaimRulesScript.has_scout_gu(state, catalog, needed):
						executable = false
						reason = "需要一只 %d 转及以上的侦察蛊，当前没有。" % needed
						remedies = ["可从商店或野外获取侦察系（recon/scout）蛊虫后再来。"]
				else:
					gain.append("传承信物对传承者产生感应，凭信物继承该遗葬。")
					if int(state.materials.get("inheritance_token", 0)) < 1:
						executable = false
						reason = "缺少传承信物：商店有售（60 元石）。"
						remedies = ["可先到商店购入传承信物，再回此地面感应。"]
		"work":
			gain.append("完成短工，获得元石 3 枚。")
	cards.append(_card(state, {
		"id": "node.%s" % action_id,
		"title": DisplayText.action(action_id),
		"summary": str(node.get("summary", "")),
		"executable": executable,
		"block_reason": reason,
		"cost": cost,
		"known_risk": risk,
		"expected_gain": gain,
		"unknown_note": unknown_note,
		"remedy_hints": remedies,
		"command": _command_for_standard(node, action_id),
	}))


static func _append_aptitude_card_if_available(cards: Array[Dictionary], state: RunState, node: Dictionary, catalog: Dictionary) -> void:
	var paths: Array = catalog.get("aptitude", {}).get("paths", [])
	if paths.is_empty() or str(state.node_flags.get("aptitude_raised", "")) == "true":
		return
	var node_kind := str(node.get("type", ""))
	var path: Dictionary = paths[0]
	if not (path.get("node_kinds", []) as Array).has(node_kind):
		return
	var lifespan_cost := int(path.get("cost_lifespan", 0))
	var stone_cost := int(path.get("cost_stone", 0))
	var aptitude := str(state.aptitude)
	var keeps_living := int(state.cultivator.get("lifespan", 0)) - lifespan_cost >= 1
	var executable := aptitude != "jia" and keeps_living and state.stone >= stone_cost
	cards.append(_card(state, {
		"id": "raise_aptitude",
		"title": "洗髓换骨",
		"summary": "以十年寿元为引，重塑根骨，资质提升一档。",
		"executable": executable,
		"block_reason": "资质已至巅峰。" if aptitude == "jia" else "寿元或元石不足，无法承受洗髓代价。" if not executable else "",
		"cost": {"stone": stone_cost, "lifespan": lifespan_cost},
		"expected_gain": ["资质提升一档（真元上限随之变化）"],
		"command": {"type": "raise_aptitude", "node_id": str(state.current_node_id)},
	}))


static func _append_scavenge_card_if_due(cards: Array[Dictionary], state: RunState, node: Dictionary, catalog: Dictionary) -> void:
	if str(node.get("id", "")) != "final_boss_stand":
		return
	if str(state.node_flags.get("boss_defeated", "")) != "true":
		return
	# 搜刮蛊方（2026-08-30）：候选选择与执行共用 Resolver.scavenge_pending_recipes
	# （兼容 scavenge_recipe 单串/数组；已持有即不再提示）。
	var pending := ResolverScript.scavenge_pending_recipes(state, catalog)
	if pending.is_empty():
		return
	cards.append(_card(state, {
		"id": "scavenge",
		"title": "搜刮尸骸",
		"summary": "翻检尊主遗骸，或可寻得蛊方。",
		"executable": true,
		"known_risk": [],
		"expected_gain": ["获得蛊方（录入全局图鉴）。"],
		"command": {"type": "scavenge", "node_id": str(state.current_node_id)},
	}))


static func _append_material_sell_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	var materials: Dictionary = state.materials
	for material_id in materials:
		var owned := int(materials[material_id])
		if owned <= 0:
			continue
		var value := int(catalog.get("material_by_id", {}).get(material_id, {}).get("value", 0))
		if value <= 0:
			continue
		var price := ResolverScript.sell_price_for(catalog, state, value)
		cards.append(_card(state, {
			"id": "sell.%s" % material_id,
			"title": "变卖%s" % DisplayText.material(str(material_id)),
			"summary": "钱货两讫，%d 份尽数出手。" % owned,
			"executable": true,
			"known_risk": [],
			"expected_gain": ["元石 %d" % (price * owned)],
			"command": {"type": "sell_material", "material_id": str(material_id)},
		}))


static func _append_leave_card(cards: Array[Dictionary], state: RunState) -> void:
	cards.append(_card(state, {
		"id": "node.leave",
		"title": "离开遭遇",
		"summary": "主动结束当前遭遇，返回地图选择下一条路线。",
		"executable": true,
		"cost": {},
		"expected_gain": ["结束当前遭遇。"],
		"command": {"type": "leave_node"},
	}))


static func _command_for_standard(node: Dictionary, action_id: String) -> Dictionary:
	if str(node.get("type", "")) == "contact":
		# 实例节点用 template_id 定位模板（resolver._resolve_contact 按模板 id 查
		# catalog.nodes 判断 type；传实例 id 会 unknown_contact）。
		return {"type": "resolve_contact", "node_id": str(node.get("template_id", node.get("id", ""))), "approach": action_id}
	if str(node.get("type", "")) == "ascension" and action_id == "attempt_ascension":
		return {"type": "attempt_ascension", "choice": "now"}
	return {"type": "choose_action", "action_id": action_id}


static func _card(state: RunState, values: Dictionary) -> Dictionary:
	return {
		"id": str(values["id"]),
		"title": str(values.get("title", "行动")),
		"summary": str(values.get("summary", "")),
		"executable": bool(values.get("executable", true)),
		"block_reason": str(values.get("block_reason", "")),
		"cost": values.get("cost", {}).duplicate(true),
		"known_risk": values.get("known_risk", []).duplicate(),
		"expected_gain": values.get("expected_gain", []).duplicate(),
		"unknown_note": str(values.get("unknown_note", "")),
		"remedy_hints": values.get("remedy_hints", []).duplicate(),
		"success_rate": values.get("success_rate", null),
		"expects_target": str(values.get("expects_target", "")),
		"target_type": str(values.get("target_type", "none")),
		"valid_target_ids": values.get("valid_target_ids", []).duplicate(),
		"command": values.get("command", {}).duplicate(true),
		"state_version": state.event_log.size(),
	}


static func _cost(stone: int, gu_ids: Array, time: int = 0) -> Dictionary:
	var result := {}
	if stone > 0:
		result["stone"] = stone
	if not gu_ids.is_empty():
		result["gu_ids"] = gu_ids.duplicate()
	if time > 0:
		result["time"] = time
	return result


static func _missing_gu(owned: Array[String], required: Array) -> Array[String]:
	var remaining := owned.duplicate()
	var missing: Array[String] = []
	for item in required:
		var gu_id := str(item)
		var index := remaining.find(gu_id)
		if index < 0:
			missing.append(gu_id)
		else:
			remaining.remove_at(index)
	return missing


## 预览侧转数门禁：取"将被投入炉中的那些实例"的最低转数。执行侧按 definition
## 逐个取首个 refined 实例（多集语义），这里用同一套配对规则（配对即移除），
## 缺货时返回 1 —— 缺货本身已由 _missing_gu 拦下，不叠加报错。
static func _lowest_selected_rank(state: RunState, required: Array) -> int:
	var remaining: Array[String] = []
	for instance_id_value in state.cave_aperture.get("stored_gu_instance_ids", []):
		var instance_id := str(instance_id_value)
		if str(state.gu_instances.get(instance_id, {}).get("state", "")) == "refined":
			remaining.append(instance_id)
	var lowest := -1
	for item in required:
		var gu_id := str(item)
		var matched := ""
		for instance_id in remaining:
			if str(state.gu_instances.get(instance_id, {}).get("definition_id", "")) == gu_id:
				matched = instance_id
				break
		if matched.is_empty():
			return 1
		remaining.erase(matched)
		var rank := int(state.gu_instances.get(matched, {}).get("rank", 1))
		if lowest < 0 or rank < lowest:
			lowest = rank
	return lowest if lowest > 0 else 1


static func _requirements_reason(missing: Array[String], stone: int, required_stone: int) -> String:
	var reasons: Array[String] = []
	if not missing.is_empty():
		reasons.append("缺少%s" % _gu_names(missing))
	if stone < required_stone:
		reasons.append("元石不足：还差 %d 枚" % (required_stone - stone))
	return "；".join(reasons) + "。" if not reasons.is_empty() else ""


static func _gu_remedies(missing: Array[String]) -> Array[String]:
	if missing.is_empty():
		return []
	return ["可在商队购置、其他遭遇中搜寻，或选择不消耗这些蛊虫的路线。"]


static func _stone_remedies(shortfall: int) -> Array[String]:
	if shortfall <= 0:
		return []
	return ["可出售已炼化蛊虫。", "可前往资源节点补足 %d 枚元石。" % shortfall, "也可选择不消耗元石的行动。"]


static func _gu_names(gu_ids: Array) -> String:
	var names: Array[String] = []
	for gu_id in gu_ids:
		names.append(DisplayText.gu(str(gu_id)))
	return "、".join(names)


static func _material_names(material_ids: Array) -> String:
	var names: Array[String] = []
	for material_id in material_ids:
		names.append(DisplayText.material(str(material_id)))
	return "、".join(names)


static func _assert_unique_ids(cards: Array[Dictionary]) -> void:
	var seen := {}
	for card in cards:
		var id := str(card["id"])
		assert(not seen.has(id), "Duplicate action card id: %s" % id)
		seen[id] = true


static func _inject_encounter_context(cards: Array[Dictionary], state: RunState, node: Dictionary) -> void:
	var node_id := str(node.get("id", state.current_node_id))
	var session_node_id := str(state.encounter_session.get("node_id", node_id))
	for card in cards:
		var command: Variant = card.get("command", {})
		if not command is Dictionary or (command as Dictionary).is_empty():
			continue
		var envelope: Dictionary = (command as Dictionary).duplicate(true)
		envelope["state_version"] = state.event_log.size()
		envelope["node_id"] = node_id
		envelope["session_node_id"] = session_node_id
		card["command"] = envelope
