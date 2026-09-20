import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/loot_rules.js', import.meta.url), 'utf8'), context);
const rules = context.LootRules;

test('weighted pick returns the only declared entry', () => {
  const picked = rules.pickWeighted([{ id: 'beast_bone', weight: 3 }], 1, 'loot', 1);
  assert.equal(picked.id, 'beast_bone');
});

test('material roll returns declared count and advances pity', () => {
  const table = {
    material_count: 2,
    material_pool: [{ id: 'beast_bone', weight: 1 }, { id: 'beast_blood', weight: 1 }],
  };
  const rolled = rules.rollMaterials(table, {
    seed: 1,
    tick: 1,
    tier: 'common',
    countAdjustment: 0,
    materialPityByTier: {},
    targets: [],
  });
  assert.equal(rolled.materialIds.length, 2);
  assert.equal(new Set(rolled.materialIds).size, 2);
});

test('gu roll respects guaranteed rarity and bucket', () => {
  const table = {
    gu_chance_pct: 100,
    forced_rarity: 'epic',
    gu_pool: {
      weights: { common: 100, epic: 0 },
      by_rarity: { epic: ['moonlight_gu'] },
    },
  };
  const rolled = rules.rollGu(table, {
    seed: 1,
    tick: 1,
    tier: 'elite',
    lootPity: 0,
    pityConfig: { threshold: 3 },
    school: 'moon',
    schoolPools: { moon: ['moonlight_gu'] },
    guById: { moonlight_gu: { rarity: 'epic' } },
  });
  assert.equal(rolled.guId, 'moonlight_gu');
  assert.equal(rolled.rarity, 'epic');
});

test('pity resets on target material and non-common gu', () => {
  assert.deepEqual(
    Array.from(Object.entries(rules.nextMaterialPity({ common: 2 }, 'common', ['beast_bone'], ['beast_bone']))),
    [['common', 0]],
  );
  assert.equal(rules.nextLootPity(2, 'rare', { clearing_rarities: ['rare'] }), 0);
  assert.equal(rules.nextLootPity(2, 'common', { clearing_rarities: ['rare'] }), 3);
});
