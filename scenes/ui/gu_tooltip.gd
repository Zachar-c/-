class_name GuTooltip
extends Control


# Fixed-format tooltip per spec §16.5. Read-only presentation: it only renders
# the data Dictionary it is handed and never mutates any state. The host scene
# adds this as a child and calls show_for(data) / hide_tooltip(). It follows the
# mouse while visible so it never obscures the hovered element.
#
# Expected data keys (all optional except where noted):
#   title   : String  short name shown in gold
#   rarity  : String  one of common/rare/epic/legendary (color-coded)
#   effect  : String  explicit, hardcoded-style effect text
#   linkage : String  explicit synergy / linkage text
#   cost    : String  explicit cost with numbers written out
#   curse   : String  non-empty => strong-red warning line with glyph


const THEME := preload("res://assets/theme/gu_theme.tres")
const UiThemeScript := preload("res://scripts/presentation/components/ui_theme.gd")


var _panel: PanelContainer
var _pending_data: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	theme = THEME
	_panel = PanelContainer.new()
	_panel.theme = THEME
	_panel.add_theme_stylebox_override("panel", _tooltip_stylebox())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.theme = THEME
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.add_theme_constant_override("margin_left", 10)
	column.add_theme_constant_override("margin_right", 10)
	column.add_theme_constant_override("margin_top", 8)
	column.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(column)
	if not _pending_data.is_empty():
		show_for(_pending_data)


func _process(_delta: float) -> void:
	if visible:
		_follow_mouse()


func show_for(data: Dictionary) -> void:
	if _panel == null:
		_pending_data = data.duplicate()
		return
	var column := _panel.get_node_or_null("Column")
	if column == null:
		return
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

	if data.has("title") and not str(data["title"]).is_empty():
		var title := UiThemeScript.label(str(data["title"]), 18, UiThemeScript.GOLD)
		title.add_theme_font_size_override("font_size", 18)
		column.add_child(title)

	if data.has("rarity") and not str(data["rarity"]).is_empty():
		var rarity: String = str(data["rarity"])
		column.add_child(_row("品质", str(rarity), UiThemeScript.rarity_color(rarity)))

	if data.has("effect") and not str(data["effect"]).is_empty():
		column.add_child(_row("效果", str(data["effect"]), UiThemeScript.JADE))

	if data.has("linkage") and not str(data["linkage"]).is_empty():
		column.add_child(_row("联动", str(data["linkage"]), UiThemeScript.JADE))

	if data.has("cost") and not str(data["cost"]).is_empty():
		column.add_child(_row("代价", str(data["cost"]), UiThemeScript.GOLD))

	if data.has("curse") and not str(data["curse"]).is_empty():
		var curse := UiThemeScript.label(
			"%s %s" % [UiThemeScript.CURSE_GLYPH, str(data["curse"])],
			15,
			UiThemeScript.CURSE
		)
		curse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(curse)

	_panel.custom_minimum_size = Vector2(300, 0)
	visible = true
	_follow_mouse()


func hide_tooltip() -> void:
	visible = false


func _exit_tree() -> void:
	_pending_data.clear()
	visible = false


func _row(label_text: String, value: String, color: Color) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.theme = THEME
	row.add_theme_constant_override("separation", 2)
	var key := Label.new()
	key.theme = THEME
	key.text = label_text
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", UiThemeScript.JADE.darkened(0.25))
	row.add_child(key)
	var val := Label.new()
	val.theme = THEME
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", color)
	row.add_child(val)
	return row


func _follow_mouse() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var vp_size := viewport.get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	var pos := get_global_mouse_position() + Vector2(18, 18)
	pos.x = mini(pos.x, vp_size.x - size.x - 4.0)
	pos.y = mini(pos.y, vp_size.y - size.y - 4.0)
	pos = pos.max(Vector2(4.0, 4.0))
	global_position = pos


static func _tooltip_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiThemeScript.BG_DEEP
	sb.border_color = UiThemeScript.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(0)
	return sb
