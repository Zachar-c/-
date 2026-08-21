class_name EndingView
extends Control


signal restart_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_ending(outcome: Dictionary, journal: Array[Dictionary]) -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "修行札记"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var result := Label.new()
	result.text = "结局：%s" % DisplayText.outcome(str(outcome.get("outcome", "survived_failure")))
	result.add_theme_color_override("font_color", Color("e7c883"))
	column.add_child(result)
	var record := RichTextLabel.new()
	record.bbcode_enabled = true
	record.fit_content = true
	record.custom_minimum_size = Vector2(0, 260)
	record.text = _journal_text(journal)
	column.add_child(record)
	var restart := Button.new()
	restart.text = "重开种子 101"
	restart.custom_minimum_size = Vector2(156, 44)
	restart.tooltip_text = "重新开始固定验证路线"
	restart.pressed.connect(func(): restart_requested.emit())
	column.add_child(restart)


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _journal_text(journal: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for entry in journal:
		lines.append("[b]%s[/b]" % DisplayText.journal_heading(str(entry["heading"])))
		lines.append(DisplayText.journal_body(entry))
		if not entry["visible_facts"].is_empty():
			lines.append("[color=#b8d5cc]%s[/color]" % DisplayText.facts(entry["visible_facts"]))
	return "\n".join(lines)
