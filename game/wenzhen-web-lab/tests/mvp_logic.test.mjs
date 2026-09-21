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

test('run starts with the focused five-gu inventory', () => {
  const run = logic.createRun(content);
  assert.equal(run.hp, 24);
  assert.equal(run.qi, 20);
  assert.equal(run.stones, 6);
  assert.equal(run.owned.moonlight_gu, 1);
  assert.equal(run.owned.small_light_gu, 1);
  assert.equal(run.owned.stone_shell_gu, 1);
  assert.equal(run.owned.vitality_grass_gu, 1);
  assert.equal(run.owned.jade_skin_gu, 1);
});

test('secure trade pays stones and adds two small light gu', () => {
  const result = logic.applyTrade(logic.createRun(content), 'secure', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.stones, 3);
  assert.equal(result.run.owned.small_light_gu, 3);
});

test('sacrifice trade removes stone shell and grants boar gu plus stones', () => {
  const result = logic.applyTrade(logic.createRun(content), 'sacrifice', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.stone_shell_gu, undefined);
  assert.equal(result.run.owned.white_boar_strength_gu, 1);
  assert.equal(result.run.stones, 10);
});

test('debt trade grants moon glow and halves exactly the next battle', () => {
  const traded = logic.applyTrade(logic.createRun(content), 'debt', content);
  assert.equal(traded.ok, true);
  assert.equal(traded.run.owned.moon_glow_gu, 1);
  assert.equal(traded.run.nextBattlePenalty, true);
  const penalized = logic.applyNextBattlePenalty(traded.run);
  assert.equal(penalized.hp, 12);
  assert.equal(penalized.qi, 10);
  assert.equal(penalized.nextBattlePenalty, false);
  const second = logic.applyNextBattlePenalty(penalized);
  assert.equal(second.hp, 12);
  assert.equal(second.qi, 10);
});

test('forge consumes the two ingredients and creates moon glow', () => {
  const result = logic.applyForge(logic.createRun(content), 'forge', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moonlight_gu, undefined);
  assert.equal(result.run.owned.small_light_gu, undefined);
  assert.equal(result.run.owned.moon_glow_gu, 1);
});

test('preserve keeps ingredients and grants three stones', () => {
  const result = logic.applyForge(logic.createRun(content), 'preserve', content);
  assert.equal(result.ok, true);
  assert.equal(result.run.owned.moonlight_gu, 1);
  assert.equal(result.run.owned.small_light_gu, 1);
  assert.equal(result.run.stones, 9);
});

test('a live counter swallows one direct strike and then settles', () => {
  const definition = data.enemies.find((enemy) => enemy.id === 'ridge_hound');
  const enemy = logic.createEnemy(definition);
  enemy.revealed = true;

  const first = logic.resolveDirectStrike(definition, enemy, { damage: 5 });
  assert.equal(first.swallowed, true);
  assert.equal(first.damage, 0);
  assert.equal(first.enemy.hp, enemy.hp);
  assert.equal(first.enemy.reactionSettled, true);

  const second = logic.resolveDirectStrike(definition, first.enemy, { damage: 5 });
  assert.equal(second.swallowed, false);
  assert.equal(second.damage, 5);
  assert.equal(second.enemy.hp, 0);
});

test('moon glow bypasses and suppresses the counter', () => {
  const definition = data.enemies.find((enemy) => enemy.id === 'iron_hide_boar');
  const enemy = logic.createEnemy(definition);
  const result = logic.resolveDirectStrike(definition, enemy, {
    damage: 4,
    bypassReaction: true,
    suppressReaction: true,
  });
  assert.equal(result.swallowed, false);
  assert.equal(result.damage, 4);
  assert.equal(result.enemy.reactionSuppressed, 2);
  assert.equal(logic.reactionState(definition, result.enemy).live, false);
});

test('thunder sovereign changes phase at half health and burns essence', () => {
  const definition = data.enemies.find((enemy) => enemy.id === 'thunder_crown_sovereign');
  const enemy = logic.createEnemy(definition);
  enemy.hp = 9;
  const synced = logic.syncIntent(definition, enemy, 1);
  assert.equal(synced.phase.index, 1);
  assert.equal(synced.enemy.currentIntent.id, 'crown_bolt');

  const player = { hp: 20, qi: 10, block: 0 };
  const resolved = logic.resolveEnemyIntent(enemy, { essence_burn: 2 }, player);
  assert.equal(resolved.qi ?? resolved.player.qi, 8);
  assert.equal(resolved.essenceBurn, 2);
});
