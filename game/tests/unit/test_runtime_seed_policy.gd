extends GutTest

# R-seed 2026-09-03（垂直切片裁定）：运行路径不设教学种子/固定种子。
# 1) 种子 101 不再映射手写 first_run 教学路线——玩家局一律按传入种子生成地图，
#    大厅新一世与结局后再入都使用 roll_seed() 随机种子；
# 2) 结局结算（弃世/死亡）删除进行中 Run 存档，大厅不再显示「续入此世」指向
#    已结束的旧档，下一次从大厅进入以全新随机局开始。


const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const MapGeneratorScript = preload("res://scripts/domain/map_generator.gd")
const SaveRepositoryScript = preload("res://scripts/domain/save_repository.gd")

var catalog: Dictionary


func before_each() -> void:
	catalog = ContentCatalog.load_all()
	_remove_run_save()


func after_each() -> void:
	_remove_run_save()


func _remove_run_save() -> void:
	if FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveRepositoryScript.SAVE_PATH))


func _new_controller() -> RunController:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = catalog
	return controller


func _route_ids(route: Array) -> Array:
	var ids: Array = []
	for node in route:
		ids.append(str((node as Dictionary).get("id", "")))
	return ids


func test_seed_101_run_builds_generated_route_not_first_run_teaching() -> void:
	var controller := _new_controller()
	controller.start_new_run(101, "", [])
	var route: Array = controller.route
	assert_false(route.is_empty(), "seed 101 必须正常开出一局")
	var first_id := str((route[0] as Dictionary).get("id", ""))
	assert_true(first_id.begins_with("L"),
			"seed 101 不得再走教学手写路线（首节点 id=%s）" % first_id)
	assert_false(str((route[0] as Dictionary).get("template_id", "")).is_empty(),
			"生成节点必须携带 template_id")

	# 与 MapGenerator 的生成路径一致：101 已无教学特判。
	var generated: Array[Dictionary] = MapGeneratorScript.build(101, false, catalog)
	assert_eq(_route_ids(route), _route_ids(generated),
			"controller 路线必须等于 MapGenerator.build(seed, false)")
	# 教学夹具（显式 first_run=true）只留给测试，绝不等于玩家局路线。
	var teaching: Array[Dictionary] = MapGeneratorScript.build(101, true, catalog)
	assert_ne(_route_ids(route), _route_ids(teaching),
			"玩家局路线不得等于 first_run 教学夹具")


func test_distinct_seeds_build_distinct_routes() -> void:
	var a: Array[Dictionary] = MapGeneratorScript.build(20260831, false, catalog)
	var b: Array[Dictionary] = MapGeneratorScript.build(4242, false, catalog)
	assert_ne(_route_ids(a), _route_ids(b), "不同种子必须生成不同路线")


func test_surrender_settlement_deletes_save_and_hall_offers_new_life() -> void:
	var controller := _new_controller()
	controller.start_new_run(4242, "", [])
	var saved: Dictionary = controller.submit_command({"type": "save_run"})
	assert_true(bool(saved.get("ok", false)), "存档命令必须成功")
	assert_true(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH), "存档文件必须存在")

	controller.surrender_run()
	assert_false(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
			"弃世结算后必须删除进行中 Run 存档")
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_false(bool(snapshot.get("has_save", false)),
			"结算后大厅不得再显示「续入此世」旧档入口")


func test_death_settlement_deletes_in_progress_run_save() -> void:
	var controller := _new_controller()
	controller.start_new_run(5150, "", [])
	SaveRepositoryScript.save_run(controller.state, controller.route, [])
	assert_true(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH), "存档文件必须存在")

	controller.force_death_for_test("test_blow")
	assert_false(FileAccess.file_exists(SaveRepositoryScript.SAVE_PATH),
			"死亡结算后必须删除进行中 Run 存档")
