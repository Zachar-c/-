class_name EndingView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")


signal restart_requested
signal return_to_hall_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME


func show_ending(outcome: Dictionary, journal: Array[Dictionary], run_data: Dictionary = {}) -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := UiTheme.label("修行札记", 30, Color("e7c883"))
	column.add_child(title)
	column.add_child(UiTheme.label("结局：%s" % DisplayText.outcome(str(outcome.get("outcome", "survived_failure"))), 18, Color("e7c883")))
	_add_recap(column, run_data)
	var record := RichTextLabel.new()
	record.bbcode_enabled = true
	record.fit_content = true
	record.custom_minimum_size = Vector2(0, 220)
	record.text = _journal_text(journal)
	column.add_child(record)
	var back := UiTheme.button("返回大厅", true)
	back.custom_minimum_size = Vector2(200, 44)
	back.tooltip_text = "回到大厅，可继续上次冒险或开启新局。"
	back.pressed.connect(func(): return_to_hall_requested.emit())
	column.add_child(back)


func show_death(report: Dictionary) -> void:
	_clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := UiTheme.label("身死道消", 30, Color("e7c883"))
	column.add_child(title)
	var blow := UiTheme.label("最后一击：%s（%d 点伤害）" % [_blow_text(str(report.get("final_blow", ""))), int(report.get("damage", 0))], 16, Color("e7c883"))
	column.add_child(blow)
	var facts := UiTheme.label("你已看见：%s" % _facts_text(report.get("known_facts", [])), 16, Color("b8d5cc"))
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(facts)
	var taunt := UiTheme.label("“%s”" % str(report.get("taunt", "")), 16, Color("b8d5cc"))
	taunt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(taunt)
	var back := UiTheme.button("返回大厅", true)
	back.custom_minimum_size = Vector2(200, 44)
	back.tooltip_text = "回到大厅，可继续上次冒险或开启新局。"
	back.pressed.connect(func(): return_to_hall_requested.emit())
	column.add_child(back)


func _add_recap(column: VBoxContainer, run_data: Dictionary) -> void:
	var items: Array[String] = []
	items.append("最高修为 / 转数：%s / %s" % [str(run_data.get("cultivation", "-")), str(run_data.get("stage", "-"))])
	items.append("流派：%s" % str(run_data.get("school", "未定")))
	items.append("关键节点轨迹：%s" % _route_text(run_data.get("route_progress", [])))
	var stone := int(run_data.get("stone", 0))
	var codex: Array = run_data.get("global_codex_ids", [])
	items.append("资产结余：元石 %d · 图鉴解锁 %d" % [stone, codex.size()])
	for item in items:
		var lbl := UiTheme.label(item, 15, Color("b8d5cc"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(lbl)


func _route_text(route_progress: Array) -> String:
	if route_progress.is_empty():
		return "无"
	var names: Array[String] = []
	for node_id in route_progress:
		names.append(DisplayText.node(str(node_id)))
	return " → ".join(names)


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


func _blow_text(id: String) -> String:
	match id:
		"stone_palm": return "石掌"
		"pounce": return "伏身扑咬"
		_: return "敌手攻势"


func _facts_text(facts: Array) -> String:
	var labels: Array[String] = []
	for fact in facts:
		match str(fact):
			"stone_dust": labels.append("脚下石粉")
			"steady_stance": labels.append("稳固站姿")
			"stone_shell": labels.append("石甲护身")
			"lowered_shoulders": labels.append("伏低肩势")
			"wet_fang": labels.append("湿亮獠牙")
			_: labels.append("已见战局")
	return "、".join(labels) if not labels.is_empty() else "无"
