/* 公理与审计数据与 docs/*.md 同步；改文档时同步此表。 */
const AXIOMS = [
  {
    title: '转数到底约束什么',
    body: '转数不是装备等级。它同时是力量层级、使用门槛、资源层级、修为承载。同转允许垃圾→极品；允许优秀一转 > 垃圾二转。禁止「高转自动替换低转」。',
  },
  {
    title: '蛊虫价值不与转数等价',
    body: '分三层：本体能力 / 构筑价值 / 环境价值。priceGu 不得回答「最终值多少」，只回答「基础效果量级是否异常」。',
  },
  {
    title: '道决定资源与战斗逻辑',
    body: '道不是伤害染色。每道先答「依靠什么运行」：血道=气血伤势以伤换力；智道=念头信息决策优势；魂道=魂魄难恢复；力道=肉身承伤。禁止火道=火伤。',
  },
  {
    title: '蛊虫是元件，杀招是运行结构',
    body: '杀招 = 核心蛊+辅助蛊+发动顺序+状态条件+资源需求+规则关系+失败风险（含泄密/被破解）。成长靠换件改序改条件，不是 Lv+30% 伤害。',
  },
  {
    title: '修为扩大可承载力量',
    body: '修为首先扩大真元容量/质量、可催动层级、杀招复杂度、循环规模与可维持手段数。境界更高 = 能运行过去无法运行的体系，不是伤害 ×2。',
  },
  {
    title: '成长 = 不断重构力量体系',
    body: '获得→适配→入体系→淘汰/出售/炼化/喂养/材料→改杀招→新循环→修为→承载更高转。禁止退化成「攻击越来越高」。',
  },
  {
    title: '平衡单位是构筑路线',
    body: '平衡成熟构筑/路线/战斗体系，不是每只蛊同转公平。允许垃圾真垃圾、极品真极品；禁止某路线全面支配。问路线优劣与适用情境，不问 PP 是否相等。',
  },
  {
    title: 'Budget / PP 权限边界',
    body: 'Rank Budget、PP、priceGu、kitDpr、encounter = 数值工程校验工具（报警器，不是法律）。只找异常，不判优秀/该选/该淘汰/该削弱。',
  },
  {
    title: '升仙是凡人力量体系的总检验',
    body: '碎窍→三气→渡劫→平衡→蛊仙，检验整条凡人成长链是否只有「数字变大」。当前 MVP 只验证「换蛊→改构筑→改解法」，禁止本轮实现升仙，但不得堵死此路。',
  },
];

const AUDIT = [
  { tag: 'KEEP', name: 'kitDpr / deriveEnemy* / check_balance', note: '数学门禁与遭遇预算基线；不判好不好玩、强不强。' },
  { tag: 'KEEP', name: 'counterZeroRate', note: '仅 lab 遭遇估算；迎击 ≠ 整回合无效。' },
  { tag: 'KEEP', name: '转数质量门禁 / Rank Power Budget', note: '门槛 ≠ 品质；层级预算轴，禁止当万能伤害倍率。' },
  { tag: 'KEEP', name: '杀招：配方/化解/泄密/残锋/跨转', note: '已符合「元件 + 运行结构」；勿用 Lv+30% 覆盖。' },
  { tag: 'DEMOTE', name: 'balance.js / priceGu / PP / costTax', note: '降为数值工程校验工具；禁止裁定价值与公平。' },
  { tag: 'DEMOTE', name: 'MVP 月光/小光/月芒/白豕', note: '10 分钟实验组合；禁止反推「一转 ≈ 2 PP」模板。' },
  { tag: 'DEMOTE', name: '逆息 / 胜利回复 / 炼耗规则', note: 'LAB 阀门与 recipe rule；未经长期体验不得进 world。' },
  { tag: 'DEMOTE', name: 'fallback +1/转（741 只）', note: 'legacy compatibility fallback；暂不批量重标。' },
  { tag: 'CONFLICT', name: '同转价值 ±10% 平衡', note: '直接 REJECT：消灭品质差与淘汰替换。' },
  { tag: 'CONFLICT', name: 'priceGu = 终局价值', note: '与公理 2 冲突，已 DEMOTE。' },
  { tag: 'CONFLICT', name: '道 = 伤害颜色', note: '与公理 3 冲突；禁止按染色扩道。' },
  { tag: 'CONFLICT', name: '蛊 = 技能 / 杀招 = 大技能', note: '与公理 4 冲突。' },
  { tag: 'CONFLICT', name: '高转自动替换低转', note: '装备等级化，禁止。' },
  { tag: 'MISSING', name: '同转品质分档', note: '垃圾→极品；完整系统补，本轮不实现。' },
  { tag: 'MISSING', name: '各道独立资源/风险循环', note: '公理层已定义，引擎未齐。' },
  { tag: 'MISSING', name: '杀招自由重构生命周期', note: '换核/调序/改触发；Godot 有配方，重构未齐。' },
  { tag: 'MISSING', name: '修为 = 承载扩容模型', note: '仅有门禁与 stage_base。' },
  { tag: 'MISSING', name: '路线级平衡 / 升仙总检验链', note: '长期骨架；禁止本轮开发。' },
];

function renderAxioms() {
  const root = document.getElementById('axiom-list');
  root.innerHTML = AXIOMS.map(
    (a) => `<li><h3>${a.title}</h3><p>${a.body}</p></li>`,
  ).join('');
}

function renderAudit(filter = 'ALL') {
  const root = document.getElementById('audit-list');
  root.innerHTML = AUDIT.map((row) => {
    const hide = filter !== 'ALL' && row.tag !== filter ? ' hidden' : '';
    return `<div class="audit-row${hide}" data-tag="${row.tag}">
      <span class="badge ${row.tag}">${row.tag}</span>
      <div><strong>${row.name}</strong><span>${row.note}</span></div>
    </div>`;
  }).join('');
}

function renderFilters() {
  const tags = ['ALL', 'KEEP', 'DEMOTE', 'CONFLICT', 'MISSING'];
  const root = document.getElementById('filters');
  root.innerHTML = tags
    .map((t) => `<button type="button" data-tag="${t}" class="${t === 'ALL' ? 'active' : ''}">${t}</button>`)
    .join('');
  root.addEventListener('click', (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;
    root.querySelectorAll('button').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    renderAudit(btn.dataset.tag);
  });
}

renderAxioms();
renderFilters();
renderAudit();
