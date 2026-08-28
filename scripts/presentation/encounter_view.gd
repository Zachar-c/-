class_name EncounterView
extends Control



const ActionCardRowScript := preload("res://scripts/presentation/action_card_row_builder.gd")


# Shared tooltip instance (Rule #3): created once at top level per render and
# reused for every option/footer hover. Freed with the view via queue_free().
var _tooltip: GuTooltip


signal command_submitted(command: Dictionary)
signal option_chosen(option_id: String)
signal dangerous_option_confirmed(option_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render_session(
	node: Dictionary,
	state: RunState,
	_session: Dictionary,
	results: Array[Dictionary],
	result: Dictionary,
	action_cards: Array[Dictionary],
	catalog: Dictionary = {}
) -> void:
	_clear()
	_tooltip = GuTooltip.new()
	var panel := _panel()
	add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 24)
	panel.add_child(hbox)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	hbox.add_child(scroll)

	var status_panel := _build_status_panel(state)
	status_panel.custom_minimum_size = Vector2(240, 0)
	status_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_child(status_panel)

	var title := Label.new()
	title.text = "遭遇：%s" % DisplayText.node(str(node.get("id", "")))
	title.add_theme_font_size_override("font_size", 26)
	left.add_child(title)
	var notorious := int(state.cultivator.get("notorious", 0))
	var facts := Label.new()
	facts.text = "真元 %d  元石 %d%s已知：%s" % [state.essence, state.stone, ("恶名 %d  " % notorious) if notorious > 0 else "", DisplayText.facts(state.known_facts)]
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(facts)
	var summary := str(node.get("summary", ""))
	if not summary.is_empty():
		var summary_label := Label.new()
		summary_label.text = summary
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		left.add_child(summary_label)
	if not results.is_empty():
		var history := RichTextLabel.new()
		history.bbcode_enabled = true
		history.fit_content = true
		history.scroll_active = true
		history.custom_minimum_size = Vector2(0, 76)
		history.custom_maximum_size = Vector2(0, 200)
		history.text = _result_history(results)
		left.add_child(history)
	elif not result.is_empty():
		var outcome := Label.new()
		outcome.text = "结果：%s" % DisplayText.result(result)
		outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome.add_theme_color_override("font_color", GuStyle.JADE)
		left.add_child(outcome)
	if not result.get("actual_changes", []).is_empty():
		var changes := RichTextLabel.new()
		changes.bbcode_enabled = true
		changes.fit_content = true
		changes.text = _actual_change_text(result["actual_changes"])
		left.add_child(changes)

	var actions_scroll := ScrollContainer.new()
	actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(actions_scroll)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	actions_scroll.add_child(actions)
	for card in action_cards:
		var row := ActionCardRowScript.build(card, 360, _tooltip)
		row.command_submitted.connect(func(cmd: Dictionary): command_submitted.emit(cmd))
		var option_id := str(card.get("id", ""))
		option_chosen.emit(option_id)
		if _is_dangerous(card):
			dangerous_option_confirmed.emit(option_id)
		actions.add_child(row)
	_append_feeding_footer(left, state, catalog)
	# Added last so it draws on top of the panel (Control has no raise() in Godot 4).
	add_child(_tooltip)


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
	button.mouse_entered.connect(func(): _tooltip.show_for({
		"title": "结清养护",
		"rarity": "",
		"effect": "以现有材料结清本节点蛊虫养护；材料不足时蛊虫会虚弱甚至死亡。" if shortage else "当前材料足以覆盖养护。",
		"linkage": "",
		"cost": "",
		"curse": "",
	}))
	button.mouse_exited.connect(func(): _tooltip.hide_tooltip())
	button.pressed.connect(func(): command_submitted.emit({"type": "settle_node_feeding"}))
	row.add_child(button)


func _feeding_text(needed: Dictionary, owned: Dictionary) -> String:
	var parts: Array[String] = []
	for material_id in needed:
		parts.append("%s %d/%d" % [DisplayText.material(str(material_id)), int(owned.get(str(material_id), 0)), int(needed[material_id])])
	return "、".join(parts) if not parts.is_empty() else "无"


func _build_status_panel(state: RunState) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	var header := Label.new()
	header.text = "自身状态"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	panel.add_child(header)
	var health := int(state.cultivator.get("health", state.health))
	var max_health := int(state.cultivator.get("max_health", state.max_health))
	_add_stat_bar(panel, "生命", health, max_health, GuStyle.JADE)
	_add_stat_bar(panel, "真元", state.essence, state.essence_capacity, GuStyle.JADE)
	var lifespan := int(state.cultivator.get("lifespan", 0))
	_add_stat_bar(panel, "寿元", lifespan, maxi(lifespan, 1), GuStyle.ANOMALY_YELLOW)
	var soul := int(state.cultivator.get("soul", 0))
	var soul_max := int(state.cultivator.get("soul_max", soul))
	_add_stat_bar(panel, "魂魄", soul, maxi(soul_max, 1), GuStyle.JADE)
	_add_stat_bar(panel, "元石", int(state.stone), maxi(int(state.stone), 1), GuStyle.ANOMALY_YELLOW)
	var notorious := int(state.cultivator.get("notorious", 0))
	_add_stat_bar(panel, "恶名", notorious, maxi(notorious, 1), GuStyle.CINNABAR if notorious > 0 else GuStyle.JADE)
	return panel


# Rule #3: reuse the shared StatBar instead of plain labels. configure() once;
# set_value() whenever the read-only snapshot changes (here per render).
func _add_stat_bar(panel: VBoxContainer, label: String, current: int, maximum: int, color: Color) -> void:
	var bar := StatBar.new()
	panel.add_child(bar)
	bar.configure(label, current, maximum, color)


# Rule #1 (death-foreseeable): an option is dangerous when it costs 寿元/魂魄
# or its known risk mentions 反噬. The UI surfaces this via dangerous_option_confirmed.
func _is_dangerous(card: Dictionary) -> bool:
	var cost: Dictionary = card.get("cost", {})
	if int(cost.get("lifespan", 0)) > 0:
		return true
	if int(cost.get("soul", 0)) > 0:
		return true
	var risk := str(card.get("known_risk", ""))
	return "反噬" in risk or "魂魄" in risk or "寿元" in risk


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
