/* Golden Dataset 对齐：projection 是否推得出与校准集同构的结果 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const load = (p) => JSON.parse(readFileSync(join(root, p), 'utf8'));

const gen = load('generated/gu_stats.json');
const golden = load('../vertical/data/gu.json');
const gById = Object.fromEntries(gen.gu.map((g) => [g.id, g]));
const goldById = Object.fromEntries(golden.gu.map((g) => [g.id, g]));

console.log('=== Golden 对齐校准 ===\n');
console.log('projection', gen.count, 'gu | golden', golden.gu.length, 'gu');

const rows = [];
for (const [id, gold] of Object.entries(goldById)) {
  const p = gById[id];
  if (!p) {
    rows.push({ id, status: 'MISSING_IN_PROJECTION' });
    continue;
  }
  const dmgRatio = gold.damage > 0 ? p.combat.damage / gold.damage : p.combat.block > 0 ? p.combat.block / (gold.block || 1) : 1;
  const priceRatio = p.economy.marketPrice / gold.economy.normalPrice;
  rows.push({
    id,
    goldDmg: gold.damage,
    projDmg: p.combat.damage,
    goldBlock: gold.block,
    projBlock: p.combat.block,
    goldQi: gold.qi,
    projQi: p.combat.qi,
    goldPrice: gold.economy.normalPrice,
    projPrice: p.economy.marketPrice,
    dmgRatio: Math.round(dmgRatio * 100) / 100,
    priceRatio: Math.round(priceRatio * 100) / 100,
  });
}

console.log('id'.padEnd(26), 'gDmg', 'pDmg', 'gQi', 'pQi', 'gPrice', 'pPrice', 'dmg×', 'price×');
for (const r of rows) {
  if (r.status) {
    console.log(r.id, r.status);
    continue;
  }
  console.log(
    r.id.padEnd(26),
    String(r.goldDmg).padStart(4),
    String(r.projDmg).padStart(4),
    String(r.goldQi).padStart(4),
    String(r.projQi).padStart(4),
    String(r.goldPrice).padStart(6),
    String(r.projPrice).padStart(6),
    String(r.dmgRatio).padStart(5),
    String(r.priceRatio).padStart(6)
  );
}

const order = ['moonlight_gu', 'moon_glow_gu', 'golden_moon_gu'];
console.log('\n[关键序] 同轴应保持 moonlight < moonglow < golden（不是同一倍率）');
const seq = order.map((id) => gById[id]?.combat.damage);
console.log('  proj damage:', seq.join(' → '), seq[0] < seq[1] && seq[1] < seq[2] ? 'PASS' : 'FAIL');

const goldSeq = order.map((id) => goldById[id]?.damage);
console.log('  golden     :', goldSeq.join(' → '));

console.log('\n[价值向量抽样] 小光 vs 月光 vs 照月');
for (const id of ['small_light_gu', 'moonlight_gu', 'moon_watch_gu']) {
  const p = gById[id];
  console.log(' ', id, JSON.stringify(p.value_vector));
}

console.log('\n[说明] 比值不是要贴到 1.0；校准看序关系、交叉（垃圾三转 vs 极品二转）与向量形状。');
console.log('DONE');
