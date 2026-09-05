extends GutTest

## A1（architecture-refactor-master-plan §3 A1）：main 路径（RunController）的
## Battle/Map 视图必须挂载 wenzhen 双 master，旧 battle_screen.tscn / map_screen.tscn
## 不得再留在路由表上（文件删除归 A6）。数据仍走 RunSnapshotBuilder 快照、命令仍走
## RunCommandBuilder——本文件只守护「挂载到谁」这一层，避免旧屏悄悄回到主路径。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")

const MAP_MASTER := "res://scenes/ui_masters/wenzhen_map_master.tscn"
const BATTLE_MASTER := "res://scenes/ui_masters/wenzhen_battle_master.tscn"
const OLD_MAP_SCREEN := "res://scenes/ui/screens/map_screen.tscn"
const OLD_BATTLE_SCREEN := "res://scenes/ui/screens/battle_screen.tscn"


func test_route_table_pins_battle_and_map_to_wenzhen_masters() -> void:
	var paths: Dictionary = RunControllerScript.MASTER_SCENE_PATHS
	assert_eq(str(paths.get("Map", "")), MAP_MASTER,
			"Map view must mount the wenzhen map master on the main route")
	assert_eq(str(paths.get("Battle", "")), BATTLE_MASTER,
			"Battle view must mount the wenzhen battle master on the main route")
	assert_ne(str(paths.get("Map", "")), OLD_MAP_SCREEN,
			"old map_screen.tscn must not stay on the main route")
	assert_ne(str(paths.get("Battle", "")), OLD_BATTLE_SCREEN,
			"old battle_screen.tscn must not stay on the main route")


func test_new_run_mounts_wenzhen_map_master_on_main_path() -> void:
	var controller := _start_controller()
	await _settle()
	assert_eq(controller.current_view_name(), "Map")
	var inst := controller._master_instance
	assert_not_null(inst, "main path must instantiate a master for the Map view")
	if inst == null:
		return
	assert_eq(inst.scene_file_path, MAP_MASTER, "Map view instance must come from the wenzhen map master")
	var host := inst.get_node_or_null("MapScreen")
	assert_not_null(host, "wenzhen map master must own the MapScreen RUI host")
	if host != null:
		assert_true(host.get_child_count() > 0, "map master must render real controls from the snapshot")
	assert_true(_has_text_under(inst, "問眞"), "map master must render real map mast text")


func test_start_battle_mounts_wenzhen_battle_master_on_main_path() -> void:
	var controller := _start_controller()
	controller.current_node = {"id": "beast_swarm_pass", "type": "combat", "enemy_kind": "ridge_hound"}
	controller._start_battle()
	await _settle()
	assert_eq(controller.current_view_name(), "Battle")
	var inst := controller._master_instance
	assert_not_null(inst, "main path must instantiate a master for the Battle view")
	if inst == null:
		return
	assert_eq(inst.scene_file_path, BATTLE_MASTER, "Battle view instance must come from the wenzhen battle master")
	var host := inst.get_node_or_null("BattleScreen")
	assert_not_null(host, "wenzhen battle master must own the BattleScreen RUI host")
	if host != null:
		assert_true(host.get_child_count() > 0, "battle master must render real controls from the snapshot")
	assert_true(_has_text_under(inst, "敌方"), "battle master must render the enemy panel")


func _start_controller() -> RunController:
	var controller: RunController = autofree(RunControllerScript.new())
	add_child(controller)
	controller.start_new_run(101)
	return controller


func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame


func _has_text_under(node: Node, wanted: String) -> bool:
	if node == null:
		return false
	if node is Label and str((node as Label).text).contains(wanted):
		return true
	if node is Button and str((node as Button).text).contains(wanted):
		return true
	for child in node.get_children():
		if _has_text_under(child, wanted):
			return true
	return false
