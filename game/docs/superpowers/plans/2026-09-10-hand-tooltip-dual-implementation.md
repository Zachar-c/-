# 手牌解释栏的两个实现：对比、冲突与取舍

- **日期**：2026-09-10
- **背景**：仓库里同时存在两套"悬停显示卡牌详情"的实现，各自完整、各自能跑，但**不能共存**。
  本文把两者的差异与冲突讲清楚，并给出取舍建议。
- **结果（2026-09-10 已落地）**：采纳 §4 的建议——**保留生产版**，手牌换用 `GuTallFanHandView`（本身不带 tooltip，
  只发 `hover_changed`），并把 `GuFanHandView`（内建 tooltip 的那一版）与 `GuBattleHandView` 一并删除。
  终局结构：**解释栏归宿主**（`battle_hand_tooltip_host` + `GuTooltipViewView`），**排布与手势归组件**。
  因此 §2 的三处冲突（双弹 / 内容模型不匹配 / 样式漂移）随组件删除自然消失，不需要额外补偿逻辑。

---

## 1. 两个版本分别在哪

| | **版本 A：生产版（宿主拥有）** | **版本 B：组件版（组件自建）** |
|---|---|---|
| 归属 | `BattleScreenView` 持有，节点在 .tscn 里 | `GuFanHandView` 自己 `new()` 出来 |
| 文件 | `battle_screen_view.gd:977-1030` + `scenes/ui/screens/battle_screen.tscn:283-305` + `gui_tooltip_view.tscn`（`GuTooltipViewView`） | `gu_fan_hand_view.gd:315-406` |
| 节点路径 | `$Root/battle_hand_tooltip_host` | 组件内 `fan_hand_tooltip`（`add_child` 到自己） |
| 触发 | 手牌 `_on_hover(card)` → `_hovered_card` → `_refresh_tooltip()` | 组件 `_on_card_mouse_entered` → `_show_tooltip(index)` |
| 数据来源 | **战斗快照的 `card` 字典**（宿主喂的键） | **组件内 `_data[index]`**（组件自己拿着的那份） |
| 内容段 | 品质 / 效果 / **联动** / **代价** / **不可用** / **诅咒警示** / **风险** + 「详情」按钮 | 卡名 + **`keywords[]` 逐条**；无 keywords 时回落 `effect` 一行 |
| 定位 | 锚定**被悬停的卡**上方，算入悬停抬升量，越界翻转/钳制视口 | 锚定卡上方居中，放不下翻到卡下方，钳制视口 |
| 宽度 | 按内容自适应，`clamp(180, 视口−24)` | `TOOLTIP_MIN_WIDTH = 180` 起，`clamp(180, 视口−24)` |
| 样式 | `PAPER_RAISED` 底 + `HAIRLINE_COLOR` 1px 边 + `RADIUS_SMALL`（`battle_screen_view.gd:1052`） | `PAPER_BG` 底 + `HAIRLINE_COLOR` 1px 边 + `RADIUS_SMALL` + 中投影（`gu_fan_hand_view.gd:321`） |
| `mouse_filter` | `2`（IGNORE）——在 .tscn 里写死 | `MOUSE_FILTER_IGNORE` | `top_level` | `true`（.tscn） | `true`（代码） |
| 手势期 | `_drag_active or _aim_active` 时**强制收起** | 无此逻辑（拖拽时仍可能挂着） |
| 交互 | 有「详情」按钮（可点） | 无交互 |

**两边都做对了的共同点**（说明这两条是踩过坑的硬要求）：`top_level = true`（不撑高布局、不被容器裁剪）、`mouse_filter = IGNORE`（绝不吃鼠标，否则悬停卡瞬间失焦抖动）。

---

## 2. 三个真实冲突

### 冲突一：会把解释栏弹**两次**

两者各自独立触发，互不知情：

- 鼠标进入卡 → 组件 `_on_card_mouse_entered` → **组件弹自己那个**
- 同一时刻组件 `hover_changed.emit(card_id)` → 宿主 `_on_card_hover(card)` → **宿主又弹自己那个**

结果：卡上方叠两层面板。而且两层内容与宽度都不同，边缘会错开几个像素，看起来像"重影的输入框"。

这不是理论推演——两个实现的数据来源不同（见冲突二），所以在真实数据下**两层显示的内容还不一样**。

### 冲突二：内容模型不匹配，组件版在真实数据下丢 5 个段位

这是最严重的一条，而且**不会报错**：

```
组件版读：card["keywords"]  →  全仓库只有 gu_fan_hand_view.gd 与它的探针构造过这个键
真实快照 ：没有 keywords     （已验证：grep -rn '"keywords"' scripts/ 只命中组件自身）
```

组件版的逻辑是：

```gdscript
var keywords: Array = card.get("keywords", [])
if keywords.is_empty():
    _tooltip_body.add_child(_tooltip_line(str(card.get("effect", "")), ...))   # 只回落效果一行
```

于是**在真实对局里**，组件版解释栏永远只显示「卡名 + 效果一行」。而生产版会显示：

| 段位 | 生产版 | 组件版（真实数据） |
|---|---|---|
| 品质（带品质色） | ✓ | ✗ |
| 效果 | ✓ | ✓（回落） |
| 联动 | ✓ | ✗ |
| **代价** | ✓ | ✗ |
| **不可用原因**（`block_reason`） | ✓ | ✗ |
| 诅咒警示 | ✓ | ✗ |
| **风险**（`_known_risk_text`） | ✓ | ✗ |
| 详情按钮 | ✓ | ✗ |

这直接撞 AGENTS.md 的红线：**"不可用"与"代价"必须执行前可见**、**不得隐藏关键成本与死亡风险**。也就是说组件版**不能直接拿来当生产解释栏**——它是个"看起来能跑"的空壳。

### 冲突三：样式与定位细节漂移

- 底色不同：`PAPER_RAISED` vs `PAPER_BG`（前者更亮一档，用于"抬起"语义）
- 投影：生产版无投影，组件版有 `SHADOW_MEDIUM`
- 定位：生产版**算入了悬停抬升量**（`anchor.size.y × (HOVER_CARD_SCALE−1)`），组件版用 `get_global_transform().origin` 近似
- 生产版手势期强制收起；组件版没有

这些都是"换个组件就悄悄变样"的差异，不做统一就会在截图对比时反复出现"怎么这次位置不太对"。

---

## 3. 画面示意

（见随附三张图：两版并存的双弹、内容模型差异、定位算法差异。）

---

## 4. 建议：**保留生产版，把组件版降级为纯布局组件**

理由：

1. 生产版承载**风险/代价/不可用**这些有红线约束的段位，且已接 `GuTooltipViewView` 的固定段序 + 详情按钮；
2. `GuFanHandView` / `GuTallFanHandView` 的定位是**排布与手势**，解释栏不是它的职责（它不知道 `block_reason`、`curse_warning`、风险文本从哪来）；
3. 契约上，快照键本来就归宿主，组件去读私有 `_data` 属于越权。

具体动作（3 处小改）：

| 动作 | 文件 | 说明 |
|---|---|---|
| 删掉组件内的 tooltip（`_build_tooltip` / `_show_tooltip` / `_tooltip_line` / `_place_tooltip` / `_hide_tooltip` 及 `_tooltip`/`_tooltip_body` 字段） | `gu_fan_hand_view.gd` | 约 90 行净删；`hover_changed` 信号保留，宿主拿它渲染统一解释栏 |
| 宿主侧统一从 `hover_changed(card_id)` 驱动 `_hovered_card` + `_refresh_tooltip()` | 接入时 | 生产版已有这条链路，只需把 `_on_card_hover` 的入参从 `card` 字典改为 `card_id` 再查表 |
| `HOVER_CARD_SCALE` 这类跨类引用改成宿主自己的常量 | `battle_screen_view.gd` | 换组件后不会断 |

> 顺带说明：`GuTallFanHandView`（本轮竖长卡组件）**没有**内建解释栏，只发 `hover_changed` —— 它一开始就是按"解释栏归宿主"设计的，可以视为目标形态。需要清理的是更早的 `GuFanHandView`。

---

## 5. 两个组件的关系（避免再混淆）

| 组件 | 卡形 | 排布 | 解释栏 | 拖拽/瞄准 | 定位 |
|---|---|---|---|---|---|
| `gu_battle_hand_view.gd` | 168×74 横向 | `HBoxContainer`（不重叠） | 无（宿主渲染） | 无（宿主接管） | **生产在役** |
| `gu_fan_hand_view.gd` | 168×74 横向 | 普通 `Control` + 扇形 | **自带（应删）** | 无 | 参考实现，定位与生产版重叠 |
| `gu_tall_fan_hand_view.gd` | 110×154 竖长 | 普通 `Control` + 扇形 | 无（只发 `hover_changed`） | **内置（含弧形箭 + 信号）** | 候选，待接入 |

建议终局：**生产版保留壳层职责（解释栏 / 命令提交），排布与手势委托给 `GuTallFanHandView`，`GuFanHandView` 删除**（避免三份扇形数学各自漂移）。
