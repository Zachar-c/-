# Soul System Audit（魂道体系现状盘点，只读）

> 任务：`ai-system/tasks/soul-system-audit.md`。本报告只盘点现状，不下数值结论，不提数值建议。
> 标注约定：`[FACT]` 附 `文件:行号`；`[INFERRED]` 附推理链（供 L1 参考，非建议）；
> `[UNKNOWN]` 写明缺什么。裁定语境见 `game/world-model/rulings/RUL-2026-09-19-004.json`。

## Q1. soul 当前值与上限是否分离？现状是什么？

- [FACT] `soul`（当前值）与 `soul_max`（上限）是两个独立键，在同一处定义：
  `game/scripts/domain/run_state.gd:115-116`（`new_run` 初始 `cultivator` 字典：`"soul": 1, "soul_max": 4`）。
  世界模型侧同样分离：`game/world-model/engine/run.py:73`（`starter["soul"]` / `starter["soul_max"]`），
  上游数据 `game/world-model/data/balance.json:110-111`（`run.starter` 含 `soul: 1, soul_max: 4`），
  构建器 `game/world-model/tools/build_world_model.py:898-899` 写死同一对值。
- [FACT] 上限是硬顶，无任何机制改变上限。全树只有**读** `soul_max`、无一处**写**：
  写入 `soul` 的全部路径都被钳制在上限内——
  商店魂丹 `game/scripts/domain/shop_command_rules.gd:325-328`（`soul >= soul_max` 拒单 `soul_at_max`，
  `soul_after` 未再钳制但前置拒单保证不超）；
  黑市兑换 `game/scripts/domain/economy_rules.gd:134-137`（`mini(soul + gain, soul_max)`）；
  调试 `game/scripts/domain/debug_actions.gd:105-110`（`clampi(..., 1, soul_max)`）；
  世界模型钳制 `game/world-model/engine/run.py:190-192`（`st["soul"] = min(st["soul"], st["soul_max"])`）。
  `rg soul_max game/scripts` 全部命中均为读取或初始定义（见上列文件），零写入路径。
- [FACT] 消费侧（读 `soul` 的系统）：行动点分档 `ActionPoints.per_turn(soul)`
  （`game/scripts/domain/action_points.gd:14-18`）；战斗多线/炼蛊上限 `SoulCapacity`
  （`game/scripts/domain/soul_capacity.gd:15-24`，`battle_ops_cap` = soul 值本身，
  `craft_cap_for_soul` 按 5/3 两档）；死亡判定（三轴之一，
  世界模型 `game/world-model/engine/rules.py:556-573`，阈值 `stats_soul_death_threshold = 0`，
  `game/world-model/data/balance.json:213`）；UI 死亡线展示（魂 floor=2 预警，
  `game/scripts/presentation/run_snapshot_builder.gd:631-632,641-644,664-671`）。
- [FACT] `SoulRules` 的 `soul_safe_capacity` 与 `soul_max` 是**两套互不相通的"上限"概念**。
  `soul_safe_capacity` 定义于 `game/scripts/domain/soul_rules.gd:64-69`（`refine_soul` 可无上限累加）、
  初始 4.0（`run_state.gd:121`）；注释明示新旧两套键永不互碰：
  `soul_rules.gd:10-11`（"never touch the legacy soul / soul_max / soul_control_limit"），
  `run_state.gd:118-119`（"the legacy soul keys above are T10.1 retirement scope and never feed these"）。
  `soul_safe_capacity` 是软顶（`float_above_capacity` 允许超载可视化，
  `soul_rules.gd:101-102`；致死线为容量的 `soul_burst_capacity_ratio = 2.0` 倍，
  `game/data/balance.json:59`，`soul_rules.gd:108-117`），与 `soul_max` 的硬顶语义完全不同。
  两者初始值同为 4 系属巧合，无代码关联。[INFERRED] 同值 4 可能是刻意对齐的过渡设计，
  但仓库内无注释说明此关系，供 L1 参考。

## Q2. 现有 AP 门槛的原始设计意图

- [FACT] 当前生效数据（世界模型与 Godot 共用一张表，语义一致）：
  `game/world-model/data/balance.json:118-124`（`run.action_points_by_soul` =
  min_soul 10000/1000/100/10/0 → AP 6/5/4/3/2）；
  构建器 `game/world-model/tools/build_world_model.py:900-901` 同值；
  引擎消费 `game/world-model/engine/rules.py:116-120`（`action_points(wm, soul)` 首个满足 `soul >= min_soul` 即返）；
  Godot 侧 `game/scripts/domain/action_points.gd:11`（`SOUL_ACTION_TIERS = [[10000,6],[1000,5],[100,4],[10,3]]`，兜底返 2，
  即 0–9 → 2，与 min_soul 0 → 2 等价）。
- [FACT] 两处文档口径：`game/docs/superpowers/specs/2026-09-01-v1-battle-schema.md:66-77`
  写全五档（`<10（含 1）→ 2 / 10–99 → 3 / 100–999 → 4 / 1000–9999 → 5 / ≥10000 → 6`），与数据完全一致；
  `game/docs/wiki/concepts/world-model-translation.md:21` 写「1/10/100/10000 底蕴 → 2/3/4/5/6 次」，
  漏写 1000 档（五个档位本应有五个阈值，此处只列四个且跳过 1000）。
- [FACT] 代码注释 `action_points.gd:5-6` 同样写「1/10/100/1000/10000+ → 2/3/4/5/6」，阈值齐全（1000 在列），
  仅首阈值记为 1 而非 0/10（1 是开局值语义，0–9 同档，数值行为一致）。
- [INFERRED] 原意判定链：2026-09-01 战斗规格（五档全表）+ 代码常量（四阈值 + 兜底 2）+ 构建器/数据（五项全表）
  三方互锁且彼此一致，唯 translation.md 一行漏写 1000。translation.md 该表是"小说概念→游戏机制"映射总表的一行，
  非门槛定义的源头文件。故数据口径（10/100/1000/10000）为原意，wiki 行是摘录笔误。供 L1 参考，非建议。
- [UNKNOWN] 何时改的：无法从仓库判定。`git log` 显示 `action_points.gd` 与 `balance.json`
  均只有单条导入提交 `ebb7f81`（monorepo 迁移导入，无上游逐次历史），`git log --oneline -3` 无更早记录。
  已查：`git log` 两文件、代码注释、2026-09-01 规格、translation.md 上下文。需上游 Gitee 历史才能追溯。

## Q3. 哪些蛊 / 事件 / 资源可以增长魂魄

> 增长对象是 legacy `soul`（上限 4 硬顶内 +1 类操作）；`SoulRules` 侧增长见 Q7。

- [FACT] 商店魂丹：`game/data/shops.json:4-10`（`id: soul_pill, kind: soul_boost, stone_cost: 6, soul_gain: 1, tier: 2`）；
  结算 `shop_command_rules.gd:320-339`（扣石、soul+1、上限拒单）；NPC 货架两处有售：
  `game/data/npcs.json:11`（货郎 stock 含 `soul_pill`）、`npcs.json:32`（第二 NPC stock 仅 `soul_pill`）。
  频率上限：[UNKNOWN] 商店刷新/补货规则未在本任务范围内查到（`shops.json` 无刷新字段，需查商店刷新机制，缺）。
- [FACT] 黑市兑换（双向）：`game/data/shops.json:136-173`——
  `lifespan 20 → soul 1`（`black_market_lifespan_for_soul`）、`health 20 → soul 1`
  （`black_market_health_for_soul`）；结算钳制见 Q1（`economy_rules.gd:134-137`）。
  代价明确，可否无限刷：[UNKNOWN] 黑市交易次数/冷却限制未查到（需查黑市命令规则，缺）。
- [FACT] `SoulRules.absorb_soul` 命令：`game/scripts/domain/run_command_rules.gd:262-275`
 （`collect_soul` 定 yield → `strengthen_soul` 加到 `soul_magnitude`），经
  `game/scripts/domain/resolver.gd:212` 注册进命令路由，契约测试覆盖
  （`game/tests/unit/test_command_contract.gd:140`、`test_command_rejections_v2.gd:154-156`）。
  但 means（capacity/efficiency/loss）的声明来源：[UNKNOWN] 仓库内未见任何调用方传入真实 means
  配置（除测试外），即收集通道有引擎、无数据源。缺：means 配置表或掉落来源。
- [FACT] 事件中**无**直接 `soul_gain`：`rg soul_gain game/data` 仅命中 `shops.json:8`（魂丹字段），
  `events.json` 6 条魂相关全是 `delayed_soul_cost` 扣除（见 Q4），零增长事件。
- [FACT] 蛊/遗物/契约/天赋增长魂：未发现。`school == "soul"` 40 蛊中唯一显式 `v1_effect`
  是 `soul_def_2_10_gu` 的 `{kind: status, name: sealed, amount: 1}`（`game/data/gu.json`vardump 实测），
  与魂增长无关；`relics.json / contracts.json / loot_tables.json` 中 `soul` 命中仅为魂材料
  （`mat_soul_1..4`，`loot_tables.json:314-1903`，用途为炼蛊材料 promotions，非直接加魂）；
  `contracts.json:32` 唯一魂外机制是 `hp_max_penalty: -2`（代价侧，见 Q6）。
- [INFERRED] 当前 soul 增长全图：魂丹（石→魂）+ 黑市（寿/血→魂）两条，且都被 `soul_max` 硬顶截断；
  means 驱动的 `soul_magnitude` 增长通道引擎就绪但无数据源。供 L1 参考。

## Q4. 哪些能力消耗或攻击魂魄

- [FACT] 消耗侧（扣 legacy soul）：
  1. 炼蛊配方 `soul_cost`：全表 468 配方中仅 1 处——`game/data/refinement_recipes.json:4816`
    （`free_mix` 失败分支 `explosion`：`health_cost: 2, soul_cost: 1, lifespan_cost: 1`），
     结算 `game/scripts/domain/refine_command_rules.gd:420`（`soul - soul_cost`，floor 0）。
  2. 事件延迟魂代价：`game/data/events.json` 6 条——`echo_cave:1, gu_rot_pact:1, small_beast_tide:1,
     tide_aftermath:2, weird_trade:1, contract_seal:2`；Godot 侧先挂账
     （`social_command_rules.gd:145` → `pending_delayed_soul_drain`，出行结算扣减
     `social_command_rules.gd:603-614`），世界模型侧同语义
     （`engine/run.py:564-568` 挂账 → `_resolve_delayed` `run.py:311-322` 扣减）；
     预览提示 `action_preview_service.gd:886-895`。
  3. 黑市反向兑换 soul→寿/血（`shops.json:146-173`，`economy_rules.gd:119-123`，floor 1 保护）。
- [FACT] 攻击侧（敌方意图 `soul_drain`）：全 `enemies.json` 仅 1 敌——
  `game/data/enemies.json:548`（`demon_path_adept`，`intent{id: soul_gnaw, kind: soul_drain, soul_drain: 1, damage: 0}`）；
  Python 实测 `soul_drain enemies: 1`。Godot 结算 `v1_battle_resolver.gd:935-937`（player soul - drain）；
  世界模型结算 `engine/rules.py:528-531`（同语义，事件 `soul_drained`）。
  世界模型 regions 同步 1 处同类意图（`world-model/data/regions.json:2941-2942`，`kind: soul_drain, soul_drain: 1`）。
- [FACT] 玩家 → 敌人的魂攻击通道：**不存在**。`game/data/v1_battle.json / synthesis.json / buffs.json / curse.json`
  中 `soul` 零命中；敌人意图 kind 枚举（`v1-battle-schema.md:103-104`）只有敌方 `soul_drain`；
  40 魂道蛊唯一 `v1_effect` 为 defense 挂 `sealed` 状态（Q3），非魂伤害；
  `soul_drain` 全树消费点均为"敌方意图 → 扣玩家 soul"方向（`battle_command_facade.gd:177` 快照亦只透出敌方值）。
  玩家侧魂相关战斗能力零条目。

## Q5. 魂道构筑闭环现状：获得 → 养魂 → 使用 → 强化

- [FACT] 骨架数字（Python 实测 `game/data/gu.json`，与 L2 已核一致）：
  40 只，rank 1–5 = 11/10/9/4/6；role attack17/def5/mov5/heal5/recon4/log4（源文件 role 键为
  defense/movement/healing/logistics，L2 口径 defense/def 等为缩写）；
  仅 1 只有显式 `v1_effect`（`soul_def_2_10_gu`，见 Q3）。
- [FACT] 获得：`schools.json:32-41`（魂道词条「掌魂魄之壮养收摄…」，starter 4 只
  `soul_atk_1_02/04/05/06_gu`）；`school_pools.json:592-631`（soul 池 40 只全列）。
  缺：除 starter/池子外无魂道专属掉落加成证据（loot 侧魂材料 `mat_soul_*` 为通用炼蛊材料，非魂道专属）。
- [FACT] 养魂（持有/成长）：数据层缺——40 魂蛊除 1 只外无 `v1_effect`、喂养字段只存在于 16 只核心蛊
  （`world-model-translation.md` 行"仅 16 只核心蛊有喂养字段"语义，魂蛊是否在内 [UNKNOWN]，需逐只核对 feed 字段，缺）。
  引擎层半就绪——`SoulRules.strengthen/refine/calm`（`soul_rules.gd:56-77`）+ `absorb_soul` 命令（Q3），
  但 means 无数据源（Q3 [UNKNOWN]）。
- [FACT] 使用（战斗/行动）：legacy soul 驱动行动点（Q1）+ `SoulCapacity` 双上限
  （`soul_capacity.gd`，注记 T10.1 待退役，`soul_capacity.gd:5-9`）；魂道蛊作为战斗单位与其他流派同权参战
  （school 仅标签，开放集合，`game/AGENTS.md` 道标签条）。缺：魂道蛊无魂特异战斗语义
  （39/40 无 `v1_effect`，魂攻击通道不存在，Q4）。
- [FACT] 强化（合成/晋升）：有独立晋升路径外形——30 条 `advance_soul_*` 配方
  （`refinement_recipes.json`，`advance_soul_atk_1_02_gu` 等，Python 实测 soul 相关 30 条全为 advance 类，
  键内无 `soul_cost`，即晋升不耗魂）；魂材料 `mat_soul_1..4` 存在（`loot_tables.json`）但标注
  design_only/provisional 语义门（`loot_tables.json:1853-1903` rationale 行）。
  缺：晋升配方是否消耗魂材料 [UNKNOWN]（配方 materials 字段未逐条核对，缺）。
- [INFERRED] 闭环四环现状一句话：获得（有：starter+池）→ 养魂（半：引擎有/数据无）→
  使用（弱：只剩通用行动点杠杆）→ 强化（形：advance 配方在，代价不明）。供 L1 参考。

## Q6. 魂与诸 Build Axis 的机会成本与克制关系

Build Axis 对照表（现状口径，键与文件见行内证据）：

| 轴 | 来源 | 消费者 | 可成长 | 死亡阈值 |
|---|---|---|---|---|
| 真元 essence | 开局 20（`run_state.gd` cave_aperture essence 20，上 40 行外，同文件族）；元石兑换 `stone_to_essence_per_stone = 5 × 资质吸收率`（`balance.json:18`，`essence_capacity.gd:37-44`） | 催动蛊/炼蛊 `attune_gu` 代价 `4+2*(rank-1)`（AGENTS Stage1 记录行）；敌 `essence_burn`（`rules.py:532-535`） | 是（上限/回复，`essence_max/regen`） | 无 |
| 气血 hp | 开局 80/80（`run_state.gd`）；黑市 soul→health（`shops.json:166-173`） | 战斗伤害；炼蛊 explosion（`health_cost: 2`）；契约 `hp_max_penalty: -2`（`contracts.json:32`） | 否（上限只被动削） | 有（`death_axes` 含 hp，阈值 0） |
| 寿元 lifespan | 开局 60/60（`run_state.gd`）；黑市 soul→lifespan 10（`shops.json:146-153`） | 杀招/洗髓/洗恶名/黑市（translation.md:22 行）；炼蛊 explosion（`lifespan_cost: 1`）；敌 `life_cost`（`rules.py` 同上） | 否 | 有（阈值 0） |
| 魂 soul（legacy） | 魂丹（石 6→魂 1）；黑市 寿/血 20→魂 1；开局 1（Q1/Q3） | AP 分档；SoulCapacity 双上限；explosion `soul_cost: 1`；事件延迟代价；敌 soul_drain | 否（硬顶 4，Q1） | 有（阈值 0，`rules.py:556-573`） |
| 魂五量 SoulRules | `absorb_soul`（means 缺，Q3）；`refine/calm` 操作（调用方缺） | 快照展示（`run_snapshot_builder.gd:883-887`）；forecast/endpoint 标记 | 是（magnitude/capacity/calm 三操作，`soul_rules.gd:56-77`） | 无（只产确认标记，`soul_rules.gd:12-13,105-117,148-161`） |
| 念头 thought | 回合回满 = AP 表（`v1-battle-schema.md:74` 行）；`thought_base_capacity = 3`（`balance.json:11`，非战斗上限） | 每次行动耗 1（同上） | 否（派生值） | 无 |
| 蛊/构筑 gu | starter/池/掉落/合成（Q5）；开局 `small_light_gu`（`run_state.gd`） | 战斗；合成材料（468 配方） | 是（数量/转数，实例制无通用硬上限，AGENTS 红线） | 无（蛊死≠人死） |
| 元石/材料 stone | 节点/事件/售卖；开局 12（`balance.json:110` starter 行） | 魂丹；炼蛊；真元兑换 | 否（纯库存） | 无 |

- [FACT] 已知兑换关系（全部有文件）：石↔真元（`stone_to_essence`）；寿↔魂↔血（黑市四单，`shops.json:136-173`）；
  石→魂（魂丹）；资质→真元效率乘数（`essence_capacity.gd:44` rate，`aptitude_recovery_multiplier = 0.5`，
  `balance.json:17`）。
- [FACT] 已知克制/互斥：契约 `hp_max_penalty`（`contracts.json:32`，拿增益换上限，永久性未核对 [UNKNOWN]）；
  跨流派代价 `cross_school_penalty_per_extra`（`content_catalog.gd:1470` 键名，数值语义 [UNKNOWN]，未展开）；
  炼蛊 explosion 三轴同扣（health 2 + soul 1 + lifespan 1，`refinement_recipes.json:4810-4821`）。
- [INFERRED] 机会成本存在处：石（魂丹 vs 炼蛊/真元）、寿（黑市换魂 vs 存活冗余 vs 杀招支付）、
  血（黑市换魂 vs 战斗容错）；不存在处：SoulRules 五量与其他轴零兑换（引擎孤岛）；蛊数量轴与魂轴无直接兑换。
  供 L1 参考。

## Q7（附加）. 两套魂系统的关系

| 维度 | legacy `soul`/`soul_max` | SoulRules 五量 |
|---|---|---|
| 定义 | `run_state.gd:114-124`（cultivator 键，soul 1/soul_max 4/control_limit 2 + 五量初值） | 同文件 120-124 初值；规则 `soul_rules.gd:1-161` |
| 调参 | 无专属调参（上限写死，阈值 0 写死） | `balance.json:59-64`（burst 比 2.0 / calm 三阈 40/25/10 / beast 双阈 0.5/1.0） |
| 消费者 | AP、SoulCapacity、战斗结算、死亡判定、黑市、商店、事件、UI 死亡线（Q1/Q3/Q4 实列） | 快照展示（`run_snapshot_builder.gd:883-887`）+ `absorb_soul` 写 magnitude（`run_command_rules.gd:262-275`）+ 测试（`test_soul_rules.gd`、`test_snapshot_transparency_v2.gd:174-178`、`test_spec_v4_acceptance.gd:196-198`） |
| 互通 | 无（双向注释隔离，Q1） | 无 |
| 死亡力 | 有（三轴之一） | 无（只产标记） |

- [FACT] 「SoulRules 零消费者」不成立。展示消费者（snapshot/composure/beast_sight/float/forecast 五键，
  `run_snapshot_builder.gd:883-887`）+ 写消费者（`absorb_soul`，`resolver.gd:212` 路由注册，
  契约测试覆盖）+ 三组测试文件。销售/战斗/死亡等**玩法**消费者为零（无一条玩法规则读五量），
  准确表述应为"零玩法消费者、有展示与命令消费者"。
- [FACT] 承载 Build Axis 的事实差异（不给推荐）：legacy 有全链路玩法接线但硬顶 4 且零成长操作；
  五量有成长操作（strengthen/refine/calm 三函数）+ 可调参 + 软顶语义，但玩法接线为零且 means 数据源缺失。
  第三套魂机制：未发现（`soul_control_limit` 仅初值出现，`test` 外无读写，可视为 legacy 残留键而非第三套；
  `mat_soul_*` 为材料非机制）。

## 现状 vs 产品意图（RUL-2026-09-19-004 四重身份）差距清单

裁定要：①魂魄生存值 ②魂道能力资源 ③魂道攻防基础 ④长期成长属性。

| 身份 | 现有支撑 | 缺口在数据层还是引擎层 |
|---|---|---|
| ①生存值 | 有：三轴死亡（阈值 0）+ soul_drain 1 敌 + 事件延迟代价 6 条 + UI 死亡线 | 基本具备；敌方魂攻只有 1 敌（数据层薄） |
| ②能力资源 | 半：soul 是 AP/多线/炼蛊上限的输入，但没有"花魂放技能"的玩家侧能力（Q4 不存在通道） | 引擎层缺（玩家侧魂消耗能力）+ 数据层缺（魂道蛊 39/40 无 effect） |
| ③攻防基础 | 弱：防（`SoulCapacity` 上限、1 只 sealed 魂蛊）有残片；攻（玩家→敌魂伤害）零 | 数据层缺（39 只 effect 空）+ 引擎层缺（魂伤害结算通道） |
| ④长期成长 | 裂：legacy 零成长（硬顶）；五量有成长引擎无数据源（means 缺） | 两套各缺一半：legacy 缺成长操作（引擎+数据），五量缺数据源与玩法接线（数据+引擎） |

## 魂相关字段/通道总表

| 字段/通道 | 位置 | 来源 → 消费者 | 可成长 |
|---|---|---|---|
| `soul` | `run_state.gd:115` | 魂丹/黑市/开局 → AP/SoulCapacity/战斗/死亡/UI | 否 |
| `soul_max` | `run_state.gd:116` | 开局常量 → 全部钳制 | 否（硬顶，无写入） |
| `soul_control_limit` | `run_state.gd:117` | 残留初值 2 → 无消费者 | —（死键） |
| `soul_magnitude` | `run_state.gd:120`，`soul_rules.gd:56-61` | absorb_soul → 快照/forecast | 是（操作），数据源缺 |
| `soul_safe_capacity` | `run_state.gd:121`，`soul_rules.gd:64-69` | refine_soul（调用方缺）→ burst 线 | 是（操作），调用方缺 |
| `soul_calm` | `run_state.gd:122`，`soul_rules.gd:72-77` | calm_soul（调用方缺）→ composure 三层 | 是（操作 0-100），调用方缺 |
| `soul_nature/beast_nature` | `run_state.gd:123-124`，`soul_rules.gd:40-52,131-161` | set_nature（调用方缺）→ beast_sight/endpoint | 名义 |
| `soul_gain`（魂丹） | `shops.json:8` | 石 6 → soul+1（`shop_command_rules.gd:320-339`） | —（单次 +1，上限截） |
| `delayed_soul_cost` | `events.json` 6 条 | 事件接受 → 延迟扣 soul | —（消耗） |
| `soul_cost`（炼蛊） | `refinement_recipes.json:4816` | free_mix 爆炸 → soul-1 | —（消耗） |
| `soul_drain`（敌） | `enemies.json:548`（1 敌） | 敌意图 → player soul-1 | —（攻击输入） |
| `mat_soul_1..4` | `loot_tables.json:314-1903` | 掉落 → 炼蛊材料（design_only） | — |
| AP 档位表 | `balance.json:118-124` / `action_points.gd:11` | soul 值 → 回合行动数 | 否 |

## 附：证据强度说明与 UNKNOWN 清单

1. 商店刷新/补货规则（魂丹能否无限刷）——缺，需查商店刷新机制文件。
2. 黑市交易次数/冷却限制——缺，需查黑市命令规则。
3. `absorb_soul` 的 means 数据源——缺，全树除测试外无真实 means 配置。
4. 魂蛊 feed/喂养字段归属（16 只核心蛊是否含魂蛊）——缺，需逐只核对 `gu.json` feed 键。
5. 30 条 advance_soul 配方 materials 是否含魂材料——缺，需逐条核对。
6. Q2 门槛变更时间——缺，上游 Gitee 历史（本仓仅 `ebb7f81` 单导入提交）。
7. `cross_school_penalty_per_extra` 数值语义——缺，未展开。
8. 契约 `hp_max_penalty` 是否永久——缺，需查契约结算。
9. lore/wiki 原著魂道口径——弱：`魂魄` 全 wiki 仅 2 文件 3 命中
   （`lore/wiki/gu/fate-gu.md:46`、`lore/wiki/events/story-arc-overview.md:79,104`，上下文为命运/战役叙述，
   非魂道机制蒸馏），魂道 doctrine 尚无蒸馏条目。可辨识为缺口，非事实。

---

## L2 附录（审计后追加 · 关联 RUL-2026-09-19-005）

> 本附录由 L2 在审计交付后追加，不属于原审计范围。结论均由 L2 独立复算，附可复现命令。

### 附录 1：40 只魂道蛊在原文的落点（约 858 万字全本统计 + 语境抽查）[FACT]

**方法**：以 `gu_names.json` 现有 776 个蛊名做**最长匹配切词**再统计整词频次。
不能用 `text.count(名字)` 直接数——短名会被长名包含。实测反例：`灯蛊` 裸数 40 次，
其中 39 次来自 `魂灯蛊`、1 次来自 `兜率灯蛊`，**独立出现 0 次**；`魅蛊` 裸数 26 次，整词 0 次。

第一步，整词频次（40 只魂道蛊）：

| 有整词命中（9 只） | 次数 | 零命中（31 只） |
|---|---|---|
| 净魂仙蛊 | 105 | 其余全部 31 只 |
| 魂蛊 | 78 | |
| 命牌蛊 | 47 | |
| 魂灯蛊 | 39 | |
| 阴蛊 | 14 | |
| 魄蛊 | 5 | |
| 摄魂蛊 / 灵蛊 / 落魄蛊 | 2 / 2 / 1 | |

第二步，**逐名抽查语境**——命中不等于真名，多数是别的词被切出来的。抽查结果：

| 名字 | 语境真相 | 判定 |
|---|---|---|
| 落魄蛊 | 唯一 1 次命中是「……是一个无奈转为仙僵的**落魄蛊仙**」，即「落魄」+「蛊仙」两个词挨在一起 | **不是蛊名**，是切词误伤 |
| 魄蛊 | 命中全在「气魄蛊、体魄蛊、云魄蛊、风魄蛊、虎魄蛊」这类长名内部 | **不是独立蛊名** |
| 阴蛊 | 命中全是「阴阳转身蛊」的阴 / 阳两半（「你已用了那阴蛊，必须用我手中这只阳蛊」） | **不是独立蛊名**，是成对蛊的一半 |
| 灵蛊 | 命中是「阵灵蛊」被切开 | **不是独立蛊名** |
| 魂蛊 | 多数命中在「神魂蛊、龙魂蛊、冰魂蛊……」里，疑为「魂道蛊虫」的通用简称 | **存疑**，非明确的具体蛊名 |
| 摄魂蛊 | 「羊枯一共有三只魂道仙蛊，可惜接下来的两只中并无**摄魂蛊**存在」「这只仙蛊却是**摄魂蛊**了」 | **确认是原文蛊名**（魂道仙蛊） |
| 净魂仙蛊 | 「这**净魂仙蛊**能精炼蛊仙魂魄，将杂质魂魄剔除出体」「这只净魂仙蛊，便是杀招万我的核心蛊」 | **确认是原文蛊名**，且为杀招核心 |
| 命牌蛊 / 魂灯蛊 | 「武樵又为方源当场炼出了**魂灯蛊、命牌蛊**……置放在武家的宗祠之中，算是方源正式认祖归宗的标志」 | **确认是原文蛊名** |

- [FACT] **结论：40 只里能在原文站住的只有 4 只**——摄魂蛊、净魂仙蛊、命牌蛊、魂灯蛊。
  余下 36 只中，31 只零命中（可判为编造），5 只命中系切词误伤（已在上表逐一说明）。
- [FACT] 另一组独立证据指向同一方向：40 只里 20 只名字是「魂」/「魂魂」+ 既有名的机械拼接
  （魂灯蛊除外——见下条），且其中大量「词根」本身在原文也是 0 命中
  （`冥蛊` 0、`幽蛊` 0、`鬼蛊` 0、`煞蛊` 0、`精灵蛊` 0、`英灵蛊` 0、`幽灵蛊` 0、`魄光蛊` 0、`影蛊` 0）。
  即：不是「拿真蛊名套壳」，而是**词根和套壳都是编的**。
- [FACT] 一个反直觉的反例：`魂灯蛊` 是**原文真名**（39 次，武家宗祠体系），
  而挂在火流派的 `灯蛊` 原文独立出现 0 次——**方向很可能是「从真名 魂灯蛊 剥掉魂字造出火蛊 灯蛊」**，
  与附录 1 第一版的假设相反，特此更正。
- [UNKNOWN] 上述 5 只「切词误伤」是否另有独立含义、以及 `魂蛊` 是否为正式蛊名，
  需按语境逐条核定，已列入交付 Worker 的问题清单（附录 4）。

### 附录 2：原文真实存在、但当前数据里没有的魂道蛊 [FACT]

原文中有一份明确的**「能凝魂」蛊虫名录**（同一句列出）：

> 「……虽然没有落魄谷，但是我却可以用其他魂道蛊虫代替。神魂蛊、龙魂蛊、冰魂蛊、梦魂蛊、月魂蛊、
> 将魂蛊、怨魂蛊、诗魂蛊、马魂蛊、英魂蛊、气魄蛊、体魄蛊、云魄蛊、风魄蛊、虎魄蛊种种。
> 这些蛊虫，都能凝魂。」

- [FACT] 该名录 **15 只全部不在** `gu_names.json` 的 802 条中。
- [FACT] `狼魂蛊` 在原文 **50 次**，且信息量极大：
  - 有转数与市价：「三转的**狼魂蛊**，一只售价七千七百枚元石」；
  - 有叠加规则：「**狼魂蛊**的效用可以叠加，一只三转的狼魂蛊还不足以凝练方源的**百人魂**」；
  - 有改造方向：「若是方源凝练成**狼魂**，对他奴役狼群也多有帮助」，且「自古奴魂不分家」。
  - **不在** `gu_names.json` 的 802 条中。
- [FACT] `落魄谷` 是**地名**不是蛊：「炼魂首选**落魄谷**中的\*\*雾、落魄风」——
  这解释了「落魄」584 次命中里绝大部分的来源。
- [FACT] 用户点名的 `挡尸蛊`、`兽魂蛊`、`撞魂` 在原文**零命中**；
  但 `僵尸蛊` 8 次、`尸蛊` 32 次、`狼魂蛊` 50 次命中——名字写法与用户记忆有出入，
  需按概念检索（已列入 Worker 清单）。
- [FACT] 原文文本中 `**` 是清洗过程的替换残留（如「\*\*魂首选荡魂山胆识蛊」），
  读原文证据时须注意该占位符，勿当成原文用字。
- [FACT] 魂道蛊 40 只中，除 `soul_def_2_10_gu` 外全部无显式效果（见 Q5）；
  叠加「40 只中 36 只在原文无着落」——魂道内容整体处于**占位状态**，不是「弱」，是「没有」。

### 附录 3：本附录关闭的审计待办 [FACT]

- Q1 的取向（当前值是否与上限分离）→ 已由 `RUL-2026-09-19-005` 裁定：**需要分离**。
- Q2 的 [UNKNOWN]（门槛原始设计意图）→ 已由 `RUL-2026-09-19-005` 回答：
  参照原文的百人魂 / 千人魂 / 万人魂，各自对应一个档位；数据口径 100 / 1000 / 10000 确为原意。
  L2 复核：原文 `百人魂` 44、`千人魂` 30、`万人魂` 62 次命中，三档确为原文概念。
- Q2 的 [UNKNOWN]（何时改的）→ **保持 UNKNOWN**，本仓无更早历史，需上游 Gitee。
- 原文正典主张（挡尸蛊撞魂 / 落魄蛊炼魂 / 狼魂蛊改造人魂 / 百千万人魂三档）
  → 已由本附录部分回答，其余登记在 `RUL-2026-09-19-005.canon_claims_pending_verification`。

### 附录 4：交给原文核验 Worker 的问题清单 [待办]

> **第 1 问已由 L0 回答并由 L2 取证落档**（`RUL-2026-09-19-006`）：
> `魂魄底蕴` = **魂道的修为**，是可增长的积累量，单位为「人魂」，
> 阶梯为 百人魂 → 千人魂 → 万人魂 → 十万人魂 → 百万人魂 → 千万人魂 → 亿人魂（原文最大 46 次提到 亿人魂）。
> 直接证据：L185618「这就是魂道的极致吗？魂魄由虚返实，干涉物质，凝如肉身……**这样的魂魄底蕴，绝对远超亿人魂**」。
> 其余 7 问仍待 Worker 核验。
> **注意**：现有游戏的 `soul` / `soul_max` 是 1 / 4，与原文的百 → 亿数量级不在同一标度上——
> 如何换算属数值设计，后置 L1，本审计不下结论。

1. ~~`魂魄底蕴` 在原文 187 次——**它到底指什么**~~ → **已回答**（见上，`RUL-2026-09-19-006`）

2. `百人魂 / 千人魂 / 万人魂` 三档的**完整语境**：如何达到、有何差别、是否有更高档。
   （部分已答：原文确有更高档，阶梯至 亿人魂；成长手段含 壮魂 / 炼魂 / 安魂 / 凝魂 四类）
3. `狼魂蛊` → `狼魂` 的改造过程：`人魂` 改 `兽魂` 的原文表述、代价与后果。
4. 用户记忆中的 `挡尸蛊 / 撞魂` 对应原文哪个概念（候选：`僵尸蛊` 8 次、`尸蛊` 32 次）。
5. 「能凝魂」名录 15 只的完整语境与共同机制（凝魂 = 什么操作）。
6. `落魄谷` 的炼魂三首选（壮魂 / 炼魂 / 安魂）全貌，含 `荡魂山`、`安魂汤`。
7. 魂道蛊的**喂养 / 成长**在原文如何运作（狼魂蛊可叠加 8 只即为一例）。
8. 魂道与白/黑/血/骨等其他流派的**克制与兑换**关系在原文有无表述。
