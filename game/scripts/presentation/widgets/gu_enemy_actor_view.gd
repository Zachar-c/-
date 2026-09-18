class_name GuEnemyActorView
extends PanelContainer

## 单个敌人的战斗呈现：立绘剪影 / 意图 / 名称 / 生命 / 护盾 / 状态。
##
## 选中与否由外部传入（selected），本组件不持有选择状态——选择属于宿主的呈现状态。

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
## 专属立绘按 enemy id 精确匹配（AI 定制，文件缺失时回退名称关键词匹配）。
## 路径规划见 docs/art/AI-ART-PROMPTS.md。
const ENEMY_PORTRAIT_BY_ID := {
	"neutral_stone_wanderer": "res://assets/wenzhen/enemies/enemy_stone_wanderer.png",
	"ridge_hound": "res://assets/wenzhen/enemies/enemy_ridge_hound.png",
	"ridge_elite_scout": "res://assets/wenzhen/enemies/enemy_ridge_elite_scout.png",
	"iron_hide_boar": "res://assets/wenzhen/enemies/enemy_iron_hide_boar.png",
	"thunder_crown_wolf": "res://assets/wenzhen/enemies/enemy_thunder_crown_wolf.png",
	"beast_swarm": "res://assets/wenzhen/enemies/enemy_beast_swarm.png",
	"faction_guard": "res://assets/wenzhen/enemies/enemy_faction_guard.png",
	"crag_serpent_matriarch": "res://assets/wenzhen/enemies/enemy_crag_serpent_matriarch.png",
	"marrow_gu_adept": "res://assets/wenzhen/enemies/enemy_marrow_gu_adept.png",
	"thunder_crown_sovereign": "res://assets/wenzhen/enemies/enemy_thunder_crown_sovereign.png",
	"blood_vein_bishop": "res://assets/wenzhen/enemies/enemy_blood_vein_bishop.png",
	"miasma_vein_lord": "res://assets/wenzhen/enemies/enemy_miasma_vein_lord.png",
}
var EnemySanxiuTex: Texture2D = null
var EnemyToadTex: Texture2D = null
var EnemyMothTex: Texture2D = null
var EnemyCentipedeTex: Texture2D = null
## enemy_id → 专属立绘缓存；null 也缓存（避免对缺失文件反复 IO）。
var _special_portrait_cache: Dictionary = {}


## 按 enemy id 加载专属立绘；文件缺失返回 null（调用方回退关键词匹配）。
func _load_special_portrait(enemy_id: String) -> Texture2D:
	if _special_portrait_cache.has(enemy_id):
		return _special_portrait_cache[enemy_id]
	var tex: Texture2D = null
	var path: String = ENEMY_PORTRAIT_BY_ID.get(enemy_id, "")
	if path != "" and FileAccess.file_exists(path):
		tex = _load_enemy_texture(path)
	_special_portrait_cache[enemy_id] = tex
	return tex


## 加载敌人立绘：文件存在时用资源系统加载（Image.load 在导出包中不可用），
## 缺失返回 null 由调用方回退，避免 load() 对缺失路径报错。
func _load_enemy_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as Texture2D

@onready var _intent_host: HBoxContainer = $ActorMargin/ActorBody/IntentHost
@onready var _seal_box: PanelContainer = $ActorMargin/ActorBody/IntentHost/SealBox
@onready var _intent_glyph: Label = $ActorMargin/ActorBody/IntentHost/SealBox/SealMargin/SealInner/IntentGlyph
@onready var _intent_value: Label = $ActorMargin/ActorBody/IntentHost/SealBox/SealMargin/SealInner/IntentValue
@onready var _intent_caption: Label = $ActorMargin/ActorBody/IntentHost/IntentCaption
@onready var _name_button: Button = $ActorMargin/ActorBody/NameRow/NameButton
@onready var _name_label: Label = $ActorMargin/ActorBody/NameRow/NameLabel
@onready var _shield_label: Label = $ActorMargin/ActorBody/NameRow/ShieldLabel
@onready var _enemy_portrait: TextureRect = $ActorMargin/ActorBody/EnemyIconHost/EnemyPortrait
@onready var _strike_line: ColorRect = $ActorMargin/ActorBody/StrikeLine
@onready var _hp_host: VBoxContainer = $ActorMargin/ActorBody/HpHost
@onready var _stat_bar = $ActorMargin/ActorBody/HpHost/StatBar
@onready var _status_host: FlowContainer = $ActorMargin/ActorBody/StatusHost

var _on_select: Callable = Callable()
var _enemy_id := ""
var _selected := false
## 最近一次 setup 的敌人数据（_apply_actor_style 重算立绘偏色用）。
var _last_enemy: Dictionary = {}
# 拖拽放置区高亮：影卡悬于该敌人上时玉绿描边提示可投放。
var _drop_highlight := false


func _ready() -> void:
	_name_button.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		if _on_select.is_valid():
			_on_select.call(_enemy_id))
	# 水墨去框（2026-09-11 用户裁定）：选目标按钮不再用主题框式按钮——
	# 名字本身就是可点文字（玉绿 hover），像古籍里的批注选项。
	_apply_flat_text_button(_name_button, GuStyle.INK_PRIMARY, GuStyle.JADE)


## selectable 为真时名称渲染成按钮（点它选目标），否则渲染成静态文字。
func setup(enemy: Dictionary, selected: bool = false,
		selectable: bool = false, on_select: Callable = Callable()) -> void:
	_enemy_id = str(enemy.get("id", ""))
	_on_select = on_select
	_selected = selected
	_drop_highlight = false
	_last_enemy = enemy
	name = "enemy_actor_" + _enemy_id
	# 四个段按 enemy_id 命名：既有测试（test_wenzhen_battle_screen）按
	# enemy_intent_<id> / enemy_hp_<id> / enemy_shield_<id> / enemy_status_<id> 定位。
	# 意图段 2026-09-11 起是篆刻印容器（印 + 小注），命名挂在 IntentHost 上。
	_intent_host.name = "enemy_intent_" + _enemy_id
	_hp_host.name = "enemy_hp_" + _enemy_id
	_shield_label.name = "enemy_shield_" + _enemy_id
	_status_host.name = "enemy_status_" + _enemy_id

	_refresh_intent(enemy)
	_refresh_name(enemy, selectable)
	_refresh_vitals(enemy)
	_refresh_statuses(enemy)
	_refresh_enemy_portrait(enemy)
	_apply_actor_style(selected)


## 意图篆刻印（2026-09-11 战斗视觉重构）：**形状 + 符号 + 颜色三通道编码**，
## 快速扫视即可判读敌人下回合动作。
##   攻击 = 朱砂方印「攻」；防御 = 契蓝青灰印「盾」；强化 = 险金印「强」；
##   蓄力 = 墨印「蓄」；未知类型 = 墨印「异」。数值放大（雅黑 UI 数字）。
## 印下小注保留「意图：」字样与「速 N」（契约文本扫描 test_v1_battle_mounted /
## test_v3_ui_sync 要求"意图："在场；test_b3_experience_gaps 要求速度可见）。
## detail 语义入 tooltip，不占版面。
func _refresh_intent(enemy: Dictionary) -> void:
	var intent: Dictionary = enemy.get("intent", {})
	var itype := str(intent.get("type", "charge"))
	var ivalue := int(intent.get("value", 0))
	var ispeed := int(intent.get("speed", 0))
	var idetail := str(intent.get("detail", "蓄势待发"))

	var glyph := "异"
	var color := GuStyle.INK_PRIMARY
	match itype:
		"attack":
			glyph = "攻"
			color = GuStyle.CINNABAR
		"defend", "guard":
			glyph = "盾"
			color = GuStyle.CONTRACT_BLUE
		"buff", "strengthen", "empower":
			glyph = "强"
			color = GuStyle.ANOMALY_YELLOW
		"charge":
			glyph = "蓄"
			color = GuStyle.INK_PRIMARY

	_intent_glyph.text = glyph
	_intent_glyph.add_theme_font_override("font", GuStyle.TITLE_FONT)
	_intent_glyph.add_theme_font_size_override("font_size", 12)
	_intent_glyph.add_theme_color_override("font_color", color)
	_intent_value.text = str(ivalue)
	_intent_value.add_theme_font_override("font", GuStyle.CARD_UI_FONT)
	_intent_value.add_theme_font_size_override("font_size", 15)
	_intent_value.add_theme_color_override("font_color", color)

	# 印身 = 篆刻印：无纸底、类型色细方框（近似印章），攻击印框加粗一档（威胁预读）。
	# 不做矩形 UI 卡片：无圆角、无阴影、背景全透，像盖在画上的一枚印。
	var seal := StyleBoxFlat.new()
	seal.bg_color = Color(color.r, color.g, color.b, 0.08)
	seal.border_color = color
	seal.set_border_width_all(3 if itype == "attack" else 2)
	seal.set_corner_radius_all(2)
	_seal_box.add_theme_stylebox_override("panel", seal)

	var speed_txt := ""
	if ispeed > 0:
		speed_txt = "速 %d" % ispeed
	_intent_caption.text = "意图：" + speed_txt
	_intent_caption.add_theme_font_override("font", GuStyle.CARD_UI_FONT)
	_intent_caption.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	_intent_host.tooltip_text = "意图：%s；数值 %d；速度 %d；%s" % [itype, ivalue, ispeed, idetail]


func _refresh_name(enemy: Dictionary, selectable: bool) -> void:
	var enemy_name := str(enemy.get("name", "敌人"))
	var is_dead: bool = enemy.get("alive", true) == false
	_name_button.visible = selectable and not is_dead
	_name_label.visible = not selectable or is_dead
	if selectable and not is_dead:
		_name_button.text = enemy_name
	else:
		_name_label.text = enemy_name
		_name_label.add_theme_font_override("font", GuStyle.TITLE_FONT)
		_name_label.add_theme_font_size_override("font_size", 16)
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
	_shield_label.add_theme_font_override("font", GuStyle.CARD_UI_FONT)
	_shield_label.add_theme_font_size_override("font_size", 12)
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


## 无框状态注记（2026-09-11 水墨去框）：图标 + 灰字，不画边框小标签——
## 状态是画上的小注，不是 UI 徽章。
func _status_row(status_name: String, stacks: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var icon_name := ""
	for key in STATUS_ICON_MAP.keys():
		if status_name.contains(key):
			icon_name = STATUS_ICON_MAP[key]
			break
	if not icon_name.is_empty() and GuIconView.has(icon_name):
		var icon := GuIconView.new()
		icon.setup(icon_name, GuStyle.INK_SOFT, GuIconView.SIZE_SMALL)
		row.add_child(icon)
	var label := Label.new()
	label.text = "%s %d" % [status_name, stacks]
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	row.add_child(label)
	return row


## 敌人立绘：优先按 enemy id 精确匹配专属立绘（AI 定制），文件缺失时
## 回退名称关键词匹配（异常自然志图鉴通用图），再回退主角立绘翻转。
## 野兽类按状态偏色（中毒偏绿、诅咒偏紫），散修类偏冷灰。
func _refresh_enemy_portrait(enemy: Dictionary) -> void:
	var enemy_id := str(enemy.get("id", ""))
	var special := _load_special_portrait(enemy_id)
	if special != null:
		_enemy_portrait.texture = special
		_enemy_portrait.flip_h = false
		var tint := _portrait_tint(enemy)
		_enemy_portrait.modulate = tint
		return
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
	_enemy_portrait.modulate = _portrait_tint(enemy)


## 按敌人状态决定立绘偏色：中毒偏绿、诅咒偏紫，否则墨色微暗。
func _portrait_tint(enemy: Dictionary) -> Color:
	var tint := GuStyle.PORTRAIT_DIM
	var statuses: Array = enemy.get("statuses", [])
	for status in statuses:
		if status is Dictionary:
			var sname := str(status.get("name", ""))
			if sname.contains("毒"):
				tint = GuStyle.ENEMY_PORTRAIT_POISON
			elif sname.contains("咒"):
				tint = GuStyle.ENEMY_PORTRAIT_CURSE
	return tint


func _status_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	return label


## 拖拽放置区高亮开关：影卡悬停时调用；与选中态共用玉绿描边语言。
func set_drop_highlight(on: bool) -> void:
	if _drop_highlight == on:
		return
	_drop_highlight = on
	_apply_actor_style(_selected)


## 水墨去框（2026-09-11 用户裁定）：实体不进矩形面板——根容器全透明，
## 命中矩形保留（拖拽落点判定用）。选中/放置高亮 = 立绘提亮 + 名字玉绿，
## 不再画边框。
func _apply_actor_style(selected: bool) -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var lit := selected or _drop_highlight
	_enemy_portrait.modulate = Color(1, 1, 1, 1) if lit else _portrait_tint(_last_enemy)
	# 死亡名灰由 _refresh_name 负责，这里只在存活时做高亮提色。
	if not (_last_enemy.get("alive", true) == false):
		_name_label.add_theme_color_override("font_color",
				GuStyle.JADE if lit else GuStyle.INK_PRIMARY)


## 无框文字按钮：透明底、无框，hover/pressed 只变色（古籍批注式操作）。
## 保留点击音效（交互闭环契约：视觉+听觉双重反馈）。
func _apply_flat_text_button(button: Button, base: Color, hover: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", base)
	button.add_theme_color_override("font_hover_color", hover)
	button.add_theme_color_override("font_pressed_color", hover)
	button.add_theme_color_override("font_focus_color", base)
	button.add_theme_color_override("font_disabled_color", GuStyle.INK_MUTED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
