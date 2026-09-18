extends GutTest

## W5 回归门禁：开局入口（start_new_run / start_m0_run）必须复用控制器
## 初始化期（_initialize_view_flow）已加载并校验的目录，不得再次全量解析
## data/*.json；未经初始化的 headless 测试/工具仍须自行加载。
##
## 复用判定用「预置目录标记」：若开局重建目录，标记必然丢失。空目录回退
## 则断言目录被真正加载（gu_by_id 索引非空），两条路径互相区分。

const RunControllerScript = preload("res://scripts/presentation/run_controller.gd")
const REUSE_MARKER := "__catalog_reuse_marker__"


func _catalog_with_marker() -> Dictionary:
	var catalog: Dictionary = ContentCatalog.load_all()
	catalog[REUSE_MARKER] = "preloaded"
	return catalog


func test_start_new_run_reuses_preloaded_catalog() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = _catalog_with_marker()
	controller.start_new_run(42, "force")
	assert_eq(controller.catalog.get(REUSE_MARKER, ""), "preloaded",
		"start_new_run 必须复用已加载目录，不得重建")
	assert_ne(controller.state, null, "开局状态仍建立")
	assert_eq(controller.current_view_name(), "Map", "正常开局仍进地图")


func test_start_m0_run_reuses_preloaded_catalog() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	controller.catalog = _catalog_with_marker()
	controller.start_m0_run(42)
	assert_eq(controller.catalog.get(REUSE_MARKER, ""), "preloaded",
		"start_m0_run 必须复用已加载目录，不得重建")
	assert_ne(controller.state, null, "M0 状态仍建立")
	assert_true(controller.m0_mode, "M0 模式仍开启")
	assert_eq(controller.current_view_name(), "Map", "M0 开局仍进地图")


func test_start_new_run_loads_catalog_without_initialization() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	assert_true(controller.catalog.is_empty(), "未初始化控制器不带目录")
	controller.start_new_run(42, "force")
	assert_false(controller.catalog.is_empty(), "无初始化路径必须自行加载目录")
	assert_false(controller.catalog.get("gu_by_id", {}).is_empty(), "加载结果含蛊表索引")


func test_start_m0_run_loads_catalog_without_initialization() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	assert_true(controller.catalog.is_empty(), "未初始化控制器不带目录")
	controller.start_m0_run(42)
	assert_false(controller.catalog.is_empty(), "无初始化路径必须自行加载目录")
	assert_false(controller.catalog.get("gu_by_id", {}).is_empty(), "加载结果含蛊表索引")


func test_run_start_still_refuses_invalid_content() -> void:
	var controller: RunController = autofree(RunControllerScript.new())
	var invalid_catalog := _catalog_with_marker()
	var first_gu: Dictionary = invalid_catalog["gu"][0]
	first_gu["rank"] = 0
	controller.catalog = invalid_catalog
	controller.start_new_run(42, "force")
	assert_eq(controller.current_view_name(), "ContentError", "非法内容仍进内容错误屏")
	assert_eq(controller.state, null, "非法内容不得建立运行状态")
