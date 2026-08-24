class_name ActionCardRow
extends VBoxContainer


const SELF_SCRIPT := preload("res://scripts/presentation/action_card_row.gd")


# Shared presentation of one domain action card. Read-only: emits only the
# card's command through command_submitted. Never mutates state.


signal command_submitted(command: Dictionary)


static func build(card: Dictionary, minimum_width: int = 360) -> ActionCardRow:
	var row := SELF_SCRIPT.new()
	row.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.text = str(card.get("title", "行动"))
	button.custom_minimum_size = Vector2(minimum_width, 46)
	button.disabled = not bool(card.get("executable", false))
	button.tooltip_text = _tooltip(card)
	button.pressed.connect(func():
		button.disabled = true
		row.command_submitted.emit({
			"type": "action_card",
			"action_id": str(card["id"]),
			"state_version": int(card["state_version"]),
		}))
	row.add_child(button)
	var details := Label.new()
	details.text = _details(card)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	details.add_theme_color_override("font_color", Color("d7c6a1") if bool(card.get("executable", false)) else Color("c28f8f"))
	row.add_child(details)
	return row


static func _details(card: Dictionary) -> String:
	var lines: Array[String] = []
	var cost := _cost_text(card.get("cost", {}))
	if not cost.is_empty():
		lines.append("代价：%s" % cost)
	if card.get("success_rate", null) != null:
		lines.append("成功率：%d%%" % int(card["success_rate"]))
	for gain in card.get("expected_gain", []):
		lines.append("收益：%s" % str(gain))
	var risks: Array = card.get("known_risk", [])
	if not risks.is_empty():
		lines.append("风险[%s]：%s" % [risk_badge(card), "；".join(_stringify_all(risks))])
	if not str(card.get("unknown_note", "")).is_empty():
		lines.append("未知：%s" % str(card["unknown_note"]))
	if not bool(card.get("executable", false)):
		lines.append("受阻：%s" % str(card.get("block_reason", "条件不足。")))
		for hint in card.get("remedy_hints", []):
			lines.append("途径：%s" % str(hint))
	return "\n".join(lines)


static func risk_badge(card: Dictionary) -> String:
	return risk_badge_for_count(int((card.get("known_risk", []) as Array).size()))


static func risk_badge_for_count(count: int) -> String:
	if count <= 0:
		return "低"
	if count <= 2:
		return "中"
	return "高"


static func _stringify_all(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _cost_text(cost: Dictionary) -> String:
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
		var names: Array[String] = []
		for gu_id in cost["gu_ids"]:
			names.append(DisplayText.gu(str(gu_id)))
		items.append("输入蛊 %s" % "、".join(names))
	return "、".join(items)


static func _tooltip(card: Dictionary) -> String:
	if bool(card.get("executable", false)):
		return _details(card)
	var hints: Array = card.get("remedy_hints", [])
	return "%s\n%s" % [str(card.get("block_reason", "条件不足。")), "\n".join(hints)]
