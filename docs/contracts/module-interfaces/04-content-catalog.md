# 模块接口：内容目录（content_catalog）

> 契约层级：领域层·数据地基。全项目唯一数据加载入口；任何模块取数据必须经本模块，禁止直接读 JSON 文件。
> 仓库路径：`scripts/domain/content_catalog.gd`；数据目录：`data/`

## 职责

加载 `data/` 下全部 JSON 配置（蛊/敌人/事件/节点/配方/数值/裁定表），归一为 `catalog` 字典，并提供全量 Schema 校验（Agent 改数值后必跑）。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `load_all()` | — | Dictionary（catalog） | 懒加载全量数据；**所有模块取数据的唯一入口** |
| `load_and_validate_all()` | — | `{catalog, errors: Array[String]}` | 加载 + 全量校验（抛错清单） |
| `validate(catalog)` | catalog | `Array[String]`（errors） | 纯校验，不加载；GUT/CI 用 |

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
- `balance`：行为数值（`{retreat_stone_cost, cultivate_rank_two_stone_cost, ...}`，42 键）
- `buffs`、`recipes`、`events`、`loot_tables`、`shops`、`aptitude`、`first_run`、`dialogue_templates`、`names`、`contracts`、`journal`
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
