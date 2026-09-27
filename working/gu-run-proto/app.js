/* 问真 · 一局蛊途 · 开发顺序②
   把蛊战接进一局：路线 / 战损 / 补给 / 炼蛊取舍
   数值源：docs/design/rank1-9-model/parameters.json（见 params.js） */

const MODEL = window.MODEL;

// 只有已核的合炼关系属于 Canon；抄方价格、破境成本与战斗效果是原型设计。
const RECIPES = {
  moonglow: { name: '月芒方', input: '月光蛊 + 两只小光蛊', result: '二转月芒蛊', source: 'ST-MOONGLOW-03 · E:V1-017144' },
  whitejade: { name: '白玉方', input: '玉皮蛊 + 白豕蛊', result: '二转白玉蛊', source: 'lore/wiki/world/gu-care-and-refinement.md:15710 · lore/wiki/gu/roster-3.md:white_jade_gu' },
};
const META_KEY = 'wenzhen_gu_run_recipes_v1';
const CHECKPOINT_KEY = 'wenzhen_gu_run_checkpoint_v1';
const CHECKPOINT_VERSION = 1;
function loadMeta() {
  try {
    const saved = JSON.parse(localStorage.getItem(META_KEY) || '{}');
    const completed = Number.isInteger(saved.completed) && saved.completed >= 0 ? saved.completed : 0;
    return { life: completed + 1, completed,
      known: Array.isArray(saved.known) ? [...new Set(saved.known.filter((id) => RECIPES[id]))] : [] };
  } catch { return { life: 1, completed: 0, known: [] }; }
}
let meta = loadMeta();
function saveMeta() {
  try { localStorage.setItem(META_KEY, JSON.stringify(meta)); } catch { /* file:// or private mode may block storage */ }
}
function knowsRecipe(id) { return meta.known.includes(id) || run.learnedThisLife.includes(id); }
const seedParam = Number(new URLSearchParams(location.search).get('seed'));
const baseSeed = Number.isInteger(seedParam) && seedParam > 0 ? seedParam >>> 0 : 20260927;
function random01() {
  run.randomState ^= run.randomState << 13;
  run.randomState ^= run.randomState >>> 17;
  run.randomState ^= run.randomState << 5;
  return (run.randomState >>> 0) / 4294967296;
}

const ECO = {
  startingWallet: MODEL.economy.startingWallet,
  recoverFullHp: MODEL.economy.recoverFullHp,
  mortalRefillPerPoint: MODEL.economy.mortalRefillPerPoint,
  foodPerGu: MODEL.economy.foodPerGu,
  guCount: MODEL.economy.guCount,
  fieldCost: MODEL.economy.fieldCost,
  refinementFee: MODEL.economy.refinementFee,
  grossPerPeriod: MODEL.economy.grossPerPeriod,
  resaleFraction: 0.35,
  failureSalvageFraction: 0.25,
};

const A = MODEL.aptitude.value;
const HP_MAX = MODEL.combat.baseHp;
const MP_MAX = Math.round(100 * A);
// 一转心智容量 C=4（模型 thoughtCapacity[0]）：出战编制上限
const READY_MAX = 4;

const GU = {
  fist: {
    id: 'fist',
    name: '拳脚（基础）',
    ap: MODEL.actions.basic.ap,
    cost: MODEL.actions.basic.mortalCost,
    desc: `伤害 ${MODEL.actions.basic.damage} · 0 真元`,
    kind: 'atk',
    dmg: MODEL.actions.basic.damage,
    cls: 'basic',
  },
  moon: {
    id: 'moon',
    name: '月光蛊 · 月刃',
    ap: MODEL.actions.strike.ap,
    cost: MODEL.actions.strike.mortalCost,
    desc: `标准攻 ${MODEL.actions.strike.damage} · 真元 ${MODEL.actions.strike.mortalCost}`,
    kind: 'atk',
    dmg: MODEL.actions.strike.damage,
    cls: 'strike',
  },
  small: {
    id: 'small',
    name: '小光蛊',
    ap: 0,
    cost: 0,
    desc: '与月光同催 → 月刃×2（[Canon] 协同；组合名 [Design]）',
    kind: 'amp',
    dmg: 0,
    cls: 'none',
  },
  jade: {
    id: 'jade',
    name: '玉皮蛊',
    ap: MODEL.actions.guard.ap,
    cost: MODEL.actions.guard.mortalCost,
    desc: `护盾 ${MODEL.actions.guard.block} · 真元 ${MODEL.actions.guard.mortalCost}`,
    kind: 'def',
    shield: MODEL.actions.guard.block,
    cls: 'none',
  },
  boar: {
    id: 'boar',
    name: '白豕蛊 · 爆发',
    ap: MODEL.actions.burst.ap,
    cost: MODEL.actions.burst.mortalCost,
    desc: `爆发 ${MODEL.actions.burst.damage} · 真元 ${MODEL.actions.burst.mortalCost} · 冷却 ${MODEL.actions.burst.cooldown}`,
    kind: 'atk',
    dmg: MODEL.actions.burst.damage,
    cls: 'burst',
    burst: true,
    cooldown: MODEL.actions.burst.cooldown,
  },
  // —— 扩充：同一套模型预算下的不同打法 ——
  moonray: {
    id: 'moonray',
    name: '月痕蛊',
    ap: 1,
    cost: 6,
    desc: `远程 ${MODEL.actions.strike.damage} 伤 · [Canon] 距加倍攻不变；[Design] 耗 6 元`,
    kind: 'atk',
    dmg: MODEL.actions.strike.damage,
    cls: 'strike',
  },
  vine: {
    id: 'vine',
    name: '青藤蛊',
    ap: 1,
    cost: 8,
    desc: '藤鞭 18 伤 · 并令敌下一击 −8（控制递减外的固定减伤一回合）',
    kind: 'atk',
    dmg: 18,
    cls: 'strike',
    weaken: 8,
  },
  herb: {
    id: 'herb',
    name: '生机草',
    ap: 1,
    cost: 6,
    desc: '回 22 耐受 · 即时治疗按模型预算 1.5× 代价意识设计',
    kind: 'heal',
    heal: 22,
    cls: 'none',
  },
  hardqi: {
    id: 'hardqi',
    name: '硬气蛊',
    ap: 1,
    cost: 8,
    desc: '盾 12 · 本回合起反击 8 伤（杀招防御补位）',
    kind: 'def',
    shield: 12,
    counter: 8,
    cls: 'none',
  },
  winebug: {
    id: 'winebug',
    name: '酒虫',
    ap: 1,
    cost: 0,
    desc: '凝元：回 12 真元 · 0 费但占 AP（续航位）',
    kind: 'restore',
    restore: 12,
    cls: 'none',
  },
  bear: {
    id: 'bear',
    name: '熊力蛊',
    ap: 1,
    cost: 4,
    desc: '近身 16 伤 · 4 真元（便宜的第二输出点）',
    kind: 'atk',
    dmg: 16,
    cls: 'basic',
  },
  // 炼成产物
  moonglow: {
    id: 'moonglow',
    name: '月芒蛊',
    rank: 2, // Wiki: ST-MOONGLOW-03 / E:V1-017144
    ap: MODEL.actions.burst.ap,
    cost: MODEL.actions.burst.mortalCost,
    desc: `炼成：月光+双小光。[Canon] 相对月光攻击三倍；[Design] 爆发 ${MODEL.actions.strike.damage * 3} · 冷却 ${MODEL.actions.burst.cooldown}`,
    kind: 'atk',
    dmg: MODEL.actions.strike.damage * 3,
    cls: 'burst',
    burst: true,
    cooldown: MODEL.actions.burst.cooldown,
    refined: true,
  },
  whitejade: {
    id: 'whitejade',
    name: '白玉蛊',
    rank: 2, // Wiki: roster-3 white_jade_gu / E:V1-009986
    ap: MODEL.actions.guard.ap,
    cost: 10,
    desc: '炼成：玉皮+白豕（[Canon] 配方）；[Design] 重盾 32 · 真元 10',
    kind: 'def',
    shield: 32,
    cls: 'none',
    refined: true,
  },
};

/* 以下同回合固定组合的名字与额外效果均为 [Design]；Wiki 只为个别基础协同提供依据。 */
const KILLER_MOVES = [
  {
    id: 'moonHeart',
    name: '杀招 · 月刃同心',
    need: ['moon', 'small'],
    desc: '月光借小光加倍（×2）',
  },
  {
    id: 'vineBoar',
    name: '杀招 · 藤力绞杀',
    need: ['vine', 'boar'],
    desc: '额外 +12 伤，敌下一手再 −8',
  },
  {
    id: 'jadeBoar',
    name: '杀招 · 皮力互济',
    need: ['jade', 'boar'],
    desc: '护盾 20 + 反击 15',
  },
  {
    id: 'wineMoon',
    name: '杀招 · 回元养锋',
    need: ['winebug', 'moon'],
    desc: '本回合结束回 6 真元',
  },
  {
    id: 'hardGate',
    name: '杀招 · 硬气封门',
    need: ['hardqi', 'jade'],
    desc: '护盾合计 28 · 本回合免疫扰元',
  },
  {
    id: 'whiteWall',
    name: '杀招 · 白玉当关',
    need: ['whitejade', 'boar'],
    desc: '护盾 32 · 反击 20 · 爆发不另计冷却',
  },
  {
    id: 'raySmall',
    name: '杀招 · 痕光相薄',
    need: ['moonray', 'small'],
    desc: '月痕伤害 ×1.5，且只耗 4 真元',
  },
];

function activeKillerMoves() {
  return KILLER_MOVES.filter((m) => m.need.every((id) => run.picked.includes(id) && hasGu(id)));
}

function makeEnemy(tplId, name, desc, patterns) {
  const t = MODEL.enemies[tplId];
  return {
    id: tplId,
    name,
    hp: t.hp,
    armor: t.armor,
    damage: t.damage,
    energyLoss: t.energyLoss || 0,
    carrier: t.carrier || null,
    packUnits: t.packUnits || 0,
    desc,
    patterns,
  };
}

const BATTLE_POOL = [
  makeEnemy('skirmisher', '快攻兽', '短命快攻。', [
    { type: 'atk', value: 13, label: '急咬', detail: '13 点伤害' },
    { type: 'atk', value: 17, label: '连咬', detail: '17 点伤害' },
  ]),
  makeEnemy('armored', '甲壳兽', '35% 减伤。', [
    { type: 'atk', value: 17, label: '甲撞', detail: '17 点伤害' },
    { type: 'atk', value: 17, label: '缩甲', detail: '17 点伤害' },
  ]),
  makeEnemy('pressure', '重压兽', '单击很重。', [
    { type: 'atk', value: 22, label: '重击', detail: '22 点伤害' },
    { type: 'atk', value: 25, label: '蓄力', detail: '25 点伤害' },
  ]),
  makeEnemy('disruptor', '扰元兽', '偷真元。', [
    { type: 'atk', value: 16, label: '撕咬', detail: '16 点伤害' },
    { type: 'steal', value: 4, label: '扰元', detail: '偷 4 真元' },
  ]),
  makeEnemy('soulBody', '虚魂体', '常规伤 −65%。', [
    { type: 'atk', value: 24, label: '魂冲', detail: '24 点伤害' },
    { type: 'atk', value: 24, label: '阴袭', detail: '24 点伤害' },
  ]),
  makeEnemy('brute', '雷冠头狼', '蓄势。', [
    { type: 'atk', value: 20, label: '电弧', detail: '20 点伤害' },
    { type: 'charge', value: 0, label: '蓄势', detail: '下一击 +6' },
    { type: 'atk', value: 26, label: '雷扑', detail: '26 点伤害' },
  ]),
  makeEnemy('guHouse', '蛊屋', '高耐高甲低伤。', [
    { type: 'atk', value: 4, label: '屋脊弹', detail: '4 点伤害（40% 甲）' },
  ]),
  makeEnemy('beastPack', '兽群', '单位衰减。', [
    { type: 'pack', value: 24, label: '群袭', detail: '按剩余单位出伤' },
    { type: 'pack', value: 24, label: '再扑', detail: '按剩余单位出伤' },
  ]),
];

/* 一局五段：每段二选一，最后一段强制终验 */
const SEGS = [
  {
    title: '起点 · 青石集外',
    scene: '带一只月光、一只小光、一件玉皮出门。\n钱包 48 元石。第一段决定你这套蛊先吃哪一路。',
    options: [
      { id: 'fight', kind: 'fight', label: '拦路战 · 快攻', hint: '收益 24U · skirmisher', pick: 0 },
      { id: 'rest', kind: 'rest', label: '路边休整', hint: '回状态 · 少量供养' },
      { id: 'breakthrough', kind: 'breakthrough', label: '闭关冲二转', hint: '[Design] 12U · 本段机会 · 可催二转蛊' },
    ],
  },
  {
    title: '二段 · 岔口',
    scene: '上一段的伤还没好全。这里可以打、可以买、可以试着炼。',
    options: [
      { id: 'fight', kind: 'fight', label: '甲壳兽', hint: '35% 减伤 · 惩罚平砍', pick: 1 },
      { id: 'shop', kind: 'shop', label: '商队驿', hint: '买蛊 / 补给 · 同时定编制' },
      { id: 'refine', kind: 'refine', label: '炼台', hint: '转型窗口 · 费 12U' },
    ],
  },
  {
    title: '三段 · 中盘',
    scene: '钱和状态开始互相顶牛。省元太狠，下一场会被打穿。',
    options: [
      { id: 'fight', kind: 'fight', label: '虚魂体', hint: '常规伤 −65% · 逼你用爆发/杀招', pick: 4 },
      { id: 'rest', kind: 'rest', label: '休整', hint: '回耐 / 回元 · 供养结算' },
      { id: 'refine', kind: 'refine', label: '炼台', hint: '费 12U · 95% 成功（r1）' },
    ],
  },
  {
    title: '四段 · 险地',
    scene: '离终点还有两战。现在保留的真元与护盾，决定终验能不能站住。',
    options: [
      { id: 'fight', kind: 'fight', label: '扰元兽', hint: '偷真元 · 惩罚省元/拖长', pick: 3 },
      { id: 'shop', kind: 'shop', label: '补给', hint: '花元石换状态 · 换编制' },
    ],
  },
  {
    title: '终验',
    scene: '终点。一场检验构筑短板的仗——没有第二套答案。',
    options: [
      { id: 'fight', kind: 'fight', label: '终验 · 兽群/雷冠', hint: '终点 · 组合短板', pick: 7, final: true },
    ],
  },
];

const run = {
  screen: 'intro', // intro | seg | battle | shop | rest | refine | end
  seg: 0,
  wallet: ECO.startingWallet,
  rank: 1,
  randomState: baseSeed,
  learnedThisLife: [],
  hp: HP_MAX,
  mp: MP_MAX,
  wounds: 0,
  gu: {
    moon: { ...GU.moon, alive: true },
    small: { ...GU.small, alive: true, n: 1 },
    jade: { ...GU.jade, alive: true },
    boar: { ...GU.boar, alive: true },
  },
  spent: { feed: 0, heal: 0, refine: 0, field: 0, study: 0, breakthrough: 0 },
  earned: 0,
  log: [],
  // battle state
  enemy: null,
  enemyHp: 0,
  enemyMax: 0,
  patternIdx: 0,
  chargeBonus: 0,
  packUnits: 0,
  picked: [],
  ready: ['moon', 'small', 'jade', 'boar'],
  burstCd: 0,
  guard: 0,
  turn: 1,
  battleOver: false,
  battleWon: false,
};

function addLog(kind, text, cls = '') {
  run.log.unshift({ kind, text, cls, seg: run.seg, life: meta.life });
  if (run.log.length > 80) run.log.pop();
}

function hasGu(id) {
  const g = run.gu[id];
  return !!(g && g.alive);
}

function activeCards() {
  // 仅允许当前转数可催动的蛊进入战斗。
  return ['fist', ...run.ready].filter((id) => id === 'fist' || (hasGu(id) && (GU[id].rank || 1) <= run.rank));
}

function ownedGuIds() {
  return Object.values(run.gu).filter((g) => g.alive && g.id !== 'fist').map((g) => g.id);
}

function resetRun() {
  run.screen = 'intro';
  run.seg = 0;
  run.wallet = ECO.startingWallet;
  run.rank = 1;
  run.randomState = baseSeed;
  run.learnedThisLife = [];
  run.hp = HP_MAX;
  run.mp = MP_MAX;
  run.wounds = 0;
  run.gu = {
    moon: { ...GU.moon, alive: true },
    small: { ...GU.small, alive: true, n: 1 },
    jade: { ...GU.jade, alive: true },
    boar: { ...GU.boar, alive: true },
  };
  run.spent = { feed: 0, heal: 0, refine: 0, field: 0, study: 0, breakthrough: 0 };
  run.earned = 0;
  run.log = [];
  run.enemy = null;
  run.enemyHp = 0;
  run.enemyMax = 0;
  run.patternIdx = 0;
  run.chargeBonus = 0;
  run.packUnits = 0;
  run.pendingFight = null;
  run.enemyWeaken = 0;
  run.picked = [];
  run.burstCd = 0;
  run.guard = 0;
  run.turn = 1;
  run.battleOver = false;
  addLog('入局', `第 ${meta.life} 世开始。种子 ${baseSeed}；已知蛊方 ${meta.known.map((id) => RECIPES[id].name).join('、') || '无'}。钱包 ${run.wallet} 元石，耐受 ${run.hp}，丙等真元 ${run.mp}。`);
  addLog('源', `经济参数来自 rank1-9-model economy：满耐 ${ECO.recoverFullHp}U、炼费 ${ECO.refinementFee}U、遇敌毛收 ${ECO.grossPerPeriod}U。`);
}

function clearCheckpoint() {
  try { localStorage.removeItem(CHECKPOINT_KEY); } catch { /* storage may be unavailable */ }
}

function saveCheckpoint() {
  if (run.screen === 'end') { clearCheckpoint(); return; }
  try {
    const snapshot = { ...run, enemy: run.screen === 'battle' ? run.enemy : null };
    localStorage.setItem(CHECKPOINT_KEY, JSON.stringify({
      version: CHECKPOINT_VERSION, seed: baseSeed, life: meta.life, run: snapshot,
    }));
  } catch { /* file://, private mode, or quota may block storage */ }
}

function finiteInt(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

function validCheckpoint(saved) {
  if (!saved || saved.version !== CHECKPOINT_VERSION || saved.seed !== baseSeed || saved.life !== meta.life) return false;
  const s = saved.run;
  if (!s || !['intro', 'seg', 'prep', 'battle', 'shop', 'rest', 'refine'].includes(s.screen)) return false;
  if (!finiteInt(s.seg, 0, SEGS.length - 1) || !finiteInt(s.wallet, 0, 100000) || !finiteInt(s.rank, 1, 9) ||
      !finiteInt(s.randomState, 0, 0xffffffff) || !finiteInt(s.hp, 0, HP_MAX) || !finiteInt(s.mp, 0, MP_MAX) ||
      !finiteInt(s.wounds, 0, 1000) || !finiteInt(s.earned, 0, 100000) || !finiteInt(s.burstCd, 0, 100) ||
      !finiteInt(s.guard, 0, 10000) || !finiteInt(s.turn, 1, MODEL.combat.maxTurns + 1) ||
      !finiteInt(s.patternIdx, 0, 10000) || !finiteInt(s.enemyHp, 0, 100000) || !finiteInt(s.enemyMax, 0, 100000) ||
      !finiteInt(s.packUnits, 0, 1000) || !finiteInt(s.chargeBonus, 0, 1000) || !finiteInt(s.enemyWeaken || 0, 0, 1000)) return false;
  const guIds = new Set(Object.keys(GU).filter((id) => id !== 'fist'));
  if (!s.gu || typeof s.gu !== 'object' || Array.isArray(s.gu) || Object.keys(s.gu).some((id) => !guIds.has(id))) return false;
  for (const [id, g] of Object.entries(s.gu)) {
    if (!g || typeof g.alive !== 'boolean' || (id === 'small' ? !finiteInt(g.n, 1, 2) : g.n !== undefined)) return false;
  }
  const listOfGu = (xs, max) => Array.isArray(xs) && xs.length <= max && xs.every((id) => guIds.has(id)) && new Set(xs).size === xs.length;
  if (!listOfGu(s.ready, READY_MAX) || !Array.isArray(s.picked) || s.picked.length > Object.keys(GU).length ||
      !s.picked.every((id) => id === 'fist' || guIds.has(id)) || new Set(s.picked).size !== s.picked.length ||
      !listOfGu(s.learnedThisLife, Object.keys(RECIPES).length)) return false;
  if (s.picked.some((id) => !s.ready.includes(id) && id !== 'fist')) return false;
  const spentKeys = ['feed', 'heal', 'refine', 'field', 'study', 'breakthrough'];
  if (!s.spent || Object.keys(s.spent).some((key) => !spentKeys.includes(key)) || spentKeys.some((key) => !finiteInt(s.spent[key], 0, 100000))) return false;
  if (!Array.isArray(s.log) || s.log.length > 80 || s.log.some((l) => !l || typeof l.kind !== 'string' || l.kind.length > 40 || typeof l.text !== 'string' || l.text.length > 500 || typeof l.cls !== 'string' || !['', 'good', 'hit'].includes(l.cls) || !finiteInt(l.seg, 0, SEGS.length - 1) || !finiteInt(l.life, 1, 100000))) return false;
  if (s.learnedThisLife.some((id) => !RECIPES[id])) return false;
  if (s.pendingFight !== null && (!s.pendingFight || !finiteInt(s.pendingFight.pick, 0, BATTLE_POOL.length - 1) || typeof s.pendingFight.final !== 'boolean')) return false;
  if (s.screen === 'prep' && !s.pendingFight) return false;
  if (s.screen !== 'prep' && s.pendingFight) return false;
  if (s.screen === 'battle') {
    if (!s.enemy || !BATTLE_POOL.some((e) => e.id === s.enemy.id) || !finiteInt(s.enemyHp, 0, s.enemyMax) || s.enemyMax < 1 ||
        !finiteInt(s.patternIdx, 0, 10000) || typeof s.battleOver !== 'boolean' || typeof s.battleWon !== 'boolean') return false;
  } else if (s.enemy !== null) return false;
  return true;
}

function restoreCheckpoint() {
  try {
    const raw = localStorage.getItem(CHECKPOINT_KEY);
    if (!raw) return false;
    const saved = JSON.parse(raw);
    if (!validCheckpoint(saved)) { clearCheckpoint(); return false; }
    const s = saved.run;
    Object.assign(run, s);
    // Enemy templates are reconstructed from trusted constants, never from checkpoint strings.
    run.enemy = s.screen === 'battle' ? { ...BATTLE_POOL.find((e) => e.id === s.enemy.id) } : null;
    run.gu = Object.fromEntries(Object.entries(s.gu).map(([id, g]) => [id, { ...GU[id], alive: g.alive, ...(id === 'small' ? { n: g.n } : {}) }]));
    return true;
  } catch {
    clearCheckpoint();
    return false;
  }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
}

/* ---------- 节点 ---------- */

function enterSeg() {
  run.screen = 'seg';
  render();
}

function chooseOption(opt) {
  if (opt.kind === 'fight') {
    run.pendingFight = { pick: opt.pick || 0, final: !!opt.final };
    run.screen = 'prep';
    render();
    return;
  }
  if (opt.kind === 'rest') {
    run.screen = 'rest';
    render();
    return;
  }
  if (opt.kind === 'shop') {
    run.screen = 'shop';
    render();
    return;
  }
  if (opt.kind === 'refine') {
    run.screen = 'refine';
    render();
    return;
  }
  if (opt.kind === 'breakthrough') {
    const cost = 12; // [Design] 五段原型压缩的一次破境选择，不是原著晋升公式。
    if (run.wallet < cost) {
      addLog('破境', `需 ${cost}U，元石不足。`);
      render();
      return;
    }
    run.wallet -= cost;
    run.spent.breakthrough += cost;
    run.rank = 2;
    addLog('破境', `选闭关冲二转 · −${cost}U · 放弃本段战斗/休整（[Design]）。`, 'good');
    nextSeg();
    return;
  }
}

function nextSeg() {
  run.seg += 1;
  if (run.seg >= SEGS.length) {
    endRun(true);
    return;
  }
  enterSeg();
}

function payFeed() {
  // 两只小光蛊是两只蛊，供养与合炼均按数量结算。
  const n = Object.values(run.gu).filter((g) => g.alive).reduce((sum, g) => sum + (g.n || 1), 0);
  const cost = n * ECO.foodPerGu;
  if (run.wallet < cost) {
    addLog('供养', `元石不够养 ${n} 只蛊（需 ${cost}U）。本段起伤势加重。`, 'hit');
    run.wounds += 1;
    return;
  }
  run.wallet -= cost;
  run.spent.feed += cost;
  addLog('供养', `阶段供养 ${n} 只 · −${cost}U`);
}

/* ---------- 战斗 ---------- */

function toggleReady(id) {
  if (id === 'fist') return;
  if (!hasGu(id)) return;
  if ((GU[id].rank || 1) > run.rank) {
    addLog('编制', `${GU[id].name}是二转蛊，当前一转不能出战。`);
    render();
    return;
  }
  const i = run.ready.indexOf(id);
  if (i >= 0) {
    run.ready.splice(i, 1);
  } else {
    if (run.ready.length >= READY_MAX) {
      addLog('编制', `出战最多 ${READY_MAX} 只（心智容量 C=${READY_MAX}）。先踢掉一只。`);
      render();
      return;
    }
    run.ready.push(id);
  }
  render();
}

function startBattle(pickIdx, final) {
  const e = BATTLE_POOL[Math.min(pickIdx, BATTLE_POOL.length - 1)];
  run.enemy = { ...e };
  run.enemyHp = e.hp;
  run.enemyMax = e.hp;
  run.patternIdx = 0;
  run.chargeBonus = 0;
  run.packUnits = e.packUnits || 0;
  run.picked = [];
  run.guard = 0;
  run.turn = 1;
  run.battleOver = false;
  run.battleWon = false;
  run.pendingFight = null;
  run.screen = 'battle';
  run.ready = run.ready.filter((id) => hasGu(id) && (GU[id].rank || 1) <= run.rank);
  if (!run.ready.length) run.ready = ownedGuIds().filter((id) => (GU[id].rank || 1) <= run.rank).slice(0, READY_MAX);
  while (run.ready.length > READY_MAX) run.ready.pop();
  // 出场消耗 fieldCost（模型）
  if (run.wallet >= ECO.fieldCost) {
    run.wallet -= ECO.fieldCost;
    run.spent.field += ECO.fieldCost;
    addLog('出场', `外出消耗 −${ECO.fieldCost}U`);
  }
  addLog('战斗', `对上 ${e.name}${final ? '（终验）' : ''}`);
  render();
}

function currentIntent() {
  return run.enemy.patterns[run.patternIdx % run.enemy.patterns.length];
}

function pickedAp() {
  return run.picked.reduce((s, id) => s + GU[id].ap, 0);
}

function pickedCost() {
  return run.picked.reduce((s, id) => s + GU[id].cost, 0);
}

function comboActive() {
  return run.picked.includes('moon') && run.picked.includes('small');
}

function togglePick(id) {
  if (run.battleOver) return;
  const i = run.picked.indexOf(id);
  if (i >= 0) {
    run.picked.splice(i, 1);
    render();
    return;
  }
  const c = GU[id];
  if (pickedAp() + c.ap > MODEL.combat.actionsPerTurn) {
    addLog('行动', `AP 不足（每回合 ${MODEL.combat.actionsPerTurn}）。`);
    render();
    return;
  }
  if (pickedCost() + c.cost > run.mp) {
    addLog('真元', `真元不足，差 ${pickedCost() + c.cost - run.mp}。`);
    render();
    return;
  }
  if (c.burst && run.burstCd > 0) {
    addLog('冷却', `${c.name} 冷却剩 ${run.burstCd}。`);
    render();
    return;
  }
  run.picked.push(id);
  render();
}

function resolveTurn() {
  if (run.battleOver) return;
  let dmg = 0;
  const notes = [];
  const combo = comboActive();
  const killers = activeKillerMoves();
  const killerIds = new Set(killers.map((k) => k.id));
  let usedBurst = false;
  let extraShield = 0;
  let extraCounter = 0;
  let weakenAmt = 0;
  let heal = 0;
  let restore = 0;
  let immuneSteal = false;
  let refundMp = 0;

  run.picked.forEach((id) => {
    const c = GU[id];
    if (c.kind === 'atk') {
      let d = c.dmg;
      if (id === 'moon' && combo) {
        d *= 2;
        notes.push('杀招·月刃同心 ×2');
      }
      if (id === 'small') d = 0;
      if (id === 'moonray' && killerIds.has('raySmall')) {
        d = Math.round(d * 1.5);
        notes.push('杀招·痕光相薄 ×1.5');
      }
      if (c.weaken) weakenAmt += c.weaken;
      if (c.burst) usedBurst = true;
      const cls = c.cls;
      if (run.enemy.carrier === 'soulBody' && d > 0) {
        const resist = MODEL.carriers.soulBodyResist[cls] || 0;
        if (resist > 0) {
          d = Math.round(d * (1 - resist));
          notes.push(`虚魂体减 ${cls} 伤`);
        }
      }
      if (run.enemy.carrier === 'beastPack' && d > 0) {
        d = Math.round(d * (MODEL.carriers.packAoeYield[cls] || 1));
      }
      const armor = run.enemy.armor || 0;
      if (armor > 0 && d > 0) d = Math.round(d * (1 - armor));
      dmg += d;
    } else if (c.kind === 'def') {
      run.guard = Math.max(run.guard, c.shield);
      if (c.counter) extraCounter += c.counter;
      notes.push(`护盾 ${c.shield}`);
    } else if (c.kind === 'heal') {
      heal += c.heal || 0;
    } else if (c.kind === 'restore') {
      restore += c.restore || 0;
    }
  });

  // 杀招加成
  if (killerIds.has('vineBoar')) {
    dmg += 12;
    weakenAmt += 8;
    notes.push('杀招·藤力绞杀 +12 / 敌再 −8');
  }
  if (killerIds.has('jadeBoar')) {
    extraShield += 20;
    extraCounter += 15;
    notes.push('杀招·皮力互济 盾20/反15');
  }
  if (killerIds.has('wineMoon')) {
    refundMp += 6;
    notes.push('杀招·回元养锋 +6 元');
  }
  if (killerIds.has('hardGate')) {
    extraShield += 28;
    immuneSteal = true;
    notes.push('杀招·硬气封门 盾28/免扰元');
  }
  if (killerIds.has('whiteWall')) {
    extraShield += 32;
    extraCounter += 20;
    usedBurst = false; // 杀招承担爆发
    notes.push('杀招·白玉当关 盾32/反20');
  }
  if (extraShield > 0) run.guard = Math.max(run.guard, extraShield);

  run.mp = Math.max(0, run.mp - pickedCost());
  run.mp = Math.min(MP_MAX, run.mp + restore + refundMp);
  if (heal > 0) {
    run.hp = Math.min(HP_MAX, run.hp + heal);
    notes.push(`治疗 +${heal}`);
  }

  if (usedBurst) run.burstCd = MODEL.actions.burst.cooldown;
  else if (run.burstCd > 0) run.burstCd -= 1;

  if (dmg > 0) {
    run.enemyHp -= dmg;
    if (run.enemy.carrier === 'beastPack' && run.packUnits > 0) {
      const maxU = run.enemy.packUnits || 1;
      const nextU = Math.max(0, Math.ceil((run.enemyHp / run.enemyMax) * maxU));
      if (nextU < run.packUnits) {
        addLog('兽群', `打散 ${run.packUnits - nextU} 单位`, 'good');
        run.packUnits = nextU;
      }
    }
    addLog('你', `打出 ${dmg} 伤${combo ? '（月刃同心）' : ''}`, 'good');
    killers.forEach((k) => addLog('杀招', k.name, 'good'));
    notes.forEach((n) => addLog('联动', n, 'good'));
  } else {
    killers.forEach((k) => addLog('杀招', k.name, 'good'));
    notes.forEach((n) => addLog('联动', n));
  }

  if (extraCounter > 0 && run.enemyHp > 0) {
    const armor = run.enemy.armor || 0;
    let cd = Math.round(extraCounter * (1 - armor));
    if (run.enemy.carrier === 'soulBody') cd = Math.round(cd * (1 - (MODEL.carriers.soulBodyResist.regular || 0)));
    run.enemyHp -= cd;
    addLog('反击', `额外 ${cd} 伤`, 'good');
    if (run.enemyHp <= 0) {
      run.enemyHp = 0;
      run.battleOver = true;
      run.battleWon = true;
      const pay = ECO.grossPerPeriod;
      run.wallet += pay;
      run.earned += pay;
      addLog('胜', `反击收掉 ${run.enemy.name} · +${pay}U`, 'good');
      render();
      return;
    }
  }

  if (weakenAmt > 0) {
    run.enemyWeaken = (run.enemyWeaken || 0) + weakenAmt;
    addLog('削弱', `敌下一手 −${weakenAmt}`, 'good');
  }

  if (run.enemyHp <= 0) {
    run.enemyHp = 0;
    run.battleOver = true;
    run.battleWon = true;
    const pay = ECO.grossPerPeriod;
    run.wallet += pay;
    run.earned += pay;
    addLog('胜', `击破 ${run.enemy.name} · 毛收 +${pay}U`, 'good');
    render();
    return;
  }

  const intent = currentIntent();
  const weaken = run.enemyWeaken || 0;
  run.enemyWeaken = 0;
  if (intent.type === 'atk') {
    let d = intent.value + run.chargeBonus - weaken;
    if (d < 0) d = 0;
    run.chargeBonus = 0;
    if (run.guard > 0) {
      const b = Math.min(run.guard, d);
      d -= b;
      run.guard = 0;
      addLog('玉皮', `挡下 ${b}`, 'good');
    }
    run.hp -= d;
    addLog('敌', `${intent.label}：${d} 伤${weaken ? `（削弱 −${weaken}）` : ''}`, 'hit');
  } else if (intent.type === 'pack') {
    const units = Math.max(1, run.packUnits || 1);
    const maxU = run.enemy.packUnits || 1;
    const scale = Math.max(MODEL.carriers.packDamageFloor, units / maxU);
    let d = Math.round(intent.value * scale + run.chargeBonus - weaken);
    if (d < 0) d = 0;
    run.chargeBonus = 0;
    if (run.guard > 0) {
      const b = Math.min(run.guard, d);
      d -= b;
      run.guard = 0;
      addLog('玉皮', `挡下 ${b}`, 'good');
    }
    run.hp -= d;
    addLog('敌', `${intent.label}：${d} 伤（${units}/${maxU}）`, 'hit');
  } else if (intent.type === 'steal') {
    if (immuneSteal) {
      addLog('硬气', '封门：扰元被挡下', 'good');
    } else {
      const s = Math.min(intent.value, run.mp);
      run.mp -= s;
      addLog('敌', `摸走 ${s} 真元`, 'hit');
    }
  } else if (intent.type === 'charge') {
    run.chargeBonus += 6;
    addLog('敌', '蓄势 +6');
  }

  if (run.hp <= 0) {
    run.hp = 0;
    run.battleOver = true;
    run.battleWon = false;
    render();
    endRun(false);
    return;
  }

  run.turn += 1;
  if (run.turn > MODEL.combat.maxTurns) {
    run.battleOver = true;
    run.battleWon = false;
    render();
    endRun(false);
    return;
  }
  run.patternIdx += 1;
  run.picked = [];
  run.guard = 0;
  render();
}

/* ---------- 休整 / 商店 / 炼台 ---------- */

function doRest(mode) {
  if (mode === 'full') {
    const cost = ECO.recoverFullHp;
    if (run.wallet < cost) {
      addLog('休整', `满耐需 ${cost}U，不够。`);
      render();
      return;
    }
    run.wallet -= cost;
    run.spent.heal += cost;
    run.hp = HP_MAX;
    run.mp = MP_MAX;
    addLog('休整', `满耐满元 · −${cost}U`);
  } else if (mode === 'half') {
    const cost = Math.round(ECO.recoverFullHp / 2);
    if (run.wallet < cost) {
      addLog('休整', `半耐需 ${cost}U，不够。`);
      render();
      return;
    }
    run.wallet -= cost;
    run.spent.heal += cost;
    run.hp = Math.min(HP_MAX, run.hp + Math.round(HP_MAX * 0.5));
    run.mp = Math.min(MP_MAX, run.mp + Math.round(MP_MAX * 0.5));
    addLog('休整', `半耐半元 · −${cost}U`);
  } else {
    // 免费小休 + 供养结算
    run.hp = Math.min(HP_MAX, run.hp + 15);
    run.mp = Math.min(MP_MAX, run.mp + 10);
    addLog('休整', '免费小休：+15 耐 / +10 元');
    payFeed();
  }
  render();
}

function doShop(mode) {
  if (mode === 'mp') {
    const pts = 20;
    const costU = Math.ceil(pts * ECO.mortalRefillPerPoint);
    if (run.wallet < costU) {
      addLog('商队', `补 ${pts} 真元需 ${costU}U，不够。`);
      render();
      return;
    }
    run.wallet -= costU;
    run.mp = Math.min(MP_MAX, run.mp + pts);
    addLog('商队', `真元 +${pts} · −${costU}U（${ECO.mortalRefillPerPoint}U/点）`);
  } else if (mode === 'hp') {
    const cost = 6;
    if (run.wallet < cost) {
      addLog('商队', '不够。');
      render();
      return;
    }
    run.wallet -= cost;
    run.hp = Math.min(HP_MAX, run.hp + 30);
    addLog('商队', `耐受 +30 · −${cost}U`);
  } else if (mode.startsWith('buy:')) {
    const id = mode.slice(4);
    const prices = { small: 8, boar: 16, moonray: 14, vine: 12, herb: 10, hardqi: 12, winebug: 10, bear: 11 };
    const cost = prices[id] || 16;
    if (id === 'small') {
      const count = hasGu('small') ? run.gu.small.n || 1 : 0;
      if (count >= 2) { addLog('商队', '小光蛊已有两只，足够入月芒方。'); render(); return; }
      if (run.wallet < cost) { addLog('商队', `小光蛊要 ${cost}U。`); render(); return; }
      run.wallet -= cost;
      run.gu.small = { ...GU.small, alive: true, n: count + 1 };
      addLog('商队', `购入第 ${count + 1} 只小光蛊 · −${cost}U · 供养按只数计。`, 'good');
      render();
      return;
    }
    if (hasGu(id)) {
      addLog('商队', `已有 ${GU[id].name}。`);
      render();
      return;
    }
    if (run.wallet < cost) {
      addLog('商队', `${GU[id].name} 要 ${cost}U。`);
      render();
      return;
    }
    run.wallet -= cost;
    run.gu[id] = { ...GU[id], alive: true };
    if (run.ready.length < READY_MAX && !run.ready.includes(id)) run.ready.push(id);
    addLog('商队', `购入 ${GU[id].name} · −${cost}U${run.ready.includes(id) ? '（已进编制）' : '（编制已满，请备战时替换）'}`);
  }
  render();
}

function studyRecipe(id) {
  if (!RECIPES[id] || knowsRecipe(id)) return;
  const cost = 8; // [Design] 抄录花钱且占用整段商队机会。
  if (run.wallet < cost) { addLog('蛊方', `抄录需 ${cost}U，元石不足。`); render(); return; }
  run.wallet -= cost;
  run.spent.study += cost;
  run.learnedThisLife.push(id);
  addLog('得方', `本世抄得${RECIPES[id].name} · ${RECIPES[id].input}→${RECIPES[id].result} · −${cost}U · 放弃商队其他交易。`, 'good');
  nextSeg();
}

function doRefine(kind) {
  if (kind !== 'trade' && !knowsRecipe(kind)) {
    addLog('炼台', `尚未掌握${RECIPES[kind]?.name || '此方'}；去商队抄方或带着上一世记忆再来。`);
    render();
    return;
  }
  const fee = ECO.refinementFee;
  if (run.wallet < fee) {
    addLog('炼台', `炼费 ${fee}U，不够。`);
    render();
    return;
  }
  // r1 成功率 95%（模型 baseSuccess[0]）
  const p0 = MODEL.refinement.baseSuccess[0];

  if (kind === 'moonglow') {
    const smallN = run.gu.small && run.gu.small.alive ? run.gu.small.n || 1 : 0;
    if (!hasGu('moon') || smallN < 2) {
      addLog('炼台', '月芒方：需月光 + 双小光。条件不足。');
      render();
      return;
    }
    const success = random01() < p0;
    run.wallet -= fee;
    run.spent.refine += fee;
    if (success) {
      run.gu.moon.alive = false;
      run.gu.small.alive = false;
      run.gu.moonglow = { ...GU.moonglow, alive: true };
      run.ready = run.ready.filter((id) => hasGu(id));
      if (run.rank >= 2 && run.ready.length < READY_MAX) run.ready.push('moonglow');
      addLog('炼成', `月芒成 · 吃掉月光与双小光 · −${fee}U`, 'good');
      addLog('转型', '旧组合没了。爆发位更强，协同与续航方式变了。');
    } else {
      run.gu.moon.alive = false;
      run.gu.small.alive = false;
      run.hp = Math.max(1, Math.round(run.hp * (1 - 0.1)));
      addLog('炼败', `月芒失败 · 月光与小光尽毁 · 伤 10% 耐受 · −${fee}U`, 'hit');
    }
    render();
    return;
  }

  if (kind === 'whitejade') {
    if (!hasGu('jade') || !hasGu('boar')) {
      addLog('炼台', '白玉方：需玉皮 + 白豕。条件不足。');
      render();
      return;
    }
    const success = random01() < p0;
    run.wallet -= fee;
    run.spent.refine += fee;
    if (success) {
      run.gu.jade.alive = false;
      run.gu.boar.alive = false;
      run.gu.whitejade = { ...GU.whitejade, alive: true };
      run.ready = run.ready.filter((id) => hasGu(id));
      if (run.rank >= 2 && run.ready.length < READY_MAX) run.ready.push('whitejade');
      addLog('炼成', `白玉成 · 吃掉玉皮与白豕 · −${fee}U`, 'good');
      addLog('转型', '重盾上线，爆发位让出。皮力互济杀招消失。');
    } else {
      run.gu.jade.alive = false;
      run.gu.boar.alive = false;
      run.hp = Math.max(1, Math.round(run.hp * (1 - 0.1)));
      addLog('炼败', '白玉失败 · 皮与豕尽毁', 'hit');
    }
    render();
    return;
  }

  if (kind === 'trade') {
    // 以小光换真元补满（把辅件变续航）——展示「炼/用」在同一决定
    if (!hasGu('small')) {
      addLog('炼台', '没有小光可拆。');
      render();
      return;
    }
    const success = random01() < p0;
    run.wallet -= fee;
    run.spent.refine += fee;
    if (success) {
      const count = run.gu.small.n || 1;
      if (count > 1) run.gu.small.n = count - 1;
      else run.gu.small.alive = false;
      run.mp = MP_MAX;
      run.wallet += 8;
      addLog('炼台', `拆解一只小光：真元回满 + 8U。${count > 1 ? '还留一只协同。' : '协同没了。'}`, 'good');
    } else {
      const count = run.gu.small.n || 1;
      if (count > 1) run.gu.small.n = count - 1;
      else run.gu.small.alive = false;
      addLog('炼败', '拆解失败，投入的那只小光仍毁。', 'hit');
    }
    render();
    return;
  }
}

function endRun(won) {
  run.screen = 'end';
  meta.completed = Math.max(meta.completed, meta.life);
  for (const id of run.learnedThisLife) if (!meta.known.includes(id)) meta.known.push(id);
  saveMeta();
  clearCheckpoint();
  const guNames = Object.values(run.gu).filter((g) => g.alive).map((g) => g.name).join('、');
  document.getElementById('end-panel').hidden = false;
  document.getElementById('end-story').innerHTML = `
    <div class="end-card">
      <h4>${won ? '走完了' : '倒在路上'}</h4>
      <p>${won
        ? '你带着战损与取舍走完了这一局。若每段都无脑打、无脑炼，说明经济还太松。'
        : '败因通常在上一段：该休整时去打了硬仗，或炼台毁掉了还在用的组合。'}</p>
    </div>
    <div class="end-card">
      <h4>账本（模型 economy）</h4>
      <p>赚 ${run.earned}U · 供养 ${run.spent.feed}U · 休整 ${run.spent.heal}U · 炼制 ${run.spent.refine}U · 出场 ${run.spent.field}U
抄方 ${run.spent.study}U · 破境 ${run.spent.breakthrough}U · 当前 ${run.rank} 转
剩余 ${run.wallet}U · 伤次 ${run.wounds}
在身蛊：${guNames || '无'}</p>
    </div>
    <div class="end-card">
      <h4>跨世蛊方</h4>
      <p>本世新得：${run.learnedThisLife.map((id) => RECIPES[id].name).join('、') || '无'}。
下一世已知：${meta.known.map((id) => RECIPES[id].name).join('、') || '无'}。
只带走蛊方；转数、蛊虫、元石和伤势都重置。下一世重新取舍路线与补给。</p>
    </div>
  `;
  render();
}

/* ---------- 渲染 ---------- */

function render() {
  document.getElementById('life').textContent = String(meta.life);
  document.getElementById('rank').textContent = String(run.rank);
  document.getElementById('knowledge').textContent = `已知蛊方：${meta.known.map((id) => RECIPES[id].name).join('、') || '无'}${run.learnedThisLife.length ? ` · 本世抄得：${run.learnedThisLife.map((id) => RECIPES[id].name).join('、')}` : ''} · 种子 ${baseSeed}`;
  document.getElementById('stage').textContent = String(run.seg);
  document.getElementById('stage-note').textContent =
    run.screen === 'battle' ? ' / 战斗' : run.screen === 'end' ? ' / 终' : ' / ' + (SEGS[run.seg] ? SEGS[run.seg].title.slice(0, 6) : '—');
  document.getElementById('wallet').textContent = String(run.wallet);
  document.getElementById('hp').textContent = String(run.hp);
  document.getElementById('mp').textContent = String(run.mp);
  document.getElementById('wounds').textContent = String(run.wounds);

  const pct = Math.round((run.seg / (SEGS.length - 1)) * 100);
  document.getElementById('bar-route').style.width = pct + '%';
  document.getElementById('route-label').textContent = run.screen === 'end' ? '终' : `段${run.seg}`;

  // map
  const map = document.getElementById('map');
  map.innerHTML = SEGS.map((s, i) => {
    const cls = i < run.seg ? 'is-done' : i === run.seg ? 'is-here' : '';
    return `<div class="map-node ${cls}">${s.title.split(' · ')[0]}<span class="tag">${i < run.seg ? '已过' : i === run.seg ? '此处' : ''}</span></div>`;
  }).join('');

  // gu
  const guEl = document.getElementById('gu-list');
  guEl.innerHTML = Object.values(run.gu)
    .filter((g) => g.id !== 'fist')
    .map((g) => {
      const n = g.n && g.n > 1 ? ` ×${g.n}` : '';
      return `
        <div class="gu-card" style="${g.alive ? '' : 'opacity:.45;text-decoration:line-through'}">
          <strong>${g.name}${n}</strong>
          <span>${g.alive ? g.desc : '已失'}</span>
        </div>
      `;
    })
    .join('');

  document.getElementById('ledger').innerHTML = `
    <div class="inv-item"><strong>经济参数</strong><span>满耐 ${ECO.recoverFullHp}U · 真元 ${ECO.mortalRefillPerPoint}U/点 · 炼费 ${ECO.refinementFee}U · 遇敌毛收 ${ECO.grossPerPeriod}U · 出场 ${ECO.fieldCost}U</span></div>
    <div class="inv-item"><strong>供养</strong><span>每只蛊 ${ECO.foodPerGu}U / 段（休整点结算）</span></div>
    <div class="inv-item"><strong>炼制</strong><span>原型成功率 95% · 失败投入全失；二转蛊须二转方能出战</span></div>
    <div class="inv-item"><strong>组合名 [Design]</strong><span>${KILLER_MOVES.map((m) => m.name.replace('杀招 · ', '')).join('、')}</span></div>
  `;

  document.getElementById('log').innerHTML = run.log
    .slice(0, 22)
    .map((l) => `<div class="log-item ${escapeHtml(l.cls)}"><strong>${escapeHtml(l.kind)}</strong>${escapeHtml(l.text)}</div>`)
    .join('');

  renderMain();
  saveCheckpoint();
}

function renderMain() {
  const title = document.getElementById('screen-title');
  const tag = document.getElementById('screen-tag');
  const scene = document.getElementById('scene');
  const intent = document.getElementById('intent');
  const enemyBox = document.getElementById('enemy-box');
  const hand = document.getElementById('hand');
  const choices = document.getElementById('choices');
  const tip = document.getElementById('combo-tip');
  const btnResolve = document.getElementById('btn-resolve');
  const btnClear = document.getElementById('btn-clear');

  intent.hidden = true;
  enemyBox.hidden = true;
  btnResolve.hidden = true;
  btnClear.hidden = true;
  hand.innerHTML = '';
  choices.innerHTML = '';

  if (run.screen === 'intro') {
    title.textContent = '一局开始';
    tag.textContent = `第 ${meta.life} 世 · 有限节点`;
    scene.textContent = `一转起步：月光、小光、玉皮、白豕各一。\n已知蛊方：${meta.known.map((id) => RECIPES[id].name).join('、') || '无'}。\n\n商队抄方会占去整段；已知方让你把这段机会改用于购蛊或炼蛊。二转蛊要先突破二转才能出战。`;
    tip.textContent = '跨世只保存蛊方知识；路线、钱、蛊和转数每世重来。';
    choices.innerHTML = `<div class="action-row">
      <button type="button" class="btn btn-primary" data-act="start">出发</button>
    </div>`;
    bindActs();
    return;
  }

  if (run.screen === 'seg') {
    const seg = SEGS[run.seg];
    title.textContent = seg.title;
    tag.textContent = `[Design] 第 ${run.seg + 1}/${SEGS.length} 段`;
    scene.textContent = seg.scene;
    tip.textContent = `钱包 ${run.wallet}U · 耐 ${run.hp} · 元 ${run.mp} · 伤次 ${run.wounds}`;
    choices.innerHTML = `<div class="action-row">${seg.options
      .map((o, i) => {
        const disabled = o.kind === 'refine' && run.wallet < ECO.refinementFee;
        return `<button type="button" class="btn ${o.final ? 'btn-primary' : ''}" data-opt="${i}" ${disabled ? 'disabled' : ''}>
          ${o.label}<small>${o.hint}${disabled ? ' · 石不够' : ''}</small>
        </button>`;
      })
      .join('')}</div>`;
    bindOpts();
    return;
  }

  if (run.screen === 'rest') {
    title.textContent = '休整';
    tag.textContent = '模型：满耐 12U / 半耐 6U / 免费小休+供养';
    scene.textContent = '把伤养回去，或者把钱留给后面的硬仗。';
    choices.innerHTML = `<div class="action-row">
      <button type="button" class="btn btn-ok" data-act="rest-full">满耐满元 · 12U</button>
      <button type="button" class="btn" data-act="rest-half">半耐半元 · 6U</button>
      <button type="button" class="btn" data-act="rest-free">免费小休 + 阶段供养</button>
      <button type="button" class="btn" data-act="leave-node">离开</button>
    </div>`;
    bindActs();
    return;
  }

  if (run.screen === 'shop') {
    title.textContent = '商队驿';
    tag.textContent = '补状态、补蛊；或用整段机会抄一张蛊方';
    scene.textContent = '抄方后本段结束；已知方可把这段时间和元石留给补给。配方来自 Wiki，抄录成本为 [Design]。';
    const buys = [
      ['small', '第二只小光 · 8U', '月芒方需两只；供养也多一只'],
      ['moonray', '月痕 · 14U', '省元远程'],
      ['vine', '青藤 · 12U', '削弱控制'],
      ['herb', '生机草 · 10U', '即时治疗'],
      ['hardqi', '硬气 · 12U', '防+反'],
      ['winebug', '酒虫 · 10U', '回元续航'],
      ['bear', '熊力 · 11U', '便宜第二刀'],
      ['boar', '白豕 · 16U', '爆发位'],
    ];
    choices.innerHTML = `<div class="action-row">
      ${Object.entries(RECIPES).map(([id, recipe]) => `<button type="button" class="btn" data-act="shop-study:${id}" ${knowsRecipe(id) ? 'disabled' : ''}>抄${recipe.name} · 8U<small>${knowsRecipe(id) ? '已掌握' : `[Design] 占本段 · ${recipe.input}→${recipe.result}`}</small></button>`).join('')}
      <button type="button" class="btn btn-ok" data-act="shop-mp">真元 +20 · ~2U</button>
      <button type="button" class="btn" data-act="shop-hp">耐受 +30 · 6U</button>
      ${buys
        .map(([id, label, hint]) => {
          const owned = id === 'small' ? hasGu(id) && (run.gu.small.n || 1) >= 2 : hasGu(id);
          return `<button type="button" class="btn" data-act="shop-buy:${id}" ${owned ? 'disabled' : ''}>
            ${label}<small>${owned ? '已有' : hint}</small>
          </button>`;
        })
        .join('')}
      <button type="button" class="btn" data-act="leave-node">离开</button>
    </div>`;
    bindActs();
    return;
  }

  if (run.screen === 'refine') {
    title.textContent = '炼台';
    tag.textContent = `炼费 ${ECO.refinementFee}U · [Design] 成功率 95% · 失败投入全失`;
    scene.textContent = '先识方，再凑齐蛊。月芒和白玉都是二转蛊：一转可预先炼成，却不能直接上场。';
    tip.textContent = `已知：${Object.keys(RECIPES).filter(knowsRecipe).map((id) => RECIPES[id].name).join('、') || '无'}。`;
    choices.innerHTML = `<div class="action-row">
      <button type="button" class="btn btn-primary" data-act="refine-moonglow" ${knowsRecipe('moonglow') ? '' : 'disabled'}>炼月芒<small>${knowsRecipe('moonglow') ? '月光+双小光 → 二转月芒 · 12U' : '未识月芒方 · 商队抄录后可炼'}</small></button>
      <button type="button" class="btn" data-act="refine-whitejade" ${knowsRecipe('whitejade') ? '' : 'disabled'}>炼白玉<small>${knowsRecipe('whitejade') ? '玉皮+白豕 → 二转白玉 · 12U' : '未识白玉方 · 商队抄录后可炼'}</small></button>
      <button type="button" class="btn" data-act="refine-trade">拆小光换续航<small>毁同心 · 元回满 +8U · 12U</small></button>
      <button type="button" class="btn" data-act="leave-node">不炼，带走组合</button>
    </div>`;
    bindActs();
    return;
  }

  if (run.screen === 'prep') {
    const pf = run.pendingFight || { pick: 0 };
    const e = BATTLE_POOL[Math.min(pf.pick, BATTLE_POOL.length - 1)];
    title.textContent = '出战编制';
    tag.textContent = `心智容量 C=${READY_MAX} · 只带 ${READY_MAX} 只进本场`;
    scene.textContent = `即将对上：${e.name}\n${e.desc}\n\n背包里的蛊不会自动上场。这一场带谁，决定你有哪些杀招。`;
    tip.textContent = `已选 ${run.ready.length}/${READY_MAX}：${run.ready.map((id) => GU[id] ? GU[id].name : id).join('、') || '空'}。杀招依赖同场组合。`;
    const owned = ownedGuIds();
    hand.innerHTML = owned
      .map((id) => {
        const c = GU[id];
        const on = run.ready.includes(id);
        const overRank = (c.rank || 1) > run.rank;
        return `
          <button type="button" class="gu-btn ${on ? 'is-picked' : ''}" data-ready="${id}" ${overRank ? 'disabled' : ''}>
            <span class="name">${c.name}</span>
            <span class="cost">${overRank ? '转数不足' : on ? '出战' : '留守'}</span>
            <span class="desc">${c.desc}</span>
          </button>
        `;
      })
      .join('');
    hand.querySelectorAll('[data-ready]').forEach((b) => {
      b.addEventListener('click', () => toggleReady(b.getAttribute('data-ready')));
    });
    choices.innerHTML = `<div class="action-row">
      <button type="button" class="btn btn-primary" data-act="go-battle" ${run.ready.length ? '' : 'disabled'}>带这套进场</button>
    </div>`;
    bindActs();
    return;
  }

  if (run.screen === 'battle') {
    title.textContent = run.enemy.name;
    tag.textContent = `战斗 · 回合 ${run.turn}/${MODEL.combat.maxTurns}`;
    scene.textContent = run.enemy.desc;

    intent.hidden = false;
    const it = currentIntent();
    const extra = run.chargeBonus ? `（含蓄势 +${run.chargeBonus}）` : '';
    intent.innerHTML = `<strong>下一手意图</strong>　${it.label} · ${it.detail}${extra}`;

    enemyBox.hidden = false;
    const pct = Math.round((run.enemyHp / run.enemyMax) * 100);
    const packLine = run.enemy.carrier === 'beastPack'
      ? `<p>剩余单位 ${run.packUnits}/${run.enemy.packUnits}</p>` : '';
    const soulLine = run.enemy.carrier === 'soulBody'
      ? `<p>常规伤 −65%，爆发全额</p>` : '';
    enemyBox.innerHTML = `
      <h4>${run.enemy.name}</h4>
      <div class="hp-bar"><i style="width:${pct}%"></i></div>
      ${packLine}${soulLine}
      <p>${run.enemy.desc}</p>
    `;

    hand.innerHTML = activeCards()
      .map((id) => {
        const c = GU[id];
        const picked = run.picked.includes(id);
        const apLeft = MODEL.combat.actionsPerTurn - (pickedAp() - (picked ? c.ap : 0));
        const mpLeft = run.mp - (pickedCost() - (picked ? c.cost : 0));
        const cd = c.burst && run.burstCd > 0;
        const disabled =
          run.battleOver || (!picked && (apLeft < c.ap || mpLeft < c.cost || cd));
        return `
          <button type="button" class="gu-btn ${picked ? 'is-picked' : ''}" data-pick="${id}" ${disabled ? 'disabled' : ''}>
            <span class="name">${c.name}</span>
            <span class="cost">AP ${c.ap} · 元 ${c.cost}${cd ? ' · 冷却' + run.burstCd : ''}</span>
            <span class="desc">${c.desc}</span>
          </button>
        `;
      })
      .join('');
    hand.querySelectorAll('[data-pick]').forEach((b) => {
      b.addEventListener('click', () => togglePick(b.getAttribute('data-pick')));
    });

    if (run.battleOver) {
      btnResolve.hidden = true;
      btnClear.hidden = true;
      choices.innerHTML = `<div class="action-row">
        <button type="button" class="btn btn-primary" data-act="after-battle">
          ${run.battleWon ? '收下战果 · 进下一段' : '…'}
        </button>
      </div>`;
      tip.textContent = run.battleWon
        ? `毛收 +${ECO.grossPerPeriod}U。下一段先看伤和钱。`
        : '败了。';
      bindActs();
      return;
    }

    btnResolve.hidden = false;
    btnClear.hidden = false;
    const km = activeKillerMoves();
    if (km.length) {
      tip.textContent = '将触发杀招：' + km.map((k) => `${k.name}（${k.desc}）`).join('；');
    } else if (comboActive()) tip.textContent = '协同：月刃 ×2（杀招·月刃同心）。';
    else if (run.picked.includes('boar')) tip.textContent = '爆发吃满 2AP 与冷却——确认意图。';
    else tip.textContent = `AP ${MODEL.combat.actionsPerTurn}/回合 · 盾过期 · 杀招需同回合固定组合`;
    return;
  }

  if (run.screen === 'end') {
    title.textContent = '本局结束';
    tag.textContent = `第 ${meta.life} 世 · 蛊方已记入跨世记忆`;
    scene.textContent = '这世的蛊、钱和转数结束了。下一世带走已知蛊方，可以更早选择购蛊与炼蛊。';
    tip.textContent = '';
    choices.innerHTML = `<div class="action-row">
      <button type="button" class="btn btn-primary" data-act="restart">再活一世</button>
      <button type="button" class="btn" data-act="copy-log">复制完整日志</button>
      <button type="button" class="btn" data-act="export-log">导出日志文件</button>
    </div>`;
    bindActs();
    return;
  }
}

function bindOpts() {
  document.querySelectorAll('[data-opt]').forEach((b) => {
    b.addEventListener('click', () => {
      const seg = SEGS[run.seg];
      chooseOption(seg.options[Number(b.getAttribute('data-opt'))]);
    });
  });
}

function bindActs() {
  document.querySelectorAll('[data-act]').forEach((b) => {
    b.addEventListener('click', () => onAct(b.getAttribute('data-act')));
  });
}

function buildLogText() {
  const guNames = Object.values(run.gu)
    .filter((g) => g.alive)
    .map((g) => g.name + (g.n > 1 ? '×' + g.n : ''))
    .join('、');
  const head = [
    `# 一局蛊途 · 第 ${meta.life} 世 · 种子 ${baseSeed}`,
    `入局已知：${meta.known.filter((id) => !run.learnedThisLife.includes(id)).map((id) => RECIPES[id].name).join('、') || '无'} · 本世抄得：${run.learnedThisLife.map((id) => RECIPES[id].name).join('、') || '无'}`,
    `原著关系依据：${Object.values(RECIPES).map((recipe) => `${recipe.name} ${recipe.source}`).join('；')}`,
    `段 ${run.seg}/${SEGS.length - 1} · 结果 ${run.screen === 'end' ? (run.hp > 0 ? '走完' : '倒下') : '进行中'}`,
    `当前转数 ${run.rank}`,
    `钱包 ${run.wallet}U · 耐 ${run.hp} · 元 ${run.mp} · 伤次 ${run.wounds}`,
    `赚 ${run.earned}U · 供 ${run.spent.feed} · 治 ${run.spent.heal} · 炼 ${run.spent.refine} · 场 ${run.spent.field} · 抄方 ${run.spent.study} · 破境 ${run.spent.breakthrough}`,
    `在身：${guNames || '无'}`,
    '',
    '## 日志（新→旧）',
    '',
  ];
  const lines = run.log.map((l) => `[L${l.life} D${l.seg} ${l.kind}] ${l.text}`);
  return head.concat(lines).join('\n');
}

function onAct(key) {
  if (key === 'copy-log') {
    const t = buildLogText();
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(t).then(() => addLog('导出', '日志已复制到剪贴板，请粘贴给设计侧。'));
    } else {
      addLog('导出', '剪贴板不可用，请改用导出文件。');
    }
    render();
    return;
  }
  if (key === 'export-log') {
    const t = buildLogText();
    const blob = new Blob([t], { type: 'text/plain;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `gu-run-log-${Date.now()}.txt`;
    a.click();
    addLog('导出', '已下载日志 txt。');
    render();
    return;
  }
  if (key === 'go-battle') {
    const pf = run.pendingFight || { pick: 0, final: false };
    startBattle(pf.pick, pf.final);
    return;
  }
  if (key === 'start') {
    enterSeg();
    return;
  }
  if (key === 'restart') {
    document.getElementById('end-panel').hidden = true;
    if (run.screen === 'end') { meta.life = meta.completed + 1; saveMeta(); }
    clearCheckpoint();
    resetRun();
    render();
    return;
  }
  if (key === 'after-battle') {
    if (!run.battleWon) return;
    payFeed();
    nextSeg();
    return;
  }
  if (key === 'leave-node') {
    nextSeg();
    return;
  }
  if (key === 'rest-full') {
    doRest('full');
    return;
  }
  if (key === 'rest-half') {
    doRest('half');
    return;
  }
  if (key === 'rest-free') {
    doRest('free');
    return;
  }
  if (key === 'shop-mp') {
    doShop('mp');
    return;
  }
  if (key === 'shop-hp') {
    doShop('hp');
    return;
  }
  if (key.startsWith('shop-buy:')) {
    doShop('buy:' + key.slice(9));
    return;
  }
  if (key.startsWith('shop-study:')) {
    studyRecipe(key.slice(11));
    return;
  }
  if (key === 'refine-moonglow') {
    doRefine('moonglow');
    return;
  }
  if (key === 'refine-whitejade') {
    doRefine('whitejade');
    return;
  }
  if (key === 'refine-trade') {
    doRefine('trade');
    return;
  }
}

document.getElementById('btn-resolve').addEventListener('click', resolveTurn);
document.getElementById('btn-clear').addEventListener('click', () => {
  run.picked = [];
  render();
});
document.getElementById('btn-restart').addEventListener('click', () => {
  document.getElementById('end-panel').hidden = true;
  if (run.screen === 'end') { meta.life = meta.completed + 1; saveMeta(); }
  clearCheckpoint();
  resetRun();
  render();
});

document.getElementById('end-panel').hidden = true;
if (!restoreCheckpoint()) resetRun();
render();
