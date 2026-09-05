extends GutTest


# UI 视图流转验收（生成式路线版）：R-seed 裁定废弃固定教学路线后，本测试改为
# 在随机生成图上驱动到第一场普通战斗，验证真实屏幕挂载下的视图流转——
# Battle 快照可出牌 → 普通战斗允许正式撤退 → 战后回 Map → Map 指令面暴露
# 受保护结局路由（surrender）→ Ending。驱动器只经 RunController.submit_command
# 推进，有限 seed 重滚，不得死循环。


const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const ACTION_PREVIEW_SERVICE = preload("res://scripts/domain/action_preview_service.gd")
const BATTLE_COMMAND_FACADE = preload("res://scripts/domain/battle_command_facade.gd")

const MAX_STEPS := 300
const MAX_SEEDS := 8


func test_generated_run_reaches_ending_through_battle_retreat_and_surrender() -> void:
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
		var retreated: Dictionary = controller.submit_command({
			"type": "retreat",
			"state_version": controller.state.event_log.size(),
			"expected_phase": str(controller.current_battle.get("phase", "")),
		})
		assert_true(bool(retreated.get("accepted", false)),
				"ordinary combat must allow a formal retreat")
		var left: Dictionary = controller.submit_command({"type": "leave_node"})
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
			controller.submit_command({"type": "end_turn", "state_version": controller.state.event_log.size()})
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
			"session_node_id": str(controller.current_session.get("node_id", "")),
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
			"session_node_id": str(controller.current_session.get("node_id", "")),
		})
		return
