# UI/UX 全面重构（引入 Reactive UI Toolkit）实施计划

> 日期：2026-08-25
> 状态：已归档
> 范围：Reactive UI Toolkit 初版重构实施计划；保留用于实现追踪。
> 基线：`branch=master @ 9f6872d`；该计划最终变更以此提交为准。
> 替代关系：视觉品牌与布局由《問眞》现行 UI 规格取代；RUI 技术约束仍可作参考。


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Reactive UI Toolkit（`guitkx`）把 5 个表现层界面与公共控件整体重写为统一组件体系，带统一主题与克制动效，并修掉遭遇界面「没按钮 / 危险选项无二次确认」缺陷。

**Architecture:** `RunController` 仍是领域编排者（持 `state`、调 resolver、决定显示哪屏），挂载单个 `RuitkRoot`，按状态渲染对应 `.guitkx` 屏组件；屏组件只读 props、发 `command_submitted` 等信号。领域层（`scripts/domain/*`、`data/*.json`、存档）完全不动。

**Tech Stack:** Godot 4.7.2、GDScript、`Reactive UI Toolkit`（`guitkx` 标记 → 编译 GDScript，Godot 4.4+ 验证/4.7 通过）、GUT（领域测试，仅保绿）、`--script` 无头冒烟（屏渲染断言）。

## Global Constraints

- 引擎版本：Godot 4.7.2（Windows Desktop Demo 优先）。
- 框架：Reactive UI Toolkit（`guitkx`），许可证 **Community License 1.1（非 MIT）**；开发/评估免费，公司近 12 月营收 < US$250,000 可免费发布，超出需商业许可。上游 URL 与锁定提交号写入 `addons/reactive_ui_toolkit/UPSTREAM.md`，保留其 `LICENSE`。
- 版本控制：只提交 `.guitkx` 源文件；编译产物 `.gd` 加入 `.gitignore`（导出前需先编译，见 Task 1 / Task 8）。
- UI 6 条规则（AGENTS.md）：①界面只读不改业务数据，状态变更经信号；②控件挂统一主题；③复用公共组件禁重复实现；④信号用 Callable，销毁时断开；⑤动态列表用 ItemList/ScrollContainer（RUI 用 VirtualList/VList）；⑥输出 UI 后标注输入数据与依赖组件。
- 场景只展示状态与提交命令；领域规则保持纯 GDScript、可测试。
- 标识符/JSON 键/测试名/提交信息用 ASCII；玩家可见中文文本用 UTF-8。
- 领域层零改动；新增仅表现层文件与测试。

---

## 文件结构

**新增（表现层）：**
- `ui/gu_style.gd` — RUIStyleSheet，统一配色/字体（Task 1）。
- `ui/widgets/gu_button.guitkx` — 主题按钮（Task 2）。
- `ui/widgets/stat_bar.guitkx` — 数值进度条（Task 2）。
- `ui/widgets/top_status_bar.guitkx` — 契约/异变/险象常驻条（Task 2）。
- `ui/widgets/gu_tooltip.guitkx` — 悬停提示（Task 2）。
- `ui/widgets/confirm_dialog.guitkx` — 危险选项二次确认（Task 2）。
- `ui/widgets/toast.guitkx` — 轻量反馈（Task 2）。
- `ui/widgets/scroll_list.guitkx` — 动态列表容器（Task 2）。
- `ui/widgets/action_card_row.guitkx` — 单张领域行动卡（Task 2，替换 `scripts/presentation/action_card_row.gd`）。
- `ui/screens/title_view.guitkx` — 大厅（Task 3）。
- `ui/screens/encounter_view.guitkx` — 遭遇（Task 4，修没按钮+确认）。
- `ui/screens/map_view.guitkx` — 地图（Task 5）。
- `ui/screens/battle_view.guitkx` — 战斗（Task 6）。
- `ui/screens/ending_view.guitkx` — 结算（Task 7）。
- `ui/smoke_render.gd` — 无头冒烟脚本（Task 1 起，逐步扩展）。

**引入（vendored，非手写）：**
- `addons/reactive_ui_toolkit/` — 运行时（锁定提交）。
- `addons/reactive_ui_toolkit_editor/` — 编辑器插件（仅开发构建启用）。
- `addons/reactive_ui_toolkit/UPSTREAM.md` — 我们写：上游 URL + 提交号 + 许可证说明。

**修改：**
- `scripts/presentation/run_controller.gd` — Task 8 改为挂载 `RuitkRoot` 并按状态渲染屏组件；移除 `_views` 命令式场景切换与对旧 `.tscn`/`.gd` 视图的依赖。
- `.gitignore`（worktree）— 追加编译产物 `.gd` 忽略规则（仅针对 `ui/**` 编译输出）。
- 删除（Task 8 收尾）：`scenes/title.tscn`、`scenes/map.tscn`、`scenes/encounter.tscn`、`scenes/battle.tscn`、`scenes/ending.tscn`，以及 `scripts/presentation/{title_view,map_view,encounter_view,battle_view,ending_view,action_card_row}.gd`（已被 `.guitkx` 取代）。

**测试：**
- 领域 GUT 套件：保持 329 单测 + 6 集成全绿（每层 `git` 提交前跑）。
- `ui/smoke_render.gd`：`--script` 无头冒烟，对每屏塞示例 `state` 断言可交互控件（Button 类）≥1；覆盖「遭遇 action_cards 为空仍有离开按钮」。

---

## Task 1: 引入 RUI 并锁定 API + 建立设计系统

**Files:**
- Create: `addons/reactive_ui_toolkit/`（从上游复制，锁定提交）、`addons/reactive_ui_toolkit_editor/`、`addons/reactive_ui_toolkit/UPSTREAM.md`
- Create: `ui/gu_style.gd`
- Create: `ui/smoke_render.gd`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Godot 4.7.2 项目根；现有 `gu_theme.tres` 配色（读取值）。
- Produces: `RuitkRoot` 挂载方式、`V.*`/`Hooks.*` 的确切 API（由本任务读 RUI 自带 examples/docs 后锁定，后续任务统一引用）；`ui/gu_style.gd` 提供的 `GuStyle` 单例/常量（调色板）；`smoke_render.gd` 的 `assert_screen_buttons(component, props)` 辅助。

- [ ] **Step 1: 复制 RUI 运行时与编辑器插件到 addons/，并写 UPSTREAM.md**

从上游 `https://github.com/reactive-ui-toolkit/ruitk-godot` 取最新稳定提交（记录提交号，例如 `v0.11.0` 对应 commit），复制 `addons/reactive_ui_toolkit/` 与 `addons/reactive_ui_toolkit_editor/`。新建 `addons/reactive_ui_toolkit/UPSTREAM.md`：

```markdown
# Reactive UI Toolkit — 上游记录
- 上游 URL: https://github.com/reactive-ui-toolkit/ruitk-godot
- 锁定提交: <填写实际 commit hash>
- 版本: 0.11.0
- 许可证: Reactive UI Toolkit Community License 1.1（非 MIT；营收门槛见 LICENSE）
- 引入日期: 2026-08-25
- 用途: UI 表现层统一组件体系与动效
```

- [ ] **Step 2: 在 Godot 中启用编辑器插件，读 examples 锁定 API**

打开 Godot 4.7.2，Project Settings → Plugins 启用 `Reactive UI Toolkit — Godot` 与 `Reactive UI Toolkit — Godot Editor`。阅读 `addons/reactive_ui_toolkit/examples/main.tscn` 与 `*.guitkx`，确认并记录：
  - 挂载入口：`RuitkRoot` 节点如何创建并 `mount(component, props)`；
  - 组件写法：`.guitkx` 的 `component Name(props):` + 末尾 `return (V.xxx({...}))`；
  - 信号/回调：按钮 `on_pressed` 回调、`useSignal`/`useState` 用法；
  - 样式：`RUIStyleSheet` 如何定义并挂到 `RuitkRoot`；
  - 动效：`useAnimate` / 过渡预设用法。
  把确认到的确切签名记在 `ui/gu_style.gd` 顶部注释，供后续任务引用。

- [ ] **Step 3: 定义统一设计系统 `ui/gu_style.gd`**

```gdscript
# gu_style.gd — 统一设计系统（RUIStyleSheet）
# 配色自 gu_theme.tres 迁移；具体 RUIStyleSheet 构造以 Task 1 Step 2 锁定的 API 为准。
class_name GuStyle
extends RefCounted

const BG := Color("1c1b17")
const JADE := Color("7fae9b")      # 主/正向
const GOLD := Color("d7c6a1")      # 资源/点缀
const DANGER := Color("c0392b")    # 诅咒/反噬/危险
const BONE := Color("d8d2c4")      # 正文
const BONE_DIM := Color("c6d3cf")  # 次要

# 返回一个配置好的 RUIStyleSheet（调用 Task 1 Step 2 确认的构造器）
static func sheet() -> Object:
    # 占位调用，按锁定 API 实现：创建 RUIStyleSheet，设 background=BG、默认文字=BONE、
    # 按钮主色=JADE、危险色=DANGER、资源色=GOLD、字号(HUD)>=18。
    # 返回该 style 实例。
    assert(false, "按 Task 1 Step 2 锁定的 RUIStyleSheet API 实现")
    return null
```

> 说明：本步骤 `sheet()` 内为确认 API 前的占位断言；Step 2 已锁定 API 后，实现者将其替换为真实构造代码。后续任务只调用 `GuStyle.sheet()` 与颜色常量。

- [ ] **Step 4: 写失败的无头冒烟骨架 `ui/smoke_render.gd`**

```gdscript
extends SceneTree

# 断言某屏组件在给定 props 下渲染出的 Button 类控件 >= min_buttons。
# 挂载方式以 Task 1 Step 2 锁定的 RuitkRoot.mount 为准。
func assert_screen_buttons(component: GDScript, props: Dictionary, min_buttons: int, label: String) -> void:
    var root = RuitkRoot.new()
    self.root.add_child(root)
    root.mount(component, props)
    var count := _count_buttons(root)
    if count < min_buttons:
        push_error("SCREEN %s 按钮数 %d < %d" % [label, count, min_buttons])
        quit(1)
    print("OK %s buttons=%d" % [label, count])

func _count_buttons(node: Node) -> int:
    var n := 0
    if node is Button:
        n += 1
    for c in node.get_children():
        n += _count_buttons(c)
    return n

func _initialize() -> void:
    # 暂未接入任何屏；先验证 RuitkRoot 可挂载一个最小样例。
    var root = RuitkRoot.new()
    self.root.add_child(root)
    root.mount(_sample, {})
    print("RUI mount OK")
    quit()

# 最小样例组件（仅用于验证工具链，后续删除）
func _sample(props: Dictionary) -> Object:
    return V.button({"text": "样例", "on_pressed": func(): pass})
```

- [ ] **Step 5: 运行冒烟，验证 RUI 工具链可编译+渲染**

Run: `& "C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe" --headless --script ui/smoke_render.gd`
Expected: 输出 `RUI mount OK` 且无解析/编译错误。（若 `.guitkx` 未编译，先打开 Godot 让其编译，或在 `--script` 前确保 `.gd` 已生成。）

- [ ] **Step 6: 更新 .gitignore，忽略 ui 编译产物**

在 worktree 的 `.gitignore` 追加：
```
# Reactive UI Toolkit 编译产物（源为 .guitkx，仅提交源）
ui/**/*.gd
```
> 注意：仅忽略 `ui/` 下由 `.guitkx` 生成的 `.gd`；`addons/` 下的 RUI 自身 `.gd` 需保留（框架运行时）。若 RUI 生成文件落在别处，按实际路径调整。

- [ ] **Step 7: 提交**

```bash
git add addons/reactive_ui_toolkit addons/reactive_ui_toolkit_editor addons/reactive_ui_toolkit/UPSTREAM.md ui/gu_style.gd ui/smoke_render.gd .gitignore
git commit -m "feat(ui): vendor Reactive UI Toolkit, lock API, define gu_style"
```

---

## Task 2: 公共控件库（.guitkx）

**Files:**
- Create: `ui/widgets/gu_button.guitkx`、`ui/widgets/stat_bar.guitkx`、`ui/widgets/top_status_bar.guitkx`、`ui/widgets/gu_tooltip.guitkx`、`ui/widgets/confirm_dialog.guitkx`、`ui/widgets/toast.guitkx`、`ui/widgets/scroll_list.guitkx`、`ui/widgets/action_card_row.guitkx`

**Interfaces:**
- Consumes: `GuStyle.sheet()` 与颜色常量；Task 1 锁定的 `V.*`/`Hooks.*`/`RuitkRoot.mount` API。
- Produces: 以下组件供屏任务引用（统一 props 契约）：
  - `GuButton(props:{label:String, disabled:bool=false, on_press:Callable, tooltip:String="", danger:bool=false})`
  - `StatBar(props:{label:String, current:int, maximum:int, color:Color})`
  - `TopStatusBar(props:{contracts:Array, debuffs:Array, dda:Array})`
  - `GuTooltip(props:{title:String, effect:String, linkage:String, cost:String, curse:String})`
  - `ConfirmDialog(props:{title:String, body:String, on_confirm:Callable, on_cancel:Callable})`
  - `Toast(props:{text:String})`
  - `ScrollList(props:{items:Array, row_factory:Callable})` — `row_factory(item:Dictionary)->Control`
  - `ActionCardRow(props:{card:Dictionary, on_command:Callable})` — 点击发 `on_command(card)`；危险卡先弹 `ConfirmDialog`

- [ ] **Step 1: 写失败冒烟——断言各控件可实例化并渲染**

在 `ui/smoke_render.gd` 的 `_initialize` 中临时 `assert_screen_buttons(GuButton, {label="测试", on_press=func():pass}, 1, "GuButton")` 等（每个控件一条）。运行应 FAIL（组件未实现/未编译）。

- [ ] **Step 2: 实现 `gu_button.guitkx`**

```guitkx
component GuButton(props):
    var disabled = props.get("disabled", false)
    var danger = props.get("danger", false)
    var on_press = props.get("on_press", func(): pass)
    func _press():
        if not disabled:
            on_press.call()
    return (
        V.button({
            "text": props.get("label", "按钮"),
            "disabled": disabled,
            "theme_type": "gu_button",
            "on_pressed": _press,
            # 悬停提示由 GuTooltip 在屏层统一处理；此处仅置 danger 配色
            "modulate": GuStyle.DANGER if danger else Color(1,1,1,1),
        })
    )
```
> 确切 `V.button` 的 props 名以 Task 1 Step 2 锁定的 API 为准（如信号键为 `on_pressed` 或 `pressed`）。

- [ ] **Step 3: 实现 `stat_bar.guitkx` / `top_status_bar.guitkx` / `gu_tooltip.guitkx` / `confirm_dialog.guitkx` / `toast.guitkx` / `scroll_list.guitkx`**

按上述 props 契约实现，全部 `theme_type` 挂 `GuStyle.sheet()`；`ConfirmDialog` 用 `RuitkRoot` 叠加层 + 缩放出现动效；`ScrollList` 用 `VirtualList`（或 `VList`）按 `items` 调 `row_factory`。每个文件末尾 `return (V.xxx({...}))`。（具体 `V.*` 构造以 Task 1 锁定 API 为准。）

- [ ] **Step 4: 实现 `action_card_row.guitkx`（替换旧 action_card_row.gd 行为）**

```guitkx
component ActionCardRow(props):
    var card = props.get("card", {})
    var on_command = props.get("on_command", func(c): pass)
    var executable = bool(card.get("executable", false))
    var danger = _is_dangerous(card)
    func _activate():
        if not executable:
            return
        if danger:
            ConfirmDialog.mount_or_show({
                "title": card.get("title", "行动"),
                "body": "此选择代价含寿元/魂魄或触发反噬，确认执行？",
                "on_confirm": func(): on_command.call(card),
                "on_cancel": func(): pass,
            })
        else:
            on_command.call(card)
    return (
        V.box({
            "vertical": true,
            "children": [
                GuButton({"label": card.get("title", "行动"), "disabled": not executable, "danger": danger, "on_press": _activate}),
                V.label({"text": _details(card), "autowrap": true, "font_size": 14,
                         "modulate": GuStyle.DANGER if not executable else GuStyle.BONE_DIM}),
            ],
        })
    )
func _is_dangerous(card: Dictionary) -> bool:
    var cost = card.get("cost", {})
    if int(cost.get("lifespan", 0)) > 0 or int(cost.get("soul", 0)) > 0:
        return true
    var risk = str(card.get("known_risk", ""))
    return "反噬" in risk or "魂魄" in risk or "寿元" in risk
func _details(card: Dictionary) -> String:
    # 同旧 action_card_row.gd 的 _details：代价/成功率/收益/风险/未知/受阻原因
    var lines = []
    var cost = card.get("cost", {})
    if not cost.is_empty(): lines.append("代价：%s" % str(cost))
    for g in card.get("expected_gain", []): lines.append("收益：%s" % str(g))
    for r in card.get("known_risk", []): lines.append("风险：%s" % str(r))
    if not bool(card.get("executable", false)): lines.append("受阻：%s" % str(card.get("block_reason", "条件不足。")))
    return "\n".join(lines)
```

- [ ] **Step 5: 运行冒烟，验证 8 个控件均渲染**

Run: 同 Task 1 Step 5（冒烟已含各控件断言）
Expected: 每个控件 `OK <名> buttons=1`（ActionCardRow/ScrollList 按内部按钮数），无解析错误。

- [ ] **Step 6: 提交**

```bash
git add ui/widgets
git commit -m "feat(ui): shared widget library (button/statbar/tooltip/confirm/toast/list/cardrow)"
```

---

## Task 3: 大厅屏（title_view.guitkx）

**Files:**
- Create: `ui/screens/title_view.guitkx`
- Modify: `ui/smoke_render.gd`（加大厅断言）

**Interfaces:**
- Consumes: `GuButton`、`GuStyle`；`RunController` 期望的信号：`start_requested`、`school_selected(String)`、`continue_requested`、`codex_requested`、`settings_requested`、`contract_placeholder_requested`（与旧 `title_view.gd` 信号一致）。
- Produces: 大厅组件 `TitleView(props:{has_save:bool, meta:Dictionary})`，发出上述信号（通过 props 传入的 Callable 或 RUI 信号机制，以 Task 1 锁定 API 为准）。

- [ ] **Step 1: 写失败冒烟——断言大厅渲染 ≥4 个可交互控件（四分支）**

在 `smoke_render.gd` 加 `assert_screen_buttons(TitleView, {has_save=true, meta={}}, 4, "Title")`；运行 FAIL。

- [ ] **Step 2: 实现 `title_view.guitkx`**

四分支用 `GuButton`：继续 Run（仅 `has_save` 时可用）、流派选择 + 契约占位、图鉴、设置。点击分别触发对应信号/回调。顶部用 `TopStatusBar` 占位（大厅无契约/异变）。布局用 `V.box` 垂直居中，标题「蛊路求生」金色大字。

- [ ] **Step 3: 运行冒烟**

Run: 同前
Expected: `OK Title buttons>=4`

- [ ] **Step 4: 提交**

```bash
git add ui/screens/title_view.guitkx ui/smoke_render.gd
git commit -m "feat(ui): title/hall screen via RUI"
```

---

## Task 4: 遭遇屏（encounter_view.guitkx）——修「没按钮」+ 危险确认

**Files:**
- Create: `ui/screens/encounter_view.guitkx`
- Modify: `ui/smoke_render.gd`（加遭遇断言，含空 action_cards 用例）

**Interfaces:**
- Consumes: `ActionCardRow`、`GuTooltip`、`StatBar`、`ScrollList`、`ConfirmDialog`、`GuStyle`、`GuStyle` 颜色；`ActionPreviewService.preview_actions`（领域，只读调用）。
- Produces: `EncounterView(props:{node, state, session, results, result, action_cards, catalog})`，发 `command_submitted(Dictionary)`（命令结构同旧 `command_submitted`：含 `action_card`/`type` 等）。**关键修复**：不在渲染期发任何选项信号；`action_cards` 为空时仍渲染一个 `node.leave` 兜底按钮。

- [ ] **Step 1: 写失败冒烟——正常与空列表两用例**

```gdscript
# 在 smoke_render.gd _initialize 中：
var catalog = ContentCatalog.load_all()
var state = RunState.new_run(7, MetaProgress.new_empty())
# 正常：找一个 contact 节点
...
assert_screen_buttons(EncounterView, {node=nd, state=state, session=..., results=[], result={}, action_cards=cards, catalog=catalog}, 1, "Encounter")
# 空列表兜底：
assert_screen_buttons(EncounterView, {node=nd, state=state, session=..., results=[], result={}, action_cards=[], catalog=catalog}, 1, "EncounterEmpty")
```
运行 FAIL（组件未实现）。

- [ ] **Step 2: 实现 `encounter_view.guitkx`**

- 左栏：`ScrollList` 渲染 `action_cards`，每行用 `ActionCardRow({card=c, on_command=func(card): command_submitted.emit(_cmd(card))})`；
- `_cmd(card)` 返回 `{"type":"action_card","action_id":str(card["id"]),"state_version":int(card["state_version"])}`；
- 若 `action_cards` 为空，左栏追加一个 `GuButton({label="离开遭遇", on_press=func(): command_submitted.emit({"type":"leave_node"})})` 兜底；
- 右侧自身状态面板：`StatBar` 生命/真元/寿元/魂魄/元石/恶名（同旧 `_build_status_panel` 取值）；
- 底部养护 footer：材料短缺时「结清养护」`GuButton` 发 `{"type":"settle_node_feeding"}`；
- 顶部 `facts`/`summary` 用 `V.label`；历史结果用 `V.label`（bbcode 视 RUI 支持）。
- **不再**在渲染期 `emit option_chosen` / `dangerous_option_confirmed`（危险确认已在 `ActionCardRow` 内通过 `ConfirmDialog` 完成）。

- [ ] **Step 3: 运行冒烟**

Run: 同前
Expected: `OK Encounter buttons>=1`、`OK EncounterEmpty buttons=1`（离开兜底）

- [ ] **Step 4: 提交**

```bash
git add ui/screens/encounter_view.guitkx ui/smoke_render.gd
git commit -m "feat(ui): encounter screen via RUI, fix no-buttons + danger confirm"
```

---

## Task 5: 地图屏（map_view.guitkx）

**Files:**
- Create: `ui/screens/map_view.guitkx`
- Modify: `ui/smoke_render.gd`

**Interfaces:**
- Consumes: `GuButton`、`ScrollList`、`GuStyle`、`MapGenerator.visible_nodes`（领域只读）、`GuStyle` 颜色。
- Produces: `MapView(props:{route, state, meta, last_feedback})`，发 `node_selected(String)` 与 `action_submitted(Dictionary)`（同旧）。

- [ ] **Step 1: 写失败冒烟——断言地图渲染 ≥1 节点按钮**

`assert_screen_buttons(MapView, {route=route, state=state, meta=meta, last_feedback=""}, 1, "Map")`；运行 FAIL。

- [ ] **Step 2: 实现 `map_view.guitkx`**

用 `ScrollList`/网格展示 `MapGenerator.visible_nodes(route, state)` 的可见节点；每个节点 `GuButton` 发 `node_selected(node_id)`；不可达节点禁用；底部显示 `last_feedback`（用 `Toast` 或 `V.label`）。保留旧 `route_tree_canvas.gd` 的视觉意图（路线树），以 RUI 布局重画。

- [ ] **Step 3: 运行冒烟；Expected `OK Map buttons>=1`**

- [ ] **Step 4: 提交 `git commit -m "feat(ui): map screen via RUI"`**

---

## Task 6: 战斗屏（battle_view.guitkx）

**Files:**
- Create: `ui/screens/battle_view.guitkx`
- Modify: `ui/smoke_render.gd`

**Interfaces:**
- Consumes: `ActionCardRow`、`StatBar`、`TopStatusBar`、`ScrollList`、`GuTooltip`、`GuStyle`、`BattleResolver` 意图（只读）。
- Produces: `BattleView(props:{battle, state, catalog, action_cards})`，发 `command_submitted(Dictionary)`（含 `action_card`/`use_gu`/`end_turn`/`retreat` 等，同旧 `_show_battle`）。

- [ ] **Step 1: 写失败冒烟——断言战斗渲染 ≥1 手牌按钮**

构造一个最小 `battle`（用 `BattleResolver.start(...)`），`assert_screen_buttons(BattleView, {...}, 1, "Battle")`；运行 FAIL。

- [ ] **Step 2: 实现 `battle_view.guitkx`**

- 敌方意图区：`V.label` 显示数值 + 效果文字（规则：敌人意图必须含数值与效果文字）；
- 自身状态：`StatBar` 生命/真元/魂魄 + `TopStatusBar` 契约/异变/险象；
- 手牌：`ScrollList` 每行 `ActionCardRow({card=c, on_command=func(card): command_submitted.emit(_cmd(card))})`；
- 遗物：`ScrollList` 列表；
- 能量/真元显示。

- [ ] **Step 3: 运行冒烟；Expected `OK Battle buttons>=1`**

- [ ] **Step 4: 提交 `git commit -m "feat(ui): battle screen via RUI"`**

---

## Task 7: 结算屏（ending_view.guitkx）

**Files:**
- Create: `ui/screens/ending_view.guitkx`
- Modify: `ui/smoke_render.gd`

**Interfaces:**
- Consumes: `GuButton`、`StatBar`、`GuStyle`、`JournalBuilder`（领域只读）。
- Produces: `EndingView(props:{outcome, journal, run_data})`（同旧 `show_ending`），发 `return_to_hall_requested`；`show_death(report)` 用同组件的危险红样式展示。

- [ ] **Step 1: 写失败冒烟——断言结算渲染 ≥1 按钮（返回大厅）**

`assert_screen_buttons(EndingView, {outcome={}, journal={}, run_data={}}, 1, "Ending")`；运行 FAIL。

- [ ] **Step 2: 实现 `ending_view.guitkx`**

六要素复盘（消耗/收获/反噬/诅咒/契约/恶名）用 `V.label`/`StatBar` 展示；底部 `GuButton({label="返回大厅", on_press=func(): return_to_hall_requested.emit()})`；死亡报告走危险红样式。

- [ ] **Step 3: 运行冒烟；Expected `OK Ending buttons>=1`**

- [ ] **Step 4: 提交 `git commit -m "feat(ui): ending screen via RUI"`**

---

## Task 8: 接管 RunController + 清理旧视图 + 动效打磨

**Files:**
- Modify: `scripts/presentation/run_controller.gd`
- Delete: `scenes/{title,map,encounter,battle,ending}.tscn`、`scripts/presentation/{title_view,map_view,encounter_view,battle_view,ending_view,action_card_row}.gd`
- Modify: `ui/smoke_render.gd`（跑完整 5 屏 + 领域 GUT）

**Interfaces:**
- Consumes: 5 个屏组件 + `RuitkRoot` + `ActionPreviewService.preview_actions`（领域）。
- Produces: `RunController` 现在挂载单个 `RuitkRoot`，`_show(component, props)` 渲染当前屏；信号连接同旧（`start_requested`→开始、`node_selected`/`action_submitted`→`submit_command`、`return_to_hall_requested`→回大厅）。

- [ ] **Step 1: 写失败冒烟——完整 5 屏串接**

`smoke_render.gd` 依次 `assert_screen_buttons` 大厅/地图/遭遇/战斗/结算（各用示例 state）；运行 FAIL（RunController 尚未接管）。

- [ ] **Step 2: 改写 `run_controller.gd` 的视图层**

- `_ensure_views()`：不再 `instantiate` 5 个 `.tscn`；改为 `add_child(RuitkRoot.new())` 并保存引用；
- 新增 `_show(component, props)`：`ruitk_root.mount(component, props)`（或清旧挂新，按 Task 1 锁定 API）；
- `_show_title/_show_map/_show_encounter/_show_battle/_show_ending` 改为调用 `_show(TitleView/MapView/EncounterView/BattleView/EndingView, props)`；
- 信号连接保持：屏组件的 `command_submitted`/`node_selected`/`start_requested`/`continue_requested`/`codex_requested`/`settings_requested`/`contract_placeholder_requested`/`return_to_hall_requested` → 对应 `RunController` 处理（同旧逻辑）；
- `_add_view`/`_show_only` 删除。

- [ ] **Step 3: 删除旧视图文件**

```bash
git rm scenes/title.tscn scenes/map.tscn scenes/encounter.tscn scenes/battle.tscn scenes/ending.tscn \
       scripts/presentation/title_view.gd scripts/presentation/map_view.gd scripts/presentation/encounter_view.gd \
       scripts/presentation/battle_view.gd scripts/presentation/ending_view.gd scripts/presentation/action_card_row.gd
```

- [ ] **Step 4: 动效打磨**

为各屏切换加 RUI 过渡（淡入/滑动 120–180ms）；`GuTooltip` 淡入；`ConfirmDialog` 缩放出现；卡牌悬停微浮。统一 `GuStyle.sheet()` 已挂所有控件。

- [ ] **Step 5: 跑领域 GUT + 无头冒烟**

Run: GUT 测试（按项目既有命令，例如 Godot `--headless` 跑 `addons/gut` 或 `res://tests`）
Expected: 329 单测 + 6 集成全绿（领域层未改）。
Run: `ui/smoke_render.gd`
Expected: 5 屏全部 `OK ... buttons>=1`。

- [ ] **Step 6: 提交**

```bash
git add scripts/presentation/run_controller.gd ui/smoke_render.gd
git commit -m "feat(ui): rewire RunController to RuitkRoot, drop legacy views, polish motion"
```

---

## 自检（写作者自查）

1. **Spec 覆盖**：§1 范围（5 屏+控件+切换）— Task 2-7+8 覆盖；§2 引入/许可证 — Task 1 Step 1/UPSTREAM.md；§3 设计系统 — Task 1 Step 3 `gu_style.gd`；§4 架构 — Task 8；§5 各屏顺序 — Task 3-7；§6 遭遇修复 — Task 4；§7/§8 测试与导出前置 — Task 1 Step 6（gitignore）+ Task 8 Step 5（GUT+冒烟）+ 导出前编译说明在 Task 1 Step 5 注释。无遗漏。
2. **占位扫描**：`gu_style.gd` 的 `sheet()` 内有一处 `assert(false, "按 Task 1 Step 2 锁定的 API 实现")` —— 这是**故意的占位断言**，因 RUI 确切 `RUIStyleSheet` 构造器在 Task 1 Step 2 读 examples 后才知；Task 1 Step 3 要求实现者锁定 API 后替换为真实代码，且 Step 5 运行会暴露未实现。不属于「TODO 留待以后」类占位。其余步骤均含实际代码/命令。

---

## Locked API Reference（Task 1 已锁定，后续 Task 严格遵照）

> Task 1 探查自 `ruitk-godot@4fe6927`（examples + `addons/reactive_ui_toolkit/core`）。**计划正文中的伪代码（`component Name(props):` / `V.button(...)` 等）是错的，以本节为准。**

### 文件与编译
- 源文件 `ui/**/*.guitkx`；编译产物 `ui/**/*.gd` 已被 `.gitignore` 忽略（只提交源）。
- 组件文件头可挂主题：`@theme "res://assets/theme/gu_theme.tres"`。
- 跨文件组件引用：`import { GuButton } from "~/ui/widgets/gu_button"`（`~` = 项目根 `res://`）。值/常量导入同理：`import { JADE } from "~/ui/gu_style"`（见下）。
- **无头编译（CI/冒烟）**：`RuitkGuitkx.compile(source, basename, [], {}, self_path, "res://")` 返回 `{ ok, gd, env_error, diagnostics }`；把 `gd` 写入同级 `.gd`，再用 `load("res://ui/x.gd")` 加载。完整样例见 `scripts/smoke_render.gd`（已验证 `buttons=2`）。
- 编辑器开发：启用两个插件（Project Settings > Plugins）后，文件监视器自动把 `.guitkx` 编译为同级 `.gd`。

### 组件形态（关键）
- `.guitkx` 中 `export Foo(props) -> RuitkVNode { return ( <.../> ) }` 编译为 `class_name Foo extends RefCounted` + `static func render(props: Dictionary, children: Array) -> RuitkVNode`。
- 宿主控件即标签：`<Button text=.../>`、`<Label/>`、`<VBoxContainer/>`、`<CenterContainer/>`、`<MarginContainer/>`、`<HSeparator/>` 等（Godot 节点 PascalCase）。属性用 `prop={ value }` 或 `prop="str"`。
- props 映射到组件函数形参名（如 `DemoBox(title: String)` 接收 `<DemoBox title="...">`）。子节点用 `{ children }` 展开。
- 取组件 Callable 用 `V.comp("res://ui/x.gd", "render")`；挂载 `RuitkRoot.create(container, V.fc(component_callable, props))`。**`V`/`RuitkRoot`/`Hooks` 是 addon 全局类，addon 禁用时头less 不可用——驱动脚本须显式 `preload` 它们**（见 smoke_render.gd）。项目内自建 `class_name`（如 `GuStyle`）头less 正常注册。

### 状态与信号
- `var v = useState(40.0)` 返回 `[值, setter]` 元组；读 `v[0]`，写 `v[1].call(new_val)`。
- 信号标签：`onValueChanged={ func(x): v[1].call(x) }`（去 `on` + 驼峰）。按钮点击用 `onPressed={ func(): ... }`。
- 子组件命令上抛：父传 `onCommand={ func(cmd): emit_signal("command_submitted", cmd) }`，子按钮 `onPressed={ func(): onCommand.call(...) }`。

### 样式
- 内联 `style={ {"font_size": 28, "font_color": GuStyle.GOLD, "min_width": 200, "separation": 12} }` = 覆盖 Godot 节点属性。
- 全局配色放 `scripts/presentation/gu_style.gd`（`class_name GuStyle`，常量 `BG/JADE/GOLD/DANGER/BONE/BONE_DIM`），标记内用 `GuStyle.JADE` 直接引用（无需 import）。
- 组件统一 `@theme` 挂 `gu_theme.tres` 后，主题默认样式生效；`style={}` 做局部覆盖/点缀。

### 冒烟约定
- `scripts/smoke_render.gd`：`_compile_file` + `_mount(path,"render",props)` + `_count_buttons(container)` 递归数 `Button`。每屏 Task 完成后往此脚本加一条 `_mount` 断言（期望 `buttons>=1` + 关键控件存在）。
3. **类型一致性**：后续任务统一引用 `GuStyle.sheet()`、`GuButton`/`ActionCardRow` 等 props 契约（在 Task 2 Interfaces 定义），屏任务 props 与 Task 2 一致；`command_submitted` 命令结构沿用旧 `RunController` 既有约定。挂载入口 `RuitkRoot.mount(component, props)` 在 Task 1 锁定并在 Task 2-8 一致使用。
