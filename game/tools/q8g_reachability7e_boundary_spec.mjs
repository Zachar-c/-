#!/usr/bin/env node
// Reachability-7E / cost-boundary + budget SPECIFICATION (inbox #23 scope ONLY).
// MEASUREMENT-ONLY. Reads the R5 audit logs + data/*.json. Never writes into
// the game; never touches scripts/domain, data, presentation or tests.
//
// Why this tool exists: every previous Reachability number was an AGGREGATE over
// 32 runs ("elite 150 -> 138"). A product ruling needs the cost expressed in
// PER-RUN, player-facing units, and needs to know WHICH runs pay it. This tool
// produces that translation, plus the interval reporting inbox #23 requires.
//
// inbox #23 permitted scope:
//   1. define the product-acceptable cost boundary for G1 / G3
//   2. define M's target Common range and its Elite / Gu / band budget
//   3. report pooled + shrink INTERVALS, never single-point absolutes
//   4. may expand the sample or recheck the short-run boundary
// Forbidden: any M/G/T combination; any production code/data change.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL } from 'node:url';
import { parseLog, mulberry32 } from './q8g_reachability5_abcd_comparison.mjs';

const projectRoot = path.resolve(path.join(import.meta.dirname, '..'));
const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const loot = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/loot_tables.json'), 'utf8'));

const PITY_THRESHOLD = loot.pity.threshold ?? 3;
const SHORT_T = 15;
const REPLICATES = 64;
const DEAD_ZONE = [149, 202];

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
    runs.push({
      school: m[1], seed: m[2], key: `${m[1]}/${m[2]}`, battles,
      visitMarks: parsed.visitMarks, f1Count, wasZero: f1Count === 0,
      battleCount: num(/battles=(\d+)/, battles.length),
      isShort: num(/battles=(\d+)/, battles.length) < SHORT_T,
      commonCount: battles.filter(b => b.outcome === 'victory' && b.tier === 'common').length,
      hits: f1Count,
    });
  }
  return runs.sort((a, b) => a.key.localeCompare(b.key));
}
const settled = b => b.outcome === 'victory' && b.tier !== 'unsettled';
const lastVisit = r => r.visitMarks.length ? Math.max(...r.visitMarks) : 0;

// Per-RUN accounting: this is the unit a product ruling actually needs.
function perRun(tierOf, run) {
  const a = { elite: 0, common: 0, boss: 0, gu: 0, curse: 0, noto: 0,
    crude: 0, plain: 0, refined: 0, prized: 0, pieces: 0 };
  for (const b of run.battles) {
    if (!settled(b)) continue;
    const t = tierOf(b); const f = FACT[t]; if (!f) continue;
    a[t] += 1; a.pieces += f.mat; a.gu += f.gu;
    if (t === 'elite') { a.curse += EC.curse; a.noto += EC.noto; }
    for (const [band, s] of Object.entries(BAND[t] ?? {})) a[band] += f.mat * s;
  }
  return a;
}
function simulate(run, tierOf, rng, pNat) {
  let c = 0; const idxs = [];
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < pNat || c >= PITY_THRESHOLD) { idxs.push(b.idx); c = 0; } else c += 1;
  }
  return idxs;
}
function aggregate(runs, tierOfFor, rateFor) {
  const per = runs.map(run => ({ key: run.key, isShort: run.isShort, wasZero: run.wasZero,
    ...perRun(tierOfFor(run), run) }));
  const sum = {}; for (const k of ['elite', 'common', 'boss', 'gu', 'curse', 'noto', 'crude', 'plain', 'refined', 'prized', 'pieces'])
    sum[k] = per.reduce((s, p) => s + p[k], 0);
  let zeroFix = 0;
  for (let rep = 0; rep < REPLICATES; rep++) {
    for (const run of runs) {
      const seed = [...`${run.key}|${rep}`].reduce((x, c) => x + c.charCodeAt(0) * 31, 7);
      const idxs = simulate(run, tierOfFor(run), mulberry32(seed), rateFor(run));
      if (run.wasZero && idxs.length) zeroFix += 1;
    }
  }
  return { per, sum, zeroFix: zeroFix / REPLICATES,
    perRunElite: sum.elite / runs.length, perRunGu: sum.gu / runs.length,
    perRunCurse: sum.curse / runs.length, perRunNoto: sum.noto / runs.length };
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
// G guard: only runs shorter than thr pay the cost.
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
function estimateRates(runs, mode, kappa = 5) {
  const SH = runs.reduce((s, r) => s + r.hits, 0), SC = runs.reduce((s, r) => s + r.commonCount, 0);
  const pooled = SC ? SH / SC : 0;
  return () => (run) => {
    if (mode === 'pooled') return pooled;
    if (mode === 'loo') { const c = SC - run.commonCount; return c > 0 ? (SH - run.hits) / c : pooled; }
    return (run.hits + pooled * kappa) / (run.commonCount + kappa);
  };
}
const f2 = x => Number(x).toFixed(2);
const f1 = x => Number(x).toFixed(1);

function main() {
  const runs = loadRuns();
  if (!runs.length) { console.error(`no logs in ${logDir}`); process.exit(1); }
  const zeroRuns = runs.filter(r => r.wasZero);
  const shortRuns = runs.filter(r => r.isShort);
  const N = runs.length;
  const rateFns = [
    ['pooled', estimateRates(runs, 'pooled')()],
    ['shrink k=2', estimateRates(runs, 'shrink', 2)()],
  ];

  console.log('Reachability-7E / cost-boundary + budget SPECIFICATION (measurement-only, inbox #23)');
  console.log(`corpus: ${N} runs (${shortRuns.length} short <${SHORT_T}, ${N - shortRuns.length} long) | f1_zero = ${zeroRuns.length}`);
  console.log(`per-run units below are what a product ruling should use; aggregates are given for cross-check only.`);
  console.log('NO M/G/T combination is run.\n');

  const base = aggregate(runs, () => (b) => b.tier, rateFns[0][1]);

  // ================= 1. G1 / G3 cost boundary, in per-run units =================
  console.log('='.repeat(104));
  console.log('[1] G1 / G3 PRODUCT COST BOUNDARY (per-run units)');
  console.log('='.repeat(104));
  console.log(`  baseline per run: elite ${f2(base.perRunElite)} | gu ${f2(base.perRunGu)} | curse ${f2(base.perRunCurse)} | notoriety ${f2(base.perRunNoto)}`);
  console.log('  Note: G only touches SHORT runs, so the cost is CONCENTRATED, not spread evenly.\n');
  console.log(`  ${'variant'.padEnd(10)}${'f1zero(range)'.padStart(16)}${'elite/run'.padStart(11)}${'delta/run'.padStart(11)}${'gu/run'.padStart(9)}${'curse/run'.padStart(11)}${'noto/run'.padStart(10)}`);
  const gRows = {};
  for (const [name, tf] of [['BASELINE', null], ['G K=1', guardFloor(1)], ['G K=2', guardFloor(2)], ['G K=3', guardFloor(3)]]) {
    const t = tf ?? (() => (b) => b.tier);
    const a = aggregate(runs, t, rateFns[0][1]);
    const rng = rateFns.map(([, rf]) => aggregate(runs, t, rf).zeroFix);
    const lo = Math.min(...rng), hi = Math.max(...rng);
    gRows[name] = a;
    console.log(`  ${name.padEnd(10)}${(f2(lo) + '-' + f2(hi)).padStart(16)}${f2(a.perRunElite).padStart(11)}` +
      `${f2(a.perRunElite - base.perRunElite).padStart(11)}${f2(a.perRunGu).padStart(9)}` +
      `${f2(a.perRunCurse).padStart(11)}${f2(a.perRunNoto).padStart(10)}`);
  }

  // who pays? split short vs long
  console.log('\n  who pays the cost (elite battles per run, by group):');
  console.log(`  ${'variant'.padEnd(10)}${'short runs'.padStart(13)}${'long runs'.padStart(12)}${'runs losing >=1 elite'.padStart(24)}${'max loss in one run'.padStart(21)}`);
  for (const [name, tf] of [['BASELINE', null], ['G K=1', guardFloor(1)], ['G K=2', guardFloor(2)], ['G K=3', guardFloor(3)]]) {
    const t = tf ?? (() => (b) => b.tier);
    const b2 = aggregate(runs, () => (b) => b.tier, rateFns[0][1]);
    const a = aggregate(runs, t, rateFns[0][1]);
    const bmap = new Map(b2.per.map(p => [p.key, p.elite]));
    let sSum = 0, sN = 0, lSum = 0, lN = 0, losers = 0, worst = 0;
    for (const p of a.per) {
      const d = (bmap.get(p.key) ?? 0) - p.elite;
      if (d > 0) { losers += 1; worst = Math.max(worst, d); }
      if (p.isShort) { sSum += p.elite; sN += 1; } else { lSum += p.elite; lN += 1; }
    }
    const sAvg = sN ? sSum / sN : 0, lAvg = lN ? lSum / lN : 0;
    console.log(`  ${name.padEnd(10)}${f2(sAvg).padStart(13)}${f2(lAvg).padStart(12)}${String(losers + '/' + N).padStart(24)}${String(worst).padStart(21)}`);
  }

  // ================= 2. M budget specification =================
  console.log('\n' + '='.repeat(104));
  console.log('[2] M TARGET RANGE + Elite / Gu / BAND BUDGET (per-run units, dead zone excluded)');
  console.log('='.repeat(104));
  console.log(`  ${'Target'.padStart(8)}${'share'.padStart(8)}${'f1zero(range)'.padStart(16)}${'elite/run'.padStart(11)}${'gu/run'.padStart(9)}${'crude/run'.padStart(11)}${'plain/run'.padStart(11)}${'refined/run'.padStart(12)}${'zone'.padStart(11)}`);
  for (const target of [81, 101, 121, 141]) {
    const m = matchShare([1, 2, 3, 4, 5], target, runs);
    const t = mTierOf([1, 2, 3, 4, 5], m.share);
    const a = aggregate(runs, t, rateFns[0][1]);
    const rng = rateFns.map(([, rf]) => aggregate(runs, t, rf).zeroFix);
    const lo = Math.min(...rng), hi = Math.max(...rng);
    const zone = m.commons >= DEAD_ZONE[0] && m.commons <= DEAD_ZONE[1] ? 'DEAD' : 'ok';
    console.log(`  ${String(m.commons).padStart(8)}${Number(m.share).toFixed(3).padStart(8)}${(f2(lo) + '-' + f2(hi)).padStart(16)}` +
      `${f2(a.perRunElite).padStart(11)}${f2(a.perRunGu).padStart(9)}${f2(a.sum.crude / N).padStart(11)}` +
      `${f2(a.sum.plain / N).padStart(11)}${f2(a.sum.refined / N).padStart(12)}${zone.padStart(11)}`);
  }
  console.log(`\n  baseline per run: elite ${f2(base.perRunElite)} | gu ${f2(base.perRunGu)} | crude ${f2(base.sum.crude / N)} | plain ${f2(base.sum.plain / N)} | refined ${f2(base.sum.refined / N)}`);
  console.log(`  M cost is SPREAD over all runs (every run can have a high-rank battle converted).`);

  // ================= 3. interval discipline =================
  console.log('\n' + '='.repeat(104));
  console.log('[3] INTERVAL DISCIPLINE (inbox #23 item 3): report ranges, never single points');
  console.log('='.repeat(104));
  console.log('  all f1=0 repair figures above are already given as pooled..shrink-k2 intervals.');
  console.log('  absolute "repairs" values are MODEL-DEPENDENT and must always carry their range.');

  // ================= 4. short-run boundary recheck =================
  console.log('\n' + '='.repeat(104));
  console.log('[4] SHORT-RUN BOUNDARY RECHECK (inbox #23 item 4)');
  console.log('='.repeat(104));
  const byCount = {};
  for (const r of runs) byCount[r.battleCount] = (byCount[r.battleCount] ?? 0) + 1;
  console.log('  battle-count histogram:', Object.entries(byCount).sort((a, b) => a[0] - b[0]).map(([k, v]) => `${k}:${v}`).join(' '));
  console.log(`  f1=0 runs and their battle counts: ${zeroRuns.map(r => `${r.key}=${r.battleCount}`).join(', ')}`);
  const zeroShort = zeroRuns.filter(r => r.isShort).length;
  console.log(`  f1=0 short/long split = ${zeroShort}/${zeroRuns.length - zeroShort}`);
  console.log(`  => the ONLY runs G can help are runs < ${SHORT_T}; the split above says how much of the problem lives there.`);
  console.log('\nNO M/G/T combination was run. A5 combined remains UNAPPROVED.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();

export { loadRuns, aggregate, guardFloor, mTierOf, matchShare, estimateRates, EC, BAND };
