/* lab.html 真实 DOM 自动走盘（W6）。
 * 只点可见按钮，不 evaluate 写 state、不直接调 act。
 * 用法：
 *   node tools/autoplay_lab.mjs --suite smoke --seed 101 --difficulty normal
 *   node tools/autoplay_lab.mjs --suite lifecycle --seed 101 --difficulty normal
 *   node tools/autoplay_lab.mjs --suite full --seeds 101-110 --difficulty normal --policy balanced
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { openLab } from '../tests/helpers/lab_browser.mjs';

const MAX_ACTIONS = 20000;
const STALL_LIMIT = 40;
const VIEWPORT = [1280, 720];

function parseSeedList(spec) {
  const text = String(spec || '').trim();
  if (!text) return [];
  if (/^\d+-\d+$/.test(text)) {
    const [a, b] = text.split('-').map(Number);
    if (b < a) throw new Error(`seeds 范围无效: ${text}`);
    const out = [];
    for (let s = a; s <= b; s += 1) out.push(s);
    return out;
  }
  return text.split(',').map((x) => Number(x.trim())).filter((n) => Number.isFinite(n));
}

function parseArgs(argv) {
  const opts = {
    entry: '',
    suite: 'smoke',
    seed: null,
    seeds: null,
    difficulty: 'normal',
    policy: 'balanced',
    shots: '',
    json: false,
    edge: '',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === '--entry') opts.entry = String(next());
    else if (a === '--suite') opts.suite = String(next());
    else if (a === '--seed') opts.seed = Number(next());
    else if (a === '--seeds') opts.seeds = parseSeedList(next());
    else if (a === '--difficulty') opts.difficulty = String(next());
    else if (a === '--policy') opts.policy = String(next());
    else if (a === '--shots') opts.shots = String(next());
    else if (a === '--json') opts.json = true;
    else if (a === '--edge') opts.edge = String(next());
    else throw new Error(`未知参数: ${a}`);
  }
  if (!['smoke', 'lifecycle', 'full'].includes(opts.suite)) {
    throw new Error(`--suite 必须是 smoke|lifecycle|full，收到 ${opts.suite}`);
  }
  if (!['balanced', 'refine'].includes(opts.policy)) {
    throw new Error(`--policy 必须是 balanced|refine，收到 ${opts.policy}`);
  }
  if (!['easy', 'normal', 'hard'].includes(opts.difficulty)) {
    throw new Error(`--difficulty 必须是 easy|normal|hard，收到 ${opts.difficulty}`);
  }
  if (opts.seed != null && opts.seeds) throw new Error('--seed 与 --seeds 互斥');
  if (opts.seed != null && !Number.isFinite(opts.seed)) throw new Error('--seed 无效');
  return opts;
}

function resolveEntry(entry) {
  if (!entry) return path.resolve(import.meta.dirname, '../lab.html');
  const text = String(entry);
  if (text.startsWith('file:') || text.startsWith('http')) return text;
  return path.resolve(text);
}

function isEntryLab(entry) {
  return /lab\.html$/i.test(String(entry).split('?')[0]);
}

async function clickFirst(lab, selectors, skip = new Set()) {
  for (const selector of selectors) {
    if (skip.has(selector)) continue;
    try {
      await lab.click(selector);
      return selector;
    } catch { /* disabled, invisible, or missing */ }
  }
  return null;
}

function snapKey(snap) {
  if (!snap) return 'null';
  const enemies = (snap.battle?.enemies || []).map((e) => `${e.id}:${e.hp}`).join(',');
  return [
    snap.page,
    snap.ending?.outcome || '',
    snap.battle?.over || '',
    snap.battle?.turn ?? '',
    snap.battle?.actionsUsed ?? '',
    snap.thought,
    snap.stones,
    snap.qi,
    snap.blood,
    enemies,
    (snap.journey?.availableNodeIds || []).join(','),
    (snap.journey?.completed || []).length,
    snap.reward ? 'R' : '',
    snap.prepFor || '',
  ].join('|');
}

function snapSummary(snap) {
  return {
    page: snap?.page || '',
    thought: snap?.thought ?? null,
    stones: snap?.stones ?? null,
    blood: snap?.blood ?? null,
    qi: snap?.qi ?? null,
    life: snap?.lifeTime ?? null,
    battleOver: snap?.battle?.over || null,
    ending: snap?.ending?.outcome || null,
    available: snap?.journey?.availableNodeIds?.length ?? 0,
    completed: snap?.journey?.completed?.length ?? 0,
  };
}

function choosePolicyActions(policy) {
  if (policy === 'refine') {
    return {
      battle: ['[data-basic-attack]', '[data-observe]', '[data-use]', '[data-use-gu]', '[data-end-turn]', '[data-exhaust]'],
      prep: ['[data-forge]', '[data-attune]', '[data-buy-offer]', '[data-km]', '[data-break]', '[data-prep-continue]'],
    };
  }
  return {
    battle: ['[data-basic-attack]', '[data-use]', '[data-use-gu]', '[data-end-turn]'],
    prep: ['[data-buy-offer]', '[data-attune]', '[data-km]', '[data-break]', '[data-forge]', '[data-prep-continue]'],
  };
}

async function playOneRun({ entry, seed, difficulty, policy, suite, shots, edge }) {
  const actions = choosePolicyActions(policy);
  console.error(`[autoplay] open entry=${entry} seed=${seed} policy=${policy}`);
  const lab = await openLab({ entry, seed, viewport: VIEWPORT, edge: edge || undefined });
  const ledger = [];
  const consoleErrors = [];
  const softlocks = [];
  const visitedNodes = [];
  let terminalReason = '';
  let outcome = 'timeout';
  let steps = 0;
  let stall = 0;
  let lastKey = '';
  const skip = new Set();

  try {
    let snap = await lab.snapshot();
    if (!snap) throw new Error('snapshot 不可用（打开的可能不是 lab）');
    ledger.push({ step: 0, kind: 'boot', summary: snapSummary(snap) });

    if (difficulty) await clickFirst(lab, [`[data-difficulty="${difficulty}"]`]);
    const started = await clickFirst(lab, ['[data-start-run]', '[data-continue-run]']);
    if (!started) throw new Error('找不到开局/继续按钮');
    console.error('[autoplay] run started');

    for (; steps < MAX_ACTIONS; steps += 1) {
      snap = await lab.snapshot();
      if (!snap) throw new Error('snapshot 丢失');
      if (snap.ending?.outcome) {
        outcome = snap.ending.outcome;
        terminalReason = snap.ending.title || snap.ending.outcome;
        break;
      }

      let acted = null;

      if (snap.page === 'reward' || snap.reward) {
        acted = await clickFirst(lab, ['[data-reward-gu]', '[data-reward-continue]']);
        if (acted) {
          ledger.push({ step: steps, kind: 'reward', via: acted, summary: snapSummary(snap) });
        }
      }

      if (!acted && snap.battle && !snap.battle.over) {
        const before = snapSummary(snap);
        acted = await clickFirst(lab, actions.battle, skip);
        if (acted) {
          const afterSnap = await lab.snapshot();
          const after = snapSummary(afterSnap);
          ledger.push({ step: steps, kind: 'battle', via: acted, before, after });
          if (snapKey(afterSnap) === snapKey(snap)) {
            skip.add(acted);
            stall += 1;
          } else {
            skip.clear();
            stall = 0;
          }
        }
      }

      if (!acted && snap.battle?.over) {
        acted = await clickFirst(lab, ['[data-reward-continue]', '[data-prep-continue]', '[data-go-map]', '[data-open-outcome]']);
        if (acted) ledger.push({ step: steps, kind: 'settle', via: acted, summary: snapSummary(snap) });
      }

      if (!acted && (snap.page === 'prep' || snap.prepFor)) {
        acted = await clickFirst(lab, actions.prep);
        if (acted) ledger.push({ step: steps, kind: 'prep', via: acted, summary: snapSummary(snap) });
      }

      if (!acted) {
        acted = await clickFirst(lab, ['[data-node-action]']);
        if (acted) ledger.push({ step: steps, kind: 'node_action', via: acted, summary: snapSummary(snap) });
      }

      if (!acted) {
        const nodeId = (snap.journey?.availableNodeIds || [])[0];
        if (nodeId) {
          acted = await clickFirst(lab, [`[data-choose-node="${nodeId}"]`, '[data-choose-node]']);
          if (acted) {
            visitedNodes.push(nodeId);
            ledger.push({ step: steps, kind: 'choose_node', nodeId, via: acted, summary: snapSummary(snap) });
            await clickFirst(lab, ['[data-start-encounter]']);
          }
        }
      }

      if (!acted) {
        acted = await clickFirst(lab, ['[data-go-map]', '[data-prep-continue]']);
        if (acted) ledger.push({ step: steps, kind: 'nav', via: acted, summary: snapSummary(snap) });
      }

      if (!acted) {
        softlocks.push({ step: steps, reason: 'no_enabled_action', summary: snapSummary(snap), key: snapKey(snap) });
        break;
      }

      const key = snapKey(await lab.snapshot());
      if (key === lastKey) {
        stall += 1;
        if (stall >= STALL_LIMIT) {
          softlocks.push({ step: steps, reason: 'stalled', summary: snapSummary(await lab.snapshot()), key });
          break;
        }
      } else {
        stall = 0;
        lastKey = key;
      }

      if (steps % 50 === 0) console.error(`[autoplay] step=${steps} ${key}`);
    }

    if (steps >= MAX_ACTIONS) {
      softlocks.push({ step: steps, reason: 'max_actions', summary: snapSummary(await lab.snapshot()) });
    }

    snap = await lab.snapshot();
    if (snap?.ending?.outcome) {
      outcome = snap.ending.outcome;
      terminalReason = terminalReason || snap.ending.title || snap.ending.outcome;
    }

    if (shots) {
      mkdirSync(shots, { recursive: true });
      await lab.shoot(path.join(shots, `seed-${seed}-${suite}-final.png`));
    }

    for (const line of lab.logs()) {
      if (line.includes('[exception]') || line.includes('[console.error]')) consoleErrors.push(line);
    }

    const resourceLedger = {
      stones: snap?.stones ?? null,
      qi: snap?.qi ?? null,
      thought: snap?.thought ?? null,
      blood: snap?.blood ?? null,
      life: snap?.lifeTime ?? null,
      owned: snap?.owned || {},
      materials: snap?.materials || {},
      equipped: snap?.equipped || [],
      completed: snap?.journey?.completed?.length ?? 0,
      pages: [...new Set(ledger.map((x) => x.kind))],
    };

    return {
      entry: lab.url(),
      contentHash: '',
      seed,
      difficulty,
      policy,
      suite,
      outcome,
      visitedNodes,
      terminalReason,
      resourceLedger,
      consoleErrors,
      softlocks,
      steps,
      logs: ledger,
      class: 'NORMAL_RUN',
    };
  } finally {
    await lab.close();
  }
}

async function playLifecycle({ entry, seed, difficulty, edge, shots }) {
  console.error(`[autoplay] lifecycle seed=${seed}`);
  const lab = await openLab({ entry, seed, viewport: VIEWPORT, edge: edge || undefined });
  const checkpoints = [];
  try {
    await clickFirst(lab, [`[data-difficulty="${difficulty}"]`]);
    await clickFirst(lab, ['[data-start-run]']);
    await clickFirst(lab, ['[data-choose-node]']);
    await clickFirst(lab, ['[data-start-encounter]']);
    const mid = await lab.snapshot();
    checkpoints.push({ kind: 'pre_reload', summary: snapSummary(mid) });
    if (shots) {
      mkdirSync(shots, { recursive: true });
      await lab.shoot(path.join(shots, `seed-${seed}-lifecycle-before.png`));
    }
    await lab.reload();
    const after = await lab.snapshot();
    checkpoints.push({ kind: 'post_reload', summary: snapSummary(after) });
    if (!after || after.ending) throw new Error('刷新后未能恢复进行中局');
    const continued = await clickFirst(lab, ['[data-continue-run]', '[data-go-map]']);
    checkpoints.push({ kind: 'continue', via: continued, summary: snapSummary(await lab.snapshot()) });
    const restartVisible = await clickFirst(lab, ['[data-start-run]']);
    checkpoints.push({ kind: 'restart_attempt', ok: !!restartVisible });
    return {
      class: 'FIXTURE_INTEGRATION',
      suite: 'lifecycle',
      seed,
      difficulty,
      checkpoints,
      consoleErrors: lab.logs().filter((l) => l.includes('[exception]') || l.includes('[console.error]')),
    };
  } finally {
    await lab.close();
  }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const entry = resolveEntry(opts.entry);
  if (!isEntryLab(entry)) {
    console.error(`FAIL: 入口必须是 lab.html，收到 ${entry}`);
    process.exit(2);
  }
  const seeds = opts.seeds || [opts.seed ?? 101];
  const results = [];

  for (const seed of seeds) {
    if (opts.suite === 'lifecycle') {
      const result = await playLifecycle({
        entry, seed, difficulty: opts.difficulty, edge: opts.edge, shots: opts.shots,
      });
      results.push(result);
      console.log(JSON.stringify({ class: result.class, suite: 'lifecycle', seed, ok: result.consoleErrors.length === 0 }));
      continue;
    }
    const result = await playOneRun({
      entry,
      seed,
      difficulty: opts.difficulty,
      policy: opts.policy,
      suite: opts.suite,
      shots: opts.shots,
      edge: opts.edge,
    });
    results.push(result);
    console.log(JSON.stringify({
      class: result.class,
      seed,
      policy: result.policy,
      outcome: result.outcome,
      terminalReason: result.terminalReason,
      steps: result.steps,
      softlocks: result.softlocks.length,
      consoleErrors: result.consoleErrors.length,
      completed: result.resourceLedger.completed,
    }));
    if (opts.suite === 'smoke') break;
  }

  const fails = results.filter((r) => {
    if (r.suite === 'lifecycle' || r.class === 'FIXTURE_INTEGRATION') return r.consoleErrors?.length > 0;
    if (r.suite === 'full') {
      return r.softlocks?.length > 0 || r.consoleErrors?.length > 0 || !['victory', 'defeat'].includes(r.outcome);
    }
    return r.softlocks?.length > 0 || r.consoleErrors?.length > 0 || r.steps < 3;
  });

  const summary = {
    entry,
    suite: opts.suite,
    difficulty: opts.difficulty,
    policy: opts.policy,
    seeds,
    pass: fails.length === 0,
    results,
  };
  if (opts.json) console.log(JSON.stringify(summary, null, 2));
  if (!summary.pass) {
    console.error(`FAIL: ${fails.length}/${results.length} 局未达标`);
    process.exit(1);
  }
  console.error(`PASS: ${results.length} 局完成（${opts.suite}）`);
}

main().catch((err) => {
  console.error(`FAIL: ${err && err.message ? err.message : err}`);
  process.exit(1);
});
