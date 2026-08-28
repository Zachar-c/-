class_name GuStyle
extends RefCounted

# ── Wen Zhen (問眞) Visual Tokens ──────────────────────────────────────
# Semantic source of truth for the minimal light UI redesign.
# Old dark-theme aliases kept at bottom for gradual migration; screens
# should consume the new tokens directly.

# —— Paper / background ——
const PAPER_BG     := Color("ece9df")       # 主表面、宣纸白
const PAPER_RAISED := Color("f4f1e8")       # 次级纸面、轻微下沉/禁用层
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

# ── Backward-compatible aliases (old dark-theme names) ──────────────────
# These keep existing screens compiling during migration.
# Gradually replace references with the new tokens above.

# Backgrounds
const BG_DEEP   := PAPER_BG        # was dark → now paper
const BG_PANEL  := PAPER_RAISED    # was dark panel → now raised paper
const BG_RAISED := Color("e8e4d8") # intermediate raised surface

# Ink / text (old names)
const INK       := INK_PRIMARY

# Primary text (old name "BONE" → now INK_PRIMARY for dark-on-light)
const BONE      := INK_PRIMARY
const BONE_DIM  := INK_SOFT

# Accent colors (old names)
const PAPER     := PAPER_BG
const PAPER_DIM := PAPER_DEEP

# Old semantic palette → Wen Zhen equivalents
const JADE_BRIGHT := Color("5d9680")  # was light jade → now slightly brighter jade
const GOLD      := Color("8c7a52")    # muted gold / resource accent
const GOLD_DIM  := Color("a8946f")    # dimmer gold
const SILVER    := Color("8a9196")    # cool accent
const EMBER     := Color("b87333")    # warm accent
const DANGER    := CINNABAR           # alias: old DANGER → new CINNABAR
const BLOOD     := Color("8e2f28")    # 深血锈（死亡线极端危险）
const ANOMALY_AMBER := ANOMALY_YELLOW # alias: old name → new ANOMALY_YELLOW
const ANOMALY_RED   := Color("b5523a") # DDA 衰运（黄红系，保留兼容）
