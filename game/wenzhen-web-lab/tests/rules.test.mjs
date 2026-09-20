import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/rules.js', import.meta.url), 'utf8'), context);

test('intent text exposes soul drain before the enemy turn', () => {
  assert.equal(
    context.intentText({
      id: 'soul_gnaw',
      label: '噬魂魔功',
      kind: 'soul_drain',
      soul_drain: 1,
      damage: 0,
    }),
    '噬魂魔功（抽魂 1）',
  );
});

test('intent text exposes lifespan cost before the enemy turn', () => {
  assert.equal(
    context.intentText({
      id: 'burn_lifespan',
      label: '燃命术',
      kind: 'life_cost',
      life_cost: 2,
      damage: 0,
    }),
    '燃命术（寿元 2）',
  );
});
