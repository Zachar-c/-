#!/usr/bin/env node
// Reachability-6 preflight, multi-seed confidence batch (inbox #17 whitelist).
// Reads ALL R5 audit logs in $TEMP/gu-zhenrens-r5-logs/ (batch1 + batch2).
//
// Mutually exclusive variable families (inbox #17 item 3):
//   COVERAGE (S1'): which layers have a Common channel at all (binary 0/0.75
//              share when covered) - marginal reported at fixed share.
//   SHARE    (S2'): uniform Common share across all covered non-boss battles
//              - marginal reported at full coverage.
// Also: short-run boundary analysis and natural-timing statistics.
//
// Shared model: production per-tier pity semantics (common counter advances
// only on common-table victories, threshold 3, forces 1 f1); natural f1 rate
// per common-table victory = observed pooled rate; all hypothetical.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { parseLog, mulberry32 } from './q8g_reachability5_abcd_comparison.mjs';

const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const P_NATURAL = 10 / 18;
const THRESHOLD = 3;

function loadRuns() {
  const runs = [];
  for (const f of fs.readdirSync(logDir).filter(f => f.endsWith('.log')).sort()) {
    const m = f.match(/^(force|sword)_(\d+)\.log$/);
    if (!m) continue;
    const parsed = parseLog(path.join(logDir, f));
    const text = fs.readFileSync(path.join(logDir, f), 'utf8');
    const summary = text.match(/R-5 summary: .*/g)?.pop() || '';
    const commonBeforeFirst = Number((summary.match(/common_before_first_refinement=(\d+)/) || [])[1] ?? 0);
    const battles = parsed.battles;
    const common = battles.filter(b => b.outcome === 'victory' && b.tier === 'common');
    runs.push({
      school: m[1], seed: m[2], battles, visitMarks: parsed.visitMarks,
      legalF1: parsed.legalF1,
      commonCount: common.length,
      f1Count: battles.reduce((s, b) => s + b.f1_hit, 0),
      battleCount: battles.length,
      commonBeforeFirst,
    });
  }
  return runs;
}

// Production per-tier pity on a hypothetical tier assignment.
function simulate(run, tierOf, rng) {
  let counter = 0, deliveries = 0, firstDelivery = -1;
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < P_NATURAL) {
      deliveries += 1;
      if (firstDelivery === -1) firstDelivery = b.idx;
      counter = 0;
    } else if (counter >= THRESHOLD) {
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

function agg(runs, tierOfFactory, seedTag) {
  let zeroResolved = 0, zeroTotal = 0, inWindow = 0, deliveries = 0, shortZeroUnresolved = 0;
  for (const run of runs) {
    const wasZero = run.f1Count === 0;
    const isShort = run.battleCount < 15;
    const rng = mulberry32([...(run.school + run.seed + seedTag)].reduce((a, c) => a + c.charCodeAt(0) * 31, 7));
    const r = simulate(run, tierOfFactory(run), rng);
    deliveries += r.deliveries;
    inWindow += r.inWindow ? 1 : 0;
    if (wasZero) {
      zeroTotal += 1;
      if (r.deliveries > 0) zeroResolved += 1;
      else if (isShort) shortZeroUnresolved += 1;
    }
  }
  return { zeroResolved, zeroTotal, inWindow, deliveries, shortZeroUnresolved };
}

const runs = loadRuns();
const zeroRuns = runs.filter(r => r.f1Count === 0);
const shortRuns = runs.filter(r => r.battleCount < 15);
console.log(`Reachability-6 multi-seed preflight: ${runs.length} runs (batch1 8 + batch2 8), f1_zero runs = ${zeroRuns.length}, short runs (<15 battles) = ${shortRuns.length}`);
console.log(`natural f1 rate per common-table victory = ${P_NATURAL.toFixed(2)}; production per-tier pity semantics; all hypothetical\n`);

// Natural timing statistics (inbox #17 item 4).
const beforeFirst = runs.filter(r => r.commonBeforeFirst > 0).length;
console.log(`natural timing: runs with a common battle BEFORE the first refinement visit = ${beforeFirst}/${runs.length}`);

// ---- COVERAGE marginal (fixed share 0.75 on covered layers).
const coverageVariants = [
  ['actual coverage', null],
  ['+L4', { 4: 0.75 }],
  ['+L5', { 5: 0.75 }],
  ['+L4+L5', { 4: 0.75, 5: 0.75 }],
  ['+L3+L4+L5', { 3: 0.75, 4: 0.75, 5: 0.75 }],
];
console.log('\nCOVERAGE marginal (covered layers get share 0.75; uncovered keep actual tiers):');
for (const [name, override] of coverageVariants) {
  const tierOf = override
    ? (b) => (override[b.layer] !== undefined && b.tier !== 'boss'
      ? (mulberry32(b.idx * 977 + b.layer)() < override[b.layer] ? 'common' : 'elite')
      : b.tier)
    : (b) => b.tier;
  const r = agg(runs, () => tierOf, 'COV' + name);
  console.log(`  ${name.padEnd(14)} f1_zero_resolved=${r.zeroResolved}/${r.zeroTotal}  inWindow_runs=${r.inWindow}/${runs.length}  deliveries=${r.deliveries}  short_zero_unresolved=${r.shortZeroUnresolved}`);
}

// ---- SHARE marginal (full coverage: every non-boss battle may be common).
console.log('\nSHARE marginal (uniform share across all non-boss battles = full coverage):');
for (const p of [0.21, 0.4, 0.6, 0.75, 0.9]) {
  const tierOf = (b) => b.tier === 'boss' ? 'boss'
    : (b.tier === 'common' ? 'common'
      : (mulberry32(b.idx * 131 + Math.round(p * 100))() < p ? 'common' : 'elite'));
  const r = agg(runs, () => tierOf, 'SH' + p);
  console.log(`  share=${String(p).padEnd(5)} f1_zero_resolved=${r.zeroResolved}/${r.zeroTotal}  inWindow_runs=${r.inWindow}/${runs.length}  deliveries=${r.deliveries}  short_zero_unresolved=${r.shortZeroUnresolved}`);
}

// ---- Short-run boundary analysis (inbox #17 item 2).
console.log('\nShort-run boundary analysis (runs with <15 battles):');
for (const run of shortRuns) {
  const commonLayersSet = new Set();
  for (const b of run.battles) if (b.outcome === 'victory' && b.tier === 'common') commonLayersSet.add(b.layer);
  console.log(`  ${run.school}/${run.seed}: battles=${run.battleCount} visits=${run.visitMarks.length} common_battles=${run.commonCount} common_layers=[${[...commonLayersSet]}] f1=${run.f1Count}`);
}
