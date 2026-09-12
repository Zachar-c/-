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
