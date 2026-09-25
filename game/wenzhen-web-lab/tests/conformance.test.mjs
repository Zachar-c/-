// P3 Conformance Ready——第一批 C1–C5 断言（RUL-2026-09-25-001 Q4）。
// 全部放进现有 node --test，不引新框架。基准反转后的一致性口径：
//   game/data（真源）→ build_data 生成物 → Web Runtime；Godot 为参考资产。
// 跨 realm 对象一律 JSON 规范化比较（vm 数组原型不同）。
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const readJSON = (p) => JSON.parse(fs.readFileSync(new URL(p, import.meta.url), 'utf8'));
const BAL = readJSON('../../data/balance.json');
const GU = readJSON('../../data/gu.json');
const guEntities = Array.isArray(GU) ? GU : (GU.entities || GU.gu || []);
const guById = Object.fromEntries(guEntities.map((e) => [e.id, e]));
const V1 = readJSON('../../data/v1_battle.json');
const PROJ = readJSON('../data/projections.json');
const RUNTIME_RULES = readJSON('../../../lore/runtime/rules.json').rules;
const runtimeRuleIds = new Set(RUNTIME_RULES.map((r) => r.id));

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

const j = (v) => JSON.stringify(v);
const SLICE = ['moonlight_gu', 'small_light_gu', 'moon_glow_gu'];

// ---------- C1 数据生成一致性（月光切片：source → generated 不丢 entity、不改 id、不改关键语义字段） ----------

test('C1-1 切片三蛊：生成物保留 id/rank，effect 与源 v1_effect 逐字段一致（未被兜底替换）', () => {
  for (const id of SLICE) {
    const src = guById[id];
    assert.ok(src, `源缺 ${id}`);
    const out = dataGuById[id];
    assert.ok(out, `生成物缺 ${id}`);
    assert.equal(out.id, src.id, `${id} id 漂移`);
    assert.equal(Number(out.rank), Number(src.rank), `${id} rank 漂移`);
    assert.equal(j(out.effect), j(src.v1_effect), `${id} effect 与源 v1_effect 不一致`);
  }
});

test('C1-2 全量：凡源数据带显式 v1_effect 且入生成物的蛊，effect 不得被 role 兜底替换', () => {
  // P5-B2：显式 v1_effect 允许 amount-less——生成物按 kind→role 曲线投影补 amount
  // （PROJ-LAB-ROLE-CURVE-001），此处独立复算同一投影作为预期，防止静默换回兜底。
  const labCurve = PROJ.items.find((i) => i.id === 'PROJ-LAB-ROLE-CURVE-001')?.value;
  assert.ok(labCurve, '缺 PROJ-LAB-ROLE-CURVE-001');
  const KIND_TO_CURVE_ROLE = { strike: 'attack', shield: 'defense', heal: 'healing', shift: 'movement' };
  const AMOUNT_FREE_KINDS = new Set(['inspect']);
  let checked = 0;
  for (const gu of DATA.gu) {
    const src = guById[gu.id];
    if (!src?.v1_effect) continue;
    const expect = { ...src.v1_effect };
    if (expect.amount == null && !AMOUNT_FREE_KINDS.has(expect.kind)) {
      const curve = labCurve[KIND_TO_CURVE_ROLE[expect.kind]];
      assert.ok(curve, `${gu.id} kind ${expect.kind} 无曲线映射`);
      expect.amount = curve[Math.min(5, Math.max(1, Number(src.rank || 1))) - 1];
    }
    assert.equal(j(gu.effect), j(expect), `${gu.id} 显式效果被改写`);
    checked += 1;
  }
  assert.ok(checked >= 20, `显式效果一致性覆盖不足：checked=${checked}`);
});

test('C1-3 切片杀招：km_light_converge 的 recipe/effect 与源一致，组件 id 全部存在于蛊表', () => {
  const src = V1.kill_moves.find((k) => k.id === 'km_light_converge');
  const out = DATA.killMoves.find((k) => k.id === 'km_light_converge');
  assert.ok(src && out, 'km_light_converge 缺失');
  assert.deepEqual([...out.recipe], [...src.recipe], 'recipe 漂移');
  assert.equal(j(out.effect), j(src.effect), 'effect 漂移');
  for (const gid of out.recipe) assert.ok(dataGuById[gid], `recipe 组件 ${gid} 不在生成蛊表`);
});

// ---------- C2 Effect Execution Golden Cases（固定 state + effect → exact resulting state） ----------

const plan = (effect, context = {}) => JSON.parse(JSON.stringify(GuRules.effectPlan(effect, context)));

test('C2-1 单 verb Golden Cases（全量 plan 精确断言）', () => {
  assert.deepEqual(plan({ kind: 'strike', amount: 3 }), {
    damage: 3, heal: 0, block: 0, statuses: [], swordIntent: 0, support: null,
    inspect: false, suppressCounter: false, armorBreak: 0, ignoreEvasion: false,
  });
  assert.deepEqual(plan({ kind: 'shield', amount: 4 }).block, 4);
  assert.deepEqual(plan({ kind: 'grant_block', amount: 2 }).block, 2);
  assert.deepEqual(plan({ kind: 'heal', amount: 3 }).heal, 3);
  assert.deepEqual(plan({ kind: 'heal_and_strike', heal: 2, amount: 3 }), {
    damage: 3, heal: 2, block: 0, statuses: [], swordIntent: 0, support: null,
    inspect: false, suppressCounter: false, armorBreak: 0, ignoreEvasion: false,
  });
  assert.deepEqual(plan({ kind: 'status', name: 'marked', amount: 2 }).statuses,
    [{ name: 'marked', amount: 2 }]);
  assert.deepEqual(plan({ kind: 'shift' }).block, 1);
  assert.deepEqual(plan({ kind: 'sword_intent', amount: 2 }).swordIntent, 2);
  assert.deepEqual(plan({ kind: 'weaken_intent', amount: 3 }).intentWeaken, 3);
  assert.deepEqual(plan({ kind: 'inspect' }).inspect, true);
});

test('C2-2 上下文结算 Golden Cases：同流派支援 / consume_status 原子 / delay 先付后登记', () => {
  // 同流派支援：context.supports[context.school] 计入 damage
  assert.deepEqual(plan({ kind: 'strike', amount: 3 }, { school: 'light', supports: { light: 2 } }).damage, 5);
  // consume_status 原子结算：base + stacks × per_stack，一层落账
  const consumed = plan(
    { kind: 'strike', amount: 2, consume_status: { name: 'marked', per_stack: 1 } },
    { statusStacks: { marked: 3 } },
  );
  assert.equal(consumed.damage, 5);
  assert.equal(consumed.consumeStatus, 'marked');
  // delay：效果延后但 damage 口径不变、delayTurns 登记
  const delayed = plan({ kind: 'strike', amount: 4, delay: { turns: 2 } });
  assert.equal(delayed.damage, 4);
  assert.equal(delayed.delayTurns, 2);
  // support 声明（供下游编排放大）：落 plan.support
  assert.deepEqual(plan({ kind: 'strike', amount: 1, support_school: 'light', support_bonus: 2 }).support,
    { school: 'light', bonus: 2 });
});

test('C2-3 行为动词与复合效果：suppress/armorBreak/ignoreEvasion + composite 顺序结算', () => {
  const verbal = plan({ kind: 'strike', amount: 1, ignoreEvasion: true, suppress: true, armorBreak: 2 });
  assert.equal(verbal.ignoreEvasion, true);
  assert.equal(verbal.suppressCounter, true);
  assert.equal(verbal.armorBreak, 2);
  const composite = plan({ kind: 'composite', parts: [{ kind: 'strike', amount: 2 }, { kind: 'heal', amount: 1 }] });
  assert.equal(composite.damage, 2);
  assert.equal(composite.heal, 1);
});

test('C2-4 确定性：同 state + 同 effect 重复执行结果逐字节一致', () => {
  const effect = { kind: 'strike', amount: 3, consume_status: { name: 'marked', per_stack: 1 } };
  const ctx = { school: 'light', supports: { light: 1 }, statusStacks: { marked: 2 } };
  assert.equal(j(GuRules.effectPlan(effect, ctx)), j(GuRules.effectPlan(effect, ctx)));
});

// ---------- C3 Projection conformance（差异=可解释投影，非 magic number） ----------

test('C3-1 全部投影条目：parent 可解析 + forbidWriteBack + LAB_ONLY + 不触禁项', () => {
  const forbidden = /recipe|canonical|provenance|dao\b/i;
  const resolve = (path) => String(path).replace(/^balance\./, '').split('.')
    .reduce((o, k) => o?.[k], BAL);
  for (const item of PROJ.items) {
    assert.ok(Array.isArray(item.parents) && item.parents.length > 0, `${item.id} 缺 parents`);
    for (const p of item.parents) {
      assert.notEqual(resolve(p), undefined, `${item.id} parent ${p} 不在 balance.json`);
    }
    assert.equal(item.forbidWriteBack, true, `${item.id} 缺 forbidWriteBack`);
    assert.equal(item.authority, 'LAB_ONLY', `${item.id} 越权`);
    assert.doesNotMatch(item.childKey, forbidden, `${item.id} childKey 触禁项`);
  }
});

test('C3-2 预算投影链示例：WORLD rank1=40 → LAB 20× → 2（裁定示例链）', () => {
  assert.equal(BAL.rank_power_budget.budget_by_rank['1'], 40);
  assert.equal(DATA.worldBalance.rank_power_budget.budget_by_rank['1'], 40);
  assert.equal(BAL.rank_power_budget.budget_by_rank['1'] / 20, 2);
});

// ---------- C4 No Silent Fallback（删 binding 必失败，不得退回 generic strike） ----------

test('C4-1 Canon binding 在案：切片三蛊的 canon 实体与 verified 转数必须存在于 DATA.canon', () => {
  for (const id of SLICE) {
    const ent = DATA.canon.entities[id];
    assert.ok(ent, `Canon binding 缺失：${id}（lore/runtime 未编译或被移除）`);
    assert.equal(typeof ent.rank, 'number', `${id} canon rank 缺失`);
  }
});

test('C4-2 切片效果未静默退回 role 曲线：生成值 == 源值 且 ≠ 兜底曲线值', () => {
  const curve = PROJ.items.find((i) => i.id === 'PROJ-LAB-ROLE-CURVE-001').value;
  for (const id of SLICE) {
    const src = guById[id];
    const out = dataGuById[id];
    const fallback = curve[src.role][Math.min(5, Math.max(1, Number(src.rank || 1))) - 1];
    assert.equal(j(out.effect), j(src.v1_effect), `${id} 被静默兜底替换`);
    assert.notEqual(Number(out.effect.amount), fallback, `${id} amount 恰等于兜底值——兜底检测失效`);
  }
});

test('C4-3 未知 verb 与复合内未知 verb 一律抛错（不静默降级）', () => {
  assert.throws(() => GuRules.effectPlan({ kind: 'mystery_verb' }), /unknown effect kind/);
  assert.throws(
    () => GuRules.effectPlan({ kind: 'composite', parts: [{ kind: 'strike', amount: 1 }, { kind: 'mystery' }] }),
    /unknown effect kind/,
  );
});

// ---------- C5 Source Classification / Provenance（canon_driven_v1 必须带 Canon/Rule ref） ----------

const CAN_RE = /^CAN-[A-Z0-9]+(-[A-Z0-9]+)*$/;
const ANCHOR_RE = /^E:V[1-6]-\d{5,6}$/;
const RULE_RE = /^(REF|KM|PE|TRIB|DM|PR|VEN|DRM)-\d{3}$/;

function assertProvenance(entry, where) {
  const refs = [
    ...(entry.canon_refs || []),
    ...(entry.rule_refs || []),
  ];
  const anchors = entry.canon_anchors || [];
  assert.ok(
    refs.length > 0 || anchors.length > 0,
    `${where}：canon_driven_v1 缺任何 canon_ref/rule_ref/anchor`,
  );
  for (const r of refs) {
    assert.ok(CAN_RE.test(r) || RULE_RE.test(r), `${where}：引用 ${r} 格式不合法`);
    if (CAN_RE.test(r)) {
      assert.ok(runtimeRuleIds.has(r), `${where}：CAN 引用 ${r} 不在 lore/runtime/rules.json`);
    }
  }
  for (const a of anchors) assert.ok(ANCHOR_RE.test(a), `${where}：锚点 ${a} 格式不合法`);
}

test('C5-1 canon_driven_v1 内容必须携带合法 Canon/Rule ref，且引用可在 Canon Runtime 解析', () => {
  let classified = 0;
  for (const e of guEntities) {
    if (e.source_class !== 'canon_driven_v1') continue;
    assertProvenance(e, `gu.json ${e.id}`);
    classified += 1;
  }
  for (const km of V1.kill_moves) {
    if (km.source_class !== 'canon_driven_v1') continue;
    assertProvenance(km, `v1_battle ${km.id}`);
    classified += 1;
  }
  assert.ok(classified >= 3, `canon_driven_v1 分类种子不足：${classified}`);
});

test('C5-2 分类诚实性：original_game_content / school_derived 内容不得自称 canon_driven_v1', () => {
  for (const e of guEntities) {
    if (e.source === 'original_game_content' || e.source === 'school_derived') {
      assert.notEqual(e.source_class, 'canon_driven_v1', `${e.id} 分类矛盾`);
    }
  }
  for (const km of V1.kill_moves) {
    if (km.origin === 'original_game_content') {
      assert.notEqual(km.source_class, 'canon_driven_v1', `${km.id} 分类矛盾`);
    }
  }
});

test('C5-3 月光切片已分类为 canon_driven_v1（种子在案）', () => {
  for (const id of SLICE) {
    assert.equal(guById[id].source_class, 'canon_driven_v1', id);
  }
});

// ---------- C6 敌人持蛊化（P5-B1，RUL-2026-09-25-001 P5：先证明知识变成规则，再扩大数量） ----------

test('C6-1 敌人 attackSource=gu 的伤害杀招逐 intent 合成校验（Σ 压缩投影 == damage）', () => {
  const table = DATA.projections.enemy_attack_amount_by_gu_rank;
  assert.ok(table, '生成物缺敌方攻击投影（PROJ-LAB-ENEMY-ATTACK-001）');
  let checked = 0;
  for (const e of DATA.enemies) {
    assert.ok(e.attackSource === 'gu' || e.attackSource === 'innate', `${e.id} attackSource 非法`);
    if (e.attackSource !== 'gu') continue;
    assert.ok(Array.isArray(e.guRefs) && e.guRefs.length > 0, `${e.id} 持蛊敌人缺装载 guRefs`);
    const intents = [e.intent, ...(e.phases || []).flatMap((p) => p.intents || [])].filter(Boolean);
    for (const it of intents) {
      for (const gid of [...(it.guRefs || []), ...e.guRefs]) {
        assert.ok(dataGuById[gid], `${e.id} 引用蛊 ${gid} 不在生成物`);
      }
      const src = it.attackSource || e.attackSource;
      if (src !== 'gu' || !(Number(it.damage) > 0)) continue;
      assert.ok(Array.isArray(it.guRefs) && it.guRefs.length > 0, `${e.id}/${it.id} 伤害杀招缺 guRefs`);
      const sum = it.guRefs.reduce((acc, gid) => {
        const g = dataGuById[gid];
        return g.effect?.kind === 'strike' ? acc + Number(table[String(g.rank)]) : acc;
      }, 0);
      assert.equal(sum, Number(it.damage), `${e.id}/${it.id} 持蛊合成 Σ${sum} != damage ${it.damage}`);
      checked += 1;
    }
  }
  assert.ok(checked >= 20, `敌人杀招合成覆盖不足：checked=${checked}`);
});

test('C6-2 敌方攻击投影压缩不变量：≤ lab attack 曲线且单调不减', () => {
  const table = DATA.projections.enemy_attack_amount_by_gu_rank;
  const labCurve = DATA.projections.role_curve_lab.attack;
  let prev = 0;
  for (let r = 1; r <= 5; r++) {
    const t = Number(table[String(r)]);
    assert.ok(Number.isFinite(t), `缺 ${r} 转`);
    assert.ok(t <= labCurve[r - 1], `r${r}=${t} 超过 lab attack 曲线 ${labCurve[r - 1]}`);
    assert.ok(t >= prev, `r${r} 单调递减`);
    prev = t;
  }
});
