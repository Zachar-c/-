# Handoff · Web parity slice 02 · Gu battle

```text
TASK web-parity-slice-02
PHASE Web 全逻辑收敛
STATUS READY_FOR_REVIEW
TYPE implementation
ASK 审阅蛊虫战队与战斗接入；决定下一批战斗效果范围。

GOAL
让已炼化战斗蛊在 Web lab 中可查看、可编队、可催动，同时保持 Godot 现行规则：
全部已炼化战斗蛊可用，没有固定蛊槽或出战数量硬上限。

DELTA
+ js/gu_rules.js：转数质量门禁、真元/念头门禁、条件门禁、效果计划、战斗蛊名单。
+ js/team.js：战队总览页；展示全部可用战斗蛊与当前门槛，只调整展示顺序。
+ tests/gu_rules.test.mjs：5 条规则测试。
~ js/main.js：state.lineup、act.useGu、act.lineupTop、战斗回合重置、效果应用。
~ js/battle.js：战斗页列出全部可用蛊并提供催动按钮。
~ js/describe.js：蛊行动失败原因与条件文案。
~ js/run_rules.js：action_points.gd::per_turn 分档；玩家主动结束回合后再进入敌方回合。
+ tools/build_data.mjs：从 data/gu.json 导出 combat/true_qi_cost/thought_cost/
  low_rank_exception/life_cost/v1_effect，并按 role default 补战斗效果。
~ js/data.js：由 build_data.mjs 重新生成。
~ index.html：新增战队页签与 gu_rules.js / team.js 加载。

RULE
canonical source: scripts/domain/v1_battle_resolver.gd, cultivator_rules.gd,
v1_grammar_pipeline.gd, action_points.gd。
No fixed slot cap was introduced.

VERIFY
tests: node --test tests/run_rules.test.mjs tests/loot_rules.test.mjs tests/gu_rules.test.mjs
result: PASS 17/17
syntax: node --check js/run_rules.js; node --check js/gu_rules.js; node --check js/team.js;
        node --check js/battle.js;
        node --check js/main.js; node --check js/describe.js; node --check tools/build_data.mjs
result: PASS
diff-check: git diff --check -- game/wenzhen-web-lab
result: PASS
Edge/browser: PASS
  team page: 8 combat Gu listed, no slot cap
  battle: Moonlight Gu button enabled
  activation: turn 1 allows Moonlight Gu + Small Light Gu, then explicit end turn
  resources: thought 2/2 -> 0/2, action 0/2 -> 2/2, enemy 7 -> 3
  end turn: enemy attacks, turn 1 -> 2, thought resets to 2/2
  console: 0 errors
server: http://127.0.0.1:4181/wenzhen-web-lab/index.html
        GET 200, listener PID 36376, root served from game/

RISK
1. Marked status is stored and logged, but its end-turn scratch settlement is not yet ported.
2. Sword intent is stored by Gu effects, but sword-specific strike scaling is not yet part
   of this slice.
3. Permanent Gu / life-cost Gu are exported but not present in the current 65-Gu lab pool.

GIT
status: modified working tree, pre-existing visual changes remain
commit: NONE
push: NO

NEXT
1. Port marked settlement and sword-intent strike scaling if the next battle sample needs them.
2. Continue with the next parity slice requested by L0.
```
