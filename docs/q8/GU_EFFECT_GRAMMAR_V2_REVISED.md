# GU_EFFECT_GRAMMAR_V2_REVISED.md — Q8-R1 阶段 B：修正版效果语法

> 日期：2026-09-12。状态：**按 Q8-R1 裁定修订，待批准后实施**（仍不改引擎）。
> ⚠️ **已被取代（2026-09-12）**：Q8-R2 裁定后，本文件的语法规格由 **`GU_EFFECT_GRAMMAR_V2_FINAL.md`** 取代（唯一权威）。本文降级为 R1 阶段决策记录：操作集 9→5、condition/consume_status 落空成本语义改零成本、weaken_intent 全局→per-target、触发器收缩等变更见 `Q8_GRAMMAR_DECISION_LOG.md`。
> 来源：行为需求反推——词典见 `WORLD_BEHAVIOR_TAXONOMY.md`；对 V2 首案的裁定（批准 condition/delay/selector/consume_status/trigger 泛化/旧 8 kind 兼容；shift 降历史兼容层；seal/weaken_intent 提前；support 降层级）全部吸收。
> 铁律：Grammar 来源于行为需求，不为 DSL 能力而 DSL；新增蛊优先 JSON 表达；旧 8 kind 行为零漂移。

---

## 1. 六层结构

```text
Effect
├── cost        花什么：true_qi / thought / life（寿元预检接管，不可致死）
├── trigger     什么时候做：on_play(默认) | on_hit_taken | on_turn_end | on_kill
├── condition   什么条件成立才做：self_hp_below | enemies_alive_gte | turn_gte
├── selector    对谁做：self | enemy_first(默认) | enemy_all
├── operation   做什么（结果动作，单一主选择）
└── modifier    在什么修饰下做（可叠加，不独立产生结果）
      ├── support   {school|self, bonus}   流派支援
      ├── consume_status {name}             引爆标签（层数清零换结算加成）
      └── delay     {turns}                延迟结算
```

**层级纪律**：operation 是唯一产生战局结果的层；support/consume_status/delay 修饰 operation；trigger/condition/selector 决定该 operation 何时/是否/对谁发生。任何新原子必须先在词典中找到行为条目才能入表。

## 2. operation 全集（9 个）

| operation | 语义 | 世界模型依据 | 现状 | 引擎改动 |
|---|---|---|---|---|
| strike | 打击 | 伤敌 | ✅ 21 显式+兜底 | 无 |
| shield | 格挡 | 护己 | ✅ | 无 |
| heal | 治疗 | 续命 | ✅ | 无 |
| status | 给敌上状态（marked / **sealed**） | 锁敌：刻痕/封蛊 | marked ✅；sealed 新名 | sealed 意图门一处 |
| sword_intent | 剑意叠层 | 道痕蓄势 | ✅ 仅剑道消费 | 无 |
| **weaken_intent** | 削弱敌方下次意图伤害 | 知彼后以蛊应之 | 新（最小反制路径） | next_intent_mod 一写一读一清 |
| shift | ⚠️ **历史兼容层**：等价 shield，新内容禁用 | 无世界语义（待独立裁定） | 5 显式+兜底继续工作 | 无 |
| buff | ⚠️ 兼容保留，只喂 basic_attack，不扩展 | — | force/yi_zhang | 无 |
| heal_and_strike | 语法糖 = heal(self) + strike(enemy_first) | 噬敌反哺 | 1 只 | 无 |

**sealed 语义（最小封蛊）**：`{"kind":"status","name":"sealed","amount":N}` → 敌 statuses.sealed += N；`_resolve_enemy_intent` 开头检查：sealed>0 时本次意图失效（不结算不推进冷却），sealed-1，日志 `intent_sealed`。确定性、无新数据结构。**纵切至少 1 只真实封蛊实例**（R1 验收 5）。

**weaken_intent 语义（意图反制最小路径）**：`{"kind":"weaken_intent","amount":N}` → `battle.next_intent_mod -= N`（钳制 ≥0）；下一个敌方回合全部意图的 damage 先减 N 再结算，用后清零，日志 `intent_weakened`。闭环=读意图（已公开投影）→ 用蛊 → 敌行为改变（R1 验收 6）。

## 3. trigger 全集（4 个）

| trigger | 语义 | 现状 |
|---|---|---|
| on_play | 催动即结算（默认） | ✅ |
| on_hit_taken | 受击触发（单次攻击事件至多 1 次，可挂 cost 子句，真元不足关闭） | ✅ 收编 TRIGGER_COST |
| on_turn_end | 回合末结算（如刻痕类自主发作、支援衰减挂钩） | 新钩子 |
| on_kill | 击杀敌人时结算 | 新钩子 |

on_turn_end / on_kill 挂 `active_permanents` 同列表；触发条件不满足时静默保持挂载（不消耗）。**不引入**其他触发器（on_enemy_hp_below 等用 condition 表达即可）。

## 4. condition 全集（3 个，首版锁定）

`self_hp_below`（0-1 比例）、`enemies_alive_gte`（int）、`turn_gte`（int）。不满足 → `condition_miss` 日志，资源照扣（对齐杀招化解纪律）。**后续扩充必须走词典新增行为条目**。

## 5. selector（3 个）

`self` / `enemy_first`（默认，回退首个存活敌）/ `enemy_all`（收编 aoe，逐只按 enemies 数组序结算）。`strike_aoe` 日志键在收编后保留原值以稳基线。

## 6. modifier（3 个）

| modifier | 语义 | 纪律 |
|---|---|---|
| support {school,self, bonus} | 登记本回合后续同流派 strike 加成，end_turn 清零 | 只修饰 strike 通道；不跨回合；不修饰 heal/shield |
| consume_status {name} | 目标持有该状态时：层数清零 + 结算加成（加成方式由效果声明，如 strike amount×层数）；无状态 → `consume_miss`，资源照扣 | 现网仅 marked 可引爆 |
| delay {turns} | operation 存入 `battle.delayed_effects`，end_turn 递减，到 0 按登记序结算（目标登记时解析、结算时校验存活） | delay 只修饰即时 operation；不得修饰其他 modifier |

## 7. 结算管线（V2 修正版）

```text
play_gu / play_kill_move
→ 转数门禁 can_activate（含 2^n 折价）
→ 成本预检：thought → true_qi → life（不可致死红线）
→ trigger 分流：on_play 进主管线；其余挂常驻列表（active_permanents）
→ condition：不满足 → condition_miss（资源照扣）→ 结束
→ selector 解析目标
→ delay? 登记 delayed_effects : 执行 operation
→ modifier 应用序：support 先登记（供后续蛊）→ consume_status 在 operation 结算时引爆
→ 统一死亡校验（hp/life/soul 三轴）→ _log → snapshot 只读投影
```

## 8. 战局状态与投影

| 新增 battle 键 | 写者 | 投影 |
|---|---|---|
| `delayed_effects:[{turns_left, effect, target_key, source_gu}]` | delay modifier | 只读键 `delayed_effects[]`（文案=剩余回合+效果摘要） |
| `next_intent_mod:int` | weaken_intent | 意图卡文案附"下一击 -N" |
| 敌 `statuses.sealed` | status(sealed) | 敌状态文案"封印 N"（statuses 已投影，新增文案映射） |

event log 新键：`intent_sealed` / `intent_weakened` / `condition_miss` / `consume_miss` / `status_consumed` / `delayed_registered` / `delayed_resolved`。全部 append-only，存档校验不受影响（事件键不进 state 校验面，`_` 前缀旁路规则不涉及）。

## 9. 行为保持承诺（→ Q8-E 基线）

1. 现网 gu.json / v1_battle.json **零迁移**：无 trigger/condition/modifier 字段的蛊按 on_play + 无条件 + 默认 selector 结算，逐只结果与现状相同。
2. aoe→selector 与 TRIGGER_COST→on_hit_taken 收编由基线逐只验证。
3. shift/buff/heal_and_strike 保留原 kind 值，新内容禁用 shift（lint：新数据出现 shift 给出 warning）。
4. 基线范围：48 显式蛊逐只 + 6 role 兜底抽样 + 26 杀招 + 4 系 counter，断言 damage/healing/shield/true_qi/thought/status/lifespan/soul/death cause。

## 10. 表达力样例（JSON 直达，零特判）

```json
{"kind":"status","name":"sealed","amount":1}                                  // 封敌一回合
{"kind":"weaken_intent","amount":2}                                            // 下一敌方回合意图 -2
{"kind":"strike","amount":3,"consume_status":"marked"}                         // 引爆刻痕
{"kind":"heal","amount":5,"condition":{"self_hp_below":0.5}}                   // 残血才起效
{"kind":"strike","amount":6,"modifier":{"delay":{"turns":1}}}                  // 后手剑
{"kind":"strike","amount":9,"cost":{"life":1}}                                 // 以命易势
{"kind":"shield","amount":4,"trigger":"on_hit_taken","modifier":{"support":{"self":1}}}
```

## 11. 明确不做（R1 暂缓令重申）

敌方 true_qi/soul/lifespan、modify_future_action、大型玩家 tag 网络、新 Buff 通道、大规模 durability 内容化、shift 世界语义、bound、condition 新读取项（未走词典）、任何无词典条目的原子。
