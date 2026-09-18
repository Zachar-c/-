# WORLD_BEHAVIOR_TAXONOMY.md — Q8-R1 阶段 A：世界行为词典

> 日期：2026-09-12。状态：分析文档，禁止修改生产代码。
> 问题：**蛊虫在本游戏中，到底能够对战局做什么？**
> 方法：从《蛊真人》世界模型与当前系统真实雏形出发归纳行为类别；传统 RPG/Buff/Skill 分类只作对照，不作骨架。
> 事实基线：`docs/q8/CURRENT_EFFECT_CAPABILITY_MATRIX.md`（17 项能力表 + 缺口 G1-G10）。标记：[FACT]=代码/数据核实；[INFERRED]=推断。

---

## 0. 归纳原则

蛊是活物，各司其职。行为类别的划分标准不是"效果类型"（那是语法层的事），而是**蛊虫改变了战局的什么**：敌人的身体、自己的身体、敌人蛊的行动、时序、信息、蛊与蛊的关系。每类行为按六问审计：①世界模型依据 ②玩家决策价值 ③现有雏形 ④是否需要新引擎能力 ⑤是否适合成为基础语法 ⑥是否暂缓。

## 1. 伤敌域

### 1.1 直接输出（strike）
①攻击蛊以毒、锋、力伤敌；高一转数倍量级。②基础交换率：真元→伤害。③[FACT] strike 21 显式 + attack 兜底全员；`_strike_enemy` 先吃盾后扣血。④无。⑤✅ operation。⑥否。

### 1.2 范围输出（enemy_all）
①虫群、毒雾、剑光弥散，不点杀而面杀。②多敌场景的取舍（现在 aoe 只对测试蛊存在，无真实决策）。③[FACT] aoe 子键引擎支持、现网 1 只测试蛊。④selector 泛化即可（已批准）。⑤✅ selector。⑥否——但纵切至少 1 只真实 aoe 蛊。

### 1.3 复合输出（heal_and_strike）
①噬敌血肉反哺己身（血道原型）。③[FACT] 1 只。⑤语法糖（=heal+strike 序列），不设独立原子。⑥否。

## 2. 护己域

### 2.1 格挡（shield）
①甲壳、壁垒、玉皮蛊护体。③[FACT] 6 显式 + defense 兜底；一次性格挡池。⑤✅ operation。⑥否。

### 2.2 治疗（heal）
①疗伤蛊耗真元生肌续命。③[FACT] 10 显式 + healing/logistics 兜底；healing 通道钳制上限。⑤✅ operation。⑥否。**开放问题**：规格要求"疗伤依赖治疗蛊或事件效果并占用构筑位置"[DESIGN]——当前治疗蛊与攻击蛊同权进战斗，无占用感，纵切用 condition（残血才起效）制造占用感。

### 2.3 身法（shift）⚠️ 历史兼容层
①身法蛊让敌人打空——但引擎无位置/闪避概念，2026-09-12 已裁定转译护盾。②当前无决策价值（=盾 1）。③[FACT] 5 显式 + movement 兜底。⑤**不写入世界模型语义**：shift 保留为历史兼容层，新内容禁止使用；身法蛊的世界语义（闪避？先手？脱离？）留待独立裁定，纵切中身法位用 trigger/condition 或 seal 等已批准原子表达。⑥语义重定义暂缓。

## 3. 锁敌域（控制）

### 3.1 封蛊（玩家→敌，seal）⭐ 提前进纵切
①封锁敌蛊催动是原著战斗核心手段（禁制、封蛊类对轰）；敌人也有 seal 意图封我方——攻防应对称。②对抗高伤意图/跳过 Boss 关键二阶段的时机决策："现在封还是留着？"。③[FACT] 敌侧 `_seal_random_gu` 完整（确定性轮转封我方蛊 ≤3 回合）；玩家侧零通道。④最小实现：operation=status(name:"sealed") 写入敌人 statuses（字典已有）+ `_resolve_enemy_intent` 开头一条门（sealed>0 → 意图失效并 -1）。不改敌人数据结构。⑤✅ status 的合法名字 + 意图执行门（唯一新引擎改动）。⑥否——R1 验收第 5 条。

### 3.2 刻痕（marked）
①剑道道痕印在敌身、自寻弱点、长留。②"铺层→引爆"的构筑句式。③[FACT] recon 兜底全员 + 剑道 T15 落地（cap 10、每层 1）。⑤✅ operation(status)。⑥否。

### 3.3 束缚（bound）⚠️ 白名单内、零实现
③[FACT] `V1_STATUS_IDS=["marked","bound"]` 但引擎不消费 bound；loot/market 侧 bound 是"蛊实例被绑定"非战斗状态。④若实现=另一个意图门，与 sealed 语义重叠。⑤不进语法。⑥暂缓——纵切不使用；建议从 V1_STATUS_IDS 移除或明确为实例状态专属。

## 4. 以命易势域（风险交换）

### 4.1 寿元支付（life_cost）⭐ 纵切必验
①"蛊师的寿元是可以被蛊索取的"——以命换力是原著反复出现的禁忌交易。②"用未来换现在"的真实决策：何时值得透支。③[FACT] `_spend_costs` 通道完备（含预检：扣到 ≤0 效果不执行直接陨落、付费不可致死红线）；杀招字段存在；**现网数据全 0**。④无新引擎。⑤✅ cost 字段（已有）。⑥否——纵切 2-3 只真实实例（杀招优先）。

### 4.2 魂魄/真元/气血的战斗外交换
①黑市寿↔魂↔气血兑换（50 倍不对称）。③[FACT] 黑市 resource_trade 完整。⑤战斗外命令，非战斗语法。⑥否（不在 R1 范围）。

### 4.3 敌侧三轴（敌 true_qi/soul/lifespan）
③敌人无相应字段。④需敌人数据结构扩展。⑥**暂缓**（R1 裁定）。

## 5. 驭时域（时序）

### 5.1 延迟行为（delay）
①蛊效酝酿发作（毒发、慢性侵蚀、后手）；事件层已有 delayed_soul_cost 先例。②"现在种、下回合收"的时机博弈。③[FACT] 战斗内零实现。④battle.delayed_effects 登记表 + end_turn 递减（已批准）。⑤✅ modifier。⑥否。

### 5.2 触发行为（trigger）
①蛊按机缘自主发作（受击反震、回合流转、敌倒触发）。③[FACT] TRIGGER_COST 受击触发完整；durability 三模式引擎齐备零使用。④trigger 泛化（on_hit_taken 收编 + on_turn_end/on_kill 新钩子）（已批准）。⑤✅ trigger。⑥否。

### 5.3 条件行为（condition）
①蛊效需机缘成立（残血反哺、敌众我寡、时机成熟）。③零实现。④三读取项（self_hp_below/enemies_alive_gte/turn_gte）（已批准）。⑤✅ condition。⑥否。

## 6. 知彼域（信息）

### 6.1 战斗外侦察
①小光蛊探路、侦查、解除迷雾。③[FACT] recon 兜底 + field_actions（scout/signal/disguise）+ reveal_hidden 传承。⑤节点层行为，非战斗语法。⑥否（已工作）。

### 6.2 敌意图反制 ⭐ 最小路径
①"知道敌人要出什么，以蛊应之"——战前知彼是原著蛊师斗法的常态；clue 线索与意图公开的数据已存在。②情报→反制的读谱决策。③[FACT] 意图对玩家公开（快照投影）；clues 字段每敌 2 条；**零玩法交互**。④最小路径：operation=`weaken_intent{amount}` 写 `battle.next_intent_mod`；敌回合意图伤害结算时应用并清零。一条读取→一只蛊反制→敌行为改变的完整闭环。⑤✅ operation（新，最小）。⑥否——R1 验收第 6 条。

### 6.3 信息隐藏与泄密
①杀招秘密一旦使用即被洞悉（`revealed_to` 直译原文）；敌方 counter_hidden 是"我不知道这招会被化解"的信息差。③[FACT] 完整。②这是**被动成本与敌方资产**，非玩家主动行为。⑤不设原子。⑥否（现状即语义）。

### 6.4 化解（counter tag）——敌对玩家的信息博弈
①world：杀招有克制。③[FACT] tag 匹配→效果无效资源照扣→revealed 迁移。⑤已有机制。⑥否。

## 7. 合道域（协同与组合）

### 7.1 流派支援（support）⚠️ 层级裁定
①同流互济（气道辅气道）。③[FACT] turn_supports 机制完整（本回合后续同流派 strike 加成，end_turn 清零）。⑤**modifier 而非 operation**——R1 裁定明确：support 修饰"后续动作的威力"，与 strike/heal 不同层级。⑥否。

### 7.2 杀招组合（kill move）
①命名杀招=多蛊协同的固化句式；配方、化解、泄密、跨转数。③[FACT] 26 条完整。⑤组合句式层（蛊×蛊→杀招），非原子。⑥否（已有）。

### 7.3 引爆标签（consume_status）
①道痕自寻弱点、毒发攻心——状态不是终点而是弹药。②"铺层还是引爆"的组合分岔。③零实现。④consume_status modifier（已批准）。⑤✅ modifier。⑥否。

### 7.4 低转进高转构筑
①低转蛊以成本效率与协同进入高转阵容。③[FACT] 2^n 折价 + can_activate 门禁。⑤cost 轴行为，非原子。⑥否（已有）。

## 8. 行为 → 语法映射总表

| 行为 | 语法元素 | 层级 | 引擎改动 |
|---|---|---|---|
| 直接输出 | strike | operation | 无 |
| 范围输出 | selector:"enemy_all" | selector | 收编 aoe |
| 格挡 | shield | operation | 无 |
| 治疗 | heal | operation | 无 |
| 复合输出 | heal_and_strike | operation（糖） | 无 |
| 身法 | shift | **历史兼容层，禁新内容** | 无 |
| 封蛊（玩家→敌） | status(sealed) + 意图门 | operation + 引擎一条门 | `_resolve_enemy_intent` 开头 |
| 刻痕 | status(marked) | operation | 无 |
| 束缚 | — | 暂缓 | — |
| 寿元支付 | cost.life | cost | 无（补数据） |
| 延迟 | delay | modifier | delayed_effects 表 |
| 触发 | trigger: on_hit_taken/on_turn_end/on_kill | trigger | 泛化 TRIGGER_COST |
| 条件 | condition 三读取项 | condition | 新 |
| 意图反制 | weaken_intent | operation（新） | next_intent_mod 一读一清 |
| 流派支援 | support | **modifier** | 无 |
| 引爆标签 | consume_status | modifier | 新 |
| 杀招组合 | kill_move 句式 | 组合层 | 无 |
| 信息类战斗外 | field_actions / reveal | 节点层 | 无 |

**新引擎改动总计 4 处**（R2 定稿）：意图门（sealed）、敌身上 `intent_weaken` 一写一清（weaken_intent，per-target）、delayed_effects 表、trigger 泛化钩子（on_play/on_hit_taken）。其余全部是数据表达与现有机制收编。

## 9. 暂缓清单（R1 裁定重申）

敌方 true_qi/soul/lifespan 三轴、modify_future_action、大型玩家 tag 网络、新 Buff 通道、大规模 durability 内容化、shift 世界语义重定义、bound 实现。
