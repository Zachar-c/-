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

function previewContext(overrides = {}) {
  const context = vm.createContext({ DATA: data, GuRules: rules });
  vm.runInContext(fs.readFileSync(new URL('../js/run_flow.js', import.meta.url), 'utf8'), context);
  context.currentKillMoves = () => data.killMoves;
  context.GU_BY_ID = Object.fromEntries(data.gu.map((gu) => [gu.id, gu]));
  context.guById = (id) => context.GU_BY_ID[id] || null;
  context.state = {
    owned: {}, cultivation: 1, cultivationStage: 0, aptitude: 'bing', stones: 0,
    modifierLedger: [], ...overrides,
  };
  context.schoolLabel = (school) => school;
  const source = fs.readFileSync(new URL('../js/journey.js', import.meta.url), 'utf8');
  const start = source.indexOf('function guChoicePreview(');
  const end = source.indexOf('\nfunction shopOfferCard(', start);
  assert.ok(start >= 0 && end > start, 'guChoicePreview source block exists');
  vm.runInContext(`${source.slice(start, end)}; globalThis.preview = guChoicePreview;`, context);
  return context;
}

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

test('Gate 7 · purchase preview compares post-buy stones with the complete moon-glow recipe', () => {
  const make = (stones, remaining) => {
    const context = previewContext({ stones, owned: { moonlight_gu: 1, small_light_gu: 1 } });
    const before = JSON.stringify(context.state);
    const html = context.preview('small_light_gu', 6);
    assert.equal(JSON.stringify(context.state), before, 'preview leaves state unchanged');
    assert.match(html, new RegExp(`购后元石\\s*${remaining}`));
    assert.match(html, /突破[^<]*(元石|资金)[^<]*(可付|足|能付)/);
    return html;
  };
  const enough = make(16, 10);
  assert.match(enough, /月芒蛊：组件齐备/);
  assert.match(enough, /已备配方[^<]*月芒[^<]*可付 10 元石/);
  const poor = make(15, 9);
  assert.match(poor, /月芒蛊：组件齐备/);
  assert.match(poor, /已备配方[^<]*月芒[^<]*资金还差 1/);
});

test('Gate 7 · reward preview without a purchase cost omits post-buy budget', () => {
  const context = previewContext({ stones: 16, owned: { moonlight_gu: 1, small_light_gu: 1 } });
  const html = context.preview('small_light_gu');
  assert.doesNotMatch(html, /购后元石/);
});

test('Gate 7 · post-buy breakthrough preview respects sari, aptitude, and max-rank gates', () => {
  const sari = previewContext({ stones: 6, owned: { gold_atk_2_12_gu: 1 } });
  const sariHtml = sari.preview('small_light_gu', 6);
  assert.match(sariHtml, /元石还差 2/);
  assert.match(sariHtml, /已持有的同阶舍利/);
  assert.doesNotMatch(sariHtml, /可突破|突破成功/);

  const aptitude = previewContext({
    stones: 30, cultivation: 1, cultivationStage: 3, aptitude: 'ding',
  });
  assert.match(aptitude.preview('small_light_gu', 6), /资质[^<]*(不足|未达|需要|需)/);
  assert.doesNotMatch(aptitude.preview('small_light_gu', 6), /仍可突破/);

  const maxed = previewContext({ stones: 30, cultivation: 5, cultivationStage: 3, aptitude: 'jia' });
  assert.match(maxed.preview('small_light_gu', 6), /巅峰|max|上限/i);
});
