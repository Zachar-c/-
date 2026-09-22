/** Gate 1 · Phase 1 敌人问题轴 × 玩家解法
 *  L0 2026-09-25：三个问题轴各至少两种可辩护方案；遮住名字只看行为痕迹应能分辨。
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const data = dataContext.DATA;
const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
const rules = rulesContext.GuRules;
const guById = Object.fromEntries(data.gu.map((g) => [g.id, g]));
const enemyById = Object.fromEntries(data.enemies.map((e) => [e.id, e]));

const planOf = (ids, context = {}) => {
  const move = { recipe: ids, tag: 'light' };
  return rules.killMoveEffectPlan(move, guById, context);
};

test('Gate 1 · three live common enemies expose three distinct problem axes', () => {
  const commons = data.enemies.filter((e) => e.tier === 'common');
  const axes = new Set(commons.map((e) => e.problemAxis).filter(Boolean));
  assert.ok(axes.has('info'), 'stone wanderer = info/counter');
  assert.ok(axes.has('armor'), 'iron hide boar = armor');
  assert.ok(axes.has('evasion'), 'ridge hound = evasion');
  assert.equal(axes.size, 3);
});

test('Gate 1 · four unfrozen verbs are live on component battleEffects', () => {
  assert.equal(guById.small_light_gu.battleEffect.inspect, true);
  assert.equal(guById.moonlight_gu.battleEffect.ignoreEvasion, true);
  assert.equal(guById.moon_glow_gu.battleEffect.suppress, true);
  const ab = guById.white_boar_strength_gu.battleEffect.armorBreak
    || guById.white_boar_strength_gu.battleEffect.pierce;
  assert.ok(ab >= 1, 'armorBreak/pierce semantic family present');

  const p = planOf(['small_light_gu', 'moonlight_gu', 'moon_glow_gu', 'white_boar_strength_gu']);
  assert.equal(p.inspect, true);
  assert.equal(p.ignoreEvasion, true);
  assert.equal(p.suppressCounter, true);
  assert.ok(p.armorBreak >= 2);
});

test('Gate 1 · armor axis — pierce OR chip are two defensible solutions', () => {
  const boar = { ...enemyById.iron_hide_boar, revealed: true };
  const naive = rules.resolveProblemHit(boar, { armorBreak: 0 }, 4);
  assert.equal(naive.damage, 2, 'naive strike eats flat armor 2');
  assert.ok(naive.notes.includes('armor_tax') || naive.notes.includes('armored'));

  const pierced = rules.resolveProblemHit(boar, { armorBreak: 2 }, 4);
  assert.equal(pierced.damage, 4, 'pierce/armorBreak negates armor');
  assert.ok(pierced.notes.includes('pierce_armor'));

  const chip = rules.resolveProblemHit(boar, { armorBreak: 0 }, 1);
  assert.equal(chip.damage, 1, 'chip/stable low damage bypasses armor');
  assert.ok(chip.notes.includes('chip_through_armor'));
});

test('Gate 1 · evasion axis — ignoreEvasion OR inspect-lock OR low-stable are solutions', () => {
  const hound = { ...enemyById.ridge_hound, revealed: false };
  const heavy = rules.resolveProblemHit(hound, {}, 4);
  assert.equal(heavy.damage, 0, 'high damage misses without a stable verb');
  assert.ok(heavy.notes.includes('evaded'));

  const sure = rules.resolveProblemHit(hound, { ignoreEvasion: true }, 4);
  assert.equal(sure.damage, 4);
  assert.ok(sure.notes.includes('ignore_evasion'));

  const locked = rules.resolveProblemHit({ ...hound, revealed: true }, { inspect: true }, 4);
  assert.equal(locked.damage, 4, 'inspect lock guarantees hit');
  assert.ok(locked.notes.includes('locked_on'));

  const low = rules.resolveProblemHit(hound, {}, 2);
  assert.equal(low.damage, 2, 'low stable damage always hits');
  assert.ok(low.notes.includes('stable_hit'));
});

test('Gate 1 · info axis — inspect+suppress OR avoid direct strike are solutions', () => {
  const walker = { ...enemyById.neutral_stone_wanderer, revealed: false };
  const blind = rules.resolveProblemHit(walker, {}, 3);
  assert.ok(blind.notes.includes('unread_tax'), 'blind strike pays unread tax');

  const read = rules.resolveProblemHit(walker, { inspect: true }, 3);
  assert.ok(read.notes.includes('read_rule'));
  assert.ok(!read.notes.includes('unread_tax'));

  const suppressed = rules.resolveProblemHit(
    { ...walker, revealed: true },
    { suppressCounter: true },
    3,
  );
  assert.ok(suppressed.notes.includes('suppressed_rule'));
  assert.ok(!suppressed.notes.includes('unread_tax'));
});

test('Gate 1 · action traces diverge: same naive strike is not the same problem', () => {
  const naivePlan = { armorBreak: 0, ignoreEvasion: false, inspect: false, suppressCounter: false };
  const tInfo = rules.resolveProblemHit({ ...enemyById.neutral_stone_wanderer, revealed: false }, naivePlan, 3);
  const tArmor = rules.resolveProblemHit({ ...enemyById.iron_hide_boar, revealed: false }, naivePlan, 3);
  const tEva = rules.resolveProblemHit({ ...enemyById.ridge_hound, revealed: false }, naivePlan, 3);

  const sig = (r) => [...r.notes].sort().join('|') + '#' + r.damage;
  const signatures = new Set([sig(tInfo), sig(tArmor), sig(tEva)]);
  assert.equal(signatures.size, 3, `traces must diverge: ${[sig(tInfo), sig(tArmor), sig(tEva)].join(' ;; ')}`);
});

test('Gate 1 · solver traces diverge: each axis has a dedicated answer pattern', () => {
  const solveArmor = rules.resolveProblemHit(
    { ...enemyById.iron_hide_boar, revealed: true },
    { armorBreak: 2 },
    4,
  );
  const solveEva = rules.resolveProblemHit(
    { ...enemyById.ridge_hound, revealed: true },
    { ignoreEvasion: true },
    4,
  );
  const solveInfo = rules.resolveProblemHit(
    { ...enemyById.neutral_stone_wanderer, revealed: true },
    { suppressCounter: true },
    3,
  );
  assert.ok(solveArmor.notes.includes('pierce_armor'));
  assert.ok(solveEva.notes.includes('ignore_evasion'));
  assert.ok(solveInfo.notes.includes('suppressed_rule'));
});
