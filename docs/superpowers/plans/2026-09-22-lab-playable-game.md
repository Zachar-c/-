# 《问真》lab.html 可玩游戏本体 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 本仓库的 Worker 协议和 L0/L1/L2 决策边界优先，不为技能增加重复审批。

**Goal:** 通过 `game/wenzhen-web-lab/lab.html` 交付可正常开局、构筑成长、完成五段胜负流程、自动保存续玩、重新开始的 Web 游戏本体，以真实玩家流程而非局部原型脚本为验收。

**Architecture:** 延续现有普通脚本、`state/act` 主循环和已有纯规则模块；修复 UI → 命令 → 状态 → 结算 → 存档的实际连接。数据继续消费 `game/data/`，不创建新数值/经济/战斗 Owner。浏览器存档、真实 DOM 驱动和发行打包是小范围工程适配，不引入通用框架。

**Tech Stack:** 现有 HTML/CSS/JavaScript、Node.js 内置测试、现有 Edge/Chrome CDP 自动化能力、本地浏览器存储；不增加前端框架、服务器或数据库。

## Global Constraints

- L0 指令：入口 `game/wenzhen-web-lab/lab.html`；交付一个可玩的游戏本体；不做 Godot（不改 `.gd`，不运行 Godot 验收）。
- 规格：`docs/superpowers/specs/2026-09-22-lab-playable-game-design.md`。权威 PRD/协议仍在根 `docs/`，本文不覆盖它们。
- 仅复用现有内容。NO new battle resolver / pricing engine / Rank source / battle2 merge / vertical expansion / bulk repricing / 26 杀招批量推导。
- 正式单局 R1→R5 仍未决。此版本沿用当前五段节点和第五层主终点，修为突破与地图段数分开验证。
- 当前已有其他执行者。W0 前没有任何写入主链授权交接；W1 起每批只有一个主链写入者，别人只读审查。
- 不覆盖用户改动，不 `reset --hard`，不自动 push。每批验收后 L2 仅提交本批确认拥有的文件/增量；无法从旧改动中安全拆分时保留工作树与结果包，不夹带提交。
- 不重置用户浏览器。验收使用独立 profile 和端口；新 profile 必须不存在，清理前解析路径并限制在本批临时目录。
- 现有调数值警报必须可见，不通过静默默认值、删断言、改阈值或硬塞资源获得通过。
- 下列新增文件是计划交付物，目前不存在不得假称可运行；每个创建步骤完成后才执行相应命令。

## CURRENT PHASE

GOAL: 从 lab 现有主链交付可玩 Web 游戏。
ACTIVE: W3 战斗可信性接缝核查与最小修复（2026-09-22，本任务 L2 调度一个 OpenCode Worker；主写仅 main.js / battle.js / combat_core.js / lab_combat.test.mjs）。
COMPLETED: W0 移交与基线已记录；7f43b91 已落库 W1/W2 实现。本任务独立复跑 tests 155/pass 155/fail 0/skipped 0、Projection 34/34、balance 38/38、L1 phases pass=41/fail=0/alarm=11；不等于 G01–G10 全部验收。
BLOCKED: 无本批已确认工程阻塞；W3 完整验收、W4–W7 与 11 条既有经济警报仍未闭合。
DECISIONS: Web only；lab.html；现有五段流程；不新建规则引擎。
NEXT: 复现并修复 W3 已证实的预览/结算适配缺陷 → 独立审查与回归 → 补齐 W3 真实游玩证据后再进入 W4。
DO NOT: 把本计划、绿灯数量或 fixture 注资突破当作游戏已完成。

2026-09-22 状态更正：原「尚未移交」已由 `game/wenzhen-web-lab/docs/2026-09-22-playable-game-handoff.md` 的明确交接记录取代；原「计划编制中」已过时。下方逐项勾选不凭提交标题批量补勾，未独立覆盖的验收项继续待验。

## 1. 批次与派发顺序

| 批次 | 玩家可见交付 | 依赖 | 主写区 |
|---|---|---|---|
| W0 | 冻结真实入口、规则与可复现基线 | 当前执行者结束/移交写入 | 仅文档、日志；不改玩法 |
| W1 | 打开即开局/继续，刷新不会丢失本局 | W0 | lab.html、main/journey、存档适配 |
| W2 | 节点、换页、胜负和再开局不绕过、不锁死 | W1 | main/journey、必要 run_flow 修复 |
| W3 | 战斗信息、预览、成本和实际结算一致 | W2 | main/battle/combat_core 的既有接点 |
| W4 | 奖励、交易、炼蛊、杀招、突破形成实际成长循环 | W3 | main/journey/alchemy/killmove 与既有规则消费 |
| W5 | 普通玩家能理解并完成整局的界面 | W4 | lab.html、lab.css、各面板文案/反馈 |
| W6 | lab 的真实自动走盘与正常开局通关证据 | W5 | lab 驱动器、测试夹具与报告 |
| W7 | 可移交的离线发行包与独立最终验收 | W6 | 打包工具、README、发行报告 |

主链全部串行；可并行的仅为当前批次只读 Review、测试记录整理。修复始终回到所属批次，不在验收脚本中伪造游戏行为。每个 Worker 交付后 L2 独立检查 diff、状态、真实数字和根因。

## 2. 测试证据分级（不得混用）

1. **规则单测**：可用边界 fixture、注入状态，证明指定规则；不能证明玩家能获得这些资源。
2. **lab 集成测试**：可装载受控局面验证扣费/重复点击/恢复等事务，但须显式标注 fixture。
3. **正常整局 E2E**：从空存档的 `game/wenzhen-web-lab/lab.html` 开始，只通过可见控件输入。禁止 `state.stones=...`、`act.*` 直接调用、强改敌血、跳节点、替换 DATA、调用 mvp `applyForge`；只读快照可辅助断言。
4. **发行玩家验收**：从解压后的文件启动，不依赖仓库路径、开发环境或网络；鼠标/键盘完成关键流程。

种子 101–110 是测试样本，不是数值裁决。不同种子至少在地图敌人/非战斗节点模板、货架或实际掉落的一类产生不同签名；同种子同操作日志应一致。确定性反制序列可以相同，不强行随机化 Counter。

## 3. W0：冻结主链基线与工程契约

**Files / Scope**
- Read: `game/wenzhen-web-lab/lab.html`、`game/wenzhen-web-lab/js/*.js`、现有 `game/wenzhen-web-lab/tests/*.test.mjs`、`game/wenzhen-web-lab/tools/check_*.mjs`、`game/wenzhen-web-lab/tools/build_data.mjs`。
- Create: `game/wenzhen-web-lab/docs/2026-09-22-playable-game-current-state.md`、`game/wenzhen-web-lab/docs/lab-runtime-contract.md`。
- 规则首读：根 PRD/AI/变更协议、`game/AGENTS.md`、`game/world-model/governance/CONSTRAINTS-V2.md`、`game/docs/contracts/module-interfaces/README.md`。Web 接口写本地契约，不借机重写 Godot 契约或实现。

**Interfaces**：消费 `game/wenzhen-web-lab/lab.html` 脚本顺序、`DATA`、`state`、`act`；产出基线文件哈希、初始状态/现有公开动作表、Web 命令与存档边界，不产出新游戏模型。

- [ ] 与当前写入者完成移交，记录 HEAD、`git status --short`、所有本批写区的 SHA-256；未确认前只读。
- [ ] 移交信号必须明确记录“移交者、接手者、HEAD、工作树清单、移交时间、哪些文件从该时刻停止写入”；L2复核后解除BLOCKED。W0的契约/状态文档写入也在此门槛之后；此前调查结果只留本任务临时目录。本计划与根导航为本任务独立文档写区，不代表接管主链。
- [ ] 从空浏览器 profile 打开 lab，记录实际脚本异常、缺图、初始 READY（含14类持有蛊）、难度、graph roots、第一可选节点和第一场战斗。保留错误原文与截图，不依据合并说明宣称唯一战斗核已接通。
- [ ] 运行现有 Node 套件、Projection、balance、P2–P5；记录测试数、失败数与警报。比较源码和真实消费者，不把静态声明当接线。
- [ ] 标记 `autoplay.mjs` 只证明短剧本；`check_progression_loop.mjs` 的注资/手写配置仅为 fixture，不能计入 G05/G07。
- [ ] 写入本地接口契约：main 的 act 是 Web 状态写入口；面板只提交动作；调用链中各规则实际 Owner；禁止为了“统一”把已有战斗整体替换。
- [ ] L2 判定本批 PASS：已建立可复核基线和明确写入权；已有失败进入后续具体批次，不必在 W0 重做一次大研究。

**Commands（仓库根）**
```powershell
git status --short
git rev-parse HEAD
node --test game/wenzhen-web-lab/tests/*.test.mjs
node game/wenzhen-web-lab/tools/check_projection.mjs
node game/wenzhen-web-lab/tools/check_balance.mjs
node game/wenzhen-web-lab/tools/check_l1_phases.mjs
```

## 4. W1：新局、继续、自动保存与恢复

**Files**
- Modify: `game/wenzhen-web-lab/lab.html`、`game/wenzhen-web-lab/js/main.js`、`game/wenzhen-web-lab/js/journey.js`、`game/wenzhen-web-lab/tools/build_data.mjs`、生成文件 `game/wenzhen-web-lab/js/data.js`、`game/wenzhen-web-lab/docs/lab-runtime-contract.md`。
- Create: `game/wenzhen-web-lab/js/lab_save.js`、`game/wenzhen-web-lab/tests/lab_save.test.mjs`、`game/wenzhen-web-lab/tests/helpers/lab_browser.mjs`。

**Interfaces**
- 消费当前 `fresh(difficulty)` 返回的完整可序列化 state，不另造 RunState。
- 新适配 `LabSave.encode(state, contentVersion)` 返回 JSON 文本；`LabSave.decode(text, contentVersion)` 返回 `{ok,state,reason}`；`LabSave.write(storage,state,contentVersion)` 与 `LabSave.read(storage,contentVersion)` 捕获存储异常并返回结果。storage 是浏览器 storage 接口，测试用内存适配，禁止依赖浏览器全局做纯单测。
- 存档信封固定 `{schemaVersion:1, contentVersion, state}`；本地键 `wenzhen.lab.run.v1`。schemaVersion 是存储版本，非玩法数值；contentVersion 来源构建产物标识。
- `build_data.mjs` 用 Node 内置 `createHash('sha256')` 对加入版本字段前的 `JSON.stringify(out)` 求摘要，写入 `out.contentVersion`；`data.js` 只重新生成、不手改。改变存档状态结构时提升 schemaVersion，不能仅依赖内容摘要判断状态兼容。
- 恢复包括 seed、难度、graph、当前位置/后继、战斗/意图/冷却/封印/延迟效果、奖励待选、库存/材料、交易售罄、保底、修为、equipped、日志与结局。临时动画和音频对象不存储。
- 测试 helper 从现有 `game/wenzhen-web-lab/tools/autoplay.mjs` 复用 CDP 连接思路，导出 `openLab({entry, seed, viewport})`，返回异步 `click(selector)`、`snapshot()`、`reload()`、`close()`。snapshot 只读完整可序列化 state；每个实例独占临时 profile/随机可用端口。W2–W4 的 Node 集成测试和 W6 driver 复用此 helper，不各造浏览器启动器。helper 不提供改元石/敌血/调用 act 的捷径。

- [ ] 编写纯单测：编码/解码完整往返、坏 JSON、版本不匹配、缺关键状态、重复恢复、storage 拒绝/容量异常；先观察新增测试失败。
- [ ] 实现本批浏览器 helper，在真实 lab 首屏点击开始→截图/只读快照→关闭；该操作测试浏览器依赖可用。纯规则 fixture 仍走原有 VM 测试，不把 fixture 写进玩家页。
- [ ] 实现最小 LabSave，不新增账户、云同步或迁移平台；坏存档保留原文，不覆盖，UI 显示“无法读取”及明确选择重新开局，不伪显示已保存。
- [ ] 在 `game/wenzhen-web-lab/lab.html` 的 `main.js` 之前载入适配；启动时读取存档。`fresh()` 只在无有效档或用户明确新局时执行。
- [ ] 把保存放在完整动作/结算后的统一提交边界，所有 act 终止分支亦覆盖；禁止在 `recordEvent()` 的半笔扣款中途保存，禁止每帧保存。
- [ ] 大厅给出继续当前局；新开局、修改进行中局的难度、顶栏重开均先确认放弃当前局。取消不得改变 state、seed、售罄、奖励或存档；已结束局可直接开启新局。
- [ ] 把种子接入 `fresh(difficulty, seed)` 与现有 `RunFlow.generateGraph`/掉落/商店路径：新局无显式种子时只生成一次种子并保存；测试入口 `?seed=101` 只影响明确的新局，继续始终优先存档种子。禁止 `READY.seed` 覆盖已选择的种子，不随机改变反制机制。
- [ ] 在战斗中、奖励待选时、买完物品后真实刷新，各自恢复同一局；刷新不得多发元石/材料/蛊，不重抽货架与掉落。

**Test example（接口实现后）**
```javascript
const raw = LabSave.encode(stateBefore, 'test-content');
const restored = LabSave.decode(raw, 'test-content');
assert.equal(restored.ok, true);
assert.deepEqual(restored.state, stateBefore);
assert.equal(LabSave.decode('{', 'test-content').ok, false);
```

**Acceptance**：G02 全部通过；存储不可用时不崩溃、不假称可续玩。原本没有浏览器存档，这是此批允许新增小适配的 capability gap。

Run: `node game/wenzhen-web-lab/tools/build_data.mjs`（先记录并审核已有生成器改动）；`node --test game/wenzhen-web-lab/tests/lab_save.test.mjs`。随后 W6 驱动复验实际刷新；本批先用真实浏览器完成三个中断点并附截图。

## 5. W2：节点状态、胜负与防绕过

**Files**
- Modify: `game/wenzhen-web-lab/js/main.js`（`chooseNode/completeCurrentNode/openBattleOutcome/endJourney/endBattle/showPage`）、`game/wenzhen-web-lab/js/journey.js`、必要的 `game/wenzhen-web-lab/js/run_flow.js`。
- Create: `game/wenzhen-web-lab/tests/lab_lifecycle.test.mjs`。
- Update: `game/wenzhen-web-lab/docs/lab-runtime-contract.md`。

**Interfaces**：沿用 `journey.nodeId/availableNodeIds/completed`、`battle/reward/prepFor/ending/page`。给现有 ending 增加明确 `outcome: 'victory'|'defeat'`，且由真实终局转移产生，不由打开页面产生。

- [ ] 用现有 graph fixtures 写失败测试：不能选择非后继；未开局不能进真实奖励；战斗未结算不能 leavePrep 跳关；结局后不能再买/炼/战斗增加局内力量。
- [ ] 统一允许的页面转移：离开战斗页只改变视图，保留遭遇；继续返回当前战斗/领奖/整备，不能一律返回空地图。修复 `endBattle()` 清空未结束 battle 导致的丢遭遇。不要顺手设计付费逃跑机制。
- [ ] 死亡关闭战斗并固定败局；最后层主真实获胜、领奖与节点完成后固定胜局。空 graph/缺敌人应报内容错误，不能伪造“行程已尽”胜利。
- [ ] 奖励/节点完成具备重复调用保护；错误点击不追加重复奖励/完成事件，刷新不再次结算。
- [ ] 大厅展示终局摘要；再开局通过 fresh 清理上一局资源、战斗、临时 flag、奖励和库存，不新增跨局力量继承。
- [ ] 用真实 UI 完成首战→奖励→整备→下一节点、败局→重开；单测检验 L5B 终点；完整正常获胜留 W6 验证，不能把设置 `b.over='胜'` 当获胜证据。

**Acceptance**：G03 以及 G02 的跨页面恢复；每个非终局状态至少有合法继续操作，无凭空通关或卡死。`node --test game/wenzhen-web-lab/tests/lab_lifecycle.test.mjs game/wenzhen-web-lab/tests/run_flow.test.mjs` 输出 fail=0。

## 6. W3：可读、可信的战斗

**Files**
- Modify: `game/wenzhen-web-lab/js/main.js`（`startBattle/_pickIntent/observe/useGu/useMove/basicAttack/enemyTurn/applyEffectPlan`）、`game/wenzhen-web-lab/js/battle.js`、`game/wenzhen-web-lab/js/combat_core.js`，仅有证实缺陷时改 `game/wenzhen-web-lab/js/rules.js` / `game/wenzhen-web-lab/js/mvp_logic.js`。
- Create: `game/wenzhen-web-lab/tests/lab_combat.test.mjs`。
- Read: `game/wenzhen-web-lab/js/gu_rules.js`、`game/wenzhen-web-lab/js/mvp_content.js`、`game/wenzhen-web-lab/docs/MERGE-MVP-LAB.md`；声明式杀招数据不改。

**Interfaces**：实际 lab 使用 `battle.enemies[].enemyIntent/currentCounter/revealed/counterRevealed` 与 main state；CombatCore 是已有 MvpLogic API 的消费适配。先建立字段映射表，再修调用点，不再引入第二套状态模型。

- [ ] 逐项建立失败 fixture：未观察/已观察、直接攻击/支援、合法杀招/缺组件、封印/已用实例、多个敌人、延迟效果、气血/寿元/魂魄归零；以现有已批准公式为期望，不编新数值。
- [ ] 验证 `toCoreEnemy` 与 `_pickIntent` 之后反制确实进入本回合状态；UI 显示和实际结算消费同一意图/反制/已知信息。不能挂上 CombatCore 脚本就标“合并完成”。
- [ ] 验证攻击入口只扣一次资源、同一效果只结算一次，尤其 `useMove` 的 effectPlan 与 declared damage 不能出现 adapter 新增的重复伤害。既有合法复合效果须有 fixture 支持，不能见两次命中就擅删。
- [ ] 修复预览形状/参数适配：隐藏信息不得提前泄露，已知信息的预计伤害/成本必须与同一局面结算对应；无能力的按钮禁用并说明原因。
- [ ] 敌人回合、状态持续、死亡检测与保存提交顺序固定；快速连点不得重复行动或绕过念头/封印/冷却。
- [ ] 普通玩家在实际页面完成一场观察后改变打法的战斗、一场多敌战斗、一场层主战；记录每步前后资源与战报。fixture 中的 Counter 覆盖不能替代这些证据。

**Acceptance**：G04；`node --test game/wenzhen-web-lab/tests/lab_combat.test.mjs game/wenzhen-web-lab/tests/gu_rules.test.mjs game/wenzhen-web-lab/tests/rules.test.mjs game/wenzhen-web-lab/tests/mvp_logic.test.mjs` 输出 fail=0。若发现规则本身有多个合理解释，精确到同一输入的冲突结果上抛 L1，其他无关工程任务可继续。

## 7. W4：奖励与成长是同一局的真实动作

**Files**
- Modify: `game/wenzhen-web-lab/js/main.js`（`rollVictoryLoot/openBattleOutcome/buyOffer/forge/attuneGu/toggleMove/useMove/sellGu/breakthrough`）、`game/wenzhen-web-lab/js/journey.js`、`game/wenzhen-web-lab/js/alchemy.js`、`game/wenzhen-web-lab/js/killmove.js`。
- 仅修已证明的调用缺陷时修改 `gu_rules.js/shop_rules.js/loot_rules.js/run_flow.js`，不复制规则。
- Create: `game/wenzhen-web-lab/tests/lab_transactions.test.mjs`。

**Interfaces**：继续使用实际 `DATA.recipes/killMoves/shopOffers/flow/loot` 和 main act；`GuRules.killMoveRecipeInstances` 是组件数量、实例占用校验的复用入口，不能在 UI 单独用 `every(owned[id]>0)` 代替重复组件计数。

- [ ] 先写事务 fixture：余额不足无扣款；一次购买只减一次钱且加一次物品；售罄不重购；奖励三选一只能领一只；刷新不重领；材料失败分支与现有 recipe 风险一致。
- [ ] 比较购买与掉落实账的事件字段；记录元石、蛊、材料的 before/after/delta，而非只验证 stock 返回数组。
- [ ] 炼蛊前展示投入数量、材料/元石、已有成功率和失败损失；点击才扣款。野生蛊不能直接作为已炼化组件使用。C3 单小光实验配方在实际页面与事件中带实验身份，不改 canonical 配方。
- [ ] 装备杀招后买/卖/炼耗蛊虫，重新检查有效组件与实例数；缺组件时明确不可用/卸下，不保留能点的幽灵杀招。结构 recipe 新旧格式经已有兼容边界解析，不批迁26条。
- [ ] 突破使用 `RunFlow.nextBreakthrough(...,DATA.flow)` 的原配置，实际扣款/舍利、stage 与 qiMax 同步；资质不足或高转不可催动必须在 UI 和 action 两侧一致。禁止替换成 10000 元石和手写 flowConfig。
- [ ] 从正常开局，通过实际游玩收入完成至少购买、炼化、合炼、装备并使用杀招、一次小突破及一次大突破；不同子链可取不同合法 run，报告注明，不把多个局拼成同一局。

**Accounting assertion 示例**
```javascript
assert.equal(after.stones, before.stones - displayedCost);
assert.equal(after.owned[guId], (before.owned[guId] || 0) + 1);
assert.equal(after.shopSold.filter(id => id === offerId).length, 1);
// 再点击售罄项/重放领奖后，资源快照应保持不变。
assert.deepEqual(afterSecondAttempt.resources, after.resources);
```

**Acceptance**：G05/G06；`node --test game/wenzhen-web-lab/tests/lab_transactions.test.mjs game/wenzhen-web-lab/tests/loot_rules.test.mjs game/wenzhen-web-lab/tests/shop_rules.test.mjs game/wenzhen-web-lab/tests/run_flow.test.mjs` 输出 fail=0。R1→R5 条件边界继续可用纯规则 fixture 测试，但不冒充正常整局成长。

## 8. W5：玩家界面收口

**Files**：`game/wenzhen-web-lab/lab.html`、`game/wenzhen-web-lab/css/lab.css`、`game/wenzhen-web-lab/js/journey.js`、`game/wenzhen-web-lab/js/battle.js`、`game/wenzhen-web-lab/js/alchemy.js`、`game/wenzhen-web-lab/js/killmove.js`、`game/wenzhen-web-lab/js/describe.js`，仅必要时调整 main 的 UI 绑定。

**Interfaces**：复用现有 data-* 按钮与 act 方法。新增选择器只服务可见按钮/反馈，不新增调试动作 API。`?debug=1` 可显示开发面板，但正常玩家入口不显示覆盖表、演武目录和源码标记。

- [ ] 保留现有视觉与资产，页面标题/大厅文案明确游戏目标、当前进度和操作入口；“拼装局”“覆盖验证”等开发说明移到开发区，不仅换标题就宣称已完成。
- [ ] 六类页面逐个检查：大厅新局/继续；地图当前节点与后继；战斗意图/反制/成本；奖励领取；整备商店/炼蛊/杀招/突破；结局原因/构筑/关键选择/再来一局。
- [ ] 按玩家决策提供数值：扣费前见价格，炼制前见损失，寿元等致死代价执行前可见；按钮禁用时展示具体缺口，不只显示“无法操作”。
- [ ] 在 1280×720 和 1920×1080 检查滚动、文字、卡牌、提示与弹窗；键盘可聚焦并激活主操作；音效失败或静音不影响状态。移动端/新美术方向不作为本轮扩项。
- [ ] 核对实际图标/敌人画像/字体加载，不用 _link_assets 的少量复制列表代替 lab 资产清单。
- [ ] 列出每个可见交互及成功/拒绝结果，执行真实浏览器巡检；隐藏控件不作为功能已实现，核心功能不得通过隐藏来逃避验收。

**Acceptance**：G01/G08；六类页面截图、键盘巡检、零启动脚本异常/关键资源缺失/挡住主操作的布局问题。新用户无需看开发说明即可从大厅进入首战并理解下一步。

## 9. W6：真实 lab 自动走盘与可玩性证据

**Files**
- Create: `game/wenzhen-web-lab/tools/autoplay_lab.mjs`、`game/wenzhen-web-lab/tests/fixtures/lab_playthroughs.json`、`game/wenzhen-web-lab/docs/2026-09-22-playable-game-acceptance.md`。
- Read/reuse: W1 的 `game/wenzhen-web-lab/tests/helpers/lab_browser.mjs` 和现有 `game/wenzhen-web-lab/tools/autoplay.mjs` 的日志/截图/DOM驱动思路；必须维持旧短剧本驱动可运行，不创建通用测试平台。
- `game/wenzhen-web-lab/tools/check_progression_loop.mjs` 仅明确其 fixture 身份；不靠改名使其成为整局证据。

**Interfaces（新驱动必须实现的命令约定）**

CLI参数必须包含 `--entry <本地HTML路径或file/http URL>`（默认实际lab.html，严禁退回index.html）、`--suite smoke|lifecycle|full`、`--seed N`、`--seeds A-B`、`--difficulty easy|normal|hard`、`--policy balanced|refine`。`--seed`与`--seeds`互斥，非法值立即报错。驱动把种子传入lab新局入口，不改已载入state；每局独立profile保证无旧存档干扰。
```powershell
node game/wenzhen-web-lab/tools/autoplay_lab.mjs --suite smoke --seed 101 --difficulty normal
node game/wenzhen-web-lab/tools/autoplay_lab.mjs --suite lifecycle --seed 101 --difficulty normal
node game/wenzhen-web-lab/tools/autoplay_lab.mjs --suite full --seeds 101-110 --difficulty normal --policy balanced
node game/wenzhen-web-lab/tools/autoplay_lab.mjs --suite full --seeds 101-110 --difficulty normal --policy refine
```

`balanced/refine` 仅是自动玩家的决策策略标签，从当前可见蛊、配方、商店作选择，不是新增游戏职业/技能/数值。驱动不能读隐藏反制来作弊。fixture 文件只记录 seed、difficulty、初始内容指纹、按钮选择与期望结果，不包含修改资源的指令。

自动化失败边界：单次DOM动作等待上限15秒，单局动作上限20000次；达到边界输出最后页面/按钮/状态摘要并FAIL，不把超时计作败局。默认采样视口1280×720；这是测试防挂起限制，不是游戏回合或时长上限。`smoke` 覆盖启动到首个真实结算；`lifecycle` 覆盖三个恢复点与重开；`full` 必须到真实胜/败终局。

- [ ] 先验证驱动打开的是 lab 而非 index/mvp，ready 信号真实，首个按钮后 state/journal 有结果；找不到按钮或超时必须 FAIL，不静默跳过。
- [ ] 通过 DOM 新局，选择地图后继、战斗、领奖、买卖、炼蛊、杀招配置、突破，直到终局；只读截图/快照用于断言，禁止页面 evaluate 写 state 或调用 act 完成动作。
- [ ] 驱动保存动作序列、资源账本、节点轨迹、结局原因、JS异常和缺资源，输出每场战斗及全局摘要；同 seed 同操作回放一致。
- [ ] 在 `lifecycle` 套件插入战斗/奖励/整备刷新、取消重开、确认重开和存储拒绝测试。存储故障测试可为专项 fixture，正常获胜轨迹不得使用。
- [ ] 种子101–110每种策略各一局：20局均合法终止，无软锁、错误奖励、负库存、JS异常。记录胜负而不强制20局全胜；每策略至少有一条不同构筑的正常难度完整获胜轨迹，证明玩家确实可赢。至少一条有意义的失败→重开轨迹。
- [ ] 若策略不会玩，修自动玩家；若状态接线错，返对应批次；若既有数值使正常构筑无法获胜，附精确资源轨迹上抛。禁止降敌血、改价格、删失败窗来让报告绿。
- [ ] 真实人工式浏览器巡检一条完整 run，审查目标理解、选择反馈、失败归因。自动化计数不能代替这一项。

**输出契约**：日志必须区分 `RULE_TEST / FIXTURE_INTEGRATION / NORMAL_RUN`，每次输出 `{entry, contentHash, seed, difficulty, policy, outcome, visitedNodes, terminalReason, resourceLedger, consoleErrors, softlocks}`。检查全过但没有实际 terminal outcome 的 full 套件必须失败。

**Acceptance**：G01–G09；固定种子/路线/构筑、真实获胜和失败日志可复现。之前短剧本 secure/debt 的失败不自动归因于 lab 数值，不机械套用 10分钟原型的回合窗口。

## 10. W7：离线发行与最终独立验收

**Files**
- Create: `game/wenzhen-web-lab/tools/package_lab.mjs`、`game/wenzhen-web-lab/README.md`（启动、操作、存档说明）、发行包内 `README.html`。
- Update: `game/wenzhen-web-lab/docs/2026-09-22-playable-game-acceptance.md`、本计划 CURRENT PHASE。
- 产物默认写入系统临时目录，不进入 Git，不携带 `.git`、source、小说正文、测试语料、secrets 或其他项目。

**Interfaces**：打包保持 `game/wenzhen-web-lab/lab.html`、本页脚本样式和其全部运行期资产的原相对路径；一并复制必要 `game/assets/` 与 lab 局部 assets，避免改源码路径来适配发行。包含文件必须由实际引用解析+运行期ID映射检查，而不是只复制4个敌人/7只蛊。

```powershell
node game/wenzhen-web-lab/tools/package_lab.mjs --out "$env:TEMP/wenzhen-playable-release"
node game/wenzhen-web-lab/tools/autoplay_lab.mjs --suite lifecycle --entry "$env:TEMP/wenzhen-playable-release/game/wenzhen-web-lab/lab.html" --seed 101 --difficulty normal
```

- [ ] 输出目录若已存在则拒绝覆盖，L2 选新目录；不得递归删除未经检查的用户目录。
- [ ] 拷贝玩家发行依赖，生成文件清单与内容哈希、相对链接 README.html；用户不需要 Node 或 Godot 即可打开游玩。
- [ ] 解压/复制到与仓库无关的新目录，断网启动，查全局运行时错误和资源请求；存档路径/浏览器行为在 README 写清，不承诺跨浏览器或移动目录自动迁移存档。
- [ ] 在发行副本跑 lifecycle 套件和一条已验证完整获胜回放；同时测试一条败局到重开。游戏条件与仓库原版本一致。
- [ ] L2 独立复核变更范围、实现、测试数字和归因，核对G01–G10逐项证据；任一核心缺口仍为 BLOCKED，不使用 ACCEPTED_WITH_GAPS 替代交付。
- [ ] 只在全部通过后给出本地可玩入口、发行包、操作说明、已验证种子与结局证据。不开新引擎/扩内容分支，停止此阶段。

## 11. Worker Task Packet（逐批发送，禁止一次全仓施工）

以下公共包与对应批次章节一起完整发送；不能只给一个文档路径让 Worker 猜范围。L2 把本批实际基线指纹与测试输出附在消息中，指纹必须现场生成，不能用本计划日期代替。

```text
WORKFLOW ROLE:
L3 Worker
UPSTREAM:
Codex Orchestrator
DOWNSTREAM:
Codex Review
PROJECT GOAL:
把《问真》已有Web主链交付成普通玩家能完整游玩、续玩、结束和重开的游戏。
CURRENT PHASE:
LAB PLAYABLE DELIVERY；Web only；lab.html为玩家入口。
TASK PURPOSE:
完成本次所附W批次的玩家可见交付，关闭既有实现接缝。
TASK:
按随包完整附带的单个批次章节逐项执行；不得实施后续批次。
SCOPE:
仅该批次Files列出的文件；根规则/协议/规格可只读；测试只运行本批及直接相关集合。
DO NOT:
不改Godot，不新建Rank/价格/战斗引擎，不改数值与产品方向，不扩大内容，
不覆盖其他执行者，不注资冒充正常通关，不commit/merge/push，不读写secrets。
DECISION AUTHORITY:
可以修工程接线、状态一致性、UI可用性和测试；数值与架构模型判定归L1，产品取舍归L0。
ESCALATE WHEN:
前提与实际不符；写区出现他人新增变更；无法在现有规则下满足验收；
需要改成本/奖励/开局/终点/杀招语义或战斗Owner。提交最小复现与具体冲突，不自行绕开。
DELIVERABLE:
改动文件、diff摘要、真实测试输出、正常流程/fixture证据分类、风险和下一步；
同时按ai-system/WORKER_HANDOFF_TEMPLATE.md返回结果包。
ACCEPTANCE:
本批Acceptance全部满足，新增测试证明修复前失败/修复后成功；
没有越界改动，UI和实际状态一致；不能用文件数或PASS标签代替结果。
STATUS TARGET:
READY_FOR_REVIEW
```

派发映射：W0 只读基线与契约；W1 生命周期/存档；W2 节点终局；W3 战斗；W4 成长事务；W5 玩家界面；W6 DOM整局；W7 打包与最终复核。默认执行器 OpenCode + `opencode/muse-spark-1.3-contributor-free`，按 `ai-system/AGENTS.md` 处理不可用，禁止静默更换模型。

## 12. L2 每批 Review 与阶段停止条件

- [ ] 检查当前写区与基线差异，区分先前用户改动、本批Worker改动、并发新增变更。
- [ ] 独立复核运行时应用点，不采信“别名等于唯一核”“有字段等于接线”“数组非空等于可购买”。
- [ ] 独立复核数字，读取真实输出；失败统计、通关比例、节点数不得根据退出码猜。
- [ ] 区分代码错误、自动玩家策略错误、已存在数据问题；未取证不得把失败概括为“构筑差”。
- [ ] PASS后进入下一批；FIX_REQUIRED回同批；数值/产品阻塞附最小自足Research Request，而非要求重新研究全体系。
- [ ] G01–G10全部达标才把CURRENT PHASE改COMPLETE；否则明确剩余哪条玩家流程不能完成。

## 13. 本轮计划交付记录

> **2026-09-24 状态校正：**下列条目是计划编写时的历史快照，不再作为当前派单依据。`bb3f88f` 已记录 W3–W7 收口，当前 Web README 也包含续玩与打包入口；其中「W1–W7 未执行」及「下一实际动作进入 W1」已过时，停止沿用。后续执行须先复核已有代码与验收证据，再回写各批状态；此校正不代表 G01–G10 已全部通过。

- 已完成：基于当前源码核对并落盘交付规格、W0–W7任务、验收矩阵和派单模板。
- 已派出：两项只读Worker调查（生命周期、资源/构筑/战斗接缝），L2已独立检查关键应用点。
- 未执行：W1–W7游戏代码写入；本文件不是它们的完成记录。
- 下一实际动作：当前主链执行者按W0交接其修复结果，冻结写区后由同一主写Worker进入W1；不再追加与交付无关的数值原型。
