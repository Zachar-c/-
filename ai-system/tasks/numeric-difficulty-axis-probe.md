# 难度轴判别实验：区分「模拟决策器太弱」与「整体难度偏高」

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
Codex Orchestrator (L2)

DOWNSTREAM
Codex Review (L2) → 用户裁定（L0，产品取舍）

PROJECT GOAL
《蛊真人》肉鸽游戏的数值与难度体系需要建立在**真实瓶颈**上，而不是凭手感调参。
本任务不改数值，只回答一个事实问题：当前 33% 的死亡率，是决策器弱，还是难度高。

CURRENT PHASE
Q8-G 经济重构之后的数值对账阶段。
`game/world-model/reports/numeric-status-audit.md`（L2 产出，只读参考）已记录：
- 基线通关率 67.0%（模拟器自评为"合理肉鸽难度带"，等级「已缓解」）
- 死因 92% 为「魂魄崩散而亡」，集中在 `event` 节点（61/66）
- 战斗几乎不致死：200 局仅 2 例死于 `combat` 节点
- 唯一的难度旋钮 `run.difficulty.enemy_hp_mult` 非单调：1.0→67.0%，1.5→70.0%，2.0→42.0%

TASK PURPOSE
`enemy_hp_mult` 打在战斗轴上，而战斗几乎不致死，因此它测不出难度瓶颈。
需要一个**打在正确轴上**的探针，把「决策器太弱」与「难度偏高」分开：
若放宽某个资源后通关率大涨 → 该资源就是真实瓶颈（难度问题）；
若几乎不动 → 瓶颈在决策器（67% 是下限，不是游戏难度）。

TASK
新增一个**独立探针脚本**（不改 `simulate_balance.py` 的默认行为），在同一批种子上跑多组
内存覆盖，输出对比报告。

必跑 4 组，每组 200 局，种子区间 `900000 … 900199`（与既有基线同区间，保证可比）：

1. **基线**：无任何覆盖。
2. **魂预算轴**：覆盖 `("run", "starter")`，把 `soul` 由 1 改为 4（`soul_max` 保持 4）。
   检验：魂是唯一的致命资源，多给 3 点是否能显著改善存活。
3. **行动点轴**：覆盖 `("run", "action_points_by_soul")`，把 3 AP 的门槛从 `min_soul: 10`
   降到 `min_soul: 1`（其余档位保持原值）。检验：让「魂」从纯风险变成可经营资源后，
   通关率是否上升。（现状：魂起始 1、上限 4，而 3 AP 需要 ≥10 → 该档在整局中不可达。）
4. **组合**：第 2 与第 3 组同时生效。

每组记录：通关率、死亡数、**死因分布**、**死亡节点类型分布**、平均终局转数分布、
平均终局蛊虫数、平均行动回合。

SCOPE
读：`game/world-model/`（全部）、`game/data/`（只读）
写（仅此三处）：
- `game/world-model/tools/probe_difficulty_axes.py`（新增）
- `game/world-model/reports/difficulty-axis-probe.md`（新增，报告）
- `ai-system/tasks/numeric-difficulty-axis-probe-result.md`（新增，Caveman Review Packet）

DO NOT
- **禁止修改任何生产数值**：`game/data/**`、`game/scripts/**`、`game/scenes/**`、
  `game/world-model/data/**` 一律只读。
- **禁止覆盖 `game/world-model/reports/balance-simulation.md`**（tracked 产物）。
- **禁止修改 `game/world-model/tools/simulate_balance.py` 的默认行为**。可以 `import` 它复用
  `simulate()` / `analyse()`；若确实需要加可选参数，必须保证不带该参数时行为与现状逐字节一致。
- 禁止 commit / push / merge / stash / reset。
- 禁止新增 Provider、Router、Agent、调度或配置抽象；禁止引入第三方依赖（仅标准库）。
- 禁止改动工作树中既有的未提交改动（见 GIT 一节）。

DECISION AUTHORITY
可以自行决定：探针脚本的内部结构、如何复用 `simulate_balance.py` 的函数、
报告表格的具体排版、如何统计死因/节点分布。
不可自行决定：4 组覆盖的取值、种子区间、局数、输出的对比维度——
这些已在上方 TASK 固定；要改必须先上报。

ESCALATE WHEN
- 覆盖路径在 `set_override` 下不生效（见下方技术事实），需要改引擎才能测；
- `run.starter` 或 `run.action_points_by_soul` 不是 `b()` 可解析的 balance 路径；
- 某组出现异常终止（`aborted`）而非正常结算；
- 发现工作树中既有改动与本次写入路径冲突。

DELIVERABLE
1. `probe_difficulty_axes.py`，可重复运行（同种子同结果）。
2. 报告含 4 组对比表 + 死因/节点分布 + 一句结论：
   「把 X 放宽后通关率变化 N 个百分点」→ 据此能否区分决策器问题与难度问题。
3. Caveman Review Packet（按 `ai-system/WORKER_HANDOFF_TEMPLATE.md`）。

ACCEPTANCE
- 4 组 × 200 局全部跑完，`aborted` 为 0（若不为 0，如实记录并说明）。
- 同一种子重复跑一次，通关率数字完全一致（可复现）。
- `git status --porcelain` 显示只有 SCOPE 允许的 3 个新文件，且 `game/data/`、`game/scripts/`、
  `game/world-model/data/`、`game/world-model/reports/balance-simulation.md` 均无改动。
- 报告中的基线组通关率与既有 `balance-simulation.md` 的 67.0% 一致（不一致必须解释原因）。

STATUS TARGET
READY_FOR_REVIEW
```

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 覆盖 API | `world-model/engine/model.py:116` `set_override(path: tuple, value)`；`:126` `b(*path)` 命中 override 时直接返回 |
| **override 只对 `b()` 路径生效** | `b()` 只查 `self.overrides[tuple(path)]` 与 `self.balance`；`wm.events`（`:181`）返回实体字典，**不走 override** |
| 既有用法先例 | `world-model/tools/simulate_balance.py:310-318` 用 `wm.set_override(("run","difficulty"), {...})` 做 `--hp-mult` 扫描 |
| 复现入口 | `simulate_balance.py:44` `simulate(wm, runs, base_seed)` / `:66` `analyse(result, label)`；`main()` 有 `if __name__ == "__main__"` 保护，可安全 import |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`（实测 3.13.14）。`python` 不在 PATH |
| 魂现状 | 起始 1 / 上限 4；`action_points_by_soul` 门槛为 10000/1000/100/10/0 → **3 AP 档不可达** |
| 魂是死因 | `world-model/engine/run.py:564-568` `delayed_soul_cost` → `pending_delayed`；92% 死因「魂魄崩散而亡」 |
| `delayed_soul_cost` 在 `events` 实体里 | 因此**不能**用 `set_override` 直接调它——这也是本任务改用 `starter.soul` 与 `action_points_by_soul` 两条 balance 路径的原因 |

## GIT（执行前必读）

工作树中已有**未提交改动**，均不属于本任务，禁止触碰：

```
 M game/scripts/domain/loot_resolver.gd
 M game/tests/unit/test_battle_save_load_semantics.gd
 M game/tests/unit/test_export_presets_exclude_filter.gd
 M game/export_presets.cfg
?? game/wenzhen-web-lab/            (untracked 原型)
?? game/world-model/reports/numeric-status-audit.md   (L2 产出)
?? game/tests/unit/test_m0_loot_allowlist.gd
?? ai-system/ 等多处
```

执行前先跑 `git status --porcelain` 自查；发现本任务写入路径与上述冲突则停止上报。

## Execution rules

- Worker class: `normal`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 仅标准库；零第三方依赖。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet。
