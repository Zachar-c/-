class_name ActionCardRowBuilder
extends VBoxContainer


const SELF_SCRIPT := preload("res://scripts/presentation/action_card_row_builder.gd")


signal command_submitted(command: Dictionary)


static func build(card: Dictionary, minimum_width: int = 360, tooltip: Node = null) -> ActionCardRowBuilder:
	var row := SELF_SCRIPT.new()
	row.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.text = str(card.get("title", "行动"))
	button.custom_minimum_size = Vector2(minimum_width, 46)
	button.disabled = not bool(card.get("executable", false))
	if tooltip != null:
		if tooltip.has_method("show_for"):
			button.mouse_entered.connect(func(): tooltip.show_for(_tooltip_data(card)))
		if tooltip.has_method("hide_tooltip"):
			button.mouse_exited.connect(func(): tooltip.hide_tooltip())

	else:
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
	details.text = DisplayText.action_card_details(card)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	details.add_theme_color_override("font_color", GuStyle.JADE if bool(card.get("executable", false)) else GuStyle.CINNABAR)
	row.add_child(details)
	return row


static func _details(card: Dictionary) -> String:
	return DisplayText.action_card_details(card)


static func risk_badge(card: Dictionary) -> String:
	return DisplayText.action_card_risk_badge(card)


static func risk_badge_for_count(count: int) -> String:
	return DisplayText.action_card_risk_badge_for_count(count)


static func _cost_text(cost: Dictionary) -> String:
	return DisplayText.action_card_cost_text(cost)


static func _tooltip(card: Dictionary) -> String:
	if bool(card.get("executable", false)):
		return DisplayText.action_card_details(card)
	var hints: Array = card.get("remedy_hints", [])
	return "%s\n%s" % [str(card.get("block_reason", "条件不足。")), "\n".join(hints)]


static func _tooltip_data(card: Dictionary) -> Dictionary:

	var curse := ""
	for risk in card.get("known_risk", []):
		if str(risk).contains("反噬"):
			curse = "本选择将触发反噬结算，可能损伤气血与魂魄。"
			break
	return {
		"title": str(card.get("title", "行动")),
		"rarity": "",
		"effect": DisplayText.action_card_details(card),
		"linkage": "",
		"cost": DisplayText.action_card_cost_text(card.get("cost", {})),
		"curse": curse,
	}
