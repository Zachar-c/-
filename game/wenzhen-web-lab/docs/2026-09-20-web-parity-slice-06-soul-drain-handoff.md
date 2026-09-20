# Handoff · Web parity slice 06 · Soul drain

```text
TASK web-parity-slice-06
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
补上现有敌人数据中的 soul_drain 意图与魂魄归零死亡。

DELTA
+ js/main.js：敌方回合结算抽魂；魂魄归零结束战斗；结局显示“魂魄耗尽”。
+ js/run_rules.js：魂魄扣减与归零判定。
+ js/rules.js：意图预览显示“抽魂 N”。
~ js/battle.js：敌人列表预览改为统一走 intentText，避免抽魂显示成伤害 0。
~ tools/build_data.mjs：将 demon_path_adept 纳入 65 只蛊 lab 可演武敌人；更新机制覆盖清单。
~ js/data.js：重新生成。
+ tests/run_rules.test.mjs / tests/rules.test.mjs：覆盖抽魂下限、死亡信号和意图文案。

VERIFY
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs tests/rules.test.mjs
syntax: node --check js/main.js js/rules.js js/run_rules.js
browser: PASS；魔道蛊师预览“噬魂魔功（抽魂 1）”，结束回合后魂魄 1 → 0，终局归因“魂魄耗尽”，控制台 0 error

RISK
1. 仍只覆盖 soul_drain，不覆盖魂魄收集、成长、狂暴与失控。
2. Web 初始魂魄为 1，魔道蛊师一次抽魂即会触发死亡，这是当前 Godot 规则的直接结果。
3. 工作树包含此前未提交改动，未 commit / push。

NEXT
1. 待 lab 数据池出现对应蛊后，再接 weaken_intent、delay、consume_status 等通道。
2. 或继续处理非战斗系统的领域接线。
```
