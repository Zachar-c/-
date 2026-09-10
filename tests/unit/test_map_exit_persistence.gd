extends GutTest


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")


func after_each() -> void:
	if FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRepositoryScript.SAVE_PATH))
	if FileAccess.file_exists(SaveRepositoryScript.TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRepositoryScript.TEMP_PATH))


func test_map_leave_confirm_save_then_hall_continue_restores_same_run() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(101)
	var before_seed := int(controller.state.seed)
	var before_node := str(controller.state.current_node_id)
	var before_route_ids := _route_ids(controller.route)
	controller.state.materials["beast_blood"] = 3
	var commands: Dictionary = controller._build_commands("Map")
	assert_true(commands.has("to_hall"))
	assert_true(commands.has("save_and_to_hall"))
	assert_true(commands.has("cancel_to_hall"))
	commands["to_hall"].call()
	assert_eq(controller.current_view_name(), "Map", "first click only opens confirmation")
	assert_true(bool(controller._snapshot_for("Map").get("leave_confirm", false)))
	commands = controller._build_commands("Map")
	commands["save_and_to_hall"].call()
	assert_eq(controller.current_view_name(), "Title")
	assert_true(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH))
	assert_eq(str(controller._snapshot_for("Title").get("primary_action", "")), "continue_run")
	# W10 方案甲：「续入此世」= 读档继续，一键恢复离开前的同一 Run
	# （不再绕道流派选择子视图；AGENTS 2026-09-05 存档体验裁定）。
	var hall_commands: Dictionary = controller._build_commands("Title")
	hall_commands["continue_run"].call()
	assert_eq(controller.current_view_name(), "Map", "continue restores the saved run directly")
	assert_eq(int(controller.state.seed), before_seed)
	assert_eq(str(controller.state.current_node_id), before_node)
	assert_eq(_route_ids(controller.route), before_route_ids)
	assert_eq(int(controller.state.materials.get("beast_blood", 0)), 3)


func test_map_leave_confirm_cancel_stays_on_map_without_saving() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(101)
	var commands: Dictionary = controller._build_commands("Map")
	commands["to_hall"].call()
	assert_true(bool(controller._snapshot_for("Map").get("leave_confirm", false)))
	commands = controller._build_commands("Map")
	commands["cancel_to_hall"].call()
	assert_eq(controller.current_view_name(), "Map")
	assert_false(bool(controller._snapshot_for("Map").get("leave_confirm", false)))
	assert_false(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH))


func _route_ids(route: Array) -> Array[String]:
	var ids: Array[String] = []
	for node_value in route:
		ids.append(str((node_value as Dictionary).get("id", "")))
	return ids
