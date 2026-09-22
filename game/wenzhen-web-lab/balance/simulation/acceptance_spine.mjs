/* 五条复利验收（HANDOFF §26）。只证模型会传染，不证数值绝对正确。 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const bal = join(root, 'balance');
const loadB = (p) => JSON.parse(readFileSync(join(bal, p), 'utf8'));
const run = (p) => {
  const src = readFileSync(join(bal, p), 'utf8');
  new Function('globalThis', 'module', 'exports', src)(globalThis, { exports: {} }, {});
};

run('projections/index.js');
run('projections/killer_moves.js');
run('projections/impact.js');
const VP = globalThis.VProject;
const KM = globalThis.VProjectKM;
const VI = globalThis.VImpact;

const identities = loadB('canonical/gu/moon_gu_identity.json');
const ranks = loadB('models/rank_profiles/ranks.json');
const quality = loadB('models/quality_profiles/quality.json');
const effects = loadB('models/effect_archetypes/effects.json');
const economy = loadB('models/economy/economy_curves.json');
const daoPack = loadB('canonical/dao/dao_profiles.json');
const enemiesM = loadB('models/enemy_archetypes/archetypes.json');
const refineM = loadB('models/refinement/graph.json');
const kmM = loadB('models/killer_moves/composition.json');
const scales = { enemyHpMid: { 1: 14, 2: 25, 3: 40, 4: 62, 5: 92 }, enemyDamageBase: { 1: 3, 2: 6, 3: 10, 4: 15, 5: 22 } };

function deepClone(x) {
  return JSON.parse(JSON.stringify(x));
}

function projectAll(ranksX, daoX, identitiesX, enemiesMX, scarcityPatch = {}) {
  const ctx = { effects, ranks: ranksX, quality, economy, dao: daoX, scales };
  for (const idn of identitiesX.gu) {
    if (scarcityPatch[idn.id] !== undefined) {
      idn.traits = { ...(idn.traits || {}), scarcity: scarcityPatch[idn.id] };
    }
  }
  const gu = identitiesX.gu.map((idn) => VP.projectGu(idn, ctx));
  const byId = Object.fromEntries(gu.map((g) => [g.id, g]));
  const priceOf = Object.fromEntries(gu.map((g) => [g.id, g.economy.marketPrice]));
  const edges = (refineM.canon_edges || []).map((e, i) => {
    const success = refineM.success_rate_by_rank_output[String(byId[e.to]?.rank || 2)];
    let once = 40 * e.from.length;
    for (const id of e.from) once += priceOf[id] || 50;
    return {
      id: 'R' + String(i + 1).padStart(2, '0'),
      from: e.from,
      to: e.to,
      success,
      onceCost: once,
      expectedCost: Math.round(once / success),
      marketPrice: priceOf[e.to],
    };
  });
  const enemies = [];
  for (const arch of Object.values(enemiesMX.archetypes)) {
    for (let r = 1; r <= 5; r++) enemies.push(VP.projectEnemy(arch, r, { scales }));
  }
  const killerMoves = (kmM.skeletons || []).map((s) => KM.projectKillerMove(s, byId));
  return { gu, byId, edges, enemies, killerMoves, priceOf };
}

const checks = [];
const ok = (name, pass, detail) => {
  checks.push({ name, pass: !!pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
};

// baseline
const base = projectAll(deepClone(ranks), daoPack.daos, deepClone(identities), enemiesM);

// 1) 改 RankProfile → 相关蛊重新生成
{
  const r2 = deepClone(ranks);
  r2.profiles['2'].energy_band.floor *= 1.3;
  r2.profiles['2'].energy_band.normal *= 1.3;
  r2.profiles['2'].energy_band.exceptional *= 1.3;
  r2.profiles['2'].qi_cost_base = Math.round(r2.profiles['2'].qi_cost_base * 1.3);
  const next = projectAll(r2, daoPack.daos, deepClone(identities), enemiesM);
  const ids = identities.gu.filter((g) => g.canonical.rank === 2).map((g) => g.id);
  const changed = ids.filter((id) => {
    const a = base.byId[id].combat;
    const b = next.byId[id].combat;
    return a.damage !== b.damage || a.qi !== b.qi || a.block !== b.block;
  });
  const untouched = identities.gu.filter((g) => g.canonical.rank !== 2).map((g) => g.id);
  const leak = untouched.filter((id) => next.byId[id].combat.damage !== base.byId[id].combat.damage && next.byId[id].quality !== 'exceptional');
  ok('1 RankProfile → R2 蛊重生成', changed.length >= 3, `changed=${changed.length}/${ids.length} leakR1R3=${leak.length}`);
}

// 2) 改 MoonDaoProfile → 月系效果/价值重新生成
{
  const dao2 = deepClone(daoPack.daos);
  dao2.moon.value_tilt.control = 2.0;
  const next = projectAll(deepClone(ranks), dao2, deepClone(identities), enemiesM);
  const moonish = identities.gu.filter((g) => g.canonical.dao.includes('moon')).map((g) => g.id);
  const changed = moonish.filter((id) => Math.abs((next.byId[id].value_vector.control || 0) - (base.byId[id].value_vector.control || 0)) > 0.05);
  ok('2 MoonDaoProfile → 月系价值向量重生成', changed.length >= 5, `changed=${changed.length}/${moonish.length}`);
}

// 3) 改小光稀有度 → 小光价 → 月芒炼耗 → 月芒价
{
  const next = projectAll(deepClone(ranks), daoPack.daos, deepClone(identities), enemiesM, {
    small_light_gu: 'extreme',
  });
  const pSmall = next.byId.small_light_gu.economy.marketPrice;
  const pSmall0 = base.byId.small_light_gu.economy.marketPrice;
  const eGlow = next.edges.find((e) => e.to === 'moon_glow_gu');
  const eGlow0 = base.edges.find((e) => e.to === 'moon_glow_gu');
  // 月芒自身价由 intrinsic 决定，炼耗变化应体现在 expectedCost；需求拉动可再进 economy——此处验证链上 cost 传染
  const costUp = eGlow.expectedCost > eGlow0.expectedCost;
  const smallUp = pSmall > pSmall0;
  ok('3 small_light scarcity → 炼制期望成本传染', smallUp && costUp, `small ${pSmall0}→${pSmall}, moonglow expected ${eGlow0.expectedCost}→${eGlow.expectedCost}`);
}

// 4) 改月芒 Ruling/unique → 杀招投影变化
{
  const id2 = deepClone(identities);
  const glow = id2.gu.find((g) => g.id === 'moon_glow_gu');
  glow.dimensions_override = { power: 0.5 };
  const next = projectAll(deepClone(ranks), daoPack.daos, id2, enemiesM);
  const km = next.killerMoves.find((k) => k.id === 'moonglow_break');
  const km0 = base.killerMoves.find((k) => k.id === 'moonglow_break');
  ok('4 月芒 override → 杀招投影变化', km && km0 && km.projected.damage !== km0.projected.damage, `moonglow_break dmg ${km0?.projected?.damage}→${km?.projected?.damage}`);
}

// 5) 改 EnemyArchetype → 五转实例同步变化
{
  const em = deepClone(enemiesM);
  em.archetypes.armored.combat_bias.hp = 2.0;
  const next = projectAll(deepClone(ranks), daoPack.daos, deepClone(identities), em);
  const rows = next.enemies.filter((e) => e.archetype === 'armored');
  const baseRows = base.enemies.filter((e) => e.archetype === 'armored');
  const allUp = rows.every((e, i) => e.hp > baseRows[i].hp);
  ok('5 EnemyArchetype.armored → 五实例同步变化', rows.length === 5 && allUp, rows.map((e) => e.hp).join(','));
}

// 传播链示例
const idx = VI.buildIndex({
  gu: base.gu,
  enemies: base.enemies,
  refineEdges: base.edges,
  killerMoves: base.killerMoves,
});
const impact = VI.impactOf('scarcity.small_light', idx);
console.log('\n[impact scarcity.small_light]', JSON.stringify(impact, null, 0).slice(0, 240), '...');

// 写 spine 快照给 index.html
const spine = {
  generated_at: new Date().toISOString(),
  acceptance: checks,
  sample: {
    gu: base.gu.filter((g) => ['moonlight_gu', 'small_light_gu', 'moon_glow_gu', 'moon_mark_gu', 'moon_watch_gu'].includes(g.id)),
    edges: base.edges.slice(0, 6),
    killerMoves: base.killerMoves.slice(0, 4),
    enemies: base.enemies.filter((e) => e.archetype === 'armored' || e.rank === 2).slice(0, 8),
    impact,
  },
  layers: {
    canonical: ['facts/moon_facts.json', 'gu/moon_gu_identity.json', 'dao/dao_profiles.json'],
    rulings: ['moon_rulings.json'],
    models: ['rank_profiles', 'quality_profiles', 'effect_archetypes', 'enemy_archetypes', 'economy', 'refinement', 'killer_moves', 'combat/primitives'],
    projections: ['index.js', 'killer_moves.js', 'impact.js'],
    generated: ['gu_stats.json', 'enemy_stats.json', 'refine_projection.json'],
    golden: ['vertical/data/* 校准集'],
  },
};
mkdirSync(join(bal, 'data'), { recursive: true });
writeFileSync(join(bal, 'data', 'spine_data.js'), 'window.SPINE = ' + JSON.stringify(spine, null, 2) + ';\n', 'utf8');
console.log('\nwrote data/spine_data.js');

const failed = checks.filter((c) => !c.pass);
console.log(`\n== 复利验收 ${checks.length - failed.length}/${checks.length} ==`);
if (failed.length) process.exit(1);
