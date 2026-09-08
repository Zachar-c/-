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
var _on_drag_start: Callable = Callable()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_card_row.add_theme_constant_override("separation", 8)


## 写入手牌与回调。target_select 态额外给一个「取消目标」出口。
## on_drag_start(card)：左键在可执行卡上按下时通知宿主（拖拽候选），宿主在
## 全局左键抬起时做落点命中——不依赖按钮捕获的 release 事件（真窗口下
## 捕获传递不可靠），也不在按住期间重建手牌。
func setup(cards: Array, interaction: Dictionary, on_press: Callable,
		on_hover: Callable, on_cancel: Callable, on_drag_start: Callable = Callable()) -> void:
	_cards = cards
	_on_press = on_press
	_on_hover = on_hover
	_on_cancel = on_cancel
	_on_drag_start = on_drag_start
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
		cancel.custom_minimum_size = Vector2(0, 20)
		cancel.add_theme_font_size_override("font_size", 12)
		cancel.add_theme_constant_override("content_margin_top", 3)
		cancel.add_theme_constant_override("content_margin_bottom", 3)
		cancel.pressed.connect(func():
			if _on_cancel.is_valid():
				_on_cancel.call())
		_cancel_row.add_child(cancel)


func _build_card(card: Dictionary, interaction: Dictionary) -> Node:
	var card_id := str(card.get("id", ""))
	var executable := bool(card.get("executable", true))
	var is_active: bool = str(interaction.get("card_id", "")) == card_id

	# 卡牌主体：线框稿 v2 紧凑文字卡 168×74（名称/道阶/效果/费用 4 行，无插画）
	var card_box := VBoxContainer.new()
	card_box.name = "card_box_" + card_id
	card_box.custom_minimum_size = Vector2(168, 74)
	card_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_box.add_theme_constant_override("separation", 0)

	var btn := Button.new()
	btn.name = "card_body_" + card_id
	btn.text = _card_face_text(card)
	btn.clip_text = true
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.custom_minimum_size = Vector2(168, 74)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MasterTheme.apply_button(btn, "card")
	btn.custom_minimum_size = Vector2(168, 74)
	btn.add_theme_font_size_override("font_size", 10)
	btn.modulate = Color(1, 1, 1, 1.0) if executable else Color(1, 1, 1, 0.55)
	if is_active:
		btn.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
		btn.add_theme_stylebox_override("normal", _active_box())

	# 悬停交给宿主统一 tooltip；右键 / Esc 取消。
	btn.mouse_entered.connect(func():
		if _on_hover.is_valid():
			_on_hover.call(card))
	if executable and _on_drag_start.is_valid():
		btn.button_down.connect(func():
			_on_drag_start.call(card))
	btn.gui_input.connect(func(event):
		var is_cancel: bool = (
				(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
						and event.pressed)
			or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed))
		if is_cancel and _on_cancel.is_valid():
			_on_cancel.call()
			return
	)

	btn.pressed.connect(func():
		if executable and _on_press.is_valid():
			_on_press.call(card))

	card_box.add_child(btn)
	return card_box


## 蛊虫插画加载：按名称关键词匹配异常自然志图鉴插画，无匹配返回null。
func _load_gu_illustration(name: String) -> Texture2D:
	if name.contains("血"):
		return _load_texture("res://assets/wenzhen/gu/gu_blood.png")
	elif name.contains("光"):
		return _load_texture("res://assets/wenzhen/gu/gu_light.png")
	elif name.contains("骨"):
		return _load_texture("res://assets/wenzhen/gu/gu_bone.png")
	elif name.contains("毒"):
		return _load_texture("res://assets/wenzhen/gu/gu_poison.png")
	elif name.contains("月"):
		return _load_texture("res://assets/wenzhen/gu/gu_moon.png")
	return null


func _load_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


## 卡面多行文案：名称 / 道阶 / 效果摘要 / 费用（线框稿 v2 行序；详细说明仍走统一 tooltip）。
func _card_face_text(card: Dictionary) -> String:
	var quality := str(card.get("quality", "普通"))
	var school := str(card.get("school_label", ""))
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
	if effect.length() > 12:
		effect = effect.substr(0, 12) + "…"
	var lines: Array[String] = [name]
	if not school.is_empty():
		lines.append("%s · %s" % [school, quality])
	else:
		lines.append(quality)
	if not effect.is_empty():
		lines.append(effect)
	if not cost.is_empty():
		lines.append("◆ %s" % cost)
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
