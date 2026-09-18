#!/usr/bin/env node
// Reachability-7B / A-Shape DESIGN preflight (inbox #19 items 1-5).
// MEASUREMENT-ONLY. Reads the R5 audit logs + data/*.json. Never writes into
// the game and never modifies scripts/domain, data, presentation or tests.
//
// Inbox #19 asks for five things, all hypothetical:
//   1. scope of A            -> L5 only / L4+L5 / all-layer share floor
//   2. side-effect acceptance-> Elite cost exposure, Gu expectation, material band
//   3. short-run guard       -> candidate designs, no fixed yield increase
//   4. refinement timing     -> candidate designs, no new nodes, no map change
//   5. 32+ run validation    -> plan (executed separately; this tool auto-detects corpus size)
//   A5 combined stays UNAPPROVED and is NOT implemented.
//
// The decisive methodological point: scopes are compared at MATCHED total
// Common opportunity, so the difference measured is purely WHERE the
// opportunity goes, not HOW MUCH is added. Without matching, "L5-only" and
// "all-layer" cannot be separated from "more total yield".

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
const PITY_REPAIR_COMMONS = PITY_THRESHOLD + 1;   // pity fires on the 4th Common
const P_NATURAL = 10 / 18;

// ------------------------------------------------------------- data grounding
function tierFacts(tier) {
  const e = loot.loot[tier];
  return {
    materialCount: e.material_count,
    guChance: (e.gu_chance_pct ?? 0) / 100,
    costPool: e.cost_pool ?? null,
  };
}
const FACTS = { common: tierFacts('common'), elite: tierFacts('elite'), boss: tierFacts('boss') };

// Band composition of each tier's material pool (weight share), from data.
function bandShares(tier) {
  const pool = loot.loot[tier].material_pool;
  const out = {}; let total = 0;
  for (const e of pool) {
    const id = typeof e === 'string' ? e : e.id;
    const w = typeof e === 'string' ? 1 : Math.max(1, e.weight || 1);
    const band = loot.materials[id]?.quality_band ?? 'unknown';
    out[band] = (out[band] ?? 0) + w; total += w;
  }
  for (const k of Object.keys(out)) out[k] /= total;
  return out;
}
const BANDS = { common: bandShares('common'), elite: bandShares('elite'), boss: bandShares('boss') };

// Expected Elite cost per elite battle, from cost_pool weights.
function eliteCostPerBattle() {
  const pool = FACTS.elite.costPool ?? [];
  let total = 0;
  for (const e of pool) total += Math.max(1, e.weight || 1);
  let curseLayers = 0, notoriety = 0;
  for (const e of pool) {
    const w = Math.max(1, e.weight || 1) / (total || 1);
    if (e.kind === 'backlash') curseLayers += w * (e.layers ?? 1);
    if (e.kind === 'notoriety') notoriety += w * (e.amount ?? 0);
  }
  return { curseLayers, notoriety, kinds: pool.map(e => e.kind) };
}
const ELITE_COST = eliteCostPerBattle();

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
    runs.push({
      school: m[1], seed: m[2], key: `${m[1]}/${m[2]}`, battles,
      visitMarks: parsed.visitMarks, f1Count, wasZero: f1Count === 0,
      battleCount: num(/battles=(\d+)/, battles.length),
      isShort: num(/battles=(\d+)/, battles.length) < SHORT_RUN_BATTLES,
      commonCount: battles.filter(b => b.outcome === 'victory' && b.tier === 'common').length,
    });
  }
  return runs.sort((a, b) => a.key.localeCompare(b.key));
}

const settled = b => b.outcome === 'victory' && b.tier !== 'unsettled';
const firstVisit = run => run.visitMarks.length ? Math.min(...run.visitMarks) : Infinity;
const lastVisit = run => run.visitMarks.length ? Math.max(...run.visitMarks) : 0;

// --------------------------------------------------------------- accounting
function account(tierOf, runs) {
  const acc = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0,
    curseLayers: 0, notoriety: 0, bands: {} };
  for (const run of runs) {
    for (const b of run.battles) {
      if (!settled(b)) continue;
      const t = tierOf(b);
      const f = FACTS[t];
      if (!f) continue;
      acc.pieces += f.materialCount;
      acc.guExp += f.guChance;
      acc[t] = (acc[t] ?? 0) + 1;
      if (t === 'elite') { acc.curseLayers += ELITE_COST.curseLayers; acc.notoriety += ELITE_COST.notoriety; }
      for (const [band, share] of Object.entries(BANDS[t] ?? {})) {
        acc.bands[band] = (acc.bands[band] ?? 0) + f.materialCount * share;
      }
    }
  }
  return acc;
}

function simulate(run, tierOf, rng) {
  let counter = 0, deliveries = 0, first = -1;
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    if (tierOf(b) !== 'common') continue;
    if (rng() < P_NATURAL || counter >= PITY_THRESHOLD) {
      deliveries += 1; if (first === -1) first = b.idx; counter = 0;
    } else counter += 1;
  }
  return { deliveries, first, inWindow: first !== -1 && first <= lastVisit(run) };
}

function evaluate(runs, tierOfFor, replicates = 64) {
  let zeroResolved = 0, inWindow = 0, shortZero = 0, deliveries = 0;
  const acc = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0, curseLayers: 0, notoriety: 0, bands: {} };
  // accounting is deterministic
  const accOnce = { pieces: 0, guExp: 0, elite: 0, common: 0, boss: 0, curseLayers: 0, notoriety: 0, bands: {} };
  for (const run of runs) {
    const a = account(tierOfFor(run), [run]);
    for (const k of Object.keys(accOnce)) {
      if (k === 'bands') { for (const [band, v] of Object.entries(a.bands)) accOnce.bands[band] = (accOnce.bands[band] ?? 0) + v; }
      else accOnce[k] += a[k];
    }
  }
  for (let rep = 0; rep < replicates; rep++) {
    for (const run of runs) {
      const seed = [...`${run.key}|${rep}`].reduce((x, c) => x + c.charCodeAt(0) * 31, 7);
      const r = simulate(run, tierOfFor(run), mulberry32(seed));
      deliveries += r.deliveries;
      inWindow += r.inWindow ? 1 : 0;
      if (run.wasZero) { if (r.deliveries > 0) zeroResolved += 1; else if (run.isShort) shortZero += 1; }
    }
  }
  const n = replicates;
  return {
    zeroResolved: zeroResolved / n, inWindow: inWindow / n,
    shortZero: shortZero / n, deliveries: deliveries / n, ...accOnce,
  };
}

// ------------------------------------------------------- scope: boost by share
// Eligible = layers in scope, non-boss, currently not common.
// NOTE: the per-battle uniform draw is STABLE (independent of `share`) so that
// raising the share monotonically ADDS conversions. Hashing the share value
// instead would reshuffle every battle on each step and destroy monotonicity,
// which silently breaks any matched-yield search.
function stableUniform(b) { return mulberry32(b.idx * 977 + b.layer * 31)(); }
function scopeTierOf(scopeLayers, share) {
  return () => (b) => {
    if (b.tier === 'boss') return 'boss';
    if (b.tier === 'common') return 'common';
    if (!scopeLayers.includes(b.layer)) return b.tier;
    return stableUniform(b) < share ? 'common' : 'elite';
  };
}
function realizedCommons(scopeLayers, share, runs) {
  const t = scopeTierOf(scopeLayers, share);
  let n = 0;
  for (const run of runs) { const f = t(run); for (const b of run.battles) if (settled(b) && f(b) === 'common') n += 1; }
  return n;
}
// Find the share whose realised Common count lands CLOSEST to `target`.
// Monotonic in share (see stableUniform), so a fine sweep is exact enough and
// robust against the step-function nature of the realisation.
function matchShare(scopeLayers, target, runs) {
  let best = null;
  for (let s = 0; s <= 1.0001; s += 0.002) {
    const c = realizedCommons(scopeLayers, s, runs);
    const d = Math.abs(c - target);
    if (!best || d < best.dist) best = { share: s, commons: c, dist: d };
    if (c >= target && best.commons >= target && d === 0) break;
  }
  return best;
}

// ------------------------------------------------------------ guard / timing
// Guard: convert earliest non-Common battles so a short run reaches K Commons.
// Piece-neutral (common.material_count == elite.material_count), so this is a
// COMPOSITION change, not a fixed-yield increase.
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
// Guard: ensure >=K Commons fall at or before the first refinement visit.
// Pure permutation of the SAME tier multiset -> strictly invariant side effects.
function guardWindow(K) {
  return (run) => {
    const base = (b) => b.tier;
    if (!run.isShort || !run.visitMarks.length) return base;
    const fv = firstVisit(run);
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const commons = run.battles.filter(b => settled(b) && b.tier === 'common').map(b => b.idx).sort((a, b) => a - b);
    const inWindow = commons.filter(i => i <= fv).length;
    if (inWindow >= K || !commons.length) return base;
    const slots = elig.filter(i => i <= fv);
    const need = Math.min(K - inWindow, slots.length, commons.length - inWindow);
    if (need <= 0) return base;
    const remap = new Map();
    // pull the earliest `need` commons that sit AFTER the window into free slots
    const movable = commons.filter(i => i > fv).slice(0, need);
    const target = slots.filter(i => !commons.includes(i)).slice(0, need);
    movable.forEach((from, i) => { remap.set(from, 'elite'); remap.set(target[i], 'common'); });
    return (b) => (remap.has(b.idx) ? remap.get(b.idx) : b.tier);
  };
}
// Timing: count-preserving front-load of existing Commons (best case).
function timingFrontload() {
  return (run) => {
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const commons = run.battles.filter(b => settled(b) && b.tier === 'common').length;
    const remap = new Map();
    elig.forEach((idx, i) => remap.set(idx, i < commons ? 'common' : 'elite'));
    return (b) => (remap.has(b.idx) ? remap.get(b.idx) : b.tier);
  };
}
// Timing: concentrate Commons into the pre-visit slots first, then place any
// REMAINING Commons at the earliest post-visit slots. The total Common count is
// preserved exactly, so Elite exposure and material pieces stay invariant.
function timingClusterBeforeFirstVisit() {
  return (run) => {
    const base = (b) => b.tier;
    if (!run.visitMarks.length) return base;
    const fv = firstVisit(run);
    const elig = run.battles.filter(b => settled(b) && b.tier !== 'boss').map(b => b.idx).sort((a, b) => a - b);
    const total = run.battles.filter(b => settled(b) && b.tier === 'common').length;
    if (!total) return base;
    const slotsBefore = elig.filter(i => i <= fv);
    const k = Math.min(total, slotsBefore.length);
    const remap = new Map();
    let placed = 0;
    for (const idx of slotsBefore) { if (placed < k) { remap.set(idx, 'common'); placed += 1; } }
    for (const idx of elig) {
      if (placed >= total) break;
      if (idx > fv && !remap.has(idx)) { remap.set(idx, 'common'); placed += 1; }
    }
    for (const idx of elig) if (!remap.has(idx)) remap.set(idx, 'elite');
    return (b) => (remap.has(b.idx) ? remap.get(b.idx) : b.tier);
  };
}

// ------------------------------------------------------------------- report
function fmt(x, d = 2) { return Number(x).toFixed(d); }

function main() {
  const runs = loadRuns();
  if (!runs.length) { console.error(`no logs in ${logDir}`); process.exit(1); }
  const zeroRuns = runs.filter(r => r.wasZero);

  console.log('Reachability-7B / A-Shape DESIGN preflight  (measurement-only, hypothetical)');
  console.log(`corpus: ${runs.length} runs | f1_zero = ${zeroRuns.length} | short (<${SHORT_RUN_BATTLES}) = ${runs.filter(r => r.isShort).length}`);
  console.log(`pity threshold ${PITY_THRESHOLD} -> repair needs >= ${PITY_REPAIR_COMMONS} Common victories; natural f1 = ${P_NATURAL.toFixed(3)}`);
  console.log(`elite cost pool: ${ELITE_COST.kinds.join(' | ')} -> per elite battle expect ${fmt(ELITE_COST.curseLayers,2)} curse layer(s) + ${fmt(ELITE_COST.notoriety,2)} notoriety`);
  console.log(`material bands: common=${Object.entries(BANDS.common).map(([k,v])=>k+' '+(v*100).toFixed(0)+'%').join('/')}  elite=${Object.entries(BANDS.elite).map(([k,v])=>k+' '+(v*100).toFixed(0)+'%').join('/')}`);

  const base = evaluate(runs, () => (b) => b.tier);
  const actualCommons = base.common;

  // Why short-run guards can move the needle: how many f1=0 runs are short?
  const zeroShort = zeroRuns.filter(r => r.isShort).length;
  const zeroLong = zeroRuns.length - zeroShort;
  const zeroCommonCounts = zeroRuns.map(r => r.commonCount);
  console.log(`\nf1=0 breakdown: short(<${SHORT_RUN_BATTLES}) = ${zeroShort}, long = ${zeroLong}`);
  console.log(`  their Common counts: ${zeroCommonCounts.join(', ')}  (repair needs >= ${PITY_REPAIR_COMMONS} without a natural hit)`);
  console.log(`  => ${zeroCommonCounts.filter(c => c >= PITY_REPAIR_COMMONS).length}/${zeroRuns.length} can be repaired by pity alone.`);
  // L5-only ceiling: the most Commons L5 alone can ever contribute.
  const l5Eligible = runs.flatMap(r => r.battles).filter(b => settled(b) && b.tier !== 'boss' && b.layer === 5 && b.tier !== 'common').length;
  console.log(`  L5-only ceiling: ${fmt(actualCommons,0)} actual + ${l5Eligible} convertible = ${fmt(actualCommons + l5Eligible,0)} max Commons (hard cap).`);

  // ---- 1. SCOPE at MATCHED total Common opportunity.
  const scopes = [
    ['L5 only', [5]],
    ['L4+L5', [4, 5]],
    ['all layers', [1, 2, 3, 4, 5]],
  ];
  console.log(`\n[1] SCOPE compared at MATCHED total Common opportunity (actual commons = ${fmt(actualCommons,0)})`);
  for (const target of [actualCommons, actualCommons + 15, actualCommons + 30]) {
    console.log(`\n  --- target total Commons ≈ ${target} ---`);
    console.log(`  ${'scope'.padEnd(12)}${'share'.padStart(7)}${'commons'.padStart(9)}${'f1zero_fix'.padStart(12)}${'inWindow'.padStart(10)}${'shortZero'.padStart(11)}${'elite'.padStart(8)}${'curseLyr'.padStart(10)}${'notor'.padStart(8)}`);
    for (const [name, layers] of scopes) {
      const m = matchShare(layers, target, runs);
      const t = scopeTierOf(layers, m.share);
      const r = evaluate(runs, t);
      console.log(`  ${name.padEnd(12)}${fmt(m.share,3).padStart(7)}${fmt(r.common,0).padStart(9)}` +
        `${(fmt(r.zeroResolved,2)+'/'+zeroRuns.length).padStart(12)}${fmt(r.inWindow,2).padStart(10)}` +
        `${fmt(r.shortZero,2).padStart(11)}${fmt(r.elite,0).padStart(8)}${fmt(r.curseLayers,1).padStart(10)}${fmt(r.notoriety,1).padStart(8)}`);
    }
  }

  // ---- 2. SIDE EFFECTS: bands + gu, versus baseline.
  console.log('\n[2] SIDE EFFECTS (composition, not piece count) at the +15 target');
  console.log(`  ${'scope'.padEnd(12)}${'pieces'.padStart(8)}${'guExp'.padStart(8)}${'crude'.padStart(8)}${'plain'.padStart(8)}${'refined'.padStart(9)}${'prized'.padStart(8)}`);
  const rows = [['BASELINE', null, base]];
  for (const [name, layers] of scopes) {
    const m = matchShare(layers, actualCommons + 15, runs);
    rows.push([name, m.share, evaluate(runs, scopeTierOf(layers, m.share))]);
  }
  for (const [name, share, r] of rows) {
    const g = k => fmt(r.bands[k] ?? 0, 1).padStart(name === 'BASELINE' ? 8 : (k === 'refined' ? 9 : 8));
    console.log(`  ${name.padEnd(12)}${fmt(r.pieces,1).padStart(8)}${fmt(r.guExp,1).padStart(8)}${g('crude')}${g('plain')}${g('refined')}${g('prized')}`);
  }

  // ---- 3. SHORT-RUN GUARD candidates.
  console.log('\n[3] SHORT-RUN GUARD candidates (hypothetical; piece count must stay flat)');
  const guards = [
    ['G1 floor K=2', guardFloor(2)],
    ['G2 floor K=4 (pity)', guardFloor(4)],
    ['G3 window >=1', guardWindow(1)],
    ['G4 window >=2', guardWindow(2)],
  ];
  console.log(`  ${'guard'.padEnd(20)}${'f1zero_fix'.padStart(12)}${'inWindow'.padStart(10)}${'shortZero'.padStart(11)}${'pieces'.padStart(9)}${'elite'.padStart(8)}`);
  console.log(`  ${'BASELINE'.padEnd(20)}${(fmt(base.zeroResolved,2)+'/'+zeroRuns.length).padStart(12)}${fmt(base.inWindow,2).padStart(10)}${fmt(base.shortZero,2).padStart(11)}${fmt(base.pieces,1).padStart(9)}${fmt(base.elite,0).padStart(8)}`);
  for (const [name, f] of guards) {
    const r = evaluate(runs, f);
    console.log(`  ${name.padEnd(20)}${(fmt(r.zeroResolved,2)+'/'+zeroRuns.length).padStart(12)}${fmt(r.inWindow,2).padStart(10)}${fmt(r.shortZero,2).padStart(11)}${fmt(r.pieces,1).padStart(9)}${fmt(r.elite,0).padStart(8)}`);
  }

  // ---- 4. REFINEMENT TIMING candidates (no new nodes, no map change).
  console.log('\n[4] REFINEMENT TIMING candidates (redistribution only; count-preserving)');
  const timings = [
    ['T1 front-load all', timingFrontload()],
    ['T2 cluster pre-visit', timingClusterBeforeFirstVisit()],
  ];
  console.log(`  ${'timing'.padEnd(20)}${'f1zero_fix'.padStart(12)}${'inWindow'.padStart(10)}${'shortZero'.padStart(11)}${'pieces'.padStart(9)}${'elite'.padStart(8)}`);
  console.log(`  ${'BASELINE'.padEnd(20)}${(fmt(base.zeroResolved,2)+'/'+zeroRuns.length).padStart(12)}${fmt(base.inWindow,2).padStart(10)}${fmt(base.shortZero,2).padStart(11)}${fmt(base.pieces,1).padStart(9)}${fmt(base.elite,0).padStart(8)}`);
  for (const [name, f] of timings) {
    const r = evaluate(runs, f);
    console.log(`  ${name.padEnd(20)}${(fmt(r.zeroResolved,2)+'/'+zeroRuns.length).padStart(12)}${fmt(r.inWindow,2).padStart(10)}${fmt(r.shortZero,2).padStart(11)}${fmt(r.pieces,1).padStart(9)}${fmt(r.elite,0).padStart(8)}`);
  }

  console.log('\n[5] VALIDATION: corpus auto-detected; recommended target >= 32 runs (16 per school).');
  console.log(`    current = ${runs.length} runs (${runs.filter(r => r.school === 'force').length} force / ${runs.filter(r => r.school === 'sword').length} sword)`);
  console.log('\nA5 combined: NOT IMPLEMENTED (requires separate approval).');
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();

export { loadRuns, evaluate, scopeTierOf, matchShare, guardFloor, guardWindow, timingFrontload, timingClusterBeforeFirstVisit, FACTS, ELITE_COST, BANDS };
