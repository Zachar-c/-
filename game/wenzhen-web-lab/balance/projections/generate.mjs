/* generate.mjs — 由 canonical + models 写出 generated/。禁止手改 generated。 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const load = (p) => JSON.parse(readFileSync(join(root, p), 'utf8'));
const save = (p, obj) => {
  const full = join(root, p);
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, JSON.stringify(obj, null, 2) + '\n', 'utf8');
  console.log('wrote', p);
};

const projSrc = readFileSync(join(root, 'projections/index.js'), 'utf8');
new Function('globalThis', 'module', 'exports', projSrc)(globalThis, { exports: {} }, {});
const VP = globalThis.VProject;

const identities = load('canonical/gu/moon_gu_identity.json');
const ranks = load('models/rank_profiles/ranks.json');
const quality = load('models/quality_profiles/quality.json');
const effects = load('models/effect_archetypes/effects.json');
const economy = load('models/economy/economy_curves.json');
const dao = load('canonical/dao/dao_profiles.json').daos;
const enemiesM = load('models/enemy_archetypes/archetypes.json');
const refineM = load('models/refinement/graph.json');
const dropsM = load('models/drops/ecology.json');

const scales = {
  enemyHpMid: { 1: 14, 2: 25, 3: 40, 4: 62, 5: 92 },
  enemyDamageBase: { 1: 3, 2: 6, 3: 10, 4: 15, 5: 22 },
};

const ctx = { effects, ranks, quality, economy, dao, scales };

const gu_stats = identities.gu.map((idn) => VP.projectGu(idn, ctx));
save('generated/gu_stats.json', {
  generator: 'projections/index.js',
  forbidden_hand_edit: true,
  generated_at: new Date().toISOString(),
  count: gu_stats.length,
  gu: gu_stats,
});

const enemy_stats = [];
for (const arch of Object.values(enemiesM.archetypes)) {
  for (let r = 1; r <= 5; r++) enemy_stats.push(VP.projectEnemy(arch, r, { scales }));
}
save('generated/enemy_stats.json', {
  generator: 'projections/index.js',
  forbidden_hand_edit: true,
  count: enemy_stats.length,
  enemies: enemy_stats,
});

// 炼制期望成本（拓扑来自 model，成本推导）
const priceOf = Object.fromEntries(gu_stats.map((g) => [g.id, g.economy.marketPrice]));
const edges = (refineM.canon_edges || []).map((e, i) => {
  const success = refineM.success_rate_by_rank_output[String(gu_stats.find((g) => g.id === e.to)?.rank || 2)];
  let once = 40 * e.from.length;
  for (const id of e.from) once += priceOf[id] || 50;
  const expected = once / success;
  return {
    id: 'R' + String(i + 1).padStart(2, '0'),
    from: e.from,
    to: e.to,
    origin: e.origin,
    fact: e.fact,
    success,
    onceCost: once,
    expectedCost: Math.round(expected),
    marketPrice: priceOf[e.to],
    ratio: priceOf[e.to] / expected,
  };
});
save('generated/refine_projection.json', {
  generator: 'projections',
  forbidden_hand_edit: true,
  edges,
});

save('generated/shop_tables.json', {
  generator: 'projections',
  forbidden_hand_edit: true,
  note: '价格 = intrinsic × tier × scarcity × supply × demand × markup，不写死在蛊上',
  tiers: Object.fromEntries(
    [1, 2, 3, 4, 5].map((t) => {
      const stock = gu_stats.filter((g) => g.rank === t).map((g) => ({
        id: g.id,
        marketPrice: g.economy.marketPrice,
        intrinsic: g.intrinsic_value,
      }));
      return [t, { income_base: economy.tiers[String(t)].income_base, stock }];
    })
  ),
});

save('generated/drop_tables.json', {
  generator: 'projections',
  forbidden_hand_edit: true,
  note: '由 ecology + wealth_class 推；详见 models/drops/ecology.json',
  wealth_classes: dropsM.wealth_classes,
  pity: dropsM.pity,
  // 简化投影：按 enemy ecology.material_bias 展开权重
  by_archetype: Object.fromEntries(
    Object.values(enemiesM.archetypes).map((a) => [
      a.id,
      {
        wealth_class: a.ecology.wealth_class,
        material_bias: a.ecology.material_bias,
        gu_drop_base: a.ecology.wealth_class === 'cultivator' ? 'medium' : 'low',
      },
    ])
  ),
});

save('generated/dependency_index.json', {
  generator: 'projections',
  forbidden_hand_edit: true,
  note: '数值 → 依赖追溯',
  example: {
    'moon_glow_gu.combat.damage': [
      'canonical/gu/moon_gu_identity.json#moon_glow_gu',
      'models/effect_archetypes/effects.json#burst_projectile',
      'models/rank_profiles/ranks.json#2',
      'models/quality_profiles/quality.json#excellent',
    ],
    'moon_glow_gu.economy.marketPrice': [
      'value_vector ← combat + refinement + killer_move',
      'models/economy/economy_curves.json#tiers.2',
      'traits.scarcity',
    ],
  },
  impact_of: {
    'scarcity.small_light': ['moon_glow_gu', 'kill_moves using small_light', 'shop tier1-2', 'drop pools', 'refine edges into moon_glow'],
  },
});

console.log('generated/ OK', gu_stats.length, 'gu', enemy_stats.length, 'enemies');
