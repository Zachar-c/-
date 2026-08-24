extends GutTest


func test_controller_shows_title_before_run_then_starts_on_command() -> void:
	var controller: RunController = autofree(preload("res://scripts/presentation/run_controller.gd").new())
	add_child(controller)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(controller.current_view_name(), "Title")
	var title := _find_title_view(controller.get_parent())
	assert_not_null(title)
	_press_text_button(title, "开始游戏")
	await get_tree().process_frame
	assert_eq(controller.current_view_name(), "Map")
	assert_not_null(controller.state)


func test_title_view_exposes_game_name_and_menu() -> void:
	var title: Control = autofree(preload("res://scripts/presentation/title_view.gd").new())
	add_child(title)
	assert_not_null(_find_label_with_text(title, "蛊路求生"))
	assert_not_null(_find_button_with_text(title, "开始游戏"))
	assert_not_null(_find_button_with_text(title, "设定"))


func _find_title_view(root: Node) -> Node:
	if root == null:
		return null
	if is_instance_of(root, load("res://scripts/presentation/title_view.gd")):
		return root
	for child in root.get_children():
		var found := _find_title_view(child)
		if found != null:
			return found
	return null


func _press_text_button(root: Node, text: String) -> void:
	var button := _find_button_with_text(root, text)
	assert_not_null(button)
	(button as Button).pressed.emit()


func _find_label_with_text(root: Node, substring: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Label and (current as Label).text.contains(substring):
			return current
		stack.append_array(current.get_children())
	return null


func _find_button_with_text(root: Node, substring: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Button and (current as Button).text.contains(substring):
			return current
		stack.append_array(current.get_children())
	return null
