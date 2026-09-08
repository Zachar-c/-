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
# —— Map tokens (2026-09-08 基准同步)：值与基准采样色对齐，与大厅 token 同源 ——
const INK_MAP      := Color("171814")       # 地图 主文字 = INK_PRIMARY
const INK_MAP_NOTE := Color("607060")       # 地图 注释文字 = NOTE_TEXT
const INK_MAP_FAINT := Color("888880")      # 地图 深度刻度 = VER_TEXT
const INK_MAP_LABEL := Color("707870")      # 地图 层级标签 = CORNER_TEXT
const INK_MAP_VALUE := Color("252624")      # 地图 资源数值（基准 32,32,32 深灰）
const INK_MAP_NAME  := Color("606860")      # 地图 资源名称 = STAT_NAME_TEXT

# —— Map route-node card tokens (2026-09-07 v1 wireframe) ——
# 节点卡三态视觉沉淀在公共 token：此刻=墨框+朱砂左线、下一程=浅底墨框、
# 再前=透明淡边。屏代码只消费 token，不私有硬编码色值。
const NODE_CURRENT_BORDER := Color("343430")  # 此刻：墨框
const NODE_REACH_BG       := Color("f6f3e9")  # 下一程：浅纸底
const NODE_REACH_BORDER   := Color("9a978c")  # 下一程：清晰墨框
const NODE_FUTURE_BORDER  := Color("c9c6b8")  # 再前：淡墨边（Godot 无虚线，以淡实框近似）
const NODE_FUTURE_INK     := Color("a4a49b")  # 再前：标题文字
const NODE_KIND_INK       := Color("6d6e64")  # 节点类别文字
const NODE_MARK_RADIUS    := 8                # 角标圆角（线框稿 8px）
const NODE_LEFT_LINE      := 4                # 此刻/选中：朱砂左标线宽
const ENEMY_CARD_BORDER   := Color("d5d3c6")  # 敌人卡纸白边框（线框稿 .enemy 边框）
const ENEMY_CARD_TEXT     := Color("56564c")  # 敌人卡状态行文字（线框稿 .sts 文字）

# —— School-select card tokens (2026-09-08 school wireframe v1) ——
# 流派选择卡：纸面半透明淡底（让网点透出）+ 选中朱砂描边 / 未选中发丝描边。
# 半透明纸底与「不搞玻璃卡片」原则兼容：底色本身是纸面家族，仅降低不透明度透纸纹。
const SCHOOL_CARD_BG_SELECTED := Color(0.91, 0.898, 0.859, 0.55)  # 选中：略深纸底
const SCHOOL_CARD_BG_IDLE     := Color(0.91, 0.898, 0.859, 0.4)   # 未选中：更浅纸底
const SCHOOL_CARD_BORDER_SELECTED := Color("82463e")              # 选中：朱砂描边（线框稿 .sel）
const SCHOOL_CARD_BORDER_IDLE     := Color("b7b7ab")              # 未选中：发丝描边（线框稿 .card）


# —— Hairline / rule ——
const RULE := Color("aaa89f")
const HAIRLINE_COLOR := Color("aaa89f")        # 发丝分隔线色
const RULE_HALL := Color("b8b6aa")             # 大厅 HTML 发丝线
const HAIRLINE     := 1                        # 发丝线宽 1px

# —— Semantic accent ——
const CINNABAR     := Color("9c332d")       # 朱砂：危险 / 不可逆 / 死亡线
## 旧朱砂印泥色（2026-09-08 基准图印章区重采样）：框/文字笔画核心 (168,112,104)≈#A87068，
## 抗锯齿边缘扩散至 #AC7870~#C09C94——Codex 基准印章为氧化褪色的暗红印泥，非鲜朱砂。
## 2026-09-08 审计后加深一档 → #a06058，抵消 1px 细框+小字的抗锯齿变浅。
const SEAL_CINNABAR := Color("8c5850")
## 基准图逐元素重采样文本色（2026-09-08 审计，全部来自 Codex 基准图采样）：
const SUBTITLE_TEXT   := Color("707060")   # 副题（凡人逐道，代价自负）灰褐
const NAV_TEXT        := Color("505040")   # 右栏 手记/图鉴/设置/退出 灰褐
const NOTE_TEXT       := Color("607060")   # 说明文字（将从…继续）绿灰
const STAT_NAME_TEXT  := Color("606860")   # 属性名（修为/寿元/蛊囊/节点）绿灰
const VER_TEXT        := Color("888880")   # 版本号 灰
const CORNER_TEXT     := Color("707870")   # 左上角（叁宫·南盟/参考·高级）灰绿
const STATUS_CONTRACT := Color("506880")   # 状态·契约 蓝灰
const STATUS_MUTATE   := Color("887830")   # 状态·异变 橄榄黄
const STATUS_CURSE    := Color("904038")   # 状态·诅咒 砖红
const HILITE_PLACE    := Color("c89860")   # 上一世地点 橙棕
const HILITE_REALM    := Color("6898c0")   # 上一世境界 蓝灰
const HILITE_NOTE     := Color("98c8d8")   # 札记名 青蓝
## 主按钮「续入此世 >」双色描边（2026-09-08 基准图逐像素确认：黑字芯 + 蓝右描边 + 铁锈橙红左投影）：
const BTN_OUTLINE_BLUE := Color("3880b8")  # 蓝色描边
const BTN_SHADOW_RUST  := Color("803810")  # 铁锈橙红 左侧投影
const CONTRACT_BLUE := Color("506880")      # 契约规则（2026-09-08 基准同步 = STATUS_CONTRACT）
const ANOMALY_YELLOW := Color("887830")     # DDA / 异变 / 险象（基准同步 = STATUS_MUTATE）
const JADE         := Color("3f7063")       # 护盾 / 正向 / 可恢复

# —— Button color tokens (shadcn/ui风格：品牌色背景 + 高对比度浅色文字) ——
# Primary按钮：朱砂色背景 + 白色文字
const BTN_PRIMARY_BG := CINNABAR
const BTN_PRIMARY_HOVER := Color("8a2c27")  # 朱砂hover加深
const BTN_PRIMARY_PRESSED := Color("7a2621") # 朱砂pressed更深
const BTN_PRIMARY_FG := Color("ffffff")      # 高对比度白色文字
# Danger按钮：深红背景 + 白色文字
const BTN_DANGER_BG := Color("a6241e")       # 深红
const BTN_DANGER_HOVER := Color("8c1e19")    # 深红hover加深
const BTN_DANGER_PRESSED := Color("731814")  # 深红pressed更深
const BTN_DANGER_FG := Color("ffffff")        # 高对比度白色文字

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


## 公用印章组件（2026-09-08 基准图重采样校准 v2）：透明底（网点透出）+ 旧朱砂 2px 细框
## + 2×2 竖排旧朱砂印泥字（基准图实测：框与字同为褪色暗红 #A87068 系，非墨色）+ 微斜 -3°。
static func apply_seal(panel: PanelContainer, tilt_deg: float = 3.0) -> void:
	if panel == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = SEAL_CINNABAR
	box.set_border_width_all(2)
	box.set_corner_radius_all(0)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	panel.rotation = deg_to_rad(tilt_deg)
	var top: Label = panel.get_node_or_null("SealCenter/SealBox/SealTop") as Label
	var bottom: Label = panel.get_node_or_null("SealCenter/SealBox/SealBottom") as Label
	for label in [top, bottom]:
		if label == null:
			continue
		label.add_theme_font_override("font", TITLE_FONT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", SEAL_CINNABAR)
