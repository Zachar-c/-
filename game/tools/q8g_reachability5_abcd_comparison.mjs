#!/usr/bin/env node
// Reachability-5 follow-up (inbox #15 whitelist): A/B/C/D report-level
// hypothetical comparison on the observed R5 battle sequences.
// Measurement-only: reads logs + data, writes nothing into the game.
//
// Directions (all hypothetical, assumptions documented in the R5 record):
//   ACTUAL   - observed sequences, natural f1 hits only (baseline).
//   C        - + R4 semantics: all-battle f1 absence streak, redemption only
//              at common-table victories (threshold 3).
//   B        - C + crude(f1) hypothetically added to the elite pool: elite
//              victories gain a natural f1 chance derived from the elite
//              pool's crude weight share x material_count (approx 2 rolls).
//   A        - nominal 75/25 tier share restored on settled non-boss battles
//              (seeded resample); converted common battles carry a natural f1
//              chance equal to the observed common-battle hit rate; boss and
//              unsettled battles untouched; redemption as in C.
//   D        - R3-era shared counter semantics on actual data: one counter fed
//              by every settled material-bearing battle, reset by any tier
//              target hit, forcing whatever tier's pool the battle settles on.
//
// Metrics per run: f1 deliveries total, first delivery battle index,
// deliveries before the last refinement visit (f1 available inside the run's
// refinement window), f1_zero resolved (deliveries > 0).

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL } from 'node:url';

const projectRoot = path.resolve(import.meta.dirname, '..');
const logDir = process.env.Q8G_R5_LOG_DIR || path.join(os.tmpdir(), 'gu-zhenrens-r5-logs');
const loot = JSON.parse(fs.readFileSync(path.join(projectRoot, 'data/loot_tables.json'), 'utf8'));

const CASES = [
  ['force', '20260927'], ['force', '11'], ['force', '33'], ['force', '55'],
  ['sword', '20260927'], ['sword', '11'], ['sword', '33'], ['sword', '55'],
];

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function eliteF1ChancePerBattle() {
  const pool = loot.loot.elite.material_pool;
  let total = 0, crude = 0;
  for (const entry of pool) {
    const id = typeof entry === 'string' ? entry : entry.id;
    const w = typeof entry === 'string' ? 1 : Math.max(1, entry.weight || 1);
    total += w;
    const mat = loot.materials[id];
    if (mat && mat.quality_band === 'crude') crude += w;
  }
  const perRoll = crude / total;
  return 1 - Math.pow(1 - perRoll, 2); // approx 2 material rolls per battle
}

function parseLog(file) {
  const text = fs.readFileSync(file, 'utf8');
  const battles = [];
  for (const m of text.matchAll(/R-5 battle: idx=(\d+) outcome=(\w+) stage=\d+ node=\S+ tmpl_kind=(\S*) battle_kind=(\S*) battle_kinds=(\[[^\]]*\]) tier=(\S+) grade=\S* rank=\S+ layer=(\d+) rank_min=\d+ rank_max=\d+ weights=(\{[^}]*\}) mat_tier=\S+ mats=(\[[^\]]*\]) f1_hit=(\d+)/g)) {
    battles.push({
      idx: Number(m[1]), outcome: m[2], tier: m[6], layer: Number(m[7]),
      mats: m[9] === '[]' ? [] : m[9].slice(1, -1).split(',').map(s => s.trim().replace(/^"|"$/g, '')).filter(Boolean),
      f1_hit: Number(m[10]),
    });
  }
  const summary = text.match(/R-5 summary: .*/g)?.pop() || '';
  const visitMarks = JSON.parse((summary.match(/visit_marks=(\[[^\]]*\])/) || [])[1] || '[]');
  const legalF1 = JSON.parse((text.match(/R-5 audit on: legal_f1=(\[[^\]]*\])/) || [])[1] || '[]');
  return { battles, visitMarks, legalF1 };
}

function simulate(direction, run, rng) {
  const pNaturalCommon = run.observedCommonF1Rate || 0.55;
  const pEliteF1 = eliteF1ChancePerBattle();
  const school = run.school;
  const chainHit = (mats) => mats.some(m => new RegExp(`^mat_${school}_[1-4]$`).test(m));
  let streak = 0;
  let deliveries = 0;
  let firstDelivery = -1;
  const firstDeliveryInWindow = () => run.visitMarks.length === 0 ? false
    : (firstDelivery !== -1 && firstDelivery <= Math.max(...run.visitMarks));
  for (const b of run.battles) {
    if (b.outcome !== 'victory') continue;
    let tier = b.tier;
    let naturalHit = b.f1_hit > 0;
    if (direction === 'A' && tier !== 'boss') {
      const converted = rng() < 0.75;
      if (converted && tier !== 'common') {
        tier = 'common';
        naturalHit = rng() < pNaturalCommon;
      } else if (!converted && tier === 'common') {
        tier = 'elite';
        naturalHit = false;
      }
    }
    if (direction === 'B' && tier === 'elite' && !naturalHit) {
      naturalHit = rng() < pEliteF1;
    }
    const hasMaterials = tier !== 'unsettled';
    if (!hasMaterials) continue;
    if (direction === 'D') {
      // R3-era shared counter: any chain-band target hit resets; forcing
      // delivers whatever tier's pool the battle settles on (f1 only via common).
      if (chainHit(b.mats)) {
        streak = 0;
        continue;
      }
      if (streak >= 3) {
        if (tier === 'common') {
          deliveries += 1;
          if (firstDelivery === -1) firstDelivery = b.idx;
        }
        streak = 0;
      } else {
        streak += 1;
      }
      continue;
    }
    if (naturalHit) {
      deliveries += 1;
      if (firstDelivery === -1) firstDelivery = b.idx;
      streak = 0;
      continue;
    }
    const redemptionEnabled = direction === 'C' || direction === 'B' || direction === 'A';
    const redemptionWindow = redemptionEnabled && tier === 'common';
    if (redemptionWindow && streak >= 3) {
      deliveries += 1;
      if (firstDelivery === -1) firstDelivery = b.idx;
      streak = 0;
    } else {
      streak += 1;
    }
  }
  return { deliveries, firstDelivery, inWindow: firstDeliveryInWindow() };
}

const results = [];
for (const [school, seed] of CASES) {
  const file = path.join(logDir, `${school}_${seed}.log`);
  const parsed = parseLog(file);
  const commonBattles = parsed.battles.filter(b => b.outcome === 'victory' && b.tier === 'common');
  const hits = commonBattles.reduce((s, b) => s + b.f1_hit, 0);
  const run = {
    battles: parsed.battles, visitMarks: parsed.visitMarks, school,
    observedCommonF1Rate: commonBattles.length ? hits / commonBattles.length : 0.55,
  };
  const row = { school, seed, actualF1: parsed.battles.reduce((s, b) => s + b.f1_hit, 0), visitCount: parsed.visitMarks.length };
  for (const direction of ['ACTUAL', 'C', 'B', 'A', 'D']) {
    const rng = mulberry32([...(school + seed)].reduce((a, c) => a + c.charCodeAt(0), 0) + direction.length * 7919);
    row[direction] = simulate(direction, run, rng);
  }
  results.push(row);
}

function main() {
  console.log('Reachability-5 A/B/C/D hypothetical comparison (measurement-only, report level)');
  console.log('legend: deliveries=total f1 delivered | first=battle idx of first delivery | inWin=first delivery at/before last visit');
  for (const r of results) {
    console.log(`\n${r.school}/${r.seed}  actual_f1=${r.actualF1}  visits=${r.visitCount}`);
    for (const d of ['ACTUAL', 'C', 'B', 'A', 'D']) {
      const s = r[d];
      console.log(`  ${d.padEnd(7)} deliveries=${s.deliveries}  first=${s.firstDelivery === -1 ? 'never' : '#' + s.firstDelivery}  inWindow=${s.inWindow}`);
    }
  }
}

// Only print when run directly, not when imported by the preflight tool.
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}

export { parseLog, mulberry32, CASES, eliteF1ChancePerBattle };
