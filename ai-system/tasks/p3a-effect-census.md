# P3-A · Effect 预算普查 + P2.1 follow-up（不依赖 L1 裁定的准备批）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → P3-B（依 L1 裁定改分配系数）

PROJECT GOAL
把《蛊真人》做成游戏。经 L1 架构裁决（RUL-2026-09-19-008），1–5 转是「综合层级轴」，
Rank Power Budget = 40/80/160/320/640（每转 ×2、1→5 共 ×16），且**不同轴不共用同一倍率**。

CURRENT PHASE
P1（转数语义）、P2（Rank Power Budget 唯一真源）、P2.1（runtime HP 接线）已完成。
P3（统一 Effect 管线）为 L1 标记的**最高优先**项。

TASK PURPOSE
P3 的**数值分配公式**（Effect Budget → 各原型各维度的换算）是设计裁决，L2 已上抛 L1
（`ai-system/RESEARCH-REQUEST-2026-09-19-p3-effect-budget.md`），**未回复前不得实施**。
但 P3 有一批「不需要任何数值判断」的准备工作，本任务就是把它做掉：
**把现状如实摆出来，让 L1 的裁定有据可依。**

TASK

## A. Effect 预算普查器 + 报告（只读，**零数值改动**）

产出一个可复用的只读分析器与一份报告，供 L1 裁定使用。

**A1. 新脚本** `game/world-model/tools/audit_effect_budget.py`
**A2. 报告** `game/world-model/reports/effect-budget-census.md`

报告必须包含以下五节（数字全部从上游数据实算，不得硬编码）：

**① 兜底曲线 vs 预算曲线**
741 只蛊走的是 `game/data/v1_battle.json` 的 `default_effect_by_role` 六条。
请把每条的实际曲线与 `Rank Power Budget`（40/80/160/320/640）并列，标出倍数差距。
已知（L2 已算，请复核而非抄写）：
```
attack   strike  r1..r5 = 2,3,4,5,6   (r5/r1 = 3.0x)
defense  shield  r1..r5 = 3,4,5,6,7   (2.3x)
healing  heal    r1..r5 = 2,3,4,5,6   (3.0x)
logistics heal   r1..r5 = 1,2,3,4,5   (5.0x)
movement shift   r1..r5 = 1,1,1,1,1   (1.0x, 不随转放大)
recon    status  r1..r5 = 1,1,1,1,1   (1.0x, 不随转放大)
Rank Power Budget                     (16.0x)
```
并说明 `v1_battle_resolver.gd` 里 `RANK_SCALED_KINDS = ["strike","shield","heal"]` 的
放大口径：`amount = 基准 + (rank-1)`，`support_bonus` 同法；`shift`/`status` **不缩放**。

**② 手写覆盖矩阵**
61 只显式 `v1_effect` 按 `(role, kind) × rank` 的分布矩阵 + 每格 `amount` 的 min/max/计数。
已知（请复核）：三转共 180 只蛊，仅 10 只手写，其中 `strike` 仅 1 只（`water_atk_3_05_gu`, amount=2）。

**③ 倒挂候选扫描（D7 口径，但判据待 L1 定）**
按 `(role, kind)` 分组，比较各转的 `amount` 上限，列出「高转低于低转」的候选。
**关键**：D7 要求「**同定位、同代价结构**」，所以你必须再按代价字段分组重算一遍：
`value` / `essence_cost` / `true_qi_cost` / `feeding_cost`（注意：部分蛊缺 `essence_cost` 等字段，
缺失情况要如实统计，不要静默当成 0）。
两条口径的结果**分别列出**，并注明哪些候选只在一种口径下成立——
L1 要据此判定「同代价结构」的可执行口径。

**④ 字段面清单**
61 只用到哪些 `v1_effect` 字段（L2 实测：kind 61、amount 61、support_school 7、support_bonus 7、
name 2、condition 1、heal 1、aoe 1、delay 1、consume_status 1）。
逐字段给出使用它的蛊 id 列表与取值样例，并标注**哪些字段是「不随转放大的维度」**
（如 `aoe` / `delay` / `condition` / `consume_status`）——L1 要用它决定「不随转的维度怎么成长」。

**⑤ 豁免路径清点**
列出绕过 1–5 转语义的机制蛊及其豁免方式。
已知一例，请核实并补全：`test_slay_gu`（rank 10 / strike 999 / `aoe: true` /
`tags: test` / `low_rank_exception: true`），经 `content_catalog.gd` 的 `low_rank_exception`
豁免上界，`v1_grammar_pipeline.gd` 里 `aoe == true` 等价于 `selector: "enemy_all"`。

> 普查器请写成**可复用**的（L1 给出判据后，L2 要把它升级成 `CONSTRAINTS-V2` R5 要求的可执行断言）。
> 但**本次不要**把它写成「通过/失败」的断言——判据未定，先只输出事实。

## B. P2.1 三个 follow-up（L2 Review 提出，与原任务同源）

见 `ai-system/tasks/wire-runtime-hp-source-l2-review.md` §4：

- **F1**：在 `game/tests/unit/test_world_model_bridge.gd` 的新开气血用例里，
  加一条把回退常量与配置绑死的断言：`RunState.START_HP_FALLBACK == GuBalance.player_start_hp(catalog)`。
  理由：两者现在同为 100，一旦配置改成别的值，**不经 `apply_start_hp` 的路径会静默拿 100**
  （`game/tools/` 下 5 个工具脚本 + 存档载入路径），而现有用例是直调 `apply_start_hp` 的，抓不到。
- **F2**：补一条经**真实入口**的断言——`run_controller.start_new_run()` 之后
  `state.health` 必须等于 `player_start_hp`（现有用例只证明函数对，证不了入口调了它）。
- **F3**：`game/tests/unit/test_q8_grammar_pipeline.gd` 第 34/35/38/39 行的注释与断言消息
  仍写 `30/80`、`50/80`、`"30/80 below half"`。判的是 `hp/max_hp < 0.5`，
  现值为 30/100=0.3（成立）与 50/100=**0.5**（不成立，恰好卡边界）——语义仍对，
  但文案失真。请改文案，并**显式标注该夹具卡在 0.5 刀锋值**（或把值挪开边界，你判断）。

SCOPE
只读：`game/data/**`、`game/world-model/**`、`game/scripts/**`、`game/tests/**`
可写（**仅这些**）：
- `game/world-model/tools/audit_effect_budget.py`（新增，只读分析器）
- `game/world-model/reports/effect-budget-census.md`（新增，报告）
- `game/tests/unit/test_world_model_bridge.gd`（F1/F2）
- `game/tests/unit/test_q8_grammar_pipeline.gd`（F3，仅文案/夹具值）
- `ai-system/tasks/p3a-effect-census-result.md`（结果包）

DO NOT
- **禁止修改任何蛊的效果数值**（`game/data/gu.json` 的 `v1_effect` 一律不动）
- **禁止修改兜底表数值**（`game/data/v1_battle.json` 的 `default_effect_by_role` 一律不动）
- **禁止自定 Effect Archetype 清单或任何分配系数**——那是 L1 的裁决，等 RR 回复
- **禁止删 `test_slay_gu`**。它是 S2 开局 Buff「十转杀蛊」的载体（`buffs.json` 的
  `slay_gu_ten.gu_id`），有 `low_rank_exception` 豁免 + 专门测试
  `test_c3_rank_tier_contract.gd` 保护它，2026-09-06 审计结论是「不删不改」。
  （旧计划 `2026-09-19-rank-foundation-implementation.md` 里写的「残留测试蛊清理」是**过期指令**，
   L2 已判定不执行。）
  → 本任务只**清点**它的豁免路径（A⑤），不动数据。
- 禁止 commit / push / merge / stash / reset
- 禁止新增第三方依赖

DECISION AUTHORITY
可自行决定：分析器的实现结构、分组与呈现方式、报告排版、F1–F3 的具体写法。
**不可自行决定**：任何效果数值、兜底曲线、archetype 清单、分配公式、倒挂判据。

ESCALATE WHEN
- 发现 `v1_effect` 还有 L2 清单之外的字段或第二条兜底路径
- 发现手写效果的覆盖矩阵与 L2 给的数字**对不上**（可能是 L2 算错，请指出）
- F1/F2 的断言需要改动生产代码（`run_state.gd` / `run_controller.gd` / `gu_balance.gd`）才能成立
- 发现除 `default_effect_by_role` 之外还有第三条效果来源

DELIVERABLE
1. `game/world-model/tools/audit_effect_budget.py`
2. `game/world-model/reports/effect-budget-census.md`（五节齐全）
3. F1/F2/F3 的测试改动
4. `ai-system/tasks/p3a-effect-census-result.md`（Caveman Review Packet）

ACCEPTANCE
- 普查器可重复运行且输出稳定；**跑完 `git status` 不得显示 `game/data/**` 有任何改动**
- 报告五节齐全，且每个数字都能由脚本复算（不得手写常量）
- 倒挂候选**两种代价口径分别列出**，并注明缺失字段的蛊数
- `python game/world-model/tools/accept.py --smoke 10` 退出码 0
- `python game/world-model/tools/check_upstream_drift.py` 退出码 0
- Godot 桥门禁 **9/9** 通过，且 `SABOTAGE` 负控打开时失败
- Godot 全量 unit 通过
- **跑 Godot 必须用 console 版**（否则静默假绿）：
  `GODOT_PATH` 指向 `…\Godot_v4.7.2-stable_win64_console.exe`，
  或直接调该 exe。**判定通过只看真实 GUT 文本输出，不看退出码。**
  详见 `ai-system/tasks/rank-budget-l2-review.md` §2
- `git status --porcelain` 只显示本 SCOPE 内文件
- 结果包写入 `ai-system/tasks/p3a-effect-census-result.md`

STATUS TARGET
READY_FOR_P3A_REVIEW
```

## 技术事实（L2 已核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 蛊总数 / 手写 / 兜底 | 802 / **61** / **741**（`game/data/gu.json`，顶层是数组） |
| 转数分布 | r1 220、r2 157、r3 180、r4 97、r5 147、**r10 1**（`test_slay_gu`） |
| role 分布 | attack 379 / defense 100 / movement 92 / healing 80 / recon 78 / logistics 73 |
| 8 种 kind | strike 28 / heal 11 / shield 7 / shift 6 / sword_intent 5 / status 2 / heal_and_strike 1 / weaken_intent 1（仅手写 61） |
| 兜底来源 | `game/scripts/domain/v1_battle_resolver.gd` 的 `default_v1_effect()`；表在 `data/v1_battle.json` 的 `default_effect_by_role` |
| 兜底放大 | `RANK_SCALED_KINDS = ["strike","shield","heal"]`，`amount` 与 `support_bonus` 各 `+ (rank-1)` |
| 配方 | 468 条（`data/refinement_recipes.json`：advance 377 / promotion 76 / fixed 14 / free_mix 1）；**0 条 output 声明 `v1_effect`**，全部走兜底 |
| 敌人 | 32 只；common rank1 `hp = 4`；（对照：r1 兜底 strike = 2） |
| 徒手基准 | `unarmed_damage_ratio = 0.2` → 100 × 0.2 = 20 |
| Rank Power Budget | `game/data/balance.json`：40/80/160/320/640 |
| 豁免机制蛊 | `test_slay_gu`：`low_rank_exception: true`（`content_catalog.gd:12` 起注释），`aoe` 等价 `selector:"enemy_all"`（`v1_grammar_pipeline.gd:25`） |
| **Godot 跑法坑** | 非 console 版 Godot headless **零输出且退出码 0**（静默假绿）。判定只看 GUT 文本。 |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台 gb2312，**必须** `PYTHONIOENCODING=utf-8` |
| `.ps1` 必须纯 ASCII | PS 5.1 按 ANSI 解析无 BOM 文件；跑 `.ps1` 用 `pwsh` |

## GIT（执行前必读）

工作树有**大量未提交改动**，多数不属于本任务，禁止触碰或回滚：

```
 M AGENTS.md / PROJECT_MAP.md / ai-system/PRD.md
 M game/AGENTS.md                                            (L2 写的两条数值基石不变量)
 M game/data/balance.json                                    (P2)
 M game/scripts/domain/{gu_balance,cultivator_rules,run_state,world_model_bridge}.gd
 M game/scripts/presentation/run_controller.gd
 M game/tests/unit/test_world_model_bridge.gd                (P2.1，本任务会在其上叠加 F1/F2)
 M game/tests/unit/test_*.gd 共 13 个夹具复基               (P2.1)
 M game/tests/unit/test_battle_save_load_semantics.gd        (★用户自己的在途工作，禁碰)
 M game/tests/unit/test_export_presets_exclude_filter.gd     (★用户自己的在途工作，禁碰)
 M game/world-model/**（data/tools/tests/reports）
 M game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md (P2.1 文档对齐)
 M lore/wiki/**                                              (与游戏无关，在途)
?? game/world-model/rulings/RUL-2026-09-19-00{4..9}.json
?? ai-system/**、docs/superpowers/plans/2026-09-19-rank-foundation-implementation.md
```

**特别注意**：`test_battle_save_load_semantics.gd` 与 `test_export_presets_exclude_filter.gd`
是用户在途改动，**禁止触碰**（P2.1 的 Worker 也正确避开了）。若全量 unit 中这两个文件报错，
**如实上报，不要去修**。

## Execution rules

- Worker class: `normal`。
- 本任务**只读数据**（`game/data/**` 零改动），但仍建议改测试前先
  `python game/world-model/tools/snapshot.py take p3a-census`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/p3a-effect-census-result.md`**。
