/* R1→R5 主链闭环探针（Integration 验收 · 非新引擎）
 * 只组装现有纯模块：mvp_logic / gu_rules / shop_rules / run_flow / balance
 * 禁止使用 vertical/vbattle。
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const ctx = vm.createContext({ console });
ctx.WORLD_BALANCE = JSON.parse(readFileSync(join(root, '../data/balance.json'), 'utf8'));
const loadJs = (rel) => vm.runInContext(readFileSync(join(root, rel), 'utf8'), ctx, { filename: rel });
loadJs('js/balance.js');
loadJs('js/mvp_content.js');
loadJs('js/mvp_logic.js');
loadJs('js/gu_rules.js');
loadJs('js/shop_rules.js');
loadJs('js/run_rules.js');
loadJs('js/run_flow.js');
// journey 数据（shop offers / pacing）；缺失则商店步记 GAP
let hasData = false;
try {
  loadJs('js/data.js');
  // data.js 使用 const DATA（浏览器全局）；vm 里用表达式取出
  ctx.DATA = vm.runInContext('typeof DATA !== "undefined" ? DATA : null', ctx);
  hasData = !!ctx.DATA;
} catch (e) {
  hasData = false;
  ctx.__dataErr = e.message;
}

const content = ctx.MVP_CONTENT;
const logic = ctx.MvpLogic;
const GuRules = ctx.GuRules;
const ShopRules = ctx.ShopRules;
const RunFlow = ctx.RunFlow;
const RunRules = ctx.RunRules;
const BAL = ctx.WORLD_BALANCE;

const steps = [];
const gaps = [];
const ok = (name, pass, detail) => steps.push({ name, ok: !!pass, detail: String(detail ?? '') });

const logicKeys = Object.keys(logic || {});
ok('mvp_logic.createRun', typeof logic?.createRun === 'function', logicKeys.slice(0, 6).join(','));
ok('GuRules/ShopRules/RunFlow', !!(GuRules && ShopRules && RunFlow), '');

/* 战斗 */
const run = logic.createRun(content);
ok('战斗 createRun', !!run && run.hp === 24, `hp=${run.hp} stones=${run.stones}`);

/* 资源 */
const rewardBase = Number(BAL.battle_stone_rewards?.base_by_tier?.common || 0);
run.stones = Number(run.stones || 0) + rewardBase * 3;
ok('资源：战斗元石入账', run.stones > 0, `stones=${run.stones}`);

/* 商店 */
if (hasData && ShopRules?.stock) {
  try {
    const offers = ctx.DATA.shopOffers || [];
    const pacingLayers = ctx.DATA.loot?.pacingLayers || {};
    const stock = ShopRules.stock(offers, { seed: 101, nodeKey: 'n1', pacingLayers, layer: 1, school: 'moon' });
    ok('商店 stock 生成', Array.isArray(stock), `n=${stock.length}`);
    ok('商店 layerPrice', ShopRules.layerPrice(pacingLayers, 1, 35) >= 35, ShopRules.layerPrice(pacingLayers, 1, 35));
  } catch (e) {
    ok('商店 stock 生成', false, e.message);
    gaps.push('GAP-SHOP: stock 调用失败 — ' + e.message);
  }
} else {
  ok('商店 stock 生成', false, hasData ? 'no ShopRules' : 'DATA 未加载');
  gaps.push('GAP-SHOP: js/data.js 或 ShopRules 不可用，购买步未接通');
}

/* 杀招组件 */
{
  const owned = run.owned;
  const inst = GuRules.killMoveRecipeInstances({ recipe: ['moonlight_gu', 'small_light_gu'] }, owned);
  ok('杀招组件实例解析', inst.length === 2 && inst.every((x) => typeof x === 'string'), JSON.stringify(inst));
}

/* 炼蛊 */
const forged = logic.applyForge(run, 'forge', content);
ok('炼蛊 applyForge', !!(forged && forged.run && forged.run.owned.moon_glow_gu >= 1), JSON.stringify(forged?.run?.owned || null));
if (forged?.run) Object.assign(run, forged.run);

/* 突破 R1→R5 */
const flowConfig = {
  aptitudeOrder: ['ding', 'bing', 'yi', 'jia'],
  smallBreakthroughCosts: {
    1: { 0: 5, 1: 8, 2: 12 },
    2: { 0: 15, 1: 20, 2: 25 },
    3: { 0: 30, 1: 40, 2: 50 },
    4: { 0: 60, 1: 80, 2: 100 },
  },
  sariByRank: { 1: 'sari_bronze_gu', 2: 'sari_red_iron_gu', 3: 'sari_silver_gu', 4: 'sari_gold_gu' },
};
let rank = 1;
let stage = 0;
let stones = 10000;
const ranks = [1];
for (let guard = 0; guard < 24; guard++) {
  const res = RunFlow.nextBreakthrough({ rank, stageIndex: stage, stones, aptitude: 'jia', owned: {} }, flowConfig);
  if (!res.ok) {
    ok(`突破 rank=${rank} stage=${stage}`, false, res.reason || res.missing || JSON.stringify(res));
    break;
  }
  stones -= Number(res.stoneCost || 0);
  if (res.kind === 'big' || res.targetRank) {
    rank = Number(res.targetRank || rank + 1);
    stage = 0;
  } else {
    stage = Number(res.nextStage ?? stage + 1);
  }
  ranks.push(rank);
  if (rank >= 5 && stage >= 3) break;
}
ok('突破链到达五转', rank === 5 && stage >= 3, `ranks=${ranks.join('→')}`);
ok('RunRules.restHeal', typeof RunRules?.restHeal === 'function', '');

for (const s of steps) console.log(`${s.ok ? 'PASS' : 'FAIL'}  ${s.name} — ${s.detail}`);
const fails = steps.filter((s) => !s.ok);
console.log(`\n== progression probe ${steps.length - fails.length}/${steps.length} ==`);
if (gaps.length) {
  console.log('\nCAPABILITY GAPS:');
  for (const g of gaps) console.log('  ' + g);
}
if (fails.length) process.exit(1);
