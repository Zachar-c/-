import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
const load = (relativePath) => vm.runInContext(
  fs.readFileSync(new URL(relativePath, import.meta.url), 'utf8'),
  context,
  { filename: relativePath },
);

load('../js/mvp_content.js');
load('../js/mvp_logic.js');
load('../js/data.js');
vm.runInContext('globalThis.__DATA = DATA;', context);

const content = context.MVP_CONTENT;
const logic = context.MvpLogic;
const data = context.__DATA;

test('run starts with persistent 24 hp and 12 essence', () => {
  const run = logic.createRun(content);
  assert.equal(run.hp, 24);
  assert.equal(run.qi, 12);
  assert.equal(run.qiMax, 12);
  assert.equal(run.stones, 3);
  assert.equal(run.owned.small_light_gu, 1);
});

test('stones can be smelted into essence outside battle', () => {
  const run = logic.createRun(content);
  run.qi = 8;
  const result = logic.smeltStone(run);
  assert.equal(result.ok, true);
  assert.equal(result.run.stones, 2);
  assert.equal(result.run.qi, 10);
});

test('secure trade spends future essence and adds two small light gu', () => {
  const result = logic.applyTrade(logic.createRun(content), 'secure', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.stones, 0);
  assert.equal(result.run.owned.small_light_gu, 3);
});

test('sacrifice trade removes stone shell and grants boar plus stones', () => {
  const result = logic.applyTrade(logic.createRun(content), 'sacrifice', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.stone_shell_gu, undefined);
  assert.equal(result.run.owned.white_boar_strength_gu, 1);
  assert.equal(result.run.stones, 7);
});

test('debt trade permanently lowers essence cap to eight', () => {
  const result = logic.applyTrade(logic.createRun(content), 'debt', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moon_glow_gu, 1);
  assert.equal(result.run.qiMax, 8);
  assert.equal(result.run.qi, 8);
  assert.equal(result.run.borrowedMoon, true);
});

test('forge consumes moon, small light and two essence to create moon glow', () => {
  const result = logic.applyForge(logic.createRun(content), 'forge', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moonlight_gu, undefined);
  assert.equal(result.run.owned.small_light_gu, undefined);
  assert.equal(result.run.owned.moon_glow_gu, 1);
  assert.equal(result.run.qi, 10);
});

test('forging after borrowing moon repays the cap debt instead of duplicating it', () => {
  const borrowed = logic.applyTrade(logic.createRun(content), 'debt', content).run;
  const result = logic.applyForge(borrowed, 'forge', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moon_glow_gu, 1);
  assert.equal(result.run.qiMax, 12);
  assert.equal(result.run.borrowedMoon, false);
  assert.equal(result.run.forgeChoice, 'repay');
});

test('preserve keeps ingredients and grants three stones', () => {
  const result = logic.applyForge(logic.createRun(content), 'preserve', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moonlight_gu, 1);
  assert.equal(result.run.stones, 6);
});

test('hound exposes a hidden counter and observation reveals it', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  const started = logic.startTurn(content, enemy, 1, 101).enemy;
  assert.ok(['intercept', 'draw_light'].includes(started.currentCounter));
  assert.equal(started.revealed, false);
  const revealed = logic.revealCounter(started);
  assert.equal(revealed.revealed, true);
  assert.ok(logic.counterRule(content, revealed.currentCounter).detail);
});

test('intercept keeps swallowing every direct attack in the round', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  const first = logic.resolveDirectStrike(enemy, { damage: 4 });
  const second = logic.resolveDirectStrike(first.enemy, { damage: 4 });
  assert.equal(first.swallowed, true);
  assert.equal(second.swallowed, true);
  assert.equal(second.selfDamage, 2);
  assert.equal(second.enemy.hp, 10);
});

test('iron keeps swallowing attacks and increases the next charge', () => {
  const enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy.currentCounter = 'iron';
  const first = logic.resolveDirectStrike(enemy, { damage: 5 });
  const second = logic.resolveDirectStrike(first.enemy, { damage: 5 });
  assert.equal(second.swallowed, true);
  assert.equal(second.enemy.ironRage, 2);
  assert.equal(second.enemy.hp, 15);
});

test('draw light adds three damage when no light gu was used', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'draw_light';
  const failed = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
    usedLight: false,
  });
  const passed = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
    usedLight: true,
  });
  assert.equal(failed.damage, 7);
  assert.equal(passed.damage, 4);
});

test('stone shell breaks the next charge counter', () => {
  const enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy.currentCounter = 'iron';
  const result = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 5 }, {
    intent: { damage: 5, tag: 'charge' },
    stoneShellUsed: true,
  });
  assert.equal(result.enemy.counterBroken, true);
});

test('moon glow suppression bypasses the counter and lowers enemy damage by three', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  enemy.revealed = true;
  const hit = logic.resolveDirectStrike(enemy, {
    damage: 4,
    bypassCounter: true,
    suppressCounter: true,
  });
  assert.equal(hit.swallowed, false);
  assert.equal(hit.enemy.hp, 6);
  const resolved = logic.resolveEnemyAction(hit.enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4 },
  });
  assert.equal(resolved.damage, 1);
});

test('seal target follows first or last action order', () => {
  assert.equal(logic.sealTarget('seal_first', ['moonlight_gu', 'stone_shell_gu']), 'moonlight_gu');
  assert.equal(logic.sealTarget('seal_last', ['moonlight_gu', 'stone_shell_gu']), 'stone_shell_gu');
});

test('boss phase changes at fourteen hp and burns three essence', () => {
  const enemy = logic.createEnemy(content, 'thunder_crown_sovereign');
  enemy.hp = 14;
  const started = logic.startTurn(content, enemy, 2, 101).enemy;
  assert.equal(logic.phaseIndexFor(content, started), 1);
  const result = logic.resolveEnemyAction(started, { hp: 24, qi: 9, block: 0 }, {
    intent: { kind: 'burn_qi', burnQi: 3, damage: 0 },
  });
  assert.equal(result.player.qi, 6);
});

test('battle reward uses the real tier table', () => {
  assert.equal(logic.battleReward(data, 'ridge_hound'), 3);
  assert.equal(logic.battleReward(data, 'ridge_elite_scout'), 8);
  assert.equal(logic.battleReward(data, 'thunder_crown_sovereign'), 15);
});

test('light support is applied before the support charge is spent', () => {
  const values = logic.actionValues(content.actions.moonlight_gu, 1);
  assert.equal(values.qi, 0);
  assert.equal(values.damage, 3);
});

test('battle screen exposes both known and unknown intelligence', () => {
  const source = fs.readFileSync(new URL('../js/mvp.js', import.meta.url), 'utf8');
  assert.match(source, /<dt>已知弱点<\/dt>\s*<dd>\$\{esc\(intel\.known\)\}<\/dd>/);
  assert.match(source, /<dt>未察信息<\/dt>\s*<dd>\$\{esc\(intel\.unknown\)\}<\/dd>/);
});

/* ------------------------------------------------------------------
   V4（2026-09-21 L1 裁决）
   1. 反制第一次观察后，本场永久识别（不再每回合重新隐藏）
   2. 正确处理当前反制 → 本次敌方伤害 -3 并取消意图附带的特殊效果，下限 0
   3. 普通战胜利 → +2 气血 / +2 真元
   ------------------------------------------------------------------ */

test('a counter type stays identified for the rest of the battle after one observation', () => {
  // 山猪的 charge 意图固定带 iron 反制，用它验证「观察一次即永久识别」
  let enemy = logic.createEnemy(content, 'iron_hide_boar');
  enemy = logic.startTurn(content, enemy, 1, 101).enemy;
  assert.equal(enemy.currentCounter, 'iron');
  assert.equal(enemy.revealed, false, '第一次遇到仍未识破');

  enemy = logic.revealCounter(enemy);
  // vm 里的数组来自另一个 realm，deepStrictEqual 会因原型不同而失败，先转成本 realm 的数组
  assert.deepEqual(Array.from(enemy.knownCounters), ['iron']);

  enemy = logic.finishEnemyAction(enemy);
  enemy = logic.startTurn(content, enemy, 3, 101).enemy;   // 第 3 回合又是 iron
  assert.equal(enemy.currentCounter, 'iron');
  assert.equal(enemy.revealed, true, '同一反制类型本场永久识别，不再收第二次念头税');
});

test('an unidentified counter grants no mitigation even when the action happens to match', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  enemy.revealed = false;
  const resolved = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.handled, false);
  assert.equal(resolved.damage, 4, '没读信息就不该白拿减伤');
});

test('handling an identified counter cuts the enemy action by three', () => {
  const hound = logic.createEnemy(content, 'ridge_hound');
  hound.currentCounter = 'intercept';
  hound.revealed = true;

  const withheld = logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(withheld.handled, true);
  assert.equal(withheld.damage, 1, '读对 + 做对：4 → 1');

  const greedy = logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: true,
  });
  assert.equal(greedy.handled, false);
  assert.equal(greedy.damage, 4, '读对但硬打：照样吃满');
});

test('handling an identified draw-light counter removes the bonus and then cuts three', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'draw_light';
  enemy.revealed = true;

  const ok = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    usedLight: true,
  });
  assert.equal(ok.damage, 1);

  const bad = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    usedLight: false,
  });
  assert.equal(bad.damage, 7, '未处理：4 + 3');
});

test('mitigation never drives the enemy action below zero', () => {
  const enemy = logic.createEnemy(content, 'ridge_hound');
  enemy.currentCounter = 'intercept';
  enemy.revealed = true;
  const resolved = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 2, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.damage, 0);
});

test('handling a seal counter cancels the seal special effect', () => {
  const enemy = logic.createEnemy(content, 'ridge_elite_scout');
  enemy.currentCounter = 'seal_first';
  enemy.revealed = true;

  const handled = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'seal', damage: 0 },
    guUsedCount: 0,
  });
  assert.equal(handled.handled, true);
  assert.equal(handled.specialCancelled, true);

  const played = logic.resolveEnemyAction(enemy, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'seal', damage: 0 },
    guUsedCount: 2,
  });
  assert.equal(played.handled, false);
  assert.equal(played.specialCancelled, false);
});

/* 记录 V4 的一处结构性缺口（不是实现错误，是冻结表与 content 的落差）：
   悍客的伤害意图 crossbow_shot 与狼王二阶段 thunder_pounce_2 都没有 counterPool，
   因此按「正确处理反制 → -3」的统一规则，这两处伤害天生不可减免。
   L1 期望的「悍客 1 / 狼王重击 2~3」需要先给这两个意图补反制才能达成，
   属数值/内容判定，已上抛，不在此处自行补。 */
test('V4 accepted gap: intents without a counter cannot be mitigated', () => {
  const elite = logic.createEnemy(content, 'ridge_elite_scout');
  elite.currentCounter = '';
  const resolved = logic.resolveEnemyAction(elite, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' },
    attacked: false,
  });
  assert.equal(resolved.handled, false);
  assert.equal(resolved.damage, 4);

  const drained = logic.resolveEnemyAction(elite, { hp: 24, qi: 12, block: 0 }, {
    intent: { kind: 'drain_qi', drainQi: 3, damage: 0 },
    guUsedCount: 0,
  });
  assert.equal(drained.handled, false);
  assert.equal(drained.player.qi, 9, '无反制的意图无法取消，噬元照扣');
});

test('V4 expected damage after correct handling matches the ruling table', () => {
  // 猎犬 4 → 1
  const hound = logic.createEnemy(content, 'ridge_hound');
  hound.currentCounter = 'intercept';
  hound.revealed = true;
  assert.equal(logic.resolveEnemyAction(hound, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 4, tag: 'charge' }, attacked: false,
  }).damage, 1);

  // 山猪 5 → 2（石皮破铁皮）
  const boar = logic.createEnemy(content, 'iron_hide_boar');
  boar.currentCounter = 'iron';
  boar.revealed = true;
  assert.equal(logic.resolveEnemyAction(boar, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 5, tag: 'charge' }, stoneShellUsed: true,
  }).damage, 2);

  // 狼王 5 → 2
  const boss = logic.createEnemy(content, 'thunder_crown_sovereign');
  boss.currentCounter = 'intercept';
  boss.revealed = true;
  assert.equal(logic.resolveEnemyAction(boss, { hp: 24, qi: 12, block: 0 }, {
    intent: { damage: 5, tag: 'charge' }, attacked: false,
  }).damage, 2);
});

test('V4 frozen enemy hp and damage table', () => {
  assert.equal(logic.profileFor(content, 'ridge_hound').hp, 10);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').hp, 15);
  assert.equal(logic.profileFor(content, 'ridge_elite_scout').hp, 18);
  const boss = logic.profileFor(content, 'thunder_crown_sovereign');
  assert.equal(boss.hp, 28);

  assert.equal(logic.profileFor(content, 'ridge_hound').intents[0].damage, 4);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').intents[0].damage, 5);
  assert.equal(logic.profileFor(content, 'iron_hide_boar').intents[2].damage, 6);
  assert.equal(logic.profileFor(content, 'ridge_elite_scout').intents[2].damage, 4);
  assert.equal(boss.phaseOne[0].damage, 5);
  assert.equal(boss.phaseTwo[1].damage, 6);
});

test('a won battle restores two health and two essence without exceeding caps', () => {
  const run = logic.createRun(content);
  run.hp = 8;
  run.qi = 7;
  const after = logic.applyVictoryRecovery(run);
  assert.equal(after.hp, 10);
  assert.equal(after.qi, 9);

  run.hp = 23;
  run.qi = 12;
  const capped = logic.applyVictoryRecovery(run);
  assert.equal(capped.hp, 24);
  assert.equal(capped.qi, 12);
});
