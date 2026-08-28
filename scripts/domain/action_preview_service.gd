class_name ActionPreviewService
extends RefCounted

const SoulCapacityScript = preload("res://scripts/domain/soul_capacity.gd")
const DeckCapacityScript = preload("res://scripts/domain/deck_capacity.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")
# BattleResolver is a global class_name; referenced directly (no preload) to
# avoid a cyclic preload with battle_resolver.gd which previews battles too.


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
				_append_cultivation_cards(cards, state)
			"ledger":
				_append_ledger_cards(cards, state, catalog)
			"shop":
				_append_shop_cards(cards, state, catalog)
			"event":
				_append_event_cards(cards, state, catalog)
			"rest":
				_append_rest_cards(cards, state, node, catalog)
			_:
				_append_standard_cards(cards, state, node, catalog)
		if not str(node.get("type", "")) in ["caravan", "refinement", "cultivation", "ledger", "shop", "event", "rest"]:
			_append_leave_card(cards, state)
	_apply_stance_card_filter(cards, state)
	_mark_consumed_cards(cards, state)
	_assert_unique_ids(cards)
	return cards


static func _apply_stance_card_filter(cards: Array[Dictionary], state: RunState) -> void:
	if str(state.encounter_session.get("stance", "neutral")) != "extreme_hostile":
		return
	var kept: Array[Dictionary] = []
	for card in cards:
		var command: Dictionary = card.get("command", {})
		if str(command.get("action_id", "")) == "fight" or str(command.get("type", "")) == "leave_node":
			kept.append(card)
		else:
			card["executable"] = false
			card["block_reason"] = "对方已血仇上脸，非战不可。"
			card["remedy_hints"] = []
			kept.append(card)
	cards.clear()
	for card in kept:
		cards.append(card)


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


static func preview_battle_actions(battle: Dictionary, state: RunState, catalog: Dictionary) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if state.is_terminal():
		return cards
	var card_by_id: Dictionary = catalog.get("card_by_id", {})
	for instance_value in battle.get("hand", []):
		var instance: Dictionary = instance_value
		var definition: Dictionary = card_by_id.get(str(instance.get("definition_id", "")), {})
		if definition.is_empty():
			continue
		_append_battle_hand_card(cards, battle, state, catalog, definition, instance)
	cards.append(_battle_card(battle, state, {
		"id": "battle.basic.punch",
		"title": "拳脚",
		"summary": "零消耗的基础打击，任何战况都可用。",
		"executable": true,
		"cost": {},
		"known_risk": _counter_swallow_risk(battle),
		"expected_gain": ["造成 1 点基础伤害。"],
		"target_type": "single_enemy",
		"valid_target_ids": _living_enemy_ids(battle),
	}))
	cards.append(_battle_card(battle, state, {
		"id": "battle.basic.dodge",
		"title": "闪避",
		"summary": "零消耗的防守姿态，速度压制慢速攻势。",
		"executable": true,
		"cost": {},
		"known_risk": ["闪避速度高于敌方攻击速度时，完全免伤本轮攻势。"],
	}))
	var retreat_cost := 0 if battle.get("flags", []).has("retreat_preserved") else 2
	var retreat_open := _battle_retreat_open(battle)
	# R-boss-no-retreat: the window only exists behind this fight, so boss-tier
	# enemies close it for good — shown with the reason, never silently.
	var boss_no_retreat: bool = BattleResolver.boss_blocks_retreat(battle)
	if boss_no_retreat:
		retreat_open = false
	var retreat_ready := retreat_open and state.stone >= retreat_cost
	cards.append(_battle_card(battle, state, {
		"id": "battle.retreat",
		"title": "撤离",
		"summary": "趁交锋间隙抽身。",
		"executable": retreat_ready,
		"block_reason": "敌方为首领：此战退无可退。" if boss_no_retreat \
			else "当前地形、追击或敌方控制不允许撤离。" if not retreat_open \
			else "元石不足：需要 %d 枚。" % retreat_cost if state.stone < retreat_cost else "",
		"cost": {"stone": retreat_cost} if retreat_cost > 0 else {},
		"known_risk": ["撤离成功后会放弃本次战利品。"],
		"remedy_hints": [] if boss_no_retreat else (
			["可先催发雾步蛊保留撤离机会。"] if not retreat_open else _stone_remedies(retreat_cost - state.stone)),
	}))
	cards.append(_battle_card(battle, state, {
		"id": "battle.end_turn",
		"title": "收势",
		"summary": "结束本轮，敌方将执行已公开意图。",
		"executable": true,
		"cost": {},
		"known_risk": ["敌方将执行：%s。" % _living_intent_labels(battle)],
	}))
	_assert_unique_ids(cards)
	return cards


static func _append_battle_hand_card(cards: Array[Dictionary], battle: Dictionary, state: RunState, catalog: Dictionary, definition: Dictionary, instance: Dictionary) -> void:
	var cost: Dictionary = definition.get("cost", {})
	var essence_cost := int(cost.get("essence", 0))
	var source_gu_ids: Array = definition.get("source_gu_ids", [])
	if source_gu_ids.is_empty():
		return
	var source_gu_id := str(source_gu_ids[0])
	var card_mode := str(definition.get("mode", ""))
	var affordable_essence := state.essence + int(battle.get("action_energy", 0))
	var executable := affordable_essence >= essence_cost
	var risk: Array[String] = []
	if source_gu_id == "thorn_whip_gu" and battle.get("clues", []).has("stone_dust"):
		risk.append("对方脚下石粉未散，直接攻伐可能遭遇已知的护身反制。")
	# Thorn strike shares the punch's swallow path in the resolver; the probe
	# (small_light_gu) bypasses reactions and must not claim this risk.
	if source_gu_id == "thorn_whip_gu" and card_mode != "bind":
		risk.append_array(_counter_swallow_risk(battle))
	var gu_by_id: Dictionary = catalog.get("gu_by_id", {})
	var highest_rank := 1
	for gu_id_value in source_gu_ids:
		highest_rank = maxi(highest_rank, int(gu_by_id.get(str(gu_id_value), {}).get("rank", 1)))
	if highest_rank > int(state.cultivator.get("reincarnation", 1)):
		risk.append("以低修为催动高转蛊会触发已知反噬，损伤气血与魂魄。")
	if bool(definition.get("occupies_soul_slots", false)):
		var occupied: Array = battle.get("active_gu_instance_ids", [])
		var projected := occupied.duplicate()
		for source_instance_id in instance.get("source_gu_instance_ids", []):
			if not projected.has(source_instance_id):
				projected.append(source_instance_id)
		if projected.size() > SoulCapacityScript.battle_ops_cap(state):
			risk.append("当前魂魄无法承受这次并发催动，会触发魂魄反噬。")
	var target_type := _target_type_for_gu(source_gu_id, definition)
	var valid_target_ids: Array[String] = []
	if target_type == "single_enemy":
		valid_target_ids.append_array(_living_enemy_ids(battle))
	cards.append(_battle_card(battle, state, {
		"id": "battle.%s.%s" % [str(battle.get("battle_id", "")), str(instance.get("instance_id", ""))],
		"title": DisplayText.gu(source_gu_id),
		"summary": _battle_effect(source_gu_id, card_mode),
		"executable": executable,
		"block_reason": "真元不足：需要 %d 点，当前仅有 %d 点。" % [essence_cost, affordable_essence] if not executable else "",
		"cost": {"spirit": essence_cost},
		"known_risk": risk,
		"expected_gain": [_battle_effect(source_gu_id, card_mode)],
		"unknown_note": "部分效果会受敌方状态和未暴露后手影响。" if not risk.is_empty() else "",
		"remedy_hints": ["可先收势恢复判断，或改用真元消耗更低的蛊虫。"] if not executable else [],
		"target_type": target_type,
		"valid_target_ids": valid_target_ids,
	}))


static func _battle_card(battle: Dictionary, state: RunState, values: Dictionary) -> Dictionary:
	var card := _card(state, values)
	card["state_version"] = int(battle.get("hand_version", 0))
	card["command"] = {}
	if not card.has("target_type"):
		card["target_type"] = "none"
	if not card.has("valid_target_ids"):
		card["valid_target_ids"] = []
	return card


static func _living_enemy_ids(battle: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)) and int(enemy.get("hp", 0)) > 0:
			ids.append(str(enemy.get("enemy_id", "")))
	return ids


static func _living_intent_labels(battle: Dictionary) -> String:
	var labels: Array[String] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)) and int(enemy.get("hp", 0)) > 0:
			labels.append(str((enemy.get("visible_intent", {}) as Dictionary).get("label", "已公开意图")))
	return "、".join(labels) if not labels.is_empty() else "已公开意图"


## §16.5 counter forewarning: labels of live direct-strike reactions the
## resolver would actually swallow. Mirrors BattleResolver._reaction_countered
## flag semantics (bound -> enemy_bound, guarded -> guarded); a countered or
## already-bound enemy clears the warning. Only strike paths the resolver
## checks (basic punch, thorn whip strike) may present this risk.
static func _live_counter_labels(battle: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	var flags: Array = battle.get("flags", [])
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("alive", false)) or int(enemy.get("hp", 0)) <= 0:
			continue
		for reaction_value in enemy.get("reactions", []):
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


static func _target_type_for_gu(gu_id: String, definition: Dictionary) -> String:
	if gu_id in ["small_light_gu", "thorn_whip_gu", "blood_moss_gu", "blood_droplet_gu", "blood_bat_gu", "force_gu", "moonlight_gu", "moon_glow_gu"]:
		return "single_enemy"
	for effect_value in definition.get("combat_effects", []):
		if str((effect_value as Dictionary).get("kind", "")) == "strike":
			return "single_enemy"
	return "self"

static func _append_battle_gu_card(cards: Array[Dictionary], battle: Dictionary, state: RunState, gu: Dictionary, gu_id: String, mode: String) -> void:
	var essence_cost := int(gu.get("essence_cost", 0))
	var executable := state.essence >= essence_cost
	var title_suffix := ""
	var effect := _battle_effect(gu_id, mode)
	if not mode.is_empty():
		title_suffix = "·%s" % ("束缚" if mode == "bind" else "抽击")
	var risk: Array[String] = []
	if gu_id == "thorn_whip_gu" and mode == "strike" and battle.get("clues", []).has("stone_dust"):
		risk.append("对方脚下石粉未散，直接攻伐可能遭遇已知的护身反制。")
	if gu_id == "thorn_whip_gu" and mode != "bind":
		risk.append_array(_counter_swallow_risk(battle))
	cards.append(_card(state, {
		"id": "battle.gu.%s.%s" % [gu_id, mode if not mode.is_empty() else "activate"],
		"title": "%s%s" % [DisplayText.gu(gu_id), title_suffix],
		"summary": effect,
		"executable": executable,
		"block_reason": "真元不足：需要 %d 点，当前仅有 %d 点。" % [essence_cost, state.essence] if not executable else "",
		"cost": {"spirit": essence_cost},
		"known_risk": risk,
		"expected_gain": [effect],
		"unknown_note": "部分效果会受敌方状态和未暴露后手影响。" if not risk.is_empty() else "",
		"remedy_hints": ["可先收势恢复判断，或改用真元消耗更低的蛊虫。"] if not executable else [],
		"command": {"type": "use_gu", "gu_id": gu_id, "mode": mode},
	}))


static func _battle_effect(gu_id: String, mode: String) -> String:
	if gu_id == "thorn_whip_gu":
		return "束缚敌人，使其难以施展护身反制。" if mode == "bind" else "对敌人造成 2 点伤害。"
	match gu_id:
		"small_light_gu": return "小光弹照中敌手，伤敌并照出异状。"
		"stone_shell_gu": return "获得护身，削减本轮所受伤害。"
		"mist_step_gu": return "保留撤离机会。"
		"blood_moss_gu": return "恢复 1 点伤势并造成 1 点伤害。"
		"venom_thread_gu": return "拖慢敌人攻势。"
		"pulse_drum_gu": return "打断敌方本轮攻势。"
		"shadow_veil_gu": return "扰乱敌方锁定，削减伤害。"
		"moonlight_gu": return "月刃横空，对敌人造成 2 点伤害。"
		"moon_glow_gu": return "月华炽放，对敌人造成 3 点伤害。"
		"trail_eye_gu": return "目光如炬，照出敌方异状并拖慢其攻势。"
		"blood_droplet_gu": return "血滴如刃，对敌人造成 2 点伤害。"
		"blood_bat_gu": return "蝙蝠噬血：恢复 1 点伤势并造成 1 点伤害。"
		"blood_wing_gu": return "展开血翼，保留撤离机会。"
		"blood_farewell_gu": return "爱别离之毒缚住敌人，拖慢本回合攻势。"
		"force_gu": return "力量蛊爆发，对敌人造成 2 点伤害。"
		"bear_strength_gu": return "熊力贯体，恢复 1 点伤势。"
		"qi_wall_gu": return "竖起无形气墙，护住周身。"
	return "催发蛊虫效果。"


static func _battle_retreat_open(battle: Dictionary) -> bool:
	if BattleResolver.boss_blocks_retreat(battle):
		return false
	return BattleResolver.can_retreat(
		str(battle.get("terrain", "")),
		int(battle.get("pursuit", 0)),
		int(battle.get("enemy_control", 0))
	)


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
				_append_recipe_card(cards, state, recipe, catalog)
	_append_leave_card(cards, state)


static func _append_recipe_card(cards: Array[Dictionary], state: RunState, recipe: Dictionary, catalog: Dictionary) -> void:
	var inputs: Array = recipe.get("input_gu_ids", [])
	var missing := _missing_gu(state.refined_gu_ids, inputs)
	var destroys_inputs := str(recipe.get("failure", "")) == "destroy_inputs"
	var locked := bool(recipe.get("locked", false))
	var codex_unlocked := state.global_codex_ids.has(str(recipe.get("id", ""))) or state.global_codex_ids.has(str(recipe.get("output_gu_id", "")))
	var deck_full := DeckCapacityScript.projected_count(state, catalog, [str(recipe.get("output_gu_id", ""))], inputs) > DeckCapacityScript.capacity(catalog)
	var is_fixed := str(recipe.get("kind", "combine")) == "fixed"
	var success_rate: Variant = null
	if not is_fixed:
		success_rate = int(recipe.get("success_roll_max", 0))
	var executable := missing.is_empty() and (not locked or codex_unlocked) and not deck_full
	var reason := ""
	if deck_full:
		reason = "牌组已满（%d/%d），炼成后无法容纳新蛊。" % [DeckCapacityScript.card_count(state, catalog), DeckCapacityScript.capacity(catalog)]
	elif locked and not codex_unlocked:
		reason = str(recipe.get("locked_reason", "尚未获得对应的炼制传承，无法按固定配方合炼。"))
	elif not missing.is_empty():
		reason = "缺少%s。" % _gu_names(missing)
	cards.append(_card(state, {
		"id": "refine.%s" % str(recipe["id"]),
		"title": "炼制%s" % DisplayText.gu(str(recipe["output_gu_id"])),
		"summary": "以%s合炼。" % _gu_names(inputs),
		"executable": executable,
		"block_reason": reason,
		"cost": _cost(0, inputs, 1),
		"known_risk": ["失败会损毁输入蛊虫：%s。" % _gu_names(inputs)] if destroys_inputs else [],
		"expected_gain": ["获得%s。" % DisplayText.gu(str(recipe["output_gu_id"]))],
		"unknown_note": "" if is_fixed else "炼制成败未定。",
		"success_rate": success_rate,
		"remedy_hints": ["可在传承或奇遇中获得对应炼制知识。"] if locked and not codex_unlocked else _gu_remedies(missing),
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
		"purchase":
			var cost := Resolver.price_for(catalog, state, int(offer.get("stone_cost", 0)))
			var deck_full := DeckCapacityScript.would_exceed(state, catalog, 1)
			var executable := state.stone >= cost and not deck_full
			cards.append(_card(state, {
				"id": "shop.%s" % str(offer["card_key"]),
				"title": "购入%s" % DisplayText.gu(str(offer["gu_id"])),
				"summary": "黑市明码标价，钱货两讫。",
				"executable": executable,
				"block_reason": "牌组已满（%d/%d），请先弃蛊或出售。" % [DeckCapacityScript.card_count(state, catalog), DeckCapacityScript.capacity(catalog)] if deck_full else "元石不足：需要 %d 枚，当前仅有 %d 枚。" % [cost, state.stone] if not executable else "",
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


static func _append_event_cards(cards: Array[Dictionary], state: RunState, catalog: Dictionary) -> void:
	for event in catalog.get("events", []):
		var health_cost := int(event.get("health_cost", 0))
		var executable := state.health > health_cost
		cards.append(_card(state, {
			"id": "event.%s.accept" % str(event["id"]),
			"title": "承受回声",
			"summary": "洞穴深处的回声在等待应答，应答者需先付出已知的气血代价。",
			"executable": executable,
			"block_reason": "当前气血不足以承受已知代价。" if not executable else "",
			"cost": {"hp": health_cost},
			"known_risk": ["已知代价：立即损失 %d 点气血。" % health_cost],
			"expected_gain": ["取得回声允诺的机缘。"],
			"unknown_note": "回声的后续代价结果未明，似有低语要在魂魄深处留下印记。",
			"remedy_hints": ["可先恢复气血，再回来应答。"] if not executable else [],
			"command": {"type": "accept_event", "event_id": str(event["id"])},
		}))
	_append_leave_card(cards, state)


static func _append_cultivation_cards(cards: Array[Dictionary], state: RunState) -> void:
	var required_stone := 5
	var executable := state.cultivation < 2 and state.stone >= required_stone
	var reason := ""
	if state.cultivation >= 2:
		reason = "你已经是二转蛊师。"
	elif state.stone < required_stone:
		reason = "元石不足：需要 %d 枚，还差 %d 枚。" % [required_stone, required_stone - state.stone]
	cards.append(_card(state, {
		"id": "cultivate.rank_two",
		"title": "冲击二转",
		"summary": "借泉眼静修，尝试突破空窍。",
		"executable": executable,
		"block_reason": reason,
		"cost": {"stone": required_stone, "time": 1},
		"expected_gain": ["由一转巅峰晋为二转初阶，真元恢复至上限。"],
		"remedy_hints": _stone_remedies(required_stone - state.stone) if state.stone < required_stone else [],
		"command": {"type": "cultivate_rank_two"},
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
	var boss: Dictionary = catalog.get("loot_tables", {}).get("loot", {}).get("boss", {})
	var recipe_id := str(boss.get("scavenge_recipe", ""))
	if recipe_id.is_empty() or state.global_codex_ids.has(recipe_id):
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
		return {"type": "resolve_contact", "node_id": str(node.get("id", "")), "approach": action_id}
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


static func _assert_unique_ids(cards: Array[Dictionary]) -> void:
	var seen := {}
	for card in cards:
		var id := str(card["id"])
		assert(not seen.has(id), "Duplicate action card id: %s" % id)
		seen[id] = true
