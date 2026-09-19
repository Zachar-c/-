# Caveman Review Packet

```text
TASK soul-system-audit
PHASE RUL-2026-09-19-004 / Soul System Audit
STATUS READY_FOR_SOUL_SYSTEM_REVIEW
TYPE content
ASK L2 确认审计口径可交付 L1（魂道闭环设计事实底座）；Q2 门槛史是否接受 UNKNOWN 结论

GOAL
只读盘点魂体系现状（Q1-Q7），不下数值结论，不改数值
范围外：数值建议、Build Axis 取舍、两套魂系统选型（均未做）

DELTA
+ game/world-model/reports/soul-system-audit.md（审计报告，Q1-Q7 + 双总表 + 差距清单）
+ ai-system/tasks/soul-system-audit-result.md（本包）
~ NONE
- NONE
= 全仓其余文件零改动（除两个新文件）

STATE
OpenCode + Muse Spark 1.3 — PARTIALLY VERIFIED（Godot 软件工程低风险可用）

FILES
game/world-model/reports/soul-system-audit.md — 新增审计报告
ai-system/tasks/soul-system-audit-result.md — 新增 Review Packet

TEST
focused: python 實測 gu.json（40 只，rank 11/10/9/4/6，role 17/5/5/5/4/4，仅 1 只 v1_effect）→ PASS，与 L2 已核一致
relevant: python 實測 enemies.json（soul_drain 仅 1 敌 demon_path_adept）/ events.json（delayed_soul_cost 6 条）/ refinement_recipes.json（468 中 soul 相关 30 条全为 advance，无 soul_cost；唯一 soul_cost 在 free_mix explosion）→ PASS
full: BLOCKED + 纯只读审计任务，无代码改动，不跑 Godot 全量（285+ 脚本无关）
diff-check: 待终检 git status --porcelain（只许两个新文件）

WORKER
normal worker
core patch: NO
tests: YES（python 实测 counts）
protocol: YES
Codex takeover: NONE
independent: YES

RISK
R1 Q2 门槛变更时间 UNKNOWN（本仓仅 ebb7f81 单导入提交，无上游历史；已查 git log/注释/规格）— pre-existing，不阻塞审计交付，L1 设计不受影响
R2 absorb_soul 的 means 全树无真实数据源（除测试）— pre-existing，五量增长通道引擎就绪但接不上数据，L1 必须知悉
R3 商店刷新/黑市冷却/advance 配方 materials/魂蛊 feed 归属 4 项 UNKNOWN（已列缺什么）— pre-existing，不阻塞，L1 可派单补查
R4 lore/wiki 魂道 doctrine 零蒸馏（魂魄仅 2 文件 3 命中，命运/战役上下文）— pre-existing，原著口径缺
UNPROVEN translation.md 漏写 1000 系笔误（INFERRED，三方互锁链，L1 参考用；严格原意需上游提交确认）

GIT
status: 待终检（执行前满屏已存改动均非本任务，目标两路径确认空闲后写入）
commit: NONE
merge: NONE
push: NO

DECISION
D1 SoulRules 是否零消费者 | recommend NO | 有展示消费者（run_snapshot_builder.gd:883-887）+ 命令消费者（absorb_soul 经 resolver.gd:212）+ 3 组测试；准确表述为零玩法消费者
D2 玩家→敌魂攻击通道 | recommend 不存在 | v1_battle/synthesis/buffs/curse 零 soul 命中，40 魂蛊唯一 effect 为 sealed，soul_drain 全树皆敌→我方向
D3 soul_max 是否可变 | recommend 不可变 | 全树零写入路径，四处消费全钳制，上限写死 run_state.gd:116

NEXT
1. 终检 git status --porcelain（除两新文件零改动）
2. L2 Review 后转 L1 研究院
3. L1 可选补查：UNKNOWN 清单 9 项（报告附节）
STOP

EVIDENCE
game/scripts/domain/run_state.gd:114-124；soul_rules.gd:1-161；action_points.gd:1-18
game/world-model/engine/rules.py:116-120,528-531,556-573；engine/run.py:73,190-192,311-322,564-568
game/world-model/data/balance.json:110-124,213-217；tools/build_world_model.py:895-901
game/data/shops.json:4-10,136-173；events.json（echo_cave/gu_rot_pact/small_beast_tide/tide_aftermath/weird_trade/contract_seal）；enemies.json:548；refinement_recipes.json:4816；schools.json:32-41；school_pools.json:592-631；contracts.json:32；loot_tables.json:314-1903；balance.json:11,17-18,59-64
game/scripts/domain/shop_command_rules.gd:320-339；economy_rules.gd:119-137；refine_command_rules.gd:420；v1_battle_resolver.gd:930-937；social_command_rules.gd:145,603-614；run_command_rules.gd:262-275；resolver.gd:212；run_snapshot_builder.gd:615-671,883-887；soul_capacity.gd:1-24；debug_actions.gd:105-110；action_preview_service.gd:886-895
game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md:66-77,103-104；game/docs/wiki/concepts/world-model-translation.md:21
```

FACT 魂丹 soul_pill（石 6→魂 1，shops.json:4-10）+ 黑市寿/血 20→魂 1（shops.json:136-173）为仅有两条 soul 增长链，均被 soul_max 硬顶截断
FACT 敌魂攻全表仅 demon_path_adept 1 敌（enemies.json:548，soul_drain 1）；事件魂代价 6 条；炼蛊 soul_cost 仅 free_mix 爆炸 1 处（refinement_recipes.json:4816）
FACT 40 魂蛊 rank 11/10/9/4/6、仅 soul_def_2_10_gu 有显式 v1_effect（sealed）；30 条 advance_soul 配方无 soul_cost
ANALYSIS 两套魂零互通（注释双向隔离）；legacy 有玩法接线无成长，SoulRules 有成长引擎无数据源；闭环呈获得有/养魂半/使用弱/强化形
UNCHECKED Q2 变更时间；商店刷新；黑市冷却；means 数据源；advance materials；魂蛊 feed；cross_school 数值；hp_max_penalty 永久性；wiki 魂道蒸馏

---

# L2 Review（Codex Orchestrator，2026-09-19）

```text
REVIEW STATUS: PASS WITH FOLLOW-UP
```

## 已独立复核（L2 亲自执行，不采信自述）

| 审计结论 | 我的复核方式 | 结果 |
|---|---|---|
| Q1 `soul`/`soul_max` 分离、硬顶 4、无写入路径 | 读 `run_state.gd:114-124`、`soul_rules.gd:8-13` | ✅ 原文含 `"soul": 1, "soul_max": 4, "soul_control_limit": 2` 与隔离注释 "never touch the legacy soul / soul_max / soul_control_limit" |
| Q2 数据口径（10/100/1000/10000）为原意 | 读 `action_points.gd:5-11` | ✅ 注释写「1/10/100/1000/10000+ → 2/3/4/5/6」，常量 `SOUL_ACTION_TIERS = [[10000,6],[1000,5],[100,4],[10,3]]` + 兜底 2；与数据、规格三方一致 |
| Q4 敌魂攻仅 1 敌 | Python 实测 `enemies.json` | ✅ `demon_path_adept` / 噬魂魔功，`soul_drain: 1, damage: 0`，全表唯一 |
| Q4 炼蛊 `soul_cost` 仅 1 处 | Python 实测 `refinement_recipes.json` | ✅ 仅 `free_mix` |
| Q5 魂道蛊 40 只 / 仅 1 只有显式效果 | Python 实测 `gu.json` | ✅ 40 只，rank 11/10/9/4/6，唯一 `soul_def_2_10_gu` = `{status, sealed, 1}` |
| Q6 `essence` 开局 20 | 读 `run_state.gd:14-15,138-140` | ✅ 数值正确（原引用措辞偏笼统，事实无误） |
| Q7 五量有展示消费者 | 读 `run_snapshot_builder.gd:883-887` | ✅ 实调 `snapshot / composure_layers / beast_sight / float_above_capacity / soul_growth_forecast` |
| 无魂道机制蒸馏条目 | `grep -rn 魂魄 lore/wiki/` | ✅ 仅 2 文件 3 命中（`story-arc-overview.md:79,104`、`fate-gu.md:46`），均为叙述非机制 |
| 交付件含数值建议 | Python 扫 12 个建议类措辞 | ✅ 零命中 |
| 证据标注密度 | 计数 | ✅ `[FACT]` 25 / `[INFERRED]` 6 / `[UNKNOWN]` 10 |

## 对 L2 自身错误的更正（重要）

**我在 Task Packet 里写「`SoulRules` 零消费者」，这是错的。** Worker 正确地推翻了它：
五量有**展示消费者**（快照五键）+ **写消费者**（`absorb_soul` 经 `resolver.gd:212` 注册、契约测试覆盖）
+ 三组测试文件。准确表述是「**零玩法消费者**、有展示与命令消费者」。
已在报告中按 Worker 的更正口径保留，L2 不再沿用旧表述。

## FIX（L2 执行）

- 报告 Q2 第 3 条含一个**不属于本文的异体字符**（阿拉伯文 "خمس"）；已删除并改为「五个档位本应有五个阈值」。
  修复后复检：全文无阿拉伯字符，225 行。

## 对 Worker 提问的答复

| Worker 提问 | L2 裁定 |
|---|---|
| 审计口径可否交付 L1 | **可以**。Q1–Q7 均有证据标注，L2 已抽验 7 条承重结论全部成立 |
| Q2 门槛史结论接受 UNKNOWN 吗 | **接受**。`git log` 对 `action_points.gd` 与 `balance.json` 均只有 `ebb7f81` 单条导入提交，本仓结构上不可能追溯；已写明需上游 Gitee 历史 |
| `translation.md` 漏写 1000 系笔误 | **暂按 INFERRED 处理**，不升为定论。三方互锁（规格全表 / 代码常量 / 数据表）足以支撑「数据口径为原意」，但"何时、为何漏写"无证据 |

## 可交付 L1 的状态

`STATUS: READY_FOR_SOUL_SYSTEM_REVIEW` —— 事实底座已就绪，
RR-1（魂道闭环结构与跨轴机会成本）现在可以送 L1 研究院。

L2 不代替 L1/L0 做以下判断：魂的定位取向、两套魂系统选哪套承载、Build Axis 取舍、任何数值。
