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

test('RULE_TEST: maintained stone shell blocks hits freely and temporary modifiers clear on stop or seal', () => {
  for (const release of ['stop', 'seal']) {
    const boar = HumanRules.guInstance('white_boar_strength_gu', 1);
    const stone = HumanRules.guInstance('stone_shell_gu', 1);
    const human = HumanRules.actor({ id: release, guInstances: [boar, stone] });
    const activation = HumanRules.startMaintained(human, stone.instanceId, {
      startCost: 1, upkeepCost: 0, hitCost: 0, turn: 1,
      modifiers: [
        { attribute: 'defense', amount: 3, sourceEffectId: 'stone_defense' },
        { attribute: 'attack', amount: 1, sourceEffectId: 'stone_attack' },
        { attribute: 'attackDelay', amount: 1, sourceEffectId: 'stone_delay' },
      ],
    });
    assert.equal(activation.ok, true);
    assert.equal(human.essence, 5);
    assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.basicStrikePlan(human))), { damage: 4, delayTurns: 1 });
    for (let turn = 0; turn < 3; turn++) {
      assert.equal(HumanRules.receiveHit(human, 5).damage, 2);
      assert.equal(human.essence, 5);
    }

    HumanRules.addModifier(human, {
      attribute: 'attack', amount: 1, sourceGuDefinitionId: boar.definitionId,
      sourceGuInstanceId: boar.instanceId, sourceEffectId: 'strength_stage_1',
      persistence: 'session_permanent', createdAt: 2,
    });
    if (release === 'stop') HumanRules.stopMaintained(human, stone.instanceId, 'stopped');
    else HumanRules.seal(human, stone.instanceId);
    assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.basicStrikePlan(human))), { damage: 4, delayTurns: 0 });
    assert.equal(HumanRules.attribute(human, 'defense'), 0);
    assert.equal(human.modifierLedger.filter((entry) => entry.sourceGuInstanceId === stone.instanceId && !entry.active).length, 3);
  }
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

test('RULE_TEST: maintained Gu reserves control capacity and each refresh restores the remaining budget', () => {
  const jade = HumanRules.guInstance('jade_skin_gu', 1);
  const stone = HumanRules.guInstance('stone_shell_gu', 1);
  const human = HumanRules.actor({ id: 'control', guInstances: [jade, stone] });
  assert.equal(HumanRules.controlCapacity(human), 3);
  assert.equal(HumanRules.refreshControl(human), 3);

  HumanRules.startMaintained(human, jade.instanceId, { startCost: 0, upkeepCost: 0, focusCost: 1 });
  assert.equal(human.maintainedGu[0].focusCost, 1);
  assert.equal(HumanRules.refreshControl(human), 2);
  human.thought = 0;
  assert.equal(HumanRules.refreshControl(human), 2);
  human.thought = 0;
  assert.equal(HumanRules.refreshControl(human), 2);

  HumanRules.startMaintained(human, stone.instanceId, { startCost: 0, upkeepCost: 0 });
  assert.equal(human.maintainedGu[1].focusCost, 0);
  assert.equal(HumanRules.controlCapacity(human), 2);
  const reloaded = JSON.parse(JSON.stringify(human));
  assert.equal(HumanRules.refreshControl(reloaded), 2);

  HumanRules.seal(human, jade.instanceId);
  assert.equal(HumanRules.refreshControl(human), 3);
  HumanRules.stopMaintained(human, stone.instanceId, 'stopped');
  assert.equal(HumanRules.refreshControl(human), 3);
});

test('RULE_TEST: maintenance drop releases its control reservation after insufficient upkeep', () => {
  const jade = HumanRules.guInstance('jade_skin_gu', 1);
  const human = HumanRules.actor({ id: 'control', guInstances: [jade] });
  HumanRules.startMaintained(human, jade.instanceId, { startCost: 0, upkeepCost: 7, focusCost: 1 });
  assert.equal(HumanRules.refreshControl(human), 2);
  human.essence = 0;
  assert.equal(HumanRules.upkeep(human)[0].reason, 'insufficient_essence');
  assert.equal(human.maintainedGu[0].active, false);
  assert.equal(HumanRules.refreshControl(human), 3);
});

test('RULE_TEST: maintained focus cost must be a nonnegative integer', () => {
  const jade = HumanRules.guInstance('jade_skin_gu', 1);
  const human = HumanRules.actor({ id: 'control', guInstances: [jade] });
  for (const focusCost of [-1, 1.5, 'invalid']) {
    assert.throws(() => HumanRules.startMaintained(human, jade.instanceId,
      { startCost: 0, upkeepCost: 0, focusCost }), /invalid maintenance cost/);
    assert.equal(human.maintainedGu.length, 0);
  }
});

test('RULE_TEST: maintained defense charges per damaging hit and loses defense when a hit is unaffordable', () => {
  const shell = HumanRules.guInstance('shell', 1);
  const human = HumanRules.actor({ id: 'shell', guInstances: [shell] });
  HumanRules.startMaintained(human, shell.instanceId, {
    startCost: 0, upkeepCost: 0, hitCost: 2,
    modifiers: [{ attribute: 'defense', amount: 3, sourceEffectId: 'shell_defense' }],
  });
  assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.receiveHit(human, 2))), {
    damage: 0, absorbed: 2, events: [{ instanceId: shell.instanceId, ok: true, cost: 2 }],
  });
  assert.equal(human.essence, 4);
  HumanRules.receiveHit(human, 1);
  assert.equal(human.essence, 2);
  human.essence = 1;
  assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.receiveHit(human, 4))), {
    damage: 4, absorbed: 0,
    events: [{ instanceId: shell.instanceId, ok: false, reason: 'insufficient_essence' }],
  });
  assert.equal(HumanRules.attribute(human, 'defense'), 0);
  assert.equal(human.maintainedGu[0].removalReason, 'insufficient_essence');
});

test('RULE_TEST: zero damage costs nothing and ordinary maintained defense remains free', () => {
  const paid = HumanRules.guInstance('paid_shell', 1);
  const free = HumanRules.guInstance('free_shell', 1);
  const human = HumanRules.actor({ id: 'shells', guInstances: [paid, free] });
  HumanRules.startMaintained(human, paid.instanceId, {
    startCost: 0, upkeepCost: 0, hitCost: 2,
    modifiers: [{ attribute: 'defense', amount: 1, sourceEffectId: 'paid_defense' }],
  });
  HumanRules.startMaintained(human, free.instanceId, {
    startCost: 0, upkeepCost: 0,
    modifiers: [{ attribute: 'defense', amount: 2, sourceEffectId: 'free_defense' }],
  });
  assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.receiveHit(human, 0))), {
    damage: 0, absorbed: 0, events: [],
  });
  assert.equal(human.essence, 6);
  assert.equal(HumanRules.receiveHit(human, 1).damage, 0);
  assert.equal(human.essence, 4);
});

test('RULE_TEST: defense groups exclude overlap and become available after stop or seal', () => {
  const first = HumanRules.guInstance('shell', 1);
  const second = HumanRules.guInstance('shell', 2);
  const human = HumanRules.actor({ id: 'shells', guInstances: [first, second] });
  const params = { startCost: 0, upkeepCost: 0, hitCost: 1, defenseGroup: 'shell', modifiers: [] };
  assert.equal(HumanRules.startMaintained(human, first.instanceId, params).ok, true);
  assert.equal(HumanRules.startMaintained(human, second.instanceId, params).reason, 'defense_group_active');
  assert.equal(human.maintainedGu[0].hitCost, 1);
  assert.equal(human.maintainedGu[0].defenseGroup, 'shell');
  HumanRules.stopMaintained(human, first.instanceId, 'stopped');
  assert.equal(HumanRules.startMaintained(human, second.instanceId, params).ok, true);
  assert.equal(HumanRules.seal(human, second.instanceId), true);
  assert.equal(human.maintainedGu[1].active, false);
  const third = HumanRules.guInstance('shell', 3);
  human.guInstances.push(third);
  assert.equal(HumanRules.startMaintained(human, third.instanceId, params).ok, true);
  third.sealed = true;
  assert.deepEqual(JSON.parse(JSON.stringify(HumanRules.receiveHit(human, 1))), {
    damage: 1, absorbed: 0,
    events: [{ instanceId: third.instanceId, ok: false, reason: 'gu_unavailable' }],
  });
  assert.equal(human.maintainedGu[2].active, false);
});

test('RULE_TEST: body training is visit-limited and shares its permanent cap across Gu instances', () => {
  const boar = HumanRules.guInstance('white_boar_strength_gu', 1);
  const human = HumanRules.actor({ id: 'boar', guInstances: [boar] });
  const params = { attribute: 'attack', step: 1, cap: 3, cost: 1 };
  for (const visitId of ['visit-1', 'visit-2', 'visit-3']) {
    const result = HumanRules.trainBody(human, boar.instanceId, { ...params, visitId });
    assert.deepEqual({ ok: result.ok, reason: result.reason, cost: result.cost, gained: result.gained, total: result.total },
      { ok: true, reason: null, cost: 1, gained: 1, total: Number(visitId.at(-1)) });
  }
  assert.equal(human.essence, 3);
  assert.equal(HumanRules.attribute(human, 'attack'), 6);
  const before = JSON.stringify({ essence: human.essence, ledger: human.modifierLedger });
  assert.equal(HumanRules.trainBody(human, boar.instanceId, { ...params, visitId: 'visit-4' }).reason, 'cap_reached');
  assert.equal(JSON.stringify({ essence: human.essence, ledger: human.modifierLedger }), before);

  HumanRules.dispose(human, boar.instanceId, 'sold');
  const replacement = HumanRules.guInstance(boar.definitionId, 2);
  human.guInstances.push(replacement);
  assert.equal(HumanRules.trainBody(human, replacement.instanceId, { ...params, visitId: 'visit-4' }).reason, 'cap_reached');
  assert.equal(HumanRules.attribute(human, 'attack'), 6);
  assert.equal(human.essence, 3);
});

test('RULE_TEST: body training rejects repeated visits, insufficient essence, sealed Gu, and missing Gu without mutation', () => {
  const first = HumanRules.guInstance('white_boar_strength_gu', 1);
  const second = HumanRules.guInstance('white_boar_strength_gu', 2);
  const sealed = HumanRules.guInstance('white_boar_strength_gu', 3);
  const human = HumanRules.actor({ id: 'boar', guInstances: [first, second, sealed] });
  const params = { step: 1, cap: 3, cost: 1 };
  assert.equal(HumanRules.trainBody(human, first.instanceId, { ...params, visitId: 'same' }).ok, true);
  const snapshot = () => JSON.stringify({ essence: human.essence, ledger: human.modifierLedger });
  let before = snapshot();
  assert.equal(HumanRules.trainBody(human, second.instanceId, { ...params, visitId: 'same' }).reason, 'repeated_visit');
  assert.equal(HumanRules.trainBody(human, second.instanceId,
    { ...params, attribute: 'defense', visitId: 'same' }).reason, 'repeated_visit');
  assert.equal(snapshot(), before);
  human.essence = 0;
  before = snapshot();
  assert.equal(HumanRules.trainBody(human, second.instanceId, { ...params, visitId: 'poor' }).reason, 'insufficient_essence');
  assert.equal(snapshot(), before);
  human.essence = 6;
  HumanRules.seal(human, sealed.instanceId);
  before = snapshot();
  assert.equal(HumanRules.trainBody(human, sealed.instanceId, { ...params, visitId: 'sealed' }).reason, 'gu_unavailable');
  assert.equal(HumanRules.trainBody(human, 'missing::1', { ...params, visitId: 'missing' }).reason, 'gu_unavailable');
  assert.equal(snapshot(), before);
});

test('RULE_TEST: body training rejects non-finite parameters before changing state', () => {
  const boar = HumanRules.guInstance('white_boar_strength_gu', 1);
  const human = HumanRules.actor({ id: 'boar', guInstances: [boar] });
  const before = JSON.stringify({ essence: human.essence, ledger: human.modifierLedger });
  assert.throws(() => HumanRules.trainBody(human, boar.instanceId,
    { step: Infinity, cap: 3, cost: 1, visitId: 'visit' }), /invalid body training parameters/);
  assert.equal(JSON.stringify({ essence: human.essence, ledger: human.modifierLedger }), before);
});

test('RULE_TEST: current HP preserves missing damage across maximum change', () => {
  assert.equal(HumanRules.adjustedHp(7, 10, 12), 9);
  assert.equal(HumanRules.adjustedHp(7, 10, 8), 5);
});
