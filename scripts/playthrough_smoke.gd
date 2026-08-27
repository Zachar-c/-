extends SceneTree

# 玩家视角游玩冒烟（playthrough smoke）：无头驱动一整局真实游玩回路——
# 大厅开局契约 → 地图逐节点推进（商队/黑市/险地/休整/炼蛊/遭遇）→
# 战斗（手牌卡/普攻）→ 飞升/死亡落账 → 汇总打印。全程只经
# RunController.submit_command 真实领域通道，无内联捷径。
# 用法：& .\tools\godot.ps1 --headless --path . -s res://scripts/playthrough_smoke.gd

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")


var _log: Array[String] = []
var _last_view := ""
# 止损检测：同一战斗内敌血持续无变化则认定打不动，尝试撤离。
var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1


func _initialize() -> void:
	var controller := RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	# 发散试玩参数：PLAYTHROUGH_SEED / PLAYTHROUGH_CONTRACTS（逗号分隔，空=无契约）。
	var seed_env := OS.get_environment("PLAYTHROUGH_SEED")
	var seed_value := int(seed_env) if not seed_env.is_empty() else 20260927
	var contract_env := OS.get_environment("PLAYTHROUGH_CONTRACTS")
	var contracts: Array[String] = []
	if not contract_env.is_empty():
		for piece in contract_env.split(",", false):
			contracts.append(piece.strip_edges())
	# 玩家真实开局路径：大厅选中契约后开新局（controller 内部执行 swearing）。
	controller.start_new_run(seed_value, "", contracts)
	_tell("开局 seed=%d | 起点=%s | 元石=%d | 气血=%d/%d | 魂魄=%d | 契约=%s" % [
		seed_value, controller.state.current_node_id,
		int(controller.state.stone), int(controller.state.health),
		int(controller.state.max_health), int(controller.state.cultivator.get("soul", 0)),
		str(controller.state.contracts),
	])

	var steps := 0
	var outcome := "ongoing"
	while steps < 400 and outcome == "ongoing":
		steps += 1
		outcome = _step(controller)
		if controller.state != null and controller.state.is_terminal():
			outcome = "terminal"
	_tell("-- 游玩结束 --")
	_tell("总步数: %d | 结局: %s" % [steps, outcome])
	_tell("终局状态: 节点=%s | 元石=%d | 气血=%d/%d | 蛊=%d | 契约=%s | 图鉴=%d | 事件=%d" % [
		controller.state.current_node_id, int(controller.state.stone),
		int(controller.state.health), int(controller.state.max_health),
		(controller.state.gu_instances as Dictionary).size(),
		str(controller.state.contracts), (controller.state.global_codex_ids as Array).size(),
		(controller.state.event_log as Array).size(),
	])
	var dda_triggers := 0
	for event in controller.state.event_log:
		if str(event.get("action", "")) == "dda_marker":
			dda_triggers += 1
	_tell("DDA 标记触发: %d 次" % dda_triggers)
	_tell("中途进程: %s" % ["失败(无进展)" if steps >= 400 else "正常"])
	controller.free()
	quit(0)


func _step(controller) -> String:
	var view: String = controller.current_view_name()
	if view == "Battle" and _last_view != "Battle":
		_tell("开战于 %s（%s）" % [
			controller.state.current_node_id,
			str(controller.current_node.get("enemy_kind", "")),
		])
	_last_view = view
	match view:
		"Map":
			return _step_map(controller)
		"Shop":
			return _step_shop(controller)
		"Encounter":
			return _step_encounter(controller)
		"Rest":
			return _step_via_cards(controller, "休整")
		"Refine":
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Reward":
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Npc":
			controller.submit_command({"type": "leave_node"})
			return "ongoing"
		"Battle":
			return _step_battle(controller)
		"Ending", "Title", "Hall", "Settings", "Codex", "Journal":
			return str(view).to_lower()
		_:
			_tell("未知视口 %s：尝试离开" % view)
			controller.submit_command({"type": "leave_node"})
			return "ongoing"


func _step_via_cards(controller, label: String) -> String:
	# 通用节点策略：按官方动作预览逐张消费可执行卡（含休整双选/地脉探查），
	# 全部处置完或只剩离场时离开。硬编码单一动作会撞 R8.1 rest_choice 门禁。
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(
		controller.state, controller.current_node, controller.catalog)
	var acted := false
	for card in cards:
		var card_id := str(card.get("id", ""))
		if not bool(card.get("executable", false)):
			continue
		if str(card_id) == "node.leave":
			continue
		var command: Dictionary = card.get("command", {})
		if command.is_empty():
			continue
		command = command.duplicate(true)
		command["type"] = "action_card"
		command["action_id"] = card_id
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		# 会话路径返回 {state, session, feed, result}：ok 在内层 result 里。
		var payload: Dictionary = result.get("result", result) as Dictionary
		var battle_started: bool = bool(payload.get("start_battle", false)) \
			or controller.current_view_name() == "Battle"
		if battle_started or bool(payload.get("ok", false)):
			_tell("%s：执行 %s" % [label, card_id])
			acted = true
		else:
			_tell("%s：%s 被拒（%s）" % [label, card_id, str(payload.get("reason", "unknown"))])
		break
	if not acted:
		controller.submit_command({"type": "leave_node"})
		_tell("%s：已无可用动作，离场" % label)
	return "ongoing"


func _step_map(controller) -> String:
	var visible: Array = controller.visible_route_nodes(2)
	var visited: Dictionary = controller.state.node_flags
	# 候选顺序：Boss 未除时 final_boss_stand 最优先（升仙门槛前置），
	# 其余按可见序。可见 ≠ 可达，逐个尝试直到成功。
	var candidates: Array[Dictionary] = []
	if str(visited.get("boss_defeated", "")) != "true":
		for node in visible:
			if not visited.has(str(node.get("id", ""))) and str(node.get("id", "")) == "final_boss_stand":
				candidates.append(node)
	for node in visible:
		var node_id := str(node.get("id", ""))
		if visited.has(node_id):
			continue
		var already := false
		for candidate in candidates:
			if str(candidate.get("id", "")) == node_id:
				already = true
				break
		if not already:
			candidates.append(node)
	for target in candidates:
		var node_id := str(target.get("id", ""))
		var result: Dictionary = controller.submit_command({"type": "travel", "node_id": node_id})
		if bool(result.get("ok", false)):
			_tell("行至 %s (%s)：元石=%d 气血=%d" % [
				node_id, str(target.get("type", "")),
				int(controller.state.stone), int(controller.state.health),
			])
			return "ongoing"
		_tell("行至被拒 %s：%s" % [node_id, str(result.get("reason", "unknown"))])
	_tell("地图无新节点可走（路线尽头）")
	return "no_route"


func _step_shop(controller) -> String:
	# 玩家视角：按货架买一件买得起且未持有的货，然后离店。
	var node_type := str(controller.current_node.get("type", ""))
	var state = controller.state
	if node_type == "caravan":
		for offer_value in controller.catalog.get("caravan_offer_by_id", {}).values():
			var offer: Dictionary = offer_value
			var gid := str(offer.get("gu_id", ""))
			if state.gu_instances.values().any(func(inst): return str(inst.get("definition_id", "")) == gid):
				continue
			var price := int(offer.get("stone_cost", 0))
			if int(state.stone) >= price:
				var bought: Dictionary = controller.submit_command({"type": "buy_gu", "offer_id": str(offer.get("id", ""))})
				if bool(bought.get("ok", false)):
					_tell("商队购入 %s（%d 元石）" % [gid, price])
					break
		controller.submit_command({"type": "leave_node"})
		return "ongoing"
	for offer_value in controller.catalog.get("shop_offer_by_id", {}).values():
		var offer: Dictionary = offer_value
		if str(offer.get("kind", "")) != "purchase":
			continue
		var gid := str(offer.get("gu_id", ""))
		if state.gu_instances.values().any(func(inst): return str(inst.get("definition_id", "")) == gid):
			continue
		var price := int(offer.get("stone_cost", 0))
		if int(state.stone) >= price:
			var bought: Dictionary = controller.submit_command({"type": "shop_purchase", "offer_id": str(offer.get("id", ""))})
			if bool(bought.get("ok", false)):
				_tell("黑市购入 %s（%d 元石）" % [gid, price])
				break
	controller.submit_command({"type": "leave_node"})
	return "ongoing"


func _step_encounter(controller) -> String:
	var node: Dictionary = controller.current_node
	var node_type := str(node.get("type", ""))
	# 战后阶段：胜利后结算再离场（玩家视角的战后处理）。
	if str(controller.current_session.get("phase", "")) == "post_battle":
		controller.submit_command({"type": "leave_node"})
		_tell("战后结算完成，离场")
		return "ongoing"
	# 升仙窗：玩家终局抉择（需先击败 Boss，choice=now 是真实命令契约）。
	if node_type == "ascension":
		var ascended: Dictionary = controller.submit_command({"type": "attempt_ascension", "choice": "now"})
		var outcome := str(ascended.get("outcome", ""))
		if outcome.is_empty():
			var nested: Dictionary = ascended.get("result", {})
			outcome = str(ascended.get("reason", nested.get("reason", "")))
		_tell("尝试飞升：%s" % outcome if not outcome.is_empty() else "尝试飞升：未知响应")
		if controller.current_view_name() == "Ending":
			return "ending"
		_tell("飞升未成（%s），本次旅途结束" % outcome)
		return "retreat_end"
	# 总账：先结清养蛊开支（玩家必做项）。
	if node_type == "ledger":
		var settled: Dictionary = controller.submit_command({"type": "settle_feeding"})
		if not bool(settled.get("ok", false)):
			controller.submit_command({"type": "choose_action", "action_id": "accept_debt"})
		_tell("总账结清：元石=%d" % int(controller.state.stone))
		controller.submit_command({"type": "leave_node"})
		return "ongoing"
	if node_type == "event":
		var choices: Array = node.get("choices", [])
		if not choices.is_empty():
			var taken: Dictionary = controller.submit_command({"type": "choose_action", "action_id": str(choices[0])})
			_tell("事件选项 %s: %s" % [str(choices[0]), "接受" if bool(taken.get("ok", false)) else "被拒(%s)" % str(taken.get("reason", ""))])
		controller.submit_command({"type": "leave_node"})
		return "ongoing"
	# 其余节点（险地/传承/野蛊/地脉/闭关等）：按预览卡逐张处置后离场。
	return _step_via_cards(controller, "遭遇")


func _step_battle(controller) -> String:
	var battle: Dictionary = controller.current_battle
	if bool(battle.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(battle.get("result", "unknown")),
			int(controller.state.health), int(controller.state.max_health),
		])
		return "ongoing"
	var battle_id := str(battle.get("battle_id", ""))
	var enemy_hp := int(battle.get("enemy_hp", -1))
	if battle_id != _stuck_battle_id:
		_stuck_battle_id = battle_id
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	elif enemy_hp == _stuck_enemy_hp:
		_stuck_count += 1
	else:
		_stuck_count = 0
		_stuck_enemy_hp = enemy_hp
	var intent: Dictionary = battle.get("visible_intent", {}) as Dictionary
	var intent_damage := int(intent.get("damage", 0))
	var hand: Array = battle.get("hand", [])
	var command: Dictionary
	if int(controller.state.health) <= 2 or _stuck_count >= 4:
		# 玩家止损：残血或长期打不动敌血就抽身；地形禁撤时只能死战。
		command = {"type": "retreat"}
	elif intent_damage > 0 and int(controller.state.health) <= intent_damage:
		# 敌方下一口能咬死人时优先闪避保命。
		command = {"type": "basic_dodge"}
	else:
		if hand.is_empty():
			# 手牌打空必须收势：不结束回合就永远抽不到下一张牌（曾致 400 步假死锁）。
			command = {"type": "end_turn"}
		else:
			var card: Dictionary = hand[0]
			command = {
				"type": "action_card",
				"action_id": "battle.%s.%s" % [str(battle.get("battle_id", "")), str(card.get("instance_id", ""))],
				"state_version": int(battle.get("hand_version", 0)),
			}
	var result: Dictionary = controller.submit_command(command)
	if bool(result.get("finished", false)):
		_tell("战斗结束：%s（我方气血 %d/%d）" % [
			str(result.get("result", "unknown")),
			int(controller.state.health), int(controller.state.max_health),
		])
		if str(result.get("result", "")) == "retreat":
			controller.submit_command({"type": "leave_node"})
			_tell("止损撤离，离开该节点")
		return "ongoing"
	if not bool(result.get("accepted", false)):
		command = {"type": "basic_attack"}
		result = controller.submit_command(command)
		if not bool(result.get("accepted", false)):
			var fallback: Dictionary = controller.submit_command({"type": "end_turn"})
			if not bool(fallback.get("accepted", false)):
				_tell("战斗阻塞：%s" % str(result.get("feeds", result)))
	return "ongoing"


func _tell(text: String) -> void:
	_log.append(text)
	print("[play] %s" % text)