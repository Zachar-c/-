// P4 换皮测试（Mechanic Distinctness，RUL-2026-09-25-001 GATE ⑥ / L1 计划 §19-20）：
// 把名称/文案从判定路径中剥离后，月光切片的行为仍可辨识、结算仍由结构与组件驱动。
// - 三蛊两两行为可区分（隐藏名称后凭 effect 签名辨认，不是 strike 3 → strike 4）；
// - 杀招结算只吃 recipe ids + 组件 effect + school，标签改名不改变结果（预制 effect 不驱动）；
// - Canon 关系按 id 绑定（supports / refinement），换皮不断链；
// - GATE ③：切片关键字段无 UNKNOWN/占位。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const j = (v) => JSON.stringify(v);
const readJSON = (p) => JSON.parse(fs.readFileSync(new URL(p, import.meta.url), 'utf8'));
const GU = readJSON('../../data/gu.json');
const guEntities = Array.isArray(GU) ? GU : (GU.entities || GU.gu || []);
const guById = Object.fromEntries(guEntities.map((e) => [e.id, e]));
const SLICE = ['moonlight_gu', 'small_light_gu', 'moon_glow_gu'];

const dataContext = vm.createContext({});
vm.runInContext(
  fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
  dataContext,
);
const DATA = dataContext.DATA;
const dataGuById = Object.fromEntries(DATA.gu.map((g) => [g.id, g]));

const rulesContext = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/gu_rules.js', import.meta.url), 'utf8'), rulesContext);
const GuRules = rulesContext.GuRules;

const buildGuById = (mutateName) => Object.fromEntries(
  SLICE.map((id) => {
    const g = dataGuById[id];
    return [id, {
      id: mutateName ? `${id}__anon` : id,
      name: mutateName ? id : g.name,
      school: g.school,
      rank: g.rank,
      v1_effect: g.effect,
    }];
  }),
);

const MOVE = DATA.killMoves.find((k) => k.id === 'km_light_converge');

test('换皮-1 三蛊两两行为可辨识：隐藏名称后 effect 签名仍互不相同', () => {
  const sigs = SLICE.map((id) => {
    const e = dataGuById[id].effect;
    // 签名只含行为字段（不含名称/文案）
    return j({
      kind: e.kind, amount: e.amount, ignoreEvasion: !!e.ignoreEvasion,
      suppress: !!(e.suppress || e.suppressWhenRevealed), inspect: !!e.inspect,
      support_school: e.support_school || null, support_bonus: e.support_bonus || null,
    });
  });
  assert.equal(new Set(sigs).size, 3, `行为签名趋同：${sigs.join(' | ')}`);
});

test('换皮-2 杀招结算与标签无关：全部改名后组件合成结果逐字节一致，且预制 effect 不驱动', () => {
  const named = GuRules.killMoveEffectPlan(MOVE, buildGuById(false), { school: 'light' });
  const anon = GuRules.killMoveEffectPlan(MOVE, buildGuById(true), { school: 'light' });
  assert.equal(j(anon), j(named), '改名改变结算——标签泄漏进语义');
  // 组件合成 = 月光 strike 3 + 小光 strike 1 = 4；预制 effect(strike 5)/damage(0) 不驱动结算
  assert.equal(named.damage, 4);
  assert.equal(named.components.filter((c) => c.applied).length, 2);
  assert.notEqual(named.damage, MOVE.effect.amount, '预制 effect 竟然驱动了结算');
});

test('换皮-3 Canon 关系按 id 绑定：supports 与 refinement 换皮后仍成立', () => {
  const rels = DATA.canon.relations;
  const support = rels.find((r) => r.relation === 'supports'
    && r.from === 'small_light_gu' && r.to === 'moonlight_gu');
  assert.ok(support, '缺 小光→月光 supports 关系');
  const refine = rels.find((r) => r.relation === 'refinement'
    && r.output === 'moon_glow_gu'
    && JSON.stringify([...r.inputs].sort()) === JSON.stringify(['moonlight_gu', 'small_light_gu', 'small_light_gu']));
  assert.ok(refine, '缺 月光+双小光→月芒 refinement 关系');
  assert.equal(refine.output_rank, 2);
});

test('GATE-③ 切片关键字段无 UNKNOWN/占位', () => {
  for (const id of SLICE) {
    const src = guById[id];
    assert.equal(typeof src.rank, 'number', `${id} rank 缺失`);
    assert.ok(src.role && src.school, `${id} role/school 缺失`);
    assert.ok(src.v1_effect && src.v1_effect.kind, `${id} v1_effect 缺失`);
    assert.doesNotMatch(j(src.v1_effect), /UNKNOWN|TODO|占位|裸名/, `${id} v1_effect 含占位`);
    const out = DATA.gu.find((g) => g.id === id);
    assert.ok(out && out.effect && out.effect.kind, `${id} 生成物效果缺失`);
  }
});
