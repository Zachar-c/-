# P2 · 定 Rank Power Budget + 钉死 HP 基准（1–5 转数值基石 · 第 2 阶段）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
L2 Orchestrator

DOWNSTREAM
L2 Review → 后续阶段 P3（统一 Effect 管线）

PROJECT GOAL
把《蛊真人》做成游戏。经 L1 架构裁决（RUL-2026-09-19-008），
「1–5 转」被定为**综合层级轴**，而仓库里原本有**六套互不知情的转数阶梯**必须收敛。

CURRENT PHASE
`RUL-2026-09-19-008`（FOUNDATION APPROVED）已生效，指定实施顺序：
① Rank 语义 ✅（P1 已完成：`game/AGENTS.md` 已登记三条不变量与禁令）→ **② Rank Power Budget（本阶段）**
→ ③ 统一 Effect 管线 → ④ Essence Budget → ⑤ 资质/突破/跨转 → ⑥ 经济稀缺 → ⑦ 1→5 节奏 → ⑧ 敌人关卡 → ⑨ 难度档

TASK PURPOSE
把「转数能力预算」立成**全仓唯一一处来源**，并把其余几套曲线**各自归位到所属的轴**；
同时钉死玩家气血的基准口径。这一步不做平衡、不改蛊效果——只做「立真源 + 归位」。

TASK

**A. 建立唯一的 `rank_power_budget(rank)`**

L2 已按 RUL-008 D2/D11 定稿基数口径，照此实现（**不要自行改口径**）：

```text
rank_power_budget(rank) = rank1_budget × rank_step_ratio^(rank-1)      rank ∈ 1..5
rank_step_ratio = 2                        （沿用现值，升格为预算曲线的步进比）
rank1_budget    = human_base_health × standard_hit_ratio × rank_step_ratio
                = 100 × 0.2 × 2 = 40
→ 1..5 转 = 40 / 80 / 160 / 320 / 640     （与现行 standard_gu_power 完全一致，零数值漂移）
```

要求：
- 在**上游** `game/data/balance.json` 里新增具名条目（键名用 `rank_power_budget` 及其构成项），
  使 40/80/160/320/640 由公式给出而**不是硬编码的五个数**
- `game/world-model/data/balance.json` **只能由 `build_world_model.py` 重新生成，禁止手改**
- Godot 侧提供**唯一访问点**（现 `gu_balance.gd` 已有 `rank_multiplier(rank) = rank_step_ratio^(rank-1)`，
  请把口径统一到本曲线，并标注两者关系），其余代码不得再各自算一套

**B. 六套曲线的归位（只做标注与重归类，不删数值）**

按 RUL-008 D12，逐条在数据/代码中写明它属于哪条轴：

| 现有曲线 | 现值 | 本阶段处置 |
|---|---|---|
| `rank_step_ratio` 通用倍率 | 2.0 | **升格**为 `rank_power_budget` 的步进比 |
| `standard_gu_power` 参照系 | 40/80/160/320/640 | **指定为** `rank_power_budget` 的唯一真源（值不变） |
| 局外真元 ×3 | 1/3/9/27/81 | **归位**：`Essence Budget` 轴（P4 处理，本阶段只标注） |
| 战斗真元 | 10/30/60/100/150 | **归位**：`Essence Budget` 轴（同上） |
| `gu_value_by_rank` 蛊价值 | 3/5/8/12/20 | **归位**：`Economy` 轴（P6），**不是**能力预算 |
| `boss_layer_mult` 层倍率 | hp 1.0/1.1/1.2/1.35/1.5 | **踢出转数曲线**：敌人/关卡系统（P8）。本阶段**只标注不改值** |
| `advance_bonus_by_rank` | 0/1/3/6/10 | **踢出转数曲线**：进度/奖励系统（P7）。只标注不改值 |
| `beast_scale` | 200/400/800/1600/3200 | **并列参照系**：其基数（100）与蛊预算隐含基数（20）不同。**只标注关系，不改值**；若你判断必须改基数才能自洽，**停止并上报**（L1 未就此事裁定） |

**C. 钉死 HP 基准（RUL-008 D11）**

- `human_base_health = 100` 立为 **Source of Truth**（它已同时承担蛊师肉身基准、一转能力参照、兽类参照）
- 玩家开局气血**不得继续是构建脚本里的裸字面量 80**。按 D11：**在没有明确产品意图的前提下，先按 100**。
  请改成**显式成对配置**（如 `standard_human_hp` / `player_start_hp`），使「玩家开局 = 标准一转肉身的 X%」
  可被读出；若你决定保留 80，必须在同一处写明「玩家开局是标准一转肉身的 80%」这一设计意图，
  并在结果包中显著标注这是**平衡变动**。
- **必须记录改动前后的模拟基线差异**（改 HP 会移动难度基线，这是已知且必须留档的副作用）

**D. 加一条可执行断言（为后续把它写进 CONSTRAINTS-V2 做准备）**

`world-model/tools/validate_world_model.py` 增加断言：
- `rank_power_budget` 的 1–5 转取值等于 `rank1_budget × 2^(rank-1)`
- 上述被归位的曲线在数据中带有**所属轴标注**（字段名由你定，但须可被脚本读出）

> 背景：`CONSTRAINTS-V2` 的 **R5** 规定「约束必须可执行；写不进脚本的规则不许存在」，
> 所以本阶段先把断言写出来；断言通过后，L2 再把它作为新规则登记进 CONSTRAINTS-V2。

SCOPE
只读：`game/data/**`、`game/scripts/**`、`game/tests/**`、`game/world-model/**`、`game/docs/`（仅参考）
可写（**仅这些**）：
- `game/data/balance.json`（上游真源；新增条目 + HP 显式化）
- `game/scripts/domain/gu_balance.gd`、`game/scripts/domain/cultivator_rules.gd`（唯一访问点与 HP 消费）
- `game/world-model/tools/build_world_model.py`（派生新条目；移除硬编码 80）
- `game/world-model/data/balance.json`（**只能由构建器重新生成**）
- `game/world-model/tools/validate_world_model.py`（新增断言）
- 相关测试（`game/tests/unit/**`、`game/world-model/tests/**`）
- `ai-system/tasks/rank-budget-result.md`（结果包，路径照此）

DO NOT
- **禁止改任何蛊的效果数值**（`gu.json` 的 `v1_effect`、兜底公式）——那是 P3 的范围
- **禁止改真元曲线的数值**（局外 ×3、战斗 10/30/60/100/150）——那是 P4，本阶段只标注
- **禁止改经济/价格/掉落**——那是 P6
- **禁止改敌人与关卡数值**（含 `boss_layer_mult`）——那是 P8
- **禁止改跨转催动折价与资质门禁**——那是 P5
- **禁止做难度档**——L1 明令「难度必须最后」（P9）
- **禁止手改 `game/world-model/data/` 的任何文件**（它是派生镜像，改了会被覆盖并触发漂移告警）
- **禁止代决 L1 留白四项**：黄金/紫晶是否 ×10、高转经济倍率、跨转 ×2 是否恰当、五转出现比例。
  工作若必须回答其中之一才能继续 → **停止并上报**
- 禁止 commit / push / merge / stash / reset
- 禁止新增依赖

DECISION AUTHORITY
可自行决定：新增条目的键名与组织方式、标注字段名、测试写法、构建器内的实现结构。
**不可自行决定**：预算曲线的口径（已由 L2 按 RUL-008 定稿）、各归位曲线的数值、HP 的最终值
（默认 100，若保留 80 必须写明设计意图并显著标注）、L1 留白四项。

ESCALATE WHEN
- 要改 `beast_scale` 的基数才能自洽（L1 未裁）
- 改动 HP 导致模拟基线大幅漂移，且你判断需要产品判断
- 发现除上表七条之外**还有第八套转数曲线**（L2 的清单可能不全）
- 发现统一访问点会波及 P3–P9 范围的文件

DELIVERABLE
1. 上游 `game/data/balance.json`（`rank_power_budget` 条目 + HP 显式成对配置）
2. `game/world-model/data/balance.json`（构建器重新生成的结果）
3. 构建器 / 校验器 / 唯一访问点 的代码改动
4. 相关测试
5. **`ai-system/tasks/rank-budget-result.md`**（Caveman Review Packet）

ACCEPTANCE
- `python game/world-model/tools/accept.py --smoke 10` 退出码 0
- `python game/world-model/tools/check_upstream_drift.py` 退出码 0（世界模型与上游一致）
- Godot 侧接线门禁 `-gtest res://tests/unit/test_world_model_bridge.gd` 通过，**且 `SABOTAGE` 负控打开时失败**（否则门禁失效）
- Godot 全量 unit 通过
- 新增断言：把 `rank_power_budget` 某个值改错时 `validate_world_model.py` 必须失败（附负控证据）
- `rg` 证据：全仓不再有第二处「转数 ×N 通用倍率」的实现；`run.starter.hp` 不再是裸字面量
- **记录改动前后的模拟基线差异**（通关率/死因分布），作为已知副作用留档
- `git status --porcelain` 只显示本 SCOPE 内文件
- 结果包写入 `ai-system/tasks/rank-budget-result.md`

STATUS TARGET
READY_FOR_RANK_BUDGET_REVIEW
```

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 裁定原文 | `game/world-model/rulings/RUL-2026-09-19-008.json`（13 条决策 + 4 项留白） |
| 实施计划 | `docs/superpowers/plans/2026-09-19-rank-foundation-implementation.md` |
| 当前参照系 | `balance.json` 的 `formulas.standard_gu_power = "human_base_health * standard_hit_ratio * rank_step_ratio^rank"` → 实算 40/80/160/320/640 |
| 当前步进比 | `growth.rank_step_ratio = 2.0` |
| 当前 HP | `growth.human_base_health = 100`；`run.starter.hp = 80`、`hp_max = 80`（**构建脚本 `build_world_model.py:897` 的裸字面量**） |
| 当前兽类参照 | `formulas.beast_scale = "human_base_health * rank_step_ratio^rank"` → 200…3200 |
| 唯一消费点 | `game/scripts/domain/gu_balance.gd:27-28` 注释 `rank_multiplier(rank) = rank_step_ratio^(rank-1)`；`cultivator_rules.gd:79` 消费 `human_base_health` |
| 真元两条曲线 | 局外 `aptitude.json` 附近 ×3；战斗 `v1_battle.json` 10/30/60/100/150（**本阶段只标注**） |
| 经济曲线 | `economy.gu_value_by_rank = {3,5,8,12,20}`（**本阶段只标注**） |
| 层倍率 | `run.boss_layer_mult`（**本阶段只标注**） |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`；`python` 不在 PATH |
| 终端编码坑 | 控制台 gb2312，**必须** `PYTHONIOENCODING=utf-8` |
| 本仓 `.ps1` 必须纯 ASCII | PS 5.1 按 ANSI 解析无 BOM 文件 |
| wiki 校验脚本需 PS7 | 用 `pwsh`（本阶段一般不涉及 wiki） |

## GIT（执行前必读）

工作树已有**大量未提交改动**，均不属于本阶段，禁止触碰或回滚：

```
 M AGENTS.md / PROJECT_MAP.md / ai-system/PRD.md / docs/debt.md
 M game/AGENTS.md                              (P1 产出，L2 已写)
 M game/export_presets.cfg / game/scripts/domain/loot_resolver.gd
 M game/tests/unit/test_battle_save_load_semantics.gd / test_export_presets_exclude_filter.gd
 M lore/wiki/**   (多个页面在途)
?? lore/wiki/world/soul-path.md 等
?? game/world-model/reports/{numeric-status-audit,difficulty-axis-probe,soul-system-audit,soul-canon-verification,rank-foundation-canon}.md
?? game/world-model/rulings/RUL-2026-09-19-00{4,5,6,7,8}.json
?? docs/superpowers/plans/2026-09-19-rank-foundation-implementation.md
?? ai-system/**   (协作体系文件)
```

执行前跑 `git status --porcelain` 自查；与上述不符或与本 SCOPE 冲突则停止上报。

## Execution rules

- Worker class: `normal`。
- 改 `game/world-model/` 之前先 `python game/world-model/tools/snapshot.py take rank-budget`。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet，
  **写入 `ai-system/tasks/rank-budget-result.md`**。
