/* 《问真》Vertical Lab · 多价值/炼耗/套利校验器
 * 身份：检测工具，不是定价法律。上位公理 > 本文件。
 * 禁止单一 value 决定一切；禁止「超预算→削弱」。
 */
globalThis.VBalance = (() => {
  const VALUES = ['combat', 'refinement', 'market', 'build'];

  function multiValue(gu) {
    const v = gu?.values || {};
    const out = {
      combat: Number(v.combat || 0),
      refinement: Number(v.refinement || 0),
      market: Number(v.market || 0),
      build: v.build && typeof v.build === 'object' ? { ...v.build } : {},
    };
    out.buildMax = Math.max(0, ...Object.values(out.build).map(Number));
    return out;
  }

  /* 期望炼耗 = 单次成本 / 成功率 + 失败损失期望
   * V0.1 失败=投入全毁，故期望成本 = once / success。 */
  function expectedRefineCost({ onceCost, success, failLoss = 0 }) {
    const s = Math.min(1, Math.max(0.01, Number(success || 0)));
    const once = Number(onceCost || 0);
    const fail = Number(failLoss || 0);
    return once / s + fail * (1 - s) / s;
  }

  function onceCostOf(edge, priceOf) {
    let sum = Number(edge.stones || 0);
    for (const inp of edge.inputs || []) {
      const p = priceOf(inp.gu) || 0;
      sum += p * Number(inp.n || 1);
    }
    for (const m of edge.materials || []) {
      const p = priceOf(m.id, true) || 0;
      sum += p * Number(m.n || 1);
    }
    return sum;
  }

  /* 市价应接近 expectedCost×1.1~1.3；否则「永远买」或「永远炼」 */
  function refineVsMarket({ edge, marketPrice, priceOf, band = [1.1, 1.3] }) {
    const once = onceCostOf(edge, priceOf);
    const expected = expectedRefineCost({ onceCost: once, success: edge.success });
    const ratio = expected > 0 ? marketPrice / expected : Infinity;
    let verdict = 'balanced';
    if (ratio < band[0]) verdict = 'always_refine_alert';
    if (ratio > band[1]) verdict = 'always_buy_alert';
    return {
      edgeId: edge.id,
      once,
      expected,
      marketPrice,
      ratio,
      verdict,
      band: band.slice(),
      success: edge.success,
    };
  }

  /* 套利环：购买→炼→出售；商店买材料回卖；掉落刷资源 */
  function findArbitrageLoops({ edges, prices, sellBackRate = 0.55, tolerance = 0 }) {
    const loops = [];
    const priceOf = (id) => Number(prices[id] || 0);

    for (const e of edges) {
      const outP = priceOf(e.output) * sellBackRate;
      let inP = Number(e.stones || 0);
      for (const inp of e.inputs || []) inP += priceOf(inp.gu) * Number(inp.n || 1);
      for (const m of e.materials || []) inP += priceOf(m.id) * Number(m.n || 1);
      const expectedOut = outP; // 成功才有产出；失败血本无归
      const costWithFail = expectedRefineCost({ onceCost: inP, success: e.success, failLoss: 0 });
      const profit = expectedOut - costWithFail;
      if (profit > tolerance) {
        loops.push({
          kind: 'buy_refine_sell',
          edgeId: e.id,
          output: e.output,
          inputCost: inP,
          expectedCost: costWithFail,
          sellBack: outP,
          profit,
          note: '材料价/回收率敏感；禁止无限钱',
        });
      }
    }
    return loops;
  }

  /* 死内容：无战斗/炼/经济/材料用途 */
  function deadContent(gu) {
    const uses = (gu.usedIn || []).length;
    const up = (gu.upgradesTo || []).length;
    const role = gu.role;
    const combat = Number(gu.values?.combat || 0) + Number(gu.damage || 0) + Number(gu.block || 0);
    const refine = Number(gu.values?.refinement || 0);
    const market = Number(gu.values?.market || 0);
    const only = combat < 5 && refine < 5 && market < 5 && uses === 0 && up === 0 && role !== 'resource';
    return only;
  }

  /* 构筑支配：同转对 10 类敌人胜率≥90% 且 HP/Qi/回合均最低 25% → ALERT，不自动削弱 */
  function dominantBuild(report) {
    const { winRate, hpRankPct, qiRankPct, roundRankPct } = report;
    return winRate >= 0.9 && hpRankPct <= 0.25 && qiRankPct <= 0.25 && roundRankPct <= 0.25;
  }

  /* 跨转催动成本 */
  function actualQiCost(baseQi, playerRank, guRank) {
    if (guRank > playerRank) return null; // 不可催动
    const mult = Math.pow(0.65, playerRank - guRank);
    return Math.max(1, Math.round(baseQi * mult));
  }

  function purchasingPower(midIncome, midPrice) {
    return midPrice > 0 ? midIncome / midPrice : 0;
  }

  return Object.freeze({
    VALUES,
    multiValue,
    expectedRefineCost,
    onceCostOf,
    refineVsMarket,
    findArbitrageLoops,
    deadContent,
    dominantBuild,
    actualQiCost,
    purchasingPower,
  });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.VBalance;
