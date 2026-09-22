// Pure Gu activation and effect-shape rules shared by the Web lab.
// Source semantics: cultivator_rules.gd, action_points.gd and v1_battle_resolver.gd.
globalThis.GuRules = (() => {
  const canActivate = (playerRank, guRank, lowRankException = false) =>
    !!lowRankException || Number(playerRank) >= Number(guRank);

  const instanceId = (definitionId, index = 0) =>
    `${definitionId}::${Number(index) + 1}`;

  // refine_command_rules.gd::_attune_gu
  const attuneCost = (rank) => 4 + 2 * (Math.min(5, Math.max(1, Number(rank) || 1)) - 1);

  function attuneWild(wild = {}, owned = {}, trueQi = 0, definitionId = '', rank = 1) {
    const id = String(definitionId || '');
    const wildCount = Math.max(0, Math.floor(Number(wild[id] || 0)));
    const qi = Number(trueQi) || 0;
    const cost = attuneCost(rank);
    if (!id || wildCount <= 0) return { ok: false, reason: 'attune_target_missing', cost };
    if (qi < cost) return { ok: false, reason: 'insufficient_essence', cost };
    return {
      ok: true,
      cost,
      wild: { ...wild, [id]: wildCount - 1 },
      owned: { ...owned, [id]: Math.max(0, Math.floor(Number(owned[id] || 0))) + 1 },
      trueQi: qi - cost,
    };
  }

  function activationReason(gu, player = {}) {
    if (!gu) return 'unknown_gu';
    if (gu.consumed) return 'gu_consumed';
    if (gu.sealed) return 'gu_sealed';
    if (gu.usedThisTurn || player.usedThisTurn) return 'gu_used_this_turn';
    if (!canActivate(player.playerRank, gu.rank, gu.lowRankException)) {
      return 'insufficient_qi_quality';
    }
    if (player.actionLimitReached) return 'action_limit_reached';
    if (Number(player.thought || 0) < Number(gu.thoughtCost || 1)) {
      return 'insufficient_thought';
    }
    if (Number(player.trueQi || 0) < Number(gu.trueQiCost || 0)) {
      return 'insufficient_true_qi';
    }
    return '';
  }

  function combatRoster(guList, owned = {}, player = {}) {
    const usedInstances = player.usedInstances || {};
    const sealedInstances = player.sealedInstances || {};
    const roster = [];
    for (const gu of guList || []) {
      if (!gu || !String(gu.combat || '') || String(gu.combat) === 'none') continue;
      const count = Math.max(0, Math.floor(Number(owned[gu.id] || 0)));
      for (let index = 0; index < count; index += 1) {
        const entry = {
          ...gu,
          count,
          instanceId: instanceId(gu.id, index),
          instanceIndex: index + 1,
          sealed: !!sealedInstances[instanceId(gu.id, index)],
        };
        entry.activationReason = activationReason(entry, {
          ...player,
          usedThisTurn: !!usedInstances[entry.instanceId],
        });
        roster.push(entry);
      }
    }
    return roster;
  }

  function killMoveRecipeInstances(move, owned = {}, usedInstances = {}, sealedInstances = {}) {
    const reserved = new Set();
    return (move?.recipe || []).map((definitionId) => {
      for (let index = 0; index < Number(owned[definitionId] || 0); index += 1) {
        const candidate = instanceId(definitionId, index);
        if (reserved.has(candidate) || usedInstances[candidate] || sealedInstances[candidate]) continue;
        reserved.add(candidate);
        return candidate;
      }
      return null;
    });
  }

  function conditionMet(condition, context = {}) {
    switch (String(condition?.type || '')) {
      case 'self_hp_below': {
        const maxHp = Math.max(1, Number(context.hpMax || 1));
        return Number(context.hp || 0) / maxHp < Number(condition.threshold ?? 0.5);
      }
      case 'enemies_alive_gte':
        return Number(context.enemiesAlive || 0) >= Number(condition.count || 1);
      case 'turn_gte':
        return Number(context.turn || 1) >= Number(condition.turn || 1);
      default:
        return false;
    }
  }

  function gateMissReason(effect, context = {}) {
    if (!effect) return '';
    if (effect.delay) {
      const turns = Number(effect.delay.turns || 0);
      if ((effect.trigger || 'on_play') !== 'on_play'
        || effect.condition
        || effect.consume_status
        || effect.support_school
        || turns < 1) {
        return 'delay_shape_rejected';
      }
    }
    if (String(effect.trigger || 'on_play') !== 'on_play') return 'trigger_unsupported';
    if (effect.condition && !conditionMet(effect.condition, context)) return 'condition_miss';
    if (effect.consume_status) {
      const name = String(effect.consume_status.name || 'marked');
      if (Number(context.statusStacks?.[name] || 0) < 1) return 'consume_status_missing';
    }
    return '';
  }

  // L0 2026-09-25：组件条件默认继承。只有杀招显式声明 componentConditionOverride
  // 才允许突破组件限制；否则任一配方组件门禁失败，整式杀招不可用。
  function killMoveGateMissReason(move, guById = {}, context = {}) {
    if (!move) return 'unknown_gu';
    if (move.componentConditionOverride) return '';
    for (const definitionId of move.recipe || []) {
      const gu = guById[definitionId] || {};
      const effect = gu.v1_effect || gu.battleEffect || null;
      const miss = gateMissReason(effect, context);
      if (miss) return miss;
    }
    return '';
  }

  // Phase 0：升炼自环（投入=产出同 ID）在真实语义定义前不得进入 live 可见路径。
  function isLiveRecipe(recipe) {
    if (!recipe || recipe.retired || recipe.live === false) return false;
    const inputs = [...(recipe.inputs || [])].map(String).sort();
    const output = String(recipe.output || '');
    if (!output || !inputs.length) return false;
    if (inputs.length === 1 && inputs[0] === output) return false;
    if (inputs.every((id) => id === output) && inputs.includes(output)) {
      const unique = [...new Set(inputs)];
      if (unique.length === 1 && unique[0] === output) return false;
    }
    return true;
  }

  function liveRecipes(recipes) {
    return (recipes || []).filter(isLiveRecipe);
  }

  function isLiveShopOffer(offer) {
    if (!offer || offer.retired || offer.live === false) return false;
    if (offer.mechanical === false) return false;
    return true;
  }

  function liveShopOffers(offers) {
    return (offers || []).filter(isLiveShopOffer);
  }

  const emptyPlan = () => ({
    damage: 0,
    heal: 0,
    block: 0,
    statuses: [],
    swordIntent: 0,
    support: null,
    // L0 Phase 1 规则动词（vertical 最小解冻）
    inspect: false,
    suppressCounter: false,
    armorBreak: 0,
    ignoreEvasion: false,
  });

  function addSupport(plan, effect) {
    const school = String(effect.support_school || '');
    const bonus = Number(effect.support_bonus || 0);
    if (school && bonus > 0) plan.support = { school, bonus };
    return plan;
  }

  function addVerbs(plan, part) {
    if (!part) return plan;
    if (part.inspect) plan.inspect = true;
    if (part.suppress || part.suppressWhenRevealed) plan.suppressCounter = true;
    // armorBreak / pierce 统一为一个语义族
    const ab = Math.max(Number(part.armorBreak || 0), Number(part.pierce || 0));
    if (ab > 0) plan.armorBreak = Math.max(plan.armorBreak || 0, ab);
    if (part.ignoreEvasion) plan.ignoreEvasion = true;
    return plan;
  }

  // L0 Phase 1：敌人问题轴 × 玩家解法。每个问题至少两种可辩护方案。
  // 返回修订后的 damage 与 trace notes（Gate 1 只看行为痕迹）。
  function resolveProblemHit(enemy, plan, rawDamage) {
    let damage = Math.max(0, Number(rawDamage || 0));
    const notes = [];
    const axis = String(enemy?.problemAxis || '');
    if (damage <= 0) return { damage: 0, notes };

    if (axis === 'armor') {
      let armor = Math.max(0, Number(enemy.armorValue || 0));
      if (Number(plan.armorBreak || 0) > 0) {
        armor = Math.max(0, armor - Number(plan.armorBreak));
        notes.push('pierce_armor');
      }
      // 解法 B：稳定低伤/蹭血可穿过重甲（持续输出路线）
      if (damage <= 1) {
        notes.push('chip_through_armor');
      } else {
        const before = damage;
        damage = Math.max(0, damage - armor);
        if (before > 0 && damage === 0 && armor > 0) notes.push('armored');
        else if (damage < before) notes.push('armor_tax');
      }
    }

    if (axis === 'evasion') {
      const bp = Math.max(0, Number(enemy.evasionBreakpoint ?? 2));
      // 解法 A：ignoreEvasion；解法 B：inspect 锁定后必中；解法 C：低伤稳定命中
      const stable = !!plan.ignoreEvasion
        || (!!plan.inspect && !!enemy.revealed)
        || damage <= bp;
      if (!stable) {
        notes.push('evaded');
        damage = 0;
      } else if (plan.ignoreEvasion) {
        notes.push('ignore_evasion');
      } else if (plan.inspect && enemy.revealed) {
        notes.push('locked_on');
      } else {
        notes.push('stable_hit');
      }
    }

    if (axis === 'info') {
      // 解法 A：inspect 后 suppress/正确处理；解法 B：不触发 direct_strike
      // 未识破且未压制的直接攻击吃「读不懂规则」税
      if (!enemy.revealed && !plan.suppressCounter && !plan.inspect) {
        notes.push('unread_tax');
      } else if (plan.suppressCounter && enemy.revealed) {
        notes.push('suppressed_rule');
      } else if (plan.inspect) {
        notes.push('read_rule');
      }
    }

    return { damage, notes };
  }

  function applyPart(plan, part, context = {}) {
    switch (String(part?.kind || '')) {
      case 'strike': {
        const support = Number(context.supports?.[context.school] || 0);
        const swordIntent = String(context.school || '') === 'sword'
          ? Number(context.swordIntent || 0)
          : 0;
        plan.damage += Number(part.amount || 0) + support + swordIntent;
        if (part.consume_status) {
          const name = String(part.consume_status.name || 'marked');
          plan.damage += Number(context.statusStacks?.[name] || 0)
            * Number(part.consume_status.per_stack || 0);
          plan.consumeStatus = name;
        }
        if (part.delay) plan.delayTurns = Math.max(1, Number(part.delay.turns || 1));
        break;
      }
      case 'shield':
      case 'grant_block':
        plan.block += Number(part.amount || 0);
        break;
      case 'heal':
        plan.heal += Number(part.amount || 0);
        break;
      case 'heal_and_strike':
        plan.heal += Number(part.heal || 0);
        plan.damage += Number(part.amount || 0);
        break;
      case 'status':
        plan.statuses.push({ name: String(part.name || 'marked'), amount: Number(part.amount || 1) });
        break;
      case 'shift':
        // 2026-09-12 ruling: shift is converted to an equal amount of block.
        plan.block += Number(part.amount || 1);
        break;
      case 'sword_intent':
        plan.swordIntent += Number(part.amount || 1);
        break;
      case 'weaken_intent':
        plan.intentWeaken = (plan.intentWeaken || 0) + Number(part.amount || 0);
        break;
      case 'inspect':
        plan.inspect = true;
        break;
      default:
        break;
    }
    addVerbs(plan, part);
    return addSupport(plan, part);
  }

  function effectPlan(effect, context = {}) {
    const plan = emptyPlan();
    if (!effect) return plan;
    if (effect.kind === 'composite') {
      for (const part of effect.parts || []) applyPart(plan, part, context);
      return plan;
    }
    return applyPart(plan, effect, context);
  }

  // L0 2026-09-22：杀招效果必须由 recipe 组件按顺序合成，禁止预制 effect/damage 主结算。
  // L0 2026-09-25：组件 battleEffect 合成结果 = 战斗语义权威；组件条件默认继承。
  function killMoveEffectPlan(move, guById = {}, context = {}) {
    const plan = emptyPlan();
    plan.components = [];
    const override = !!move?.componentConditionOverride;
    for (const definitionId of move?.recipe || []) {
      const gu = guById[definitionId] || {};
      const effect = gu.v1_effect || gu.battleEffect || null;
      const entry = { id: String(definitionId || ''), applied: false, gate: '' };
      if (!effect) {
        plan.components.push(entry);
        continue;
      }
      const partContext = { ...context, school: gu.school || context.school || move?.tag || '' };
      entry.gate = gateMissReason(effect, partContext);
      if (entry.gate && !override) {
        plan.components.push(entry);
        continue;
      }
      if (effect.kind === 'composite') {
        for (const part of effect.parts || []) applyPart(plan, part, partContext);
      } else {
        applyPart(plan, effect, partContext);
      }
      entry.applied = true;
      plan.components.push(entry);
    }
    return plan;
  }

  // 直接攻击口径必须跟合成语义一致，而不是预制 m.effect.kind。
  function killMoveIsDirectStrike(move, guById = {}, context = {}) {
    return Number(killMoveEffectPlan(move, guById, context).damage || 0) > 0;
  }

  return Object.freeze({
    canActivate,
    activationReason,
    instanceId,
    attuneCost,
    attuneWild,
    combatRoster,
    killMoveRecipeInstances,
    conditionMet,
    gateMissReason,
    killMoveGateMissReason,
    isLiveRecipe,
    liveRecipes,
    isLiveShopOffer,
    liveShopOffers,
    effectPlan,
    killMoveEffectPlan,
    killMoveIsDirectStrike,
    resolveProblemHit,
    addVerbs,
  });
})();
