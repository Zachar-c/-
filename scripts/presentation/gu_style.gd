class_name GuStyle
extends RefCounted

# ── Wen Zhen (問眞) Visual Tokens ──────────────────────────────────────
# Semantic source of truth for the minimal light UI redesign.
# Formal UI token source. Screens and components consume these names directly.

# —— Paper / background ——
const PAPER_BG     := Color("ece9df")       # 主表面、宣纸白
const PAPER_RAISED := Color("e6e2d7")       # 次级纸面、轻微下沉/禁用层
const PAPER_DEEP   := Color("ddd8cc")       # 禁用层、轻分区
const PAPER_HALL   := Color("e5e2d7")       # 大厅 HTML 主纸面
const PAPER_MAP    := Color("e7e4da")       # 地图 HTML 主纸面

# —— Stage / narrative backdrop ——
# 叙事层：暗色南疆志怪绘卷的舞台底色。低饱和、偏冷、不是纯黑。
# 纸面UI浮在其上形成「命簿记录志怪世界」的层次。
const STAGE_BG       := Color("1b1e1d")     # 舞台主底色（深灰偏冷）
const STAGE_BG_DEEP  := Color("151716")     # 舞台深色（边缘/暗角）
const STAGE_HIGHLIGHT := Color("2a2f2d")    # 舞台微弱亮部（月光/磷光感）
const STAGE_VIGNETTE  := Color(0, 0, 0, 0.35)  # 暗角叠加
# 青茅山背景复用调变色：偏冷调暗 + 半透明，营造南疆山林氛围。
const STAGE_BACKDROP_DIM := Color(0.38, 0.42, 0.48, 0.35)

# 人物立绘调变色：偏冷调暗 + 半透明，让立绘融入南疆洞窟舞台而非UI主体。
const PORTRAIT_DIM := Color(0.55, 0.6, 0.68, 0.5)
# 敌人立绘偏色：按状态类型区分（中毒偏绿、诅咒偏紫），调暗半透明作剪影。
const ENEMY_PORTRAIT_POISON := Color(0.4, 0.55, 0.4, 0.45)
const ENEMY_PORTRAIT_CURSE := Color(0.5, 0.4, 0.55, 0.45)

# 战场雾气渐变：半透明冷灰水平渐变，模拟南疆湿冷山雾。
const FOG_COLOR_EDGE := Color(0.6, 0.65, 0.7, 0.08)
const FOG_COLOR_MID := Color(0.65, 0.7, 0.75, 0.12)

# 萤火颜色：暖黄色光点，模拟南疆山林夜间萤火（第三批V-F-14动态背景）。
const FIREFLY_COLOR := Color(1.0, 0.85, 0.4, 0.0)
const FIREFLY_COLOR_ON := Color(1.0, 0.85, 0.4, 0.8)

# 地图屏背景调变色：淡青茅山氛围，透明度低（0.18），不抢地图主体可读性。
const MAP_BACKDROP_DIM := Color(0.5, 0.52, 0.55, 0.18)

# 大厅屏背景调变色：极淡青茅山氛围（0.08），命簿背后的山水暗示，不影响可读性。
const HALL_BACKDROP_DIM := Color(1.0, 1.0, 1.0, 0.08)

# —— Ink / text ——
const INK_PRIMARY  := Color("171814")       # 近黑墨色（主文字 / 主结构线）
const INK_SOFT     := Color("686960")       # 次要文字、已知但不紧急
const INK_MUTED    := Color("68675f")       # 介于 INK_PRIMARY 与 PAPER_BG
const INK_HALL     := Color("171817")       # 大厅 HTML 主文字
const INK_MAP      := Color("1b1c19")       # 地图 HTML 主文字
const INK_MAP_NOTE := Color("64665f")       # 地图 HTML 注释文字
const INK_MAP_FAINT := Color("8b8d85")      # 地图 HTML 深度刻度
const INK_MAP_LABEL := Color("92948d")      # 地图 HTML 层级标签
const INK_MAP_VALUE := Color("252624")      # 地图 HTML 资源数值
const INK_MAP_NAME  := Color("666861")      # 地图 HTML 资源名称

# —— Hairline / rule ——
const RULE := Color("aaa89f")
const HAIRLINE_COLOR := Color("aaa89f")        # 发丝分隔线色
const RULE_HALL := Color("b8b6aa")             # 大厅 HTML 发丝线
const HAIRLINE     := 1                        # 发丝线宽 1px

# —— Semantic accent ——
const CINNABAR     := Color("9c332d")       # 朱砂：危险 / 不可逆 / 死亡线
const CONTRACT_BLUE := Color("315f73")      # 契约规则
const ANOMALY_YELLOW := Color("936f1e")     # DDA / 异变 / 险象
const JADE         := Color("3f7063")       # 护盾 / 正向 / 可恢复

# 淡染层（TINT_*）：语义色的半透明变体，只做徽章 / 警示条 / 死线行的**底**，
# 绝不当文字色。半透明是为了让下层纸纹透出来，符合「不搞玻璃卡片」的原则。
# 这组常量存在的唯一理由：调用点不许再写裸 Color(0.x, 0.x, 0.x, a)。
const TINT_BLOOD      := Color(0.55, 0.18, 0.15, 0.25)  # 危险死线行、结算危险块
const TINT_BLOOD_DEEP := Color(0.5, 0.12, 0.1, 0.85)    # 确认弹窗警示条（近实）
const TINT_CONTRACT   := Color(0.3, 0.4, 0.5, 0.25)     # 契约徽章底
const TINT_ANOMALY    := Color(0.5, 0.35, 0.15, 0.25)   # 异变 / DDA 徽章底

# Rarity remains an identification accent, not a surface color.
const RARITY_COMMON := INK_SOFT
const RARITY_RARE := CONTRACT_BLUE
const RARITY_EPIC := Color("76528f")
const RARITY_LEGENDARY := Color("8c6b25")

const CURSE_GLYPH := "⚠"
const CONTRACT_GLYPH := "契"
const DDA_GLYPH := "异"

# The only packaged font is owner-authorized for this noncommercial build.
# Body copy deliberately uses Godot's default until a separately cleared body face arrives.
const TITLE_FONT := preload("res://assets/wenzhen/fonts/LXGWZhiSongCL-Regular.ttf")
# 中文正文必须走同一套宋体：引擎默认回退是无衬线，与宣纸/宋标题断风格。
const BODY_FONT: Font = TITLE_FONT

# —— Reusable texture assets (GDQuest, purchased; visual-reference-index §3 mandates reuse) ——
const LIFE_BAR_FILL := preload("res://assets/theme/bar/life_bar_fill.png")
const LIFE_BAR_BG := preload("res://assets/theme/bar/life_bar_bg.png")

const SCREEN_MARGIN := 32
const TOP_BAR_HEIGHT := 72

# —— Spacing ——
const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32

# —— Radius ——
const RADIUS_SMALL := 4
const RADIUS_MEDIUM := 6
const RADIUS_LARGE := 8
const RADIUS_PILL := 16

# —— Shadow ——
# 冷峻旧宣纸风格的阴影系统：低透明度、柔和偏移、不搞厚重投影。
const SHADOW_SMALL_COLOR := Color(0, 0, 0, 0.06)
const SHADOW_SMALL_SIZE := 2
const SHADOW_SMALL_OFFSET := Vector2(0, 1)
const SHADOW_MEDIUM_COLOR := Color(0, 0, 0, 0.10)
const SHADOW_MEDIUM_SIZE := 4
const SHADOW_MEDIUM_OFFSET := Vector2(0, 2)
const SHADOW_LARGE_COLOR := Color(0, 0, 0, 0.15)
const SHADOW_LARGE_SIZE := 8
const SHADOW_LARGE_OFFSET := Vector2(0, 4)

# —— Typography scale ——
# 字体大小层级：从徽标到注释，统一走常量，不许散落裸数字。
const FONT_DISPLAY := 96    # 大厅問眞徽标
const FONT_H1 := 32         # 屏幕主标题
const FONT_H2 := 24         # 面板标题
const FONT_H3 := 18         # 卡片标题/小节标题
const FONT_BODY := 14       # 正文
const FONT_BODY_SMALL := 13 # 次要正文
const FONT_CAPTION := 12    # 注释/标签
const FONT_MICRO := 10      # 角标/极小文字

# —— Decoration ——
# 朱砂装饰线：标题栏左侧的短竖线，营造命簿批注感。
const CINNABAR_RULE_WIDTH := 3
const CINNABAR_RULE_HEIGHT := 18
# 面板标题栏与内容区的分隔发丝线
const TITLE_DIVIDER_COLOR := Color("c8c5ba")
const TITLE_DIVIDER_WIDTH := 1

static func rarity_color(rarity: String) -> Color:
	match str(rarity):
		"rare": return RARITY_RARE
		"epic": return RARITY_EPIC
		"legendary": return RARITY_LEGENDARY
		_: return RARITY_COMMON


# Quality is presented as a Chinese display string on cards ("普通/稀有/史诗/传说").
# 品质色统一走 rarity_color，避免两套色轨矛盾（2026-09-06 视觉审计修复）。
static func quality_color(quality: String) -> Color:
	return rarity_color(quality)


static var _resource_vocabulary = preload("res://scripts/presentation/resource_vocabulary.gd")


static func resource_normalize(kind: String) -> String:
	return _resource_vocabulary.normalize(kind)


static func resource_label(kind: String) -> String:
	return _resource_vocabulary.label(kind)


static func resource_suffix(kind: String) -> String:
	return _resource_vocabulary.suffix(kind)


static func resource_color(kind: String) -> Color:
	match _resource_vocabulary.normalize(kind):
		"lifespan": return INK_PRIMARY
		"soul", "material": return JADE
		_: return ANOMALY_YELLOW


static func contract_color() -> Color:
	return CONTRACT_BLUE


static func curse_color() -> Color:
	return CINNABAR


static func dda_color() -> Color:
	return ANOMALY_YELLOW


static func _panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_RAISED
	sb.border_color = HAIRLINE_COLOR
	sb.set_border_width_all(HAIRLINE)
	sb.set_corner_radius_all(RADIUS_SMALL)
	sb.set_content_margin_all(SPACE_2)
	return sb


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_stylebox())
	return p


static func button(text: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK_PRIMARY)
	b.add_theme_color_override("font_disabled_color", INK_MUTED)
	b.add_theme_color_override("font_hover_color", INK_PRIMARY)
	b.add_theme_color_override("font_pressed_color", CINNABAR)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PAPER_RAISED
	normal.border_color = HAIRLINE_COLOR
	normal.set_border_width_all(HAIRLINE)
	normal.set_corner_radius_all(RADIUS_SMALL)
	b.add_theme_stylebox_override("normal", normal)
	var disabled := normal.duplicate()
	disabled.bg_color = PAPER_DEEP
	b.add_theme_stylebox_override("disabled", disabled)
	return b


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
