class_name EncounterView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")
const ActionCardRowScript := preload("res://scripts/presentation/action_card_row.gd")


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME


func render_session(
	node: Dictionary,
	state: RunState,
	session: Dictionary,
	results: Array[Dictionary],
	result: Dictionary,
	action_cards: Array[Dictionary],
	catalog: Dictionary = {}
) -> void:
	_clear()
	var panel := _panel()
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "遭遇：%s" % DisplayText.node(str(node.get("id", "")))
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var notorious := int(state.cultivator.get("notorious", 0))
	var facts := Label.new()
	facts.text = "真元 %d  元石 %d%s已知：%s" % [state.essence, state.stone, ("恶名 %d  " % notorious) if notorious > 0 else "", DisplayText.facts(state.known_facts)]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(facts)
	var summary := str(node.get("summary", ""))
	if not summary.is_empty():
		var summary_label := Label.new()
		summary_label.text = summary
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.add_theme_color_override("font_color", Color("c6d3cf"))
		column.add_child(summary_label)
	if not results.is_empty():
		var history := RichTextLabel.new()
		history.bbcode_enabled = true
		history.fit_content = true
		history.scroll_active = true
		history.custom_minimum_size = Vector2(0, 76)
		history.custom_maximum_size = Vector2(0, 200)
		history.text = _result_history(results)
		column.add_child(history)
	elif not result.is_empty():
		var outcome := Label.new()
		outcome.text = "结果：%s" % DisplayText.result(result)
		outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome.add_theme_color_override("font_color", Color("b8d5cc"))
		column.add_child(outcome)
	if not result.get("actual_changes", []).is_empty():
		var changes := RichTextLabel.new()
		changes.bbcode_enabled = true
		changes.fit_content = true
		changes.text = _actual_change_text(result["actual_changes"])
		column.add_child(changes)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	for card in action_cards:
		var row := ActionCardRowScript.build(card)
		row.command_submitted.connect(func(cmd: Dictionary): command_submitted.emit(cmd))
		actions.add_child(row)
	_append_feeding_footer(column, state, catalog)


func _append_feeding_footer(column: VBoxContainer, state: RunState, catalog: Dictionary) -> void:
	if catalog.is_empty():
		return
	var needed: Dictionary = state.estimate_feeding_materials(catalog)
	var shortage := false
	for material_id in needed:
		if int(state.materials.get(str(material_id), 0)) < int(needed[material_id]):
			shortage = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := Label.new()
	label.text = "本节点养护：%s" % _feeding_text(needed, state.materials)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var button := Button.new()
	button.text = "结清养护"
	button.custom_minimum_size = Vector2(140, 34)
	button.disabled = not shortage
	button.tooltip_text = "以现有材料结清本节点蛊虫养护；材料不足时蛊虫会虚弱甚至死亡。" if shortage else "当前材料足以覆盖养护。"
	button.pressed.connect(func(): command_submitted.emit({"type": "settle_node_feeding"}))
	row.add_child(button)


func _feeding_text(needed: Dictionary, owned: Dictionary) -> String:
	var parts: Array[String] = []
	for material_id in needed:
		parts.append("%s %d/%d" % [DisplayText.material(str(material_id)), int(owned.get(str(material_id), 0)), int(needed[material_id])])
	return "、".join(parts) if not parts.is_empty() else "无"


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


func _result_history(results: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for entry in results:
		lines.append("[color=#b8d5cc]%s[/color]" % _result_text(entry))
	return "\n".join(lines)


func _result_text(entry: Dictionary) -> String:
	match str(entry.get("text_key", "")):
		"node_entered": return "你踏入此地，局势尚未收束。"
		"node_left": return "你主动收手，离开了此处。"
		"reputation_hostile_stance": return "对方神情不善，敌意已难以遮掩。"
		"reputation_extreme_stance": return "对方与你已是不共戴天，唯有死战。"
		"contact_deceive_success": return "你的说辞暂时骗过了散修，得手两枚元石。"
		"contact_negotiate_result": return "散修松了口风，透露商队愿意给熟人让价。"
		"contact_fight_started": return "对方没有再听你说话，已经摆出斗蛊架势。"
		"caravan_buy_result": return "交易落定，商队把蛊虫交到你手中。"
		"caravan_sell_result": return "商队验过蛊虫，按价收下。"
		"caravan_exchange_result": return "双方的蛊虫完成交换，关系还未结束。"
		"refinement_result": return "炉火已起，炼制结果记入行迹。"
		"cultivation_result": return "你调整气息，修行所得已稳住。"
		"lifespan_milestone_gained": return "寿元见长：里程碑入账十载。"
		"stance_flipped_hostile": return "交涉失败，对方翻脸成仇。"
		"aptitude_raised": return "洗髓功成，根骨重塑。"
		"battle_loot": return "此战缴获：%s。" % str(entry.get("changes", {}).get("loot_display", "些许材料"))
		"action_rejected": return "此举条件不足，局势没有改变。"
		_: return "行动已留下结果，你仍可继续处置此地。"


func _actual_change_text(changes: Array) -> String:
	var lines: Array[String] = []
	for change in changes:
		lines.append(str(change.get("message", "局势发生变化。")))
	return "[color=#b8d5cc]结算：%s[/color]" % " ".join(lines)
