# Handoff · Web parity slice 03 · Marked + sword intent

```text
TASK web-parity-slice-03
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
补齐战斗回合末的 marked 结算与剑意跨回合规则。

DELTA
+ js/run_rules.js：marked 划伤、剑意上限与回合末衰减。
+ tools/build_data.mjs：导出 mark_scratch_per_layer / mark_scratch_cap；更新机制覆盖清单。
~ js/gu_rules.js：剑意只加成剑道 strike。
~ js/main.js：敌方行动后结算 marked；结算致死直接胜利；剑意加成、封顶与衰减接线。
~ js/battle.js：战斗 HUD 显示剑意，目标状态显示刻痕层数。
~ js/describe.js：剑意蛊效果文案。
~ tests/run_rules.test.mjs、tests/gu_rules.test.mjs：新增规则回归。

VERIFY
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs
result: PASS 22/22
syntax: node --check main/run_rules/gu_rules/battle/describe/build_data
result: PASS
generated data: skills transform comparison 0 mismatch / 65
diff-check: git diff --check -- game/wenzhen-web-lab
result: PASS

RISK
1. Marked 当前没有消费型 strike 数据可验；本批只接独立回合末划伤。
2. 永驻蛊 / 寿元蛊仍不在当前 65 只 lab 池内。
3. 浏览器实机序列尚未在本次环境中重新执行。

GIT
status: modified working tree, pre-existing visual changes remain
commit: NONE
push: NO
```
