/* 一转→五转 经济—构筑—战斗 联合模拟（首跑） */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const load = (p) => JSON.parse(readFileSync(join(root, p), 'utf8'));
const vbSrc = readFileSync(join(root, 'js/vbalance.js'), 'utf8');
const vbatSrc = readFileSync(join(root, 'js/vbattle.js'), 'utf8');
new Function('globalThis', vbSrc)(globalThis);
new Function('globalThis', vbatSrc)(globalThis);
const VB = globalThis.VBalance;
const VBattle = globalThis.VBattle;

const guPack = load('data/gu.json');
const movesPack = load('data/killmoves.json');
const recipesPack = load('data/recipes.json');
const enemiesPack = load('data/enemies.json');
const shopsPack = load('data/shops.json');
const scales = load('data/scales.json');

const guList = guPack.gu;
const guById = Object.fromEntries(guList.map((g) => [g.id, g]));
const moves = movesPack.killmoves;
const moveById = Object.fromEntries(moves.map((m) => [m.id, m]));
const edges = recipesPack.edges;
const instances = enemiesPack.archetypes.flatMap((t) => t.instances.map((i) => ({ ...i, family: t.id, tests: t.tests, lootTag: t.lootTag })));

const ROUTES = {
  moonglow: ['moonlight_gu', 'small_light_gu', 'moon_glow_gu', 'golden_moon_gu', 'gold_wheel_break_gu', 'five_star_moon_wheel_gu'],
  frost: ['moonlight_gu', 'moon_spin_gu', 'moon_glow_gu', 'frost_moon_gu', 'cold_moon_seal_gu', 'cold_sky_moon_soul_gu'],
  phantom: ['moonlight_gu', 'moon_watch_gu', 'moon_veil_gu', 'moon_glow_gu', 'phantom_moon_gu', 'moon_shadow_gu', 'taiyin_lock_yuan_gu'],
  rainbow: ['moonlight_gu', 'jade_skin_gu', 'moon_rainbow_gu', 'treasure_moon_king_gu'],
  blood: ['moonlight_gu', 'small_light_gu', 'moon_glow_gu', 'blood_moon_gu', 'moon_soul_gu'],
};

function mulberry32(a) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function sampleIntents(inst) {
  return (inst.intents || []).map((it) => ({
    id: it.id,
    damage: it.damage,
    weight: it.weight || 1,
    hits: it.hits || 1,
    counterPool: it.counterPool || inst.counters || ['none'],
    aoe: !!it.aoe,
  }));
}

function battleOnce({ playerRank, owned, movesKnown, inst, seed }) {
  const sc = scales.scales[String(playerRank)];
  const player = {
    hp: sc.playerHp,
    maxHp: sc.playerHp,
    qi: 100,
    maxQi: 100,
    rank: playerRank,
    distance: 2,
    owned,
    movesKnown,
    route: 'sim',
  };
  const enemies = [{
    id: inst.id,
    name: inst.name,
    rank: inst.rank,
    hp: inst.hp,
    defense: inst.defense || 0,
    isBoss: !!inst.isBoss,
    resist: inst.resist || [],
    weak: inst.weak || [],
    intents: sampleIntents(inst),
    counters: inst.counters || ['none'],
  }];
  return VBattle.runBattle({
    player,
    enemies,
    guIndex: guById,
    moveIndex: moveById,
    battleSeed: seed,
  });
}

function simulateCareer({ routeName, seed, n = 20 }) {
  const route = ROUTES[routeName];
  const rng = mulberry32(seed);
  const results = [];
  for (let i = 0; i < n; i++) {
    const s = seed + i * 17;
    let stones = 20;
    let rank = 1;
    const owned = { moonlight_gu: 1 };
    const keepWatchAt5 = [];
    const timeline = [];
    let cleared = 0;
    let totalRounds = 0;
    let hpLeft = scales.scales['1'].playerHp;

    for (let r = 1; r <= 5; r++) {
      const pool = instances.filter((x) => x.rank === r);
      const fights = 6;
      for (let f = 0; f < fights; f++) {
        const inst = pool[Math.floor(rng() * pool.length)];
        // 构筑：拥有路线中当前能带的蛊
        const kit = {};
        for (const id of route) {
          const g = guById[id];
          if (!g || g.rank > r) continue;
          if (owned[id]) kit[id] = 1;
        }
        // 保证至少有核
        if (!Object.keys(kit).length) kit.moonlight_gu = 1;
        const km = moves.filter((m) => m.rank <= r && (m.coreGu || []).every((id) => kit[id] || owned[id])).map((m) => m.id).slice(0, 3);
        const res = battleOnce({ playerRank: r, owned: kit, movesKnown: km, inst, seed: s + f });
        totalRounds += res.rounds;
        if (res.result === 'clear') {
          cleared++;
          const inc = inst.isBoss
            ? scales.scales[String(r)].eliteStoneIncome
            : scales.scales[String(r)].battleStoneIncome;
          stones += Math.floor(inc[0] + rng() * (inc[1] - inc[0]));
          // 掉落：小概率关键件
          if (rng() < 0.25) {
            const next = route.find((id) => guById[id].rank === r && !owned[id]);
            if (next) owned[next] = 1;
          }
        }
        hpLeft = res.playerHp;
      }
      // 商店/炼蛊：尝试买/炼路线上的下一只
      const want = route.find((id) => guById[id].rank === r && !owned[id]);
      if (want) {
        const price = guById[want].economy.normalPrice;
        if (stones >= price) {
          stones -= price;
          owned[want] = 1;
          timeline.push({ rank: r, action: 'buy', id: want, price });
        } else {
          // 试炼
          const outs = edges.filter((e) => e.output === want);
          if (outs.length) {
            const e = outs[0];
            const once = VB.onceCostOf(e, (id) => guById[id]?.economy?.normalPrice || 20);
            if (stones >= e.stones) {
              stones -= e.stones;
              if (rng() < e.success) {
                owned[want] = 1;
                timeline.push({ rank: r, action: 'refine', id: want, recipe: e.id });
              } else {
                timeline.push({ rank: r, action: 'refine_fail', id: want, recipe: e.id });
              }
            }
          }
        }
      }
      // 保留一转功能蛊
      if (r === 5) {
        for (const id of ['moon_watch_gu', 'small_light_gu', 'stone_mark_gu', 'whirlwind_gu']) {
          if (owned[id]) keepWatchAt5.push(id);
        }
      }
      if (r < 5) {
        const bt = scales.scales[String(r)].breakthrough;
        if (stones >= bt.stone) {
          stones -= bt.stone;
          rank = r + 1;
          hpLeft = scales.scales[String(rank)].playerHp;
          timeline.push({ rank, action: 'breakthrough' });
        } else {
          timeline.push({ rank: r, action: 'stuck', stones });
          break;
        }
      }
    }
    const finalRank = Object.keys(owned).reduce((mx, id) => Math.max(mx, guById[id].rank), 1);
    results.push({
      cleared,
      totalRounds,
      stones,
      rank,
      finalGuCount: Object.values(owned).reduce((a, b) => a + b, 0),
      owned,
      keepR1: keepWatchAt5,
      reached5: rank >= 5,
      timeline,
    });
  }
  return results;
}

console.log('=== Vertical Lab 联合模拟 · 一转→五转 ===\n');
const N = Number(process.argv[2] || 30);
const all = {};
const routeShare = { moonglow: 0, frost: 0, phantom: 0, rainbow: 0, blood: 0 };

// 混合人群：随机路线
const mixed = [];
const mixRng = mulberry32(20260921);
const names = Object.keys(ROUTES);
for (let i = 0; i < N; i++) {
  const routeName = names[Math.floor(mixRng() * names.length)];
  routeShare[routeName]++;
  const batch = simulateCareer({ routeName, seed: 1000 + i * 31, n: 1 })[0];
  batch.routeName = routeName;
  mixed.push(batch);
}

for (const name of names) {
  all[name] = simulateCareer({ routeName: name, seed: 42 + name.length * 100, n: 12 });
}

const pct = (x, n) => ((100 * x) / n).toFixed(1) + '%';
console.log('路线占用（混合人群 n=' + N + '）');
for (const name of names) console.log(`  ${name}: ${routeShare[name]} (${pct(routeShare[name], N)})`);

console.log('\n各路线 12 局生涯摘要：');
for (const name of names) {
  const rs = all[name];
  const clear = rs.reduce((a, b) => a + b.cleared, 0);
  const reach5 = rs.filter((r) => r.reached5).length;
  const keep = rs.filter((r) => r.keepR1.length > 0).length;
  const avgGu = (rs.reduce((a, b) => a + b.finalGuCount, 0) / rs.length).toFixed(1);
  const avgRounds = (rs.reduce((a, b) => a + b.totalRounds, 0) / rs.length).toFixed(1);
  console.log(`  ${name}: clear ${clear}/${rs.length * 6} fights | reach5 ${reach5}/12 | keep R1 gu @5 ${keep}/12 | avgGu ${avgGu} | avgRounds ${avgRounds}`);
}

const mixedClear = mixed.reduce((a, b) => a + b.cleared, 0);
const mixed5 = mixed.filter((r) => r.reached5).length;
const mixedKeep = mixed.filter((r) => r.keepR1.length > 0);
const keepNames = {};
for (const m of mixedKeep) for (const id of m.keepR1) keepNames[id] = (keepNames[id] || 0) + 1;

console.log('\n混合人群总览：');
console.log(`  场次 clear ${mixedClear}/${N * 6} | 到五转 ${mixed5}/${N} | 五转仍留 1 转功能蛊 ${mixedKeep.length}/${N}`);
console.log('  最常保留一转蛊:', Object.entries(keepNames).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}×${v}`).join(', ') || '(none)');

// 低转保值验收
const keepRate = mixedKeep.length / N;
console.log(`\n[验收] 五转 build 保留 1~2 转功能蛊比例 = ${pct(mixedKeep.length, N)}（目标 10~30% 或更高）`);
if (keepRate > 0.9 && mixed5 === N) console.log('  WARN: 可能退化为全员保留，检查是否过强');
if (mixed5 > 0 && keepRate < 0.1) console.log('  FAIL: 系统退化为装备换代');
else if (mixedKeep.length > 0) console.log('  PASS: 低转功能蛊仍有保留');

// 单路线支配检测（粗）
const clearRates = names.map((n) => ({
  n,
  rate: all[n].reduce((a, b) => a + b.cleared, 0) / (all[n].length * 6),
}));
clearRates.sort((a, b) => b.rate - a.rate);
console.log('\n[支配粗检] clear rate:', clearRates.map((c) => `${c.n}=${(c.rate * 100).toFixed(0)}%`).join(' '));
if (clearRates[0].rate >= 0.9) console.log(`  DOMINANT_BUILD_ALERT? ${clearRates[0].n}=${(clearRates[0].rate * 100).toFixed(0)}%（不自动削弱，进人工评审）`);

// 经济购买力复核
console.log('\n[购买力目标]');
for (const t of [1, 2, 3, 4, 5]) {
  const s = scales.scales[String(t)];
  const mid = (s.battleStoneIncome[0] + s.battleStoneIncome[1]) / 2;
  console.log(`  R${t}: ${VB.purchasingPower(mid, s.guPriceMid).toFixed(2)} 只普通蛊/普通战  目标=${scales.purchasingPowerTarget[String(t)]}`);
}

// 炼耗 vs 市价抽样
console.log('\n[炼耗期望 vs 市价] 月芒/黄金月/宝月光王：');
for (const id of ['R09', 'R16', 'R27']) {
  const e = edges.find((x) => x.id === id);
  const market = guById[e.output].economy.normalPrice;
  const r = VB.refineVsMarket({ edge: e, marketPrice: market, priceOf: (x) => guById[x]?.economy?.normalPrice || 20 });
  console.log(`  ${e.id}→${e.output}: expected=${r.expected.toFixed(0)} market=${market} ratio=${r.ratio.toFixed(2)} ${r.verdict}`);
}

console.log('\nDONE');
