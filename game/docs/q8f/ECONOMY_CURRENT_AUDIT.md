# ECONOMY_CURRENT_AUDIT.md — Q8-F F1：经济现状审计

> - **阶段**：Q8-F / F1（**只审计，不改生产数值**）
> - **日期**：2026-09-12
> - **方法**：`data/*.json` 全量机械提取 + 代码实际接线核实（`tools/q8f_f1_extract.py`，原始输出 `_f1_extract.txt`）
> - **标注约定**：`[FACT]` = 代码/数据实测；`[INFERRED]` = 推导，未验证；`[GAP]` = 定义存在但无消费者
> - **下游**：F2 材料模型 / F3 蛊价值 / F4 晋升 / F5 商店 / F6 掉落 / F7 寿魂 / F8 模拟

---

## 0. 首要结论（三条颠覆性事实）

**这三条推翻了 `docs/wiki/concepts/economy.md` 与早期审计的若干表述，后续所有模型必须建立在此之上。**

| # | 事实 | 证据 |
|---|---|---|
| **A** | **层预算 `stone_budget` 无任何运行时注入** | 全仓仅 `content_catalog.gd:259-277` 校验用；无代码在进层时给玩家加元石 |
| **B** | **战斗胜利不掉元石** | `loot_resolver.settle_victory` 产出仅 `{material_ids, gu_id}`（loot_resolver.gd:38）；`battle_command_facade.gd:207-219` victory 分支不写 `stone` |
| **C** | **材料掉落直接进背包，无中间流程** | `_apply_loot`（loot_resolver.gd:303-320）直写 `state.materials[id] += 1` |

**推论 [INFERRED]**：元石是**纯卖方市场货币**——只能靠卖蛊 / 卖材料 / 打工采集 / 欺骗获得，
而层预算所谓"12→35 收入"**在代码中不存在**。这使 F5 商店审计的前提完全改变：
玩家的购买力不来自"层预算"，而来自**变卖战利品**。

---

## 1. 元石收入通道（全量）

| 通道 | 位置 | 触发 | 增量 | 性质 |
|---|---|---|---|---|
| 卖蛊 `sell_gu` | `refine_command_rules.gd:55` | 卖出持有蛊 | `GuBalance.gu_value(gu, rank)` | 取决于价值表 |
| 卖材料 `sell_material` | `refine_command_rules.gd:777,789` | 卖出材料 | `materials[id].value` × 持有 | 数据驱动 |
| 打工 `work` | `social_command_rules.gd:724` | 遭遇动作 | **硬编码 +3** | 固定 |
| 采集 `harvest` | `social_command_rules.gd:726` | 遭遇动作 | **硬编码 +2** | 固定 |
| 欺骗 `deceive` | `social_command_rules.gd:51` | 接触散修 | **硬编码 +2** | 固定 |
| 开局 buff `grant_stones` | `run_opening_flow.gd:43` | 开局遗物/契约 | buff `amount` | 一次性 |
| 立誓契约 `starter_stone` | `run_opening_flow.gd:150` | 开局契约 | `ContractRules.aggregate` | 一次性 |
| ~~遗物 `grant_stone_on_battle_end`~~ | `relic_hook_resolver.gd:108` | — | — | **[GAP] 死通道** |

### 1.1 收入结构问题

- **三条主要收入全是硬编码小数字（+2/+3/+2）**，与层数、转数、敌强度**完全无关**。
  层 5 打工赚 3 石，层 1 打工也赚 3 石 → **高层的元石购买力被通胀（+50% 价格）单方面侵蚀**。
- **战斗不产元石** → "打怪赚钱"这一最直觉的循环**在代码中不存在**。
- `relic_hook_resolver.apply_battle_end`（含 `grant_stone_on_battle_end`）**全仓无调用者** `[GAP]`。
- `essence_capacity.stone_to_essence`（balance `stone_to_essence_per_stone: 5`）**纯函数、无调用者** `[GAP]`
  → 规格局的"元石补真元"通道**未接线**。

---

## 2. 元石支出通道（全量）

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

### 2.1 支出结构问题

- **删卡/拔印记（120/150）与层预算量级严重脱节**：玩家若真能收到 12–35 石/层，
  删一张卡需要 **4–12 层的全部收入**。这两个服务在当前收入结构下**几乎不可达**
  （除非卖蛊/卖材料，见 §3.2）。
- **炼蛊 raw cost 极低（6/10 占 220/157 条）**，而古方解锁 60–200 很高 →
  **"解锁古方" 是真正的元石 sink，"炼蛊过程" 几乎免费**。

---

## 3. 蛊材（7 种）

### 3.1 全字段表 `[FACT]`

| id | 名称 | value | tier | 参考价 | dao_tags | diet_tags | 流动性 | 可分 | 常见 | 专属 | use |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `beast_bone` | 兽骨 | 1 | 1 | 5 | force | meat, bone | 0.7 | ✗ | ✓ | ✗ | 气血 +1 |
| `beast_blood` | 兽血 | 2 | 2 | 10 | blood, qi | meat | 0.8 | ✓ | ✓ | ✗ | 气血 +2 |
| `venom_sac` | 毒囊 | 3 | 3 | 15 | poison | — | 0.3 | ✗ | ✗ | ✗ | **气血 −1** |
| `moon_dew` | 月华露 | 4 | 4 | 20 | moon | — | 0.4 | ✓ | ✗ | ✗ | 真元 +2 |
| `moon_blue_petal` | 月蓝花瓣 | 1 | 1 | 5 | moon | herb | 0.5 | ✓ | ✓ | ✗ | 入药（无配方消费） |
| `boar_king_tusk` | 野猪王獠牙 | 1 | 1 | 15 | force | meat, bone | 0.2 | ✗ | ✗ | **✓** | 入药 |
| `inheritance_token` | 传承信物 | **30** | **3** | **60** | human | — | 0.5 | ✗ | ✗ | ✗ | **遗葬之地感应（无配方消费）** |

> 字段已全量补齐（原始 JSON 见 `_f1_extract.txt` §B）。
> **两个异常点 `[FACT]`**：
> - `inheritance_token` 的 `value=30` 是全场最高（兽骨 1 的 30 倍），参考价 60 与商店售价一致 ——
>   它是**唯一标着"世界观用途文本"却完全无配方消费**的材料，卖钱是它唯一现实功能。
> - `boar_king_tusk` 与兽骨**同 value=1 同 tier=1**，但 `is_exclusive=true` 且参考价 15（兽骨的 3 倍）→
>   **value / 参考价 / 流动性三者不自洽**（F2 需裁定哪个是权威锚点）。

### 3.2 配方使用分布 `[FACT]` — 兽骨单点依赖实锤

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
- 含 `materials` 字段的 **385/392**，含 `stone_cost` 的 **385/392**。
- **有效材料只有 5 种，其中 1 种占 378**；2 种**零使用**（`moon_blue_petal` / `inheritance_token`）。
- 矛盾点 `[FACT]`：`inheritance_token` **商店售价 60 石**（`shops.json` offer#26），
  其 `value=30` 是全场最高，但**配方零使用** → 买它等于纯浪费（F5 将标记为"永不会买"）。
- `moon_blue_petal` 出现在 `common` 掉落池，却在配方零消费 → **纯卖钱材料**（F2 需定性）。

### 3.3 value / 参考价 / 流动性 三元不自洽 `[FACT]`

| 材料 | `value` | `reference_value` | `public_liquidity` | 比值（参考价/value） |
|---|---|---|---|---|
| beast_bone | 1 | 5 | 0.7 | 5× |
| beast_blood | 2 | 10 | 0.8 | 5× |
| venom_sac | 3 | 15 | 0.3 | 5× |
| moon_dew | 4 | 20 | 0.4 | 5× |
| moon_blue_petal | 1 | 5 | 0.5 | 5× |
| **boar_king_tusk** | **1** | **15** | **0.2** | **15×** ⚠ |
| **inheritance_token** | **30** | **60** | **0.5** | **2×** ⚠ |

> 前 5 种严格满足 `reference_value = value × 5`；后 2 种破坏该规律。
> `boar_king_tusk` 的 `value=1` 与 `reference_value=15` 相差 15 倍，**明显是配置笔误或双轨制**，
> 但两者都被消费（`value` 用于 `sell_material`，`reference_value` 用于商店/估值）→
> **同一材料卖出与买入的定价基准不同**，F5 需裁定。

---

## 4. 蛊价值表

- `gu.json` **802 只**；`gu_value_by_rank = {1:3, 2:5, 3:8, 4:12, 5:20}`（balance.json）。
- `gu_estimate_ratio = 6.5`（用途待 F3 澄清）。
- **稀有度与转数强相关**（F3 将做交叉表验证）→ 换言之 `rarity` 不携带独立价值信息。
- 显式 `v1_effect` 48 只（Q8 已覆盖），其余走 role 兜底。

---

## 5. 商店（37 offers，非规格所说 33）

### 5.1 kind 分布 `[FACT]`

| kind | 数量 | 说明 |
|---|---|---|
| `purchase`（买蛊） | 20 | 6–80 石 |
| `gu_fang_unlock`（古方） | 5 | 80 ×3 / 200 ×2 |
| `material_purchase` | 3 | 3 / 10 / 60 |
| `resource_trade`（黑市） | 5 | 无元石，纯资源互换 |
| `recipe_unlock` | 1 | 60 |
| `soul_boost`（魂丹） | 1 | 6 |
| `lifespan_deal` | 1 | 寿元 1 换蛊 |
| `barter` | 1 | 以蛊换蛊 |
| `wash_notoriety` | 1 | 无显式价 |

### 5.2 tier 分布与价格

- 价格跨度 **3 → 200 石**。
- `remove_card_cost`(120) / `remove_imprint_cost`(150) 与最高价古方(200) 同量级。

---

## 6. 掉落表 `[FACT]`

### 6.1 `loot_tables.loot`（三档基准）

| tier | material_count | material_pool | gu_chance | 特殊 |
|---|---|---|---|---|
| common | 1 | beast_blood / beast_bone / moon_blue_petal | **0%** | — |
| elite | 1 | beast_blood / beast_bone / venom_sac | **30%** | `forced_rarity: epic` + `cost_pool`（诅咒 or 恶名+2） |
| boss | 2 | + moon_dew | **0%** | `scavenge_recipe`（2 条） |

### 6.2 层覆盖（`pacing.layers[*].loot`）

| 层 | material_count | 权重 common/rare/epic | shop_price_pct |
|---|---|---|---|
| 1 | 2 | 90/10/0 | 0% |
| 2 | 2 | 80/18/2 | 10% |
| 3 | 3 | 70/24/6 | 20% |
| 4 | 3 | 60/28/12 | 35% |
| 5 | 4 | 50/30/20 | **50%** |

**机制 `[FACT]`**（`loot_resolver._layer_table:121-141`）：层配置**覆盖** tier 的
`material_count` 与稀有度权重，`material_pool` / `by_rarity` 仍取 tier 表。

### 6.3 掉落问题

- **普通战斗不掉蛊（0%）** → 想拿蛊只有：买（6–80）、精英 30%、开局、以蛊换蛊。
- **Boss 不掉蛊（0%）却掉 2 份材料** → Boss 战回报可能**低于精英**（精英 30% 掉 epic 蛊）。
- 材料池高度重叠（三档都在 beast_blood/bone），**层数只加数量不加种类**。

---

## 7. 黑市（`resource_trade`，5 条）

| id | 付出 | 获得 | 比率 |
|---|---|---|---|
| `black_market_lifespan_for_soul` | 寿元 20 | 魂 1 | 20:1 |
| `black_market_soul_for_lifespan` | 魂 1 | 寿元 10 | 1:10 |
| `black_market_health_for_soul` | 气血 20 | 魂 1 | 20:1 |
| `black_market_soul_for_health` | 魂 1 | 气血 10 | 1:10 |
| `black_market_health_for_lifespan` | 气血 20 | 寿元 10 | 2:1 |

- **往返亏损**：寿元→魂→寿元 = 20 进 10 出（**亏 50%**）。
- **无三角套利** `[INFERRED]`：需 F7 严格验证（20 气血→10 寿元→0.5 魂；回路不通）。
- `life_cost` 现网 **全 0**（gu.json 无一只设置）→ 寿元**只出不进**且**无消耗场景**（F7 核心问题）。

---

## 8. 未接线通道汇总 `[GAP]`

| 通道 | 位置 | 状态 |
|---|---|---|
| 层预算注入 | `stone_budget` | 仅校验，无注入 |
| 战斗元石奖励 | `settle_victory` | 无 stone 字段 |
| 遗物战斗结算钩 | `relic_hook_resolver.apply_battle_end` | 无调用者 |
| 元石补真元 | `essence_capacity.stone_to_essence` | 无命令 |
| 传承信物用途 | `inheritance_token` | 商店在卖，配方零用 |
| 月蓝花瓣用途 | `moon_blue_petal` | 掉落池有，配方零用 |
| `durability_mode` | 全 3 模式 | 现网零配置（Q8 审计已记） |

---

## 9. 对本阶段的意义

F1 证明：**当前经济不是"数值不平衡"，而是"循环结构缺失"**。

- **收入端**：无层预算、无战斗掉落、无遗物钩 → 靠硬编码 +2/+3 与变卖。
- **材料端**：1 种垄断 98%，2 种零用途。
- **支出端**：删卡/拔印（120/150）在收入结构下不可达；炼蛊几乎免费。
- **蛊端**：普通战斗不掉蛊，Boss 也不掉。

因此 F2–F7 的目标不是"调价"，而是**回答每种资源为何存在、玩家为何要它**
（对应任务书 §十五："为什么这个东西值这么多元石"）。

> 价格修改留到 F8 之后，且须外部架构审阅者裁定。本文件不含任何数值改动建议。
