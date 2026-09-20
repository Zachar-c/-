# FIX · SIDE-FIX 收尾：契约测试口径 + 焚元守卫自洽

```text
WORKFLOW ROLE
L3 Worker（返工）

UPSTREAM
L2 Orchestrator（Review: FIX REQUIRED）

DOWNSTREAM
L2 Review → 提交

PROJECT GOAL
把《蛊真人》做成游戏。当前阶段 Godot = Canonical（RUL-2026-09-19-010）。

CURRENT PHASE
SIDE-FIX（敌人运行时补线）已交付并**通过 L2 独立复算**
（L2 亲自跑：phases 8/8 31 asserts、contract 7/7 31 asserts、
全量 unit 221 scripts / 1619 tests / 54126 asserts 全过、drift 0、accept 64635/0）。
本任务是收尾两处小问题，**不重做已通过的部分**。

TASK PURPOSE
本任务要消灭的病是「数据声明了但没人消费」。你的契约测试正是为它而生，
但其中有一条**恰好把一处真缺口记成了已覆盖**——那会让这个测试在最该生效的地方失效。
另一处是代码与注释不一致，同属潜在静默丢弃。

TASK

## A. `phases[].reactions` 必须诚实登记为未接线（不要记成已覆盖）

现状：`test_enemy_data_runtime_contract.gd` 的 `COVERAGE` 表把 `phase.reactions` 的消费点写成
`enemy_catalog._validate_phases schema (structural container)`。

**那是形状校验器，不是运行时消费点。** L2 已全仓复核（`grep -n reactions game/scripts/**/*.gd`）：
运行时每一次读取反击都走**顶层** `enemy.get("reactions", ...)` 或
`enemy.get("counter_revealed", ...)`（`action_preview_service.gd:338`、`:1056`；
`death_report_builder.gd:21`）。**`phases[i].reactions` 零读取。**

本轮接线只接通了 `phases[].intents` 这一半。

**要做**：把 `phase.reactions` 从 `COVERAGE` 移到豁免表，原因必须写明真实情况，包含这三点：
1. 运行时只读顶层 `reactions`，每阶段反应表未接线；
2. **当前是潜在缺口而非在爆 bug**——实测 5 个带 `phases` 的 Boss
   （`miasma_vein_lord` / `thunder_crown_sovereign` / `blood_vein_bishop` / `clan_patriarch` /
   `blue_fur_jiangshi`），**每个阶段的反应表都与顶层逐字相同**，故行为上暂无差异；
3. 接线前要先裁「阶段反应表是**替换**还是**追加**顶层表」——数据没写，属设计裁决，**不得自行决定**。

**不要**顺手把它接上（见 DO NOT）。

## B. 焚元守卫与注释必须自洽

现状（`v1_battle_resolver.gd`，`match kind:` 的 `"attack"` 分支内）：

```gdscript
# SIDE-FIX（2026-09-19）：焚元结算——意图实际发出即扣玩家真元，下限 0，
# 独立于伤害（格挡/减免不吞焚元；sealed 门禁吞掉意图时不触发）。
var burn := int(intent.get("essence_burn", 0))
if is_damage_intent and burn > 0:
```

注释说「意图实际发出即扣」，代码却要求 `is_damage_intent`，且整段位于 `"attack"` 分支内。
后果：一个 `kind` 非 `attack` 的意图即使声明了 `essence_burn` 会被**静默丢弃**——
正是本任务要消灭的那类病。（当前数据无此情形：唯一带 `essence_burn` 的
`paralyzing_howl` 没有 `kind` 字段，缺省按 `attack` 处理，故现在是潜在缺口。）

**要做**：二选一，让代码与注释一致，**并用测试钉住你选的那一种**：

- **（推荐）**把焚元结算移出 `"attack"` 分支，放到「意图确实执行」的位置
  （**仍在 sealed 门禁之后**——被 sealed 吞掉的意图不焚元），使其对任何 kind 生效；
  补一条合成夹具（`kind: "seal"` + `essence_burn: 2`）证明它确实扣。
- 或保留 `is_damage_intent` 守卫，把注释改成与之一致（写清「仅伤害意图焚元」），
  补一条测试钉死「非伤害意图不焚元」。

两条都可接受。**关键是代码、注释、测试三者一致**，且不得改变已通过的现有行为
（`paralyzing_howl` 仍必须焚元 2）。

## C. 更正结果包里的一个数字

`ai-system/tasks/side-fix-enemy-runtime-result.md` 的 EVIDENCE 行写
`drift exit 0 (204 items, 0 drift)`。L2 实测该工具输出为 **检查项：5204｜漂移项：0**
（少了一位）。结论（0 漂移、退出码 0）是对的，数字请你改成实测值。

SCOPE
可写：
- `game/tests/unit/test_enemy_data_runtime_contract.gd`
- `game/tests/unit/test_enemy_phases_runtime.gd`（若 B 新增用例放这里更合适）
- `game/scripts/domain/v1_battle_resolver.gd`（**仅**焚元结算的位置/守卫）
- `ai-system/tasks/side-fix-enemy-runtime-result.md`（更正 drifts 数字）

只读：其余一切。

DO NOT
- **禁止把 `phases[].reactions` 真正接上**——「替换还是追加」是设计裁决，先上抛。
- **禁止改动本轮已通过的任何行为**：阶段选择、冷却门禁 `T+n+1`、`cooldown_wait`、
  `phase_shift`、facade 透传、`test_battle_command_facade.gd` 的夹具更新，**一律不动**。
- 禁止改 `game/data/**` 任何值；禁止改平衡数值；禁止改 `game/wenzhen-web-lab/**`。
- 禁止发明 `sparked` 语义。
- 禁止 commit / push / merge / stash / reset；禁止新增依赖；禁止 `--no-verify`。

DECISION AUTHORITY
可自行决定：B 里二选一、事件记录的文案、新用例放哪个文件。
**不可自行决定**：`phase.reactions` 的接线语义（替换/追加）。

ESCALATE WHEN
- 你发现 `phase.reactions` 其实**有**运行时消费点（若如此，附证据，本包前提作废）
- 让代码与注释自洽会导致本轮已通过的用例失败

DELIVERABLE
1. `phase.reactions` 移入豁免表 + 三点原因
2. 焚元守卫/注释/测试三者自洽（含新增用例）
3. 结果包的 drift 数字更正
4. 追加到结果包（或新建 `-fix` 结果包）的复跑证据

ACCEPTANCE
- `res://tests/unit/test_enemy_data_runtime_contract.gd` 全绿（凭 **GUT 文本**，不看退出码）
- `res://tests/unit/test_enemy_phases_runtime.gd` 全绿，且**用例数 ≥9**（新增至少 1 条）
- **契约测试的负控仍有效**：临时删掉 `v1_battle_resolver.gd` 里的 `essence_burn` 字样 →
  `test_consumption_markers_exist_in_sources` 必须变红（附输出片段）
- `git status` 证明 `game/data/**` 与 `game/wenzhen-web-lab/**` 零改动
- **必须用 console 版 Godot**：`game/tools/godot.ps1 -Console`
  （注意：本机 `GODOT_PATH` 仍指向**非 console** 版 `Godot_v4.7.2-stable_win64.exe`，
  直接用 `test.ps1` 会静默假绿——L2 实测确认）
- 结果包写入 `ai-system/tasks/side-fix-enemy-runtime-result.md`（追加一节）

STATUS TARGET
READY_FOR_FIX_REVIEW
```

## L2 已完成的独立复算（不必重做）

| 项 | Worker 报 | L2 实测 | 结论 |
|---|---|---|---|
| phases 用例 | 8/8, 31 asserts | 8/8, 31 asserts | 一致 |
| contract 用例 | 7/7, 31 asserts | 7/7, 31 asserts | 一致 |
| 全量 unit | 221 / 1619 / 54126 全过 | **221 / 1619 / 54126 全过**（142.06s） | 一致 |
| accept | 64635 checks / 0 fail, exit 0 | validation-report 64635/0 | 一致 |
| drift | exit 0（**204** items） | exit 0，**5204** items | 结论对，数字错 → 见 C |
| `game/data` 零改动 | 是 | `git status` 证实 | 一致 |
| web-lab 未动 | 是 | 无文件在 23:35 后被改（该目录未被 git 跟踪，故只能按 mtime 判） | 一致 |

## GIT（执行前必读）

工作树当前有**本轮 SIDE-FIX 的未提交改动**（`v1_battle_resolver.gd`、`battle_command_facade.gd`、
三个测试文件），以及若干已存在的未提交文档（`game/AGENTS.md`、`RUL-2026-09-19-010/011.json` 等）。
**这些都是预期的，不要动它们，也不要清理。** 只改本包 SCOPE 列出的文件。

## Execution rules

- Worker class: `normal`。
- 改 `game/` 下任何文件前先 `python game/world-model/tools/snapshot.py take side-fix-fix`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet。
