# 第三阶段战斗核心独立审查

> 审查日期：2026-09-17
> 审查对象：提交 `d56660e`（`feat(battle): consolidate M0 and battle core flows`）
> 审查方式：重新执行测试、静态对照实现与契约、核对工作树；不以执行模型的完成说明作为证据。
> 结论（2026-09-18 收口）：**`F-01` / `F-02` 已判定 CLOSED** —— 修复 + 回归守卫 + 第 1 节复验 + 独立复验二次确认，四项条件齐备；二次结论已回收，最终计数为可写 `user://` 下全量 unit **1581/1581** / integration **56/56**（证据见 §9）。**`F-03`～`F-06` 仍为 P2 技术债。**

## 1. 审查范围与证据

本次只审查 M0/战斗核心收敛，不重新评估世界观、数值平衡或美术。仓库约束允许交互改动默认使用 headless 门禁，因此本次没有把真实窗口手工操作冒充为已验证。

首次审查（`d56660e`）与收口后重跑（2026-09-17 `fa6357d8` + 未提交工作树）的结果：

| 检查 | 首次审查 `d56660e` | 收口后重跑（含退出码） |
|---|---:|---:|
| 战斗核心契约单测 | 17/17，299 断言 | **18/18，327 断言**（rc=0） |
| 战斗核心流程集成 | 5/5，54 断言 | **8/8，72 断言**（rc=0） |
| 全量 unit | 1576/1576，52620 断言 | **1577/1577，52651 断言**（rc=0，SCRIPT ERROR 0，2 orphan） |
| 全量 integration | 46/46，1639 断言 | **49/49，1657 断言**（rc=0，SCRIPT ERROR 0） |
| 交互门禁 `tools/verify_interaction_loop.gd` | 15 屏；`dead=[]`、`no_ui_click=[]`、`occluded=[]` | **15 屏，三项全空**（rc=0） |
| 契约漂移 `tools/check_contract_drift.gd` | 230 identifiers resolved | **231 identifiers resolved**（rc=0） |
| 启动探针 `--quit-after 3` | — | **rc=0**，ERROR/SCRIPT ERROR 0 |
| `git diff --check` | — | **rc=0**（无空白错误） |
| `tools/check.ps1` | 退出码 0（真窗会话） | **本会话不可用**，见下方说明 |

**`tools/check.ps1` 在本次 agent 会话里给不出结论**：脚本在 `tools/test.ps1` 处抛终止错误
`Unable to open Android 'build-tools' directory.` —— 这是 Godot 启动期对缺失 Android SDK 的原生
stderr 警告，被 PowerShell 5.1 的 `$ErrorActionPreference='Stop'` 升级为终止错误，GUT 尚未启动
即中止（`RC_AFTER_CATCH=-1`）。属会话环境问题，不是代码缺陷（同族问题 `check.ps1:18-20` 已对
启动探针段做过降级处理，`test.ps1` 段未做）。其四个组成门禁已用直连命令逐条跑通并留计数：
`guitkx_build`（`compiled=0 errors=0 held=0 total=16`）、GUT 全量 unit/integration、`--quit-after 3` 启动探针、
`tools/check_contract_drift.gd`、`git diff --check` —— 见上表。

退出期残留（未造成失败，继续按技术债记账）：unit 会话 8 个 ObjectDB 实例泄漏、2 个资源仍在使用、
2 个 orphan；integration 无泄漏，仅 Dialogue Manager 的 invalid UID 警告。

> **第二轮（独立复验反馈后）的重跑结果见 §6**，第三轮见 §7，第四轮环境与最终计数见 §8 / §9。上表是首轮收口时的记录，保留为证据链。

## 2. 已确认成立的部分

1. `BattleCommandFacade.apply_turn` 是运行时战斗命令的统一入口；`RunBattleFlow` 开局走 `start_session`，不再直接推进账本。
2. 终局、拒绝不变更、敌人先手、存档回放、Boss 禁撤和多敌目标均有自动化覆盖。
3. M0 与文真 UI 的普通战斗路径使用胜利收口，不会把“投降/撤离”当作默认结束路径。该结论来自 `test_m0_core_loop.gd` 与 `test_wenzhen_ui_flow.gd`，不是来自肉眼推断。
4. 相同种子和相同命令序列的最终战斗状态与战斗事件日志可复现。

## 3. 审查发现（F-01 / F-02 已关闭，F-03～F-06 仍开放）

> 每条保留原始证据链，再记「处置 + 证据锚点」。`F-01` / `F-02` 的关闭条件是：实现修复 + 回归守卫 + 本报告第 1 节
> 列出的复验 + **独立复验二次确认**，四者齐备；仅测试变绿不算关闭。第二轮独立复验提出的 5 项已修复（§6）、
> 第三轮针对 `F-02` 的 5 项补修已修复（§7）、第四轮把复跑中的 16 unit + 1 integration 失败归因并复现为
> 「`user://` 不可写」的环境问题（§8），**独立复验二次结论已于 2026-09-18 回收** ⇒ 按上述四项条件判定 **CLOSED**（§9）。

### F-01（P1）：撤离预览与领域执行门禁不一致 —— **已关闭（CLOSED，2026-09-18）**

原缺陷证据链：

- `ActionPreviewService._append_battle_retreat_card` 同时检查 Boss、地形/追击状态和元石数量，并据此设置 `executable`。
- `BattleCommandFacade.apply_turn` 的 `retreat` 分支目前只调用 `boss_blocks_retreat`；普通战斗不会再次检查地形或元石。
- `test_battle_core_contract.gd` 用 `PREVIEW_ONLY_GATES = ["battle.retreat"]` 主动跳过了被预览禁用但领域仍会接受的卡片。

这直接违反战斗计划最终门禁第 3 条“预览、命令构建和执行使用同一套可执行性语义”。当前契约文档把差异写成“待裁定”，所以测试通过不能证明该门禁已经完成。

**处置（选择“以预览规则为准”）**：

1. 门禁唯一来源 `scripts/domain/battle_command_facade.gd` 新增纯函数族：
   `boss_blocks_retreat`（收编两代形状：`flags.boss_battle` + 敌方 `tier`/`enemy_definition.tier`）、
   `retreat_terrain_open`（terrain ∈ path/ridge/marsh 且 pursuit/enemy_control ≤ 1）、
   `retreat_cost`（`retreat_preserved` 免付，否则读 `catalog.balance.retreat_stone_cost`）、
   以及 `retreat_gate(battle, state, catalog) -> {ok, reason, cost}`（Boss → 地形/追击 → 元石）。
2. `ActionPreviewService._append_battle_retreat_card` 改为只转呈门禁结论：`executable = gate.ok`、`reason = gate.reason`，
   `block_reason`/`remedy_hints` 由同一组布尔派生；`_boss_blocks_retreat`/`_retreat_terrain_open` 降级为对门面的转发，
   预览侧不再持有第二份判定。
3. `apply_turn` 的 `retreat` 分支改为先跑 `retreat_gate`，不通过即 `_rejected(battle, state, gate.reason)`——
   拒绝走既有 `_rejected`（`battle.duplicate(true)` + 原 state），不落事件、不写 `battle_finished`。
4. `tests/unit/test_battle_core_contract.gd` 删除 `PREVIEW_ONLY_GATES`（含测试体内对该豁免的 `continue`），
   新增 `test_retreat_preview_and_execute_share_the_same_gates`：允许 / Boss / 元石不足 / 地形不允许四路径，
   断言 preview `executable` ⇔ execute `accepted`、卡片 `reason` 与拒绝 `feeds` 同码、拒绝后 battle/事件日志/
   `battle_finished` 三者零变化。
5. 副作用一：`tests/unit/test_data_driven_guard.gd::test_preview_reads_costs_from_balance` 由「扫预览源含
   `retreat_stone_cost`」改为「唯一来源（门面）读该键 + 预览必须调 `retreat_gate` 且不得重复读该键」——守卫意图不变，
   从“预览读键”升级为“单一真值”。副作用二：`tests/unit/test_v1_battle_settlement_guards.gd` 的裸 V1 battle 夹具补
   `terrain = "path"`（缺地形不开放撤离是预览侧既有语义，`test_preview_retreat_gate.gd::test_v1_retreat_still_terrain_gated` 仍钉住它）。

证据锚点：

- `scripts/domain/battle_command_facade.gd`：`retreat_gate` / `retreat_cost` / `retreat_terrain_open` / `boss_blocks_retreat`、`apply_turn` 的 `"retreat"` 分支
- `scripts/domain/action_preview_service.gd`：`_append_battle_retreat_card`（转呈门禁）
- `tests/unit/test_battle_core_contract.gd`：`test_retreat_preview_and_execute_share_the_same_gates`、`test_preview_executable_commands_are_accepted_and_disabled_ones_rejected`（已无豁免）

### F-02（P1）：规范化战斗命令载荷与新鲜度校验未闭合 —— **已关闭（CLOSED，2026-09-18）**

原缺陷：计划要求每张 Gu 卡的嵌套 `command` 至少等价于：

```gdscript
{
    "type": "use_gu",
    "instance_id": instance_id,
    "target_id": "",
    "state_version": state.event_log.size(),
    "expected_phase": str(battle.get("phase", "player_action")),
}
```

实际情况：

- Gu、基础攻击、杀招的嵌套 `command` 缺少 `expected_phase`；只有卡片顶层补了该字段。
- `RunController.submit_command` 的战斗路径直接转发给 `BattleCommandFacade`，没有经过 `CommandSpecRegistry` 的 `battle.action_card` / `battle.turn` freshness preflight。
- 测试文件明确把 V1 战斗新鲜度预检标记为“废除”，因此当前测试并未证明旧卡/旧阶段命令会被拒绝。

**处置（选择“接通预检”，即字段是执行门禁而不是展示元数据）**：

1. 卡片载荷补齐：`_append_battle_gu_card` / `_battle_basic_attack_card` / `_append_battle_kill_card` 的嵌套 `command` 全部带
   `expected_phase`（`state_version` 原已具备）；`RunCommandBuilder._battle_card_command` 的 gu / 拳脚 / 杀招 / 通用卡四路与
   `_battle_turn_command` 同步补齐。旧 `play_card(action_id, target_id, confirmed)` 兼容包装保留，改为按 ID 组装同一份带上下文的命令，
   UI 不重算领域规则。
2. 提交路径接线：`RunBattleFlow.submit_battle_command` 在门面前调 `CommandSpecRegistry.preflight`——`type=="action_card"` 或
   `action_id` 以 `battle.` 开头走 `battle.action_card`，其余 `is_battle_command` 走 `battle.turn`；非战斗命令直接放行。
   拒绝返回与门面同形的信封（`accepted=false` / `feeds=[reason]` / `finished=false` / `ok=false`），并且只 `_show_battle()` 重绘。
3. `_preflight_battle_card` 的两处缺省对齐 V1 契约：`hand_version` 缺失时 `expected_version` 回落 `state.event_log.size()`；
   `expected_phase` 缺省由 `"player"` 改为 `"player_action"`（原默认值与 V1 phase 取值不符）。
4. 拒绝原因接入玩家文案：`rejection_text.gd` 新增 `battle_hand_stale` / `battle_action_stale` / `battle_phase_stale` / `command_context_missing`。
5. 新增覆盖（`tests/integration/test_battle_core_flow.gd`）：有效命令通过（`test_valid_battle_command_with_fresh_context_is_accepted`）、
   `state_version` 过期拒绝（`battle_action_stale`）、`expected_phase` 过期拒绝（`battle_phase_stale`）；后两条逐条断言 battle 深比较不变、
   事件日志长度不变、无 `battle_finished`、当前屏仍为 Battle。
6. 既有调用点同步补齐新鲜度字段（12 个文件）：`test_drive_to_ending`、`test_m0_core_loop`、`test_wenzhen_ui_flow`、`test_battle2_lifecycle`、
   `test_first_run_flow`、`test_battle_save_load_semantics`、`test_encounter_session`、`test_moonlight_full_route`、`test_slay_gu_final_chapter`、
   `test_slice_ending`、`test_v1_five_layer_clear`、`test_v2_first_slice_flow`；`test_battle_opening_warning` 里陈旧的
   `expected_phase: "player"` 字面量改为读当前战斗阶段。接线前这些点全绿（字段从未被校验），接线后 13 个 unit + 11 个 integration 用例集体转红——除 2 条（下面是 F-01 的守卫/夹具改写）外，其余 12 + 11 条都是本项的直接证据。

证据锚点：

- `docs/superpowers/plans/2026-09-17-battle-core-module-implementation.md`：Task 3 Step 1 / Step 4
- `scripts/domain/action_preview_service.gd`：`_append_battle_gu_card`、`_battle_basic_attack_card`、`_append_battle_kill_card`
- `scripts/presentation/run_controller.gd`：`submit_command`
- `scripts/domain/command_spec_registry.gd`：`_preflight_battle_card`、`_preflight_battle_turn`

### F-03（P2）：计划完成状态没有回写

战斗实施计划仍保留全部 `- [ ]` 检查框。它可以作为原始执行清单，但不能单独作为“Task 0–6 已完成”的证明。本报告是当前独立验收记录；在 F-01/F-02 关闭前，最终 Gate 不应标记为完成。

### F-04（P2）：表现层残留无用账本 preload

`run_controller.gd` 仍保留 `Battle2TurnEngineScript` 与 `CultivatorRulesScript` preload。当前代码路径没有直接推进它们，行为上未造成失败，但与“账本生命周期只属 facade”的边界声明不完全一致，应在后续清理或用测试固定“不得直接调用”的卫生规则。

### F-05（P2）：确定性测试的接受性断言偏弱

`test_same_seed_and_command_sequence_replay_to_the_same_battle` 逐条提交命令，但只断言最终状态/日志相同，并以 `first_events.size() > 0` 作为“脚本确实推进过”的证明，没有逐条断言 `accepted`、`result` 和拒绝时的无变更语义。当前结果仍可作为回放证据，但不是最强的命令序列验收。

### F-06（P2）：提交边界需要继续拆清

提交时工作树包含战斗核心、M0、契约、计划和测试等 36 个文件；审查前没有可用于区分执行模型起点的基线 SHA，因此不能把所有文件都归因于 Tare。备份、负控日志和生成短名单已刻意排除在提交之外，仍留在工作树中。

## 4. “非必要不投降”验收结论

该要求已在自动化路径中成立：普通战斗由可接受的战斗命令推进到 `battle_victory`，M0 四战和文真 UI 流程均没有使用撤离作为默认结束。撤离按钮的元石/地形/Boss 判据已由 F-01 的同源门禁 `retreat_gate` 收口（§3 F-01）；F-01 已于 2026-09-18 判定 CLOSED（§9），本节的「非必要不投降」口径不受阻碍。

## 5. 放行结论与后续条件

`F-01`、`F-02` 状态：**CLOSED**（2026-09-18）。第 1 节列出的四项复验均已重新执行并留下退出码与通过计数
（`tools/check.ps1` 因会话环境不可用，已按其组成门禁逐条直连复验）。独立复验**不接受首轮签收**而提出的 5 项待修（§6）
已全部修复并补齐回归守卫；针对 `F-02` 的第三轮 5 项补修（§7）已完成并经负控（RED 检查）验证；第四轮（§8）把复跑中出现的
16 unit + 1 integration 失败归因并**负控复现**为「`user://` 不可写」的环境问题，与本次改动无关。
**独立复验二次结论已回收** ⇒ 关闭条件四项齐备，最终计数见 §9。

仍未关闭的是 `F-03`～`F-06` 四项 P2 技术债（计划复选框未回写、表现层残留无用账本 preload、确定性回放断言偏弱、
提交边界未拆清），以及第 1 节记录的退出期 ObjectDB/orphan 残留。这些不阻断本轮交付，但不应被“全绿”吞掉。

本轮改动共 33 个文件（全部为 `M`，无新增/删除），已于 2026-09-18 收口为**单个可回溯提交**。

## 6. 独立复验反馈与修复（2026-09-17 第二轮）

独立复验**不接受首轮签收**，要求只修复以下 5 项后重新复验。逐项处置与证据锚点：

| # | 独立复验意见 | 处置 | 证据锚点 |
|---|---|---|---|
| 1 | `scripts/acceptance_driver.gd` 生成的战斗命令缺 `state_version` / `expected_phase`，真实 `smoke/play` 验收路径无法提交 | `_play_gu_command` / `_battle_turn_command` 按 `controller.state.event_log.size()` 与 `current_battle.phase` 补上下文，并改为 `static` 供回归测试直调；6 处蛊命令调用点同步 | `scripts/acceptance_driver.gd:3190,3199`；`tests/integration/test_battle_core_flow.gd::test_acceptance_driver_battle_commands_carry_freshness_context` |
| 2 | 新鲜度拒绝未写入 `last_feedback`，战斗界面不显示拒绝文案；被拒命令仍播放成功动画/音效 | 预检拒绝与领域拒绝（新增 `run_battle_flow._turn_rejected`）都在 `_show_battle()` **之前**写 `last_feedback`（文案取 `rejection_text.gd`）；`battle_screen_view` 新增 `_command_rejected`，被拒时不播 `battle_card_play` / 墨迹扩散、不进 `play_success` 态，并释放去重键供重试 | `scripts/presentation/run_battle_flow.gd:79,97-115`；`scripts/presentation/screens/battle_screen_view.gd:281,310,815` |
| 3 | 旧 `play_card("battle.end_turn" / "battle.retreat")` 兼容路径不能路由 | 根因：现行卡 id（`ActionPreviewService.preview_battle_actions`）是 `battle.end_turn` / `battle.retreat`（**无 battle_id 段**），而 `_action_card_passthrough` 只认 `battle.<battle_id>.end_turn` ⇒ 一律 `unsupported_battle_action`。补「现行形状 + 旧信封」两代并存 | `scripts/domain/battle_command_facade.gd::_action_card_passthrough` |
| 4 | 缺对应回归测试 | 新增 6 条：过期拒绝反馈可见（预检分支 + 领域分支）、旧 `play_card` 结束回合与撤离、被拒不出成功动效且可重试、验收驱动命令上下文 | `tests/integration/test_battle_core_flow.gd`（+3）、`tests/unit/test_battle_command_facade.gd`（+3） |
| 5 | 活跃契约未同步；审查报告中 F-01 状态自相矛盾 | §1/§3/§5 写「已关闭」而 §4 写「仍由 F-01 阻断」——已统一改判为 HOLD（该判定为第二轮当时的状态；2026-09-18 二次结论回收后已收口为 `CLOSED`，见 §9）；契约 `2026-09-02-domain-ui-contract.md` 补「命令新鲜度 / 拒绝可见性与零副作用 / 旧 `play_card` id 形状」三节，模块契约 08 同步 | 本报告 §4/§5/§6；`docs/contracts/2026-09-02-domain-ui-contract.md` §3.2 / §5.1 / §7；`docs/contracts/module-interfaces/08-presentation-command-surface.md` |

### 第二轮门禁结果（工作树，未提交）

| 检查 | 结果（含退出码） |
|---|---|
| 聚焦 · 战斗核心契约单测 `test_battle_core_contract.gd` | 18/18，327 断言（rc=0，SCRIPT ERROR 0） |
| 聚焦 · 战斗核心流程集成 `test_battle_core_flow.gd` | 11/11，95 断言（rc=0，SCRIPT ERROR 0） |
| 聚焦 · 门面单测 `test_battle_command_facade.gd` | 32/32，116 断言（rc=0，SCRIPT ERROR 0） |
| 聚焦 · 命令契约守卫 `test_command_contract.gd` | 11/11，42 断言（rc=0，SCRIPT ERROR 0） |
| 全量 unit | **1580/1580**，52660 断言（rc=0，SCRIPT ERROR 0；2 orphan、1 泄漏、1 资源在用） |
| 全量 integration | **52/52**，1680 断言（rc=0，SCRIPT ERROR 0，无泄漏） |
| 交互门禁 `tools/verify_interaction_loop.gd` | 15 屏，`dead=[]` / `occluded=[]` / `no_ui_click=[]` 三项全空（rc=0） |
| 契约漂移 `tools/check_contract_drift.gd` | 242 identifiers resolved（rc=0） |
| 启动探针 `--quit-after 3` | rc=0，ERROR / SCRIPT ERROR 0 |
| `git diff --check` | rc=0（无空白错误） |
| `tools/check.ps1` | **本会话仍不可用**：`guitkx_build` 段通过（`compiled=0 errors=0 held=0 total=16`），随后在 `test.ps1` 段抛 `CAUGHT: Unable to open Android 'build-tools' directory.`（`RC_AFTER_CATCH=-1`，7s 中止）。与首轮同因（Godot 原生 stderr × PS5.1 `Stop`），非代码缺陷；其组成门禁已逐条直连并留计数（见上表各行）。 |

**计数校验**：`NOTHING_RAN=0`（`Nothing was run` 命中 0 次）。本仓 GUT 在"什么都没跑"时**同样 rc=0**（实测：`-gdir` 被 shell 拼接坏成 `res` 时只打 `The path [res] does not exist.` 并 rc=0），因此本轮结论以 `Tests` / `Passing Tests` 计数**存在且 >0** 为准，不以退出码为准。

**相对首轮的增量**：unit 1577→1580（+3：旧 `play_card` 结束回合、旧 `play_card` 撤离、被拒不出成功动效）、integration 49→52（+3：预检拒绝反馈、领域拒绝反馈、验收驱动命令上下文）；无既有用例被改红。

## 7. F-02 补修（第三轮，2026-09-17）

第二轮 5 项修复后，独立复验在 `F-02` 上又提出 5 项；逐项处置与证据锚点：

| # | 独立复验意见 | 处置 | 证据锚点 |
|---|---|---|---|
| 1 | `RunCommandBuilder` 的 `play_card` lambda 未显式 `return`，领域拒绝信封被吞 | 战斗屏以「返回 `null` = 命令未转呈」判定是否走兼容回退，lambda 丢弃信封会让**被拒**命令被当成「没转呈」而放行成功态。`submit_command` 与 `play_card` 两个 lambda 均改为显式 `return controller.submit_command(...)`，拒绝信封一路回到战斗屏 | `scripts/presentation/run_command_builder.gd:174-175` |
| 2 | 旧 `play_card("battle.end_turn" / "battle.retreat")` 被拒时不得进成功态 / 不得播墨迹 / 必须可重试，且须走**真实 `RunController` 路径** | 战斗屏新增 `_command_rejected(result)`（认 `accepted` / `ok`），在成功路径**之前**拦截：不播 `battle_card_play`、不推墨迹、不进 `play_success`，并 `_submitted_card_keys.erase(request_key)` 释放去重键供原地重试；集成用例经真实 controller 提交旧形状卡验证 | `scripts/presentation/screens/battle_screen_view.gd:272-282, 808-816`；`tests/integration/test_battle_core_flow.gd::test_rejected_legacy_play_card_keeps_the_battle_screen_retryable` |
| 3 | 旧卡 id 形状兼容口径不统一：**声明兼容但一提交就被 preflight 拒** | 新增唯一映射点 `BattleCommandFacade.canonical_action_card_id`，把两代形状按**后缀**归一到现行手牌 id（`battle.end_turn` / `battle.retreat` / `basic_attack`，由 `ActionPreviewService.preview_battle_actions` 产出、**不含 `battle_id` 段**）；**刻意不读 `battle_id`**（生产战斗从不设置该键），否则旧形状既路由不到又过不了 controller preflight。`_action_card_passthrough` 复用之 | `scripts/domain/battle_command_facade.gd:313-337`；`tests/unit/test_battle_command_facade.gd::test_card_id_shapes_canonicalise_to_the_current_hand_ids` |
| 4 | 缺**真实路径**（非 facade 直调）回归测试 | 新增 1 unit + 4 integration：现行卡形状过 preflight、两代撤离 id 命中同一门禁、旧 `play_card` 被拒可重试、新鲜上下文被接受 | `tests/integration/test_battle_core_flow.gd`（+4）；`tests/unit/test_battle_command_facade.gd`（+1） |
| 5 | 活跃契约仍留有「已关闭」矛盾表述 | `2026-09-02-domain-ui-contract.md` 第 85 行与模块契约 08 统一改判 `HOLD`（第三轮当时的状态；2026-09-18 已收口为 `CLOSED`，见 §9）；两份文档补「命令新鲜度 / 拒绝可见性与零副作用 / 旧 `play_card` id 形状」三节 | `docs/contracts/2026-09-02-domain-ui-contract.md:85,238`；`docs/contracts/module-interfaces/08-presentation-command-surface.md:28,52` |

### 第三轮门禁结果（工作树，未提交）

| 检查 | 结果（含退出码） |
|---|---|
| 聚焦 · 门面单测 `test_battle_command_facade.gd` | 32/32（rc=0，SCRIPT ERROR 0） |
| 聚焦 · 战斗核心流程集成 `test_battle_core_flow.gd` | 11/11（rc=0，SCRIPT ERROR 0） |
| 全量 unit | **1581/1581**，52673 断言（rc=0，SCRIPT ERROR 0；2 orphan、8 ObjectDB 泄漏、2 资源在用） |
| 全量 integration | **56/56**，1723 断言（rc=0，SCRIPT ERROR 0；48 orphan） |
| 交互门禁 `tools/verify_interaction_loop.gd` | 15 屏，`dead=[]` / `occluded=[]` / `no_ui_click=[]` 三项全空（rc=0） |
| 契约漂移 `tools/check_contract_drift.gd` | 242 identifiers resolved（rc=0） |
| 启动探针 `--quit-after 3` | rc=0，ERROR / SCRIPT ERROR 0 |
| `git diff --check` | rc=0（无空白错误） |
| `tools/check.ps1` | **本会话仍不可用**（同因：`guitkx_build` 通过后在 `test.ps1` 段抛 Android `build-tools` 目录缺失），其组成门禁已逐条直连（见上表各行） |

**计数校验**：`NOTHING_RAN=0`（`Nothing was run` 在 unit / integration 两份日志中命中 0 次）。本仓 GUT 在「什么都没跑」时同样 rc=0，故结论以 `Tests` / `Passing Tests` 计数**存在且 >0** 为准。

**相对第二轮的增量**：unit 1580→1581（+1：两代卡 id 归一）、integration 52→56（+4：现行形状过 preflight、两代撤离 id 同门禁、旧 `play_card` 被拒可重试、新鲜上下文被接受）；无既有用例被改红。

**负控（RED 检查）**：临时摘掉 `play_card` 的 `return` 并把 `canonical_action_card_id` 退化为恒等，确认新增用例确实转红后才恢复，并回验无残留。

**状态**：`F-01` / `F-02` 修复与回归守卫已落地、门禁全绿（详见 §8）；独立复验二次结论回收后，已于 2026-09-18 判定 **CLOSED**（见 §9）。

## 8. 全量门禁环境归因与文档统一（第四轮，2026-09-18）

独立复验在本机复跑全量得到 unit 1563/1581（16 失败）、integration 55/56（1 失败），表现为 `SaveRepository.save_run` 返回非 OK（错误码 `12`）。本轮三件事：统一文档状态、复跑全量、把失败归因钉死。

### 8.1 文档状态统一

`docs/contracts/module-interfaces/06-action-preview.md:31` 原写「`F-01` 已于 2026-09-17 关闭」，与同页第 53 行的 `HOLD` 自相矛盾 ⇒ 已改为「已于 2026-09-17 落地修复，但状态为 `HOLD`——独立复验二次结论未回收，本页不作「已关闭」声明」；随着二次结论回收，该处已于 2026-09-18 改为 `CLOSED`（见 §9）。全库复扫 `已关闭`：`F-01`/`F-02` 相关表述已无残留（其余命中是历史报告里的无关条目）。

### 8.2 归因：失败完全由「`user://` 不可写」造成，非代码缺陷

`save_run` 的返回码来自 `FileAccess.get_open_error()`（`scripts/domain/save_repository.gd:19-21`）：`FileAccess.open(TEMP_PATH, WRITE)` 失败即返回 `12`（`ERR_FILE_CANT_OPEN`）。

**负控复现**：把 `APPDATA` 指向一个被同名文件挡住的路径，使 `user://` 不可写（该次日志首行即 `ERROR: Could not create directory: 'user://logs'.`）：

| 门禁 | 不可写 `user://`（负控实测） | 独立复验所见 |
|---|---|---|
| unit | 1563/1581，**16 失败** | 1563/1581，16 失败 |
| integration | 55/56，**1 失败** | 55/56，1 失败 |

16 条失败全部落在 8 个**依赖 `user://` 读写**的脚本：`test_battle_save_load_semantics`、`test_map_exit_persistence`、`test_moonlight_school_start`、`test_runtime_seed_policy`、`test_save_import_export`、`test_settings_display`、`test_t5a_confirm_toast`、`test_v3_ui_sync`；集成侧 1 条是 `test_battle_core_flow.gd::test_battle_death_ends_the_run_with_the_precise_cause_then_a_fresh_run_resets`，失败行正是 `assert_eq(SaveRepository.save_run(...), OK)`（`tests/integration/test_battle_core_flow.gd:453`）。**无一条与 `F-01` / `F-02` 改动相关。**

按既定口径（不把 `user://` 写权限当缺陷），**未改任何生产代码**，也未给测试加「跳过存档断言」的软化处理。

### 8.3 可写 `user://` 下的全量结果（两套独立配置）

`user://` 解析为 `%APPDATA%\Godot\app_userdata\蛊真人`（`project.godot` `config/name="蛊真人"`，未启用 `use_custom_user_dir`）。把 `APPDATA` 重定向到**全新空目录**即可得到干净的 `user://`：

```bash
export APPDATA="<writable dir>"    # 例：<repo>/.workbuddy/test_appdata（.gitignore 已覆盖）
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit
```

| 门禁 | A：工作区外全新可写目录 | B：工作区内 `.workbuddy/test_appdata`（受限沙箱亦可用） |
|---|---|---|
| unit | **1581/1581**，52673 断言（rc=0） | **1581/1581**，52673 断言（rc=0） |
| integration | **56/56**，1723 断言（rc=0） | **56/56**，1723 断言（rc=0） |
| SCRIPT ERROR | 0 | 0 |
| `NOTHING_RAN` | 0 | 0 |

两次的 `user://` 都是**全新空目录**（`app_userdata/蛊真人` 由该次运行首次创建），排除「只有靠历史存档才全绿」的可能。B 把 `user://` 落在工作区内，因此**写权限被限制在工作区的沙箱同样可写**——这是给最终独立复验用的推荐配置。

第三轮门禁（交互门禁 15 屏三键全空、契约漂移 242 项、启动探针 ERROR/SCRIPT ERROR 0、`git diff --check` rc=0）在本轮未复跑，结论沿用 §7。

### 8.4 结论

全量在可写 `user://` 环境达到 **1581/1581** 与 **56/56**；独立复验据此回收二次结论，`F-01` / `F-02` 于 2026-09-18 判定 **CLOSED**（收口记录见 §9）。本轮唯一生产/文档改动是 `06-action-preview.md:31` 的状态统一（工作树 33 个文件全 `M`，无未跟踪文件）。

## 9. 收口与关闭结论（2026-09-18）

独立复验二次结论已回收 ⇒ `F-01` / `F-02` 按 §3 预设的四项关闭条件（实现修复 + 回归守卫 + 第 1 节复验 + 独立复验二次确认）判定 **CLOSED**。`F-03`～`F-06` 仍为 P2 技术债，不在本次收口范围。

### 9.1 最终状态

| 项 | 状态 | 判据摘要 |
|---|---|---|
| `F-01` 撤离预览与执行门禁漂移 | **CLOSED** | 撤离门禁唯一来源 `BattleCommandFacade.retreat_gate`（Boss → 地形/追击 → 元石）；预览只转呈、执行复用同一纯门禁；`PREVIEW_ONLY_GATES` 豁免已删除 |
| `F-02` 战斗命令新鲜度闭环 | **CLOSED** | Gu / 基础攻击 / 杀招 / 结束回合 / 撤离的嵌套 `command` 全带 `state_version` + `expected_phase`；`RunBattleFlow.submit_battle_command` → `CommandSpecRegistry` preflight；拒绝可见且零副作用；两代卡 id 形状由唯一映射点 `canonical_action_card_id` 归一 |

### 9.2 保留的独立复审证据

| 检查 | 结果 |
|---|---|
| 全量 unit（**可写 `user://`**） | **1581/1581**，52673 断言（rc=0，SCRIPT ERROR 0） |
| 全量 integration（**可写 `user://`**） | **56/56**，1723 断言（rc=0，SCRIPT ERROR 0） |
| `NOTHING_RAN` | 0（unit / integration 两份日志均未出现 `Nothing was run`） |
| 负控：不可写 `user://` | 1563/1581（16 失败）+ 55/56（1 失败），失败全部落在 8 个依赖 `user://` 读写的脚本 ⇒ 证明 Full-suite 假红源于环境，见 §8.2 |
| `tools/check.ps1` | 本会话仍不可用（组成门禁逐条直连替代），非代码缺陷 |

复跑命令（`.workbuddy/` 已被 `.gitignore` 覆盖，不产生未跟踪文件）：

```bash
export APPDATA="<repo>/.workbuddy/test_appdata"   # 全新空目录：先 rm -rf 再 mkdir
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit
```

### 9.3 交付范围

本次收口只做**文档状态同步**，未再修改任何生产代码（`scripts/` 下的改动全部来自前三轮已记录的修复）。33 个文件集结为单个可回溯提交。

相关活文档：

- [战斗结算接口](../../contracts/module-interfaces/01-battle-settlement.md)
- [行动预览接口](../../contracts/module-interfaces/06-action-preview.md)
- [表现层命令面](../../contracts/module-interfaces/08-presentation-command-surface.md)
- [战斗核心实施计划](../plans/2026-09-17-battle-core-module-implementation.md)
