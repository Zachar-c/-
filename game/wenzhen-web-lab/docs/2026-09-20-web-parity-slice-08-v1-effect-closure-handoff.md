# Handoff · Web parity slice 08 · V1 effect closure

```text
TASK web-parity-slice-08
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation

GOAL
把 `data/gu.json` 里剩余四种真实 V1 蛊效果通道接入 Web 战斗：寿元成本、延迟结算、刻痕消费和意图弱化。

DELTA
+ tools/build_data.mjs：将血手印蛊、鬼火蛊、雨蛊、灵感蛊、才华蛊加入 lab 蛊池；覆盖页补四种通道来源。
+ tests/run_rules.test.mjs：覆盖寿元扣减/归零、意图弱化下限、延迟到期回合。
+ tests/rules.test.mjs：覆盖敌方 life_cost 意图文案。
+ tests/gu_rules.test.mjs：覆盖 consume_status 代价前门禁、延迟/消费/弱化 effect plan、特殊蛊生成数据。
~ js/run_rules.js：新增 spendLife / lifeDefeated / weakenedDamage / delayDueTurn。
~ js/gu_rules.js：effectPlan 返回 delayTurns / consumeStatus / intentWeaken；consume_status 无层数时在扣费前拒绝。
~ js/main.js：life_cost 支付后归零立即败北且不执行效果；delay 先付费后登记、到期重放；consume_status 命中后清层；weaken_intent 只压低下一次伤害意图，消费或回合末清零。
~ js/battle.js：战斗 HUD 显示寿元、延迟队列、意图弱化、寿元成本与风险标记。
~ js/describe.js、index.html：补火道/智道文案、状态原因与 HUD 寿元池。
~ js/data.js：重新生成。

VERIFY
data: node tools/build_data.mjs → gu 70 / recipes 6 / killMoves 5 / enemies 14 / nodes 37 / route 12 / shopOffers 28
      唯一漂移：thunder_crown_wolf counter_status="sparked" 尚无规则实现（既有问题）
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs tests/rules.test.mjs tests/shop_rules.test.mjs
result: PASS 39/39
syntax: node --check main / journey / shop_rules / rules / run_rules / battle / describe / gu_rules / build_data → PASS
diff-check: git diff --check -- game/wenzhen-web-lab → PASS
browser: PASS
  delay: 鬼火蛊第 1 回合登记，敌方未立刻掉血；结束回合后第 2 回合结算 3 伤并击杀
  consume: 灵感蛊造 1 层刻痕，雨蛊命中 3 伤后清空刻痕
  weaken: 才华蛊写入意图弱化 2；铁皮山猪 2 点意图被压到 0，玩家气血不变
  life-cost: 寿元 2 时催动血手印蛊，寿元归零、效果不执行、终局归因“寿元耗尽”
  console: 0 error

RISK
1. lab 初始为一转，鬼火/雨蛊/才华蛊/血手印蛊按真实转数门禁不可催动；本批通过规则测试与浏览器 dev-state 战斗序列验证，未给这些蛊增加低转例外。
2. 当前蛊池没有 is_permanent / durability_mode 数据，因此常驻蛊与维持费通道仍未接入。
3. 已接通用 life_cost 意图结算，但当前 14 只 lab 敌人没有 life_cost 意图数据。
4. 工作树包含此前未提交改动，未 commit / push。

NEXT
1. 接入 held_only survivor loot 的 wild 落袋语义。
2. 按 L0 指定范围继续下一批 Web parity；服务型系统与动态难度不进入实现。
```
