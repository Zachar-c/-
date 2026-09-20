# Handoff · Web parity slice 05 · Gu lifecycle

```text
TASK web-parity-slice-05
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把开局野生蛊、炼化成本、炼化后出战资格接入 Web lab。

DELTA
+ js/gu_rules.js：attune_cost = 4 + 2 * (rank - 1)，以及 wild -> refined 的纯规则转换。
~ js/main.js：开局改为 1 只已炼化小光蛊 + 2 只野生小光蛊；新增 attune_gu 命令与事件。
~ js/alchemy.js：新增“炼化野生蛊”区，成本与真元门禁可见。
~ index.html / js/main.js / js/battle.js：删除口误产生的战队页、页签、lineup 顺序和 team.js 引用。
~ js/journey.js：休整页移除强化蛊、移除蛊、移除印记、移除反噬四个未接入占位服务。
~ tools/build_data.mjs：更新机制覆盖清单。
~ js/data.js：重新生成。
+ tests/gu_rules.test.mjs：覆盖成本、成功转换、缺目标和真元不足。

VERIFY
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs
result: PASS 25/25
syntax: node --check js/main.js js/gu_rules.js js/alchemy.js
result: PASS
browser: Edge/Chromium smoke via Playwright
result: PASS; 20 -> 16 真元，野生 2 -> 1，已炼化 1 -> 2；战队页签/面板不存在；休整仅显示调息/突破/离开；控制台 0 error
diff-check: git diff --check -- game/wenzhen-web-lab
result: PASS

RISK
1. Web state 仍用 definition count 表达实例，未拆成完整 instance id map；战斗实例 id 由 count 投影。
2. marked / sword intent / seal 等上批规则保持现状。
3. 工作树包含此前 visual/lab 改动与未提交文件，未 commit / push。

NEXT
1. 接入 held_only survivor loot 的 wild 落袋语义。
2. 按需继续补生命成本、永驻、消耗、弱化、延迟等尚缺 V1 通道。
```
