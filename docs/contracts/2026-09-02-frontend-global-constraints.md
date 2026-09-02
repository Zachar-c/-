# 前端全局约束：全局 UI 设计规范与公共基础组件约定（spec-v4 第九批·第二步产出）

> 日期：2026-09-02
> 上游依据：[接口契约](2026-09-02-domain-ui-contract.md)（第一步产出）。本档定义**所有前端生成必须遵守的全局约束**；第三步生成任何页面前，逐条对照本档。
> 现状基线：`master @ a9e6384`。本档大量条目直接编码自仓库既有实现与守卫测试（`test_ui_rules_guard.gd`），它们不是新发明，是把既有惯例成文并扩展到待生成代码。

---

## 一、全局 UI 设计规范

### 1.1 设计语言（宣纸与墨）

- 配色唯一来源是 `scripts/presentation/gu_style.gd` 的常量（`PAPER_BG / PAPER_RAISED / PAPER_DEEP / INK_PRIMARY / INK_SOFT / ...` 及 `rarity_color / quality_color / resource_color / contract_color / curse_color / dda_color` 等语义色函数）。**禁止**在任何场景/脚本里写 `Color("...")` 字面量——`test_ui_rules_guard.test_no_hardcoded_colors_in_new_stack` 会抓。
- 长度量纲唯一来源是同文件令牌：`SPACE_1..6 = 4/8/12/16/24/32`、`RADIUS_SMALL = 4`；圆角**封顶 4px**（守卫测试强制）。禁止出现 8/12/16 圆角或自造间距。
- 字体只允许在 `gu_style.gd` 预加载（守卫强制）；字号层级跟随 `gu_theme.tres` 的默认主题字号，不在组件里另设 font 资源。
- 图标只走 `gu_icon` 注册表（守卫强制：`test_icons_go_through_gu_icon_registry`），注册表文件必须真实存在。

### 1.2 主题与外观变体

- 全局唯一主题 `res://gu_theme.tres`；组件样式一律走 `theme_type_variation`（现役范例：`CardView` / `CardViewDim`——`Dim` 后缀表示同族禁用/降权态）。新变体命名 `<族名>[Dim|Emph|Danger]`，在主题里登记后才能引用。
- 屏根节点必须是 `MarginContainer`（守卫强制：`test_screen_roots_are_margin_containers`）；HTML 合成屏遵守"自管页边距"（`d5d7eaa` 的教训成文）。

### 1.3 画布与布局

- 视口 1920×1080、窗口 maximized（`project.godot`）；设计以 1080p 为基准，允许缩放不允许多套布局。
- 布局节奏：屏根 margin 用 `SPACE_5`/`SPACE_6`；卡片与分区之间 `SPACE_3`/`SPACE_4`；控件内部 `SPACE_1`/`SPACE_2`。左上信息、右下操作是战斗与遭遇屏的固定朝向；顶栏（`gu_top_bar`）常驻资源与回合信息。

### 1.4 信息透明规范（§17.2，前端最高优先级约束）

1. **每个数字都来自快照键**：界面上出现的任何数值（成本、概率、替代率、伤害、承载、饥饿预测）必须绑定接口契约列出的快照键；禁止 UI 层计算、估算或拼装数字。找不到键 = 走"快照键 + 同源测试"流程补快照，不是在 UI 里硬算。
2. **数值文案禁模糊**（§16.5 既有守卫）：成本与风险用精确值（"真元 5%"，不是"消耗少量真元"）；`DisplayText` 负责把 id 转中文名，前端不手写 id 对应文案。
3. **不可逆与死亡透明**：凡预检返回结构化代价/风险的命令（`cost_sources`、`lethal_confirm_required`、`unfed_value_note`、`permanent_losses`、`release_gu` 后果、饥饿死亡预测），必须**在触发确认之前**完整展示；致死确认必须显示精准死因（`gu_death_cause_overlay` 承载）。
4. **旁路信息永不渲染**：`_` 前缀键（`_snapshot`、`_feeding_*`）只进事件归因流水，任何屏不得展示。
5. **拒绝可见**：被拒绝的操作必须把 `_REJECTION_TEXT` 的中文原因展示出来（toast 或就地提示），不允许静默失败。

### 1.5 交互状态规范（每个可交互元素五态）

| 态 | 判定来源（契约） | 表现 |
| --- | --- | --- |
| 可执行 | 快照 `executable=true` / 预检 `ok` | 正常态可点 |
| 禁用+原因 | `executable=false` + `block_reason` + `remedy_hints[]` | `Dim` 变体 + 原因就地展示（悬停/长按出 remedy_hints） |
| 待确认 | 命令属 §1.6 确认层级 | 点击先弹确认，不直接提交 |
| 过期 | `state_version`/`hand_version` 不匹配被拒 | 提示"局面已变化"并触发快照重建，不留死按钮 |
| 提交中 | 命令已提交未返回 | 原子禁用（防双击），返回后按 `ok/reason` 复位 |

死按钮、假状态、不可达交互是 AGENTS 明令禁止项；第三步生成验收时按此表逐控件核对。

### 1.6 确认层级（不可逆操作规范）

1. **直接执行**：普通可逆操作（移动、查看、普通交易报价预览）。
2. **单次确认**：`gu_confirm_dialog`——触发条件来自契约中的结构化信号：永久失去项清单（`exchange_screen.permanent_losses`）、寿元/魂魄类支付（`lifespan_trade_warning`）、灭蛊、释放（展示 `release_gu` 后果）、献炼核心作辅蛊（`aux_core_warning`）、饥饿结算排序提交。确认框内容必须逐项列出失去物，不允许只有"确定/取消"。
3. **二次确认 + 精准死因**：任何 `lethal_confirm_required=true` 的预检（超载、放血、魂魄膨胀）——第一层确认展示死因与数值，第二层确认才提交；`gu_death_cause_overlay` 承载死因展示。
4. **非死亡特殊结局**（兽化等）：阈值达到只出提示标记，终局必须玩家主动二次确认（阶段八接口）。
5. 系统永远不替玩家做确认级以上的决定；确认框没有"不再询问"。

### 1.7 反馈与事件流

- 操作结果用 `gu_toast` 呈现 `feedback/reason` 文案；战斗内致命与结算用覆盖层。
- 事件流渲染只消费事件日志契约（§4 的 action 词表 + `DisplayText.action` 中文名）；归因视图按事件序号（逻辑时钟）排列，不使用墙钟。

### 1.8 文案与命名规范

- 玩家可见文本一律 UTF-8 中文；id → 中文名只经 `DisplayText`（`gu/node/enemy/material/curse/inheritance/action/type` 各表），快照已带中文的字段直接用。
- 代码标识符、文件名、信号名全 ASCII；组件类名 `Gu` 前缀 + PascalCase。
- 屏名/路由使用契约 §7 的固定集合，新增屏属于契约变更，需先补快照再生成。

### 1.9 验收门槛（每个生成物）

1. `test_ui_rules_guard.gd` 全绿（颜色/圆角/屏根/字体/图标五守卫 + 新屏纳入守卫扫描范围）。
2. 契约键绑定核对：屏上每个数值/按钮可指出其快照键与命令 type（评审时逐控件对表）。
3. 五态核对（§1.5）+ 确认层级核对（§1.6）。
4. 真实渲染核对：Godot 实跑截图，禁止单测绿即算 UI 完成（AGENTS：UI 改动必须核对真实渲染）。

---

## 二、公共基础组件约定

### 2.1 现役组件登记表（复用优先，禁止重复造）

| 组件 | 路径 | 职责契约 |
| --- | --- | --- |
| `GuTopBar`（gu_top_bar） | `scenes/ui/widgets` | 常驻顶栏：资源 chips（走 `gu_resource_chip`）、层/阶段、回合信息；数据源=快照顶栏键 |
| `GuResourceChip` | 同上 | 单资源显示：`GuStyle.resource_label/suffix/color` + 数值；禁止在业务屏手拼资源文本 |
| `GuStatBar`（gu_stat_bar） | 同上 | 比例条（hp/真元/承载/安分）：必须携带"当前/上限"两个快照键，不允许无上限的单值条 |
| `GuPanel` | 同上 | 标准分区容器（`GuStyle.panel()`），统一内边距 `SPACE_2` |
| `GuIcon` | 同上 | 唯一图标入口（注册表制） |
| `GuToast` | 同上 | 反馈提示；绑定 `_REJECTION_TEXT` 文案或快照 feedback |
| `GuTooltipView` | 同上 | 悬停详情；**数值必须来自快照键**（§16.5） |
| `GuConfirmDialog` | 同上 | §1.6 单次确认：必须支持逐项失去物列表 + 结构化代价 + 致死死因模式（复用 `gu_death_cause_overlay`） |
| `GuEnemyActor` | 同上 | 敌人展示：hp/shield/statuses/intent/alive 全量绑定 |
| `GuCard` / `CardView`(GuHandCardView) / `GuBattleHand` / `HandPanel` | `scenes/ui/widgets` + `scenes/ui` | 卡牌实例视图与手牌区：主题变体 `CardView[Dim]`、`%HandBox` spawn 模式、溢出滚动 |
| `GuDeathCauseOverlay` | 同上 | 致死/终局死因覆盖层 |
| `DebugPanel` | 同上 | 只读调试段（§16.22），仅 debug 构建 |

### 2.2 待新增公共组件规范（第三步生成时按此实例化，先组件后页面）

| 组件 | 绑定契约（来源模块） | 关键规则 |
| --- | --- | --- |
| `GuCommandButton` | 任意命令 type + 字段模板 | 唯一命令提交入口：内置 `state_version` 戳、五态（§1.5）、拒绝 reason → toast；业务屏禁止直接 `submit_command` |
| `GuLedgerBadge` | battle2 ledger（thoughts_left/thought_used/reserved/maintained/gu_used/actions_used） | 回合账本徽章：念头池与四基础动作使用权、维持占用 |
| `GuDistanceBand` | `Battle2Constants.DISTANCES` + 快照距离键 | 四级距离带指示（接触/近/中/远），只显档位不显数值进度 |
| `GuIntentBadge` | 敌人意图键 | 意图 + 反应窗口开放标记；窗口开放必须可点出反应选项 |
| `GuCostBreakdown` | `cost_sources[]` / `cost{}` | 结构化代价清单（凭证/元石/材料/寿元/魂魄/禁忌逐项） |
| `GuPermanentLossList` | `exchange_screen.permanent_losses` / `unfed_value_note` | 永久失去项列表（确认框内嵌组件） |
| `GuHungerBanner` | `FeedingRules.preview_settle` 键（will_hunger/will_die） | 结算预览横幅：饥饿/死亡预测 + 主动排序入口 |
| `GuEventFeed` | 事件日志契约 | 事件流列表：`DisplayText.action` 中文名 + 逻辑时钟排序；过滤 `_` 前缀键 |
| `GuCoreBadge` | `core_state{depth}` + `hub_evidence` | 核心/枢纽深度标记与倾斜提示 |
| `GuTiltHint` | `tilt_pool` 建议 | 候选分布倾斜提示（只标注，不承诺掉落） |
| `GuStaleBanner` | 预检 stale reason | 过期提示 + 一键重建快照 |

### 2.3 组件通用规则

1. **快照驱动、整体重建**：组件公开唯一入口 `bind(snapshot: Dictionary)`，每次快照更新整体重建内容；禁止跨帧增量改内部业务字段（视觉动画除外）。
2. **零领域依赖**：组件只 import `presentation` 助手（`GuStyle/DisplayText/GuIcon`）与自身；**禁止** preload 任何 `scripts/domain/*` 规则模块——领域数值只能来自快照键（这是"UI 只读快照"在代码结构上的落实）。
3. **信号上行**：组件只 emit 信号（如 `command_requested(type, fields)`），由屏/控制器提交命令；组件内部不持 RunState 引用。
4. **无业务分支**：同一组件在不同屏表现差异只允许来自绑定数据与主题变体，不允许组件里写 `if screen == "Battle"` 式业务分叉。
5. **可测性**：每个新组件屏必须能脱离领域状态用样例快照字典实例化（供渲染核对与守卫测试）；组件目录纳入 `test_ui_rules_guard` 扫描。
6. **文件与命名**：`scenes/ui/widgets/<snake_case>.tscn` + `scripts/ui/<snake_case>.gd`（`class_name Gu<PascalCase>`）；屏在 `scenes/ui/screens/<screen>_screen.tscn`。

### 2.4 明令禁止清单（生成物评审一票否决项）

- 在 UI 层写死任何数值、颜色、圆角、字体、图标路径、id 文案。
- 绕过 `GuCommandButton` 直接调用 `submit_command` 或更底层的 resolver/规则模块。
- 渲染 `_` 前缀旁路键；渲染快照不存在的"预估"数值。
- 无 block_reason 的禁用、无文案的失败、无确认的不可逆操作、自动触发确认级以上决定。
- 假状态：无命令支撑的按钮、装饰性进度条、示意性掉落承诺（倾斜提示必须用"倾向"措辞，见 `GuTiltHint`）。
- 复用现役组件该管的职责另造平行实现（先查 §2.1 登记表）。

---

## 三、维护约定

1. 本档与接口契约同址维护；T9.x 每提交落地后，若新增组件/屏/主题变体，同步更新 §2.1/§2.2 登记表。
2. 与 `test_ui_rules_guard.gd` 的守卫条目一一对应：本档成文的每条机器可查规则都应（逐步）有守卫测试；发现守卫缺口随 T9 提交补。
3. 第三步（页面生成）开工验收 = 本档 §1.9 门槛 + §2.4 禁止清单逐项过。
