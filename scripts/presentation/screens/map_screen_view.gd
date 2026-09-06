class_name MapScreenView
extends MarginContainer
## 地图屏（Godot 官方 .tscn 节点树版，替代 ui/screens/map_screen.guitkx）。
##
## 只读快照 + commands（travel / save_run / to_hall / save_and_to_hall /
## leave_without_save / cancel_to_hall）。拓扑、可达性、层号全部由快照给定，
## 节点坐标是表现层投影，绝不反写状态。
##
## 静态骨架（纸面 / 刊头 / 层标签 / 检视台 / 离局确认）预置在节点树里靠 visible
## 控制；数量不定的内容（节点卡、连线、深度刻度、资源 chip）走代码生成。
## 见 docs/ui/UI_RULES.md §5。

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const GuToastScene := preload("res://scenes/ui/widgets/gu_toast.tscn")
## 路径连线层用 preload 而非 class_name：无头批量跑测试时全局类缓存不一定
## 已扫描到新文件，按名引用会 parse error（本项目其余新组件同理走 preload）。
const MapPathLayerScript = preload("res://scripts/presentation/widgets/map_path_layer.gd")

## 节点类型 → 角标字形 / 中文类别 / 墨色。未知类型落在「? / 未知」。
const NODE_STYLE := {
	"start": {"mark": "起", "kind": "起始", "color": GuStyle.INK_MAP_FAINT},
	"combat": {"mark": "鬥", "kind": "战斗", "color": GuStyle.INK_MAP},
	"pursuit": {"mark": "鬥", "kind": "追击", "color": GuStyle.INK_MAP},
	"event": {"mark": "？", "kind": "异闻", "color": GuStyle.INK_MAP},
	"shop": {"mark": "市", "kind": "黑市", "color": GuStyle.INK_MAP},
	"market": {"mark": "市", "kind": "商队", "color": GuStyle.INK_MAP},
	"caravan": {"mark": "市", "kind": "商队", "color": GuStyle.INK_MAP},
	"rest": {"mark": "息", "kind": "休整", "color": GuStyle.INK_MAP},
	"seclusion": {"mark": "息", "kind": "静修", "color": GuStyle.INK_MAP},
	"cultivation": {"mark": "息", "kind": "修行", "color": GuStyle.INK_MAP},
	"refinement": {"mark": "市", "kind": "炼蛊", "color": GuStyle.INK_MAP},
	"ascension": {"mark": "險", "kind": "突破", "color": GuStyle.INK_MAP},
}
const UNKNOWN_STYLE := {"mark": "?", "kind": "未知", "color": GuStyle.INK_MAP_FAINT}
const ELITE_STYLE := {"mark": "險", "kind": "精英", "color": GuStyle.INK_MAP}

# —— 布局常量：沿用 HTML 主屏的 1280px 拓扑坐标系，镜头只做裁切 ——
const NODE_SIZE := Vector2(192, 126)
const FUTURE_NODE_SIZE := Vector2(168, 108)
const CANDIDATE_Y := 482.0
const FUTURE_Y := 31.0
const CURRENT_Y := 712.0
const LAYER_X_MARGIN := 12.0
const LAYER_X_GAP := 18.0
const DESIGN_WIDTH := 1280.0
const MAX_VISIBLE_ROWS := 3
## 深度刻度三条带（底=当前层、中=下一层、顶=+2 层）。
const DEPTH_BAND_Y := [678.0, 348.0, 18.0]
const DEPTH_BAND_NAMES := ["now", "near", "far"]
## 刊头资源条：material 属蛊囊范畴，按领域约定不上地图 HUD。
const RESOURCE_SPECS := ["yuanstone", "shouyuan", "hunpo"]

@onready var _paper: ColorRect = $map_root/map_paper
@onready var _toast_host: CenterContainer = $map_root/map_toast_host
@onready var _mast_label: Label = $map_root/map_mast/map_mast_label
@onready var _map_resources: HBoxContainer = $map_root/map_mast/map_resources
@onready var _contract_badge: Label = $map_root/map_markers/map_contract_badge
@onready var _anomaly_badge: Label = $map_root/map_markers/map_anomaly_badge
@onready var _zone_label: Label = $map_root/map_title/map_zone_label
@onready var _subtitle_label: Label = $map_root/map_title/map_subtitle_label
@onready var _camera_backdrop: Panel = $map_root/map_camera/map_camera_backdrop
@onready var _depth_rail: Panel = $map_root/map_camera/map_depth
@onready var _map_paths = $map_root/map_camera/map_world/map_routes/map_paths
@onready var _map_nodes: Control = $map_root/map_camera/map_world/map_routes/map_nodes
@onready var _inventory = $map_root/map_inventory
@onready var _inspection_name: Label = $map_root/map_inspector/map_inspector_info/map_inspection_name
@onready var _inspection_note: Label = $map_root/map_inspector/map_inspector_info/map_inspection_note
@onready var _travel_button: Button = $map_root/map_inspector/map_travel_button
@onready var _save_button: Button = $map_root/map_inspector/map_save_button
@onready var _return_button: Button = $map_root/map_inspector/map_return_button
@onready var _leave_confirm_host: Control = $map_root/map_leave_confirm_host
@onready var _leave_panel: PanelContainer = $map_root/map_leave_confirm_host/map_leave_center/map_leave_confirm
@onready var _leave_save_button: Button = $map_root/map_leave_confirm_host/map_leave_center/map_leave_confirm/MarginContainer/VBoxContainer/map_leave_buttons/map_leave_save_button
@onready var _leave_direct_button: Button = $map_root/map_leave_confirm_host/map_leave_center/map_leave_confirm/MarginContainer/VBoxContainer/map_leave_buttons/map_leave_direct_button
@onready var _leave_cancel_button: Button = $map_root/map_leave_confirm_host/map_leave_center/map_leave_confirm/MarginContainer/VBoxContainer/map_leave_buttons/map_leave_cancel_button

var _snapshot: Dictionary = {}
var _commands: Dictionary = {}
## mount_snapshot 可能早于 _ready()（SceneTree 脚本模式），未就绪时只收数据。
var _ready_done := false
## 当前聚焦节点 id（首个可达节点，无可达时回落到当前节点）。
var _selected_id := ""
var _selected: Dictionary = {}
var _submitted_travel_ids: Dictionary = {}


func _ready() -> void:
	_ready_done = true
	_apply_static_theme()
	_wire_static_buttons()
	_refresh()


## run_controller 的挂载入口（与各屏同签名）。
func mount_snapshot(snapshot: Dictionary, commands: Dictionary) -> void:
	_snapshot = snapshot
	_commands = commands
	_submitted_travel_ids.clear()
	if _ready_done:
		_refresh()


## 纸面/徽章/刻度/按钮的调色板全走 GuStyle 令牌：.tscn 只写结构，颜色在这里
## 精确落值（测试按 Color 精确比对，手写 .tscn 的三位小数会差一个 epsilon）。
func _apply_static_theme() -> void:
	_paper.color = GuStyle.PAPER_MAP
	_mast_label.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
	_zone_label.add_theme_color_override("font_color", GuStyle.INK_MAP)
	_zone_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_subtitle_label.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
	_inspection_name.add_theme_color_override("font_color", GuStyle.INK_MAP)
	_inspection_note.add_theme_color_override("font_color", GuStyle.INK_MAP_NOTE)
	for layer_label in [
		$map_root/map_camera/map_world/map_routes/map_layer_label_far,
		$map_root/map_camera/map_world/map_routes/map_layer_label_near,
		$map_root/map_camera/map_world/map_routes/map_layer_label_now,
	]:
		(layer_label as Label).add_theme_color_override("font_color", GuStyle.INK_MAP_LABEL)
	_camera_backdrop.add_theme_stylebox_override("panel", _rail_box(GuStyle.PAPER_MAP, SIDE_TOP))
	_depth_rail.add_theme_stylebox_override("panel", _rail_box(Color(0, 0, 0, 0), SIDE_RIGHT))
	_contract_badge.add_theme_stylebox_override("normal", _badge_box(GuStyle.CONTRACT_BLUE))
	_anomaly_badge.add_theme_stylebox_override("normal", _badge_box(GuStyle.ANOMALY_YELLOW))
	_contract_badge.add_theme_color_override("font_color", GuStyle.CONTRACT_BLUE)
	_anomaly_badge.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_leave_panel.add_theme_stylebox_override("panel", _leave_box())
	# 检视台按钮沿用 HTML 尺寸（action/large = 120x44）：换成 primary 会把
	# 台面撑到 64px，破坏底部 48px 的安静留白带。
	MasterTheme.apply_button(_travel_button, "action", "large")
	MasterTheme.apply_button(_save_button, "action")
	MasterTheme.apply_button(_return_button, "archive")
	MasterTheme.apply_button(_leave_save_button, "primary")
	MasterTheme.apply_button(_leave_direct_button, "action")
	MasterTheme.apply_button(_leave_cancel_button, "cancel")
	_apply_map_atmosphere()


## 地图氛围层：淡青茅山背景 + 暗角，增强南疆卷轴感，不影响地图可读性。
## 地图屏保持浅色命簿纸面（PAPER_MAP），与战斗屏/休整屏的暗色舞台区分。
func _apply_map_atmosphere() -> void:
	# 淡青茅山背景：透明度极低（0.1），只作氛围暗示，不抢地图主体
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/wenzhen/hall/qing-mao-mountain.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = GuStyle.MAP_BACKDROP_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = 0
	_paper.get_parent().add_child(backdrop)
	_paper.get_parent().move_child(backdrop, 1)  # 紧接 map_paper 之后，在其他 UI 之下

	# 暗角层：径向渐变，中心透明四角微暗，增强旧卷轴包围感
	var vignette_grad := Gradient.new()
	vignette_grad.set_color(0, Color(0, 0, 0, 0))
	vignette_grad.set_color(1, Color(0, 0, 0, 0.15))
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = vignette_grad
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.width = 512
	vignette_tex.height = 512
	var vignette := TextureRect.new()
	vignette.texture = vignette_tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 10
	_paper.get_parent().add_child(vignette)


func _wire_static_buttons() -> void:
	_travel_button.pressed.connect(func(): _fire_travel(_selected_id))
	_save_button.pressed.connect(func(): _fire("save_run"))
	_return_button.pressed.connect(func(): _fire("to_hall"))
	_leave_save_button.pressed.connect(func(): _fire("save_and_to_hall"))
	_leave_direct_button.pressed.connect(func(): _fire("leave_without_save"))
	_leave_cancel_button.pressed.connect(func(): _fire("cancel_to_hall"))


func _refresh() -> void:
	if not _ready_done:
		return
	var nodes: Array = _snapshot.get("nodes", [])
	_refresh_resources(_snapshot.get("resources", {}))
	_refresh_markers(_snapshot.get("contracts", []), _snapshot.get("anomalies", []))
	_refresh_title(_snapshot)
	_inventory.setup(_snapshot.get("inventory", {}))
	_refresh_depth_rail(nodes)
	_refresh_world(nodes)
	_refresh_inspector()
	_refresh_toast(str(_snapshot.get("toast", "")))
	_refresh_leave_confirm()


# ---------------------------------------------------------------- 刊头 / 标题

func _refresh_resources(resources: Dictionary) -> void:
	_clear_children(_map_resources)
	for resource_id in RESOURCE_SPECS:
		if not resources.has(resource_id):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_map_resources.add_child(row)
		var res_icon := GuIconView.new()
		res_icon.setup(resource_id, GuStyle.INK_MAP_VALUE, GuIconView.SIZE_SMALL)
		row.add_child(res_icon)
		var value := Label.new()
		value.name = "map_resource_value_" + resource_id
		value.text = str(resources[resource_id])
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", GuStyle.INK_MAP_VALUE)
		row.add_child(value)
		var name_label := Label.new()
		name_label.name = "map_resource_name_" + resource_id
		name_label.text = GuStyle.resource_label(resource_id)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", GuStyle.INK_MAP_NAME)
		row.add_child(name_label)


func _refresh_markers(contracts: Array, anomalies: Array) -> void:
	_contract_badge.text = "契约 · " + ("、".join(_display_list(contracts)) if not contracts.is_empty() else "无")
	_anomaly_badge.text = "异变 · " + _anomaly_label(anomalies)


## R14.6：anomalies 条目是 {id,label} 字典，裸 str() 会把字典结构漏给玩家（§16.5）。
func _anomaly_label(anomalies: Array) -> String:
	if anomalies.is_empty():
		return "无"
	var first: Variant = anomalies[0]
	if first is Dictionary:
		return str((first as Dictionary).get("label", (first as Dictionary).get("id", "险象")))
	return str(first)


func _display_list(items: Array) -> Array:
	var out: Array = []
	for item in items:
		if item is Dictionary:
			var d := item as Dictionary
			out.append(str(d.get("label", d.get("id", ""))))
		else:
			out.append(str(item))
	return out


## P0-4：地带 / 深度 / 境界绑定真实快照；快照没给就留空（旧硬编码假状态不得复活）。
func _refresh_title(state: Dictionary) -> void:
	var parts: Array = []
	var depth_label := str(state.get("depth_label", ""))
	var realm_label := str(state.get("realm_label", ""))
	if depth_label != "":
		parts.append(depth_label)
	if realm_label != "":
		parts.append(realm_label)
	_zone_label.text = str(state.get("zone_title", ""))
	_subtitle_label.text = " · ".join(parts)


# ------------------------------------------------------------------ 深度刻度

## 刻度显示快照里的真实层号，无对应带则不渲染（替代旧的 65/64/63/62 死数字）。
func _refresh_depth_rail(nodes: Array) -> void:
	_clear_children(_depth_rail)
	var layers := _visible_layers(nodes)
	for band_index in layers.size():
		var label := Label.new()
		label.name = "map_depth_label_" + str(DEPTH_BAND_NAMES[band_index])
		label.text = str(int(layers[band_index]))
		label.anchor_right = 1.0
		label.offset_right = -13.0
		label.offset_top = DEPTH_BAND_Y[band_index]
		label.offset_bottom = DEPTH_BAND_Y[band_index] + 18.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
		_depth_rail.add_child(label)


# -------------------------------------------------------------- 镜头 / 拓扑

func _refresh_world(nodes: Array) -> void:
	_clear_children(_map_nodes)
	_clear_children(_map_paths)
	_selected = _selected_node(nodes)
	_selected_id = str(_selected.get("id", ""))
	var layout := _node_layout(nodes)
	var positions: Dictionary = layout["positions"]
	var sizes: Dictionary = layout["sizes"]
	_build_paths(nodes, positions, sizes)
	_build_nodes(nodes, positions, sizes, layout["rows"])


## 可见行（layer*1000+row）最多三行：当前、候选、前瞻。
## 三条带锚定当前节点行：先丢弃早于当前行的非过去行（同层二选一起点
## 里被跳过的兄弟），否则当前节点被挤进中部带、可达后继顶进镜头裁切带
## （FUTURE_Y 在 clip_contents 之外，玩家点不到后继——2026-09-02 阻塞报告）。
func _node_layout(nodes: Array) -> Dictionary:
	var anchor_key := _anchor_row_key(nodes)
	var rows: Array = []
	var by_row: Dictionary = {}
	for node in nodes:
		if str(node.get("visibility", "lookahead")) == "past":
			continue
		var row_key := int(node.get("layer", 0)) * 1000 + int(node.get("row", 0))
		if anchor_key >= 0 and row_key < anchor_key:
			continue
		if not by_row.has(row_key):
			by_row[row_key] = []
			rows.append(row_key)
		(by_row[row_key] as Array).append(node)
	rows.sort()
	if rows.size() > MAX_VISIBLE_ROWS:
		rows = rows.slice(0, MAX_VISIBLE_ROWS)

	var positions := {}
	var sizes := {}
	var route_width := minf(DESIGN_WIDTH, _map_nodes.size.x if _map_nodes.size.x > 0.0 else DESIGN_WIDTH)
	var camera_height := _camera_backdrop.size.y
	var world_top := maxf(0.0, 970.0 - camera_height) if camera_height > 0.0 else 0.0
	for row_index in rows.size():
		var row_nodes: Array = by_row[rows[row_index]]
		var future_row := row_index >= 2
		var row_size := FUTURE_NODE_SIZE if future_row else NODE_SIZE
		var total_width := row_nodes.size() * row_size.x + maxi(0, row_nodes.size() - 1) * LAYER_X_GAP
		var start_x := maxf(LAYER_X_MARGIN, (route_width - total_width) * 0.5)
		var y := FUTURE_Y if future_row else (maxf(CANDIDATE_Y, world_top + 8.0) if row_index == 1 else CURRENT_Y)
		for node_index in row_nodes.size():
			var node: Dictionary = row_nodes[node_index]
			var id := str(node.get("id", ""))
			positions[id] = Vector2(start_x + node_index * (row_size.x + LAYER_X_GAP), y)
			sizes[id] = row_size
	return {"rows": rows, "positions": positions, "sizes": sizes}


func _build_paths(nodes: Array, positions: Dictionary, sizes: Dictionary) -> void:
	var geometry: Array = []
	for node in nodes:
		var origin_id := str(node.get("id", ""))
		if not positions.has(origin_id):
			continue
		for next_id_value in node.get("next_ids", []):
			var next_id := str(next_id_value)
			if not positions.has(next_id):
				continue
			var hot := origin_id == _selected_id or next_id == _selected_id
			var segment := Control.new()
			segment.name = "map_path_segment_%s_%s" % [origin_id, next_id]
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_map_paths.add_child(segment)
			geometry.append({
				"from": positions[origin_id] + Vector2((sizes[origin_id] as Vector2).x * 0.5, 0),
				"to": positions[next_id] + Vector2((sizes[next_id] as Vector2).x * 0.5, (sizes[next_id] as Vector2).y),
				"hot": hot,
			})
	_map_paths.set_segments(geometry)


func _build_nodes(nodes: Array, positions: Dictionary, sizes: Dictionary, rows: Array) -> void:
	for node in nodes:
		var id := str(node.get("id", ""))
		if not positions.has(id):
			continue
		var row_index := rows.find(int(node.get("layer", 0)) * 1000 + int(node.get("row", 0)))
		_map_nodes.add_child(_build_node_button(node, id, positions[id], sizes[id], row_index))


func _build_node_button(node: Dictionary, id: String, position: Vector2, size: Vector2, row_index: int) -> Button:
	var ntype := str(node.get("type", ""))
	var visual: Dictionary = NODE_STYLE.get(ntype, UNKNOWN_STYLE)
	if ntype == "combat" and str(node.get("enemy_kind", "")).contains("elite"):
		visual = ELITE_STYLE
	var reachable := bool(node.get("reachable", false))
	var is_current := str(node.get("visibility", "")) == "current" or bool(node.get("current", false))
	var is_selected := id == _selected_id
	var status := "当前所在" if is_current else ("可前往" if reachable else "已知前路")
	var detail := "可提交行路" if reachable else ("上一层未选道路已隐去" if is_current else "后继可查看")
	var mark_color: Color = visual["color"]

	var button := Button.new()
	button.name = "map_node_" + id
	button.text = ""
	button.position = position
	button.custom_minimum_size = size
	# 绝对定位容器里的 Button 不会自动取 custom_minimum_size，必须显式定尺。
	button.size = size
	_apply_node_style(button, is_current, is_selected, reachable)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(column)

	var mark_row := HBoxContainer.new()
	mark_row.add_theme_constant_override("separation", 9)
	column.add_child(mark_row)
	mark_row.add_child(_build_node_mark(id, str(visual["mark"]), mark_color))
	var title_label := Label.new()
	title_label.text = str(node.get("label", node.get("type", "节点")))
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20 if row_index < 2 else 17)
	title_label.add_theme_color_override("font_color", GuStyle.INK_MAP)
	mark_row.add_child(title_label)

	var kind_label := Label.new()
	kind_label.text = str(visual["kind"]) + " · " + status
	kind_label.add_theme_font_size_override("font_size", 10)
	kind_label.add_theme_color_override("font_color", GuStyle.INK_MAP_FAINT)
	column.add_child(kind_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 9)
	detail_label.add_theme_color_override("font_color", GuStyle.CINNABAR if reachable else GuStyle.INK_MAP_FAINT)
	column.add_child(detail_label)

	# 不可达节点按 HTML 原样保留可点外观，但按下不提交行路命令。
	button.pressed.connect(func():
		if reachable:
			_fire_travel(id))
	return button


## 角标沿用 HTML 的圆框：30x30、圆角 15、1px 墨线。
func _build_node_mark(id: String, glyph: String, color: Color) -> PanelContainer:
	var mark := PanelContainer.new()
	mark.name = "map_node_mark_" + id
	mark.custom_minimum_size = Vector2(30, 30)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	mark.add_theme_stylebox_override("panel", box)
	var center := CenterContainer.new()
	mark.add_child(center)
	var label := Label.new()
	label.name = "map_node_mark_label_" + id
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	center.add_child(label)
	return mark


func _apply_node_style(button: Button, is_current: bool, is_selected: bool, reachable: bool) -> void:
	var role := "node_current" if is_current else ("node_reachable" if reachable else "node_future")
	MasterTheme.apply_button(button, role)
	var normal_bg := Color(0, 0, 0, 0) if is_current else GuStyle.PAPER_MAP
	var border := GuStyle.CINNABAR if (is_current or is_selected) else GuStyle.INK_MAP_FAINT
	var left := 4 if (is_current or is_selected) else GuStyle.HAIRLINE
	button.add_theme_stylebox_override("normal", _node_box(normal_bg, border, left))
	button.add_theme_stylebox_override("hover", _node_box(GuStyle.PAPER_BG, GuStyle.CINNABAR, left))
	button.add_theme_stylebox_override("pressed", _node_box(GuStyle.PAPER_RAISED, GuStyle.CINNABAR, left))
	button.add_theme_stylebox_override("focus", _node_box(normal_bg, GuStyle.CINNABAR, left))


func _node_box(bg: Color, border: Color, left_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.border_width_left = left_width
	box.set_corner_radius_all(4)
	box.set_content_margin(SIDE_LEFT, 12)
	box.set_content_margin(SIDE_RIGHT, 10)
	box.set_content_margin(SIDE_TOP, 9)
	box.set_content_margin(SIDE_BOTTOM, 7)
	return box


# --------------------------------------------------------------- 检视 / 弹层

func _refresh_inspector() -> void:
	var reachable := bool(_selected.get("reachable", false))
	_inspection_name.text = str(_selected.get("label", "尚未选择路线"))
	var note := "此节点可进入，提交前由领域校验行路状态。" if reachable else "查看路线信息；不可达节点不会提交行路命令。"
	_inspection_note.text = str(_selected.get("type", "")) + " · " + note
	_travel_button.visible = reachable and _commands.has("travel")
	_save_button.visible = _commands.has("save_run")
	_return_button.visible = _commands.has("to_hall")


func _refresh_toast(toast_text: String) -> void:
	_clear_children(_toast_host)
	if toast_text == "":
		return
	var toast := GuToastScene.instantiate()
	_toast_host.add_child(toast)
	toast.setup(toast_text, "info")


func _refresh_leave_confirm() -> void:
	_leave_confirm_host.visible = bool(_snapshot.get("leave_confirm", false))


# ------------------------------------------------------------------ 工具

func _visible_layers(nodes: Array) -> Array:
	var anchor_key := _anchor_row_key(nodes)
	var layers: Array = []
	for node in nodes:
		if str(node.get("visibility", "lookahead")) == "past":
			continue
		if anchor_key >= 0 and int(node.get("layer", 0)) * 1000 + int(node.get("row", 0)) < anchor_key:
			continue
		var layer := int(node.get("layer", 0))
		if not layers.has(layer):
			layers.append(layer)
	layers.sort()
	if layers.size() > MAX_VISIBLE_ROWS:
		layers = layers.slice(0, MAX_VISIBLE_ROWS)
	return layers


## 行键锚点：当前节点所在行；无当前节点（trailhead）返回 -1 表示不裁行。
func _anchor_row_key(nodes: Array) -> int:
	for node in nodes:
		if str(node.get("visibility", "")) == "current" or bool(node.get("current", false)):
			return int(node.get("layer", 0)) * 1000 + int(node.get("row", 0))
	return -1


## 焦点节点 = 首个可达节点（按可见层序），无可达时回落到当前节点。
func _selected_node(nodes: Array) -> Dictionary:
	var layers := _visible_layers(nodes)
	var by_layer := {}
	for layer in layers:
		by_layer[layer] = []
	for node in nodes:
		var layer := int(node.get("layer", 0))
		if by_layer.has(layer) and str(node.get("visibility", "lookahead")) != "past":
			(by_layer[layer] as Array).append(node)
	for layer in layers:
		for node in by_layer[layer]:
			if bool((node as Dictionary).get("reachable", false)):
				return node
	for node in nodes:
		if str((node as Dictionary).get("visibility", "")) == "current" or bool((node as Dictionary).get("current", false)):
			return node
	return {}


func _fire(command_name: String) -> void:
	if _commands.has(command_name):
		_commands[command_name].call()


func _fire_travel(node_id: String) -> void:
	if node_id == "" or _submitted_travel_ids.has(node_id) or not _commands.has("travel"):
		return
	_submitted_travel_ids[node_id] = true
	_commands["travel"].call(node_id)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _rail_box(bg: Color, side: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(0)
	box.set_border_width(side, 1)
	return box


## 徽章：左侧 2px 竖线 + 7px 内缩，与契约 / 异变语义色对应。
func _badge_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = color
	box.set_border_width_all(0)
	box.border_width_left = 2
	box.set_content_margin(SIDE_LEFT, 7)
	return box


func _leave_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_BG
	box.border_color = GuStyle.CINNABAR
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	return box
