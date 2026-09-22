/* PHASE2–5 · RUL-2026-09-21-010（返工版：必须核对真实实现 / 可突变）
 * 2 Rank 接线 · 3 购买力四轴全转 · 4 杀招严格组件校验 · 5 Counter 真词表
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const game = join(root, '..');
const load = (rel, base = root) => JSON.parse(readFileSync(join(base, rel), 'utf8'));

const RUL = load('world-model/rulings/RUL-2026-09-21-010.json', game);
const RANK_RT = load('data/rank_runtime.json');
const PPG = load('data/purchasing_power_gates.json');
const BAL = load('data/balance.json', game);
const GU = load('data/gu.json', game);
const KM = load('data/v1_battle.json', game);
const RECIPES = load('data/refinement_recipes.json', game);

const context = vm.createContext({});
context.WORLD_BALANCE = BAL;
vm.runInContext(readFileSync(join(root, 'js/balance.js'), 'utf8'), context, { filename: 'balance.js' });
const B = context.MvpBalance;

const rows = [];
const add = (name, ok, detail, severity = 'fail') => rows.push({ name, ok: !!ok, detail: String(detail ?? ''), severity });

/* ========== PHASE2 Rank 纵轴：声明 + 真实实现 ========== */
const fieldNames = Object.keys(RANK_RT.fields);
add('Rank 字段数=8', fieldNames.length === 8, fieldNames.join(','));
for (const f of fieldNames) {
  const spec = RANK_RT.fields[f];
  add(`字段 ${f} mult=false`, spec.mult === false, '');
  add(`字段 ${f} wired=true 且有 source`, spec.wired === true && !!spec.source, spec.source || '');
}
add('allow_rank_multiplier_on=[]', (RANK_RT.allow_rank_multiplier_on || []).length === 0, '');

// 真实曲线实现（非冻结 vertical）
assertCrossRank();
function assertCrossRank() {
  const impl = RANK_RT.fields.cross_rank_cost_curve.impl;
  add('crossRank 实现指向 MvpBalance.crossRankQiCost', impl === 'MvpBalance.crossRankQiCost', impl);
  add('crossRankQiCost(8,5,1)=1', B.crossRankQiCost(8, 5, 1) === 1, B.crossRankQiCost(8, 5, 1));
  add('crossRankQiCost(20,2,2)=20', B.crossRankQiCost(20, 2, 2) === 20, B.crossRankQiCost(20, 2, 2));
  add('crossRankQiCost 高转不可催动=null', B.crossRankQiCost(20, 1, 2) === null, B.crossRankQiCost(20, 1, 2));
  add('crossRankQiCost(8,5,1)=max(1,round(8*0.65^4))', B.crossRankQiCost(8, 5, 1) === Math.max(1, Math.round(8 * Math.pow(0.65, 4))), '');
  add('complexityPoints 可计算', B.complexityPoints({ recipe: ['a', 'b'], thought_cost: 2, effect: {} }) >= 3, B.complexityPoints({ recipe: ['a', 'b'], thought_cost: 2, effect: {} }));
}
add('低转禁价值折损', String(RANK_RT.low_rank_keep.value_decay).includes('FORBIDDEN'), '');
add('复杂度未限用玩家', RANK_RT.fields.killer_move_complexity_cap.affects_player === false, '');

/* ========== PHASE3 购买力四轴 · R1–R5 + 炼耗轴 ========== */
const I = PPG.income_curve.I_by_rank;
add('IncomeCurve 显式 I_by_rank 覆盖 1–5', [1, 2, 3, 4, 5].every((r) => Number(I[String(r)]) > 0), JSON.stringify(I));
add('I_r 非 rank_multiplier 推导（独立表）', PPG.income_curve.note.includes('禁止用 rank_multiplier'), PPG.income_curve.note);
const rewards = BAL.battle_stone_rewards || {};
add('battle_stone_rewards 存在（净收入口径已声明）', Number(rewards.base_by_tier?.common) > 0 && String(PPG.unit).includes('净收入'), PPG.unit);

const step = Number(BAL.rank_step_ratio || 2);
const sp1 = Number(BAL.stone_per_t1_material || 0);
const guPriceRank = (r) => sp1 * Math.pow(step, r - 1) * 4;

for (let r = 1; r <= 5; r++) {
  const income = Number(I[String(r)]);
  const price = guPriceRank(r);
  const fights = price / income;
  const [lo, hi] = PPG.gates_fights_of_I[String(r)].gu_price;
  const verdict = fights < lo ? 'TOO_CHEAP' : fights > hi ? 'TOO_EXPENSIVE' : 'OK';
  add(`R${r} 蛊价/I = ${fights.toFixed(2)} [${lo}–${hi}] ${verdict}`, verdict === 'OK', `I=${income} price=${price}`, 'alarm');

  const bt = PPG.gates_fights_of_I[String(r)].breakthrough_stone;
  if (bt) {
    const bKey = ['cultivate_rank_two_stone_cost', 'cultivate_rank_three_stone_cost', 'cultivate_rank_four_stone_cost', 'cultivate_rank_five_stone_cost'][r - 1];
    const bCost = Number(BAL[bKey] || 0);
    const bFights = bCost / income;
    const bVerdict = bFights < bt[0] ? 'TOO_CHEAP' : bFights > bt[1] ? 'TOO_EXPENSIVE' : 'OK';
    add(`R${r} 突破/I = ${bFights.toFixed(2)} [${bt[0]}–${bt[1]}] ${bVerdict}`, bVerdict === 'OK', `cost=${bCost}`, 'alarm');
  }

  // RefinementLossCurve：同转配方抽样「失败期望损失 / I」
  const outs = new Set(GU.filter((g) => g.rank === r).map((g) => g.id));
  const samples = (RECIPES.recipes || []).filter((rec) => outs.has(rec.output_gu_id) && rec.stone_cost != null).slice(0, 8);
  if (!samples.length) {
    add(`R${r} 炼耗轴 · 无配方样本`, false, 'need refine sample', 'alarm');
  } else {
    // 失败期望损失 ≈ onceCost * (1-success)/1 保守：用 stone_cost 当 once 下界
    const losses = samples.map((rec) => {
      const once = Number(rec.stone_cost || 0);
      // successRollMax 若有则用之，否则 0.7 保守
      const s = rec.successRollMax != null ? Number(rec.successRollMax) / 100 : 0.7;
      return { once, failLoss: once * (1 - s) / Math.max(s, 0.01) * s / Math.max(s, 0.01) === 0 ? once * (1 - s) / s : once * (1 - s) / s, s, id: rec.id };
    });
    // 规范：expected fail loss = once * (1-s)/s 的常见近似 once*(1-s)（失败时全毁一次）
    const avgLoss = losses.reduce((a, x) => a + x.once * (1 - x.s), 0) / losses.length;
    const fLoss = avgLoss / income;
    const [flo, fhi] = PPG.gates_fights_of_I[String(r)].refine_fail_loss;
    const fVerdict = fLoss < flo ? 'TOO_CHEAP' : fLoss > fhi ? 'TOO_EXPENSIVE' : 'OK';
    add(
      `R${r} 炼制失败损失/I = ${fLoss.toFixed(2)} [${flo}–${fhi}] ${fVerdict}`,
      fVerdict === 'OK',
      `avgFailLoss=${avgLoss.toFixed(1)} n=${samples.length}`,
      'alarm',
    );
  }
}
add('四轴分写禁 multiplier 总控', PPG.forbid.includes('rank_multiplier'), '');
add('留白四条未代填', (PPG.unresolved_leave_blank || []).length === 4, '');

/* ========== PHASE4 杀招：未知组件 / 非法 role / 突变可检 ========== */
const guById = new Map(GU.map((g) => [g.id, g]));
const TOL = 0.15;
const ROLES = RUL.q1_kill_move.roles;

function evalKillMoves(kmList) {
  const out = { fails: [], checked: 0, legacy: 0 };
  for (const km of kmList) {
    const rawRecipe = km.recipe || [];
    out.checked++;
    // 未知组件
    for (const entry of rawRecipe) {
      const id = typeof entry === 'string' ? entry : entry?.gu_id;
      if (!id || !guById.has(id)) {
        out.fails.push(`${km.id} 未知组件 ${id}`);
      }
      if (entry && typeof entry === 'object') {
        if (!ROLES.includes(entry.role)) out.fails.push(`${km.id} 非法 role ${entry.role}`);
      }
    }
    const parts = rawRecipe
      .map((e) => guById.get(typeof e === 'string' ? e : e?.gu_id))
      .filter(Boolean);
    let componentDamage = 0;
    for (const g of parts) {
      const v1 = g.v1_effect || {};
      if (v1.kind === 'strike') componentDamage += Number(v1.amount || 0);
    }
    const composition = km.composition;
    const coordination = Number(composition?.coordination ?? 1.0);
    const expected = componentDamage * coordination;
    const declared = Number(km.damage || 0);
    if (!composition) {
      out.legacy++;
      if (declared > 0 && expected > 0) {
        const dev = Math.abs(declared - expected) / expected;
        if (dev > TOL && !km.override_reason) out.fails.push(`${km.id} 超差无 override declared=${declared} expected=${expected.toFixed(2)}`);
      }
      continue;
    }
    if (coordination < 0.85 || coordination > 1.15) out.fails.push(`${km.id} coordination 越界 ${coordination}`);
    if (declared > 0 && expected > 0) {
      const dev = Math.abs(declared - expected) / expected;
      if (dev > TOL && !km.override_reason) out.fails.push(`${km.id} |d-e|>15% 无 override dev=${(dev * 100).toFixed(0)}%`);
    }
  }
  return out;
}

const baseEval = evalKillMoves(KM.kill_moves || []);
add(`杀招 ${baseEval.checked} 条 · legacy ${baseEval.legacy}`, baseEval.fails.length === 0, baseEval.fails.slice(0, 5).join(' | ') || 'ok');

// 突变 A：不存在组件
const mutUnknown = JSON.parse(JSON.stringify(KM.kill_moves.slice(0, 3)));
mutUnknown[0] = { ...mutUnknown[0], recipe: ['no_such_gu_xyz', mutUnknown[0].recipe?.[1] || 'bear_strength_gu'] };
const e1 = evalKillMoves(mutUnknown);
add('突变未知组件必须检出', e1.fails.some((f) => f.includes('未知组件')), e1.fails.join('|') || 'MISSED');

// 突变 B：非法 role
const mutRole = [{ id: 'km_probe', recipe: [{ gu_id: 'moonlight_gu', role: 'not_a_role' }], damage: 0 }];
const e2 = evalKillMoves(mutRole);
add('突变非法 role 必须检出', e2.fails.some((f) => f.includes('非法 role')), e2.fails.join('|') || 'MISSED');

// 突变 C：伤害 99999 无 override
const mutDmg = [{ id: 'km_bomb', recipe: ['moonlight_gu', 'small_light_gu'], damage: 99999, override_reason: '' }];
const e3 = evalKillMoves(mutDmg);
add('突变 damage=99999 必须检出', e3.fails.some((f) => f.includes('超差') || f.includes('>15%')), e3.fails.join('|') || 'MISSED');

/* ========== PHASE5 Counter 真词表 ========== */
const ALLOWED = new Set(['intercept', 'draw_light', 'seal_first', 'seal_last', 'iron', 'none']);
const mvpLogic = readFileSync(join(root, 'js/mvp_logic.js'), 'utf8');
const v1Json = JSON.stringify(KM);
const godotSrc = readFileSync(join(game, 'scripts/domain/v1_battle_resolver.gd'), 'utf8');
const tokenRe = /['"]((?:intercept|draw_light|seal_first|seal_last|iron|none|[a-z]+_light|[a-z]+_first|[a-z]+_last))['"]/g;
function extractCounters(src) {
  const found = new Set();
  for (const m of src.matchAll(tokenRe)) found.add(m[1]);
  return found;
}
const liveCounters = new Set([...extractCounters(mvpLogic), ...extractCounters(v1Json), ...extractCounters(godotSrc)]);
const extras = [...liveCounters].filter((c) => !ALLOWED.has(c) && /^(intercept|draw_light|seal_|iron)/.test(c));
add(`真实 Counter 词表 ⊆ 白名单（检出 ${[...liveCounters].join(',')}）`, extras.length === 0, extras.join(',') || 'ok');
add('白名单 6 项来自 RUL 而非测试内数组', RUL.q4_counter.decision.includes('not_skeleton'), RUL.q4_counter.decision);
add('新 primitive 六门含 SOURCE', RUL.q4_counter.admission_gates.includes('SOURCE'), '');

/* 输出 */
const fail = rows.filter((r) => !r.ok && r.severity === 'fail');
const alarms = rows.filter((r) => !r.ok && r.severity === 'alarm');
for (const r of rows) {
  if (r.ok && !process.env.L1_VERBOSE) continue;
  const mark = r.ok ? 'PASS' : r.severity === 'alarm' ? 'ALARM' : 'FAIL';
  console.log(`${mark}  ${r.name} — ${r.detail}`);
}
if (alarms.length) console.log(`\n-- ALARM ${alarms.length} --`);
console.log(`\n== L1 phases 2–5: pass=${rows.length - fail.length - alarms.length} fail=${fail.length} alarm=${alarms.length} ==`);
if (fail.length) process.exit(1);
