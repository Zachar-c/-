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
    return (move?.recipe || []).map((definitionId) => {
      for (let index = 0; index < Number(owned[definitionId] || 0); index += 1) {
        const candidate = instanceId(definitionId, index);
        if (!usedInstances[candidate] && !sealedInstances[candidate]) return candidate;
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

  const emptyPlan = () => ({
    damage: 0,
    heal: 0,
    block: 0,
    statuses: [],
    swordIntent: 0,
    support: null,
  });

  function addSupport(plan, effect) {
    const school = String(effect.support_school || '');
    const bonus = Number(effect.support_bonus || 0);
    if (school && bonus > 0) plan.support = { school, bonus };
    return plan;
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
      default:
        break;
    }
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
    effectPlan,
  });
})();
