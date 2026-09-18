# 模块接口：内容目录（content_catalog）

> 契约层级：领域层·数据地基。全项目唯一数据加载入口；任何模块取数据必须经本模块，禁止直接读 JSON 文件。  
> 仓库路径：`scripts/domain/content_catalog.gd`；数据目录：`data/`

## 职责

加载 `data/` 下全部 JSON 配置（蛊/敌人/事件/节点/配方/数值/裁定表），归一为 `catalog` 字典，并提供全量 Schema 校验（Agent 改数值后必跑）。

## 公开接口 

| 入口                        | 输入      | 输出                                 | 说明                       |
| ------------------------- | ------- | ---------------------------------- | ------------------------ |
| `load_all()`              | —       | Dictionary（catalog）                | 懒加载全量数据；**所有模块取数据的唯一入口** |
| `load_and_validate_all()` | —       | `{catalog, errors: Array[String]}` | 加载 + 全量校验（抛错清单）          |
| `validate(catalog)`       | catalog | `Array[String]`（errors）            | 纯校验，不加载；GUT/CI 用         |

## 关键数据契约（catalog 键）

- `gu_by_id`：蛊定义（802 项，`{id, tier, rank, school, role, rarity, v1_effect, is_permanent, durability_mode, ...}`）
- `enemies_by_id`：敌人定义（**32 项**，`{id, theme, grade, tier, rank, hp, clues, intent, reactions, phases?}`）。
  - `theme ∈ {beast, faction, cultivator, neutral, anomaly}`（白名单见 `enemy_catalog.THEMES`，缺失或未知即校验报错）。
  - `grade ∈ {mortal, beast, cultivator, anomaly}`（阶梯**类别**，与 `theme` 正交）。**战力阶梯**  
    （用户裁定 2026-09-10 + 原著 `CAN-CULTIVATION-001` / `CAN-BEAST-TIER-001`）：  
    **凡人 < 普通野兽 < 一转蛊修 < 二转 < 三转 < 四转 < 五转**。  
    `rank ∈ 0..5` 是**层位**（1..5 = 一至五转；0 = 未入转）。  
    **蛊修最低一转** ⇒ `grade=="cultivator"` 的条目 `rank` 必须 `>= 1`；  
    反过来 rank 0 只可能是非蛊修（普通野兽 / 凡人 / 不入转的异变体，如白毛僵尸）。
    > 散修 `theme=neutral` 但 `grade=cultivator`；山间猎户 `theme=neutral` 但 `grade=mortal`  
    > —— 所以类别必须独立于主题，不能靠 theme 反推。
  - `hp` 不得等于中心 `beast_scale(rank)` 值（100/200/400/800/1600/3200），否则必须给 `override_reason`。
  - `clues` **至少 2 条**（玩家出手前的敌情预警载体），守卫见 `test_b5_content_expansion.gd`。
  - **无 `turn` / `essence`**：两者在 V1 引擎中零消费点，已于 2026-09-10 退役（原校验一并删除）。
- `enemy_ids_by_theme`：`theme → [enemy_id]` 索引。
  - `enemy_catalog.enemy_pool(catalog, theme, fallback_ids)`：取主题池，**池空/未知主题一律回退，  
    绝不返回空数组**。
  - `enemy_catalog.roll_enemy_ids(catalog, theme, rank_min, rank_max, tier_weights, count, seed, salt, fallback)`：  
    E6 按层抽取（Boss 永不入选；同节点不重复；区间为空先放宽下界再回退）。
- `pacing.enemy_weights`：**tier 权重表**（`{common, elite, boss}`，非负整数）。  
  `boss` 必须为 **0** —— Boss 只在锚点摆放，随机抽到会让层节奏失效。
- `pacing.layers[N].enemy_rank_min / enemy_rank_max`：本层可随机到的敌人 rank 区间  
  （2026-09-10 取 `[0,1] / [0,2] / [1,3] / [2,4] / [3,5]`）；`max` 不得落后于层号。
- `nodes_data`：`{nodes[]}` 地图节点模板；`pacing`：`{layers{1..5}, ending_after_stage}`
  - `ending_after_stage`（**语义 2026-09-15 变更**）：层名（`"one".."five"`）或空串。  
    旧义「打掉该层关底即强制收官」已废弃；现义为「**收官可选起始层**」——击败该层关底后  
    `close_run` 开放（空串 = 打完任意关底即可主动收官）。生产值 `"one"`。  
    判据实现唯一：`scripts/domain/social_command_rules.gd::closure_available`。  
    注意 `pacing.layers` 以**层序数字**（`"1".."5"`）为键，层名需经 `MapGenerator.layer_index` 换算。
  - **`boss_pool`（2026-09-16 R9）**：仅允许出现在关底台（`layer_boss_stand_*`）上，≥2 个 boss id、  
    成员存在且 `tier == "boss"`、无重复。生成时由 `map_generator._roll_boss_for` 用**独立派生流**  
    `mixed_seed(seed, "boss_stand_" + 实例id, 0)` 抽取，并排除**相邻层**已抽中的 Boss  
    （排除后无候选则放弃排除）。池必须按 `hp × boss_layer_mult` 的**有效强度**分层  
    （层内差 ≤2、层间单调递增），**禁止全池随机**。  
    池缺失 / 目录不可用 / 池内无有效 id ⇒ 返回**空字典**，调用方保持模板自带的 `enemy_kind`  
    （回退即无池时的原行为）。门禁 `tools/verify_boss_variety.gd`。
  - **`event_pool`（2026-09-16 D4）**：仅允许挂在 `type == "event"` 的节点上，≥2 个真实 event id、无重复。  
    抽法与 `boss_pool` 同构：`mixed_seed(seed, "event_node_" + 实例id, 0)`，抽中 id 写入实例的  
    `event_id` / `dialogue_title`，同样**不消耗主 rng**。池不可用时回退模板自带 `event_id`。  
    门禁 `tools/verify_event_variety.gd`。
- `balance`：行为数值（`{retreat_stone_cost, cultivate_rank_two_stone_cost, ...}`，45 键）
  - 升转成本四键（**一转一突破 2026-09-15 新增后三键**）：`cultivate_rank_two_stone_cost`(5) /  
    `cultivate_rank_three_stone_cost`(12) / `cultivate_rank_four_stone_cost`(20) /  
    `cultivate_rank_five_stone_cost`(30)。读数唯一入口 `RefineCommandRules.cultivate_stone_cost`；  
    键名表锁在 `RefineCommandRules.CULTIVATE_COST_BALANCE_KEYS`（`test_data_driven_guard` 守卫）。
  - 真元上限曲线不在 balance：见 `aptitude.json.cultivation_factor`（1/3/9/27/81），  
    经 `EssenceCapacity.essence_max_for(state, catalog, rank)` 取用。
- `buffs`、`recipes`、`events`、`loot_tables`、`shops`、`aptitude`、`first_run`、`dialogue_templates`、`names`、`contracts`、`journal`
- `events`（**2026-09-16 由 2 条扩至 12 条**）：`{id, kind, title, summary, health_cost,
  delayed_soul_cost, delayed_trigger, curse_id, curse_bargain, stone_gain, known_risk,
  unknown_note, expected_gain}`
  - **四个真实杠杆**：`health_cost`（立即失血）/ `delayed_soul_cost`（行路时抽魂）/  
    `curse_id`（引用 `curse.json`，现 3 条）/ **`stone_gain`（2026-09-16 唯一新增的收益类型）**。
  - `title` / `summary` / `known_risk` / `unknown_note` / `expected_gain` 是**自描述文案字段**，  
    供遭遇卡直接消费。卡片文案必须由数值杠杆**派生**（`executable ← state.health > health_cost`  
    与 resolver 同一判据），**禁止在卡片侧硬编码数值**——反漂移守卫会拦截。
  - `stone_gain` 与 `health_cost` **同源读取**（预检提示与真实结算不得漂移）；结算在  
    `social_command_rules._accept_event`，与代价写在**同一条不可变事件日志**里，表现层无需另接通路。
  - **新增事件时必须同步 `data/dialogues/events.dialogue` 的 `~ <event_id>` 菜单块**，  
    否则对话气球点了悬空（Dialogue Manager 是真 autoload，气球才是事件主界面）；  
    `tools/verify_event_variety.gd` 的反空转 canary 会当场 FAIL。
  - `kind` 是**惰性字段**（只做白名单校验，`_accept_event` 不读它）——不要为"看起来完整"加枚举值。
- 实体字典识别前缀：`"gu_`/`"enemy_`/`"offer_`/`"event_`（守卫测试防硬编码的依据）

## 信号

无（纯函数式 domain 模块）。

## 依赖

- `data/` 下全部 JSON（gu/enemies/events/nodes/pacing/balance/buffs/recipes/loot_tables/shops/aptitude/first_run/dialogue_templates/names/contracts/journal）

## 强制规则（Agent 生成代码必读）

1. **禁止在脚本内直接 `FileAccess`/`load` 读 `data/` JSON**——一律经 `ContentCatalog.load_all()`。
2. 新增/修改数值只改 `data/` JSON，不碰业务代码；改动后跑 `load_and_validate_all` 校验。
3. 新增 balance 键必须同步 `_validate_balance` 的 `positive_keys`，否则校验抛错。
4. 实体字典字面量（以 `"id": "gu_...` 开头且含数值字段）禁止出现在 `scripts/` 业务代码（守卫 `test_data_driven_guard.gd` 自动拦截）。
