class_name HandPanel
extends MarginContainer

## 手牌区：持有/重建卡牌实例，把卡牌交互向上汇总为一个信号。
## 卡牌实例全部由脚本 spawn 进场景里的 %HandBox（HBox），横向溢出由
## HandScroll 接管滚动；整表重建只发生在换回合（show_hand），回合内只
## 刷可催动态（refresh_affordable）。

signal card_played(card_id: StringName)
signal card_inspected(card_id: StringName, hovered: bool)

const CARD_SCENE: PackedScene = preload("res://scenes/ui/card_view.tscn")
const MAX_HAND: int = 10
const THEME: Theme = preload("res://gu_theme.tres")

@onready var _hand_box: HBoxContainer = %HandBox

var _views: Array[GuHandCardView] = []


func _init() -> void:
	# T5：主题挂到手牌区整层（入树前挂，孙级才能解析 HandBox/HandScroll 条目）；
	# 卡牌实例各自再自挂同一资源，同源无冲突。
	theme = THEME


func show_hand(cards: Array) -> void:
	_clear()
	for data: Dictionary in cards.slice(0, MAX_HAND):
		var view: GuHandCardView = CARD_SCENE.instantiate()
		_hand_box.add_child(view)
		view.bind_card(data)
		view.card_pressed.connect(func(id: StringName) -> void: card_played.emit(id))
		view.card_hovered.connect(func(id: StringName, h: bool) -> void: card_inspected.emit(id, h))
		_views.append(view)


## 战斗回合刷新真元后，批量更新可催动态，不重建节点。
func refresh_affordable(affordable_ids: Array) -> void:
	for view in _views:
		view.set_affordable(affordable_ids.has(view.card_id()))


func _clear() -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
