/* 传播链：改上游 → 列出受影响对象。Dependency Graph 可执行化。 */
globalThis.VImpact = (() => {
  function impactOf(changeKey, index) {
    // changeKey: scarcity.small_light_gu | rank_profile.3 | dao.moon | enemy_archetype.armored | ruling.* | effect_archetype.*
    const hits = {
      gu: [],
      killer_moves: [],
      refine_edges: [],
      shops: [],
      drops: [],
      enemies: [],
      notes: [],
    };
    const raw = String(changeKey);
    const dot = raw.indexOf('.');
    const kind = dot < 0 ? raw : raw.slice(0, dot);
    let key = dot < 0 ? '' : raw.slice(dot + 1);
    // 允许 scarcity.small_light → small_light_gu
    if (kind === 'scarcity' && key && !index.refineEdges.some((e) => e.from.includes(key) || e.to === key)) {
      const guess = index.refineEdges.find((e) => e.from.some((f) => f.startsWith(key) || key.startsWith(f.replace(/_gu$/, ''))) || e.to.startsWith(key));
      if (guess) key = (guess.from.find((f) => f.includes(key.replace(/_gu$/, '')) || key.includes(f.replace(/_gu$/, ''))) || guess.to);
    }

    if (kind === 'scarcity') {
      hits.gu.push(key);
      hits.notes.push(`${key} 价格/供应变化`);
      for (const e of index.refineEdges) {
        if (e.from.includes(key) || e.to === key) hits.refine_edges.push(e.id);
      }
      for (const e of index.refineEdges) {
        if (e.from.includes(key) && !hits.gu.includes(e.to)) hits.gu.push(e.to);
      }
      for (const k of index.killerMoves) {
        const cores = k.components?.core || k.core || [];
        const tr = k.components?.transforms || k.transforms || [];
        if ([...cores, ...tr].some((id) => hits.gu.includes(id))) hits.killer_moves.push(k.id);
      }
      hits.shops.push('tiers touching', ...hits.gu);
      hits.notes.push('炼制期望成本 → 成品市价 → 路线成型速度');
    } else if (kind === 'rank_profile') {
      hits.gu.push(...index.guByRank[key] || []);
      hits.enemies.push(...index.enemiesByRank[key] || []);
      hits.notes.push(`R${key} 能力空间变化 → 该转全部投影`);
    } else if (kind === 'dao') {
      hits.gu.push(...index.guByDao[key] || []);
      hits.notes.push(`${key} DaoProfile → 该道效果/价值倾斜`);
    } else if (kind === 'enemy_archetype') {
      hits.enemies.push(...(index.enemiesByArchetype[key] || []).map((e) => e.id));
      hits.drops.push(key);
      hits.notes.push(`${key} 五转投影 + 掉落生态`);
    } else if (kind === 'ruling') {
      hits.gu.push(...(index.guByRuling[key] || []));
      hits.killer_moves.push(...(index.kmByRuling[key] || []));
      hits.notes.push(`${key} 身份约束 → 实体 semantics/override`);
    } else if (kind === 'effect_archetype') {
      hits.gu.push(...(index.guByArchetype[key] || []));
      hits.notes.push(`${key} 维度曲线 → 全部使用该原型的蛊`);
    }

    for (const k of Object.keys(hits)) {
      if (Array.isArray(hits[k])) hits[k] = [...new Set(hits[k])];
    }
    return hits;
  }

  function buildIndex({ gu, enemies, refineEdges, killerMoves }) {
    const idx = {
      refineEdges,
      killerMoves,
      guByRank: {},
      guByDao: {},
      guByArchetype: {},
      guByRuling: {},
      enemiesByRank: {},
      enemiesByArchetype: {},
    };
    for (const g of gu) {
      (idx.guByRank[g.rank] ||= []).push(g.id);
      for (const d of g.dao || []) (idx.guByDao[d] ||= []).push(g.id);
      for (const a of g.archetype || []) (idx.guByArchetype[a] ||= []).push(g.id);
      for (const r of g.deps?.rulings || g.ruling_refs || []) (idx.guByRuling[r] ||= []).push(g.id);
    }
    for (const e of enemies) {
      (idx.enemiesByRank[e.rank] ||= []).push(e.id);
      (idx.enemiesByArchetype[e.archetype] ||= []).push(e);
    }
    for (const k of killerMoves) {
      for (const r of k.ruling_refs || []) (idx.kmByRuling[r] ||= []).push(k.id);
    }
    return idx;
  }

  return Object.freeze({ impactOf, buildIndex });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.VImpact;
