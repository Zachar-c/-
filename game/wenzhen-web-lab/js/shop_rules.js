// Deterministic shop shelf rules ported from shop_command_rules.gd.
globalThis.ShopRules = (() => {
  const GOODS_KINDS = ['purchase', 'material_purchase'];
  const SERVICE_KINDS = ['gu_fang_unlock'];

  // L0 2026-09-25 Phase 0：无机械收益/已退役商品不得作为正式可购成长项。
  const isLiveOffer = (offer) => {
    if (!offer || offer.retired || offer.live === false) return false;
    if (offer.mechanical === false) return false;
    return true;
  };

  const saltHash = (salt) => {
    let digest = 0n;
    for (const character of String(salt || '')) {
      digest = BigInt.asIntN(64, digest * 31n + BigInt(character.charCodeAt(0)));
    }
    return digest;
  };

  const mixedSeed = (seed, salt) =>
    BigInt.asIntN(64, BigInt(seed) * 1000003n + saltHash(salt));

  function seededShuffle(seed, salt, items) {
    const shuffled = [...(items || [])];
    let state = mixedSeed(seed, salt);
    if (state < 0n) state = -state;
    state %= 2147483647n;
    if (state === 0n) state = 1n;
    for (let i = shuffled.length - 1; i > 0; i -= 1) {
      state = (state * 48271n) % 2147483647n;
      const j = Number(state % BigInt(i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  const slotCount = (layer) => 4 + Math.trunc(Math.max(1, Number(layer) || 1) / 2);

  function layerConfig(pacingLayers, layer) {
    const normalized = Math.min(5, Math.max(1, Number(layer) || 1));
    return pacingLayers?.[String(normalized)] || {};
  }

  const maxTier = (pacingLayers, layer) =>
    Number(layerConfig(pacingLayers, layer).shop_max_tier || 1);

  // 成交价 = 货架挂牌 stone_cost × 层加价。挂牌属内容数据；层加价 OWNER=
  // pacing.shop_price_pct（稀缺/进度轴），不是第二套 market_rules 定价。
  // 市场公价/回收参照 MvpBalance.Market（= market_rules.gd），此处只叠层。
  function layerPrice(pacingLayers, layer, base) {
    const price = Math.max(0, Number(base) || 0);
    const percent = Number(layerConfig(pacingLayers, layer).shop_price_pct || 0);
    return price + Math.trunc((price * percent) / 100);
  }

  function goodsPool(offers, { pacingLayers, layer, school } = {}) {
    const cap = maxTier(pacingLayers, layer);
    return (offers || [])
      .filter((offer) => GOODS_KINDS.includes(String(offer.kind || '')))
      .filter((offer) => Number(offer.tier || 1) <= cap)
      .filter((offer) => !offer.school || String(offer.school) === String(school || ''))
      .filter((offer) => !offer.npc_only)
      .filter(isLiveOffer)
      .map((offer) => String(offer.id))
      .sort();
  }

  const stockSalt = (nodeKey) => `shop.stock.${String(nodeKey || '')}`;

  const offerById = (offers, id) =>
    (offers || []).find((offer) => String(offer.id) === String(id)) || null;

  function hasTier(stock, offers, tier) {
    return stock.some((id) => Number(offerById(offers, id)?.tier || 1) === Number(tier));
  }

  function isSchoolOffer(offer, school) {
    return !!school
      && String(offer?.kind || '') === 'purchase'
      && String(offer?.school || '') === String(school);
  }

  function hasSchoolGu(stock, offers, school) {
    if (!school) return true;
    return stock.some((id) => isSchoolOffer(offerById(offers, id), school));
  }

  function pickCandidate(seed, salt, pool, offers, predicate) {
    const candidates = pool.filter(predicate);
    if (!candidates.length) return '';
    return seededShuffle(seed, salt, candidates)[0];
  }

  function stock(offers, { seed, nodeKey, pacingLayers, layer, school, slotOverride = 0 } = {}) {
    const pool = goodsPool(offers, { pacingLayers, layer, school });
    if (!pool.length) return [];
    const slots = Math.min(
      slotOverride > 0 ? Math.trunc(slotOverride) : slotCount(layer),
      pool.length,
    );
    const salt = stockSalt(nodeKey);
    const result = seededShuffle(seed, salt, pool).slice(0, slots);
    const cap = maxTier(pacingLayers, layer);
    if (!hasTier(result, offers, cap)) {
      const top = pickCandidate(
        seed,
        `${salt}.guarantee`,
        pool.filter((id) => !result.includes(id)),
        offers,
        (id) => Number(offerById(offers, id)?.tier || 1) === cap,
      );
      if (top) result[result.length - 1] = top;
    }
    if (!hasSchoolGu(result, offers, school)) {
      const schoolPick = pickCandidate(
        seed,
        `${salt}.school`,
        pool.filter((id) => !result.includes(id)),
        offers,
        (id) => isSchoolOffer(offerById(offers, id), school),
      );
      if (schoolPick) result[result.length - 1] = schoolPick;
    }
    return result;
  }

  const offerIsStocked = (offers, offerId, context = {}) => {
    const offer = offerById(offers, offerId);
    if (!offer) return false;
    if (!isLiveOffer(offer)) return false;
    if (SERVICE_KINDS.includes(String(offer.kind || ''))) return true;
    if (!GOODS_KINDS.includes(String(offer.kind || ''))) return false;
    return stock(offers, context).includes(String(offerId));
  };

  // ---- Phase 7：购买力与三竞争 ----
  // I = 同层普通战毛收入（stones）。不用绝对石价，用「几场 I」。
  function incomeUnit(stoneRewards = {}, tier = 'common', layer = 1) {
    const base = Number(stoneRewards.base_by_tier?.[tier] ?? stoneRewards.base_by_tier?.common ?? 3);
    const step = Number(stoneRewards.layer_step_pct || 0) / 100;
    return base + Math.trunc(base * step * Math.max(0, Number(layer || 1) - 1));
  }

  function fightsOfI(cost, I) {
    const unit = Math.max(1, Number(I || 1));
    return Math.round((Number(cost || 0) / unit) * 100) / 100;
  }

  function nextBreakthroughCost({ rank = 1, stageIndex = 0, flow = {}, owned = {} }) {
    const small = flow.smallBreakthroughCosts?.[String(rank)] || flow.smallBreakthroughCosts?.[rank];
    const stages = Array.isArray(small) ? small.length : 3;
    const idx = Math.max(0, Math.min(stages - 1, Number(stageIndex || 0)));
    if (Array.isArray(small) && Number(stageIndex || 0) < stages) {
      return Number(small[idx] || 0);
    }
    const big = flow.bigStoneCosts?.[String(Number(rank) + 1)] ?? flow.bigStoneCosts?.[Number(rank) + 1];
    if (big != null) return Number(big);
    void owned;
    return null;
  }

  function spendPressures({
    stones = 0, materials = {}, owned = {}, rank = 1, stageIndex = 0,
    offers = [], recipes = [], flow = {}, stoneRewards = {}, layer = 1,
  } = {}) {
    const I = incomeUnit(stoneRewards, 'common', layer);
    const options = [];
    for (const offer of offers) {
      if (!isLiveOffer(offer)) continue;
      if (offer.kind !== 'purchase' || !offer.gu_id) continue;
      const cost = Number(offer.stone_cost || 0);
      options.push({
        kind: 'buy_build',
        id: offer.id,
        label: `买构筑·${offer.gu_id}`,
        cost,
        fights: fightsOfI(cost, I),
        affordable: cost <= stones,
        pressure: cost <= stones && fightsOfI(cost, I) <= 6 ? 2 : 1,
      });
    }
    for (const offer of offers) {
      if (!isLiveOffer(offer)) continue;
      if (offer.kind !== 'material_purchase' || !offer.material_id) continue;
      const cost = Number(offer.stone_cost || 0);
      const missingKey = Number(materials[offer.material_id] || 0) < 1;
      options.push({
        kind: 'buy_material',
        id: offer.id,
        label: `买材料·${offer.material_id}`,
        cost,
        fights: fightsOfI(cost, I),
        affordable: cost <= stones,
        pressure: cost <= stones && missingKey && fightsOfI(cost, I) <= 3 ? 3 : 1,
      });
    }
    const breakCost = nextBreakthroughCost({ rank, stageIndex, flow, owned });
    if (breakCost != null) {
      options.push({
        kind: 'save_breakthrough',
        id: 'save_breakthrough',
        label: '存元石突破',
        cost: breakCost,
        fights: fightsOfI(breakCost, I),
        affordable: stones >= breakCost,
        pressure: stones >= breakCost ? 4 : stones >= breakCost * 0.5 ? 3 : 1,
      });
    }
    for (const r of recipes || []) {
      if (r.retired) continue;
      const stone = Number(r.stoneCost || 0);
      const matOk = Object.entries(r.materials || {}).every(
        ([id, n]) => Number(materials[id] || 0) >= Number(n || 1),
      );
      const need = {};
      for (const id of r.inputs || []) need[id] = (need[id] || 0) + 1;
      const guOk = Object.entries(need).every(([id, n]) => Number(owned[id] || 0) >= n);
      const can = matOk && guOk && stone <= stones;
      options.push({
        kind: 'forge',
        id: r.id,
        label: `炼·${r.branchLabel || r.output}`,
        cost: stone,
        fights: fightsOfI(stone, I),
        affordable: can,
        pressure: can ? 3 : 0,
        branchAxis: r.branchAxis || null,
      });
    }
    return { incomeUnit: I, options };
  }

  function strategyBalance(pressures = {}) {
    const byKind = {};
    for (const opt of pressures.options || []) {
      const score = Number(opt.pressure || 0);
      if (!opt.affordable && score < 3) continue;
      byKind[opt.kind] = Math.max(byKind[opt.kind] || 0, score);
    }
    const kinds = ['buy_build', 'buy_material', 'forge', 'save_breakthrough'];
    const scores = kinds.map((k) => ({ kind: k, score: byKind[k] || 0 }));
    const max = Math.max(...scores.map((s) => s.score), 0);
    const leaders = scores.filter((s) => s.score === max && max > 0);
    return {
      scores,
      max,
      leaders: leaders.map((s) => s.kind),
      uniqueDominant: leaders.length === 1 && max >= 3
        && scores.filter((s) => s.score > 0 && s.kind !== leaders[0]).every((s) => s.score < max - 1),
    };
  }

  function hasRiskFreeLoop(offers = []) {
    for (const offer of offers) {
      if (!isLiveOffer(offer) || offer.kind !== 'purchase' || !offer.gu_id) continue;
      const buy = Number(offer.stone_cost || 0);
      const approxSell = Math.floor(buy * 0.5);
      if (approxSell >= buy) return true;
    }
    return false;
  }

  return Object.freeze({
    goodsKinds: GOODS_KINDS,
    serviceKinds: SERVICE_KINDS,
    seededShuffle,
    slotCount,
    maxTier,
    layerPrice,
    goodsPool,
    stock,
    offerIsStocked,
    incomeUnit,
    fightsOfI,
    spendPressures,
    nextBreakthroughCost,
    strategyBalance,
    hasRiskFreeLoop,
  });
})();
