# Handoff · Web parity slice 01

```text
TASK web-parity-slice-01
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation
ASK 审阅本轮 Web parity 规则与 Edge 验收，决定下一批领域模块。

GOAL
开始把 Godot 领域规则移植到 lab：休整、真元回复、炼蛊、战斗产石、事件日志、突破、材料/蛊掉落与保底。
本轮不新增玩法、不改 Godot 领域数据。

DELTA
+ js/run_rules.js：休整、战斗回复、种子判定、产石、真元容量、突破门槛。
+ js/loot_rules.js：材料权重、蛊概率/稀有度、派系优先、材料与蛊 pity。
+ tests/run_rules.test.mjs + tests/loot_rules.test.mjs：11 条 Node 测试。
~ js/main.js：run event_log、突破、战利品结算、事件推进、真元容量按 aptitude 曲线。
~ js/alchemy.js：真实成功率、材料成本、失败销毁全部投入。
~ js/journey.js：休整/突破入口、战利品展示、层级与 tier。
~ tools/build_data.mjs：导出 seed、配方、aptitude、cultivation 成本、loot tables、school pool、pity 目标。
~ js/data.js：由 build_data.mjs 重新生成（65 蛊定义，含战利品池定义）。

STATE
规则模块：VERIFIED
Edge 验收：VERIFIED
完整领域 event_log 形状：PARTIALLY VERIFIED

FILES
game/wenzhen-web-lab/js/run_rules.js
game/wenzhen-web-lab/js/loot_rules.js
game/wenzhen-web-lab/tests/run_rules.test.mjs
game/wenzhen-web-lab/tests/loot_rules.test.mjs
game/wenzhen-web-lab/js/main.js
game/wenzhen-web-lab/js/alchemy.js
game/wenzhen-web-lab/js/journey.js
game/wenzhen-web-lab/tools/build_data.mjs
game/wenzhen-web-lab/js/data.js
game/wenzhen-web-lab/index.html

TEST
focused: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs → PASS 11/11
syntax: node --check 8 files → PASS
diff-check: git diff --check -- game/wenzhen-web-lab → PASS
Edge: 休整 24→8 气血 / 20→3 真元；突破 1→2 转，元石 10→5，真元上限 20→60；普通战 reward 元石 +3、2 材料；console 0 error

RISK
1. event_log 只记录 lab 已接动作的形状，不是 Godot 全量领域事件流；跨动作精确 tick 仍可能漂移。
2. 战利品已接材料、蛊、pity；elite 的 backlash/notoriety cost_pool 尚未接。
3. 坊市只接 purchase/material_purchase/soul_boost；寿元、换蛊、蛊方解锁等尚未接。
4. 休整只接 heal/breakthrough；移除蛊、印记、反噬尚未接。
5. 工作树含此前 visual/lab 改动；本轮未 commit / push。

GIT
status: game/wenzhen-web-lab 多文件修改 + 未跟踪 tests/docs/js
commit: NONE
merge: NONE
push: NO

NEXT
1. 接入 Godot 全量 event_log 形状与更多命令事件。
2. 接 elite cost_pool、坊市交易全集、休整 removal。
3. 再做一轮首局端到端 Edge 验收与对照记录。
STOP
```
