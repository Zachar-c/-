extends GutTest


const RUN_CONTROLLER = preload("res://scripts/presentation/run_controller.gd")
const V1_BATTLE_RESOLVER = preload("res://scripts/domain/v1_battle_resolver.gd")
const SAVE_REPOSITORY = preload("res://scripts/domain/save_repository.gd")
const REWARD_SCREEN = preload("res://scenes/ui/screens/reward_screen.tscn")
const HALL_SCREEN = preload("res://scenes/ui/screens/hall_screen.tscn")


func test_m0_is_reachable_from_hall_button_without_changing_full_run_entry() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	add_child(controller)
	var commands: Dictionary = controller._build_commands("Title")
	assert_true(commands.has("new_run"), "full-run entry must remain available")
	assert_true(commands.has("new_m0_run"), "hall must expose the M0 entry command")

	var hall: Control = HALL_SCREEN.instantiate()
	add_child_autofree(hall)
	hall.mount_snapshot(controller._snapshot_for("Title"), commands)
	await get_tree().process_frame
	var m0_button: Button = hall.get_node("Root/MainView/HallSheet/HallPrimary/M0Action")
	assert_true(m0_button.visible, "hall must show the M0 entry button")
	m0_button.pressed.emit()
	assert_eq(controller.current_view_name(), "Map")
	assert_true(controller.m0_mode, "hall M0 entry must start isolated M0 mode")


func test_m0_four_fights_rewards_build_and_boss_win() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	assert_true(controller.has_method("start_m0_run"), "M0 entry point must exist")
	if not controller.has_method("start_m0_run"):
		return
	controller.start_m0_run(101)
	assert_eq(controller.current_view_name(), "Map")
	var battle_count := 0
	while controller.current_view_name() != "Ending" and battle_count < 4:
		_travel_to_next_m0_node(controller)
		assert_eq(controller.current_view_name(), "Battle")
		var before_battle_events := controller.state.event_log.size()
		assert_true(_fight_without_retreat(controller), "M0 battle %d must be won without retreat" % (battle_count + 1))
		assert_true(_has_event_since(controller.state.event_log, before_battle_events,
				"battle_finished", "battle_victory"))
		battle_count += 1
		if battle_count < 4:
			assert_eq(controller.current_view_name(), "Reward")
			var reward_snapshot: Dictionary = controller._snapshot_for("Reward")
			assert_true(bool(reward_snapshot.get("m0_mode", false)),
					"M0 Reward must expose its mode to the UI snapshot")
			assert_eq((reward_snapshot.get("choice_rewards", []) as Array).size(), 3,
					"M0 UI snapshot must expose three choices")
			var reward_commands: Dictionary = controller._build_commands("Reward")
			assert_true(reward_commands.has("choose_reward"),
					"M0 Reward UI must expose a choose_reward command")
			var options: Array = controller.m0_reward_options
			assert_eq(options.size(), 3, "each non-boss M0 victory must offer three choices")
			var chosen := _find_option(options, "gu")
			assert_false(chosen.is_empty(), "M0 reward must include a build-changing Gu choice")
			var blocked: Dictionary = controller.submit_command({"type": "leave_encounter"})
			assert_false(bool(blocked.get("ok", false)),
					"M0 Reward must not be dismissible before a choice")
			var before_build := _build_signature(controller)
			reward_commands["choose_reward"].call(str(chosen.get("id", "")))
			assert_true(controller.m0_reward_selected, "M0 UI reward command must select once")
			assert_ne(_build_signature(controller), before_build,
					"taking a Gu reward must change the current build")
			var repeated: Dictionary = controller.submit_command({
				"type": "m0_reward_take",
				"reward_id": str(chosen.get("id", "")),
			})
			assert_false(bool(repeated.get("ok", false)), "M0 reward choice must be one-shot")
			var left: Dictionary = controller.submit_command({"type": "leave_encounter"})
			assert_true(bool((left.get("result", left) as Dictionary).get("ok", false)),
					"selected M0 reward must allow leaving the reward screen")
	assert_eq(battle_count, 4, "M0 must contain exactly four fights")
	assert_eq(controller.current_view_name(), "Ending", "M0 Boss victory must end the run")
	assert_true(_has_event(controller.state.event_log, "m0_boss_defeated", "m0_boss_defeated"))
	assert_false(_has_event(controller.state.event_log, "battle_retreat", "battle_retreat"),
			"M0 success path must not retreat")


func test_m0_different_seeds_produce_different_reward_choices() -> void:
	var first: RunController = autofree(RUN_CONTROLLER.new())
	var second: RunController = autofree(RUN_CONTROLLER.new())
	assert_true(first.has_method("start_m0_run"), "M0 entry point must exist")
	if not first.has_method("start_m0_run"):
		return
	var signatures: Array[String] = []
	for pair in [[first, 101], [second, 2026]]:
		var controller: RunController = pair[0]
		controller.start_m0_run(int(pair[1]))
		_travel_to_next_m0_node(controller)
		assert_true(_fight_without_retreat(controller))
		var options: Array = controller.m0_reward_options
		assert_eq(options.size(), 3)
		var option_ids: Array[String] = []
		for option_value in options:
			option_ids.append(str((option_value as Dictionary).get("id", "")))
		signatures.append("|".join(option_ids))
	assert_ne(signatures[0], signatures[1], "different M0 seeds must change the reward problem")


func test_m0_death_can_restart_as_a_fresh_run() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	assert_true(controller.has_method("start_m0_run"), "M0 entry point must exist")
	if not controller.has_method("start_m0_run"):
		return
	controller.start_m0_run(2026)
	controller.force_death_for_test("m0_restart_probe")
	assert_eq(controller.current_view_name(), "Ending")
	controller._show_title()
	controller.start_m0_run(2027)
	assert_eq(controller.current_view_name(), "Map")
	assert_eq(controller.state.terminal_state, "active")
	assert_eq(int(controller.state.node_flags.get("m0_battles_completed", 0)), 0)
	assert_eq(controller.state.current_node_id, "trailhead")


func test_m0_save_restore_preserves_isolated_mode_and_route() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_m0_run(303)
	_travel_to_next_m0_node(controller)
	assert_true(_fight_without_retreat(controller))
	var payload: Dictionary = SAVE_REPOSITORY.serialize_run(controller.state, controller.route, [])
	var loaded: Dictionary = SAVE_REPOSITORY.load_run_from_data(payload)
	assert_true(loaded.has("state"), "M0 state must remain loadable through the normal v4 save contract")

	var restored: RunController = autofree(RUN_CONTROLLER.new())
	assert_true(restored._restore_game(loaded), "M0 save must restore through the normal controller path")
	assert_true(restored.m0_mode, "M0 save must restore isolated mode")
	assert_eq(restored.route.size(), 4, "M0 save must restore the four-node route")
	assert_eq(restored.state.current_node_id, controller.state.current_node_id)


func test_m0_reward_screen_mounts_three_choices_and_locks_after_click() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_m0_run(101)
	_travel_to_next_m0_node(controller)
	assert_true(_fight_without_retreat(controller))
	assert_eq(controller.current_view_name(), "Reward")

	var screen: Control = REWARD_SCREEN.instantiate()
	add_child_autofree(screen)
	screen.mount_snapshot(controller._snapshot_for("Reward"), controller._build_commands("Reward"))
	await get_tree().process_frame

	var reward_row: HBoxContainer = screen.get_node("Root/primary_decision_surface/RewardRow")
	var choice_buttons: Array[Button] = []
	for child in reward_row.get_children():
		if child is Button:
			choice_buttons.append(child as Button)
	assert_eq(choice_buttons.size(), 3, "M0 Reward scene must render three clickable choices")
	var continue_button: Button = screen.get_node("Root/ContinueButton")
	assert_true(continue_button.disabled, "M0 Reward scene must lock Continue before choice")

	choice_buttons[0].pressed.emit()
	assert_true(controller.m0_reward_selected, "clicking a rendered choice must apply the reward")
	screen.mount_snapshot(controller._snapshot_for("Reward"), controller._build_commands("Reward"))
	await get_tree().process_frame
	assert_false(continue_button.disabled, "M0 Reward scene must unlock Continue after choice")
	for child in reward_row.get_children():
		if child is Button:
			assert_true((child as Button).disabled, "M0 choices must lock after one selection")


func test_m0_retreat_cannot_finish_the_run_nor_count_as_a_completed_battle() -> void:
	# 第三阶段 Task 4：M0 普通路线不得以 battle_retreat 结束；撤离既不给奖励，
	# 也不计入四战进度，run 保持 active。
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_m0_run(101)
	_travel_to_next_m0_node(controller)
	assert_eq(controller.current_view_name(), "Battle")

	var before_events := controller.state.event_log.size()
	var retreated: Dictionary = controller.submit_command({
		"type": "retreat",
		"state_version": controller.state.event_log.size(),
		"expected_phase": str(controller.current_battle.get("phase", "")),
	})
	assert_true(bool(retreated.get("accepted", false)),
			"M0 ordinary combat must keep retreat as an explicit path")
	assert_eq(str(retreated.get("result", "")), "retreat")

	assert_ne(controller.current_view_name(), "Ending", "retreat must not end the M0 run")
	assert_ne(controller.current_view_name(), "Reward", "retreat must not open the M0 reward")
	assert_eq(int(controller.state.node_flags.get("m0_battles_completed", 0)), 0,
			"a retreat must not count as a completed M0 battle")
	assert_eq(controller.state.terminal_state, "active", "retreat must leave the run active")
	assert_false(_has_event(controller.state.event_log, "m0_battle_completed", "m0_battle_completed"),
			"retreat must not append the M0 completion event")

	# 收口仍归生命周期层：这次撤离恰好落一条 battle_finished。
	assert_true(_has_event_since(controller.state.event_log, before_events,
			"battle_finished", "battle_retreat"))
	assert_eq(_count_events(controller.state.event_log, "battle_finished"), 1,
			"a battle must be closed by exactly one battle_finished event")


func test_m0_reward_gate_blocks_both_leave_commands_until_a_choice_is_made() -> void:
	var controller: RunController = autofree(RUN_CONTROLLER.new())
	controller.start_m0_run(101)
	_travel_to_next_m0_node(controller)
	assert_true(_fight_without_retreat(controller))
	assert_eq(controller.current_view_name(), "Reward")
	assert_false(controller.m0_reward_selected)

	for command_type in ["leave_encounter", "leave_node"]:
		var blocked: Dictionary = controller.submit_command({"type": command_type})
		assert_false(bool(blocked.get("ok", false)),
				"M0 Reward must block %s before a choice" % command_type)
		assert_eq(str(blocked.get("reason", "")), "m0_reward_choice_required",
				"%s must be answered by the existing M0 reward gate" % command_type)
	assert_eq(controller.current_view_name(), "Reward", "a gated command must not change the screen")


func _travel_to_next_m0_node(controller: RunController) -> void:
	for node_value in controller.visible_route_nodes(2):
		var node: Dictionary = node_value
		if not bool(node.get("reachable", false)):
			continue
		var result: Dictionary = controller.submit_command({
			"type": "travel",
			"node_id": str(node.get("id", "")),
		})
		if bool(result.get("ok", false)) or controller.current_view_name() == "Battle":
			return
	fail_test("M0 route did not expose a reachable next combat node")


func _fight_without_retreat(controller: RunController, max_steps: int = 120) -> bool:
	var steps := 0
	while controller.current_view_name() == "Battle" and steps < max_steps:
		steps += 1
		var battle: Dictionary = controller.current_battle
		var attack_id := _pick_effect_gu(battle, ["strike", "heal_and_strike"])
		var guard_id := _pick_effect_gu(battle, ["shield", "buff"])
		var command: Dictionary
		if not attack_id.is_empty():
			command = _gu_command(controller, attack_id, _living_target_id(battle))
		elif not guard_id.is_empty():
			command = _gu_command(controller, guard_id, _living_target_id(battle))
		else:
			command = {"type": "end_turn", "state_version": controller.state.event_log.size()}
		var result: Dictionary = controller.submit_command(command)
		if not bool(result.get("accepted", false)) and not bool(result.get("finished", false)):
			controller.submit_command({"type": "end_turn", "state_version": controller.state.event_log.size()})
	return controller.current_view_name() in ["Reward", "Encounter", "Ending"]


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


func _gu_command(controller: RunController, instance_id: String, target_id: String) -> Dictionary:
	return {
		"type": "use_gu",
		"instance_id": instance_id,
		"target_id": target_id,
		"state_version": controller.state.event_log.size(),
	}


func _living_target_id(battle: Dictionary) -> String:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if bool(enemy.get("alive", int(enemy.get("hp", 0)) > 0)) and int(enemy.get("hp", 0)) > 0:
			return str(enemy.get("id", ""))
	return ""


func _find_option(options: Array, kind: String) -> Dictionary:
	for option_value in options:
		var option: Dictionary = option_value
		if str(option.get("kind", "")) == kind:
			return option
	return {}


func _build_signature(controller: RunController) -> String:
	var ids: Array[String] = []
	for instance_value in controller.state.gu_instances.values():
		var instance: Dictionary = instance_value
		ids.append(str(instance.get("definition_id", "")))
	ids.sort()
	return ",".join(ids)


func _has_event(events: Array, action: String, reason: String) -> bool:
	return _has_event_since(events, 0, action, reason)


func _has_event_since(events: Array, start_index: int, action: String, reason: String) -> bool:
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index]
		if str(event.get("action", "")) == action and str(event.get("reason", "")) == reason:
			return true
	return false


func _count_events(events: Array, action: String) -> int:
	var total := 0
	for event_value in events:
		if str((event_value as Dictionary).get("action", "")) == action:
			total += 1
	return total
