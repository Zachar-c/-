# RESEARCH REQUEST · 休眠资产换基评审(B 档数值/架构件复用方案)

> **STATUS: PENDING_L1**
>
> 日期：2026-09-25　发起：L2 Orchestrator　送审：L1　后续批准：L0(凡涉及核心体验取舍或行为变更)
>
> **自足声明**：你不能访问我们的仓库。本文件内嵌了全部判断所需的事实、裁决原文与数据；
> 文中 `file:line` 只是我们内部回查用的出处标注，**你不需要核对**。标注约定：
> `[裁决原文]` = 已生效裁定的原文摘录；`[仓内事实]` = 我们核验过的代码/数据现状；`[L2核实]` = 我的复核结论，可推翻。

## 背景与范围

冻结死档审计(2026-09-25)确认全仓 45 份带「冻结/唯一依据/权威」标记的已死文档中 26 份沉默死去；L0 判定其价值多数还在，死因是门禁未开、载体换血或批次阻塞。A 档 4 份已按现行真源落地；B 档 11 份登记换基前提待复用。

**本件只评审 B 档中需要建模判断的 4 件**(效果语法、role 曲线落点、魂轴模型、conformance 机制)。视觉类 6 件的复用门禁在 L0(视觉圣经批准/美术线立项)，不在本件；RUL-2026-09-19-010 的**不变量修订**也在 L0，本件 Q4 只设计机制。

**载体前提**(`[裁决原文]` L0 2026-09-24，见 PROJECT_MAP.md)：浏览器 Web 版(`game/wenzhen-web-lab/lab.html`)是当前完整长线游戏的产品载体；Godot 工程作为成熟规则与数据来源；美术方向可原创。另：2026-09-20 清理后 `game/world-model/` 仅存 governance/rulings/reports，其运行时、镜像数据与快照/验收脚本已删除。

## 硬约束(任何裁决不得触碰)

1. `[裁决原文]` RUL-2026-09-19-008(FOUNDATION APPROVED)：「1–5 转是凡级世界的『能力层级轴』——它决定能力预算、真元层级、可使用蛊的层级、成长门槛、资源稀缺度、社会身份，但它不是『一个统一乘到 HP / Damage / Price / Essence 上的万能倍率』。」冻结不变量：「Rank Power Budget ≈ 每转 ×2、1→5 约 ×16。它作用于『效果预算(Effect Budget)』，不直接乘所有伤害」「不同轴之间不要求共用同一个倍率」。
2. `[裁决原文]` RUL-2026-09-19-011：默认主标量按 sqrt(Budget) 增长(R1→R5 约 ×4，非 ×16)；movement/recon 为有意偏离(见 Q2 证据)。
3. **HOLD-1**(`docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md:110`)：战后真元完全回满 NOT APPROVED，任何方案不得依赖改它。
4. `[仓内事实]` V4.1 冻结表(至今是 lab 战斗核真值，锚点已核)：玩家基线 HP 24 / Qi 12(`js/mvp_content.js:25`)；战后回复 `victoryRecovery {hp:2, qi:2}` 为 MVP 战斗核唯一回血(`js/mvp_content.js:354`)；V4 敌方 HP 快照 猎犬10/山猪15/悍客18/狼王28(`js/mvp_content.js:263`)；逆息为 V4.1-Q1 主刀回气手段(`js/mvp_logic.js:470` 起)。
5. `[仓内事实]` 平衡证据纪律：复写引擎的模拟结果永久不得作为平衡/验收证据；数值论断须回到应用点；数值与产品取舍上抛，L2/Worker 不得自改冻结值。

---

## Q1 · 效果语法 FINAL 的换基采纳

**对象**:`game/docs/q8/GU_EFFECT_GRAMMAR_V2_FINAL.md`(R2 FINAL，2026-09-12，178 行)。自称「Effect Grammar 唯一权威」，状态「实施冻结——Go/No-Go 九项全 PASS 前禁止编写任何生产实现代码」。`[L2核实]` 它从未实施：生产代码中 `grammar_expression` 零命中；其 Go/No-Go 第 5/6 项指向的 12 只验证蛊纵切片件(`Q8_12_GU_VERTICAL_SLICE.md`)同样未实施。它的死因不是内容错误，而是 Go 门从未开、随后载体转向。

### 证据包

**§1 管线与两条硬纪律(原文摘录)**：

```text
effect := { trigger, condition?, cost, selector?, operation, modifier? }
执行顺序: can_activate -> trigger -> condition(false -> 结束) -> cost commit -> selector -> modifier -> operation
- condition 是零成本资格判断:false -> 立即结束(事件 condition_miss),必须短路在 cost commit 之前;
  cost commit 是第一笔不可逆变更,此前任何 miss 一分不扣。
- 一效果一操作(复合行为只存在于遗留兼容通道,不新增)。
- 先付费后延迟(delay 是 modifier:cost 在打出时支付,效果延后结算——拖延不免费)。
```

**§2 操作集(冻结 5 个)**：`strike`(造伤)/`shield`(护盾)/`heal`(治疗)/`status`(敌方;仅 marked + sealed 两种)/`weaken_intent`(敌方 per-target)。
- marked：上限 10 层，每回合每层 1 伤。sealed：**最小纵切**——被 sealed 的敌人其下一次 damage intent 被门禁(跳过)，仅此而已；完整封印世界观一律不做(R2 裁定)。
- weaken_intent：只降低目标**下一次 damage intent** 数值；per-target 不做全局 debuff；用后立即清零。与 sealed 分工：sealed 是门禁(意图不存在)，weaken 是削幅(意图变小)。
- 明确排除：move、buff、shift、heal_and_strike、sword_intent(进遗留兼容)、一切复合操作。

**§3 修饰符(冻结 3 个)**：`support`(登记式：打出后 `turn_supports[school] += support_bonus`，本回合后续同流派 strike 获加成，end_turn 清零；support 自己不结算)/`consume_status`(线性公式 **`final_amount = base_amount + stacks × per_stack`**；status 缺失时事件 `consume_miss`、**不扣成本**、effect 视为未发生)/`delay`(形态锁定：只允许 `on_play + delay + operation` 一种组合；打出时付费，登记 `delayed_effects` 表，到期自动结算；表随 battle 生命周期存在并入存档序列化)。

**§4–5 触发器与资格(冻结)**：触发器 2 个——`on_play` / `on_hit_taken`(on_turn_end/on_kill 仅记录为候选，不实现不预留钩子)。condition 3 谓词——`self_hp_below` / `enemies_alive_gte` / `turn_gte`(纯谓词无副作用，miss 不扣成本无部分结算)。selector 3 项——`self` / `enemy_first` / `enemy_all`。

**§9 最小引擎改动清单(4 处，越界即回退)**：① sealed 意图门禁(敌方 intent 消费处一刀门禁)；② weaken_intent(敌方 intent 数值处 per-target 减免+消费/回合结束清零)；③ delayed_effects 表(登记/到期结算/存档序列化)；④ trigger 泛化(on_play/on_hit_taken 统一入口)。行为保持承诺：显式化前后逐只蛊伤害相同(对拍验证非抽查)；成本先展示后支付；不改 `can_activate`、转数惩罚 `2^(gu_rank - cultivator_rank)` 与资质系数。

**§12 实现硬约束(要点)**：H1 禁止 cost-then-check；H2 consume_status 原子事务(禁止 clear-then-strike)；H3 sealed 数据化(禁止在 resolver 里硬编码 `if sealed > 0: skip()`，敌方意图需带 `damage_intent` 属性)；H4 `enemy_first` = 「当前敌人行动队列的第一个存活目标」(禁止实现为「数组第一个元素」)。

**§11 禁止项(要点)**：不做流派克制网、抽牌/手牌/蛊槽；不加新货币、不加跨局战力成长；status/buff 不表破防加伤；杀招多段走 `steps` 不加新 effect kind；不做全局意图 debuff；蛊生命周期(喂养/忠诚/凶性/逃逸)本阶段冻结。

**冲突证据**(`[裁决原文]` numeric-status-audit.md 对账表 C2/C3 原文行)：

| # | 矛盾 | 双方 |
|---|---|---|
| C2 | 蛊的伤害有两套通道且不可比 | 显式 61 只(手写、无转数放大、可倒挂)vs 兜底 741 只(`base+(rank-1)`)；实测三转 strike 2 弱于一转 strike 4 |
| C3 | 语法文档与代码对 strike 的表述冲突 | `GU_EFFECT_GRAMMAR_V2_FINAL.md:40` 称 strike「沿用 rank 缩放」(`amount = base + (rank-1)`)，`v1_battle_resolver.gd:469` 实际不缩放——按文档实施会得到与现状不同的行为 |

**lab 现行效果层**(`[仓内事实]`)：产品战斗核 = `lab.html:90-91` 加载的 `js/mvp_logic.js`(CombatCore)+ `js/mvp_content.js`；效果数据由 `game/data/` 生成到 `js/data.js` 消费；当前仅 4 只 MVP 蛊(月光/小光/月芒/白豕)为 10 分钟实验组合，反制处理走 `counterHandled()`(「读对+做对」减伤 3)。lab 无 resolver 里的 rank 缩放争议面——它的效果定价走 PP 体系(见 Q2)。

### 请裁决

| ID | 方案 | 含义 |
| --- | --- | --- |
| Q1-A | **按节采纳**：语义层(管线/操作集/修饰符/触发器/condition/selector/H1–H4)整体采纳为 lab 效果层规格，仅缩放段按 RUL-008/011 重写 | 复用最大；效果行为会变，须 L0 批准行为变更并处理存档兼容 |
| Q1-B | **只采纳词汇表**：操作集与修饰符命名/语义作设计词典，管线不采纳，lab 维持现行 resolver | 零行为变更；语法降级为参考 |
| Q1-C | **不采纳**：等肉鸽层/构筑分叉重建时重起语法 | 放弃存量设计 |

若裁 Q1-A，请一并给出：
1. **缩放段重写方案**：C3 冲突(文档称 strike 沿用 rank 缩放、代码不缩放)在「转数=层级轴非万能倍率」新框架下应统一到哪个口径(兜底按 Q2 的 sqrt 曲线？显式手写不缩放？)；
2. **验收判据**：如何证明「语法实施后与 RUL-008/011 预算形状一致」；
3. **与 lab 现行 V4.1 战斗核的叠加方式**(替换 CombatCore、还是作为 CombatCore 之上的效果语义层)。

---

## Q2 · p3b1 role curves 的 Web 落点校验

**对象**:`ai-system/tasks/p3b1-role-curves.md`(P3-B1 任务包)。曲线数学已由 RUL-011 冻结，A 档已把该包挂回 Phase 8 批B 作底稿。执行是 L2 机械活，**落点映射**需你确认一次。

### 证据包

**`[裁决原文]` RUL-2026-09-19-011**(adjudicated_via p3-effect-budget RR，L2 已复算)：
- statement：「转数预算 40/80/160/320/640 为分配总量；默认主标量按 sqrt(Budget) 增长(R1→R5 约 ×4，非 ×16)；给出六个 role 的默认标量曲线；保留现有 6 role + 8 kind 分类；role 曲线只是默认值，剩余预算由 kind / 蛊个体效果分配；R5 一致性按 (role, kind, 归一化耗元档位) 同侪组比较『已结算总效果预算』，容差 85%–115%。」
- B3 六条曲线(L2 复算与纯 sqrt 预测逐项比对：attack/defense/healing/logistics 全符；movement/recon 为有意偏离)：`attack: 4/6/8/11/16；defense: 4/6/8/11/16；healing: 3/4/6/8/12；logistics: 2/3/4/6/8；movement: 1/1/2/2/3(纯 sqrt 预测为 1/1/2/3/4，有意压低)；recon: 恒 1`。

**任务包 A 表(数值「照抄 L1，不得自行调整」)**：

| role | kind | `amount_by_rank`(一转…五转) |
|---|---|---|
| attack | strike | `[4, 6, 8, 11, 16]` |
| defense | shield | `[4, 6, 8, 11, 16]` |
| healing | heal | `[3, 4, 6, 8, 12]` |
| logistics | heal | `[2, 3, 4, 6, 8]` |
| movement | shift | `[1, 1, 2, 2, 3]` |
| recon | status | `[1, 1, 1, 1, 1]` |

**现行状态**(`[仓内事实]`，已核数据文件)：
- `game/data/v1_battle.json` `default_effect_by_role`(第 8 行起)：attack `{kind:"strike", amount:2}`、defense `{shield, 3}`、healing/logistics/movement/recon 同构标量；配线性律 `amount = base + (rank-1)`(`v1_battle_resolver.gd:174`，`RANK_SCALED_KINDS=["strike","shield","heal"]`)。
- 覆盖规模：802 只蛊中 **741 只(92%)** 无手写 `v1_effect`，走兜底；现行曲线倍数 attack 3.0×/defense 2.3×/healing 3.0×/logistics 5.0×/movement 1.0×/recon 1.0×——对预算总量 ×16 不同源。
- `game/data/balance.json` `rank_power_budget`(真源，已核)：`rank1_budget=40`，`budget_by_rank 40/80/160/320/640`，注记「全仓唯一能力预算真源…不直接乘所有伤害」。

**lab 侧量纲与投影规则**(`[仓内事实]`，`js/balance.js` 头注原文摘录)：

```text
两个 scope，各自单一真源(禁止「双真源」、禁止隐式双向同步):
  WORLD: game/data/balance.json      → 正式世界量纲
  LAB:   game/wenzhen-web-lab/js/balance.js → 10 分钟验证量纲
只允许 WORLD --projection--> LAB。

LAB_BUDGET_PROJECTION = 20
  labBudget(rank) = rankPowerBudget(rank) / 20   → 40/80/160/320/640 → 2/4/8/16/32
  20× 是投影比例,不是最终 Effect→amount 公式。lab 内 1 PP ≈ 1 lab damage;
  禁止写成「1 PP = 1 damage(全仓)」。

LAB_PRICING_V1(检测用相对尺,非正式定价/税法):
  PP: damage 1 / block 1.2 / heal 1.5 / inspect 1.5 / support 1.2 / suppress 2.5
  costTax = 1 + qi×0.15 + hp×0.25 + (thought-1)×0.20 + cooldown×0.10

LAB 分层常量(有意 ≠ 全仓;一律 PROJECTION,禁止修齐):
  thoughtsPerTurn=2(全仓 3)·1石→2 Qi(全仓 5)·playerHp=24(全仓 human_base_health=100)

MVP 蛊(月光/小光/月芒/白豕)= 10 分钟实验组合,禁止反推全库定价模板。
敌方推导: deriveEnemyHp({dpr, targetTurns, zeroRate, margin}) —— 敌方 HP 由
「kit 吞吐 × 目标回合 × 反制税」推导(js/balance.js:267-320),content 禁止手写 HP。
```

**载体变化对任务包的影响**(`[L2核实]`):p3b1 写作时(09-19)的阻塞点——派生镜像 `game/world-model/data/**` 怎么写(P1/P2/P3，因镜像被 `world-model/engine/rules.py resolve_effect` 当规则读)——**已随 2026-09-20 world-model 清理消解**(镜像与 engine 均已删除)；其 §C「审计工具里的第二份规则源」(`audit_effect_budget.py` 正则抠 GDScript)同属被清理体系。Godot 侧 `v1_battle_resolver.gd` 仍在(规则来源)，lab 侧消费生成的 `js/data.js`。

### 请裁决

1. **落点映射**：`amount_by_rank` 是否作为唯一真源写进 `game/data/v1_battle.json` `default_effect_by_role`(Godot resolver 改按 rank 索引读取、lab 经生成层消费)？还是 Godot/lab 各持一份(若各持，谁是真源)？
2. **lab 投影是否需要新映射**：兜底曲线值(4…16)与 `LAB_BUDGET_PROJECTION=20` 的 lab 预算(2…32)如何对接——直接以曲线值进 lab 战斗核，还是经 PP 体系换算？现行 MVP 4 蛊实验组合是否豁免(不反推全库)？
3. **敌方侧**:`deriveEnemyHp` 的 kit 吞吐输入是否随兜底曲线同步换基，还是维持现状待批B 一起动？
4. **批B 验收判据**：除曲线形状断言(30 个值逐值钉住)外，是否加「lab 24 HP 基线在换表后整局可通关」的产品门？

---

## Q3 · 魂轴数值模型：复核时效并决定是否重派

**对象**:`ai-system/RESEARCH-REQUEST-2026-09-19-soul-numeric-model.md`(368 行，自足件，原文逐条取证)。**它不是被取代——它是从未被回答**：全仓零引用、无 ANSWER 节，产品随后转向 Web。

### 证据包

**`[裁决原文]` 裁决链(全部 2026-09-19，现行)**：
- **RUL-004**(producer)：魂是可成长 Build Axis，承担四重身份(魂魄生存值/魂道能力资源/魂道攻击防御基础/长期成长属性)，「不要把魂设计成固定 1-4 的风险条」。当前禁止：直接删除高魂 AP 档位；以 max_soul=4 为前提调难度；把 starting_soul 定为主要 difficulty knob；仅把魂视为第三死亡条。「下一步先做只读 Soul System Audit，再决定数值。」
- **RUL-005**(producer，增补)：「AP 的门槛原始设计意图，其实就是参照原文的百人魂、千人魂、万人魂」「魂魄的当前值需要跟上限值分离」「可以增加改造现有的魂道蛊虫效果，让他们利用自身的魂道积累，可以打出更好的效果」「跟肉身跟真元有竞争关系了…你有 2000 个元石，但是你选择了提升魂魄底蕴，那么买提升修为的蛊虫和提升肉身的蛊虫的机会就没了」。
- **RUL-006**(producer)：魂魄底蕴就是魂道的修为，魂道最高造诣为幽魂的三头万臂。**关键 effects 条目**：「现存 soul 与 soul_max 的量级(开局 1/上限 4)与原文的『人魂』数量级(百→亿)不在同一标度上。是否换算、按什么比例换算，属数值设计，**后置给 L1 研究院，本件不做裁定**」；AP 门槛 100/1000/10000 与百/千/万人魂一一对应(L0 确认+原文核实)。
- **RUL-007**(producer，同音校正)：挡尸蛊→**胆识蛊**、撞魂→**壮魂**(原话同音误记；原文「一些胆石中，藏有胆识蛊，可以壮人魂魄」L76064)；落魄蛊→**落魄谷**(真源是地名)。

**待评审件与裁决链的关系**(`[L2核实]`)：该件 §2 产品意图已逐字吸收 RUL-004/005(Build Axis 四重身份、四条禁止、资源池机会成本「这是设计意图不是缺陷」)；§3.1 = RUL-006 定义；§3.5 手段表已应用 RUL-007 校正(胆识蛊/壮魂/落魄谷)。**它就是 RUL-006 明文委托「后置给 L1 研究院」的受件**，委托关系成立且无冲突——问题只是它被搁置未答。

**你判断时效所需的核心事实**(该件 §4 摘录)：
- 行动点档位表(现行生效)：魂值 0–9→2 点、10–99→3 点、100–999→4 点、1000–9999→5 点、≥10000→6 点；「游戏当前的魂上限是 4，玩家永远只能停在第一档(2 点)，上面四档全部不可达——当前最大的结构断裂」。
- 魂有两套互不相通实现：A 套(`soul`/`soul_max`，1/4 硬顶、全代码零写入路径、玩法全接线)在用；B 套(`soul_magnitude`/`soul_safe_capacity`/`soul_calm`/`soul_nature`，软顶、有成长函数、零玩法接线)闲置。
- 收支：增长仅 2 条(魂丹 6 元石→+1；黑市 20 寿元或气血→+1)；玩家→敌人的魂攻击通道完全不存在；40 只魂道蛊里 36 只无原文依据、39 只无战斗效果(「打出去和普通蛊没区别」)，真蛊胆识蛊被错挂人道。
- `[实测]` 脚本化决策器 4 组×200 局：基线通关率 68.0%(魂死因 61/64)；放开魂预算(1→4)97.0%；同时放开 99.0%。现有唯一难度旋钮(敌血倍率)非单调(1.5 倍反而更简单)。`[L2判断·该件原文]` 这些数据在「魂上限=4、无成长」旧结构下测得，证明魂轴在被设计前就已是硬约束，不能直接给新结构定难度。

**时效风险**(`[L2核实]`)：上述 `[游戏]` 事实取自 2026-09-19 的 Godot 时代代码/数据审计；此后发生 2026-09-20 world-model 清理(运行时/镜像删除)与 2026-09-25 lab 收敛批(材料循环移除、存档升 `lab-run-v2`、产品入口唯一 lab.html)。数据真源 `game/data/balance.json` 的 run 节(soul 1/4、AP 档位)未闻变动，但未逐键复核；产品运行层现为 lab 主运行层(`main.js`/`data.js`)，魂相关事实是否同构未审。

### 请裁决

1. **前提复核**：该件 §2–§3 与 RUL-004~007 的吸收关系是否完整一致？有无裁定后的新事实需要增补为前提？
2. **事实基准**:`[游戏]` 事实应以哪个运行层为基准重审(Godot `game/scripts` vs lab 主运行层)，还是仅按数据真源 `game/data/` 复核即可？
3. **处置**：按原文直接重派 L1 作答(RUL-006 的换算委托由它兑现)，还是先做一轮「事实刷新批」(把 §4 逐键对 lab-run-v2 复核)再派？
4. 若重派，其 Q1–Q9 的作答结果按什么顺序落进现行产品(Web 优先级如何排)?

---

## Q4 · RUL-010 机制遗产：lab ↔ game/data 一致性设计(机制设计，不变量裁定不在本件)

**`[裁决原文]` RUL-2026-09-19-010 statement**：「Web 线判定：弃 Godot 必须走 Production-Equivalent Bake-off；当前『双线手抄』模式 REJECT(长期必漂)；当前阶段 Godot = Canonical、Web = Disposable Prototype；P3 走『一份 Effect 语义 + 一份数据真源 + Godot 先做 Canonical + 输出 conformance cases』。」
**现状**：该不变量已被 L0 2026-09-24 载体裁定实际反转(修订在 L0)；但它防的病——双线手抄必漂——现在就是 lab 战斗核与 `game/data/` 真源之间的现存风险。**请设计 conformance 机制本身**。

### 证据包(`[仓内事实]`，全部已核)

现行漂移面与既有防线：
1. **量纲双 scope**:WORLD(`game/data/balance.json`)→ LAB(`js/balance.js`)单向投影，`LAB_BUDGET_PROJECTION=20`;balance.js 头注明「禁止双真源、禁止隐式双向同步」「只允许 WORLD --projection--> LAB」——这是**约定防线，无自动断言**。
2. **生成层**:lab 消费 `game/data/` 生成出的 `js/data.js`(classic script，经词法全局 `DATA.worldBalance` 读取，缺数据时 balance.js 设计为直接失败、禁止 silent FALLBACK——已是半自动防线)。
3. **来源字段三套口径**(P0 审计 2026-09-25，已登记 debt):gu.json 用 `source: novel/school_derived`;enemies/nodes/v1_battle 用 `origin+origin_ref` 裸行号;其余文件无来源字段——新增内容无统一可断言的溯源契约。
4. **已知双写位**:杀招伤害两个写入位置(`effect.amount` 25 条 vs `damage` 1 条，修饰符只作用于前者);`regen_pct` 同名两值(aptitude.json 丙等 20% 局外 vs v1_battle.json 丙等 25% 战斗)——numeric-status-audit C4/C5。
5. **测试底座**:lab 侧 27 个 `node --test` 文件(phase0–phase8 门禁、balance、canon_pack、canon_runtime、lab_combat、lab_save、mvp_logic、run_flow、shop_rules 等);lore 侧另有 `compile_runtime.py` 把 lore/wiki+canon-index 编译成 `lore/runtime/` 机器投影(entities/rules/relations)。
6. **已消失的防线**:旧 `check_upstream_drift.py`/`build_world_model.py` 派生镜像体系随 world-model 清理删除;`game/docs/contracts/module-interfaces/` 为现行接口权威。

### 请裁决

1. **断言层级**:conformance cases 应覆盖哪几层——数据 schema(键与类型)、效果语义(同一输入 → 同一结算)、数值投影(balance.json → lab 预算/PP 换算)、存档兼容、来源字段完整性？请给出优先序与理由。
2. **基准侧/跟随侧**：每层谁是基准(`game/data/` 真源)谁是跟随(lab 生成层/CombatCore)？投影常量(LAB_BUDGET_PROJECTION、playerHp 24 等「有意 ≠ 全仓」项)应作为**合法偏差白名单**还是逐条断言换算公式？
3. **最小第一版**：在现有 27 文件 `node --test` 体系内，不引新框架，第一批最值得落的 3–5 条断言是什么(给出每条的断言对象与失败含义)？

---

## WHY CODEX CANNOT DECIDE

- Q1 是架构与数值模型取舍、Q2 是数值映射口径、Q3 是模型层设计委托的兑现、Q4 是一致性机制设计——均属根 `AGENTS.md`/`docs/AI_DEVELOPMENT_PROTOCOL_v1.0.md` 规定的 L1 判定；Q1 若裁采纳，行为变更还须 L0 批准。
- L2 已完成且不在本件范围：死档审计与分档、A 档落地、全部代码/数据锚点核实(`docs/dormant-registry.md`)。

## ANSWER(待 L1 填写)

> 裁决落盘后在此节登记：每问一个结论 + 依据 + 需 L0 批准项清单；并同步回写 `docs/dormant-registry.md` B 档对应行的「换基前提」为已裁决状态。
