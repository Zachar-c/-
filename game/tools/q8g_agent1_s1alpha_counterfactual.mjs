#!/usr/bin/env node
// Agent-1 addendum: MODEL-FREE per-run counterfactual for the S1-alpha question.
//
// Why this exists: the R7/R7B tools answer "restore L4/L5 Common coverage" with a
// Monte-Carlo model whose per-run table only covered the L5-only scope. The
// aggregate rows for L4+L5 could not be checked per run. This tool does the
// counterfactual DETERMINISTICALLY, straight off the observed battle sequence:
//
//   convert every L4/L5 elite *victory* into a Common victory, then ask whether
//   the run's Common count reaches the pity repair threshold (threshold + 1 = 4).
//
// Pity semantics (production, per-tier counter, threshold 3):
//   worst case is "every Common victory misses the natural roll"; then after 3
//   misses the 4th Common victory forces an f1. Therefore
//       N >= threshold + 1   =>   f1 > 0 is GUARANTEED, whatever the natural rate.
//   This makes the repair test independent of any natural-rate assumption.
//
// Also reports the deterministic cost: how many elite victories get converted
// (each conversion also moves a battle from the elite band to the crude band and
// from gu 0.30 to gu 0.06 - that side effect is NOT modelled here, only counted).
//
// MEASUREMENT-ONLY. Reads the corpus, writes nothing into the game.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TMP = process.env.TEMP || os.tmpdir();
const DIR = process.env.Q8G_R5_LOG_DIR || path.join(TMP, 'gu-zhenrens-r5-logs');
const THRESHOLD = 3;                 // data/loot_tables.json pity.material_pity.threshold
const REPAIR_COMMONS = THRESHOLD + 1; // pity guarantees a hit on this Common victory

const SEEDS = ['20260927', '11', '33', '55', '101', '202', '303', '404',
  '505', '606', '707', '808', '909', '1111', '1212', '1313'];
const SCHOOLS = ['force', 'sword'];

function loadRun(file) {
  const text = fs.readFileSync(file, 'utf8');
  const battles = [];
  for (const m of text.matchAll(/^\[play\] R-5 battle: (.+)$/gm)) {
    const l = m[1];
    const g = (k) => (l.match(new RegExp(`${k}=([^ ]+)`)) || [, ''])[1];
    battles.push({
      idx: Number(g('idx')), outcome: g('outcome'),
      tier: g('tier'), layer: Number(g('layer')), f1: Number(g('f1_hit')),
    });
  }
  const s = text.match(/^\[play\] R-5 summary: (.+)$/m);
  if (!s) return null;
  const marks = (s[1].match(/visit_marks=\[([^\]]*)\]/) || [, ''])[1]
    .split(',').map((x) => Number(x.trim())).filter((x) => Number.isFinite(x) && x > 0);
  return {
    battles,
    visits: marks,
    lastVisit: marks.length ? Math.max(...marks) : 0,
    f1Count: Number((s[1].match(/f1_count=(\d+)/) || [])[1] ?? 0),
  };
}

// Deterministic pity simulation over an ordered list of Common-victory flags.
// Returns the index (1-based position among Common victories) of the forced hit,
// or -1 if the pity never fires. Natural hits reset the counter (they only help),
// so we simulate the WORST case: assume no natural hit ever happens.
function pityForcedAt(commonVictoryIndices) {
  let counter = 0;
  for (let i = 0; i < commonVictoryIndices.length; i++) {
    counter += 1;
    if (counter >= REPAIR_COMMONS) return i + 1; // this Common victory forces an f1
  }
  return -1;
}

const variants = [
  { name: 'actual',       pick: () => false },
  { name: 'S1a L5-only',  pick: (b) => b.layer === 5 },
  { name: 'S1a L4+L5',    pick: (b) => b.layer === 4 || b.layer === 5 },
];

const rows = [];
const agg = {};
for (const v of variants) agg[v.name] = { repaired: 0, repairedInWindow: 0, converted: 0, runsTouched: 0 };

for (const school of SCHOOLS) {
  for (const seed of SEEDS) {
    const file = path.join(DIR, `${school}_${seed}.log`);
    if (!fs.existsSync(file)) continue;
    const run = loadRun(file);
    if (!run) continue;
    const key = `${school}/${seed}`;

    const row = { key, f1zero: run.f1Count === 0, lastVisit: run.lastVisit, detail: {} };
    for (const v of variants) {
      const commons = [];
      let converted = 0;
      for (const b of run.battles) {
        const isCommon = b.outcome === 'victory' && b.tier === 'common';
        const isElite = b.outcome === 'victory' && b.tier === 'elite';
        if (isCommon) { commons.push(b.idx); continue; }
        if (isElite && v.pick(b)) { commons.push(b.idx); converted += 1; }
      }
      const forcedAt = pityForcedAt(commons);
      // Timing: the forced f1 must be able to reach a refinement visit to be
      // convertible. Use the battle index of the forcing Common victory.
      const forcedIdx = forcedAt > 0 ? commons[forcedAt - 1] : -1;
      const inWindow = forcedIdx > 0 && forcedIdx <= run.lastVisit;
      row.detail[v.name] = { commons: commons.length, converted, forcedAt, forcedIdx, inWindow };
      if (v.name !== 'actual') {
        agg[v.name].converted += converted;
        if (converted > 0) agg[v.name].runsTouched += 1;
      }
      // "repaired" = the run ends with f1 > 0 under this variant
      const repaired = run.f1Count > 0 || forcedAt > 0;
      if (v.name !== 'actual' && repaired && run.f1Count === 0) agg[v.name].repaired += 1;
      if (v.name !== 'actual' && repaired && run.f1Count === 0 && inWindow) agg[v.name].repairedInWindow += 1;
    }
    rows.push(row);
  }
}

console.log('===== S1-alpha deterministic per-run counterfactual =====');
console.log(`corpus = ${DIR}`);
console.log(`pity: threshold ${THRESHOLD} -> ${REPAIR_COMMONS} Common victories guarantee an f1`);
console.log('repair test is MODEL-FREE: it assumes the worst case (no natural hit ever)\n');

console.log('--- the two f1=0 runs ---');
for (const r of rows.filter((x) => x.f1zero)) {
  console.log(`${r.key}  last refinement visit = battle #${r.lastVisit}`);
  for (const v of variants) {
    const d = r.detail[v.name];
    const verdict = d.forcedAt > 0 ? `REPAIRED (pity fires on Common #${d.forcedAt}, battle #${d.forcedIdx}`
      + `${d.inWindow ? ', before last visit' : ', AFTER last visit -> not convertible'})` : 'NOT repaired';
    console.log(`   ${v.name.padEnd(14)} commons=${String(d.commons).padEnd(3)}`
      + ` convertedElite=${String(d.converted).padEnd(3)} -> ${verdict}`);
  }
}

console.log('\n--- all runs: what each variant changes ---');
console.log('variant'.padEnd(16), 'f1zeroRepaired'.padEnd(16), 'repairedInWindow'.padEnd(17),
  'eliteConverted'.padEnd(15), 'runsTouched');
for (const v of variants) {
  const a = agg[v.name];
  console.log([
    v.name.padEnd(16), String(a.repaired).padEnd(16), String(a.repairedInWindow).padEnd(17),
    String(a.converted).padEnd(15), String(a.runsTouched),
  ].join(' '));
}

const actualElite = rows.reduce((acc, r) => acc + (r.detail.actual ? 0 : 0), 0);
console.log('\n--- per-run detail (only runs where a variant converts something) ---');
console.log('run'.padEnd(16), 'f1=0'.padEnd(6), 'lastVisit'.padEnd(10),
  'L5->cmn'.padEnd(9), 'L4L5->cmn');
for (const r of rows) {
  const a = r.detail['S1a L5-only'], b = r.detail['S1a L4+L5'];
  if (a.converted === 0 && b.converted === 0) continue;
  console.log([
    r.key.padEnd(16), String(r.f1zero ? 'YES' : '').padEnd(6), String(r.lastVisit).padEnd(10),
    String(a.converted).padEnd(9), String(b.converted),
  ].join(' '));
}

console.log('\n----- interpretation -----');
console.log('The repair test does not depend on the natural f1 rate: N >= 4 Commons');
console.log('guarantees a pity hit in the worst case. So "repaired" above is exact for');
console.log('the coverage-restoration counterfactual, given that L4/L5 elite victories');
console.log('really would become Common victories.');
console.log('NOT modelled: band change (elite plain/refined -> common crude), gu chance');
console.log('(0.30 -> 0.06), stone reward, and whether the player would still take the');
console.log('same route. Only the elite->common COUNT is exact.');
