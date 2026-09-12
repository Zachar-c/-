# 蛊虫效果语法 V2 最终版（唯一权威）

> - **版本**：R2 FINAL（2026-09-12）
> - **地位**：本文档是 Effect Grammar 的**唯一权威**。`GU_EFFECT_GRAMMAR_V2.md`（V2 原案）与 `GU_EFFECT_GRAMMAR_V2_REVISED.md`（R1 修订案）降级为决策记录；任何冲突以本文件为准。
> - **状态**：**实施冻结**——Go/No-Go（§10）九项条件全部 PASS 之前，禁止编写任何生产实现代码（含引擎改动与数据改写）。
> - **上游**：`WORLD_BEHAVIOR_TAXONOMY.md`（行为词典，R2 裁定已吸收）。
> - **下游**：`Q8_12_GU_VERTICAL_SLICE.md`（12 只验证蛊 + 6 个决策场景）、`Q8_GRAMMAR_DECISION_LOG.md`（R1→R2 裁定变更记录）。

---

## 1. 六层结构与执行管线

```text
effect := { trigger, condition?, cost, selector?, operation, modifier? }
```

执行顺序（R2 验收定稿，H1 硬约束原文）：

```text
can_activate -> trigger -> condition(false -> 结束) -> cost commit -> selector -> modifier -> operation
```

1. **can_activate**：打出前预检（成本可支付、转数门槛、封印/已用检查）。未过 → 预检拒绝、零消耗（沿用现行 `can_activate` + 转数惩罚，不改）。
2. **trigger**：时机判定。未命中 → effect 不存在（零痕迹）。
3. **condition**：资格判断。**零成本**——false → 立即结束（事件 `condition_miss`），**必须短路在 cost commit 之前**。cost commit 是整条管线上**第一笔不可逆变更**，此前任何 miss 一分不扣。
4. **cost commit**：提交支付。`true_qi_cost`（缺省取 `essence_cost`，再缺省 1，见 v1_battle_resolver.gd:178）/ `thought_cost`（缺省 1）/ `life_cost`（缺省 0）。支付失败 → 预检拒绝。
5. **selector**：目标选择。冻结集合：**`self` / `enemy_first` / `enemy_all`**。`weaken_intent` 必填；其余操作有默认目标。
6. **modifier**：先定参（如 consume_status 算出 `final_amount`）。不引入第二个操作。
7. **operation**：结算。**一效果恰好一个操作**。

两条硬纪律：

- **一效果一操作**。复合行为（如 heal_and_strike）只存在于遗留兼容通道，不新增。
- **先付费后延迟**。`delay` 是 modifier：cost 在打出时支付，效果延后结算——拖延不免费。

## 2. 操作集（冻结：5 个）

| 操作 | 目标 | 语义 | 引擎现状 |
| --- | --- | --- | --- |
| strike | 敌方 | 造伤；沿用 rank 缩放（`amount = base + (rank-1)`）与 turn_supports 同流派加成（v1_battle_resolver.gd:393） | 已有 |
| shield | 己方 | 护盾 | 已有 |
| heal | 己方 | 治疗；沿用 rank 缩放 | 已有 |
| status | 敌方 | 见下，marked + sealed 两种 status id | marked 走 recon fallback；sealed 待实现 |
| weaken_intent | 敌方（per-target） | 降低目标**下一次 damage intent** 数值 | 待实现 |

### status：marked + sealed

- **marked**（敌方）：上限 10 层，每回合每层 1 伤。现状：gu.json 显式 status kind 为 **0**，唯一入口是 recon role fallback；纵切将其显式化，显式化前后数值逐只相同。
- **sealed**（敌方）：**最小纵切**——被 sealed 的敌人，其下一次 damage intent 被门禁（跳过）。仅此而已。封蛊、封技能、封流派、封印持续时间体系等完整封印世界观一律**不做**（R2 裁定：sealed 是最小纵切，不是完整 seal world model）。

### weaken_intent：正式纵切操作（第 5 个操作，不是 modifier）

- **selector 必填**，默认 `enemy_first`。
- 只作用于目标**下一次 damage intent** 的数值（降低 `amount`）。
- **per-target**：不做全局 debuff，不产生跨目标涟漪。
- **用后立即清零**：该意图被消费（或回合结束）时减免随之消失。
- 与 sealed 的分工：sealed 是门禁（意图不存在），weaken 是削幅（意图变小）。

**明确排除（本版不是操作）**：move、buff、shift、heal_and_strike、sword_intent（进 §6 遗留兼容）；一切复合操作；一切未列出的新操作。

## 3. 修饰符（冻结：3 个）

### support（登记式）

- 数据键 `v1_effect.support_school`（`"self"` 哨兵解析为蛊自身流派，v1_battle_resolver.gd:148-149）。
- 打出后 `turn_supports[school] += support_bonus`；本回合**后续**同流派 strike 获加成；`end_turn` 清零（现状即如此，v1_battle_resolver.gd:393、432-436）。
- support 自己不结算、不造伤，只登记。

### consume_status（线性，正式）

- 公式：**`final_amount = base_amount + stacks × per_stack`**（R2 裁定原文）。
- status 存在（stacks ≥ 1）：按公式结算，随后清除该目标身上该 status 的**全部层数**（层数已全额计入 final_amount）。
- status 缺失（stacks = 0）：事件 `consume_miss`，**不扣成本**，effect 视为未发生。与 condition miss 同构，但用独立事件键以便区分统计（R2 裁定：消费落空不是照扣，是零成本资格路径）。
- 本版唯一消费源：敌方 marked。

### delay（形态锁定）

- **只允许 `on_play + delay + operation` 一种形态**；与 condition / consume_status / support / 非 on_play 触发器组合 → schema 校验拒绝。
- 打出时支付 cost；在 `delayed_effects` 表登记；到期回合自动结算，事件 `delayed_fired`。
- `delayed_effects` 随 battle 生命周期存在：战斗结束即销毁，存档序列化包含该表（序列化只存 ID 与数值）。

## 4. 触发器（第一版冻结：2 个）

| 触发器 | 语义 | 引擎现状 |
| --- | --- | --- |
| on_play | 打出即触发（现行为默认时机） | 已有 |
| on_hit_taken | 玩家被击中时触发 | TRIGGER_COST（v1_battle_resolver.gd:744-756）泛化收编 |

- **on_turn_end / on_kill：未来候选**——只记录在本文件，不实现、不预留超出现有的钩子（R2 裁定：批准为候选 ≠ 批准实现）。

## 5. condition 与 selector（R2 验收定稿集合）

- **condition 冻结 3 谓词**：`self_hp_below` / `enemies_alive_gte` / `turn_gte`。
- 纯谓词，无副作用：读自身血量比例、存活敌人数、当前回合数，返回真伪。
- miss → 事件 `condition_miss`、**不扣成本、无部分结算**（R2 裁定原文：「condition 是零成本的资格判断」）。
- condition 不是操作：不得造成伤害、治疗、状态或任何结算。
- **selector 冻结 3 项**：`self` / `enemy_first` / `enemy_all`。其中 `enemy_first` 语义见 §12-H4。

## 6. 遗留兼容（仅历史通道，不新增数据）

| 遗留 kind | 处置 | 引擎锚点 |
| --- | --- | --- |
| shift | 历史转译为 shield，存量保留 | v1_battle_resolver.gd:419-424 |
| buff | 只喂 basic_attack，存量保留 | 引擎现状 |
| heal_and_strike | 复合遗留（blood_bat_gu），存量保留 | 引擎现状 |
| sword_intent | 存量保留原语义（cap 5 / 每回合减半 / 仅剑击加成） | v1_battle_resolver.gd:397 |

规则：不新增任何遗留 kind 的数据；存量蛊显式化迁移时，按 R1 行为保持承诺逐只等价转换，转换前逐只对拍。

## 7. active_permanents 与蛊生命周期边界

- `active_permanents` 是**技术容器**（悬挂效果的宿主），**不是世界模型**——它不承载任何世界观承诺。
- 本阶段**不实现**蛊生命周期：hunger（喂养）、loyalty（忠诚）、ferocity（凶性）、flee（逃逸）全部冻结。
- `feeding_cost` / `feeding_need` 等养蛊数据保持原样透传，不进战斗语法。

## 8. 新增键与事件（纵切允许面）

battle 新键：

- `delayed_effects: Array`（元素含 effect 与 due_turn）。
- 每敌：`intent_weaken: int`（下一次 damage intent 减免额）、`statuses.sealed`（门禁标记）。

事件键（append-only，全部落不可变事件日志）：

- `condition_miss` / `consume_miss`
- `weaken_applied` / `weaken_consumed`
- `sealed_applied` / `sealed_consumed`
- `delayed_scheduled` / `delayed_fired`

## 9. 最小引擎改动清单（4 处，越界即回退）

1. **sealed 意图门禁**：敌方 intent 消费处一刀门禁（沿 `_apply_enemy_status` 既有路径，v1_battle_resolver.gd:450-465 旁）。
2. **weaken_intent**：敌方 intent 数值处 per-target 减免 + 消费/回合结束清零。
3. **delayed_effects 表**：battle 生命周期内登记、到期结算、存档序列化。
4. **trigger 泛化**：on_play / on_hit_taken 统一入口（收编 TRIGGER_COST 现状，v1_battle_resolver.gd:744-756）。

行为保持承诺（承 R1）：

- 显式化前后**逐只蛊伤害相同**（对拍验证，非抽查）。
- 成本可见：任何代价先展示后支付；预检拒绝，非静默致死。
- 纯数据不改引擎逻辑；引擎改动仅限上表 4 处。
- 不改 `can_activate`、转数惩罚 `2^(gu_rank - cultivator_rank)` 与资质系数。

## 10. Go/No-Go 检查表（九项全 PASS 才允许大规模实现）

| # | 条件 | 状态 |
| --- | --- | --- |
| 1 | 操作集冻结为 5（strike/shield/heal/status/weaken_intent），无第 6 个操作进入实现 | PASS（§2） |
| 2 | 修饰符冻结为 3；consume_status 线性公式 + 落空不扣成本已成文 | PASS（§3） |
| 3 | 触发器第一版只有 on_play/on_hit_taken；on_turn_end/on_kill 仅为候选记录 | PASS（§4） |
| 4 | condition 零成本语义成文（miss 不扣成本、无部分结算） | PASS（§5） |
| 5 | 12 只验证蛊各含 6 字段（world_semantics / grammar_expression / cost / decision_value / synergy / counterplay） | 见 Q8_12_GU_VERTICAL_SLICE.md |
| 6 | 6 个决策场景全部 A/B 双合理、理由非纯数值 | 见 Q8_12_GU_VERTICAL_SLICE.md |
| 7 | 引擎改动 ≤ 4 处且有明确清单 | PASS（§9） |
| 8 | 遗留兼容路径明确，不新增遗留 kind 数据 | PASS（§6） |
| 9 | 行为保持承诺 + 禁止项复核通过 | PASS（§9/§11） |

> 注：本表由 R2 任务书裁定条目逐条映射生成；与任务书原文如有出入，**以任务书原文为准**。

## 11. 禁止项（红线，承 R1/R2 与 AGENTS.md）

- 不做流派克制网；不做抽牌、手牌、弃牌堆、蛊槽。
- 不加新货币；不加跨局战力成长（唯一例外仍是蛊方图鉴）。
- 不偷人道机制；不把推断概念宣称为原文（引用原文必须给原句，推断必须标注）。
- status/buff 不表破防加伤（引擎事实约束）。
- 杀招多段走 `steps`，不加新 effect kind。
- 不做全局意图 debuff；weaken / sealed 均 per-target。
- 蛊生命周期（喂养/忠诚/凶性/逃逸）本阶段冻结。
- LLM 不参与随机、数值、战斗、掉落、炼蛊、交易、地图、恶名、存档或结局判定。

## 12. 实现硬约束（R2 验收裁定原文，2026-09-12，Q8-IMPLEMENT 全程生效）

- **H1 · 成本提交顺序**：`can_activate → trigger → condition(false → 结束) → cost commit → selector → modifier → operation`。condition 落空必须短路在 cost commit 之前；**禁止 cost-then-check**（先扣钱再查资格）。
- **H2 · consume_status 原子事务**：验证消费条件 → 计算结果 → 提交结算 → 清除已消费状态。「消费状态 + 使用状态产生的效果」属于**同一次确定性结算**；**禁止 clear-then-strike**（先清层数再结算，中途崩溃或拒绝即丢状态）。
- **H3 · sealed 数据化**：敌方意图需带最小语义属性（如 `damage_intent = true/false`），sealed 门禁读属性裁决；**禁止**在 `_resolve_enemy_intent()` 里硬编码 `if sealed > 0: skip()`。
- **H4 · enemy_first 语义**：= **「当前敌人行动队列的第一个存活目标」**，此定义落档为唯一语义；**禁止**实现为「数组第一个元素」（不查存活）或与「最危险敌人」混同。

未来项禁令（本阶段一律不实现、不预留钩子）：on_kill、on_turn_end、enemy soul / enemy lifespan / enemy true_qi 三轴、tag 网络、新 Buff、新操作、shift 世界语义改动、durability 大规模内容化。
