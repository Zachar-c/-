class_name GuStyle
extends RefCounted

# ── Wen Zhen (問眞) Visual Tokens ──────────────────────────────────────
# Semantic source of truth for the minimal light UI redesign.
# Formal UI token source. Screens and components consume these names directly.

# —— Paper / background ——
const PAPER_BG     := Color("ece9df")       # 主表面、宣纸白
const PAPER_RAISED := Color("e6e2d7")       # 次级纸面、轻微下沉/禁用层
const PAPER_DEEP   := Color("ddd8cc")       # 禁用层、轻分区

# —— Ink / text ——
const INK_PRIMARY  := Color("171814")       # 近黑墨色（主文字 / 主结构线）
const INK_SOFT     := Color("686960")       # 次要文字、已知但不紧急
const INK_MUTED    := Color("68675f")       # 介于 INK_PRIMARY 与 PAPER_BG

# —— Hairline / rule ——
const RULE := Color("aaa89f")
const HAIRLINE_COLOR := Color("aaa89f")        # 发丝分隔线色
const HAIRLINE     := 1                        # 发丝线宽 1px

# —— Semantic accent ——
const CINNABAR     := Color("9c332d")       # 朱砂：危险 / 不可逆 / 死亡线
const CONTRACT_BLUE := Color("315f73")      # 契约规则
const ANOMALY_YELLOW := Color("936f1e")     # DDA / 异变 / 险象
const JADE         := Color("3f7063")       # 护盾 / 正向 / 可恢复

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
const BODY_FONT: Font = null
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

static func rarity_color(rarity: String) -> Color:
	match str(rarity):
		"rare": return RARITY_RARE
		"epic": return RARITY_EPIC
		"legendary": return RARITY_LEGENDARY
		_: return RARITY_COMMON


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
