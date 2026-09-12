# SHOP_VALUE_AUDIT.md — Q8-F F5：商店经济审计

> - **阶段**：Q8-F / F5（**只审计，不改生产数值**）
> - **日期**：2026-09-12
> - **上游**：F1 §5 / F2 §4 / F3 §1 / F4 §2
> - **下游**：F6 掉落 / F8 模拟
> - **注**：实测 **37 offers**（规格文档所说 33 已过时）

---

## 0. 首要结论

### 0.1 三条颠覆性事实 `[FACT]`

| # | 事实 | 证据 |
|---|---|---|
| **A** | **商店买价与 `gu_value` 完全脱钩** | `shop_layer_price` = `stone_cost`（数据写死）+ 层通胀；**从不调用 `gu_value`** |
| **B** | **同一只蛊的买价可差 26 倍** | `purchase_heaven_dew` 80 石 vs `small_light_gu` 12 石，**两者 `gu_value` 都是 3** |
| **C** | **商店回收价 ≠ 买价的对称面** | 卖出走 `sell_price_for(base=gu_value)` → **买贵卖贱脱钩** |

> **含义 `[INFERRED]`**：商店**不是"定价系统"，而是 37 条手工定价条目**。
> 每条的 `stone_cost` 是**独立拍的数字**，没有公式、没有基准、没有与价值表对照。
> 因此 F5 的核心任务不是"评价格高低"，而是**逐条回答"这个价格迫使玩家做什么选择"**。

### 0.2 商店价格公式 `[FACT]`

```
最终买价 = ceil( stone_cost × (1 + 恶名% /100) × (1 + 回访% /100) × (1 + 契约% /100) )
              × (1 + 层通胀 shop_price_pct/100)

层通胀: 层1 = 0% / 层2 = 10% / 层3 = 20% / 层4 = 35% / 层5 = 50%
恶名:   price_pct_per_point = 10%/点，上限 60%
服务涨价: 每次使用 +25%，上限 +100%（删卡/拔印适用）
```

> **关键 `[FACT]`**：**`stone_cost` 是唯一的价值输入**，层通胀是**唯一的动态调整**。
> 层通胀是**对所有货品统一加价**（不区分贵贱）→ 它**不改变相对价格结构**，
> 只**整体抬高** → 结果是 §2.2 的"高层购买力崩塌"。

---

## 1. 全部 37 条 offer 逐条审计

### 1.1 `purchase`（买蛊，19 条）

| id | 蛊 | 转 | 价 | `gu_value` | **买/价倍率** | tier | 流派 |
|---|---|---|---|---|---|---|---|
| `purchase_stone_shell` | stone_shell_gu | 1 | 6 | 5 | **1.2** | 1 | — |
| `purchase_moonlight` | moonlight_gu | 1 | 6 | 4 | 1.5 | 3 | — |
| `purchase_thunder_ward` | qi_atk_1_01_gu | 1 | 9 | 3 | 3.0 | 4 | — |
| `purchase_moon_glow` | moon_glow_gu | 2 | 12 | 9 | **1.33** | 5 | — |
| `purchase_small_light_gu` | small_light_gu | 1 | 12 | 3 | 4.0 | 1 | — |
| `purchase_jade_skin_gu` | jade_skin_gu | 1 | 30 | 8 | 3.75 | 1 | — |
| `purchase_white_boar_strength_gu` | white_boar_strength_gu | 1 | 35 | 10 | 3.5 | 1 | — |
| `purchase_mending_grass` | wood_atk_1_05_gu | 1 | 8 | 3 | 2.67 | 1 | — |
| `purchase_bone_knit` | bone_atk_1_08_gu | 1 | 14 | 3 | **4.67** | 2 | — |
| `purchase_spring_heart` | human_atk_1_01_gu | 1 | 18 | 3 | **6.0** | 3 | — |
| `purchase_moon_shadow_300` | moon_shadow_gu | 3 | 40 | 16 | 2.5 | 3 | — |
| `purchase_life_root` | wood_atk_1_05_gu | 1 | 20 | 3 | **6.67** | 4 | — |
| `purchase_undying_vine` | wood_atk_1_05_gu | 1 | 20 | 3 | **6.67** | 4 | — |
| `purchase_heaven_dew` | water_atk_1_08_gu | 1 | **80** | 3 | **26.67** ⚠ | 5 | — |
| `purchase_sword_atk_1_06` | sword_atk_1_06_gu | 1 | 8 | 3 | 2.67 | 1 | sword |
| `purchase_sword_atk_2_12` | sword_atk_2_12_gu | 2 | 18 | 5 | 3.6 | 2 | sword |
| `purchase_sword_def_3_14` | sword_def_3_14_gu | 3 | 30 | 8 | 3.75 | 3 | sword |
| `purchase_sword_heal_4_16` | sword_heal_4_16_gu | 4 | 45 | 12 | 3.75 | 4 | sword |
| `purchase_sword_atk_5_02` | sword_atk_5_02_gu | 5 | 70 | 20 | 3.5 | 5 | sword |

**逐条判定**：

| 判定 | 条目 | 理由 |
|---|---|---|
| **必买（性价比最优）** | `stone_shell`(1.2)、`moon_glow`(1.33)、`moonlight`(1.5) | 买价 ≈ 回收价，**几乎零损耗** |
| **合理** | 4 条 sword（3.5–3.75） | 倍率一致，且 sword 有升转链（F4 §2） |
| **偏高** | `thunder_ward`(3.0)、`jade_skin`(3.75)、`white_boar`(3.5)、`mending_grass`(2.67)、`moon_shadow`(2.5)、`sword_atk_1_06`(2.67) | 需要玩家真觉得这只蛊有用才值 |
| **陷阱** | `bone_knit`(4.67)、`spring_heart`(6.0)、`life_root`(6.67)、`undying_vine`(6.67) | 买价是回收价 **4.7–6.7 倍**，卖出即巨亏 |
| **荒谬** | **`heaven_dew`(26.67)** | **80 石买一只 `gu_value=3` 的转 1 蛊** |
| **重复条目** ⚠ | `mending_grass` / `life_root` / `undying_vine` **都是 `wood_atk_1_05_gu`** | **同一只蛊三个不同价格（8/20/20）挂三档** |

> **最严重问题 `[FACT]`**：`purchase_heaven_dew` 与 `purchase_life_root`/`undying_vine`。
> - `heaven_dew`：80 石 → **26.67 倍**回收价。玩家若不知情，买了就是**扔掉 77 石**。
> - 三只 wood 同蛊不同价 → **玩家在层 1 花 8 石买完，到层 4 看到 20 石的同一只蛊**。

### 1.2 `gu_fang_unlock`（古方，5 条）

| id | 产物 | 价 | tier | 判读 |
|---|---|---|---|---|
| `gu_fang_moon_glow_gu` | moon_glow_gu | 80 | 2 | 与直接买 `purchase_moon_glow`(12) 相比：**古方贵 6.7 倍** |
| `gu_fang_white_jade_gu` | white_jade_gu | 80 | 2 | `white_jade_gu` `gu_value=30`，但**无 purchase offer** |
| `gu_fang_blood_heal_2_23_gu` | blood_heal_2_23_gu | 80 | 2 | — |
| `gu_fang_blood_atk_3_03_gu` | blood_atk_3_03_gu | **200** | 3 | 转 3 蛊 `gu_value=8` → **古方贵 25 倍** |
| `gu_fang_blood_atk_3_11_gu` | blood_atk_3_11_gu | **200** | 3 | 同上 |

> **关键 `[FACT]`**：**古方解锁是"知识"而非"物品"**。
> 它给的是 `global_codex_ids`（跨局永久），而 `advance` **本来就豁免蛊方门禁**（F4 §1.1）→
> **玩家花 80–200 石买来的古方，对 advance 毫无影响**。
> 唯一受益的是 `fixed` 配方（13 条），但其中 8 条已 `default_unlocked`。
> → `[INFERRED]` **古方售卖的实际价值 ≈ 0**（除非玩家想用未解锁的 fixed 配方）。

### 1.3 `material_purchase`（买材料，3 条）

| id | 材料 | 价 | 材料 `value` | 材料 `reference_value` | 判读 |
|---|---|---|---|---|---|
| `purchase_moon_blue_petal` | moon_blue_petal | 3 | 1 | 5 | 买 3 卖 1，**且无配方用途**（F2 §2.5）→ **纯亏** |
| `purchase_boar_king_tusk` | boar_king_tusk | 10 | 1 | 15 | **唯一来源**（无掉落池），但只服务 2 条配方 |
| `purchase_inheritance_token` | inheritance_token | 60 | 30 | 60 | **无任何用途**（F2 §2.7）→ 买 60 卖 30，**纯亏 30** |

> **`[FACT]` 最大缺口**：**商店不卖兽骨**。
> 而兽骨是 377 条 advance 的**唯一材料**（F4 §1.2）——
> 玩家**唯一的兽骨来源是掉落**，无元石兜底通道。

### 1.4 `resource_trade`（黑市兑换，5 条）

| id | 付出 | 获得 | 比率 | 判读 |
|---|---|---|---|---|
| `black_market_lifespan_for_soul` | 寿元 20 | 魂 1 | 20:1 | 见 F7 |
| `black_market_soul_for_lifespan` | 魂 1 | 寿元 10 | 1:10 | 见 F7 |
| `black_market_health_for_soul` | 气血 20 | 魂 1 | 20:1 | 气血换魂 |
| `black_market_soul_for_health` | 魂 1 | 气血 10 | 1:10 | 魂换气血（**上限受 max_health 限制**） |
| `black_market_health_for_lifespan` | 气血 20 | 寿元 10 | 2:1 | 气血换寿元 |

> **门禁 `[FACT]`**：`resource_trade_plan` 用 `node_flags[offer_id] = "used"` 做**一次门禁**
> → **每个 offer 每局只能用一次** → 无法刷。
> `[INFERRED]` 这削弱了套利空间（但往返亏损仍在，见 F7）。
> **注意**：5 条全部 `tier=1` → **层 1 就能用**，不受层门禁（服务常驻）。

### 1.5 服务类（5 条）

| id | kind | 价 | 判读 |
|---|---|---|---|
| `soul_pill` | `soul_boost` | 6 | 魂 +1（`soul_max` 封顶）→ **全场最便宜的成长** |
| `wash_notoriety` | `wash_notoriety` | 无显式价 | 洗恶名（恶名降买价） |
| `purchase_white_jade_recipe` | `recipe_unlock` | 60 | 解锁 `white_jade_advance` |
| `lifespan_pulse_drum` | `lifespan_deal` | **寿元 1** | 用寿元换 `qi_atk_1_01_gu`（`gu_value=3`） |
| `barter_unknown_gu` | `barter` | `qi_rec_2_14_gu` | 以蛊换蛊（+概率遗物） |

> **`lifespan_deal` 判读** `[FACT]`：**寿元 1 换一只 `gu_value=3` 的蛊**。
> 对照 `black_market_health_for_lifespan`（气血 20 → 寿元 10）→ **寿元 1 ≈ 气血 2**。
> 即：**2 点气血换一只转 1 蛊** —— 这个兑换率**远优于任何其他通道**。

---

## 2. 结构诊断

### 2.1 价格离散度失控 `[FACT]`

`purchase` 的买/价倍率分布：

| 倍率区间 | 条数 | 条目 |
|---|---|---|
| 1.0–1.5 | 3 | stone_shell, moon_glow, moonlight |
| 1.5–3.0 | 6 | thunder_ward, mending_grass, moon_shadow, sword×2, sword_atk_1_06 |
| 3.0–5.0 | 7 | small_light, jade_skin, white_boar, bone_knit, sword_def, sword_heal, sword_atk_5 |
| 5.0–7.0 | 4 | spring_heart, life_root, undying_vine |
| **> 26** | **1** | **heaven_dew** |

> **离散度 1.2 → 26.67（22 倍差距）**，且**没有任何可解释的排序**
> （`heaven_dew` 和 `small_light_gu` 的 `gu_value` **完全相同 = 3**）。

### 2.2 层通胀的"反向筛选" `[FACT]`

| 层 | 通胀 | 例：`purchase_life_root` 实际价 | 玩家层收入（F1：+2/+3 硬编码） |
|---|---|---|---|
| 1 | 0% | 20 | ~5–8/层 |
| 2 | 10% | 22 | ~5–8 |
| 3 | 20% | 24 | ~5–8 |
| 4 | 35% | **27** | ~5–8 |
| 5 | 50% | **30** | ~5–8 |

> **`[FACT]` 收入恒定（+2/+3）而价格逐层上涨 50%** →
> **层 5 的相对购买力只有层 1 的 2/3**，而层 5 的货**恰好是最贵的**
> → **越往后越买不起**，与"越深越富"的直觉完全相反。

### 2.3 货架机制 `[FACT]`

- **槽位**：`4 + ⌊层/2⌋` → 层 1=4、层 2=5、层 3=5、层 4=6、层 5=6。
- **货池**：37 里的 `SHOP_GOODS_KINDS` = `purchase`(19) + `material_purchase`(3)
  + `gu_fang_unlock`(5) + `barter`(1) + `lifespan_deal`(1) = **29 条**。
- **洗牌取前 N**：种子 = (局种子, 节点模板 id) → **同店恒定、不刷货**。
- **保底两条**：①本层最高档至少 1 件；②**本流派蛊至少 1 件**（若玩家选了流派）。
- **服务常驻**：`resource_trade` / `wash_notoriety` / `recipe_unlock` / `soul_boost` **不受货架限制**。

> **`[INFERRED]` 货架机制的后果**：
> 层 1 有 29 条候选、只有 4 个槽 → **玩家平均每局看不到 86% 的货**。
> 加上"保底本流派蛊"，**散修（未选流派）反而少一条保底** → 散修看到好货的概率更低。

---

## 3. 逐条"迫使玩家做什么选择"（任务书 §八核心问题）

| offer | 玩家面对的选择 | 是否有趣 |
|---|---|---|
| `stone_shell`(6) | 买（1.2 倍，几乎零损耗）→ **无脑买** | ❌ |
| `moonlight`(6) / `moon_glow`(12) | 买 → **无脑买**（且 moon_glow 可 advance） | ❌ |
| `heaven_dew`(80) | **看到就跳过**（或误买巨亏） | ❌ **陷阱** |
| `life_root`/`undying_vine`(20) | 跳过（同蛊层 1 只卖 8） | ❌ 矛盾 |
| `bone_knit`/`spring_heart`(14/18) | 除非真需要，否则跳过 | ⚠️ 弱 |
| sword ×5 | **买**（有升转链，3.5 倍合理） | ✅ 唯一正解 |
| `gu_fang_*`(80–200) | **跳过**（advance 本来就豁免门禁） | ❌ 无效 |
| `purchase_inheritance_token`(60) | **跳过**（纯亏 30） | ❌ 陷阱 |
| `purchase_moon_blue_petal`(3) | 跳过（无用途） | ❌ 无效 |
| `purchase_boar_king_tusk`(10) | **必须买**（唯一来源）否则 2 条配方永久锁死 | ⚠️ 被迫 |
| `lifespan_pulse_drum` | **考虑**（2 气血 = 1 蛊，比率最优） | ✅ |
| `soul_pill`(6) | **考虑**（最便宜成长） | ✅ |

> **F5 判定**：37 条 offer 里，玩家会做出**真实权衡的只有 3–4 条**
> （sword 系列、`lifespan_deal`、`soul_pill`）。
> **其余 33 条**要么无脑买（3 条）、要么无脑跳过（→ 无效条目 20+ 条）、
> 要么是**纯亏陷阱**（`heaven_dew` / `inheritance_token`）。

---

## 4. 交给下游

| 下游 | F5 输入 |
|---|---|
| **F6 掉落** | 商店买不到兽骨 → **掉落是唯一来源**；普通战 0% 掉蛊 → **商店是唯一稳定蛊源** |
| **F7 寿魂** | `lifespan_deal`（寿元 1 → 蛊）是全游戏**最优兑换率**；须与黑市 5 条一起裁定 |
| **F8 模拟** | 需观测：玩家**是否几乎从不买中高价货**；`heaven_dew`/`inheritance_token` 是否**从未被买** |

---

## 5. 待外部裁定问题

1. **商店买价是否应锚定 `gu_value`？**（当前 37 条手工数字，倍率差 22 倍）
2. **`purchase_heaven_dew`(80) / `purchase_inheritance_token`(60) 是否为配置错误？**
3. **`mending_grass`/`life_root`/`undying_vine` 同蛊三价是否为错误？**
4. **古方（80–200）是否应降价或改为解锁非 advance 配方？**（当前近乎无价值）
5. **是否应增加兽骨 offer？**（当前唯一"无元石兜底"的必需材料）
6. **层通胀是否应改为"只影响高档货"？**（当前整体加价使高层更穷）

> 6 项均超出 F5 权限，留待 F8 汇总 + 外部架构审阅者裁定。
