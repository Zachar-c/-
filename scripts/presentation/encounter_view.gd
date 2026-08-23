class_name EncounterView
extends Control


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render_session(
	node: Dictionary,
	state: RunState,
	session: Dictionary,
	results: Array[Dictionary],
	result: Dictionary,
	action_cards: Array[Dictionary]
) -> void:
	_clear()
	var panel := _panel()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "遭遇：%s" % DisplayText.node(str(node.get("id", "")))
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var facts := Label.new()
	facts.text = "真元 %d  元石 %d  已知：%s" % [state.essence, state.stone, DisplayText.facts(state.known_facts)]
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
		history.custom_minimum_size = Vector2(0, 76)
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
		_add_action_card(actions, card)


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
		"contact_deceive_success": return "你的说辞暂时骗过了散修，得手两枚元石。"
		"contact_negotiate_result": return "散修松了口风，透露商队愿意给熟人让价。"
		"contact_fight_started": return "对方没有再听你说话，已经摆出斗蛊架势。"
		"caravan_buy_result": return "交易落定，商队把蛊虫交到你手中。"
		"caravan_sell_result": return "商队验过蛊虫，按价收下。"
		"caravan_exchange_result": return "双方的蛊虫完成交换，关系还未结束。"
		"refinement_result": return "炉火已起，炼制结果记入行迹。"
		"cultivation_result": return "你调整气息，修行所得已稳住。"
		"action_rejected": return "此举条件不足，局势没有改变。"
		_: return "行动已留下结果，你仍可继续处置此地。"


func _add_action_card(container: VBoxContainer, card: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	container.add_child(row)
	var button := Button.new()
	button.text = str(card.get("title", "行动"))
	button.custom_minimum_size = Vector2(360, 42)
	button.disabled = not bool(card.get("executable", false))
	button.tooltip_text = _card_tooltip(card)
	button.pressed.connect(func(): command_submitted.emit({
		"type": "action_card",
		"action_id": str(card["id"]),
		"state_version": int(card["state_version"]),
	}))
	row.add_child(button)
	var details := Label.new()
	details.text = _card_details(card)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	details.add_theme_color_override("font_color", Color("d7c6a1") if bool(card.get("executable", false)) else Color("c28f8f"))
	row.add_child(details)


func _card_details(card: Dictionary) -> String:
	var lines: Array[String] = []
	var cost := _cost_text(card.get("cost", {}))
	if not cost.is_empty():
		lines.append("代价：%s" % cost)
	if card.get("success_rate", null) != null:
		lines.append("成功率：%d%%" % int(card["success_rate"]))
	for gain in card.get("expected_gain", []):
		lines.append("收益：%s" % str(gain))
	for risk in card.get("known_risk", []):
		lines.append("风险：%s" % str(risk))
	if not str(card.get("unknown_note", "")).is_empty():
		lines.append("未知：%s" % str(card["unknown_note"]))
	if not bool(card.get("executable", false)):
		lines.append("受阻：%s" % str(card.get("block_reason", "条件不足。")))
		for hint in card.get("remedy_hints", []):
			lines.append("途径：%s" % str(hint))
	return "\n".join(lines)


func _card_tooltip(card: Dictionary) -> String:
	if bool(card.get("executable", false)):
		return _card_details(card)
	var hints: Array = card.get("remedy_hints", [])
	return "%s\n%s" % [str(card.get("block_reason", "条件不足。")), "\n".join(hints)]


func _cost_text(cost: Dictionary) -> String:
	var items: Array[String] = []
	if cost.has("stone"):
		items.append("元石 %d" % int(cost["stone"]))
	if cost.has("spirit"):
		items.append("真元 %d" % int(cost["spirit"]))
	if cost.has("time"):
		items.append("时机 %d" % int(cost["time"]))
	if cost.has("lifespan"):
		items.append("寿元 %d" % int(cost["lifespan"]))
	if cost.has("hp"):
		items.append("气血 %d" % int(cost["hp"]))
	if cost.has("gu_ids"):
		var gu_names: Array[String] = []
		for gu_id in cost["gu_ids"]:
			gu_names.append(DisplayText.gu(str(gu_id)))
		items.append("输入蛊 %s" % "、".join(gu_names))
	return "、".join(items)


func _actual_change_text(changes: Array) -> String:
	var lines: Array[String] = []
	for change in changes:
		lines.append(str(change.get("message", "局势发生变化。")))
	return "[color=#b8d5cc]结算：%s[/color]" % " ".join(lines)
