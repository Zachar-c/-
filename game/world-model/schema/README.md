# 世界模型 Schema 与字段说明表

> 验收项 **A1** 的证据文件：`world-model/schema/world-model.schema.json` 的每个实体、每个字段
> 都在这里有中文说明，并标注是否可调参。
>
> 机器可读的真源是 `world-model.schema.json`；本文件是它的中文对照表。
> 环境无 `jsonschema` 包，实际校验由 `world-model/schema/mini_schema.py`（仅标准库）完成。

## 0. 文档外壳（envelope）

`world-model/data/*.json` 的顶层一律是同一个外壳，`entity_type` 决定 `entities[]` 用哪个定义校验。

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `world_model_version` | string | 语义化版本 `x.y.z` | 是 | 世界模型版本，单一来源为 `world-model/VERSION` | 否 |
| `schema_id` | string | 常量 `gu-zhenren/world-model` | 是 | schema 标识 | 否 |
| `schema_version` | string | `x.y.z` | 是 | schema 版本 | 否 |
| `entity_type` | string | 见 §1 的 10 个取值 | 是 | 本文件承载的实体类型 | 否 |
| `generated_at` | string | UTC ISO8601 | 是 | 构建时间戳，由 `tools/build_world_model.py` 注入 | 否 |
| `generator` | string | 路径字符串 | 是 | 生成脚本 | 否 |
| `source_refs` | array&lt;string&gt; | 只读上游表路径 | 是 | 本文件派生自哪些 `data/*.json` | 否 |
| `count` | integer | ≥0，必须等于 `entities` 长度 | 是 | 实体条数；不符即报 `DataFormatError` | 否 |
| `entities` | array&lt;object&gt; | 至少 1 条 | 是 | 实体数组，逐项按 `entity_type` 校验 | — |

## 1. 实体类型（`entity_type`）

| 取值 | 数据文件 | 条数 | 说明 |
| --- | --- | --- | --- |
| `realm` | `realms.json` | 36 | 境界：1–9 转 × 初阶/中阶/高阶/巅峰 |
| `path` | `paths.json` | 20 | 道途 / 流派 |
| `gu` | `gu.json` | 802 | 蛊虫 |
| `economy` | `economy.json` | 1 | 资源与经济（含 8 种资源、37 条商店报价、黑市汇率、层预算） |
| `faction` | `factions.json` | 6 | 势力与关系（4 个原创势力 + 兽潮压力源 + 全局恶名轴） |
| `region` | `regions.json` | 7 | 地域与关卡（1 个宏观区域 + 5 层 + 升仙之窗） |
| `event` | `events.json` | 12 | 事件卡 |
| `loot` | `loot.json` | 1 | 遗物 / 战利品（80 种蛊材 + 2 件遗物 + 达标保底） |
| `balance` | `balance.json` | 1 | **集中参数表（验收 A5 的单点调参入口）** |
| `manifest` | `manifest.json` | 1 | 数据清单 + 每个文件的 sha256 |

## 2. 来源追溯字段（全部实体共有）

字段名与 `docs/lore/content-source-schema.md` 保持一致。

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `source_class` | string | `canon` \| `adaptation` \| `original_game_content` | 是 | 原著事实 / 兼容性游戏化 / 原创游戏内容 | 否 |
| `source_ids` | array&lt;string&gt; | 形如 `CAN-…` / `ADP-…` / `GAME-…` | 是 | 指向 `docs/lore/` 三份登记册的编号 | 否 |
| `canon_review_status` | string | `draft` \| `needs_source` \| `approved` \| `rejected` | 是 | 复核状态；仅 `approved` 可进可玩内容池 | 否 |
| `adaptation_note` | string | 自由文本 | 是 | `adaptation` 必填说明扩展或简化 | 否 |
| `tunable` | boolean | — | 是 | 该实体是否允许只改参数而不动世界规则 | 否 |

> `tunable` 是本任务新增的字段（`content-source-schema.md` 未定义）。它回答的是
> 「改这里算不算改世界规则」：`true` 表示可以安全调数值，`false` 表示改动会
> 牵动原著事实或已冻结口径。

---

## 3. `realm`（境界）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^r[1-9]_(initial\|middle\|upper\|peak)$` | 是 | 境界 id，如 `r1_initial` | 否 |
| `name_zh` | string | 非空 | 是 | 中文名，如「一转初阶」 | 否 |
| `rank` | integer | 1–9 | 是 | 转数（CAN-CULTIVATION-001） | 否 |
| `stage` | string | `initial`\|`middle`\|`upper`\|`peak` | 是 | 小境界 | 否 |
| `cultivator_class` | string | `gu_master`(1–5) \| `gu_immortal`(6–9) | 是 | 凡人蛊师 / 蛊仙（CAN-CULTIVATION-003） | 否 |
| `honorific` | string | `""` \| `venerable` | 否 | 九转称尊者 | 否 |
| `energy_type` | string | `primeval_essence` \| `immortal_essence` | 是 | 真元 / 仙元 | 否 |
| `essence_tier` | string\|null | `bronze`\|`iron`\|`silver`\|`gold`\|`amethyst`\|`null` | 否 | 真元品阶；**六转以上原著未明确，故为 null** | 否 |
| `essence_tier_zh` | string\|null | — | 否 | 青铜/赤铁/白银/黄金/紫晶 | 否 |
| `essence_tier_note` | string | — | 否 | 为什么为空 | 否 |
| `cultivation_factor` | integer | ≥1，取值 1/3/9/27/81/243… | 是 | 真元上限的转数乘子 | **是** |
| `essence_max_battle_base` | integer\|null | ≥1 | 否 | 战斗真元基准 10/30/60/100/150；6 转以上为 null | **是** |
| `load_capacity` | number | ≥0 | 否 | 肉身承载上限（`human_base_body_capacity`） | **是** |
| `thought_capacity_base` | integer | ≥0 | 否 | 局外念头容量（`thought_base_capacity`） | **是** |
| `body_anchor` | object | — | 否 | 凡人肉身三锚（health/strength/body_capacity） | **是** |
| `advance_to_next_rank` | object\|null | 含 `target_rank`/`cultivate_stone_cost`/`aptitude_gate` | 否 | 突破到下一转的条件 | **是** |
| `in_launch_scope` | boolean | — | 是 | 是否首发可玩（1–5 转为 true） | 否 |
| `is_immortal_tier` | boolean | — | 否 | 是否蛊仙层次 | 否 |

## 4. `path`（道途 / 流派）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^[a-z_]+$` | 是 | 流派 id（`blood`/`qi`/`force`/…） | 否 |
| `name_zh` | string | 非空 | 是 | 中文名，如「血道」 | 否 |
| `summary_zh` | string | — | 否 | 流派世界观描述 | 否 |
| `dao_tags` | array&lt;string&gt; | 开放集合 | 是 | 道标签；**不是封闭流派枚举** | **是** |
| `starter_gu_ids` | array&lt;string&gt; | ≥1，须存在于 `gu.json` | 是 | 该流派起始可用蛊 | **是** |
| `pool_gu_ids` | array&lt;string&gt; | 须存在于 `gu.json` | 是 | 流派典型蛊池 | **是** |
| `pool_size` | integer | ≥0，等于 `pool_gu_ids` 长度 | 是 | 池规模 | 否 |
| `pool_excluded_debug_entities` | array&lt;string&gt; | — | 否 | 被排除的调试实体（如 `test_slay_gu`） | 否 |
| `pool_ranks` | array&lt;integer&gt; | 1–9 | 否 | 池内出现的转数 | 否 |
| `conflict_paths` | array&lt;string&gt; | 须存在于 `paths.json` | 否 | 互斥流派（来自 `school_exclusions`） | **是** |
| `cross_school_penalty_per_extra` | number | ≥0 | 是 | 每多兼修一系的罚值 | **是** |
| `cross_school_exclusion_penalty` | number | ≥0 | 否 | 兼修互斥系的罚值 | **是** |
| `material_resonance` | integer | ≥0 | 否 | 本派蛊材的掉落共振加成 | **是** |
| `is_open_set` | boolean | — | 否 | 恒为 true：道标签是开放集合 | 否 |

## 5. `gu`（蛊虫）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^[a-z0-9_]+$` | 是 | 蛊 id | 否 |
| `name_zh` | string | 非空 | 是 | 中文名 | 否 |
| `rank` | integer | 1–9（`is_test_entity=true` 时可达 99） | 是 | 转数 | 否 |
| `rarity` | string | `common`\|`rare`\|`epic`\|`legendary` | 是 | 稀有度 | **是** |
| `school` | string | 须存在于 `paths.json` | 是 | 所属流派 | **是** |
| `role` | string | `attack`\|`defense`\|`support`\|`movement`\|`healing`\|`recon`\|`logistics` | 是 | 用途分类（非蛊槽） | **是** |
| `value` | integer | 0–999 | 是 | 定义字面价值（元石） | **是** |
| `tags` | array&lt;string&gt; | 非空、无空格 | 否 | 标签，驱动联动 | **是** |
| `activation_cost` | integer | 0–99 | 是 | 催发真元消耗 | **是** |
| `activation_cost_source` | string | `true_qi_cost`\|`essence_cost`\|`default` | 否 | 该消耗值的来源，便于核对口径 | 否 |
| `feeding` | object | `{stone_per_stage, feed_points_per_stage}` | 是 | 阶段末养护总账口径 | **是** |
| `effect` | object | `kind` ∈ strike/heal/shield/shift/status/heal_and_strike/composite/none | 是 | 战斗效果投影 | **是** |
| `effect_source` | string | `explicit`\|`combat_effects`\|`role_default` | 是 | **`role_default` = 只有角色兜底，不是独立效果** | 否 |
| `combat_key` | string | — | 否 | 原型的战斗行为键 | 否 |
| `low_rank_exception` | boolean | — | 否 | 是否豁免真元质量门禁 | 否 |
| `sword_mark_cost` | boolean | — | 否 | 是否消耗剑道道痕 | 否 |
| `life_cost` | integer | 0–99 | 否 | 催发时消耗寿元 | **是** |
| `is_test_entity` | boolean | — | 否 | 调试/越界实体，不进内容池 | 否 |
| `in_launch_scope` | boolean | — | 否 | 1–3 转且非测试实体 | 否 |
| `prototype_source` | string | `""`\|`novel`\|`school_derived` | 否 | 原型表的来源标记 | 否 |
| `refine_as_output` | array&lt;recipe_edge&gt; | 见下 | 否 | 以该蛊为产物的配方 | **是** |
| `refine_as_input` | array&lt;string&gt; | 配方 id | 否 | 以该蛊为输入的配方（反向索引） | 否 |
| `shop_offer_ids` | array&lt;string&gt; | 须存在于 `economy.shop_offers` | 否 | 哪些报价卖这只蛊 | 否 |
| `drop_tiers` | array&lt;string&gt; | 形如 `common:rare` | 否 | 出现在哪些掉落档 | 否 |

### `recipe_edge`（配方边）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `recipe_id` | string | — | 是 | 配方 id | 否 |
| `kind` | string | `advance`\|`fixed`\|`free_mix`\|`promotion` | 是 | 同名升阶 / 定式合炼 / 自由混合 / 定向晋升 | 否 |
| `input_gu_ids` | array&lt;string&gt; | 须存在于 `gu.json` | 是 | 输入蛊；**不含输出蛊自身**（advance 除外） | **是** |
| `materials` | object | 值为 0–999 的整数 | 是 | 蛊材消耗 | **是** |
| `stone_cost` | integer | 0–9999 | 是 | 元石消耗 | **是** |
| `output_gu_id` | string | 须存在于 `gu.json` | 是 | 产物蛊 | **是** |
| `output_rank` | integer\|null | 1–9 | 否 | 产物转数 | **是** |
| `default_unlocked` | boolean | — | 否 | 是否默认解锁 | **是** |

## 6. `economy`（资源与经济）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | — | 是 | 经济体 id | 否 |
| `name_zh` | string | — | 是 | 中文名 | 否 |
| `scope` | string | `mortal_run`\|`immortal_tier` | 否 | 适用范围 | 否 |
| `resources` | array&lt;resource&gt;（≥5） | 见下 | 是 | 8 种资源的产出/消耗渠道 | **是** |
| `price_anchors` | object | — | 是 | 价格锚：回购比、需求价档、删卡价等 | **是** |
| `battle_stone_rewards` | object | — | 否 | 战斗产石公式参数 | **是** |
| `layer_budget` | object | 层 → {石预算, 商店加价, 货架档位} | 是 | 每层预算 | **是** |
| `inflation` | object | — | 否 | 通胀参数（回头客/服务使用/层步进） | **是** |
| `black_market_exchange` | array&lt;exchange_rate&gt;（≥1） | 见下 | 是 | 黑市双向兑换 | **是** |
| `black_market_asymmetry_note` | string | — | 否 | 不对称性说明（风险项 RISK-06） | 否 |
| `shop_offer_histogram` | object | — | 否 | 报价种类计数 | 否 |
| `shop_offers` | array&lt;shop_offer&gt; | 见下 | 否 | 37 条报价全表 | **是** |
| `material_reference_prices` | object | 键须存在于 `loot.materials` | 否 | 每种蛊材的参考价与流动性 | **是** |

### `resource`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^[a-z_]+$` | 是 | 资源 id | 否 |
| `name_zh` | string | — | 是 | 元石/蛊材/寿元/魂/真元/气血/念头/仙元石 | 否 |
| `unit` | string | — | 是 | 计量单位 | 否 |
| `start_value` | integer\|null | ≥0 | 否 | 开局值 | **是** |
| `hard_cap` | integer\|string\|null | — | 否 | 硬上限，也可以是公式字符串 | **是** |
| `channels_in` / `channels_out` | array&lt;string&gt; | — | 是 | 产出/消耗渠道枚举 | **是** |
| `in_launch_scope` | boolean | — | 否 | 仙元石为 false（蛊仙阶段不参与凡人跑局） | 否 |
| `tunable` | boolean | — | 是 | 是否可调 | **是** |

### `exchange_rate`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `from` / `to` | string | 资源 id | 是 | 兑出 / 兑入资源 | **是** |
| `amount_in` / `amount_out` | integer | ≥1 | 是 | 数量 | **是** |

### `shop_offer`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | — | 是 | 报价 id | 否 |
| `kind` | string | `purchase`\|`material_purchase`\|`gu_fang_unlock`\|`recipe_unlock`\|`resource_trade`\|`lifespan_deal`\|`soul_boost`\|`barter`\|`wash_notoriety` | 是 | 报价类型 | **是** |
| `tier` | integer | 0–9 | 是 | 上架层位 | **是** |
| `card_key` | string | — | 是 | 表现层文案键 | 否 |
| `gu_id` / `material_id` | string | 须存在 | 否 | 标的物 | **是** |
| `stone_cost` | integer\|null | 0–9999 | 否 | 元石价格 | **是** |
| `lifespan_cost` | integer\|null | 0–999 | 否 | 寿元代价 | **是** |
| `soul_gain` | integer\|null | 0–99 | 否 | 魂收益 | **是** |
| `cost_kind`/`cost_amount`/`gain_kind`/`gain_amount` | — | — | 否 | 资源兑换的两端 | **是** |
| `input_gu_ids` | array&lt;string&gt; | 须存在 | 否 | 以蛊换蛊的输入 | **是** |
| `rewards` | array&lt;object&gt; | — | 否 | 随机奖励表（含遗物） | **是** |
| `recipe_id` | string | — | 否 | 解锁的配方 | **是** |
| `school` | string | — | 否 | 关联流派 | **是** |

## 7. `faction`（势力与关系）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^[a-z_]+$` | 是 | 势力 id | 否 |
| `name_zh` | string | — | 是 | 中文名 | 否 |
| `entity_kind` | string | `faction`\|`global_axis` | 是 | 势力 / 全局轴（恶名） | 否 |
| `summary_zh` | string | — | 否 | 势力定位 | 否 |
| `agents` | array&lt;string&gt; | 须存在于 `npc_roster` | 否 | 该势力的 NPC 成员 | **是** |
| `relation_levels` | array&lt;relation_level&gt;（≥2） | 见下 | 是 | 关系档位与阈值 | **是** |
| `route_effects` | object | — | 是 | 对路线/遭遇权重/撤离的影响 | **是** |
| `trade_effects` | object | — | 否 | 对价格与回购的影响 | **是** |
| `pursuit_effects` | object | — | 否 | 是否会被追杀及压力 | **是** |
| `notoriety` | object | — | 否 | 恶名收益与效果（仅全局轴） | **是** |

### `relation_level`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `hostile`\|`cold`\|`neutral`\|`warm`\|`honored` | 是 | 关系档位 | 否 |
| `label_zh` | string | — | 是 | 中文名 | 否 |
| `min_points` / `max_points` | integer | −999–999 | 是 | 该档的分值区间 | **是** |
| `price_pct` | number | −100–200 | 是 | 价格浮动百分比 | **是** |
| `hostile_chance_pct` | number | 0–100 | 否 | 转为敌意的概率 | **是** |
| `first_move_chance_pct` | number | 0–100 | 否 | 对方先手概率 | **是** |

## 8. `region`（地域与关卡）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | — | 是 | 地域 id（`south_jiang`/`layer_N`/`ascension_window`） | 否 |
| `name_zh` | string | — | 是 | 层名 | 否 |
| `entity_kind` | string | `macro_region`\|`layer`\|`special_stage` | 是 | 地域层级 | 否 |
| `layer` | integer\|null | 1–5 | 否 | 层号 | 否 |
| `rows_min` / `rows_max` | integer | 1–30，min ≤ max | 否 | 每层行数区间 | **是** |
| `row_nodes_min` / `row_nodes_max` | integer | 1–10，min ≤ max | 否 | 每行宽度区间 | **是** |
| `category_weights` | object | 各值 ≥0，**总和必须为 100** | 否 | 分类权重（battle/rest/unknown/trade） | **是** |
| `category_weight_sum` | number | ≥1，等于权重和 | 否 | 权重守恒校验用 | **是** |
| `anchors` | array&lt;object&gt; | `{template, row}` | 否 | 固定锚点（quarter/mid/pre_boss） | **是** |
| `node_pool` | array&lt;string&gt; | 须存在于 `node_templates` | 否 | 本层战斗池 | **是** |
| `stage_node_templates` | array&lt;string&gt; | 同上 | 否 | 本层 stage 的全部节点模板 | **是** |
| `boss_seat` | string\|null | 须存在于 `node_templates` | 否 | Boss 席位节点 id | **是** |
| `boss_pool` | array&lt;string&gt; | 须存在于 `enemy_roster` | 否 | Boss 候选（空=固定 Boss） | **是** |
| `final_boss` | string\|null | — | 否 | 固定场次时的 Boss | **是** |
| `boss_pool_is_fixed` | boolean | — | 否 | 是否固定 Boss | **是** |
| `enemy_rank_min` / `enemy_rank_max` | integer | 0–9，min ≤ max | 否 | 本层敌人转数区间 | **是** |
| `enemy_turn` | integer | 1–5 | 否 | 本层强度档位（驱动回合膨胀） | **是** |
| `loot_material_count` | integer | ≥0 | 否 | 本层掉落蛊材数量 | **是** |
| `loot_rarity_weights` | object | 各值 ≥0，**总和必须为 100** | 否 | 本层掉落稀有度权重 | **是** |
| `shop_price_pct` | number | 0–300 | 否 | 本层商店加价 | **是** |
| `shop_max_tier` | integer | 0–9 | 否 | 本层货架上限 | **是** |
| `stone_budget` | integer | 0–999 | 否 | 本层元石预算 | **是** |
| `enemy_pool` | array&lt;string&gt; | 须存在于 `enemy_roster` | 否 | 本层敌人池 | **是** |
| `enemy_roster` | array&lt;enemy&gt; | 仅 macro_region | 否 | 敌人名册（32 条） | **是** |
| `npc_roster` | array&lt;npc&gt; | 仅 macro_region | 否 | NPC 名册（5 条） | **是** |
| `node_templates` | array&lt;node_template&gt; | 仅 macro_region | 否 | 节点模板全表（37 条） | **是** |
| `template_pools` | object | 分类 → 模板 id 数组 | 否 | 分类抽取池 | **是** |
| `display_names` | object | — | 否 | 类型/动作/结局的中文名映射 | 否 |
| `map_structure` | object | 仅 macro_region | 否 | 5 层/节点预算等总览 | **是** |
| `travel_gate` | object | 仅 macro_region | 否 | 低转远游限制 | **是** |

### `enemy`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | — | 是 | 敌人 id | 否 |
| `name_zh` | string | — | 否 | 中文名 | 否 |
| `theme` | string | `beast`\|`faction`\|`cultivator`\|`anomaly`\|`neutral` | 是 | 主题 | **是** |
| `theme_zh` | string | — | 否 | 主题中文名 | 否 |
| `grade` | string | `mortal`\|`beast`\|`anomaly`\|`cultivator` | 是 | 战力阶梯档（CAN-RANK-LADDER-001） | **是** |
| `tier` | string | `common`\|`elite`\|`boss` | 是 | 杂兵/精英/层主 | **是** |
| `rank` | integer | 0–9 | 是 | 转数档（0 = 未入转） | **是** |
| `hp` | integer | 1–99 | 是 | 基础气血 | **是** |
| `intent` | object | 至少含 `id` | 是 | 当前意图 | **是** |
| `reactions` | array&lt;object&gt; | — | 否 | 受击反制 | **是** |
| `clues` | array&lt;string&gt; | — | 否 | 可侦查线索 | **是** |
| `phases` | array\|null | 每项含 `until_hp_ratio`/`intents` | 否 | Boss 相位（阈值严格递减） | **是** |
| `boss_layer` | integer\|null | 1–5 | 否 | 编入哪一层的 Boss 池 | **是** |
| `is_final_boss` | boolean | — | 否 | 是否终局 Boss | **是** |

### `node_template`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` / `name_zh` | string | — | 是 / 否 | 模板 id 与中文名 | 否 |
| `type` | string | `combat`\|`pursuit`\|`contact`\|`caravan`\|`market`\|`shop`\|`rest`\|`refinement`\|`cultivation`\|`ledger`\|`hazard`\|`inheritance`\|`wild_gu`\|`event`\|`earth_vein`\|`commission`\|`seclusion`\|`ascension` | 是 | 节点类型 | **是** |
| `type_zh` | string | — | 否 | 类型中文名 | 否 |
| `stage` | string | `one`–`five` | 是 | 所属层 | **是** |
| `visible` | boolean | — | 是 | 是否明示 | **是** |
| `summary_zh` | string | — | 否 | 场景描述 | **是** |
| `choices` | array&lt;string&gt; | — | 是 | 可选项全集 | **是** |
| `time_scale` | string | `hours`\|`days` | 是 | 时间尺度 | **是** |
| `on_skip` | string | — | 是 | 跳过后果 | **是** |
| `next_ids` | array&lt;string&gt; | 须存在于 `node_templates` | 否 | 后继节点 | **是** |
| `enemy_kind` / `enemy_kinds` | string / array | 须存在于 `enemy_roster` | 否 | 敌人 | **是** |
| `npc_id` | string | 须存在于 `npc_roster` | 否 | 关联 NPC | **是** |
| `layer_boss` | integer\|null | 1–5 | 否 | 是否为某层 Boss 席 | **是** |
| `boss_pool` | array&lt;string&gt; | — | 否 | Boss 池 | **是** |
| `event_pool` | array&lt;string&gt; | 须存在于 `events.json` | 否 | 事件池 | **是** |
| `event_id` | string | 须存在 | 否 | 固定事件 | **是** |

### `npc`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `^[a-z_]+$` | 是 | NPC id | 否 |
| `goals` | array&lt;string&gt; | — | 否 | 目标 | **是** |
| `bottom_line` | string | — | 否 | 底线 | **是** |
| `will` | integer | 0–10 | 是 | 意志强度 | **是** |
| `known_facts` | array&lt;string&gt; | — | 否 | 已知事实 | **是** |
| `retreat` | string | — | 否 | 退让条件 | **是** |
| `reinforcements` | string | — | 否 | 援手 | **是** |
| `injury_reaction` | string | — | 否 | 受伤反应 | **是** |
| `stock` | array&lt;string&gt; | — | 否 | 持有货品 | **是** |

## 9. `event`（事件卡）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` / `name_zh` | string | — | 是 | 事件 id 与标题 | 否 |
| `kind` | string | — | 否 | 母题（`delayed_cost`/`curse_bargain`/…） | **是** |
| `summary_zh` | string | — | 否 | 场景描述 | **是** |
| `trigger` | object | — | 是 | 触发条件（节点类型 + 种子抽取） | **是** |
| `options` | array&lt;event_option&gt;（≥2） | 见下 | 是 | 选项（必有接受/离开） | **是** |
| `gain_text_zh` / `unknown_note_zh` | string | — | 否 | 收益提示 / 未知后果提示 | **是** |
| `delayed_cost` | object | `{soul, trigger}` | 否 | 延迟代价 | **是** |
| `health_cost` / `stone_gain` | integer | 0–99 / 0–999 | 否 | 直接代价与收益 | **是** |
| `curse_id` | string | 须存在于 `event_curse_pool` | 否 | 绑定诅咒 | **是** |

### `event_option`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | `accept`\|`decline` | 是 | 选项 id | 否 |
| `label_zh` | string | — | 是 | 按钮文案 | **是** |
| `effects` | object | `{stone_gain, health_cost, delayed_soul_cost, delayed_trigger, curse_id, curse_name_zh}` | 是 | 结算读数 | **是** |
| `precheck_required` | boolean | — | 是 | 是否必须预检并提示 | **是** |
| `precheck_text_zh` | string | — | 否 | 预检提示文案 | **是** |

## 10. `loot`（遗物 / 战利品）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` / `name_zh` | string | — | 是 | 战利品体 id 与中文名 | 否 |
| `core_material_ids` | array&lt;string&gt; | 须存在于 `materials` | 是 | 7 种核心蛊材 | **是** |
| `materials` | array&lt;material&gt;（≥1） | 见下 | 是 | 80 种蛊材全表 | **是** |
| `relics` | array&lt;object&gt; | 含 `hooks` | 是 | 遗物表 | **是** |
| `tiers` | object | 必含 `common`/`elite`/`boss` | 是 | 分档掉落表 | **是** |
| `pity` | object | 必含 `threshold`/`clearing_rarities` | 是 | 达标保底 | **是** |
| `rarity_weights` | object | — | 否 | 各档稀有度权重 | **是** |
| `gu_drop_chance_pct` | object | 0–100 | 否 | 各档出蛊概率 | **是** |
| `sell_prices` | object | — | 否 | 回购比例 | **是** |
| `school_material_resonance` | integer | — | 否 | 流派蛊材共振 | **是** |

### `material`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` / `name_zh` | string | — | 是 | 蛊材 id 与中文名 | 否 |
| `value` | integer | 0–999 | 是 | 公开市场价值 | **是** |
| `value_tier` | integer | 0–9 | 否 | 价值档 | **是** |
| `rank` | integer | 0–9 | 否 | 转数档 | **是** |
| `reference_value` | integer | 0–9999 | 是 | 黑市/需求价基准 | **是** |
| `public_liquidity` | number | 0–1 | 是 | 公开市场可兑现比例 | **是** |
| `is_common` / `is_exclusive` / `divisible` / `is_core_material` | boolean | — | 否 | 属性标记 | **是** |
| `dao_tags` / `diet_tags` | array&lt;string&gt; | — | 否 | 道痕标签 / 食性标签 | **是** |
| `acquisition_mode` | string | — | 否 | 获取方式（`hunt`/`trade`/…） | **是** |
| `origin_status` | string | — | 否 | `original`/`design_extension` | 否 |
| `use` | object | — | 否 | 直接使用效果 | **是** |

## 11. `balance`（集中参数表）

> **验收 A5 的核心**：所有引擎逻辑都必须从这里读参数。改这里即可整体调参，
> 不需要改任何引擎代码。

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` / `name_zh` / `note_zh` | string | — | 是/否/否 | 标识与说明 | 否 |
| `growth` | object | — | 是 | 成长曲线：`essence_base`/`aptitude_factor`/`cultivation_factor`/`regen_pct_*`/`stage_base_battle`/`rank_step_ratio`/`standard_hit_ratio`/`human_base_*`/`thought_base_capacity`/`cultivate_stone_cost`/`aptitude_hard_gate`/`aptitude_reroll` | **是** |
| `run` | object | — | 是 | 运行结构：`starter`/`action_points_by_soul`/`layer_count`/`rest_heal_pct`/`rows_between_forced_rest`/`lifespan_milestones`/`turn_scaling`/`boss_layer_mult`/`max_seal_turns`/`retreat_stone_cost`/`feed_tier`/`death_axes`/`max_battle_rounds`/`stalemate_rule`/`difficulty` | **是** |
| `economy` | object | — | 是 | 经济：`gu_value_by_rank`/`public_buyback_ratio`/`demand_price_tiers`/`remove_*_cost`/`battle_stone_rewards`/`layer_stone_budget`/`layer_shop_price_pct`/`black_market_exchange`/`free_pair`/`free_mix_recipe`/`contracts`/`synthesis` | **是** |
| `loot` | object | — | 是 | 掉落：`pity_threshold`/`gu_chance_pct_by_tier`/`material_count_by_tier`/`rarity_weights_by_layer` | **是** |
| `combat_gate` | object | — | 否 | 战斗门禁：降转折价公式、`school_exclusions`、`reaction_multiplier` | **是** |
| `faction` | object | — | 否 | 恶名收益与效果 | **是** |
| `formulas` | object | — | 是 | 关键公式的书面记录（便于与实现对照） | 否 |

关键公式（与 `engine/rules.py` 一一对应）：

| 名称 | 公式 |
| --- | --- |
| `essence_max_out_of_run` | `essence_base * aptitude_factor * cultivation_factor` |
| `essence_max_battle` | `stage_base_battle[rank] * aptitude_factor` |
| `essence_regen_per_turn` | `ceil(essence_max * regen_pct_battle[aptitude] / 100)` |
| `standard_gu_power` | `human_base_health * standard_hit_ratio * rank_step_ratio^rank` |
| `fixed_defense` | `standard_gu_power(rank) * fixed_defense_ratio` |
| `actual_activation_cost_pct` | `native * rank_step_ratio^(gu_rank-1) / rank_step_ratio^(cultivator_rank-1)` |
| `beast_scale` | `human_base_health * rank_step_ratio^rank` |
| `battle_stone` | `base_by_tier[tier] + base_by_tier[tier] * layer_step_pct * (layer-1) / 100` |
| `action_points` | `action_points_by_soul` 中满足 `min_soul` 的最高档 |

## 12. `manifest`（数据清单）

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `id` | string | — | 是 | 清单 id | 否 |
| `version` | string | `x.y.z` | 是 | 世界模型版本 | 否 |
| `schema_version` | string | — | 是 | schema 版本 | 否 |
| `generated_at` | string | ISO8601 | 是 | 构建时间 | 否 |
| `files` | array&lt;manifest_entry&gt;（≥1） | 见下 | 是 | 逐文件清单 | 否 |
| `file_count` | integer | ≥1，等于 `files` 长度 | 是 | 文件数 | 否 |
| `total_bytes` | integer | ≥0 | 否 | 总字节 | 否 |
| `third_party_dependencies` | array | **必须为空** | 是 | 零第三方依赖的证据 | 否 |
| `read_only_upstream` | array&lt;string&gt; | — | 否 | 只读上游表清单 | 否 |
| `upstream_write_policy` | string | 常量 `read_only` | 否 | 只读承诺 | 否 |

### `manifest_entry`

| 字段名 | 类型 | 取值范围 | 必填 | 含义 | 可调参 |
| --- | --- | --- | --- | --- | --- |
| `path` | string | 相对仓库根 | 是 | 文件路径 | 否 |
| `entity_type` | string | §1 的 10 个取值之一（单数） | 是 | 实体类型 | 否 |
| `count` | integer | ≥0 | 是 | 实体条数 | 否 |
| `bytes` | integer | ≥0 | 是 | 字节数 | 否 |
| `sha256` | string | 64 位十六进制 | 是 | 内容哈希，用于检测漂移 | 否 |

---

## 13. 不支持 / 报错约定

| 情形 | 异常类型 | 退出表现 |
| --- | --- | --- |
| 数据文件不存在 | `DataMissingError` | CLI 启动打印 `[启动失败] data_missing: …`，退出码 2 |
| JSON 解析失败 / `entity_type` 不符 / `count` 不符 / 重复 id / schema 违规 | `DataFormatError` | 同上 |
| 存档校验和不符 / 版本不兼容 / 类型不符 | `SaveCorruptError` | 损坏存档被隔离为 `run.corrupt.json`，提示可从大厅开新局 |
| 资源不足 | `ResourceExhausted` | 交互模式回显「无法执行」并留在原地 |
| 越级催蛊 | `GuBacklash` | `strict` 模式零副作用抛错（供预检）；`strict=False` 为「强催」路径，先扣反噬自伤 |
| 数值越界（如蛊仙阶段战斗真元、未定义转数成本、Meta 数值成长） | `NumericOverflow` | 明确报错，不静默夹取 |
