class_name TopStatusBar
extends Control


# Persistent horizontal top bar per spec §16.5 (global debuffs + contract effects
# pinned to the top) and §16.4 (DDA / 异变 markers such as 险象 / 衰运).
# Read-only: the host scene pushes lists via set_contracts / set_debuffs / set_dda
# and this component only renders them. Wraps with an HFlowContainer when crowded.


const GuStyleScript := preload("res://scripts/presentation/gu_style.gd")


var _contracts: Array = []
var _debuffs: Array = []
var _dda: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 44)
	var flow := HFlowContainer.new()
	flow.name = "Flow"
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 4)
	flow.add_theme_constant_override("margin_left", 12)
	flow.add_theme_constant_override("margin_right", 12)
	flow.add_theme_constant_override("margin_top", 6)
	flow.add_theme_constant_override("margin_bottom", 6)
	add_child(flow)
	_rebuild()


func set_contracts(list: Array) -> void:
	_contracts = list.duplicate()
	_rebuild()


func set_debuffs(list: Array) -> void:
	_debuffs = list.duplicate()
	_rebuild()


func set_dda(markers: Array) -> void:
	_dda = markers.duplicate()
	_rebuild()


func _rebuild() -> void:
	var flow := get_node_or_null("Flow")
	if flow == null:
		return
	for child in flow.get_children():
		flow.remove_child(child)
		child.queue_free()

	if not _contracts.is_empty():
		flow.add_child(_section_label("契约", GuStyleScript.CONTRACT_BLUE))
		for item in _contracts:
			flow.add_child(_chip(_text(item), GuStyleScript.CONTRACT_BLUE, GuStyleScript.CONTRACT_GLYPH))

	if not _dda.is_empty():
		flow.add_child(_section_label("异变", GuStyleScript.ANOMALY_YELLOW))
		for item in _dda:
			flow.add_child(_chip(_text(item), GuStyleScript.ANOMALY_YELLOW, GuStyleScript.DDA_GLYPH))

	if not _debuffs.is_empty():
		flow.add_child(_section_label("减益", GuStyleScript.CINNABAR))
		for item in _debuffs:
			flow.add_child(_chip(_text(item), GuStyleScript.CINNABAR, GuStyleScript.CURSE_GLYPH))


func _section_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _chip(text: String, color: Color, glyph: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.62)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "%s %s" % [glyph, text] if not glyph.is_empty() else text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	chip.add_child(lbl)
	return chip


static func _text(item: Variant) -> String:
	if item is Dictionary:
		for key in ["label", "name", "text", "title"]:
			if item.has(key) and not str(item[key]).is_empty():
				return str(item[key])
		return ""
	return str(item)
