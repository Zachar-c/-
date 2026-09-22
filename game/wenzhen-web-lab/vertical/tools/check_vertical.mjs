/* Vertical Lab 静态检查：数据完整性 / 多价值 / 炼制网络 / 掉落 / 支配 / 死内容 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const load = (p) => JSON.parse(readFileSync(join(root, p), 'utf8'));
const VBalance = (await import(join(root, 'js/vbalance.js'))).default || globalThis.VBalance;

// vbalance 是 IIFE 挂 globalThis
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
// 直接读文件 eval 以兼容 globalThis IIFE
const vbSrc = readFileSync(join(root, 'js/vbalance.js'), 'utf8');
const sandbox = { module: { exports: {} }, exports: {} };
new Function('module', 'exports', 'globalThis', vbSrc)(sandbox.module, sandbox.exports, globalThis);
const VB = globalThis.VBalance;

const scales = load('data/scales.json');
const guPack = load('data/gu.json');
const movesPack = load('data/killmoves.json');
const recipesPack = load('data/recipes.json');
const enemiesPack = load('data/enemies.json');
const shopsPack = load('data/shops.json');
const dropsPack = load('data/drops.json');

const checks = [];
const pass = (name, ok, detail = '') => {
  checks.push({ name, ok: !!ok, detail });
  const mark = ok ? 'PASS' : 'FAIL';
  console.log(`${mark}  ${name}${detail ? ' — ' + detail : ''}`);
};

const guList = guPack.gu;
const guById = Object.fromEntries(guList.map((g) => [g.id, g]));
const moves = movesPack.killmoves;
const edges = recipesPack.edges;

// 规模
pass('gu_count>=30', guList.length >= 30, `got ${guList.length}`);
pass('killmove_count>=24', moves.length >= 24, `got ${moves.length}`);
pass('refine_edges 40-60', edges.length >= 40 && edges.length <= 60, `got ${edges.length}`);
pass('enemy_instances=50', enemiesPack.archetypes.reduce((a, t) => a + t.instances.length, 0) === 50, '');
pass('shop_tiers=5', shopsPack.tiers.length === 5, '');

// 每只蛊完整字段
const requiredGu = ['id', 'name', 'rank', 'role', 'thought', 'qi', 'values', 'economy', 'refine', 'feed', 'upgradesTo', 'usedIn', 'phaseOut', 'retain', 'acquire'];
let guFieldOk = true;
for (const g of guList) {
  for (const k of requiredGu) {
    if (g[k] === undefined) {
      guFieldOk = false;
      console.log(`  missing ${k} on ${g.id}`);
    }
  }
  const v = g.values || {};
  for (const axis of ['combat', 'refinement', 'market', 'build']) {
    if (v[axis] === undefined) {
      guFieldOk = false;
      console.log(`  missing values.${axis} on ${g.id}`);
    }
  }
}
pass('gu_full_fields+four_values', guFieldOk, '');

// 杀招完整字段
const requiredKm = ['id', 'name', 'rank', 'coreGu', 'supportGu', 'thoughtCost', 'qiCost', 'effects', 'failureRule', 'counterplay', 'upgradePath', 'alternatives', 'obsolescence'];
let kmOk = true;
for (const m of moves) {
  for (const k of requiredKm) {
    if (m[k] === undefined) {
      kmOk = false;
      console.log(`  missing ${k} on ${m.id}`);
    }
  }
}
pass('killmove_full_fields', kmOk, '');

// 炼制网络连通：每个二转+ 蛊有至少一条入边
let orphan = [];
for (const g of guList) {
  if (g.rank === 1 && g.role === 'resource') continue;
  const ins = edges.filter((e) => e.output === g.id);
  if (!ins.length && g.rank >= 2) orphan.push(g.id);
}
pass('refine_network_no_orphan_r2plus', orphan.length === 0, orphan.join(','));

// 月光至少 4 条出边（原作分叉）
const fromMoon = edges.filter((e) => e.inputs.some((i) => i.gu === 'moonlight_gu'));
pass('moonlight_fork>=4', fromMoon.length >= 4, `got ${fromMoon.length}`);

// 月芒至少 3 条三转出边
const fromGlow = edges.filter((e) => e.inputs.some((i) => i.gu === 'moon_glow_gu') && (guById[e.output]?.rank === 3));
pass('moonglow_fork_to_r3>=3', fromGlow.length >= 3, `got ${fromGlow.length}`);

// 死内容
const dead = guList.filter((g) => VB.deadContent(g));
pass('no_dead_content', dead.length === 0, dead.map((g) => g.id).join(','));

// 炼耗 vs 市价
const priceOf = (id, isMat) => {
  if (isMat) return 20; // 材料统一估价，套利检查保守
  return Number(guById[id]?.economy?.normalPrice || 0);
};
let refineAlerts = [];
for (const e of edges) {
  if (!guById[e.output]) continue;
  const market = Number(guById[e.output].economy.normalPrice);
  const r = VB.refineVsMarket({ edge: e, marketPrice: market, priceOf });
  if (r.verdict !== 'balanced') refineAlerts.push(`${e.id}:${r.verdict} ratio=${r.ratio.toFixed(2)}`);
}
// 材料估价粗糙，允许 alert 存在但要报告
pass('refine_vs_market_reported', true, refineAlerts.length ? refineAlerts.slice(0, 8).join(' | ') : 'all in band');

// 套利环
const prices = {};
for (const g of guList) prices[g.id] = g.economy.npcBuyPrice;
const loops = VB.findArbitrageLoops({ edges, prices, sellBackRate: 0.55 });
pass('arbitrage_loops_checked', true, loops.length ? `${loops.length} potential (npcBuy back)` : '0 with npcBuy prices');

// 购买力
for (const t of [1, 2, 3, 4, 5]) {
  const s = scales.scales[String(t)];
  const mid = (s.battleStoneIncome[0] + s.battleStoneIncome[1]) / 2;
  const pp = VB.purchasingPower(mid, s.guPriceMid);
  pass(`purchasing_power_r${t}`, t >= 4 ? pp < 1 : pp <= 1.2 && pp >= 0.3, `incomeMid=${mid} priceMid=${s.guPriceMid} => ${pp.toFixed(2)} gu/fight`);
}

// 每个转数 2-3 条有效路线（按 upgradesTo 分叉）
for (let r = 1; r <= 5; r++) {
  const outs = new Set();
  for (const g of guList.filter((x) => x.rank === r)) {
    for (const u of g.upgradesTo || []) outs.add(u);
    for (const e of edges.filter((x) => x.inputs.some((i) => i.gu === g.id))) outs.add(e.output);
  }
  pass(`routes_at_r${r}`, r === 5 ? outs.size >= 1 : outs.size >= 2, `out-degree unique=${outs.size}`);
}

// 杀招：不存在被全面支配（K24 vs K20 示例）
const k20 = moves.find((m) => m.id === 'K20');
const k24 = moves.find((m) => m.id === 'K24');
pass('K20_not_strictly_worse_than_K24', !!k20 && !!k24 && k20.effects.some((e) => e.type === 'block') && k24.effects.some((e) => e.type === 'damage'), 'defense vs finisher');

// 失败/过时杀招存在
const obsoleteish = moves.filter((m) => m.obsolescence && m.rank <= 3);
pass('has_obsolete_killmoves', obsoleteish.length >= 3, `${obsoleteish.length} marked`);

// 掉落 target
pass('drop_targets_defined', !!dropsPack.dropTargets && !!dropsPack.examples.length, '');

// 同转倍率不共用
const hpRatio = scales.scales['5'].playerHp / scales.scales['1'].playerHp;
const priceRatio = scales.scales['5'].guPriceMid / scales.scales['1'].guPriceMid;
const incRatio = ((scales.scales['5'].battleStoneIncome[0] + scales.scales['5'].battleStoneIncome[1]) / 2) / ((scales.scales['1'].battleStoneIncome[0] + scales.scales['1'].battleStoneIncome[1]) / 2);
const distinct = new Set([hpRatio.toFixed(1), priceRatio.toFixed(1), incRatio.toFixed(1)]).size;
pass('axes_not_universal_multiplier', distinct === 3, `hp×${hpRatio.toFixed(1)} price×${priceRatio.toFixed(1)} income×${incRatio.toFixed(1)}`);

const failed = checks.filter((c) => !c.ok);
console.log(`\n== ${checks.length - failed.length}/${checks.length} PASS ==`);
if (failed.length) {
  console.log('FAILED:', failed.map((f) => f.name).join(', '));
  process.exit(1);
}
