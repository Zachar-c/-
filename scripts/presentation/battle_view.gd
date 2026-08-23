class_name BattleView
extends Control


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render(battle: Dictionary, state: RunState, catalog: Dictionary, action_cards: Array[Dictionary]) -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "交锋：%s" % DisplayText.enemy(str(battle.get("enemy_kind", "")))
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var status := Label.new()
	status.text = "你：气血 %d/%d  真元 %d    敌：气力 %d/%d  回合 %d" % [state.health, state.max_health, state.essence, battle.get("enemy_hp", 0), battle.get("enemy_max_hp", 0), battle.get("turn", 0)]
	status.add_theme_color_override("font_color", Color("e7c883"))
	column.add_child(status)
	var intent := Label.new()
	intent.text = "敌方意图：%s" % str(battle.get("visible_intent", {}).get("label", "正在观察"))
	intent.add_theme_color_override("font_color", Color("e8b4a4"))
	column.add_child(intent)
	var clues := Label.new()
	clues.text = "可见征兆：%s" % _clue_text(battle.get("clues", []))
	clues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(clues)
	if not battle.get("log", []).is_empty():
		var log := RichTextLabel.new()
		log.bbcode_enabled = true
		log.fit_content = true
		log.custom_minimum_size = Vector2(0, 94)
		log.text = _battle_log(battle.get("log", []))
		column.add_child(log)
	var action_row := VBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	for card in action_cards:
		_add_action_button(action_row, card)


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _add_action_button(row: VBoxContainer, card: Dictionary) -> void:
	var button := Button.new()
	button.text = str(card.get("title", "行动"))
	button.custom_minimum_size = Vector2(280, 42)
	button.disabled = not bool(card.get("executable", false))
	button.tooltip_text = _card_tooltip(card)
	button.pressed.connect(func(): command_submitted.emit({"type": "action_card", "action_id": card["id"], "state_version": card["state_version"]}))
	row.add_child(button)
	var details := Label.new()
	details.text = _card_tooltip(card)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	row.add_child(details)


func _card_tooltip(card: Dictionary) -> String:
	var lines: Array[String] = []
	if card.get("cost", {}).has("spirit"):
		lines.append("消耗真元 %d" % int(card["cost"]["spirit"]))
	for gain in card.get("expected_gain", []):
		lines.append("效果：%s" % str(gain))
	for risk in card.get("known_risk", []):
		lines.append("风险：%s" % str(risk))
	if not str(card.get("unknown_note", "")).is_empty():
		lines.append("未知：%s" % str(card["unknown_note"]))
	if not bool(card.get("executable", false)):
		lines.append("受阻：%s" % str(card.get("block_reason", "条件不足。")))
	return "\n".join(lines)


func _clue_text(clues: Array) -> String:
	var labels: Array[String] = []
	for clue in clues:
		match str(clue):
			"stone_dust": labels.append("脚下石粉")
			"steady_stance": labels.append("站姿沉稳")
			"lowered_shoulders": labels.append("伏低肩势")
			"wet_fang": labels.append("湿亮獠牙")
			_: labels.append("异样气息")
	return "、".join(labels) if not labels.is_empty() else "暂未发现"


func _battle_log(entries: Array) -> String:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("[color=#b8d5cc]%s[/color]" % _log_line(entry))
	return "\n".join(lines)


func _log_line(entry: Dictionary) -> String:
	match str(entry.get("id", "")):
		"intent_revealed": return "对方的攻势已显露。"
		"light_reveal": return "小光蛊照亮了对方的细微异状。"
		"thorn_bind": return "棘鞭缠住了对方的手脚。"
		"thorn_strike": return "棘鞭抽实，对方气力受损。"
		"stone_shell": return "石粉聚甲，攻势被挡住。"
		"stone_guard": return "石甲覆身，先护住要害。"
		"pounce": return "敌手伏身扑咬，伤害已经结算。"
		"stone_palm": return "敌手一掌拍下，伤害已经结算。"
		"retreated": return "你抓住空当撤出了交锋。"
		_: return "战局发生了一次变化。"
