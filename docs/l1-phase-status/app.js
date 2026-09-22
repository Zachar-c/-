const PHASES = [
  {
    s: 'ok',
    t: 'PHASE1 · Projection validator',
    p: '26/26。schema：id/parents[]/scope/rationale/authority/validation/forbidWriteBack。禁投影炼方组成（C3 canonical=月光+小光×2）。',
    c: 'node tools/check_projection.mjs',
  },
  {
    s: 'ok',
    t: 'PHASE2 · Rank 纵轴 8 字段',
    p: 'rank / essence_tier / gu_rank_cap / cross_rank_cost_curve / killer_move_complexity_cap / refinement_rank_cap / maintenance_capacity / progression_access_tier。全部 mult=false；低转禁价值折损。',
    c: 'data/rank_runtime.json',
  },
  {
    s: 'alarm',
    t: 'PHASE3 · 购买力四轴',
    p: '门禁已上（几场 I_r）。ALARM：R1 蛊价 40/I3=13.3 场 TOO_EXPENSIVE（目标 1.5–2.5）；R1→R2 突破 5/3=1.67 场 TOO_CHEAP。只报警不改价。R2–R5 待 IncomeCurve 独立接线。',
    c: 'node tools/check_l1_phases.mjs',
  },
  {
    s: 'ok',
    t: 'PHASE4 · 杀招组件一致性（B）',
    p: '保留 declared damage；组件和×coordination（0.85–1.15）±15% 或 override_reason。km_force_avalanche 已标注迁移债。未重写 26 条。',
    c: 'data/v1_battle.json override_reason',
  },
  {
    s: 'ok',
    t: 'PHASE5 · Counter 权限边界',
    p: 'primitive_only_not_skeleton；六门准入含 SOURCE；词表白名单冻结 6 项。',
    c: 'node --test tests/l1_boundaries.test.mjs',
  },
];

const leave = ['黄金/紫晶×10', '高转经济倍数', '跨转×2', '五转出现率'];

document.getElementById('main').innerHTML =
  PHASES.map(
    (x) => `<div class="row">
      <div class="badge ${x.s}">${x.s === 'ok' ? 'OK' : 'ALARM'}</div>
      <div><h2>${x.t}</h2><p>${x.p}</p><p><code>${x.c}</code></p></div>
    </div>`
  ).join('') +
  `<div class="row"><div class="badge ok">HOLD</div>
   <div><h2>留白（禁止代填）</h2><p>${leave.join(' · ')}</p>
   <p>C6：系统测试须 R1→R5 连续；正式一局结构 UNRESOLVED。</p></div></div>`;
