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
  });
})();
