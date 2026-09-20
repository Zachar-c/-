import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(source, context);
const rules = context.RunRules;

test('battle regen uses the domain ceiling percentage', () => {
  assert.equal(rules.ceilPct(10, 25), 3);
  assert.equal(rules.ceilPct(20, 25), 5);
  assert.equal(rules.battleRegen(10, 25), 3);
});

test('per-turn thoughts follow the soul action-point tiers', () => {
  assert.equal(rules.actionPointsPerTurn(1), 2);
  assert.equal(rules.actionPointsPerTurn(9), 2);
  assert.equal(rules.actionPointsPerTurn(10), 3);
  assert.equal(rules.actionPointsPerTurn(1000), 5);
  assert.equal(rules.actionPointsPerTurn(10000), 6);
});

test('sword intent caps at five and decays by half each turn', () => {
  assert.equal(rules.addSwordIntent(0, 3), 3);
  assert.equal(rules.addSwordIntent(3, 3), 5);
  assert.equal(rules.addSwordIntent(5, 1), 5);
  assert.equal(rules.decaySwordIntent(5), 2);
  assert.equal(rules.decaySwordIntent(2), 1);
  assert.equal(rules.decaySwordIntent(1), 0);
});

test('marked scratch damage ignores shield and respects the layer cap', () => {
  assert.equal(rules.markScratchDamage(3, 1, 10), 3);
  assert.equal(rules.markScratchDamage(99, 1, 10), 10);
  assert.equal(rules.markScratchDamage(3, 2, 10), 6);
});

test('soul drain floors at zero and raises the death signal', () => {
  assert.equal(rules.drainSoul(4, 1), 3);
  assert.equal(rules.drainSoul(1, 1), 0);
  assert.equal(rules.drainSoul(1, 9), 0);
  assert.equal(rules.soulDefeated(1), false);
  assert.equal(rules.soulDefeated(0), true);
});

test('life cost floors at zero and raises the death signal', () => {
  assert.equal(rules.spendLife(5, 2), 3);
  assert.equal(rules.spendLife(1, 2), 0);
  assert.equal(rules.lifeDefeated(1), false);
  assert.equal(rules.lifeDefeated(0), true);
});

test('weakened damage only reduces the current intent and never goes below zero', () => {
  assert.equal(rules.weakenedDamage(5, 2), 3);
  assert.equal(rules.weakenedDamage(2, 5), 0);
});

test('delayed effects become due after the declared number of turns', () => {
  assert.equal(rules.delayDueTurn(1, 1), 2);
  assert.equal(rules.delayDueTurn(3, 2), 5);
  assert.equal(rules.delayDueTurn(3, 0), 4);
});

test('rest heal restores thirty percent of max health and two essence', () => {
  const partial = rules.restHeal({ health: 1, maxHealth: 100, essence: 1, essenceMax: 20 });
  assert.equal(partial.health, 31);
  assert.equal(partial.essence, 3);
  const capped = rules.restHeal({ health: 90, maxHealth: 100, essence: 20, essenceMax: 20 });
  assert.equal(capped.health, 100);
  assert.equal(capped.essence, 20);
  assert.equal(
    rules.restHeal({ health: 0, maxHealth: 1, essence: 0, essenceMax: 1 }).health,
    1,
  );
});

test('seeded index follows the Godot LCG stream', () => {
  assert.equal(rules.seededIndex(100, 1, 'recipe', 0), 72);
  assert.equal(rules.seededIndex(100, 1, 'recipe', 1), 58);
  assert.equal(rules.seededIndex(100, 12345, 'moonlight', 7), 57);
  assert.equal(rules.refinementRoll(1, 'recipe', 0), 73);
});

test('refinement succeeds at or below the recipe roll cap', () => {
  assert.equal(rules.refinementSucceeds(50, { successRollMax: 50 }), true);
  assert.equal(rules.refinementSucceeds(51, { successRollMax: 50 }), false);
  assert.equal(rules.refinementSucceeds(100, {}), true);
});

test('battle stone rewards use tier base plus layer scaling', () => {
  const config = {
    base_by_tier: { common: 3, elite: 8, boss: 15 },
    layer_step_pct: 20,
  };
  assert.equal(
    rules.resolveBattleTier([{ tier: 'common' }, { tier: 'elite' }, { tier: 'boss' }]),
    'boss',
  );
  assert.equal(
    rules.resolveBattleTier([{ tier: 'common' }, { tier: 'elite' }]),
    'elite',
  );
  assert.equal(rules.resolveBattleTier([{ tier: 'common' }]), 'common');
  assert.equal(rules.battleStoneReward('common', 1, config), 3);
  assert.equal(rules.battleStoneReward('elite', 2, config), 9);
  assert.equal(rules.battleStoneReward('boss', 3, config), 21);
  assert.equal(rules.battleStoneReward('unknown', 5, config), 0);
});

test('essence max follows aptitude and cultivation factors', () => {
  const data = {
    essenceBase: 10,
    aptitudeFactor: { bing: 2 },
    cultivationFactor: { 1: 1, 2: 3, 3: 9 },
  };
  assert.equal(rules.essenceMax(1, 'bing', data), 20);
  assert.equal(rules.essenceMax(2, 'bing', data), 60);
  assert.equal(rules.essenceMax(3, 'bing', data), 180);
});

test('breakthrough advances one rank and charges the configured cost', () => {
  const costs = { 2: 5, 3: 12 };
  assert.equal(rules.nextBreakthrough(1, 5, costs).targetRank, 2);
  assert.equal(rules.nextBreakthrough(1, 4, costs).ok, false);
  assert.equal(rules.nextBreakthrough(2, 12, costs).targetRank, 3);
  assert.equal(rules.nextBreakthrough(5, 30, costs).ok, false);
});
