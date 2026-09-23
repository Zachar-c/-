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
const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
const rules = rulesContext.GuRules;
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));
const recipes = rules.liveRecipes(data.recipes);

const startOwned = {
  moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
  jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
};

test('Gate 4 · live graph has ≥1 real fork node with 2 destinations', () => {
  const forks = rules.forkGroups(data.recipes);
  assert.ok(forks.length >= 1, 'need at least one fork');
  const moon = forks.find((f) => f.branches.length >= 2);
  assert.ok(moon, 'need a two-destination fork');
  const outs = new Set(moon.branches.map((b) => b.output));
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

test('Gate 4 · choosing one branch closes or delays the other future', () => {
  const moon = data.recipes.find((r) => r.id === 'moonlight_glow');
  const ray = data.recipes.find((r) => r.id === 'moon_ray_forged');
  assert.ok(moon && ray);
  assert.ok((moon.closes || []).length || (moon.delays || []).length);
  assert.ok((ray.closes || []).length || (ray.delays || []).length);
  assert.deepEqual([...(moon.inputs || [])].sort(), [...(ray.inputs || [])].sort());
  const afterA = { ...startOwned };
  for (const id of moon.inputs) afterA[id] -= 1;
  afterA[moon.output] = (afterA[moon.output] || 0) + 1;
  assert.equal(Number(afterA.small_light_gu || 0), 0, 'inputs consumed — other branch unreachable');
  assert.equal(Number(afterA.moon_ray_gu || 0), 0);
});

test('Gate 4 · same start, forge A vs B diverge in kit / matchup within 3 fights', () => {
  const sigs = rules.forgeBranchSignatures('fork_moonlight_small', data.recipes, {
    owned: startOwned,
    guById,
    killMoves: data.killMoves,
  });
  assert.equal(sigs.length, 2);
  assert.notEqual(sigs[0].signature, sigs[1].signature, 'A/B must diverge immediately');

  const infoKit = rules.actionStructureFor('kit_info_suppress', { problemAxis: 'info' });
  const burstKit = rules.actionStructureFor('kit_pierce_burst', { problemAxis: 'armor' });
  assert.notEqual(infoKit.signature, burstKit.signature);

  const jadeSigs = rules.forgeBranchSignatures('fork_jade_boar', data.recipes, {
    owned: startOwned,
    guById,
    killMoves: data.killMoves,
  });
  assert.equal(jadeSigs.length, 2);
  assert.notEqual(jadeSigs[0].signature, jadeSigs[1].signature);
});

test('Gate 4 · products enter Phase 1 problem system (not pure stat sticks)', () => {
  for (const id of ['moon_glow_gu', 'moon_ray_gu', 'white_jade_gu', 'bear_strength_gu']) {
    assert.ok(guById[id], id);
    const tags = rules.buildTagsOf(guById[id], guById);
    const role = rules.buildRoleOf(guById[id], guById);
    assert.ok(tags.length > 0 || role !== 'Core' || (guById[id].battleEffect || {}).kind !== 'strike',
      `${id} should map to a solution role/verb`);
  }
  assert.equal(guById.moon_glow_gu.battleEffect.suppress, true);
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
