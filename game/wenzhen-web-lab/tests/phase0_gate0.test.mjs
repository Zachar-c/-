/** Gate 0 · Phase 0 可信实验基线
 *  L0 2026-09-25：UI / 门禁 / resolver 必须一致；组件条件默认继承；
 *  advance 自环与无机械收益古方不得进入 live 可见路径；Boss 蛊池不得为空。
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
const rules = rulesContext.GuRules;

const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));

test('Gate 0 · boss gu pool is non-empty and draws from real gu ids', () => {
  const boss = data.loot.tables.boss;
  const byRarity = boss.gu_pool.by_rarity || {};
  const ids = Object.values(byRarity).flat().map(String);
  assert.ok(ids.length > 0, 'boss gu_pool.by_rarity must not be empty');
  for (const id of ids) assert.ok(guById[id], `boss pool id missing from gu table: ${id}`);
  assert.ok(Object.keys(boss.gu_pool.weights || {}).length > 0);
});

test('Gate 0 · advance self-loops are retired and not live-visible', () => {
  // D3 真源纪律：自环 advance 不得进入 lab 导出；源表已 retired。
  const exported = data.recipes.filter((r) => r.kind === 'advance' || String(r.id).startsWith('advance_'));
  assert.equal(exported.length, 0, 'advance self-loops must not be exported to lab data');
  const live = rules.liveRecipes(data.recipes);
  for (const recipe of live) {
    const inputs = [...recipe.inputs].map(String);
    assert.ok(!(inputs.length === 1 && inputs[0] === String(recipe.output)), `${recipe.id} is a self-loop`);
  }
  for (const recipe of data.recipes) {
    assert.equal(rules.isLiveRecipe({ ...recipe, retired: true }), false);
  }
});

test('Gate 0 · gu_fang offers without mechanical benefit are not purchasable growth', () => {
  const exported = data.shopOffers.filter((o) => o.kind === 'gu_fang_unlock');
  assert.equal(exported.length, 0, 'gu_fang must not be exported as formal growth until mechanical');
  assert.equal(rules.liveShopOffers(data.shopOffers).some((o) => o.kind === 'gu_fang_unlock'), false);
  assert.equal(rules.isLiveShopOffer({ kind: 'gu_fang_unlock', mechanical: false }), false);
  assert.equal(rules.isLiveShopOffer({ kind: 'gu_fang_unlock', retired: true }), false);
});

test('Gate 0 · kill move display/gate/resolver share component battleEffect authority', () => {
  const move = data.killMoves.find((m) => m.id === 'km_blood_ember');
  assert.ok(move, '血昙 must exist');
  const fullHp = { hp: 20, hpMax: 20, enemiesAlive: 1, turn: 1, statusStacks: {} };
  const lowHp = { hp: 5, hpMax: 20, enemiesAlive: 1, turn: 1, statusStacks: {} };

  // 组件条件默认继承：满血时血昙门禁必须失败（爱别离 hp<50%）
  assert.equal(rules.killMoveGateMissReason(move, guById, fullHp), 'condition_miss');
  assert.equal(rules.killMoveGateMissReason(move, guById, lowHp), '');

  // 满血时合成结果不得把条件组件算进去
  const fullPlan = rules.killMoveEffectPlan(move, guById, fullHp);
  assert.equal(fullPlan.damage, 2, 'only blood_droplet contributes at full HP');
  assert.equal(fullPlan.heal, 0);
  const lowPlan = rules.killMoveEffectPlan(move, guById, lowHp);
  assert.equal(lowPlan.damage, 6, 'both components at low HP');
  assert.equal(lowPlan.heal, 0, 'components compose to pure strike, not prefab heal_and_strike');

  // 展示、门禁、结算同源
  assert.equal(fullPlan.damage, 2);
  assert.ok(rules.killMoveIsDirectStrike(move, guById, lowHp));
  assert.ok(rules.killMoveIsDirectStrike(move, guById, fullHp));
});

test('Gate 0 · component condition override is explicit and narrow', () => {
  const move = data.killMoves.find((m) => m.id === 'km_blood_ember');
  const fullHp = { hp: 20, hpMax: 20, enemiesAlive: 1, turn: 1, statusStacks: {} };
  const overridden = { ...move, componentConditionOverride: true };
  assert.equal(rules.killMoveGateMissReason(overridden, guById, fullHp), '');
  const plan = rules.killMoveEffectPlan(overridden, guById, fullHp);
  assert.equal(plan.damage, 6, 'override may break component limits only when declared');
});

test('Gate 0 · prefab m.effect never drives kill move settlement', () => {
  const move = data.killMoves.find((m) => m.id === 'km_light_converge');
  const spoofed = {
    ...move,
    effect: { kind: 'strike', amount: 99 },
    damage: 88,
  };
  const plan = rules.killMoveEffectPlan(spoofed, guById, { school: 'light' });
  // 月光 strike3 + 小光 strike1 = 4；支援闩 2 单独挂 support，不是预制 5/99
  assert.equal(plan.damage, 4);
  assert.equal(plan.support?.bonus, 2);
  assert.notEqual(plan.damage, 99);
  assert.notEqual(plan.damage, 88);
});

test('Gate 0 · every live drop gu id resolves and every live purchase has gu or material', () => {
  for (const table of Object.values(data.loot.tables)) {
    for (const id of Object.values(table.gu_pool?.by_rarity || {}).flat()) {
      assert.ok(guById[String(id)], `drop gu missing: ${id}`);
    }
  }
  for (const offer of rules.liveShopOffers(data.shopOffers)) {
    if (offer.kind === 'purchase') assert.ok(guById[offer.gu_id] || offer.gu_id === 'aptitude_gu', offer.id);
    if (offer.kind === 'material_purchase') assert.ok(offer.material_id, offer.id);
  }
});
