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
// Use the actual main index: synthetic fixtures must not conceal a runtime merge bug.
const indexStart = mainSource.indexOf('const GU_BY_ID =');
const indexEnd = mainSource.indexOf('function recomputeQiMax()', indexStart);
vm.runInContext(mainSource.slice(indexStart, indexEnd) + ';globalThis.lookup = GU_BY_ID;', dataCtx);
const GU_BY_ID = dataCtx.lookup;

function loadRules() {
  const ctx = vm.createContext({ DATA, globalThis: { DATA } });
  ctx.globalThis = ctx;
  for (const name of ['mvp_logic', 'gu_rules', 'run_rules', 'run_flow', 'shop_rules', 'loot_rules', 'human_rules']) {
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

function extractBodyTrainingPreview() {
  const start = mainSource.indexOf('function bodyTrainingPreview(gu) {');
  const end = mainSource.indexOf('\nfunction startMaintainedGu', start);
  assert.ok(start >= 0 && end > start, 'bodyTrainingPreview missing');
  return mainSource.slice(start, end);
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
    GU_BY_ID,
    GuRules: rules.GuRules,
    RunRules: rules.RunRules,
    RunFlow: rules.RunFlow,
    ShopRules: rules.ShopRules,
    LootRules: rules.LootRules,
    HumanRules: rules.HumanRules,
    Sfx: { click() {}, success() {}, fail() {}, forge() {}, hit() {}, lose() {} },
    toast() {},
    draw() {},
    commit() {},
    assertRunMutable: () => true,
    recordEvent(action, data, event, tags = []) {
      state.eventLog.push({ action, event, data, tags });
    },
    confirmAbandon: () => true,
    showPage() {},
    openPrep() {},
    skipPersistOnce: false,
    offerName: (o) => o.gu_name || o.gu_id || o.id,
    canBuyOffer: () => true,
    offerCost: () => 0,
    currentNode: () => null,
    currentKillMoves: () => DATA.killMoves,
    ...overrides.ctx,
  });
  for (const name of Object.keys(rules)) {
    if (name !== 'globalThis' && name !== 'DATA') ctx[name] = rules[name];
  }
  // Keep instance construction dynamic while exercising main.js's real preview and action.
  ctx.heldPlayerGuInstances = () => Object.entries(state.owned || {}).flatMap(([id, count]) =>
    Array.from({ length: Math.max(0, Math.floor(Number(count || 0))) }, (_, index) =>
      ctx.HumanRules.guInstance(id, index + 1)));
  vm.runInContext(extractBodyTrainingPreview(), ctx);
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

test('FIXTURE_INTEGRATION: legacy light run can buy an existing blood or force Gu', () => {
  const crossSchoolOffer = DATA.shopOffers.find((offer) =>
    offer.kind === 'purchase' && ['blood', 'force'].includes(GU_BY_ID[offer.gu_id]?.school));
  assert.ok(crossSchoolOffer, 'snapshot must expose an existing blood/force shop Gu');

  const { state, act } = txContext({
    state: { playableSchool: 'light', stones: 20, shopSold: [] },
    acts: ['buyOffer'],
    ctx: { canBuyOffer: () => true, offerCost: () => 0 },
  });
  act.buyOffer(crossSchoolOffer.id);
  assert.equal(state.owned[crossSchoolOffer.gu_id], 1);
  assert.equal(state.stones, 20);
});

test('FIXTURE_INTEGRATION: legacy light run can claim an existing non-light reward Gu', () => {
  const gu = DATA.gu.find((entry) => ['blood', 'force'].includes(entry.school));
  assert.ok(gu, 'snapshot must expose an existing blood/force Gu');
  const { state, act } = txContext({
    state: {
      playableSchool: 'light',
      reward: { guChoices: [gu.id], stones: 0, nodeId: 'fixture' },
    },
    acts: ['chooseRewardGu', 'openPrep'],
  });

  act.chooseRewardGu(gu.id);
  assert.equal(state.owned[gu.id], 1);
  assert.equal(state.reward, null);
});

test('FIXTURE_INTEGRATION: legacy light run can forge an existing cross-school recipe', () => {
  const recipe = DATA.recipes.find((entry) => entry.id === 'bear_split');
  assert.ok(recipe, 'snapshot must expose the existing force recipe');
  const owned = Object.fromEntries(recipe.inputs.map((id) => [id, 1]));
  const { state, act } = txContext({
    state: { playableSchool: 'light', stones: 100, owned },
    acts: ['forge'],
  });

  act.forge(recipe.id);
  assert.equal(state.owned.jade_skin_gu, 0);
  assert.equal(state.owned.white_boar_strength_gu, 0);
  assert.equal(state.eventLog.at(-1)?.action, 'refine_gu');
});

test('FIXTURE_INTEGRATION: paused kill moves cannot be equipped even with their components', () => {
  const move = DATA.killMoves.find((entry) => entry.id === 'km_blood_ember');
  assert.ok(move, 'snapshot must expose the existing blood kill move');
  const owned = Object.fromEntries(move.recipe.map((id) => [id, 1]));
  const { state, act } = txContext({
    state: { playableSchool: 'light', owned, equipped: [] },
    acts: ['toggleMove'],
  });

  act.toggleMove(move.id);
  assert.deepEqual(state.equipped, []);
});

test('FIXTURE_INTEGRATION: paused kill moves cannot spend battle resources', () => {
  const move = DATA.killMoves.find(entry => entry.id === 'km_blood_ember');
  const { state, act } = txContext({
    state: { qi: 5, thought: 2, equipped: [move.id] },
    acts: ['useMove'],
  });
  act.useMove(move.id);
  assert.equal(state.qi, 5);
  assert.equal(state.thought, 2);
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

test('FIXTURE_INTEGRATION: forge missing Gu input leaves ledger unchanged', () => {
  const recipe = DATA.recipes.find((r) => (r.inputs || []).length);
  assert.ok(recipe);
  const { state, act } = txContext({
    state: {
      stones: 50,
      owned: Object.fromEntries((recipe.inputs || []).map((id) => [id, 0])),
    },
    acts: ['forge'],
  });
  const before = JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned }));
  act.forge(recipe.id);
  assert.deepEqual(JSON.parse(JSON.stringify({ stones: state.stones, owned: state.owned })), before);
});

test('FIXTURE_INTEGRATION: paused kill moves stay unavailable regardless of recipe instances', () => {
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
    assert.deepEqual(state.equipped, []);
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


test('reward decline preserves already granted resources and cannot grant Gu on a second click', () => {
  const choices = DATA.gu.slice(0, 3).map(g => g.id);
  const {state, act} = txContext({state:{stones:17, owned:{}, reward:{guChoices:choices}}, acts:['continueReward','chooseRewardGu','openPrep']});
  act.continueReward();
  assert.ok(state.reward, 'ordinary continue must not silently discard choices');
  act.continueReward(true);
  assert.equal(state.reward, null);
  assert.equal(state.stones, 17);
  assert.equal(Object.keys(state.owned).length, 0);
  assert.equal(state.eventLog.filter(e=>e.event==='loot_gu_declined').length, 1);
  act.chooseRewardGu(choices[0]);act.continueReward(true);
  assert.equal(Object.keys(state.owned).length, 0);
  assert.equal(state.stones, 17);
});


test('main game can prepare two Small Lights then use Moonlight in its one-action turn', () => {
  const target = { id: 'fixture', name: '目标', hp: 100, statuses: {} };
  const battle = {
    turn: 1, actionsUsed: 0, actionLimit: 1, turnSupports: {},
    guUsedThisTurn: {}, guSealed: {}, log: [], enemies: [target],
  };
  const { state, ctx, act } = txContext({
    acts: ['useGu'],
    state: { battle, owned: { small_light_gu: 2, moonlight_gu: 1 }, thought: 4, qi: 10 },
    ctx: {
      targetOf: () => target,
      aliveEnemies: () => [target],
      isDirectStrike: () => false,
      finishPlayerAction() {},
      BattleFx: { damage() {} },
    },
  });
  ctx.currentCombatRoster = (used, sealed) => ctx.GuRules.combatRoster(DATA.gu, state.owned, {
    usedInstances: used, sealedInstances: sealed,
  });
  const from = mainSource.indexOf('function applyEffectPlan(');
  const to = mainSource.indexOf('function scheduleEffect(', from);
  vm.runInContext(mainSource.slice(from, to), ctx);
  act.useGu('small_light_gu::1');
  assert.equal(battle.actionsUsed, 0);
  assert.equal(state.qi, 9);
  assert.equal(state.thought, 3);
  assert.equal(battle.guUsedThisTurn['small_light_gu::1'], true);
  act.useGu('small_light_gu::2');
  assert.equal(battle.turnSupports.guTargets.moonlight_gu.length, 1);
  act.useGu('moonlight_gu::1');
  assert.equal(target.hp, 94);
  assert.equal(battle.actionsUsed, 1);
  assert.equal(state.qi, 6);
  assert.equal(state.thought, 1);
  assert.equal(battle.turnSupports.guTargets.moonlight_gu, undefined);
});

test('FIXTURE_INTEGRATION: basic punches resolve problem axes without spending resources', () => {
  const punch = ({ target, blood = 20 }) => {
    const battle = {
      turn: 1, actionsUsed: 0, actionLimit: 1, turnSupports: {},
      buffs: {}, log: [], enemies: [target],
      playerHuman: {
        baseline: { attack: 3 },
        modifierLedger: [{ attribute: 'attack', amount: 3, persistence: 'session_permanent', active: true }],
        guInstances: [], maintainedGu: [],
      },
    };
    const { state, ctx, act } = txContext({
      acts: ['basicAttack'],
      state: {
        battle, blood, qi: 7, thought: 2,
      },
      ctx: {
        targetOf: () => target,
        aliveEnemies: () => battle.enemies.filter(enemy => enemy.hp > 0),
        liveReactions: () => [],
        finishPlayerAction() {},
        openBattleOutcome() {},
        BattleFx: { selfDamage() {} },
        $: () => null,
        setTimeout() {},
      },
    });
    const helperStart = mainSource.indexOf('function resolveProblemHit(');
    const helperEnd = mainSource.indexOf('\nfunction applyEffectPlan(', helperStart);
    vm.runInContext(mainSource.slice(helperStart, helperEnd), ctx);
    act.basicAttack();
    return { state, battle };
  };

  const armored = punch({ target: { name: '厚甲', hp: 20, problemAxis: 'armor', armorValue: 2 } });
  assert.equal(armored.battle.enemies[0].hp, 16, 'raw 6 is reduced by armor 2');
  assert.equal(armored.state.qi, 7);
  assert.equal(armored.state.thought, 2);
  assert.match(armored.battle.log.join(' '), /伤 4/);

  const evasive = punch({ target: { name: '闪避', hp: 20, problemAxis: 'evasion', evasionBreakpoint: 2 } });
  assert.equal(evasive.battle.enemies[0].hp, 20, 'raw 6 exceeds breakpoint 2 and is evaded');
  assert.match(evasive.battle.log.join(' '), /被闪避/);

  const taxDeath = punch({ target: { name: '规则', hp: 6, problemAxis: 'info' }, blood: 3 });
  assert.equal(taxDeath.state.blood, 0);
  assert.equal(taxDeath.battle.enemies[0].hp, 0, 'the same punch is lethal to the target');
  assert.equal(taxDeath.battle.over, '败', 'information tax defeat wins over a killing punch');
  assert.equal(taxDeath.battle.deathCause, 'info_tax');
});


test('main Gu index preserves full playable definitions while adding enemy-only semantics', () => {
  for (const id of ['moonlight_gu', 'small_light_gu', 'stone_shell_gu']) {
    const full = DATA.gu.find(gu => gu.id === id);
    assert.deepEqual(GU_BY_ID[id].battleEffect, full.battleEffect);
    assert.equal(GU_BY_ID[id].trueQiCost, full.trueQiCost);
    assert.equal(GU_BY_ID[id].value, full.value);
  }
  const extra = Object.keys(DATA.guSemanticsById).find(id => !DATA.gu.some(gu => gu.id === id));
  assert.ok(extra, 'enemy-only definitions remain available');
  assert.equal(GU_BY_ID[extra].id, extra);
  assert.ok(Object.hasOwn(GU_BY_ID[extra], 'passive_effect'));
});

test('FIXTURE_INTEGRATION: body training spends resources once per prep visit and caps at three', () => {
  const gu = GU_BY_ID.white_boar_strength_gu;
  assert.equal(gu.effect.kind, 'body_training');
  const { state, ctx, act } = txContext({
    acts: ['trainBody'],
    state: { page: 'prep', prepFor: 'node-1', qi: 6, stones: 5, owned: { [gu.id]: 1 } },
  });

  const preview = ctx.bodyTrainingPreview(gu);
  assert.equal(preview.ok, true);
  assert.equal(preview.human.essence, 5);
  act.trainBody(gu.id);
  assert.equal(state.qi, 5);
  assert.equal(state.stones, 4);
  assert.equal(state.modifierLedger.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(state.modifierLedger[0])), {
    attribute: 'attack', amount: 1, sourceGuDefinitionId: gu.id,
    sourceGuInstanceId: `${gu.id}::1`, sourceEffectId: 'body_training',
    persistence: 'session_permanent', dependency: 'none', createdAt: 'node-1',
    active: true, removalReason: null,
  });

  const afterFirst = JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger });
  act.trainBody(gu.id);
  assert.equal(JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger }), afterFirst,
    'a second click in the same visit must not charge again');

  for (const visit of ['node-2', 'node-3']) {
    state.prepFor = visit;
    act.trainBody(gu.id);
  }
  assert.equal(state.modifierLedger.reduce((sum, entry) => sum + entry.amount, 0), 3);
  assert.equal(state.qi, 3);
  assert.equal(state.stones, 2);
  state.prepFor = 'node-4';
  const atCap = JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger });
  assert.equal(ctx.bodyTrainingPreview(gu).reason, 'cap_reached');
  act.trainBody(gu.id);
  assert.equal(JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger }), atCap);
});

test('FIXTURE_INTEGRATION: body training with insufficient Qi or feeding stones changes nothing', () => {
  const gu = GU_BY_ID.white_boar_strength_gu;
  for (const resources of [{ qi: 0, stones: 5 }, { qi: 6, stones: 0 }]) {
    const { state, ctx, act } = txContext({
      acts: ['trainBody'],
      state: { page: 'prep', prepFor: 'node-1', owned: { [gu.id]: 1 }, ...resources },
    });
    const before = JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger, journal: state.journal });
    assert.equal(ctx.bodyTrainingPreview(gu).ok, false);
    act.trainBody(gu.id);
    assert.equal(JSON.stringify({ qi: state.qi, stones: state.stones, ledger: state.modifierLedger, journal: state.journal }), before);
  }
});

test('FIXTURE_INTEGRATION: permanent body training survives selling and refining its source Gu', () => {
  const gu = GU_BY_ID.white_boar_strength_gu;
  const { state, act } = txContext({
    acts: ['trainBody', 'sellGu', 'forge'],
    state: {
      page: 'prep', prepFor: 'node-1', qi: 6, stones: 100,
      owned: { [gu.id]: 2, jade_skin_gu: 1 },
    },
  });
  act.trainBody(gu.id);
  const trainedLedger = JSON.stringify(state.modifierLedger);
  act.sellGu(gu.id);
  assert.equal(state.owned[gu.id], 1);
  assert.equal(JSON.stringify(state.modifierLedger), trainedLedger);
  act.forge('white_jade_basic');
  assert.equal(state.owned[gu.id], 0);
  assert.equal(JSON.stringify(state.modifierLedger), trainedLedger);
  assert.equal(state.modifierLedger[0].persistence, 'session_permanent');
  assert.equal(state.modifierLedger[0].dependency, 'none');
});

test('breakthrough changes capacity without granting unearned essence at empty, half and full balances', () => {
  for (const stage of [0, 3]) {
    for (const qi of [0, 3, 6]) {
      const { state, ctx, act } = txContext({
        acts: ['breakthrough'],
        state: { cultivation: 1, cultivationStage: stage, stones: 100, qiMax: 6, qi },
        ctx: { STAGE_BY_RANK: ['', 'one', 'two', 'three', 'four', 'five'] },
      });
      const start = mainSource.indexOf('function recomputeQiMax()');
      const end = mainSource.indexOf('function currentCombatRoster(', start);
      vm.runInContext(mainSource.slice(start, end), ctx);
      act.breakthrough();
      assert.equal(state.qi, qi, `stage=${stage}, old essence=${qi}`);
      assert.ok(stage === 0 ? state.cultivationStage > 0 : state.cultivation > 1);
      assert.ok(state.stones < 100);
    }
  }
});


test('new runs start with six rank-one Gu and retain higher-rank Gu as discoverable content', () => {
  const ctx = vm.createContext({ DATA });
  const end = mainSource.indexOf('const NODE_ACTION_TYPES');
  vm.runInContext(mainSource.slice(0, end) + ';globalThis.starter = READY;', ctx);
  const starter = ctx.starter;
  assert.deepEqual(Object.keys(starter.owned).sort(), ['moonlight_gu', 'small_light_gu', 'stone_shell_gu', 'vitality_leaf_gu', 'jade_skin_gu', 'white_boar_strength_gu'].sort());
  for (const [id, count] of Object.entries(starter.owned)) {
    assert.equal(count, id === 'vitality_leaf_gu' ? 2 : 1);
    assert.equal(GU_BY_ID[id].rank, 1);
  }
  assert.equal(starter.wild.small_light_gu, 2);
  for (const id of ['fire_atk_2_01_gu', 'water_atk_3_05_gu', 'wisdom_atk_3_13_gu', 'blood_atk_5_02_gu']) {
    assert.equal(starter.owned[id], undefined);
    assert.ok(DATA.gu.find(g => g.id === id), 'higher-rank content stays in the game');
    assert.ok(Object.values(DATA.loot.schoolPools).flat().includes(id), 'existing higher-rank Gu have a discovery pool entry');
  }
});


test('resource HUD writes actual balances on first render and without animation', () => {
  const element = { textContent: '20/20' };
  const ctx = vm.createContext({ $: selector => selector === '#hud-qi-num' ? element : null, window: {} });
  const start = mainSource.indexOf('const hudPrevNum =');
  const end = mainSource.indexOf('function hud()', start);
  vm.runInContext(mainSource.slice(start, end), ctx);
  ctx.hudNumFx('hud-qi-num', '6/6');
  assert.equal(element.textContent, '6/6');
  ctx.hudNumFx('hud-qi-num', '5/6');
  assert.equal(element.textContent, '5/6');
  ctx.hudNumFx('missing', '0');
});


test('main production transaction persists one visit and leaf recovery cannot be bypassed', () => {
  const { ctx, state } = txContext({ state: { page: 'prep', prepFor: 'node1',
    cultivation: 2, qi: 5, blood: 7, bloodMax: 10,
    owned: { vitality_grass_gu: 1 }, journey: { nodeId: 'node1' } }, ctx: { guReasonLabel: reason => reason } });
  const start = mainSource.indexOf('function leafProductionPreview(gu) {');
  const end = mainSource.indexOf('function startMaintainedGu(', start);
  vm.runInContext(mainSource.slice(start, end), ctx);
  vm.runInContext(extractAct(['produceLeaf', 'useLeaf']), ctx);
  ctx.act.produceLeaf('vitality_grass_gu');
  assert.equal(state.qi, 3);
  assert.equal(state.owned.vitality_grass_gu, 1);
  assert.equal(state.owned.vitality_leaf_gu, 1);
  ctx.act.produceLeaf('vitality_grass_gu');
  assert.equal(state.qi, 3);
  assert.equal(state.owned.vitality_leaf_gu, 1);
  ctx.act.useLeaf('vitality_leaf_gu');
  assert.equal(state.blood, 10);
  assert.equal(state.owned.vitality_leaf_gu, 0);
  assert.equal(state.leafRecoveryNodeId, 'node1');
  state.blood = 7;
  state.owned.vitality_leaf_gu = 1;
  ctx.act.useLeaf('vitality_leaf_gu');
  assert.equal(state.blood, 7);
  assert.equal(state.owned.vitality_leaf_gu, 1);
  state.prepFor = 'node2'; state.journey.nodeId = 'node2';
  ctx.act.produceLeaf('vitality_grass_gu');
  assert.equal(state.qi, 1);
  assert.equal(state.owned.vitality_leaf_gu, 2);
  ctx.act.useLeaf('vitality_leaf_gu');
  assert.equal(state.blood, 10);
  assert.equal(state.owned.vitality_leaf_gu, 1);
});

test('custom kill move draft rejects components beyond owned instances', () => {
  const { state, act } = txContext({
    state: { page: 'prep', owned: { moonlight_gu: 1 }, killmoveDraft: ['moonlight_gu'] },
    acts: ['addMoveComponent'],
  });
  act.addMoveComponent('moonlight_gu');
  assert.deepEqual(JSON.parse(JSON.stringify(state.killmoveDraft)), ['moonlight_gu']);
});

test('remembering a custom move costs nothing, preserves inventory and does not equip it', () => {
  const owned = { moonlight_gu: 1, small_light_gu: 1 };
  const before = JSON.parse(JSON.stringify(owned));
  const { state, act } = txContext({
    state: { page: 'prep', stones: 23, owned, equipped: [], killmoveDraft: ['small_light_gu', 'moonlight_gu'] },
    acts: ['rememberCustomMove'],
  });
  act.rememberCustomMove();
  assert.equal(state.stones, 23);
  assert.deepEqual(JSON.parse(JSON.stringify(state.owned)), before);
  assert.deepEqual(JSON.parse(JSON.stringify(state.customMoveRecipes)), [['moonlight_gu', 'small_light_gu']]);
  assert.deepEqual(JSON.parse(JSON.stringify(state.killmoveDraft)), []);
  assert.deepEqual(JSON.parse(JSON.stringify(state.equipped)), []);
});

test('custom recipes accept two distinct instances and deduplicate component order', () => {
  const { state, act } = txContext({
    state: {
      page: 'prep', owned: { moonlight_gu: 2, small_light_gu: 1 },
      killmoveDraft: ['moonlight_gu', 'small_light_gu', 'moonlight_gu'],
    },
    acts: ['rememberCustomMove'],
  });
  act.rememberCustomMove();
  assert.deepEqual(JSON.parse(JSON.stringify(state.customMoveRecipes)), [
    ['moonlight_gu', 'moonlight_gu', 'small_light_gu'],
  ]);
  state.killmoveDraft = ['small_light_gu', 'moonlight_gu', 'moonlight_gu'];
  act.rememberCustomMove();
  assert.deepEqual(JSON.parse(JSON.stringify(state.customMoveRecipes)), [
    ['moonlight_gu', 'moonlight_gu', 'small_light_gu'],
  ]);
});

test('forgetting a custom move removes it from equipped slots', () => {
  const recipe = ['moonlight_gu', 'small_light_gu'];
  const { state, ctx, act } = txContext({
    state: { page: 'prep', owned: { moonlight_gu: 1, small_light_gu: 1 }, customMoveRecipes: [recipe], equipped: [] },
    acts: ['toggleMove', 'forgetCustomMove'],
    ctx: {
      currentKillMoves: () => [
        ...DATA.killMoves,
        ...state.customMoveRecipes.map(item => ctx.GuRules.composeKillMove(item, GU_BY_ID).move),
      ],
    },
  });
  const moveId = ctx.GuRules.composeKillMove(recipe, GU_BY_ID).move.id;
  act.toggleMove(moveId);
  assert.deepEqual(JSON.parse(JSON.stringify(state.equipped)), [moveId]);
  act.forgetCustomMove(moveId);
  assert.deepEqual(JSON.parse(JSON.stringify(state.customMoveRecipes)), []);
  assert.deepEqual(JSON.parse(JSON.stringify(state.equipped)), []);
});

test('custom kill move actions cannot edit recipes outside preparation', () => {
  const initial = {
    page: 'map', owned: { moonlight_gu: 1, small_light_gu: 1 },
    killmoveDraft: ['moonlight_gu', 'small_light_gu'],
    customMoveRecipes: [['moonlight_gu', 'small_light_gu']], equipped: ['km_custom_moonlight_gu__small_light_gu'],
  };
  const { state, act } = txContext({
    state: initial,
    acts: ['addMoveComponent', 'removeMoveComponent', 'rememberCustomMove', 'forgetCustomMove'],
  });
  const before = JSON.parse(JSON.stringify({ draft: state.killmoveDraft, recipes: state.customMoveRecipes, equipped: state.equipped }));
  act.addMoveComponent('moonlight_gu');
  act.removeMoveComponent(0);
  act.rememberCustomMove();
  act.forgetCustomMove('km_custom_moonlight_gu__small_light_gu');
  assert.deepEqual(JSON.parse(JSON.stringify({ draft: state.killmoveDraft, recipes: state.customMoveRecipes, equipped: state.equipped })), before);
});
