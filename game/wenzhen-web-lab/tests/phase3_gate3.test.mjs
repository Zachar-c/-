/** Gate 3 · Phase 3 获得新蛊 → 构筑改变
 *  L0 2026-09-25：关键新蛊入库后至少一个真实决策；重构后 action/resource/matchup 至少一项改变。
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

const insightOf = (guId, owned) => rules.gainInsight(guId, {
  owned,
  recipes: rules.liveRecipes(data.recipes),
  killMoves: data.killMoves,
  guById,
});

const startOwned = {
  moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
  jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
};

test('Gate 3 · key new gu offers a real decision (not only keep/sell)', () => {
  for (const id of ['moon_glow_gu', 'white_jade_gu', 'blood_bat_gu', 'moon_ray_gu']) {
    const owned = { ...startOwned, [id]: 1 };
    const insight = insightOf(id, owned);
    assert.equal(insight.hasRealDecision, true, `${id} must open a real decision`);
    const kinds = new Set(insight.decisions.map((d) => d.kind));
    assert.ok(
      kinds.has('replace') || kinds.has('forge') || kinds.has('killmove') || kinds.has('kit'),
      `${id} decisions: ${[...kinds].join(',')}`,
    );
  }
});

test('Gate 3 · moon_glow completes info kit and changes action pattern', () => {
  const before = rules.kitCoverage('kit_info_suppress', startOwned, guById);
  assert.equal(before.ok, false);
  const afterOwned = { ...startOwned, moon_glow_gu: 1 };
  const after = rules.kitCoverage('kit_info_suppress', afterOwned, guById);
  assert.equal(after.ok, true);

  const insight = insightOf('moon_glow_gu', afterOwned);
  const kitJoin = insight.kitJoins.find((k) => k.kitId === 'kit_info_suppress');
  assert.ok(kitJoin, 'moon_glow must join info kit');
  assert.equal(kitJoin.completes, true);

  // 重构后 action pattern 必须改变：从「只能 inspect」到 inspect→suppress
  const rebuilt = rules.actionStructureFor('kit_info_suppress', { problemAxis: 'info' });
  assert.ok(rebuilt.steps.includes('suppress'));
  assert.ok(rebuilt.steps.includes('inspect'));
  const oldPartial = ['inspect', 'controlled_strike']; // 缺 moon_glow 时无法 suppress
  assert.notDeepEqual([...rebuilt.steps], oldPartial);
});

test('Gate 3 · kill move variants recompute composition (not prefab)', () => {
  const move = data.killMoves.find((m) => m.id === 'km_blood_ember');
  assert.ok(move);
  const owned = { ...startOwned, blood_bat_gu: 1 };
  const variants = rules.killMoveVariants(move, owned, guById);
  assert.ok(variants.length >= 2, 'base + substitute variant');
  const base = variants.find((v) => !v.changed) || variants[0];
  const alt = variants.find((v) => v.changed);
  assert.ok(alt, 'must offer a changed variant when substitute owned');
  // 替代后合成签名必须不同于原配方
  assert.notEqual(alt.signature, base.signature);
  assert.ok(alt.recipe.includes('blood_bat_gu') || alt.recipe.includes('blood_farewell_gu'));
});

test('Gate 3 · white_boar can replace defense/attack slots and shifts matchup vs armor', () => {
  const insight = insightOf('white_boar_strength_gu', startOwned);
  assert.equal(insight.hasRealDecision, true);
  assert.ok(insight.substitutes.length > 0, 'can replace something');
  // 破甲组合使 armor 轴 matchup 改变
  const withPierce = rules.actionStructureFor('kit_pierce_burst', { problemAxis: 'armor' });
  const without = rules.actionStructureFor('kit_stable_sustain', { problemAxis: 'armor' });
  assert.notEqual(withPierce.signature, without.signature);
  assert.ok(withPierce.steps.includes('pierce'));
});

test('Gate 3 · gain insight lists keep/sell plus at least one build path for key pieces', () => {
  const insight = insightOf('moon_glow_gu', { ...startOwned, moon_glow_gu: 1 });
  const kinds = insight.decisions.map((d) => d.kind);
  assert.ok(kinds.includes('keep'));
  assert.ok(kinds.includes('sell') || kinds.includes('forge') || kinds.includes('killmove'));
  assert.ok(insight.killMoveForms.length > 0 || insight.kitJoins.length > 0 || insight.refineInto.length > 0);
});

test('Gate 3 · resource pattern changes when Resource piece enters sustain kit', () => {
  const withoutHeal = { moonlight_gu: 1, blood_droplet_gu: 1 };
  const withHeal = { ...withoutHeal, vitality_grass_gu: 1 };
  assert.equal(rules.kitCoverage('kit_stable_sustain', withoutHeal, guById).ok, false);
  assert.equal(rules.kitCoverage('kit_stable_sustain', withHeal, guById).ok, true);
  const insight = insightOf('vitality_grass_gu', withHeal);
  const join = insight.kitJoins.find((k) => k.kitId === 'kit_stable_sustain');
  assert.ok(join && join.completes);
});
