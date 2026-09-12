# GU_EFFECT_GRAMMAR_V2.md — Q8 第二阶段：最小原子语法提案

> **⚠️ 已被取代（2026-09-12）**：用户 Q8-R1 裁定本提案大部分原子（condition/delay/selector/consume_status/trigger 泛化/旧 8 kind 兼容），但要求层级重排（support 降为 modifier）、seal 与 weaken_intent 提前入纵切、shift 仅作历史兼容层。现行版本见 `GU_EFFECT_GRAMMAR_V2_REVISED.md`。本文件保留作决策记录。

> 日期：2026-09-12。状态：**提案，待用户批准后实施**（本阶段只设计，不改引擎）。
> 推导来源：`docs/q8/CURRENT_EFFECT_CAPABILITY_MATRIX.md` 的缺口清单 G1-G10 与现网 48 显式效果 + 6 角色兜底的真实量纲。
> 设计目标：用最少的原子表达尽可能多的蛊虫差异；新增蛊优先改 JSON 而非写 GDScript 特判；已有行为零漂移。

---

## 0. 设计纪律

1. **现有 8 种 kind 的语义是基线**，V2 形式化它们而非重写；48 只显式效果与 754 只兜底的结算结果必须逐只相同（Q8-4 行为基线守门）。
2. **禁止 RNG 原子**。所有原子确定性结算；概率只允许存在于战斗外种子化流程（合成/掉落/抽敌）。
3. **禁止新增全局状态**。原子只读写 battle Dictionary 内的既有或新增子键；snapshot 单向投影不破坏。
4. **收编特殊 case 优先于新增原子**：aoe→selector；TRIGGER_COST→trigger 泛化；bound→实现或出白名单。
5. 每个原子必须能独立回答：语义 / 输入 / 输出 / 成本 / 组合 / RNG / 死亡 / battle state / event log / snapshot（§3 表格统一回答）。

## 1. 原子总览（9 个操作原子 + 3 个修饰轴 + 现有成本字段）

```text
效果 = cost(true_qi/thought/life) + trigger + [condition] + operation(selector) + [modifier]*

操作原子（operation）：        修饰轴（可叠加在任意 operation 上）：
  strike                        selector: self / enemy_first(默认) / enemy_all(收编 aoe)
  shield                        delay: N（延迟结算）
  heal                          trigger: on_play(默认) / on_hit_taken / on_turn_end / on_kill
  buff                        （condition、consume_status、intent_mod 见 §2 暂缓名单）
  status
  sword_intent
  shift（转译为 shield）
  heal_and_strike（复合语法糖 = heal + strike）
  support（support_school/support_bonus 子键，随任意 operation 叠加）
```

## 2. 收编与新增决策

### 2.1 收编（不改行为，只改表达）[DESIGN]

| 现状 | V2 表达 | 行为等价性 |
|---|---|---|
| `effect.aoe=true`（1 只测试蛊） | `selector:"enemy_all"` | 逐只结算顺序相同（enemies 数组序），基线可验 |
| `durability_mode:"TRIGGER_COST"` + trigger_qi_cost/trigger_block | `trigger:"on_hit_taken"` + operation(shield/heal) + cost 子句（每事件至多 1 次、真元不足关闭） | 现网零实例，纯形式化，无迁移风险 |
| `durability_mode:"CONSUME_ON_USE"` / `"PER_TURN_MAINTAIN"` | 保留为蛊生命周期轴（非效果原子），语义不变 | 现网零实例 |
| `heal_and_strike` | 保留为语法糖（=heal+self+strike+enemy_first 序列） | 1 只，直接保留原 kind 减少迁移 |

### 2.2 新增原子（3 个，各对应一个缺口）

**A. `delay: N`（延迟轴，→ G2）**
语义：operation 不立即结算，写入 `battle.delayed_effects`，每回合 end_turn 计数-1，到 0 时按登记顺序结算（selector 在登记时解析目标、结算时校验存活）。
输入：任意 operation + delay≥1。输出：延迟登记条目 / 到期结算。成本：随蛊本体。组合：与 selector/trigger 正交。RNG：无。死亡：到期结算走统一死亡校验（hp/life/soul 三轴）。battle state：新增 `delayed_effects:[{turns_left, effect, target_key, source_gu}]`。event log：`delayed_registered` / 到期按原 kind 落日志。snapshot：新增只读键 `delayed_effects[]`（剩余回合+效果文案）。世界模型：蛊效的"酝酿/发作"（对齐事件层 delayed_soul_cost 先例）。

**B. `consume_status`（标签消耗，→ G3）**
语义：若目标（self 或 enemy_first）身上存在指定 status（如 marked），移除全部层数并执行本效果；不存在则效果不结算（日志 `consume_miss`，资源照扣——对齐杀招化解"资源照扣"纪律）。
输入：`consume_status:"marked"` + 任意 operation。组合：与 strike 组合成"引爆刻痕"（剑道纵切核心句式：刻痕×N 引爆为 N×倍率伤害）。RNG：无。死亡：正常结算链。battle state：敌 statuses 字典（已有）。event log：`status_consumed`。snapshot：无新键（statuses 已投影）。

**C. `condition`（前置读取，→ G1/G7）**
语义：首版只落三个读取项——`self_hp_below:X`、`enemies_alive_gte:N`、`turn_gte:N`；不满足则本效果跳过（日志 `condition_miss`，资源照扣）。
输入：条件字典 + 任意 operation。组合：条件×任意原子=行为分岔。RNG：无。死亡：无新增。battle state：只读现有字段。event log：`condition_miss`。snapshot：效果文案附带条件（Q7 _v1_effect_text 先例）。

### 2.3 明确不做（暂缓名单，纵切验证后再议）

- `modify_enemy_intent` / 反意图原子（G8）：情报交互设计未定，防止为丰富而丰富。
- 玩家侧 tag 设置（G3 反向）：组合价值未证明。
- 敌侧 true_qi/soul/lifespan 字段（G4）：是内容补齐不是语法问题，留待内容阶段。
- `modify_next_gu` / `modify_future_action`（用户候选列表项）：现有 support 通道已覆盖"影响后续"最小需求。
- 新 Buff name 通道扩展：buff 只喂 basic_attack 的裁定不变。

## 3. 原子规格表（任务书十问统一回答）

| 原子 | 语义 | 输入 | 输出 | 成本 | 组合 | RNG | 死亡 | battle state | event log | snapshot |
|---|---|---|---|---|---|---|---|---|---|---|
| strike | 物理打击 | amount | 敌 hp- | 本体成本 | 支援+剑意 | 无 | 即时三轴校验 | enemies[].hp | struck | 已有 |
| shield | 格挡 | amount | player.shield+ | 本体成本 | ❌ | 无 | 无 | player.shield | （投影） | 已有 |
| heal | 治疗 | amount | hp+（钳制） | 本体成本 | ❌ | 无 | 无 | player.hp | （投影） | 已有 |
| buff | 肉身增益 | name,amount | buffs 叠加 | 本体成本 | 同名叠加 | 无 | 无 | player.buffs | （投影） | 已有 |
| status | 给敌上状态 | name,amount | 敌 statuses+ | 本体成本 | 层数叠加 | 无 | 无 | enemies[].statuses | status | 已有 |
| sword_intent | 剑意叠层 | amount | 意图层数+（≤5） | 本体成本 | 剑道 strike 消费 | 无 | 无 | school 层 | sword_intent | 已有 |
| shift | 转译护盾 | amount | player.shield+ | 本体成本 | ❌ | 无 | 无 | 同 shield | （投影） | 已有 |
| support | 流派支援 | school,bonus | turn_supports+ | 零 | 任意 kind 叠加 | 无 | 无 | battle.turn_supports | support | 已有 |
| selector | 目标选择 | self/enemy_first/enemy_all | 结算目标集 | 零 | 全 operation | 无 | aoe 逐只校验 | 无新增 | strike_aoe(改名前 strike) | 目标文案 |
| delay | 延迟 | N+operation | 延迟登记 | 本体成本 | 任意 operation | 无 | 到期结算 | **新增 delayed_effects** | delayed_registered | **新增只读键** |
| consume_status | 引爆标签 | name+operation | 层数清零+结算 | 本体成本 | ×strike=引爆 | 无 | 正常 | enemies[].statuses | status_consumed | 无新键 |
| condition | 前置条件 | 三读取项 | 生效/跳过 | 零 | 任意 operation | 无 | 无 | 只读 | condition_miss | 文案附带 |

## 4. 结算管线（V2 形式化，行为不变）

```text
play_gu/kill_move
→ 预检：can_activate(转数门禁) → 成本预检(念头/真元/寿元含不可致死)
→ trigger 判定：on_play 直接进入；on_hit_taken 挂常驻（现 TRIGGER_COST）；on_turn_end/on_kill 登记钩子（新增，挂 active_permanents 同列表）
→ condition 判定：不满足 → condition_miss，资源照扣
→ operation 结算：selector 解析目标 → delay? 登记 : 即时执行
→ 全链 _log 落事件日志 → snapshot 下次构建只读投影
```

死亡校验统一在 `_strike_enemy` / `_settle_marks` / 延迟结算 / 敌意图结算四处出口（现状保持），新增原子不得绕过。

## 5. 行为保持承诺（对接 Q8-4）

1. 现有 8 kind 的 JSON 原样可跑：V2 引擎必须接受现网 gu.json/v1_battle.json 零迁移。
2. aoe→selector 等价转换由基线测试逐只验证（含 strike_aoe 顺序）。
3. TRIGGER_COST 语义原样保留，仅内部改挂 trigger:"on_hit_taken" 通道。
4. 基线测试集：48 显式效果逐只断言（伤害/治疗/真元/念头/状态/资源/寿元/魂/死因），外加 6 角色兜底各 1 抽样 + 杀招 4 系化解各 1。

## 6. 表达力自查（任务书验收 B 对照）

用本语法改写典型差异蛊（全部 JSON 可达，无特判）：

- 直接输出：`strike 6`（5 转 attack 兜底）
- 资源管理：`heal 2 + cost(true_qi 0, thought 2)` 高念头低真元
- 条件触发：`condition(self_hp_below 0.5) + heal 5`
- 状态操作：`status marked 2`（recon）；`consume_status marked + strike 3×层`（剑道引爆）
- 敌意图反制：暂缓（§2.3）
- 流派协同：`support(self, 2)` 任意流派铺场
- 风险换收益：`strike 12 + life_cost 2`（寿元预检接管）
- 构筑核心：`sword_intent 2`（跨回合引擎）+ 引爆句式组合

结论：9 原子 + 3 修饰轴 + 3 成本字段可覆盖验收 B 的 8 类行为中的 7 类（敌意图反制暂缓）。
