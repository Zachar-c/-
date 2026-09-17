# Battle Core Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有蛊行动制战斗收敛为第一个可独立测试、可复现、由单一入口驱动的核心模块，不新增战斗机制。

**Architecture:** 保留 `BattleCommandFacade` 作为唯一外部战斗命令入口，保留 `V1BattleResolver` 作为纯规则结算内核，保留 `Battle2TurnEngine` 作为内部回合账本。表现层的 `RunBattleFlow` 只编排生命周期和页面切换，`BattleSnapshot` 与行动预览只做只读投影；M0 和完整运行流继续复用同一战斗管线。

**Tech Stack:** Godot 4.7.2, GDScript, GUT, JSON data tables, deterministic seeded run state.

**Independent audit status (2026-09-17):** `HOLD`. The fresh unit, integration, interaction, and repository checks pass, but the final gate is not closed. Findings `F-01` (retreat preview/execution gate drift) and `F-02` (normalized command freshness contract not fully wired) are recorded in [`docs/superpowers/reports/2026-09-17-battle-core-audit.md`](../reports/2026-09-17-battle-core-audit.md). The checkboxes below remain the execution checklist; they are not evidence that every final-gate condition is satisfied.

## Global Constraints

- 本阶段只收敛现有战斗模块，不新增距离、速度、复杂状态、杀招、敌人或数值机制。
- M0 四战切片和完整运行流的既有玩法语义必须保持不变。
- UI 只能提交命令，不能直接修改 `battle`、`RunState` 或资源。
- `BattleCommandFacade` 是唯一外部战斗命令入口；`V1BattleResolver` 是唯一战斗规则结算内核。
- `Battle2TurnEngine` 只能作为领域内部回合账本使用，表现层不得直接推进它。
- 预览与执行必须共用同一套领域门禁；拒绝命令不得修改 battle、RunState、资源或事件日志。
- 相同 seed 加相同命令序列必须产生相同战斗结果和事件事实。
- 保持当前战斗存档语义：战斗中保存同步后的 HP，但加载后不恢复 `current_battle`，回到 Map。
- 不修改 `data/`、`world-model/`、美术资源或 M0 之外的玩法系统。
- 不执行 `git reset --hard`、`git checkout --`、递归清理或强制推送。
- 当前 M0 改动尚未全部提交；执行本计划前必须保护现有工作树，不覆盖或回退这些改动。

## Current Evidence Baseline

现有代码已经具备战斗骨架，但职责尚未完全收敛：

- `scripts/domain/battle_command_facade.gd` 已提供 `start`、`apply_turn`、`apply_enemy_pre_turn` 和 `boss_blocks_retreat`。
- `scripts/domain/v1_battle_resolver.gd` 已包含蛊行动、拳脚、杀招、结束回合、敌人意图、伤害、状态、胜负和死亡结算。
- `scripts/domain/battle2/turn_engine.gd` 已提供阶段、念头、持续行动和每回合使用账本。
- `scripts/presentation/run_battle_flow.gd` 仍直接创建和清理 `current_battle2_ledger`，形成表现层与门面层共同管理回合账本的现状。
- `scripts/presentation/snapshots/battle_snapshot.gd` 负责蛊卡投影；`scripts/domain/action_preview_service.gd` 负责基础行动预览，蛊卡与基础行动存在两套预览来源。
- 既有测试包括 `test_battle_command_facade.gd`、`test_battle2_lifecycle.gd`、`test_battle2_turn_ledger.gd`、`test_battle2_actions_defense.gd`、`test_action_preview_service.gd`、`test_battle_save_load_semantics.gd` 和 `test_m0_core_loop.gd`。

本计划解决的是边界、生命周期、预览一致性和验收覆盖，不把已有机制重新设计一遍。

---

### Task 0: Protect the M0 baseline and inventory battle ownership

**Files:**
- Read-only: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/AGENTS.md`
- Read-only: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/01-battle-settlement.md`
- Read-only: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/06-action-preview.md`
- Read-only: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/08-presentation-command-surface.md`

**Interfaces:**
- Consumes: current working tree, current M0 changes, existing battle contracts.
- Produces: an execution baseline; no production code changes.

- [ ] **Step 1: Confirm the actual repository and worktree.**

Run from `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor`:

``@@BT@powershell
git status --short --branch
git diff --stat
git diff --check
``@@BT@

Expected: the existing M0 modifications and untracked M0 documents remain visible; no command changes the tree.

- [ ] **Step 2: Inventory direct turn-ledger callers.**

``@@BT@powershell
rg -n "Battle2TurnEngine|current_battle2_ledger" scripts tests
``@@BT@

Expected direct runtime ownership before the change: `run_battle_flow.gd` initializes/finalizes the per-battle ledger, while `battle_command_facade.gd` advances it for accepted ongoing actions.

- [ ] **Step 3: Do not begin implementation if the baseline is not understood.**

The executor must preserve the current M0 files and must not use reset, checkout, clean, or force-push operations to make the baseline look clean.

---

### Task 1: Add the battle-core contract tests before changing ownership

**Files:**
- Create: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_core_contract.gd`
- Create: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_battle_core_flow.gd`
- Reference: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_command_facade.gd`
- Reference: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_battle2_lifecycle.gd`

**Interfaces:**
- Consumes: `BattleCommandFacade.start`, `BattleCommandFacade.apply_turn`, `BattleCommandFacade.apply_enemy_pre_turn`, existing `RunController` battle flow.
- Produces: executable acceptance tests for the canonical battle lifecycle and no-mutation rejection behavior.

- [ ] **Step 1: Write unit tests for battle construction and intent visibility.**

The new unit test must preload `BattleCommandFacade`, call `ContentCatalog.load_all()`, create `RunState.new_run(101)`, and assert:

``@@BT@gd
var battle: Dictionary = FacadeScript.start({"enemy_kind": "beast_swarm"}, state, catalog)
assert_eq(str(battle["phase"]), "player_action")
assert_false((battle.get("enemies", []) as Array).is_empty())
assert_true((battle["enemies"][0] as Dictionary).has("intent"))
assert_true((battle["enemies"][0]["intent"] as Dictionary).has("kind"))
``@@BT@

- [ ] **Step 2: Write the accepted-action and end-turn tests.**

Cover one accepted `use_gu`, one accepted `end_turn`, enemy intent resolution, new player-turn resources, and the `used_this_turn` reset. Use the existing test fixture and command shapes from `test_battle_command_facade.gd`; do not introduce a new command shape.

Required assertions:

``@@BT@gd
assert_true(bool(use_result.get("accepted", false)))
assert_eq(str(use_result.get("result", "")), "ongoing")
assert_lt(int(use_result["battle"]["player"]["true_qi"]), int(battle["player"]["true_qi"]))
assert_true(int(end_result["battle"]["turn"]) > int(use_result["battle"]["turn"]))
assert_eq(int(end_result["battle"]["player"]["used_this_turn"]), 0)
``@@BT@

- [ ] **Step 3: Write the no-mutation rejection tests.**

For each rejected command, deep-copy the battle and record `state.event_log.size()` before submission. Assert the returned battle equals the copy and the event-log size is unchanged. Cover:

- repeated use of the same Gu in one turn (`gu_used_this_turn`);
- unknown Gu (`unknown_gu`);
- terminal battle follow-up (`battle_over`);
- Boss retreat (`retreat_forbidden`);
- unsupported battle action (`unsupported_battle_action`).

- [ ] **Step 4: Write determinism and terminal tests.**

Run the same seed and command sequence twice and compare the terminal battle signature, player resources, enemy HP, and structured event facts. Assert victory, defeat, and explicit ordinary retreat each set `finished=true`, while any follow-up action is rejected.

- [ ] **Step 5: Run only the new focused tests.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_battle_core_contract.gd -gtest res://tests/integration/test_battle_core_flow.gd -gexit -glog=2
``@@BT@

Expected before implementation: any failure must identify an actual lifecycle or ownership gap, not a parser error or missing fixture.

---

### Task 2: Make the facade the owner of the per-battle lifecycle

**Files:**
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/domain/battle_command_facade.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/presentation/run_battle_flow.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/presentation/run_controller.gd` only to remove a now-unused direct turn-engine preload.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_battle2_lifecycle.gd`

**Interfaces:**
- Consumes: `BattleCommandFacade.start`, `BattleCommandFacade.apply_turn`, `BattleCommandFacade.apply_enemy_pre_turn`, `Battle2TurnEngine.new_turn`, `Battle2TurnEngine.consume`.
- Produces: `BattleCommandFacade.start_session(encounter, state, catalog) -> Dictionary` and `BattleCommandFacade.finalize_session(battle, state, outcome) -> Dictionary`.

The new session interface must return:

``@@BT@gd
{
    "battle": Dictionary,
    "state": RunState,
    "result": "ongoing"
}
``@@BT@

The finalization interface must return:

``@@BT@gd
{
    "state": RunState,
    "ledger": Dictionary
}
``@@BT@

- [ ] **Step 1: Add `start_session`.**

Implement `start_session` by calling the existing `start`, creating the per-battle ledger with `Battle2TurnEngine.new_turn(CultivatorRules.thought_capacity(...))`, and returning both battle and updated state. Keep `start` available for existing direct unit tests; it remains a compatibility constructor and must not introduce a second rule path.

- [ ] **Step 2: Move ledger initialization out of `run_battle_flow.gd`.**

Change `start_battle` to call `BattleCommandFacade.start_session`. Remove the direct `Battle2TurnEngine` and `CultivatorRules` initialization from the presentation flow. Keep first-mover calculation, warning display, and screen routing in `run_battle_flow.gd`.

- [ ] **Step 3: Make accepted turn advancement pass through the facade.**

Keep the existing `apply_turn` return shape. On every accepted ongoing player action, advance the ledger exactly once. On rejected commands, do not create, consume, or clear a ledger. On enemy pre-turn, preserve the existing no-extra-thought semantics and return the updated state through the same result dictionary.

- [ ] **Step 4: Add `finalize_session`.**

Copy the current ledger into an immutable return snapshot, clear `state.current_battle2_ledger`, and return both. Do not append a battle-finished event inside the facade; `run_battle_flow.gd` remains responsible for the single lifecycle event.

- [ ] **Step 5: Make `finish_battle_in_session` consume the facade result.**

Replace direct reads and writes of `state.current_battle2_ledger` with `finalize_session`. Preserve the existing `_battle2_ledger` event info key and the existing event ordering.

- [ ] **Step 6: Run the focused lifecycle tests.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/integration/test_battle2_lifecycle.gd -gtest res://tests/unit/test_battle_core_contract.gd -gexit -glog=2
``@@BT@

Expected: ledger creation, one-step advancement, final event snapshot, and post-exit clearing remain green.

---

### Task 3: Unify battle preview and command construction

**Files:**
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/domain/action_preview_service.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/presentation/snapshots/battle_snapshot.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/presentation/run_command_builder.gd` only to consume normalized command payloads while retaining compatibility wrappers.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_action_preview_service.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_command_facade.gd` for command/target parity assertions.

**Interfaces:**
- Consumes: `V1BattleResolver.can_play_gu`, `V1BattleResolver.basic_attack_reason`, `V1BattleResolver.kill_move_reason`, current battle snapshot schema.
- Produces: normalized battle action cards with a `command` dictionary and one source of executable/blocking state.

- [ ] **Step 1: Add a Gu-card preview helper to `ActionPreviewService`.**

The helper must produce one card for each `battle.gu_slots` entry, using the existing V1 gate and existing display fields. The returned command must be equivalent to:

``@@BT@gd
{
    "type": "use_gu",
    "instance_id": str(slot.get("instance_id", "")),
    "target_id": "",
    "state_version": state.event_log.size(),
    "expected_phase": str(battle.get("phase", "player_action"))
}
``@@BT@

Do not duplicate cost, rank, effect, or rejection calculations in the UI.

- [ ] **Step 2: Make `BattleSnapshot` consume the normalized preview.**

Preserve the current `hand` dictionary shape used by `battle_screen_view.gd`; adapt field names at the projection boundary instead of changing the UI card schema. `BattleSnapshot` must not call a second copy of `can_play_gu` logic.

- [ ] **Step 3: Make command building prefer the card command.**

Keep `_battle_card_command` for old callers and existing tests. The mounted battle UI path must submit the card's normalized `command`, adding only the currently selected `target_id` when the card declares `target_type="single_enemy"`.

- [ ] **Step 4: Add preview/execute parity tests.**

Cover:

- true-qi insufficiency;
- thought insufficiency;
- same-turn Gu reuse;
- sealed Gu;
- cultivation/rank gate;
- invalid target;
- multi-enemy target selection;
- Boss retreat disabled in both preview and execution.

- [ ] **Step 5: Run focused preview and facade tests.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_action_preview_service.gd -gtest res://tests/unit/test_battle_command_facade.gd -gexit -glog=2
``@@BT@

Expected: every executable preview command is accepted by the facade, and every blocked preview command is rejected without state mutation.

---

### Task 4: Close terminal, rejection, determinism, and event contracts

**Files:**
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/domain/battle_command_facade.gd` only where Task 1 tests expose a contract gap.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/domain/v1_battle_resolver.gd` only where an existing pure rule violates the already documented battle contract.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/scripts/presentation/run_controller.gd` if a missing rejection text prevents a documented battle reason from reaching the UI.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_core_contract.gd`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_save_load_semantics.gd` only to strengthen an existing assertion without changing the current save policy.

**Interfaces:**
- Consumes: normalized facade result, existing immutable event log, current save policy.
- Produces: stable terminal and rejection behavior.

- [ ] **Step 1: Enforce terminal immutability.**

After `victory` or `defeat`, `apply_turn` must return `accepted=false`, `result="rejected"`, and `feeds=["battle_over"]` for every battle action. The returned battle must remain unchanged.

- [ ] **Step 2: Enforce one event per accepted action.**

An accepted player action appends one `battle_v1` event. A terminal exit appends one `battle_finished` event in the presentation lifecycle. Rejected commands append no event.

- [ ] **Step 3: Preserve explicit retreat semantics.**

Ordinary retreat remains a player-submitted terminal path. Boss retreat remains rejected with `retreat_forbidden`. M0 ordinary combat must continue to reach rewards through `battle_victory`, not retreat.

- [ ] **Step 4: Add deterministic trace coverage.**

Run two controllers with the same seed and submit the same command list. Compare battle phase, turn, player resources, enemy HP, event actions, event reasons, and terminal result. Run a second seed only to prove that the result is not accidentally globally cached.

- [ ] **Step 5: Preserve current save behavior.**

The existing `test_battle_save_load_semantics.gd` must continue to assert that loading during battle returns to Map with synced HP and an empty `current_battle`. Do not implement mid-battle scene restoration in this stage.

---

### Task 5: Regress M0 and normal battle integration

**Files:**
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_battle_core_flow.gd`
- Modify only when necessary to strengthen existing assertions: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_m0_core_loop.gd`, `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_first_run_flow.gd`, `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/integration/test_wenzhen_ui_flow.gd`

**Interfaces:**
- Consumes: `RunController.start_m0_run`, normal `_start_battle`, `RunBattleFlow`, `BattleCommandFacade`.
- Produces: proof that the battle module can serve both M0 and the full run without a second implementation.

- [ ] **Step 1: Verify normal battle victory.**

Use the existing normal-flow fixture and submit real accepted battle commands until `battle_finished` has reason `battle_victory`. Assert that no `battle_retreat` appears in the default victory path.

- [ ] **Step 2: Verify M0 compatibility.**

Keep the existing M0 assertions for four fights, three reward choices, Boss victory, death restart, deterministic reward signatures, and save restoration. Add only battle-core assertions where the current test does not already prove them.

- [ ] **Step 3: Verify enemy-first and multi-enemy paths.**

Use the existing `test_battle2_lifecycle.gd` fixture. Assert that enemy-first opening damage, two-enemy target selection, one accepted-turn ledger advance, and retreat finalization all use the same facade boundary.

- [ ] **Step 4: Run focused integration tests.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/integration/test_battle_core_flow.gd -gtest res://tests/integration/test_battle2_lifecycle.gd -gtest res://tests/integration/test_m0_core_loop.gd -gtest res://tests/integration/test_first_run_flow.gd -gexit -glog=2
``@@BT@

Expected: normal victory, M0 victory, explicit retreat, death, enemy-first, and multi-enemy paths all pass without command-route duplication.

---

### Task 6: Update live battle contracts and run the full gate

**Files:**
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/01-battle-settlement.md`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/06-action-preview.md`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/module-interfaces/08-presentation-command-surface.md`
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/docs/contracts/2026-09-02-domain-ui-contract.md` only for newly confirmed battle keys or commands.
- Modify: `C:/Users/Zachary/DevEnv/06_个人项目/gu-zhenren/gu-zhenren-editor/tests/unit/test_battle_core_contract.gd` if a contract assertion is missing.

**Interfaces:**
- Consumes: final implementation behavior and passing focused tests.
- Produces: auditable live contracts and a complete verification record.

- [ ] **Step 1: Document the final ownership boundary.**

The battle settlement contract must explicitly state that `RunBattleFlow` does not directly advance `Battle2TurnEngine`, and that `BattleCommandFacade` owns the per-battle lifecycle bridge.

- [ ] **Step 2: Document the normalized action-card contract.**

The action-preview contract must state that Gu actions, basic actions, kill moves, end-turn, and retreat expose command payloads and use the same domain preflight gates as execution.

- [ ] **Step 3: Run focused unit and integration suites.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_battle_core_contract.gd -gtest res://tests/unit/test_battle_command_facade.gd -gtest res://tests/unit/test_action_preview_service.gd -gtest res://tests/unit/test_battle2_turn_ledger.gd -gtest res://tests/unit/test_battle_save_load_semantics.gd -gexit -glog=1

& .\tools\godot.ps1 --headless --path . -s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit -glog=1
``@@BT@

- [ ] **Step 4: Run the interaction gate.**

``@@BT@powershell
& .\tools\godot.ps1 --headless --path . -s tools/verify_interaction_loop.gd
``@@BT@

Expected:

``@@BT@text
dead=[]
no_ui_click=[]
occluded=[]
``@@BT@

- [ ] **Step 5: Run static hygiene checks.**

``@@BT@powershell
git diff --check
git status --short
``@@BT@

The executor must report existing warnings, ObjectDB leaks, or unrelated failures separately and must not silently classify them as battle-core success.

## Final Stage-3 Gate

第三阶段只有在以下条件全部成立时才算完成：

1. 战斗状态机只有一个权威命令入口。
2. `Battle2TurnEngine` 不再由表现层直接推进。
3. 预览、命令构建和执行使用同一套可执行性语义。
4. 拒绝命令不改变任何领域状态或事件日志。
5. 相同输入可复现相同战斗结果。
6. 胜利、死亡、撤离、Boss 禁撤和存档语义均有测试。
7. M0 和完整运行流无行为回归。
8. 全量集成、全量单元和交互门禁通过。
9. 未引入本阶段之外的新机制。

## Executor Handoff

执行模型必须按 Task 0 → Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 顺序推进。每个任务先写或补测试，再做最小实现；遇到新增机制、数据扩容或 UI 重做需求时停止并登记，不得夹带进第三阶段。除非另行授权，执行模型不得提交或推送。


