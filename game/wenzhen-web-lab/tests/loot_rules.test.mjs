import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/loot_rules.js', import.meta.url), 'utf8'), context);
const rules = context.LootRules;

test('weighted pick returns the only declared entry', () => {
  const picked = rules.pickWeighted([{ id: 'moonlight_gu', weight: 3 }], 1, 'loot', 1);
  assert.equal(picked.id, 'moonlight_gu');
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

test('gu pity resets on a clearing rarity and advances on common', () => {
  assert.equal(rules.nextLootPity(2, 'rare', { clearing_rarities: ['rare'] }), 0);
  assert.equal(rules.nextLootPity(2, 'common', { clearing_rarities: ['rare'] }), 3);
});

test('P5 掉落派生：持蛊敌人被击败后，蛊_chance 命中首选其装载蛊（夺蛊）', () => {
  const table = {
    gu_chance_pct: 100,
    gu_pool: { by_rarity: { rare: ['fire_atk_2_01_gu'] }, weights: { rare: 1 } },
  };
  const guById = Object.fromEntries([
    ['fire_atk_2_01_gu', { id: 'fire_atk_2_01_gu', rarity: 'rare' }],
    ['sword_atk_2_12_gu', { id: 'sword_atk_2_12_gu', rarity: 'rare' }],
    ['stone_shell_gu', { id: 'stone_shell_gu', rarity: 'rare' }],
  ]);
  // 敌人装载 [古剑蛊, 石皮蛊]：首选必为装载蛊之一（夺蛊），候选池含装载蛊与原表
  for (let seed = 1; seed <= 20; seed += 1) {
    const r = rules.rollGuChoices(table, {
      seed, tick: 0, tier: 'elite', guById,
      carriedPool: ['sword_atk_2_12_gu', 'stone_shell_gu'],
    });
    assert.ok(['sword_atk_2_12_gu', 'stone_shell_gu'].includes(r.guIds[0]),
      `seed=${seed} 首选 ${r.guIds[0]} 不在装载池`);
    assert.ok(r.guIds.includes('fire_atk_2_01_gu'), `seed=${seed} 原表蛊应在候选`);
  }
  // 装载蛊不在册（guById 缺）→ 走原表
  const r2 = rules.rollGuChoices(table, {
    seed: 7, tick: 0, tier: 'elite', guById,
    carriedPool: ['ghost_gu'],
  });
  assert.equal(r2.guIds[0], 'fire_atk_2_01_gu');
  // innate 敌人（空池）→ 原表流程
  const r3 = rules.rollGuChoices(table, { seed: 7, tick: 0, tier: 'elite', guById, carriedPool: [] });
  assert.equal(r3.guIds[0], 'fire_atk_2_01_gu');
  // rarity 取装载蛊自身（夺蛊的品阶跟蛊走）
  const r4 = rules.rollGuChoices({
    gu_chance_pct: 100,
    gu_pool: { by_rarity: { common: ['stone_shell_gu'] }, weights: { common: 1 } },
  }, {
    seed: 3, tick: 0, tier: 'elite', guById,
    carriedPool: ['sword_atk_2_12_gu'],
  });
  assert.equal(r4.rarity, 'rare');
});
