# 数值现状对账（只读）

> **性质**：**纯审计，零改动**。本文不改任何生产数值，不新增数值，不给出"应该改成多少"的结论。
> 目的：把"这个游戏的数值现在到底是什么状态"讲清楚——哪些已定、哪些自相矛盾、哪些是真空，
> 供拍板时使用。
>
> **日期**：2026-09-19 · **方法**：逐文件读取 + 数据实测统计；每条结论标注出处；
> 凡我未能亲自核到的，写"未核"。
>
> **边界**：本文**不裁定**任何争议项的取值（尤其三条转数曲线）；只做并列陈述。

---

## 0. 两项必须先更正的治理事实

这两条直接决定"现在能不能改数值"，且我此前引用过**已失效**的文档，先纠正。

### 0.1 旧的冻结令已作废（2026-09-17）

我此前引用的 `docs/q8f/EXTERNAL_REVIEW_RULING.md`（"⛔ 第 0 批完成前不修改任何生产数值"）与
`docs/q8g/Q8G_BATCH0_RULING.md`（"Agent 不得自行决定数值"）**均已失效**：

| 依据 | 内容 |
|---|---|
| `world-model/rulings/RUL-2026-09-17-003.json` | 制作人裁定："去他娘的规矩，把目前所有的约束都无效" |
| 同上 `voids[]` | 明确作废 `docs/q8f/EXTERNAL_REVIEW_RULING.md`、`docs/q8g/Q8G_BATCH0_RULING.md`、`Stage 0 hard gate 与生产冻结令`、"Agent 无选职权 / 不得自行决定数值 / 语义冻结≠数值冻结" |
| `world-model/governance/CONSTRAINTS-V2.md` §1 | 作废清单 C 组：`docs/q8*`（RULING / WORKSHEET / BATCH / REACHABILITY）全部解除约束力 |

**现行约束（`CONSTRAINTS-V2.md` §3，6 条，可执行）**：

| # | 规则 | 落地 |
|---|---|---|
| R1 | 数据即规范，结构由 schema + 校验器强制 | `world-model/tools/validate_world_model.py` |
| R2 | 一条命令验收，退出码即结论 | `world-model/tools/accept.py` |
| R3 | 一条裁定一个文件 | `world-model/rulings/*.json` |
| R4 | **默认放行 + 自动快照**："任何文件都可改；改前自动快照，改后自动校验；**不再有'禁止修改'**" | `world-model/tools/snapshot.py` |
| R5 | 约束必须可执行（写不进脚本的规则不许存在） | 评审口径 |
| R6 | 验收不靠人勾选 | `accept.py` |

**未随本次裁定作废的 3 条**（§2）：种子确定性（可复现）、改前可回滚（快照）、不复制原著正文。

> §6 原话：**"数值与玩法仍由你拍板，我只负责让改动快、可验证、可回滚。"**
> 即：**现在可以改数值了**，但改动要走 `world-model/data/` 且必须过 `accept.py`。

### 0.2 主文档把"单点调参入口"写反了方向

`world-model/docs/数值与成长曲线.md:3` 写：

> **单点调参入口**：`world-model/data/balance.json`（唯一实体 `world_balance`）。改数值只需改那里。

**实际方向相反**。`world-model/tools/build_world_model.py:1-2` 的文件头写着：

> Derive the machine-readable world model under world-model/data/ **from the read-only Godot
> prototype tables under data/**. STRICTLY READ-ONLY on the parent repository.

并且 `check_upstream_drift.py:1-2`：

> world-model/data 是**从上游 data/ 派生的快照**，上游被并行改动后两边会静默漂移。

`build_world_model.py:1052-1057` 列出的 `read_only_upstream` 共 21 个文件，含
`data/balance.json`、`data/aptitude.json`、`data/v1_battle.json`、`data/pacing.json`、
`data/loot_tables.json`、`data/shops.json`。

**结论**：

- **上游（真源）= `game/data/*.json`**；改那里。
- **`world-model/data/*.json` = 派生镜像**；改它的下一次 `build_world_model.py` 会被覆盖，
  且会触发 `check_upstream_drift.py` 退出码 1。
- 数值实际**分散在 6 个上游文件**，不是"一个入口"：

| 上游文件 | 承载的数值 |
|---|---|
| `data/balance.json` | 通用倍率、人本锚、蛊价值锚、自由配对、突破成本、战斗产石 |
| `data/aptitude.json` | 真元基数、资质系数、转数系数、局外回复率 |
| `data/v1_battle.json` | 战斗真元 `stage_base`、战斗回复率、role 兜底效果、杀招 26 条 |
| `data/pacing.json` | 层缩放、turn_scaling、层预算、商店加价、敌人 rank 区间 |
| `data/loot_tables.json` | 掉蛊率、材料数、稀有度权重、保底 |
| `data/shops.json` | 38 条报价的 `stone_cost` |

---

## 1. 十问逐条对账

**图例**：✅ 已定（有成文口径）· ⚠️ 自相矛盾（有多套并存或文档与代码不符）· ❌ 真空（无成文口径）

### Q1. 一转→五转应在什么区间 ⚠️ 已定但三套并存

数**存在三套独立转数曲线**，服务对象不同，但没有任何一处把它们并列对账（详见 §2）。

| 曲线 | 公式 | 1→5 转 | 出处 |
|---|---|---|---|
| 局外真元上限 | `essence_base(10) × aptitude_factor × cultivation_factor` | 丙等 **20 / 60 / 180 / 540 / 1620** | `data/aptitude.json:2,3,9` |
| 战斗真元上限 | `stage_base_battle[转] × aptitude_factor` | 丙等 **20 / 60 / 120 / 200 / 300** | `data/v1_battle.json` `stage_base` |
| 通用强度倍率 | `rank_step_ratio ^ (rank-1)` | **1 / 2 / 4 / 8 / 16** | `data/balance.json:6`；代码 `scripts/domain/gu_balance.gd:28` |

其余已定的转数相关口径：

- **突破成本**（`data/balance.json:87-90`）：2 转 5 / 3 转 12 / 4 转 20 / 5 转 30 元石；
  3 转起硬门槛"资质 ≥ 乙等"（`world-model/data/balance.json` → `growth.aptitude_hard_gate`）。
- **资质系数**：`丁1 / 丙2 / 乙3 / 甲4`（线性轴）。
- **人本锚**：`human_base_health = 100`、空手重击 20（`data/balance.json:8`，`standard_hit_ratio`）。
- **强度参照系**：`standard_gu_power(转) = 100 × 0.2 × 2^转` = 40/80/160/320/640；
  `beast_scale = 100 × 2^转` = 100…3200。

> ⚠️ **量纲断裂（已被察觉并冻结，非新发现）**：`数值与成长曲线.md:60-63` 自述——
> "这三张表里 `standard_gu_power` / `beast_scale` 的量级（40–3200）**远大于**实际敌我
> HP（3–20）与蛊伤（1–8）。原型用它们做「量纲参照」而不是直接战斗数值。**本模型不改这个口径**。"
> 即：**参照系与实战数值是两套量纲，且被有意保持不一致**。

### Q2. 强敌 vs 弱敌 ⚠️ 实测有清晰带，但无成文表

**没有**任何文档规定 per-rank 的敌人 HP/伤害。敌人属性是**逐条手写**的。实测分布（`data/enemies.json` 32 条）：

| tier | rank | 条数 | HP | 伤害 |
|---|---|---|---|---|
| common | 0–2 | 13 | 3–5 | 1–2 |
| elite | 2–5 | 12 | 6–11 | 2–4 |
| boss | 3–5 | 7 | 14–20 | 2–5 |

**成文的只有层缩放**：

- `data/pacing.json` → `turn_scaling`：每回合 HP +2 / 伤害 +1，上限 +6 / +2。
- `data/v1_battle.json` → `boss_layer_mult`：HP ×1.0/1.1/1.2/1.35/1.5，伤害 ×1.0/1.05/1.1/1.15/1.25。
- `data/pacing.json` → 各层 `enemy_rank_min/max`：[0,1] / [0,2] / [1,3] / [2,4] / [3,5]。
- tier 权重 `common 75 / elite 25 / boss 0`（boss 只在锚点摆放）。

> 一处相关的**已作废**裁定：`Q8G_BATCH0_RULING.md:203`「是否按敌人 HP/伤害实时公式」**冻结为否**
> （针对战斗产石定价，不是针对敌人属性本身）。该文件已被 2026-09-17 裁定作废（§0.1）。

**缺的是**：同 tier 同 rank 的敌人之间如何区分强弱（目前只能看手写 HP）。也**没有**"敌人强度 → 玩家应有战力"的对照。

### Q3. 强蛊 vs 弱蛊 ❌ 真空（且存在两套不可比的通道）

`data/balance.json:65-71` → `gu_value_by_rank` = **3 / 5 / 8 / 12 / 20**（1–5 转）。

**这是唯一的成文"强弱"口径，且只读"转数"一轴**：

- 代码 `scripts/domain/gu_balance.gd:20-24`：`value = max(定义 value, 中央表[实例转数])`。
- 802 只蛊被压成 **5 个价位**。
- 例外的 13 只"策展蛊"必须在 `gu_value_anchor_exceptions` 显式登记，否则校验失败。
- `rarity`（common 368 / rare 185 / epic 249）**不参与定价**，只作用于掉落入池选择。
  ⚠️ 且 `epic(249) > rare(185)`，与"越稀有越少"的直觉相反，排序本身可疑。

**真正没回答的是"同转之下谁更强"**，因为战斗数值走两条**不可比**的通道：

| 通道 | 覆盖 | 伤害如何定 | 随转数放大？ |
|---|---|---|---|
| 显式 `v1_effect` | **61 只** | 手写 `amount`（见下表值域） | ❌ **否** |
| role 兜底 `default_effect_by_role` | **741 只** | `base + (rank-1)` | ✅ 是 |

证据：`scripts/domain/v1_battle_resolver.gd:469` —— `var amount := int(effect.get("amount", 0))`，
**直接取 amount，不加任何 rank 项**；只额外叠加 `turn_supports`（同流派支援）与 `sword_intent`（仅剑道）。

`docs/q8/CURRENT_EFFECT_CAPABILITY_MATRIX.md:67` 明写：

> **转数放大仅作用于此表**：strike/shield/heal 三种 kind 执行 `amount = base + (rank-1)`。
> 即：一只 5 转 attack 蛊与一只 1 转 attack 蛊的差异 = strike 6 vs strike 2，以及价值 20 vs 3。

**实测显式 61 只的 amount 值域**（无转数函数）：

| kind | 只数 | amount 取值 |
|---|---|---|
| strike | 28 | 1, 2, 3, 4, 5, 6, 8, **999**(测试蛊) |
| heal | 11 | 1, 2, 5 |
| shield | 7 | 3, 5 |
| shift | 6 | 1 |
| sword_intent | 5 | 1, 2 |
| status | 2 | 1 |
| heal_and_strike | 1 | 1 |
| weaken_intent | 1 | 2 |

⚠️ **`data/gu.json` 里存在测试残留**：`test_slay_gu`，`rank = 10`、`tags:["test"]`、
`v1_effect.amount = 999`、`value = 0`。

**后果（本对账的核心发现）**：显式通道里**转数与伤害完全脱钩**，甚至**倒挂**。实测 28 条显式 strike 的"转数 × 伤害"：

| 转数 | strike 伤害 | 例 |
|---|---|---|
| 1 | 1, 2, 2, 2, 2, 2, 3, **4** | `blood_farewell_gu` = **4** |
| 2 | 3 ×9, **4**, 4 | `moon_glow_gu` / `moon_ray_gu` = 4 |
| 3 | **2** | `water_atk_3_05_gu` = **2** |
| 4 | 5 | `sword_atk_4_01_gu` |
| 5 | 6, 6, 6, 6, 8 | `blood_atk_5_02_gu` = 8 |

即：**三转 `water_atk_3_05_gu`（strike 2）比一转 `blood_farewell_gu`（strike 4）更弱**，
`small_light_gu`（一转 strike 1）与其它一转蛊并列最弱。
"强的蛊和弱的蛊的区别"在显式通道里**没有定义**——转数既不单调、也不放大。

> 相关：`docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md:40,42` 声称 strike / heal "沿用 rank 缩放
> （`amount = base + (rank-1)`）"。**这句对显式通道不成立**（代码如上）。它描述的只是兜底通道。
> `CURRENT_EFFECT_CAPABILITY_MATRIX.md:29` 的措辞才是准的："显式 amount 无转数放大（手写 1-6）"。

### Q4. 强杀招 vs 弱杀招 ❌ 真空（无中央公式）

`data/v1_battle.json` → `kill_moves`，**26 条**。伤害**逐条手写**，无公式。

剑道两条线的五档（其余各线见文件）：

| 杀招 | 1 转 | 2 转 | 3 转 | 4 转 | 5 转 |
|---|---|---|---|---|---|
| 双锋引 | 4 | 6 | — | 8 | 12 |
| 五指拳心剑 | — | 15 | — | 17 | 24 |
| 剑气冲霄 | 2 (+回2) | 3 (+回2) | — | 5 (+回5) | 6 (+回5) |
| 剑痕索命 | 2 | 3 | — | 5 | 6 |

真元消耗 3–7、念头 1–2。**转数与消耗、转数与伤害都没有单调函数关系**
（例：五指拳心剑·二转 15 伤 7 真元，双锋引·五转 12 伤 4 真元）。

**结算走双通道**（`scripts/domain/v1_battle_resolver.gd:735-737`）：

```gdscript
next = _apply_effect(next, {"effect": km.get("effect", {}), "school": tag}, "kill_move")
if int(km.get("damage", 0)) > 0:
    next = _strike_enemy(next, int(km.get("damage", 0)))
```

即 `effect`（吃支援/剑意/consume_status 修饰）**与** `damage`（直调 `_strike_enemy`，**绕过全部修饰**）
两条路同时生效。26 条里只有 **1 条**（`km_force_avalanche` 崩山）用了 `damage: 8` + `effect: {}`，
其余 25 条走 `effect`。**结论：不是 bug（两种写法都能打出伤害），但是同一件事有两个写入位置。**

规格层的既定要求（`docs/superpowers/specs/2026-09-01-gu-system-economy-combat-design.md` §4.2）：
"杀招默认累加组成蛊的真实真元、念头、蛊材和使用次数成本。任何节省、增幅或额外代价都必须来自明确杀招规则。"
**数据现状与这条不符**：26 条杀招的成本是手写固定值，未从组成蛊累加。

### Q5. 攻 / 防 / 治疗蛊虫的区别 ✅ 已定（role 兜底表 + 已冻结的操作集）

**基线口径** `data/v1_battle.json` → `default_effect_by_role`（覆盖 741 只）：

| role | 效果 | 转数放大后（1→5 转） |
|---|---|---|
| attack | strike 2 | 2 → 6 |
| defense | shield 3 | 3 → 7 |
| healing | heal 2 | 2 → 6 |
| movement | shift 1 | 1 → 5 |
| logistics | heal 1 | 1 → 5 |
| recon | status marked 1 + **自流派支援 1** | 1 → 5 |

**冻结的操作集只有 5 个**（`docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md` §2）：
`strike` / `shield` / `heal` / `status` / `weaken_intent`。
明确排除为"遗留兼容、不扩展"：`move` / `buff` / `shift` / `heal_and_strike` / `sword_intent`。

两条硬纪律：**一效果一操作**（不新增复合）；**先付费后延迟**（`delay` 是 modifier，cost 打出时付）。

`status` 的两个 id：`marked`（上限 10 层，每层每回合 1 伤）、`sealed`（门禁目标下一次 damage intent，最小纵切）。
`weaken_intent`（第 5 个操作）：per-target 削目标**下一次** damage intent 数值，用后清零。

### Q6. 增幅型蛊虫 ✅ 已定（是 modifier，不是 operation）

- **数据键**：`v1_effect.support_school` + `support_bonus`；`"self"` 哨兵解析为蛊自身流派。
- **机制**（FINAL §3）：打出后 `turn_supports[school] += support_bonus`；本回合**后续**同流派 `strike`
  获加成；**`end_turn` 清零**——**只在本回合内、只作用于 strike**。
- **明确不修饰 `heal` / `shield`**（FINAL §3 原文）。
- **自己不结算、不造伤，只登记。**

**现网实例极少**：矩阵 §3 记 `support_bonus` **5 只**（3 只 `"self"` 哨兵 + 2 只指定流派），
另 recon role 兜底给全员注入支援 1。**没有成文的 support_bonus 随转数曲线**——这一项是真真空。

### Q7. 敌人掉落资源价值 ✅ 已定

| 维度 | 口径 | 出处 |
|---|---|---|
| 战斗产石 | common **3** / elite **8** / boss **15**，每层 +20% | `data/balance.json:91-99` |
| 层预算（规划参数，非发钱机制） | 12 / 16 / 22 / 28 / 35 | `data/pacing.json` |
| 掉蛊率 | common **6%** / elite **30%** / boss **0%** | `data/loot_tables.json` |
| 材料数 | common 1 / elite 1 / boss 2 | 同上 |
| 稀有度权重（按层） | 1 层 90/10/0 → 5 层 50/30/20 | 同上 |
| 保底 | 阈值 3，**按 tier 独立** | 同上 |
| 7 种核心蛊材 | value 1–4 / 参考价 5–20 | `数值与成长曲线.md` §3.3 |

⚠️ elite 的 `gu_chance 30%` 实际只出 3 只（`forced_rarity: epic` 把池缩到 3 只）；
boss **0% 且蛊池为空**——即 Boss 在掉蛊上严格劣于精英。这是已登记的获取通路问题。

### Q8. 蛊 / 蛊方 / 杀招 的等价资源关系 ⚠️ 部分已定，杀招无价

| 对象 | 定价 | 出处 |
|---|---|---|
| **蛊** | `gu_value_by_rank` 3/5/8/12/20；卖出 `max(定义 value, 中央表[转数])`；回购比 0.5、低流动性 0.3 | `data/balance.json:65`，`gu_balance.gd:20` |
| **蛊方** | 商店 `gu_fang_unlock` **80**（tier2）/ **200**（tier3）；`recipe_unlock` **60** | `data/shops.json` |
| **杀招** | **全仓无任何价格**。只靠持有配方获得，不进入购买 | — |

**商店买价与 `gu_value` 完全脱钩**（代码级确认）：

```gdscript
# scripts/domain/shop_command_rules.gd:201-206
static func shop_layer_price(catalog, state, base) -> int:
    var price := Resolver.price_for(catalog, state, base)   # ← base = offer.stone_cost
    ...
```

`Resolver.price_for` → `scripts/domain/economy_rules.gd:57` 只叠加恶名/回头客/契约**涨价百分比**，
**从不调用 `gu_value`**。即：买价 = `shops.json` 里写死的 `stone_cost`（6–80）再乘层加价。

**结果是同一条链上的价格是自洽的、跨链不可比**。例：剑道一至五转的买价是干净的
**8 / 18 / 30 / 45 / 70**，但同为 tier 1 的 `jade_skin_gu` 要 30、`moonlight_gu` 只要 6。
`shops.json` 的 `tier` 字段也不可靠（`small_light_gu` 12 石标 tier 1、`moonlight_gu` 6 石标 tier 3）。

### Q9. 蛊 / 杀招 / 蛊方 三者的区别 ✅ 已定（语义层）

- **蛊** = 实体。有转数、流派、value、`v1_effect`。定价见 Q8。
- **蛊方** = 配方（怎么炼出来）。`data/refinement_recipes.json` **468 条**。
- **杀招** = **遭遇内的协同使用规则**（由若干蛊组合临时释放），不是实体、不可购买。

规则原文（`docs/lore/game-rule-register.md`，注意该文件已被 2026-09-17 裁定解除约束力）：
"杀招是遭遇内的协同使用规则；合炼或升炼是遭遇外、永久改变本局构筑的内容转换。
两者分别数据化，允许共享前置蛊虫但**不可互相替代**。"

**468 条配方的 kind 分布**：

| kind | 条数 | 语义 |
|---|---|---|
| `advance` | 377 | 同名培炼（实例转数 +1，封顶 5），兽骨 1–2 + 6/10 石 |
| `promotion` | 76 | **跨 definition 定向晋升**（换蛊名，严格 +1 转） |
| `fixed` | 14 | 定式合炼 |
| `free_mix` | 1 | 无秘方自由混合（有毁灭/异变/爆炸三结局） |

`promotion` 76 条 = **19 个流派 × 4 步（1→2 / 2→3 / 3→4 / 4→5）各一条**，
覆盖 light / force / gold / wisdom / heaven / fire / water / wind / wood / earth / blood /
dream / luck / qi / human / slave / soul / refine / sword。
**缺 `bone` 一个流派**（`data/gu.json` 有 20 个流派各约 40 只）。
另注：`docs/q8g/` 下只有 Batch 0 与 Batch 1-A 文档，**没有 1-B 的裁定/验收文档**，
但数据里 76 条 promotion 已落地——**文档记录落后于数据**。

### Q10. 炼蛊消耗资源 → 获得蛊虫 ⚠️ 已定但已知失衡

| 路径 | 成本 | 成功/产出 |
|---|---|---|
| `free_pair`（自由配对） | 2 转 20 / 3 转 60 / 4 转 150 / 5 转 300 石 | 成功率 90 / 70 / 50 / 35% |
| `advance`（同名培炼） | 兽骨 1–2 + 6/10 石 | 实例转数 +1（封顶 5） |
| `promotion`（定向晋升） | 见 76 条，示例 10 / 18 / 30 石 + 1 材料 | 换名，+1 转 |
| `fixed`（定式合炼） | 14 条 | 13 条**无 `stone_cost` 字段**；其中 light 系 5 条 **0 石 0 材料**，含 **2 条直达三转** |

**已知失衡（均已在 `world-model/RISK_REGISTER.md` / 数值与成长曲线.md §3.5、§4.5 登记）**：

- **兽骨单点依赖**：实测 `advance` 377 条中 **375 条（99%）** 吃 `beast_bone`；
  全 468 条配方中 **381 条（81.4%）** 吃兽骨。
  （`数值与成长曲线.md:210` 记的是"392 条里 378 条（96%）"——那是 promotion 落地之前的旧数，**已过时**。）
- **light 系 `fixed` 零成本直达三转**（已登记，未修）。
- **终局转数停滞**：模拟 200 局，终局 1 转 21.5% / 2 转 78.5%，**3 转以上未触达**。

---

## 2. 三类清单

### 2.1 已定（可直接引用，不需要重新设计）

1. 玩家开局（`world-model/data/balance.json` → `run.starter`）：气血 **80**、寿元 60、魂 1、念头 3、
   元石 12、资质丙等、一转、起始蛊 `small_light_gu`、流派 light。
   ⚠️ **但 80 不是上游派生值**——见 C9。
2. 真元：局外上限公式、战斗上限公式、每回合回复率（甲35/乙30/丙25/丁18）、元石换真元 `floor(5×(0.5+回复率))`。
3. 人本锚 100，空手重击 20；"蛊师气血不随转数自动增长"。
4. 突破成本 5/12/20/30 石 + 三转资质硬门槛。
5. 蛊价值锚 3/5/8/12/20 + 策展蛊登记机制。
6. role 兜底效果表（6 role）。
7. 操作集 5 个 + 修饰符 3 个（support / consume_status / delay）+ 触发器 2 个（on_play / on_hit_taken）。
8. 战斗产石 3/8/15 + 层步进 20%。
9. 掉落三档表 + 稀有度层权重 + 保底阈值 3。
10. 层缩放（turn_scaling / boss_layer_mult / enemy_rank 区间 / tier 权重）。
11. 黑市 5 组兑换率、商店层加价 0/10/20/35/50%、恶名与回头客加价。
12. 蛊 / 蛊方 / 杀招三者语义与配方 kind 分类。

### 2.2 自相矛盾（需要拍板，本对账不裁定）

| # | 矛盾 | 双方 | 后果 |
|---|---|---|---|
| C1 | **三条转数曲线并存** | 真元 ×3（`aptitude.json:9`）／战斗真元 10-30-60-100-150（`v1_battle.json`）／通用 ×2（`balance.json:6`） | 1–2 转三者不冲突，**3 转起分叉**：丙等三转局外真元 180 vs 战斗真元 120。派生模型（`growth`）已把它们命名为 `essence_max_out_of_run` / `essence_max_battle` 两条公式，**即"二者是不同资源"是既定设计**；缺的只是**一处并列对账表**，以及说明各自的适用范围 |
| C2 | **蛊的伤害有两套通道且不可比** | 显式 61 只（手写、**无转数放大、可倒挂**）vs 兜底 741 只（`base+(rank-1)`） | 同转之下强弱不可比；实测三转 strike 2 弱于一转 strike 4 |
| C3 | **语法文档与代码对 strike 的表述冲突** | `GU_EFFECT_GRAMMAR_V2_FINAL.md:40` 称 strike "沿用 rank 缩放"，`v1_battle_resolver.gd:469` 实际不缩放 | 按文档实施会得到与现状不同的行为 |
| C4 | **杀招伤害有两个写入位置** | `effect.amount`（25 条）vs `damage`（1 条，崩山） | 修饰符只作用于前者；后者绕过支援/剑意/consume |
| C5 | **同名 `regen_pct` 两个值** | `data/aptitude.json:16` 丙等 20%（局外）vs `data/v1_battle.json` 丙等 25%（战斗） | 两个上游文件用了同一个键名；派生模型已分别改名 `regen_pct_out_of_run` / `regen_pct_battle` 消歧，**但上游未改**，直接读上游会拿错 |
| C6 | **商店买价与 gu_value 脱钩** | 定价写死在 `shops.json`（38 条），`price_for` 从不读 `gu_value` | 同价值不同价；`tier` 字段不可靠 |
| C7 | **主文档把调参入口指向镜像** | `数值与成长曲线.md:3` 指向 `world-model/data/balance.json`，实际上游是 `data/` | 照它改会被覆盖并触发漂移告警 |
| C8 | **量纲双轨** | 参照系 40–3200 vs 实战 3–20（文档已自述并有意冻结） | 想按"标准蛊威力"设计数值会与实战表对不上 |
| C9 | **玩家气血 80 vs 100，且 80 是硬编码** | `build_world_model.py:897` 写死 `"hp": 80, "hp_max": 80`（`:431` 又重复一次 `start_value: 80, hard_cap: 80`）；而上游 `data/balance.json:8` 的 `human_base_health = 100`，`scripts/domain/cultivator_rules.gd:79` 取它作为蛊师肉身气血 | **"玩家到底 80 还是 100"没有单一来源**。且这违反了世界模型自述的"一切从上游派生"原则（同一段的 `thought_max` 是派生 `b["thought_base_capacity"]`，`hp` 却是字面量）。这是本对账**对 Web 原型最相关的一条**——见 §4 |
| C10 | **唯一的难度旋钮非单调** | `run.difficulty.enemy_hp_mult`（自称"唯一的整体难度旋钮"）灵敏度实测：1.0 → 通关 **67.0%**，**1.5 → 70.0%（比基准更容易）**，2.0 → 42.0% | 把敌人 HP 当"简单/困难"档，会出现**"困难档比普通档更容易通关"**的区间。根因：战斗拖长 → 更多掉落与魂恢复机会（`reports/balance-simulation.md` §二）。且战斗几乎不致死（200 局仅 2 例死于 `combat` 节点），故该旋钮**打不到真正的死因** |

### 2.3 真空（无成文口径，是真需要设计的部分）

| # | 缺口 | 现状 |
|---|---|---|
| G1 | **敌人 per-rank / per-tier 强度表** | 32 条敌人 HP/伤害全手写；只有层缩放成文 |
| G2 | **蛊同转之下的强弱** | 只有"转数 → 价值"一轴；同转内无区分度 |
| G3 | **杀招伤害中央公式** | 26 条手写；规格 §4.2 要求的"Σ 组成蛊成本"未落地 |
| G4 | **杀招价格** | 全仓无价格 |
| G5 | **`support_bonus`（增幅）随转数曲线** | 5 只实例 + recon 兜底全员 1；无曲线 |
| G6 | **rarity 溢价** | rarity 不影响价格；且 epic > rare 计数反常 |
| G7 | **741 只蛊的战斗效果** | 只有 role 兜底 6 档；`v1_effect` 显式仅 61 只 |
| G8 | **"应有战力 ↔ 敌人强度"对照** | 无从判断某转数玩家该打得过谁 |
| G9 | **难度分档** | 不存在"简单/普通/困难"；只有连续倍率 `enemy_hp_mult`（见 C10）。且现有旋钮打在战斗轴上，而 92% 的死因在事件轴的魂 |
| G10 | **魂的收益侧** | 见下 |

### 2.4 一条结构性缺陷：魂只有死亡风险，没有可达收益

> ⚠️ **本节解释已作废，事实保留（`RUL-2026-09-19-004`，2026-09-19）**
>
> L0 已裁定：**魂是可成长的 Build Axis，对应魂道玩法**，同时承担①魂魄生存值
> ②魂道能力资源 ③魂道攻防基础 ④长期成长属性；**不是**固定 1–4 的风险条。
>
> 因此下面「魂只有风险、没有可达收益」是**事实观察**（上限 4 够不到 ≥10 的门槛仍然为真），
> 但由此推出的方向——「把魂修成有收益的风险资源」——**已被取代**。
> 正确方向是让魂成为可经营的成长轴，而非调参。禁止以 `max_soul = 4` 为前提调难度。
> 详见 `rulings/RUL-2026-09-19-004.json` 与只读 `soul-system-audit`（进行中）。

把三处数字放在一起看：

| 项 | 值 | 出处 |
|---|---|---|
| 魂起始 / 上限 | **1 / 4** | `run.starter.soul` / `soul_max` |
| 行动点阶梯 | 魂 ≥10000→6 AP / ≥1000→5 / ≥100→4 / **≥10→3** / 否则 **2** | `run.action_points_by_soul` |
| 魂 → 0 | **即死**（92% 的实际死因） | `events.json` `delayed_soul_cost`；`stats_soul_death_threshold: 0` |

**上限 4 永远够不到 ≥10 的门槛** → 魂的四档高收益全部不可达，整局永远只有 2 行动点。
与此同时魂可以归零致死。即：**这个资源只提供风险，不提供玩家可经营的上行空间**。

配套证据：`Q8G_BATCH0_SEMANTICS_WORKSHEET.md` §Q7 的审计事实记
"F8 实测：**所有原型所有种子恒为 1，零变化**"。另 `run.lifespan_milestones` 使 5 层共 +100 寿元
（起点 60），寿元轴为**净正收益**，同样不构成压力。

**结论**：模拟中"卡关"不是某层特别难，而是死因集中在一条**既不能改善、又随时归零**的轴上；
且死亡在 1–5 层几乎等量（14/13/12/14/13）——**难度曲线是平的**。
这两点共同解释了"卡关"，也说明**在敌人 HP 上加难度档不会改善卡关**。

**实验证实（2026-09-19）**：`reports/difficulty-axis-probe.md` 用同种子区间跑 4 组 × 200 局
（内存覆盖，不改数据）：

| 组 | 覆盖 | 通关率 | 相对基线 |
|---|---|---|---|
| baseline | 无 | 68.0% | — |
| soul | 魂起始 1 → **4** | **97.0%** | **+29.0pp**（魂死因 61 → 1） |
| ap | 3 AP 门槛 `min_soul` 10 → 1 | 70.0% | +2.0pp |
| combo | 两者同时 | 99.0% | +31.0pp |

即：**魂的存量是真实瓶颈**（放宽后死亡几乎消失），而"3 AP 不可达"本身几乎不影响结果。
这同时证伪了"33% 死亡率主要来自决策器弱"——**主因是难度，且落在魂这条轴上**。

---

## 3. 顺手发现的文档 / 数据漂移

供后续修正，均非本对账要裁定的内容：

| # | 项 | 文档说 | 实测 |
|---|---|---|---|
| D1 | 显式 `v1_effect` 只数 | `CURRENT_EFFECT_CAPABILITY_MATRIX.md:13` 记 **48 只** | **61 只**（+status 2 / +weaken_intent 1 / +strike 7 / +heal 1 / +shield 1 / +shift 1） |
| D2 | 兽骨依赖比 | `数值与成长曲线.md:210` 记 392 条中 378 条（96%） | 468 条中 **381 条（81.4%）**；`advance` 内仍是 375/377（99%） |
| D3 | 配方总数 | 文档语境为 392 条 | **468 条**（promotion +76） |
| D4 | promotion 落地无文档 | `docs/q8g/` 只有 Batch 0 与 1-A | 数据里已有 **76 条 promotion，覆盖 19 流派 × 4 步**（缺 `bone`） |
| D5 | `gu.json` 测试残留 | — | `test_slay_gu`：rank 10、amount 999、tag `test`、value 0 |
| D6 | 调参入口方向 | 见 C7 | 上游是 `data/` |

---

## 4. 我在 Web 原型里引入的缺陷（自报）

`game/wenzhen-web-lab/`（`game/wenzhen-web-lab/js/main.js`）里有 4 个值是我**自己编造**的，没有任何来源：

| 我编的 | 应当取的值 | 判定 |
|---|---|---|
| 气血 **12 → 24** | **80**（世界模型口径）或 **100**（上游人本锚）——**两者本身就没对齐，见 C9** | ❌ 12/24 是我为了让 Boss 战跑完临时设的，两者都不是 |
| 元石奖励 **+2** | common 3 / elite 8 / boss 15，每层 +20% | ❌ 无来源 |
| 合炼成算 **七成** | 自由配对 90/70/50/35%（`free_pair`；该机制本身未接线） | ❌ 无来源 |
| 真元上限 20 | 20 —— 正确 | ✅ 与 `stage_base.one(10) × aptitude_mult.bing(2)` 一致 |

前三个**没有任何来源**，是为了跑通单个环节而临时设的，属倒果为因。
**注意**：即使换成 80 或 100，也只是"改成引用现有口径"，**不等于解决了 C9**——
C9 是"这两者哪个才对"本身没有答案，需要拍板。

### 4.1 一条正向确认（我的实现与既定口径一致）

`build_world_model.py:928-930` 记录的原型口径：

> "敌方意图全部处于 cooldown 时原型口径为**「调息不出手」**；若双方都无法终结战斗，
> 回合数超过 `max_battle_rounds`(40) 即按撤退结算"

这与我给 Web 原型实现的 `cooldown_wait`（所有意图都在冷却 → 该回合不攻击，战报记"蓄势不动"）
语义一致。**多阶段 AI 的冷却门禁这一条，我的实现方向是对的**；只是气血等数值不该自己编。

---

## 5. 本次未验证 / 未做的事

- **未改任何生产数值**。未触碰 `data/`、`scripts/`、`scenes/`、`world-model/data/`。
- 未运行 `accept.py` / `validate_world_model.py` / `simulate_balance.py`（只读审计，不需要）。
- 未裁定 C1–C8 任何一项的取值。
- 未审计 `data/` 之外的上游（`scenes/`、UI 层）里的数值。
- 已知未读的相关文档（留待后续）：`docs/q8/Q8_12_GU_VERTICAL_SLICE.md`、
  `docs/q8/WORLD_BEHAVIOR_TAXONOMY.md`、`world-model/docs/世界模型总纲.md`、
  `world-model/reports/independent-verification.md`。
- 敌人/杀招的"强弱"结论基于**数据分布**，未做实战模拟验证。
