# Q8_12_GU_VERTICAL_SLICE.md — Q8-R2：12 只验证蛊 + 6 个决策场景

> - **日期**：2026-09-12。**状态**：纵切规格（实施冻结中，不改代码）。语法依据：`GU_EFFECT_GRAMMAR_V2_FINAL.md`（唯一权威）。
> - **目的**：用 12 只**真实在册**蛊（gu.json 802 之内，非虚构）证明 V2 FINAL 语法足以表达《問眞》世界行为，且每个行为都有玩家决策价值（R2 验收第 5/6 条）。
> - **标注纪律**：[FACT] = gu.json / 引擎现有数据；[DESIGN] = 纵切新增的语法映射（实施期写入）。推断不入正文，语义层描述一律 [DESIGN]。
> - **成本事实基线** [FACT]：`true_qi_cost` 缺省取 `essence_cost` 再缺省 1（v1_battle_resolver.gd:178）；`thought_cost` 缺省 1（battle_snapshot.gd:302）；`life_cost` 缺省 0；个别蛊带专属代价键（如 sword_mark_cost）原样透传。

## 0. 两类映射（行为保持红线的落点）

- **第一类·显式化（行为零漂移）**：A1–A4。现网效果已是事实（显式 v1_effect 或 role 兜底），显式化后**逐只数值相同**，实施期做 seed 固定对拍。
- **第二类·新语法映射提案 [DESIGN]**：B1–B4、C1、C2、D1、D2。这些蛊现走 role 兜底或无战斗效果；提案实施时**替代或叠加**兜底行为，数值属新平衡，须单独走数值表审批（AGENTS.md：调参数值落 JSON 配置并通过 Schema 校验）。
- **缩放规则** [FACT]：显式 v1_effect **无**转数放大；role 兜底（default_effect_by_role）的 strike/shield/heal 按 `amount = base + (rank-1)` 缩放（v1_battle_resolver.gd:145-146），support_bonus 随 rank 梯度（L147-148）。故兜底蛊显式化时最终数值 = 表基值 + rank 缩放，逐只对拍以此为准。

## A. 基础 ×4（第一类·显式化）

### A1 `sword_atk_4_01_gu` — strike 基准 [FACT]
- **world_semantics**：剑道攻击蛊（r4 epic），飞剑斩敌；本位只证「纯打击」最小行为（飞剑/刻痕等剑道机制走既有通道）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"}, "operation": {"kind": "strike", "amount": 5}}
```
- **cost**：true_qi 1（默认）[FACT]；`sword_mark_cost: true` 原样透传。
- **decision_value**：全语法体系的**交换率锚点**——其余操作是否值得，相对它衡量。
- **synergy**：吃 turn_supports 同流派加成（v1_battle_resolver.gd:393）。
- **counterplay**：敌方盾先吃（strike 先盾后血）；counter tag 化解。

### A2 `stone_shell_gu` — shield 基准 [FACT]
- **world_semantics**：石壳蛊甲壳护体（earth r1 common，tags guard/body/jade）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "self"}, "operation": {"kind": "shield", "amount": 3}}
```
- **cost**：true_qi 1（`essence_cost: 1` 显式）[FACT]；`feeding_cost: 2` 属养蛊域，冻结不进战斗。
- **decision_value**：盾是「本回合确定性减伤」，与 heal（回已有伤）构成「将伤 vs 已伤」取舍。
- **synergy**：铺层流派（marked）的天敌位——层跳伤先撞盾。
- **counterplay**：多段杀招逐段磨盾（steps 每步各自吃盾）。

### A3 `sword_heal_1_09_gu` — heal 基准 [FACT]
- **world_semantics**：剑修以剑气调理伤势（sword r1 healing role）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "self"}, "operation": {"kind": "heal", "amount": 2}}
```
- **cost**：true_qi 1（默认）[FACT]。
- **decision_value**：残血时的生存线投资；治疗通道既有钳制上限。
- **synergy**：与 B1 残血条件流构成构筑生存轴。
- **counterplay**：斩杀线压过治疗量（一波伤害 > 治疗+盾）。

### A4 `wisdom_rec_1_20_gu` — status(marked) 显式化 [FACT]
- **world_semantics**：智道侦察蛊标记敌人破绽。**gu.json 显式 status kind 为 0**，此蛊现走 recon role 兜底；显式化后数值逐只相同。
- **grammar_expression**（数值 [FACT] 抄自 data/v1_battle.json `default_effect_by_role.recon`）：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "status", "status": "marked", "amount": 1},
 "modifier": {"kind": "support", "school": "self", "bonus": 1}}
```
- **cost**：true_qi 1（默认）[FACT]。
- **decision_value**：铺层（每回合 1/层，上限 10）与速攻的时序分岔入口。
- **synergy**：B2 引爆位；剑道刻痕（cap 10 同构）。
- **counterplay**：敌方高压节奏——在层跳伤收益兑现前结束战斗。
- **附注** [FACT]：recon 兜底自带 `support_school: self + support_bonus: 1`（同流派支援登记），显式化一并保留。

## B. 组合 ×4（第二类·[DESIGN] 提案）

### B1 `blood_farewell_gu` — condition 零成本资格
- **world_semantics**：血道诀别蛊（r1 epic，tags poison）——伤重之际回光一击；**伤不重则不出手、不收钱**（condition 零成本语义的展示位）。
- **grammar_expression**：
```json
{"trigger": "on_play", "condition": {"type": "self_hp_below", "threshold": 0.5},
 "selector": {"type": "enemy_first"}, "operation": {"kind": "strike", "amount": 4}}
```
- **cost**：true_qi 1；**condition miss → 事件 `condition_miss`、不扣真元、无部分结算**（R2 D1 裁定）。
- **decision_value**：构筑分岔——只有残血换血流派才带它；满血时它是零成本死按钮，仍占行动（决策仍在）。
- **synergy**：与 D1 燃寿流构成「以命易势」风格线（词典 4.1 域）。
- **counterplay**：敌方速攻抢在残血线之前终结。

### B2 `water_atk_3_05_gu` — consume_status 线性引爆
- **world_semantics**：水蚀溃创——**有创才溃**：敌方已有伤印则溃之，无伤则不出手不收钱（水渍需旧创方能渗入）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "strike", "amount": 2},
 "modifier": {"kind": "consume_status", "status": "marked", "per_stack": 1}}
```
- **cost**：true_qi 1；**marked 缺失（stacks=0）→ `consume_miss` + 不扣真元、effect 未发生**（R2 D2 裁定，注意：这是「条件化」语义——替代现网无条件 fallback strike 2，属第二类）。
- **结算**：2 层 marked → final = 2 + 2×1 = 4 伤，随后清除全部层。
- **decision_value**：「保留铺层（复利）vs 引爆（一次性兑现）」的核心分岔（场景 S3）。
- **synergy**：A4 铺层、剑道刻痕。
- **counterplay**：单层时引爆价值低——铺层深度决定引爆收益。

### B3 `fire_atk_2_01_gu` — delay 延迟结算
- **world_semantics**：火蛊埋燃——今夜种火，来日方燃（fire r2 attack）。
- **grammar_expression**（strike 2 保留现网 fallback 值 [FACT]，纯叠加 delay [DESIGN]）：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "strike", "amount": 2},
 "modifier": {"kind": "delay", "turns": 1}}
```
- **cost**：true_qi 1 **打出时支付**（先付费后延迟）；delayed_effects 表登记，到期结算事件 `delayed_fired`。
- **decision_value**：本回合让出节奏、下回合确定性兑现——时机博弈（场景 S2）。
- **synergy**：与 sealed/weaken 组合「下回合必中大额」combo。
- **counterplay**：战斗在到期前结束则沉没；敌盾在结算时才吃。

### B4 `blood_atk_1_08_gu` — support 同流派支援
- **world_semantics**：血道同源互济——先手血蛊为后续血蛊开势。
- **grammar_expression**（fallback strike 2 保留 [FACT]，叠加支援登记 [DESIGN]）：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "strike", "amount": 2},
 "modifier": {"kind": "support", "school": "self", "bonus": 1}}
```
- **cost**：true_qi 1（默认）。
- **结算语义** [FACT 机制]：登记 `turn_supports["blood"] += 1`，本回合**后续**血道 strike 各 +1（含血_droplet 等同队蛊），end_turn 清零。
- **decision_value**：「垫刀」价值——本蛊伤害平凡，开势价值为主。
- **synergy**：`blood_droplet_gu`（strike 2 显式 [FACT]）本回合跟打 +1。
- **counterplay**：支援不可囤积（end_turn 清零）；击杀/干扰垫刀蛊断链。

## C. 信息/反制 ×2（第二类·[DESIGN] 提案）

### C1 `soul_def_2_10_gu` — status(sealed) 意图门禁
- **world_semantics**：魂道慑魂——摄其心神，令这一击**发不出来**（最小纵切：仅门禁敌方下一次 damage intent，不做封蛊世界观）。
- **grammar_expression**（该蛊现走 defense 兜底 shield 3；提案重定义属第二类）：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "status", "status": "sealed", "amount": 1}}
```
- **cost**：true_qi 1（默认）。
- **decision_value**：读谱时机决策——封高伤意图、还是封 Boss 二阶段起手（场景 S4）。
- **synergy**：与 C2 构成两档反制：**不发（seal）vs 打小（weaken）**。
- **counterplay**：意图已消费则空转（per-target 一次性）；多敌需 selector 精准。

### C2 `wisdom_atk_3_13_gu` — weaken_intent 削意图
- **world_semantics**：智道攻心——算准敌人招式路径，削其锋而不夺其势。
- **grammar_expression**（现走 attack 兜底 strike 2；提案重定义属第二类）：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "weaken_intent", "amount": 2}}
```
- **cost**：true_qi 1（默认）。
- **结算语义**（R2 D3 裁定）：per-target 写目标 `intent_weaken += 2`；只降低目标**下一次 damage intent**；消费或回合结束**立即清零**；不做全局 debuff。
- **decision_value**：情报→反制的读谱决策（意图快照对玩家公开 [FACT]）；削多少够、削谁（selector 必填）。
- **synergy**：clues 每敌 2 条 [FACT] + 意图公开 → 反制闭环。
- **counterplay**：削早了浪费在低伤意图上（用后即清）。

## D. 高成本 ×2（第二类·[DESIGN] 提案）

### D1 `blood_atk_5_02_gu` — life_cost 燃寿（词典 4.1 纵切必验）
- **world_semantics**：血道禁忌大蛊——燃寿催血，以命易势（r5 attack）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "strike", "amount": 8},
 "cost": {"true_qi": 1, "life": 2}}
```
- **cost**：**life_cost 2 [DESIGN 补数据；现网全 0（audit 事实）]**。预检通道已有 [FACT]：付费不可致死（扣到 ≤0 拒绝执行），UI 风险文案通道已有（battle_snapshot.gd:227-230）。
- **decision_value**：三轴死亡压力下「用未来换现在」（场景 S6）。
- **synergy**：B1 残血条件流的终局兑现位。
- **counterplay**：寿元战斗内不可回复；连续燃寿逼近预检拒绝线。

### D2 `qi_atk_5_02_gu` — 高真元/念头
- **world_semantics**：气道高阶输出——以浑厚真元催动大技（r5 attack）。
- **grammar_expression**：
```json
{"trigger": "on_play", "selector": {"type": "enemy_first"},
 "operation": {"kind": "strike", "amount": 6},
 "cost": {"true_qi": 6, "thought": 2}}
```
- **cost**：true_qi 6 + thought 2 [DESIGN]；高成本档的正确形态是**多资源**而非多操作（一效果一操作）。
- **decision_value**：真元续航 vs 单回合爆发的资源曲线；转数惩罚 `2^(gu_rank-cultivator_rank)` 下低境界携带成本陡增 [FACT 公式]。
- **synergy**：气道回气/支援链。
- **counterplay**：真元枯竭期成为真空回合——资源型输出的天然弱点。

## E. 覆盖矩阵

| 蛊 | operation | modifier | trigger | condition | cost 层 |
| --- | --- | --- | --- | --- | --- |
| A1 sword_atk_4_01 | strike 5 | — | on_play | — | qi 1 |
| A2 stone_shell | shield 3 | — | on_play | — | qi 1 |
| A3 sword_heal_1_09 | heal 2 | — | on_play | — | qi 1 |
| A4 wisdom_rec_1_20 | status marked 1 | support self 1 | on_play | — | qi 1 |
| B1 blood_farewell | strike 4 | — | on_play | self_hp_below 0.5 | qi 1（miss 零成本） |
| B2 water_atk_3_05 | strike 2 | consume marked | on_play | — | qi 1（miss 零成本） |
| B3 fire_atk_2_01 | strike 3 | delay 1 | on_play | — | qi 1（先付） |
| B4 blood_atk_1_08 | strike 2 | support self 1 | on_play | — | qi 1 |
| C1 soul_def_2_10 | status sealed | — | on_play | — | qi 1 |
| C2 wisdom_atk_3_13 | weaken_intent 2 | — | on_play | — | qi 1 |
| D1 blood_atk_5_02 | strike 8 | — | on_play | — | qi 1 + **life 2** |
| D2 qi_atk_5_02 | strike 6 | — | on_play | — | qi 6 + thought 2 |

覆盖核对：**5 操作 ✅；3 modifier ✅（support×2 / consume_status / delay）；condition 零成本 ✅；cost 三资源（qi/thought/life）✅**。
on_hit_taken：12 只不新增该触发器数据——现有 TRIGGER_COST 机制即其活体实例 [FACT]，引擎改动 #4（trigger 泛化收编）时以既有实例对拍验证。

## F. 决策场景 ×6（R2 验收：A/B 双合理，理由差异非纯数值）

### S1 速攻 vs 挂伤（A1 vs A4）
局况：敌 HP 中等，预计 3 回合内解决。
- **A** `sword_atk_4_01_gu` 直击 5：短敌命——铺层来不及跳完，确定性伤害最优。
- **B** `wisdom_rec_1_20_gu` 挂 marked：若下一层是更长恶战，每回合稳定 1 伤的复利更值，且 B2 引爆位形成构筑。
- **判定**：战场预期时长改变选择，非伤害点数比较。

### S2 先防 vs 先埋（A2 vs B3）
局况：敌本回合意图攻击 6，我方盾 0。
- **A** `stone_shell_gu` 盾 3，伤害推后下回合再打：先解燃眉——盾是确定性减伤，节奏稳。
- **B** `fire_atk_2_01_gu` 埋火延迟 1 回合，本回合硬吃 6：读谱判断敌后续无强意图，用血量换先手节奏。
- **判定**：风险承受与节奏判断，非「3 盾 vs 2 伤」算术。

### S3 保留 vs 引爆（A4 + B2）
局况：敌身上 marked 2 层。
- **A** 再挂 1 层（3 层复利）：预计战斗还剩 ≥3 回合，跳伤总量超过引爆。
- **B** `water_atk_3_05_gu` 引爆（2+2=4 伤并清层）：敌人下回合有强化/逃跑窗口，兑现锁定。
- **判定**：对剩余回合的信念 + 敌方意图读谱决定。

### S4 封 vs 弱（C1 vs C2）
局况：敌方下回合意图：攻击 8。
- **A** `soul_def_2_10_gu` sealed——这一击不发：8 点超出血线安全边际，门禁是唯一够强的应对。
- **B** `wisdom_atk_3_13_gu` weaken 2——打到 6：预期还有多回合，seal 一次性用完不如留资源打持久；且削幅保盾更划算。
- **判定**：威胁等级分级与资源续航观（不发 vs 打小是两档反制哲学）。

### S5 弱化谁（C2 selector 分岔）
局况：双敌。甲意图攻击 7（先手），乙意图攻击 3；甲有盾、将死。
- **A** selector `enemy_first`（默认）削甲：默认序=先手威胁序，操作成本最低。
- **B** selector 指定乙：甲将死且带盾，乙才是长线威胁——读谱 override 默认序。
- **判定**：威胁评估差异；selector 必填但不强制唯一解，玩家判断保留。

### S6 燃寿 vs 耗元（D1 vs D2）
局况：Boss 残血 HP 6；我方真元 7、寿元 22、念头 3。
- **A** `blood_atk_5_02_gu`（qi 1 + life 2，strike 8）当场收 Boss：终局窗口，2 年寿元买断整场恶战风险。
- **B** `qi_atk_5_02_gu`（qi 6 + thought 2，strike 6）同样收 Boss：寿元不可回复，真元可再生；耗尽真元留真空期但保住寿元线。
- **判定**：同样是「赢」，代价结构不同（不可再生 vs 可再生但枯竭）——三轴死亡观差异。

## G. 实施期验收方式（本阶段不执行）

1. **对拍**：第一类（A1–A4）显式化前后逐只伤害/治疗/盾/状态/支援登记相同（seed 固定回归）。
2. **场景回放**：6 场景在测试局内固定 seed + 固定敌配各跑 A/B 分支，事件日志断言对应键（`condition_miss` / `consume_miss` / `weaken_applied` / `sealed_applied` / `delayed_scheduled` 等）。
3. **交互门不回退**：`verify_interaction_loop.gd` 三键全绿。
