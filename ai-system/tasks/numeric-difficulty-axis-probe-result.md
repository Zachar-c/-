# Caveman Review Packet

```text
TASK numeric-difficulty-axis-probe
PHASE Q8-G numeric reconciliation
STATUS READY_FOR_REVIEW
TYPE implementation
ASK L2 裁定：魂预算是否为真实瓶颈；是否接受基线 67.0%→68.0% 的 1pp 漂移解释；结论是否可上抛 L0 做产品取舍。

GOAL
只回答事实问题（33% 死亡率是决策器弱还是难度高），不改任何数值。范围外：调参、改决策器、动生产数据。

DELTA
+ game/world-model/tools/probe_difficulty_axes.py（新建，~200 行，标准库 only，import simulate_balance.simulate/analyse）
+ game/world-model/reports/difficulty-axis-probe.md（新建，4 组对比表 + 死因/节点分布 + 结论 + 基线漂移说明）
+ ai-system/tasks/numeric-difficulty-axis-probe-result.md（本文件）
~ game/world-model/reports/difficulty-axis-probe.md §六：追加基线一致性说明（漂移原因）
= simulate_balance.py 默认行为未变；game/data、game/scripts、world-model/data、balance-simulation.md 零改动

STATE
OpenCode + Muse Spark 1.3 | PARTIALLY VERIFIED（Godot 侧低风险可用；本任务纯 Python 世界模型探针，按 L2 给定技术事实执行）

FILES
game/world-model/tools/probe_difficulty_axes.py — 新增探针脚本，同种子可重复运行
game/world-model/reports/difficulty-axis-probe.md — 新增对比报告
ai-system/tasks/numeric-difficulty-axis-probe-result.md — 本 Packet

TEST
focused: probe_difficulty_axes.py --runs 200 --seed 900000 → PASS（4 组×200 局，aborted 全 0）
  baseline 68.0%（64 死）| soul 97.0%（6 死）| ap 70.0%（60 死）| combo 99.0%（2 死）
relevant: 同种子基线重跑 200 局 → PASS，通关率/死因/节点分布逐项 IDENTICAL（0.68，魂魄崩散 61，event 61）
full: 未跑（Godot 全量 unit 与本任务无关；world-model accept 未跑，因 world-model/data 零改动）
diff-check: PASS（git status 仅 3 个 SCOPE 新文件；禁区零改动；loot_resolver.gd 的 M 为任务前既有用户改动，未触碰）

WORKER
OpenCode + Muse Spark 1.3（L3 Worker）
core patch: NO
tests: YES
protocol: YES
Codex takeover: NONE
independent: YES

RISK
基线漂移 67.0%→68.0%（pre-existing，非本任务引入）：数据指纹 fca50a01→43a003e6，系 343ff44（essence_max 显式报错）晚于 2026-09-17 基线报告；差 2 局，不影响“+29pp”量级结论。不阻塞。
UNPROVEN NONE（结论只基于本批 800 局；“决策器上限”外推需 L2/L0 裁定）

GIT
status: 仅新增 SCOPE 内 3 文件；其余脏项均为任务前既有（loot_resolver.gd 等 M 项 + wenzhen-web-lab 等 untracked），未触碰
commit: NONE
merge: NONE
push: NO

DECISION
D1 魂预算是真实瓶颈 | recommend YES | soul 1→4 通关率 +29.0pp（68→97%），魂死因 61→1，event 死亡 61→1；AP 轴仅 +2.0pp
D2 33% 死亡率主因是难度（魂预算紧）而非决策器弱 | recommend YES | 放宽唯一致命资源后死亡几乎消失，符合任务预设判读规则（≥10pp 即难度问题）

NEXT
L2 Review 后交 L0 产品取舍（是否放宽魂预算 / 改 delayed_soul_cost）
STOP

EVIDENCE
game/world-model/reports/difficulty-axis-probe.md §一–§六
game/world-model/tools/probe_difficulty_axes.py build_overrides（set_override 路径：("run","starter")、("run","action_points_by_soul")，均走 wm.b()，run.py:61 / rules.py:117 已验证）
基线对照：game/world-model/reports/balance-simulation.md（67.0%，指纹 fca50a01…，2026-09-17）
漂移提交：343ff44
```

---

# L2 Review（Codex Orchestrator，2026-09-19）

```text
REVIEW STATUS: PASS WITH FOLLOW-UP
```

## 已独立复核

| 项 | 复核方式 | 结果 |
|---|---|---|
| 4 组数字 | **L2 亲自复跑两次**（`probe_difficulty_axes.py --runs 200 --seed 900000`） | 与 Worker 逐项一致：baseline 68.0% / soul 97.0% / ap 70.0% / combo 99.0%，`aborted` 全 0 |
| 可复现性 | 同种子三次独立运行比对 | 通关率、死因、节点分布 IDENTICAL |
| 越界 | `git status --short` 对 `game/data/`、`game/scripts/`、`game/scenes/`、`world-model/data/`、`balance-simulation.md`、`simulate_balance.py` | 全部零改动；`loot_resolver.gd` 的 `M` 为任务前既有，未触碰 |
| 提交 | `git log` / `git status` | 无 commit、无 push、无 merge |
| 脚本安全性 | 通读写入点 | 仅 `REPORT.write_text`；覆盖只走 `set_override`（内存）；未引入第三方依赖 |

## FIX（已由 L2 执行，非 Worker 返工）

**缺陷：报告 §六 是手工追加的，脚本不生成 → 按文档命令复跑会抹掉它，而报告自称"可复现"。**

- 证据：L2 首次复跑后 `diff` 显示 Worker 版 §六/§七 消失，仅剩 §六 复现方式。
- 修复：把该节折进 `render()`，并新增 `read_reference_baseline()` **从 `balance-simulation.md` 解析**基线通关率（不硬编码，避免过期）。有参照时才输出该节，并把「复现方式」顺延为 §七。
- 验证：再次复跑，§六 正常生成且数值正确（68.0% vs 67.0%，+1.0pp）。

## 对 Worker 结论的一处更正（重要）

Worker 的 `RISK` 把 1pp 漂移归因于提交 `343ff44`。**该归因不成立，L2 已更正：**

| 事实 | 证据 |
|---|---|
| `343ff44` **没有**碰数据 | `git show --stat 343ff44` → 只改 `engine/rules.py`、`HANDOFF.md`、`tests/run_tests.py` |
| `data_digest` **只覆盖 `world-model/data/`** | `engine/model.py:58-85`，哈希输入为 `ENTITY_FILES` |
| 因此指纹变化 ⇒ **数据**变了，而 `343ff44` 不是原因 | 同上两条 |
| 但 git **无法定位**是哪个提交 | `git log -- game/world-model/data/` 只有 `ebb7f81 chore: import Godot game project` 一条——游戏子树是整体导入的，历史已被压平 |

**正确的表述**（报告 §六 已照此措辞）：差异来自 `world-model/data/` 或 `engine/` 的既有改动，
**具体来源无法从本仓历史判定**。判读以组间差值为准。

结论本身不受影响：`+29.0pp` 与 `+2.0pp` 的量级差足以支撑判别。

## 可上抛 L0 的结论

1. **魂预算（起始 1 / 上限 4）是真实瓶颈**，不是决策器弱：放宽后通关率 68.0%→97.0%，魂死因 61→1。
2. **行动点轴几乎无影响**（+2.0pp）：3 AP 不可达本身不是主因，魂的**存量**才是。
3. **现有难度旋钮 `enemy_hp_mult` 打在错的轴上**（战斗 200 局仅 2 例致死），与之互证。
4. 待 L0 裁定：是放宽魂预算、改 `events.json` 的 `delayed_soul_cost`，还是把难度分档建在魂这条轴上。

