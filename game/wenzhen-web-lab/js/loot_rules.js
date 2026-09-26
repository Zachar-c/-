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
    const weights = lootConfig.weights || {};
    const byRarity = table.gu_pool?.by_rarity || {};
    const effective = {};
    for (const [rarity, weight] of Object.entries(weights)) {
      if (weight > 0 && (byRarity[rarity] || []).length) effective[rarity] = weight;
    }
    if (Object.keys(effective).length) table.gu_pool.weights = effective;
    return table;
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
    guById = {}, supportPool = [], choiceCount = 3, carriedPool = [],
  } = {}) {
    const first = rollGu(table, {
      seed, tick, tier, lootPity, pityConfig, school, schoolPools, guById,
    });
    if (!first.guId) return { guIds: [], rarity: '' };
    // P5 掉落派生（世界实体驱动）：被击败的持蛊敌人，蛊_chance 命中后首选从其装载蛊池
    // 取（夺蛊=原著标准战利品语义，adaptation 机制）；池空/全不在册时走原表流程。
    let carriedFirst = '';
    const carried = [...new Set((carriedPool || []).map(String))].filter((id) => guById[id]);
    if (carried.length) {
      carriedFirst = carried[RunRules.seededIndex(carried.length, seed, `loot.gu.carried.${tier}`, tick)];
    }
    const pool = [...new Set([
      carriedFirst || first.guId,
      first.guId,
      ...(carriedFirst ? carried : []),
      ...Object.values(table?.gu_pool?.by_rarity || {}).flat().map(String),
      ...(supportPool || []).map(String),
    ].filter(Boolean))];
    const guIds = [String(carriedFirst || first.guId)];
    const wanted = Math.max(1, Math.floor(Number(choiceCount) || 3));
    for (let index = 1; index < Math.min(wanted, pool.length); index += 1) {
      const remaining = pool.filter((id) => !guIds.includes(id));
      if (!remaining.length) break;
      const picked = remaining[
        RunRules.seededIndex(remaining.length, seed, `loot.gu.choice.${tier}.${index}`, tick + index)
      ];
      guIds.push(String(picked));
    }
    return { guIds, rarity: carriedFirst ? String(guById[carriedFirst]?.rarity || first.rarity) : first.rarity };
  }

  function nextLootPity(current, rarity, pityConfig = {}) {
    const clearing = pityConfig.clearing_rarities || ['rare', 'epic', 'legendary'];
    if (clearing.includes(rarity)) return 0;
    if (rarity === 'common') return Number(current || 0) + 1;
    return Number(current || 0);
  }

  // 战后奖励类型：元石提供经济，蛊虫提供构筑选择。
  // economic=元石 · build=蛊/杀招/组合组件
  function classifyReward(reward = {}, { guById = {} } = {}) {
    const kinds = { economic: 0, build: 0 };
    if (Number(reward.stones || 0) > 0) kinds.economic += 1;
    for (const gid of reward.guChoices || reward.guIds || []) {
      if (guById[String(gid || '')]) kinds.build += 1;
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
    rollGu,
    rollGuChoices,
    nextLootPity,
    classifyReward,
    newFutureGuIds,
    ensureNewFutureChoice,
    opensNewChoice,
  });
})();
