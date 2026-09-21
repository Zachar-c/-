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
