import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
const load = (relativePath) => vm.runInContext(
  fs.readFileSync(new URL(relativePath, import.meta.url), 'utf8'),
  context,
  { filename: relativePath },
);

load('../js/balance.js');
load('../js/mvp_content.js');
const B = context.MvpBalance;
const content = context.MVP_CONTENT;

test('kitDpr uses moonlight as the sustained engine', () => {
  const kit = B.kitDpr(content.run.owned, content.actions);
  assert.equal(kit.dpr > 1.5 && kit.dpr < 3, true, `dpr=${kit.dpr}`);
  assert.ok(kit.plan.some((p) => p.id === 'moonlight_gu'));
});

test('deriveEnemyHp scales with dpr and turns and counter tax', () => {
  const base = B.deriveEnemyHp({ dpr: 2, targetTurns: 5, zeroRate: 0, margin: 1 });
  assert.equal(base, 10);
  const taxed = B.deriveEnemyHp({ dpr: 2, targetTurns: 5, zeroRate: 0.5, margin: 1 });
  assert.equal(taxed, 5);
  const faster = B.deriveEnemyHp({ dpr: 4, targetTurns: 5, zeroRate: 0, margin: 1 });
  assert.equal(faster, 20);
});

test('counterZeroRate treats intercept and iron as zero-output slots', () => {
  assert.equal(B.counterZeroRate(['draw_light', 'none', 'intercept', 'none']), 0.25);
  assert.equal(B.counterZeroRate(['iron', 'none', 'none']), 1 / 3);
  assert.equal(B.counterZeroRate(['draw_light', 'none', 'intercept', 'none'], { hasSuppress: true }), 0.0625);
});

test('content enemy hp matches balance derivation', () => {
  const ref = content.balanceReport.refDpr;
  for (const [id, seqKey] of [
    ['ridge_hound', 'seqHound'],
    ['iron_hide_boar', 'seqBoar'],
    ['ridge_elite_scout', 'seqSeal'],
  ]) {
    const seq = content.balanceReport.sequences[seqKey];
    const expected = B.deriveEnemyHp({
      dpr: ref,
      targetTurns: content.balanceReport.targetTurns[
        id === 'ridge_hound' ? 'battle_1' : id === 'iron_hide_boar' ? 'battle_2' : 'elite'
      ],
      zeroRate: B.counterZeroRate(seq),
      margin: 1.08,
      minHp: 4,
    });
    assert.equal(content.enemyProfiles[id].hp, expected, id);
  }
});

test('priceGu keeps rank curve as geometric x2 on budget', () => {
  const r1 = B.priceGu({ rank: 1, archetype: 'strike', qi: 1 });
  const r2 = B.priceGu({ rank: 2, archetype: 'strike', qi: 1 });
  assert.equal(r2.budget, r1.budget * 2);
  assert.ok(r2.damage > r1.damage);
});

test('every declared action has a positive power budget (base damage, not expected)', () => {
  for (const [id, action] of Object.entries(content.actions)) {
    const b = B.guBudget(action);
    assert.ok(b.total >= 0, id);
    assert.equal(b.pricingId, 'LAB_PRICING_V1');
    if (B.isDamageAction(action)) {
      assert.equal(b.baseDamage, Number(action.damage || 0), `${id} 定价用 base 伤`);
      assert.ok(B.expectedDamagePerUse(action) >= Number(action.damage || 0), id);
    }
  }
});

test('L1 P0-C1: WORLD 40 projects to LAB 2 via LAB_BUDGET_PROJECTION=20', () => {
  assert.equal(B.LAB_BUDGET_PROJECTION, 20);
  assert.equal(B.LAB.fullGame.rank1PowerBudget / B.LAB_BUDGET_PROJECTION, 2);
  assert.equal(B.priceGu({ rank: 1, archetype: 'strike' }).budget, 2);
  assert.equal(B.priceGu({ rank: 5, archetype: 'strike' }).budget, 32);
});

test('L1 P2-A4: rankMultiplier is 2^(rank-1)', () => {
  assert.equal(B.rankMultiplier(1), 1);
  assert.equal(B.rankMultiplier(2), 2);
  assert.equal(B.rankMultiplier(5), 16);
});

test('L1 P0-H1: deviation >20% requires override_reason', () => {
  const ok = B.checkEncounter({
    name: 't',
    dpr: 2,
    enemyHp: 10,
    turnWindow: [3, 6],
    zeroRate: 0,
    margin: 1,
    targetTurns: 5,
  });
  assert.equal(ok.needsOverride, false);
  assert.equal(ok.overrideOk, true);

  const drifted = B.checkEncounter({
    name: 't',
    dpr: 2,
    enemyHp: 20,
    turnWindow: [3, 6],
    zeroRate: 0,
    margin: 1,
    targetTurns: 5,
  });
  assert.equal(drifted.needsOverride, true);
  assert.equal(drifted.overrideOk, false, '无 reason 不得过');

  const explained = B.checkEncounter({
    name: 't',
    dpr: 2,
    enemyHp: 20,
    turnWindow: [3, 6],
    zeroRate: 0,
    margin: 1,
    targetTurns: 5,
    overrideReason: 'phase shield soak',
  });
  assert.equal(explained.overrideOk, true);
});

test('L1 P1-H2: threat v1 rates frozen', () => {
  assert.equal(B.THREAT_V1.handleRate, 0.35);
  assert.equal(B.THREAT_V1.survivalRateByTier.hound, 0.2);
  assert.equal(B.THREAT_V1.survivalRateByTier.common, 0.25);
  assert.equal(B.THREAT_V1.survivalRateByTier.elite, 0.3);
  assert.equal(B.THREAT_V1.survivalRateByTier.boss, 0.35);
});

test('L1 P1-F1: lab thoughts=2 is intentional layering vs world 3', () => {
  assert.equal(B.LAB.thoughtsPerTurn, 2);
  assert.equal(B.LAB.fullGame.thoughtBaseCapacity, 3);
  assert.equal(B.LAB.LAB_EXCHANGE_RATE.qi, 2);
  assert.equal(B.LAB.fullGame.stoneToEssence, 5);
});
