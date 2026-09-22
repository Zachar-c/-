/* 杀招投影：骨架 × 组件效果 × 协调，不是 24 个手填按钮 */
globalThis.VProjectKM = (() => {
  function projectKillerMove(skeleton, guStatsById, opts = {}) {
    const coordination = opts.coordination ?? 1.15;
    const core = (skeleton.components.core || []).map((id) => guStatsById[id]).filter(Boolean);
    const transforms = (skeleton.components.transforms || []).map((id) => guStatsById[id]).filter(Boolean);
    if (!core.length) {
      return { id: skeleton.id, error: 'missing_core', deps: { skeleton: skeleton.id } };
    }
    let damage = 0;
    let block = 0;
    let qi = 0;
    let thought = 0;
    let slots = 0;
    const primitives = [];
    for (const g of core) {
      damage += g.combat.damage || 0;
      block += g.combat.block || 0;
      qi += g.combat.qi || 0;
      thought += g.combat.thought || 1;
      slots += 1;
    }
    for (const g of transforms) {
      // 变换件：不把自身伤加总，提高协调/改规则
      qi += Math.round((g.combat.qi || 0) * 0.5);
      slots += 0.5;
    }
    damage = Math.round(damage * coordination);
    block = Math.round(block * coordination);
    // compositeCost：不叠加单蛊全额，取 max(核心) + 半变换 + 协调税
    const coreQi = Math.max(...core.map((g) => g.combat.qi || 0));
    qi = Math.round((coreQi + qi * 0.35) * coordination);
    thought = Math.max(2, thought);
    for (const r of skeleton.emergent_rules || []) {
      if (r.includes('ignore') || r.includes('evade')) primitives.push('Damage');
      if (r.includes('shield')) primitives.push('Shield');
      if (r.includes('suppress')) primitives.push('Suppress');
    }
    if (damage > 0) primitives.push('Damage');
    if (block > 0) primitives.push('Shield');

    return {
      id: skeleton.id,
      name: skeleton.name,
      rank: skeleton.rank,
      components: { core: skeleton.components.core, transforms: skeleton.components.transforms },
      execution: skeleton.execution,
      emergent_rules: skeleton.emergent_rules,
      projected: { damage, block, qi, thought, slots },
      primitives: [...new Set(primitives)],
      deps: {
        skeleton: skeleton.id,
        core: skeleton.components.core,
        transforms: skeleton.components.transforms,
        coordination,
      },
    };
  }

  /* 换核重推演：月光→月芒 = 同骨架新 variant */
  function rededuce(skeleton, newCoreId, guStatsById) {
    return projectKillerMove(
      {
        ...skeleton,
        id: skeleton.id + ':' + newCoreId,
        components: { ...skeleton.components, core: [newCoreId] },
        note: 'rededuce_on_core_swap',
      },
      guStatsById
    );
  }

  return Object.freeze({ projectKillerMove, rededuce });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.VProjectKM;
