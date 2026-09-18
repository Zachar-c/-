# 模块接口：蛊实体与合成（gu_instance + synthesis_rules + recipe_rules）

> 契约层级：领域层。蛊实例是跨模块流通的唯一实体形态，禁止绕过本模块手工拼实例字典。
> 仓库路径：`scripts/domain/gu_instance.gd`、`scripts/domain/synthesis_rules.gd`、`scripts/domain/recipe_rules.gd`

## 职责

蛊实例的生命周期（创建/归一/存档）与合成判定（固定配方 + 跨流派配对映射）；实例 ID 唯一性由 `run_state` 维护。

## 公开接口

| 入口 | 输入 | 输出 | 说明 |
|---|---|---|---|
| `GuInstance.new_instance(definition_id, instance_id, catalog, extra)` | 定义 ID + 实例 ID | Dictionary（归一化实例） | 唯一合法创建路径 |
| `GuInstance.normalize(instance)` | 实例字典 | 实例字典 | 补默认字段，保证下游读取安全 |
| `GuInstance.consume_definition_instances(instances, stored, inputs)` | 仓 + 洞天投影 + 输入 ID 列表 | void | 合成后消耗材料蛊（就地移除） |
| `GuInstance.transaction_ledger(instances, aperture, output_gu_id, catalog, inputs, output_rank)` | 合成输入输出 | Dictionary（台账） | 产出+消耗留痕，供事件日志 |
| `GuInstance.max_refined_rank(instances, gu_id)` | 实例仓 | int | 图鉴/升级展示用 |
| `SynthesisRules.pair_output_id(main_id, partner_id, catalog)` | 双蛊定义 ID | String（输出蛊 ID） | 古方知识模型：配对映射函数，取代 mx_ 表 |
| `SynthesisRules.pair_preview(state, catalog, main_instance_id, partner_instance_id)` | 实例 ID 对 | `{ok, output_id, chance, ...}` | 预检三层揭示（合成前可看） |
| `SynthesisRules.execute(state, catalog, main_instance_id, partner_instance_id)` | 实例 ID 对 | `{ok, state, output, ...}` | 执行合炼，含首炼授予/古方持有判定 |
| `RecipeRules.known_fixed_success(recipe, inputs_ready, unlocked, interrupted)` | 固定配方状态 | `{ok, reason}` | 旧固定配方路径（仍用于校验） |

## 关键数据契约

- 实例：`{instance_id, definition_id, state ∈ {raw/refined}, rank, extra...}`；持久化用 `to_save_data/from_save_data`
- 蛊定义：`data/gu.json` → `{id, tier, rank, school, role, rarity, v1_effect, is_permanent, durability_mode, ...}`
- 配方：`data/refinement_recipes.json`（固定配方）；合成方向由配对映射函数（D1b 古方知识模型）决定

## 信号

无（纯函数式 domain 模块）。

## 依赖

- `content_catalog.gd`（蛊定义/配方表）；`run_state.gd`（gu_instances/refined_gu_ids）
- `data/gu.json`、`data/refinement_recipes.json`；`seeded_roll.gd`（roll_chance）

## 强制规则（Agent 生成代码必读）

1. 创建蛊实例只走 `GuInstance.new_instance`；禁止在 resolver/UI 直接 `{ "instance_id": ... }` 字面量。
2. 合成消耗输入蛊必须经 `consume_definition_instances`，且只允许 `state=="refined"` 实例参与。
3. 改合成数值/配方只改 `data/` JSON；`synthesis_rules.gd` 不出现具体蛊 ID 或成本常量。
4. 输出蛊品质/转阶影响由配对映射函数返回，禁止在调用方二次推导。
