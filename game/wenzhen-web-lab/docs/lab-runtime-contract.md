# lab Runtime Contract（Web 本地接口契约）

> 范围：`game/wenzhen-web-lab/lab.html` 普通脚本运行时。  
> 不重写 Godot 契约；不新增游戏模型。权威链仍以根 PRD / AI 协议 / CONSTRAINTS-V2 为准。

## 1. 脚本装载顺序（`lab.html`，禁改序不报备）

```text
js/data.js          ← build_data.mjs 生成，唯一内容桥
js/balance.js       ← WORLD_BALANCE 报警器
js/run_rules.js
js/run_flow.js
js/gu_rules.js
js/loot_rules.js
js/shop_rules.js
js/node_action_rules.js
js/mvp_content.js   ← 短剧本/实验配方夹具
js/mvp_logic.js     ← 唯一战斗规则核
js/combat_core.js   ← MvpLogic 别名 + Lab 适配（禁止第二套结算）
js/audio.js
js/describe.js
js/rules.js
js/alchemy.js
js/killmove.js
js/battle.js        ← 战斗面板
js/journey.js       ← 大厅/地图/整备/奖励/结局面板
js/main.js          ← state / act / showPage / boot
```

W1 起：`js/lab_save.js` 插在 `main.js` **之前**（在 `journey.js` 之后）。  
Boot 成功信号：`document.documentElement.dataset.ready = '1'`。超时 1200ms 未置位则 `#bootfail`。  
只读测试探针：`globalThis.__labSnapshot()` / `globalThis.__labBootInfo()`（禁止用来改状态或调 `act`）。

## 2. 全局状态

### 2.1 `READY`（开局模板，非可变局）

见 `docs/2026-09-22-playable-game-current-state.md`。`fresh(difficulty)` 展开为可序列化 `state`。

### 2.2 `state`（唯一局内真相）

| 键 | 含义 | 序列化 |
| --- | --- | --- |
| `seed` | 本局种子 | 是（W1 起由新局生成一次） |
| `cultivation` / `cultivationStage` / `aptitude` / `stage` | 修为与资质 | 是 |
| `stones` `blood` `bloodMax` `lifeTime` `soul` `soulMax` | 资源 | 是 |
| `qi` `qiMax` `thought` `thoughtMax` | 真元 / 念头 | 是 |
| `owned` `wild` `equipped` `materials` | 库存 | 是 |
| `journey` | `{difficulty, graph:{roots,nodes[]}, nodeId, availableNodeIds, completed, started}`；nodes 为数组 | 是 |
| `battle` | 遭遇（含 enemies/intent/counter/revealed/封印/冷却/延迟效果） | 是 |
| `prepFor` `reward` `shopSold` `restUsed` | 流程旗标 | 是 |
| `lootPity` `materialPityByTier` | 保底 | 是 |
| `globalCodexIds` `knownFacts` | 情报 | 是 |
| `journal` `eventLog` | 文本日志 / 不可变事件 | 是 |
| `page` | 当前视图 | 是 |
| `ending` | 终局摘要 `{title, detail, turn, outcome: 'victory'\|'defeat'}`；`outcome` 只能由真实终局转移写入，不得由打开页面产生 | 是 |

**不入库**：临时动画、音频对象、DOM 引用、toast 计时器。

### 2.3 `READY.seed` 禁覆盖

W1 后：已选择/已存档种子优先；`READY.seed` 不得覆盖。`?seed=` 只影响**明确的新局**。

## 3. 命令面 `act`（Web 状态唯一写入口）

面板只调用 `act.*`；禁止 UI 直改 `state`，禁止测试/驱动 `page.evaluate` 写 `state` 或调 `act` 冒充玩家。

| 分组 | 方法 |
| --- | --- |
| 局生命周期 | `startRun(difficulty)` `restartRun(difficulty)` `endJourney(title, outcome)` `completeCurrentNode(reason)` `advanceJourney(reason)` |
| 地图/节点 | `chooseNode(nodeId)` `enterNodeAction()` `resolveNodeAction(choiceId)` `resolveRestAction(choiceId)` `leaveRest()` `leavePrep()` `openPrep()` |
| 战斗 | `startBattle(enemyIds, nodeId)` `_pickIntent(b, enemy)` `setTarget(id)` `basicAttack()` `exhaust()` `observe()` `useMove(id)` `useGu(instanceId)` `endTurn()` `endBattle()` |
| 成长/交易 | `attuneGu(definitionId)` `forge(recipeId)` `toggleMove(id)` `buyOffer(offerId)` `leaveShop()` `sellGu(guId)` `breakthrough(mode)` `useAptitudeGu()` |
| 奖励 | `openBattleOutcome()`（函数）`chooseRewardGu(guId)` `continueReward(discardGu = false)` |

规则 Owner（禁止“统一”成新引擎）：

| 域 | Owner |
| --- | --- |
| Rank 预算 / 跨转真元 | `game/data/balance.json` + `GuRules`/`RunRules` 消费；`balance.js` 只报警 |
| 蛊定义 / 效果 | `game/data/gu.json` + `GuRules` |
| 杀招结构 | `game/data/v1_battle.json` + `KillMove` + `GuRules.killMoveRecipeInstances` |
| 炼方 | `game/data/refinement_recipes.json` + `Alchemy`；C3 实验配方须带 `experimental_scenario_recipe` |
| 市价 / 店存 | `ShopRules` + `DATA.shop*`（桥自 `game/data`） |
| 掉落 / 保底 | `LootRules` |
| 图生成 / 突破门 | `RunFlow.generateGraph` / `RunFlow.nextBreakthrough` |
| 战斗结算 / Counter / 逆息 / 越阶 | **`MvpLogic` via `CombatCore` 唯一** |

## 4. 页面与转移

`showPage(page)` 只切换视图，不隐式结算。页面：`hall | map | node-action | battle | prep | reward | cover | ending`。

允许转移（W2 收口后强制）：

- `hall` → `map`（开始/继续）；`map` → `node-action|battle|prep|reward`（`chooseNode`）
- 离开战斗页 = 视图切换，**保留 `state.battle`**；返回 `currentNodePage()` 或地图上的「返回当前战斗」
- `endBattle()`：未结算 = view-only（不清遭遇）；已结算 = `openBattleOutcome`；**禁止付费逃跑**
- `reward` 领完 → `prep`；`prep` → `map`（`leavePrep` → `completeCurrentNode`，未结算战斗不得跳关）
- 真实终局 → `ending`（含 `outcome`）：死亡/败局 `outcome:'defeat'`；节点完成且 `nextIds` 耗尽（含 L5B）`outcome:'victory'`
- `ending` → `hall`（终局摘要）或 `restartRun`（`fresh` 清上一局）
- 禁止：未开局领奖、战斗未结算跳关、结局后继续增强局内力量、空 graph/缺敌人伪造「行程已尽」胜利、重复结算奖励/节点完成

## 5. 存档边界（W1 起生效）

- 键：`wenzhen.lab.run.v1`；信封 `{schemaVersion:1, contentVersion, state}`
- API：`LabSave.encode/decode/write/read/clear`；storage 注入，纯单测用内存适配
- `contentVersion`：`build_data.mjs` 对 `JSON.stringify(out)`（写入字段前）做 `sha256`，写入 `out.contentVersion`
- 提交点：完整动作/结算后的统一边界（`act` 公开方法终止后 `commit()`）；**禁止** `recordEvent` 半笔中途保存、禁止每帧保存；`_pickIntent` 等内部方法不包装
- 坏档：保留原文不覆盖；UI「无法读取」+ 明确重新开局；不伪显示已保存
- 存储异常：不崩溃、不假称可续玩
- 种子：`fresh(difficulty, seed)`；`?seed=` 只影响明确的新局；继续优先存档 `state.seed`；`READY.seed` 禁止覆盖
- 放弃确认：新开局 / 修改进行中局难度 / 顶栏重开，进行中局必须先确认；取消不得改 state/seed/售罄/奖励/存档；已结束局可直接新局

## 6. 测试证据分级（与计划 §2 一致）

1. 规则单测 — 可 fixture，不证明玩家可得资源  
2. lab 集成 — 可装载受控局面，须标 fixture  
3. 正常整局 E2E — 空存档 + 可见控件 only  
4. 发行玩家验收 — 解压启动、断网、无仓库路径  

`autoplay.mjs` = 短剧本；`check_progression_loop.mjs` = fixture。二者不得顶替 3/4。

## 7. 明确禁止

- 第二套战斗/Rank/定价引擎；`battle2` 合并；vertical 进玩家链  
- 注资/改敌血/跳节点/替换 DATA/`applyForge` 冒充整局  
- 静默默认值吞掉经济警报；删断言；改阈值  
- 为“统一”替换已有战斗核  
- 自动 commit/push；`git reset --hard`  
- 改 Godot `.gd`（本阶段）

## 2026-10-03 主实现收敛与选择预览

唯一维护的可玩入口为 `lab.html`。坊市与奖励页用既有 `GuRules.gainInsight` 只读预览购入后的合炼缺件、成本和修为要求，不生成另一套构筑规则。`continueReward(true)` 明确放弃本次蛊虫，保留已到账资源，并记录 `loot_gu_declined`；默认调用不隐式丢弃未选奖励。

战斗 `turnSupports.guTargets[guId]` 保存定向支援。小光的 `target_gu_id: moonlight_gu`、`multiplier: 2`、`nonStacking: true` 仅增幅本回合下一次月光攻击，使用后消耗、回合切换清空；既有学校加值支援沿用原语义。原著依据是 Wiki 小光页 `E:V1-010940` 与 `E:V1-017148`，定向辅助付真元与念头、不单独占行动；按回合挂起支援是网页现有行动结构的适配，不宣称原著存在回合。


### 主链字段与行动门禁修复

完整 `DATA.gu` 定义在 `GU_BY_ID` 中优先于敌人补充语义；后者补充主表没有的敌方蛊与被动字段，不覆盖成本、价格、构筑角色或投影效果。拳脚不消耗真元/念头；念头为零仍可在有行动且未终局时出拳，观察依然要求一念头。小突破和大突破只改变修为与容量，保留现有真元（按新上限截断），不凭空授予旧上限的资源。

组合结算中的定向辅助先收集再解析主蛊，配方书写顺序不改变月光与小光的同催倍率；条件不成立的辅助不计入，且不改写调用者的挂起支援。杀招主界面已窄开放凝光实验同催，其他组合保持暂停（见后文）。


### 白豕永久力量与恢复反馈（2026-10-03）

白豕不再作为直接攻击或破甲技能。整备的 `act.trainBody` 通过既有 `HumanRules.trainBody` 写入 `modifierLedger`：`session_permanent`、`dependency=none`、`sourceEffectId=body_training`。战斗复制该账本，拳脚自动读取永久力量，不另耗真元/念头。卖出、失蛊或合炼不会移除该力量；同一定义所有实例共享上限与每次整备次数，重复点击不扣费。没有新增另一套成长或存档系统。

原著依据：白豕 Wiki `E:V1-010994/011000/012758`（耗元逐步增力）、`E:V1-015308`（已得力量无需耗元）、`E:V1-009692`（失蛊仍保留）、`E:V1-011066`（一猪上限）、`E:V1-018198`（同型不叠加）。公开实验参数：每个完成节点后的整备最多一次，真元1、补饲元石1、力量+1，同型累计上限+3；+3沿用现有力量投影预算，次数和数值不宣称为原著事实。若未来引入真实天数与饲养材料，应替换节点时间与元石补饲适配。

驱熊扑击按既有兽体伤害1结算，不把白豕的战前投资伪造为攻击组件；构建期对真实蛊攻击的合成校验仍保留。治疗文字显示气血，战后与战中反馈只报告实际补回量；满血不虚报恢复。


### 拳脚问题轴与可见决策（2026-10-03）

拳脚与蛊虫攻击共用现有 `GuRules.resolveProblemHit` 的重甲、闪避与信息结算；永久力量不隐含破甲或必中。保留既有拳脚的显式反击门禁，不新增旧反制触发。信息反噬使气血归零时，攻击即使同时击杀敌人，也应判败；拳脚、蛊虫、杀招与延迟效果均先检查败局再检查胜局。问题轴属于既有游戏适配，不宣称是原著中普遍存在的数值公式。

战斗按钮直接显示各蛊效果与费用；地图休整提示按当前资源可恢复的净气血/真元量。此展示消费既有数据与恢复函数，不改变效果、收益或数值。走盘记录补充每次操作的前后资源、库存、修为、敌方意图与新日志；固定脚本决策不等于用户趣味验收。


### 六蛊开局、跨流派发现与筹备（2026-10-03）

`READY.owned` 只含六只一转蛊各一只：月光、小光、玉皮、石皮、生机草、白豕；野生小光×2、其他资源与数值保持现有值。初始库存是试玩设定，不宣称原著蛊师统一携带六蛊。新局不携带旧机制演示的高转库存；旧存档继续使用其已持有物，不回收、不强制重开。

构建器输出全部现有流派池，但只保留 `DATA.gu` 的85个真实投影实体：84只进入14个池，资质蛊沿用特殊支持入口。`rollGuChoices` 的可选 `discoveryPool` 只补充额外候选，并校验实体存在与稀有度所在桶非空；概率判定、首选的原表/夺蛊、保底与不出蛊结果不改。主游戏把流派池传入发现列表，不再靠送出高转初始库存使跨道分支可达。转数继续是使用门槛，不伪装为稀有度；持有高转候选与当前可催用是不同选择。

整备的合炼筹备展示仅使用真实持有组件（共享 `countBy`）、既有配方成本和成品转数。炼蛊页说明组件被消耗、再次取得后可以尝试另一分支；不宣称元数据 `closes` 已实现永久路线封锁。投入锻体蛊保留已得力量，但无法继续用该实例锻体。

`hudNumFx` 先以正确ID选择器写入真实数值，再处理可选动效。原实现既漏了 `#`，也没有写入文本，使顶部停留HTML初值；新增无动效/首帧检查，以及浏览器锻体、续档后的六项资源文字与状态对照。此前只读取状态的走盘不能作为资源显示正确的证据。


### 玉皮与白玉的持续防护（2026-10-03）

依据 Wiki 玉皮、白玉 `E:V1-016070`：必须持续灌入真元，承击增加消耗。两蛊从一次性护盾改为现有 `HumanRules.maintainedGu` 与属性账本中的持续防御；启动后每个真实正伤害攻击另付承击费，余额不足则即时撤防、本击不再获该蛊防御。零伤害/蓄势不付承击费。封印立即解除；玩家可用“停止”按钮免费撤防，不占行动，续档保留活动状态与余额。敌我共用承击规则，防御在命中后结算。

公开试玩参数：玉皮启动真元1、防御3；白玉启动2、防御5；两者维持每回合1、每击2，同类皮甲形态不可叠加。既有回合回复仍在维持结算前进行，常规单次承击时每回合至少净耗真元1；这些绝对数值、时间步长与互斥均为授权实验参数，不宣称原著公式。战后回满等既有暂缓项仍未改动。石皮随后已接入石臂形态，详见后续石臂与收支复核节，不套用玉质防护耗元。

持续防护须单独催动；现有一次性杀招合成不能把它变成免费格挡。杀招门禁、替代候选与变体生成均排除该语义，直至组合生命周期有真实实现。


### 石臂形态、迟缓与防护收支复核（2026-10-03）

石皮 Wiki `E:V1-011888/011894/011900` 支持石臂变硬、沉重迟缓、命中有重量；不按承击另收费是Wiki的合理推导，持续时间与绝对数值未明确。本轮使用现有活动蛊账本：启动真元1/念头1、防御3、临时拳脚+1、拳脚晚1回合（敌先行动）结算，维持/承击0，形态直到停止、封印或战斗结束。同一皮甲形态互斥。以上量化、全战斗持存与互斥均为授权试玩裁定，不宣称原著公式或永久肉身强化。敌我共享 `basicStrikePlan`；玩家沿用现有延迟队列并固定原目标，原目标倒下则落空。蛊虫月刃不按石臂拳脚延迟。

战后奖励保留最多80条战斗日志，并提供“交锋回顾”，避免最后一击和对方先行动被结算页吞没。含持续蛊的旧“明光壁”一次性杀招暂不能催动，UI明确显示持续蛊须单独催动，构筑建议不再承诺该式；完整同催激活仍待实现，不能把石皮免费变回一次性格挡。

对普通seed7实际走盘复核发现：白玉原参数（维持1、承击1）与每回合回复2相抵，在念头耗尽、拳脚打不中闪避敌时产生无限互挡。现场快照骨枪马贼1/7HP、活动白玉，回合1744、日志12200条；不以回合递增或无异常证明进展。授权实验承击费现改为玉皮/白玉每击2，维持仍1、启动仍1/2、防御仍3/5；常规单击下每回合至少净耗真元1，续档承击费用缓存跟随现行定义。

走盘单独按资源、敌人HP/状态/标志和待结算效果的剩余时间判断战斗进展，连续40步不变则保存 `combat_stalled`，不再被回合号与日志增长欺骗。浏览器工具也清除已完成请求的超时计时器，使测试完成后及时退出；实际超时错误仍保留。玩家是否觉得新防护选择好玩，以及完整时间、命中、心念与喂养规则，仍待后续验收。


### 普通催蛊的每回合操控余量（2026-10-03）

原著“心念一动”是发出催动指令，不能据此建立所有普通蛊共享的整场可耗尽念头库存。月芒 Wiki `E:V1-020174` 的连续催动受真元限制；实体念头生产和消耗属于特定智道机制，参见 [智道星念证据](../../../lore/wiki/gu/light-rec-5-12-gu.md) `E:V4-148976/149048/149438`。多蛊并催的分心有 [一心多用证据](../../../lore/wiki/gu/force-atk-4-27-gu.md) `E:V2-053000/059386`，但不存在原著统一操控上限3或回合刷新公式。

现有字段 `thought/thoughtMax` 保留用于数据和存档兼容，玩家界面改称“操控”。敌我共用 `HumanRules.controlCapacity/refreshControl`：当前上限减去真实持有且未封印的活动蛊 `focusCost`，在下一真实回合、回复与维持扣费后重置可用余量。玉皮/白玉持续灌元各占1；石臂成形后占0。绝对容量、每次催动消耗、回合量化与上述占用均为授权试玩参数，不写成原著事实。魂魄基准1与行动上限1、真元成本/回复及战后回满不变。

小光准备仍消耗本回合操控而不占行动；免费撤防、观察、刷新续档不触发余量重置。撤防在下一真实回合释放占用。活动态缓存的占用在回合刷新时跟随当前蛊定义，旧存档不保留过时占用。显示当前余量及持续占用，拒绝催动时提示“本回合操控余量不足”。此适配解决普通蛊整场三次的错误限制，不代表完整注意力、时间或智道系统已经完成。


### 九叶生机草与消耗型生机叶（2026-10-03）

依据 [九叶生机草 Wiki](../../../lore/wiki/gu/vitality-grass-gu.md)：本体二转（`E:V1-016490`），每片叶取下是一转生机叶、用后消失（`016494/016496`），疗伤后一小时内其他叶无效（`016498`）；灌真元催生且需要时间（`017106/017114`）。方源两成真元每叶与半天九叶是个案，不推广为全体公式。

现有 `vitality_grass_gu` 改为二转木道生产蛊，战斗投影为空；新增 `vitality_leaf_gu` 是一转木道消耗治疗蛊。生产由原有整备蛊仓入口与 `GuRules.produceGu` 结算，本体保留，产物进入同一 `owned` 库存；战斗和整备疗伤共用 `consumeHealingGu/consumeLeaf`，实际扣一只叶并只恢复净缺血量。满血、无库存和间隔未到均不扣资源。没有新材料仓、配方引擎或原型。原有杀招合成不支持产叶/消耗生命周期，门禁、计划、变体与建议不以它们模拟免费治疗。

公开实验参数：草每节点整备一次、真元2产叶1；叶治疗3气血，每节点仅一次有效疗伤。草/叶挂牌10/3元石，沿用层价和回收价规则；价格不是原著50元石的照搬。`leafProductionVisit` 与 `leafRecoveryNodeId` 随既有存档保存，不因刷新或返回蛊仓解除。节点时间折算不同于已实现真实一小时，九片在株叶、真实日程、产能与修行时间争用尚未实现。

新局以两片叶替换原来的一转治疗草，其余开局资源不变。旧存档不回收草或赠送叶，持草者按现行二转门槛生产。14流派池归档改为木道；当前投影86实体，85只进入发现池，另有特殊资质蛊。实体数不意味着原著机制逐只完成。


### 月芒主攻与月系配方边界（2026-10-03）

[月芒 Wiki](../../../lore/wiki/gu/moon-glow-gu.md) `E:V1-015710/017148/017150/017154` 明示月光1＋小光2合炼、攻击三倍、射程不增；没有信息压制或必中属性。既有月芒投影由 Support＋信息压制改为 Core＋主攻，伤害9（基础月光3）、真元4、炼制10元石。绝对伤害、真元与元石均为公开试玩参数；稳定命中沿用当前月刃问题轴的适配，不宣称原著必中。月芒不会继承小光对基础月光的定向支援倍率。

`moonlight_glow` 恢复月光1＋小光2的真实投入，消费原有 `countBy` 与 `act.forge`，缺一小光或缺钱不可开炉。移除虚构的信息/爆发分叉、材料钥匙与永久关闭路线元数据；`moon_glow_fixed` 只保留重复配方历史。旧 `moon_ray_forged` 小光配方明确退役：[月痕](../../../lore/wiki/gu/moon-ray-gu.md)原著需要痕石。月痕实体当前仍有通用攻击占位，其射程语义未落实；月旋曲线弹道也未落实，不能作为已实现原著分支验收。

内部 `kit_info_suppress` ID 暂为兼容保留，展示语义改为“月芒高耗爆发”，只要求月芒，玉皮/叶片作为可选辅助；行动结构为观察、爆发、回元，不能在建议中伪造 suppress 能力。该描述只服务既有构筑洞察，不新增战斗执行引擎。

整局走盘新增 `--policy moon`：从正常开局炼化小光、留钱合炼、突破二转，优先主攻月芒并使用可见防护和疗伤按钮，跳过白豕锻体；当前生存策略继续白豕与白玉投资。两个脚本消费同一主游戏，未注入状态。不同买卖、休整和支出决策使终局元石不宜作纯平衡对照；战后回满暂缓边界不变。

## 后期敌池与威胁验证（2026-10-03）

沿用24名敌人的源属性，不按修为虚增肉身气血。首段单敌使用原common池；第二段单敌为二至三转common/elite，第三至第五段为三转common/elite；双敌仅从对应范围elite抽取。层主顺序为miasma_vein_lord、crag_serpent_matriarch、marrow_gu_adept、thunder_crown_sovereign、blood_vein_bishop，修为3/4/4/5/5。缺少合规敌池时生成报错。当前没有四/五转常规敌，不以rankCap配置冒充已实现内容。

地图展示单敌/双敌交锋；收益仍按实际敌人tier结算，因此后期单敌含elite也可能有精英收益，经济平衡尚未完成。自动试玩只按可见抽魂意图改选目标，并可调用已持有月芒应对一拳无法击杀的致命抽魂敌，不修改存档或敌人。

## 失败原因与资源终结（2026-10-03）

敌方抽魂、夺寿及自身催动寿元成本导致归零时，战斗记录lastResourceBlow保存实际来源、资源、数量和回合。buildDeathReport按deathCause选择资源败因，不将此前气血lastBlow误认为抽魂或寿元失败来源；旧存档缺资源来源时回退到对应资源耗尽提示。lastBlow保留为气血历史，最后三条日志不再称三回合。只修正失败反馈，不改变费用、伤害、魂魄或寿元。

## 付款前的预算取舍（2026-10-03）

guChoicePreview增加可选purchaseCost，坊市传现有offerCost层价，奖励及已售商品传空。预览仅假设库存+1、购后余石，不修改state。下一突破复用RunFlow.nextBreakthrough，分开元石、资质与同阶舍利门槛；当前齐备配方用liveRecipes及逐件计数，保留重复小光等投入要求，以购后余石逐项显示可付或资金缺口。显示同一笔元石共用，不承诺同时可突破与合炼。修为催动预览复用GuRules.canActivate含既有低阶例外。没有新价格、奖励、储备扣款或第二套经济规则。

## 凝光同催的实际开放（2026-10-03）

原著关系依据small-light-gu与moonlight-gu Wiki E:V1-010932/010926/017148：两蛊同时灌元、月刃增幅且不叠加。凝光不是原著已证招式名。build_data仅将km_light_converge标记playable，其余16条显式false；费用由月光/小光现有组件字段求和，真元3/操控2，绝对数值属于授权六蛊试玩适配。效果复用killMoveEffectPlan（当前伤害6），不读取旧预制伤害5。

装备、战斗按钮及调用均检查playable；催动还检查已装备、真元品质、组件实例可用、操控、真元、行动与组件效果门禁。toggleMove补assertRunMutable。洞察/奖励新未来只传可玩组合，不把未开放杀招当作新可操作选择。use_kill_move事件在战后补给前记录实际费用与组件实例占用；库存保留。持续/生产/消耗组件仍由GuRules拒绝，没有重新开放明光壁，也没有免除其他系统成本。三槽保持既有上限；自由编辑及其他道完整杀招仍未完成。
