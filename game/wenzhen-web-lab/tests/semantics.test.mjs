// P2 Semantics Ready 批B 验收（RUL-2026-09-25-001 Q2 五条）：
// ① 30 值 role 曲线唯一真源 = balance.effect_budget.default_amount_by_role；
// ② kind 真源 = v1_battle（role→semantic kind），legacy amount 已标注（Godot 迁移批收敛）；
// ③ WORLD→LAB 投影可自动断言：projections.json 表 == 生成物 DATA.projections == 全量兜底落值；
// ④ MVP 覆写例外已显式登记（parent/policy/forbidWriteBack + 裁定点名四蛊）；
// ⑤ 未知 effect verb fail-fast（No Silent Fallback 冻结不变量）。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const readJSON = (p) => JSON.parse(fs.readFileSync(new URL(p, import.meta.url), 'utf8'));
const BAL = readJSON('../../data/balance.json');
const V1 = readJSON('../../data/v1_battle.json');
const PROJ = readJSON('../data/projections.json');
const GU = readJSON('../../data/gu.json');
const guEntities = Array.isArray(GU) ? GU : (GU.entities || GU.gu || []);

const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const DATA = dataContext.DATA;

const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
const GuRules = rulesContext.GuRules;

// RUL-2026-09-25-001 Q2 裁定直给值（WORLD 量纲）
const WORLD_CURVE = {
  attack: [4, 6, 8, 11, 16],
  defense: [4, 6, 8, 11, 16],
  healing: [3, 4, 6, 8, 12],
  logistics: [2, 3, 4, 6, 8],
  movement: [1, 1, 2, 2, 3],
  recon: [1, 1, 1, 1, 1],
};
const KIND_BY_ROLE = {
  attack: 'strike', defense: 'shield', healing: 'heal',
  movement: 'shift', recon: 'status', logistics: 'heal',
};

test('Q2-① role 曲线唯一真源：balance.effect_budget == 裁定 30 值', () => {
  assert.deepEqual(BAL.effect_budget.default_amount_by_role, WORLD_CURVE);
});

test('Q2-② kind 真源：v1_battle 声明 role→semantic kind；legacy amount 已标注待 Godot 迁移批收敛', () => {
  for (const [role, kind] of Object.entries(KIND_BY_ROLE)) {
    assert.equal(V1.default_effect_by_role[role].kind, kind, role);
  }
  assert.equal(V1._legacy_default_effect_by_role.status, 'legacy_godot_fallback_only');
});

test('Q2-③ WORLD→LAB 投影可自动断言：projections 表 == 生成物落库 == 全量兜底落值', () => {
  const item = PROJ.items.find((i) => i.id === 'PROJ-LAB-ROLE-CURVE-001');
  assert.ok(item, '缺 PROJ-LAB-ROLE-CURVE-001');
  assert.equal(item.parents[0], 'balance.effect_budget.default_amount_by_role');
  // vm 跨 realm 数组原型不同，用 JSON 规范化比较（与 check_projection.mjs 同口径）
  assert.equal(
    JSON.stringify(DATA.projections.role_curve_lab),
    JSON.stringify(item.value),
    '生成物内嵌投影与 projections.json 漂移',
  );

  // 全量断言：无显式 v1_effect 的战斗蛊，kind 来自 v1_battle 真源、amount 等于投影表
  const explicit = new Set(guEntities.filter((e) => e.v1_effect).map((e) => e.id));
  let checked = 0;
  for (const gu of DATA.gu) {
    if (explicit.has(gu.id) || gu.role === 'support') continue;
    const curve = item.value[gu.role];
    if (!curve) continue;
    const rank = Math.min(5, Math.max(1, Number(gu.rank || 1)));
    assert.equal(gu.effect.kind, KIND_BY_ROLE[gu.role], `${gu.id} kind`);
    assert.equal(Number(gu.effect.amount), curve[rank - 1], `${gu.id} amount@r${rank}`);
    checked += 1;
  }
  // DATA.gu 为白名单子集（当前 77 只），兜底落值可断言面约 47 只
  assert.ok(checked > 30, `兜底落值全量断言覆盖不足：checked=${checked}`);
});

test('Q2-④ MVP 覆写例外显式登记：parent/policy/forbidWriteBack + 裁定点名四蛊', () => {
  const item = PROJ.items.find((i) => i.id === 'PROJ-LAB-MVP-GU-EXCEPTION-001');
  assert.ok(item, '缺 PROJ-LAB-MVP-GU-EXCEPTION-001');
  assert.equal(item.parents[0], 'balance.effect_budget.default_amount_by_role');
  assert.equal(item.policy, 'explicit_projection_exception');
  assert.equal(item.forbidWriteBack, true);
  for (const g of ['moonlight_gu', 'small_light_gu', 'moon_glow_gu', 'white_boar_strength_gu']) {
    assert.ok(item.value.guRefs.includes(g), `裁定四蛊未登记：${g}`);
  }
});

test('Q2-⑤ 未知 effect verb fail-fast（No Silent Fallback）', () => {
  assert.throws(() => GuRules.effectPlan({ kind: 'mystery_verb' }), /unknown effect kind/);
});
