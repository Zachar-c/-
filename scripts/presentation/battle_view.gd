class_name BattleView
extends Control



const ActionCardRowScript := preload("res://scripts/presentation/action_card_row_builder.gd")
const ResourceIconScript := preload("res://scripts/presentation/resource_icon.gd")
const CurseRegistryScript = preload("res://scripts/domain/curse_registry.gd")

const StatBarScene := preload("res://scenes/ui/stat_bar.tscn")
const TopStatusBarScene := preload("res://scenes/ui/top_status_bar.tscn")
const GuTooltipScene := preload("res://scenes/ui/gu_tooltip.tscn")

const HUD_INDICATOR_NAMES := ["真元", "元石", "寿元", "魂魄"]
const HUD_INDICATOR_KINDS := {"真元": "essence", "元石": "stone", "寿元": "lifespan", "魂魄": "soul"}

# Pity (保底) is only ever hinted, never shown as a raw number.
const PITY_HINT_CAP := 8

# Semantic colors stay centralized in GuStyle.
const COLOR_GOLD := GuStyle.ANOMALY_YELLOW
const COLOR_JADE := GuStyle.JADE
const COLOR_DANGER := GuStyle.CINNABAR
const COLOR_CONTRACT := GuStyle.CONTRACT_BLUE
const COLOR_CURSE := GuStyle.CINNABAR
const COLOR_DDA_YELLOW := GuStyle.ANOMALY_YELLOW
const COLOR_DDA_RED := GuStyle.CINNABAR
const COLOR_SHIELD := GuStyle.JADE


# Primary command channel consumed by RunController.command_submitted.
signal command_submitted(command: Dictionary)
# Convenience signals; both also flow through command_submitted so the
# controller wiring stays single-entry.
signal card_played(instance_id: String)
signal end_turn_pressed()


var _tooltip: GuTooltip
var _content_root: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_tooltip()


func _ensure_tooltip() -> void:
	if _tooltip != null:
		return
	_tooltip = GuTooltipScene.instantiate()
	add_child(_tooltip)


func render(battle: Dictionary, state: RunState, catalog: Dictionary, action_cards: Array[Dictionary]) -> void:
	_clear()
	_ensure_tooltip()
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 36)
	root.add_theme_constant_override("margin_right", 36)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)
	_content_root = root
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)

	_append_top_status(column, state)
	_append_hud(column, battle, state)
	_append_field(column, battle, state)
	_append_action_cards(column, battle, action_cards, catalog)
	_append_relics(column, state, catalog)


# --------------------------------------------------------------------------- #
# §16.5.3  Persistent top strip via shared TopStatusBar:
# 契约 (blue) + debuff/异变 (yellow/red) chips. Read-only from state.
# --------------------------------------------------------------------------- #
func _append_top_status(column: VBoxContainer, state: RunState) -> void:
	var contracts: Array[String] = []
	for imprint in state.body_imprints:
		contracts.append(DisplayText.fact(str(imprint)))
	var debuffs: Array[String] = []
	var cultivator: Dictionary = state.cultivator
	var statuses: Dictionary = cultivator.get("statuses", {})
	for curse_id in statuses:
		var entry: Dictionary = statuses[curse_id]
		debuffs.append("%s 诅咒 %d" % [GuStyle.CURSE_GLYPH, int(entry.get("layers", 1))])
	var notorious := int(cultivator.get("notorious", 0))
	if notorious > 0:
		debuffs.append("恶名 %d" % notorious)

	if contracts.is_empty() and debuffs.is_empty():
		var calm := Label.new()
		calm.text = "状态平稳"
		calm.add_theme_font_size_override("font_size", 16)
		calm.add_theme_color_override("font_color", COLOR_JADE)
		column.add_child(calm)
		return

	var bar: TopStatusBar = TopStatusBarScene.instantiate()
	bar.set_contracts(contracts)
	bar.set_debuffs(debuffs)
	# DDA / 异变 markers are not yet carried on RunState; pass empty until the
	# domain exposes them (read-only, no invented data).
	bar.set_dda([])
	column.add_child(bar)


# --------------------------------------------------------------------------- #
# Resource HUD (真元/元石/寿元/魂魄) + §16.5.5 subtle pity hint.
# --------------------------------------------------------------------------- #
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
		label.add_theme_color_override("font_color", COLOR_GOLD)
		cell.add_child(label)
	row.add_child(_pity_hint(state))
	_animate_hud(strip)


func _pity_hint(state: RunState) -> Control:
	var pity := int(state.loot_pity)
	# Subtle only: opacity scales with progress, the raw number is never shown.
	var alpha := clampf(0.15 + 0.09 * mini(pity, PITY_HINT_CAP), 0.15, 0.85)
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	var icon := ResourceIconScript.new()
	icon.kind = "essence"
	icon.modulate.a = alpha
	cell.add_child(icon)
	var label := Label.new()
	label.text = "气"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.modulate.a = alpha
	label.tooltip_text = "气运将临：保底正在累积，越发明亮时越接近补偿。"
	cell.add_child(label)
	return cell


func _hud_value(kind: String, _battle: Dictionary, state: RunState) -> String:
	var cave: Dictionary = state.cave_aperture
	var cultivator: Dictionary = state.cultivator
	match kind:
		"真元": return "%d/%d" % [int(cave.get("essence", state.essence)), int(cave.get("essence_max", state.essence_capacity))]
		"元石": return "%d" % state.stone
		"寿元": return "%d" % int(cultivator.get("lifespan", 0))
		"魂魄": return "%d/%d" % [int(cultivator.get("soul", 0)), int(cultivator.get("soul_max", 0))]
	return ""


func _animate_hud(strip: PanelContainer) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(strip, "modulate:a", 0.75, 1.1)
	tween.tween_property(strip, "modulate:a", 1.0, 1.1)


# --------------------------------------------------------------------------- #
# Hero / enemy field.
# --------------------------------------------------------------------------- #
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
	var name_label := Label.new()
	name_label.text = "我 · 南疆散修"
	name_label.add_theme_font_size_override("font_size", 26)
	column.add_child(name_label)
	if _is_first_battle(state):
		var tip := Label.new()
		tip.text = "初战指引：出手次数上限=魂魄；每回合回复真元；速度高于敌招时可凭「闪避」豁免。"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", COLOR_GOLD)
		column.add_child(tip)

	# §16.5.1 生命与护盾分条展示 via shared StatBar.
	var health := int(state.health)
	var max_health := int(state.max_health)
	var health_bar: StatBar = StatBarScene.instantiate()
	health_bar.configure("生命", health, max_health, COLOR_JADE)
	column.add_child(health_bar)
	var shield := _player_shield(battle)
	if shield > 0:
		var shield_max := maxi(1, shield)
		var shield_bar: StatBar = StatBarScene.instantiate()
		shield_bar.configure("护盾", shield, shield_max, COLOR_SHIELD)
		column.add_child(shield_bar)

	# 真元 bar from cave_aperture.
	var cave: Dictionary = state.cave_aperture
	var essence := int(cave.get("essence", state.essence))
	var essence_max := int(cave.get("essence_max", state.essence_capacity))
	var essence_label := "真元"
	if int(battle.get("action_energy", 0)) > 0:
		essence_label += "（临时 +%d）" % int(battle.get("action_energy", 0))
	var essence_bar: StatBar = StatBarScene.instantiate()
	essence_bar.configure(essence_label, essence, essence_max, GuStyle.rarity_color("rare"))
	# Re-assert the value (configure already sets it; kept for clarity on update).
	essence_bar.set_value(essence, essence_max)
	column.add_child(essence_bar)

	var injury := Label.new()
	injury.text = "伤势 %d" % int(state.injury)
	injury.add_theme_color_override("font_color", COLOR_JADE)
	column.add_child(injury)

	# §16.5.6 魂魄 / 一心多用 operation limit.
	var ops_cap := int(battle.get("soul_ops_cap", state.cultivator.get("soul_control_limit", 1)))
	var ops_used := int(battle.get("active_gu_instance_ids", []).size())
	var ops := Label.new()
	ops.text = "一心多用  已用 %d / 上限 %d" % [ops_used, ops_cap]
	ops.add_theme_color_override("font_color", COLOR_JADE)
	column.add_child(ops)

	if int(battle.get("first_turn_energy", 0)) > 0:
		var first_turn := Label.new()
		first_turn.text = "首回合额外真元 +%d" % int(battle.get("first_turn_energy", 0))
		first_turn.add_theme_color_override("font_color", COLOR_GOLD)
		column.add_child(first_turn)

	# §16.5.4 curse warnings already surface in the top strip; reiterate here
	# if the player is currently carrying any curse layers.
	var curse_layers := _total_curse_layers(state)
	if curse_layers > 0:
		var curse := Label.new()
		curse.text = "%s 身负诅咒 %d 层" % [GuStyle.CURSE_GLYPH, curse_layers]
		curse.add_theme_color_override("font_color", COLOR_CURSE)
		column.add_child(curse)

	var clues := Label.new()
	clues.text = "可见征兆：%s" % _clue_text(battle.get("clues", []))
	clues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clues.add_theme_color_override("font_color", COLOR_JADE)
	column.add_child(clues)
	if not battle.get("log", []).is_empty():
		var log_scroll := ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 110)
		log_scroll.custom_maximum_size = Vector2(0, 190)
		column.add_child(log_scroll)
		var log_view := RichTextLabel.new()
		log_view.bbcode_enabled = true
		log_view.fit_content = true
		log_view.text = _battle_log(battle.get("log", []))
		log_scroll.add_child(log_view)


func _player_shield(battle: Dictionary) -> int:
	# Domain models the player's damage reduction as the `guarded` flag
	# (石甲蛊 / 气墙蛊), which subtracts 2 from incoming damage. Surface it as
	# a 护盾 readout so the player sees the active defensive layer.
	var flags: Array = battle.get("flags", [])
	if flags.has("guarded"):
		return 2
	return 0


func _total_curse_layers(state: RunState) -> int:
	var total := 0
	var statuses: Dictionary = state.cultivator.get("statuses", {})
	for curse_id in statuses:
		total += int(statuses[curse_id].get("layers", 0))
	return total


func _append_enemy_block(column: VBoxContainer, battle: Dictionary) -> void:
	var name_label := Label.new()
	name_label.text = "敌 · %s" % DisplayText.enemy(str(battle.get("enemy_kind", "")))
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", GuStyle.CINNABAR)
	column.add_child(name_label)

	# §16.5.2 enemy intent must carry an explicit number AND effect word.
	for intent in _enemy_intents(battle):
		column.add_child(_intent_chip(intent))

	var life := ProgressBar.new()
	life.max_value = maxi(1, int(battle.get("enemy_max_hp", 1)))
	life.value = int(battle.get("enemy_hp", 0))
	life.custom_minimum_size = Vector2(0, 22)
	# Godot 4 has no tint_progress; tint via the theme fill stylebox.
	life.add_theme_stylebox_override("fill", _progress_fill(COLOR_DANGER))
	column.add_child(life)
	var life_label := Label.new()
	life_label.text = "气力 %d/%d" % [int(battle.get("enemy_hp", 0)), int(battle.get("enemy_max_hp", 1))]
	life_label.add_theme_color_override("font_color", COLOR_JADE)
	column.add_child(life_label)
	var turn := Label.new()
	turn.text = "回合 %d" % int(battle.get("turn", 1))
	turn.add_theme_color_override("font_color", COLOR_JADE)
	column.add_child(turn)


func _enemy_intents(battle: Dictionary) -> Array[Dictionary]:
	var primary: Dictionary = battle.get("visible_intent", {})
	var result: Array[Dictionary] = []
	if not primary.is_empty():
		result.append(primary)
	# Future-proof: a list of intents under "intents" is also supported.
	for extra in battle.get("intents", []):
		result.append(extra)
	return result


func _intent_chip(intent: Dictionary) -> PanelContainer:
	var damage := int(intent.get("damage", 0))
	var defense := int(intent.get("defense", 0))
	var effect_word := "攻击"
	var number := damage
	if defense > 0:
		effect_word = "防御"
		number = defense
	elif damage <= 0:
		effect_word = "蓄势"
		number = 0
	var speed := int(intent.get("speed", 0))
	var primary_text := "%s %d" % [effect_word, number]
	var detail := "（速 %d）" % speed if speed > 0 else ""
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var color := COLOR_DANGER if effect_word == "攻击" else COLOR_SHIELD
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	chip.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = "意图：%s%s" % [primary_text, detail]
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.tooltip_text = "敌方已露出的攻势：%s%s" % [primary_text, detail]
	if not str(intent.get("label", "")).is_empty():
		label.tooltip_text += "\n%s" % str(intent.get("label", ""))
	chip.add_child(label)
	return chip


# --------------------------------------------------------------------------- #
# Action cards (hand) — §16.5.4 curse gu cards get a strong red warning.
# Hand lives in a ScrollContainer so the dynamic hand size scrolls (Rule #5).
# Card hover drives the shared GuTooltip (instantiated once at top level).
# --------------------------------------------------------------------------- #
func _append_action_cards(column: VBoxContainer, battle: Dictionary, action_cards: Array[Dictionary], catalog: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var hand_defs := {}
	for instance_value in battle.get("hand", []):
		var instance: Dictionary = instance_value
		hand_defs[str(instance.get("instance_id", ""))] = str(instance.get("definition_id", ""))

	for card in action_cards:
		var row := ActionCardRowScript.build(card, 320)
		# Rule #4: connect with Callable; freed cards auto-disconnect on queue_free.
		row.command_submitted.connect(_on_card_command.bind(battle))
		var action_id := str(card.get("id", ""))
		var instance_id := _instance_id_from_action(action_id, battle)
		var definition_id := ""
		if not instance_id.is_empty():
			definition_id = str(hand_defs.get(instance_id, ""))
		var tip_data := _card_tooltip_data(card, definition_id, catalog)
		row.mouse_entered.connect(_show_card_tooltip.bind(tip_data))
		row.mouse_exited.connect(_tooltip.hide_tooltip)
		if not instance_id.is_empty() and _is_curse_gu(definition_id, catalog):
			list.add_child(_curse_wrapper(row))
		else:
			list.add_child(row)


func _card_tooltip_data(card: Dictionary, definition_id: String, catalog: Dictionary) -> Dictionary:
	var data: Dictionary = {}
	data["title"] = str(card.get("title", "行动"))
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	if not gu.is_empty():
		if not str(gu.get("rarity", "")).is_empty():
			data["rarity"] = str(gu.get("rarity", ""))
		if not str(gu.get("effect", "")).is_empty():
			data["effect"] = str(gu.get("effect", ""))
		if not str(gu.get("linkage", "")).is_empty():
			data["linkage"] = str(gu.get("linkage", ""))
	var cost := ActionCardRowScript._cost_text(card.get("cost", {}))
	if not cost.is_empty():
		data["cost"] = cost
	if _is_curse_gu(definition_id, catalog):
		data["curse"] = "诅咒蛊：使用伴随反噬，谨慎出手。"
	return data


func _show_card_tooltip(data: Dictionary) -> void:
	_tooltip.show_for(data)


func _on_card_command(cmd: Dictionary, battle: Dictionary) -> void:
	command_submitted.emit(cmd)
	var action_id := str(cmd.get("action_id", ""))
	if action_id == "battle.end_turn":
		end_turn_pressed.emit()
		return
	var instance_id := _instance_id_from_action(action_id, battle)
	if not instance_id.is_empty():
		card_played.emit(instance_id)


func _instance_id_from_action(action_id: String, battle: Dictionary) -> String:
	var prefix := "battle.%s." % str(battle.get("battle_id", ""))
	if not action_id.begins_with(prefix):
		return ""
	return action_id.trim_prefix(prefix)


func _is_curse_gu(definition_id: String, catalog: Dictionary) -> bool:
	if definition_id.is_empty():
		return false
	var gu: Dictionary = catalog.get("gu_by_id", {}).get(definition_id, {})
	if bool(gu.get("is_curse", false)):
		return true
	for tag_value in gu.get("tags", []):
		if str(tag_value) == "curse":
			return true
	return false


func _curse_wrapper(row: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var warn := Label.new()
	warn.text = "%s 诅咒" % GuStyle.CURSE_GLYPH
	warn.add_theme_font_size_override("font_size", 14)
	warn.add_theme_color_override("font_color", COLOR_CURSE)
	box.add_child(warn)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = COLOR_CURSE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(row)
	box.add_child(panel)
	return box


# --------------------------------------------------------------------------- #
# Relic list — ItemList handles dynamic counts (Rule #5).
# --------------------------------------------------------------------------- #
func _append_relics(column: VBoxContainer, state: RunState, _catalog: Dictionary) -> void:
	var panel := GuStyle.panel()
	panel.custom_minimum_size = Vector2(0, 90)
	column.add_child(panel)
	var pcol := VBoxContainer.new()
	panel.add_child(pcol)
	pcol.add_child(GuStyle.label("遗物", 18, GuStyle.ANOMALY_YELLOW))
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 60)
	pcol.add_child(list)
	if state.relic_ids.is_empty():
		list.add_item("（无）")
	else:
		for relic_id in state.relic_ids:
			list.add_item(DisplayText.gu(str(relic_id)))


# --------------------------------------------------------------------------- #
# Shared helpers.
# --------------------------------------------------------------------------- #
func _is_first_battle(state: RunState) -> bool:
	for entry in state.event_log:
		if str(entry.get("action", "")) == "battle_finished":
			return false
	return true


func _clear() -> void:
	# Free only the render tree; the persistent tooltip (top level) survives.
	if _content_root != null:
		_content_root.queue_free()
		_content_root = null


func _progress_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	return sb


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
		"light_reveal": return "小光蛊照亮了对方细微异状。"
		"light_probe": return "小光弹照中敌手，伤敌并照出异状。"
		"thorn_bind": return "棘鞭缠住了对方手脚。"
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
