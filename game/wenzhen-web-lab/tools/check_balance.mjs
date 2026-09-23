/* 数值预算校验器：content 必须与 balance.js 推导一致，且遭遇落在目标窗口。
 *
 * 用法：
 *   node tools/check_balance.mjs
 *   node tools/check_balance.mjs --json
 *
 * 扩到成百上千只蛊时，本工具是 CI 门禁：新增 gu 只允许声明 (rank, role, costs, modifier)，
 * 任何与推导不一致的手写敌人数字、任何超出窗口的遭遇，在这里失败。
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { pathToFileURL } from 'node:url';

const root = path.resolve(import.meta.dirname, '..');
const load = (rel) => {
  const src = readFileSync(path.join(root, rel), 'utf8');
  vm.runInContext(src, context, { filename: rel });
};

const context = vm.createContext({});
/* Rank 真源注入（Integration 刀1）：balance.js 只做投影，不再自带第三套 Rank。 */
context.WORLD_BALANCE = JSON.parse(readFileSync(path.join(root, '../data/balance.json'), 'utf8'));
load('js/balance.js');
load('js/mvp_content.js');

const B = context.MvpBalance;
const content = context.MVP_CONTENT;

const rows = [];
const add = (name, ok, detail) => rows.push({ name, ok, detail: String(detail) });

/* ---- Rank 主链门禁（改 balance.json 必须立刻反映到 Lab） ---- */
const world = B.WORLD;
const worldBudget = world.rank_power_budget?.budget_by_rank || {};
const step = Number(world.rank_step_ratio || 0);
add('WORLD rank_step_ratio=2', step === 2, step);
add('WORLD human_base_health=100', Number(world.human_base_health) === 100, world.human_base_health);
add('WORLD thought_base_capacity=3', Number(world.thought_base_capacity) === 3, world.thought_base_capacity);
add('WORLD stone_to_essence_per_stone=5', Number(world.stone_to_essence_per_stone) === 5, world.stone_to_essence_per_stone);
for (let r = 1; r <= 5; r++) {
  const w = Number(worldBudget[String(r)] ?? worldBudget[r]);
  const expectLab = w / B.LAB_BUDGET_PROJECTION;
  add(`R${r} labBudget=WORLD/${B.LAB_BUDGET_PROJECTION}`, Math.abs(expectLab - w / 20) < 1e-9 && B.worldRankBudget(r) === w, `world=${w} lab=${expectLab}`);
  add(`R${r} rankMultiplier=step^(r-1)`, B.rankMultiplier(r) === Math.pow(step, r - 1), B.rankMultiplier(r));
}
add('LAB playerHp=24 is PROJECTION of 100', B.LAB.playerHp === 24 && B.LAB.fullGame.humanHp === 100, `${B.LAB.playerHp}/${B.LAB.fullGame.humanHp}`);
add('LAB thoughts=2 is PROJECTION of 3', B.LAB.thoughtsPerTurn === 2 && B.LAB.fullGame.thoughtBaseCapacity === 3, `${B.LAB.thoughtsPerTurn}/${B.LAB.fullGame.thoughtBaseCapacity}`);

/* 刀2：mvp_content 必须是 override 清单，不是第二套蛊库 */
const actionIds = Object.keys(content.actions || {});
add('mvp actions 全部带 guRef', actionIds.length > 0 && actionIds.every((id) => content.actions[id].guRef), actionIds.join(','));
add('mvp actions 全部带 overrideReason', actionIds.every((id) => String(content.actions[id].overrideReason || '').length > 0), '');
/* 刀4：炼方 provenance 指回 refinement_recipes */
const forge = content.forge || {};
add('forge 标注 formal recipe owner', !!forge.recipeId && (forge.recipeOwner === 'game/data/refinement_recipes.json'), forge.recipeId);

/* Effect/GuRole 对齐（数值模型续）：身份 OWNER=gu.json；lab 只投影效果量 */
const guCatalog = JSON.parse(readFileSync(path.join(root, '../data/gu.json'), 'utf8'));
const guById = new Map(guCatalog.map((g) => [g.id, g]));
let labOnly = [];
let effectLinked = 0;
for (const id of actionIds) {
  const a = content.actions[id];
  const formal = guById.get(a.guRef);
  if (!formal) {
    labOnly.push(a.guRef);
    continue;
  }
  const v1 = formal.v1_effect || {};
  if (v1.kind === 'strike' && Number(v1.amount) > 0 && Number(a.damage || 0) > 0) effectLinked++;
}
add(
  'mvp guRef 在 gu.json 有身份或标明 lab-only',
  labOnly.every((x) => x.endsWith('_gu')),
  `lab-only=${labOnly.join(',') || '(none)'} linkedStrike=${effectLinked}`,
);
/* Role：formal slot_role/role 与 lab 行为不一致只警告，不在此判对错 */
const roleNote = actionIds
  .map((id) => {
    const f = guById.get(content.actions[id].guRef);
    return f ? `${id}:${f.slot_role || f.role}` : `${id}:lab-only`;
  })
  .join(' ');
add('Effect 形状来自 gu.json.v1_effect（lab 为投影）', effectLinked >= 1 || labOnly.length > 0, roleNote);

const report = content.balanceReport;
const refDpr = report.refDpr;
add('refDpr > 0', refDpr > 0, refDpr);

/* 窗口来自 L1 V4.1（产品代理指标），可执行检查必须咬住 */
const WINDOW = {
  battle_1: [3, 5],
  battle_2: [4, 6],
  elite: [4, 6],
  boss: [6, 9],
};
const ENEMY_KEY = {
  battle_1: 'ridge_hound',
  battle_2: 'iron_hide_boar',
  elite: 'ridge_elite_scout',
  boss: 'thunder_crown_sovereign',
};
const SEQ = {
  battle_1: report.sequences.seqHound,
  battle_2: report.sequences.seqBoar,
  elite: report.sequences.seqSeal,
  boss: [...report.sequences.seqBoss1, ...report.sequences.seqBoss2],
};

for (const [key, window] of Object.entries(WINDOW)) {
  const enemyId = ENEMY_KEY[key];
  const enemy = content.enemyProfiles[enemyId];
  const zeroRate = B.counterZeroRate(SEQ[key]);
  const overrideReason = enemy.overrideReason || content.balanceReport.overrideReasons?.[enemyId] || '';
  const check = B.checkEncounter({
    name: key,
    dpr: refDpr,
    enemyHp: enemy.hp,
    turnWindow: window,
    zeroRate,
    margin: 1.08,
    targetTurns: report.targetTurns[key],
    overrideReason,
  });
  add(
    `${key} 可达回合落在 ${window[0]}~${window[1]}`,
    check.windowOk,
    `hp=${enemy.hp} dpr=${refDpr.toFixed(2)} zero=${zeroRate.toFixed(2)} → ${check.achievableTurns.toFixed(2)} 回合（建议 HP ${check.recommendedHp}）`,
  );
  add(
    `${key} HP 过 H1 门（偏差≤20% 或有 override_reason）`,
    check.overrideOk,
    `偏差 ${(check.deviation * 100).toFixed(1)}%${check.needsOverride ? ` · reason=${check.overrideReason || '(缺)'}` : ''}`,
  );
}

/* 威胁预算（L1 P1-H2 冻结）：handleRate=0.35；survivalRate 按等级 */
const SURVIVAL = {
  battle_1: B.THREAT_V1.survivalRateByTier.hound,
  battle_2: B.THREAT_V1.survivalRateByTier.common,
  elite: B.THREAT_V1.survivalRateByTier.elite,
  boss: B.THREAT_V1.survivalRateByTier.boss,
};
for (const key of Object.keys(WINDOW)) {
  const enemyId = ENEMY_KEY[key];
  const profile = content.enemyProfiles[enemyId];
  const budget = B.deriveEnemyDamagePerTurn({
    playerHp: content.run.hp,
    targetTurns: report.targetTurns[key],
    survivalRate: SURVIVAL[key],
    handleRate: B.THREAT_V1.handleRate,
  });
  const intents = [
    ...(profile.intents || []),
    ...(profile.phaseOne || []),
    ...(profile.phaseTwo || []),
  ].filter((i) => Number(i.damage || 0) > 0);
  const avg = intents.length
    ? intents.reduce((n, i) => n + Number(i.damage || 0), 0) / intents.length
    : 0;
  const all = (profile.intents || profile.phaseOne || []).length
    + (profile.phaseTwo || []).length;
  const dmgShare = all ? intents.length / all : 1;
  const dpt = avg * dmgShare;
  add(
    `${key} 威胁窗（survival=${SURVIVAL[key]} handle=0.35）`,
    dpt <= budget + 0.6,
    `均伤${avg.toFixed(2)}×占比${dmgShare.toFixed(2)}=${dpt.toFixed(2)} 预算${budget.toFixed(2)}`,
  );
}

/* 投影自检：WORLD 40 → LAB 2 */
add(
  'LAB_BUDGET_PROJECTION=20 投影自检',
  B.LAB_BUDGET_PROJECTION === 20 && B.priceGu({ rank: 1, archetype: 'strike' }).budget === 2,
  `projection=${B.LAB_BUDGET_PROJECTION} r1budget=${B.priceGu({ rank: 1, archetype: 'strike' }).budget}`,
);
add(
  'rankMultiplier 同形 2^(r-1)',
  B.rankMultiplier(5) === 16 && B.rankMultiplier(1) === 1,
  `m(5)=${B.rankMultiplier(5)}`,
);
add('pricingId=LAB_PRICING_V1', B.PRICING_ID === 'LAB_PRICING_V1', B.PRICING_ID);

/* Market 投影自检：与 market_rules.gd 同式，禁止第二套定价 */
const M = B.Market;
add('Market owner=market_rules.gd', M.owner === 'game/scripts/domain/market_rules.gd', M.owner);
add('t1MaterialBase=stone_per_t1_material', M.t1MaterialBasePrice() === Number(world.stone_per_t1_material ?? 10), M.t1MaterialBasePrice());
add('publicResale(value)=value*public_buyback_ratio', M.publicResale(10) === 10 * Number(world.public_buyback_ratio ?? 0.5), M.publicResale(10));
add('guPublicPrice=rankStandard*4', M.guPublicPrice(1) === M.rankStandardPrice(1) * 4, M.guPublicPrice(1));
add('guRecyclePrice=rankStandard*1', M.guRecyclePrice(1) === M.rankStandardPrice(1), M.guRecyclePrice(1));
add('guEstimate=rankStandard*gu_estimate_ratio', M.guEstimate(1) === M.rankStandardPrice(1) * Number(world.gu_estimate_ratio ?? 6.5), M.guEstimate(1));
add('gu_value_by_rank 3/5/8/12/20', [1, 2, 3, 4, 5].map((r) => M.guValueByRank(r)).join(',') === '3,5,8,12,20', [1, 2, 3, 4, 5].map((r) => M.guValueByRank(r)).join(','));
add('sellValue=publicResale(gu.value) 同式', Math.floor(5 * M.publicBuybackRatio()) === 2, `floor(5*${M.publicBuybackRatio()})`);
add('demandQuote tier=1 即挂牌价', M.demandQuote(10, 1, 1).unitPrice === 10, M.demandQuote(10, 1, 1).unitPrice);
add('demandQuote tier=2 +20%', M.demandQuote(10, 1, 2).unitPrice === 12, M.demandQuote(10, 1, 2).unitPrice);
add('infoValue 随 spread 减半', M.infoValue(20, 1) === 10, M.infoValue(20, 1));

/* 规模化烟测：priceGu 一转平砍应接近 lab 标准 2 伤 */
const sample = B.priceGu({ rank: 1, role: 'attack', archetype: 'strike', thought: 1, qi: 1, cooldown: 0 });
add('priceGu 一转平砍 ≈2 伤', sample.damage >= 1 && sample.damage <= 3, sample.damage);

const pass = rows.filter((r) => r.ok).length;
for (const r of rows) {
  console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name}  (${r.detail})`);
}
console.log(`\n  ${pass}/${rows.length} 项通过`);
if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ refDpr, report, rows }, null, 2));
}
process.exit(pass === rows.length ? 0 : 3);
