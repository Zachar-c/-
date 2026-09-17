# 第三阶段战斗核心独立审查

> 审查日期：2026-09-17
> 审查对象：提交 `d56660e`（`feat(battle): consolidate M0 and battle core flows`）
> 审查方式：重新执行测试、静态对照实现与契约、核对工作树；不以执行模型的完成说明作为证据。
> 结论：**HOLD——测试层通过，但第三阶段最终契约尚未完全闭合。**

## 1. 审查范围与证据

本次只审查 M0/战斗核心收敛，不重新评估世界观、数值平衡或美术。仓库约束允许交互改动默认使用 headless 门禁，因此本次没有把真实窗口手工操作冒充为已验证。

重新执行的结果：

| 检查 | 结果 |
|---|---:|
| 战斗核心契约单测 | 17/17，299 断言 |
| 战斗核心流程集成 | 5/5，54 断言 |
| 预览 / facade / 存档聚焦测试 | 45/45，195 断言 |
| 生命周期 / M0 / 文真 UI 流程 | 11/11，135 断言 |
| 全量 unit | 1576/1576，52620 断言 |
| 全量 integration | 46/46，1639 断言 |
| 交互门禁 | 15 屏；`dead=[]`、`no_ui_click=[]`、`occluded=[]` |
| `tools/check.ps1` | 退出码 0；contract drift `230 identifiers resolved` |

全量测试退出时仍报告 4 个 warning、2 个 orphan、8 个 ObjectDB 实例泄漏、2 个资源仍在使用。这些没有造成当前测试失败，但必须作为独立技术债记录，不能被“全绿”吞掉。

## 2. 已确认成立的部分

1. `BattleCommandFacade.apply_turn` 是运行时战斗命令的统一入口；`RunBattleFlow` 开局走 `start_session`，不再直接推进账本。
2. 终局、拒绝不变更、敌人先手、存档回放、Boss 禁撤和多敌目标均有自动化覆盖。
3. M0 与文真 UI 的普通战斗路径使用胜利收口，不会把“投降/撤离”当作默认结束路径。该结论来自 `test_m0_core_loop.gd` 与 `test_wenzhen_ui_flow.gd`，不是来自肉眼推断。
4. 相同种子和相同命令序列的最终战斗状态与战斗事件日志可复现。

## 3. 未做到的地方

### F-01（P1）：撤离预览与领域执行门禁不一致

证据链：

- `ActionPreviewService._append_battle_retreat_card` 同时检查 Boss、地形/追击状态和元石数量，并据此设置 `executable`。
- `BattleCommandFacade.apply_turn` 的 `retreat` 分支目前只调用 `boss_blocks_retreat`；普通战斗不会再次检查地形或元石。
- `test_battle_core_contract.gd` 用 `PREVIEW_ONLY_GATES = ["battle.retreat"]` 主动跳过了被预览禁用但领域仍会接受的卡片。

这直接违反战斗计划最终门禁第 3 条“预览、命令构建和执行使用同一套可执行性语义”。当前契约文档把差异写成“待裁定”，所以测试通过不能证明该门禁已经完成。

建议：以当前预览规则为准，让领域执行复用相同的撤离门禁，并补充“元石不足/地形不允许时 preview=false 且 execute=false”的测试；或者明确删除预览侧门禁并同步所有文档。未作选择前保持 HOLD。

证据锚点：

- `scripts/domain/action_preview_service.gd`：`_append_battle_retreat_card`
- `scripts/domain/battle_command_facade.gd`：`apply_turn` 的 `"retreat"` 分支
- `tests/unit/test_battle_core_contract.gd`：`PREVIEW_ONLY_GATES` 与 `test_preview_executable_commands_are_accepted_and_disabled_ones_rejected`

### F-02（P1）：规范化战斗命令载荷与新鲜度校验未闭合

计划要求每张 Gu 卡的嵌套 `command` 至少等价于：

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

这不是当前普通战斗必然报错，但它使“规范化命令携带上下文”和“过期命令拒绝”成为文档承诺而非运行时事实。必须二选一：接通已有预检并补 stale command 测试，或正式修订契约，说明这些字段仅为展示/去重元数据而非执行门禁。

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

该要求已在自动化路径中成立：普通战斗由可接受的战斗命令推进到 `battle_victory`，M0 四战和文真 UI 流程均没有使用撤离作为默认结束。它不等于撤离按钮已经具备正确的元石/地形执行门禁；后者仍由 F-01 阻断。

## 5. 放行结论与后续条件

本次提交可以作为当前工程状态的审查快照，但不能据此宣称第三阶段最终 Gate 已全部通过。关闭 F-01、F-02 后，至少重新执行：

1. 战斗核心契约单测与集成测试；
2. 全量 unit、integration 与 `tools/verify_interaction_loop.gd`；
3. `tools/check.ps1`、`git diff --check`；
4. 更新本报告的结论和待办登记。

相关活文档：

- [战斗结算接口](../../contracts/module-interfaces/01-battle-settlement.md)
- [行动预览接口](../../contracts/module-interfaces/06-action-preview.md)
- [表现层命令面](../../contracts/module-interfaces/08-presentation-command-surface.md)
- [战斗核心实施计划](../plans/2026-09-17-battle-core-module-implementation.md)
