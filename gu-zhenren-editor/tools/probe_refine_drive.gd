extends SceneTree
## 探针 v2：复刻 acceptance_driver play 驱动（保守战斗策略），
## 在 rest/refinement 节点打印 stance 与卡片 executable，验证血仇过滤是否波及服务类节点。
## 用法：godot --headless --path . -s tools/probe_refine_drive.gd

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const ActionPreviewServiceScript = preload("res://scripts/domain/action_preview_service.gd")
const ContentCatalog = preload("res://scripts/domain/content_catalog.gd")
const V1BattleResolverScript = preload("res://scripts/domain/v1_battle_resolver.gd")

var controller = null
var _stuck_battle_id := ""
var _stuck_count := 0
var _stuck_enemy_hp := -1


func _initialize() -> void:
	controller = RunControllerScript.new()
	controller.catalog = ContentCatalog.load_all()
	controller.catalog["pacing"]["ending_after_stage"] = "five"
	controller.start_new_run(20260927, "sword", [])
	var steps := 0
	var last_event_count := -1
	while steps < 2000:
		steps += 1
		if controller.state == null or controller.state.is_terminal():
			break
		var view := str(controller.current_view_name())
		if view == "Ending":
			break
		_step(view)
		var event_count: int = controller.state.event_log.size()
		if event_count == last_event_count:
			if steps > 100 and view == "Map":
				print("PROBE_STALL_MAP at step", steps)
				break
		else:
			last_event_count = event_count
	print("PROBE_DONE steps=%d node=%s terminal=%s" % [steps, str(controller.state.current_node_id), str(controller.state.is_terminal())])
	quit(0)


func _step(view: String) -> void:
	if view == "Map":
		_step_map()
	elif view == "Battle":
		_step_battle()
	elif view in ["Rest", "Refine"]:
		var ntype := str(controller.current_node.get("type", ""))
		if ntype in ["rest", "refinement", "cultivation"]:
			_probe_service_node()
		_step_service()
	elif view in ["Shop", "Caravan"]:
		_step_shop()
	elif view in ["Encounter", "Reward", "Npc"]:
		_step_encounter()
	else:
		controller.submit_command({"type": "leave_node"})


func _probe_service_node() -> void:
	var session: Dictionary = controller.state.encounter_session
	var stance := str(session.get("stance", "neutral"))
	var ntype := str(controller.current_node.get("type", ""))
	var notorious := _notoriety()
	var used_flag := str(controller.state.node_flags.get("%s_used" % str(controller.state.current_node_id), ""))
	if used_flag == "used":
		return
	print("PROBE %s@%s stance=%s notoriety=%d hp=%d/%d" % [
		ntype, str(controller.state.current_node_id), stance, notorious,
		int(controller.state.health), int(controller.state.max_health)])
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, controller.catalog)
	for card in cards:
		print("  CARD %s exec=%s block=%s cmd=%s" % [
			str(card.get("id", "")), str(card.get("executable", false)),
			str(card.get("block_reason", "")), str(card.get("command", {}))])


func _notoriety() -> int:
	# 与 Resolver.notoriety 同口径：读取 known_facts 里恶名标记计数
	var count := 0
	for fact in controller.state.known_facts:
		if str(fact).begins_with("notoriety_"):
			count += 1
	return count


func _step_service() -> void:
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, controller.catalog)
	var node_type := str(controller.current_node.get("type", ""))
	var acted := false
	for card in cards:
		var card_id := str(card.get("id", ""))
		if not bool(card.get("executable", false)):
			continue
		if card_id == "node.leave" or card_id == "refine.free_mix":
			continue
		var cost: Dictionary = card.get("cost", {})
		if int(cost.get("stone", 0)) > 0 and node_type != "shop" and node_type != "refinement":
			continue
		var command: Dictionary = card.get("command", {}).duplicate(true)
		if command.is_empty():
			continue
		command["type"] = "action_card"
		command["action_id"] = card_id
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		var payload: Dictionary = result.get("result", result) as Dictionary
		if bool(payload.get("start_battle", false)) or controller.current_view_name() == "Battle" or bool(payload.get("ok", false)):
			acted = true
			break
	if not acted:
		var skipped: Dictionary = controller.submit_command({"type": "rest", "mode": "skip"})
		if not bool(skipped.get("result", skipped).get("ok", false)):
			controller.submit_command({"type": "leave_node"})


func _step_map() -> void:
	if int(controller.state.health) < int(controller.state.max_health):
		for mat_id in ["beast_blood", "beast_bone"]:
			if int(controller.state.materials.get(mat_id, 0)) > 0:
				var eaten: Dictionary = controller.submit_command({"type": "use_material", "material_id": mat_id})
				if bool(eaten.get("result", eaten).get("ok", false)):
					return
	var visible: Array = controller.visible_route_nodes(2)
	var picks: Array[Dictionary] = []
	var boss: Dictionary = {}
	for node_value in visible:
		var node: Dictionary = node_value
		if str(node.get("template_id", "")).begins_with("layer_boss_stand") or str(node.get("id", "")) == "final_boss_stand":
			boss = node
			continue
		if not bool(node.get("reachable", false)):
			continue
		if not controller.state.node_flags.has(str(node.get("id", ""))):
			picks.append(node)
	picks.sort_custom(func(a, b):
		var ra := 0 if str(a.get("type", "")) == "refinement" else 1
		var rb := 0 if str(b.get("type", "")) == "refinement" else 1
		return ra < rb)
	for target in picks:
		var result: Dictionary = controller.submit_command({"type": "travel", "node_id": str(target.get("id", ""))})
		if bool(result.get("ok", false)):
			return
	if not boss.is_empty():
		controller.submit_command({"type": "travel", "node_id": str(boss.get("id", ""))})


func _step_shop() -> void:
	controller.submit_command({"type": "leave_node"})


func _step_encounter() -> void:
	var cards: Array[Dictionary] = ActionPreviewServiceScript.preview_actions(controller.state, controller.current_node, controller.catalog)
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		if str(card.get("id", "")) == "node.leave":
			continue
		var command: Dictionary = card.get("command", {}).duplicate(true)
		if command.is_empty():
			continue
		command["type"] = "action_card"
		command["action_id"] = str(card.get("id", ""))
		command["state_version"] = controller.state.event_log.size()
		var result: Dictionary = controller.submit_command(command)
		var payload: Dictionary = result.get("result", result) as Dictionary
		if bool(payload.get("start_battle", false)) or controller.current_view_name() == "Battle" or bool(payload.get("ok", false)):
			return
		break
	controller.submit_command({"type": "leave_node"})


func _step_battle() -> void:
	# 快速穿层探针：普通战斗一律 retreat；Boss 台锁退则硬打（strike 蛊优先，否则普攻）
	if not _is_boss(controller.current_battle):
		var command: Dictionary = _turn_command(controller, "retreat")
		var result: Dictionary = controller.submit_command(command)
		if not bool(result.get("accepted", false)) and not bool(result.get("finished", false)):
			controller.submit_command(_turn_command(controller, "basic_attack"))
		return
	var battle: Dictionary = controller.current_battle
	var slots: Array = battle.get("gu_slots", [])
	var target := ""
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)):
			target = str(enemy.get("id", ""))
			break
	var used := false
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) or bool(slot.get("used_this_turn", false)):
			continue
		if str(slot["effect"].get("kind", "")) != "strike":
			continue
		if V1BattleResolverScript.can_play_gu(battle, i) != "":
			continue
		var result: Dictionary = controller.submit_command({"type": "use_gu", "instance_id": str(slot.get("instance_id", "")), "target_id": target, "state_version": controller.state.event_log.size()})
		if bool(result.get("accepted", false)) or bool(result.get("finished", false)):
			used = true
		break
	if not used:
		var result: Dictionary = controller.submit_command(_turn_command(controller, "basic_attack"))
		if not bool(result.get("accepted", false)) and not bool(result.get("finished", false)):
			controller.submit_command(_turn_command(controller, "end_turn"))


func _is_boss(battle: Dictionary) -> bool:
	var tpl := str(controller.current_node.get("template_id", ""))
	return tpl.begins_with("layer_boss_stand") or tpl == "final_boss_stand"


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
	return {"type": "use_gu", "instance_id": instance_id, "target_id": target_id, "state_version": controller.state.event_log.size()}


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
	return {"type": command_type, "state_version": controller.state.event_log.size()}
