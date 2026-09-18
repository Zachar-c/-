#!/usr/bin/env node
// Q8G Post-Fix Baseline / Agent-1 measurement tool.
// MEASUREMENT-ONLY. Reads the R5 audit corpus and data/*.json. Writes nothing
// into the game; never touches scripts/domain, data, presentation or tests.
//
// Extracts, per run:
//   entry node/layer, visited-node count, route refinement opportunities,
//   battle totals + tier/layer distribution, refinement visits,
//   f1/f2/f3/f4 school-material drops and remaining stock,
//   promotion funnel (visits -> gu_ready -> mat_ready -> full_ready -> attempts -> successes),
//   Gate B/C, common window (before first / after last refinement).
//
// Modes:
//   node tools/q8g_agent1_post_fix_baseline.mjs            -> aggregate + per-run table
//   node tools/q8g_agent1_post_fix_baseline.mjs <run>      -> per-battle trace, e.g. force/303
//   Q8G_R5_LOG_DIR=<dir> node ...                          -> point at another corpus

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TMP = process.env.TEMP || os.tmpdir();
const DIR = process.env.Q8G_R5_LOG_DIR || path.join(TMP, 'gu-zhenrens-r5-logs');

const SEEDS = ['20260927', '11', '33', '55', '101', '202', '303', '404',
  '505', '606', '707', '808', '909', '1111', '1212', '1313'];
const SCHOOLS = ['force', 'sword'];
const BANDS = [1, 2, 3, 4];

function num(re, text, dflt = null) {
  const m = text.match(re);
  return m ? Number(m[1]) : dflt;
}

function parseRun(text, school) {
  const r = { school, visited: [], battles: null, by_layer: {}, by_tier: {} };

  for (const m of text.matchAll(/^\[play\] 行至 (L(\d+)R\d+N\d+) \(([a-z_]+)\)/gm)) {
    r.visited.push({ id: m[1], layer: Number(m[2]), type: m[3] });
  }
  r.entry = r.visited[0] ? r.visited[0].id : null;
  r.entry_layer = r.visited[0] ? r.visited[0].layer : null;
  r.visited_count = r.visited.length;
  r.route_refinement_nodes = r.visited.filter((v) => v.type === 'refinement').length;
  r.route_combat_nodes = r.visited.filter((v) => v.type === 'combat' || v.type === 'pursuit').length;

  r.funnel = {
    visits: num(/R-4 漏斗: 探访 (\d+)/, text),
    gu_ready: num(/R-4 漏斗: 探访 \d+ \| gu_ready (\d+)/, text),
    mat_ready: num(/R-4 漏斗: 探访 \d+ \| gu_ready \d+ \| mat_ready (\d+)/, text),
    full_ready: num(/全条件就绪 (\d+)/, text),
    attempts: num(/尝试 (\d+) \/ 成功/, text),
    successes: num(/尝试 \d+ \/ 成功 (\d+)/, text),
  };
  r.opportunity_to_visit = (text.match(/机会→探访转换 (\d+)\/(\d+)/) || []).slice(1).map(Number);
  r.materials_gained = num(/材料掉落合计 (\d+) 件/, text, 0);
  r.bands = {};
  for (const m of text.matchAll(/掉落 mat_\w+_(\d) ×(\d+) \| 剩余 ×(\d+)/g)) {
    r.bands[Number(m[1])] = { gained: Number(m[2]), left: Number(m[3]) };
  }
  r.highest_rank = num(/持有蛊最高 rank: (\d+)/, text, 0);
  r.promotions = num(/promotion 完成: (\d+) 次/, text, 0);
  r.retreats = (text.match(/止损撤离/g) || []).length;

  const s = text.match(/^\[play\] R-5 summary: (.+)$/m);
  r.has_summary = Boolean(s);
  if (!s) return r;
  const line = s[1];
  r.battles = num(/battles=(\d+)/, line);
  r.f1_count = num(/f1_count=(\d+)/, line);
  r.f1_zero = /f1_zero=yes/.test(line);
  r.common_before = num(/common_before_first_refinement=(\d+)/, line);
  r.common_after = num(/common_after_last_refinement=(\d+)/, line);
  r.visit_marks = (line.match(/visit_marks=\[([^\]]*)\]/) || [, ''])[1]
    .split(',').map((x) => Number(x.trim())).filter((x) => Number.isFinite(x) && x > 0);
  r.common_indices = (line.match(/common_indices=\[([^\]]*)\]/) || [, ''])[1]
    .split(',').map((x) => Number(x.trim())).filter((x) => Number.isFinite(x) && x > 0);
  r.gate_b = /gate_b=PASS/.test(line);
  r.gate_c = /gate_c=PASS/.test(line);
  const bl = line.match(/by_layer=\{([^}]*)\}/);
  if (bl) for (const m of bl[1].matchAll(/(\d+):\s*(\d+)/g)) r.by_layer[Number(m[1])] = Number(m[2]);
  const bt = line.match(/by_tier=\{([^}]*)\}/);
  if (bt) for (const m of bt[1].matchAll(/"(\w+)":\s*(\d+)/g)) r.by_tier[m[1]] = Number(m[2]);
  return r;
}

function loadAll() {
  const runs = {};
  for (const school of SCHOOLS) {
    for (const seed of SEEDS) {
      const p = path.join(DIR, `${school}_${seed}.log`);
      if (!fs.existsSync(p)) { runs[`${school}/${seed}`] = null; continue; }
      runs[`${school}/${seed}`] = parseRun(fs.readFileSync(p, 'utf8'), school);
    }
  }
  return runs;
}

// ---------------------------------------------------------------- per-battle
function battleTrace(key) {
  const p = path.join(DIR, key.replace('/', '_') + '.log');
  if (!fs.existsSync(p)) { console.error(`missing ${p}`); process.exit(1); }
  const text = fs.readFileSync(p, 'utf8');
  const run = parseRun(text, key.split('/')[0]);
  const rows = [];
  for (const m of text.matchAll(/^\[play\] R-5 battle: (.+)$/gm)) {
    const l = m[1];
    const g = (k) => (l.match(new RegExp(`${k}=([^ ]+)`)) || [, ''])[1];
    rows.push({
      idx: Number(g('idx')), outcome: g('outcome'), node: g('node'),
      tmpl: g('tmpl_kind'), kind: g('battle_kind'), tier: g('tier'),
      grade: g('grade'), rank: g('rank'), layer: g('layer'),
      rankMin: g('rank_min'), rankMax: g('rank_max'),
      mats: g('mats'), f1: Number(g('f1_hit')),
    });
  }
  console.log(`===== per-battle trace: ${key} =====`);
  console.log(`entry=${run.entry} visited=${run.visited_count} battles=${run.battles} `
    + `route_refinement_nodes=${run.route_refinement_nodes} refinement_visits=${run.funnel.visits}`);
  console.log(`visit_marks=${JSON.stringify(run.visit_marks)} common_indices=${JSON.stringify(run.common_indices)}`);
  console.log(`f1_count=${run.f1_count} bands=${JSON.stringify(run.bands)} promotions=${run.promotions} highest_rank=${run.highest_rank}`);
  console.log(`funnel=${JSON.stringify(run.funnel)} gate_b=${run.gate_b} gate_c=${run.gate_c}`);
  console.log('');
  console.log('idx  outcome    node       tmpl_kind                   actual_kind                 tier       layer rank  rankWin mats');
  for (const b of rows) {
    console.log([
      String(b.idx).padEnd(4), b.outcome.padEnd(10), b.node.padEnd(10),
      b.tmpl.padEnd(27), b.kind.padEnd(27), b.tier.padEnd(10),
      String(b.layer).padEnd(5), String(b.rank).padEnd(5),
      `${b.rankMin}-${b.rankMax}`.padEnd(7), b.mats,
    ].join(' '));
  }
  const visits = new Set(run.visit_marks);
  console.log('');
  console.log(`common battles: ${run.common_indices.length} at indices ${JSON.stringify(run.common_indices)}`);
  console.log(`first refinement visit at battle #${run.visit_marks[0] ?? 'n/a'}, last at #${run.visit_marks[run.visit_marks.length - 1] ?? 'n/a'}`);
  console.log(`common before first visit = ${run.common_before}, after last visit = ${run.common_after}`);
  console.log(`(refinement visit marks: ${[...visits].sort((a, b) => a - b).join(', ') || 'none'})`);
  return;
}

// ---------------------------------------------------------------- aggregate
// ---------------------------------------------------------------- layer share
// S1-alpha input: per-layer settled tier composition (victories only), so the
// Common share of each layer can be compared against the pre-fix baseline.
function layerShare() {
  const byLayer = {};
  for (const school of SCHOOLS) {
    for (const seed of SEEDS) {
      const p = path.join(DIR, `${school}_${seed}.log`);
      if (!fs.existsSync(p)) continue;
      for (const m of fs.readFileSync(p, 'utf8').matchAll(/^\[play\] R-5 battle: (.+)$/gm)) {
        const l = m[1];
        const g = (k) => (l.match(new RegExp(`${k}=([^ ]+)`)) || [, ''])[1];
        if (g('outcome') !== 'victory') continue;
        const layer = Number(g('layer'));
        const tier = g('tier');
        if (!Number.isFinite(layer)) continue;
        byLayer[layer] ??= { common: 0, elite: 0, boss: 0 };
        byLayer[layer][tier] = (byLayer[layer][tier] ?? 0) + 1;
      }
    }
  }
  console.log(`\n----- settled victories by layer (corpus = ${DIR}) -----`);
  console.log('layer  common  elite  boss   settled   common-share');
  for (const L of Object.keys(byLayer).map(Number).sort((a, b) => a - b)) {
    const v = byLayer[L];
    const settled = v.common + v.elite + v.boss;
    console.log([
      `L${L}`.padEnd(6), String(v.common).padEnd(7), String(v.elite).padEnd(6),
      String(v.boss).padEnd(5), String(settled).padEnd(9),
      `${((100 * v.common) / settled).toFixed(1)}%`,
    ].join(' '));
  }
  const tot = Object.values(byLayer).reduce((a, v) => {
    a.common += v.common; a.elite += v.elite; a.boss += v.boss; return a;
  }, { common: 0, elite: 0, boss: 0 });
  const settled = tot.common + tot.elite + tot.boss;
  console.log([
    'ALL'.padEnd(6), String(tot.common).padEnd(7), String(tot.elite).padEnd(6),
    String(tot.boss).padEnd(5), String(settled).padEnd(9),
    `${((100 * tot.common) / settled).toFixed(1)}%`,
  ].join(' '));
}

const arg = process.argv[2];
if (arg === '--layers') { layerShare(); process.exit(0); }
if (arg) { battleTrace(arg); process.exit(0); }

const runs = loadAll();
const keys = Object.keys(runs).filter((k) => runs[k] && runs[k].has_summary);
if (!keys.length) { console.error(`no logs in ${DIR}`); process.exit(1); }

const sum = (f) => keys.reduce((a, k) => a + (f(runs[k]) ?? 0), 0);
const agg = {
  runs: keys.length,
  entry_layers: {}, battles_total: 0, tier: {}, layer: {}, short: 0,
  refinement_visits: 0, route_refinement_nodes: 0, route_combat_nodes: 0, visited_total: 0,
  f1_zero: 0, f1_count: 0, bands: {},
  mat_ready: 0, full_ready: 0, gu_ready: 0, attempts: 0, successes: 0,
  common_before: 0, common_after: 0, common_total: 0, elite_total: 0, boss_total: 0,
  gate_b: 0, gate_c: 0, promotions: 0, highest_rank_max: 0, materials_gained: 0,
  common_scarce: 0, common_scarce_at_threshold: 0, retreats: 0,
};
for (const b of BANDS) agg.bands[b] = { gained: 0, left: 0 };
for (const k of keys) {
  const r = runs[k];
  agg.entry_layers[r.entry_layer] = (agg.entry_layers[r.entry_layer] || 0) + 1;
  agg.battles_total += r.battles;
  if (r.battles < 15) agg.short += 1;
  for (const [t, n] of Object.entries(r.by_tier)) agg.tier[t] = (agg.tier[t] || 0) + n;
  for (const [L, n] of Object.entries(r.by_layer)) agg.layer[L] = (agg.layer[L] || 0) + n;
  agg.refinement_visits += r.funnel.visits;
  agg.route_refinement_nodes += r.route_refinement_nodes;
  agg.route_combat_nodes += r.route_combat_nodes;
  agg.visited_total += r.visited_count;
  agg.f1_count += r.f1_count;
  if (r.f1_zero) agg.f1_zero += 1;
  for (const b of BANDS) {
    agg.bands[b].gained += r.bands[b]?.gained ?? 0;
    agg.bands[b].left += r.bands[b]?.left ?? 0;
  }
  agg.gu_ready += r.funnel.gu_ready; agg.mat_ready += r.funnel.mat_ready;
  agg.full_ready += r.funnel.full_ready; agg.attempts += r.funnel.attempts;
  agg.successes += r.funnel.successes;
  agg.common_before += r.common_before; agg.common_after += r.common_after;
  agg.common_total += r.by_tier.common ?? 0;
  agg.elite_total += r.by_tier.elite ?? 0;
  agg.boss_total += r.by_tier.boss ?? 0;
  if (r.gate_b) agg.gate_b += 1;
  if (r.gate_c) agg.gate_c += 1;
  agg.promotions += r.promotions;
  agg.highest_rank_max = Math.max(agg.highest_rank_max, r.highest_rank);
  agg.materials_gained += r.materials_gained;
  agg.retreats += r.retreats;
  const commons = r.by_tier.common ?? 0;
  if (commons < 3) agg.common_scarce += 1;          // below pity threshold
  if (commons < 3 && r.f1_count === 0) agg.common_scarce_at_threshold += 1;
}

console.log(`===== Q8G post-fix baseline =====`);
console.log(`corpus = ${DIR}  runs = ${agg.runs}\n`);
console.log('----- per run -----');
console.log('run'.padEnd(15), 'entry'.padEnd(8), 'vis'.padEnd(4), 'batt'.padEnd(5),
  'com'.padEnd(4), 'eli'.padEnd(4), 'bos'.padEnd(4), 'unset'.padEnd(6),
  'refVisit'.padEnd(9), 'f1'.padEnd(3), 'f2'.padEnd(3), 'f3'.padEnd(3), 'f4'.padEnd(3),
  'matRdy'.padEnd(7), 'att/suc'.padEnd(8), 'B', 'C');
for (const k of keys) {
  const r = runs[k];
  console.log([
    k.padEnd(15), String(r.entry).padEnd(8), String(r.visited_count).padEnd(4),
    String(r.battles).padEnd(5), String(r.by_tier.common ?? 0).padEnd(4),
    String(r.by_tier.elite ?? 0).padEnd(4), String(r.by_tier.boss ?? 0).padEnd(4),
    String(r.by_tier.unsettled ?? 0).padEnd(6), String(r.funnel.visits).padEnd(9),
    String(r.bands[1]?.gained ?? 0).padEnd(3), String(r.bands[2]?.gained ?? 0).padEnd(3),
    String(r.bands[3]?.gained ?? 0).padEnd(3), String(r.bands[4]?.gained ?? 0).padEnd(3),
    String(r.funnel.mat_ready).padEnd(7),
    `${r.funnel.attempts}/${r.funnel.successes}`.padEnd(8),
    r.gate_b ? 'P' : '.', r.gate_c ? 'P' : '.',
  ].join(' '));
}

console.log('\n----- aggregate -----');
const lines = [
  ['entry layer histogram', JSON.stringify(agg.entry_layers)],
  ['visited nodes total / per run', `${agg.visited_total} / ${(agg.visited_total / agg.runs).toFixed(1)}`],
  ['route refinement nodes total', agg.route_refinement_nodes],
  ['route combat nodes total', agg.route_combat_nodes],
  ['battles total / per run', `${agg.battles_total} / ${(agg.battles_total / agg.runs).toFixed(1)}`],
  ['short runs (<15)', agg.short],
  ['battles by layer', JSON.stringify(agg.layer)],
  ['battles by tier', JSON.stringify(agg.tier)],
  ['refinement visits', agg.refinement_visits],
  ['f1 / f2 / f3 / f4 drops', BANDS.map((b) => agg.bands[b].gained).join(' / ')],
  ['f1 / f2 / f3 / f4 left', BANDS.map((b) => agg.bands[b].left).join(' / ')],
  ['f1_count total', agg.f1_count],
  ['f1_zero runs', agg.f1_zero],
  ['common runs with <3 Common (below pity)', agg.common_scarce],
  ['  ... and f1_count==0', agg.common_scarce_at_threshold],
  ['common before first refinement', agg.common_before],
  ['common after last refinement', agg.common_after],
  ['funnel visits / gu_ready / mat_ready / full_ready', `${agg.refinement_visits} / ${agg.gu_ready} / ${agg.mat_ready} / ${agg.full_ready}`],
  ['attempts / successes', `${agg.attempts} / ${agg.successes}`],
  ['promotions total', agg.promotions],
  ['highest rank ever reached', agg.highest_rank_max],
  ['gate_b / gate_c PASS runs', `${agg.gate_b} / ${agg.gate_c}`],
  ['materials gained total', agg.materials_gained],
  ['retreats total', agg.retreats],
];
for (const [m, v] of lines) console.log(String(m).padEnd(48), String(v));
