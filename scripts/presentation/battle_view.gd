class_name BattleView
extends Control


const THEME := preload("res://assets/theme/gu_theme.tres")
const ActionCardRowScript := preload("res://scripts/presentation/action_card_row.gd")
const ResourceIconScript := preload("res://scripts/presentation/resource_icon.gd")
const HUD_INDICATOR_NAMES := ["真元", "元石", "寿元", "魂魄"]
const HUD_INDICATOR_KINDS := {"真元": "essence", "元石": "stone", "寿元": "lifespan", "魂魄": "soul"}


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = THEME


func render(battle: Dictionary, state: RunState, catalog: Dictionary, action_cards: Array[Dictionary]) -> void:
	_clear()
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 36)
	root.add_theme_constant_override("margin_right", 36)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)

	_append_hud(column, battle, state)
	_append_field(column, battle, state)
	_append_action_cards(column, battle, action_cards)


func _hud_value(kind: String, battle: Dictionary, state: RunState) -> String:
	match kind:
		"真元": return "%d/%d" % [state.essence, int(state.cave_aperture.get("essence_max", state.essence_capacity))]
		"元石": return "%d" % state.stone
		"寿元": return "%d" % int(state.cultivator.get("lifespan", 0))
		"魂魄": return "%d/%d" % [int(state.cultivator.get("soul", 0)), int(state.cultivator.get("soul_max", 0))]
	return ""


func _append_hud(column: VBoxContainer, battle: Dictionary, state: RunState) -> void:
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 54)
	strip.name = "HUD"
	column.add_child(strip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 18)
	strip.add_child(row)
	for kind in HUD_INDICATOR_NAMES:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		row.add_child(cell)
		var icon := ResourceIconScript.new()
		icon.kind = HUD_INDICATOR_KINDS[kind]
		cell.add_child(icon)
		var label := Label.new()
		label.text = "%s  %s" % [kind, _hud_value(kind, battle, state)]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color("e7c883"))
		cell.add_child(label)
	_animate_hud(strip)


func _animate_hud(strip: PanelContainer) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(strip, "modulate:a", 0.75, 1.1)
	tween.tween_property(strip, "modulate:a", 1.0, 1.1)


func _append_field(column: VBoxContainer, battle: Dictionary, state: RunState) -> void:
	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 24)
	column.add_child(field)

	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(hero)
	_append_hero_block(hero, battle, state)

	var enemy := VBoxContainer.new()
	enemy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(enemy)
	_append_enemy_block(enemy, battle)


func _append_hero_block(column: VBoxContainer, battle: Dictionary, state: RunState) -> void:
	var name := Label.new()
	name.text = "我 · 南疆散修"
	name.add_theme_font_size_override("font_size", 26)
	column.add_child(name)
	if _is_first_battle(state):
		var tip := Label.new()
		tip.text = "初战指引：出手次数上限=魂魄；每回合回复真元；速度高于敌招时可凭「闪避」豁免。"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color("e7c883"))
		column.add_child(tip)
	var life := ProgressBar.new()
	life.max_value = maxi(1, int(state.max_health))
	life.value = int(state.health)
	life.custom_minimum_size = Vector2(0, 22)
	life.tooltip_text = "气血 %d/%d" % [state.health, state.max_health]
	column.add_child(life)
	var life_label := Label.new()
	life_label.text = "气血 %d/%d" % [state.health, state.max_health]
	life_label.add_theme_color_override("font_color", Color("b8d5cc"))
	column.add_child(life_label)
	var armor := Label.new()
	armor.text = "真元 %d/%d  伤势 %d" % [state.essence, int(state.cave_aperture.get("essence_max", state.essence_capacity)), state.injury]
	armor.add_theme_color_override("font_color", Color("c6d3cf"))
	column.add_child(armor)
	var ops := Label.new()
	ops.text = "一心多用  出手 %d/%d" % [int(battle.get("active_gu_instance_ids", []).size()), int(battle.get("soul_ops_cap", 1))]
	ops.add_theme_color_override("font_color", Color("c6d3cf"))
	column.add_child(ops)
	if int(battle.get("first_turn_energy", 0)) > 0:
		var first_turn := Label.new()
		first_turn.text = "首回合额外真元 +%d" % int(battle.get("first_turn_energy", 0))
		first_turn.add_theme_color_override("font_color", Color("e7c883"))
		column.add_child(first_turn)
	var clues := Label.new()
	clues.text = "可见征兆：%s" % _clue_text(battle.get("clues", []))
	clues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clues.add_theme_color_override("font_color", Color("c6d3cf"))
	column.add_child(clues)
	if not battle.get("log", []).is_empty():
		var log_scroll := ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 110)
		log_scroll.custom_maximum_size = Vector2(0, 190)
		column.add_child(log_scroll)
		var log := RichTextLabel.new()
		log.bbcode_enabled = true
		log.fit_content = true
		log.text = _battle_log(battle.get("log", []))
		log_scroll.add_child(log)


func _is_first_battle(state: RunState) -> bool:
	for entry in state.event_log:
		if str(entry.get("action", "")) == "battle_finished":
			return false
	return true


func _append_enemy_block(column: VBoxContainer, battle: Dictionary) -> void:
	var name := Label.new()
	name.text = "敌 · %s" % DisplayText.enemy(str(battle.get("enemy_kind", "")))
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Color("e8b4a4"))
	column.add_child(name)
	var intent := Label.new()
	var intent_data: Dictionary = battle.get("visible_intent", {})
	var intent_label := str(intent_data.get("label", "正在观察"))
	var intent_speed := int(intent_data.get("speed", 0))
	intent.text = "意图：%s · 速 %d" % [intent_label, intent_speed] if intent_speed > 0 else "意图：%s" % intent_label
	intent.add_theme_font_size_override("font_size", 22)
	intent.add_theme_color_override("font_color", Color("e8b4a4"))
	intent.tooltip_text = "敌方已露出的攻势倾向（速=出手速度）；速度低于我方闪避出手时，可凭基础动作「闪避」豁免此招。"
	column.add_child(intent)
	var life := ProgressBar.new()
	life.max_value = maxi(1, int(battle.get("enemy_max_hp", 1)))
	life.value = int(battle.get("enemy_hp", 0))
	life.custom_minimum_size = Vector2(0, 22)
	column.add_child(life)
	var life_label := Label.new()
	life_label.text = "气力 %d/%d" % [int(battle.get("enemy_hp", 0)), int(battle.get("enemy_max_hp", 1))]
	life_label.add_theme_color_override("font_color", Color("b8d5cc"))
	column.add_child(life_label)
	var turn := Label.new()
	turn.text = "回合 %d" % int(battle.get("turn", 1))
	turn.add_theme_color_override("font_color", Color("c6d3cf"))
	column.add_child(turn)


func _append_action_cards(column: VBoxContainer, battle: Dictionary, action_cards: Array[Dictionary]) -> void:
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
		"light_probe": return "小光弹照中敌手，伤敌并照出异状。"
		"thorn_bind": return "棘鞭缠住了对方的手脚。"
		"thorn_strike": return "棘鞭抽实，对方气力受损。"
		"stone_shell": return "石粉聚甲，攻势被挡住。"
		"stone_guard": return "石甲覆身，先护住要害。"
		"pounce": return "敌手伏身扑咬，伤害已经结算。"
		"stone_palm": return "敌手一掌拍下，伤害已经结算。"
		"retreated": return "你抓住空当撤出了交锋。"
		"blood_droplet_shot": return "血滴如刃飞出，对方气力受损。"
		"blood_bat_bite": return "幽血蝙蝠扑咬，噬血回气。"
		"blood_wing_escape": return "血翼张开，退路保全。"
		"farewell_grip": return "爱别离之毒缠身，敌方攻势迟滞。"
		"power_blow": return "力量蛊轰出，对方气力受损。"
		"bear_vitality": return "熊力贯体，伤势减轻。"
		"qi_bulwark": return "无形气墙竖立，护住要害。"
		"moonlight_strike": return "月刃横空，对方气力受损。"
		"moon_glow_flare": return "月华炽放，重创对方。"
		"scout_eye": return "目光如炬，照出对方异状。"
		"venom_snare": return "毒丝缠敌，攻势迟滞。"
		"pulse_wave": return "鼓声如雷，打断对方节奏。"
		"shadow_haze": return "影幕垂落，扰乱对方锁定。"
		"venom_slow": return "毒丝缠敌，攻势迟滞。"
		"pulse_interrupt": return "鼓声如雷，打断对方节奏。"
		"shadow_veil": return "影幕垂落，扰乱对方锁定。"
		"mist_step": return "雾步虚晃，退路保全。"
		_: return "战局发生了一次变化。"
