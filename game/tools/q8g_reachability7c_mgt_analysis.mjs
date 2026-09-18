#!/usr/bin/env node
// Reachability-7C / M-G-T boundary analysis (inbox #21 permitted scope ONLY).
// MEASUREMENT-ONLY. Reads the R5 audit logs + data/*.json. Writes nothing into
// the game; never touches scripts/domain, data, presentation or tests.
//
// inbox #21 splits option A into three ORTHOGONAL variables and forbids any
// combination (no M+G, no M+T, no M+G+T). This tool therefore runs exactly four
// independent analyses:
//   1. M = Common opportunity magnitude/scope -> acceptable boundary frontier
//   2. G = short-run guard                    -> G1 K=2 vs G2 K=4, head to head
//   3. T = refinement timing redistribution   -> CONVERSION-RATE metric, explicitly
//                                                NOT treated as F1 supply repair
//   4. natural f1 pooled-rate assumption      -> three estimators + selection effect
//
// Semantics used for the conversion window, taken from the audit log itself:
//   visit_marks       = battle indices where a refinement visit happens
//   conversion window = [first visit, last visit]
//   a delivery is CONVERTIBLE iff its battle index <= last visit
//   common_after_last_refinement>0 means supply exists but can no longer be spent.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL } from 'node:url';
import { parseLog, mulberry32 } from './q8g_reachability5_abcd_comparison.mjs';

const projectRoot = path.resolve(import.meta.dirname, '..');
const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const loot = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/loot_tables.json'), 'utf8'));

const SHORT_RUN_BATTLES = 15;
const PITY_THRESHOLD = loot.pity.threshold ?? 3;
const PITY_REPAIR_COMMONS = PITY_THRESHOLD + 1;
const REPLICATES = 64;

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
    out[loot.materials[id]?.quality_band ?? 'unknown'] = (out[loot.materials[id]?.quality_band ?? 'unknown'] ?? 0) + w;
    total += w;
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
    const commons = battles.filter(b => b.outcome === 'victory' && b.tier === 'common');
    runs.push({
      school: m[1], seed: m[2], key: `${m[1]}/${m[2]}`, battles,
      visitMarks: parsed.visitMarks, f1Count, wasZero: f1Count === 0,
      battleCount: num(/battles=(\d+)/, battles.length),
      isShort: num(/battles=(\d+)/, battles.length) < SHORT_RUN_BATTLES,
      commonCount: commons.length, hits: f1Count,
      afterLast: num(/common_after_last_refinement=(\d+)/),
    });
  }
  return runs.sort((a, b) => a.key.localeCompare(b.key));
}
const settled = b => b.outcome === 'victory' && b.tier !== 'unsettled';
const lastVisit = r => r.visitMarks.length ? Math.max(...r.visitMarks) : 0;
const firstVisit = r => r.visitMarks.length ? Math.min(...r.visitMarks) : Infinity;

// ------------------------------------------------------------- core simulate
// Returns per-delivery battle indices so the conversion window can be scored.
function simulate(run, tierOf, rng, pNatural) {
  let counter = 0; const idxs = [];
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < pNatural || counter >= PITY_THRESHOLD) { idxs.push(b.idx); counter = 0; }
    else counter += 1;
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
  let zeroFix = 0, inWin = 0, shortZero = 0, deliv = 0, convertible = 0, runsConvertible = 0;
  for (let rep = 0; rep < REPLICATES; rep++) {
    for (const run of runs) {
      const seed = [...`${run.key}|${rep}`].reduce((x, c) => x + c.charCodeAt(0) * 31, 7);
      const idxs = simulate(run, tierOfFor(run), mulberry32(seed), rateFor(run));
      deliv += idxs.length;
      const lv = lastVisit(run);
      const conv = idxs.filter(i => i <= lv).length;
      convertible += conv;
      if (idxs.length > 0 && idxs[0] <= lv) inWin += 1;
      if (conv > 0) runsConvertible += 1;
      if (run.wasZero) { if (idxs.length > 0) zeroFix += 1; else if (run.isShort) shortZero += 1; }
    }
  }
  const n = REPLICATES;
  return { zeroFix: zeroFix / n, inWin: inWin / n, shortZero: shortZero / n,
    deliv: deliv / n, convertible: convertible / n, runsConvertible: runsConvertible / n,
    convRate: convertible ? convertible / deliv : 0, ...acc };
}

// --------------------------------------------------------------- M: scope map
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

// -------------------------------------------------------- G: short-run guard
function guardFloor(K) {
  return (run) => {
    const base = (b) => b.tier;
    if (!run.isShort) return base;
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss');
    const have = elig.filter(b => b.tier === 'common').length;
    if (have >= K) return base;
    const promote = new Set(elig.filter(b => b.tier !== 'common').slice(0, K - have).map(b => b.idx));
    return (b) => (promote.has(b.idx) ? 'common' : b.tier);
  };
}

// --------------------------------------------- T: timing redistribution only
function timingFrontload() {
  return (run) => {
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const c = run.battles.filter(b => settled(b) && b.tier === 'common').length;
    const remap = new Map();
    elig.forEach((idx, i) => remap.set(idx, i < c ? 'common' : 'elite'));
    return (b) => (remap.has(b.idx) ? remap.get(b.idx) : b.tier);
  };
}

// ------------------------------------- 4. natural f1 rate: estimator families
function estimateRates(runs, mode, kappa = 5) {
  const SH = runs.reduce((s, r) => s + r.hits, 0);
  const SC = runs.reduce((s, r) => s + r.commonCount, 0);
  const pooled = SC ? SH / SC : 0;
  return (run) => {
    if (mode === 'pooled') return pooled;
    if (mode === 'loo') {                       // leave-one-out pooled (breaks circularity)
      const c = SC - run.commonCount;
      return c > 0 ? (SH - run.hits) / c : pooled;
    }
    if (mode === 'shrink') {                    // Beta shrinkage toward the pooled mean
      return (run.hits + pooled * kappa) / (run.commonCount + kappa);
    }
    return pooled;
  };
}

function main() {
  const runs = loadRuns();
  if (!runs.length) { console.error(`no logs in ${logDir}`); process.exit(1); }
  const zeroRuns = runs.filter(r => r.wasZero);
  const pooledFn = estimateRates(runs, 'pooled');

  console.log('Reachability-7C / M-G-T boundary analysis  (measurement-only, inbox #21 scope)');
  console.log(`corpus: ${runs.length} runs | f1_zero = ${zeroRuns.length} | short(<${SHORT_RUN_BATTLES}) = ${runs.filter(r => r.isShort).length} | replicates = ${REPLICATES}`);
  console.log(`pity threshold ${PITY_THRESHOLD} -> repair needs >= ${PITY_REPAIR_COMMONS} Common victories`);
  console.log('variables are analysed INDEPENDENTLY; no M+G / M+T / M+G+T combination is run.\n');

  const base = evaluate(runs, () => (b) => b.tier, pooledFn);
  const actualCommons = base.common;
  const maxCommons = commonsAt([1, 2, 3, 4, 5], 1, runs);

  // ============================ 1. M acceptable boundary ============================
  console.log('=' .repeat(96));
  console.log('[1] M = Common opportunity magnitude -> ACCEPTABLE BOUNDARY');
  console.log(`    canonical scope = all layers (scope proven not to matter at matched yield)`);
  console.log(`    realised Commons: actual ${actualCommons} ... ceiling ${maxCommons} (share=1.0)`);
  console.log('=' .repeat(96));
  const targets = [];
  for (let t = actualCommons; t <= maxCommons; t += 10) targets.push(t);
  if (targets[targets.length - 1] !== maxCommons) targets.push(maxCommons);
  console.log(`  ${'commons'.padStart(8)}${'share'.padStart(8)}${'f1zero'.padStart(10)}${'inWindow'.padStart(10)}${'shortZero'.padStart(11)}${'elite'.padStart(8)}${'curse'.padStart(8)}${'guExp'.padStart(8)}${'crude'.padStart(8)}${'dF1/dElite'.padStart(12)}`);
  let prev = null;
  for (const t of targets) {
    const m = matchShare([1, 2, 3, 4, 5], t, runs);
    const r = evaluate(runs, mTierOf([1, 2, 3, 4, 5], m.share), pooledFn);
    let eff = '     -';
    if (prev) {
      const dF = r.zeroFix - prev.zeroFix, dE = r.elite - prev.elite;
      eff = dE !== 0 ? (dF / -dE).toFixed(4) : 'n/a';
    }
    console.log(`  ${String(m.commons).padStart(8)}${m.share.toFixed(3).padStart(8)}${(r.zeroFix.toFixed(2)+'/'+zeroRuns.length).padStart(10)}` +
      `${r.inWin.toFixed(2).padStart(10)}${r.shortZero.toFixed(2).padStart(11)}${r.elite.toFixed(0).padStart(8)}` +
      `${r.curse.toFixed(0).padStart(8)}${r.gu.toFixed(1).padStart(8)}${(r.bands.crude ?? 0).toFixed(1).padStart(8)}${String(eff).padStart(12)}`);
    prev = r;
  }
  console.log('  (dF1/dElite = marginal f1=0 repairs gained per elite battle sacrificed; higher is better)');

  // ============================ 2. G1 vs G2 head to head ============================
  console.log('\n' + '='.repeat(96));
  console.log('[2] G = short-run guard -> G1 (K=2) vs G2 (K=4), INDEPENDENT of M');
  console.log('='.repeat(96));
  const gVariants = [['BASELINE', null], ['G1 K=2', guardFloor(2)], ['G2 K=4', guardFloor(4)]];
  const gRes = {};
  console.log(`  ${'variant'.padEnd(10)}${'f1zero'.padStart(10)}${'inWindow'.padStart(10)}${'shortZero'.padStart(11)}${'elite'.padStart(8)}${'curse'.padStart(8)}${'noto'.padStart(8)}${'guExp'.padStart(8)}${'pieces'.padStart(8)}${'crude'.padStart(8)}`);
  for (const [name, f] of gVariants) {
    const r = evaluate(runs, f ?? (() => (b) => b.tier), pooledFn);
    gRes[name] = r;
    console.log(`  ${name.padEnd(10)}${(r.zeroFix.toFixed(2)+'/'+zeroRuns.length).padStart(10)}${r.inWin.toFixed(2).padStart(10)}` +
      `${r.shortZero.toFixed(2).padStart(11)}${r.elite.toFixed(0).padStart(8)}${r.curse.toFixed(0).padStart(8)}` +
      `${r.noto.toFixed(0).padStart(8)}${r.gu.toFixed(1).padStart(8)}${r.pieces.toFixed(1).padStart(8)}${(r.bands.crude ?? 0).toFixed(1).padStart(8)}`);
  }
  // head-to-head deltas and the cost of the last step
  const g1 = gRes['G1 K=2'], g2 = gRes['G2 K=4'], gb = gRes['BASELINE'];
  console.log('\n  head-to-head:');
  console.log(`    G1 vs base : f1zero +${(g1.zeroFix - gb.zeroFix).toFixed(2)} | elite ${(g1.elite - gb.elite).toFixed(0)} | gu ${(g1.gu - gb.gu).toFixed(1)}`);
  console.log(`    G2 vs base : f1zero +${(g2.zeroFix - gb.zeroFix).toFixed(2)} | elite ${(g2.elite - gb.elite).toFixed(0)} | gu ${(g2.gu - gb.gu).toFixed(1)}`);
  console.log(`    G2 vs G1   : f1zero +${(g2.zeroFix - g1.zeroFix).toFixed(2)} | elite ${(g2.elite - g1.elite).toFixed(0)} | gu ${(g2.gu - g1.gu).toFixed(1)}   <- cost of the LAST step`);
  console.log(`    efficiency : G1 ${((g1.zeroFix - gb.zeroFix) / Math.max(1, gb.elite - g1.elite)).toFixed(4)} vs G2 ${((g2.zeroFix - gb.zeroFix) / Math.max(1, gb.elite - g2.elite)).toFixed(4)} repairs per elite sacrificed`);

  // ============================ 3. T conversion-rate metric ============================
  console.log('\n' + '='.repeat(96));
  console.log('[3] T = refinement timing redistribution -> CONVERSION-RATE metric');
  console.log('    (T is NOT an F1 supply repair; it is scored on whether supply lands inside the window)');
  console.log('='.repeat(96));
  console.log(`  ${'variant'.padEnd(18)}${'f1zero'.padStart(10)}${'deliveries'.padStart(12)}${'convertible'.padStart(13)}${'convRate'.padStart(10)}${'runsConv'.padStart(10)}${'supplyDelta'.padStart(12)}`);
  for (const [name, f] of [['BASELINE', null], ['T1 front-load', timingFrontload()]]) {
    const r = evaluate(runs, f ?? (() => (b) => b.tier), pooledFn);
    console.log(`  ${name.padEnd(18)}${(r.zeroFix.toFixed(2)+'/'+zeroRuns.length).padStart(10)}${r.deliv.toFixed(2).padStart(12)}` +
      `${r.convertible.toFixed(2).padStart(13)}${(r.convRate * 100).toFixed(1).padStart(9)+'%'}${(r.runsConvertible.toFixed(1)+'/'+runs.length).padStart(10)}` +
      `${(r.deliv - base.deliv).toFixed(2).padStart(12)}`);
  }
  console.log('  supplyDelta must be ~0: T may only MOVE supply, never create it.');
  const t1 = evaluate(runs, timingFrontload(), pooledFn);
  console.log(`  => T improves convRate ${(base.convRate * 100).toFixed(1)}% -> ${(t1.convRate * 100).toFixed(1)}% with supply change ${(t1.deliv - base.deliv).toFixed(2)},`);
  console.log(`     but f1=0 repairs stay at ${base.zeroFix.toFixed(2)} -> ${t1.zeroFix.toFixed(2)}/${zeroRuns.length}. T is an auxiliary metric ONLY.`);

  // ============================ 4. natural rate + selection effect ============================
  console.log('\n' + '='.repeat(96));
  console.log('[4] natural f1 rate: pooled assumption and SELECTION EFFECT');
  console.log('='.repeat(96));
  const SH = runs.reduce((s, r) => s + r.hits, 0), SC = runs.reduce((s, r) => s + r.commonCount, 0);
  const zRuns = runs.filter(r => r.wasZero), nzRuns = runs.filter(r => !r.wasZero);
  const zH = zRuns.reduce((s, r) => s + r.hits, 0), zC = zRuns.reduce((s, r) => s + r.commonCount, 0);
  const nH = nzRuns.reduce((s, r) => s + r.hits, 0), nC = nzRuns.reduce((s, r) => s + r.commonCount, 0);
  console.log(`  pooled (all runs)          : ${SH}/${SC} = ${(SH / SC).toFixed(4)}`);
  console.log(`  f1=0 runs only             : ${zH}/${zC} = ${zC ? (zH / zC).toFixed(4) : 'n/a'}   <- structurally 0 (selection)`);
  console.log(`  non-zero runs only         : ${nH}/${nC} = ${nC ? (nH / nC).toFixed(4) : 'n/a'}`);
  console.log(`  => the failing runs contribute ${zC} Common victories and ${zH} hits; using a failing run's OWN`);
  console.log(`     observed rate to predict its own future hits is circular and biased toward 0.`);
  console.log('\n  estimator sensitivity (baseline and M=+30 rebuilt under each rate family):');
  console.log(`  ${'rateFamily'.padEnd(14)}${'base f1zero'.padStart(14)}${'base deliv'.padStart(12)}${'M+30 f1zero'.padStart(14)}${'M+30 elite'.padStart(14)}`);
  for (const [name, kappa] of [['pooled', 5], ['loo', 5], ['shrink k=2', 2], ['shrink k=5', 5], ['shrink k=10', 10]]) {
    const mode = name.startsWith('shrink') ? 'shrink' : name;
    const fn = estimateRates(runs, mode, kappa);
    const b = evaluate(runs, () => (x) => x.tier, fn);
    const m = matchShare([1, 2, 3, 4, 5], actualCommons + 30, runs);
    const r30 = evaluate(runs, mTierOf([1, 2, 3, 4, 5], m.share), fn);
    console.log(`  ${name.padEnd(14)}${(b.zeroFix.toFixed(2)+'/'+zeroRuns.length).padStart(14)}${b.deliv.toFixed(2).padStart(12)}` +
      `${(r30.zeroFix.toFixed(2)+'/'+zeroRuns.length).padStart(14)}${r30.elite.toFixed(0).padStart(14)}`);
  }
  console.log('\n  NOTE: no combination of M/G/T was run. A5 combined remains UNAPPROVED.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();

export { loadRuns, evaluate, mTierOf, matchShare, guardFloor, timingFrontload, estimateRates, EC, BAND };
