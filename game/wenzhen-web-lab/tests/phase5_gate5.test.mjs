/** Gate 5 · Phase 5 材料 = 配方钥匙 / 定向追逐
 *  L0 2026-09-25：正式掉落材料 100% 有 Consumer；两条 Build→配方→缺材料→选敌链。
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
const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), rulesContext);
vm.runInContext(fs.readFileSync(new URL('../js/loot_rules.js', import.meta.url), 'utf8'), rulesContext);
const rules = rulesContext.GuRules;
const loot = rulesContext.LootRules;
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));
const recipes = rules.liveRecipes(data.recipes);
const consumers = rules.materialConsumers(recipes);

test('Gate 5 · every live recipe material is a recipe key with a consumer', () => {
  for (const r of recipes) {
    for (const matId of Object.keys(r.materials || {})) {
      assert.ok((consumers[matId] || []).includes(r.id), `${matId} must consume via ${r.id}`);
    }
    if (r.forkId) {
      assert.ok(Object.keys(r.materials || {}).length >= 1, `${r.id} fork branch needs a material key`);
    }
  }
  assert.ok(Object.keys(consumers).length >= 2);
});

test('Gate 5 · formal drop pool only carries consumer materials', () => {
  for (const [tier, table] of Object.entries(data.loot.tables)) {
    const filtered = loot.consumerFilter(table.material_pool, consumers);
    assert.ok(filtered.length > 0, `${tier} pool must keep consumer keys`);
    for (const entry of filtered) {
      assert.ok((consumers[entry.id] || []).length > 0, `${entry.id} in ${tier} drop without consumer`);
    }
  }
});

test('Gate 5 · chain A: info kit → moon_glow → moon_dew → stone wanderer', () => {
  const chain = rules.farmChain('kit_info_suppress', {
    recipes,
    enemies: data.enemies,
    owned: {},
    materials: {},
    guById,
  });
  assert.ok(chain, 'info kit farm chain');
  assert.ok(chain.missing.some((m) => m.materialId === 'moon_dew'));
  const chaseIds = chain.chase.map((c) => c.enemyId);
  assert.ok(chaseIds.includes('neutral_stone_wanderer'), `chase must include stone wanderer: ${chaseIds.join(',')}`);
  const enemy = data.enemies.find((e) => e.id === 'neutral_stone_wanderer');
  assert.ok((enemy.preferredMaterials || []).includes('moon_dew'));
});

test('Gate 5 · chain B: sustain kit → bear → venom_sac → ridge hound (choose enemy B)', () => {
  const chain = rules.farmChain('bear_split', {
    recipes,
    enemies: data.enemies,
    owned: {},
    materials: {},
    guById,
  });
  assert.ok(chain);
  assert.ok(chain.missing.some((m) => m.materialId === 'venom_sac'));
  const chaseIds = chain.chase.map((c) => c.enemyId);
  assert.ok(chaseIds.includes('ridge_hound'), `chase must include ridge hound: ${chaseIds.join(',')}`);
  // 与链 A 的目标敌人不同 → 玩家选择敌人因此变化
  const chainA = rules.farmChain('moonlight_glow', {
    recipes, enemies: data.enemies, owned: {}, materials: {}, guById,
  });
  const aIds = new Set(chainA.chase.map((c) => c.enemyId));
  const bIds = new Set(chain.chase.map((c) => c.enemyId));
  assert.ok([...bIds].some((id) => !aIds.has(id)), 'chains must diverge on enemy choice');
});

test('Gate 5 · preferred enemy materials win more rolls (targeted farm)', () => {
  const table = data.loot.tables.common;
  const plain = [];
  const boosted = [];
  for (let tick = 1; tick <= 20; tick += 1) {
    plain.push(...loot.rollMaterials(table, {
      seed: 101, tick, tier: 'common', consumers, preferred: [],
    }).materialIds);
    boosted.push(...loot.rollMaterials(table, {
      seed: 101, tick, tier: 'common', consumers, preferred: ['moon_dew'],
    }).materialIds);
  }
  const count = (arr, id) => arr.filter((x) => x === id).length;
  assert.ok(count(boosted, 'moon_dew') >= count(plain, 'moon_dew'),
    `moon_dew should not decrease under affinity: ${count(plain, 'moon_dew')} → ${count(boosted, 'moon_dew')}`);
  assert.ok(count(boosted, 'moon_dew') > 0, 'affinity must actually deliver the key material sometimes');
  // 无 Consumer 的 mat_* 不得出现在正式掉落
  assert.equal(plain.filter((id) => String(id).startsWith('mat_')).length, 0);
  assert.equal(boosted.filter((id) => String(id).startsWith('mat_')).length, 0);
});

test('Gate 5 · material role is recipe_key not universal currency', () => {
  for (const r of recipes) {
    if (r.materialRole) assert.equal(r.materialRole, 'recipe_key');
    if (Object.keys(r.materials || {}).length) {
      assert.ok(r.farmHint, `${r.id} must tell the player where to farm`);
    }
  }
});
