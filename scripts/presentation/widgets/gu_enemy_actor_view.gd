class_name GuEnemyActorView
extends PanelContainer

## 单个敌人的战斗呈现：立绘剪影 / 意图 / 名称 / 生命 / 护盾 / 状态。
##
## 选中与否由外部传入（selected），本组件不持有选择状态——选择属于宿主的呈现状态。

const MasterTheme = preload("res://scripts/presentation/wenzhen_master_theme.gd")
const EnemyPortraitTex := preload("res://assets/wenzhen/hall/first-life-character.png")
## 状态名关键词 → 开源图标映射（game-icons.net CC BY 3.0）。
## 无匹配时回退纯文本，不阻断流程。
const STATUS_ICON_MAP := {
	"毒": "gi_poison",
	"咒": "gi_curse",
	"盾": "gi_shield",
	"护": "gi_shield",
	"火": "gi_fire",
	"死": "gi_skull",
	"亡": "gi_skull",
	"血": "gi_blood",
}
## 敌人立绘库：异常自然志图鉴风格，AI生成。运行时用Image.load()直接加载。
var EnemySanxiuTex: Texture2D = null
var EnemyToadTex: Texture2D = null
var EnemyMothTex: Texture2D = null
var EnemyCentipedeTex: Texture2D = null


func _load_enemy_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

@onready var _intent_label: Label = $ActorMargin/ActorBody/IntentLabel
@onready var _name_button: Button = $ActorMargin/ActorBody/NameButton
@onready var _enemy_portrait: TextureRect = $ActorMargin/ActorBody/EnemyIconHost/EnemyPortrait
@onready var _name_label: Label = $ActorMargin/ActorBody/NameLabel
@onready var _strike_line: ColorRect = $ActorMargin/ActorBody/StrikeLine
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
	_refresh_enemy_portrait(enemy)
	_apply_actor_style(selected)


func _refresh_intent(enemy: Dictionary) -> void:
	var intent: Dictionary = enemy.get("intent", {})
	var itype := str(intent.get("type", "charge"))
	var ivalue := int(intent.get("value", 0))
	var ispeed := int(intent.get("speed", 0))
	var idetail := str(intent.get("detail", "蓄势待发"))

	var intent_label := "蓄势"
	var color := GuStyle.INK_SOFT
	if itype == "attack":
		intent_label = "攻击"
		color = GuStyle.CINNABAR
	elif itype == "defend" or itype == "guard":
		intent_label = "防御"
		color = GuStyle.ANOMALY_YELLOW

	_intent_label.text = "意图：%s %d · 速 %d\n%s" % [intent_label, ivalue, ispeed, idetail]
	_intent_label.tooltip_text = "意图：%s；数值 %d；速度 %d；%s" % [itype, ivalue, ispeed, idetail]
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_label.add_theme_font_size_override("font_size", 14)
	_intent_label.add_theme_color_override("font_color", color)


func _refresh_name(enemy: Dictionary, selectable: bool) -> void:
	var enemy_name := str(enemy.get("name", "敌人"))
	var is_dead: bool = enemy.get("alive", true) == false
	_name_button.visible = selectable and not is_dead
	_name_label.visible = not selectable or is_dead
	if selectable and not is_dead:
		_name_button.text = enemy_name
		MasterTheme.apply_button(_name_button, "target")
	else:
		_name_label.text = enemy_name
		_name_label.add_theme_font_size_override("font_size", 18)
		# 死亡态：名字变灰 + 朱砂划除线从左到右划过（文字划除=死亡，设计文档§12）
		if is_dead:
			_name_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
			_strike_line.visible = true
			_strike_line.color = GuStyle.CINNABAR
			_strike_line.scale = Vector2(0, 1)
			var tween := create_tween()
			tween.tween_property(_strike_line, "scale:x", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_name_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
			_strike_line.visible = false


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
		var sname := str(status.get("name", "状态"))
		var stacks := int(status.get("stacks", 0))
		_status_host.add_child(_status_row(sname, stacks))


## 带开源图标的状态行：匹配到图标时用 HBoxContainer 包裹图标+文本，无匹配回退纯文本。
func _status_row(status_name: String, stacks: int) -> Control:
	var icon_name := ""
	for key in STATUS_ICON_MAP.keys():
		if status_name.contains(key):
			icon_name = STATUS_ICON_MAP[key]
			break
	if icon_name.is_empty() or not GuIconView.has(icon_name):
		return _status_label("%s %d 层" % [status_name, stacks])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := GuIconView.new()
	icon.setup(icon_name, Color(0, 0, 0, 0), GuIconView.SIZE_SMALL)
	row.add_child(icon)
	var label := _status_label("%s %d 层" % [status_name, stacks])
	row.add_child(label)
	return row


## 敌人立绘：按名称关键词匹配对应异常自然志图鉴立绘，无匹配回退主角立绘翻转。
## 野兽类按状态偏色（中毒偏绿、诅咒偏紫），散修类偏冷灰。
func _refresh_enemy_portrait(enemy: Dictionary) -> void:
	if EnemySanxiuTex == null:
		EnemySanxiuTex = _load_enemy_texture("res://assets/wenzhen/enemies/enemy_sanxiu.png")
		EnemyToadTex = _load_enemy_texture("res://assets/wenzhen/enemies/enemy_toad.png")
		EnemyMothTex = _load_enemy_texture("res://assets/wenzhen/enemies/enemy_moth.png")
		EnemyCentipedeTex = _load_enemy_texture("res://assets/wenzhen/enemies/enemy_centipede.png")
	var enemy_name := str(enemy.get("name", ""))
	var matched: bool = false
	if enemy_name.contains("散修") or enemy_name.contains("修") or enemy_name.contains("道") or enemy_name.contains("人"):
		_enemy_portrait.texture = EnemySanxiuTex
		_enemy_portrait.flip_h = false
		matched = true
	elif enemy_name.contains("蟾") or enemy_name.contains("蛙"):
		_enemy_portrait.texture = EnemyToadTex
		_enemy_portrait.flip_h = false
		matched = true
	elif enemy_name.contains("蛾") or enemy_name.contains("蝶"):
		_enemy_portrait.texture = EnemyMothTex
		_enemy_portrait.flip_h = false
		matched = true
	elif enemy_name.contains("蜈蚣") or enemy_name.contains("蚣"):
		_enemy_portrait.texture = EnemyCentipedeTex
		_enemy_portrait.flip_h = false
		matched = true
	if not matched:
		_enemy_portrait.texture = EnemyPortraitTex
		_enemy_portrait.flip_h = true
	var tint := GuStyle.PORTRAIT_DIM
	var statuses: Array = enemy.get("statuses", [])
	for status in statuses:
		if status is Dictionary:
			var sname := str(status.get("name", ""))
			if sname.contains("毒"):
				tint = GuStyle.ENEMY_PORTRAIT_POISON
			elif sname.contains("咒"):
				tint = GuStyle.ENEMY_PORTRAIT_CURSE
	_enemy_portrait.modulate = tint


func _status_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	return label


## 杀戮尖塔风格：完全透明背景，选中态用 JADE 描边（可点目标）+ 立绘提亮。
func _apply_actor_style(selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)  # 完全透明背景
	box.border_color = GuStyle.JADE if selected else Color(0, 0, 0, 0)  # 选中态玉绿描边，未选中无边框
	box.set_border_width_all(2 if selected else 0)
	box.set_corner_radius_all(GuStyle.RADIUS_SMALL)
	add_theme_stylebox_override("panel", box)
	var current := _enemy_portrait.modulate
	_enemy_portrait.modulate = Color(current.r, current.g, current.b, 1.0 if selected else current.a)
