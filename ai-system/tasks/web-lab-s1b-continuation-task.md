# L3 任务包 · 网页端决定性实验 S1（续做，接上一次限流中断）

```text
WORKFLOW ROLE:
L3 Web Lab Worker（读写限定 game/wenzhen-web-lab/**；Godot 线只读）

UPSTREAM:
Codex Orchestrator（L2）

DOWNSTREAM:
Codex Review（L2）→ 实验计量表（docs/2026-09-20-deepening-experiment.md §3）

PROJECT GOAL:
《问真》（《蛊真人》改编游戏）的**载体裁决**需要证据：规则复杂度上升后，Web 侧的改写速度是否还保持。
game/wenzhen-web-lab/ 是为回答这个问题建的功能验收台。

CURRENT PHASE:
V2 需求重构期。L0 已单独裁决允许网页端做这一件「决定性实验」。本包是 S1 的**续做**。

TASK PURPOSE:
上一个 worker 做到一半被模型限流中断。本包只做**剩余部分**，不重做已完成部分，也不需要重新取证。

--------------------------------------------------------------------
先读这两份（规格全在这里，不要凭本包的转述做）
--------------------------------------------------------------------
1. ai-system/tasks/web-lab-s1-multi-enemy-task.md   ← S1 完整任务包（规格来源 A–H 与验收全在此）
2. game/wenzhen-web-lab/docs/2026-09-20-deepening-experiment.md  ← 实验边界与计量口径

--------------------------------------------------------------------
已完成（**不要重做**，只做核对）
--------------------------------------------------------------------
- tools/build_data.mjs：已加 encounters 抽取；已把覆盖页「多敌遭遇」从 notCovered 移到 covered
  （措辞已写对，含护体池语义）。
- js/data.js：已重新生成，`encounters` 10 条（唯一多敌 = beast_swarm_pass）。
- 自验：`node tools/build_data.mjs` 输出 `gu 10 | recipes 6 | killMoves 3 | enemies 6 | encounters 10`。
- 先核对这些是否仍在（`git diff` 看 build_data.mjs 与 data.js），若被回退则重做这一小步。

--------------------------------------------------------------------
待做（本包的全部工作）
--------------------------------------------------------------------
1. js/rules.js：按 S1 包 F 节，把 reactionLive / reactionSettled / liveReactions 改成
   **按目标取**（吃「单个敌人对象 + 该敌人的 flags」），不再读全局 battle.flags。
   phaseView / activePhase / intentReady / selectIntent 已是纯函数，保持不动或只改签名。
2. js/main.js：按 S1 包 B/C/D/E/G 节
   - startBattle(encounterId)：建 b.enemies[]，每只带 hpMax/hp/phaseIndex/lastFired/flags(或 statuses)/intent 预算；
   - useMove(id, targetId)：只打选中目标；数据里带 aoe 的打全部存活；targetId 无效时回退第一个存活；
   - enemyTurn：按数组序遍历存活敌人逐个结算，每只结算后立即判胜负；
   - **护体改池语义**（`block -= absorbed`，不是清零）；
   - 胜利 = 全灭；败 = 玩家气血归零。
3. js/battle.js：敌方区改列表，每只一盒（立绘/名/血条/阶段/意图/意图冷却/线索/反击/状态），
   可点选目标（选中高亮），默认第一个存活；对手选择页要能选到 beast_swarm_pass 那场（标注为多敌）。
4. 端到端真点 + **真看图**：按 S1 包 ACCEPTANCE 第 2 条的 a–e 五项，
   每项跑 `node ../wenzhen-web/tools/drive.mjs "<file://…/index.html>?silent=1" "<计划>" "1280,720"`，
   截图落在 game/wenzhen-web-lab/screenshots/（被 .gitignore 排除，可随时重跑）。
5. 报告 game/wenzhen-web-lab/docs/2026-09-20-s1-report.md（新建）：
   改了哪些文件 + 每个文件净增改行数（`git diff --stat` 口径，排除 js/data.js）+
   每张截图路径 + 每条断言的**实际输出文本** + 由上一次中断接续的说明。

SCOPE:
读：上述两份 + game/wenzhen-web-lab/** + game/data/nodes.json、game/data/enemies.json +
    game/scripts/domain/{battle_command_facade,v1_battle_resolver,v1_grammar_pipeline,map_generator}.gd +
    game/wenzhen-web/tools/drive.mjs。
写：game/wenzhen-web-lab/js/**、game/wenzhen-web-lab/docs/2026-09-20-s1-report.md。

DO NOT:
- 不改 Godot 线任何文件；不动 game/tests/**；不动 js/data.js（生成物，只能由 build_data.mjs 写出）。
- 不引入 ES module / 构建步骤 / 新依赖；保持双击 file:// 能开（普通脚本按序加载、相对路径、无 fetch）。
- 不自创规则；写不出 Godot 出处的判定不要做。
- 不 commit、不 push、不 merge。
- 不改 docs/2026-09-19-handoff.md 与 docs/2026-09-20-deepening-experiment.md（后者由 L2 填计量）。

ACCEPTANCE:
- 上述 a–e 五项端到端断言全部有实际输出，且**截图已肉眼确认**（不能只看 dataset.ready）。
- 报告含净增改行数（本实验的核心计量之一）。
- 页面仍能双击打开、四个面板都在、控制台零错误。

ESCALATE WHEN:
- 发现 build_data.mjs 的已有改动与 S1 包 A 节规格不符；
- 需要给杀招编造 aoe/selector 数据才能继续（那是数据问题，不是实现问题）；
- 又一次被限流：把**已完成到哪一步**写进返回包的 STATUS=FIX/PARTIAL，不要为了交差跳过验证。

STATUS TARGET:
READY_FOR_REVIEW
```

## 返回格式

```text
STATUS: DONE / PARTIAL / BLOCKED
CHANGED:
FOUND:
EVIDENCE:
TESTS:
RISKS:
QUESTIONS:
```
