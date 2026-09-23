/** W4 growth/transaction fixtures. Synthetic act fixtures + pure rule checks.
 *  Not end-to-end playthroughs; NORMAL_RUN growth evidence is W6. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const mainSource = readFileSync(new URL('../js/main.js', import.meta.url), 'utf8');
const dataCtx = vm.createContext({});
vm.runInContext(
  readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA=DATA;',
  dataCtx,
);
const DATA = dataCtx.DATA;

function loadRules() {
  const ctx = vm.createContext({ DATA, globalThis: { DATA } });
  ctx.globalThis = ctx;
  for (const name of ['mvp_logic', 'gu_rules', 'run_rules', 'run_flow', 'shop_rules', 'loot_rules']) {
    vm.runInContext(readFileSync(new URL(`../js/${name}.js`, import.meta.url), 'utf8'), ctx);
  }
  return ctx;
}

function extractAct(names) {
  const spans = names.map((name) => {
    const start = mainSource.indexOf(`  ${name}(`);
    assert.ok(start >= 0, `act.${name} missing`);
    const next = mainSource.indexOf('\n  },', start);
    assert.ok(next > start, `act.${name} end missing`);
    return mainSource.slice(start, next + 5);
  });
  return `globalThis.act = {${spans.join('\n')}};`;
}

function txContext(overrides = {}) {
  const rules = loadRules();
  const state = {
    seed: 42,
    stones: 20,
    qi: 10,
    qiMax: 10,
    thought: 3,
    blood: 20,
    lifeTime: 80,
    soul: 10,
    soulMax: 10,
    cultivation: 1,
    cultivationStage: 0,
    aptitude: 'bing',
    owned: {},
    wild: {},
    materials: {},
    equipped: [],
    shopSold: [],
    globalCodexIds: [],
    eventLog: [],
    journal: [],
    reward: null,
    journey: { started: true, difficulty: 'normal', availableNodeIds: [] },
    ...overrides.state,
  };
  const ctx = vm.createContext({
    state,
    DATA,
    GU_BY_ID: Object.fromEntries(DATA.gu.map((g) => [g.id, g])),
    GuRules: rules.GuRules,
    RunRules: rules.RunRules,
    RunFlow: rules.RunFlow,
    ShopRules: rules.ShopRules,
    LootRules: rules.LootRules,
    Sfx: { click() {}, success() {}, fail() {}, forge() {}, hit() {}, lose() {} },
    toast() {},
    draw() {},
    commit() {},
    assertRunMutable: () => true,
    recordEvent(action, data, event, tags = []) {
      state.eventLog.push({ action, event, data, tags });
    },
    materialById: (id) => ({ name: id }),
    confirmAbandon: () => true,
    showPage() {},
    openPrep() {},
    skipPersistOnce: false,
    offerName: (o) => o.gu_name || o.gu_id || o.id,
    canBuyOffer: () => true,
    offerCost: () => 0,
    currentNode: () => null,
    ...overrides.ctx,
  });
  for (const name of Object.keys(rules)) {
    if (name !== 'globalThis' && name !== 'DATA') ctx[name] = rules[name];
  }
  vm.runInContext(extractAct(overrides.acts || ['buyOffer', 'sellGu', 'chooseRewardGu', 'forge', 'toggleMove', 'breakthrough']), ctx);
  return { state, ctx, act: ctx.act };
}

test('FIXTURE_INTEGRATION: buy with insufficient stones does not charge', () => {
  const offer = DATA.shopOffers.find((o) => o.kind === 'purchase') || DATA.shopOffers[0];
  assert.ok(offer);
  const { state, act } = txContext({
    state: { stones: 0, shopSold: [] },
    acts: ['buyOffer'],
    ctx: {
      canBuyOffer: () => false,
      offerCost: () => 99,
    },
  });
  const before = JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, sold: state.shopSold }));
  act.buyOffer(offer.id);
  assert.equal(state.stones, before.stones);
  assert.deepEqual(state.owned, before.owned);
  assert.deepEqual(state.shopSold, before.sold);
});

test('FIXTURE_INTEGRATION: buy once charges once and marks sold once', () => {
  const offer = DATA.shopOffers.find((o) => o.kind === 'purchase' && o.gu_id) || DATA.shopOffers.find((o) => o.gu_id);
  assert.ok(offer);
  const cost = 5;
  let allowed = true;
  const { state, act } = txContext({
    state: { stones: 20, owned: {}, shopSold: [] },
    acts: ['buyOffer'],
    ctx: {
      canBuyOffer: () => allowed && !state.shopSold.includes(offer.id),
      offerCost: () => cost,
    },
  });
  act.buyOffer(offer.id);
  assert.equal(state.stones, 15);
  assert.equal(state.owned[offer.gu_id], 1);
  assert.equal(state.shopSold.filter((id) => id === offer.id).length, 1);
  const after = JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, sold: state.shopSold }));
  allowed = true;
  act.buyOffer(offer.id);
  assert.deepEqual(JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, sold: state.shopSold })), after);
});

test('FIXTURE_INTEGRATION: sell credits once and unequips instance-starved kill moves', () => {
  const gu = DATA.gu.find((g) => Number(g.value) > 0);
  const move = {
    id: 'fixture_move',
    label: 'fixture',
    recipe: [gu.id, gu.id],
    true_qi_cost: 1,
    thought_cost: 1,
    effect: { kind: 'strike', amount: 1 },
  };
  DATA.killMoves.push(move);
  try {
    const { state, act } = txContext({
      state: { stones: 0, owned: { [gu.id]: 2 }, equipped: ['fixture_move'] },
      acts: ['sellGu'],
    });
    const price = Math.floor(Number(gu.value) * 0.5);
    act.sellGu(gu.id);
    assert.equal(state.owned[gu.id], 1);
    assert.equal(state.stones, price);
    assert.ok(!state.equipped.includes('fixture_move'), 'duplicate recipe must drop when one instance leaves');
    act.sellGu(gu.id);
    assert.equal(state.owned[gu.id], 0);
    assert.equal(state.stones, price * 2);
    const snapshot = JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, equipped: state.equipped }));
    act.sellGu(gu.id);
    assert.deepEqual(JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, equipped: state.equipped })), snapshot);
  } finally {
    DATA.killMoves.pop();
  }
});

test('FIXTURE_INTEGRATION: reward claim once, second click is a no-op', () => {
  const choices = DATA.gu.slice(0, 3).map((g) => g.id);
  const { state, act } = txContext({
    state: { owned: {}, reward: { guChoices: choices } },
    acts: ['chooseRewardGu', 'openPrep'],
  });
  act.chooseRewardGu(choices[0]);
  assert.equal(state.owned[choices[0]], 1);
  assert.equal(state.reward, null);
  const after = JSON.parse(JSON.stringify(state.owned));
  act.chooseRewardGu(choices[1]);
  assert.deepEqual(JSON.parse(JSON.stringify(state.owned)), after);
});

test('FIXTURE_INTEGRATION: forge missing material leaves ledger unchanged', () => {
  const recipe = DATA.recipes.find((r) => Object.keys(r.materials || {}).length)
    || DATA.recipes.find((r) => (r.inputs || []).length);
  assert.ok(recipe);
  const { state, act } = txContext({
    state: {
      stones: 50,
      owned: Object.fromEntries((recipe.inputs || []).map((id) => [id, 0])),
      materials: Object.fromEntries(Object.keys(recipe.materials || {}).map((id) => [id, 0])),
    },
    acts: ['forge'],
  });
  const before = JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, materials: state.materials }));
  act.forge(recipe.id);
  assert.deepEqual(JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned, materials: state.materials })), before);
});

test('FIXTURE_INTEGRATION: toggleMove refuses duplicate recipes without enough instances', () => {
  const gu = DATA.gu[0];
  const move = {
    id: 'dup_move',
    label: 'dup',
    recipe: [gu.id, gu.id],
    true_qi_cost: 1,
    thought_cost: 1,
    effect: { kind: 'strike', amount: 1 },
  };
  DATA.killMoves.push(move);
  try {
    const { state, act } = txContext({
      state: { owned: { [gu.id]: 1 }, equipped: [] },
      acts: ['toggleMove'],
    });
    act.toggleMove('dup_move');
    assert.deepEqual(state.equipped, []);
    state.owned[gu.id] = 2;
    act.toggleMove('dup_move');
    assert.deepEqual(state.equipped, ['dup_move']);
  } finally {
    DATA.killMoves.pop();
  }
});

test('RULE_TEST: killMoveRecipeInstances rejects one owned gu for a two-slot recipe', () => {
  const rules = loadRules();
  const instances = rules.GuRules.killMoveRecipeInstances(
    { recipe: ['alpha_gu', 'alpha_gu'] },
    { alpha_gu: 1 },
    {},
    {},
  );
  assert.equal(instances[0], 'alpha_gu::1');
  assert.equal(instances[1], null);
  const two = rules.GuRules.killMoveRecipeInstances(
    { recipe: ['alpha_gu', 'alpha_gu'] },
    { alpha_gu: 2 },
    {},
    {},
  );
  assert.deepEqual(two, ['alpha_gu::1', 'alpha_gu::2']);
});
