# 附录：F1–F7 审计详表

> ## ⚠️ **本附录 D 部分（F4 晋升经济）有 2 处事实已于 2026-09-12 实测更正**
>
> 更正正文：`docs/q8g/Q8G_BATCH0_RULING.md` §13。要点：
> **① `advance` 确实升转**（实例 rank+1）；**② sword 升转链有完整成本**（12–60 石 + 材料），
> **真正免费的是 5 条 light 系 `fixed`**。原错误源于**提取脚本漏读 `stone_cost` 与 `materials` 字段**。
> 附录其余部分（F1/F2/F3/F5/F6/F7、F4 的链路结构）**经复核准确，无需更正**。

> 本文件是 Q8-F 审计的可查证底稿。**日常裁定不必读**，仅在需要逐条核实证据时查阅。
> 标注：`[FACT]` = 代码/数据实测；`[INFERRED]` = 推导；`[GAP]` = 定义存在但无消费者。

---

# A. F1 经济现状审计

## A.1 元石收入通道（全量）`[FACT]`

| 通道 | 位置 | 触发 | 增量 | 性质 |
|---|---|---|---|---|
| 卖蛊 `sell_gu` | `refine_command_rules.gd:55` | 卖出持有蛊 | `GuBalance.gu_value(gu, rank)` | 取决于价值表 |
| 卖材料 `sell_material` | `refine_command_rules.gd:777,789` | 卖出材料 | `materials[id].value × 持有` | 数据驱动 |
| 打工 `work` | `social_command_rules.gd:724` | 遭遇动作 | **硬编码 +3** | 固定 |
| 采集 `harvest` | `social_command_rules.gd:726` | 遭遇动作 | **硬编码 +2** | 固定 |
| 欺骗 `deceive` | `social_command_rules.gd:51` | 接触散修 | **硬编码 +2** | 固定 |
| 开局 buff `grant_stones` | `run_opening_flow.gd:43` | 开局遗物/契约 | buff `amount` | 一次性 |
| 立誓契约 `starter_stone` | `run_opening_flow.gd:150` | 开局契约 | `ContractRules.aggregate` | 一次性 |
| ~~遗物 `grant_stone_on_battle_end`~~ | `relic_hook_resolver.gd:108` | — | — | **[GAP] 死通道** |

**问题**：三条主要收入全是**硬编码小数字（+2/+3/+2）**，与层数、转数、敌强度**完全无关**。
层 5 打工赚 3 石，层 1 也赚 3 石 → **高层购买力被通胀（+50% 价格）单方面侵蚀**。

## A.2 元石支出通道（全量）`[FACT]`

| 通道 | 位置 | 价格来源 | 值域 |
|---|---|---|---|
| 炼蛊配方 | `refine_command_rules.gd:251` | recipe `stone_cost` | 6/10/12/24/40/50/60 |
| 晋升二转 | `refine_command_rules.gd:384` | `cultivate_rank_two_stone_cost` | 5 |
| 删卡 | `refine_command_rules.gd:546` | `remove_card_cost` | 120（+服务涨价） |
| 拔印记 | `refine_command_rules.gd:590` | `remove_imprint_cost` | 150 |
| 喂蛊 | `refine_command_rules.gd:663` | `estimate_feeding` | 变动 |
| 买蛊 | `shop_command_rules.gd:255` | offer `stone_cost` × 层加价 | 6–80 |
| 买材料 | `shop_command_rules.gd:272` | offer `stone_cost` | 3 / 10 / 60 |
| 古方解锁 | `shop_command_rules.gd:290` | offer `stone_cost` | 60–200 |
| 配方解锁 | `shop_command_rules.gd:305` | offer `stone_cost` | 60–200 |
| 魂丹 | `shop_command_rules.gd:328` | offer `stone_cost` | 6 |
| 升资质 | `shop_command_rules.gd:389` | `path.cost_stone` | 变动 |
| 合成（成败均扣） | `synthesis_rules.gd:148,175` | 配方 `stone_cost[rank]` | 变动 |
| 接触撤退 | `social_command_rules.gd:60` | **硬编码 −1** | 1 |
| 买机会/情报 | `social_command_rules.gd:253,627,802` | 命令 `cost` / **硬编码 −2** | 2 |
| ~~元石补真元~~ | `essence_capacity.gd:37` | — | **[GAP] 预览读数，无命令** |

**问题**：删卡/拔印记（120/150）与收入量级严重脱节 → **几乎不可达**。
炼蛊 raw cost 极低（6/10 占 220/157 条）而古方 60–200 →
**"解锁古方"是真正的元石 sink，"炼蛊过程"几乎免费**。

## A.3 七种蛊材全字段 `[FACT]`

| id | 名称 | value | tier | 参考价 | dao_tags | diet_tags | 流动性 | 可分 | 常见 | 专属 | use |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `beast_bone` | 兽骨 | 1 | 1 | 5 | force | meat, bone | 0.7 | ✗ | ✓ | ✗ | 气血 +1 |
| `beast_blood` | 兽血 | 2 | 2 | 10 | blood, qi | meat | 0.8 | ✓ | ✓ | ✗ | 气血 +2 |
| `venom_sac` | 毒囊 | 3 | 3 | 15 | poison | — | 0.3 | ✗ | ✗ | ✗ | **气血 −1** |
| `moon_dew` | 月华露 | 4 | 4 | 20 | moon | — | 0.4 | ✓ | ✗ | ✗ | 真元 +2 |
| `moon_blue_petal` | 月蓝花瓣 | 1 | 1 | 5 | moon | herb | 0.5 | ✓ | ✓ | ✗ | 入药（无配方消费） |
| `boar_king_tusk` | 野猪王獠牙 | 1 | 1 | 15 | force | meat, bone | 0.2 | ✗ | ✗ | **✓** | 入药 |
| `inheritance_token` | 传承信物 | **30** | **3** | **60** | human | — | 0.5 | ✗ | ✗ | ✗ | **遗葬之地感应（无配方消费）** |

## A.4 配方使用分布 `[FACT]` — 兽骨单点依赖实锤

| 材料 | 使用配方数 | 总消耗量 | 占比 |
|---|---|---|---|
| **`beast_bone` 兽骨** | **378** | **537** | **98.2% 的配方** |
| `beast_blood` 兽血 | 3 | 3 | 0.8% |
| `boar_king_tusk` 野猪王獠牙 | 2 | 2 | 0.5% |
| `moon_dew` 月华露 | 1 | 1 | 0.3% |
| `venom_sac` 毒囊 | 1 | 1 | 0.3% |
| `moon_blue_petal` 月蓝花瓣 | **0** | **0** | **完全未用** |
| `inheritance_token` 传承信物 | **0** | **0** | **完全未用** |

- 配方总数 **392**（`fixed` 14 / `advance` 377 / `free_mix` 1）。
- **有效材料只有 5 种，其中 1 种占 378**；2 种**零使用**。

## A.5 value / 参考价 / 流动性 三元不自洽 `[FACT]`

| 材料 | `value` | `reference_value` | 流动性 | 比值（参考价/value） |
|---|---|---|---|---|
| beast_bone | 1 | 5 | 0.7 | 5× |
| beast_blood | 2 | 10 | 0.8 | 5× |
| venom_sac | 3 | 15 | 0.3 | 5× |
| moon_dew | 4 | 20 | 0.4 | 5× |
| moon_blue_petal | 1 | 5 | 0.5 | 5× |
| **boar_king_tusk** | **1** | **15** | **0.2** | **15×** ⚠ |
| **inheritance_token** | **30** | **60** | **0.5** | **2×** ⚠ |

> 前 5 种严格满足 `reference_value = value × 5`；后 2 种破坏该规律。
> **同一材料卖出与买入的定价基准不同。**

## A.6 掉落表 `[FACT]`

| tier | material_count | 材料池 | gu_chance | 特殊 |
|---|---|---|---|---|
| common | 1 | beast_blood / beast_bone / moon_blue_petal | **0%** | — |
| elite | 1 | beast_blood / beast_bone / venom_sac | **30%** | `forced_rarity: epic` + `cost_pool` |
| boss | 2 | + moon_dew | **0%** | `scavenge_recipe`（2 条） |

**层覆盖**（`pacing.layers[*].loot`）：

| 层 | material_count | 权重 common/rare/epic | shop_price_pct |
|---|---|---|---|
| 1 | 2 | 90/10/0 | 0% |
| 2 | 2 | 80/18/2 | 10% |
| 3 | 3 | 70/24/6 | 20% |
| 4 | 3 | 60/28/12 | 35% |
| 5 | 4 | 50/30/20 | **50%** |

**机制**（`loot_resolver._layer_table:121-141`）：层配置**只覆盖** `material_count` 与稀有度权重；
`material_pool` / `by_rarity` 仍取 tier 表 → **层数不改变掉落种类**。

## A.7 黑市（`resource_trade`，5 条）`[FACT]`

| id | 付出 | 获得 | 比率 |
|---|---|---|---|
| `black_market_lifespan_for_soul` | 寿元 20 | 魂 1 | 20:1 |
| `black_market_soul_for_lifespan` | 魂 1 | 寿元 10 | 1:10 |
| `black_market_health_for_soul` | 气血 20 | 魂 1 | 20:1 |
| `black_market_soul_for_health` | 魂 1 | 气血 10 | 1:10 |
| `black_market_health_for_lifespan` | 气血 20 | 寿元 10 | 2:1 |

## A.8 未接线通道汇总 `[GAP]`

| 通道 | 位置 | 状态 |
|---|---|---|
| 层预算注入 | `stone_budget` | 仅校验，无注入 |
| 战斗元石奖励 | `settle_victory` | 无 stone 字段 |
| 遗物战斗结算钩 | `relic_hook_resolver.apply_battle_end` | 无调用者 |
| 元石补真元 | `essence_capacity.stone_to_essence` | 无命令 |
| 传承信物用途 | `inheritance_token` | 商店在卖，配方零用 |
| 月蓝花瓣用途 | `moon_blue_petal` | 掉落池有，配方零用 |
| `durability_mode` | 全 3 模式 | 现网零配置 |

---

# B. F2 材料角色模型

## B.1 三种角色原型

| 原型 | 定义 | 玩家行为 |
|---|---|---|
| **消耗品** | 直接使用有效果，不入配方 | 受伤/缺真元时用掉 |
| **生产资料** | 入配方被消耗，产出蛊 | 攒着炼蛊，**不卖** |
| **商品** | 既无 `use` 效果、也无配方消费，只能卖 | 到手即卖 |

> **关键设计判据 `[INFERRED]`**：一个材料**不能同时是"高价值生产资料"和"高流动性商品"**——
> 否则玩家在"卖钱"与"炼蛊"间无痛选择，**机会成本归零**。

## B.2 材料角色归类 `[FACT]`

| id | 名称 | 原型 | `value` | 参考价 | 流动性 | 配方消费 | `use` 效果 | 来源 |
|---|---|---|---|---|---|---|---|---|
| `beast_bone` | 兽骨 | **生产资料** | 1 | 5 | 0.7 | **378 配方 / 537 件** | 气血 +1 | 全三档掉落池 |
| `beast_blood` | 兽血 | **消耗品（兼资料）** | 2 | 10 | 0.8 | 3 配方 / 3 件 | 气血 +2 | 全三档掉落池 |
| `venom_sac` | 毒囊 | **陷阱商品** ⚠ | 3 | 15 | 0.3 | 1 配方 / 1 件 | **气血 −1** | elite / boss 池 |
| `moon_dew` | 月华露 | **消耗品** | 4 | 20 | 0.4 | 1 配方 / 1 件 | 真元 +2 | boss 池 |
| `moon_blue_petal` | 月蓝花瓣 | **纯商品** ⚠ | 1 | 5 | 0.5 | **0** | 无 | common 池 |
| `boar_king_tusk` | 野猪王獠牙 | **孤儿生产资料** ⚠ | 1 | 15 | 0.2 | 2 配方 / 2 件 | 无（仅文本） | 无掉落池、仅商店 |
| `inheritance_token` | 传承信物 | **纯商品（高价）** ⚠ | 30 | 60 | 0.5 | **0** | 无（仅文本） | 无掉落池、仅商店 |

**即：7 种材料里有 4 种没有履行任何机制角色。**

## B.3 逐材料八问要点

**兽骨（经济水泥）**：378/392 配方的通用材料；三档池全含；**唯一"必须囤"的材料**；
卖它等于自断炼蛊能力（1 石/件）；**零替代**（硬编码）；层数只增数量不增种类。

**兽血（被掩盖的消耗品）**：`use.health=2` 直接回血；流动性 0.8（全场最高）；
配方层面 3 条均**同时需要兽骨** → 不是卡点。
→ **`use.health=2` 是固定值，不随层缩放** → **层 1 是保命符，层 5 是垃圾** `[GAP]`。

**毒囊（惩罚性材料）**：`use.health=-1`（**使用掉血**）+ 1 条配方；流动性 **0.3**（回收打 3 折 ≈ 0.9 石）。
→ `value=3` 宣称值钱，但**使用是负收益、卖出被打折** → **纯掉落噪音**。

**月华露（唯一自洽）**：`use.essence=2`，**全场唯一回真元的材料**；**仅 boss 池**（供给稀缺）；
`value=4` 高。→ **7 种里唯一"设计自洽"的材料**。
但 `[GAP]` `stone_to_essence` 未接线 → 一旦接线，月华露的唯一性会被元石替代。

**月蓝花瓣（零用途纯商品）**：`[GAP]` 无机制需要；**common 池最高频**；`value=1`；**零配方**。
→ **掉落的填充物，稀释"获得感"**。

**野猪王獠牙（配置不一致孤儿）**：2 条配方消费它，但 **`enemies.json` 无野猪王敌人、无掉落池**；
仅商店 10 石售；`value=1` 卖 vs `reference_value=15`（差 15 倍）；`is_exclusive=true` 却无专属来源。
→ **未完工的材料，机制上无法正常获得或循环。**

**传承信物（最贵纯商品）**：`use.text` 说"遗葬之地感应"，**代码中无任何消费点**；
商店 **60 石**售，`value=30` 卖 → **买 60 卖 30，净亏 30**。
→ **经济系统里唯一的"骗局式"陷阱**（玩家会以为"贵=有用"）。

## B.4 三种结构病灶 `[FACT]`

| 病灶 | 表现 | 材料 |
|---|---|---|
| **单点依赖** | 一种材料占 98.2% 配方 | 兽骨 |
| **零用途噪音** | 掉落池里有，但无任何机制消费 | 月蓝花瓣、传承信物 |
| **孤儿材料** | 有消费点，但无来源 | 野猪王獠牙 |

## B.5 玩家面对的真实选择 `[FACT]`

| 情境 | 玩家的"最优解" | 是否有趣 |
|---|---|---|
| 掉了兽骨 | **留着**（无法买，只能攒） | 被迫，非选择 |
| 掉了兽血 | 层 1 留着回血 / 层 5 卖掉 | 有层依赖，尚可 |
| 掉了毒囊 | **立刻卖** | 无脑 |
| 掉了月华露 | 留着回真元 | 合理 |
| 掉了月蓝花瓣 | **立刻卖**（1 石也是钱） | 无脑 |
| 看到獠牙 offer | **不买** | 无脑 |
| 看到信物 offer | **不买** | 无脑 |

> **F2 结论**：7 种材料中，玩家会做出**真实权衡的只有 2 种**（兽血、月华露）。

## B.6 跨层衰减缺口 `[GAP]`

- `beast_blood.use.health = 2`、`moon_dew.use.essence = 2` 均为**固定绝对值**。
- 敌人伤害随层增长（`turn_scaling.damage_add_per_turn = 1`，层 5 敌人 +5 伤害）。
- → **同一种材料在层 5 的实际疗效不足层 1 的 1/3** `[INFERRED]`。
- **材料效果是唯一没有随层缩放的战斗数值。**

---

# C. F3 蛊虫价值模型

## C.1 当前唯一生效的定价 `[FACT]`

```
value = max(定义字面 value, gu_value_by_rank[实例转数])
gu_value_by_rank = {1:3, 2:5, 3:8, 4:12, 5:20}
```

## C.2 与数据的吻合度 `[FACT]`

| rank | 蛊数 | 字面 value 分布 | 与表值关系 |
|---|---|---|---|
| 1 | 220 | 3,4,5,6,8,10 | 211 匹配 / **9 高于** |
| 2 | 157 | 5,9,10,30 | 154 匹配 / **3 高于** |
| 3 | 180 | 8,16 | 179 匹配 / **1 高于** |
| 4 | 97 | 12 | **97 全匹配** |
| 5 | 147 | 20 | **147 全匹配** |

> **rank 4/5 的 244 只蛊价值完全由表决定**（字面值无区分度）；
> rank 1–3 有 13 只"手工蛊"高于表值，全部在 **light / force / earth / blood** 四流派。

## C.3 `rarity` 是转数的影子 `[FACT]`

| rarity | rank 分布 |
|---|---|
| common | {1: 214, 2: 154} —— **只存在于低转** |
| rare | {1: 3, 2: 2, 3: 180} —— **基本=转 3** |
| epic | {1: 3, 2: 1, 4: 97, 5: 147, 10: 1} —— **基本=转 4/5** |

## C.4 11 条价值轴 `[FACT]`

| # | 轴 | 数据来源 | 当前被定价？ | 可测性 |
|---|---|---|---|---|
| A1 | **转数 rank** | 802/802 | ✅ **唯一被消费** | 强 |
| A2 | 稀有度 rarity | 802/802 | ❌（且=rank 影子） | 强 |
| A3 | 真元成本 essence_cost | 16/802 | ❌ | 弱（2%） |
| A4 | 念头成本 thought_cost | 3/802 | ❌ | 极弱 |
| A5 | 寿元成本 life_cost | **1/802** | ❌ | **近乎空** |
| A6 | 战斗效果 v1_effect | 57/802 | ❌ | 中（7%） |
| A7 | 组合价值 synergy_hooks | 14/802 | ❌ | 弱 |
| A8 | 流派归属性 school | 802/802 | ❌ | 强 |
| A9 | 信息价值 field_actions | 12/802 | ❌ | 弱 |
| A10 | 稀缺性 source | 786/802 | ❌ | 中 |
| A11 | 可替代性 | 推导 | ❌ | 中 |

## C.5 逐轴要点

**A1 转数**：`standard_gu_power(rank) = 100 × 0.2 × 2^rank` → 转 1 = 40，转 5 = 640（**16 倍**）；
而 `gu_value_by_rank` 从 3 → 20（**6.7 倍**）→ **战力增长远快于价值增长**。

**A2 稀有度**：elite 战利品 `forced_rarity: epic` → **打精英掉一只 epic 转 1 蛊，卖价与 common 转 1 蛊相同（3 石）**
→ **稀有度溢价被完全抹掉**。

**A3–A5 资源成本轴**：`essence_cost` 16/802（2.0%）；`thought_cost` 3/802（0.4%）；
`life_cost` **1/802（0.1%）**（唯一一条 `blood_atk_5_02_gu = 2`）。
→ **745 只批量蛊的资源成本轴是空的**，驱动成本全走 `standard_activation_cost = 0.1`。

**A6 战斗效果**：`v1_effect` 57 只，kind 分布
`strike 27 / heal 10 / shield 6 / shift 5 / sword_intent 5 / status 2 / heal_and_strike 1 / weaken_intent 1`。
strike amount 随 rank（1→8），但 **rank 1 内部差异 1 到 4（4 倍）**，
且 **rank 3 的显式 strike（2）低于 rank 2（4）** → **内部不自洽**（逐只手工填，无统一公式）。

**A8 流派**：20 个流派（19×40 + human 42），**每流派 rank 分布几乎相同**，
但 **role 构成不同**：
- `force`：0 recon / 0 logistics，attack 33（最高）——**纯战斗**
- `light`：recon 9（最高）+ logistics 4 ——**侦察**
- `refine`：logistics 10（最高）——**后勤**
- `wind`：movement 11（最高）——**机动**
- `human`：attack 35（最高）、healing 1（最低）

> 一个"构筑价值"定价必须能表达：**force 的转 1 攻击蛊 ≠ light 的转 1 侦察蛊**（当前同价 3 石）。

**A10/A11**：`source`：`novel` 261 / `school_derived` 525 / 缺失 16。
→ **novel 应稀缺高价，school_derived 应廉价，但当前同价** → **稀缺性溢价不存在**。

## C.6 候选公式（提案，不落地）

### C.6.1 构筑价值三因子提案

```
build_value(gu) = rank_value × school_factor × role_factor × scarcity_factor
```

| 因子 | 依据 | 建议取值（示意） |
|---|---|---|
| `rank_value` | 现 `gu_value_by_rank` | 3 / 5 / 8 / 12 / 20 |
| `school_factor` | 流派 role 稀缺度 | 1.0 基线；`force` 0.9；`light` 1.2 |
| `role_factor` | 角色不可替代性 | attack 1.0 / defense 1.05 / healing 1.05 / movement 1.0 / recon 1.15 / logistics 1.10 |
| `scarcity_factor` | `source==novel` 或有 synergy | 1.0 基线；novel 1.3；有 synergy 1.2 |

> **⚠ 作者自评**：`school_factor` / `role_factor` 的取值**目前没有任何实证依据**，
> 属于"为了给流派差异定价而拍的数字"。**在没有 F8 模拟数据前，不应采用。**

### C.6.2 替代方案：只补"手工蛊溢价"

```
value = max(
  literal_value,              # 手工蛊已手工调高的值（13 只）
  gu_value_by_rank[rank],     # 批量蛊基线
  has_v1_effect ? base × 1.5 : base   # 显式效果蛊（57 只）加 50%
)
```

> 只用了数据里**已存在的手工排序**，不引入新因子 → **风险最低，
> 但也不能解决"批量蛊 745 只全部同价"的问题**。

## C.7 F3 核心结论

| # | 事实 | 后果 |
|---|---|---|
| 1 | `gu_value` **只看 rank** | 802 只蛊压缩成 **5 个价格档** |
| 2 | rank 4/5 的 244 只**字面值全等于表值** | 高转区间**零区分度** |
| 3 | 11 条轴中 **10 条未被消费** | 流派/稀有度/成本/组合/信息**全部不计价** |
| 4 | `life_cost` 覆盖 **1/802** | 寿元在蛊系统**零参与** |
| 5 | `essence_cost` 2%、`thought_cost` 0.4% | 资源成本对 745 只批量蛊**不存在** |
| 6 | 战力 16× vs 价值 6.7× | **高转蛊被系统性低估** |
| 7 | `rarity=epic` 的转 1 蛊与 common 同价 | 精英战利品**稀有度溢价被抹掉** |
| 8 | `synergy_hooks` 仅 14 只 | **构筑价值在数据层几乎不存在** |

---

# D. F4 晋升经济审计

## D.1 三条颠覆性事实 `[FACT]`

| # | 事实 |
|---|---|
| **A** | **377 条 `advance` 输入与输出转数完全相同**（220 条 1→1、157 条 2→2），且 `output_gu_id == input_gu_ids[0]`（**377/377 同名**） |
| **B** | **只有 13 条 `fixed` 配方能提升转数**，且全部是手工蛊（light/earth/blood/sword 四流派） |
| **C** | **转 3/4/5 的蛊零晋升配方**（180+97+147 = 424 只全部无 advance） |

## D.2 `advance` 形式结构 `[FACT]`

| 属性 | 值 |
|---|---|
| 数量 | 377（占配方 96.2%） |
| 输入 | **恒定 1 只蛊** |
| 输出 | **与输入同名**（377/377） |
| 材料 | **恒定只见 `beast_bone`**（217+1+157），另 3 条例外用 `beast_blood`/`moon_dew` |
| 元石 | 按输出蛊转数分档：rank 1 → 6 石；rank 2 → 10 石 |
| 门禁 | `advance` **豁免蛊方图鉴**（`recipe_unlocked:174` 直接 `return true`） |

**素材消耗**：转 1 蛊 219 份兽骨 + 1 兽血 + 1 月华露；转 2 蛊 314 份兽骨 → **合计 537 份兽骨**
（= F1 的"兽骨总消耗 537"，**全部来自 advance**）。

**净亏**：花 6 石 + 1 兽骨 advance 一只转 1 蛊，若结果仍是转 1（常规），**卖出只回 3 石 → 净亏 3 石 + 1 兽骨**。

## D.3 唯一能升转的通道：13 条 `fixed` `[FACT]`

| 配方 | 输入 | 输出 | 转数变化 | 默认解锁 | 流派 |
|---|---|---|---|---|---|
| `moon_glow_fixed` | moonlight_gu + small_light_gu ×2 | moon_glow_gu | 1→2 | ✅ | light |
| `moon_ray_forged` | moonlight_gu + small_light_gu | moon_ray_gu | 1→2 | ✅ | light |
| `moonlight_glow` | moonlight_gu + small_light_gu | moon_glow_gu | 1→2 | ✅ | light |
| `white_jade_advance` | jade_skin_gu + white_boar_strength_gu | white_jade_gu | 1→2 | ❌ | earth |
| `white_jade_basic` | jade_skin_gu + white_boar_strength_gu | white_jade_gu | 1→2 | ✅ | earth |
| `blood_moon_forged` | moon_ray_gu + blood_atk_1_08_gu | blood_atk_3_11_gu | 2→3 | ❌ | blood |
| `moon_shadow_locked` | moon_glow_gu + qi_mov_1_07_gu | moon_shadow_gu | 2→3 | ❌ | light |
| `ascend_sword_atk_1_05_gu` | sword_atk_1_05_gu | sword_atk_2_12_gu | 1→2 | ✅ | sword |
| `ascend_sword_atk_1_06_gu` | sword_atk_1_06_gu | sword_atk_2_13_gu | 1→2 | ✅ | sword |
| `ascend_sword_def_1_07_gu` | sword_def_1_07_gu | sword_def_3_14_gu | **1→3** | ✅ | sword |
| `ascend_sword_mov_1_08_gu` | sword_mov_1_08_gu | sword_mov_3_15_gu | **1→3** | ✅ | sword |
| `ascend_sword_heal_1_09_gu` | sword_heal_1_09_gu | sword_heal_4_16_gu | **1→4** | ✅ | sword |
| `ascend_sword_rec_1_10_gu` | sword_rec_1_10_gu | sword_rec_5_17_gu | **1→5** | ✅ | sword |

**结构观察**：
1. 13 条全部集中在 **4 个流派**（light 3 / earth 2 / blood 1 / **sword 6**），**其余 16 流派零升转通道**。
2. **sword 独占 6 条**，是**唯一能从转 1 直达转 5**的流派。
3. **升转是"换名"而非"同名+1"** → 属**定向合炼（`output_rank` 路径）**，不是 advance。
4. ~~**`stone_cost` 字段缺失** → 13 条全部**不花元石**。~~<br>⚠️ **本条已于 2026-09-12 推翻**：`stone_cost` 字段**存在且被代码读取**，是本附录的**提取脚本漏读该字段**。实测 9/14 条有成本（sword 12–60 石 + 材料、`white_jade` 50 石、`stone_shell_bone_forge` 2 骨），**只有 5 条 light 系真正免费**。详见 `Q8G_BATCH0_RULING.md` §13.2/§13.3。
5. **`default_unlocked` 8 条为 true** → 一半升转配方**开局即有**。

**一句话成本效率**：~~`ascend_sword_rec` = 1 只转 1 蛊（卖 3 石）→ 转 5 蛊（卖 20 石），**零元石零材料**。~~
→ ⚠️ **更正**：`ascend_sword_rec_1_10_gu` 实测为 **60 石 + 1 `boar_king_tusk`**。
→ **真正 0 成本和的存在于 light 系**：`moon_glow_fixed` / `moon_ray_forged` / `moonlight_glow`（三项 0 石 1→2）+
  `blood_moon_forged` / `moon_shadow_locked`（**0 石 2→3**）。详见 `Q8G_BATCH0_RULING.md` §13.3。

## D.4 `free_pair` 与 `cultivate` `[FACT]`

**`free_pair`**：
```
success_pct: {2: 90, 3: 70, 4: 50, 5: 35}
stone_cost:  {2: 20, 3: 60, 4: 150, 5: 300}
```
- `[GAP]` **全仓无代码读取** → 高转蛊**无法用元石获得**。
- 但这**正是任务书描述的"元石 → 高转蛊"通道**。

**`cultivate_rank_two`**：成本 5 石 → `cultivation = 2`（**人物修二转，非蛊升转**）。
`[GAP]` **无 `cultivate_rank_three/four/five`** → 修三转以上**不存在**。

**`advance_bonus_by_rank`**：`{1:0, 2:1, 3:3, 4:6, 5:10}` `[GAP]` **全仓无调用者**
→ 这是**最接近"升转奖励曲线"的定义**，却未接线。

## D.5 晋升经济全景

| 链 | 形式 | 覆盖 |
|---|---|---|
| **链 A（advance）** | 同名蛊 + 兽骨 + 元石 → 同名蛊 | 转 1/2 全覆盖，**不改转数** |
| **链 B（fixed）** | 异名蛊 + 材料 → 高转异名蛊 | 13 条，**4 流派** |

**结论**：`低转蛊 → 晋升材料 → 元石 → 高转蛊` 这条**完整链条不存在**。

## D.6 对红线（任务书 §六）的核查

| 检查项 | 结果 | 判定 |
|---|---|---|
| 低转蛊能否进入高转构筑？ | 能，但**仅 4 流派** | ⚠️ 部分成立 |
| 成本效率是否优于直接购买？ | ⚠️ ~~sword 链零元石~~ **更正**：sword 链成本 172 石/条；**light 5 条才是 0 石** | ⚠️ 需重估 |
| 是否存在"低转蛊唯一出口是卖钱"？ | **16 流派是** | ❌ 红线受损 |
| 高转蛊是否有获取通道？ | 商店买（6–80）/ Boss **0%** / 无配方 | ⚠️ 单一 |

> **F4 判定（更正后）**：红线**仅在 1 个流派（light）存在 0 成本通道**，
> **在其余 19 流派失效**（sword 虽有 6 条但成本完整且偏高）。
> 原因不是定价，而是**"能升转的配方只做了 13 条"** → **内容覆盖问题，不是数值问题**。
> 附加问题：**light 的 5 条免费配方**属**成本缺失**，与"覆盖不足"是两类不同缺陷。

---

# E. F5 商店经济审计

## E.1 三条颠覆性事实 `[FACT]`

| # | 事实 |
|---|---|
| **A** | **商店买价与 `gu_value` 完全脱钩**：`shop_layer_price` = 数据写死的 `stone_cost` + 层通胀，**从不调用 `gu_value`** |
| **B** | **同一只蛊的买价可差 26 倍**：`purchase_heaven_dew` 80 石 vs `moonlight_gu` 6 石（两者 `gu_value` 相近） |
| **C** | **商店回收价 ≠ 买价的对称面**：卖出走 `sell_price_for(base=gu_value)` → **买贵卖贱脱钩** |

## E.2 价格公式 `[FACT]`

```
最终买价 = ceil( stone_cost × (1 + 恶名%/100) × (1 + 回访%/100) × (1 + 契约%/100) )
              × (1 + 层通胀 shop_price_pct/100)

层通胀: 层1 = 0% / 层2 = 10% / 层3 = 20% / 层4 = 35% / 层5 = 50%
恶名:   price_pct_per_point = 10%/点，上限 60%
服务涨价: 每次使用 +25%，上限 +100%（删卡/拔印适用）
```

> **`stone_cost` 是唯一的价值输入**；层通胀是**唯一动态调整**，且**对所有货品统一加价**
> → **不改变相对价格结构，只整体抬高**。

## E.3 `purchase`（买蛊，19 条）逐条 `[FACT]`

| id | 蛊 | 转 | 价 | `gu_value` | **买/价倍率** | tier |
|---|---|---|---|---|---|---|
| `purchase_stone_shell` | stone_shell_gu | 1 | 6 | 5 | **1.2** | 1 |
| `purchase_moonlight` | moonlight_gu | 1 | 6 | 4 | 1.5 | 3 |
| `purchase_thunder_ward` | qi_atk_1_01_gu | 1 | 9 | 3 | 3.0 | 4 |
| `purchase_moon_glow` | moon_glow_gu | 2 | 12 | 9 | **1.33** | 5 |
| `purchase_small_light_gu` | small_light_gu | 1 | 12 | 3 | 4.0 | 1 |
| `purchase_jade_skin_gu` | jade_skin_gu | 1 | 30 | 8 | 3.75 | 1 |
| `purchase_white_boar_strength_gu` | white_boar_strength_gu | 1 | 35 | 10 | 3.5 | 1 |
| `purchase_mending_grass` | wood_atk_1_05_gu | 1 | 8 | 3 | 2.67 | 1 |
| `purchase_bone_knit` | bone_atk_1_08_gu | 1 | 14 | 3 | **4.67** | 2 |
| `purchase_spring_heart` | human_atk_1_01_gu | 1 | 18 | 3 | **6.0** | 3 |
| `purchase_moon_shadow_300` | moon_shadow_gu | 3 | 40 | 16 | 2.5 | 3 |
| `purchase_life_root` | wood_atk_1_05_gu | 1 | 20 | 3 | **6.67** | 4 |
| `purchase_undying_vine` | wood_atk_1_05_gu | 1 | 20 | 3 | **6.67** | 4 |
| `purchase_heaven_dew` | water_atk_1_08_gu | 1 | **80** | 3 | **26.67** ⚠ | 5 |
| `purchase_sword_atk_1_06` | sword_atk_1_06_gu | 1 | 8 | 3 | 2.67 | 1 |
| `purchase_sword_atk_2_12` | sword_atk_2_12_gu | 2 | 18 | 5 | 3.6 | 2 |
| `purchase_sword_def_3_14` | sword_def_3_14_gu | 3 | 30 | 8 | 3.75 | 3 |
| `purchase_sword_heal_4_16` | sword_heal_4_16_gu | 4 | 45 | 12 | 3.75 | 4 |
| `purchase_sword_atk_5_02` | sword_atk_5_02_gu | 5 | 70 | 20 | 3.5 | 5 |

**逐条判定**：

| 判定 | 条目 | 理由 |
|---|---|---|
| **必买** | `stone_shell`(1.2)、`moon_glow`(1.33)、`moonlight`(1.5) | 买价 ≈ 回收价，**几乎零损耗** |
| **合理** | 4 条 sword（3.5–3.75） | 倍率一致，且 sword 有升转链 |
| **偏高** | `thunder_ward`、`jade_skin`、`white_boar`、`mending_grass`、`moon_shadow` | 需玩家真觉得有用才值 |
| **陷阱** | `bone_knit`(4.67)、`spring_heart`(6.0)、`life_root`(6.67)、`undying_vine`(6.67) | 买价是回收价 **4.7–6.7 倍** |
| **荒谬** | **`heaven_dew`(26.67)** | **80 石买一只 `gu_value=3` 的转 1 蛊** |
| **重复条目** ⚠ | `mending_grass` / `life_root` / `undying_vine` | **同一只蛊三个价格（8/20/20）挂三档** |

## E.4 `gu_fang_unlock`（古方，5 条）`[FACT]`

| id | 产物 | 价 | 判读 |
|---|---|---|---|
| `gu_fang_moon_glow_gu` | moon_glow_gu | 80 | 与直接买 `purchase_moon_glow`(12) 相比：**古方贵 6.7 倍** |
| `gu_fang_white_jade_gu` | white_jade_gu | 80 | `gu_value=30`，但**无 purchase offer** |
| `gu_fang_blood_heal_2_23_gu` | blood_heal_2_23_gu | 80 | — |
| `gu_fang_blood_atk_3_03_gu` | blood_atk_3_03_gu | **200** | 转 3 蛊 `gu_value=8` → **贵 25 倍** |
| `gu_fang_blood_atk_3_11_gu` | blood_atk_3_11_gu | **200** | 同上 |

> **关键 `[FACT]`**：古方给的是 `global_codex_ids`（跨局永久），
> 而 `advance` **本来就豁免蛊方门禁** → **玩家花 80–200 石买的古方，对 advance 毫无影响**。
> 唯一受益的是 `fixed`（13 条），但其中 8 条已 `default_unlocked`。
> → `[INFERRED]` **古方售卖的实际价值 ≈ 0**。

## E.5 `material_purchase`（买材料，3 条）`[FACT]`

| id | 材料 | 价 | `value` | `reference_value` | 判读 |
|---|---|---|---|---|---|
| `purchase_moon_blue_petal` | moon_blue_petal | 3 | 1 | 5 | 买 3 卖 1，**且无配方用途** → **纯亏** |
| `purchase_boar_king_tusk` | boar_king_tusk | 10 | 1 | 15 | **唯一来源**（无掉落池），但只服务 2 条配方 |
| `purchase_inheritance_token` | inheritance_token | 60 | 30 | 60 | **无任何用途** → 买 60 卖 30，**纯亏 30** |

> **最大缺口**：**商店不卖兽骨**，而兽骨是 377 条 advance 的**唯一材料** →
> 玩家**唯一的兽骨来源是掉落**，无元石兜底通道。

## E.6 服务类（5 条）`[FACT]`

| id | kind | 价 | 判读 |
|---|---|---|---|
| `soul_pill` | `soul_boost` | 6 | 魂 +1（`soul_max` 封顶）→ **全场最便宜的成长** |
| `wash_notoriety` | `wash_notoriety` | 无显式价 | 洗恶名（恶名降买价） |
| `purchase_white_jade_recipe` | `recipe_unlock` | 60 | 解锁 `white_jade_advance` |
| `lifespan_pulse_drum` | `lifespan_deal` | **寿元 1** | 用寿元换 `qi_atk_1_01_gu`（`gu_value=3`） |
| `barter_unknown_gu` | `barter` | `qi_rec_2_14_gu` | 以蛊换蛊（+概率遗物） |

> **`lifespan_deal` 判读**：**寿元 1 换一只 `gu_value=3` 的蛊**。
> 对照 `black_market_health_for_lifespan`（气血 20 → 寿元 10）→ **寿元 1 ≈ 气血 2**
> → **2 点气血换一只转 1 蛊** —— **远优于任何其他通道**。

## E.7 结构诊断

**价格离散度失控**：

| 倍率区间 | 条数 | 条目 |
|---|---|---|
| 1.0–1.5 | 3 | stone_shell, moon_glow, moonlight |
| 1.5–3.0 | 6 | thunder_ward, mending_grass, moon_shadow, sword×2, sword_atk_1_06 |
| 3.0–5.0 | 7 | small_light, jade_skin, white_boar, bone_knit, sword_def, sword_heal, sword_atk_5 |
| 5.0–7.0 | 4 | spring_heart, life_root, undying_vine |
| **> 26** | **1** | **heaven_dew** |

> **离散度 1.2 → 26.67（22 倍）**，且**没有任何可解释的排序**。

**层通胀的"反向筛选"**：

| 层 | 通胀 | 例：`purchase_life_root` 实际价 | 玩家层收入（+2/+3 硬编码） |
|---|---|---|---|
| 1 | 0% | 20 | ~5–8/层 |
| 2 | 10% | 22 | ~5–8 |
| 3 | 20% | 24 | ~5–8 |
| 4 | 35% | **27** | ~5–8 |
| 5 | 50% | **30** | ~5–8 |

> **收入恒定而价格逐层上涨 50%** → **层 5 相对购买力只有层 1 的 2/3**，
> 而层 5 的货**恰好最贵** → **越往后越买不起**，与"越深越富"直觉相反。

**货架机制**：槽位 `4 + ⌊层/2⌋`（4/5/5/6/6）；货池 29 条；种子 =（局种子, 节点模板 id）→ **不刷货**；
保底两条（本层最高档至少 1 件 + **本流派蛊至少 1 件**）；
服务常驻（`resource_trade` / `wash_notoriety` / `recipe_unlock` / `soul_boost`）。
→ 层 1 有 29 条候选、只有 4 个槽 → **玩家平均每局看不到 86% 的货**。

## E.8 逐条"迫使玩家做什么选择"（任务书 §八）

| offer | 玩家面对的选择 | 是否有趣 |
|---|---|---|
| `stone_shell`(6) | 买（1.2 倍，几乎零损耗）→ **无脑买** | ❌ |
| `moonlight`(6) / `moon_glow`(12) | 买 → **无脑买** | ❌ |
| `heaven_dew`(80) | **看到就跳过**（或误买巨亏） | ❌ **陷阱** |
| `life_root`/`undying_vine`(20) | 跳过（同蛊层 1 只卖 8） | ❌ 矛盾 |
| `bone_knit`/`spring_heart`(14/18) | 除非真需要，否则跳过 | ⚠️ 弱 |
| sword ×5 | **买**（有升转链，3.5 倍合理） | ✅ **唯一正解** |
| `gu_fang_*`(80–200) | **跳过**（advance 本来就豁免门禁） | ❌ 无效 |
| `purchase_inheritance_token`(60) | **跳过**（纯亏 30） | ❌ 陷阱 |
| `purchase_moon_blue_petal`(3) | 跳过（无用途） | ❌ 无效 |
| `purchase_boar_king_tusk`(10) | **必须买**（唯一来源）否则 2 条配方永久锁死 | ⚠️ 被迫 |
| `lifespan_pulse_drum` | **考虑**（2 气血 = 1 蛊，比率最优） | ✅ |
| `soul_pill`(6) | **考虑**（最便宜成长） | ✅ |

> **F5 判定**：37 条 offer 里，玩家会做出**真实权衡的只有 3–4 条**
> （sword 系列、`lifespan_deal`、`soul_pill`）。

---

# F. F6 掉落经济审计

## F.1 三档掉落表 `[FACT]`

| tier | 材料数 | 材料池 | 掉蛊率 | 强制稀有度 | 额外成本 |
|---|---|---|---|---|---|
| **common** | 1 | beast_blood / **beast_bone** / moon_blue_petal | **0%** | — | 无 |
| **elite** | 1 | beast_blood / **beast_bone** / venom_sac | **30%** | **epic** | **诅咒 or 恶名 +2** |
| **boss** | 2 | + moon_dew（4 选 1 ×2） | **0%** | — | 无 |

**蛊池 `[FACT]`**：

| tier | common 权重 | rare 权重 | epic 权重 | 池大小 |
|---|---|---|---|---|
| common | 80 | 18 | 2 | 6 + 5 + 3 = **14** |
| elite | 60 | 35 | 5 | 2 + 3 + 3 = **8** |
| boss | 无 `gu_pool.weights` → **空** | — | — | **0** |

> `[GAP]` boss 的 `gu_pool` 只有键名没有内容 → `_roll_gu:204` `if chance <= 0 or weights.is_empty(): return ""`
> → **Boss 即便有掉蛊率也不会掉**。叠加 `gu_chance_pct = 0` → **双保险地不掉蛊**。

## F.2 敌人体量 `[FACT]`

| tier | 数量 | hp 范围 | 意图伤害 | rank 范围 |
|---|---|---|---|---|
| common | 13 | **3–5** | 1–2 | 0–2 |
| elite | 12 | **6–11** | **0–4**（有 0！） | 2–5 |
| boss | 7 | **14–20** | 2–4 | 3–5 |

> **异常 `[FACT]`**：**elite 有伤害 0 的条目**（3 只 `dmg=0`），但 hp 6–11 → "高血低攻"沙包。
> `[INFERRED]` 这类 elite 难度**低于**高攻 common（hp 5 / dmg 2），但**回报高一档** → **存在"低风险高回报"的刷分点**。

## F.3 逐 tier 风险 → 回报

| tier | 风险 | 材料 | 蛊 | 成本 | **净对价判读** |
|---|---|---|---|---|---|
| **common** | 低（3–5 hp，1–2 dmg） | 1 份（兽骨 1/3 概率） | **0%** | 无 | 期望 ≈ **0.33 兽骨** |
| **elite** | 中（6–11 hp，0–4 dmg） | 1 份（毒囊 1/3 概率） | **30% epic** | **诅咒或恶名 +2** | 期望 ≈ 0.33 材料 + **0.3 只 epic 蛊** + **必然代价** |
| **boss** | **高**（14–20 hp，2–4 dmg） | 2 份（含月华露 1/4 概率） | **0%** | 无 | 期望 ≈ **0.5 月华露 + 1.5 兽骨** |

> **最反常的对价**：**Boss 风险最高、回报最低（无蛊）**。

## F.4 精英成本 `[FACT]`

`cost_pool` 二选一（权重各 1）：
- `backlash`：`curse_id = gu_erosion`，1 层
- `notoriety`：恶名 +2

> 恶名 +2 → **买价 +20%**（上限 60%）→ **打一场精英 = 永久购买力下降 20%**。
> 精英回报 = 0.3 只 epic 蛊 + 0.33 材料 →
> `[INFERRED]` **若不出蛊（70% 概率），这场精英是纯亏**。

## F.5 保底（pity）机制 `[FACT]`

```json
pity = {
  "threshold": 3,
  "clearing_rarities": ["rare", "epic", "legendary"],
  "material_pity": { "threshold": 3, "target_material_ids": ["venom_sac", "moon_dew"] }
}
```

| 机制 | 触发 | 是否有效 |
|---|---|---|
| 蛊保底 | 连续 3 次出 common | ❌ **common tier 0% 掉蛊**，精英强制 epic → **永不触发** |
| 材料保底 | 连续 3 次未出毒囊/月华露 | ✅ 有效 |

> `[GAP]` **蛊保底是死代码**：`_roll_gu` 只在 `gu_chance_pct > 0` 时进入，
> 而唯一 >0 的 elite tier 有 `forced_rarity` → **保底分支（215–227 行）在全游戏中不可达**。

## F.6 掉落的"噪音"问题 `[FACT]`

| tier | 有效材料 | 无效/陷阱材料 | **噪音率** |
|---|---|---|---|
| common | beast_blood, beast_bone | **moon_blue_petal** | **33%** |
| elite | beast_blood, beast_bone | **venom_sac** | **33%** |
| boss | 全部（含 moon_dew） | **venom_sac**（1/4） | **25%** |

> 普通战 **1/3 概率**掉"1 石垃圾" → **"掉落获得感"被稀释 1/3**。

## F.7 层配置覆盖 `[FACT]`

层配置**只覆盖** `material_count` 和 `gu_pool.weights`；
`material_pool` 与 `by_rarity` **仍取 tier 表** → **层数不改变掉落种类**。

> **后果**：
> 1. **层 5 掉 4 份材料，但池子还是那 3–4 种** → **高层没有新材料，只有更多同种**。
> 2. 权重里的 `epic 20%` 在 elite tier 下**被 `forced_rarity: epic` 完全覆盖** →
>    **层权重系统对实际掉落几乎无影响**。

## F.8 F6 核心结论

> **只有"攒兽骨"是一个成立的战斗动机**，而它每场只给 0.33 份
> → **炼一条转 1 蛊需要 3 场普通战，转 2 需要 6 场**。
> 而 advance 共吃 **537 份兽骨** → **完成全部 advance 需约 1600 场普通战**（不可能）。

---

# G. F7 寿元与魂的经济模型

## G.1 三条颠覆性事实 `[FACT]`

| # | 事实 |
|---|---|
| **A** | **`life_cost` 全场只有 1 只蛊设置**（`blood_atk_5_02_gu = 2`），其余 801 只零寿元成本 |
| **B** | **寿元净收入远大于净支出** |
| **C** | **魂是"只进不出"的资源**：唯一消耗是黑市兑换，而兑换有**一次门禁** |

## G.2 寿元全生命周期 `[FACT]`

| 方向 | 来源 | 量 | 位置 |
|---|---|---|---|
| **收入** | `stage_one_ledger` 里程碑 | **+10** | `social_command_rules.gd:668` |
| **收入** | `boss_defeated` 里程碑 | **+10** | `social_command_rules.gd:420` |
| **收入** | 黑市 `soul ×1 → lifespan ×10` | +10/次（**每局一次**） | `economy_rules.gd:132` |
| **收入** | 黑市 `health ×20 → lifespan ×10` | +10/次（**每局一次**） | `economy_rules.gd:132` |
| **支出** | 黑市 `lifespan ×20 → soul ×1` | −20/次（**每局一次**） | `economy_rules.gd:114` |
| **支出** | 升资质 `cost_lifespan` | 变动 | `shop_command_rules.gd:372` |
| **支出** | 洗恶名 | **−10**（+8 元石） | `social_command_rules.gd:433` |
| **支出** | 门店 `lifespan_deal` | **−1** | `shop_command_rules.gd:405` |
| **支出** | 蛊 `life_cost` | **−2**（唯一一只） | `refine_command_rules.gd:320` |
| **债务** | 体质印记 `lifespan_debt` | `+N`（**不直接扣 current**） | `social_command_rules.gd:650` |

**初始寿元**：`run_state.gd:110` → `"lifespan": 60`。

**净收支核算**：收入（保证可得）= 10 + 10 = **+20**；
→ **60 起 + 20 里程碑 = 80，而唯一强制支出是 `lifespan_deal` −1（可选）**
→ **寿元终局几乎必然 >60（净增长）** `[INFERRED]`。

## G.3 黑市套利核查 `[FACT]`

**环 1：寿元 → 魂 → 寿元**：付 20 → 得 1 → 得 10 → **净 −10 寿元 ❌ 亏 50%**
**环 2：气血 → 魂 → 气血**：付 20 → 得 1 → 得 10 → **净 −10 气血 ❌ 亏 50%**
**环 3：气血 → 寿元 → 魂**：20 气血 → 10 寿元 → 需 20 才得 1 魂 → **差 10 ❌ 不通**
**环 4：气血 → 魂 → 寿元**：只单向 → **❌ 不通**

> **判定**：**不存在任何套利环路**。所有环路**单程即亏 50%**，
> 且**一次门禁**（`node_flags[offer_id] = "used"`）保证每个 offer 每局只能用一次
> → **连"多次往返"都不可能**。**黑市定价是自洽的、不可套利的。**

## G.4 唯一的有意汇率锚 `[FACT]`

- `soul_pill` 6 石 = 魂 1；黑市 `lifespan ×20 → soul ×1`
  → **6 石 ≈ 20 寿元** → **1 石 ≈ 3.3 寿元**
- 对照 `lifespan_deal`（**1 寿元换一只 `gu_value=3` 的蛊**）→ **1 寿元 ≈ 3 石**
- → ****1 石 ≈ 3.3 寿元** 与 **1 寿元 ≈ 3 石** 恰好互为倒数，一致** `[FACT]`

> **这是本次审计发现的唯一"隐性价值锚"**：元石 ↔ 寿元的汇率在**两条互不相关的路径上收敛到 ≈3**，
> 说明数据作者在此处**是有意设计的**（而商店买蛊的 22 倍离散度则明显是无意的）。

## G.5 魂的经济 `[FACT]`

| 属性 | 值 | 位置 |
|---|---|---|
| 驱动 | 每回合行动点（`action_points.per_turn(soul)`） | `action_points.gd:14` |
| 入 | `soul_pill` +1（6 石） | `shops.json` offer#00 |
| 入 | 黑市 `lifespan ×20` / `health ×20` → +1 | offer#14/16 |
| 出 | 黑市 `soul ×1` → 寿元/气血 | offer#15/17 |
| 出 | `soul_drain`（敌人意图字段） | `battle_command_facade.gd:150` |
| 出 | `free_mix` 爆炸（`soul_cost: 1`） | `refinement_recipes.json` |
| 上限 | `soul_max` | `shop_command_rules.gd:317` |

> **魂是战斗核心资源**（决定每回合行动次数），但获取只有：
> ① `soul_pill` 6 石（每次 +1，受 `soul_max` 限制）② 黑市（每局一次）
> → **魂的获取极度受限** `[INFERRED]`。

## G.6 `SoulRules` 巨额悬空 `[FACT]`

`balance.json` 有一整套 `soul_*` 常量：
```
soul_burst_capacity_ratio: 2.0
soul_calm_emotional_below: 40
soul_calm_beast_below: 25
soul_calm_departure_below: 10
beast_nature_emerging_above: 0.5
beast_nature_threshold: 1.0
```

`soul_rules.gd` 实现了**完整的第二套魂系统**：
- 5 个量：`soul_magnitude` / `soul_safe_capacity` / `soul_calm` / `soul_nature` / `beast_nature`
- 3 个操作：`strengthen_soul` / `refine_soul` / `calm_soul`
- 收魂门禁 `collect_soul`（15.3）
- 爆魂致死 `soul_growth_forecast`（`soul_burst` cause）
- 兽性终点 `bestiality_endpoint_check`（16.10）

> **`[GAP]` 关键判定**：注释（`soul_rules.gd:9-11`）明确说这 **5 个量是新键，绝不触碰 legacy `soul`/`soul_max`**。
> 即：**存在两套彼此不相连的魂系统**——
> ① legacy `cultivator.soul`（驱动行动点、黑市、魂丹）✅ **活**
> ② `SoulRules` 五量（爆魂、兽性、收魂）❌ **无消费者**
> → **`SoulRules` 是一套已实现但未接线的"魂道 DLC"**。

## G.7 寿元是否"被低估"？六问回答

**Q1：是否存在无限套利？** ❌ **不存在**。所有环路单程亏 50%，且每 offer 每局一次。

**Q2：寿元是否被低估？** ✅ **不是被低估，而是没有支出去处**。
60 起 + 20 里程碑，支出总和有限 → 终局净增长 → **玩家不需要为寿元做任何决策**。

**Q3：`life_cost` 为何只有 1 只蛊？**
`blood_atk_5_02_gu`（转 5 血道攻击，`v1_effect strike amount 8`）是**唯一带 2 点寿元成本的蛊**。
`[INFERRED]` 从剑道计划看，"**残锋**"（永久耗道痕降转）是剑道的代价机制；
**血道的 `life_cost` 可能是同类设计的孤例**。

**Q4：魂是否有独立价值？** ⚠️ **有两套魂，只有 legacy 那套活着**。

**Q5：黑市是否被使用？** `[INFERRED]` **大概率很少**。

**Q6：洗恶名（−10 寿元）是否划算？** `[FACT]` 换算：
- 洗恶名 −10 寿元 + **8 元石** → 减 2 恶名
- 恶名 2 点 → 买价 **+20%**
- 若玩家计划花 100 石，+20% = **多付 20 石** → 用 10 寿元 + 8 石换 20 石 = **净赚 12 石**
- 但若玩家不再购物 → 洗恶名**纯亏 10 寿元**
- **→ 这是一个真实的两难选择** ✅ **F7 发现的唯一"有趣决策"**

## G.8 死亡风险与预检 `[FACT]`

| 死因 | 触发 | 预检 |
|---|---|---|
| `death_cause_lifespan` | 寿元 ≤ 0 | ✅ `lifespan_trade_warning`（`< 1` 即拒） |
| `death_cause_soul` | 魂 ≤ 0 | ✅ `insufficient_soul` |
| `soul_burst` | `soul_magnitude > capacity × 2` | ⚠️ `SoulRules` 实现，**但未接线** |

> **红线合规**：寿元/魂的所有支付路径**都在扣减前判定 `< 1`**
> → **不存在静默致死**。符合项目红线。
