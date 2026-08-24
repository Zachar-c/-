class_name BattleView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")
const ActionCardRowScript := preload("res://scripts/presentation/action_card_row.gd")


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME


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
		var row := ActionCardRowScript.build(card, 320)
		row.command_submitted.connect(func(cmd: Dictionary): command_submitted.emit(cmd))
		action_row.add_child(row)


func _clear() -> void:
	for child in get_children():
		child.queue_free()


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
