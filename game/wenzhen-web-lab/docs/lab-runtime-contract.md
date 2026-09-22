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
| 奖励 | `openBattleOutcome()`（函数）`chooseRewardGu(guId)` `continueReward()` |

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
