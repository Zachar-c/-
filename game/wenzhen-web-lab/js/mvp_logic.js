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
      playerRank: Number(start.playerRank || 1),
      lowRankGu: {},
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
    if (option.penalty?.borrowedMoon) {
      next.borrowedMoon = true;
      /* 借月：唯一合法的越阶催动例外（月芒 rank2 @ 一转） */
      next.lowRankGu = { ...(next.lowRankGu || {}), moon_glow_gu: true };
    }
    next.tradeChoice = option.id;
    next.runLog.push({
      kind: 'trade',
      label: option.label,
      detail: option.consequence,
    });
    return { ok: true, run: next };
  }

  function canUseGu(run, actionId, content) {
    const action = content.actions?.[actionId];
    if (!action) return { ok: false, reason: 'unknown_gu' };
    const playerRank = Number(run.playerRank || 1);
    const guRank = Number(action.rank || 1);
    const except = !!(run.lowRankGu && run.lowRankGu[actionId]);
    if (typeof GuRules !== 'undefined' && GuRules.canActivate) {
      if (!GuRules.canActivate(playerRank, guRank, except)) {
        return { ok: false, reason: 'insufficient_qi_quality', playerRank, guRank };
      }
      return { ok: true };
    }
    if (guRank > playerRank && !except) {
      return { ok: false, reason: 'insufficient_qi_quality', playerRank, guRank };
    }
    return { ok: true };
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
    /* 借月还债：消耗投入解除道伤，不产出二转蛊，不走 gu_rank_cap */
    if (next.borrowedMoon) {
      next.owned = payGu(next.owned, content.forge.consume);
      next.qi -= Number(content.forge.qiCost || 0);
      next.borrowedMoon = false;
      next.lowRankGu = {};
      next.qiMax = next.baseQiMax;
      next.forgeChoice = 'repay';
      next.runLog.push({
        kind: 'forge',
        label: '正炼还债',
        detail: '不获得第二只月芒；解除道伤，真元上限恢复至 12。',
      });
      return { ok: true, run: next };
    }
    /* gu_rank_cap：一转不可炼成并持有可催动的二转蛊（RUL-010 / canActivate） */
    const outputRank = Number(content.forge.outputRank || content.actions?.[content.forge.output]?.rank || 1);
    const playerRank = Number(next.playerRank || 1);
    if (outputRank > playerRank && !content.forge.allowOverRank) {
      return { ok: false, reason: 'insufficient_rank', needRank: outputRank, playerRank, run };
    }
    next.owned = payGu(next.owned, content.forge.consume);
    next.qi -= Number(content.forge.qiCost || 0);
    next.owned = addGu(next.owned, content.forge.output, 1);
    /* 越阶炼成：登记借役例外，否则 canUseGu 会按 gu_rank_cap 拒绝催动 */
    if (outputRank > playerRank) {
      next.lowRankGu = { ...(next.lowRankGu || {}), [content.forge.output]: true };
      next.runLog.push({
        kind: 'forge',
        label: '越阶借役',
        detail: `一转炼成二转${content.forge.output}，仅可以借役催动；转数门禁仍生效。`,
      });
    }
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
      knownCounters: [],
      counterDisabled: false,
      suppressed: false,
      damageReduction: 0,
      ironRage: 0,
      counterBroken: false,
    };
  }

  // 随机入口唯一：RunRules.seededIndex（与 Godot SeededRoll 同序列）。
  function pickVariant(seed, salt, pool) {
    const items = [...(pool || [])];
    if (!items.length) return '';
    const rr = globalThis.RunRules;
    if (!rr || typeof rr.seededIndex !== 'function') {
      throw new Error('mvp_logic.js requires RunRules.seededIndex (load run_rules.js first)');
    }
    return items[rr.seededIndex(items.length, seed, salt, 0)];
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
    next.knownCounters = [...(next.knownCounters || [])];
    next.counterDisabled = false;
    next.suppressed = false;
    next.damageReduction = 0;
    next.currentCounter = '';

    const intent = next.currentIntent;
    /* V4.1-Q2/Q3：反制用确定性序列循环；'none' 明确表示本回合无反制。
       - 默认按「该意图第几次出现」取槽（多意图敌人也能 50% 密度）
       - counterSeqMode:'turn' 时按玩家回合取槽（山猪要 1/3 全回合铁皮）
       不再用 pickVariant 权重，避免某些 seed 连续出 counter。 */
    if (intent?.counterSequence?.length) {
      next.intentHits = { ...(next.intentHits || {}) };
      next.seqCursors = { ...(next.seqCursors || {}) };
      const hitKey = intent.counterSequenceKey || intent.id || 'default';
      next.intentHits[hitKey] = (next.intentHits[hitKey] || 0) + 1;
      const seq = intent.counterSequence;
      let slotIndex;
      if (intent.counterSeqMode === 'turn') {
        slotIndex = (Math.max(1, Number(turn)) - 1) % seq.length;
      } else {
        slotIndex = (next.intentHits[hitKey] - 1) % seq.length;
      }
      const slot = seq[slotIndex];
      if (!slot || slot === 'none') next.currentCounter = '';
      else if (slot === 'iron' && next.counterBroken) next.currentCounter = '';
      else next.currentCounter = String(slot);
    } else if (intent?.counterPool?.length) {
      next.currentCounter = pickVariant(seed, `${next.id}:${turn}:counter`, intent.counterPool);
    } else if (intent?.counter === 'iron' && !next.counterBroken) {
      next.currentCounter = 'iron';
    }
    /* V4：同一反制类型在本场被观察过一次后即永久识别，不再每回合重新隐藏。
       隐藏信息因此只在「第一次遇到该反制」时收一次念头税，而不是每回合固定收。 */
    next.revealed = !!next.currentCounter && next.knownCounters.includes(next.currentCounter);
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
    const id = next.currentCounter;
    next.knownCounters = [...(next.knownCounters || [])];
    if (id && !next.knownCounters.includes(id)) next.knownCounters.push(id);
    return next;
  }

  /* V4：正确处理当前反制的要求 → 本次敌方伤害 -3 并取消该意图附带的特殊效果。
     门槛是「读对 + 做对」：反制必须先被识破（revealed），才开始谈执行要求；
     否则不看信息、靠运气撞对动作就能白拿减伤，信息就不再是资源了。 */
  function counterHandled(enemy, context = {}) {
    const counterId = counterActive(enemy) ? enemy.currentCounter : '';
    if (!counterId || !enemy.revealed) return false;
    switch (counterId) {
      case 'intercept': return !context.attacked;                      // 不硬打
      case 'draw_light': return !!context.usedLight;                   // 用了光道蛊
      case 'iron': return !!enemy.counterDisabled || !!enemy.counterBroken;  // 已破铁皮
      case 'seal_first':
      case 'seal_last': return Number(context.guUsedCount || 0) === 0; // 本回合不出招，无手可封
      default: return false;
    }
  }

  /* V4：普通战胜利后恢复 2 气血 / 2 真元。这是唯一的生存校准阀门——
     不做节点、不做 UI、不做选择。Boss 前不额外满血。 */
  function applyVictoryRecovery(run, content = globalThis.MVP_CONTENT) {
    const next = clone(run);
    const recovery = content?.victoryRecovery || {};
    next.hp = Math.min(next.hpMax, next.hp + Number(recovery.hp || 0));
    next.qi = Math.min(next.qiMax, next.qi + Number(recovery.qi || 0));
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

    /* 铁皮是否在本轮被石皮破掉，必须先结算：counterHandled('iron') 要看这个结果，
       而这些赋值不依赖下方任何伤害计算，因此提前不影响原有语义。 */
    const wasAlreadyBroken = !!nextEnemy.counterBroken;
    if (context.stoneShellUsed && intent.tag === 'charge') nextEnemy.counterBroken = true;
    if (intent.tag === 'charge' && wasAlreadyBroken) nextEnemy.counterBroken = false;

    const counterId = counterActive(nextEnemy) ? nextEnemy.currentCounter : '';
    const handled = counterHandled(nextEnemy, { ...context, intent });
    const specialSuppressed = !!nextEnemy.suppressed;
    const specialCancelled = handled || specialSuppressed;

    let rawDamage = Math.max(0, Number(intent.damage || 0));
    if (intent.tag === 'charge') rawDamage += Math.max(0, Number(nextEnemy.ironRage || 0));
    if (counterId === 'draw_light' && !context.usedLight) rawDamage += 3;
    if (handled) rawDamage = Math.max(0, rawDamage - 3);
    if (specialSuppressed) rawDamage = Math.max(0, rawDamage - 3);
    rawDamage = Math.max(0, rawDamage - Math.max(0, Number(context.damageReduction || 0)));

    const blocked = Math.min(Math.max(0, Number(nextPlayer.block || 0)), rawDamage);
    const hpLoss = rawDamage - blocked;
    nextPlayer.block = Math.max(0, Number(nextPlayer.block || 0) - blocked);
    nextPlayer.hp = Math.max(0, Number(nextPlayer.hp || 0) - hpLoss);
    nextPlayer.lastHpLoss = hpLoss;

    let qiLoss = 0;
    if (!specialCancelled && intent.kind === 'drain_qi') qiLoss += Math.max(0, Number(intent.drainQi || 0));
    if (!specialCancelled && intent.kind === 'burn_qi') qiLoss += Math.max(0, Number(intent.burnQi || 0));
    nextPlayer.qi = Math.max(0, Number(nextPlayer.qi || 0) - qiLoss);

    return {
      enemy: nextEnemy,
      player: nextPlayer,
      damage: hpLoss,
      blocked,
      qiLoss,
      counterId,
      handled,
      specialSuppressed,
      specialCancelled,
    };
  }

  /* 意图预览：回显 V4 减伤后的实际伤害区间（扣减伤前、护体前）。
     与 resolveEnemyAction 同一条公式，避免预览和结算两套账。
     min = 本回合剩余选择里能压到的最低值；max = 做错/未识破时的最高值。 */
  function previewEnemyDamage(enemy, intent, context = {}) {
    const target = intent || enemy?.currentIntent || { damage: 0 };
    const base = Math.max(0, Number(target.damage || 0))
      + (target.tag === 'charge' ? Math.max(0, Number(enemy?.ironRage || 0)) : 0);
    if (!base && !target.damage) return { min: 0, max: 0, base: 0, projected: 0, hasCounter: false };

    const counterId = enemy?.currentCounter || '';
    const revealed = !!enemy?.revealed;
    const suppressed = !!enemy?.suppressed;
    const damageReduction = Math.max(0, Number(context.damageReduction || 0));
    const canStillUseLight = context.canStillUseLight !== false;
    const canStillAvoidAttack = context.canStillAvoidAttack !== false;
    const canStillBreakIron = context.canStillBreakIron !== false;

    const drawPenalty = (usedLight) => (counterId === 'draw_light' && !usedLight ? 3 : 0);
    const handleDrop = (handled) => (handled && revealed ? 3 : 0);
    const suppressDrop = suppressed ? 3 : 0;

    // 当前回合已做选择下的投影值
    const projectedHandled = counterHandled(enemy || {}, context);
    const projected = Math.max(0,
      base
      + drawPenalty(!!context.usedLight)
      - handleDrop(projectedHandled)
      - suppressDrop
      - damageReduction,
    );

    // 最好：本轮仍可「先识破再做对」+ 已有减伤。best 指最优玩法，不把当前未识破卡死。
    const bestHandleDrop = 3;
    let best = base - suppressDrop - damageReduction;
    if (counterId === 'draw_light') {
      if (context.usedLight || canStillUseLight) best -= bestHandleDrop;
      else best += drawPenalty(true);
    } else if (counterId === 'intercept') {
      if (!context.attacked || canStillAvoidAttack) best -= bestHandleDrop;
    } else if (counterId === 'iron') {
      if (enemy?.counterDisabled || enemy?.counterBroken || canStillBreakIron) best -= bestHandleDrop;
    } else if (counterId === 'seal_first' || counterId === 'seal_last') {
      if (Number(context.guUsedCount || 0) === 0) best -= bestHandleDrop;
    }
    best = Math.max(0, best);

    // 最坏：该吃满的加伤与未处理都吃上
    let worst = base + drawPenalty(!!context.usedLight) - suppressDrop - damageReduction;
    if (counterId === 'draw_light' && !context.usedLight && !canStillUseLight) {
      /* 已无法再用光道，逐光加伤已锁定 */
    } else if (counterId === 'draw_light' && !context.usedLight) {
      worst = Math.max(worst, base + 3 - suppressDrop - damageReduction);
    }
    if (counterId === 'intercept' && context.attacked && !canStillAvoidAttack) {
      /* 已硬打，-3 拿不到 */
    }
    worst = Math.max(0, Math.max(worst, projected, best));

    return {
      base,
      min: best,
      max: worst,
      projected,
      hasCounter: !!counterId,
      revealed,
      counterId,
    };
  }

  /* ---------------- V4.1-Q1 逆息 ----------------
     HP→Qi 紧急兑换，只防 soft-lock。+3 Qi 不是免费回复。
     触发条件（玩家回合开始语义）：
       存在至少一只伤害蛊，但当前没有任何伤害蛊能用，且原因包含真元不足。
     效果：1 念头 / 真元 +3（不超上限）/ 气血 -2。
     限制：同一场每 2 个玩家回合最多 1 次；当回合禁收势与生机草蛊。 */

  function isDamageAction(action) {
    return Number(action?.damage || 0) > 0;
  }

  function exhaustionConfig(content) {
    return content?.exhaustion || {
      thought: 1, qiGain: 3, hpCost: 2, cooldownTurns: 2,
      banActions: ['defend', 'vitality_grass_gu'],
    };
  }

  /* 单只伤害蛊的可用性。battle 提供 used/cooldowns/sealedToday/lightSupport。 */
  function damageGuBlockReason(id, action, run, battle = {}, index = 0) {
    const key = `${id}:${index}`;
    if (battle.sealedToday?.[id]) return 'sealed';
    if (battle.used?.[key]) return 'used';
    const nextTurn = Number(battle.cooldowns?.[key] || 0);
    const turn = Number(battle.turn || 1);
    if (nextTurn > turn) return 'cooldown';
    if (Number(run.thoughts || 0) < Number(action.thought || 0)) return 'thought';
    const supported = !!action.light && Number(battle.lightSupport || 0) > 0;
    const qiCost = Math.max(0, Number(action.qi || 0) - (supported ? 1 : 0));
    if (Number(run.qi || 0) < qiCost) return 'qi';
    if (action.hp && Number(run.hp || 0) <= Number(action.hp)) return 'hp';
    return '';
  }

  function exhaustionGate(run, content, battle = {}) {
    const cfg = exhaustionConfig(content);
    const owned = run.owned || {};
    const damageSlots = [];
    for (const [id, count] of Object.entries(owned)) {
      const action = content?.actions?.[id];
      if (!action || !isDamageAction(action)) continue;
      for (let i = 0; i < Number(count || 0); i++) {
        damageSlots.push({ id, index: i, action, reason: damageGuBlockReason(id, action, run, battle, i) });
      }
    }
    const hasDamageGu = damageSlots.length > 0;
    const anyUsable = damageSlots.some((s) => s.reason === '');
    const qiBlocked = damageSlots.some((s) => s.reason === 'qi');
    const cooldownUntil = Number(battle.exhaustionReadyAt || 0);
    const turn = Number(battle.turn || 1);
    const onCooldown = cooldownUntil > turn;
    const banned = !!battle.exhaustionUsedThisTurn;
    const canPay = Number(run.thoughts || 0) >= Number(cfg.thought || 1)
      && Number(run.hp || 0) > Number(cfg.hpCost || 2);
    const eligible = hasDamageGu && !anyUsable && qiBlocked && !onCooldown && !banned && canPay;
    return {
      eligible,
      hasDamageGu,
      anyUsable,
      qiBlocked,
      onCooldown,
      banned,
      canPay,
      cooldownUntil,
      reason: eligible ? '' : (
        !hasDamageGu ? 'no_damage_gu'
          : anyUsable ? 'damage_gu_ready'
            : !qiBlocked ? 'not_qi_blocked'
              : onCooldown ? 'cooldown'
                : banned ? 'already_this_turn'
                  : 'cannot_pay'
      ),
    };
  }

  function applyExhaustion(run, battle, content) {
    const cfg = exhaustionConfig(content);
    const gate = exhaustionGate(run, content, battle);
    if (!gate.eligible) return { ok: false, reason: gate.reason || 'not_eligible', run, battle };
    const nextRun = clone(run);
    const nextBattle = clone(battle);
    nextRun.thoughts = Math.max(0, Number(nextRun.thoughts || 0) - Number(cfg.thought || 1));
    nextRun.qi = Math.min(Number(nextRun.qiMax || 0), Number(nextRun.qi || 0) + Number(cfg.qiGain || 3));
    nextRun.hp = Math.max(0, Number(nextRun.hp || 0) - Number(cfg.hpCost || 2));
    nextBattle.exhaustionUsedThisTurn = true;
    nextBattle.exhaustionReadyAt = Number(nextBattle.turn || 1) + Number(cfg.cooldownTurns || 2);
    nextBattle.exhaustionCount = Number(nextBattle.exhaustionCount || 0) + 1;
    nextBattle.damageReduction = Number(nextBattle.damageReduction || 0); // 收势仍可用过，但之后禁
    return {
      ok: true,
      run: nextRun,
      battle: nextBattle,
      qiGain: Number(cfg.qiGain || 3),
      hpCost: Number(cfg.hpCost || 2),
      banActions: [...(cfg.banActions || [])],
    };
  }

  function isActionBannedThisTurn(actionId, battle = {}, content = null) {
    if (!battle.exhaustionUsedThisTurn) return false;
    const bans = exhaustionConfig(content).banActions || ['defend', 'vitality_grass_gu'];
    return bans.includes(actionId);
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
    canUseGu,
    profileFor,
    createEnemy,
    pickVariant,
    phaseIndexFor,
    intentFor,
    startTurn,
    counterRule,
    counterActive,
    counterHandled,
    revealCounter,
    resolveDirectStrike,
    resolveEnemyAction,
    previewEnemyDamage,
    applyVictoryRecovery,
    isDamageAction,
    damageGuBlockReason,
    exhaustionGate,
    applyExhaustion,
    isActionBannedThisTurn,
    finishEnemyAction,
    sealTarget,
    repeatingGuIds,
    battleReward,
  };
  return Object.freeze(api);
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.MvpLogic;
