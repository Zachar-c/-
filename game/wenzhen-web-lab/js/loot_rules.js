// Deterministic victory-loot rules ported from loot_resolver.gd.
globalThis.LootRules = (() => {
  const normalizeEntries = (pool) => (pool || [])
    .map((entry) => (typeof entry === 'string'
      ? { id: entry, weight: 1 }
      : { id: String(entry.id || ''), weight: Math.max(0, Number(entry.weight ?? 1)) }))
    .filter((entry) => entry.id && entry.weight > 0);

  function pickWeighted(entries, seed, salt, tick) {
    const normalized = normalizeEntries(entries);
    const total = normalized.reduce((sum, entry) => sum + entry.weight, 0);
    if (total <= 0) return null;
    let roll = RunRules.seededIndex(total, seed, salt, tick);
    for (const entry of normalized) {
      if (roll < entry.weight) return entry;
      roll -= entry.weight;
    }
    return null;
  }

  function layerTable(lootTables, pacingLayers, tier, layer) {
    const base = lootTables?.[tier];
    if (!base) return null;
    const layerConfig = pacingLayers?.[String(Math.min(5, Math.max(1, layer)))] || {};
    const lootConfig = layerConfig.loot || {};
    const table = JSON.parse(JSON.stringify(base));
    if (lootConfig.material_count != null) table.material_count = lootConfig.material_count;
    const weights = lootConfig.weights || {};
    const byRarity = table.gu_pool?.by_rarity || {};
    const effective = {};
    for (const [rarity, weight] of Object.entries(weights)) {
      if (weight > 0 && (byRarity[rarity] || []).length) effective[rarity] = weight;
    }
    if (Object.keys(effective).length) table.gu_pool.weights = effective;
    return table;
  }

  // L0 Phase 5：无 Consumer 的材料不进入正式掉落池（不删除，只不出货）。
  function consumerFilter(pool, consumers) {
    const normalized = normalizeEntries(pool);
    if (!consumers || typeof consumers !== 'object') return normalized;
    const allowed = new Set(Object.keys(consumers).filter((id) => (consumers[id] || []).length));
    if (!allowed.size) return normalized;
    return normalized.filter((entry) => allowed.has(entry.id));
  }

  function rollMaterials(table, {
    seed, tick, tier, countAdjustment = 0, materialPityByTier = {}, targets = [], pityConfig = {},
    consumers = null, preferred = [],
  }) {
    let pool = normalizeEntries(table.material_pool);
    if (consumers) pool = consumerFilter(pool, consumers);
    // 敌人亲和：优先加权；池中没有则注入（该敌定向产出钥匙材料）
    const pref = new Set((preferred || []).map(String));
    if (pref.size) {
      const have = new Set(pool.map((e) => e.id));
      pool = pool.map((entry) => (pref.has(entry.id)
        ? { ...entry, weight: entry.weight * 3 }
        : entry));
      for (const id of pref) {
        if (consumers && !(consumers[id] || []).length) continue;
        if (!have.has(id)) pool.push({ id, weight: 5 });
      }
    }
    let count = Math.max(0, Number(table.material_count || 0) + Number(countAdjustment || 0));
    const materialIds = [];
    while (materialIds.length < count && pool.length) {
      const picked = pickWeighted(pool, seed, `loot.material.${tier}`, tick);
      if (!picked) break;
      materialIds.push(picked.id);
      pool.splice(pool.findIndex((entry) => entry.id === picked.id), 1);
    }
    const threshold = Number(pityConfig.material_pity?.threshold || 0);
    const pityCount = Number(materialPityByTier[tier] || 0);
    const pityTargets = (targets || []).filter((id) => !consumers || (consumers[id] || []).length);
    if (threshold > 0 && pityCount >= threshold && pityTargets.length && !materialIds.some((id) => pityTargets.includes(id))) {
      const forced = pool.filter((entry) => pityTargets.includes(entry.id));
      if (forced.length) {
        const picked = forced[RunRules.seededIndex(forced.length, seed, `loot.material.forced.${tier}`, tick)];
        materialIds.push(picked.id);
      }
    }
    return { materialIds };
  }

  function schoolPoolByRarity(school, rarity, schoolPools, guById) {
    if (!school || !guById) return [];
    return (schoolPools?.[school] || []).filter((id) => guById[id]?.rarity === rarity);
  }

  function pickFromBucket(rarity, bucket, {
    seed, tick, tier, school, schoolPools, guById,
  }) {
    const ids = [...(bucket || [])].map(String);
    const schoolMembers = ids.filter((id) => (schoolPools?.[school] || []).includes(id));
    let pickPool = schoolMembers;
    if (!pickPool.length) pickPool = schoolPoolByRarity(school, rarity, schoolPools, guById);
    if (!pickPool.length) pickPool = ids;
    if (!pickPool.length) return { guId: '', rarity: '' };
    const picked = pickPool[RunRules.seededIndex(pickPool.length, seed, `loot.gu.pick.${tier}.${rarity}`, tick)];
    return { guId: String(picked), rarity };
  }

  function rollGu(table, {
    seed, tick, tier, lootPity = 0, pityConfig = {}, school = '', schoolPools = {}, guById = {},
  }) {
    const chance = Math.min(100, Math.max(0, Number(table.gu_chance_pct || 0)));
    const byRarity = table.gu_pool?.by_rarity || {};
    const weights = table.gu_pool?.weights || {};
    if (chance <= 0 || !Object.keys(byRarity).length) return { guId: '', rarity: '' };
    if (chance < 100 && RunRules.seededIndex(100, seed, `loot.gu.${tier}`, tick) >= chance) {
      return { guId: '', rarity: '' };
    }
    const forcedRarity = String(table.forced_rarity || '');
    if (forcedRarity && (byRarity[forcedRarity] || []).length) {
      return pickFromBucket(forcedRarity, byRarity[forcedRarity], {
        seed, tick, tier, school, schoolPools, guById,
      });
    }
    let effectiveWeights = { ...weights };
    let raritySalt = `loot.gu.rarity.${tier}`;
    if (lootPity >= Number(pityConfig.threshold || 3)) {
      const forcedWeights = Object.fromEntries(
        Object.entries(weights).filter(([rarity, weight]) => rarity !== 'common' && Number(weight) > 0),
      );
      if (Object.values(forcedWeights).some((weight) => Number(weight) > 0)) {
        effectiveWeights = forcedWeights;
        raritySalt = `loot.gu.rarity.forced.${tier}`;
      }
    }
    const rarity = pickWeighted(
      Object.entries(effectiveWeights).map(([id, weight]) => ({ id, weight })),
      seed,
      raritySalt,
      tick,
    );
    if (!rarity) return { guId: '', rarity: '' };
    return pickFromBucket(rarity.id, byRarity[rarity.id] || [], {
      seed, tick, tier, school, schoolPools, guById,
    });
  }

  // 战后三选一：先按奖池概率决定是否出蛊，再在该 tier 的所有真实蛊中
  // 补足到三个不同候选。候选池仍来自构建时数据，不在这里另造实体。
  function rollGuChoices(table, {
    seed, tick, tier, lootPity = 0, pityConfig = {}, school = '', schoolPools = {},
    guById = {}, supportPool = [], choiceCount = 3,
  } = {}) {
    const first = rollGu(table, {
      seed, tick, tier, lootPity, pityConfig, school, schoolPools, guById,
    });
    if (!first.guId) return { guIds: [], rarity: '' };
    const pool = [...new Set([
      first.guId,
      ...Object.values(table?.gu_pool?.by_rarity || {}).flat().map(String),
      ...(supportPool || []).map(String),
    ].filter(Boolean))];
    const guIds = [String(first.guId)];
    const wanted = Math.max(1, Math.floor(Number(choiceCount) || 3));
    for (let index = 1; index < Math.min(wanted, pool.length); index += 1) {
      const remaining = pool.filter((id) => !guIds.includes(id));
      if (!remaining.length) break;
      const picked = remaining[
        RunRules.seededIndex(remaining.length, seed, `loot.gu.choice.${tier}.${index}`, tick + index)
      ];
      guIds.push(String(picked));
    }
    return { guIds, rarity: first.rarity };
  }

  function nextMaterialPity(currentByTier, tier, materialIds, targets = []) {
    const next = { ...(currentByTier || {}) };
    if (!targets.length) return next;
    const hit = materialIds.some((id) => targets.includes(id));
    next[tier] = hit ? 0 : Number(next[tier] || 0) + 1;
    return next;
  }

  function nextLootPity(current, rarity, pityConfig = {}) {
    const clearing = pityConfig.clearing_rarities || ['rare', 'epic', 'legendary'];
    if (clearing.includes(rarity)) return 0;
    if (rarity === 'common') return Number(current || 0) + 1;
    return Number(current || 0);
  }

  // ---- Phase 6：掉落三价值 ----
  // economic=元石/可售 · growth=炼蛊钥匙材料 · build=蛊/杀招/组合组件
  function classifyItem(id, guById = {}, consumers = {}) {
    const key = String(id || '');
    if (guById[key]) return 'build';
    if ((consumers[key] || []).length) return 'growth';
    return 'economic';
  }

  function classifyReward(reward = {}, { guById = {}, consumers = {} } = {}) {
    const kinds = { economic: 0, growth: 0, build: 0 };
    if (Number(reward.stones || 0) > 0) kinds.economic += 1;
    for (const mid of reward.materialIds || []) {
      kinds[classifyItem(mid, guById, consumers)] += 1;
    }
    for (const gid of reward.guChoices || reward.guIds || []) {
      kinds[classifyItem(gid, guById, consumers)] += 1;
    }
    return kinds;
  }

  // Boss「新未来」：优先给出能补完组合 / 开杀招的蛊，而不是又一只数值牌。
  function newFutureGuIds({
    owned = {}, guById = {}, killMoves = [], buildKits = {},
  } = {}) {
    const ids = new Set();
    for (const kit of Object.values(buildKits || {})) {
      for (const mid of kit.members || []) {
        if (Number(owned[mid] || 0) <= 0) ids.add(mid);
      }
    }
    for (const move of killMoves || []) {
      for (const sid of move.recipe || []) {
        if (Number(owned[sid] || 0) <= 0) ids.add(sid);
      }
    }
    // 可替换组件（同族）也算新未来
    if (typeof GuRules !== 'undefined' && GuRules.compatibleSubstitutes) {
      for (const ownedId of Object.keys(owned)) {
        for (const sub of GuRules.compatibleSubstitutes(ownedId, guById)) {
          if (Number(owned[sub] || 0) <= 0) ids.add(sub);
        }
      }
    }
    return [...ids].filter((id) => guById[id]);
  }

  // 在三选一中保证至少一个「新未来」候选（Boss/精英）。
  function ensureNewFutureChoice(guIds = [], newFutureIds = [], {
    seed, tick, tier, byRarity = {},
  } = {}) {
    const list = [...guIds].map(String);
    const future = new Set((newFutureIds || []).map(String));
    if (list.some((id) => future.has(id)) || !future.size) return list;
    const bucket = [...new Set(Object.values(byRarity || {}).flat().map(String))]
      .filter((id) => future.has(id));
    if (!bucket.length) return list;
    const picked = bucket[RunRules.seededIndex(bucket.length, seed, `loot.gu.newfuture.${tier}`, tick)];
    // 替换最后一位，保留前两位选择
    if (list.length) list[list.length - 1] = String(picked);
    else list.push(String(picked));
    return list;
  }

  // Gate 6：奖励是否打开「下一段 Run 的新选择」，而不只是购买力。
  function opensNewChoice(reward = {}, insight = null) {
    if (insight?.hasRealDecision) return true;
    if (insight?.kitJoins?.some((k) => k.completes || k.coversGap)) return true;
    if (insight?.killMoveForms?.some((k) => k.canForm || k.changesPattern || k.fillsGap)) return true;
    const kinds = reward.valueKinds || null;
    if (kinds && Number(kinds.build || 0) > 0 && (reward.guChoices || []).length) return true;
    return false;
  }

  return Object.freeze({
    pickWeighted,
    layerTable,
    consumerFilter,
    rollMaterials,
    rollGu,
    rollGuChoices,
    nextMaterialPity,
    nextLootPity,
    classifyItem,
    classifyReward,
    newFutureGuIds,
    ensureNewFutureChoice,
    opensNewChoice,
  });
})();
