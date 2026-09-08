extends GutTest


const TscnMountHelper = preload("res://tests/unit/tscn_mount_helper.gd")
const HALL_SCREEN_TSCN := "res://scenes/ui/screens/hall_screen.tscn"


# Title/Hall flow under the RUI screens: the controller starts on the hall
# screen, the hall snapshot exposes run entry state, and HallView renders
# the game name plus the main menu commands.


func test_controller_shows_title_before_run_then_starts_on_command() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	await get_tree().process_frame
	assert_eq(controller.current_view_name(), "Title")
	controller.start_new_run(101)
	assert_eq(controller.current_view_name(), "Map")
	assert_not_null(controller.state)


func test_hall_view_exposes_wenzhen_brand_and_quiet_menu() -> void:
	var snapshot := {
		"has_save": false,
		"brand_title": "問眞",
		"primary_action": "open_schools",
		"run_summary": {
			"route": "", "rank": "0转", "hp": "0",
			"lifespan": "0年", "gu_count": 0, "node_count": 0,
			"curse_count": 0, "build_label": "BUILD 0.9.0 · LOCAL",
		},
		"available_schools": [
			{"id": "blood", "name": "血道"},
			{"id": "qi", "name": "气道"},
			{"id": "force", "name": "力道"},
		],
		"contracts": [],
		"meta_stats": {"runs": 1, "endings": 0},
	}
	# 大厅已迁到 Godot 官方 .tscn：不再有 render 入口。
	var host := Control.new()
	add_child_autofree(host)
	var root := TscnMountHelper.instantiate(HALL_SCREEN_TSCN, snapshot, {})
	host.add_child(root)
	await get_tree().process_frame
	var texts := TscnMountHelper.texts(root)
	assert_true(_any_contains(texts, "問眞"), "hall must show the formal brand")
	assert_true(_any_contains(texts, "开始此世"), "hall must offer its sole new-run entry")
	assert_true(_any_contains(texts, "图鉴"), "hall must expose codex")
	assert_true(_any_contains(texts, "手记"), "hall must expose journal")
	assert_false(_any_contains(texts, "继续上次冒险"), "hall must not expose the old secondary continue action")


func test_hall_snapshot_carries_save_flag_and_schools() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_true(snapshot.has("has_save"))
	assert_true((snapshot.get("available_schools", []) as Array).size() >= 3)


func test_hall_commands_expose_school_selection() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	var commands: Dictionary = controller._build_commands("Title")
	assert_true(commands.has("select_school"), "hall must route school selection")
	commands["select_school"].call("qi")
	assert_eq(controller._selected_school, "qi")


func test_hall_snapshot_lists_school_ids_and_names() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	var snapshot: Dictionary = controller._snapshot_for("Title")
	var schools: Array = snapshot.get("available_schools", [])
	assert_gte(schools.size(), 3)
	var first: Dictionary = schools[0]
	assert_true(first.has("id"), "school entry must carry an id")
	assert_true(first.has("name"), "school entry must carry a display name")


func _rui_texts(vnode: Variant) -> Array[String]:
	var out: Array[String] = []
	if vnode == null:
		return out
	if vnode is RefCounted or vnode is Dictionary:
		var props: Variant = vnode.props if vnode is RefCounted else vnode.get("props", {})
		if props is Dictionary:
			for key in ["text", "label", "title"]:
				if props.has(key):
					out.append(str(props[key]))
		var children: Variant = vnode.children if vnode is RefCounted else vnode.get("children", [])
		if children is Array:
			for child in children:
				out.append_array(_rui_texts(child))
	return out


func _any_contains(texts: Array[String], substring: String) -> bool:
	for text in texts:
		if text.contains(substring):
			return true
	return false
