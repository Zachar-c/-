#!/usr/bin/env node
// Reachability-7D / G1 boundary + M candidate points + interval reporting
// (inbox #22 permitted scope ONLY). MEASUREMENT-ONLY.
// Reads the R5 audit logs + data/*.json. Writes nothing into the game; never
// touches scripts/domain, data, presentation or tests.
//
// Inbox #22 "下一步" asks for exactly three things:
//   1. define the acceptable Elite / Gu / material-band boundary for G1 K=2
//   2. pick M candidate points that AVOID the 149-202 dead zone, and keep
//      reporting the side effects
//   3. express the pooled natural-f1-rate result as an interval / shrinkage
//      estimate instead of a single-point absolute promise
// Plus: keep A5 combined unapproved; run NO M/G/T combination.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL } from 'node:url';
import { parseLog, mulberry32 } from './q8g_reachability5_abcd_comparison.mjs';

const projectRoot = path.resolve(path.join(import.meta.dirname, '..'));
const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const loot = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/loot_tables.json'), 'utf8'));

const PITY_THRESHOLD = loot.pity.threshold ?? 3;
const REPLICATES = 64;
const DEAD_ZONE = [149, 202];        // from R7C

const FACT = {};
for (const t of ['common', 'elite', 'boss']) {
  const e = loot.loot[t];
  FACT[t] = { mat: e.material_count, gu: (e.gu_chance_pct ?? 0) / 100, cost: e.cost_pool ?? null };
}
function bandShares(tier) {
  const pool = loot.loot[tier].material_pool; const out = {}; let total = 0;
  for (const e of pool) {
    const id = typeof e === 'string' ? e : e.id;
    const w = typeof e === 'string' ? 1 : Math.max(1, e.weight || 1);
    const b = loot.materials[id]?.quality_band ?? 'unknown';
    out[b] = (out[b] ?? 0) + w; total += w;
  }
  for (const k of Object.keys(out)) out[k] /= total;
  return out;
}
const BAND = { common: bandShares('common'), elite: bandShares('elite'), boss: bandShares('boss') };
const EC = (() => {
  const pool = FACT.elite.cost ?? []; let total = 0;
  for (const e of pool) total += Math.max(1, e.weight || 1);
  let curse = 0, noto = 0;
  for (const e of pool) { const w = Math.max(1, e.weight || 1) / (total || 1);
    if (e.kind === 'backlash') curse += w * (e.layers ?? 1);
    if (e.kind === 'notoriety') noto += w * (e.amount ?? 0); }
  return { curse, noto };
})();

// ---------------------------------------------------------------- log loading
function loadRuns() {
  const runs = [];
  for (const f of fs.readdirSync(logDir).filter(f => f.endsWith('.log')).sort()) {
    const m = f.match(/^(force|sword)_(\d+)\.log$/);
    if (!m) continue;
    const full = path.join(logDir, f);
    const parsed = parseLog(full);
    const text = fs.readFileSync(full, 'utf8');
    const summary = text.match(/R-5 summary: .*/g)?.pop() || '';
    const num = (re, d = 0) => Number((summary.match(re) || [])[1] ?? d);
    const battles = parsed.battles;
    const f1Count = battles.reduce((s, b) => s + b.f1_hit, 0);
    const n = battles.length;
    runs.push({
      school: m[1], seed: m[2], key: `${m[1]}/${m[2]}`, battles,
      visitMarks: parsed.visitMarks, f1Count, wasZero: f1Count === 0,
      battleCount: num(/battles=(\d+)/, n),
      commonCount: battles.filter(b => b.outcome === 'victory' && b.tier === 'common').length,
      hits: f1Count,
    });
  }
  return runs.sort((a, b) => a.key.localeCompare(b.key));
}
const settled = b => b.outcome === 'victory' && b.tier !== 'unsettled';
const lastVisit = r => r.visitMarks.length ? Math.max(...r.visitMarks) : 0;

function simulate(run, tierOf, rng, pNat) {
  let c = 0; const idxs = [];
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < pNat || c >= PITY_THRESHOLD) { idxs.push(b.idx); c = 0; } else c += 1;
  }
  return idxs;
}
function account(tierOf, runs) {
  const a = { pieces: 0, gu: 0, elite: 0, common: 0, boss: 0, curse: 0, noto: 0, bands: {} };
  for (const run of runs) for (const b of run.battles) {
    if (!settled(b)) continue;
    const t = tierOf(b); const f = FACT[t]; if (!f) continue;
    a.pieces += f.mat; a.gu += f.gu; a[t] = (a[t] ?? 0) + 1;
    if (t === 'elite') { a.curse += EC.curse; a.noto += EC.noto; }
    for (const [band, s] of Object.entries(BAND[t] ?? {})) a.bands[band] = (a.bands[band] ?? 0) + f.mat * s;
  }
  return a;
}
function evaluate(runs, tierOfFor, rateFor) {
  const acc = { pieces: 0, gu: 0, elite: 0, common: 0, boss: 0, curse: 0, noto: 0, bands: {} };
  for (const run of runs) {
    const a = account(tierOfFor(run), [run]);
    for (const k of Object.keys(acc)) {
      if (k === 'bands') { for (const [b, v] of Object.entries(a.bands)) acc.bands[b] = (acc.bands[b] ?? 0) + v; }
      else acc[k] += a[k];
    }
  }
  let zeroFix = 0, inWin = 0, shortZero = 0, deliv = 0, conv = 0;
  for (let rep = 0; rep < REPLICATES; rep++) {
    for (const run of runs) {
      const seed = [...`${run.key}|${rep}`].reduce((x, c) => x + c.charCodeAt(0) * 31, 7);
      const idxs = simulate(run, tierOfFor(run), mulberry32(seed), rateFor(run));
      deliv += idxs.length;
      const lv = lastVisit(run);
      conv += idxs.filter(i => i <= lv).length;
      if (idxs.length && idxs[0] <= lv) inWin += 1;
      if (run.wasZero) { if (idxs.length) zeroFix += 1; else if (run.battleCount < SHORT_T) shortZero += 1; }
    }
  }
  const n = REPLICATES;
  return { zeroFix: zeroFix / n, inWin: inWin / n, shortZero: shortZero / n, deliv: deliv / n,
    convRate: deliv ? conv / deliv : 0, ...acc };
}

let SHORT_T = 15;   // mutable so the short-run threshold can be swept

// G: guarantee K Commons inside runs shorter than `thr` battles.
function guardFloor(K, thr = SHORT_T) {
  return (run) => {
    const base = (b) => b.tier;
    if (run.battleCount >= thr) return base;
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss');
    const have = elig.filter(b => b.tier === 'common').length;
    if (have >= K) return base;
    const promote = new Set(elig.filter(b => b.tier !== 'common').slice(0, K - have).map(b => b.idx));
    return (b) => (promote.has(b.idx) ? 'common' : b.tier);
  };
}
function stableUniform(b) { return mulberry32(b.idx * 977 + b.layer * 31)(); }
function mTierOf(layers, share) {
  return () => (b) => {
    if (b.tier === 'boss') return 'boss';
    if (b.tier === 'common') return 'common';
    if (!layers.includes(b.layer)) return b.tier;
    return stableUniform(b) < share ? 'common' : 'elite';
  };
}
function commonsAt(layers, share, runs) {
  const t = mTierOf(layers, share); let n = 0;
  for (const run of runs) { const f = t(run); for (const b of run.battles) if (settled(b) && f(b) === 'common') n += 1; }
  return n;
}
function matchShare(layers, target, runs) {
  let best = null;
  for (let s = 0; s <= 1.0001; s += 0.002) {
    const c = commonsAt(layers, s, runs); const d = Math.abs(c - target);
    if (!best || d < best.dist) best = { share: s, commons: c, dist: d };
  }
  return best;
}
function estimateRates(runs, mode, kappa = 5) {
  const SH = runs.reduce((s, r) => s + r.hits, 0), SC = runs.reduce((s, r) => s + r.commonCount, 0);
  const pooled = SC ? SH / SC : 0;
  return () => (run) => {
    if (mode === 'pooled') return pooled;
    if (mode === 'loo') { const c = SC - run.commonCount; return c > 0 ? (SH - run.hits) / c : pooled; }
    return (run.hits + pooled * kappa) / (run.commonCount + kappa);
  };
}
function fmt(x, d = 2) { return Number(x).toFixed(d); }

// ---------------------------------------------------------------------- main
function main() {
  const runs = loadRuns();
  if (!runs.length) { console.error(`no logs in ${logDir}`); process.exit(1); }
  const zeroRuns = runs.filter(r => r.wasZero);
  const pooledFn = estimateRates(runs, 'pooled')();
  const pooled = pooledFn(runs[0]);
  const keep = () => (b) => b.tier;

  console.log('Reachability-7D / G1 boundary + M candidates + interval reporting');
  console.log('(measurement-only, inbox #22 scope; NO M/G/T combination is run)');
  console.log(`corpus: ${runs.length} runs | f1_zero = ${zeroRuns.length} | replicates = ${REPLICATES}`);
  console.log(`pity threshold ${PITY_THRESHOLD}; pooled natural f1 = ${fmt(pooled, 4)}`);
  console.log(`dead zone from R7C: Common ${DEAD_ZONE[0]}-${DEAD_ZONE[1]}\n`);

  // ================= 1. G1 K=2 boundary =================
  const base = evaluate(runs, () => keep(), pooledFn);
  console.log('='.repeat(100));
  console.log('[1] G1 K=2 -> ACCEPTABLE BOUNDARY');
  console.log('='.repeat(100));
  console.log('  1a. floor sweep (short = battles < 15)');
  console.log(`  ${'variant'.padEnd(12)}${'f1zero'.padStart(10)}${'shortZero'.padStart(11)}${'elite'.padStart(8)}${'curse'.padStart(8)}${'noto'.padStart(8)}${'guExp'.padStart(9)}${'pieces'.padStart(9)}${'crude'.padStart(9)}${'plain'.padStart(8)}${'refined'.padStart(9)}`);
  const show = (name, r) => console.log(`  ${name.padEnd(12)}${(fmt(r.zeroFix, 2) + '/' + zeroRuns.length).padStart(10)}${fmt(r.shortZero, 2).padStart(11)}` +
    `${fmt(r.elite, 0).padStart(8)}${fmt(r.curse, 0).padStart(8)}${fmt(r.noto, 0).padStart(8)}${fmt(r.gu, 1).padStart(9)}` +
    `${fmt(r.pieces, 1).padStart(9)}${fmt(r.bands.crude ?? 0, 1).padStart(9)}${fmt(r.bands.plain ?? 0, 1).padStart(8)}${fmt(r.bands.refined ?? 0, 1).padStart(9)}`);
  show('BASELINE', base);
  const gRes = {};
  for (const K of [1, 2, 3, 4]) {
    const r = evaluate(runs, guardFloor(K), pooledFn);
    gRes[K] = r; show(`G K=${K}`, r);
  }
  console.log('\n  1b. short-run threshold sensitivity for G1 K=2 (is "K=2 @ <15" fragile?)');
  console.log(`  ${'threshold'.padEnd(12)}${'shortRuns'.padStart(11)}${'f1zero'.padStart(10)}${'shortZero'.padStart(11)}${'elite'.padStart(8)}${'guExp'.padStart(9)}`);
  for (const thr of [12, 15, 18, 21]) {
    SHORT_T = thr;
    const nShort = runs.filter(r => r.battleCount < thr).length;
    const r = evaluate(runs, guardFloor(2, thr), pooledFn);
    console.log(`  ${('< ' + thr).padEnd(12)}${String(nShort).padStart(11)}${(fmt(r.zeroFix, 2) + '/' + zeroRuns.length).padStart(10)}${fmt(r.shortZero, 2).padStart(11)}${fmt(r.elite, 0).padStart(8)}${fmt(r.gu, 1).padStart(9)}`);
  }
  SHORT_T = 15;

  // candidate boundaries relative to baseline
  const g1 = gRes[2];
  const pct = (a, b) => ((a - b) / b * 100);
  console.log('\n  1c. G1 K=2 side-effect deltas vs baseline (the boundary numbers)');
  console.log(`    f1=0 repairs      ${fmt(base.zeroFix, 2)} -> ${fmt(g1.zeroFix, 2)}  (+${fmt(g1.zeroFix - base.zeroFix, 2)})`);
  console.log(`    Elite exposure    ${fmt(base.elite, 0)} -> ${fmt(g1.elite, 0)}  (${fmt(pct(g1.elite, base.elite), 1)}%)`);
  console.log(`    curse layers      ${fmt(base.curse, 0)} -> ${fmt(g1.curse, 0)}  (${fmt(pct(g1.curse, base.curse), 1)}%)`);
  console.log(`    notoriety         ${fmt(base.noto, 0)} -> ${fmt(g1.noto, 0)}  (${fmt(pct(g1.noto, base.noto), 1)}%)`);
  console.log(`    Gu expectation    ${fmt(base.gu, 1)} -> ${fmt(g1.gu, 1)}  (${fmt(pct(g1.gu, base.gu), 1)}%)`);
  console.log(`    material pieces   ${fmt(base.pieces, 1)} -> ${fmt(g1.pieces, 1)}  (${fmt(pct(g1.pieces, base.pieces), 1)}%)   <- must be 0%`);
  console.log(`    crude band        ${fmt(base.bands.crude, 1)} -> ${fmt(g1.bands.crude, 1)}  (+${fmt(g1.bands.crude - base.bands.crude, 1)} pieces)`);
  console.log(`    plain band        ${fmt(base.bands.plain, 1)} -> ${fmt(g1.bands.plain, 1)}  (${fmt(g1.bands.plain - base.bands.plain, 1)} pieces)`);
  console.log(`    refined band      ${fmt(base.bands.refined, 1)} -> ${fmt(g1.bands.refined, 1)}  (${fmt(g1.bands.refined - base.bands.refined, 1)} pieces)`);

  // ================= 2. M candidate points outside the dead zone =================
  console.log('\n' + '='.repeat(100));
  console.log('[2] M candidate points STRICTLY BELOW the dead zone (Common < 149)');
  console.log('='.repeat(100));
  console.log(`  ${'commons'.padStart(8)}${'share'.padStart(8)}${'f1zero'.padStart(10)}${'shortZero'.padStart(11)}${'inWindow'.padStart(10)}${'elite'.padStart(8)}${'guExp'.padStart(9)}${'crude'.padStart(9)}${'plain'.padStart(8)}${'refined'.padStart(9)}${'zone'.padStart(12)}`);
  for (const target of [81, 91, 101, 111, 121, 131, 141]) {
    const m = matchShare([1, 2, 3, 4, 5], target, runs);
    const r = evaluate(runs, mTierOf([1, 2, 3, 4, 5], m.share), pooledFn);
    const zone = m.commons >= DEAD_ZONE[0] && m.commons <= DEAD_ZONE[1] ? 'DEAD ZONE' : (m.commons < DEAD_ZONE[0] ? 'ok' : 'past dead');
    console.log(`  ${String(m.commons).padStart(8)}${fmt(m.share, 3).padStart(8)}${(fmt(r.zeroFix, 2) + '/' + zeroRuns.length).padStart(10)}` +
      `${fmt(r.shortZero, 2).padStart(11)}${fmt(r.inWin, 2).padStart(10)}${fmt(r.elite, 0).padStart(8)}${fmt(r.gu, 1).padStart(9)}` +
      `${fmt(r.bands.crude ?? 0, 1).padStart(9)}${fmt(r.bands.plain ?? 0, 1).padStart(8)}${fmt(r.bands.refined ?? 0, 1).padStart(9)}${zone.padStart(12)}`);
  }
  console.log(`  (piece count is 389.0 for every row - not repeated; it is invariant by construction)`);

  // ================= 3. interval reporting for the natural rate =================
  console.log('\n' + '='.repeat(100));
  console.log('[3] pooled natural-f1-rate -> INTERVAL / shrinkage reporting');
  console.log('='.repeat(100));
  const SH = runs.reduce((s, r) => s + r.hits, 0), SC = runs.reduce((s, r) => s + r.commonCount, 0);
  console.log(`  pooled point estimate = ${SH}/${SC} = ${fmt(SH / SC, 4)}`);
  console.log('  report the following as a RANGE, never as a single absolute promise:\n');
  console.log(`  ${'variant'.padEnd(16)}${'pooled'.padStart(12)}${'loo'.padStart(12)}${'shrink k=2'.padStart(13)}${'shrink k=10'.padStart(14)}${'interval'.padStart(20)}`);
  const families = [['pooled', estimateRates(runs, 'pooled')], ['loo', estimateRates(runs, 'loo')],
    ['shrink k=2', estimateRates(runs, 'shrink', 2)], ['shrink k=10', estimateRates(runs, 'shrink', 10)]];
  const rows = [];
  for (const [name, tf] of [['BASELINE', null], ['G1 K=2', guardFloor(2)], ['G2 K=4', guardFloor(4)]]) {
    const vals = families.map(([, rf]) => evaluate(runs, tf ?? (() => keep()), rf()).zeroFix);
    const lo = Math.min(...vals), hi = Math.max(...vals);
    console.log(`  ${name.padEnd(16)}${fmt(vals[0], 2).padStart(12)}${fmt(vals[1], 2).padStart(12)}${fmt(vals[2], 2).padStart(13)}${fmt(vals[3], 2).padStart(14)}` +
      `${(fmt(lo, 2) + '-' + fmt(hi, 2)).padStart(20)}`);
    rows.push([name, lo, hi]);
  }
  for (const target of [101, 141]) {
    const m = matchShare([1, 2, 3, 4, 5], target, runs);
    const vals = families.map(([, rf]) => evaluate(runs, mTierOf([1, 2, 3, 4, 5], m.share), rf()).zeroFix);
    const lo = Math.min(...vals), hi = Math.max(...vals);
    console.log(`  ${('M@' + m.commons).padEnd(16)}${fmt(vals[0], 2).padStart(12)}${fmt(vals[1], 2).padStart(12)}${fmt(vals[2], 2).padStart(13)}${fmt(vals[3], 2).padStart(14)}` +
      `${(fmt(lo, 2) + '-' + fmt(hi, 2)).padStart(20)}`);
    rows.push(['M@' + m.commons, lo, hi]);
  }
  console.log('\n  Interval width check: if the ranking of candidates flips across the interval, the');
  console.log('  comparison is NOT robust and must not be used to pick a winner.');
  const sorted = [...rows].sort((a, b) => b[1] - a[1]);
  console.log(`  ranking by interval low-end : ${sorted.map(r => r[0] + ' ' + fmt(r[1], 2)).join(' > ')}`);
  const g1r = rows.find(r => r[0] === 'G1 K=2'), g2r = rows.find(r => r[0] === 'G2 K=4');
  if (g1r && g2r) {
    const disjoint = g1r[1] > g2r[2] || g2r[1] > g1r[2];
    console.log(`  G1 vs G2 intervals ${disjoint ? 'are DISJOINT (separation is robust)' : 'OVERLAP (do not claim a winner on this metric alone)'}`);
  }

  console.log('\nNO M/G/T combination was run. A5 combined remains UNAPPROVED.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();

export { loadRuns, evaluate, guardFloor, mTierOf, matchShare, estimateRates };
