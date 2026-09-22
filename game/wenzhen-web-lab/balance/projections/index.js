/* Projections：由 Model 推导数值。禁止在此手写「月芒伤害=9」。
 * damage / qi / block / value_vector / prices 全部曲线推导。
 */
globalThis.VProject = (() => {
  function loadBases(effects, ranks, quality) {
    return { effects, ranks, quality };
  }

  function qualityMult(quality, cls, rankProfile) {
    const b = quality.bands[cls] || quality.bands.normal;
    // 品质带落在 Rank 能力空间上：改 RankProfile.energy_band 会重算
    const band = rankProfile?.energy_band || {};
    const map = {
      floor: band.floor ?? 0.55,
      normal: band.normal ?? 1.0,
      good: ((band.normal ?? 1.0) + (band.exceptional ?? 1.55)) / 2 * 0.9,
      excellent: band.exceptional ?? 1.55,
      exceptional: band.exceptional ?? 1.55,
    };
    const scaled = map[cls] ?? b.energy_mult;
    return scaled;
  }

  function projectDimensions(archetype, overrides = {}) {
    const base = { ...(archetype.base_dimensions || {}) };
    for (const [k, v] of Object.entries(overrides)) base[k] = v;
    return base;
  }

  function projectCombat({ identity, effects, ranks, quality }) {
    const rank = identity.canonical.rank;
    const rp = ranks.profiles[String(rank)];
    const archId = identity.archetype[0];
    const arch = effects.archetypes[archId];
    if (!arch) throw new Error('unknown archetype ' + archId + ' on ' + identity.id);
    const dims = projectDimensions(arch, identity.dimensions_override || {});
    const qm = qualityMult(quality, identity.quality?.class || 'normal', rp);
    const baseDmg = effects.base_damage_by_rank[String(rank)];
    const curves = effects.dimension_curves;

    let dmg = baseDmg * (dims.power || 1) * qm;
    dmg *= 1 + (dims.range || 0) * curves.range.to_damage_mult;
    // AOE：总伤预算共享，但不把单目标伤打到 0（cap 每目标惩罚）
    const extraT = Math.max(0, (dims.targets || 1) - 1);
    const isFullField = (dims.targets || 1) >= 8;
    const perTargetPenalty = isFullField ? 0.25 : Math.min(0.45, extraT * curves.targets.to_damage_mult_per_extra);
    dmg *= 1 + perTargetPenalty;
    dmg *= 1 + (dims.penetration || 0) * curves.penetration.to_damage_mult * 0.1;
    dmg = Math.max(1, Math.round(dmg));

    let qi = effects.qi_base_by_rank[String(rank)] * (rp.qi_cost_base / (8 + 3 * (rank - 1)));
    qi *= (rp.energy_band?.normal ?? 1);
    qi *= 1 + (dims.range || 0) * curves.range.to_qi_mult;
    qi *= 1 + Math.max(0, (identity.traits?.qi_efficiency === 'high' ? -0.2 : 0));
    qi = Math.max(1, Math.round(qi));

    let block = 0;
    if (archId === 'shield') {
      const bp = arch.block_per_power_rank[String(rank)] * (dims.power || 1) * qm;
      block = Math.max(1, Math.round(bp));
      dmg = 0;
    }
    if (archId === 'inspect' || archId === 'support_amp' || archId === 'resource_cycle' || archId === 'stealth_utility' || archId === 'phantom_decoy') {
      dmg = 0;
    }

    const thought = rank >= 5 && arch.slots >= 3 ? 2 : 1;
    return {
      damage: dmg,
      block,
      qi,
      thought,
      cd: Math.max(0, (arch.slots || 1) - 1),
      dims,
      archetype: archId,
      qualityClass: identity.quality?.class || 'normal',
    };
  }

  function projectValueVector({ identity, combat, effects, ranks, quality, daoTilt }) {
    const axes = effects.value_vector_axes;
    const tilt = { ...Object.fromEntries(axes.map((a) => [a, 0.3])) };
    const arch = effects.archetypes[identity.archetype[0]];
    for (const [k, v] of Object.entries(arch?.value_tilt || {})) tilt[k] = Math.max(tilt[k] || 0, v);
    for (const [k, v] of Object.entries(daoTilt || {})) tilt[k] = (tilt[k] || 0.3) * v;
    const qv = (quality.bands[identity.quality?.class || 'normal'] || {}).value_mult || 1;
    const out = {};
    for (const a of axes) {
      let x = (tilt[a] || 0.3) * qv;
      if (a === 'combat_direct') x *= 0.5 + (combat.damage || 0) / 10;
      if (a === 'defense') x *= 0.5 + (combat.block || 0) / 10;
      if (a === 'refinement' && identity.traits?.refinement_hunger === 'high') x *= 1.6;
      if (a === 'information' && identity.traits?.longevity) x *= 1.3;
      if (a === 'killer_move' && (identity.refinement_edges || []).length) x *= 1.1;
      out[a] = Math.round(x * 100) / 100;
    }
    return out;
  }

  function intrinsicFromVector(vec) {
    return (
      vec.combat_direct * 1.0 +
      vec.defense * 0.9 +
      vec.control * 1.0 +
      vec.information * 0.8 +
      vec.mobility * 0.7 +
      vec.resource * 0.8 +
      vec.refinement * 1.0 +
      vec.killer_move * 0.9 +
      vec.economy * 0.8
    );
  }

  function projectEconomy({ identity, vec, economy, rank }) {
    const tier = economy.tiers[String(rank)];
    const intrinsic = intrinsicFromVector(vec);
    const scarcity = identity.traits?.scarcity === 'extreme' ? 1.6 : identity.traits?.scarcity === 'high' ? 1.3 : identity.quality?.class === 'floor' ? 0.7 : 1.0;
    const demand = 1 + (vec.refinement || 0) * 0.15 + (vec.killer_move || 0) * 0.1;
    const supply = identity.traits?.feeding_difficulty === 'extreme' ? 0.8 : 1.0;
    const merchantMarkup = 1.15;
    // tier income_base 是一场普通战收入；同转普通蛊价 ≈ income * fights_needed
    const fightsNeeded = 2.2 / Math.max(0.3, tier.common_gu_purchasing_power);
    const basePrice = tier.income_base * fightsNeeded * 0.35;
    // 五转稀缺靠 scarcity/fights，不再线性堆 intrinsic（防价格爆炸）
    const legendaryCap = rank >= 5 ? 0.55 : rank >= 4 ? 0.8 : 1;
    const marketPrice = Math.round(intrinsic * basePrice * scarcity * supply * demand * merchantMarkup * 0.35 * legendaryCap);
    const npcBuy = Math.round(marketPrice * 0.55);
    const black = Math.round(marketPrice * 1.3);
    return { intrinsic: Math.round(intrinsic * 100) / 100, marketPrice, npcBuyPrice: npcBuy, blackMarketPrice: black, scarcity, demand, supply, merchantMarkup };
  }

  function projectRefineCost({ edge, priceOf, success }) {
    let once = Number(edge.stonesBase || 0);
    for (const id of edge.from || []) once += priceOf(id);
    // 材料按阶估
    const rankGuess = 1;
    once += 15 * (edge.from || []).length;
    const s = success;
    return { once, expected: once / s, success: s };
  }

  function projectGu(identity, ctx) {
    const combat = projectCombat({ identity, ...ctx });
    const vec = projectValueVector({
      identity,
      combat,
      ...ctx,
      daoTilt: ctx.dao?.[identity.canonical.dao[0]]?.value_tilt || {},
    });
    const eco = projectEconomy({ identity, vec, economy: ctx.economy, rank: identity.canonical.rank });
    return {
      id: identity.id,
      name: identity.canonical.name,
      rank: identity.canonical.rank,
      dao: identity.canonical.dao,
      archetype: identity.archetype,
      quality: identity.quality?.class || 'normal',
      origin: identity.origin,
      sources: identity.sources || [],
      unique_rules: identity.mechanics?.unique_rules || {},
      traits: identity.traits || {},
      combat,
      value_vector: vec,
      intrinsic_value: eco.intrinsic,
      economy: {
        marketPrice: eco.marketPrice,
        npcBuyPrice: eco.npcBuyPrice,
        blackMarketPrice: eco.blackMarketPrice,
      },
      refinement_edges: identity.refinement_edges || [],
      deps: {
        rank_profile: 'rank_profiles_v1',
        quality_profile: 'quality_profiles_v1/' + (identity.quality?.class || 'normal'),
        effect_archetype: combat.archetype,
        dao_profile: identity.canonical.dao[0],
        economy_tier: String(identity.canonical.rank),
        facts: identity.sources || [],
        rulings: identity.ruling_refs || [],
      },
    };
  }

  function projectEnemy(archetype, rank, ctx) {
    const bias = archetype.combat_bias;
    const hpMid = ctx.scales.enemyHpMid[String(rank)];
    const hp = Math.round(hpMid * bias.hp);
    const dmgBase = ctx.scales.enemyDamageBase[String(rank)];
    const damage = Math.max(1, Math.round(dmgBase * bias.damage));
    const mechanisms = archetype.mechanism_growth[String(rank)] || [];
    return {
      id: `${archetype.id}_r${rank}`,
      archetype: archetype.id,
      family: archetype.family,
      name: archetype.family + '·R' + rank,
      rank,
      hp,
      defense: Math.round((rank - 1) * bias.defense),
      speed: Math.round(2 * bias.speed),
      damage,
      mechanisms,
      isBoss: !!archetype.isBoss || rank === 5 && archetype.id === 'boss',
      ecology: archetype.ecology,
      tests: archetype.tests,
      deps: { enemy_archetype: archetype.id, rank_profile: String(rank), quality_band: 'normal' },
      origin: 'derived',
    };
  }

  return Object.freeze({ projectGu, projectEnemy, projectCombat, projectValueVector, projectEconomy, intrinsicFromVector });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.VProject;
