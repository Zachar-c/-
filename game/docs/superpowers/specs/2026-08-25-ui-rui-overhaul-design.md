# 《問眞》UI/UX 全面重构设计（引入 Reactive UI Toolkit，已归档）

> 日期：2026-08-25
> 状态：已归档
> 范围：Reactive UI Toolkit 初版表现层重构设计；保留用于历史实现追踪。
> 权威基线：[机制先行锁死规格书](./2026-08-25-mechanics-first-lockdown-design.md)
> 替代关系：视觉品牌与布局由《問眞》极简 UI 重设计规格取代；RUI 技术约束仍可作参考。


- 日期：2026-08-25
- 状态：待评审
- 范围：表现层（5 屏 + 公共控件 + 界面切换）整体重写，建立统一组件体系、主题与动效
- 技术选型：Reactive UI Toolkit（`guitkx`，Godot 4.7 验证）
- 关联约束：AGENTS.md「UI 前端约定（6 条）」、「场景只负责展示状态和提交命令」

---

## 1. 背景与目标

现有 5 个界面由子代理按「命令式 Control 树」拼出，虽已满足 6 条 UI 规则，但：
- 各屏视觉不统一、缺乏动效与一致的交互反馈；
- 遭遇界面存在逻辑缺陷：`encounter_view.gd` 在渲染期就 `emit option_chosen` / `dangerous_option_confirmed`（死代码，且绕过了「危险选项二次确认」这一死亡可预见规则要求的 UX）；
- 缺少统一组件库，按钮/卡牌/提示框/对话框各自零散实现。

目标：引入外部框架 Reactive UI Toolkit，一次性建立统一组件体系，5 屏全部重做布局、主题与克制动效，并修掉上述缺陷。

## 2. 范围边界

**做（表现层 only）：**
- 大厅 / 地图 / 遭遇 / 战斗 / 结算 5 屏重写为 `.guitkx` 组件；
- 公共控件：`GuButton`、`ActionCardRow`、`StatBar`、`TopStatusBar`、`GuTooltip`、`ConfirmDialog`、`Toast`、`ScrollList`；
- `RunController` 的界面切换改为挂载单个 `RuitkRoot` 并按状态渲染对应屏组件；
- 统一设计系统（RUIStyleSheet 配色 / 字体 / 动效）。

**不做（领域层不动）：**
- `scripts/domain/*`（RunState、各 resolver、ActionPreviewService、catalog、save_repository）；
- `data/*.json` 数据表；
- 存档格式与序列化；
- 领域层 GUT 测试。
界面保持只读、仅通过信号提交命令（规则 #1），领域规则不进入 UI。

## 3. 技术选型与许可证

- 框架：Reactive UI Toolkit（GitHub `reactive-ui-toolkit/ruitk-godot`），声明式 `.guitkx` 标记语言，编译为 GDScript，Godot 4.4+ 验证、4.7 通过；纯 GDScript、无 .NET。
- 许可证：**Reactive UI Toolkit Community License 1.1**（非 MIT）。开发 / 评估免费；公司（含母公司/子公司）近 12 个月营收 < US$250,000 可免费发布，超出需购买商业许可。AGENTS.md 通常要求 MIT + 保留许可证/提交号，按「用户最新指令优先于 AGENTS.md」以本次选择为准，但须如实记录。
- 引入方式：
  - 将 `reactive_ui_toolkit/`（运行时）与 `reactive_ui_toolkit_editor/`（编辑器插件）复制到 `addons/`；
  - 锁定一个具体提交号，写入 `addons/reactive_ui_toolkit/UPSTREAM.md`（含上游 URL、提交号、许可证全文或链接）；
  - 保留 `LICENSE` 文件不动；
  - 编辑器插件仅在开发构建启用；导出（Release）构建裁剪，不依赖编辑器插件（见 §8）。
- `.guitkx` 是作者源文件，**只提交 `.guitkx`**；编译产物 `.gd` 加入 `.gitignore`（见 §8 导出前置）。

## 4. 设计系统（RUIStyleSheet）

- 配色（自现有 `gu_theme.tres` 迁移）：
  - 背景：墨/皮纸深底 `#1c1b17` 系；
  - 主/正向（玉）：`#7fae9b`；
  - 资源/点缀（金）：`#d7c6a1`；
  - 危险/诅咒/反噬（红）：`#c0392b`；
  - 正文：骨白 `#d8d2c4`；次要文字 `#c6d3cf`。
- 字体：中文可读性优先，HUD 字号 ≥18px；标题用稍大字号 + 金色。
- 动效预算（克制）：
  - 界面切换：淡入/滑动 120–180ms；
  - 卡牌悬停：微浮 + 描边高亮；
  - Tooltip：淡入；
  - 确认框：缩放出现；
  - 不做常驻循环动画，保持肉鸽安静可读。
- 所有控件挂统一 RUI 主题（规则 #2/#3），公共组件集中复用，禁止在屏内重复实现按钮/卡牌容器/提示框（规则 #3）。

## 5. 组件架构

- `RunController`（领域编排者，不动其领域职责）：持有 `state`、调 resolver、决定当前应显示哪屏；挂载一个 `RuitkRoot`，按状态变化渲染对应屏组件。**不**用 RUI router 管理游戏流程（UI 不拥有流程）。
- 信号约定（规则 #4）：每屏组件 props 接收 `(state, catalog, session, results, result, action_cards, …)` 只读快照；发出 `command_submitted(command: Dictionary)`；节点销毁时信号自动断开（Godot 4 接收端释放即断，列表重建整体 `queue_free`）。
- 公共控件清单（各自 `.guitkx`，统一主题）：
  - `GuButton`：主题按钮，禁用态置灰 + 原因 tooltip；
  - `ActionCardRow`：替换 `action_card_row.gd`，展示单张领域行动卡（代价/收益/风险/受阻原因），点击发 `command_submitted`，危险卡触发 `ConfirmDialog`；
  - `StatBar`：生命/真元/寿元/魂魄/元石/恶名进度条；
  - `TopStatusBar`：契约（蓝）/异变（黄红）/险象·衰运（DDA）常驻顶部；
  - `GuTooltip`：悬停提示，固定格式（品质/效果/联动/代价/诅咒警示）；
  - `ConfirmDialog`：危险选项二次确认；
  - `Toast`：轻量反馈（如存档成功）；
  - `ScrollList`：动态卡牌/遗物列表（ItemList / VirtualList，规则 #5）。
- 每屏输出代码后标注：输入数据 + 依赖的公共组件（规则 #6）。

## 6. 各屏规格与验收（顺序即交付顺序）

1. **基础层**：引入 RUI、定义 `gu_style`（RUIStyleSheet）、实现 §5 公共控件。验收：Godot 4.7.2 打开能编译，挂载 `RuitkRoot` 渲染一个含 `GuButton`+`StatBar`+`GuTooltip` 的样例屏，悬停/点击/确认动效正常。
2. **大厅（TitleView）**：四分支——继续 Run（优先）/ 流派选择 + 契约占位 / 图鉴 / 设置；已 restored 的 `continue_requested`/`codex_requested`/`settings_requested`/`contract_placeholder_requested` 信号保留并接到 `RunController`。
3. **遭遇（EncounterView）**：修「没按钮」专项（见 §7）；渲染 `action_cards`，空列表兜底「离开」按钮；危险卡走 `ConfirmDialog`；右侧自身状态面板用 `StatBar`；底部养护 footer 保留。
4. **地图（MapView）**：路线树 `RouteTreeCanvas` 节点选择，发出 `node_selected` / `action_submitted`。
5. **战斗（BattleView）**：手牌（`ScrollList`）、遗物（`ScrollList`）、敌方意图（数值+效果文字）、真元/能量；出牌走 `ActionCardRow`。
6. **结算（EndingView）**：六要素复盘（消耗/收获/反噬/诅咒/契约/恶名），`return_to_hall_requested` 回大厅；死亡报告 `show_death` 保留。
7. **动效与整体打磨**：跨屏统一过渡、tooltip 一致性、空池回退小字提示、诅咒蛊强红视觉。

## 7. 遭遇「没按钮」修复专项

- 根因：`encounter_view.gd:107-109` 在 `render_session` 遍历 `action_cards` 时，对每个卡**渲染期**就 `emit option_chosen` / `dangerous_option_confirmed`；这两个信号在 `RunController` 未连接（死代码），且使「危险选项二次确认」从未真正生效。
- 修复（在 `.guitkx` 重写中落实）：
  - `ActionCardRow` 仅在按钮真正 `pressed` 时发 `command_submitted`（携带 `action_id` 与 `state_version`）；
  - 危险卡（代价含寿元/魂魄，或 known_risk 含「反噬/魂魄/寿元」）点击先弹 `ConfirmDialog`，确认后才发 `command_submitted`；
  - `render_session` 不再在渲染期发任何选项信号；
  - 防御：`action_cards` 为空时仍渲染一个 `node.leave` 兜底按钮，保证永远有可交互控件（无头冒烟断言 ≥1 控件）。

## 8. 测试与验证

- 领域 GUT 套件（当前 329 单测 + 6 集成）必须保持全绿——领域层不动。
- 新增无头冒烟（GDScript `--script` 或 GUT 集成）：对 5 屏各塞一份示例 `state` 调渲染，断言可交互控件（Button 类）≥1；专门覆盖「遭遇 action_cards 为空」仍渲染离开按钮。
- 手动：Godot 4.7.2 实跑，点通 大厅→地图→遭遇→战斗→结算→大厅；确认危险选项弹确认、tooltip 正常、切换有动效。
- **导出前置（`.gd` 仅 gitignore 的代价）**：Windows Desktop Demo 导出前，必须先让 `.guitkx` 编译为 `.gd`（打开 Godot 触发插件，或提供一个编译脚本/CI 步骤），再执行导出；导出产物不依赖编辑器插件。

## 9. 风险与缓解

- 许可证非 MIT：已记录 Community License 1.1 与营收门槛；若项目商业化营收超阈值需购商业许可。缓解：仅用于本演示，不涉及分发收费。
- 范式切换成本：5 屏需改写为 `.guitkx`，学习曲线。缓解：基础层先做最小可用样例验证工具链；领域层零改动降低回归面。
- 编译 `.gd` 不进 git 导致干净克隆不可直接运行/导出：缓解见 §8 导出前置。
- RUI 与现有 `gu_theme.tres` 主题并存：以 RUIStyleSheet 为唯一主题来源，`gu_theme.tres` 逐步退役（保留一段时间做对照，最终删除）。

## 10. 交付节奏

按 §6 顺序逐屏交付，每屏一个 Task：先写可失败验收（无头冒烟/手动步骤），再实现最小改动，完成后跑 GUT + 实跑验证，再进入下一屏。全部完成后做一次跨屏动效与一致性打磨。

## 11. 回滚与兼容

- 领域层与存档格式不变，回滚表现层不影响存档/大厅档向前兼容。
- 若 RUI 引入出现不可接受问题，可保留领域层、回退到命令式 Control 树旧界面（旧 `.gd` 仍在 git 历史）。
