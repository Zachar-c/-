import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(readFileSync(new URL('../js/human_rules.js', import.meta.url), 'utf8'), context);
const HumanRules = context.HumanRules;

test('RULE_TEST: unmodified rank 1 and rank 5 humans share non-essence attributes', () => {
  const first = HumanRules.actor({ id: 'first', rank: 1 });
  const fifth = HumanRules.actor({ id: 'fifth', rank: 5 });
  for (const attr of ['hpMax', 'soulMax', 'thoughtMax', 'defense', 'attack']) {
    assert.equal(HumanRules.attribute(first, attr), HumanRules.attribute(fifth, attr), attr);
  }
  assert.equal(HumanRules.attribute(first, 'hpMax'), 10);
  assert.equal(HumanRules.attribute(first, 'essenceMax'), 6);
  assert.equal(HumanRules.attribute(fifth, 'essenceMax'), 14);
});

test('RULE_TEST: permanent change survives source Gu sale while maintained protection stops', () => {
  const boar = HumanRules.guInstance('white_boar_strength_gu', 1);
  const stone = HumanRules.guInstance('stone_shell_gu', 1);
  const human = HumanRules.actor({ id: 'cultivator', guInstances: [boar, stone] });
  HumanRules.addModifier(human, {
    attribute: 'attack', amount: 1, sourceGuDefinitionId: boar.definitionId,
    sourceGuInstanceId: boar.instanceId, sourceEffectId: 'strength_stage_1',
    persistence: 'session_permanent', createdAt: 1,
  });
  const activation = HumanRules.startMaintained(human, stone.instanceId, {
    startCost: 3, upkeepCost: 2, turn: 1,
    modifiers: [
      { attribute: 'defense', amount: 1, sourceEffectId: 'stone_defense' },
      { attribute: 'attack', amount: -1, sourceEffectId: 'stone_slow' },
    ],
  });
  assert.equal(activation.ok, true);
  assert.equal(human.essence, 3);
  assert.equal(HumanRules.attribute(human, 'attack'), 3);
  assert.equal(HumanRules.attribute(human, 'defense'), 1);

  HumanRules.dispose(human, boar.instanceId, 'sold');
  assert.equal(HumanRules.attribute(human, 'attack'), 3);
  HumanRules.seal(human, stone.instanceId);
  assert.equal(HumanRules.attribute(human, 'attack'), 4);
  assert.equal(HumanRules.attribute(human, 'defense'), 0);
  assert.equal(human.modifierLedger.filter((entry) => entry.removalReason === 'sealed').length, 2);
});

test('RULE_TEST: pre-activated Gu pays startup and upkeep, then drops when essence is insufficient', () => {
  const stone = HumanRules.guInstance('stone_shell_gu', 1);
  const human = HumanRules.actor({ id: 'stone', guInstances: [stone] });
  HumanRules.startMaintained(human, stone.instanceId, {
    startCost: 3, upkeepCost: 2, turn: 0,
    modifiers: [{ attribute: 'defense', amount: 1, sourceEffectId: 'stone_defense' }],
  });
  assert.equal(human.essence, 3);
  assert.equal(HumanRules.upkeep(human)[0].ok, true);
  assert.equal(human.essence, 1);
  assert.equal(HumanRules.attribute(human, 'defense'), 1);
  assert.equal(HumanRules.upkeep(human)[0].reason, 'insufficient_essence');
  assert.equal(HumanRules.attribute(human, 'defense'), 0);
  assert.equal(human.essence, 1);
});

test('RULE_TEST: current HP preserves missing damage across maximum change', () => {
  assert.equal(HumanRules.adjustedHp(7, 10, 12), 9);
  assert.equal(HumanRules.adjustedHp(7, 10, 8), 5);
});
