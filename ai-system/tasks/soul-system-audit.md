# 只读 Soul System Audit（魂道体系现状盘点）

```text
WORKFLOW ROLE
L3 Worker

UPSTREAM
Codex Orchestrator (L2)

DOWNSTREAM
Codex Review (L2) → L1 研究院（魂道闭环与跨轴机会成本）→ L0 数值裁定

PROJECT GOAL
把「魂」从一个固定 1–4 的风险条，重新建立成**可成长的 Build Axis（魂道玩法）**。
在动任何数值之前，必须先把现状盘清楚。

CURRENT PHASE
`RUL-2026-09-19-004`（`game/world-model/rulings/`）已生效，内容摘要：
- **魂 = 可成长 Build Axis，对应魂道玩法**，同时承担
  ①魂魄生存值 ②魂道能力资源 ③魂道攻防基础 ④长期成长属性
- **不是**固定 1–4 的风险条
- **禁止**：直接删除高魂 AP 档位；继续以 `max_soul = 4` 为前提调难度；
  把 `starting_soul` 定为主要 difficulty knob；仅把魂视为第三死亡条
- **下一步：先做只读 Soul System Audit，再决定数值**

TASK PURPOSE
L0 指定了 6 个必须回答的问题。本任务**只盘点现状、不下数值结论**，
产出供 L1 研究院设计魂道闭环的事实底座。

TASK
产出一份只读审计报告，逐条回答下列问题。**每条结论必须标注
`[FACT]`（附 `文件:行号`）/ `[INFERRED]`（附推理链）/ `[UNKNOWN]`（并写明缺什么）。**

**Q1. `soul` 的「当前值」与「上限」是否应分离？现状是什么？**
- `soul` / `soul_max` 在何处定义、何处读写、谁消费
- 上限是硬顶还是软顶；是否有任何机制改变上限
- 与 `SoulRules` 的 `soul_safe_capacity` 概念是什么关系（是否已是"上限"的另一种表达）

**Q2. 现有 AP 门槛的原始设计意图**
- 当前数据：`run.action_points_by_soul` = 10000/1000/100/10/0 → 6/5/4/3/2
- 文档记录：`docs/wiki/concepts/world-model-translation.md:21` 写「1/10/100/10000 底蕴 → 2/3/4/5/6 次」；
  `docs/superpowers/specs/2026-09-01-v1-battle-schema.md:74` 记 ≥10000 → 6
- **两处口径不一致（wiki 是 1/10/100/10000，数据是 10/100/1000/10000），必须确认哪个是原意、何时改的**
- 追溯 `original` 意图：找设计文档、提交信息、注释、旧表格，说明这四/五档当初要解决什么

**Q3. 哪些蛊 / 事件 / 资源可以「增长」魂魄**
- 蛊：搜索 `soul_boost`、`soul_pill`、`school == "soul"` 且有增长语义的条目
- 事件：`data/events.json` 中的 `soul_gain` 类效果
- 资源：黑市兑换、商店、遗物、契约、天赋
- 逐条给出：来源 → 增量 → 代价 → 频率上限（能否无限刷）

**Q4. 哪些能力「消耗」或「攻击」魂魄**
- 消耗侧：`soul_cost`（哪些操作在扣）、`SoulRules` 的操作集
- 攻击侧：`soul_drain`（敌方意图，哪些敌人有、数值多少）
- 是否存在**玩家 → 敌人**的魂攻击通道（若有，在哪里；若无，明确写"不存在"）

**Q5. 魂道构筑的闭环现状：获得 → 养魂 → 使用 → 强化**
- 以 `school == "soul"` 的 40 只蛊为骨架（已核：1–5 转 11/10/9/4/6；
  role attack17/def5/mov5/heal5/recon4/log4；**仅 1 只有显式 `v1_effect`**）
- 四个环节各自**现在存在什么、缺什么**（缺的要写清缺在数据层还是引擎层）
- 魂道是否有独立的合成/晋升路径（查 `data/refinement_recipes.json` 中 soul 相关）
- `data/schools.json` / `school_pools.json` 里 soul 的配置

**Q6. 魂与肉身 / 真元等 Build Axis 的机会成本与克制关系**
- 列出当前所有 Build Axis（至少含：真元、气血、寿元、魂、念头、蛊数量/构筑、元石/材料）
- 每个轴的：来源 / 消费者 / 是否可成长 / 是否有死亡阈值
- 轴与轴之间的兑换关系（如黑市寿元↔魂↔气血；元石↔真元）
- **已知的克制/互斥机制**（例：契约的 `hp_max_penalty`、资质对真元的乘数）
- 明确标出：哪些轴之间存在**机会成本**（花在这里就不能花在那里），哪些**没有**

**Q7（附加）. 两套魂系统的关系**
- legacy `soul`/`soul_max`（活）与 `SoulRules` 五量
  （`soul_magnitude` / `soul_safe_capacity` / `soul_calm` / `soul_nature` / `beast_nature`）
- 各自的定义位置、消费者、是否互通；`SoulRules` 零消费者的事实复核
- 若要把魂建成 Build Axis，哪一套更适合承载（只给事实与差异，**不给推荐**）

SCOPE
只读：`game/` 全树（`data/`、`scripts/`、`docs/`、`world-model/`、`tests/`）、`lore/wiki/`（原著口径）
只写（仅此两处）：
- `game/world-model/reports/soul-system-audit.md`（审计报告）
- `ai-system/tasks/soul-system-audit-result.md`（Caveman Review Packet）

DO NOT
- **禁止修改任何文件**（除上述两个新文件）。本任务**纯只读**。
- 特别禁止：`game/data/**`、`game/scripts/**`、`game/scenes/**`、`game/world-model/data/**`、
  `game/world-model/rulings/**`、`game/docs/**`、`lore/**`
- **禁止提出数值建议或给出"应该改成多少"**。只盘点现状。若发现设计空间，写到
  `[INFERRED]` 并标明"供 L1 参考，非建议"。
- **禁止把魂重新解释为"风险条"**，也禁止以 `max_soul = 4` 为前提做任何推理
  （这是 `RUL-2026-09-19-004` 明令禁止的）
- **禁止建议删除高魂 AP 档位**
- 禁止 commit / push / merge / stash / reset
- 禁止新增依赖（仅标准库 / 现有工具）
- 禁止读原文全文；`lore/wiki/` 只读已蒸馏的条目

DECISION AUTHORITY
可自行决定：审计的检索路径、报告的章节组织、如何标注证据强度、
如何呈现 40 只魂道蛊的现状。
不可自行决定：任何数值取向、魂的定位、Build Axis 的取舍、两套魂系统选哪套。

ESCALATE WHEN
- 发现 Q2 的门槛口径无法从仓库判定原意（写明已查过哪些地方）
- 发现魂道存在**未登记的第三套魂机制**
- 发现现有代码中魂的行为与 `RUL-2026-09-19-004` 的产品意图直接冲突且涉及架构
- 发现报告所需事实只能靠改代码才能验证（本任务不允许改代码）

DELIVERABLE
`game/world-model/reports/soul-system-audit.md`，含：
1. Q1–Q7 逐条回答，每条 `[FACT]`/`[INFERRED]`/`[UNKNOWN]` 标注 + 证据
2. **一张「魂相关字段/通道总表」**：来源、消费者、位置、是否可成长
3. **一张「Build Axis 对照表」**：真元/气血/寿元/魂/念头/蛊/元石 — 来源、消费、可成长性、死亡阈值
4. **一段「现状 vs 产品意图」的差距清单**：RUL-2026-09-19-004 想要的四重身份，
   现在各有多少支撑、缺在数据层还是引擎层
5. Caveman Review Packet（`ai-system/WORKER_HANDOFF_TEMPLATE.md`）

ACCEPTANCE
- Q1–Q7 每条都有回答，且每条结论都带证据标注；`[UNKNOWN]` 必须写明缺什么
- 40 只魂道蛊的现状数字与 L2 已核数据一致（1–5 转 11/10/9/4/6；仅 1 只显式 `v1_effect`）
- Q2 必须明确写出：wiki 口径与数据口径哪个是原意，或明确写"无法从仓库判定"及已查范围
- `git status --porcelain` 显示**除两个新文件外零改动**
- 报告中不出现任何数值建议

STATUS TARGET
READY_FOR_SOUL_SYSTEM_REVIEW
```

## 技术事实（已由 L2 核实，Worker 不必重新考古）

| 事实 | 证据 |
|---|---|
| 裁定文件 | `game/world-model/rulings/RUL-2026-09-19-004.json`，JSON 已校验合法 |
| 生效约束体系 | `world-model/governance/CONSTRAINTS-V2.md` §3（R1–R6）；R3 = 一条裁定一个文件 |
| 魂道蛊 40 只 | `data/gu.json` 中 `school == "soul"`；rank 1–5 = 11/10/9/4/6；role attack17/def5/mov5/heal5/recon4/log4；**仅 1 只**有显式 `v1_effect` |
| AP 门槛 | `run.action_points_by_soul`（`world-model/data/balance.json`）= 10000/1000/100/10/0 → 6/5/4/3/2 |
| 门槛文档口径 | `docs/wiki/concepts/world-model-translation.md:21`；`docs/superpowers/specs/2026-09-01-v1-battle-schema.md:74` |
| 魂字段分布（全树 grep 计数） | `"soul"` 164 / `soul_atk_` 109 / `soul_def_` 39 / `soul_mov_` 35 / `soul_heal_` 24 / `soul_log_` 20 / `soul_max` 20 / `soul_boost` 20 / `soul_rec_` 16 / `soul_drain` 16 / `soul_cost` 15 / `soul_safe_capacity` 8 / `soul_magnitude` 8 / `soul_calm` 8 / `soul_nature` 5 |
| `soul_drain` 位置 | `world-model/engine/run.py` 附近有消费；敌人意图侧在 `data/enemies.json` |
| Python | `C:\Users\90877\.workbuddy\binaries\python\versions\3.13.12\python.exe`（实测 3.13.14）；`python` 不在 PATH |
| 本仓 `.ps1` 必须纯 ASCII | PS 5.1 对无 BOM 文件按 ANSI 解析，中文注释直接造成语法错误（L2 于 2026-09-19 踩过） |

## GIT（执行前必读）

工作树已有**未提交改动**，均不属于本任务，禁止触碰：

```
 M game/export_presets.cfg
 M game/scripts/domain/loot_resolver.gd
 M game/tests/unit/test_battle_save_load_semantics.gd
 M game/tests/unit/test_export_presets_exclude_filter.gd
?? game/tests/unit/test_m0_loot_allowlist.gd
?? game/wenzhen-web-lab/                                  (untracked 原型)
?? game/world-model/reports/numeric-status-audit.md        (L2 产出)
?? game/world-model/reports/difficulty-axis-probe.md       (L2 派单产出)
?? game/world-model/tools/probe_difficulty_axes.py         (L2 派单产出)
?? game/world-model/rulings/RUL-2026-09-19-004.json        (L0 裁定，L2 落档)
```

执行前跑 `git status --porcelain` 自查；发现本任务写入路径与上述冲突则停止上报。

## Execution rules

- Worker class: `normal`。
- 纯只读审计；只新增 2 个文件。
- 不 commit / 不 push / 不 merge / 不 stash / 不 reset。
- 结束时按 `ai-system/WORKER_HANDOFF_TEMPLATE.md` 输出 Caveman Review Packet。
