extends GutTest

# 发布阻断验收（真实命令链）：整局驱动 bot 只经 RunController.submit_command
# 推进——不用 DebugActions、不注入验证专用契约。
# 1) 25 个固定种子全程驱动：每个种子都必须抵达 Ending（统一结算页）或
#    确定性终局（死亡/封顶），并记录每层 Boss 战前数据、Boss 战逐回合
#    intent/damage/shield、回合数、结局与死因，供平衡批调取；
# 2) seed 101 作为普通生成种子漂全程不得出现 no_route / leave_blocked
#    （断头修复验收泛化；玩家局无教学/固定种子，101 与任何种子一样走
#    生成式地图）。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const BattleCommandFacadeScript = preload("res://scripts/domain/battle_command_facade.gd")
const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")
const ResolverScript = preload("res://scripts/domain/resolver.gd")


func test_twenty_five_seeds_reach_ending_or_terminal_with_trace() -> void:
	var seeds := [1, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]
	var traces: Array[Dictionary] = []
	var reached_l5_count := 0
	var entered_ending_count := 0
	for seed_value in seeds:
		var outcome := _drive(seed_value)
		traces.append(outcome)
		if bool(outcome.get("reached_l5", false)):
			reached_l5_count += 1
		if bool(outcome.get("entered_ending", false)):
			entered_ending_count += 1
		var accepted := bool(outcome.get("entered_ending", false)) or str(outcome.get("result", "")).begins_with("terminal@")
		if OS.has_environment("DRIVE_SWEEP") or not accepted:
			print("[sweep] seed %d -> %s" % [seed_value, _format_trace(outcome)])
	assert_eq(traces.size(), 25)
	for trace in traces:
		var result := str(trace.get("result", ""))
		var seed_value := int(trace.get("seed", -1))
		assert_false(result.begins_with("leave_blocked"), "seed %d must not soft-lock while leaving: %s" % [seed_value, _format_trace(trace)])
		assert_ne(result, "no_route")
		assert_ne(result, "steps_cap")
		assert_true(bool(trace.get("entered_ending", false)) or result.begins_with("terminal@"))
	assert_gte(reached_l5_count, 13)
	assert_gte(entered_ending_count, 13)
	assert_gte(reached_l5_count, 22)
	assert_gte(entered_ending_count, 22)



func test_seed_101_generated_run_never_reports_no_route() -> void:
	# 断头修复验收（泛化）：任意种子（含 101）的生成式地图都必须能推进，
	# 终点为死亡/飞升/封顶皆可，唯独不允许 no_route 或 leave_blocked。
	var outcome := _drive(101)
	print("[sweep] seed 101 -> %s" % _format_trace(outcome))
	var result := str(outcome.get("result", ""))
	assert_ne(result, "no_route", "seed 101 生成图不得死路（此前止步 stage_one_ledger）")
	assert_ne(result, "leave_blocked", "seed 101 生成图不得软锁在离场上")
	assert_false(result.begins_with("leave_blocked:"), "seed 101 不得软锁在离场")


func _format_trace(trace: Dictionary) -> String:
	var runaways := trace.get("runaways", []) as Array
	return "%s|layer:%d|l5:%s|ending:%s|battles:%d|boss:%d|runaway:%s|turns:%s|death:%s" % [
		str(trace.get("result", "")), int(trace.get("max_layer", 0)),
		str(trace.get("reached_l5", false)), str(trace.get("entered_ending", false)),
		int(trace.get("battles", 0)), (trace.get("boss_pre_states", []) as Array).size(),
		",".join(runaways) if not runaways.is_empty() else "-",
		str(trace.get("battle_turns", [])), str(trace.get("death_cause", "")),
	]


func _observe_progress(controller, trace: Dictionary) -> void:
	var node_layer := int(controller.current_node.get("layer", 0))
	var battle_layer := int(controller.current_battle.get("layer", 0))
	trace["max_layer"] = maxi(int(trace.get("max_layer", 0)), maxi(node_layer, battle_layer))
	if int(trace["max_layer"]) >= 5:
		trace["reached_l5"] = true
	if str(controller.current_view_name()) == "Ending":
		trace["entered_ending"] = true


func _is_fight_card(card: Dictionary) -> bool:
	var command: Dictionary = card.get("command", {})
	return str(command.get("action_id", "")) == "fight" or (str(command.get("type", "")) == "resolve_contact" and str(command.get("approach", "")) == "fight")


func _mandatory_fight_pending(controller) -> bool:
	var session: Dictionary = controller.current_session
	return bool(session.get("offers_fight", false)) and str(session.get("stance", "neutral")) == "extreme_hostile" and str(session.get("phase", "active")) != "post_battle"


func _fight_via_preview(controller) -> String:
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, controller.catalog)
	for card in cards:
		if not bool(card.get("executable", false)) or not _is_fight_card(card):
			continue
		var result: Dictionary = controller.submit_command({"type": "action_card", "action_id": str(card.get("id", "")), "state_version": controller.state.event_log.size(), "node_id": str(controller.current_node.get("id", "")), "session_node_id": str(controller.current_session.get("node_id", ""))})
		var payload: Dictionary = result.get("result", result)
		if bool(payload.get("start_battle", false)) or str(controller.current_view_name()) == "Battle" or bool(payload.get("ok", false)):
			return "ongoing"
		_last_reject_reason = str(payload.get("reason", "mandatory_fight_rejected"))
		return "mandatory_fight_rejected:%s" % _last_reject_reason
	var session: Dictionary = controller.current_session
	return "mandatory_fight_missing@%s:stance=%s:phase=%s" % [str(controller.state.current_node_id), str(session.get("stance", "?")), str(session.get("phase", "?"))]


var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1
var _last_reject_reason := ""
var _cmd_trace: Array = []
# 逐回合记录游标：同一节点的战斗内按 battle.turn 推进采样。
var _rec_node := ""
var _rec_turn := -1
var _rec_is_boss := false
var _rec_hp := -1
var _rec_shield := -1
var _rec_intent := -1
var _footprint: Array = []


func _drive(seed_value: int) -> Dictionary:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	# 不入树：与 acceptance_driver 的 play 模式同款无头驾驶，避免 RUITK 屏幕挂载的引擎
	# set_name 噪音污染 GUT 错误桶。
	controller.start_new_run(seed_value, "", [])
	# 深层走通覆盖：本测试按多层契约驱动，关闭切片收官（S6 默认 L1 Boss 落败即 Ending）。
	controller.catalog["pacing"]["ending_after_stage"] = ""
	_stuck_battle_id = ""
	_stuck_count = 0
	_stuck_enemy_hp = -1
	_last_reject_reason = ""
	_cmd_trace = []
	_rec_node = ""
	_rec_turn = -1
	_rec_is_boss = false
	_rec_hp = -1
	_rec_shield = -1
	_rec_intent = -1
	_footprint = []
	var trace := {
		"seed": seed_value,
		"result": "steps_cap",
		"battles": 0,
		"boss_pre_states": [],
		"battle_turns": [],
		"death_cause": "",
		"max_layer": 0,
		"reached_l5": false,
		"entered_ending": false,
	}
	var steps := 0
	var stall := 0
	var last_event_count := -1
	const MAX_STEPS := 2200
	while steps < MAX_STEPS:
		steps += 1
		if controller.state == null:
			trace["result"] = "no_state"
			break
		_observe_progress(controller, trace)
		var view := str(controller.current_view_name())
		if view == "Ending":
			trace["result"] = "ending"
			trace["death_cause"] = str(controller._ending_state.get("death_cause_id", ""))
			break
		if controller.state.is_terminal():
			var battle: Dictionary = controller.current_battle
			var battle_result: Dictionary = battle.get("result", {})
			var enemy_ids: Array[String] = []
			for enemy_value in battle.get("enemies", []):
				var enemy: Dictionary = enemy_value
				enemy_ids.append(str(enemy.get("id", "?")))
			trace["result"] = "terminal@%s|hp%d|cause:%s|phase:%s|enemy:%s|ess%d|gu%d|rank2:%s" % [
				str(controller.state.current_node_id), int(controller.state.health),
				str(battle_result.get("cause", "?")), str(battle.get("phase", "?")),
				",".join(enemy_ids), int(controller.state.essence_capacity),
				(controller.state.gu_instances as Dictionary).size(),
				str(controller.state.cultivator.get("rank", 1)),
			]
			trace["death_cause"] = str(battle_result.get("cause", ""))
			break
		if view in ["Title", "Hall"]:
			trace["result"] = "left_run"
			break
		var step_result := _step(controller, view, trace)
		_footprint.append("%d %s@%s->%s" % [steps, view, str(controller.state.current_node_id), step_result])
		if _footprint.size() > 30:
			_footprint.pop_front()
		_observe_progress(controller, trace)
		if step_result != "ongoing":
			if step_result == "ending" and not bool(trace["entered_ending"]):
				trace["result"] = "ending_without_view"
			else:
				trace["result"] = step_result
			break
		# 推进判定以事件日志为准（战斗视图会连续多步相同，视口不能当 stall 依据）。
		var event_count := controller.state.event_log.size()
		if event_count == last_event_count:
			stall += 1
			if stall > 10:
				trace["result"] = "stall_%s@%s:%s:%s" % [view, str(controller.state.event_log.back().get("action", "")), _last_reject_reason, str(_cmd_trace)]
				break
		else:
			stall = 0
		last_event_count = event_count
	if not (trace["result"] as String).begins_with("ending") \
			and not (trace["result"] as String).begins_with("terminal@"):
		print("[tail] seed %d %s | %s" % [seed_value, trace["result"], " | ".join(_footprint)])
	controller.free()
	return trace


func _step(controller, view: String, trace: Dictionary) -> String:
	match view:
		"Map":
			return _step_map(controller)
		"Shop", "Caravan":
			return _step_shop(controller)
		"Reward":
			return _leave(controller, view)
		"Npc":
			# 血仇门禁：恶名触发的 extreme_hostile 会锁 leave（feud_no_escape），
			# 但 UI 保留 fight 卡。bot 必须优先打完血仇战再离场（真玩家同路径）。
			var npc_cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(
				controller.state, controller.current_node, controller.catalog)
			var can_fight := false
			for card in npc_cards:
				if bool(card.get("executable", false)) and _is_fight_card(card):
					can_fight = true
					break
			if can_fight:
				var fought := _fight_via_preview(controller)
				if fought == "ongoing" or fought.begins_with("mandatory_fight"):
					return fought
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
			return _step_battle(controller, trace)
		_:
			return "error_%s" % view


func _leave(controller, context: String) -> String:
	var result: Dictionary = controller.submit_command({"type": "leave_node"})
	var payload: Dictionary = result.get("result", result) as Dictionary
	if bool(payload.get("ok", false)):
		return "ongoing"
	if OS.has_environment("DRIVE_SWEEP"):
		var session: Dictionary = controller.current_session
		print("[leave] %s blocked reason=%s node=%s type=%s stance=%s phase=%s offers_fight=%s" % [
			context, str(payload.get("reason", "unknown")),
			str(controller.state.current_node_id), str(controller.current_node.get("type", "")),
			str(session.get("stance", "?")), str(session.get("phase", "?")),
			str(session.get("offers_fight", "?")),
		])
		for card_value in ActionPreviewServiceScript.preview_actions(
				controller.state, controller.current_node, controller.catalog):
			var card: Dictionary = card_value
			print("[leave]   card %s executable=%s cost=%s" % [
				str(card.get("id", "")), str(card.get("executable", false)), str(card.get("cost", {}))])
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
		if OS.has_environment("DRIVE_SWEEP") and not bool(payload.get("ok", false)):
			print("[card] %s rejected: %s" % [str(card.get("id", "")), str(payload.get("reason", payload))])
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
	if _mandatory_fight_pending(controller):
		return _fight_via_preview(controller)
	return _leave(controller, "商店")


func _step_battle(controller, trace: Dictionary) -> String:
	var battle: Dictionary = controller.current_battle
	var living := _living(battle)
	var enemy_hp := _hp_total(living)
	var intent_damage := _intent_damage(living)
	var player: Dictionary = battle["player"]
	var hp := int(player.get("hp", 0))
	var max_hp := maxi(1, int(player.get("max_hp", 1)))
	var shield := int(player.get("shield", 0))
	var turn := int(battle.get("turn", 0))
	if OS.has_environment("DRIVE_SWEEP") and turn > 0 and turn % 50 == 0:
		var slot_texts: Array[String] = []
		for i in (battle.get("gu_slots", []) as Array).size():
			var slot: Dictionary = battle["gu_slots"][i]
			slot_texts.append("%s(%s%s%s)" % [
				str(slot.get("instance_id", "?")),
				str(slot["effect"].get("kind", "?")),
				"/sealed" if bool(slot.get("is_sealed", false)) else "",
				"/used" if bool(slot.get("used_this_turn", false)) else "",
			])
		var enemy_texts: Array[String] = []
		for enemy_value in battle.get("enemies", []):
			var enemy: Dictionary = enemy_value
			enemy_texts.append("%s hp%d sh%d intent%s" % [
				str(enemy.get("id", "?")), int(enemy.get("hp", 0)),
				int(enemy.get("shield", 0)), str(enemy.get("intent", {}))])
		print("[battle] t%d hp%d sh%d thoughts%d qi%d soul%d ap? slots:%s enemies:%s log:%s" % [
			turn, hp, shield, int(player.get("thoughts", -1)), int(player.get("true_qi", -1)),
			int(player.get("soul", -1)), ",".join(slot_texts), ",".join(enemy_texts),
			str((battle.get("log", []) as Array).slice(maxi(0, (battle.get("log", []) as Array).size() - 3))),
		])
	var guarded := shield > 0
	var can_flee := not BattleCommandFacadeScript.boss_blocks_retreat(battle)
	var attack_id := _pick_effect_gu(battle, ["strike", "heal_and_strike"])
	var heal_id := _pick_effect_gu(battle, ["heal", "heal_and_strike"])
	var guard_id := _pick_effect_gu(battle, ["shield", "buff"])
	var command: Dictionary
	var lethal := intent_damage > 0 and hp <= intent_damage
	var finish_now := enemy_hp <= 1
	var stalled := _no_progress(str(controller.state.current_node_id), enemy_hp)
	_record_battle_turn(controller, trace, battle, hp, shield, intent_damage)
	# 集火：优先击杀当前血量最低的敌人，最快削减敌方总出手。
	var focus := _focus_target(battle)
	var low_hp_heal := hp * 10 <= max_hp * 5 and not heal_id.is_empty()
	if finish_now and not attack_id.is_empty():
		command = _gu_command(controller, attack_id, focus)
	elif can_flee and (hp <= 1 or lethal or stalled):
		command = _turn_command(controller, "retreat")
	elif not can_flee:
		var danger := hp <= intent_damage * 2
		var kill_window := enemy_hp <= 4
		var grind := _stuck_count >= 6
		if not attack_id.is_empty() and (not danger or kill_window or guarded or _stuck_count >= 4):
			command = _gu_command(controller, attack_id, focus)
		elif grind:
			# 输出蛊全被转数门禁/费用挡住时，用基础攻击磨血，避免无限叠盾空转。
			command = _turn_command(controller, "basic_attack")
		elif danger and not guarded and not guard_id.is_empty():
			command = _gu_command(controller, guard_id, focus)
		elif low_hp_heal:
			command = _gu_command(controller, heal_id, focus)
		elif not guard_id.is_empty():
			command = _gu_command(controller, guard_id, focus)
		else:
			command = _turn_command(controller, "basic_attack")
	else:
		if intent_damage >= 2 and not guarded and not guard_id.is_empty():
			command = _gu_command(controller, guard_id, focus)
		elif low_hp_heal:
			command = _gu_command(controller, heal_id, focus)
		elif not attack_id.is_empty():
			command = _gu_command(controller, attack_id, focus)
		elif not heal_id.is_empty() and hp < max_hp:
			command = _gu_command(controller, heal_id, focus)
		else:
			command = _turn_command(controller, "end_turn")
	var event_count: int = controller.state.event_log.size()
	var result: Dictionary = controller.submit_command(command)
	_cmd_trace.append("%s/%s" % [
		str(command.get("type", "")),
		str(command.get("instance_id", "")),
	])
	if _cmd_trace.size() > 5:
		_cmd_trace.pop_front()
	if bool(result.get("finished", false)):
		return "ongoing"
	if not bool(result.get("accepted", false)):
		_last_reject_reason = str(result.get("reason", result.get("feeds", ["?"])))
		var punched: Dictionary = controller.submit_command(
			_turn_command(controller, "basic_attack")
		)
		if not bool(punched.get("accepted", false)) and not bool(punched.get("finished", false)):
			controller.submit_command(_turn_command(controller, "end_turn"))
	elif controller.state.event_log.size() == event_count:
		_last_reject_reason = "accepted_without_event"
	return "ongoing"


func _record_battle_turn(controller, trace: Dictionary, battle: Dictionary, hp: int, shield: int, intent_damage: int) -> void:
	# 逐回合采样：进入战斗第一帧记 Boss 战前数据；同场战斗内 turn 变化即
	# 上一回合收口（净伤害=上回合起始 hp − 本回合起始 hp，负值即净回复）。
	var node_id := str(controller.state.current_node_id)
	# Boss 台识别走模板：实例 id 由 instance_id_for 生成，不带模板前缀。
	var boss_template := str(controller.current_node.get("template_id", ""))
	var is_boss := boss_template.begins_with("layer_boss_stand") or boss_template == "final_boss_stand"
	var turn := int(battle.get("turn", 0))
	if node_id != _rec_node:
		_rec_node = node_id
		_rec_turn = turn
		_rec_is_boss = is_boss
		_rec_hp = hp
		_rec_shield = shield
		_rec_intent = intent_damage
		trace["battles"] = int(trace.get("battles", 0)) + 1
		if is_boss:
			var enemy_texts: Array[String] = []
			for enemy_value in battle.get("enemies", []):
				var enemy: Dictionary = enemy_value
				enemy_texts.append("%s:%d" % [str(enemy.get("id", "?")), int(enemy.get("hp", 0))])
			(trace["boss_pre_states"] as Array).append("pre@%s hp%d/%d sh%d intent%d ess%d gu%d rank%s enemy:%s" % [
				node_id, hp, int(battle["player"].get("max_hp", 0)), shield, intent_damage,
				int(controller.state.essence_capacity),
				(controller.state.gu_instances as Dictionary).size(),
				str(controller.state.cultivator.get("rank", 1)),
				",".join(enemy_texts),
			])
	elif turn != _rec_turn:
		if turn > 100 and _rec_turn <= 100:
			if not trace.has("runaways"):
				trace["runaways"] = []
			(trace["runaways"] as Array).append(node_id)
		if _rec_is_boss:
			var turns: Array = trace["battle_turns"]
			turns.append("t%d@%s hp%d sh%d intent%d net%d" % [
				_rec_turn, node_id, _rec_hp, _rec_shield, _rec_intent, _rec_hp - hp,
			])
			if turns.size() > 80:
				turns.pop_front()
		_rec_turn = turn
	_rec_hp = hp
	_rec_shield = shield
	_rec_intent = intent_damage


func _no_progress(battle_id: String, enemy_hp: int) -> bool:
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


func _living(battle: Dictionary) -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)):
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
		total += maxi(0, int(enemy["intent"].get("damage", 0)))
	return total


func _pick_effect_gu(battle: Dictionary, kinds: Array) -> String:
	var slots: Array = battle.get("gu_slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) or bool(slot.get("used_this_turn", false)):
			continue
		if str(slot["effect"].get("kind", "")) not in kinds:
			continue
		if V1BattleResolverScript.can_play_gu(battle, i) != "":
			continue
		return str(slot.get("instance_id", ""))
	return ""


func _gu_command(controller, instance_id: String, target_id: String) -> Dictionary:
	return {
		"type": "use_gu",
		"instance_id": instance_id,
		"target_id": target_id,
		"state_version": controller.state.event_log.size(),
	}


func _focus_target(battle: Dictionary) -> String:
	var best := ""
	var best_hp := 2147483647
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)):
			continue
		var hp := int(enemy.get("hp", 0))
		if hp < best_hp:
			best_hp = hp
			best = str(enemy.get("id", ""))
	return best


func _turn_command(controller, command_type: String) -> Dictionary:
	return {
		"type": command_type,
		"state_version": controller.state.event_log.size(),
	}
