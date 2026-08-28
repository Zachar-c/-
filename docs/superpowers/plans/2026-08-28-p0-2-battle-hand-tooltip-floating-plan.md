# P0-2 战斗手牌减法（共享浮层 + 卡面去重 + 禁用原因可见）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans（本会话采用内联执行，每个 Task 完成后跑 `tools/test.ps1 -Test <file>`，关键路径再跑 `tools/check.ps1`）。
>
> 工作树：必须在 `C:\Users\Zachary\DevEnv\06_个人项目\gu-zhenren\gu-zhenren-editor-fix-p0-2`（独立 worktree，分支 `fix/p0-2-battle-hand-tooltip-floating`），主工作区不动。

**Goal:** 把战斗手牌常驻的完整 `GuTooltipView` 改为按需浮层显示；移除卡内重复卡名的同款 Button；让不可执行卡的禁用原因（`block_reason`）随 hover/focus 暴露给玩家。

**Architecture:**
- 表现层（`ui/widgets/gu_battle_hand.guitkx`）改为按需渲染：每张卡只渲染卡面（标题 / 品质 / 简短 effect / 费用 / 危险角标）+ 唯一决策控件（卡体本身可点击 + ESC/右键取消）。tooltip 不再挂在卡内常驻。
- 共享浮层 tooltip 由 `ui/screens/battle_screen.guitkx` 持有，沿用 `useState` 的 `interaction.mode` 作为单一来源：mode ∈ {`hover`, `target_select`} 时渲染一个浮层 host，并在进入时由屏接收 `on_hover`/`on_press` 回调去更新 active card。
- `block_reason` 通过 `BattleScreen` 拼接到 tooltip 的第 5 段之后（独立于现有五段），不可执行卡也允许 hover / focus（卡面不再 `disabled`）。
- 命令边界不变：只读 `state` 快照；只通过 `commands["play_card"]` 提交；不出新命令，不动领域侧。

**Tech Stack:** Godot 4.7.2 · RUI toolkit（`.guitkx`）· GUT 1.x · PowerShell `tools/test.ps1` / `tools/check.ps1`。

## Global Constraints

- 标识符、JSON 键、测试名、提交信息必须 ASCII；玩家可见中文可用 UTF-8。
- 屏幕只读 `state` 快照、只发 `commands`，不得在 UI 中修改领域状态（AGENTS.md 工作边界）。
- 不改 `scripts/domain/**`、JSON 数据、存档格式（领域侧已完备）。
- 不动 `vendor/godot-open-rpg/`。
- 工作区切换：所有改动必须在 `gu-zhenren-editor-fix-p0-2`；主工作区不动；推送目标分支 `fix/p0-2-battle-hand-tooltip-floating`。
- 不引入新色、新字体、新依赖；只调整既有 token 的使用方式。
- `git diff --check` 必须零冲突。

---

### Task 1：手牌渲染红测（断言去重 + 禁用卡可 hover）

**Files:**
- Modify: `tests/unit/test_wenzhen_battle_screen.gd`
- 参考快照工厂：`_snapshot_with_hand(cards)`（在同文件新增）

**Step 1:** 在 `test_wenzhen_battle_screen.gd` 末尾新增三个测试函数：

```gdscript
func test_battle_hand_renders_no_permanent_tooltip_children() -> void:
    var cards: Array = [
        {"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害", "curse_warning": false, "executable": true, "block_reason": ""},
        {"id": "c1", "name": "闭息蛊", "quality": "稀有", "cost": "2", "effect": "本回合护盾 +6", "curse_warning": false, "executable": true, "block_reason": ""},
    ]
    var host := _mount_with_hand(cards)
    var hand := _named(host, "battle_hand")
    assert_not_null(hand)
    # 常驻 GuTooltipView 已下线：手牌宿主内不允许出现 GuTooltipView 子节点。
    assert_eq(_count_descendants_of_class(hand, "PanelContainer"), 0, "no permanent tooltip mounted into the hand region")
    # 卡面命中区合并为卡体本身（按可识别名作为 Card 标签），同名 Button 只出现一次。
    assert_eq(_count_labels_with_text(hand, "血牙蛊"), 1, "card name must appear once, not three times")
    assert_eq(_count_labels_with_text(hand, "闭息蛊"), 1, "card name must appear once, not three times")

func test_battle_hand_blocked_cards_remain_hoverable_and_carry_block_reason() -> void:
    var cards: Array = [
        {"id": "c0", "name": "月光蛊", "quality": "史诗", "cost": "3", "effect": "对单体造成 8 点伤害", "curse_warning": false, "executable": false, "block_reason": "真元不足：需要 3 点，当前仅有 1 点。"},
    ]
    var host := _mount_with_hand(cards)
    var card_body := _named(host, "card_body_c0")
    assert_not_null(card_body, "disabled cards still render a hoverable card body so players see why")
    # card_body 必须没有被禁用的同款 Button 卡死（不允许卡内还有一个独立的 disabled Button）。
    assert_null(_named(host, "card_press_c0"), "do not render a second disabled Button inside the card")
    # block_reason 在屏快照中可被 BattleScreen 拾取（避免提示被静默丢弃）。
    var state := _host_state(host)
    assert_eq(str(state["hand"][0]["block_reason"]), "真元不足：需要 3 点，当前仅有 1 点。")

func test_battle_hand_hover_updates_screen_tooltip_host() -> void:
    var cards: Array = [
        {"id": "c0", "name": "血牙蛊", "quality": "普通", "cost": "1", "effect": "造成 4 点伤害", "curse_warning": false, "executable": true, "block_reason": ""},
    ]
    var host := _mount_with_hand(cards)
    var body := _named(host, "card_body_c0")
    assert_not_null(body)
    body.emit_signal("mouse_entered")
    var overlay := _named(host, "battle_hand_tooltip_host")
    assert_not_null(overlay, "BattleScreen must own a shared tooltip host for the hand")
    # 当 active card 存在时，宿主上有一个标签展示卡名；不 hover 时不渲染标签。
    assert_not_null(_named(overlay, "hand_tooltip_title"))
```

并新增辅助：

```gdscript
func _mount_with_hand(cards: Array) -> Control:
    var state := _snapshot_with_enemies(1)
    state["hand"] = cards
    return _mount(state)

func _count_descendants_of_class(node: Node, class_name: String) -> int:
    if node == null:
        return 0
    var count := 0
    if node.is_class(class_name):
        count += 1
    for child in node.get_children():
        count += _count_descendants_of_class(child, class_name)
    return count

func _count_labels_with_text(node: Node, text: String) -> int:
    if node == null:
        return 0
    var count := 0
    if node is Label and str(node.text) == text:
        count += 1
    for child in node.get_children():
        count += _count_labels_with_text(child, text)
    return count

func _host_state(host: Node) -> Dictionary:
    # RuiRoot 在 host 上挂一个名为 rui_root 的节点，_fc 包装了 props["state"]。
    # 测试只关心快照的 hand 字段——通过遍历顶层 props 取最后传入的 state。
    # 如不可达，返回 {} 以让断言失败信息明确。
    return _last_state if _last_state != null else {}
```

`_last_state` 需在 `_mount` 里记录：

```gdscript
var _last_state: Dictionary = {}

func _mount(state: Dictionary) -> Control:
    _last_state = state
    ...
```

**Step 2:** 运行 `tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`，**预期全部失败**：tooltip 仍然常驻、卡名出现 3 次、`card_body_c0` 不存在、`battle_hand_tooltip_host` 不存在。失败原因必须符合「P0-2 待修复」语义，而不是脚本错误。

**Step 3:** 暂不实现改动，把失败证据记在 commit message 中。

**Step 4:** 暂不提交（红测文件本身要随实现一起提交）。

---

### Task 2：`GuBattleHand` 卡面去重 + 移除常驻 tooltip + 卡体作为唯一命中区

**Files:**
- Modify: `ui/widgets/gu_battle_hand.guitkx`

**Step 1:** 把循环体替换为：

```gdscript
for card in cards:
    var executable := bool(card.get("executable", true))
    var card_name := str(card.get("name", "蛊虫"))
    var card_id := str(card.get("id", ""))
    var is_active := str(interaction.get("card_id", "")) == card_id
    var body_style := {
        "min_height": 96,
        "size_flags_horizontal": 3,
        "modulate": Color(1, 1, 1, 0.55) if not executable else Color(1, 1, 1, 1.0),
    }
    var card_node := <PanelContainer name={ "card_body_" + card_id } style={ body_style } onMouseEntered={ func(): on_hover.call(card) } onGuiInput={ func(event): if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed): on_cancel.call() }>
      <MarginContainer style={ {"margin_left": 12, "margin_right": 12, "margin_top": 10, "margin_bottom": 10} }>
        <VBoxContainer style={ {"separation": 6} }>
          <HBoxContainer style={ {"separation": 8} }>
            @if (bool(card.get("curse_warning", false))) {
              return (<PanelContainer style={ {"bg_color": GuStyle.DANGER, "corner_radius_all": 4} }><MarginContainer style={ {"margin_left": 5, "margin_right": 5, "margin_top": 1, "margin_bottom": 1} }><Label text="咒" style={ {"font_color": GuStyle.BONE, "font_size": 12} } /></MarginContainer></PanelContainer>)
            }
            <Label text={ card_name } style={ {"font_color": GuStyle.INK_PRIMARY, "font_size": 16} } />
            @if (str(card.get("quality", "")) != "") {
              return (<Label text={ str(card.get("quality", "")) } style={ {"font_color": GuStyle.GOLD, "font_size": 12} } />)
            }
          </HBoxContainer>
          <Label text={ str(card.get("effect", "")) } style={ {"font_color": GuStyle.INK_MUTED, "font_size": 13} } />
          @if (str(card.get("cost", "")) != "") {
            return (<Label text={ "◆ " + str(card.get("cost", "")) } style={ {"font_color": GuStyle.GOLD, "font_size": 13} } />)
          }
          @if (not executable and str(card.get("block_reason", "")) != "") {
            return (<Label text={ "不可用：" + str(card.get("block_reason", "")) } style={ {"font_color": GuStyle.DANGER, "font_size": 12} } />)
          }
        </VBoxContainer>
      </MarginContainer>
    </PanelContainer>
    if is_active:
        # 选中态：边框再加深一层（通过重设 style，不在卡内嵌入任何 tooltip）。
        card_node.style = {
            "bg_color": GuStyle.PAPER,
            "border_color": GuStyle.JADE_BRIGHT,
            "border_width_all": 2,
            "min_height": 96,
            "size_flags_horizontal": 3,
        }
    card_rows.append(card_node)
```

> 关键差异：① 不再嵌入 `GuTooltipView` 或同名 `Button`；② 卡体 PanelContainer 自带 `onMouseEntered` / `onGuiInput`（ESC / 右键取消沿用）；③ 卡名只在一处出现；④ 不可用卡把 `block_reason` 直接打印在卡面红色短行，符合 §16.5“禁用原因可见”；⑤ 卡面仍可 hover（不被 `disabled` 吞掉）。

**Step 2:** 同步调整循环外的空手牌分支 `<Label text="（无手牌）" ...>`（无需 tooltip）。

**Step 3:** 在 `.guitkx` 顶部 import 列表移除 `GuTooltipView`（本文件不再使用）。

**Step 4:** `tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`，预期 Task 1 的第 1、2 个测试转绿；第 3 个（共享浮层）仍失败。

**Step 5:** 暂不提交。

---

### Task 3：`BattleScreen` 共享浮层 host（按 hover/target_select 单点渲染）

**Files:**
- Modify: `ui/screens/battle_screen.guitkx`

**Step 1:** 在屏组件 `BattleScreen` 内已有的 `set_mode`/`reset_interaction` 旁新增浮层渲染函数（在 `play_card` 函数前）：

```gdscript
var render_hand_tooltip = func():
    var tooltip_rows = []
    var mode_now := str(interaction.get("mode", "idle"))
    if mode_now == "hover" or mode_now == "target_select":
        var hovered := interaction.get("card", {})
        if not hovered.is_empty():
            var curse_warning := bool(hovered.get("curse_warning", false))
            tooltip_rows.append(<PanelContainer name="battle_hand_tooltip_host" style={ {"bg_color": GuStyle.PAPER, "corner_radius_all": 6, "border_width_all": 1, "border_color": GuStyle.PAPER_DIM} }>
              <MarginContainer style={ {"margin_left": 12, "margin_right": 12, "margin_top": 10, "margin_bottom": 10} }>
                <VBoxContainer style={ {"separation": 4} }>
                  <HBoxContainer style={ {"separation": 8} }>
                    <Label name="hand_tooltip_title" text={ str(hovered.get("name", "蛊虫")) } style={ {"font_color": GuStyle.INK, "font_size": 16} } />
                    @if (str(hovered.get("quality", "")) != "") {
                      return (<Label text={ str(hovered.get("quality", "")) } style={ {"font_color": GuStyle.GOLD, "font_size": 12} } />)
                    }
                  </HBoxContainer>
                  <Label text={ "效果：" + str(hovered.get("effect", "")) } style={ {"font_color": GuStyle.INK, "font_size": 14} } />
                  @if (not bool(hovered.get("executable", true)) and str(hovered.get("block_reason", "")) != "") {
                    return (<Label text={ "不可用：" + str(hovered.get("block_reason", "")) } style={ {"font_color": GuStyle.DANGER, "font_size": 14} } />)
                  }
                  @if (curse_warning) {
                    return (<Label text={ "诅咒警示：执行即受反噬。" } style={ {"font_color": GuStyle.DANGER, "font_size": 14} } />)
                  }
                </VBoxContainer>
              </MarginContainer>
            </PanelContainer>)
    return tooltip_rows
```

**Step 2:** 把屏函数返回值（在 `return (<VBoxContainer ... />)` 之前）追加 `{ render_hand_tooltip.call() }`，紧贴 `battle_hand` 节点之后。这样 Task 1 第 3 个测试（`battle_hand_tooltip_host`）能找到该节点。

**Step 3:** `on_press` 与 `on_release` 现在挂在卡体 PanelContainer 上，把现有 `play_card(card)` 改为接收 PanelContainer 捕获的 `card`（`onMouseEntered` 传的是 `card` 字典本身）。`target_select` 模式进入后 `mode` 已变 `target_select`，浮层会随之显示当前选中卡的“不可用原因”（若有）。

**Step 4:** 同步把 `on_hover` 回调从 `set_mode.call("hover", card)` 改为不切换 mode——改为调用 `set_interaction.call({...当前状态..., "card": card, "card_id": str(card.get("id", ""))})`，使 hover 不会清掉 target_select 的 `target_id`。具体：在 `BattleScreen` 内 `var on_hover_card = func(card): set_interaction.call({... interaction 现在值 ..., "card": card, "card_id": str(card.get("id", ""))})` 然后传入 `GuBattleHand`。

**Step 5:** `tools/test.ps1 -Test tests/unit/test_wenzhen_battle_screen.gd`，三个测试应当全绿。

**Step 6:** 跑 `tools/test.ps1 -Test tests/unit/test_v3_battle_card_actions.gd` 与 `tests/unit/test_v3_battle_preview_risks.gd`（紧耦合的回归测试），确认现有行为未崩。

**Step 7:** 跑 `tools/check.ps1`，确认全量单测与项目锁检查通过。

**Step 8:** 重生成战斗截图（`ui_capture.gd` 走 default 批即可）：从 worktree 运行 `& "$env:USERPROFILE\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe" --path . -s res://scripts/ui_capture.gd`，抽取 `*_battle_*.png` 在 1920×1080 的截图，README 不要求保留（仅作视觉抽检，留最近一张到 commit message）。

**Step 9:** `git add` 修改的文件，commit message：
```
fix(ui): float hand tooltip, dedupe card body, surface disabled reason

P0-2 follow-up: remove the per-card GuTooltipView that duplicated the
card name three times and cluttered the hand region. Battle hand now
renders a single card body per card (name, quality, effect, cost,
curse badge). When the screen is in hover/target_select mode, a
shared tooltip host surfaces the five fixed segments plus the
card's block_reason for unplayable cards. Cards remain hoverable
even when not executable so the reason is visible (GU/AGENTS §16.5).
```

**Step 10:** `git push -u origin fix/p0-2-battle-hand-tooltip-floating`，等待 CI（如有）/确认推送成功。

---

### Task 4：交付与归档

**Files:**
- Modify: `AGENTS.md`（仅在 worktree 内，不影响主工作区）

**Step 1:** 在「当前状态」追加一行「2026-08-28 fix/p0-2-battle-hand-tooltip-floating 已推送：P0-2 战斗手牌浮层化+去重」，并指向本次 commit。

**Step 2:** 提交并推送到同一分支（不合并到 master，等用户人工验收）。

**Step 3:** 在会话结尾向用户给出：分支名、commit SHA、推送状态、`tools/check.ps1` 全绿证据、截图路径。
