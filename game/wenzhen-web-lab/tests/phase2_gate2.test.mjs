/** Gate 2 · Phase 2 蛊角色整理与三套解法组合
 *  L0 2026-09-25：Build A/B/C 面对同一敌人至少两种有效行动结构；
 *  同一 Build 面对 Phase 1 三敌不能保持完全相同的动作序列。
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

const kits = Object.keys(rules.BUILD_KITS);
const axes = ['info', 'armor', 'evasion'];

test('Gate 2 · live gu carry build roles from the seven-role vocabulary', () => {
  const required = {
    small_light_gu: 'Information',
    moon_glow_gu: 'Support',
    white_boar_strength_gu: 'Transform',
    blood_farewell_gu: 'Finisher',
    moonlight_gu: 'Core',
    blood_droplet_gu: 'Core',
    vitality_grass_gu: 'Resource',
    stone_shell_gu: 'Defense',
  };
  for (const [id, role] of Object.entries(required)) {
    assert.equal(rules.buildRoleOf(id, guById), role, `${id} role`);
  }
  assert.ok(rules.BUILD_ROLES.includes('Core'));
  assert.ok(rules.BUILD_ROLES.includes('Finisher'));
});

test('Gate 2 · three minimum kits are complete and map to three problem axes', () => {
  assert.deepEqual(kits.sort(), ['kit_info_suppress', 'kit_pierce_burst', 'kit_stable_sustain']);
  const covered = new Set();
  for (const id of kits) {
    const kit = rules.kitById(id);
    assert.ok(kit.members.length >= 2, `${id} needs real members`);
    covered.add(kit.axis);
    // 组合必须改变解法，不能只是数字
    const verbs = kit.members.flatMap((mid) => rules.buildTagsOf(mid, guById));
    assert.ok(
      verbs.some((t) => ['inspect', 'suppress', 'armorBreak', 'ignoreEvasion', 'stable_hit', 'chip', 'sustain'].includes(t)),
      `${id} must carry solution verbs`,
    );
  }
  assert.equal(covered.size, 3);
});

test('Gate 2 · kit membership is reachable from live owned pool pieces', () => {
  // 不要求开局齐套，但成员必须是 live 真实蛊
  for (const id of kits) {
    const kit = rules.kitById(id);
    for (const mid of [...kit.members, ...kit.optional]) {
      assert.ok(guById[mid], `${id} member missing: ${mid}`);
    }
  }
  // 开局已含两套半：破甲爆发 / 稳定持续 / 信息侧的 inspect
  const start = {
    moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
    jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
  };
  assert.equal(rules.kitCoverage('kit_pierce_burst', start, guById).ok, true);
  assert.equal(rules.kitCoverage('kit_stable_sustain', start, guById).ok, true);
  const info = rules.kitCoverage('kit_info_suppress', start, guById);
  assert.equal(info.ok, false);
  assert.equal([...info.missing].join(','), 'moon_glow_gu');
});

test('Gate 2 · Build A/B/C vs the same enemy yield ≥2 distinct action structures', () => {
  for (const axis of axes) {
    const enemy = { problemAxis: axis };
    const sigs = kits.map((id) => rules.actionStructureFor(id, enemy).signature);
    const unique = new Set(sigs);
    assert.ok(unique.size >= 2, `axis ${axis} needs ≥2 structures, got ${sigs.join(' ;; ')}`);
  }
});

test('Gate 2 · one Build vs three Phase 1 enemies cannot keep one action sequence', () => {
  for (const kitId of kits) {
    const seqs = axes.map((axis) => rules.actionStructureFor(kitId, { problemAxis: axis }).steps.join('>'));
    const unique = new Set(seqs);
    assert.equal(unique.size, 3, `${kitId} must adapt to all three axes: ${seqs.join(' ;; ')}`);
  }
});

test('Gate 2 · numeric-only pile is not a kit member set', () => {
  // 纯数值 strike/shield 不得单独构成解法组合
  const numericOnly = ['blood_droplet_gu', 'force_gu', 'qi_atk_1_01_gu'];
  const verbs = numericOnly.flatMap((id) => rules.buildTagsOf(id, guById));
  assert.ok(!verbs.includes('inspect'));
  assert.ok(!verbs.includes('suppress'));
  assert.ok(!verbs.includes('armorBreak'));
  assert.ok(!verbs.includes('ignoreEvasion'));
});
