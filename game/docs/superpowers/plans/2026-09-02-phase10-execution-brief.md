# 阶段十执行交接单：旧系统清退与迁移收尾（T10.1 + T10.2）

> 日期：2026-09-02
> 上级计划：[2026-09-01-gu-system-economy-combat-implementation.md](2026-09-01-gu-system-economy-combat-implementation.md)（最终批）
> 权威规格：`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md`——实现前**必须阅读** §18（迁移纪律与废止清单 12 条）、§17.4（验收矩阵 18 条）。本批是"只删不改 + 收尾验收"批，任何新规则都不得在本批出现。
> 仓库约束：遵守 `AGENTS.md` 全部条款；三份契约文档（`docs/contracts/2026-09-02-*.md`）随删除项同步回写。

---

## 0. 当前基线（开工前先核对）

- 分支 `master` @ `91f6639`，工作树有未提交文档改动（AGENTS.md 与契约/交接单文档——由维护者另行提交，与本批无关，**不得打包进本批提交**）。开工前跑 `git status --short --branch` 确认。
- 阶段一至九全部合入。阶段九审查结论：**通过**（1 个 P2 双轨期遗留，已并入 T10.1-⑥，见下）。全量 `-Suite all` 退出码 0、零失败（unit 1121/1120 + 1 pre-existing risky；integration 13/12 + 1 pre-existing pending）。
- 行数门禁：`resolver.gd` 2452 / cap 2457、`battle_resolver.gd` 1514 / cap 1516。阶段十结束时**基线必须一次性下调**（单向只降不升），目标是低于删除前基线。
- **v2 命令面现状**（T9.2 落地）：15 条新命令在 `resolver._dispatch` → `v2_commands.gd` 薄委托；`enact/dodge/grapple/respond` 的 battle2 ledger 目前**由命令携带**（无状态透传）——这是双轨期占位，本批 T10.1-⑥ 必须把 ledger 移入权威领域状态后再删 V1 路径。
- `destroy_gu` 双实现：v2 分派键保留在既有 resolver 实现（`v2_commands` 里的同名 handler 未接分派，防语义互换）——T10.1-⑧ 清理时二选一收敛。

---

## T10.1 §18 废止清单逐条删除（提交 1..N，可按族拆多个提交）

**纪律：只删不改。** 每族删除 = 先在 `tests/unit/test_legacy_abolition.gd` 写"旧符号不存在"断言（先红）→ 删除 → 绿。禁止顺手"改进"任何幸存代码；发现删除会破坏行为的，停下来报告而不是加兼容层。

| # | 废止族 | 删除对象（先 `rg` 核对现役引用） | 先行替代（已就位） |
| --- | --- | --- | --- |
| ① | 蛊槽硬上限族 | `deck_capacity.gd` 拒绝路径及全部引用 | 喂养软上限（FeedingRules.budget_report） |
| ② | 抽牌/手牌/弃牌/洗牌 | `deck_builder.gd`、battle 抽牌流、快照 `piles` 键 | 卡牌=实例操作界面（GuInstance） |
| ③ | 魂魄派生操作上限 | `soul_capacity.gd` 的 ops_cap/craft_cap 逻辑及测试 | 念头账本（Battle2TurnEngine + CultivatorRules.thought_capacity） |
| ④ | 升转自动加属性 | resolver/其他模块的升转增益路径 | 零增长模型（CultivatorRules.body，#5 断言在位） |
| ⑤ | 真元行动点重置 | 旧 action-point 重置、`action_points.gd`、`essence_capacity.gd` 旧路径 | 真元海百分比（GuBalance.actual_cost_percent/natural_recovery） |
| ⑥ | 连续时间单位族 | battle_resolver 连续时间/速度倍率换算/小数进度/全场排序段；**先落地 battle2 权威化**：ledger 从命令携带迁入领域状态（RunState/battle dict），`enact/dodge/grapple/respond` 改为从领域状态读写，再删 V1 战斗路径与 `battle_command_facade` 的 passthrough | 离散回合（Battle2 三模块，全部就位） |
| ⑦ | 身体部位族 | 若有部位/结构伤势残留 | 统一气血（§14.1） |
| ⑧ | 随机炼化/吞料/战后裁剪 | `success_roll_max` 存量条目（`bright_thread_risk`）、`_refine_gu` 随机路径、战后裁剪；`destroy_gu` 双实现收敛到一处（建议收敛到 resolver 既有实现，删 `v2_commands.destroy_gu` 未接线的平行体或对调，二选一写入报告） | 确定成功（RecipeRules.known_fixed_success） |
| ⑨ | 等值自动替代/灭蛊固定返还 | 旧替代与固定返还路径 | 身份规则（RecipeRules.check_identity）+ 声明式提取物（LootRules.destroy_gu） |
| ⑩ | 固定掉落组合/无来源抽象永久改造 | `loot_tables.loot.boss` 等固定组合及 resolver 读取段；无来源抽象改造 | 预算制（LootRules.budget_profile，生成专用） |
| ⑪ | 五道封闭枚举 | `content_catalog` 中"枚举即全部"的校验假设（schools 白名单仅限首批内容，不得拒绝新道标签） | 道标签开放集合（§0.1，首批 = 血气力魂炼） |
| ⑫ | 杀招强制统一沉重代价 | 杀招自动附加惩罚路径 | 成本由组成蛊+杀招规则决定（§11.3） |

- 每族删除后同步收缩 `resolver.gd`/`battle_resolver.gd` 行数；**同步回写三份契约文档**（删除的命令/键/词表移除或标注退役；`_REJECTION_TEXT` 里 `deck_capacity/gu_slot_full` 等废止 reason 一并清理）。
- AGENTS.md：删除完成后核对其中仍引用旧模型的段落（如"抽牌/手牌/槽满替换"表述的语境）并同步改写；不维护删除流水账。

## T10.2 迁移收尾与 18 条验收矩阵（提交 N）

- **存档终态**：`save_repository.gd` 大厅迁移最终形态固化（codex/recipes_unlocked/contract_unlocked/stats 零丢失）；v3 Run 拒载文案终审；废弃的运行中 Run 存档处理核对。
- **AGENTS.md 收尾**：把 2026-09-01 规格确认为唯一权威基线的表述定稿；清理遗留旧模型表述。
- **先红后绿**：新增 `tests/integration/test_spec_v4_acceptance.gd`——**§17.4 十八条逐条复验**（E2E：开局→战斗→喂养结算→炼蛊→交易→核心确认与更换→层推进；任一条红即阻断）。18 条与任务的挂接表见上级计划 §"验收矩阵"。
- **收尾验收命令**：
  - `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite all`
  - `powershell -ExecutionPolicy Bypass -File tools/check.ps1`
  - `tools/crash_recovery_check.ps1`（v4 存档下复跑 PASS）
- **门禁终值报告**：`resolver.gd`/`battle_resolver.gd` 行数报告——应显著低于删除前基线（2452/1514）；`test_resolver_growth_gate` 的 cap 在本批末**一次性下调**到终值（单向只降不升）。
- 契约三文档终审：删除项全部回写；`[T9/T10]` 占位清零。

---

## 全局纪律

1. 提交切分：每个废止族独立提交 `feat(spec-v4): T10.1-<n> abolish <族>` + 对应红测试先行；T10.2 单独提交。
2. **只删不改**：唯一例外是 ⑥ 的 battle2 权威化（ledger 迁入领域状态）——这是行为迁移，必须独立提交、附状态所有权说明（ledger 生命周期：new_turn 创建于战斗开始、start_turn 推进、快照只读投影）。
3. 每族删除后 `-Suite all` 必须全绿；18 条矩阵在 T10.2 前不要求，T10.2 一次收口。
4. 契约回写、EOF 守卫、禁区目录照旧；跨阶段缺陷报告不夹带。

## 完成报告要求（供审查）

逐项列出：每个提交 hash 与删除清单（文件/符号级）；12 族逐族的"删除符号 → 先红断言名 → 替代来源"对照表；⑥ 的 battle2 权威化迁移说明（ledger 所有权变更前后）；`destroy_gu` 收敛裁定；`resolver.gd`/`battle_resolver.gd` 删除前后行数账目与门禁终值；18 条矩阵逐条结果；四条收尾验收命令输出；`_REJECTION_TEXT` 清理清单；契约三文档回写 diff 摘要；AGENTS.md 改写点；未验证风险与遗留问题。

## 后续预告（非本批）

阶段十是后端主线收官。下一批为**前端页面生成批**：按页面清单 §5 顺序以契约 + 全局约束 + 已落地键生成真实页面（基础组件 → 低风险屏 → 中风险屏 → Refine/Battle 改造 → LayerSettle），届时审查加入真实渲染核对。
