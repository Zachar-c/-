class_name RouteTreeCanvas
extends Control


signal node_selected(node_id: String)




const NODE_SIZE := Vector2(184, 84)
const HORIZONTAL_GAP := 72.0
const VERTICAL_GAP := 30.0
const PADDING := Vector2(34, 32)
const FOCUSED_FORWARD_LAYERS := 2

# Shared tooltip host injected by MapView. On hover we call show_for/hide_tooltip
# on it instead of building a bespoke String tooltip (Rule #3).
var tooltip: GuTooltip


func _ready() -> void:


var _route: Array[Dictionary] = []
var _state: RunState
var _positions: Dictionary = {}
var _visible_ids := {}
var _empty_pool_ids: Array[String] = []


func configure(route: Array[Dictionary], state: RunState, empty_pool_ids: Array[String] = []) -> void:
	_route = route
	_state = state
	_empty_pool_ids = empty_pool_ids
	_visible_ids = _visible_id_lookup()
	_positions = _layout_positions(MapGenerator.tree_columns(route))
	_build_buttons()
	queue_redraw()


func focused_visible_nodes() -> Array[Dictionary]:
	# The RUI map master consumes this same read-only projection. Keep the
	# legacy canvas aligned without changing map reachability or route state.
	return MapGenerator.visible_nodes(_route, _state, FOCUSED_FORWARD_LAYERS)


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


# Per node-type visual identity. The dispatched 8 categories from the design
# (战斗/精英/事件/商店/黑市/休整/突破/结算) are covered here together with the
# remaining encounter kinds, so every generated node is visually distinguishable.
const NODE_STYLE := {
	"combat": {"label": "战", "text": "战斗", "color": "ff5a4d"},
	"pursuit": {"label": "追", "text": "追击", "color": "ff5a4d"},
	"event": {"label": "象", "text": "异象", "color": "b8d5cc"},
	"shop": {"label": "黑", "text": "黑市", "color": "c0152f"},
	"market": {"label": "市", "text": "市集", "color": "5a8bd6"},
	"seclusion": {"label": "息", "text": "静修", "color": "8fbf9f"},
	"rest": {"label": "息", "text": "歇息", "color": "8fbf9f"},
	"cultivation": {"label": "修", "text": "修行", "color": "8fbf9f"},
	"ascension": {"label": "仙", "text": "升仙", "color": "e7c883"},
	"refinement": {"label": "炼", "text": "炼蛊", "color": "d8a657"},
	"inheritance": {"label": "承", "text": "传承", "color": "c9a0dc"},
	"caravan": {"label": "队", "text": "商队", "color": "5a8bd6"},
	"contact": {"label": "触", "text": "接触", "color": "9fb6c9"},
	"hazard": {"label": "险", "text": "险地", "color": "ff7766"},
	"earth_vein": {"label": "脉", "text": "地脉", "color": "a0d8c0"},
	"ledger": {"label": "账", "text": "总账", "color": "e7c883"},
	"wild_gu": {"label": "野", "text": "野蛊", "color": "c2b280"},
}


func _style_for(node: Dictionary) -> Dictionary:
	var type := str(node.get("type", ""))
	var style: Dictionary = NODE_STYLE.get(type, {"label": "?", "text": "未知", "color": "b8d5cc"})
	# Elite override: a pursuit/combat node backed by an elite enemy reads as 精英.
	var elite := str(node.get("enemy_kind", "")) in ["resolute_elite", "thunder_crown_wolf"]
	if elite and type in ["combat", "pursuit"]:
		style = {"label": "精", "text": "精英", "color": "ff8c1a"}
	# Boss override: the ascension-gate boss is its own marker.
	if str(node.get("id", "")) == "final_boss_stand":
		style = {"label": "决", "text": "决战", "color": "ff3b30"}
	return style


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
		var style: Dictionary = _style_for(node)
		var is_endpoint := str(node.get("type", "")) == "ascension"
		var is_reachable := reachable_ids.has(node_id)
		var text := "%s  %s\n%s" % [style["label"], DisplayText.node(node_id), style["text"]]
		if is_endpoint:
			text += "\n（终点·统一结算）"
		elif _state.node_flags.has(node_id):
			text += "\n已结算"
		button.text = text
		button.disabled = not is_reachable
		button.modulate.a = 1.0 if is_reachable else 0.45
		button.add_theme_color_override("font_color", Color(style["color"]))
		button.pressed.connect(func(): node_selected.emit(node_id))
		# Hover shows the shared GuTooltip; Callable auto-disconnects when the
		# button is freed on the next _build_buttons pass (Rule #4).
		var tooltip_data := _tooltip_data(node, style, is_endpoint, is_reachable)
		button.mouse_entered.connect(func():
			if tooltip != null:
				tooltip.show_for(tooltip_data))
		button.mouse_exited.connect(func():
			if tooltip != null:
				tooltip.hide_tooltip())
		add_child(button)
		if _empty_pool_ids.has(node_id):
			var hint := Label.new()
			hint.position = _positions[node_id] + Vector2(0, NODE_SIZE.y + 2)
			hint.size = Vector2(NODE_SIZE.x, 18)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.text = "（空池·已回退）"
			hint.add_theme_color_override("font_color", Color("8a8a8a"))
			hint.add_theme_font_size_override("font_size", 12)
			add_child(hint)


# Maps the former fixed fields 类型/地点/可选行动/风险/状态 onto the shared
# GuTooltip fixed format (title/rarity/effect/linkage/cost/curse). Pure read of
# node + state; returns the data Dictionary consumed by GuTooltip.show_for.
func _tooltip_data(node: Dictionary, style: Dictionary, is_endpoint: bool, is_reachable: bool) -> Dictionary:
	var node_id := str(node["id"])
	var choices: Array = node.get("choices", [])
	var choices_text: String
	if choices.is_empty():
		choices_text = "进入即触发"
	else:
		var labels: Array[String] = []
		for choice in choices:
			labels.append(DisplayText.action(str(choice)))
		choices_text = "、".join(labels)
	var risk := "无额外风险"
	if str(node.get("type", "")) in ["combat", "pursuit", "hazard", "earth_vein"]:
		risk = "可能受伤或招致追击"
	elif is_endpoint:
		risk = "终极结算，一锤定音"
	var status := "未结算"
	if is_endpoint:
		status = "终点"
	elif _state.node_flags.has(node_id):
		status = "已结算"
	elif not is_reachable:
		status = "未抵达"
	var title := DisplayText.node(node_id)
	if status != "未结算":
		title += "（%s）" % status
	return {
		"title": title,
		"rarity": "",
		"effect": "类型：%s（%s）" % [style["text"], style["label"]],
		"linkage": choices_text,
		"cost": risk,
		"curse": "",
	}


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
