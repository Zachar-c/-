/** Gate 7 · Phase 7 经济三竞争
 *  L0 2026-09-24：买蛊 / 存突破 / 炼蛊互为竞争；禁唯一策略与无风险循环。
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
vm.runInContext(fs.readFileSync(new URL('../js/shop_rules.js', import.meta.url), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), ctx);
const shop = ctx.ShopRules;
const rules = ctx.GuRules;
const recipes = rules.liveRecipes(data.recipes);
const offers = rules.liveShopOffers(data.shopOffers);

test('Gate 7 · income unit I equals common fight revenue; costs are in fights of I', () => {
  const I = shop.incomeUnit(data.battle.stoneRewards, 'common', 1);
  assert.equal(I, 3);
  assert.equal(shop.fightsOfI(6, I), 2);
  assert.equal(shop.fightsOfI(3, I), 1);
});

test('Gate 7 · build, forge, and breakthrough costs compete for stones', () => {
  const mid = shop.spendPressures({
    stones: 12,
    owned: { moonlight_gu: 1, small_light_gu: 1, jade_skin_gu: 1, white_boar_strength_gu: 1 },
    rank: 1,
    stageIndex: 0,
    offers,
    recipes,
    flow: data.flow,
    stoneRewards: data.battle.stoneRewards,
  });
  const kinds = new Set(mid.options.map((o) => o.kind));
  assert.ok(kinds.has('buy_build'));
  assert.ok(kinds.has('save_breakthrough'));
  assert.ok(kinds.has('forge'));
  assert.equal(mid.incomeUnit, 3);
});

test('Gate 7 · no unique dominant strategy at three game stages', () => {
  const stages = [
    { stones: 3, owned: { moonlight_gu: 1, small_light_gu: 1 }, rank: 1, stageIndex: 0 },
    { stones: 12, owned: { jade_skin_gu: 1, white_boar_strength_gu: 1 }, rank: 1, stageIndex: 1 },
    { stones: 20, owned: { jade_skin_gu: 1, white_boar_strength_gu: 1 }, rank: 1, stageIndex: 2 },
    { stones: 8, owned: { moonlight_gu: 1, small_light_gu: 1 }, rank: 2, stageIndex: 0 },
  ];
  const dominants = [];
  for (const st of stages) {
    const p = shop.spendPressures({
      ...st,
      offers,
      recipes,
      flow: data.flow,
      stoneRewards: data.battle.stoneRewards,
    });
    const bal = shop.strategyBalance(p);
    if (bal.uniqueDominant) dominants.push(bal.leaders[0]);
  }
  assert.deepEqual(dominants, [], `unique dominant strategies found: ${dominants.join(',')}`);
});

test('Gate 7 · forge branches are affordable within a few I, not 16-fight sinks', () => {
  const I = shop.incomeUnit(data.battle.stoneRewards, 'common', 1);
  for (const r of recipes) {
    if (!r.forkId) continue;
    assert.ok(shop.fightsOfI(r.stoneCost || 0, I) <= 6,
      `${r.id} cost ${(r.stoneCost || 0)} = ${shop.fightsOfI(r.stoneCost || 0, I)} I`);
  }
});

test('Gate 7 · no risk-free net-asset loop (buy > sell)', () => {
  assert.equal(shop.hasRiskFreeLoop(offers), false);
  for (const o of offers) {
    if (o.kind !== 'purchase') continue;
    const buy = Number(o.stone_cost || 0);
    const sell = Math.floor(buy * 0.5);
    assert.ok(buy > sell, `${o.id} buy ${buy} must exceed sell ${sell}`);
  }
});
