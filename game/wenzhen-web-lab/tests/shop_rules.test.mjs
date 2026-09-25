import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/shop_rules.js', import.meta.url), 'utf8'), context);
const rules = context.ShopRules;
const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const data = dataContext.DATA;

const offers = [
  { id: 'a_t1', kind: 'purchase', tier: 1, gu_id: 'a' },
  { id: 'c_t2', kind: 'purchase', tier: 2, gu_id: 'c' },
  { id: 'd_t2', kind: 'purchase', tier: 2, gu_id: 'd', school: 'sword' },
  { id: 'e_service', kind: 'soul_boost', tier: 9 },
  { id: 'f_npc', kind: 'purchase', tier: 1, gu_id: 'f', npc_only: true },
  { id: 'g_fang', kind: 'gu_fang_unlock', tier: 1, gu_id: 'g', mechanical: false, retired: true },
  { id: 'h_fang_live', kind: 'gu_fang_unlock', tier: 1, gu_id: 'h', mechanical: true },
];
const pacingLayers = { 1: { shop_max_tier: 1, shop_price_pct: 0 } };

test('shop slots follow layer and goods keep services off the shelf budget', () => {
  assert.equal(rules.slotCount(1), 4);
  assert.equal(rules.slotCount(2), 5);
  assert.equal(rules.slotCount(5), 6);
  assert.deepEqual(rules.goodsPool(offers, { pacingLayers, layer: 1, school: 'light' }), ['a_t1']);
  assert.equal(rules.offerIsStocked(offers, 'e_service', { seed: 1, nodeKey: 'shop', pacingLayers, layer: 1 }), false);
  // L0 2026-09-25 Phase 0：无机械收益古方不得上架
  assert.equal(rules.offerIsStocked(offers, 'g_fang', { seed: 1, nodeKey: 'shop', pacingLayers, layer: 1 }), false);
  assert.equal(rules.offerIsStocked(offers, 'h_fang_live', { seed: 1, nodeKey: 'shop', pacingLayers, layer: 1 }), true);
  assert.equal(rules.offerIsStocked(offers, 'f_npc', { seed: 1, nodeKey: 'shop', pacingLayers, layer: 1 }), false);
});

test('shop stock is deterministic, unique, and bounded by the layer pool', () => {
  const offersAtLayer2 = offers.map((offer) => ({ ...offer }));
  const config = { seed: 20260920, nodeKey: 'ridge_black_market', pacingLayers: { 2: { shop_max_tier: 2, shop_price_pct: 10 } }, layer: 2, school: 'sword' };
  const first = rules.stock(offersAtLayer2, config);
  const second = rules.stock(offersAtLayer2, config);
  const pool = rules.goodsPool(offersAtLayer2, { pacingLayers: config.pacingLayers, layer: 2, school: 'sword' });
  assert.deepEqual(first, second);
  assert.equal(new Set(first).size, first.length);
  assert.equal(first.length, Math.min(rules.slotCount(2), pool.length));
  assert.ok(first.every((id) => pool.includes(id)));
  assert.ok(first.includes('c_t2') || first.includes('d_t2'));
  assert.ok(first.includes('d_t2'));
});

test('shop layer price matches the configured markup', () => {
  assert.equal(rules.layerPrice(pacingLayers, 1, 6), 6);
  assert.equal(rules.layerPrice({ 2: { shop_price_pct: 10 } }, 2, 6), 6);
  assert.equal(rules.layerPrice({ 3: { shop_price_pct: 20 } }, 3, 6), 7);
});

test('Web shop stock is limited to Gu purchases', () => {
  const parityOffers = [
    { id: 'purchase_jade_skin_gu', kind: 'purchase', tier: 1 },
    { id: 'purchase_mending_grass', kind: 'purchase', tier: 1 },
    { id: 'purchase_small_light_gu', kind: 'purchase', tier: 1 },
    { id: 'purchase_stone_shell', kind: 'purchase', tier: 1 },
    { id: 'purchase_white_boar_strength_gu', kind: 'purchase', tier: 1 },
  ];
  const stock = rules.stock(parityOffers, {
    seed: 101,
    nodeKey: 'beast_swarm_pass',
    pacingLayers,
    layer: 1,
    school: 'light',
  });
  assert.equal(stock.length, 4);
  assert.ok(stock.every((id) => parityOffers.find((offer) => offer.id === id)?.kind === 'purchase'));
});

test('generated shop and NPC stock only reference retained offers', () => {
  const offerIds = new Set(data.shopOffers.map((offer) => offer.id));
  assert.ok(data.shopOffers.every((offer) =>
    rules.goodsKinds.includes(offer.kind) || rules.serviceKinds.includes(offer.kind)));
  assert.ok(data.npcs.every((npc) =>
    (npc.stock || []).every((id) => offerIds.has(id))));
  assert.equal(
    data.npcs.flatMap((npc) => npc.stock || []).find((id) => id === 'barter_unknown_gu'),
    undefined,
  );
});
