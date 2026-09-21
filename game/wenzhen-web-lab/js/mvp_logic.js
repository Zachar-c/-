// Pure state transitions for the focused MVP. Browser and Node run the same code.
globalThis.MvpLogic = (() => {
  const clone = (value) => JSON.parse(JSON.stringify(value));

  function addGu(owned, id, amount = 1) {
    const next = { ...owned };
    next[id] = Math.max(0, Number(next[id] || 0) + Number(amount || 0));
    if (next[id] === 0) delete next[id];
    return next;
  }

  function canPay(owned, cost = {}) {
    return Object.entries(cost).every(([id, amount]) => Number(owned[id] || 0) >= Number(amount || 0));
  }

  function payGu(owned, cost = {}) {
    let next = { ...owned };
    for (const [id, amount] of Object.entries(cost)) next = addGu(next, id, -Number(amount || 0));
    return next;
  }

  function createRun(content) {
    const start = content.run;
    return {
      hp: start.hp,
      hpMax: start.hpMax,
      qi: start.qi,
      qiMax: start.qiMax,
      thoughts: start.thoughts,
      thoughtMax: start.thoughts,
      stones: start.stones,
      owned: clone(start.owned),
      stepIndex: 0,
      battle: null,
      tradeChoice: null,
      forgeChoice: null,
      nextBattlePenalty: false,
      runLog: [],
      result: null,
    };
  }

  function applyTrade(run, optionId, content) {
    const option = (content.tradeOptions || []).find((entry) => entry.id === optionId);
    if (!option) return { ok: false, reason: 'unknown_trade', run };
    if (run.tradeChoice) return { ok: false, reason: 'trade_already_chosen', run };

    const next = clone(run);
    const stoneCost = Number(option.cost?.stones || 0);
    if (next.stones < stoneCost) return { ok: false, reason: 'insufficient_stones', run };
    if (!canPay(next.owned, option.cost?.gu || {})) return { ok: false, reason: 'missing_gu', run };

    next.stones -= stoneCost;
    next.owned = payGu(next.owned, option.cost?.gu || {});
    next.stones += Number(option.gain?.stones || 0);
    for (const [id, amount] of Object.entries(option.gain?.gu || {})) {
      next.owned = addGu(next.owned, id, Number(amount || 0));
    }
    if (option.penalty?.nextBattleHalf) next.nextBattlePenalty = true;
    next.tradeChoice = option.id;
    next.runLog.push({
      kind: 'trade',
      label: option.label,
      detail: option.consequence,
    });
    return { ok: true, run: next };
  }

  function applyForge(run, choice, content) {
    if (run.forgeChoice) return { ok: false, reason: 'forge_already_chosen', run };
    const next = clone(run);
    if (choice === 'preserve') {
      next.stones += Number(content.forge.preserveStones || 0);
      next.forgeChoice = 'preserve';
      next.runLog.push({
        kind: 'forge',
        label: '保炉',
        detail: `保留原有蛊虫，获得 ${content.forge.preserveStones} 元石。`,
      });
      return { ok: true, run: next };
    }
    if (choice !== 'forge') return { ok: false, reason: 'unknown_forge_choice', run };
    if (!canPay(next.owned, content.forge.consume)) {
      return { ok: false, reason: 'missing_ingredients', run };
    }
    next.owned = payGu(next.owned, content.forge.consume);
    next.owned = addGu(next.owned, content.forge.output, 1);
    next.forgeChoice = 'forge';
    next.runLog.push({
      kind: 'forge',
      label: '炼蛊',
      detail: `${content.forge.recipeId} -> ${content.forge.output}；${content.forge.rule}`,
    });
    return { ok: true, run: next };
  }

  function createEnemy(definition) {
    const hp = Number(definition.hp || 1);
    return {
      id: definition.id,
      hp,
      hpMax: hp,
      lastFired: {},
      lastPhaseIndex: -1,
      currentIntent: null,
      revealed: false,
      reactionSettled: false,
      reactionSuppressed: 0,
    };
  }

  function phaseDataFor(definition, hpRatio) {
    if (!definition.phases?.length) {
      return {
        index: 0,
        total: 1,
        data: {
          intents: definition.intent ? [definition.intent] : [],
          reactions: definition.reactions || [],
        },
      };
    }
    const ratio = Math.max(0, Number(hpRatio));
    let index = 0;
    for (let i = 0; i < definition.phases.length; i += 1) {
      if (Number(definition.phases[i].until_hp_ratio) >= ratio) index = i;
    }
    return {
      index,
      total: definition.phases.length,
      data: definition.phases[index],
    };
  }

  function intentReady(lastFired, cooldown, turn) {
    if (lastFired === null || lastFired === undefined) return true;
    return turn >= Number(lastFired) + Number(cooldown || 0) + 1;
  }

  function chooseIntent(definition, enemy, turn) {
    const phase = phaseDataFor(definition, enemy.hp / enemy.hpMax);
    for (const intent of phase.data.intents || []) {
      if (intentReady(enemy.lastFired[intent.id], intent.cooldown, turn)) return intent;
    }
    return null;
  }

  function syncIntent(definition, enemy, turn) {
    const next = clone(enemy);
    const phase = phaseDataFor(definition, next.hp / next.hpMax);
    const phaseChanged = next.lastPhaseIndex >= 0 && next.lastPhaseIndex !== phase.index;
    next.lastPhaseIndex = phase.index;
    next.currentIntent = chooseIntent(definition, next, turn);
    return { enemy: next, phase, phaseChanged };
  }

  function markIntentUsed(enemy, intent, turn) {
    const next = clone(enemy);
    if (intent?.id) next.lastFired[intent.id] = Number(turn);
    return next;
  }

  function phaseReactions(definition, enemy) {
    return phaseDataFor(definition, enemy.hp / enemy.hpMax).data.reactions || [];
  }

  function reactionState(definition, enemy) {
    const reaction = phaseReactions(definition, enemy)[0] || null;
    return {
      reaction,
      live: !!reaction && !enemy.reactionSettled && Number(enemy.reactionSuppressed || 0) <= 0,
      suppressed: !!reaction && Number(enemy.reactionSuppressed || 0) > 0,
      settled: !!reaction && enemy.reactionSettled,
    };
  }

  function resolveDirectStrike(definition, enemy, options = {}) {
    const next = clone(enemy);
    const state = reactionState(definition, next);
    const damage = Math.max(0, Number(options.damage || 0));
    if (state.live && !options.bypassReaction) {
      next.reactionSettled = true;
      return {
        enemy: next,
        damage: 0,
        swallowed: true,
        reactionLabel: state.reaction.label,
      };
    }
    if (state.live && options.bypassReaction) {
      next.reactionSuppressed = Math.max(Number(next.reactionSuppressed || 0), 2);
    } else if (options.suppressReaction) {
      next.reactionSuppressed = Math.max(Number(next.reactionSuppressed || 0), 2);
    }
    next.hp = Math.max(0, Number(next.hp) - damage);
    return {
      enemy: next,
      damage,
      swallowed: false,
      reactionLabel: state.reaction?.label || '',
      suppressed: !!options.suppressReaction && !!state.reaction,
    };
  }

  function tickReactionSuppression(enemy) {
    const next = clone(enemy);
    next.reactionSuppressed = Math.max(0, Number(next.reactionSuppressed || 0) - 1);
    return next;
  }

  function resolveEnemyIntent(enemy, intent, player) {
    const nextEnemy = clone(enemy);
    const nextPlayer = clone(player);
    const rawDamage = Math.max(0, Number(intent?.damage || 0));
    const blocked = Math.min(Math.max(0, Number(nextPlayer.block || 0)), rawDamage);
    const damage = rawDamage - blocked;
    nextPlayer.block = Math.max(0, Number(nextPlayer.block || 0) - blocked);
    nextPlayer.hp = Math.max(0, Number(nextPlayer.hp || 0) - damage);
    nextPlayer.qi = Math.max(0, Number(nextPlayer.qi || 0) - Math.max(0, Number(intent?.essence_burn || 0)));
    return {
      enemy: nextEnemy,
      player: nextPlayer,
      damage,
      blocked,
      essenceBurn: Math.max(0, Number(intent?.essence_burn || 0)),
    };
  }

  function battleReward(definition, rewardConfig) {
    const tier = String(definition?.tier || 'common');
    return Math.max(0, Number(rewardConfig?.base_by_tier?.[tier] || 0));
  }

  function applyNextBattlePenalty(run) {
    if (!run.nextBattlePenalty) return clone(run);
    const next = clone(run);
    next.hp = Math.max(1, Math.floor(next.hp / 2));
    next.qi = Math.floor(next.qi / 2);
    next.nextBattlePenalty = false;
    return next;
  }

  const api = {
    clone,
    addGu,
    canPay,
    payGu,
    createRun,
    applyTrade,
    applyForge,
    createEnemy,
    phaseDataFor,
    intentReady,
    chooseIntent,
    syncIntent,
    markIntentUsed,
    reactionState,
    resolveDirectStrike,
    tickReactionSuppression,
    resolveEnemyIntent,
    battleReward,
    applyNextBattlePenalty,
  };
  return Object.freeze(api);
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.MvpLogic;
