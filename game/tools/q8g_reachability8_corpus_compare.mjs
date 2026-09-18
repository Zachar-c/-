#!/usr/bin/env node
// R8 / B1 start-leak fix: PRE vs POST corpus comparison.
//
// Reads the preserved pre-fix corpus and the rebuilt post-fix corpus, and
// reports the population changes the handoff asks for:
//   entry layer, route length, battle counts, retreat distribution,
//   f1 / promotion funnel, per-layer battle spread.
//
// Usage: node tools/q8g_reachability8_corpus_compare.mjs
//   PRE  = %TEMP%/gu-zhenrens-r5-logs-PRE_START_FIX
//   POST = %TEMP%/gu-zhenrens-r5-logs

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TMP = process.env.TEMP || os.tmpdir();
const PRE_DIR = path.join(TMP, 'gu-zhenrens-r5-logs-PRE_START_FIX');
const POST_DIR = path.join(TMP, 'gu-zhenrens-r5-logs');

const SEEDS = ['20260927', '11', '33', '55', '101', '202', '303', '404',
  '505', '606', '707', '808', '909', '1111', '1212', '1313'];
const SCHOOLS = ['force', 'sword'];

function parseRun(text) {
  const r = {
    first_node: null, entry_layer: null,
    battles: null, by_layer: {}, by_tier: {},
    common_before_first_refinement: null, common_after_last_refinement: null,
    refinement_visits: 0, retreats: 0, visits: null,
    f1_count: null, f1_zero: null, mat_ready: null, full_ready: null,
    attempts: null, successes: null, gate_b: null, gate_c: null,
    has_summary: false,
  };
  const first = text.match(/^\[play\] 行至 (L(\d+)R\d+N\d+) /m);
  if (first) { r.first_node = first[1]; r.entry_layer = Number(first[2]); }

  r.refinement_visits = (text.match(/^\[play\] 行至 L\d+R\d+N\d+ \(refinement\)/gm) || []).length;
  r.retreats = (text.match(/止损撤离/g) || []).length;

  const s = text.match(/^\[play\] R-5 summary: (.+)$/m);
  if (!s) return r;
  r.has_summary = true;
  const line = s[1];
  const num = (k) => { const m = line.match(new RegExp(`${k}=(-?\\d+)`)); return m ? Number(m[1]) : null; };
  r.battles = num('battles');
  r.common_before_first_refinement = num('common_before_first_refinement');
  r.common_after_last_refinement = num('common_after_last_refinement');
  r.visits = num('visits');
  r.f1_count = num('f1_count');
  r.mat_ready = num('mat_ready');
  r.full_ready = num('full_ready');
  r.attempts = num('attempts');
  r.successes = num('successes');
  const fz = line.match(/f1_zero=(\w+)/); r.f1_zero = fz ? fz[1] : null;
  const gb = line.match(/gate_b=(\w+)/); r.gate_b = gb ? gb[1] : null;
  const gc = line.match(/gate_c=(\w+)/); r.gate_c = gc ? gc[1] : null;

  const bl = line.match(/by_layer=\{([^}]*)\}/);
  if (bl) for (const m of bl[1].matchAll(/(\d+):\s*(\d+)/g)) r.by_layer[Number(m[1])] = Number(m[2]);
  const bt = line.match(/by_tier=\{([^}]*)\}/);
  if (bt) for (const m of bt[1].matchAll(/"(\w+)":\s*(\d+)/g)) r.by_tier[m[1]] = Number(m[2]);
  return r;
}

function load(dir) {
  const runs = {};
  for (const school of SCHOOLS) {
    for (const seed of SEEDS) {
      const p = path.join(dir, `${school}_${seed}.log`);
      const key = `${school}/${seed}`;
      if (!fs.existsSync(p)) { runs[key] = null; continue; }
      runs[key] = parseRun(fs.readFileSync(p, 'utf8'));
    }
  }
  return runs;
}

function agg(runs) {
  const keys = Object.keys(runs).filter((k) => runs[k] && runs[k].has_summary);
  const sum = (f) => keys.reduce((a, k) => a + (f(runs[k]) ?? 0), 0);
  const entryLayers = {};
  const layerBattles = {};
  const tiers = {};
  for (const k of keys) {
    const r = runs[k];
    const el = r.entry_layer ?? 0;
    entryLayers[el] = (entryLayers[el] || 0) + 1;
    for (const [L, n] of Object.entries(r.by_layer)) layerBattles[L] = (layerBattles[L] || 0) + n;
    for (const [t, n] of Object.entries(r.by_tier)) tiers[t] = (tiers[t] || 0) + n;
  }
  const battles = keys.map((k) => runs[k].battles);
  const sorted = [...battles].sort((a, b) => a - b);
  return {
    runs: keys.length,
    entryLayers,
    nonL1: keys.filter((k) => (runs[k].entry_layer ?? 1) !== 1).length,
    battles_total: sum((r) => r.battles),
    battles_min: sorted[0], battles_median: sorted[Math.floor(sorted.length / 2)], battles_max: sorted[sorted.length - 1],
    short_runs: battles.filter((b) => b < 15).length,
    layerBattles, tiers,
    retreats_total: sum((r) => r.retreats),
    refinement_visits: sum((r) => r.refinement_visits),
    f1_zero: keys.filter((k) => runs[k].f1_zero === 'yes').length,
    f1_count: sum((r) => r.f1_count),
    mat_ready: sum((r) => r.mat_ready), full_ready: sum((r) => r.full_ready),
    attempts: sum((r) => r.attempts), successes: sum((r) => r.successes),
    common_before: sum((r) => r.common_before_first_refinement),
    common_after: sum((r) => r.common_after_last_refinement),
    gate_b_pass: keys.filter((k) => runs[k].gate_b === 'PASS').length,
    gate_c_pass: keys.filter((k) => runs[k].gate_c === 'PASS').length,
  };
}

const pre = load(PRE_DIR);
const post = load(POST_DIR);
const aPre = agg(pre);
const aPost = agg(post);

console.log('===== R8 / B1 start-leak fix: PRE vs POST corpus =====');
console.log(`PRE  dir = ${PRE_DIR}`);
console.log(`POST dir = ${POST_DIR}\n`);

console.log('----- per-run -----');
console.log('run'.padEnd(16), 'PRE entry/battles/retr'.padEnd(24), 'POST entry/battles/retr');
for (const school of SCHOOLS) {
  for (const seed of SEEDS) {
    const k = `${school}/${seed}`;
    const p = pre[k], q = post[k];
    const fmt = (r) => r ? `L${r.entry_layer} / ${r.battles} / ${r.retreats}` : 'MISSING';
    console.log(k.padEnd(16), fmt(p).padEnd(24), fmt(q));
  }
}

const rows = [
  ['runs', aPre.runs, aPost.runs],
  ['non-L1 entry runs', aPre.nonL1, aPost.nonL1],
  ['entry layer histogram', JSON.stringify(aPre.entryLayers), JSON.stringify(aPost.entryLayers)],
  ['battles total', aPre.battles_total, aPost.battles_total],
  ['battles min/med/max', `${aPre.battles_min}/${aPre.battles_median}/${aPre.battles_max}`, `${aPost.battles_min}/${aPost.battles_median}/${aPost.battles_max}`],
  ['short runs (<15 battles)', aPre.short_runs, aPost.short_runs],
  ['battles by layer', JSON.stringify(aPre.layerBattles), JSON.stringify(aPost.layerBattles)],
  ['battles by tier', JSON.stringify(aPre.tiers), JSON.stringify(aPost.tiers)],
  ['retreats total', aPre.retreats_total, aPost.retreats_total],
  ['refinement visits', aPre.refinement_visits, aPost.refinement_visits],
  ['f1_zero runs', aPre.f1_zero, aPost.f1_zero],
  ['f1_count total', aPre.f1_count, aPost.f1_count],
  ['mat_ready / full_ready', `${aPre.mat_ready} / ${aPre.full_ready}`, `${aPost.mat_ready} / ${aPost.full_ready}`],
  ['attempts / successes', `${aPre.attempts} / ${aPre.successes}`, `${aPost.attempts} / ${aPost.successes}`],
  ['common before first refinement', aPre.common_before, aPost.common_before],
  ['common after last refinement', aPre.common_after, aPost.common_after],
  ['gate_b PASS runs', aPre.gate_b_pass, aPost.gate_b_pass],
  ['gate_c PASS runs', aPre.gate_c_pass, aPost.gate_c_pass],
];

console.log('\n----- aggregate -----');
console.log('metric'.padEnd(32), 'PRE'.padEnd(30), 'POST');
for (const [m, p, q] of rows) console.log(String(m).padEnd(32), String(p).padEnd(30), String(q));
