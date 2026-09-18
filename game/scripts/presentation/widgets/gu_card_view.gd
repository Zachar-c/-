class_name GuCardView
extends PanelContainer
## 卡牌容器（2026-09-11 信息层级重构版，Godot 官方 .tscn 节点树）。
##
## 层级：标题（毛笔书法 + 阴影）→ 右上费用徽章（图标 + 数字）→
## 深灰标签行（品质 + 咒/锁角标）→ 独立画框插画 → 内建描述槽（关键词高亮）
## → 外部内容槽（content_host：价格、按钮等宿主专属内容）。
## 视觉：圆角 + DropShadow 投影、稀有度描边、epic+ 稀有度流光（Shader）、
## 悬停辉光（Shader）。只表达宿主给的本地交互反馈，不拥有任何战斗 FSM 或领域状态。
## 根节点 mouse_filter=STOP，内部子节点全部 IGNORE（tscn 预置），交互归根节点。

## 稀有度闪箔强度（普通/稀有不可见；水墨兼容：低饱和金色、中低强度）。
const FOIL_INTENSITY := {
	"epic": 0.3, "legendary": 0.55,
}

## 蛊虫插画库：异常自然志图鉴风格，AI生成。按名称关键词匹配，无匹配回退到虫形图标。
## 用 load() 加载导入后的 Texture2D（Image.load 直读 res:// 在导出包中不可用）。
var GU_BLOOD_TEX: Texture2D = null
var GU_LIGHT_TEX: Texture2D = null
var GU_BONE_TEX: Texture2D = null
var GU_POISON_TEX: Texture2D = null
var GU_MOON_TEX: Texture2D = null

var _foil_intensity := 0.0
var _anim_time := 0.0
var _tilt := Vector2.ZERO
var _hovered := false


func _load_gu_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	return load(path) as Texture2D

@onready var _title_label: Label = $CardMargin/CardBody/HeadRow/TitleLabel
@onready var _cost_badge: PanelContainer = $CardMargin/CardBody/HeadRow/CostBadge
@onready var _cost_icon: GuIconView = $CardMargin/CardBody/HeadRow/CostBadge/CostMargin/CostRow/CostIcon
@onready var _cost_label: Label = $CardMargin/CardBody/HeadRow/CostBadge/CostMargin/CostRow/CostLabel
@onready var _quality_label: Label = $CardMargin/CardBody/TagRow/QualityLabel
@onready var _curse_badge: PanelContainer = $CardMargin/CardBody/TagRow/CurseBadge
@onready var _seal_badge: PanelContainer = $CardMargin/CardBody/TagRow/SealBadge
@onready var _art_frame: PanelContainer = $CardMargin/CardBody/ArtFrame
@onready var _gu_image: TextureRect = $CardMargin/CardBody/ArtFrame/ArtMargin/GuImage
@onready var _desc_label: RichTextLabel = $CardMargin/CardBody/DescLabel

## 外部内容挂载点（价格行、按钮等宿主专属内容；描述走内建描述槽）。
@onready var content_host: VBoxContainer = $CardMargin/CardBody/ContentHost

@onready var _shimmer_overlay: ColorRect = $ShimmerOverlay
@onready var _glow_overlay: ColorRect = $GlowOverlay


func _ready() -> void:
	_apply_badge(_curse_badge, GuStyle.CINNABAR, GuStyle.INK_PRIMARY, true)
	_apply_badge(_seal_badge, GuStyle.PAPER_RAISED, GuStyle.INK_SOFT, false)
	# 标题：毛笔书法字体 + 放大（OFL 许可，UI_RULES §4 卡面例外）。
	# 文字阴影已按 2026-09-11 用户裁定全量移除（所有文字阴影不得保留）。
	_title_label.add_theme_font_override("font", GuStyle.TITLE_BRUSH_FONT)
	_title_label.add_theme_font_size_override("font_size", 19)
	_title_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 标签（品质）：缩小 + 深灰，稀有度改由描边与流光表达。
	_quality_label.add_theme_font_size_override("font_size", 11)
	_quality_label.add_theme_color_override("font_color", GuStyle.INK_SOFT)
	# 费用徽章：图标 + 放大数字。
	var cost_box := StyleBoxFlat.new()
	cost_box.bg_color = GuStyle.PAPER_RAISED
	cost_box.set_corner_radius_all(6)
	_cost_badge.add_theme_stylebox_override("panel", cost_box)
	_cost_icon.setup("yuanstone", GuStyle.CONTRACT_BLUE, GuIconView.SIZE_SMALL)
	_cost_label.add_theme_font_size_override("font_size", 16)
	_cost_label.add_theme_color_override("font_color", GuStyle.INK_PRIMARY)
	# 描述槽默认样式。
	_desc_label.add_theme_color_override("default_color", GuStyle.INK_PRIMARY)
	_desc_label.add_theme_font_size_override("normal_font_size", 13)
	# 画框：独立「装裱」细边框 + 微沉底色。
	var art_box := StyleBoxFlat.new()
	art_box.bg_color = GuStyle.PAPER_RAISED
	art_box.set_corner_radius_all(4)
	art_box.set_border_width_all(1)
	art_box.border_color = GuStyle.INK_SOFT
	_art_frame.add_theme_stylebox_override("panel", art_box)
	# Shader 覆盖层：尺寸同步 + 悬停辉光 + 裸眼 3D 视差材质。
	var parallax_mat := ShaderMaterial.new()
	parallax_mat.shader = preload("res://assets/wenzhen/shaders/card_parallax.gdshader")
	_gu_image.material = parallax_mat
	resized.connect(_sync_rect_uniforms)
	_sync_rect_uniforms()
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_init_gu_image()
	_refresh_style()


## 流光时间推进 + 裸眼 3D 姿态：仅悬停期间轮询指针，普通卡 _process 直通。
## 用 _process 轮询而非 _gui_input：容器子节点会拦截 motion 事件，路由不可靠。
func _process(delta: float) -> void:
	if not _hovered:
		return
	var local := get_local_mouse_position()
	_set_tilt((local - size * 0.5) / (size * 0.5))
	if _foil_intensity <= 0.0:
		return
	_anim_time += delta
	(_shimmer_overlay.material as ShaderMaterial).set_shader_parameter("anim_time", _anim_time)


func _set_tilt(t: Vector2) -> void:
	_tilt = t.clamp(Vector2(-1, -1), Vector2(1, 1))
	var foil_mat := _shimmer_overlay.material as ShaderMaterial
	if foil_mat != null:
		foil_mat.set_shader_parameter("tilt", _tilt)
	var parallax_mat := _gu_image.material as ShaderMaterial
	if parallax_mat != null:
		parallax_mat.set_shader_parameter("tilt", _tilt)


## 覆盖层 rect_half 与卡面尺寸同步。辉光按 glow_width 内缩，
## 因为 canvas_item 只在自己的矩形内绘制，外扩环带会被裁掉。
func _sync_rect_uniforms() -> void:
	var half := size * 0.5
	var glow_half := half - Vector2(5.0, 5.0)
	var shimmer_mat := _shimmer_overlay.material as ShaderMaterial
	var glow_mat := _glow_overlay.material as ShaderMaterial
	if shimmer_mat != null:
		shimmer_mat.set_shader_parameter("rect_half", half)
		shimmer_mat.set_shader_parameter("corner_radius", 8.0)
	if glow_mat != null:
		glow_mat.set_shader_parameter("rect_half", glow_half)
		glow_mat.set_shader_parameter("corner_radius", 8.0)
		glow_mat.set_shader_parameter("glow_width", 5.0)


func _set_hover(hovered: bool) -> void:
	_hovered = hovered
	if not hovered:
		_set_tilt(Vector2.ZERO)
	var glow_mat := _glow_overlay.material as ShaderMaterial
	if glow_mat == null:
		return
	glow_mat.set_shader_parameter("on", 1.0 if hovered else 0.0)


## 蛊虫图像区初始化：默认用虫形图标占位，setup时按标题匹配插画。
## 图标走 GuIconView 注册表构建路径，不直接 preload（守卫测试强制）。
func _init_gu_image() -> void:
	var icon_path := GuIconView.ICON_DIR + GuIconView.ICON_PATHS["insect"] + ".svg"
	_gu_image.texture = load(icon_path)
	_gu_image.modulate = GuStyle.INK_SOFT
	_sync_parallax_tex()


## 蛊虫插画匹配：按标题关键词选择对应异常自然志图鉴插画，无匹配回退到虫形图标。
## 插画自带旧宣纸背景与水墨风格，不做品质着色（保持原画完整性）。
## 返回是否命中图鉴插画（未命中时虫形图标按品质着色）。
func _refresh_gu_image(title: String) -> bool:
	if GU_BLOOD_TEX == null:
		GU_BLOOD_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_blood.png")
		GU_LIGHT_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_light.png")
		GU_BONE_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_bone.png")
		GU_POISON_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_poison.png")
		GU_MOON_TEX = _load_gu_texture("res://assets/wenzhen/gu/gu_moon.png")
	if title.contains("血"):
		_gu_image.texture = GU_BLOOD_TEX
	elif title.contains("光"):
		_gu_image.texture = GU_LIGHT_TEX
	elif title.contains("骨"):
		_gu_image.texture = GU_BONE_TEX
	elif title.contains("毒"):
		_gu_image.texture = GU_POISON_TEX
	elif title.contains("月"):
		_gu_image.texture = GU_MOON_TEX
	else:
		var icon_path := GuIconView.ICON_DIR + GuIconView.ICON_PATHS["insect"] + ".svg"
		_gu_image.texture = load(icon_path)
		_gu_image.modulate = GuStyle.INK_SOFT
		_gu_image.stretch_mode = TextureRect.STRETCH_SCALE
		_sync_parallax_tex()
		return false
	_gu_image.modulate = Color(1, 1, 1, 1)
	_gu_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sync_parallax_tex()
	return true


## 视差 shader 的 art_tex 随插画纹理更新（纹理在 setup 时会换）。
func _sync_parallax_tex() -> void:
	var mat := _gu_image.material as ShaderMaterial
	if mat != null and _gu_image.texture != null:
		mat.set_shader_parameter("art_tex", _gu_image.texture)


## 描述关键词高亮：统一走 GuStyle 共享实现（竖长手牌卡同源）。
func _highlight_desc(text: String) -> String:
	return GuStyle.highlight_desc_keywords(text)


## 一次性写入卡牌展示数据并刷新。所有参数可选，未传即回落默认。
## desc 走内建描述槽（bbcode 关键词高亮）；宿主专属内容仍挂 content_host。
func setup(title: String = "", quality: String = "", danger: bool = false,
		curse_warning: bool = false, sealed: bool = false, cost: String = "",
		highlight: bool = false, disabled: bool = false, selected: bool = false,
		interaction_mode: String = "idle", desc: String = "") -> void:
	_title_label.text = title
	_title_label.visible = title != ""
	_quality_label.text = quality
	_quality_label.visible = quality != ""
	_curse_badge.visible = curse_warning
	_seal_badge.visible = sealed
	_cost_label.text = cost
	_cost_badge.visible = cost != ""
	if desc != "":
		_desc_label.text = _highlight_desc(desc)
	_desc_label.visible = desc != ""

	set_meta("danger", danger or curse_warning)
	set_meta("highlight", highlight or selected)
	set_meta("quality", quality)
	# 蛊虫插画按标题匹配：有匹配用异常自然志图鉴插画，无匹配回退虫形图标（品质着色）
	if not _refresh_gu_image(title):
		_gu_image.modulate = _quality_color(quality)
	# 封印 / 禁用 / 拖拽三态共用 modulate 表达"退后一层"，不再另造 token。
	if sealed or disabled:
		modulate = Color(1, 1, 1, 0.55)
	elif interaction_mode == "dragging":
		modulate = Color(1, 1, 1, 0.82)
	else:
		modulate = Color(1, 1, 1, 1.0)
	_refresh_style()
	_refresh_overlays(quality)


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
	# DropShadow 投影：增强卡牌厚度感（墨色低透明度，不喧宾夺主）。
	box.shadow_size = 6
	box.shadow_color = GuStyle.INK_DROP_SHADOW
	box.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", box)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 稀有度闪箔：epic+ 才开（shader 内 intensity<=0 直接 discard，普通卡零开销）。
func _refresh_overlays(quality: String) -> void:
	var key: String = GuStyle.quality_key(quality)
	_foil_intensity = float(FOIL_INTENSITY.get(key, 0.0))
	var foil_mat := _shimmer_overlay.material as ShaderMaterial
	if foil_mat != null:
		foil_mat.set_shader_parameter("intensity", _foil_intensity)
		foil_mat.set_shader_parameter("foil_color", GuStyle.ANOMALY_YELLOW)
		foil_mat.set_shader_parameter("tilt", _tilt)
	# 辉光颜色随稀有度描边，与卡框呼应。
	var glow_mat := _glow_overlay.material as ShaderMaterial
	if glow_mat != null:
		glow_mat.set_shader_parameter("glow_color",
				GuStyle.JADE if bool(get_meta("highlight", false)) else _quality_color(quality))


func _quality_color(quality: String) -> Color:
	return GuStyle.rarity_color(GuStyle.quality_key(quality))


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
