class_name EncounterSessionResolver
extends RefCounted


const ResultFeedScript = preload("res://scripts/domain/result_feed.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const CommandSpecRegistryScript = preload("res://scripts/domain/command_spec_registry.gd")


static func start(node: Dictionary) -> Dictionary:
	return {
		"node_id": str(node.get("id", "")),
		"kind": str(node.get("type", "")),
		"phase": "active",
		"completed": false,
		"completion_reason": "",
		"flags": {},
		# 血仇（extreme_hostile）门禁只对有 fight 动作的节点生效：商队有
		# 专门的 node.fight 卡（choice 表里没有），其余节点以 choices 为准。
		"offers_fight": bool("fight" in (node.get("choices", []) as Array)) \
				or str(node.get("type", "")) == "caravan",
	}


static func begin(state: RunState, node: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	var session := start(node)
	var feed := ResultFeedScript.entry("enter_node", "node_entered", {}, [])
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var notorious := Resolver.notoriety(state)
	var hostile_pct := int(effects.get("hostile_chance_pct_per_point", 15)) * notorious
	var extreme_pct := mini(30, int(effects.get("extreme_stance_pct_per_point", 5)) * notorious)
	var stance := "neutral"
	if extreme_pct > 0 and Resolver.roll_chance(state, extreme_pct, "reputation_extreme"):
		stance = "extreme_hostile"
		session["flags"]["reputation_extreme"] = true
		feed = ResultFeedScript.entry("enter_node", "reputation_extreme_stance", {}, [])
	elif hostile_pct > 0 and Resolver.roll_chance(state, hostile_pct, "reputation_hostile"):
		stance = "hostile"
		session["flags"]["reputation_hostile"] = true
		feed = ResultFeedScript.entry("enter_node", "reputation_hostile_stance", {}, [])
	session["stance"] = stance
	# M5 anti-farming: every market/shop visit is counted, later visits pay more.
	var shop_visits := int(state.node_flags.get("shop_visits", 0))
	if str(node.get("type", "")) in ["shop", "market"]:
		shop_visits += 1
	var node_flags := state.node_flags.duplicate(true)
	node_flags["shop_visits"] = shop_visits
	var next := _record_session_state(state, session, feed, "encounter_started", true, node_flags)
	next.node_flags = node_flags
	return {"state": next, "session": session, "feed": feed, "result": {"ok": true}}


static func apply(state: RunState, session: Dictionary, command: Dictionary, catalog: Dictionary, node: Dictionary = {}) -> Dictionary:
	if bool(session.get("completed", false)):
		return _rejected(state, session, "session_completed")
	if str(command.get("type", "")) == "action_card":
		return _apply_action_card(state, session, node, command, catalog)
	if str(command.get("type", "")) == "leave_node":
		return _leave(state, session, catalog)
	var resolved := Resolver.apply(state, command, catalog)
	var next_session := session.duplicate(true)
	if not bool(resolved["result"].get("ok", false)):
		var acting := str(command.get("action_id", str(command.get("type", "action"))))
		var stance := str(next_session.get("stance", "neutral"))
		if acting in ["deceive", "trade"] and stance == "neutral" and _flip_hostile_roll(state, catalog, next_session):
			next_session["stance"] = "hostile"
			next_session["flags"]["reputation_hostile"] = true
			resolved["result"]["flipped_hostile"] = true
	var feed := _feed_for(command, state, resolved["state"], resolved["result"])
	var next := _record_session_state(resolved["state"], next_session, feed, "encounter_action")
	return {
		"state": next,
		"session": next_session,
		"feed": feed,
		"result": _with_resolution(resolved["result"], state, next, node, catalog),
	}


static func _flip_hostile_roll(state: RunState, catalog: Dictionary, session: Dictionary) -> bool:
	var effects: Dictionary = catalog.get("reputation", {}).get("effects", {})
	var pct := int(effects.get("flip_hostile_chance_pct", 0))
	if pct <= 0:
		return false
	return Resolver.roll_chance(state, pct, "npc_flip_%s" % str(session.get("node_id", "node")))


static func _apply_action_card(
	state: RunState,
	session: Dictionary,
	node: Dictionary,
	command: Dictionary,
	catalog: Dictionary
) -> Dictionary:
	if node.is_empty():
		return _card_rejected(state, session, node, catalog, "missing_action_node")
	var preflight: Dictionary = CommandSpecRegistryScript.preflight("encounter.action_card", state, {}, session, command, catalog, node)
	if not bool(preflight.get("ok", false)):
		return _card_rejected(state, session, node, catalog, str(preflight.get("reason", "action_preview_stale")))
	var card := ActionPreviewServiceScript.find_card(state, node, str(command.get("action_id", "")), catalog)
	if card.is_empty():
		return _card_rejected(state, session, node, catalog, "unknown_action_card")
	if not bool(card.get("executable", false)):
		return _card_rejected(state, session, node, catalog, "action_not_executable")
	# Consume the card so the same action cannot be re-triggered in this session.
	var next_session := session.duplicate(true)
	var used: Array = next_session.get("used_action_ids", [])
	if not used.has(str(card["id"])):
		used.append(str(card["id"]))
	next_session["used_action_ids"] = used
	# Never accept a command object from the UI. Recompute and execute the current card only.
	return apply(state, next_session, card["command"], catalog, node)


static func _card_rejected(state: RunState, session: Dictionary, node: Dictionary, catalog: Dictionary, reason: String) -> Dictionary:
	var rejected := _rejected(state, session, reason)
	rejected["result"] = _with_resolution(rejected["result"], state, state, node, catalog)
	return rejected


static func _leave(state: RunState, session: Dictionary, catalog: Dictionary) -> Dictionary:
	# R8.1 hard choice mirrors Resolver._travel: walking out of a rest node
	# without consuming the visit is refused and the session stays open so the
	# player can still pick heal/upgrade/one of the removals.
	if _rest_choice_pending(state, session, catalog):
		return _rejected(state, session, "rest_choice_required")
	# 血仇只在节点确有战斗且战斗未决时阻止离场。无战斗节点和战后阶段
	# 都必须放行，否则会把玩家锁在当前节点。
	if str(session.get("stance", "neutral")) == "extreme_hostile" \
			and bool(session.get("offers_fight", false)) \
			and str(session.get("phase", "active")) != "post_battle":
		return _rejected(state, session, "feud_no_escape")
	var completed := Resolver.apply(state, {
		"type": "complete_node",
		"node_id": session["node_id"],
		"outcome": "abandoned",
	}, catalog)
	if not bool(completed["result"].get("ok", false)):
		return _rejected(state, session, str(completed["result"].get("reason", "cannot_leave_node")))
	var left_state: RunState = completed["state"]
	if left_state.known_facts.has("caravan_favor_debt"):
		var gains: Dictionary = catalog.get("reputation", {}).get("gains", {})
		left_state = Resolver.gain_notoriety(left_state, int(gains.get("broken_trust", 1)), "broken_trust")
	var next_session := session.duplicate(true)
	next_session["completed"] = true
	next_session["completion_reason"] = "player_left"
	var feed := ResultFeedScript.entry("leave_node", "node_left", {}, [])
	# 修复 3：带伤离场（气血不满）记入近期败势（DDA 战斗摘要窗口消费该 reason）。
	var leave_reason := "encounter_left_wounded" if left_state.health < left_state.max_health else "encounter_left"
	var next := _record_session_state(left_state, next_session, feed, leave_reason)
	return {
		"state": next,
		"session": next_session,
		"feed": feed,
		"result": _with_resolution({"ok": true}, state, next, {}, catalog),
	}


static func _rest_choice_pending(state: RunState, session: Dictionary, catalog: Dictionary) -> bool:
	var node_id := str(session.get("node_id", ""))
	var template_id := str(state.current_node_template_id)
	# E3a 三选一（规格 §4）：硬门禁统一覆盖休息类（rest/refinement/cultivation），
	# 与 Resolver._travel 同口径——未消费探访不许离开，会话保持开放供三族选择。
	if not Resolver._is_rest_class_node(catalog, node_id) and not Resolver._is_rest_class_node(catalog, template_id):
		return false
	return str(state.node_flags.get("%s_used" % node_id, "")) != "used"


static func _record_session_state(
	state: RunState,
	session: Dictionary,
	feed: Dictionary,
	reason: String,
	replace_results: bool = false,
	node_flags: Dictionary = {}
) -> RunState:
	var feeds: Array[Dictionary] = []
	if not replace_results:
		for existing_feed in state.encounter_results:
			feeds.append(existing_feed.duplicate(true))
	feeds.append(feed.duplicate(true))
	var after := {"encounter_session": session, "encounter_results": feeds}
	if not node_flags.is_empty():
		after["node_flags"] = node_flags
	return state.append_event({
		"stage": state.stage,
		"time": state.event_log.size(),
		"node_id": session["node_id"],
		"action": "encounter_session",
		"before": {},
		"after": after,
		"reason": reason,
		"source": "encounter_session_resolver",
		"targets": [],
	})


static func _feed_for(command: Dictionary, before: RunState, after: RunState, result: Dictionary) -> Dictionary:
	var action := str(command.get("approach", command.get("action_id", command.get("type", "action"))))
	if not bool(result.get("ok", false)):
		if bool(result.get("flipped_hostile", false)):
			return ResultFeedScript.entry(action, "stance_flipped_hostile", {}, [])
		return ResultFeedScript.entry(action, "action_rejected", {}, [])
	var changes := {}
	if after.stone != before.stone:
		changes["stone"] = after.stone - before.stone
	if after.essence != before.essence:
		changes["essence"] = after.essence - before.essence
	var facts: Array[String] = []
	for fact in after.known_facts:
		if not before.known_facts.has(fact):
			facts.append(fact)
	return ResultFeedScript.entry(action, _text_key_for(action), changes, facts)


static func _with_resolution(result: Dictionary, before: RunState, after: RunState, node: Dictionary, catalog: Dictionary) -> Dictionary:
	var resolution := result.duplicate(true)
	resolution["actual_changes"] = _actual_changes(before, after)
	resolution["next_available_actions"] = ActionPreviewServiceScript.preview_actions(after, node, catalog) if not node.is_empty() else []
	resolution["state_version"] = after.event_log.size()
	return resolution


static func _actual_changes(before: RunState, after: RunState) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	_append_numeric_change(changes, "stone", before.stone, after.stone, "元石")
	_append_numeric_change(changes, "spirit", before.essence, after.essence, "真元")
	_append_numeric_change(changes, "hp", before.health, after.health, "气血")
	var lifespan_before := int(before.cultivator.get("lifespan", 0))
	var lifespan_after := int(after.cultivator.get("lifespan", 0))
	if lifespan_before != lifespan_after:
		changes.append({
			"type": "lifespan",
			"before": lifespan_before,
			"delta": lifespan_after - lifespan_before,
			"message": "寿元%s %d。" % ["增加" if lifespan_after > lifespan_before else "减少", abs(lifespan_after - lifespan_before)],
		})
	var soul_before := int(before.cultivator.get("soul", 0))
	var soul_after := int(after.cultivator.get("soul", 0))
	if soul_before != soul_after:
		changes.append({
			"type": "soul",
			"before": soul_before,
			"delta": soul_after - soul_before,
			"message": "魂魄%s %d。" % ["增强" if soul_after > soul_before else "受损", abs(soul_after - soul_before)],
		})
	for gu_id in after.refined_gu_ids:
		if not before.refined_gu_ids.has(gu_id):
			changes.append({"type": "gu_gained", "after": gu_id, "message": "获得蛊虫：%s。" % DisplayText.gu(gu_id)})
	for gu_id in before.refined_gu_ids:
		if not after.refined_gu_ids.has(gu_id):
			changes.append({"type": "gu_lost", "before": gu_id, "message": "失去蛊虫：%s。" % DisplayText.gu(gu_id)})
	for fact in after.known_facts:
		if not before.known_facts.has(fact):
			changes.append({"type": "intel", "after": fact, "message": "获得新情报。"})
	return changes


static func _append_numeric_change(changes: Array[Dictionary], change_type: String, before: int, after: int, label: String) -> void:
	if before == after:
		return
	changes.append({
		"type": change_type,
		"before": before,
		"delta": after - before,
		"message": "%s%s %d。" % [label, "增加" if after > before else "减少", abs(after - before)],
	})


static func _text_key_for(action: String) -> String:
	match action:
		"deceive": return "contact_deceive_success"
		"negotiate": return "contact_negotiate_result"
		"fight": return "contact_fight_started"
		"buy_gu": return "caravan_buy_result"
		"sell_gu": return "caravan_sell_result"
		"exchange_gu": return "caravan_exchange_result"
		"refine_gu": return "refinement_result"
		"cultivate_rank_two": return "cultivation_result"
	return "action_result"


static func _rejected(state: RunState, session: Dictionary, reason: String) -> Dictionary:
	return {
		"state": state,
		"session": session.duplicate(true),
		"feed": ResultFeedScript.entry("action", "action_rejected", {}, []),
		"result": {"ok": false, "reason": reason},
	}
