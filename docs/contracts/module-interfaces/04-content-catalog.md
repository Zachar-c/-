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
- `enemies_by_id`：敌人定义（12 项，`{id, tier, rank, hp, turn, essence, clues, intent, reactions}`）
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
