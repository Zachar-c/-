// Pure state transitions for the focused MVP. Values are frozen by the 2026-09-21 L1 ruling.
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

  function actionValues(action = {}, lightSupport = 0) {
    const supported = !!action.light && Number(lightSupport) > 0;
    return {
      qi: Math.max(0, Number(action.qi || 0) - (supported ? 1 : 0)),
      damage: Number(action.damage || 0) + (supported ? 1 : 0),
    };
  }

  function payGu(owned, cost = {}) {
    let next = { ...owned };
    for (const [id, amount] of Object.entries(cost)) next = addGu(next, id, -Number(amount || 0));
    return next;
  }

  function createRun(content, seed = content.run.seed) {
    const start = content.run;
    return {
      seed: Number(seed) || Number(start.seed) || 101,
      hp: start.hp,
      hpMax: start.hpMax,
      qi: start.qi,
      qiMax: start.qiMax,
      baseQiMax: start.baseQiMax,
      thoughts: start.thoughts,
      thoughtMax: start.thoughts,
      stones: start.stones,
      owned: clone(start.owned),
      stepIndex: 0,
      battle: null,
      tradeChoice: null,
      forgeChoice: null,
      borrowedMoon: false,
      runLog: [],
      result: null,
    };
  }

  function smeltStone(run) {
    if (run.stones <= 0) return { ok: false, reason: 'insufficient_stones', run };
    if (run.qi >= run.qiMax) return { ok: false, reason: 'essence_full', run };
    const next = clone(run);
    next.stones -= 1;
    next.qi = Math.min(next.qiMax, next.qi + 2);
    next.runLog.push({
      kind: 'smelt',
      label: '碎石还元',
      detail: '元石 1 → 真元 2。',
    });
    return { ok: true, run: next };
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
    if (option.penalty?.qiMax) {
      next.qiMax = Number(option.penalty.qiMax);
      next.qi = Math.min(next.qi, next.qiMax);
    }
    if (option.penalty?.borrowedMoon) next.borrowedMoon = true;
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
    if (next.qi < Number(content.forge.qiCost || 0)) {
      return { ok: false, reason: 'insufficient_essence', run };
    }
    next.owned = payGu(next.owned, content.forge.consume);
    next.qi -= Number(content.forge.qiCost || 0);
    if (next.borrowedMoon) {
      next.borrowedMoon = false;
      next.qiMax = next.baseQiMax;
      next.forgeChoice = 'repay';
      next.runLog.push({
        kind: 'forge',
        label: '正炼还债',
        detail: '不获得第二只月芒；解除道伤，真元上限恢复至 12。',
      });
      return { ok: true, run: next };
    }
    next.owned = addGu(next.owned, content.forge.output, 1);
    next.forgeChoice = 'forge';
    next.runLog.push({
      kind: 'forge',
      label: '正炼月芒',
      detail: `${content.forge.recipeId} -> ${content.forge.output}；${content.forge.rule}`,
    });
    return { ok: true, run: next };
  }

  function profileFor(content, enemyId) {
    return content.enemyProfiles[enemyId] || null;
  }

  function createEnemy(content, enemyId) {
    const profile = profileFor(content, enemyId);
    if (!profile) throw new Error(`unknown enemy profile: ${enemyId}`);
    return {
      id: enemyId,
      hp: profile.hp,
      hpMax: profile.hp,
      lastPhaseIndex: -1,
      currentIntent: null,
      currentCounter: null,
      revealed: false,
      counterDisabled: false,
      suppressed: false,
      damageReduction: 0,
      ironRage: 0,
      counterBroken: false,
    };
  }

  function hashInt(value) {
    let hash = 0;
    for (const char of String(value)) hash = (hash * 31 + char.charCodeAt(0)) % 2147483647;
    return hash || 1;
  }

  function pickVariant(seed, salt, pool) {
    const items = [...(pool || [])];
    if (!items.length) return '';
    let state = Math.abs((Number(seed) * 1000003) + hashInt(salt)) % 2147483647;
    if (state === 0) state = 1;
    state = (state * 48271) % 2147483647;
    return items[state % items.length];
  }

  function phaseIndexFor(content, enemy) {
    const profile = profileFor(content, enemy.id);
    if (!profile?.phaseAt) return 0;
    return enemy.hp <= profile.phaseAt ? 1 : 0;
  }

  function phaseIntents(content, enemy) {
    const profile = profileFor(content, enemy.id);
    if (!profile) return [];
    if (!profile.phaseAt) return profile.intents || [];
    return phaseIndexFor(content, enemy) === 0 ? profile.phaseOne : profile.phaseTwo;
  }

  function intentFor(content, enemy, turn) {
    const intents = phaseIntents(content, enemy);
    if (!intents.length) return null;
    return clone(intents[(Math.max(1, Number(turn)) - 1) % intents.length]);
  }

  function startTurn(content, enemy, turn, seed) {
    const next = clone(enemy);
    const phaseIndex = phaseIndexFor(content, next);
    const phaseChanged = next.lastPhaseIndex >= 0 && next.lastPhaseIndex !== phaseIndex;
    next.lastPhaseIndex = phaseIndex;
    next.currentIntent = intentFor(content, next, turn);
    next.revealed = false;
    next.counterDisabled = false;
    next.suppressed = false;
    next.damageReduction = 0;
    next.currentCounter = '';

    const intent = next.currentIntent;
    if (intent?.counterPool?.length) {
      next.currentCounter = pickVariant(seed, `${next.id}:${turn}:counter`, intent.counterPool);
    } else if (intent?.counter === 'iron' && !next.counterBroken) {
      next.currentCounter = 'iron';
    }
    return { enemy: next, phaseIndex, phaseChanged };
  }

  function counterRule(content, counterId) {
    return content.counterRules[counterId] || null;
  }

  function counterActive(enemy) {
    return !!enemy.currentCounter && !enemy.counterDisabled && !enemy.suppressed;
  }

  function revealCounter(enemy) {
    const next = clone(enemy);
    next.revealed = true;
    return next;
  }

  function resolveDirectStrike(enemy, options = {}) {
    const next = clone(enemy);
    const damage = Math.max(0, Number(options.damage || 0));
    const counterId = counterActive(next) ? next.currentCounter : '';

    if (counterId === 'intercept' && !options.bypassCounter) {
      next.hp = Math.max(0, next.hp);
      return { enemy: next, damage: 0, swallowed: true, counterId, selfDamage: 2 };
    }
    if (counterId === 'iron' && !options.bypassCounter) {
      next.ironRage += 1;
      return { enemy: next, damage: 0, swallowed: true, counterId, ironRage: next.ironRage };
    }
    if (options.bypassCounter && counterId) next.counterDisabled = true;
    if (options.suppressCounter) {
      next.counterDisabled = true;
      next.suppressed = true;
      next.damageReduction = Math.max(Number(next.damageReduction || 0), 3);
    }
    next.hp = Math.max(0, Number(next.hp) - damage);
    return {
      enemy: next,
      damage,
      swallowed: false,
      counterId,
      selfDamage: 0,
      suppressed: !!options.suppressCounter && !!counterId,
    };
  }

  function resolveEnemyAction(enemy, player, context = {}) {
    const nextEnemy = clone(enemy);
    const nextPlayer = clone(player);
    const intent = context.intent || enemy.currentIntent || { damage: 0 };
    const counterId = counterActive(nextEnemy) ? nextEnemy.currentCounter : '';
    let rawDamage = Math.max(0, Number(intent.damage || 0));

    if (intent.tag === 'charge') rawDamage += Math.max(0, Number(nextEnemy.ironRage || 0));
    if (counterId === 'draw_light' && !context.usedLight) rawDamage += 3;
    if (nextEnemy.suppressed) rawDamage = Math.max(0, rawDamage - 3);
    rawDamage = Math.max(0, rawDamage - Math.max(0, Number(context.damageReduction || 0)));

    const blocked = Math.min(Math.max(0, Number(nextPlayer.block || 0)), rawDamage);
    const hpLoss = rawDamage - blocked;
    nextPlayer.block = Math.max(0, Number(nextPlayer.block || 0) - blocked);
    nextPlayer.hp = Math.max(0, Number(nextPlayer.hp || 0) - hpLoss);
    nextPlayer.lastHpLoss = hpLoss;

    const specialSuppressed = !!nextEnemy.suppressed;
    let qiLoss = 0;
    if (!specialSuppressed && intent.kind === 'drain_qi') qiLoss += Math.max(0, Number(intent.drainQi || 0));
    if (!specialSuppressed && intent.kind === 'burn_qi') qiLoss += Math.max(0, Number(intent.burnQi || 0));
    nextPlayer.qi = Math.max(0, Number(nextPlayer.qi || 0) - qiLoss);

    const wasAlreadyBroken = !!nextEnemy.counterBroken;
    if (context.stoneShellUsed && intent.tag === 'charge') nextEnemy.counterBroken = true;
    if (intent.tag === 'charge' && wasAlreadyBroken) nextEnemy.counterBroken = false;

    return {
      enemy: nextEnemy,
      player: nextPlayer,
      damage: hpLoss,
      blocked,
      qiLoss,
      counterId,
      specialSuppressed,
    };
  }

  function finishEnemyAction(enemy) {
    const next = clone(enemy);
    next.currentCounter = '';
    next.currentIntent = null;
    next.revealed = false;
    next.counterDisabled = false;
    next.suppressed = false;
    next.damageReduction = 0;
    return next;
  }

  function sealTarget(counterId, actionOrder = []) {
    if (counterId === 'seal_first') return actionOrder[0] || '';
    if (counterId === 'seal_last') return actionOrder.at(-1) || '';
    return '';
  }

  function repeatingGuIds(previous = [], current = []) {
    const previousIds = new Set(previous);
    return [...new Set(current.filter((id) => previousIds.has(id)))];
  }

  function battleReward(data, enemyId) {
    const definition = data?.enemies?.find((entry) => entry.id === enemyId);
    const tier = String(definition?.tier || 'common');
    return Math.max(0, Number(data?.battle?.stoneRewards?.base_by_tier?.[tier] || 0));
  }

  const api = {
    clone,
    addGu,
    canPay,
    payGu,
    actionValues,
    createRun,
    smeltStone,
    applyTrade,
    applyForge,
    profileFor,
    createEnemy,
    pickVariant,
    phaseIndexFor,
    intentFor,
    startTurn,
    counterRule,
    counterActive,
    revealCounter,
    resolveDirectStrike,
    resolveEnemyAction,
    finishEnemyAction,
    sealTarget,
    repeatingGuIds,
    battleReward,
  };
  return Object.freeze(api);
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.MvpLogic;
