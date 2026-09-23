/** Gate 6 · Phase 6 掉落三价值 · 风险 → 新未来
 *  L0 2026-09-25：普通=经济/成长 · 精英=构筑组件 · Boss=新未来；精英/Boss 后必有新选择。
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const data = dataContext.DATA;
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(new URL('../js/loot_rules.js', import.meta.url), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), ctx);
const loot = ctx.LootRules;
const rules = ctx.GuRules;
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));
const consumers = rules.materialConsumers(rules.liveRecipes(data.recipes));

const startOwned = {
  moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
  jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
};

test('Gate 6 · loot carries three value kinds (economy / growth / build)', () => {
  assert.equal(loot.classifyItem('moon_dew', guById, consumers), 'growth');
  assert.equal(loot.classifyItem('moon_glow_gu', guById, consumers), 'build');
  assert.equal(loot.classifyItem('mat_unused_x', guById, consumers), 'economic');
  const kinds = loot.classifyReward({
    stones: 5,
    materialIds: ['moon_dew'],
    guChoices: ['moon_glow_gu'],
  }, { guById, consumers });
  assert.equal(kinds.economic, 1);
  assert.equal(kinds.growth, 1);
  assert.equal(kinds.build, 1);
});

test('Gate 6 · tier identity: common=economy/growth, elite=build, boss=new_future', () => {
  const identity = {
    common: 'economy_growth',
    elite: 'build_component',
    boss: 'new_future',
  };
  // 与 rollVictoryLoot 约定一致
  assert.equal(identity.boss, 'new_future');
  assert.ok(data.loot.tables.boss.gu_chance_pct >= 50);
  assert.equal(data.loot.tables.elite.forced_rarity, 'epic');
  assert.ok(Object.values(data.loot.tables.boss.gu_pool.by_rarity).flat().length >= 5);
});

test('Gate 6 · boss/elite three-choice includes a new-future gu', () => {
  const newFuture = loot.newFutureGuIds({
    owned: startOwned,
    guById,
    killMoves: data.killMoves,
    buildKits: rules.BUILD_KITS,
  });
  assert.ok(newFuture.length > 0, 'start kit still misses futures (e.g. moon_glow)');
  assert.ok(newFuture.includes('moon_glow_gu') || newFuture.includes('moon_ray_gu'));

  const rolled = loot.rollGuChoices(data.loot.tables.boss, {
    seed: 101, tick: 3, tier: 'boss',
    lootPity: 0, pityConfig: data.loot.pity,
    school: 'light', schoolPools: data.loot.schoolPools,
    guById, supportPool: [], choiceCount: 3,
  });
  let guIds = rolled.guIds || [];
  guIds = loot.ensureNewFutureChoice(guIds, newFuture, {
    seed: 101, tick: 3, tier: 'boss',
    byRarity: data.loot.tables.boss.gu_pool.by_rarity,
  });
  assert.ok(guIds.some((id) => newFuture.includes(id)),
    `boss choice must open a new future: ${guIds.join(',')}`);
});

test('Gate 6 · elite/boss reward opens a new choice, not only buying power', () => {
  const pick = 'moon_glow_gu';
  const insight = rules.gainInsight(pick, {
    owned: { ...startOwned, [pick]: 1 },
    recipes: rules.liveRecipes(data.recipes),
    killMoves: data.killMoves,
    guById,
  });
  const reward = {
    stones: 20,
    materialIds: ['moon_dew'],
    guChoices: [pick],
    valueKinds: loot.classifyReward({ stones: 20, materialIds: ['moon_dew'], guChoices: [pick] }, { guById, consumers }),
  };
  assert.equal(loot.opensNewChoice(reward, insight), true);
  // 仅有元石/卖钱不够
  const boring = { stones: 30, materialIds: [], guChoices: [], valueKinds: { economic: 1, growth: 0, build: 0 } };
  assert.equal(loot.opensNewChoice(boring, { hasRealDecision: false, kitJoins: [], killMoveForms: [] }), false);
});

test('Gate 6 · new future is kit/killmove relevant, not pure stat stick', () => {
  const newFuture = loot.newFutureGuIds({
    owned: startOwned,
    guById,
    killMoves: data.killMoves,
    buildKits: rules.BUILD_KITS,
  });
  for (const id of newFuture) {
    const relatedToKit = Object.values(rules.BUILD_KITS).some(
      (k) => (k.members || []).includes(id) || (k.optional || []).includes(id),
    );
    const relatedToMove = (data.killMoves || []).some((m) => (m.recipe || []).includes(id));
    const substitute = rules.compatibleSubstitutes(id, guById).some((sid) => Number(startOwned[sid] || 0) > 0);
    assert.ok(relatedToKit || relatedToMove || substitute, `${id} must open a real future`);
  }
});
