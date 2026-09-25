import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8');
const context = vm.createContext({});
vm.runInContext(source, context);
const rules = context.GuRules;
const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const data = dataContext.DATA;
const plain = (value) => JSON.parse(JSON.stringify(value));

const gu = (overrides = {}) => ({
  rank: 1,
  trueQiCost: 1,
  thoughtCost: 1,
  lowRankException: false,
  ...overrides,
});

test('gu activation blocks a higher-rank gu unless it declares an exception', () => {
  const player = { playerRank: 1, trueQi: 10, thought: 3, usedThisTurn: false };
  assert.equal(rules.activationReason(gu({ rank: 2 }), player), 'insufficient_qi_quality');
  assert.equal(
    rules.activationReason(gu({ rank: 2, lowRankException: true }), player),
    '',
  );
});

test('gu activation reports exhausted resources and one-use-per-turn state', () => {
  const base = { playerRank: 3, trueQi: 3, thought: 2, usedThisTurn: false };
  assert.equal(rules.activationReason(gu({ trueQiCost: 4 }), base), 'insufficient_true_qi');
  assert.equal(rules.activationReason(gu({ thoughtCost: 3 }), base), 'insufficient_thought');
  assert.equal(rules.activationReason(gu(), { ...base, usedThisTurn: true }), 'gu_used_this_turn');
  assert.equal(rules.activationReason(gu({ sealed: true }), base), 'gu_sealed');
});

test('combat roster includes every owned combat gu without a slot cap', () => {
  const roster = rules.combatRoster([
    gu({ id: 'alpha_gu', combat: 'strike' }),
    gu({ id: 'beta_gu', combat: 'shield' }),
    gu({ id: 'utility_gu', combat: '' }),
    gu({ id: 'unowned_gu', combat: 'strike' }),
  ], { alpha_gu: 1, beta_gu: 1, utility_gu: 1 });

  assert.deepEqual(plain(roster).map((entry) => entry.id), ['alpha_gu', 'beta_gu']);
});

test('combat roster expands duplicate definitions into separate instances', () => {
  const roster = rules.combatRoster(
    [gu({ id: 'alpha_gu', combat: 'strike' })],
    { alpha_gu: 2 },
    {
      playerRank: 1,
      trueQi: 10,
      thought: 2,
      usedInstances: { 'alpha_gu::1': true },
    },
  );

  assert.deepEqual(
    plain(roster).map((entry) => entry.instanceId),
    ['alpha_gu::1', 'alpha_gu::2'],
  );
  assert.equal(roster[0].activationReason, 'gu_used_this_turn');
  assert.equal(roster[1].activationReason, '');
});

test('wild gu attunement pays rank-scaled essence and moves one instance to refined', () => {
  const result = rules.attuneWild({ small_light_gu: 2 }, { small_light_gu: 1 }, 20, 'small_light_gu', 1);
  assert.equal(result.ok, true);
  assert.equal(result.cost, 4);
  assert.equal(result.wild.small_light_gu, 1);
  assert.equal(result.owned.small_light_gu, 2);
  assert.equal(result.trueQi, 16);
  assert.equal(rules.attuneCost(2), 6);
});

test('wild gu attunement rejects missing targets and insufficient essence without spending', () => {
  const missing = rules.attuneWild({}, {}, 20, 'small_light_gu', 1);
  assert.equal(missing.ok, false);
  assert.equal(missing.reason, 'attune_target_missing');
  const poor = rules.attuneWild({ small_light_gu: 1 }, {}, 3, 'small_light_gu', 1);
  assert.equal(poor.ok, false);
  assert.equal(poor.reason, 'insufficient_essence');
  assert.equal(poor.cost, 4);
});

test('kill move recipes resolve one unused instance per required gu', () => {
  const move = { recipe: ['alpha_gu', 'beta_gu'] };
  assert.deepEqual(
    rules.killMoveRecipeInstances(move, { alpha_gu: 2, beta_gu: 1 }, { 'alpha_gu::1': true }, {}),
    ['alpha_gu::2', 'beta_gu::1'],
  );
  assert.deepEqual(
    rules.killMoveRecipeInstances(move, { alpha_gu: 2, beta_gu: 1 }, { 'beta_gu::1': true }, {}),
    ['alpha_gu::1', null],
  );
});

test('L0 kill move effect is composed from recipe components in order', () => {
  const guById = {
    alpha_gu: { school: 'force', v1_effect: { kind: 'strike', amount: 2 } },
    beta_gu: { school: 'blood', v1_effect: { kind: 'heal_and_strike', heal: 1, amount: 3 } },
  };
  const move = {
    recipe: ['alpha_gu', 'beta_gu'],
    // LEGACY prefab must not drive settlement
    effect: { kind: 'strike', amount: 99 },
    damage: 88,
  };
  const plan = rules.killMoveEffectPlan(move, guById, { school: 'force' });
  assert.equal(plan.damage, 5);
  assert.equal(plan.heal, 1);
  const flipped = rules.killMoveEffectPlan({ ...move, recipe: ['beta_gu', 'alpha_gu'] }, guById, {});
  assert.equal(flipped.damage, 5);
  assert.equal(flipped.heal, 1);
});

test('generated effects mirror Godot role fallback rank and self-support transforms', () => {
  const byId = Object.fromEntries(data.gu.map((entry) => [entry.id, entry]));
  assert.equal(byId.light_atk_5_03_gu.battleEffect.amount, 6);
  // P5-B2：white_jade_gu 已收敛为显式 effect（shield 5，canon_driven_v1），
  // 镜像断言改用仍在 role 兜底上的 loot 蛊。
  assert.equal(byId.light_def_5_22_gu.battleEffect.amount, 7);
  assert.equal(byId.white_jade_gu.battleEffect.amount, 5);
  assert.equal(byId.white_jade_gu.sourceClass, 'canon_driven_v1');
  assert.equal(byId.light_rec_3_07_gu.battleEffect.support_school, 'light');
});

test('gu condition gates run before cost commit', () => {
  const effect = {
    kind: 'strike',
    amount: 4,
    condition: { type: 'self_hp_below', threshold: 0.5 },
  };
  assert.equal(rules.gateMissReason(effect, { hp: 50, hpMax: 100 }), 'condition_miss');
  assert.equal(rules.gateMissReason(effect, { hp: 49, hpMax: 100 }), '');
});

test('consume_status requires at least one live stack before cost commit', () => {
  const effect = {
    kind: 'strike',
    amount: 2,
    consume_status: { name: 'marked', per_stack: 1 },
  };
  assert.equal(rules.gateMissReason(effect, { statusStacks: {} }), 'consume_status_missing');
  assert.equal(rules.gateMissReason(effect, { statusStacks: { marked: 1 } }), '');
});

test('gu effect plan resolves strike support, shield, heal and composite effects', () => {
  const base = {
    damage: 0, heal: 0, block: 0, statuses: [], swordIntent: 0, support: null,
    inspect: false, suppressCounter: false, armorBreak: 0, ignoreEvasion: false,
  };
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'strike', amount: 2 }, { school: 'light', supports: { light: 3 } })),
    { ...base, damage: 5 },
  );
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'shield', amount: 3 })),
    { ...base, block: 3 },
  );
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'heal_and_strike', heal: 2, amount: 4 })),
    { ...base, damage: 4, heal: 2 },
  );
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'composite', parts: [{ kind: 'grant_block', amount: 5 }] })),
    { ...base, block: 5 },
  );
});

test('gu effect plan resolves delayed, consume-status and intent-weaken effects', () => {
  const base = {
    damage: 0, heal: 0, block: 0, statuses: [], swordIntent: 0, support: null,
    inspect: false, suppressCounter: false, armorBreak: 0, ignoreEvasion: false,
  };
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'strike', amount: 3, delay: { turns: 1 } })),
    { ...base, damage: 3, delayTurns: 1 },
  );
  assert.deepEqual(
    plain(rules.effectPlan(
      { kind: 'strike', amount: 2, consume_status: { name: 'marked', per_stack: 1 } },
      { statusStacks: { marked: 3 } },
    )),
    {
      ...base,
      damage: 5,
      consumeStatus: 'marked',
    },
  );
  assert.deepEqual(
    plain(rules.effectPlan({ kind: 'weaken_intent', amount: 2 })),
    { ...base, intentWeaken: 2 },
  );
});

test('lab data exports every special V1 effect channel used by the rules', () => {
  const byId = Object.fromEntries(data.gu.map((entry) => [entry.id, entry]));
  for (const id of [
    'blood_atk_5_02_gu',
    'fire_atk_2_01_gu',
    'water_atk_3_05_gu',
    'wisdom_rec_1_20_gu',
    'wisdom_atk_3_13_gu',
  ]) {
    assert.ok(byId[id], `${id} must be present in the lab pool`);
  }
  assert.equal(byId.blood_atk_5_02_gu.lifeCost, 2);
  assert.equal(byId.fire_atk_2_01_gu.battleEffect.delay.turns, 1);
  assert.equal(byId.water_atk_3_05_gu.battleEffect.consume_status.name, 'marked');
  assert.equal(byId.wisdom_rec_1_20_gu.battleEffect.kind, 'status');
  assert.equal(byId.wisdom_atk_3_13_gu.battleEffect.kind, 'weaken_intent');
});

test('sword intent only boosts sword-school strikes', () => {
  assert.equal(
    rules.effectPlan({ kind: 'strike', amount: 2 }, { school: 'sword', swordIntent: 3 }).damage,
    5,
  );
  assert.equal(
    rules.effectPlan({ kind: 'strike', amount: 2 }, { school: 'light', swordIntent: 3 }).damage,
    2,
  );
});
