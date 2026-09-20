# PROJECT_WORLD_MODEL_AUDIT.md — 《問眞》（前称《蛊路求生》）项目状态基线

> 2026-09-20 说明：本文是 2026-09 的架构审计快照。`world-model` 运行时、
> Dialogue Manager 与 GDQuest vendor 源码均已清理，涉及这些对象的事实段不再代表当前仓库；
> 当前状态以 `game/AGENTS.md`、代码、测试和 `tools/check.ps1` 为准。

> 生成日期：2026-09-12。生成方式：三路并行代码/数据调研 + 权威规格文档核对。
> 用途：供外部架构审阅者在**不打开 Godot 项目**的情况下回答"这个项目现在到底是什么、独特在哪、有没有走偏"。
> 标记约定：[FACT]=代码/数据确凿存在；[DESIGN]=文档明确规定；[IMPLEMENTATION]=已实现且接入主循环；[PROTOTYPE]=存在但未稳定；[INFERRED]=推断；[MISSING]=不存在。

---

# 1. 项目一句话定义

一个以《蛊真人》小说为**世界模型**（而非题材皮肤）的单机 Roguelike：玩家扮演南疆一名新开窍的散修，在 5 大层节点地图中经历"生存→构筑→炼蛊→布局→冲击蛊仙（升仙窗口）"，目标是由小说的世界规则（蛊虫实体、转数量级、真元质量、念头操控、元石经济、寿元与魂魄代价）推导出全部游戏机制。品牌名《問眞》，旧名《蛊路求生》/Nanjiang Smoke。[FACT]

**关键定位声明** [DESIGN]（`docs/项目决策浓缩对话.md`）：不做方源剧情复刻；原著资料用来提炼"物品关系、地域风土与事件因果"；战斗、交易、试探、伪装、设局、借势、撤离、投降都是主动手段；每局随机经历一名蛊界人士的修行人生（首版固定身份）。

# 2. 项目当前阶段

- 技术栈：Godot 4.7.2 + GDScript + GUT，纯本地规则引擎，LLM 永久搁置（仅保留离线模板接口）。[FACT]
- 已完成：V1 战斗引擎全量替换卡牌战斗（2026-08-30 用户裁定）、resolver 拆分、按层伪随机地图 E1–E7、蛊方合成+图鉴、UI 全屏迁移 .tscn、交互闭环回归门、剑道流派批次 1/2/2b。[FACT]
- 当前批次：交互门全屏回归（17 个审计标签）、真窗键鼠验收（用户主动触发才做）、2026-09-12 架构纠偏计划（P1 巨石债）。[FACT]
- 规模基线：scripts/ 127 个 .gd，tests/ 202 个 .gd，data/ 29 张 JSON 表（约 45 万字节），scenes/ 28 个 .tscn，docs/superpowers/ 52 份计划 + 62 份规格。[FACT]
- 单局目标：3–5 小时、200–300 有效节点（5 层 × 8–11 行 × 2–6 节点）。[FACT]

# 3. 核心设计哲学

[DESIGN] 2026-09-01 总规格（用户已批准的权威基线）第 0 节八条纪律，这是判断本项目是否兑现世界模型的最权威文本：

1. **蛊虫是世界中的活物和独立实体，卡牌只是操作界面**，不是抽象技能许可证。
2. 万物皆可由蛊承载，但不能无来源地抽象（资质/侦察/交易能力必须落到具体蛊、蛊方、人物或场景）。
3. **代价真实存在**：真元、念头、喂养、时间、蛊材、元石、风险不得结算后凭空补齐。
4. 玩家自由组合蛊虫；复杂性由统一数据语法收敛，而非禁止组合。
5. **转数差距明显但不是唯一设计轴**：高一转数倍量级；低转蛊靠低成本/辅助/聚量/杀招进入高转构筑。
6. 所有关键结果可预见（死亡/蛊死/核心损失必须预检提示，不允许静默致死）。
7. 中央参数导出最终值，内容不重复写死跨转数表。
8. 规则引擎本地、确定、可复现；LLM 不参与任何判定。

配套红线 [FACT]：不使用抽牌/手牌/弃牌堆决定蛊虫可用性；无蛊槽数量硬上限（持有量由喂养/炼化/交易成本软约束）；蛊方图鉴是唯一跨局解锁；事件日志 append 起不可变。

# 4. 当前 Gameplay Loop

逐环节状态标注（主循环全部已实现，无断链）：

| 环节 | 现状 | 说明 |
|---|---|---|
| 开始一局 | [已实现] | `RunState.new_run`：丙等一转散修，80 血/60 寿元/魂 1（soul_max 4），12 元石，初始蛊小光蛊，洞天真元 20 |
| 获得什么 | [已实现] | 蛊实例（战斗掉落/商店/黑市/炼蛊产出）、7 种蛊材、元石、情报/clue、遗物（仅 2 个 [PROTOTYPE]） |
| 如何探索 | [已实现] | 5 层节点图，未走节点迷雾 `?`（E4），小光蛊/情报/传承揭露局部（`reveal_hidden`） |
| 如何遭遇敌人 | [已实现] | combat 节点 + E6 `enemy_roll` 按层 rank 区间/主题锚定池/tier 权重；Boss 只在层主位 |
| 如何战斗 | [已实现] | v1 纯函数回合制：真元+念头催蛊 / 基础攻击（1 念头不耗真元）/ 杀招 / 结束回合；敌先手按恶名掷先手 |
| 战斗获得什么 | [已实现] | 材料（按层 stone_budget 12→35 与稀有度权重 90/10/0 → 50/30/20）、元石（层预算制）、低概率蛊、elite 强制 epic 蛊 + 强制代价（蛊蚀或恶名） |
| 如何使用资源 | [已实现] | 黑市购蛊/以物易物/寿元↔魂↔气血兑换、元石补真元（1 石≈4-5 真元）、删卡/拔诅咒、洗白恶名 |
| 如何成长 | [已实现] | 转数晋升（同转晋升蛊方+兽骨+6/10 石）、洗髓换骨升资质（10 寿元+8 石/局限 1 次）、卡牌删改（各限 2 次/局） |
| 商人/事件/机缘 | [已实现] | shop/market/caravan/contact/event/inheritance/hazard/earth_vein/seclusion/pursuit 等 17 类节点模板 |
| 如何死亡 | [已实现] | hp≤0 或寿元≤0 或魂≤0 → `finalize_death` 清空局内资源，事件日志保留归因 |
| 死亡后保留什么 | [已实现] | MetaProgress 11 字段：蛊/蛊方/遗物/传承四图鉴、契约解锁、手记、统计、DDA 开关 |
| 为什么开下一局 | [已实现，深度有限] | 蛊方图鉴决定新局配方门禁（`global_codex_ids` 注入）+ 契约/手记/结局文案解锁；**无永久数值成长**（符合红线） |

[PROTOTYPE]/[孤立实现]：遗物系统（relics.json 仅玉蝉壳/饥饿藤签 2 个）；随机战斗合成（synthesis.json 盲合，3 张临时牌）；DDA 动态难度（数据与权重齐备，`dda_state_adaptive_enabled` 可开关）；传承杀招组合（inheritances.json 3 组）。

# 5. 《蛊真人》世界模型

总表：小说概念 → 游戏实体 → 实现状态。

| 小说概念 | 游戏实体 | 实现状态 |
|---|---|---|
| 蛊虫=活物 | 蛊实例（definition + instance 分离，同名蛊不同实体） | [IMPLEMENTATION] |
| 转数（1–9转） | rank 1–5 gating：`can_activate = low_rank_exception or cultivator_rank >= gu_rank`；下阶折价 `2^(gu_rank-cultivator_rank)` 倍率 | [IMPLEMENTATION] |
| 空窍/元海/资质（丁丙乙甲） | `aptitude_factor 1/2/3/4` 贯穿局外真元上限、战斗真元上限、回率、元石吸收率 | [IMPLEMENTATION] |
| 真元 | 局外 essence（节点内预算，节点完成回满）+ 战斗内 true_qi（stage_base × aptitude_mult）双轨 | [IMPLEMENTATION] |
| 念头 | thought_cost：每次行动耗 1 念头，回合重置；约束"正在主动操控的过程" | [IMPLEMENTATION] |
| 魂魄 | soul：行动次数分档（1/10/100/10000 底蕴 → 2/3/4/5/6 次）+ 死亡条件 + 炼蛊投料上限（craft_cap 2/3/4） | [IMPLEMENTATION] |
| 寿元 | lifespan 60 起步：杀招/蛊 life_cost、敌方意图、洗髓、洗恶名、黑市兑换均可扣；扣到 0 效果不执行直接陨落 | [IMPLEMENTATION]（但现网 life_cost 数据全 0，见 §26） |
| 元石 | 唯一货币 + 真元电池（1 石≈5 真元×资质吸收率） | [IMPLEMENTATION] |
| 杀招 | 命名杀招=配方蛊组合，威力手工配置；化解标签 + 泄密（`revealed_to`，直译"仙道杀招一旦被借用秘密即被洞悉"） | [IMPLEMENTATION] |
| 炼蛊/蛊方 | 392 条配方：advance 晋升 377 / fixed 古方 14 / free_mix 自由混合 1（三结局：毁尽/变异/炸炉） | [IMPLEMENTATION] |
| 流派/道标签 | 20 流派 × 40 蛊；同流派支援增益 `support_school`（只惠及本回合后续同流派蛊）+ 剑意衰减 50% + 剑水互斥兼修罚值 | [IMPLEMENTATION]（剑道部分 2026-09-11 落地） |
| 恶名/身份 | notorious：每点价格 +10%（封顶 60%）、敌意 +15%、先手 -10%；洗白 10 寿元/-2 点 | [IMPLEMENTATION] |
| 升仙 | `attempt_ascension`：Boss 胜利硬前置 + 五条件评分制（空窍根基/天地灵气/地点/保护/外患），风险追击/伤势/寿元债扣分，四等评价 | [IMPLEMENTATION] |
| 养蛊（喂养/饥饿/忠主/凶性/逃遁） | 仅 16 只核心剧情蛊有 `feeding_cost/feeding_need` 字段；其余 786 只无实例生命周期 | [PROTOTYPE]，规格 §2.1 全量实例状态 [MISSING] |
| 人情/NPC 深交涉 | npcs.json 5 个 NPC（意志 2-4）+ 声望规则；"目标/底线/恐惧/原则/援军"式深交涉 | [PROTOTYPE]，规格级深交涉 [MISSING] |

**结论 [INFERRED]**：世界模型不是术语换皮——转数质量门禁、资质贯穿、念头行动制、杀招泄密、寿元真实代价、节点内真元预算这六处是"从小说规则推导游戏机制"的实证。但世界模型的**生命面**（蛊会饿、会逃、会死、有性格）停留在 16 只核心蛊；世界模型的**社会面**（家族/势力/人情）停留在声望数值与 5 个 NPC。

# 6. 游戏实体模型

**蛊实例** [FACT]（RunState `gu_instances`）：definition_id + instance_id + rank + 炼化/核心状态；得失蛊必须同步 `gu_instances` 与 `cave_aperture.stored_gu_instance_ids`（走 transaction_ledger）。

**蛊定义**（gu.json 802 只，含 1 测试蛊）[FACT]：

```text
Gu
├─ id / name(gu_names.json 802 中文映射) / source(786 只标注小说出处)
├─ rank 1-5（220/157/180/97/147）│ rarity common 368/rare 185/epic 249
├─ school ×20 流派（blood/bone/dream/earth/fire/force/gold/heaven/human42/light/
│   luck/qi/refine/slave/sword/water/wind/wisdom/wood），每流派 40 只
├─ role 单一主功能：attack 379/defense 100/movement 92/healing 80/recon 78/logistics 73
├─ value 价值锚点 3/5/8/12/20（与 balance.json.gu_value_by_rank 一致，8 只离群高价值）
├─ v1_effect 仅 48 只有显式效果（strike 21/heal 10/shield 6/shift 5/sword_intent 5/heal_and_strike 1）；
│   其余 754 只由 v1_battle.json.default_effect_by_role 兜底
├─ essence_cost/true_qi_cost/feeding_cost 仅 16 只核心蛊有值（其余走默认 1）
└─ slot_role/field_actions/synergy_hooks/replace_value/core_depth/branch_recipes（16 只核心蛊专属）
```

**杀招** [FACT]：v1_battle.json 26 条（剑道 22 + 光 2 + 血 1 + 力 1）。结构 `{id, label, tag, recipe[definition_id...], true_qi_cost, thought_cost, life_cost, damage, effect}`。威力手工配置：最高"五指拳心剑·五转"=5 剑组成、7 真元、2 念头、伤害 24。

**配方** [FACT]：refinement_recipes.json 392 条 + 4 条商队报价。字段 `{id, kind, input_gu_ids, output_gu_id, materials, stone_cost, input_min_rank, output_rank, default_unlocked, source}`。

**敌人** [FACT]：enemies.json 32 条（common 13/elite 12/boss 7；beast 12/faction 6/anomaly 5/cultivator 5/neutral 4），字段 `{id, theme, grade, tier, rank, hp, clues[2], intent{damage,speed,cooldown|seal|soul_drain|essence_burn}, reactions[{trigger→counter_status}], boss:phases(50% 血量转阶段)}`。**无防御字段、无直接元石掉落字段**。

**节点模板** [FACT]：nodes.json 37 个（combat 10/rest 2/shop 1/market 2/caravan 2/contact 2/event 2/inheritance 3/hazard 3/earth_vein 3/refinement 1/cultivation 1/ledger 1/wild_gu 1/commission 1/pursuit 1/seclusion 1）+ 登仙节点。

# 7. 蛊虫系统

- **是什么**：永久实例资产（Run 内），非卡牌非装备。战斗中通过卡片化 UI 催动，持有数量无硬上限。[DESIGN+IMPLEMENTATION]
- **获取**：战后低概率掉落（common 掉率 0%、elite 30% 强制 epic、boss 0% 但给 2 材料+挖尸配方）、商店/黑市购买、商队以蛊换蛊、合成产出。战后蛊候选"三选一或全弃"是规格要求 [DESIGN]，掉落侧已实现概率制 [IMPLEMENTATION]。
- **构筑组合**：逐只催动已炼化蛊；每只先按单一主功能结算，后续蛊读取已形成的状态；基础联动无知识门槛、不收组合费、不凭空倍率 [DESIGN]。同流派支援 `support_school` 只惠及本回合**后续**同流派蛊（end_turn 清零）[FACT]。
- **炼蛊**：三种配方——晋升（同名蛊+兽骨+6/10 元石→转数+1，377 条）、古方 fixed（如月芒蛊=月光蛊+小光蛊×2，14 条，附小说出处与失败代价）、自由混合 free_mix（1 条：2 蛊起合，成功率 60% 基础+失败递增，三结局 w5 毁尽+蛊蚀 / w4 变异血别蛊 / w1 炸炉 HP-2 魂-1 寿-1）。已知配方安全确定成功；随机失败只留给盲炼/自由混合 [DESIGN+IMPLEMENTATION]。
- **喂养**：[PROTOTYPE] 仅 16 只核心蛊有 feeding 字段，主循环未见喂养压力生效。
- **升级/替换**：转数晋升即升级；核心蛊确认与更换凭证体系（规格 §1）[DESIGN]，实现侧有 `claim_core_token` 核心替换券挂在 2 个 boss/商队节点 [IMPLEMENTATION 程度待深查]。
- **稀有度**：common/rare/epic 三档 + value 价值轴分离（价值描述同转稀缺性，不做统一掉落强度轴）[DESIGN]。
- **核心判断 [INFERRED]**：玩家是在"构建自己的蛊虫体系"（转数门禁 + 流派支援 + 杀招配方 + 材料经济四条腿），不是"选技能"。但见 §26：754/802 的蛊在战斗数值层目前同质化。

# 8. 真元系统

**双轨制** [FACT]：

| 轨道 | 字段 | 上限公式 | 恢复 | 消耗 |
|---|---|---|---|---|
| 局外 essence | `RunState.essence / cave_aperture.essence_max` | `10 × aptitude(1/2/3/4) × cultivation(1/3/9/27/81)`，开局丙等=20 | 休息 +2、meditate +1、**节点完成即回满**、元石吸收（每石 floor(5×(0.5+regen%))）、材料 | 跨节点 use_gu、travel -1 |
| 战斗 true_qi | `battle.player.true_qi_max` | `stage_base{10,30,60,100,150} × aptitude_mult{1,2,3,4}`，开局满值 | 每回合 `ceil(max × regen_pct)`（v1_battle.json：甲35/乙30/丙25/丁18） | 蛊/杀招 true_qi_cost（默认 1）、TRIGGER_COST 受击触发 |

**世界模型特征判定 [INFERRED]**：不是普通 Mana 换皮。①真元有"质量"维度——低转真元催不动高转蛊（`insufficient_qi_quality`），下阶催动按 `2^(gu-cultivator)` 倍率加价；②真元是"节点内预算"的修仙资源观而非全局蓝条；③元石是真元电池（`stone_to_essence`，带 `max_useful` 防浪费预计算）；④资质影响吸收率（甲 0.9 → 丁 0.6）。已知缺陷：见 §26 regen_pct 双表冲突。

# 9. 生命/伤势系统

- HP：`health/max_health` 开局 80/80，战斗内镜像写回 `run_battle_flow.sync_battle_hp_to_state` 防双源漂移 [FACT]。
- 三死亡条件：hp≤0 / lifespan≤0 / soul≤0，cause 分别 hp/life_cost/soul [FACT]。寿元与魂魄同时是**可支付资源**（洗髓、洗恶名、黑市兑换、杀招代价），支付有预检红线：付费不可致死（`lifespan - cost >= 1`）[FACT]。
- 恢复：休息节点 heal 30% max(≥1)、治疗蛊、材料（兽血 +2 HP / 毒囊 **-1 HP**）、魂丹 6 石 +1 魂。
- 判定 [INFERRED]：不是传统 HP 换皮——伤势与寿元债、魂魄是三种独立死亡轴，且其中两条可被玩家主动透支（有预检+精准死因提示，符合"不允许静默致死"红线）。但"伤势影响后续决策"（重伤 debuff、疗效递减）[MISSING]；疗伤依赖治疗蛊或事件效果、应占构筑位置 [DESIGN] 已部分兑现。

# 10. 境界成长系统

```text
一转凡人起步（丙等资质）
↓ 转数晋升：同名蛊 advance 配方（兽骨 1-2 根 + 元石 6/10）→ rank+1（封顶 5）
↓ 另有 cultivate_rank_two 命令（休息类节点，5 元石，1→2 转）
↓ 每转提供：战斗真元上限 ×3 递增（stage_base 10→30→60→100→150）
↓ 转数只抬真元上限，不加 HP/攻击（2026-08-29 裁定）
↓ gating：cultivator_rank >= gu_rank 才能催动（低转蛊仍可玩：成本折价支持低转入高转构筑）
资质线（独立轴）：丁1/丙2/乙3/甲4
↓ 洗髓换骨：10 寿元 + 8 元石，+1 档，每局限 1 次，仅闭关/传承节点，甲等拒绝
```

[FACT] 局内成长，死亡清空（寿元里程碑 `lifespan_milestones` 仅作事件日志记录）。战力=转数×蛊（质量×数量）的派生读数，无单一战力数值节点 [FACT]。

# 11. 经济系统

**全局常数**（balance.json）[FACT]：蛊价值锚 1-5 转 = 3/5/8/12/20 元石；回购半价 0.5（低流动性 0.3）；需求价档 0.8/1.0/1.2；1 转材料基准价 10；删卡 120/删烙印 150；自由配对费 2 转 20 → 5 转 300 石；跨流派兼修每额外 +1 罚值（剑水互斥）。

**玩家财富流** [FACT+INFERRED]：

```text
收入：层 stone_budget 预算注入（12/16/22/28/35 元石）、商队交易、卖蛊（半价）、挖尸配方产出
支出：买蛊（6-80 石）、古方解锁（60-200 石）、晋升（6-12 石/次+兽骨）、自由配对（20-300 石）、
      元石补真元、删卡/拔诅咒（6-150 石）、魂丹/洗白/寿元交易
水龙头/水槽：黑市资源兑换（寿元 20→魂 1；魂 1→寿元 10；气血同理）——双向不对称 50 倍，
             是把"透支生命"定价进经济的核心机制 [INFERRED：未见文档确认该比例来源]
```

**价格膨胀** [FACT]：每层 `shop_price_pct` 0%→10%→20%→35%→50%；回头客每次访问涨价 +25%（封顶 100%）；恶名每点 +10%（封顶 60%）。市场节点"跳过则涨价"（`on_skip: price_rises`）。

**兽骨问题** [FACT]：385 条带材料配方中 378 条消耗 `beast_bone`（参考价 5、回购 0.5×），其余仅兽血 3、野猪王牙 2、月露 1、毒囊 1。**晋升经济实质 = 兽骨 + 6/10 元石**，7 种蛊材中 5 种几乎不进主流配方。

# 12. 商店系统

[FACT] shops.json 33 个 offer：purchase 13 / resource_trade 5 / gu_fang_unlock 5 / material_purchase 3 / lifespan_deal、barter、wash_notoriety、soul_boost、recipe_unlock 各 1。标价样本：石壳蛊 6、月光蛊 6、雷御蛊 9、小光蛊 12、玉皮蛊 30、白猪力蛊 35、月影蛊 40、月华露 80、传承信物 60、剑道系列 8/18/30/45/70（r1→r5）、古方解锁 60/80/200、魂丹 6。

E7 按层货架：每店洗牌取前 `4+⌊层/2⌋` 件（4→6）+ 保底 1 件本层最高档；`(局种子, 节点模板)` 派生，同店反复进出不变；`shop_max_tier` 1→5 按层解锁高价货。NPC 商人（商队管事/货郎/勒索者）库存引用 offer id [FACT]。讨价还价/供需/关系定价 [MISSING]（有需求价档常数与回头客涨价，属雏形 [PROTOTYPE]）。

# 13. 掉落系统

[FACT] loot_tables.json：7 种蛊材各有 value/参考价/流动性/食用效果（兽血 v2/10/0.8/+2HP；毒囊 v3/15/0.3/**-1HP**；野猪王牙 v1/15/流动性 0.2 **exclusive**；传承信物 v30/60）。掉落按 tier：common 蛊掉率 0%；elite 30% 且**强制 epic**，另绑代价池（蛊蚀 1 层或恶名 +2，各 w1）；boss 0% 蛊但给 2 材料 + 挖尸配方（月影/血月）。保底 pity 阈值 3（连出 3 个同档清空计数强制跨档）；材料保底针对毒囊/月露。

**判定 [INFERRED]**：掉落与层预算、恶名、契约、DDA 联动，"普通战给资源不给蛊"严格执行了规格 §1.4。但蛊获取渠道因此偏窄（商店+elite+合成），构筑节奏依赖炼蛊晋升。

# 14. 敌人系统

[FACT] 全 32 条完整数值见附录 A（关键样本）：杂兵 HP 3-5/伤 1-2；精英 HP 6-11/伤 3-4；层主 HP 14-20/伤 2-4 + 二阶段（50% 血量加封印/烧真元意图）。意图种类：attack/seal（确定性轮转封蛊，最多 3 回合）/soul_drain/life_cost/essence_burn；反制 `reactions` 把 counter_tag 塞进 `counter_hidden`——**杀招 tag 匹配则效果无效资源照扣**（light/blood/force/sword 四系化解网）。

世界逻辑差异 [FACT+INFERRED]：cultivator/faction/beast/anomaly/neutral 五主题+clue 线索+恶名联动先手，比"普通怪物"有身份感；但不同主题敌人的**资源结构差异**（散修 vs 家族蛊师 vs 商队）尚未进入掉落/财富差异——掉落只按 tier 分。

**审计红旗 [FACT]**：① 终点 `final_boss_stand` 敌人是 `miasma_vein_lord`（rank3/HP14），弱于 3/4 层层主（HP 18/20）——数值倒挂；② `blue_fur_jiangshi`(HP20)、`clan_patriarch`(HP19) 两个 rank5 boss 游离于层主体系外；③ 敌人无防御数值，防御只来自玩家侧。

# 15. 战斗系统

**流程** [FACT]：`start`（恶名/敌对掷先手，敌先手立即执行一轮）→ 玩家回合（多次行动，受魂魄分档行动点 + 念头约束）→ `end_turn`（念头清零/支援清空/蛊 used 复位 → 敌人依次意图 → 刻痕结算 → 剑意减半 → 回合+1 → 玩家回合开始回真元）。胜利=全敌倒；败北=hp/寿元/魂任一归零；撤退在 Boss 台被拒（`retreat_forbidden`）。

**玩家四类行动** [FACT]：`play_gu`（七重门禁：蛊死/封印/本回合已用/真元质量/行动上限/念头/真元）、`basic_attack`（1 念头不耗真元，伤害=1+buffs，buff 只喂此通道）、`play_kill_move`（配方蛊全未封印→念头→真元→寿元，扣到 0 效果不执行直接陨落）、`end_turn`。

**伤害公式** [FACT]：全确定性无暴击无闪避随机。蛊 strike = amount + 同流派支援 + 剑道剑意加成；先吃 shield 剩余穿透；heal 钳制 max_hp；shift 已裁定转译为等量护盾（2026-09-12）。战斗回合膨胀：敌 HP +2/回合（上限+6）、伤 +1（上限+2）；Boss 层倍率 HP×1.5/伤×1.25。

**原创 vs 传统** [INFERRED]：
- 传统（STS 同构）：一次性格挡池、刻痕≈中毒（注释自认）、休息三选一、pity 保底、分层地图+Boss 门禁、契约≈开局遗物。
- 原创（世界规则推导）：真元质量门禁+下阶折价、念头行动制（行动次数=魂魄底蕴）、杀招化解+泄密、寿元支付与三轴死亡、节点内真元预算、洗髓换骨、恶名改变先手与物价。

# 16. 状态/Buff/Debuff 系统

| 传统概念 | 小说对应 | 当前实现 | 世界模型一致性 |
|---|---|---|---|
| 挡格 | 蛊防 | `shield` 一次性吸收池 | 低（功能同构 STS Block） |
| 中毒 | ⭐刻痕（剑道道痕自寻弱点） | `status: marked`，每层回合末 1 伤，上限 10 层，**不吃护盾不吃增益不衰减只伤敌** | 高（剑道落地规格），但数据上 marked 也给 recon 角色兜底用 [INFERRED：概念混用] |
| 缄默 | 封印 | `seal` 封蛊 1-3 回合（敌我共用），确定性选择 | 中高 |
| Buff | 蛊效加成 | `buffs {force, yi_zhang}` 仅喂 basic_attack | 低（通道狭窄是已知引擎事实 F4） |
| 灼烧 | 烧真元 | `essence_burn` 扣战斗真元 | 高（对真元模型的直接攻击） |
| 咒 | 蛊蚀/滞胀/封蛊 | curse.json 三种：污染抽取+1/层（拔除 6 石）、真元附加费（免费额度 2）、封槽 | 中高 |
| 虚弱/易伤 | — | [MISSING] 无减益乘区 | — |

引擎事实（2026-09-11 锁定）[FACT]：status 仅 marked/bound 且不参与伤害计算；buff 只进 basic_attack；显式 v1_effect 无转数自动放大。**判定**：状态体系刻意做薄（"status/buff 不表破防加伤"是守护条款），复杂度被推向杀招与蛊组合——这是设计取向不是缺陷，但当前可表达的状态空间确实窄。

# 17. 事件/NPC/社会关系

[FACT] events.json 事件带延迟代价（回声洞：HP-1 + 下次赶路魂-1；蛊腐契约：HP-1+延迟魂-1+诅咒）；contracts.json 6 种契约（血契打击+30% 敌意图+20%、守财、真元潮 HP上限-2、苦修、调试契约开局 1000 石）；reputation.json 恶名→物价/敌意/先手；npcs.json 5 NPC 带意志与库存；dialogue_templates.json 离线模板 + LLM 接口保留（永久搁置新开发）。

**判定 [INFERRED]**：信息差（clue 线索、counter_hidden 杀招保密、地图迷雾、NPC 意图公开但有反制隐藏）是当前"社会性"的主要载体；人情账/势力关系 [MISSING]，符合"不强行设计"的纪律。

# 18. 地图与 Roguelike 结构

[FACT] 5 大层 × 8-11 行 × 2-6 节点/行；首行 1-2 入口，末行强制 Boss；层间 Boss 门禁（未杀 Boss 无路可走）。E1 分类概率表（层1 战 82/休 5/未知 9/交易 4 → 层5 战 76/未知 13/交易 8）；E2 分类池抽取+行内去重+层保底；每两行强制休整（REST_ROW_STRIDE=2）；锚点（黑市/炼蛊/遗葬）按 mid/pre_boss/quarter 摆位；未知节点迷雾。E6 敌人按层 roll（Boss 永不入选普通节点）；E7 商店按层货架。首局 first_run.json 固定 13 节点教学链。

**世界模型重解释判定 [INFERRED]**：Shop/Elite/Boss 结构仍是 STS 骨架，但商店=黑市经济（通胀/流动性/以物易物/恶名定价）、Elite=强制代价精英、Boss=升仙前置门禁，均有规则层重解释；节点类型丰富度（17 类）远超普通 STS 套壳。局限：层与层之间只有难度曲线，没有"数月到数年修行阶段"的时间叙事 [DESIGN 目标，IMPLEMENTATION 浅]。

# 19. Meta Progression

[FACT] MetaProgress 11 字段：`gu_codex_ids / recipe_codex_ids / relic_codex_ids / inheritance_codex_ids / unlocked_content_ids / unlocked_random_outcomes / contracts_unlocked / journal_unlocked / hall_material_bonus_accrued(仅展示) / dda_state_adaptive_enabled / statistics{runs_started, runs_won, runs_risky, deaths}`。归因只从事件日志回放（`refinement_succeeded`→蛊方图鉴、`relic_gained`→遗物图鉴、结局→契约、route 白名单→手记）。新局 `global_codex_ids = meta.recipe_codex_ids + gu_codex_ids` 注入配方门禁。

**判定 [FACT+INFERRED]**：纯知识/图鉴型 Meta，零永久数值——完全符合红线"蛊方图鉴是唯一明确允许的跨局解锁"；不破坏"每局重建资源体系"。深度风险：Meta 只影响"能配什么"，不影响"世界如何反应"，跨局成长感较薄，这是取向而非缺陷。

# 20. 当前核心数值（汇总表）

| 类别 | 数值 |
|---|---|
| 玩家初始 | HP 80/80、寿元 60、魂 1(max4)、元石 12、丙等一转真元 20、小光蛊×1 |
| 真元上限 | 局外 10×资质×3^(转-1)；战斗 stage 10/30/60/100/150 ×资质 |
| 战斗回真元 | 每回合 ceil(max×35/30/25/18%)（甲/乙/丙/丁，v1_battle.json） |
| 行动点 | 魂底蕴 ≥10000:6 / ≥1000:5 / ≥100:4 / ≥10:3 / 否则 2；每行动耗 1 念头 |
| 基础攻击 | 伤害 1 + buffs，耗 1 念头，不耗真元 |
| 蛊价值 | r1-r5 = 3/5/8/12/20 元石；回购 0.5× |
| 晋升成本 | 1→2 转 6 石+兽骨1-2；2→3 转 10 石+兽骨 |
| 洗髓换骨 | 10 寿元+8 石，+1 资质档，每局 1 次 |
| 层预算 | 元石 12/16/22/28/35；商店加价 0/10/20/35/50%；货架 4→6 件 |
| 敌人 | HP 3-20（见附录 A）；回合膨胀 HP+2(≤6)/伤+1(≤2)；Boss 层 ×1.5/×1.25 |
| 杀招 | 26 条；威力手工配（最高 24 伤/7 真元/2 念头）；化解 tag 4 系 |
| 刻痕 | 每层回合末 1 伤，上限 10 层 |
| 保底 | pity 3；elite 蛊掉率 30% 强制 epic+强制代价 |
| 恶名 | 价格+10%/点(≤60%)、敌意+15%、先手-10%；洗白 10 寿元/-2 点 |
| 黑市兑换 | 寿 20→魂 1；魂 1→寿 10；气血 20→魂 1；魂 1→气血 10；气血 20→寿 10 |
| 元石→真元 | 每石 floor(5×(0.5+regen%/100))，乙等≈4 |
| 地图 | 5 层×8-11 行×2-6 节点；每 2 行强制休整；首局 13 节点 |
| 契约 | 上限 6；删卡/删烙印/拔诅咒各 2 次/局；卡容量 12/手牌 2 |

# 21. Godot 技术架构

[FACT] Autoload 仅 2 个（DialogueManager、AudioManager）——领域层零全局单例。四层结构：`scripts/core`（RNG/种子化）/`domain`（约 60 个规则文件）/`presentation`（screens 13 + widgets 15 + snapshots 13 + flow 8）/`scenes`（main.tscn + 13 屏 + 14 组件）。命令流：UI → `run_controller.submit_command`（905 行，四路分发）→ RunBattleFlow / RunTravelFlow / RunDialogueFlow / EncounterSessionResolver / `Resolver.apply`（273 行路由核，`_dispatch` 表约 55 种命令，四命令族模块单向 preload：social 955 行 / refine 828 行 / shop 448 行 / run_command 271 行）。快照：`run_snapshot_builder.for_screen`（885 行）只读投影，`state_version=event_log.size()` 过期拒绝。

[FACT] 存档：双 JSON（大厅档/Run 档）+ SAVE_VERSION 4（v3 大厅档迁移保留、v3 Run 档拒绝）+ 原子写（tmp→rename）+ 递归 XOR 校验和 + 事件日志连续性校验。随机：SeededRng（Lehmer LCG）+ seeded_roll 盐值混合（2026-09-10 修正等差阶梯缺陷）；表现层纯装饰随机豁免（W14）。

**稳定架构 vs 债务** [FACT]：稳定=领域纯函数化（battle 是 Dictionary，动作 `duplicate` 写回）、数据驱动（调参数值全落 JSON+Schema 校验）、契约回写纪律。债务=run_controller 905 行未达 <900 目标、run_snapshot_builder 885 行、`current_battle`/`current_session` 镜像字段、vendor/godot-open-rpg 未审计不耦合、PoolManager 仅是规划名词未实现（池逻辑分散在 EnemyCatalog/shop_stock/loot pity）。

**高重构成本点 [INFERRED]**：① `gu.json` 802 只的 role 兜底表若改为逐蛊显式效果，是数据工程级变更；② 事件日志 schema 是存档校验+Meta 归因+结局归因三方的共同依赖，改动波及面最大；③ `.tscn` 转换骨架与 widgets 双源（.guitkx/.gd）在迁移完成前仍是双向耦合。

# 22. Agent 协作架构

[FACT] `docs/contracts/2026-09-12-agent-ownership-contract.md`（用户批准，硬门槛，因历史并行会话曾 4 次物理删除文件而立）：四角色写区——**Logic**（scripts/domain+data+领域单测，禁入 presentation/scenes）、**Visual**（scenes+screens+widgets，禁入 domain、禁写 state）、**Test**（tests+tools，生产代码只读）、**Astra**（跨界终审）；Shared 单写者区 7 项（run_controller / run_snapshot_builder+snapshots / resolver / run_state / save_repository / docs/contracts / project.godot+main.tscn），修改走 5 步协议（声明文件→对应任务→影响面→指定测试→单独 commit），违反 1-3 一律回退。Git 纪律：禁 stash/reset --hard（.git 五次损坏史）；worktree 用于大型重构，验收后合并 master。

[FACT] 验收体系：`tools/test.ps1 -Suite unit|integration`（202 个测试文件）、`tools/check.ps1`（构建+全测+启动探针+契约漂移守门）、`verify_interaction_loop.gd`（13 屏+大厅 4 子视图，dead/no_ui_click/occluded 三键全空才可交付，约 4.5 分钟）、约 30 个 `verify_*.gd` 逐特性渲染验证（含像素/色彩分布级白屏检测）。

**判定 [FACT]**：协作规范已经稳定且被契约强制；视觉层/逻辑层隔离真实存在（domain 无 UI 依赖、UI 只读快照只提交命令）。残余风险：多 agent 并发命中 Shared 区时的等待协议靠人肉纪律；文档-代码存在轻微漂移（resolver 行数 205/261/273 三种说法并存）。

# 23. 已完成阶段总结

[FACT] 里程碑脉络（据 plans/specs 52+62 份文档索引与 AGENTS.md）：
- **2026-08-21~25**：南疆 smoke 设计 → 机制先行锁死规格（权威基线）→ P0 批次。
- **08-27~28**：最小 UI 重设计、文真主题视觉验收修复、升仙评价制裁定。
- **09-01~09**：蛊系统总规格批准 → spec-v4 十阶段 20 任务 → 事件-对话-战斗收敛 → 2026-08-30 用户裁定全量替换卡牌战斗为 v1 引擎 → 架构重构总计划 → L5 终 Boss 验收。
- **09-05~07**：随机合成杀招切片、D1b 古方知识模型、仓库卫生（数据驱动测试）。
- **09-09~10**：路线内容多样性批次（E1-E7 全落地）、4 需求视觉批次（线框+tscn 首批）、技术债原子任务、W11 resolver 拆分（2407→205 路由核）。
- **09-11**：交互门 13+4 屏扩容、剑道流派考据修正（推翻"剑意"旧判，改"残锋降转"）并落地批次 1/2/2b。
- **09-12**：Agent Ownership 契约落档、架构纠偏计划、shift-distance 规格与剑道 P2 规格。

# 24. 当前真正的设计资产

1. **真元质量门禁 + 下阶折价**（转数≠等级树，是资源质量轴）：小说规则→引擎的最硬实证；直接催生"低转蛊靠成本效率进高转构筑"的取舍空间。潜力：构筑深度的主轴。风险：754 只蛊效果同质化稀释它。
2. **杀招系统**（配方组合 + 手工威力 + 化解 tag + 泄密 revealed_to）：把"战斗招式"变成"知识资产与情报博弈"。潜力：可扩展为玩家自定义编排保存（规格 §4.2 [DESIGN 未实现]）。
3. **资质贯穿模型**：一档资质同时影响四个互不相连的系统（局外上限/战斗上限/回率/吸收率）+ 寿元换资质的洗髓，构成"天生差异可被代价扭转"的叙事闭环。
4. **三轴死亡 + 可支付生死资源**（hp/寿元/魂，寿元与魂是可主动透支的货币，付费不可致死红线 + 预检）：把《蛊真人》"代价真实"哲学落进结算引擎。
5. **节点内真元预算制**：真元不是全局蓝条而是"本节点资源"，配合元石电池，形成独特的跨节点资源节奏。
6. **图鉴型 Meta + 事件日志归因**：不可变事件日志同时服务存档校验、Meta 归因、结局归因、调试——单一机制四用，工程资产价值高。
7. **黑市资源兑换的不对称定价**（寿/魂/气血互兑 50 倍差价）：把"透支生命"直接定价，是经济系统里最有世界味的设计（尽管 [INFERRED] 未见比例来源文档）。
8. **按层伪随机 pacing 体系（E1-E7）**：确定性种子化 + 层预算 + 保底 + 强制休整步长，是可复现内容生成的完整范式。

# 25. 当前设计风险

1. **构筑表象 vs 战斗现实脱节**（最高风险）：802 蛊 × 20 流派的目录规模下，48 只显式效果 + 754 只 role 兜底（attack 全是 strike 2+rank-1）——玩家在商店/掉落里看到的差异化标签，进战斗后大多是同一条数值曲线。目录资产的多样性尚未兑换成玩法多样性。
2. **晋升经济单一**：378/385 配方吃兽骨（参考价 5），晋升≈刷兽骨+攒 6/10 石，蛊材体系 7 种中 5 种边缘化。
3. **终局挑战曲线倒挂**：终点 Boss（rank3/HP14）弱于 3/4 层层主，两个 rank5 boss 未编入层主位——五层攀登的终局爽点缺位。
4. **寿元死亡轴休眠**：现网杀招/蛊 life_cost 数据全 0，寿元只在洗髓/洗白/黑市/敌方意图中消耗——三轴死亡实际接近两轴半。
5. **养蛊半成品**：规格 §2.1 的实例生命周期（饥饿/忠主/凶性/逃遁/保存）只落在 16 只核心蛊的字段上，无主循环压力；"持有软上限"因此实际接近无上限。
6. **文档-代码漂移累积**：resolver 行数三个版本并存、SAVE_VERSION 记忆残留 v3、PoolManager 规划名实不符——对多 Agent 协作是慢性毒药。
7. **已知技术债**：ObjectDB/RID 泄漏（复测仍复现）、Dialogue Manager invalid UID、run_controller 905 行。

# 26. 疑似设计偏移

| 问题 | 当前表现 | 为何偏离核心 | 严重度 |
|---|---|---|---|
| 蛊虫效果同质化 | 754/802 蛊进战斗=role 兜底数值；流派差异只剩 support_bonus 与剑道特例 | 违背纪律 4"自由组合的复杂性来自统一数据语法"——语法在，内容没跟上 | **高** |
| 战斗骨架 STS 同构度高 | shield/中毒/休息三选一/pity/契约遗物位 | 本身不是罪（骨架可复用），但状态体系刻意做薄后，"传统感"上升 | 中 |
| regen_pct 双表冲突 | aptitude.json 40/30/20/10（局外吸收率）vs v1_battle.json 35/30/25/18（战斗回率） | 同名常量两套值，资质叙事出现裂缝；乙等恰好重合掩盖了问题 | 中 |
| 黑市兑换率 50 倍不对称 | 寿→魂 20:1 vs 魂→寿 1:10 | 可能是故意单向阀门，但无文档裁定记录，且气血 20:10 与寿元 20:10 一致性未说明 | 中 |
| 杀招威力手工配置 | 26 条杀招逐条手写 amount，违背纪律 7"中央参数导出" | 内容量增长时平衡成本平方级上升 | 中 |
| 卡片化术语残留 | deck.json"牌库容量 12/手牌 2"、删卡 120 石 | 红线说"卡牌只是操作界面"，"手牌/牌库"词汇可能反向侵蚀概念（需确认实际语义是编组容量而非抽牌） | 低-中 |
| 最终 Boss 倒挂 | 见 §25.3 | 5 层结构的高潮缺失 | 中-高 |

# 27. 当前最值得保护的设计

- v1 战斗引擎的**纯函数性**（battle=Dictionary，动作 duplicate 写回）——一切回归测试与种子化的地基；
- 转数门禁 `can_activate` + `2^n` 折价的语义（改它=改世界观）；
- 事件日志不可变 + `state_version` 过期拒绝（改它=同时破坏存档/Meta/归因）；
- 预检红线（付费不可致死、静默致死禁令）——这是用户裁定的产品底线；
- Meta 零数值成长原则（图鉴唯一跨局解锁）；
- 蛊实例/定义分离与 transaction_ledger 同步纪律。

# 28. 当前尚未解决的核心问题

1. [FACT] ObjectDB/RID 泄漏（2026-09-06 复测 20601 实例仍复现）——长期运行稳定性。
2. [FACT] run_controller 905 行 > 900 目标；snapshot builder 885 行巨石（纠偏计划已立）。
3. [FACT] Dialogue Manager invalid UID 遗留。
4. [FACT] 真窗键鼠全流程验收未做（S 阶段）。
5. [INFERRED] 兽骨单一经济与掉落蛊渠道偏窄的"构筑节奏"问题：规格要求"每 2-3 节点一次构筑机会"，当前兑现依赖晋升配方池，多样性不足。
6. [INFERRED] 效果表达层升级路线未定：v1_effect 8 种 kind 是否扩容、如何与 802 目录对齐，是下一阶段最大设计决策。
7. [MISSING] 玩家自定义杀招编排保存（规格 §4.2）、NPC 深交涉、养蛊压力、时间叙事——均为已设计未实现层，需外部审阅者排优先级。

# 29. 下一阶段原计划

[FACT] AGENTS.md 当前待办：① 交互门全屏回归常态化（17 审计标签，dead/no_ui_click/occluded 全空）；② 真窗键鼠验收（S 阶段全流程）；③ 最终 `test.ps1 -Suite all` + `check.ps1` 全绿 + 泄漏调查；④ 剑道批次 3 的 P2 暂缓项（T15 刻痕扩展/T16）与 2026-09-12 架构纠偏计划（巨石拆分、镜像字段清理）。用户记忆侧：重点推进炼蛊+图鉴与 .tscn 迁移（已完成大半）。

# 30. 给外部架构审阅者的关键上下文

1. **判断"是否换皮"时**，去看四个实证点：`CultivatorRules.can_activate`（转数质量门禁）、`v1_battle.json` 杀招 `reveals/revealed_to`（泄密）、`aptitude.json` 四系数贯穿、`lifespan` 支付预检链。它们是小说规则→引擎的硬证据；其余骨架（地图/挡格/保底）承认是 STS 同构，项目自己也这么标注。
2. **判断"构筑深度"时**，核心矛盾是：数据层 802×20 的目录规模 vs 战斗层 48 只显式效果。任何下一阶段建议都必须回答"如何把目录多样性兑换成战斗多样性"且不破坏纯函数引擎与行为保持红线（显式化前后逐只伤害相同）。
3. **判断"经济自洽"时**，用 §20 汇总表验算：蛊价值锚 3/5/8/12/20 vs 晋升成本 6/10+兽骨 vs 层预算 12→35 vs 黑市通胀 0→50%——晋升线便宜、买蛊线贵、 elite 强制 epic+强制代价是三个主要阀门；兽骨单点依赖和兑换率不对称是两个待裁定的缺口。
4. **项目纪律强于常规**：TDD red-green、行为保持红线、预检红线、契约回写、Agent 所有权 5 步协议。审阅建议若与这些红线冲突，需要先论证红线本身，否则建议无效。
5. **文档权威顺序**：2026-09-01 总规格（蛊/经济/战斗）> 2026-08-25 锁死规格（其余）> 契约三件套 > plans。冲突取更具体、更新者。注意文档-代码漂移点：resolver 行数、SAVE_VERSION、PoolManager。

---

## 附录 A：敌人全表（32 条）

| id | 主题 | tier | 转 | HP | 意图 | 反制 |
|---|---|---|---|---|---|---|
| straw_puppet | neutral | common | 0 | 3 | 挥击 1/0 | bound |
| mountain_hunter | neutral | common | 0 | 3 | 木棍 1/1 | guarded |
| white_fur_jiangshi | anomaly | common | 0 | 3 | 一扑 2/0 | guarded |
| ridge_hound | beast | common | 1 | 3 | 扑咬 2/0 | guarded |
| fat_sand_scorpion | neutral | common | 1 | 3 | 虚张 1/0 | guarded |
| neutral_stone_wanderer | neutral | common | 1 | 4 | 掌势 2/1 | bound |
| beast_swarm | beast | common | 1 | 4 | 蜂群 2/1 | — |
| mountain_boar | beast | common | 0 | 4 | 直撞 2/1 | bound |
| iron_crown_eagle | beast | common | 2 | 4 | 鹰羽 2/3 | bound |
| clan_warden | faction | common | 1 | 4 | 横挡 2/1 | bound |
| ridge_elite_scout | faction | elite | 2 | 6 | 弩箭 3/3 | bound |
| faction_guard | faction | elite | 2 | 6 | 盾撞 3/3 | — |
| school_elder | faction | elite | 2 | 6 | 禁令 seal2 | guarded |
| rogue_cultivator | cultivator | common | 2 | 5 | 野路 2/2 | bound |
| black_fur_jiangshi | anomaly | common | 2 | 5 | 尸群 2/1 | bound |
| iron_hide_boar | beast | common | 2 | 5 | 獠牙 2/1 | bound |
| thunder_crown_wolf | beast | elite | 3 | 7 | 雷咬 3/3 | sparked |
| venom_whisker_wolf_king | beast | elite | 3 | 7 | 包抄 3/2 | guarded |
| demon_path_adept | cultivator | elite | 3 | 7 | 噬魂 soul_drain1 | guarded |
| sand_lurker_spider | beast | elite | 3 | 8 | 缚足 seal1 | guarded |
| roaming_jiangshi | anomaly | elite | 3 | 8 | 扑噬 3/1 | guarded |
| marrow_gu_adept | cultivator | **boss** | 4 | 16 | 骨矛 3/2 + P2 | guarded（L2 层主） |
| blood_forest_wolf | beast | elite | 4 | 11 | 碾压 4/0 | bound |
| clan_elder | faction | elite | 4 | 9 | 权柄 3/2 | guarded |
| slave_path_adept | cultivator | elite | 4 | 9 | 扑击 3/1 | bound |
| crag_serpent_matriarch | beast | **boss** | 4 | 15 | 绞杀 3/1 | —（L1 层主） |
| dragon_eagle | beast | elite | 5 | 10 | 俯击 4/3 | guarded |
| thunder_crown_sovereign | beast | **boss** | 5 | 18 | 雷贯 4/2 cd1 + P2 | —（L3 层主） |
| blood_vein_bishop | cultivator | **boss** | 5 | 20 | 血鞭 4/3 cd1 + P2 | guarded（L4 层主） |
| blue_fur_jiangshi | anomaly | **boss** | 5 | 20 | 尸潮 4/2 cd1 + P2 | guarded（未编入层主位） |
| clan_patriarch | faction | **boss** | 5 | 19 | 族威 4/2 cd1 + P2 | guarded（未编入层主位） |
| miasma_vein_lord | anomaly | **boss** | 3 | 14 | 瘴气 2/1 cd2 + P2(essence_burn) | guarded（**final_boss_stand 终点**） |

## 附录 B：商店 offer 标价全表（33 条）

购蛊：石壳蛊 6 / 月光蛊 6 / 雷御蛊 9 / 小光蛊 12 / 玉皮蛊 30 / 白猪力蛊 35 / 月影蛊 40；材料：月蓝花瓣 3 / mending_grass 8 / 野猪王牙 10 / bone_knit 14 / life_root 20 / undying_vine 20 / spring_heart 18 / 月华露 80；解锁：白玉配方 60 / 古方 80×3（月华/白玉/blood_heal_2_23）/ 200×2（blood_atk_3_03/3_11）/ 传承信物 60；剑道系列 8/18/30/45/70（r1→r5）；服务：魂丹 6 石+1 魂 / 洗恶名 10 寿元-2 点 / 寿元交易 / 以蛊换蛊（小光蛊+月光蛊→qi_mov_1_07_gu）；黑市资源：寿 20→魂 1、魂 1→寿 10、气血 20→魂 1、魂 1→气血 10、气血 20→寿 10；商队报价：力道蛊 5 石、血滴蛊 6 石、石壳蛊 5 石。

## 附录 C：配方经济全貌

392 条 = advance 377（1→2 转 6 石 ×220、2→3 转 10 石 ×157）+ fixed 14（含月芒方=月光蛊+小光蛊×2，出处《蛊真人-clean.txt》17024-17155，失败代价小光蛊消亡）+ free_mix 1（min_inputs 2；结局 destroyed w5 / mutation_venom→血别蛊 w4 / explosion HP-2 魂-1 寿-1 w1；成功率 60% 基础每败 +10% ≤ +30%，盲合 -20% 得蛊蚀）。材料去重仅 5 种：兽骨 378 / 兽血 3 / 野猪王牙 2 / 月露 1 / 毒囊 1。
