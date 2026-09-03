extends GutTest

const RunSnapshotBuilderScript = preload("res://scripts/presentation/run_snapshot_builder.gd")
const RunStateScript = preload("res://scripts/domain/run_state.gd")
const ContentCatalogScript = preload("res://scripts/domain/content_catalog.gd")
const TOP_BAR_TSCN := "res://scenes/ui/widgets/gu_top_bar.tscn"
const INVENTORY_TSCN := "res://scenes/ui/widgets/gu_inventory.tscn"
const STAT_BAR_TSCN := "res://scenes/ui/widgets/gu_stat_bar.tscn"
const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")

var _hosts: Array = []

class StubController extends RefCounted:
	var state
	var catalog: Dictionary = {}
	var current_node: Dictionary = {}
	var meta = null
	var last_feedback := ""

func after_each() -> void:
	for host in _hosts:
		if host != null and is_instance_valid(host):
			host.free()
	_hosts.clear()

func test_gui_snapshot_projects_read_only_inventory_sections() -> void:
	var state = RunStateScript.new_run(101)
	state.materials = {"beast_blood": 3, "iron_sand": 1}
	state.gu_instances["inst_1"] = {"instance_id": "inst_1", "definition_id": "small_light_gu", "state": "refined", "rank": 1}
	var controller := StubController.new()
	controller.state = state
	controller.catalog = ContentCatalogScript.load_all()
	var snapshot: Dictionary = RunSnapshotBuilderScript._gui_state(controller)
	assert_true(snapshot.has("inventory"))
	var inventory: Dictionary = snapshot["inventory"]
	assert_true(inventory.has("materials"))
	assert_true(inventory.has("gu_instances"))
	assert_true(inventory.has("loot"))
	assert_true(inventory.has("intel"))
	assert_eq(int(inventory["materials"][0]["quantity"]), 3)
	state.health = 1
	snapshot = RunSnapshotBuilderScript._gui_state(controller)
	assert_true(snapshot["death_lines"].has("health"))
	assert_true(bool(snapshot["death_lines"]["health"]["danger"]))

func test_top_bar_scene_has_no_death_lines_or_material_chip() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 100)
	add_child(host)
	_hosts.append(host)
	var bar = TscnMountHelper.instantiate(TOP_BAR_TSCN, {
		"resources": {"yuanstone": 5, "shouyuan": 20, "hunpo": 4, "material": 9},
		"contracts": [], "anomalies": [], "death_lines": {}, "layer": 1
	}, {})
	host.add_child(bar)
	await get_tree().process_frame
	assert_null(_named(bar, "DeathHost"))
	assert_null(_named(bar, "DeathShouyuan"))
	assert_null(_named(bar, "ChipMaterial"))


func test_danger_feedback_stays_on_existing_resource_chips_and_health_bar() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 160)
	add_child(host)
	_hosts.append(host)
	var bar = TscnMountHelper.instantiate(TOP_BAR_TSCN, {}, {})
	host.add_child(bar)
	bar.set_data({"yuanstone": 5, "shouyuan": 1, "hunpo": 1}, [], [], {
		"shouyuan": {"danger": true, "detail": "寿元将尽"},
		"hunpo": {"danger": true, "detail": "魂魄将散"},
	}, 1)
	var health_bar = TscnMountHelper.instantiate(STAT_BAR_TSCN, {}, {})
	host.add_child(health_bar)
	health_bar.setup("生命", 1, 30, GuStyle.JADE, 0, Callable(), true, "气血将竭")
	await get_tree().process_frame
	assert_eq(_named(bar, "ChipShouyuan").tooltip_text, "寿元将尽")
	assert_eq(_named(bar, "ChipHunpo").tooltip_text, "魂魄将散")
	assert_eq(health_bar.tooltip_text, "气血将竭")
	assert_eq(health_bar.get_node("ValueRow/ValueLabel").get_theme_color("font_color"), GuStyle.CINNABAR)


func test_inventory_view_renders_all_run_inventory_sections() -> void:
	var host := Control.new()
	host.size = Vector2(720, 640)
	add_child(host)
	_hosts.append(host)
	var view = TscnMountHelper.instantiate(INVENTORY_TSCN, {}, {})
	host.add_child(view)
	view.setup({
		"materials": [{"id": "beast_blood", "name": "兽血", "quantity": 3}],
		"gu_instances": [{"id": "inst_1", "name": "小光蛊", "state": "refined", "rank": 1, "quality": "普通"}],
		"loot": [{"id": "loot_1", "name": "此战告捷。"}],
		"intel": [{"id": "site_clue", "name": "掌握地势线索"}],
	})
	await get_tree().process_frame
	assert_not_null(_named(view, "InventoryMaterials"))
	assert_not_null(_named(view, "InventoryGuInstances"))
	assert_not_null(_named(view, "InventoryLoot"))
	assert_not_null(_named(view, "InventoryIntel"))
	assert_true(_has_text(view, "兽血 ×3"))
	assert_true(_has_text(view, "小光蛊 · 一转 · 普通"))


func test_inventory_view_renders_an_explicit_empty_state() -> void:
	var host := Control.new()
	host.size = Vector2(720, 640)
	add_child(host)
	_hosts.append(host)
	var view = TscnMountHelper.instantiate(INVENTORY_TSCN, {}, {})
	host.add_child(view)
	view.setup({})
	await get_tree().process_frame
	assert_true(_has_text(view, "行囊暂无物品"))

func _named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _named(child, wanted)
		if found != null:
			return found
	return null


func _has_text(node: Node, wanted: String) -> bool:
	if node is Label and str((node as Label).text).contains(wanted):
		return true
	for child in node.get_children():
		if _has_text(child, wanted):
			return true
	return false
