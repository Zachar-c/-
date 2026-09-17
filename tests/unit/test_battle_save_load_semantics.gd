extends GutTest

## M1（纠偏计划 2026-09-12）：战斗中存档语义钉死。
## 现状行为（审计结论，测试将其锁定为契约）：
## 1. save_run 只序列化 RunState + route + dialogue_replies，v1 战斗态
##    （controller.current_battle）不入档；
## 2. 战斗命令结算时 sync_battle_hp_to_state 已把 hp 同步进 state，
##    所以战斗中存档保留的是"已同步的 hp"，不是战斗现场；
## 3. load_run 恢复后 current_battle 必为空、视图回到 Map、
##    state.encounter_session 随存档整体恢复（M3 后无镜像字段）。
## 若未来实现"战斗中存档可恢复战斗"，必须先改本测试再改实现。

const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")
const ControllerScript = preload("res://scripts/presentation/run_controller.gd")


func _cleanup_save_files() -> void:
	for path in [SaveRepositoryScript.SAVE_PATH, SaveRepositoryScript.TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func before_each() -> void:
	_cleanup_save_files()


func after_each() -> void:
	_cleanup_save_files()


func _find_combat_node_id(controller: RunController) -> String:
	for node_value in controller.route:
		var node: Dictionary = node_value
		if str(node.get("type", "")) == "combat":
			return str(node.get("id", ""))
	return ""


func test_save_during_battle_persists_synced_hp_and_load_returns_to_map_without_battle() -> void:
	var controller: RunController = autofree(ControllerScript.new())
	controller.start_new_run(101)
	assert_false(controller.route.is_empty(), "route must be generated")

	var combat_id := _find_combat_node_id(controller)
	assert_false(combat_id.is_empty(), "seed 101 route must contain a combat node")
	controller.current_node = controller._node_by_id(combat_id)
	controller._stamp_current_node(controller.state, controller.current_node)
	controller._start_battle()
	assert_false(controller.current_battle.is_empty(), "battle must be running before save")

	# 走一步真实战斗命令，触发 hp 同步路径（不关心战斗结果）。
	var attack_result := controller.submit_command({"type": "basic_attack"})
	assert_true(attack_result.has("state") or bool(attack_result.get("finished", false)),
			"battle command must return a turn result")
	var expected_hp := int(controller.state.health)
	var expected_session: Dictionary = controller.state.encounter_session.duplicate(true)

	var save_result := controller.submit_command({"type": "save_run"})
	assert_true(bool(save_result.get("ok", false)), "save during battle must succeed")
	assert_false(FileAccess.file_exists(SaveRepositoryScript.TEMP_PATH),
			"atomic write must not leave temp file behind")

	var load_result := controller.submit_command({"type": "load_run"})
	assert_true(bool(load_result.get("ok", false)), "load must succeed")

	# 钉死语义：战斗现场不恢复。
	assert_true(controller.current_battle.is_empty(),
			"current_battle must NOT be restored (v1 battle state is not serialised)")
	assert_eq(controller.current_view_name(), "Map",
			"load must land on Map, not Battle")
	assert_eq(int(controller.state.health), expected_hp,
			"synced hp must survive the round trip")
	assert_eq(controller.state.encounter_session, expected_session,
			"encounter_session must be restored from the save")


## 第三阶段 Task 5：相同 seed + 相同命令序列必须重放出一致的 battle 与事件日志。
func test_same_seed_and_command_sequence_replay_to_the_same_battle() -> void:
	var recorded: Array = []
	var first_battle := ""
	var first_events: Array = []

	for attempt in 2:
		var controller: RunController = autofree(ControllerScript.new())
		controller.start_new_run(101)
		_open_first_combat(controller)
		if attempt == 0:
			recorded = _scripted_commands(controller.current_battle)
		for command_value in recorded:
			var command: Dictionary = (command_value as Dictionary).duplicate(true)
			command["state_version"] = controller.state.event_log.size()
			controller.submit_command(command)
		if attempt == 0:
			first_battle = JSON.stringify(controller.current_battle)
			first_events = _battle_events(controller.state)
		else:
			assert_eq(JSON.stringify(controller.current_battle), first_battle,
					"same seed + same command sequence must replay the same battle state")
			assert_eq(_battle_events(controller.state), first_events,
					"same seed + same command sequence must replay the same battle log")
	assert_false(first_battle.is_empty(), "the fixture must actually run a battle")
	assert_gt(first_events.size(), 0,
			"the scripted sequence must actually be accepted, otherwise the replay proves nothing")


## 第三阶段 Task 5：快照是只读投影，刷新不得重抽敌意/手牌/杀招，也不得落事件。
func test_snapshot_refresh_does_not_reroll_intent_hand_or_log() -> void:
	var controller: RunController = autofree(ControllerScript.new())
	controller.start_new_run(101)
	_open_first_combat(controller)

	var log_size := controller.state.event_log.size()
	var first: Dictionary = controller._snapshot_for("Battle")
	var second: Dictionary = controller._snapshot_for("Battle")

	assert_eq(JSON.stringify(second.get("enemies", [])), JSON.stringify(first.get("enemies", [])),
			"refreshing the snapshot must not re-roll the public enemy intent")
	assert_eq(JSON.stringify(second.get("hand", [])), JSON.stringify(first.get("hand", [])),
			"refreshing the snapshot must not re-roll the hand cards")
	assert_eq(JSON.stringify(second.get("kill_moves", [])), JSON.stringify(first.get("kill_moves", [])),
			"refreshing the snapshot must not re-roll the kill-move cards")
	assert_eq(controller.state.event_log.size(), log_size,
			"a read-only snapshot must not append events")


## 第三阶段 Task 5：回合账本是运行期字段，不得随存档恢复为可继续的战斗现场。
func test_battle_ledger_is_runtime_only_and_not_restored_by_load() -> void:
	var controller: RunController = autofree(ControllerScript.new())
	controller.start_new_run(101)
	_open_first_combat(controller)

	var slots: Array = controller.current_battle.get("gu_slots", [])
	assert_false(slots.is_empty(), "seed 101 first combat must expose at least one gu slot")
	controller.submit_command({
		"type": "use_gu",
		"instance_id": str((slots[0] as Dictionary).get("instance_id", "")),
		"state_version": controller.state.event_log.size(),
	})
	assert_false(controller.state.current_battle2_ledger.is_empty(),
			"an accepted turn must advance the runtime battle ledger")

	assert_true(bool(controller.submit_command({"type": "save_run"}).get("ok", false)),
			"save during battle must succeed")
	assert_true(bool(controller.submit_command({"type": "load_run"}).get("ok", false)),
			"load must succeed")

	assert_true(controller.state.current_battle2_ledger.is_empty(),
			"the battle ledger must not survive the save round trip")
	assert_true(controller.current_battle.is_empty(),
			"the battle scene must not be restored by load")
	assert_eq(controller.current_view_name(), "Map", "load must land on Map")


func _open_first_combat(controller: RunController) -> void:
	var combat_id := _find_combat_node_id(controller)
	assert_false(combat_id.is_empty(), "seed 101 route must contain a combat node")
	controller.current_node = controller._node_by_id(combat_id)
	controller._stamp_current_node(controller.state, controller.current_node)
	controller._start_battle()


## 固定命令序列（不含版本戳；提交前按当前日志长度补齐）。
func _scripted_commands(battle: Dictionary) -> Array:
	var commands: Array = []
	var slots: Array = battle.get("gu_slots", [])
	if not slots.is_empty():
		commands.append({
			"type": "use_gu",
			"instance_id": str((slots[0] as Dictionary).get("instance_id", "")),
			"target_id": _first_living_enemy_id(battle),
		})
	commands.append({"type": "end_turn"})
	commands.append({"type": "basic_attack"})
	commands.append({"type": "end_turn"})
	return commands


func _first_living_enemy_id(battle: Dictionary) -> String:
	for enemy_value in battle.get("enemies", []):
		var enemy: Dictionary = enemy_value
		if int(enemy.get("hp", 0)) > 0:
			return str(enemy.get("id", ""))
	return ""


func _battle_events(state: RunState) -> Array:
	var out: Array = []
	for event_value in state.event_log:
		var event: Dictionary = event_value
		if str(event.get("action", "")).begins_with("battle_v1"):
			out.append(JSON.stringify(event))
	return out
