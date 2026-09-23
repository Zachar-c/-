/** Gate 8 · Phase 8 Rank 从主成长降回承载轴
 *  L0 2026-09-25（docs/superpowers/specs/2026-09-25-l0-build-fork-decision.md §五）：
 *  Build identity 来自蛊的获得/替换 + 炼蛊分支 + 杀招重构；
 *  Rank 只承担力量承载与使用门槛，不作为构筑身份，也不得退化为万能数值倍率。
 *  Gate 8：同 Rank 玩家必须能够有明显不同的 Build；Rank 提升后若不改蛊/杀招，
 *  不能自动变成完全不同的 Build。本文件是零数值漂移结构验收。
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const read = (relativePath) => fs.readFileSync(new URL(relativePath, import.meta.url), 'utf8');
const dataContext = vm.createContext({});
vm.runInContext(read('../js/data.js') + ';globalThis.DATA = DATA;', dataContext);
const data = dataContext.DATA;

const ctx = vm.createContext({});
vm.runInContext(read('../js/run_rules.js'), ctx);
vm.runInContext(read('../js/gu_rules.js'), ctx);
vm.runInContext(read('../js/run_flow.js'), ctx);
vm.runInContext(read('../js/balance.js'), ctx);
vm.runInContext(read('../js/mvp_logic.js'), ctx);
const rules = ctx.GuRules;
const runRules = ctx.RunRules;
const flow = ctx.RunFlow;
const balance = ctx.MvpBalance;
const mvp = ctx.MvpLogic;

const guSource = read('../js/gu_rules.js');
const mvpSource = read('../js/mvp_logic.js');
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));

const KIT_IDS = ['kit_info_suppress', 'kit_pierce_burst', 'kit_stable_sustain'];
const AXES = ['info', 'armor', 'evasion'];

// 构筑身份：已完成 kit 集合 + 可合成杀招 variant 签名集合。
// 只读 owned（lab 无独立 equipped 面，kitCoverage/killMoveVariants 均按 owned 判定）；
// state.playerRank 即使存在也不参与——Rank 只承载，不入身份。
function buildIdentity(state) {
  const { owned = {} } = state;
  const kits = KIT_IDS
    .filter((kitId) => rules.kitCoverage(kitId, owned, guById).ok)
    .sort();
  const variants = new Set();
  for (const move of data.killMoves) {
    for (const variant of rules.killMoveVariants(move, owned, guById)) {
      if (variant.changed) variants.add(`${move.id}::${variant.signature}`);
    }
  }
  return JSON.stringify({ kits, variants: [...variants].sort() });
}

// 提取函数源码体（花括号配对），用于「伤害计算路径不含 rank」的定向断言，
// 避免对整个文件做脆弱 grep（gu_rules 的 canActivate 合法地读 playerRank）。
function fnSource(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.ok(start >= 0, `function ${name} not found`);
  const braceStart = source.indexOf('{', start);
  let depth = 0;
  for (let i = braceStart; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    else if (source[i] === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  throw new Error(`unclosed function ${name}`);
}

const RANK_MARKERS = /playerRank|rankMultiplier|cultivation/i;

// ---- a) 同 Rank 分叉 ----

test('Gate 8a · three kits fork into ≥2 (expected 3) action structures on the same axis at rank 1 and rank 3', () => {
  for (const rank of [1, 3]) {
    for (const axis of AXES) {
      const signatures = KIT_IDS.map(
        (kitId) => rules.actionStructureFor(kitId, { problemAxis: axis, playerRank: rank }).signature,
      );
      const unique = new Set(signatures);
      assert.ok(
        unique.size >= 2,
        `axis=${axis} rank=${rank} must fork ≥2 structures, got ${signatures.join(' ;; ')}`,
      );
      assert.equal(unique.size, 3, `axis=${axis} rank=${rank} expected all 3 kits distinct`);
    }
  }
});

test('Gate 8a · actionStructureFor takes no rank parameter; rank in context does not change the signature', () => {
  // 第二参带默认值，arity 不可靠；直接查函数体：不得出现 rank 入参/引用
  const body = fnSource(guSource, 'actionStructureFor');
  assert.ok(!/\brank\b/i.test(body), 'actionStructureFor must not declare or read a rank parameter');
  for (const kitId of KIT_IDS) {
    for (const axis of AXES) {
      const low = rules.actionStructureFor(kitId, { problemAxis: axis, playerRank: 1 });
      const high = rules.actionStructureFor(kitId, { problemAxis: axis, playerRank: 5 });
      assert.equal(low.signature, high.signature, `${kitId}@${axis} signature must ignore rank`);
      assert.deepEqual(low.steps, high.steps, `${kitId}@${axis} steps must ignore rank`);
    }
  }
});

// ---- b) Rank 升阶不换构筑身份 ----

test('Gate 8b · build identity is unchanged across playerRank 1→5 when owned stays fixed', () => {
  const owned = {
    moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
    jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
  };
  const baseline = buildIdentity({ owned, playerRank: 1 });
  for (const playerRank of [2, 3, 4, 5]) {
    assert.equal(
      buildIdentity({ owned, playerRank }),
      baseline,
      `identity must not change on rank ${playerRank - 1}→${playerRank} without gu/killmove changes`,
    );
  }
});

test('Gate 8b · adding moon_glow_gu changes the identity (signature is not a constant)', () => {
  const owned = {
    moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
    jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
  };
  assert.equal(rules.kitCoverage('kit_info_suppress', owned, guById).ok, false, 'info kit incomplete at baseline');
  const before = buildIdentity({ owned, playerRank: 1 });
  const afterOwned = { ...owned, moon_glow_gu: 1 };
  assert.equal(rules.kitCoverage('kit_info_suppress', afterOwned, guById).ok, true, 'moon_glow completes info kit');
  const after = buildIdentity({ owned: afterOwned, playerRank: 1 });
  assert.notEqual(after, before, 'gain of a build piece must change build identity');
  // Rank 仍不参与：同一 after owned 在各 rank 下身份一致
  for (const playerRank of [2, 3, 4, 5]) {
    assert.equal(buildIdentity({ owned: afterOwned, playerRank }), after);
  }
});

// ---- c) 玩家伤害无 Rank 倍率 ----

test('Gate 8c · killMoveEffectPlan output is identical for playerRank 1 vs 5 contexts', () => {
  const moves = data.killMoves.filter((m) => (m.recipe || []).length);
  assert.ok(moves.length >= 4, 'expected several live kill moves');
  for (const move of moves) {
    const low = rules.killMoveEffectPlan(move, guById, { playerRank: 1 });
    const high = rules.killMoveEffectPlan(move, guById, { playerRank: 5 });
    for (const field of ['damage', 'heal', 'block', 'armorBreak']) {
      assert.equal(low[field], high[field], `${move.id}.${field} must not scale with playerRank`);
    }
    assert.equal(low.ignoreEvasion, high.ignoreEvasion, `${move.id}.ignoreEvasion rank-free`);
    assert.equal(low.inspect, high.inspect, `${move.id}.inspect rank-free`);
    assert.equal(low.suppressCounter, high.suppressCounter, `${move.id}.suppressCounter rank-free`);
  }
});

test('Gate 8c · resolveProblemHit takes no rank; damage-path function bodies contain no rank markers', () => {
  assert.equal(rules.resolveProblemHit.length, 3, 'resolveProblemHit(enemy, plan, dmg) only');
  const enemy = { problemAxis: 'armor', armorValue: 2, revealed: true };
  const plan = { armorBreak: 1 };
  const first = rules.resolveProblemHit(enemy, plan, 4);
  const second = rules.resolveProblemHit(enemy, plan, 4);
  assert.deepEqual(first, second);

  // 伤害计算路径定向源断言（行为断言为主，源断言补盲区）
  for (const name of ['killMoveEffectPlan', 'applyPart', 'resolveProblemHit']) {
    const body = fnSource(guSource, name);
    assert.ok(
      !RANK_MARKERS.test(body),
      `gu_rules.${name} body must not reference playerRank/rankMultiplier/cultivation`,
    );
  }
  for (const name of ['resolveDirectStrike', 'resolveEnemyAction']) {
    const body = fnSource(mvpSource, name);
    assert.ok(
      !RANK_MARKERS.test(body),
      `mvp_logic.${name} body must not reference playerRank/rankMultiplier/cultivation`,
    );
  }
});

test('Gate 8c · actionValues accepts no rank and is deterministic', () => {
  // 参数带默认值，arity 不可靠；无法注入 rank → 按任务约定断言函数体源不含 rank 字样
  const action = { damage: 3, qi: 2, light: true };
  assert.deepEqual(mvp.actionValues(action, 0), mvp.actionValues(action, 0));
  assert.deepEqual(mvp.actionValues(action, 1), mvp.actionValues(action, 1));
  // 函数体内不允许出现 rank 字样（行为上无法注入 rank，故查函数体源）
  const body = fnSource(mvpSource, 'actionValues');
  assert.ok(!RANK_MARKERS.test(body), 'actionValues body must stay rank-free');
});

// ---- d) Rank 承载轴仍生效（正向锁） ----

test('Gate 8d · canActivate enforces rank as carriage gate: (1,1) yes, (1,2) no, (2,2) yes', () => {
  assert.equal(rules.canActivate(1, 1), true);
  assert.equal(rules.canActivate(1, 2), false);
  assert.equal(rules.canActivate(2, 2), true);
});

test('Gate 8d · essenceMax is rank-monotone and rank1 follows the DATA aptitude formula', () => {
  const dataMap = {
    essenceBase: data.aptitude.essence_base,
    aptitudeFactor: data.aptitude.aptitude_factor,
    cultivationFactor: data.aptitude.cultivation_factor,
  };
  const expectedRank1 = data.aptitude.essence_base
    * data.aptitude.aptitude_factor.bing
    * data.aptitude.cultivation_factor['1'];
  assert.equal(runRules.essenceMax(1, 'bing', dataMap), expectedRank1, 'rank1 must equal base×aptitude×cultivation formula');
  let previous = -Infinity;
  for (const rank of [1, 2, 3, 4, 5]) {
    const value = runRules.essenceMax(rank, 'bing', dataMap);
    assert.ok(Number.isFinite(value) && value >= previous, `essenceMax rank${rank} must be ≥ previous (monotone)`);
    previous = value;
  }
});

test('Gate 8d · gu_rules neither exports nor consumes balance rankMultiplier', () => {
  // crossRankQiCost 的非 rankMultiplier 断言已由 l1_boundaries.test.mjs 覆盖，此处不重复；
  // 这里只锁 gu_rules 侧：不得把 balance 的 rankMultiplier 引进规则/伤害路径。
  assert.equal(rules.rankMultiplier, undefined, 'GuRules must not export rankMultiplier');
  assert.ok(!guSource.includes('rankMultiplier'), 'gu_rules source must not mention rankMultiplier');
  assert.equal(typeof balance.crossRankQiCost, 'function', 'crossRankQiCost stays in balance (l1-covered)');
});

// ---- e) 突破只动承载面 ----

test('Gate 8e · RunFlow.nextBreakthrough result never touches owned/equipped/recipes/killMoves', () => {
  const forbidden = ['owned', 'equipped', 'recipes', 'killMoves'];
  const cases = [
    flow.nextBreakthrough({ rank: 1, stageIndex: 0, stones: 100, aptitude: 'bing', owned: {} }, data.flow),
    flow.nextBreakthrough({ rank: 1, stageIndex: 3, stones: 100, aptitude: 'bing', owned: {} }, data.flow),
    flow.nextBreakthrough({ rank: 1, stageIndex: 3, stones: 0, aptitude: 'ding', owned: {} }, data.flow),
    flow.nextBreakthrough({ rank: 5, stageIndex: 3, stones: 100, aptitude: 'jia', owned: {} }, data.flow),
    flow.nextBreakthrough({ rank: 2, stageIndex: 1, stones: 0, aptitude: 'bing', owned: { gold_atk_2_11_gu: 1 } }, data.flow),
  ];
  for (const result of cases) {
    const keys = Object.keys(result);
    const overlap = keys.filter((k) => forbidden.includes(k));
    assert.deepEqual(overlap, [], `breakthrough must stay on the carriage face, got build keys: ${overlap.join(',')}`);
    assert.ok(keys.includes('ok'), 'result must report ok');
    assert.ok(
      keys.every((k) => ['ok', 'kind', 'reason', 'targetStageIndex', 'targetLabel', 'targetRank',
        'stoneCost', 'sariId', 'canStone', 'canSari', 'missing', 'requiredApt', 'aptitudeOk', 'stoneOk'].includes(k)),
      `unexpected result keys: ${keys.join(',')}`,
    );
  }
  // 大突破与小突破的 target 语义是阶/费用/标签，不是构筑
  const small = flow.nextBreakthrough({ rank: 1, stageIndex: 0, stones: 100, aptitude: 'bing', owned: {} }, data.flow);
  assert.equal(small.kind, 'small');
  assert.equal(small.targetStageIndex, 1);
  const big = flow.nextBreakthrough({ rank: 1, stageIndex: 3, stones: 100, aptitude: 'bing', owned: {} }, data.flow);
  assert.equal(big.kind, 'big');
  assert.equal(big.targetRank, 2);
});
