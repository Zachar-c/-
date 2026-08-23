class_name RouteTreeCanvas
extends Control


signal node_selected(node_id: String)


const NODE_SIZE := Vector2(184, 76)
const HORIZONTAL_GAP := 72.0
const VERTICAL_GAP := 30.0
const PADDING := Vector2(34, 32)


var _route: Array[Dictionary] = []
var _state: RunState
var _positions: Dictionary = {}
var _visible_ids := {}


func configure(route: Array[Dictionary], state: RunState) -> void:
	_route = route
	_state = state
	_visible_ids = _visible_id_lookup()
	_positions = _layout_positions(MapGenerator.tree_columns(route))
	_build_buttons()
	queue_redraw()


func _layout_positions(columns: Array[Array]) -> Dictionary:
	var positions := {}
	var largest_column := 1
	for branch in columns:
		var visible_count := 0
		for node in branch:
			if _visible_ids.has(str(node["id"])):
				visible_count += 1
		largest_column = maxi(largest_column, visible_count)
	var content_height := float(largest_column) * NODE_SIZE.y + float(largest_column - 1) * VERTICAL_GAP
	for depth in columns.size():
		var branch: Array = columns[depth]
		var visible_branch: Array = []
		for node in branch:
			if _visible_ids.has(str(node["id"])):
				visible_branch.append(node)
		if visible_branch.is_empty():
			continue
		var branch_height := float(visible_branch.size()) * NODE_SIZE.y + float(visible_branch.size() - 1) * VERTICAL_GAP
		var start_y := PADDING.y + (content_height - branch_height) * 0.5
		for index in visible_branch.size():
			positions[str(visible_branch[index]["id"])] = Vector2(
				PADDING.x + float(depth) * (NODE_SIZE.x + HORIZONTAL_GAP),
				start_y + float(index) * (NODE_SIZE.y + VERTICAL_GAP)
			)
	custom_minimum_size = Vector2(
		PADDING.x * 2.0 + float(maxi(1, _visible_column_count(columns))) * NODE_SIZE.x + float(maxi(0, _visible_column_count(columns) - 1)) * HORIZONTAL_GAP,
		PADDING.y * 2.0 + content_height
	)
	return positions


func _build_buttons() -> void:
	for child in get_children():
		child.queue_free()
	var reachable_ids: Array[String] = []
	for node in MapGenerator.reachable_nodes(_route, _state):
		reachable_ids.append(str(node["id"]))
	for node in _route:
		var node_id := str(node["id"])
		if not _visible_ids.has(node_id) or not _positions.has(node_id):
			continue
		var button := Button.new()
		button.position = _positions[node_id]
		button.size = NODE_SIZE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "进入此处"
		button.text = "%s\n[%s]" % [DisplayText.node(node_id), DisplayText.type(str(node["type"]))]
		button.disabled = not reachable_ids.has(node_id)
		if _state.node_flags.has(node_id):
			button.text += "\n已结算"
		button.pressed.connect(func(): node_selected.emit(node_id))
		add_child(button)


func _draw() -> void:
	if _state == null:
		return
	for node in _route:
		var origin_id := str(node["id"])
		if not _visible_ids.has(origin_id) or not _positions.has(origin_id):
			continue
		for next_id_value in node.get("next_ids", []):
			var next_id := str(next_id_value)
			if not _visible_ids.has(next_id) or not _positions.has(next_id):
				continue
			var is_open := _state.node_flags.has(origin_id)
			var color := Color("5a6966")
			if is_open:
				color = Color("80b8a1")
			var origin_position: Vector2 = _positions[origin_id]
			var next_position: Vector2 = _positions[next_id]
			var from: Vector2 = origin_position + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)
			var to: Vector2 = next_position + Vector2(0, NODE_SIZE.y * 0.5)
			draw_line(from, to, color, 3.0, true)


func _is_discovered(node_id: String) -> bool:
	return _visible_ids.has(node_id)


func _visible_id_lookup() -> Dictionary:
	var ids := {}
	for node_id in MapGenerator.visible_node_ids(_route, _state):
		ids[node_id] = true
	return ids


func _visible_column_count(columns: Array[Array]) -> int:
	var count := 0
	for branch in columns:
		for node in branch:
			if _visible_ids.has(str(node["id"])):
				count += 1
				break
	return count
