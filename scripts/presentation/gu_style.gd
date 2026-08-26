class_name GuStyle
extends RefCounted

# 统一设计系统配色（自 gu_theme.tres 迁移 + 规格书 2026-08-26-ui-sts-redesign-design §3.1 全 token）。
# RUI 的 .guitkx 组件在 style={...} 中以 GuStyle.JADE 等内联引用全局类常量。
# 整屏主题统一通过 @theme "res://assets/theme/gu_theme.tres" 挂载（见各组件文件头）。

# —— 底色层级（夜色墨青）——
const BG_DEEP := Color("0f1418")      # 全局最底层
const BG_PANEL := Color("1c2326")     # 面板 / 卡片底
const BG_RAISED := Color("263034")    # 凸起元素 / 卡面
const INK := Color("1c1b17")          # 墨（描边 / 深色块）

# —— 语义主色 ——
const JADE := Color("7fae9b")         # 主 / 正向 / 玉
const JADE_BRIGHT := Color("a8d4c0")  # 蛊虫青白微光（高亮 / 选中）
const GOLD := Color("d7c6a1")         # 资源 / 元石 / 点缀
const GOLD_DIM := Color("a8946f")     # 资源次级 / 禁用金
const SILVER := Color("c9d4d8")       # 月光银（第二光源 / 冷强调）
const EMBER := Color("d98e4a")        # 烛火橙（暖点缀 / 稀有）

# —— 危险 / 诅咒 / 反噬 ——
const DANGER := Color("c0392b")       # 诅咒 / 反噬 / 危险
const BLOOD := Color("8e2f28")        # 血锈深（死亡线 / 极端危险）

# —— 文字与承载 ——
const BONE := Color("d8d2c4")         # 正文
const BONE_DIM := Color("c6d3cf")     # 次要文字
const PAPER := Color("e8dcc0")        # 宣纸米黄（图标底 / 文字承载）
const PAPER_DIM := Color("c9bda0")    # 宣纸暗（图例 / 卷轴）

# —— 元机制分区（§16.13 契约蓝 / 异变黄红）——
const CONTRACT_BLUE := Color("7aa7c9")   # 契约标识（蓝系）
const ANOMALY_AMBER := Color("c9a24a")   # 本局异变 / DDA 险象（黄红系）
const ANOMALY_RED := Color("b5523a")     # DDA 衰运（黄红系）
