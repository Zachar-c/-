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

	return btn


func _active_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.set_border_width_all(2)
	box.border_color = GuStyle.JADE
	box.set_corner_radius_all(8)
	return box


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
