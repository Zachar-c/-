# CURRENT_EFFECT_CAPABILITY_MATRIX.md — Q8 第一阶段：当前效果能力地图

> 日期：2026-09-12。任务：Q8 世界模型兑现阶段第一步。
> 方法：纯审计，不写新代码、不扩展内容。全部结论标注 [FACT]（代码/数据核实）或 [INFERRED]。
> 核实文件：`scripts/domain/v1_battle_resolver.gd`、`data/gu.json`、`data/v1_battle.json`、`data/enemies.json`、`scripts/domain/content_catalog.gd`。

---

## 0. 审计范围

| 对象 | 现状 [FACT] |
|---|---|
| `v1_effect`（gu.json 显式效果） | **48 只**：strike 21 / heal 10 / shield 6 / shift 5 / sword_intent 5 / heal_and_strike 1。**status 显式 0 只** |
| `default_effect_by_role`（v1_battle.json） | attack=strike2 / defense=shield3 / healing=heal2 / movement=shift1 / recon=status marked1+support(self,1) / logistics=heal1。覆盖其余 **754 只** |
| `effect.kind` 引擎分支（`_apply_effect` L385-439） | 8 种：strike / shield / buff / heal / heal_and_strike / status / shift / sword_intent |
| `support_school` 子键 | 任意 kind 可叠加；"self" 哨兵=本蛊流派；现网 5 只显式 + recon 兜底全员 |
| `status` | 敌人 `statuses` 字典自由 name；目录白名单 `V1_STATUS_IDS=["marked","bound"]`；**引擎只消费 marked（刻痕结算），bound 无任何战斗实现** |
| `buffs` | `player.buffs{name:amount}`；唯一消费者 = basic_attack（force / yi_zhang） |
| `reactions`（enemies.json） | 敌人受击后把 counter_tag 塞入 `counter_hidden`；与杀招 tag 化解联动 |
| `kill_move`（v1_battle.json 26 条） | `effect`（走 `_apply_effect` 单次）+ `damage`（直调 `_strike_enemy`）双字段；化解 tag 4 系（sword/light/blood/force）；泄密 `revealed_to` |
| `durability_mode` | 引擎支持 **3 模式**：`CONSUME_ON_USE`（用后消耗）/ `TRIGGER_COST`（受击触发：扣 trigger_qi_cost 换 trigger_block 回 HP，真元不足关闭）/ `PER_TURN_MAINTAIN`（每回合维持扣费，不足**全部关闭**）。**现网 gu.json 无一只设置此字段（全部默认 ""）** |
| 成本字段 | `true_qi_cost`（默认1）/ `thought_cost`（默认1）/ `life_cost`（**现网全 0**）/ `essence_cost`（跨节点催蛊，默认 v1_battle 默认值1）/ `feeding_cost`（仅 16 只核心蛊，战斗外） |
| v1_battle.json 顶层 12 键 | aptitude_mult / default_effect_by_role / regen_pct / stage_base / boss_layer_mult / thought_cost_default / true_qi_cost_default / fight_damage_base / max_seal_turns / mark_scratch_per_layer(1) / mark_scratch_cap(10) / kill_moves |

## 1. 十七项能力总表

| 能力 | 当前是否支持 | 当前实现方式 | 是否可组合 | 是否有特殊 case | 问题 |
|---|---|---|---|---|---|
| 直接伤害 | ✅ | kind=strike；`amount + turn_supports[school] + 剑意(仅 sword)`；先吃敌 shield 再扣 hp | 部分：吃流派支援与剑意 | aoe 子键仅 1 只测试蛊；sword 流派硬特判 L397 | 显式 amount 无转数放大（手写 1-6）；无条件修正 |
| 治疗 | ✅ | kind=heal；`min(max_hp, hp+amount)`；heal_and_strike 复合 | ❌ 不吃支援不吃剑意 | heal_and_strike 1 只 | 无战斗外携带治疗通道占构筑的落地压力 |
| 护盾 | ✅ | kind=shield 累加 `player.shield`；一次性格挡池 | ❌ | shift 转译共享同字段 | 敌方 shield 字段恒 0（预留未启用） |
| 位移 | ⚠️ 名义 | kind=shift（5 显式 amount=1 + movement 兜底）；**2026-09-12 Q8 裁定：一律转译为等量护盾** | ❌ | 转译逻辑是补丁 | 语义空洞：位移≠护盾的世界模型解释缺失 |
| 封蛊（玩家→敌） | ❌ | 玩家侧无通道；`_seal_random_gu` 只有敌人意图用 | — | — | 世界模型重要手段（封锁敌蛊）缺位 |
| 烧真元（玩家→敌） | ❌ | 敌人无 true_qi 字段；essence_burn 是敌方意图烧玩家 | — | boss P2 专用意图 | 不对称：敌能烧我，我不能烧敌 |
| 魂魄影响（战斗内） | ❌ | soul_drain 仅敌方意图；玩家无通道 | — | — | 三轴死亡之一的攻防交互完全单向 |
| 寿元影响 | ⚠️ 通道在/数据休眠 | `life_cost` 走 `_spend_costs` 有预检（扣到≤0 不执行陨落）；杀招同；现网数据全 0 | — | 敌方 life_cost 意图存在 | "用未来换现在"零实例 |
| 资源获得（战斗内） | ❌ | 无 modify_essence/modify_stones 通道；真元仅回合开始 regen | — | — | 战斗内资源引擎缺位 |
| 资源消耗 | ✅ | true_qi_cost + thought_cost + life_cost 三字段；TRIGGER_COST 真元换 HP | — | — | 无石/材料/蛊死通道 |
| 条件触发 | ⚠️ 仅一种 | TRIGGER_COST 受击触发（单次攻击事件至多 1 次） | ❌ | — | 无"敌意图时/血量阈值/击杀时/回合数"触发 |
| 延迟效果 | ❌ 战斗内 | 事件层有 `delayed_soul_cost`（travel 结算）；战斗内无 create_delayed | — | — | TRIGGER/MAINTAIN 是持续不是延迟 |
| 反应敌人意图 | ❌ | 意图公开可见（UI 投影）但玩家不可修改/取消/抢先/招架 | — | — | 情报（clue）与意图数据齐备但无玩法交互 |
| 读取前置状态 | ⚠️ 仅两条 | strike 读 turn_supports（本回合）+ sword_intent（跨回合层数） | ✅ 这两条 | sword 流派特判 | 无 hp/enemy 数/意图/回合数读取 |
| 设置标签 | ⚠️ 单向 | status kind 可给敌人 `statuses[name]+=amount`；实际仅 marked 有结算 | — | bound 白名单内但引擎不消费 | 标签系统名存实虚 |
| 消耗标签 | ⚠️ 反向 | 敌 counter_hidden 消耗玩家杀招（效果无效资源照扣→revealed）；玩家不能消费自己的标签 | — | — | 化解是"敌标签吃我招"，无反向设计 |
| 组合效果 | ⚠️ 窄 | heal_and_strike 1 只；support_school 任意 kind 叠加；杀招=配方蛊组合；aoe 1 只 | 部分 | — | 组合维度：真元/念头串联→支援增益→杀招，仅 3 条 |

## 2. 效果结算的确定性保证 [FACT]

全引擎无随机数：封蛊选择 = `turn % 候选数`；意图执行按 enemies 数组顺序；先手按恶名用种子化 roll 在战斗开始时定死。效果导致的死亡即时结算（hp/life_time/soul ≤0 → alive=false / cause 死亡）。`_log()` 全量落 battle.log，快照单向投影。

## 3. 现网 48 显式效果的量纲分布 [FACT]

| kind | amount 值域 | 说明 |
|---|---|---|
| strike (21) | 1,2,3,4,5,6 + 999(测试蛊) | 手写，无 rank 函数 |
| heal (10) | 1,2,5 | |
| shield (6) | 3,5 | |
| shift (5) | 1 | 全部=转译护盾 1 |
| sword_intent (5) | 1,2 | 叠层不消费，回合末减半，仅剑道 strike 消费，上限 5 |
| heal_and_strike (1) | heal 1 / amount 1 | 唯一复合 |
| support_bonus | 5 只 | "self" 哨兵 3 只（默认注入）+ 指定流派 2 只 |
| aoe | 1 只 | 测试蛊 strike 999 |
| status | **0 只显式** | marked 全部来自 recon 兜底 |

## 4. 兜底通道（754 只的现实数值面）[FACT]

attack 全员 strike 2 / defense 全员 shield 3 / healing 全员 heal 2 / movement 全员 shift 1（=护盾1）/ logistics 全员 heal 1 / recon 全员 marked 1 + 自流派支援 1。**转数放大仅作用于此表**：strike/shield/heal 三种 kind 执行 `amount = base + (rank-1)`。即：一只 5 转 attack 蛊与一只 1 转 attack 蛊的差异 = strike 6 vs strike 2，以及价值 20 vs 3。

## 5. 缺口清单（→ GU_EFFECT_GRAMMAR_V2.md 的推导输入）

按"表达力 vs 组合性 vs 现实需求"排序：

1. **G1 条件/触发轴缺失**：只有受击触发一种。无血量阈值、敌意图反应、回合数、击杀触发。
2. **G2 延迟效果缺失**：战斗内无 create_delayed；事件层已有先例（delayed_soul_cost）可对齐语义。
3. **G3 标签系统半成品**：statuses 写入自由但只有 marked 结算；bound 白名单无实现；无玩家侧 add/consume tag 语义。
4. **G4 敌侧资源面空白**：敌人无 true_qi/soul/lifespan 字段——三轴死亡的攻防交互单向。
5. **G5 寿元通道休眠**：life_cost 机制完备（含预检与陨落），数据 0 实例。
6. **G6 durability 三模式零使用**：引擎已实现 CONSUME_ON_USE/TRIGGER_COST/PER_TURN_MAINTAIN，无一只蛊配置——现成的表达力未被内容利用。
7. **G7 读取状态面过窄**：仅 turn_supports + sword_intent。
8. **G8 反意图交互缺失**：情报/clue 数据已存在（enemies.json clues、意图公开）但无玩法接口。
9. **G9 组合通道单薄**：仅支援增益/杀招/aoe 三条。
10. **G10 shift 语义空洞**：转译护盾是裁定结果，但世界模型解释待补（位移→身法卸力？）。

## 6. 约束确认（重构时不得破坏）[FACT]

转数门禁 `can_activate` 与 `2^n` 下阶折价；资质四档贯穿（含 v1_battle regen_pct）；念头行动体系（行动次数=魂魄分档）；寿元预检与不可静默致死；纯函数引擎（battle Dictionary + duplicate 写回）；SeededRNG；事件日志 append-only；snapshot 单向投影（UI 不回写）；无抽牌/手牌/弃牌堆。
