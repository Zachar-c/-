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
var _on_release: Callable = Callable()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_card_row.add_theme_constant_override("separation", 8)


## 写入手牌与回调。target_select 态额外给一个「取消目标」出口。
## on_release(card, global_pos)：左键在卡上抬起时回传落点，供宿主做
## 拖拽命中（落到敌方卡上 = 按该目标出牌）；普通点击落点在卡内，宿主可忽略。
func setup(cards: Array, interaction: Dictionary, on_press: Callable,
		on_hover: Callable, on_cancel: Callable, on_release: Callable = Callable()) -> void:
	_cards = cards
	_on_press = on_press
	_on_hover = on_hover
	_on_cancel = on_cancel
	_on_release = on_release
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
	btn.text = _card_face_text(card)
	btn.clip_text = true
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.custom_minimum_size = Vector2(150, 110)
	# 卡保持固定宽不随行扩展：5-7 张时平铺会互相挤压，细节走 tooltip。
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MasterTheme.apply_button(btn, "card")
	# 四行卡面塞进 110px 高的按钮：主题 16px 必纵向溢出，压到 13px。
	btn.add_theme_font_size_override("font_size", 13)
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
			_on_cancel.call()
			return
		# 拖拽命中：左键抬起（含拖出卡外的捕获释放）回传全局落点，宿主判定
		# 是否落在敌方卡上；普通点击落点在卡内，宿主可忽略。
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
				and not event.pressed and executable and _on_release.is_valid()):
			_on_release.call(card, btn.get_global_rect().position + event.position))
	# 不可执行的卡不触发 press，避免"点了却注定失败"。
	btn.pressed.connect(func():
		if executable and _on_press.is_valid():
			_on_press.call(card))

	return btn


## 卡面多行文案：品质 / 名称 / 费用 / 效果摘要（详细说明仍走统一 tooltip）。
func _card_face_text(card: Dictionary) -> String:
	var quality := str(card.get("quality", "普通"))
	var name := str(card.get("name", "蛊虫"))
	# cost 已是展示文案（如「念头 1」）；cost_ex 仅在数据自带时优先。
	var cost := str(card.get("cost_ex", ""))
	if cost.is_empty():
		cost = str(card.get("cost", ""))
	# 卡面只放得下一短行效果；长尾（括号注记、封印细节）留给 tooltip。
	var effect := str(card.get("effect", ""))
	var paren := effect.find("（")
	if paren >= 0:
		effect = effect.substr(0, paren)
	if effect.length() > 14:
		effect = effect.substr(0, 14) + "…"
	var lines: Array[String] = ["〔%s〕" % quality, name, "◆ %s" % cost]
	if not effect.is_empty():
		lines.append(effect)
	return "\n".join(lines)


func _active_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.set_border_width_all(2)
	box.border_color = GuStyle.JADE
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	return box


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
