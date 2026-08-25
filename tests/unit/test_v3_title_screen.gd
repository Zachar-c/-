extends GutTest


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


func test_hall_view_exposes_game_name_and_menu() -> void:
	var snapshot := {
		"has_save": false,
		"available_schools": ["血道", "气道", "力道"],
		"contracts": [],
		"meta_stats": {"runs": 1, "endings": 0},
	}
	var root: Variant = load("res://ui/screens/hall_view.gd").render({"state": snapshot, "commands": {}}, [])
	assert_not_null(root)
	var texts := _rui_texts(root)
	assert_true(texts.has("蛊路求生"), "hall must keep the game name")
	assert_true(_any_contains(texts, "开始新冒险"), "hall must offer a new run entry")
	assert_true(_any_contains(texts, "图鉴"), "hall must expose codex")
	assert_true(_any_contains(texts, "继续上次冒险"), "hall must expose continue-run")
	assert_true(_any_contains(texts, "血道"), "hall must list school choices")


func test_hall_snapshot_carries_save_flag_and_schools() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	controller.start_new_run(101)
	var snapshot: Dictionary = controller._snapshot_for("Title")
	assert_true(snapshot.has("has_save"))
	assert_true((snapshot.get("available_schools", []) as Array).size() >= 3)


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