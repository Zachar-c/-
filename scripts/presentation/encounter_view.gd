class_name EncounterView
extends Control


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render(node: Dictionary, state: RunState, result: Dictionary) -> void:
	_clear()
	var panel := _panel()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "遭遇：%s" % str(node.get("id", "未知"))
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var facts := Label.new()
	facts.text = "真元 %d  元石 %d  已知：%s" % [state.essence, state.stone, ", ".join(state.known_facts)]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(facts)
	if not result.is_empty():
		var outcome := Label.new()
		outcome.text = "结果：%s" % str(result)
		outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome.add_theme_color_override("font_color", Color("b8d5cc"))
		column.add_child(outcome)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	for action_id in node.get("choices", []):
		var button := Button.new()
		button.text = str(action_id)
		button.custom_minimum_size = Vector2(112, 42)
		button.tooltip_text = "执行此路径"
		button.pressed.connect(func(): command_submitted.emit(_command_for(node, str(action_id))))
		actions.add_child(button)
	var leave := Button.new()
	leave.text = "返回路线"
	leave.custom_minimum_size = Vector2(112, 42)
	leave.tooltip_text = "离开当前遭遇"
	leave.pressed.connect(func(): command_submitted.emit({"type": "leave_encounter"}))
	column.add_child(leave)


func _command_for(node: Dictionary, action_id: String) -> Dictionary:
	if node.get("type", "") == "caravan":
		var command := {"type": "choose_action", "npc_id": "caravan_steward", "action_id": action_id}
		if action_id == "trade":
			command["offer"] = "ledger_evidence"
		return command
	if node.get("type", "") == "ascension" and action_id == "attempt_ascension":
		return {"type": "attempt_ascension", "choice": "now"}
	return {"type": "choose_action", "action_id": action_id}


func _panel() -> MarginContainer:
	var panel := MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 48)
	panel.add_theme_constant_override("margin_right", 48)
	panel.add_theme_constant_override("margin_top", 48)
	panel.add_theme_constant_override("margin_bottom", 48)
	return panel


func _clear() -> void:
	for child in get_children():
		child.queue_free()
