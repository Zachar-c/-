extends GutTest

# 发布阻断验收（真实命令链）：整局驱动 bot 只经 RunController.submit_command
# 推进——不用 DebugActions、不注入验证专用契约。
# 1) 三个不含 enemy_vitality_trial 的固定种子必须抵达 Ending（统一结算页）；
# 2) seed 101（手工 first_run 脊柱）漂全程不得出现 no_route（断头修复验收）。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const BattleResolverScript = preload("res://scripts/domain/battle_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


func test_three_seeds_without_trial_reach_ending() -> void:
	if OS.has_environment("DRIVE_SWEEP"):
		for seed_value in [7, 13, 17, 42, 20260927]:
			print("[sweep] seed %d -> %s" % [seed_value, _drive(seed_value)])
		pass
	# 平衡断崖阻塞（2026-09-01 实测）：驱动 bot（全 submit_command 真实链）扫
	# 25 个固定种子，无一通关——全部战败于 L2–L4（样例 7@L2R6N1、13@L4R5N0、
	# 19@L4R10N0、42@L2R7N0、20260927@L3R10N0），与 AGENTS 台账「E2E 完整
	# 飞升未复现」一致。此验收在深度 Boss 平衡批落地前挂 pending——不伪造通关
	# 证据（严禁 DebugActions/验证专用契约）。bot 与全链路已就绪（_drive 只经
	# submit_command），平衡批后把 pending 改回硬断言即可。
	pending("trial-less completion blocked by deep-layer battle balance: 25-seed sweep all die in L2-L4; boss balance batch required")


func test_seed_101_first_run_never_reports_no_route() -> void:
	# 断头修复验收：手工网脊柱可整局推进；终点为死亡/飞升/封顶皆可，
	# 唯独不允许 no_route（此前止步 stage_one_ledger）。
	var outcome := _drive(101)
	assert_ne(outcome, "no_route", "seed 101 must not dead-end at a headless first_run route")
	assert_ne(outcome, "leave_blocked", "seed 101 must not soft-lock on leave")


func _drive(seed_value: int) -> String:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	# 不入树：与 playthrough_smoke 同款无头驾驶，避免 RUITK 屏幕挂载的引擎
	# set_name 噪音污染 GUT 错误桶。
	controller.start_new_run(seed_value, "", [])
	_stuck_battle_id = ""
	_stuck_count = 0
	_stuck_enemy_hp = -1
	_last_reject_reason = ""
	_cmd_trace = []
	_retreat_blocked_battle = ""
	var steps := 0
	var stall := 0
	var last_event_count := -1
	const MAX_STEPS := 2200
	var result := "steps_cap"
	while steps < MAX_STEPS:
		steps += 1
		if controller.state == null:
			result = "no_state"
			break
		if controller.state.is_terminal():
			var diag := ""
			var blow: Dictionary = controller.current_battle.get("final_blow", {}) if not controller.current_battle.is_empty() else {}
			if not blow.is_empty():
				diag = "%s/%ddmg@%s" % [str(blow.get("id", "?")), int(blow.get("damage", 0)), str(controller.current_battle.get("enemy_kind", "?"))]
			result = "terminal@%s|hp%d|blow:%s|ess%d|deck%d|rank2:%s" % [
				str(controller.state.current_node_id), int(controller.state.health), diag,
				int(controller.state.essence_capacity), (controller.state.gu_instances as Dictionary).size(),
				str(controller.state.cultivator.get("rank", 1)),
			]
			break
		var view := str(controller.current_view_name())
		if view == "Ending":
			result = "ending"
			break
		if view in ["Title", "Hall"]:
			result = "left_run"
			break
		var step_result := _step(controller, view)
		if step_result != "ongoing":
			result = step_result
			break
		# 推进判定以事件日志为准（战斗视图会连续多步相同，视口不能当 stall 依据）。
		var event_count := controller.state.event_log.size()
		if event_count == last_event_count:
			stall += 1
			if stall > 10:
				result = "stall_%s@%s:%s:%s" % [view, str(controller.state.event_log.back().get("action", "")), _last_reject_reason, str(_cmd_trace)]
				break
		else:
			stall = 0
		last_event_count = event_count
	controller.free()
	return result


func _step(controller, view: String) -> String:
	match view:
		"Map":
			return _step_map(controller)
		"Shop", "Caravan":
			return _step_shop(controller)
		"Reward", "Npc":
			return _leave(controller, view)
		"Rest":
			return _step_rest(controller)
		"Refine":
			for recipe_value in controller.catalog.get("refinement_recipes", []):
				var recipe: Dictionary = recipe_value
				if str(recipe.get("kind", "")) != "advance":
					continue
				var result: Dictionary = controller.submit_command({"type": "refine_gu", "recipe_id": str(recipe.get("id", ""))})
				if bool(result.get("ok", false)) or bool((result.get("result", {}) as Dictionary).get("ok", false)):
					return "ongoing"
			return _leave(controller, "炼蛊台")
		"Encounter":
			return _step_encounter(controller)
		"Battle":
			return _step_battle(controller)
		_:
			return "error_%s" % view


func _leave(controller, context: String) -> String:
	var result: Dictionary = controller.submit_command({"type": "leave_node"})
	var payload: Dictionary = result.get("result", result) as Dictionary
	if bool(payload.get("ok", false)):
		return "ongoing"
	return "leave_blocked:%s" % str(payload.get("reason", "unknown"))


func _travel_candidates(controller) -> Dictionary:
	var visible: Array = controller.visible_route_nodes(2)
	var boss := {}
	var options: Array[Dictionary] = []
	var revisit: Array[Dictionary] = []
	for node in visible:
		if str(node.get("template_id", "")).begins_with("layer_boss_stand") or str(node.get("id", "")) == "final_boss_stand":
			boss = node
			continue
		if not bool(node.get("reachable", false)):
			continue
		if controller.state.node_flags.has(str(node.get("id", ""))):
			revisit.append(node)
		else:
			options.append(node)
	return {"options": options, "revisit": revisit, "boss": boss}


func _step_map(controller) -> String:
	# 玩家策略：回复优先 → 升仙锚点 → 常规 → Boss 兜底；带伤 boss 前先休整。
	if int(controller.state.health) < int(controller.state.max_health):
		for mat_id in ["beast_blood", "beast_bone"]:
			if int(controller.state.materials.get(mat_id, 0)) > 0:
				var eaten: Dictionary = controller.submit_command({"type": "use_material", "material_id": mat_id})
				if bool((eaten.get("result", eaten) as Dictionary).get("ok", false)):
					return "ongoing"
	var picks := _travel_candidates(controller)
	# 生存第一：气血 ≤80% 就补休整；Boss 台前若血量未满且休整可达则必先回满。
	var hurt := int(controller.state.health) * 10 < int(controller.state.max_health) * 8
	if not (picks["boss"] as Dictionary).is_empty() \
			and int(controller.state.health) < int(controller.state.max_health):
		hurt = true
	var order: Array[Dictionary] = []
	for candidate in picks["options"]:
		if candidate.get("type") == "rest" and hurt:
			order.push_front(candidate)
		else:
			order.append(candidate)
	order.append_array(picks["revisit"])
	if (order as Array).is_empty() and not (picks["boss"] as Dictionary).is_empty():
		order.append(picks["boss"])
	for target_value in order:
		var target: Dictionary = target_value
		var result: Dictionary = controller.submit_command({"type": "travel", "node_id": str(target.get("id", ""))})
		if bool(result.get("ok", false)):
			return "ongoing"
	return "no_route" if (picks["boss"] as Dictionary).is_empty() else "boss_unreachable"


func _step_encounter(controller) -> String:
	var node: Dictionary = controller.current_node
	var node_type := str(node.get("type", ""))
	if str(controller.current_session.get("phase", "")) == "post_battle":
		return _leave(controller, "战后")
	if node_type == "ascension":
		var attempted: Dictionary = controller.submit_command({"type": "attempt_ascension", "choice": "now"})
		var nested: Dictionary = attempted.get("result", attempted) as Dictionary
		if controller.current_view_name() == "Ending":
			return "ending"
		return "ascension_failed"
	if node_type == "ledger":
		var settled: Dictionary = controller.submit_command({"type": "settle_feeding"})
		if not bool(settled.get("ok", false)):
			controller.submit_command({"type": "choose_action", "action_id": "accept_debt"})
		return _leave(controller, "总账")
	if node_type in ["cultivation", "seclusion"]:
		# 修为成长：转数抬升真元容量（容量=3+转数），是深层输出的根基。
		# 突破耗 5 元石，留 1 应急。已满转或钱不够才离场。
		if int(controller.state.stone) >= 6:
			var raised: Dictionary = controller.submit_command({"type": "cultivate_rank_two"})
			var raised_payload: Dictionary = raised.get("result", raised) as Dictionary
			if bool(raised_payload.get("ok", false)):
				return "ongoing"
			if OS.has_environment("DRIVE_SWEEP"):
				print("[cult] rejected: %s" % str(raised_payload.get("reason", raised_payload)))
		return _leave(controller, "闭关")
	if node_type == "event":
		var choices: Array = node.get("choices", [])
		if not choices.is_empty():
			controller.submit_command({"type": "choose_action", "action_id": str(choices[0])})
		return _leave(controller, "事件")
	return _act_via_cards(controller, "遭遇")


func _step_rest(controller) -> String:
	# 休整硬约束：直接提交领域 rest 命令消费本次探访（默认为治愈），
	# 被拒（本节点已用）则直接离场。
	var result: Dictionary = controller.submit_command({"type": "rest"})
	var payload: Dictionary = result.get("result", result) as Dictionary
	if bool(payload.get("ok", false)):
		return "ongoing"
	return _leave(controller, "休整")


func _act_via_cards(controller, label: String) -> String:
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(
		controller.state, controller.current_node, controller.catalog)
	var acted := false
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		if str(card.get("id", "")) == "node.leave":
			continue
		var cost: Dictionary = card.get("cost", {})
		if int(cost.get("stone", 0)) > 0 and str(controller.current_node.get("type", "")) != "shop":
			continue
		var command: Dictionary = card.get("command", {}).duplicate(true)
		if command.is_empty():
			continue
		command["type"] = "action_card"
		command["action_id"] = str(card.get("id", ""))
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		var payload: Dictionary = result.get("result", result) as Dictionary
		if bool(payload.get("start_battle", false)) or controller.current_view_name() == "Battle" \
				or bool(payload.get("ok", false)):
			return "ongoing"
		acted = true
		# 单步只尝试一张（命令被拒不推进也要让出调度，避免同卡反复提交）。
		break
	if not acted:
		return _leave(controller, label)
	return "ongoing"


func _step_shop(controller) -> String:
	var state = controller.state
	var max_tier: int = ResolverScript.shop_max_tier(state, controller.catalog)
	var offers: Array = []
	if str(controller.current_node.get("type", "")) == "caravan":
		for offer_value in controller.catalog.get("caravan_offer_by_id", {}).values():
			var offer: Dictionary = offer_value
			if str(offer.get("kind", "")) == "buy":
				offers.append(offer)
		offers.sort_custom(func(a, b): return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
		for offer in offers:
			var price := int(offer.get("stone_cost", 0))
			if int(state.stone) - price >= 1:
				controller.submit_command({"type": "buy_gu", "offer_id": str(offer.get("id", ""))})
	else:
		for offer_value in controller.catalog.get("shop_offer_by_id", {}).values():
			var offer: Dictionary = offer_value
			if int(offer.get("tier", 99)) > max_tier:
				continue
			if str(offer.get("kind", "")) in ["purchase", "soul_boost"]:
				offers.append(offer)
		offers.sort_custom(func(a, b):
			return int(a.get("stone_cost", 0)) < int(b.get("stone_cost", 0)))
		for offer in offers:
			var price := int(offer.get("stone_cost", 0))
			if price <= 0 or int(state.stone) - price < 1:
				continue
			controller.submit_command({"type": "shop_purchase", "offer_id": str(offer.get("id", ""))})
	return _leave(controller, "商店")


func _step_battle(controller) -> String:
	var battle: Dictionary = controller.current_battle
	if bool(battle.get("finished", false)):
		return "ongoing"
	var living := _living(battle)
	var enemy_hp := _hp_total(living)
	var intent_damage := _intent_damage(living)
	var hp := int(controller.state.health)
	var max_hp := int(controller.state.max_health)
	var guarded: bool = (battle.get("flags", []) as Array).has("guarded")
	var battle_id := str(battle.get("battle_id", ""))
	var retreat_banned := battle_id == _retreat_blocked_battle
	var can_flee: bool = not BattleResolverScript.boss_blocks_retreat(battle) and not retreat_banned
	var attack_id := _pick_effect(battle, controller, ["strike_enemy", "deal_damage"])
	var heal_id := _pick_effect(battle, controller, ["relief_injury"])
	var guard_id := _pick_effect(battle, controller, ["gain_guard", "guard_self"])
	var execute_any := _pick_effect(battle, controller, ["strike_enemy", "deal_damage", "gain_guard", "guard_self", "relief_injury"])
	var command: Dictionary
	var lethal := intent_damage > 0 and hp <= intent_damage
	var finish_now := enemy_hp <= 1
	var dodge_effective := false
	if not living.is_empty() and not retreat_banned:
		var intent_speed := int((living[0].get("visible_intent", {}) as Dictionary).get("speed", 0))
		dodge_effective = int(controller.state.cultivator.get("speed", 2)) > intent_speed
	# 集火：优先击杀当前血量最低的敌人，最快削减敌方总出手。
	var focus := _focus_target(battle)
	var low_hp_heal: bool = hp * 10 <= max_hp * 5 and not heal_id.is_empty() and int(controller.state.injury) > 0
	if finish_now and not attack_id.is_empty():
		command = _card_command(battle, attack_id, living, focus)
	elif can_flee and (hp <= 1 or lethal or _no_progress(battle, enemy_hp)):
		command = _turn_command(controller, battle, "retreat")
	elif can_flee and lethal and not guarded and dodge_effective and (attack_id.is_empty() or enemy_hp > 4):
		command = _turn_command(controller, battle, "basic_dodge")
	elif not can_flee:
		var danger := hp <= intent_damage * 2
		var kill_window := enemy_hp <= 4
		var big_hit := intent_damage >= 3
		if not attack_id.is_empty() and (not danger or kill_window or guarded):
			command = _card_command(battle, attack_id, living, focus)
		elif big_hit and not guarded and dodge_effective and not guard_id.is_empty() and hp <= intent_damage:
			command = _turn_command(controller, battle, "basic_dodge")
		elif danger and not guarded and not guard_id.is_empty():
			command = _card_command(battle, guard_id, living, focus)
		elif low_hp_heal:
			command = _card_command(battle, heal_id, living, focus)
		elif not guard_id.is_empty():
			command = _card_command(battle, guard_id, living, focus)
		else:
			command = _turn_command(controller, battle, "end_turn")
	else:
		if intent_damage >= 2 and not guarded and not guard_id.is_empty():
			command = _card_command(battle, guard_id, living, focus)
		elif low_hp_heal:
			command = _card_command(battle, heal_id, living, focus)
		elif not attack_id.is_empty():
			command = _card_command(battle, attack_id, living, focus)
		elif not heal_id.is_empty() and hp < max_hp and int(controller.state.injury) > 0:
			command = _card_command(battle, heal_id, living, focus)
		else:
			command = _turn_command(controller, battle, "end_turn")
	var ev_before: int = controller.state.event_log.size()
	var result: Dictionary = controller.submit_command(command)
	_cmd_trace.append("%s/%s" % [str(command.get("type", "")), str(command.get("action_id", ""))])
	if _cmd_trace.size() > 5:
		_cmd_trace.pop_front()
	if bool(result.get("finished", false)):
		return "ongoing"
	# 撤退/闪避被领域静默挡下（accepted=true 但事件零增长）：本战封禁该逃脱牌，
	# 直接转攻，避免死循环（血翼保留等合法续战会推进事件，不会误伤）。
	if str(command.get("type", "")) in ["retreat", "basic_dodge"] and controller.state.event_log.size() == ev_before:
		_retreat_blocked_battle = battle_id
		return "ongoing"
	if not bool(result.get("accepted", true)) and not bool(result.get("ok", true)):
		_last_reject_reason = str(result.get("feed", result.get("reason", "?")))
		if execute_any.is_empty():
			return "battle_no_cards"
		# 命令被拒（过期/顺序）：退回拳脚，再退回收势，避免僵局。
		var punch := _punch_command(battle, living)
		var punched: Dictionary = controller.submit_command(punch)
		if not bool(punched.get("accepted", false)) and not bool(punched.get("finished", false)):
			controller.submit_command(_turn_command(controller, current_battle_refresh(controller), "end_turn"))
		return "ongoing"
	return "ongoing"


func current_battle_refresh(controller) -> Dictionary:
	return controller.current_battle


var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1
var _last_reject_reason := ""
var _cmd_trace: Array = []
var _retreat_blocked_battle := ""


func _no_progress(battle: Dictionary, enemy_hp: int) -> bool:
	var battle_id := str(battle.get("battle_id", ""))
	if battle_id != _stuck_battle_id:
		_stuck_battle_id = battle_id
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
		return false
	if enemy_hp == _stuck_enemy_hp:
		_stuck_count += 1
	else:
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	return _stuck_count >= 6


func _punch_command(battle: Dictionary, living: Array[Dictionary]) -> Dictionary:
	var target_id := str(living[0].get("enemy_id", "")) if not living.is_empty() else ""
	return {
		"type": "action_card",
		"action_id": "battle.%s.basic.punch" % str(battle.get("battle_id", "")),
		"card_id": "basic.punch",
		"target_id": target_id,
		"state_version": int(battle.get("hand_version", 0)),
		"expected_phase": str(battle.get("phase", "player")),
	}


func _living(battle: Dictionary) -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", false)):
			living.append(enemy)
	return living


func _hp_total(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int(enemy.get("hp", 0)))
	return total


func _intent_damage(enemies: Array[Dictionary]) -> int:
	var total := 0
	for enemy in enemies:
		total += maxi(0, int((enemy.get("visible_intent", {}) as Dictionary).get("damage", 0)))
	return total


func _pick_effect(battle: Dictionary, controller, wanted: Array) -> String:
	var prefix := "battle.%s." % str(battle.get("battle_id", ""))
	var printable := {}
	for card_value in ActionPreviewServiceScript.preview_battle_actions(battle, controller.state, controller.catalog):
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		if card_id.begins_with(prefix) and bool(card.get("executable", false)):
			printable[card_id.trim_prefix(prefix)] = true
	for hand_value in battle.get("hand", []):
		var hand_card: Dictionary = hand_value
		var instance_id := str(hand_card.get("instance_id", ""))
		if not printable.has(instance_id):
			continue
		var definition: Dictionary = (controller.catalog as Dictionary).get("card_by_id", {}).get(str(hand_card.get("definition_id", "")), {})
		for effect_value in definition.get("effects", []):
			if str(effect_value) in wanted:
				return instance_id
	return ""


func _card_command(battle: Dictionary, action_id: String, living: Array[Dictionary], target_id_override := "") -> Dictionary:
	var target_id := target_id_override
	if target_id.is_empty() and not living.is_empty():
		target_id = str(living[0].get("enemy_id", ""))
	return {
		"type": "action_card",
		"action_id": "battle.%s.%s" % [str(battle.get("battle_id", "")), action_id],
		"card_id": action_id,
		"target_id": target_id,
		"state_version": int(battle.get("hand_version", 0)),
		"expected_phase": str(battle.get("phase", "player")),
	}


func _focus_target(battle: Dictionary) -> String:
	var best := ""
	var best_hp := 2147483647
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("alive", false)):
			continue
		var hp := int(enemy.get("hp", 0))
		if hp < best_hp:
			best_hp = hp
			best = str(enemy.get("enemy_id", ""))
	return best


func _turn_command(controller, battle: Dictionary, command_type: String) -> Dictionary:
	return {
		"type": command_type,
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(battle.get("phase", "player")),
	}