// Context Pack 消费一致性（P4 原型）：
// 场景 = 南疆一转战斗（MVP 四蛊）。断言 pack 是 canon runtime 的自洽子集、
// 覆盖该场景真实决策所需的最小规则集、且保持小体积（700 万字是冷库，prompt 只拿 14KB）。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const readJson = (rel) => JSON.parse(
  fs.readFileSync(new URL(rel, import.meta.url), 'utf8'));

const pack = readJson('../../../lore/runtime/packs/south_border_rank1_combat.json');
const manifest = readJson('../../../lore/runtime/manifest.json');
const canon = readJson('../../../lore/runtime/entities.json');
const canonRules = readJson('../../../lore/runtime/rules.json');

// Stage 1 战斗场景定义（与 js/balance.js 的 MVP 组合、js/main.js READY.owned 对应）。
const SCENE_GU = ['moonlight_gu', 'small_light_gu', 'moon_glow_gu', 'white_boar_strength_gu'];
// 场景决策最小规则集（与 lore/wiki/tools/benchmark-runtime-stage1.md 判分依据一致）。
const SCENE_RULES = [
  'CAN-RANK-LADDER-001', 'CAN-CULTIVATION-001', 'CAN-CULTIVATION-002',
  'CAN-APTITUDE-001', 'CAN-APTITUDE-003', 'CAN-BEAST-TIER-001', 'CAN-BEAST-TIER-003',
  'CAN-BEAST-TIDE-001', 'CAN-BEAST-TIDE-002', 'CAN-SMALL-LIGHT-001', 'CAN-GU-CARE-001',
  'PE-001', 'PE-002', 'PE-004', 'KM-002', 'KM-003', 'REF-002', 'REF-004',
];

test('pack is bound to the compiled runtime source', () => {
  assert.equal(pack.source.sha256, manifest.source.sha256);
  assert.equal(pack.source.lines, manifest.source.lines);
});

test('scene gu are present with canon rank and status', () => {
  const ids = new Set(pack.entities.map((e) => e.id));
  for (const id of SCENE_GU) {
    assert.ok(ids.has(id), `场景蛊 ${id} 不在 pack`);
    const e = pack.entities.find((x) => x.id === id);
    assert.equal(e.properties.rank_status, 'verified', id);
  }
  assert.equal(pack.entities.find((x) => x.id === 'moonlight_gu').properties.rank, 1);
  assert.equal(pack.entities.find((x) => x.id === 'moon_glow_gu').properties.rank, 2);
});

test('scene-critical rules are packed', () => {
  const ids = new Set(pack.rules.map((r) => r.id));
  const missing = SCENE_RULES.filter((id) => !ids.has(id));
  assert.deepEqual(missing, []);
});

test('pack facts carry evidence and provenance (traceability)', () => {
  for (const e of pack.entities) assert.ok(e.evidence.length > 0, `${e.id} 无 E-ID`);
  for (const r of pack.rules) {
    assert.ok(r.evidence.length > 0 || r.source_line_refs?.length || r.evidence_raw,
      `${r.id} 无证据`);
  }
  for (const r of pack.relations) assert.ok(r.evidence.length > 0, r.id);
});

test('pack is a strict subset of the canon runtime (no new facts)', () => {
  const canonIds = new Set(canon.entities.map((e) => e.id));
  const canonRuleIds = new Set(canonRules.rules.map((r) => r.id));
  for (const e of pack.entities) assert.ok(canonIds.has(e.id), e.id);
  for (const r of pack.rules) assert.ok(canonRuleIds.has(r.id), r.id);
});

test('immortal-stage content stays out of the mortal rank-1 pack', () => {
  const ids = new Set(pack.rules.map((r) => r.id));
  assert.ok(!ids.has('PE-006'), '仙元形成规则属蛊仙层');
  assert.ok(!ids.has('PE-007'), '仙元阶位规则属蛊仙层');
  // P5-B4：PE-008（仙元阶位·转数关联，778db228 批新增）同样属蛊仙层，经 true-qi 域
  // 漏入过一转包，2026-09-26 由 compile_runtime rule_exclude_ids 根治——断言常驻防回归。
  assert.ok(!ids.has('PE-008'), '仙元阶位（转数关联）规则属蛊仙层');
  assert.ok(!ids.has('CAN-ASCENSION-001'), '升仙框架不进凡人战斗包');
});

test('support and refinement relations are packed', () => {
  const ids = new Set(pack.relations.map((r) => r.id));
  assert.ok(ids.has('REL-SMALLLIGHT-MOONLIGHT-SUPPORT'));
  assert.ok(ids.has('REL-REFINE-MOONGLOW'));
});

test('pack stays small enough to load as prompt context', () => {
  const chars = JSON.stringify(pack).length;
  assert.ok(chars < 20000, `pack 体积 ${chars} 字符，超出预算 20000`);
});
