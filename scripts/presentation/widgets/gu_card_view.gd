class_name GuCardView
extends PanelContainer
## 卡牌容器（Godot 官方 .tscn 节点树版，替代 ui/widgets/gu_card.guitkx）。
##
## 品质色轨 + 危险「咒」角标 + 封印「锁」态 + 圆角描边（上限 8px）。
## 蛊虫图像区遵循「异常自然志图鉴」风格：主体是蛊虫本身，小尺寸下保证轮廓识别。
## 只表达宿主给的本地交互反馈，不拥有任何战斗 FSM 或领域状态。
## 外部内容（描述、价格、按钮行）一律加进 content_host。

const QUAL_COLORS := {
	"普通": "common", "稀有": "rare", "史诗": "epic", "传说": "legendary",
	"common": "common", "rare": "rare", "epic": "epic", "legendary": "legendary",
}

## 蛊虫插画库：异常自然志图鉴风格，AI生成。按名称关键词匹配，无匹配回退到虫形图标。
## 运行时用Image.load()直接加载PNG创建ImageTexture，绕过Godot资源导入系统。
var GU_BLOOD_TEX: Texture2D = null
var GU_LIGHT_TEX: Texture2D = null
var GU_BONE_TEX: Texture2D = null
var GU_POISON_TEX: Texture2D = null
var GU_MOON_TEX: Texture2D = null


func _load_gu_texture(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

@onready var _curse_badge: PanelContainer = $CardMargin/CardBody/BadgeRow/CurseBadge
@onready var _seal_badge: PanelContainer = $CardMargin/CardBody/BadgeRow/SealBadge
@onready var _title_label: Label = $CardMargin/CardBody/BadgeRow/TitleLabel
@onready var _quality_label: Label = $CardMargin/CardBody/BadgeRow/QualityLabel
@onready var _gu_image: TextureRect = $CardMargin/CardBody/GuImage
@onready var _cost_label: Label = $CardMargin/CardBody/CostLabel

## 外部内容挂载点（对应原 .guitkx 的 children）。
@onready var content_host: VBoxContainer = $CardMargin/CardBody/ContentHost


func _ready() -> void:
	_apply_badge(_curse_badge, GuStyle.CINNABAR, GuStyle.INK_PRIMARY, true)
	_apply_badge(_seal_badge, GuStyle.PAPER_RAISED, GuStyle.INK_SOFT, false)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality_label.add_theme_font_size_override("font_size", 12)
	_cost_label.add_theme_font_size_override("font_size", 13)
	_cost_label.add_theme_color_override("font_color", GuStyle.ANOMALY_YELLOW)
	_init_gu_image()
	_refresh_style()


## 蛊虫图像区初始化：默认用虫形图标占位，setup时按标题匹配插画。
## 图标走 GuIconView 注册表构建路径，不直接 preload（守卫测试强制）。
func _init_gu_image() -> void:
	var icon_path := GuIconView.ICON_DIR + GuIconView.ICON_PATHS["insect"] + ".svg"
	_gu_image.texture = load(icon_path)
	_gu_image.modulate = GuStyle.INK_SOFT


## 蛊虫插画匹配：按标题关键词选择对应异常自然志图鉴插画，无匹配回退到虫形图标。
## 插画自带旧宣纸背景与水墨风格，不做品质着色（保持原画完整性）。
func _refresh_gu_image(title: String) -> void:
	if GU_BLOOD_TEX == null:
		GU_BLOOD_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_blood.png")
		GU_LIGHT_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_light.png")
		GU_BONE_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_bone.png")
		GU_POISON_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_poison.png")
		GU_MOON_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_moon.png")
	var matched: bool = false
	if title.contains("血"):
		_gu_image.texture = GU_BLOOD_TEX
		matched = true
	elif title.contains("光"):
		_gu_image.texture = GU_LIGHT_TEX
		matched = true
	elif title.contains("骨"):
		_gu_image.texture = GU_BONE_TEX
		matched = true
	elif title.contains("毒"):
		_gu_image.texture = GU_POISON_TEX
		matched = true
	elif title.contains("月"):
		_gu_image.texture = GU_MOON_TEX
		matched = true
	if matched:
		_gu_image.modulate = Color(1, 1, 1, 1)
		_gu_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		var icon_path := GuIconView.ICON_DIR + GuIconView.ICON_PATHS["insect"] + ".svg"
		_gu_image.texture = load(icon_path)
		_gu_image.modulate = GuStyle.INK_SOFT
		_gu_image.stretch_mode = TextureRect.STRETCH_SCALE


## 一次性写入卡牌展示数据并刷新。所有参数可选，未传即回落默认。
func setup(title: String = "", quality: String = "", danger: bool = false,
		curse_warning: bool = false, sealed: bool = false, cost: String = "",
		highlight: bool = false, disabled: bool = false, selected: bool = false,
		interaction_mode: String = "idle") -> void:
	_title_label.text = title
	_title_label.visible = title != ""
	_quality_label.text = quality
	_quality_label.visible = quality != ""
	_quality_label.add_theme_color_override("font_color", _quality_color(quality))
	_curse_badge.visible = curse_warning
	_seal_badge.visible = sealed
	_cost_label.text = "◆ " + cost if cost != "" else ""
	_cost_label.visible = cost != ""

	set_meta("danger", danger or curse_warning)
	set_meta("highlight", highlight or selected)
	set_meta("quality", quality)
	# 蛊虫插画按标题匹配：有匹配用异常自然志图鉴插画，无匹配回退虫形图标（品质着色）
	_refresh_gu_image(title)
	if _gu_image.texture == null or _gu_image.texture is CompressedTexture2D == false:
		_gu_image.modulate = _quality_color(quality)
	# 封印 / 禁用 / 拖拽三态共用 modulate 表达"退后一层"，不再另造 token。
	if sealed or disabled:
		modulate = Color(1, 1, 1, 0.55)
	elif interaction_mode == "dragging":
		modulate = Color(1, 1, 1, 0.82)
	else:
		modulate = Color(1, 1, 1, 1.0)
	_refresh_style()


func _refresh_style() -> void:
	var is_danger: bool = get_meta("danger", false)
	var highlighted: bool = get_meta("highlight", false)
	var quality: String = get_meta("quality", "")
	var border_color := GuStyle.CINNABAR if is_danger else (
			GuStyle.JADE if highlighted else _quality_color(quality))
	var box := StyleBoxFlat.new()
	# PAPER_DEEP 是禁用层 token，不做卡牌底色；层级靠 1px 发丝线与留白表达。
	box.bg_color = GuStyle.PAPER_BG
	box.set_corner_radius_all(8)
	box.set_border_width_all(2 if is_danger else 1)
	box.border_color = border_color
	add_theme_stylebox_override("panel", box)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _quality_color(quality: String) -> Color:
	var key: String = String(QUAL_COLORS.get(quality, "common"))
	return GuStyle.rarity_color(key)


func _apply_badge(badge: PanelContainer, bg: Color, font_color: Color, strong: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(4)
	if strong:
		box.border_color = GuStyle.INK_SOFT
		box.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", box)
	var label: Label = badge.get_node("MarginContainer/Label")
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", font_color)
