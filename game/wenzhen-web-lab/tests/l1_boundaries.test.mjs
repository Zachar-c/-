/* P5 · Counter 权限边界：必须读真实实现，禁止只断言测试内数组 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const game = join(root, '..');
const RUL = JSON.parse(readFileSync(join(root, '../world-model/rulings/RUL-2026-09-21-010.json'), 'utf8'));
const RANK_RT = JSON.parse(readFileSync(join(root, 'data/rank_runtime.json'), 'utf8'));
const BAL = JSON.parse(readFileSync(join(root, '../data/balance.json'), 'utf8'));
const mvpLogic = readFileSync(join(root, 'js/mvp_logic.js'), 'utf8');
const v1 = JSON.parse(readFileSync(join(game, 'data/v1_battle.json'), 'utf8'));
const godot = readFileSync(join(game, 'scripts/domain/v1_battle_resolver.gd'), 'utf8');

const ALLOWED = ['intercept', 'draw_light', 'seal_first', 'seal_last', 'iron', 'none'];
const tokenRe = /['"]((?:intercept|draw_light|seal_first|seal_last|iron|none))['"]/g;

function liveCounters() {
  const s = new Set();
  for (const src of [mvpLogic, JSON.stringify(v1), godot]) {
    for (const m of src.matchAll(tokenRe)) s.add(m[1]);
  }
  return s;
}

test('Counter is primitive_only_not_skeleton', () => {
  assert.match(RUL.q4_counter.decision, /not_skeleton/);
});

test('Counter does not own economy / refinement / kill_move_structure', () => {
  for (const x of ['economy', 'refinement', 'kill_move_structure', 'qi_economy']) {
    assert.ok(RUL.q4_counter.not_owns.includes(x), x);
  }
});

test('new combat primitive needs six gates including SOURCE', () => {
  for (const x of ['UNIQUE', 'BUILD_RELEVANT', 'COUNTERPLAY', 'STATEFUL', 'TESTABLE', 'SOURCE']) {
    assert.ok(RUL.q4_counter.admission_gates.includes(x), x);
  }
});

test('real implementation counters ⊆ frozen whitelist', () => {
  const live = liveCounters();
  assert.ok(live.size >= 5, 'must observe real tokens, got ' + [...live].join(','));
  for (const c of live) {
    assert.ok(ALLOWED.includes(c), `unexpected counter ${c}`);
  }
});

test('mvp_logic actually handles each whitelist counter except none', () => {
  for (const c of ALLOWED) {
    if (c === 'none') continue;
    assert.ok(mvpLogic.includes(`'${c}'`) || mvpLogic.includes(`"${c}"`) || mvpLogic.includes(`case '${c}'`), c);
  }
});

test('crossRankQiCost is live and uses 0.65 not rank_multiplier', () => {
  const context = vm.createContext({});
  context.WORLD_BALANCE = BAL;
  vm.runInContext(readFileSync(join(root, 'js/balance.js'), 'utf8'), context);
  const B = context.MvpBalance;
  assert.equal(typeof B.crossRankQiCost, 'function');
  assert.equal(B.crossRankQiCost(8, 5, 1), Math.max(1, Math.round(8 * Math.pow(0.65, 4))));
  assert.equal(B.crossRankQiCost(20, 1, 3), null);
  assert.notEqual(B.crossRankQiCost(20, 5, 1), B.rankMultiplier(5) * 20);
});

test('rank runtime eight fields all wired and mult=false', () => {
  assert.equal(Object.keys(RANK_RT.fields).length, 8);
  for (const [f, spec] of Object.entries(RANK_RT.fields)) {
    assert.equal(spec.mult, false, f);
    assert.equal(spec.wired, true, f);
    assert.ok(spec.source, f);
  }
});

test('low-rank keep policy forbids extra value decay', () => {
  assert.match(RANK_RT.low_rank_keep.value_decay, /FORBIDDEN/);
});

test('L1 leave-blank list stays four items', () => {
  assert.equal(RUL.unresolved_leave_blank.length, 4);
});
