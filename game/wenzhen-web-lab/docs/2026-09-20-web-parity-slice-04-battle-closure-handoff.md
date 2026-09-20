# Handoff · Web parity slice 04 · Battle closure

```text
TASK web-parity-slice-04
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把当前 65 只 lab 蛊、5 个杀招和 13 个敌人样本中可见的 V1 战斗规则一次收口。

DELTA
+ js/run_rules.js：marked 划伤、剑意封顶/衰减。
+ js/gu_rules.js：实例化 roster、剑意 strike 加成、封印状态。
~ js/main.js：基础搏斗、sealed 意图与倒计时、杀招配方封印/实例锁、杀招支援与额外伤害、marked 回合末结算。
~ js/main.js：初始持有加入明星蛊；杀招记录每回合使用状态，配方按实例占用，使用后锁住对应实例。
~ js/battle.js：基础搏斗按钮、封印/刻痕/剑意状态展示、杀招配方封印门禁。
~ js/rules.js：seal 意图文案。
~ tools/build_data.mjs：导出 mark scratch 数值；更新机制覆盖清单。
~ js/data.js：重新生成。

VERIFY
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs
result: PASS 23/23
syntax: node --check main/run_rules/gu_rules/battle/team/rules/describe/build_data
result: PASS
generated data: skills transform comparison 0 mismatch / 65
diff-check: git diff --check -- game/wenzhen-web-lab
result: PASS

RISK
1. 当前 65 只 lab 池没有 life-cost / permanent / consume_status / weaken / delay 数据，相关 V1 规则未在本批暴露。
2. 浏览器实机序列尚未在本次环境中重新执行。
3. 工作树包含此前 visual/lab 改动，未 commit / push。

NEXT
1. 若用户扩大 lab 数据池，再补 life-cost / permanent / consume_status 等隐藏通道。
2. 或接下一层页面 parity：完整事件日志、交易、休整移除、存档。
```
