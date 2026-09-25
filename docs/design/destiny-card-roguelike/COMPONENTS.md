# 组件库规格（桌面优先）

> 命名：`Category/Name` · 变体属性用 `Variant`。全部绑定 Semantic token，禁止散落 HEX。

## Actions

### Button
| 属性 | 值 |
| --- | --- |
| Variant | `Primary` \| `Ghost` \| `Danger` \| `Quiet` |
| Size | `L`（主行动坞） \| `M`（默认） \| `S`（工具条） |
| State | `Default` \| `Hover` \| `Pressed` \| `Disabled` \| `Focus` |
| Props | `label` TEXT · `icon` BOOLEAN · `leadingIcon` INSTANCE_SWAP |

- Primary：金底 `action/primary-bg`，字 `night/0`，`effect/glow-gold`；Hover 提亮 8%  
- Ghost：透明 + `border/fate` 1px  
- Danger：仅描边与字用 `state/danger`  
- Focus：2px `accent/glow` 外描边  
- 最小高度：L=52 · M=40 · S=32

### IconButton
`Size 24/32/40` · `State` 同上 · 必须有 `tooltip` 文本属性

### SegmentedControl
`Options 2–5` · `selected` · 用于地图筛选、背包页签

---

## Data Display

### ResourceBar（HUD 资源）
| 属性 | 值 |
| --- | --- |
| Kind | `Qi` \| `Hp` \| `Life` \| `Stone` \| `Thought` |
| State | `Normal` \| `Low` \| `Critical` |
| Props | `value` · `max` · `label` |

- 条色：`meter/*`；Critical 时 `effect/glow-soft` 呼吸  
- 数值 `type/num-md` 等宽

### StatChip
`Kind Qi/Hp/Life/Stone` · `tone default/warn/danger` · 紧凑数字+图标

### GuCard（蛊卡）
| 属性 | 值 |
| --- | --- |
| Size | `M`（手牌/货架 220×300） \| `S`（合成槽 72×96） |
| School | `Force/Soul/Blood/Wisdom/Wood/Time` |
| Tier | `1–5`（道痕角标数） |
| State | `Default/Hover/Selected/Disabled/Spent` |
| Props | `name` · `cost` · `desc` · `count` |

结构：晶壳描边（流派色）+ 暗面 + 顶标费用 + 底标名称 + 中央核光

### KillMoveCard（杀招卡）
`Ready/Cooldown/Locked` · 组件槽点列表 · 合成结果摘要

### MapNode
| 属性 | 值 |
| --- | --- |
| Type | `Battle/Elite/Boss/Shop/Rest/Event/Seclusion` |
| State | `Locked/Available/Current/Done` |
| Props | `title` · `subtitle` · `segment` |

- Available：`border/fate` + 微光  
- Current：金色描边 + `glow-gold`  
- Done：压暗 30% + 左侧金线

### TimelineStep（时间长河刻度）
`done/current/future` · 用于五段进度脊、结算时间线

### ShopRow / SynthesisSlot
见 SCREENS 商店/合成

---

## Feedback

### Toast
`tone info/success/warn/danger` · 顶部居中 · 3s  
### Dialog
`title` · `body` · `confirm` · `cancel`（取消必须在）  
危险操作用 Danger 按钮 + 明确代价文案  
### Tooltip
`title` + `body` · 跟随鼠标 · 不挡主按钮  
### IntentBadge（敌方意图）
`Known/Hidden/Countered` · 朱砂点+短文案

---

## Navigation

### TopBar
Logo（问真式宋体题） · 资源组 · 设置入口  
### StageTabs / Breadcrumb
场景名只读；弱切换  
### ActionDock（主行动坞）
底栏固定高 76 · 左提示语 · 右主 Button L  
**规则：一屏只有一个金色主按钮**

### BackLink
`Quiet` 文字链，永远可回上级（游戏内为回行程）

---

## Cards / Surfaces

### Panel
`bg/surface` + `border/subtle` + `radius/3`  
### Sheet（结算/对话大卡）
`bg/raised` + `effect/card-rest` · max-width 720  
### Divider
1px `border/fate` @ 40% — 「命运丝线」

---

## 组合约束

1. 主行动只出现在 ActionDock 或屏内唯一主按钮，不重复双金钮  
2. 蛊卡流派色不得当按钮色  
3. 所有可点控件 Focus 态可见  
4. 触控目标 ≥ 44px（桌面兼容触屏）  
5. 禁止 emoji 当图标；用 SVG 单线图标（1.5 stroke）
