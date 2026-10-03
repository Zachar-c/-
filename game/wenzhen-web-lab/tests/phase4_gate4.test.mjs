/** Gate 4 · Phase 4 最小炼蛊分支
 *  L0 2026-09-25：同投入二选一；炼一支关闭/推迟另一未来；不是 damage 5 vs 7。
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
const sourceRecipes = JSON.parse(fs.readFileSync(new URL('../../data/refinement_recipes.json', import.meta.url), 'utf8')).recipes;
const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
const rules = rulesContext.GuRules;
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));
const recipes = rules.liveRecipes(data.recipes);

const startOwned = {
  moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_leaf_gu: 1,
  jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
};

test('Gate 4 · live graph has a real non-moon fork with 2 destinations', () => {
  const forks = rules.forkGroups(data.recipes);
  assert.ok(forks.length >= 1, 'need at least one fork');
  const fork = forks.find((f) => f.forkId === 'fork_jade_boar' && f.branches.length >= 2);
  assert.ok(fork, 'need the live jade/boar two-destination fork');
  const outs = new Set(fork.branches.map((b) => b.output));
  assert.ok(outs.size >= 2, 'destinations must be different outputs');
});

test('Gate 4 · fork branches are not just numeric deltas', () => {
  const forks = rules.forkGroups(data.recipes);
  for (const fork of forks) {
    const kinds = fork.branches.map((b) => {
      const gu = guById[b.output] || {};
      const eff = gu.battleEffect || gu.v1_effect || {};
      return `${eff.kind || '?'}|${b.branchAxis || gu.buildRole || ''}`;
    });
    assert.ok(new Set(kinds).size >= 2, `branches must differ in kind: ${kinds.join(' ;; ')}`);
  }
});

test('Gate 4 · moon recipes preserve canon boundaries and leave missing branches unimplemented', () => {
  const moon = data.recipes.find((r) => r.id === 'moonlight_glow');
  const ray = sourceRecipes.find((r) => r.id === 'moon_ray_forged');
  const oldFixed = sourceRecipes.find((r) => r.id === 'moon_glow_fixed');
  assert.ok(moon && ray && oldFixed);
  assert.deepEqual([...moon.inputs].sort(), ['moonlight_gu', 'small_light_gu', 'small_light_gu'].sort());
  assert.equal(moon.output, 'moon_glow_gu');
  assert.equal(moon.branchAxis, 'burst');
  assert.match(moon.branchLabel, /月芒.*(高伤|爆发)/);
  assert.equal(moon.stoneCost, 10, '10 stones is a public trial budget, not a canon fact');
  assert.equal(moon.forkId, null);
  assert.deepEqual([...moon.closes], []);
  assert.deepEqual([...moon.delays], []);
  assert.deepEqual(ray.input_gu_ids, ['moonlight_gu', 'small_light_gu']);
  assert.equal(ray.output_gu_id, 'moon_ray_gu');
  assert.equal(ray.retired, true, '月痕 requires 痕石蛊; range behavior is not implemented here');
  assert.equal(oldFixed.retired, true, 'keep the superseded canon recipe as history');
  assert.ok(!recipes.some((r) => ['moon_ray_forged', 'moon_glow_fixed'].includes(r.id)));
});

test('Gate 4 · moon-glow forge is disabled at 9 stones and available at 10', () => {
  const alchemyContext = vm.createContext({
    DATA: data,
    GuRules: rules,
    GU_BY_ID: guById,
    state: { owned: { moonlight_gu: 1, small_light_gu: 2 }, wild: {}, stones: 9, qi: 20 },
    effectText: () => '',
  });
  vm.runInContext(
    fs.readFileSync(new URL('../js/alchemy.js', import.meta.url), 'utf8') + ';globalThis.renderAlchemy = renderAlchemy;',
    alchemyContext,
  );
  const htmlAt = (stones) => {
    alchemyContext.state.stones = stones;
    const root = { innerHTML: '' };
    alchemyContext.renderAlchemy(root);
    return root.innerHTML.match(/<div class="recipe[\s\S]*?data-forge="moonlight_glow"[\s\S]*?<\/div>/)?.[0] || '';
  };
  assert.match(htmlAt(9), /<button disabled data-forge="moonlight_glow">/);
  assert.match(htmlAt(9), /元石不足/);
  assert.match(htmlAt(10), /<button  data-forge="moonlight_glow">/);
  assert.doesNotMatch(htmlAt(10), /元石不足/);
});

test('Gate 4 · same start, live jade/boar branches diverge in build future', () => {
  const sigs = rules.forgeBranchSignatures('fork_jade_boar', data.recipes, {
    owned: startOwned,
    guById,
    killMoves: data.killMoves,
  });
  assert.equal(sigs.length, 2);
  assert.notEqual(sigs[0].signature, sigs[1].signature, 'A/B must diverge immediately');

  assert.notEqual(sigs[0].signature, sigs[1].signature);
});

test('Gate 4 · products enter Phase 1 problem system (not pure stat sticks)', () => {
  for (const id of ['moon_glow_gu', 'moon_ray_gu', 'white_jade_gu', 'bear_strength_gu']) {
    assert.ok(guById[id], id);
    const tags = rules.buildTagsOf(guById[id], guById);
    const role = rules.buildRoleOf(guById[id], guById);
    assert.ok(tags.length > 0 || role !== 'Core' || (guById[id].battleEffect || {}).kind !== 'strike',
      `${id} should map to a solution role/verb`);
  }
  assert.equal(guById.moon_glow_gu.buildRole, 'Core');
  assert.equal(guById.moon_glow_gu.battleEffect.kind, 'strike');
  assert.equal(guById.moon_glow_gu.battleEffect.amount, 9);
  assert.equal(guById.moon_glow_gu.battleEffect.ignoreEvasion, true);
  assert.equal(guById.moon_glow_gu.battleEffect.suppress, undefined);
  assert.equal(guById.moon_glow_gu.battleEffect.suppressWhenRevealed, undefined);
  const insight = rules.gainInsight('moon_ray_gu', {
    owned: { ...startOwned, moon_ray_gu: 1 },
    recipes,
    killMoves: data.killMoves,
    guById,
  });
  assert.equal(insight.hasRealDecision, true);
});

test('Gate 4 · no strictly dominated recipe in the live fork graph', () => {
  for (const r of recipes) {
    assert.equal(rules.isStrictlyDominatedRecipe(r, recipes), false, `${r.id} must not be dominated`);
  }
  assert.ok(!recipes.some((r) => r.id === 'moon_glow_fixed'));
  assert.ok(!recipes.some((r) => r.id === 'white_jade_advance'));
});
