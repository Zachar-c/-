extends GutTest


# UI 视图流转验收（生成式路线版）：R-seed 裁定废弃固定教学路线后，本测试改为
# 在随机生成图上驱动到第一场普通战斗，验证真实屏幕挂载下的视图流转——
# Battle 快照可出牌 → 普通战斗真实胜利 → 战后回 Map → Map 指令面暴露受保护
# 结局路由（surrender）→ Ending。投降只在显式终局路由覆盖中出现；驱动器只经
# RunController.submit_command 推进，有限 seed 重滚，不得死循环。


const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const ACTION_PREVIEW_SERVICE = preload("res://scripts/domain/action_preview_service.gd")
const BATTLE_COMMAND_FACADE = preload("res://scripts/domain/battle_command_facade.gd")
const V1_BATTLE_RESOLVER = preload("res://scripts/domain/v1_battle_resolver.gd")

const MAX_STEPS := 300
const MAX_SEEDS := 8


func test_generated_run_reaches_ending_through_battle_victory_and_surrender() -> void:
	var reached := false
	for seed_value in [1, 3, 7, 13, 23, 47, 71, 97]:
		var controller: RunController = autofree(RUN_CONTROLLER.new())
		controller.start_new_run(seed_value, "force", [])
		assert_eq(controller.current_view_name(), "Map")
		var outcome := _drive_to_first_ordinary_battle(controller)
		if outcome != "battle":
			controller.free()
			continue
		assert_gt((controller.current_battle.get("enemies", []) as Array).size(), 0,
				"battle snapshot must expose enemies")
		var snapshot: Dictionary = controller._snapshot_for("Battle")
		assert_false((snapshot.get("hand", []) as Array).is_empty(),
				"battle snapshot must expose a hand")
		assert_true(_fight_to_victory(controller),
				"ending route must clear ordinary combat through victory when combat is viable")
		assert_true(_has_battle_victory(controller.state.event_log),
				"ordinary combat must record battle_victory before ending route")
		assert_false(_has_battle_retreat(controller.state.event_log),
				"ordinary combat ending route must not retreat by default")
		var left: Dictionary = controller.submit_command({"type": "leave_encounter"})
		assert_true(bool((left.get("result", left) as Dictionary).get("ok", false)),
				"post-battle encounter must return to map")
		assert_eq(controller.current_view_name(), "Map")
		var map_commands: Dictionary = controller._build_commands("Map")
		assert_true(map_commands.has("surrender"),
				"map command surface must expose the protected ending route")
		map_commands["surrender"].call()
		assert_eq(controller.current_view_name(), "Ending")
		reached = true
		break
	assert_true(reached, "no seed within %d reached an ordinary battle in %d steps" % [MAX_SEEDS, MAX_STEPS])


func test_generated_run_prefers_real_battle_victory_before_reward() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_new_run(1, "force", [])
	var outcome := _drive_to_first_ordinary_battle(controller)
	assert_eq(outcome, "battle")
	var victory := _fight_to_victory(controller)
	assert_true(victory, "normal UI battle path must reach reward through victory, not retreat")
	assert_true(_has_battle_victory(controller.state.event_log),
			"ordinary combat must record battle_victory")
	assert_false(_has_battle_retreat(controller.state.event_log),
			"ordinary combat path must not retreat by default")
	assert_true(controller.current_view_name() in ["Reward", "Encounter"],
			"victory must expose reward or post-battle encounter")


func _fight_to_victory(controller: RunController, max_steps: int = 80) -> bool:
	var steps := 0
	while controller.current_view_name() == "Battle" and steps < max_steps:
		steps += 1
		var battle: Dictionary = controller.current_battle
		var attack_id := _pick_effect_gu(battle, ["strike", "heal_and_strike"])
		var guard_id := _pick_effect_gu(battle, ["shield", "buff"])
		var command: Dictionary
		if not attack_id.is_empty():
			command = {
				"type": "use_gu",
				"instance_id": attack_id,
				"target_id": _living_target_id(battle),
				"state_version": controller.state.event_log.size(),
				"expected_phase": str(controller.current_battle.get("phase", "player_action")),
			}
		elif not guard_id.is_empty():
			command = {
				"type": "use_gu",
				"instance_id": guard_id,
				"target_id": _living_target_id(battle),
				"state_version": controller.state.event_log.size(),
				"expected_phase": str(controller.current_battle.get("phase", "player_action")),
			}
		else:
			command = {"type": "end_turn", "state_version": controller.state.event_log.size(), "expected_phase": str(controller.current_battle.get("phase", "player_action"))}
		var result: Dictionary = controller.submit_command(command)
		if not bool(result.get("accepted", false)) and not bool(result.get("finished", false)):
			controller.submit_command({"type": "end_turn", "state_version": controller.state.event_log.size(), "expected_phase": str(controller.current_battle.get("phase", "player_action"))})
	return controller.current_view_name() in ["Reward", "Encounter"] and _has_battle_victory(controller.state.event_log)


func _pick_effect_gu(battle: Dictionary, kinds: Array) -> String:
	var slots: Array = battle.get("gu_slots", [])
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if bool(slot.get("consumed", false)) or bool(slot.get("is_sealed", false)) or bool(slot.get("used_this_turn", false)):
			continue
		if str(slot.get("effect", {}).get("kind", "")) not in kinds:
			continue
		if V1_BATTLE_RESOLVER.can_play_gu(battle, i) != "":
			continue
		return str(slot.get("instance_id", ""))
	return ""


func _living_target_id(battle: Dictionary) -> String:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)) and int(enemy.get("hp", 0)) > 0:
			return str(enemy.get("id", ""))
	return ""


func _has_battle_victory(events: Array) -> bool:
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("action", "")) == "battle_finished" and str(event.get("reason", "")) == "battle_victory":
			return true
	return false


func _has_battle_retreat(events: Array) -> bool:
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("action", "")) == "battle_retreat" or str(event.get("reason", "")) == "retreat":
			return true
	return false


# 驱动到第一场允许撤退的普通战斗。返回 "battle" 或失败类别。
func _drive_to_first_ordinary_battle(controller: RunController) -> String:
	var steps := 0
	var stall := 0
	var last_event_count := -1
	while steps < MAX_STEPS:
		steps += 1
		if controller.state == null or controller.state.is_terminal():
			return "terminal"
		var view := str(controller.current_view_name())
		if view == "Ending":
			return "ending_early"
		if view == "Battle":
			if bool(BATTLE_COMMAND_FACADE.boss_blocks_retreat(controller.current_battle)):
				return "boss_battle"
			return "battle"
		var event_count: int = controller.state.event_log.size()
		_step(controller, view)
		if controller.state.event_log.size() == event_count and str(controller.current_view_name()) == view:
			stall += 1
			if stall > 10:
				return "stall_%s" % view
		else:
			stall = 0
		last_event_count = event_count
	return "steps_cap"


func _step(controller: RunController, view: String) -> void:
	match view:
		"Map":
			_step_map(controller)
		"Shop", "Caravan", "Rest", "Refine":
			_leave(controller)
		"Encounter", "Npc", "Reward":
			_act_via_cards(controller)
		"Battle":
			controller.submit_command({"type": "end_turn", "state_version": controller.state.event_log.size(), "expected_phase": str(controller.current_battle.get("phase", "player_action"))})
		_:
			_leave(controller)


func _step_map(controller: RunController) -> void:
	var chosen := ""
	for node in controller.visible_route_nodes(2):
		if not bool(node.get("reachable", false)):
			continue
		if str(node.get("template_id", "")).begins_with("layer_boss_stand") or str(node.get("id", "")) == "final_boss_stand":
			continue
		var preference := int(node.get("type", "") in ["combat", "pursuit"])
		if chosen == "" or preference == 1:
			chosen = str(node.get("id", ""))
			if preference == 1:
				break
	if chosen != "":
		controller.submit_command({"type": "travel", "node_id": chosen})


func _act_via_cards(controller: RunController) -> void:
	var cards: Array[Dictionary] = ACTION_PREVIEW_SERVICE.preview_actions(
			controller.state, controller.current_node, controller.catalog)
	for card in cards:
		if not bool(card.get("executable", false)):
			continue
		var command: Dictionary = card.get("command", {})
		if command.is_empty():
			continue
		var result: Dictionary = controller.submit_command({
			"type": "action_card",
			"action_id": str(card.get("id", "")),
			"state_version": controller.state.event_log.size(),
			"node_id": str(controller.current_node.get("id", "")),
			"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
		})
		if bool(result.get("accepted", false)) or bool((result.get("result", {}) as Dictionary).get("ok", false)):
			return
	_leave(controller)


func _leave(controller: RunController) -> void:
	var result: Dictionary = controller.submit_command({"type": "leave_node"})
	if not bool(((result.get("result", result) as Dictionary).get("ok", false))):
		_fight_via_preview(controller)


func _fight_via_preview(controller: RunController) -> void:
	var cards: Array[Dictionary] = ACTION_PREVIEW_SERVICE.preview_actions(
			controller.state, controller.current_node, controller.catalog)
	for card in cards:
		var command: Dictionary = card.get("command", {})
		var is_fight := str(command.get("action_id", "")) == "fight" \
				or (str(command.get("type", "")) == "resolve_contact" and str(command.get("approach", "")) == "fight")
		if not is_fight or not bool(card.get("executable", false)):
			continue
		controller.submit_command({
			"type": "action_card",
			"action_id": str(card.get("id", "")),
			"state_version": controller.state.event_log.size(),
			"node_id": str(controller.current_node.get("id", "")),
			"session_node_id": str(controller.state.encounter_session.get("node_id", "")),
		})
		return
