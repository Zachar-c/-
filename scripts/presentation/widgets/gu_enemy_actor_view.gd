class_name GuEnemyActorView
extends PanelContainer

## 单个敌人的战斗呈现：意图 / 名称 / 生命 / 护盾 / 状态。
##
## 选中与否由外部传入（selected），本组件不持有选择状态——选择属于宿主的呈现状态。

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")

@onready var _intent_label: Label = $ActorMargin/ActorBody/IntentLabel
@onready var _name_button: Button = $ActorMargin/ActorBody/NameButton
@onready var _name_label: Label = $ActorMargin/ActorBody/NameLabel
@onready var _hp_host: VBoxContainer = $ActorMargin/ActorBody/HpHost
@onready var _stat_bar = $ActorMargin/ActorBody/HpHost/StatBar
@onready var _shield_label: Label = $ActorMargin/ActorBody/ShieldLabel
@onready var _status_host: VBoxContainer = $ActorMargin/ActorBody/StatusHost

var _on_select: Callable = Callable()
var _enemy_id := ""


func _ready() -> void:
	_name_button.pressed.connect(func():
		if _on_select.is_valid():
			_on_select.call(_enemy_id))


## selectable 为真时名称渲染成按钮（点它选目标），否则渲染成静态文字。
func setup(enemy: Dictionary, selected: bool = false,
		selectable: bool = false, on_select: Callable = Callable()) -> void:
	_enemy_id = str(enemy.get("id", ""))
	_on_select = on_select
	name = "enemy_actor_" + _enemy_id
	# 四个段按 enemy_id 命名：既有测试（test_wenzhen_battle_screen）按
	# enemy_intent_<id> / enemy_hp_<id> / enemy_shield_<id> / enemy_status_<id> 定位。
	_intent_label.name = "enemy_intent_" + _enemy_id
	_hp_host.name = "enemy_hp_" + _enemy_id
	_shield_label.name = "enemy_shield_" + _enemy_id
	_status_host.name = "enemy_status_" + _enemy_id

	_refresh_intent(enemy)
	_refresh_name(enemy, selectable)
	_refresh_vitals(enemy)
	_refresh_statuses(enemy)
	_apply_actor_style(selected)


func _refresh_intent(enemy: Dictionary) -> void:
	var intent: Dictionary = enemy.get("intent", {})
	var itype := str(intent.get("type", "charge"))
	var ivalue := int(intent.get("value", 0))
	var ispeed := int(intent.get("speed", 0))
	var idetail := str(intent.get("detail", "蓄势待发"))

	var rune := "☾"
	var color := GuStyle.INK_SOFT
	if itype == "attack":
		rune = "⚔"
		color = GuStyle.CINNABAR
	elif itype == "defend" or itype == "guard":
		rune = "🛡"
		color = GuStyle.ANOMALY_YELLOW

	_intent_label.text = "意图：%s %d · 速 %d · %s" % [rune, ivalue, ispeed, idetail]
	_intent_label.tooltip_text = "意图：%s；数值 %d；速度 %d；%s" % [itype, ivalue, ispeed, idetail]
	_intent_label.add_theme_font_size_override("font_size", 14)
	_intent_label.add_theme_color_override("font_color", color)


func _refresh_name(enemy: Dictionary, selectable: bool) -> void:
	var enemy_name := str(enemy.get("name", "敌人"))
	_name_button.visible = selectable
	_name_label.visible = not selectable
	if selectable:
		_name_button.text = enemy_name
		MasterTheme.apply_button(_name_button, "target")
	else:
		_name_label.text = enemy_name
		_name_label.add_theme_font_size_override("font_size", 18)
		_name_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)


func _refresh_vitals(enemy: Dictionary) -> void:
	_stat_bar.setup("生命", int(enemy.get("hp", 0)),
			maxi(1, int(enemy.get("max_hp", 1))), GuStyle.CINNABAR)
	_shield_label.text = "护盾 %d" % int(enemy.get("shield", 0))
	_shield_label.tooltip_text = "护盾先承受本次伤害。"
	_shield_label.add_theme_font_size_override("font_size", 13)
	_shield_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)


func _refresh_statuses(enemy: Dictionary) -> void:
	for child in _status_host.get_children():
		child.queue_free()
	var statuses: Array = enemy.get("statuses", [])
	if statuses.is_empty():
		_status_host.add_child(_status_label("无状态"))
		return
	for status in statuses:
		if not (status is Dictionary):
			continue
		_status_host.add_child(_status_label("%s %d 层" % [
				str(status.get("name", "状态")), int(status.get("stacks", 0))]))


func _status_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	return label


## 选中态用 JADE 描边（可点目标），未选中是发丝线。
func _apply_actor_style(selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = GuStyle.PAPER_RAISED
	box.border_color = GuStyle.JADE if selected else GuStyle.HAIRLINE_COLOR
	box.set_border_width_all(GuStyle.HAIRLINE)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	add_theme_stylebox_override("panel", box)
