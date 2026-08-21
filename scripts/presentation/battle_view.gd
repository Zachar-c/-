class_name BattleView
extends Control


signal command_submitted(command: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func render(battle: Dictionary, state: RunState, catalog: Dictionary) -> void:
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
	status.text = "敌方气力 %d    真元 %d    回合 %d" % [battle.get("enemy_hp", 0), state.essence, battle.get("turn", 0)]
	status.add_theme_color_override("font_color", Color("e7c883"))
	column.add_child(status)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	column.add_child(slots)
	for gu_id in battle.get("slots", []):
		var gu: Dictionary = catalog["gu_by_id"].get(gu_id, {})
		var button := Button.new()
		button.text = DisplayText.gu(str(gu_id))
		button.custom_minimum_size = Vector2(154, 78)
		button.tooltip_text = "消耗 %d 真元" % int(gu.get("essence_cost", 0))
		button.disabled = state.essence < int(gu.get("essence_cost", 0))
		button.pressed.connect(func(): command_submitted.emit({"type": "use_gu", "gu_id": gu_id}))
		slots.add_child(button)
	var inheritance_row := HBoxContainer.new()
	inheritance_row.add_theme_constant_override("separation", 10)
	column.add_child(inheritance_row)
	for move in InheritanceResolver.available_moves(state.equipped_gu_ids, state.inheritance_ids, catalog):
		var move_id := str(move["move_id"])
		var button := Button.new()
		button.text = DisplayText.inheritance(move_id)
		button.custom_minimum_size = Vector2(210, 42)
		button.tooltip_text = "施展已声明的传承杀招"
		button.pressed.connect(func(): command_submitted.emit({"type": "use_inheritance", "move_id": move_id}))
		inheritance_row.add_child(button)
	var retreat := Button.new()
	retreat.text = "撤离"
	retreat.custom_minimum_size = Vector2(110, 42)
	retreat.tooltip_text = "按地形、追击与控制判定，通常损失 2 元石"
	retreat.pressed.connect(func(): command_submitted.emit({"type": "retreat"}))
	column.add_child(retreat)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
