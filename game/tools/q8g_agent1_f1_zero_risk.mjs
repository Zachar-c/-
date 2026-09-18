#!/usr/bin/env node
// Agent-1 addendum: is the residual f1=0 population structural or variance?
// MEASUREMENT-ONLY, statistics over the existing corpus. No Godot, no writes
// into the game, no production file touched.
//
// Model (matches the production semantics used by the R7 tools):
//   - pity counter is per-tier; common counter advances on each Common victory
//     that did NOT deliver a legal f1; threshold = 3, so the 4th Common victory
//     forces an f1 (given a legal candidate exists).
//   - hence P(f1 = 0 | N Common victories) = (1-q)^N for N <= 3, and 0 for N >= 4,
//     where q = P(at least one f1 drop | one Common victory).
// q is estimated from the corpus itself; Wilson 95% CI is reported.
//
// Output answers: "how many f1=0 runs should we EXPECT given the observed q and
// the observed Common-count distribution, and is the observed count surprising?"

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TMP = process.env.TEMP || os.tmpdir();
const DIR = process.env.Q8G_R5_LOG_DIR || path.join(TMP, 'gu-zhenrens-r5-logs');
const THRESHOLD = 3; // data/loot_tables.json pity.material_pity.threshold

const SEEDS = ['20260927', '11', '33', '55', '101', '202', '303', '404',
  '505', '606', '707', '808', '909', '1111', '1212', '1313'];
const SCHOOLS = ['force', 'sword'];

function wilson(k, n, z = 1.959964) {
  if (n === 0) return [0, 0];
  const p = k / n, d = 1 + (z * z) / n;
  const c = p + (z * z) / (2 * n);
  const s = z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n));
  return [(c - s) / d, (c + s) / d];
}

const runs = [];
for (const school of SCHOOLS) {
  for (const seed of SEEDS) {
    const p = path.join(DIR, `${school}_${seed}.log`);
    if (!fs.existsSync(p)) continue;
    const text = fs.readFileSync(p, 'utf8');
    const s = text.match(/^\[play\] R-5 summary: (.+)$/m);
    if (!s) continue;
    const line = s[1];
    const g = (re) => Number((line.match(re) || [])[1] ?? 0);
    const common = g(/"common":\s*(\d+)/);
    const f1 = g(/f1_count=(\d+)/);
    // draws = material pieces dropped on Common victories (2..4 each)
    let draws = 0, f1Draws = 0, commonHits = 0, commonBattles = 0;
    for (const m of text.matchAll(/^\[play\] R-5 battle: (.+)$/gm)) {
      const l = m[1];
      if (!/outcome=victory/.test(l) || !/tier=common/.test(l)) continue;
      const mats = (l.match(/mats=\[([^\]]*)\]/) || [, ''])[1];
      const ids = mats.split(',').map((x) => x.trim().replace(/"/g, '')).filter(Boolean);
      const hit = Number((l.match(/f1_hit=(\d+)/) || [])[1] ?? 0);
      draws += ids.length;
      f1Draws += hit;
      commonBattles += 1;
      if (hit > 0) commonHits += 1;
    }
    runs.push({ key: `${school}/${seed}`, common, f1, draws, f1Draws, commonHits, commonBattles, f1zero: f1 === 0 });
  }
}

const totalRuns = runs.length;
const withCommon = runs.filter((r) => r.common > 0);
const sumCommon = withCommon.reduce((a, r) => a + r.common, 0);
const totalDraws = runs.reduce((a, r) => a + r.draws, 0);
const totalF1Draws = runs.reduce((a, r) => a + r.f1Draws, 0);
const drawsPerCommon = totalDraws / sumCommon;

// q = P(at least one f1 drop | one Common victory), estimated directly from the
// per-Common-victory f1_hit outcomes (this is the quantity the pity model needs).
const commonBattles = runs.reduce((a, r) => a + r.commonBattles, 0);
const commonHits = runs.reduce((a, r) => a + r.commonHits, 0);

console.log(`===== residual f1=0: structural or variance? =====`);
console.log(`corpus = ${DIR}`);
console.log(`runs = ${totalRuns} | runs with a Common victory = ${withCommon.length}`);
console.log(`Common victories total = ${sumCommon} | material draws on Common victories = ${totalDraws}`
  + ` (${drawsPerCommon.toFixed(2)} per victory)`);
console.log(`f1 material draws = ${totalF1Draws}  ->  per-draw rate = ${(totalF1Draws / totalDraws).toFixed(4)}`);
console.log(`Common victories that delivered >=1 f1 = ${commonHits} / ${commonBattles}`
  + `  ->  per-Common-victory rate q = ${(commonHits / commonBattles).toFixed(4)}`);

const q = commonHits / commonBattles;
const [qLo, qHi] = wilson(commonHits, commonBattles);
console.log(`Wilson 95% CI for q = [${qLo.toFixed(4)}, ${qHi.toFixed(4)}]\n`);

// Common-count histogram
const hist = {};
for (const r of withCommon) hist[r.common] = (hist[r.common] || 0) + 1;

console.log('Common-count histogram (runs with >=1 Common):');
for (const n of Object.keys(hist).map(Number).sort((a, b) => a - b)) {
  console.log(`  N=${String(n).padEnd(3)} runs=${String(hist[n]).padEnd(3)}`);
}

function expectedZero(qq) {
  let e = 0;
  for (const n of Object.keys(hist).map(Number)) {
    const pZero = n >= THRESHOLD + 1 ? 0 : Math.pow(1 - qq, n);
    e += hist[n] * pZero;
  }
  return e;
}

console.log(`\nModel: P(f1=0 | N Commons) = (1-q)^N for N <= ${THRESHOLD}, 0 for N >= ${THRESHOLD + 1}`);
console.log('  N        P(f1=0)');
for (let n = 1; n <= THRESHOLD + 1; n++) {
  const pz = n >= THRESHOLD + 1 ? 0 : Math.pow(1 - q, n);
  console.log(`  ${String(n).padEnd(8)} ${pz.toFixed(4)}${n === THRESHOLD + 1 ? '   (pity guarantees a hit)' : ''}`);
}

const observedZero = runs.filter((r) => r.f1zero).length;
console.log(`\nEXPECTED f1=0 runs = ${expectedZero(q).toFixed(2)}   (q = ${q.toFixed(4)})`);
console.log(`EXPECTED f1=0 runs = ${expectedZero(qHi).toFixed(2)} .. ${expectedZero(qLo).toFixed(2)}`
  + `   (q at Wilson 95% CI bounds)`);
console.log(`OBSERVED f1=0 runs = ${observedZero}`);

console.log('\nPer-run detail (runs at risk, i.e. Common victories <= ' + THRESHOLD + '):');
console.log('run'.padEnd(16), 'common'.padEnd(7), 'f1'.padEnd(4), 'draws'.padEnd(6), 'f1draws'.padEnd(8), 'P(f1=0)');
for (const r of runs.filter((x) => x.common > 0 && x.common <= THRESHOLD)) {
  const pz = Math.pow(1 - q, r.common);
  console.log([
    r.key.padEnd(16), String(r.common).padEnd(7), String(r.f1).padEnd(4),
    String(r.draws).padEnd(6), String(r.f1Draws).padEnd(8), pz.toFixed(4),
  ].join(' '));
}

console.log('\n----- interpretation -----');
console.log(`Every at-risk run has N <= ${THRESHOLD}; a short-run guard with floor K <= ${THRESHOLD}`
  + ` cannot lift any of them to the pity repair threshold (${THRESHOLD + 1}).`);
console.log(`Observed ${observedZero} vs expected ${expectedZero(q).toFixed(2)}`
  + ` (range ${expectedZero(qHi).toFixed(2)}..${expectedZero(qLo).toFixed(2)} at 95% CI).`);
console.log('Caveat: all runs come from ONE RNG path per seed/school, so the runs are not');
console.log('independent draws; treat the interval as indicative, not a formal test.');
