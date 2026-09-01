class_name GuCardView
extends Button

## 单张卡牌视图：只做数据绑定与交互上报，不含任何布局/样式代码。
## 样式全部走 res://gu_theme.tres（theme_type_variation 锚定 CardView 类型项），
## 根节点 _ready 自挂主题，多张实例共享同一处样式源、脚本零 modulate。

signal card_pressed(card_id: StringName)
signal card_hovered(card_id: StringName, hovered: bool)

const CARD_THEME: Theme = preload("res://gu_theme.tres")

var _card_id: StringName = &""
var _cost: int = 0

@onready var _title: Label = %TitleLabel
@onready var _cost_label: Label = %CostLabel
@onready var _art: TextureRect = %ArtRect
@onready var _type: Label = %TypeLabel
@onready var _desc: Label = %DescLabel


func _init() -> void:
	# 主题必须在入树前挂上：Label 等孙级在进入树时沿父链解析 theme_owner，
	# _ready 里再挂已在树内的孙级不会重解析（探针实证 get_theme_color 落回默认白）。
	theme = CARD_THEME


func _ready() -> void:
	pressed.connect(_emit_pressed)
	mouse_entered.connect(func() -> void: card_hovered.emit(_card_id, true))
	mouse_exited.connect(func() -> void: card_hovered.emit(_card_id, false))


## 由调用方传入领域快照里的卡牌条目（id/名称/费用/道阶/文案/图标），本节点不查目录。
func bind_card(data: Dictionary) -> void:
	_card_id = StringName(data.get("id", ""))
	_cost = int(data.get("cost", 0))
	_title.text = String(data.get("name", ""))
	_cost_label.text = str(_cost)
	_type.text = String(data.get("rank_text", ""))
	_desc.text = String(data.get("desc", ""))
	_art.texture = data.get("texture")
	tooltip_text = String(data.get("desc", ""))
	set_affordable(bool(data.get("affordable", true)))


## 每回合由战斗状态刷新（真元是否够催动）：Button 走主题 disabled 样式；
## 卡内文字同步切同名 Dim 主题变体（T2——色值仅存在 gu_theme.tres，
## 脚本零色值、零 modulate，只切主题锚点）。
func set_affordable(ok: bool) -> void:
	disabled = not ok
	_apply_dim(_title, "TitleLabel", ok)
	_apply_dim(_cost_label, "CostLabel", ok)
	_apply_dim(_type, "TypeLabel", ok)
	_apply_dim(_desc, "DescLabel", ok)


func _apply_dim(label: Label, base: String, ok: bool) -> void:
	label.theme_type_variation = StringName(base if ok else base + "Dim")


func card_id() -> StringName:
	return _card_id


func _emit_pressed() -> void:
	card_pressed.emit(_card_id)