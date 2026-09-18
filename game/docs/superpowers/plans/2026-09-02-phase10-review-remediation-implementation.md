# Phase 10 Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 2026-09-01 第十批合并审查发现的假绿门禁、Battle2 状态所有权和生命周期、真实快照接线、十二族旧规则清退及验收证据不足，并交付可按固定 SHA 范围复审的完成报告。

**Architecture:** `RunState.battle2_ledger` 是离散战斗回合的唯一权威状态，所有变化经 `Resolver.apply()` 和不可变 `append_event()` 进入状态与日志；Controller 只提交命令，`RunSnapshotBuilder.for_screen()` 只投影状态。旧 V1 战斗、抽牌、行动点、随机炼蛊等按规格 §18 一族一提交清退；18 条规则矩阵与一条真实 Controller 连续流程分开提供证据。

**Tech Stack:** Godot 4.7.2、GDScript、JSON、GUT、PowerShell、Git。

## Global Constraints

- 开工审查基点固定为 `cc6635d0a49e53079d30939f790023b4001cabd3`；开工 SHA 如有偏离，必须先在完成报告解释新增提交，不得悄悄改变复审范围。
- 开工先执行 `git status --short --branch`、`git rev-parse HEAD`；记录 `IMPLEMENTATION_BASE`，不得改写或丢弃用户改动。本计划文件可作为唯一已知未跟踪交接工件保留且不得夹带进实现提交；除此之外如工作树不干净，先记录并保护已有改动，不得自行清理。
- 必读：`AGENTS.md`、规格 `docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md` §17.2/§17.3/§17.4/§18、`docs/superpowers/plans/2026-09-02-phase10-execution-brief.md` 及三份 `docs/contracts/2026-09-02-*.md` 契约。
- 先红后绿；每个任务只提交本任务文件。每个旧规则族删除后必须跑 focused test 和 `-Suite all`，一族一提交。
- UI 不得直接修改领域字段；状态变化只经 Controller 命令 -> `Resolver.apply()` -> 领域规则 -> `RunState.append_event()`。
- `battle2_ledger` 必须复制、持久化并通过事件 `after` 写入；`_battle2_ledger` 只允许作为日志归因副本，不能托管实时状态。
- 空账本执行 `enact` 必须以 `battle2_not_started` 原因拒绝，禁止静默创建容量为 5 的满念头账本。
- 战斗开始容量只来自 `CultivatorRules.thought_capacity(state.cultivator, catalog)`；后续回合只经 `Battle2TurnEngine.start_turn(current, capacity, continue_ids)`。
- §18.6 废止连续时间，不废止整数离散回合。`duration_turns` 和蛊方阶段的整数回合数可保留；速度倍率、完成时刻、小数动作进度和全场速度排序必须删除。
- 当前基点的 `battle2/turn_engine.gd`、`action_resolver.gd`、`body_rules.gd` 只覆盖回合账本、距离/防御和肉身规则；敌人集合、敌方意图推进、敌我气血落账、胜负/死亡与战利品闭环仍由旧战斗路径承担。阶段十执行简报规定本批除 ledger 权威化外“只删不改”，所以 Task 10 必须先证明这些生产转换已有 Battle2 替代；缺任一项即按已知架构阻塞报告，禁止在清退提交里发明新战斗规则或删除仍在托管可玩闭环的代码。
- 不修改 `addons/gut`、`vendor/`、`分支：六卷精编版/`、`肉鸽设计-原始数据/`、`.worktrees/game-impl/`。
- 每个提交后记录 hash；最终报告必须含开工 SHA、最终 SHA、逐提交 hash、12 族对照、18 条结果、行数与完整验证证据。

## File And Interface Map

| Responsibility | Files | Stable interface after remediation |
| --- | --- | --- |
| Strict GUT execution | `tools/run_gut_checked.ps1`, `tools/test.ps1`, `tools/tests/test_run_gut_checked.ps1` | 非零退出、解析错误、跳过脚本、零测试均失败 |
| Battle2 state | `scripts/domain/run_state.gd`, `scripts/domain/v2_commands.gd`, `scripts/domain/resolver.gd` | `battle2_ledger`; commands `start_battle2_turn`, `finish_battle2`, `enact` |
| Battle2 lifecycle owner | `scripts/presentation/run_controller.gd` | Controller 只调用 `Resolver.apply()`，不赋值 ledger |
| Read-only projection | `scripts/presentation/run_snapshot_builder.gd` | `transparency_v2(controller)`; `for_screen(screen, controller)` returns eight groups |
| Legacy abolition | `tests/unit/test_legacy_abolition.gd` plus files listed per family | 12 independently reviewable absence guards |
| Acceptance evidence | `tests/integration/test_spec_v4_acceptance.gd`, `tests/integration/test_spec_v4_vertical_flow.gd` | 18-rule matrix plus real continuous flow |
| Review evidence | `docs/superpowers/reports/2026-09-02-phase10-review-remediation-report.md` | fixed-SHA completion report |

---

### Task 1: Make Skipped GUT Scripts Fail The Gate

**Files:**
- Create: `tools/run_gut_checked.ps1`
- Create: `tools/tests/test_run_gut_checked.ps1`
- Modify: `tools/test.ps1`
- Modify: `tests/unit/test_t5d_debug_panel.gd`

**Interfaces:**
- Consumes: `tools/godot.ps1`, GUT command-line output.
- Produces: `run_gut_checked.ps1 -CommandPath <path> -CommandArguments <array> [-ExpectedTestPath <res path>]`; exit `0` only when a nonzero test count ran without parse/script errors.

- [ ] **Step 1: Add the missing preload and prove the target file really runs**

Add beside the existing preloads in `test_t5d_debug_panel.gd`:

```gdscript
const DebugActionsScript = preload("res://scripts/domain/debug_actions.gd")
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5d_debug_panel.gd
```

Expected before the preload: output contains `Parse Error` or `DebugActionsScript` and the file is skipped. Expected after the preload: the file name appears, at least one test runs, and no parse/ignore message appears. Record the reported test count.

- [ ] **Step 2: Write runner self-tests before the helper exists**

`tools/tests/test_run_gut_checked.ps1` must create temporary fake command scripts and assert these cases:

```powershell
Assert-Exit 0 @('tests/unit/test_ok.gd', 'Tests 1', 'Passing 1')
Assert-Exit 1 @('Parse Error: bad identifier', 'Ignoring script tests/unit/test_bad.gd')
Assert-Exit 1 @('Nothing was run')
Assert-Exit 1 @('SCRIPT ERROR: Invalid access', 'Tests 1')
Assert-Exit 1 @('Tests 0', 'Passing 0')
Assert-Exit 1 @('Tests 1', 'Passing 1') -ExpectedTestPath 'res://tests/unit/test_missing.gd'
```

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/tests/test_run_gut_checked.ps1
```

Expected: FAIL because `tools/run_gut_checked.ps1` does not exist.

- [ ] **Step 3: Implement the checked runner**

The helper must capture and re-emit combined stdout/stderr, preserve the native exit code, and reject case-insensitive matches for `Parse Error`, `Ignoring script`, `Nothing was run`, and `SCRIPT ERROR`. It must also reject a zero/missing test count and, when `ExpectedTestPath` is supplied, require the normalized target path or basename in output.

Use this public parameter shape:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CommandPath,
    [Parameter(Mandatory)][string[]]$CommandArguments,
    [string]$ExpectedTestPath = ''
)

$ErrorActionPreference = 'Stop'
$lines = @(& $CommandPath @CommandArguments 2>&1 | ForEach-Object { [string]$_ })
$nativeExit = $LASTEXITCODE
$lines | Write-Output

$raw = $lines -join "`n"
$plain = [regex]::Replace($raw, "`e\[[0-9;?]*[ -/]*[@-~]", '')
if ($nativeExit -ne 0) { exit $nativeExit }
if ($plain -match '(?im)Parse Error|Ignoring script|Nothing was run|SCRIPT ERROR') { exit 1 }

$counts = [regex]::Matches($plain, '(?im)^\s*Tests\s*:?\s*(\d+)\s*$')
if ($counts.Count -eq 0) { exit 1 }
$executed = 0
foreach ($match in $counts) { $executed += [int]$match.Groups[1].Value }
if ($executed -le 0) { exit 1 }

if ($ExpectedTestPath) {
    $normalized = $ExpectedTestPath.Replace('\\', '/')
    $basename = [IO.Path]::GetFileName($normalized)
    if ($plain.Replace('\\', '/') -notmatch [regex]::Escape($normalized) -and
        $plain -notmatch [regex]::Escape($basename)) { exit 1 }
}
exit 0
```

`tools/test.ps1` must keep `guitkx_build.ps1`, but replace every direct GUT invocation with this helper. A focused run passes `-ExpectedTestPath "res://$Test"`; suite runs require only a nonzero count. Do not edit GUT vendor code.

- [ ] **Step 4: Verify helper and real GUT execution**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/tests/test_run_gut_checked.ps1
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_t5d_debug_panel.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_legacy_abolition.gd
```

Expected: all PASS; both GUT files report a positive executed-test count; output contains none of the four forbidden diagnostics.

- [ ] **Step 5: Commit**

```powershell
git add tools/run_gut_checked.ps1 tools/tests/test_run_gut_checked.ps1 tools/test.ps1 tests/unit/test_t5d_debug_panel.gd
git commit -m "fix(test): fail the gate when GUT skips test scripts"
```

---

### Task 2: Give Battle2 Ledger Immutable RunState Ownership

**Files:**
- Modify: `scripts/domain/run_state.gd`
- Modify: `scripts/domain/v2_commands.gd`
- Modify: `tests/unit/test_run_state.gd`
- Modify: `tests/unit/test_command_rejections_v2.gd`
- Modify: `tests/unit/test_save_gate_v4.gd`

**Interfaces:**
- Consumes: `RunState.append_event(event)`, `RunState.to_save_data()`, `SaveRepository.serialize_run/load_run_from_data`.
- Produces: persisted `RunState.battle2_ledger`; rejection reason `battle2_not_started`.

- [ ] **Step 1: Add three failing ownership tests**

Add tests named exactly:

```gdscript
func test_append_event_preserves_battle2_ledger() -> void:
    var state := RunState.new_run(101)
    state.battle2_ledger = {"phase": "declare", "thoughts_left": 2}
    var next := state.append_event({"action": "probe", "after": {"stone": state.stone + 1}})
    assert_eq_deep(next.battle2_ledger, state.battle2_ledger)

func test_battle2_ledger_changes_only_through_event_after() -> void:
    var state := RunState.new_run(101)
    var ledger := {"phase": "declare", "thoughts_left": 3}
    var next := state.append_event({"action": "battle2_turn_started", "after": {"battle2_ledger": ledger}})
    assert_eq_deep(next.battle2_ledger, ledger)
    assert_eq_deep(next.event_log.back()["after"]["battle2_ledger"], ledger)
```

In `test_command_rejections_v2.gd` add `test_enact_rejects_when_battle2_not_started_unchanged`; in `test_save_gate_v4.gd` add `test_v4_round_trip_preserves_battle2_ledger` using `Battle2TurnEngine.new_turn(3)`.

Run all three focused files. Expected: ledger preservation and save round-trip FAIL; empty `enact` currently succeeds.

- [ ] **Step 2: Make ledger a normal state field and remove post-event mutation**

Add `"battle2_ledger"` to `RunState.STATE_FIELDS`. Replace `V2Commands.enact` fallback and post-assignment with immutable event data:

```gdscript
if state.battle2_ledger.is_empty():
    return _reject(state, "battle2_not_started")
var out := Battle2TurnEngineScript.enact(state.battle2_ledger, proposal)
var next: RunState = state.append_event(_event(
        state, "battle2_enact",
        {"battle2_ledger": state.battle2_ledger, "_battle2_ledger": state.battle2_ledger},
        {"battle2_ledger": out["ledger"], "_battle2_ledger": out["ledger"]},
        "player_enact", []))
```

Do not assign `next.battle2_ledger` after `append_event()`.

- [ ] **Step 3: Verify ownership and persistence**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_run_state.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_command_rejections_v2.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_save_gate_v4.gd
```

Expected: PASS; original state remains unchanged; loaded ledger deep-equals saved ledger.

- [ ] **Step 4: Commit**

```powershell
git add scripts/domain/run_state.gd scripts/domain/v2_commands.gd tests/unit/test_run_state.gd tests/unit/test_command_rejections_v2.gd tests/unit/test_save_gate_v4.gd
git commit -m "fix(spec-v4): persist battle2 ledger in RunState"
```

---

### Task 3: Wire The Battle2 Lifecycle Through Domain Commands

**Files:**
- Modify: `scripts/domain/v2_commands.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `tests/unit/test_command_rejections_v2.gd`
- Modify: `tests/unit/test_combat_node_fight.gd`
- Create: `tests/unit/test_battle2_lifecycle.gd`

**Interfaces:**
- Consumes: `Battle2TurnEngine.new_turn(capacity)`, `start_turn(ledger, capacity, continue_ids)`, `CultivatorRules.thought_capacity(cultivator, catalog)`.
- Produces: commands `start_battle2_turn {continue_ids:Array[String]}` and `finish_battle2 {outcome:String}`; events `battle2_turn_started`, `battle2_finished`.

- [ ] **Step 1: Write lifecycle tests through Resolver**

Cover these exact behaviors in `test_battle2_lifecycle.gd`:

```gdscript
func test_start_command_uses_catalog_thought_capacity() -> void
func test_next_turn_resets_once_per_turn_usage_and_keeps_continue_ids() -> void
func test_start_command_appends_battle2_turn_started() -> void
func test_finish_command_clears_ledger_and_appends_battle2_finished() -> void
func test_unrelated_append_event_after_enact_keeps_ledger() -> void
func test_controller_routes_battle2_commands_while_encounter_node_is_active() -> void
```

Tune `catalog["balance"]["thought_base_capacity"] = 7`, call `Resolver.apply(state, {"type":"start_battle2_turn","continue_ids":[]}, catalog)`, and assert capacity `7`; do not call `TurnEngine` directly for the behavior under test.

Run the new file. Expected: FAIL with `unknown_command`.

- [ ] **Step 2: Add thin lifecycle handlers and dispatch**

Add `CultivatorRulesScript` preload to `v2_commands.gd` and handlers with this behavior:

```gdscript
static func start_battle2_turn(state, command: Dictionary, catalog: Dictionary) -> Dictionary:
    var capacity := CultivatorRulesScript.thought_capacity(state.cultivator, catalog)
    var continue_ids: Array = command.get("continue_ids", [])
    var ledger := Battle2TurnEngineScript.new_turn(capacity) if state.battle2_ledger.is_empty() else Battle2TurnEngineScript.start_turn(state.battle2_ledger, capacity, continue_ids)
    var next = state.append_event(_event(state, "battle2_turn_started",
            {"battle2_ledger": state.battle2_ledger},
            {"battle2_ledger": ledger, "_battle2_ledger": ledger},
            "battle2_turn_started", []))
    return _accept(next, {"ledger": ledger})

static func finish_battle2(state, command: Dictionary, _catalog: Dictionary) -> Dictionary:
    if state.battle2_ledger.is_empty():
        return _reject(state, "battle2_not_started")
    var outcome := str(command.get("outcome", "resolved"))
    var next = state.append_event(_event(state, "battle2_finished",
            {"battle2_ledger": state.battle2_ledger},
            {"battle2_ledger": {}, "_battle2_ledger": state.battle2_ledger},
            "battle2_%s" % outcome, []))
    return _accept(next)
```

Register both names in `Resolver._dispatch`.

- [ ] **Step 3: Connect production start/end without direct state assignment**

Add a Controller allowlist for `start_battle2_turn`, `finish_battle2`, `enact`, `dodge`, `grapple`, and `respond`. Route these names to `Resolver.apply()` before the generic `if not current_node.is_empty()` encounter-session branch; otherwise every real combat node swallows them in `EncounterSessionResolver`. The helper must replace `state` only with the Resolver result, update `last_result`/feedback, and re-render Battle while the ledger remains active. Do not add a second command switch in `RunCommandBuilder` yet; the UI command migration belongs to Family 6 after its replacement gate passes.

At battle entry, Controller must call `Resolver.apply(state, {"type":"start_battle2_turn","continue_ids":[]}, catalog)` and replace `state` with the returned state before showing Battle. At each formal new turn use the same command with selected maintained IDs. At all battle exits, including victory, retreat and death cleanup, apply `finish_battle2` before clearing presentation session data. This task makes the ledger authoritative but does not claim that the old enemy/intent/loot owner is already replaceable. Search and remove every `state.battle2_ledger =` outside fixture setup.

Add Controller-path assertions to `test_combat_node_fight.gd`: entering combat creates a nonempty ledger and `battle2_turn_started`; `_finish_battle_in_session()` clears it through `battle2_finished`.

- [ ] **Step 4: Verify lifecycle**

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_battle2_lifecycle.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_combat_node_fight.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_command_rejections_v2.gd
rg -n "battle2_ledger\s*=" scripts
```

Expected: tests PASS; `rg` finds only the declaration and local variables, never Controller or post-event assignment.

- [ ] **Step 5: Commit**

```powershell
git add scripts/domain/v2_commands.gd scripts/domain/resolver.gd scripts/presentation/run_controller.gd tests/unit/test_command_rejections_v2.gd tests/unit/test_combat_node_fight.gd tests/unit/test_battle2_lifecycle.gd
git commit -m "fix(spec-v4): wire battle2 turn lifecycle"
```

---

### Task 4: Expose V2 Transparency Through Real Screen Snapshots

**Files:**
- Modify: `scripts/presentation/run_snapshot_builder.gd`
- Modify: `tests/unit/test_snapshot_transparency_v2.gd`
- Modify: `tests/unit/test_v3_ui_sync.gd`
- Modify: `docs/contracts/2026-09-02-domain-ui-contract.md`
- Modify: `docs/contracts/2026-09-02-page-inventory-requirements.md`

**Interfaces:**
- Consumes: `controller.state.battle2_ledger`, rule projections `_v2_group1` through `_v2_group8`.
- Produces: `transparency_v2(controller)` with no injectable ledger/catalog arguments; all real `for_screen()` snapshots carry `group1_gu_ledger` through `group8_soul`.

- [ ] **Step 1: Rewrite tests to use the public snapshot path**

Remove calls that pass a test ledger into `transparency_v2`. Set `controller.state.battle2_ledger`, then call:

```gdscript
var snapshot := RunSnapshotBuilderScript.for_screen("Battle", controller)
for index in range(1, 9):
    assert_true(snapshot.has("group%d_%s" % [index, ["gu_ledger","core","recipes","feeding","market","body","action","soul"][index - 1]]))
assert_eq_deep(snapshot["group1_gu_ledger"]["gu_used"], controller.state.battle2_ledger["gu_used"])
```

Add one non-Battle screen assertion through `for_screen("Map", controller)` so the conservative all-screen merge is proven. Expected before implementation: FAIL because `for_screen()` does not merge the groups.

- [ ] **Step 2: Remove parallel truth injection and merge projections**

Change the signature to:

```gdscript
static func transparency_v2(controller) -> Dictionary:
```

Read `state.battle2_ledger` directly in group 1. An absent battle projects an empty inactive ledger shape; it must not fabricate a fresh full-capacity turn. Add a private merge helper and call it from every successful `for_screen()` branch:

```gdscript
static func _with_v2(snapshot: Dictionary, controller) -> Dictionary:
    var merged := snapshot.duplicate(true)
    merged.merge(transparency_v2(controller), true)
    return merged
```

Update both contract documents to name the no-argument source and real screen path.

- [ ] **Step 3: Verify real reachability**

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_snapshot_transparency_v2.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_v3_ui_sync.gd
rg -n "transparency_v2\([^)]*," scripts tests docs/contracts
```

Expected: tests PASS; `rg` returns no public call supplying a ledger or catalog.

- [ ] **Step 4: Commit**

```powershell
git add scripts/presentation/run_snapshot_builder.gd tests/unit/test_snapshot_transparency_v2.gd tests/unit/test_v3_ui_sync.gd docs/contracts/2026-09-02-domain-ui-contract.md docs/contracts/2026-09-02-page-inventory-requirements.md
git commit -m "fix(spec-v4): expose v2 transparency through screen snapshots"
```

---

## Twelve Legacy Families

For Tasks 5-16, first add the named guard to `tests/unit/test_legacy_abolition.gd`, run it red, run the task's inventory `rg`, delete only active legacy behavior and its obsolete tests/data/UI keys, run the guard green, then run `tools/test.ps1 -Suite all`. A full-suite failure caused by an obsolete test must be resolved by deleting or rewriting that test in the same family commit; never add a compatibility implementation of the abolished rule.

### Task 5: Family 1 - Gu Slot Hard Caps

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/domain/action_preview_service.gd`
- Modify: `docs/contracts/2026-09-02-domain-ui-contract.md`
- Delete active remnants found under: `scripts/`, `tests/`, `data/`

**Interfaces:** Consumes `FeedingRules.budget_report`; produces unlimited holding with feeding as the only soft pressure.

- [ ] Add `test_abolished_1_gu_slot_hard_cap_surface_is_gone`, guarding `deck_capacity`, `gu_slot_full`, slot-full replacement language, and any capacity rejection branch.
- [ ] Run `rg -n "deck_capacity|gu_slot_full|slot[_ ]?full|槽满|蛊槽" scripts data tests docs/contracts` and preserve only explicit abolition assertions or historical spec text outside live contracts.
- [ ] Remove Controller `_REJECTION_TEXT["gu_slot_full"]`, preview rejection branches and contract reasons; do not remove feeding budgets.
- [ ] Run focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-1 abolish gu slot hard caps"`.

### Task 6: Family 2 - Draw, Hand, Discard And Shuffle

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Delete: `scripts/domain/deck_builder.gd`
- Delete: `data/deck.json`
- Modify/Delete: `scripts/domain/battle_resolver.gd`, `scripts/presentation/run_snapshot_builder.gd`, `scripts/presentation/widgets/gu_battle_hand_view.gd`
- Delete/Rewrite: `tests/unit/test_v3_deck_builder.gd`, `tests/unit/test_hand_panel.gd`, draw-pile assertions in battle tests

**Interfaces:** Consumes `RunState.gu_instances` and Battle2 per-instance ledger; produces cards as instance-operation projections without availability piles.

- [ ] Add `test_abolished_2_draw_hand_discard_shuffle_are_gone`, guarding file existence plus live keys `draw_pile`, `discard_pile`, `hand`, `shuffle`, `draw_count`.
- [ ] Inventory with `rg -n "deck_builder|draw_pile|discard_pile|shuffle|draw_count|\bhand\b|\bpiles\b" scripts data tests docs/contracts`.
- [ ] Delete deck construction and pile mutation. Replace any surviving Battle snapshot `hand/piles` contract with `group1_gu_ledger` and instance actions; do not rename a pile to conceal it.
- [ ] Run focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-2 abolish draw pile combat"`.

### Task 7: Family 3 - Soul-Derived Operation Caps

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Delete: `scripts/domain/soul_capacity.gd`
- Delete: `tests/unit/test_soul_capacity.gd`
- Modify: `scripts/domain/run_state.gd`, `scripts/domain/resolver.gd`, `scripts/domain/action_preview_service.gd`, `scripts/playthrough_smoke.gd`
- Modify/Delete: tests still using `soul`, `soul_max`, `soul_control_limit` as operation/craft caps

**Interfaces:** Consumes `CultivatorRules.thought_capacity` and `SoulRules` five quantities; produces zero coupling between soul and per-turn/crafting operation count.

- [ ] Add `test_abolished_3_soul_operation_caps_are_gone`, guarding `soul_capacity.gd`, `ops_cap`, `craft_cap`, `soul_control_limit`, and legacy `soul_max` capacity logic.
- [ ] Inventory with `rg -n "SoulCapacity|soul_capacity|ops_cap|craft_cap|soul_control_limit|soul_max" scripts data tests docs/contracts`.
- [ ] Remove legacy fields from `RunState.new_run`, resolver/previews/debug controls and active tests. Preserve `soul_magnitude`, `soul_safe_capacity`, `soul_calm`, `soul_nature`, `beast_nature` and lethal prechecks.
- [ ] Run `test_soul_rules.gd`, `test_cultivator_rules.gd`, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-3 abolish soul operation caps"`.

### Task 8: Family 4 - Automatic Attribute Growth On Rank-Up

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `scripts/domain/resolver.gd`
- Modify: `scripts/domain/essence_capacity.gd`
- Modify: `tests/unit/test_resolver_ascension.gd`, `tests/unit/test_cultivator_rules.gd`

**Interfaces:** Consumes explicit paid upgrades only; produces rank/cultivation changes that do not automatically change health, body, speed, thought, aptitude or aperture length.

- [ ] Add `test_abolished_4_rank_up_does_not_auto_grow_attributes`. Through `Resolver.apply()` capture health/max health/body capacity/speed/thought/aptitude/essence maximum before `cultivate_rank_two`, then assert all remain equal after.
- [ ] Inventory with `rg -n "cultivate_rank_two|cultivation.*2|next_capacity|max_health|body_capacity|thought_capacity|speed|aptitude" scripts/domain tests/unit`.
- [ ] Remove only automatic rank-linked assignments. Keep explicit `raise_aptitude`, sourced body changes and catalog-driven starting values.
- [ ] Run the guard, resolver ascension/cultivator tests and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-4 abolish automatic rank growth"`.

### Task 9: Family 5 - Essence Action Points

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Delete: `scripts/domain/action_points.gd`
- Modify/Delete: `scripts/domain/essence_capacity.gd`, `scripts/domain/relic_hook_resolver.gd`, `scripts/presentation/run_snapshot_builder.gd`
- Delete/Rewrite: `tests/unit/test_per_turn_renewal.gd`, `tests/unit/test_opening_fairness.gd`, action-point sections in relic/battle tests

**Interfaces:** Consumes persistent cave-aperture essence percentage and `GuBalance.actual_cost_percent/natural_recovery`; produces no `actions_left/actions_max/no_actions_left` resource.

- [ ] Add `test_abolished_5_essence_action_points_are_gone`, guarding `action_points.gd`, `actions_left`, `actions_max`, `no_actions_left`, and soul-to-action calculations.
- [ ] Inventory with `rg -n "ActionPoints|action_points|actions_left|actions_max|no_actions_left|actions_per_turn" scripts data tests docs/contracts`.
- [ ] Delete reset/relic/UI paths. Preserve persistent essence, its configured natural recovery and thought spending.
- [ ] Run `test_gu_balance_schema.gd`, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-5 abolish essence action points"`.

### Task 10: Family 6 - Continuous Time And V1 Battle Authority

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Audit first; delete only after the replacement gate passes: `scripts/domain/v1_battle_resolver.gd`, `scripts/domain/battle_command_facade.gd`, `data/v1_battle.json`
- Modify/Delete: `scripts/domain/battle_resolver.gd`, `scripts/presentation/run_controller.gd`, `scripts/presentation/run_snapshot_builder.gd`, obsolete V1 battle tests
- Modify: `data/nodes.json` only where `time_scale` drives combat timing rather than world/pacing description

**Interfaces:** Consumes Task 3 Battle2 ledger commands and Task 4 snapshots; deletes the old production authority only if an already-existing discrete-turn production owner covers the complete battle lifecycle. This task must not implement missing combat rules.

- [ ] **Run the replacement-capability preflight before writing an abolition guard.** Trace production calls from `RunController.submit_command()` and `_begin_battle()` through `Resolver.apply()`, then identify a non-V1 owner and focused test for every row below:

| Required production transition | Evidence required before deletion |
| --- | --- |
| Battle start | Seeded enemy collection and disclosed intents enter serialized authoritative state through an appended event |
| Player action | A real Controller command applies damage/status to a selected enemy and records immutable before/after data |
| Enemy action | Intent advancement applies health/soul/lifespan/status consequences to `RunState` and records the source |
| Termination | Victory, death and retreat each finish once, with exact outcome and death cause where applicable |
| Victory settlement | The production victory path invokes survivor/material/information loot settlement exactly once |
| Persistence | Save/load during battle restores enemies, intents, ledger and pending consequences without `current_battle` |

Run:

```powershell
rg -n "current_battle|V1Battle|BattleCommandFacade|enemies|intent|victory|death|retreat|settle_victory|battle2_ledger" scripts/domain scripts/presentation tests/unit tests/integration
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_battle2_lifecycle.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/unit/test_combat_node_fight.gd
```

The gate passes only when all six rows have a production owner outside `v1_battle_resolver.gd`, `battle_command_facade.gd`, `battle_resolver.gd` continuous-time compatibility paths and presentation-only `current_battle`. A pure `battle2/action_resolver.gd` formula without command/state/event wiring is not replacement evidence.

- [ ] **Use the mandatory blocker branch when the preflight fails.** Record each missing row, the surviving owner and the proving file/line in the implementation handoff under `BLOCKED: Task 10 / Family 6`. Do not add the abolition guard, delete V1/facade/data files, create compatibility state, or commit `T10.1-6`. Continue only the independent Family 7-12 cleanups in Tasks 11-16; do not execute Tasks 17-20 or make a full-suite completion claim because their contract, vertical-flow and terminal gates require Family 6. Return completed commit hashes for partial review.
- [ ] **Only if the preflight passes, add the red abolition guard.** Add `test_abolished_6_continuous_time_and_v1_battle_are_gone`, guarding the V1 files, `BattleCommandFacade`, speed multiplier/completion timestamp/decimal progress/global sort symbols. Explicitly assert the guard does not reject `duration_turns`. Run it and require a failure naming a real surviving legacy symbol or file.
- [ ] Inventory the deletion surface with `rg -n "V1Battle|BattleCommandFacade|time_scale|speed_multiplier|completion_time|action_progress|timeline|sort.*speed" scripts data tests docs/contracts`. Delete only the authority proven replaceable by the six-row gate; remove Controller/facade calls and obsolete tests. Keep integer `duration_turns`, recipe stage turns and world/pacing descriptions that do not drive combat timing.
- [ ] Extend `test_battle2_lifecycle.gd` and Controller combat coverage so entry, player action, enemy action, new turn, save/load, victory loot, retreat and death use only `controller.submit_command()`/`Resolver.apply()` and serialized authoritative state. Assert no flow depends on `current_battle` after `_restore_game()` clears it.
- [ ] Run all Battle2 unit files, Controller combat tests, the focused abolition guard and `-Suite all`; expected PASS with no V1 script preload and nonzero test counts.
- [ ] Commit only after every gate passes: `git commit -m "feat(spec-v4): T10.1-6 abolish continuous-time V1 battle"`.

### Task 11: Family 7 - Body Parts And Structural Injury

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify/Delete: active hits in `scripts/domain/`, `scripts/presentation/`, `data/`, `tests/`

**Interfaces:** Consumes unified cultivator health and Battle2 body capacity; produces no body-part HP or generic structural injury model.

- [ ] Add `test_abolished_7_body_parts_and_structural_injury_are_gone`, guarding `body_parts`, `body_part`, `limb_hp`, `torso_hp`, `structural_injury`, `heavy_injury` in live code/data/contracts.
- [ ] Inventory with `rg -n "body_parts?|limb_hp|torso_hp|structural_injury|heavy_injury|部位血量|结构伤势|通用身体重伤" scripts data tests docs/contracts`.
- [ ] Delete active legacy shape while preserving unified `health/max_health`, `body_capacity`, strength overload and explicit status effects.
- [ ] Run `test_battle2_dodge_grapple_overload.gd`, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-7 abolish body-part injury"`.

### Task 12: Family 8 - Random Refinement, Ingredient Swallowing And Survivor Trimming

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `data/refinement_recipes.json`
- Modify: `scripts/domain/resolver.gd`, `scripts/domain/loot_rules.gd`, `scripts/domain/content_catalog.gd`, `scripts/domain/action_preview_service.gd`, `scripts/domain/v2_commands.gd`
- Modify: `tests/unit/test_loot_rules.gd`, `tests/unit/test_v2_economy_resolver.gd`
- Delete/Rewrite: random-refinement tests in `tests/unit/test_seeded_roll.gd`

**Interfaces:** Consumes `RecipeRules.known_fixed_success`, `LootRules.collect_surviving_gu`, single Resolver `destroy_gu`; produces deterministic known refinement and untrimmed survivors.

- [ ] Expand `test_abolished_8_random_refine_and_dual_destroy_are_converged` to guard `success_roll_max`, `_refinement_roll`, random failure/ingredient loss branches, survivor budget trimming, and a second command-level `destroy_gu` handler. `LootRules.destroy_gu` is the rule function and must not be counted as a duplicate command handler.
- [ ] Add Resolver-path tests proving both declaration cases. For a gu whose definition has `death_drops: {"beast_bone": 2}`, submit `destroy_gu` and assert the instance becomes dead, aperture ownership is removed, `materials.beast_bone` increases by `2`, and one `destroy_gu` event contains all three changes in its `after`. Repeat with no `death_drops` and assert materials are unchanged. Keep the existing cursed/direct-drop rejection test and assert it does not extract materials.
- [ ] Inventory with `rg -n "success_roll_max|_refinement_roll|refine.*roll|ingredient.*loss|trim.*surviv|func (_)?destroy_gu|death_drops|extracted" scripts data tests docs/contracts`.
- [ ] Remove `bright_thread_risk.success_roll_max`, catalog override, preview probability and resolver RNG path. Route known recipes through fixed success; ensure unknown/interrupted rejection consumes nothing. Delete the unregistered parallel handler in `v2_commands.gd`.
- [ ] Keep `Resolver._destroy_gu` as the only command handler. After curse/ownership preflight, call `LootRules.destroy_gu(existing, method, means, catalog)`, merge its returned `extracted` quantities into a copied `state.materials`, and use one `append_event()` whose `after` includes `gu_instances`, `cave_aperture`, and `materials`. Do not hard-code a refund or assign a second post-event state. A gu without declared `death_drops` yields no material.
- [ ] Run recipe/loot/removal tests, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-8 abolish random refinement and trimming"`.

### Task 13: Family 9 - Automatic Equivalent Substitution And Fixed Destroy Refunds

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `scripts/domain/resolver.gd`, `scripts/domain/recipe_rules.gd`, `scripts/domain/loot_rules.gd`
- Modify: `data/refinement_recipes.json`, `data/gu.json` only to remove undeclared fallback fields

**Interfaces:** Consumes `RecipeRules.check_identity` and declaration-only `LootRules.destroy_gu`; produces no yuanstone/equal-value identity bypass and no undeclared refund.

- [ ] Add `test_abolished_9_auto_substitution_and_fixed_destroy_refund_are_gone`, including behavioral assertions: equal-value wrong material and yuanstone both reject; a gu without extraction declaration yields nothing.
- [ ] Inventory with `rg -n "equivalent.*substitut|stone.*substitut|fixed.*refund|return_material|destroy.*refund|extract" scripts data tests docs/contracts`.
- [ ] Remove fallback branches only. Preserve explicit `allow_substitute` relations and declared extraction products.
- [ ] Run `test_recipe_rules.gd`, `test_loot_rules.gd`, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-9 abolish automatic substitution refunds"`.

### Task 14: Family 10 - Fixed Loot Bundles And Sourceless Permanent Modification

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `scripts/domain/resolver.gd`, `scripts/domain/content_catalog.gd`, `scripts/domain/loot_resolver.gd`
- Modify: `data/loot_tables.json`
- Delete/Rewrite: fixed boss-loot assertions in `tests/unit/test_loot_tables.gd`

**Interfaces:** Consumes `LootRules.budget_profile(enemy_composition, scene, catalog)` for generation only; produces no fixed ordinary/elite/boss bundle read during settlement.

- [ ] Add `test_abolished_10_fixed_loot_and_sourceless_modification_are_gone`, guarding resolver reads of `loot.boss`, tier fixed bundle fields and abstract permanent-modification services without a world source.
- [ ] Inventory with `rg -n "loot.*boss|boss.*loot|fixed.*loot|permanent.*modif|abstract.*upgrade" scripts data tests docs/contracts` and inspect known resolver reads near former lines 2271/2292.
- [ ] Remove fixed bundle settlement. Keep budget profile only at seeded content generation; survivor collection never accepts a loot budget.
- [ ] Run loot tests, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-10 abolish fixed loot bundles"`.

### Task 15: Family 11 - Closed Five-Dao Enumeration

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify: `scripts/domain/content_catalog.gd`
- Modify: `tests/unit/test_content_catalog.gd`, `tests/unit/test_school_starter_data.gd`

**Interfaces:** Consumes arbitrary nonempty dao-tag strings; produces open tag validation while preserving separately configured starter schools.

- [ ] Add `test_abolished_11_dao_tags_are_open`, injecting a gu with `dao_tags:["time"]` and asserting `ContentCatalog.validate()` does not reject the tag merely because it is absent from `schools.json`.
- [ ] Inventory with `rg -n "five_schools|allowed_schools|school_id.*missing|dao_tags|schools missing" scripts data tests docs/contracts`.
- [ ] Remove closed-enum assumptions from gu/recipe tag validation. Do not delete `schools.json`, Hall school selection or checks that configured starter schools reference real content.
- [ ] Run catalog/school tests, focused guard and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-11 open dao tag vocabulary"`.

### Task 16: Family 12 - Mandatory Generic Heavy Kill-Move Cost

**Files:**
- Modify: `tests/unit/test_legacy_abolition.gd`
- Modify/Delete only where the inventory finds a surviving generic penalty: `scripts/domain/battle_resolver.gd`, `scripts/domain/v1_battle_resolver.gd`, `scripts/domain/content_catalog.gd`
- Modify only where the inventory finds a surviving generic penalty: `data/cards.json`, `data/v1_battle.json`
- Delete/Rewrite: generic kill-move-cost assertions

**Interfaces:** Consumes explicit component-gu and named move cost declarations; produces no cost added solely because an action is a kill move.

- [ ] Add `test_abolished_12_kill_moves_have_no_automatic_heavy_cost`, proving a named move with no declared extra cost pays only its component activations.
- [ ] Inventory with `rg -n "kill_move|heavy_cost|mandatory.*cost|fixed.*cost|play_kill_move" scripts data tests docs/contracts`.
- [ ] Modify whichever live files the inventory identifies; do not assume Task 10 deleted V1 files. Remove only a generic auto-added penalty. Preserve explicit lifespan/soul/taboo costs declared by a specific move and their lethal confirmation.
- [ ] Run focused guard, Battle2 action tests and full suite; expected PASS.
- [ ] Commit: `git commit -m "feat(spec-v4): T10.1-12 abolish generic kill-move penalty"`.

---

### Task 17: Converge Commands, Rejections And The Three Contracts

**Files:**
- Modify: `scripts/presentation/run_controller.gd`
- Modify: `scripts/domain/command_spec_registry.gd`
- Modify: `scripts/presentation/run_command_builder.gd`
- Modify: `docs/contracts/2026-09-02-domain-ui-contract.md`
- Modify: `docs/contracts/2026-09-02-frontend-global-constraints.md`
- Modify: `docs/contracts/2026-09-02-page-inventory-requirements.md`
- Modify: `AGENTS.md` only where live wording still declares an abolished model
- Modify: `tests/unit/test_command_contract.gd`

**Interfaces:** Consumes final command/snapshot surface from Tasks 2-16; produces exact live contract with no T9/T10 placeholders or retired reasons.

- [ ] Add contract guards asserting the documents contain `start_battle2_turn`, `finish_battle2`, `battle2_not_started`, eight real snapshot groups, and contain none of `deck_capacity`, `gu_slot_full`, `hand`, `piles`, V1 passthrough or `[T9`/`[T10` markers.
- [ ] Inventory with `rg -n "\[T9|\[T10|待废|deck_capacity|gu_slot_full|hand|piles|V1|no_actions_left" AGENTS.md docs/contracts scripts/presentation scripts/domain/command_spec_registry.gd`.
- [ ] Update `_REJECTION_TEXT` with a player-readable `battle2_not_started` message and remove retired reasons. Synchronize command builders/registry and all three contracts. Keep `AGENTS.md` normative and free of implementation history.
- [ ] Run `test_command_contract.gd`, snapshot tests and full suite; expected PASS.
- [ ] Commit: `git commit -m "docs(contracts): align phase 10 terminal surface"`.

---

### Task 18: Rebuild The Eighteen-Rule Acceptance Matrix

**Files:**
- Modify: `tests/integration/test_spec_v4_acceptance.gd`

**Interfaces:** Consumes real `Resolver.apply()` command paths and production rules; produces 18 named rule/integration acceptance tests, not labeled end-to-end.

- [ ] Rename/comment the file as an acceptance matrix. Preserve exactly one test per specification §17.4 item, named `test_acceptance_01_...` through `test_acceptance_18_...`.
- [ ] Replace direct pure-module success assertions with `Resolver.apply()` wherever a production command exists: core confirm/replace, enact, feeding, refinement, survivor collection, information sale and layer settlement. Pure module calls are permitted only for formulas with no command surface, and the test comment must name that boundary.
- [ ] Add an index at the top mapping each number to the exact spec sentence and tested command/module. Assertions must cover state, result and the expected immutable event for every state-changing item.
- [ ] Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_spec_v4_acceptance.gd
```

Expected: 18 tests executed, 18 passing, zero pending/risky/ignored scripts.

- [ ] Commit:

```powershell
git add tests/integration/test_spec_v4_acceptance.gd
git commit -m "test(spec-v4): verify the eighteen-rule acceptance matrix"
```

---

### Task 19: Add A Real Controller Vertical Flow

**Files:**
- Create: `tests/integration/test_spec_v4_vertical_flow.gd`
- Modify: `scripts/presentation/run_controller.gd` only if the test exposes a missing production connection already required above

**Interfaces:** Consumes `RunController.submit_command()`, `_snapshot_for()`, `SaveRepository.serialize_run/load_run_from_data`; produces one deterministic continuous handoff test.

- [ ] **Dependency gate:** execute this task only if Task 10 / Family 6 passed its six-row production replacement gate and committed successfully. If Task 10 is blocked, do not fabricate enemies, intents, victory or loot in the test; stop before Task 19 and report the same blocker.
- [ ] Build a deterministic fixture with real catalog and Controller, then execute this sequence without direct rule-module calls: start run -> enter an active encounter node (`current_node` remains nonempty) -> verify ledger/enemies/intents created -> `enact` -> resolve player and enemy consequences -> save/load -> continue through the restored Controller -> `start_battle2_turn` with `continue_ids` -> read real Battle snapshot -> reach a real battle outcome and loot settlement -> feed -> refine -> trade/sell info -> confirm/replace core -> settle next layer.
- [ ] State setup needed to reach a gate may use a fixture builder before the first command, but after the flow starts every state transition must pass through `controller.submit_command()` or a save/load API. Never assign `controller.state` fields between asserted commands.
- [ ] Assert Battle2 commands still reach `Resolver.apply()` while the encounter node is active; they must not be swallowed by `EncounterSessionResolver`. After save/load, continue solely from serialized authoritative state: `_restore_game()` clears `current_battle`, so the test must neither repopulate it nor depend on it.
- [ ] Assert after each command: `result.ok`, expected event action, state version increments exactly once where applicable, no resource appears without a source, and prior `RunState` objects remain unchanged.
- [ ] Include these regression assertions:

```gdscript
assert_false(controller.state.battle2_ledger.is_empty())
assert_eq_deep(restored.battle2_ledger, saved_ledger)
assert_eq_deep(controller._snapshot_for("Battle")["group1_gu_ledger"]["gu_used"], controller.state.battle2_ledger["gu_used"])
for key in ["group1_gu_ledger", "group2_core", "group3_recipes", "group4_feeding", "group5_market", "group6_body", "group7_action", "group8_soul"]:
    assert_true(controller._snapshot_for("Battle").has(key))
```

- [ ] Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_spec_v4_vertical_flow.gd
```

Expected: target file is reported, at least one continuous-flow test executes and passes, no parse/ignore/zero-test diagnostics.

- [ ] Commit:

```powershell
git add tests/integration/test_spec_v4_vertical_flow.gd scripts/presentation/run_controller.gd
git commit -m "test(spec-v4): verify phase 10 through a real vertical flow"
```

---

### Task 20: Lower Terminal Gates And Produce Review Evidence

**Files:**
- Modify: `tests/unit/test_resolver_growth_gate.gd`
- Create: `docs/superpowers/reports/2026-09-02-phase10-review-remediation-report.md`

**Interfaces:** Consumes all prior commits and verification output; produces one-way lower line caps and a fixed-range review report.

- [ ] Record exact line counts:

```powershell
(Get-Content scripts/domain/resolver.gd).Count
if (Test-Path scripts/domain/battle_resolver.gd) { (Get-Content scripts/domain/battle_resolver.gd).Count } else { 'deleted' }
```

Set `RESOLVER_LINE_CAP` to the exact final count if lower than its current cap. Set `BATTLE_RESOLVER_LINE_CAP` likewise if the file remains; if deleted, replace its line-cap assertion with a file-absence assertion. Caps may only decrease.

- [ ] Create the report with these mandatory sections: `Review Range`, `Commit Ledger`, `Findings Remediated`, `Battle2 Ownership`, `Twelve Families`, `Eighteen Acceptance Results`, `Vertical Flow`, `Line Gates`, `Contract Diff`, `Verification`, `Remaining Risks`.

The first section must contain:

```markdown
- Review base: `cc6635d0a49e53079d30939f790023b4001cabd3`
- Implementation base: `<recorded opening SHA>`
- Final SHA: `<git rev-parse HEAD after the report commit>`
```

For each family list `removed symbols/files -> red guard name -> replacement authority -> commit hash`. For each of the 18 items list test name and PASS. Include the actual executed test counts, not only process exit codes.

- [ ] Run terminal verification in this order:

```powershell
powershell -ExecutionPolicy Bypass -File tools/tests/test_run_gut_checked.ps1
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_spec_v4_acceptance.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Test tests/integration/test_spec_v4_vertical_flow.gd
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all
powershell -ExecutionPolicy Bypass -File tools/check.ps1
powershell -ExecutionPolicy Bypass -File tools/crash_recovery_check.ps1
git diff --check cc6635d0a49e53079d30939f790023b4001cabd3...HEAD
git diff --stat cc6635d0a49e53079d30939f790023b4001cabd3...HEAD
rg -n "<<<<<<<|=======|>>>>>>>" . --glob '!addons/**' --glob '!vendor/**'
```

Expected: every command exits `0`; acceptance reports exactly 18 passing tests; vertical flow executes; full suite reports nonzero unit and integration counts with no parse/ignore/zero-test diagnostics; conflict-marker search returns no source conflict markers. Record any unrelated pre-existing risky/pending result separately and prove it predates the implementation base.

- [ ] Review the final diff and commit:

```powershell
git status --short --branch
git diff --check
git add tests/unit/test_resolver_growth_gate.gd docs/superpowers/reports/2026-09-02-phase10-review-remediation-report.md
git commit -m "chore(spec-v4): close phase 10 remediation gate"
git rev-parse HEAD
git log --oneline --reverse cc6635d0a49e53079d30939f790023b4001cabd3..HEAD
```

Update the report's `Final SHA` after the commit by amending only the report:

```powershell
git add docs/superpowers/reports/2026-09-02-phase10-review-remediation-report.md
git commit --amend --no-edit
git rev-parse HEAD
```

Because amending changes the SHA again, the report must identify the final commit using the literal marker `self (report commit)` and the handoff message must provide the authoritative final SHA from the last command. Do not repeatedly amend in pursuit of embedding a self-referential hash.

## Handoff To Reviewer

The implementation agent's final message must include:

1. `IMPLEMENTATION_BASE` and authoritative final SHA.
2. Ordered commit hashes and subjects for Tasks 1-20; explicitly mark any task blocked or intentionally empty.
3. Link to `docs/superpowers/reports/2026-09-02-phase10-review-remediation-report.md`.
4. Exact test counts for strict-runner self-test, 18-rule matrix, vertical flow, full unit and full integration suites.
5. Confirmation that no command reported `Parse Error`, `Ignoring script`, `Nothing was run`, or `SCRIPT ERROR`.
6. Remaining risks and any repository changes not authored by the implementation agent.

The reviewer will inspect the fixed range `cc6635d0a49e53079d30939f790023b4001cabd3...<final SHA>` and will treat missing hashes, skipped families, module-only claims labeled E2E, or exit-code-only test evidence as incomplete delivery.
