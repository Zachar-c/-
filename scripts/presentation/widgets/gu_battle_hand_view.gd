class_name GuBattleHandView
extends VBoxContainer
## 战斗手牌（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_battle_hand.guitkx）。
##
## 每张手牌一个紧凑卡体；详细信息只在悬停 / 选中时由 BattleScreen 的统一 tooltip 展示。
## 右键或 Esc 取消当前选择；不可执行的卡点了不触发（原因由 block_reason 直出）。

const MasterTheme := preload("res://scripts/presentation/wenzhen_master_theme.gd")

@onready var _card_row: HBoxContainer = $CardRow
@onready var _cancel_row: HBoxContainer = $CancelRow

var _cards: Array = []
var _on_press: Callable = Callable()
var _on_hover: Callable = Callable()
var _on_cancel: Callable = Callable()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_card_row.add_theme_constant_override("separation", 8)


## 写入手牌与回调。target_select 态额外给一个「取消目标」出口。
func setup(cards: Array, interaction: Dictionary, on_press: Callable,
		on_hover: Callable, on_cancel: Callable) -> void:
	_cards = cards
	_on_press = on_press
	_on_hover = on_hover
	_on_cancel = on_cancel
	_rebuild(interaction)


func _rebuild(interaction: Dictionary) -> void:
	_clear_children(_card_row)
	_clear_children(_cancel_row)
	for card in _cards:
		if card is Dictionary:
			_card_row.add_child(_build_card(card, interaction))
	if _cards.is_empty():
		var empty := Label.new()
		empty.text = "（无手牌）"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", GuStyle.INK_SOFT)
		_card_row.add_child(empty)
	if str(interaction.get("mode", "idle")) == "target_select":
		var cancel := Button.new()
		cancel.text = "取消目标"
		MasterTheme.apply_button(cancel, "cancel")
		cancel.pressed.connect(func():
			if _on_cancel.is_valid():
				_on_cancel.call())
		_cancel_row.add_child(cancel)


func _build_card(card: Dictionary, interaction: Dictionary) -> Node:
	var card_id := str(card.get("id", ""))
	var executable := bool(card.get("executable", true))
	var is_active: bool = str(interaction.get("card_id", "")) == card_id

	var btn := Button.new()
	btn.name = "card_body_" + card_id
	btn.text = str(card.get("name", "蛊虫"))
	btn.custom_minimum_size = Vector2(120, 110)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MasterTheme.apply_button(btn, "card")
	btn.modulate = Color(1, 1, 1, 1.0) if executable else Color(1, 1, 1, 0.55)
	if is_active:
		btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
		btn.add_theme_stylebox_override("normal", _active_box())

	# 悬停交给宿主统一 tooltip；右键 / Esc 取消。
	btn.mouse_entered.connect(func():
		if _on_hover.is_valid():
			_on_hover.call(card))
	btn.gui_input.connect(func(event):
		var is_cancel: bool = (
				(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
						and event.pressed)
				or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed))
		if is_cancel and _on_cancel.is_valid():
			_on_cancel.call())
	# 不可执行的卡不触发 press，避免"点了却注定失败"。
	btn.pressed.connect(func():
		if executable and _on_press.is_valid():
			_on_press.call(card))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)

	if bool(card.get("curse_warning", false)):
		body.add_child(_badge("咒", GuStyle.CINNABAR, GuStyle.PAPER_BG))
	var quality := str(card.get("quality", ""))
	if quality != "":
		var q := Label.new()
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.text = quality
		q.add_theme_font_size_override("font_size", 12)
		q.add_theme_color_override("font_color", GuStyle.quality_color(quality))
		body.add_child(q)
	var effect_text := str(card.get("effect", ""))
	if effect_text != "":
		body.add_child(_text(effect_text, GuStyle.INK_SOFT, 13))
	var block_reason := str(card.get("block_reason", ""))
	if not executable and block_reason != "":
		body.add_child(_text("不可用：" + block_reason, GuStyle.CINNABAR, 12))
	var cost_label := str(card.get("cost", ""))
	if cost_label != "":
		body.add_child(_text("◆ " + cost_label, GuStyle.INK_PRIMARY, 13))
	return btn


func _active_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.set_border_width_all(2)
	box.border_color = GuStyle.JADE
	box.set_corner_radius_all(8)
	return box


func _badge(text: String, bg: Color, font_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", box)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 1)
	panel.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", font_color)
	margin.add_child(label)
	return panel


func _text(value: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
