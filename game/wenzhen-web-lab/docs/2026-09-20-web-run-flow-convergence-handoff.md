# Handoff · Web run-flow convergence

```text
TASK web-run-flow-convergence
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 Web lab 从线性首局路线改为固定分支节点图、战斗后三选一和每节点统一整备页。

DELTA
+ js/run_flow.js：难度、固定图生成、后继查询、四阶突破、舍利同阶门禁、卖蛊计价。
+ tests/run_flow.test.mjs：覆盖图深度/后继、确定性、大小突破、同阶舍利、支持蛊数据。
~ tools/build_data.mjs：输出 flow 配置、支持蛊实体、支持蛊坊市货架和更新机制覆盖清单。
~ js/main.js：改为图节点开局；胜利自动回真元/30% 气血；战后三选一；统一整备；卖蛊自动卸下失效杀招。
~ js/journey.js：节点图页、统一整备页、战后奖励页、终局页。
~ index.html / css/lab.css：新增节点与整备入口和页面样式。
~ js/battle.js / describe.js / killmove.js：适配 battle/elite/boss 节点、支持蛊文案与脏装备防御。

DECISIONS
- 难度只改每段准备节点数：简单 15 / 普通 10 / 困难 5；整局固定 5 段。
- 每段准备深度固定 3 个候选节点，节点后继为本层全部候选；最后准备层汇入唯一层主。
- 任意战斗失败终局，不可重试。
- 战斗胜利自动恢复真元至上限并恢复最大气血 30%。
- 舍利蛊只接受当前转数同阶；资质蛊使用后立即提升一档资质。
- 每节点整备页刷新坊市；本页售罄，下一节点再刷新。
- 卖蛊返还 value 的 50%，造成杀招失效时自动卸下。

VERIFY
data: node tools/build_data.mjs -> gu 77 / shopOffers 34；既有 nodes 37 / route 12 保持不变
tests: node --test tests/*.test.mjs -> PASS 45/45
syntax: node --check run_flow / journey / main / loot_rules / battle / build_data -> PASS
diff-check: git diff --check -- game/wenzhen-web-lab ... -> PASS
browser:
  - 大厅可选简单/普通/困难并开局
  - 节点图显示固定五段、当前可走后继
  - 点击节点进入战斗
  - 胜利自动到账元石/材料并进入三选一
  - 无蛊掉落时直接进入统一整备
  - 整备页可突破、使用资质蛊、购入、卖蛊、炼蛊、调杀招、进入下一节点
  - 终局与失败均进入 ending
  - console: 0 error

RISK
1. 资质蛊是本轮 L0 要求的 lab-only 普通蛊实体；Godot 现有数据没有对应实体。
2. 节点模板名和敌人来自 Godot 数据，图结构由 Web lab 的 run_flow 规则生成，不是 Godot 现成图。
3. 工作树仍有此前视觉线与 parity 改动，未 commit / push。
4. `.playwright-cli/` 与 output 截图是本轮浏览器验证产物，不应提交。

NEXT
1. 根据实际试玩调整普通/精英节点配比和奖励概率。
2. 补事件、险地、宝库等节点类型时，先单独走设计门禁。
```
