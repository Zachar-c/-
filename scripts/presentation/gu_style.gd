class_name GuStyle
extends RefCounted

# 统一设计系统配色（自 gu_theme.tres 迁移）。
# RUI 的 .guitkx 组件在 style={...} 中以 GuStyle.JADE 等内联引用全局类常量。
# 整屏主题统一通过 @theme "res://assets/theme/gu_theme.tres" 挂载（见各组件文件头）。

const BG := Color("1c1b17")        # 墨 / 皮纸深底
const JADE := Color("7fae9b")      # 主 / 正向
const GOLD := Color("d7c6a1")      # 资源 / 点缀
const DANGER := Color("c0392b")    # 诅咒 / 反噬 / 危险
const BONE := Color("d8d2c4")      # 正文
const BONE_DIM := Color("c6d3cf")  # 次要文字
