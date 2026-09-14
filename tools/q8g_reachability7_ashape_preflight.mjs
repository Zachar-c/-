#!/usr/bin/env node
// Reachability-7 / A-Shape Design Preflight (inbox #18 whitelist).
// MEASUREMENT-ONLY. Reads the 16 R5 audit logs + data/*.json. Writes nothing
// into the game. Does NOT modify scripts/domain, data, presentation or tests.
//
// Purpose: compare the SIDE EFFECTS of four candidate shapes for product
// option A. Each candidate is a SINGLE-VARIABLE hypothetical. A5 (combined)
// is deliberately NOT implemented here (requires separate approval).
//
//   A1  L5-only coverage      : give layer 5 a Common channel at all, holding
//                               the applied share at a *matched reference*
//                               (pooled observed common share of covered
//                               layers). Also swept at fixed magnitudes to
//                               test whether coverage is separable from share.
//   A2  effective-share floor : floor the effective Common share of every
//                               non-boss battle; sweep 0.60 / 0.75.
//   A3  short-run guard       : runs with <15 battles get a Common opportunity
//                               floor; sweep floor K = 1 / 2.
//   A4  timing-only           : count-preserving permutation that front-loads
//                               the EXISTING Common battles. Tier multiset is
//                               preserved exactly, so material pieces and elite
//                               exposure are provably unchanged.
//
// Mandatory reporting (inbox #18):
//   f1=0 repair rate | first delivery inside the refinement window | short-run
//   residue | total material pieces (distribution only, no fixed yield gain)
//   | 元石 / Elite-cost exposure flag.
//
// Confidence: every variant is evaluated over REPLICATES seeded streams, so
// the report carries mean + min..max spread instead of a single point estimate
// (this addresses the R6 "single RNG path / point estimate" limitation).

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL } from 'node:url';
import { parseLog, mulberry32 } from './q8g_reachability5_abcd_comparison.mjs';

const projectRoot = path.resolve(import.meta.dirname, '..');
const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const loot = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/loot_tables.json'), 'utf8'));
const pacing = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/pacing.json'), 'utf8'));

const SHORT_RUN_BATTLES = 15;   // inbox #18 definition of a short run
const PITY_THRESHOLD = loot.pity.threshold ?? 3;
const P_NATURAL_DEFAULT = 10 / 18; // matches R6 for comparability

// ---- Grounded accounting constants (read from data, not hardcoded guesses).
const TIER_FACTS = {};
for (const tier of ['common', 'elite', 'boss']) {
  const e = loot.loot[tier];
  TIER_FACTS[tier] = {
    materialCount: e.material_count,
    guChance: (e.gu_chance_pct ?? 0) / 100,
    hasCostPool: Boolean(e.cost_pool && e.cost_pool.length),
  };
}
const PITY_BANDS = loot.pity.material_pity?.target_bands_by_tier ?? {};

function parseArgs(argv) {
  const opts = { replicates: 64, natural: P_NATURAL_DEFAULT, json: false };
  for (const a of argv.slice(2)) {
    const m = a.match(/^--replicates=(\d+)$/); if (m) opts.replicates = Number(m[1]);
    if (a === '--natural=observed') opts.natural = null;
    if (a === '--json') opts.json = true;
  }
  return opts;
}

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
    const commonVictories = parsed.battles.filter(b => b.outcome === 'victory' && b.tier === 'common');
    const f1Count = parsed.battles.reduce((s, b) => s + b.f1_hit, 0);
    runs.push({
      school: m[1], seed: m[2], key: `${m[1]}/${m[2]}`,
      battles: parsed.battles,
      visitMarks: parsed.visitMarks,
      f1Count,
      wasZero: f1Count === 0,
      battleCount: num(/battles=(\d+)/, parsed.battles.length),
      isShort: num(/battles=(\d+)/, parsed.battles.length) < SHORT_RUN_BATTLES,
      commonCount: commonVictories.length,
      observedCommonRate: commonVictories.length
        ? commonVictories.reduce((s, b) => s + b.f1_hit, 0) / commonVictories.length
        : null,
      commonBeforeFirst: num(/common_before_first_refinement=(\d+)/),
    });
  }
  return runs.sort((a, b) => a.key.localeCompare(b.key));
}

// ------------------------------------------------------------- shared metrics
function settledOf(battle) { return battle.outcome === 'victory' && battle.tier !== 'unsettled'; }

function exposures(tierOf, run) {
  const acc = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0, settled: 0 };
  for (const b of run.battles) {
    if (!settledOf(b)) continue;
    const t = tierOf(b);
    const f = TIER_FACTS[t];
    if (!f) continue;
    acc.pieces += f.materialCount;
    acc.guExp += f.guChance;
    acc[t] = (acc[t] ?? 0) + 1;
    acc.settled += 1;
  }
  return acc;
}

// Production per-tier pity semantics on a hypothetical tier assignment.
// Counter advances only on common-table victories; threshold forces one f1.
function simulate(run, tierOf, rng, pNatural) {
  let counter = 0, deliveries = 0, firstDelivery = -1;
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < pNatural || counter >= PITY_THRESHOLD) {
      deliveries += 1;
      if (firstDelivery === -1) firstDelivery = b.idx;
      counter = 0;
    } else {
      counter += 1;
    }
  }
  const lastVisit = run.visitMarks.length ? Math.max(...run.visitMarks) : 0;
  return { deliveries, firstDelivery, inWindow: firstDelivery !== -1 && firstDelivery <= lastVisit };
}

// ------------------------------------------------------ candidate definitions
// Each candidate returns a tierOf(battle) function. Pure functions of the run.

function makeReferenceShare(runs) {
  // Pooled observed Common share among layers that ALREADY have coverage.
  let commonBattles = 0, nonBossSettled = 0;
  const layerHasCommon = new Map();
  for (const run of runs) {
    for (const b of run.battles) {
      if (!settledOf(b) || b.tier === 'boss') continue;
      nonBossSettled += 1;
      if (b.tier === 'common') { commonBattles += 1; layerHasCommon.set(b.layer, true); }
    }
  }
  const coveredNonBoss = runs.flatMap(r => r.battles)
    .filter(b => settledOf(b) && b.tier !== 'boss' && layerHasCommon.get(b.layer));
  let coveredSettled = 0, coveredCommon = 0;
  for (const b of coveredNonBoss) { coveredSettled += 1; if (b.tier === 'common') coveredCommon += 1; }
  return {
    pooled: nonBossSettled ? commonBattles / nonBossSettled : 0,
    matched: coveredSettled ? coveredCommon / coveredSettled : 0,
    coveredLayers: [...layerHasCommon.keys()].sort(),
  };
}

// Per-layer coverage diagnostic. Decides whether "L5-only coverage" can be a
// structural toggle or is necessarily a magnitude restoration.
function perLayerDiagnostic(runs) {
  const byLayer = new Map();
  for (const run of runs) {
    for (const b of run.battles) {
      if (!settledOf(b) || b.tier === 'boss') continue;
      const e = byLayer.get(b.layer) ?? { settled: 0, common: 0 };
      e.settled += 1;
      if (b.tier === 'common') e.common += 1;
      byLayer.set(b.layer, e);
    }
  }
  return [...byLayer.entries()].sort((a, b) => a[0] - b[0])
    .map(([layer, e]) => ({ layer, settled: e.settled, common: e.common, rate: e.settled ? e.common / e.settled : 0 }));
}

function A1_L5_coverage(share) {
  // Only change: layer 5 gains a Common channel. Every other layer keeps its
  // observed tier. `share` is the effective Common share granted on L5.
  return () => (b) => {
    if (b.tier === 'boss' || b.layer !== 5) return b.tier;
    if (b.tier === 'common') return 'common';
    return mulberry32(b.idx * 977 + 5)() < share ? 'common' : 'elite';
  };
}

function A2_share_floor(share) {
  // Only change: every non-boss battle may be Common with probability `share`.
  return () => (b) => {
    if (b.tier === 'boss') return 'boss';
    if (b.tier === 'common') return 'common';
    return mulberry32(b.idx * 131 + Math.round(share * 100))() < share ? 'common' : 'elite';
  };
}

function A3_short_guard(floorK) {
  // Only change: short runs get at least `floorK` Common-settled battles.
  // Applied back-to-front on the earliest eligible non-boss battles.
  return (run) => {
    const base = (b) => b.tier;
    if (!run.isShort) return base;
    const eligible = run.battles.filter(b => settledOf(b) && b.tier !== 'boss');
    const have = eligible.filter(b => b.tier === 'common').length;
    if (have >= floorK) return base;
    const promote = new Set(
      eligible.filter(b => b.tier !== 'common').slice(0, floorK - have).map(b => b.idx));
    return (b) => (promote.has(b.idx) ? 'common' : b.tier);
  };
}

function A4_timing_only() {
  // Only change: ORDER. The tier multiset over non-boss settled battles is
  // preserved exactly and re-assigned to the earliest slots (best-case
  // front-loading). Material pieces / elite exposure are provably invariant.
  return (run) => {
    const slots = run.battles.filter(b => settledOf(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const tiers = run.battles.filter(b => settledOf(b) && b.tier !== 'boss').map(b => b.tier);
    const commons = tiers.filter(t => t === 'common').length;
    const remap = new Map();
    slots.forEach((idx, i) => remap.set(idx, i < commons ? 'common' : 'elite'));
    return (b) => (remap.has(b.idx) ? remap.get(b.idx) : b.tier);
  };
}

function A3b_short_front_window() {
  // Second reading of "short-run guard": if a short run has NO Common battle at
  // or before its first refinement visit, swap the earliest eligible slot with
  // the earliest existing Common. Exactly ONE swap per run, so the tier
  // multiset is preserved exactly -> elite exposure and material pieces
  // invariant, and it is clearly distinct from A4 (which front-loads ALL).
  return (run) => {
    const base = (b) => b.tier;
    if (!run.isShort || !run.visitMarks.length) return base;
    const firstVisit = Math.min(...run.visitMarks);
    const eligible = run.battles.filter(b => settledOf(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const commonIdx = run.battles.filter(b => settledOf(b) && b.tier === 'common').map(b => b.idx).sort((a, b) => a - b);
    if (!commonIdx.length) return base;                                   // no Common to move
    if (commonIdx[0] <= firstVisit) return base;                          // already inside the window
    const slot = eligible.find(idx => idx <= firstVisit);                 // earliest slot inside the window
    if (slot === undefined || slot === commonIdx[0]) return base;
    const swap = new Map([[slot, 'common'], [commonIdx[0], 'elite']]);
    return (b) => (swap.has(b.idx) ? swap.get(b.idx) : b.tier);
  };
}

// ---------------------------------------------------------------- evaluation
function evaluate(runs, label, tierOfFor, opts) {
  const naturalFor = (run) => (opts.natural === null ? (run.observedCommonRate ?? 0.55) : opts.natural);
  const perRep = [];
  for (let rep = 0; rep < opts.replicates; rep++) {
    let zeroResolved = 0, inWindow = 0, shortZero = 0, deliveries = 0;
    const exp = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0, settled: 0 };
    for (const run of runs) {
      const tierOf = tierOfFor(run);
      const seedKey = [...`${run.key}|${label}|${rep}`].reduce((a, c) => a + c.charCodeAt(0) * 31, 7);
      const r = simulate(run, tierOf, mulberry32(seedKey), naturalFor(run));
      deliveries += r.deliveries;
      inWindow += r.inWindow ? 1 : 0;
      if (run.wasZero) {
        if (r.deliveries > 0) zeroResolved += 1; else if (run.isShort) shortZero += 1;
      }
      const e = exposures(tierOf, run);
      for (const k of Object.keys(exp)) exp[k] += e[k];
    }
    perRep.push({ zeroResolved, inWindow, shortZero, deliveries, ...exp });
  }
  const agg = {};
  for (const k of Object.keys(perRep[0])) {
    const vals = perRep.map(p => p[k]);
    agg[k] = {
      mean: vals.reduce((a, b) => a + b, 0) / vals.length,
      min: Math.min(...vals), max: Math.max(...vals),
      constant: vals.every(v => v === vals[0]),
    };
  }
  return { label, perRep, agg };
}

function fmt(a) {
  if (a.constant) return a.mean.toFixed(2);
  return `${a.mean.toFixed(2)} [${a.min}..${a.max}]`;
}

function fmtCount(a, denom) {
  const num = a.constant ? String(Math.round(a.mean)) : a.mean.toFixed(2);
  return denom === undefined ? num : `${num}/${denom}`;
}

// ---------------------------------------------------------------------- main
function main() {
  const opts = parseArgs(process.argv);
  const runs = loadRuns();
  if (!runs.length) { console.error(`no R5 logs in ${logDir}`); process.exit(1); }
  const ref = makeReferenceShare(runs);
  const zeroRuns = runs.filter(r => r.wasZero);
  const shortRuns = runs.filter(r => r.isShort);
  const observedRate = (() => {
    const withRate = runs.filter(r => r.observedCommonRate !== null);
    const totalCommon = runs.reduce((s, r) => s + r.commonCount, 0);
    const totalHits = runs.reduce((s, r) => s + r.battles.filter(b => b.tier === 'common').reduce((x, b) => x + b.f1_hit, 0), 0);
    return { pooled: totalCommon ? totalHits / totalCommon : null, runsWithCommon: withRate.length };
  })();

  const layerDiag = perLayerDiagnostic(runs);
  const l5 = layerDiag.find(d => d.layer === 5);
  const l5Rate = l5 && l5.settled ? l5.rate : 0;

  const variants = [
    ['ACTUAL', () => (b) => b.tier],
    [`A1 L5 cov @ref ${ref.matched.toFixed(2)}`, A1_L5_coverage(ref.matched)],
    [`A1 L5 cov @own ${l5Rate.toFixed(2)}`, A1_L5_coverage(l5Rate)],
    [`A1 L5 cov @0.60`, A1_L5_coverage(0.60)],
    [`A1 L5 cov @0.75`, A1_L5_coverage(0.75)],
    [`A2 share floor 0.60`, A2_share_floor(0.60)],
    [`A2 share floor 0.75`, A2_share_floor(0.75)],
    [`A3a short floor K=1`, A3_short_guard(1)],
    [`A3a short floor K=2`, A3_short_guard(2)],
    ['A3b short front-window', A3b_short_front_window()],
    ['A4 timing-only (all)', A4_timing_only()],
  ];

  const results = variants.map(([label, factory]) => evaluate(runs, label, factory, opts));

  if (opts.json) {
    console.log(JSON.stringify({
      runs: runs.length, zeroRuns: zeroRuns.length, shortRuns: shortRuns.length,
      replicates: opts.replicates,
      reference: { matched: ref.matched, pooled: ref.pooled, coveredLayers: ref.coveredLayers },
      tierFacts: TIER_FACTS,
      results: results.map(r => ({ label: r.label, agg: r.agg })),
    }, null, 2));
    return;
  }

  console.log('Reachability-7 / A-Shape Design Preflight  (measurement-only, hypothetical)');
  console.log(`corpus: ${runs.length} runs | f1_zero = ${zeroRuns.length} | short (<${SHORT_RUN_BATTLES} battles) = ${shortRuns.length} | replicates = ${opts.replicates}`);
  console.log(`reference share: matched(covered layers) = ${ref.matched.toFixed(3)} | pooled(all non-boss) = ${ref.pooled.toFixed(3)} | covered layers = [${ref.coveredLayers}]`);
  console.log(`pity: per-tier threshold ${PITY_THRESHOLD}; natural f1 rate = ${opts.natural === null ? 'observed per run' : opts.natural.toFixed(3)}${observedRate.pooled === null ? '' : ` (pooled observed among common victories = ${observedRate.pooled.toFixed(3)}, ${observedRate.runsWithCommon}/${runs.length} runs have a Common victory)`}`);
  console.log(`side-effect basis: common{mat=${TIER_FACTS.common.materialCount},gu=${TIER_FACTS.common.guChance},cost=no} elite{mat=${TIER_FACTS.elite.materialCount},gu=${TIER_FACTS.elite.guChance},cost=yes} boss{mat=${TIER_FACTS.boss.materialCount}}`);

  // ---- Per-layer coverage diagnostic (grounds the A1 interpretation).
  console.log('\nPer-layer Common coverage (settled non-boss battles):');
  for (const d of layerDiag) {
    console.log(`  L${d.layer}: settled=${String(d.settled).padStart(3)}  common=${String(d.common).padStart(2)}  rate=${(d.rate * 100).toFixed(1)}%`);
  }
  console.log(`  => L5 already has a non-zero Common channel (rate ${(l5Rate * 100).toFixed(1)}%); "L5-only coverage" is therefore a MAGNITUDE restoration on L5, not a structural on/off toggle.`);

  // ---- Pity feasibility on the failing runs. With no natural hits, the pity
  // counter fires once per (THRESHOLD+1) common victories, so a run needs at
  // least THRESHOLD+1 common victories for pity ALONE to repair it.
  const needCommons = PITY_THRESHOLD + 1;
  console.log(`\nPity feasibility on the f1=0 runs (pity alone fires on common #${needCommons}, #${needCommons * 2}, ...):`);
  for (const run of zeroRuns) {
    const feasible = run.commonCount >= needCommons;
    console.log(`  ${run.key.padEnd(12)} battles=${String(run.battleCount).padStart(2)} common_victories=${run.commonCount}  short=${run.isShort ? 'yes' : 'no '}  pity_alone_can_repair=${feasible ? 'YES' : 'NO'}  (needs >= ${needCommons})`);
  }
  console.log(`  mean [min..max] over ${opts.replicates} seeded replicates per variant\n`);

  // ---- OBSERVED (fact) baseline: what actually happened, no model applied.
  const observed = (() => {
    let deliveries = 0, inWindow = 0, shortZero = 0;
    const exp = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0, settled: 0 };
    for (const run of runs) {
      const lastVisit = run.visitMarks.length ? Math.max(...run.visitMarks) : 0;
      let first = -1;
      for (const b of run.battles) {
        if (b.f1_hit > 0) { deliveries += b.f1_hit; if (first === -1) first = b.idx; }
      }
      if (first !== -1 && first <= lastVisit) inWindow += 1;
      if (run.wasZero && run.isShort) shortZero += 1;
      const e = exposures(b => b.tier, run);
      for (const k of Object.keys(exp)) exp[k] += e[k];
    }
    return { deliveries, inWindow, shortZero, ...exp };
  })();
  console.log('OBSERVED (fact, no model applied):');
  console.log(`  f1zero_fix 0/${zeroRuns.length} (nothing changes)   inWindow ${observed.inWindow}/${runs.length}   shortZero ${observed.shortZero}   deliv ${observed.deliveries}   matPieces ${observed.pieces}   elite ${observed.elite}   common ${observed.common}\n`);

  const cols = [
    ['f1zero_fix', r => fmtCount(r.zeroResolved, zeroRuns.length)],
    ['inWindow', r => fmtCount(r.inWindow, runs.length)],
    ['shortZero', r => fmtCount(r.shortZero)],
    ['deliv', r => fmt(r.deliveries)],
    ['matPieces', r => fmt(r.pieces)],
    ['guExp', r => fmt(r.guExp)],
    ['elite', r => fmt(r.elite)],
    ['common', r => fmt(r.common)],
  ];
  const width = Math.max(...results.map(r => r.label.length), 8);
  console.log(`${'variant'.padEnd(width)}  ${cols.map(([h]) => h.padStart(14)).join('  ')}`);
  console.log('-'.repeat(width + cols.length * 16));
  for (const res of results) {
    const cells = cols.map(([, get]) => String(get(res.agg)).padStart(14));
    console.log(`${res.label.padEnd(width)}  ${cells.join('  ')}`);
  }

  // ---- Mandatory: 元石 / Elite-cost exposure flag.
  const base = results[0].agg, baseElite = base.elite.mean;
  console.log('\n元石 / Elite-cost exposure flag (elite battles carry cost_pool: curse or notoriety+2):');
  for (const res of results.slice(1)) {
    const d = res.agg.elite.mean - baseElite;
    const pct = baseElite ? (d / baseElite) * 100 : 0;
    const tag = d === 0 ? 'NO COST IMPACT (exposure invariant)'
      : (d < 0 ? `cost EXPOSURE DROPS ${Math.abs(d).toFixed(2)} (${pct.toFixed(1)}%)` : `cost exposure RISES ${d.toFixed(2)}`);
    console.log(`  ${res.label.padEnd(width)}  elite ${baseElite.toFixed(2)} -> ${res.agg.elite.mean.toFixed(2)}   ${tag}`);
  }

  console.log('\nMaterial piece check (inbox #18: distribution only, no fixed yield increase):');
  const basePieces = base.pieces.mean;
  for (const res of results.slice(1)) {
    const d = res.agg.pieces.mean - basePieces;
    console.log(`  ${res.label.padEnd(width)}  pieces ${basePieces.toFixed(2)} -> ${res.agg.pieces.mean.toFixed(2)}  (delta ${d >= 0 ? '+' : ''}${d.toFixed(2)})`);
  }
  console.log(`  NOTE: common and elite both declare material_count=${TIER_FACTS.common.materialCount}, so elite->common conversion is piece-neutral;`);
  console.log(`        what changes is the QUALITY BAND (pity bands: common=[${(PITY_BANDS.common || []).join(',')}] elite=[${(PITY_BANDS.elite || []).join(',')}]) and gu chance (${TIER_FACTS.common.guChance} vs ${TIER_FACTS.elite.guChance}).`);

  // ---- Separability probe: is A1 coverage a lever on its own?
  console.log('\nSeparability probe (is A1 "coverage" separable from A2 "share magnitude"?):');
  for (const label of ['A1 L5 cov @own', 'A1 L5 cov @ref', 'A1 L5 cov @0.60', 'A1 L5 cov @0.75']) {
    const r = results.find(x => x.label.startsWith(label));
    if (!r) continue;
    console.log(`  ${r.label.padEnd(width)}  f1zero_fix ${fmtCount(r.agg.zeroResolved, zeroRuns.length)}  shortZero ${r.agg.shortZero.mean.toFixed(2)}  elite ${r.agg.elite.mean.toFixed(0)}`);
  }
  console.log(`  A2 share floor 0.60 (all layers)` + ''.padEnd(Math.max(0, width - 31)) +
    `  f1zero_fix ${fmtCount(results.find(r => r.label.startsWith('A2 share floor 0.60')).agg.zeroResolved, zeroRuns.length)}  shortZero ${results.find(r => r.label.startsWith('A2 share floor 0.60')).agg.shortZero.mean.toFixed(2)}  elite ${results.find(r => r.label.startsWith('A2 share floor 0.60')).agg.elite.mean.toFixed(0)}`);
  console.log(`\n  INTERPRETATION: L5 arrives with rate ${(l5Rate * 100).toFixed(1)}%. A1 "restores" L5 by raising ITS magnitude,`);
  console.log(`  so A1 and A2 share the SAME mechanism (magnitude) and differ only in SCOPE (L5-only vs all layers).`);
  console.log(`  They are NOT independent mechanisms; only A3 (population guard) and A4 (order) are orthogonal to magnitude.`);

  // ---- Per-failing-run Common count under each candidate. This is the
  // decision-relevant matrix: a run can only be repaired without a natural hit
  // once its Common count reaches PITY_THRESHOLD + 1.
  console.log(`\nCommon count on the f1=0 runs (repair without a natural hit needs >= ${needCommons}):`);
  const shortTags = variants.slice(1).map(v => v[0].replace(/^A1 L5 cov @/, 'A1@')
    .replace(/^A2 share floor /, 'A2@').replace(/^A3a short floor /, 'A3a ').replace(/^A3b short front-window/, 'A3b').replace(/^A4 timing-only \(all\)/, 'A4'));
  const tagW = Math.max(8, ...shortTags.map(t => t.length));
  console.log(`${'run'.padEnd(13)}${'actual'.padStart(8)}` + shortTags.map(t => t.padStart(tagW + 1)).join(''));
  for (const run of zeroRuns) {
    let line = `${run.key.padEnd(13)}${String(run.commonCount).padStart(8)}`;
    for (const [, factory] of variants.slice(1)) {
      const tierOf = factory(run);
      const c = run.battles.filter(b => settledOf(b) && tierOf(b) === 'common').length;
      line += `${(c >= needCommons ? `${c}*` : String(c)).padStart(tagW + 1)}`;
    }
    console.log(line);
  }
  console.log(`  (* = at/above the pity-only repair threshold of ${needCommons})`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}

export { loadRuns, evaluate, A1_L5_coverage, A2_share_floor, A3_short_guard, A4_timing_only, TIER_FACTS };
