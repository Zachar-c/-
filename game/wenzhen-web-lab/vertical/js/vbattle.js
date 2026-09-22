/* 《问真》Vertical Lab · 可执行战斗规则 V0.1
 * 按 EXECUTABLE_SPEC Phase 1–5：回合/HP/Qi/Thought/距离/盾/状态/Counter/杀招/AI。
 * 同 seed 完全复现。禁止转数万能倍率。
 */
globalThis.VBattle = (() => {
  function mulberry32(a) {
    return function () {
      let t = (a += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function deriveStreams(battleSeed) {
    return {
      intent: mulberry32(battleSeed * 1 + 1),
      counter: mulberry32(battleSeed * 2 + 2),
      hit: mulberry32(battleSeed * 3 + 3),
      loot: mulberry32(battleSeed * 4 + 4),
    };
  }

  const COUNTER_MITIGATION = { 1: 3, 2: 5, 3: 8, 4: 12, 5: 17 };
  const INTERCEPT_RECOIL = { 1: 2, 2: 4, 3: 7, 4: 11, 5: 16 };
  const IRON_SHIELD = { 1: 6, 2: 10, 3: 16, 4: 24, 5: 32 };

  function qiCostFor(baseQi, playerRank, guRank) {
    if (guRank > playerRank) return null;
    return Math.max(1, Math.round(Number(baseQi || 0) * Math.pow(0.65, playerRank - guRank)));
  }

  function createContext({ player, enemies, guIndex, moveIndex, battleSeed = 1, encounterType = 'normal' }) {
    const streams = deriveStreams(battleSeed);
    const ctx = {
      battleSeed,
      encounterType,
      round: 0,
      maxRounds: enemies.some((e) => e.isBoss) ? 50 : 30,
      player: {
        hp: player.hp,
        maxHp: player.maxHp,
        qi: player.qi,
        maxQi: player.maxQi || 100,
        thought: 0,
        maxThought: 2,
        rank: player.rank || 1,
        distance: player.distance != null ? player.distance : 2,
        shield: player.shield || 0,
        statuses: [],
        knownCounters: new Set(),
        owned: { ...(player.owned || {}) },
        cooldowns: {},
        sealed: {},
        lastActions: [],
        movesKnown: player.movesKnown || [],
        route: player.route || 'hybrid',
      },
      enemies: enemies.map((e, i) => ({
        ...e,
        uid: e.id || `E${i}`,
        hp: e.hp,
        maxHp: e.hp,
        shield: e.shield || 0,
        ironShield: 0,
        flatReduction: Number(e.defense || 0),
        statuses: [],
        phase: 1,
        currentIntent: null,
        currentCounter: null,
        counterRevealed: false,
        counterHandled: false,
        counterConsumed: false,
        dead: false,
        frost: 0,
        bleed: null,
        evadeOnce: false,
        qi: 100,
        maxQi: 100,
      })),
      guIndex,
      moveIndex,
      streams,
      log: [],
      result: null,
      stats: {
        damageDealt: 0,
        damageTaken: 0,
        qiSpent: 0,
        countersHandled: 0,
        controlsApplied: 0,
        kills: 0,
        guUsed: new Set(),
        movesUsed: new Set(),
      },
    };
    return ctx;
  }

  function aliveEnemies(ctx) {
    return ctx.enemies.filter((e) => !e.dead);
  }

  function applyDamageToEnemy(ctx, enemy, raw, opts = {}) {
    if (enemy.dead) return 0;
    let dmg = Math.max(0, Number(raw || 0));
    // 破甲先减 flatReduction
    let flat = Number(enemy.flatReduction || 0);
    const br = Number(opts.armorBreak || 0);
    flat = Math.max(0, flat - br);
    dmg = Math.max(0, dmg - flat);
    // 抗性
    const tag = opts.tag || 'physical';
    const res = Number(enemy.resist?.includes?.(tag) ? 0.3 : enemy.resistMap?.[tag] || (enemy.resist?.includes?.(tag) ? 0.3 : 0));
    // weak 简化为 +20% 伤
    if (enemy.weak?.includes?.(tag)) dmg = Math.round(dmg * 1.2);
    else dmg = Math.round(dmg * (1 - res));
    // counter mitigation
    if (opts.counteredMitigation) dmg = Math.max(0, dmg - opts.counteredMitigation);
    // ignore shield portion
    let toShield = enemy.shield || 0;
    let overflow = dmg;
    if (opts.ignoreShield) {
      const hitShield = Math.min(toShield, Number(opts.ignoreShield));
      // ignoreShield 直接穿透部分盾
      overflow = dmg; // 无视的盾不吸收
      const absorbed = Math.min(toShield, Math.max(0, dmg - 0));
      // 简化：ignoreShield N 表示前 N 点伤害不吃盾
      const shieldedPart = Math.max(0, dmg - Number(opts.ignoreShield));
      const absorbedShield = Math.min(toShield, shieldedPart);
      enemy.shield = toShield - absorbedShield;
      overflow = dmg - absorbedShield;
    } else {
      const absorbed = Math.min(toShield, dmg);
      enemy.shield = toShield - absorbed;
      overflow = dmg - absorbed;
    }
    enemy.hp -= overflow;
    ctx.stats.damageDealt += overflow;
    if (enemy.hp <= 0) {
      enemy.hp = 0;
      enemy.dead = true;
      ctx.stats.kills++;
    }
    return overflow;
  }

  function applyDamageToPlayer(ctx, raw, opts = {}) {
    let dmg = Math.max(0, Number(raw || 0));
    if (ctx.player.statuses.some((s) => s.id === 'brace')) dmg = Math.max(1, Math.round(dmg * 0.8));
    if (opts.counteredMitigation) dmg = Math.max(0, dmg - opts.counteredMitigation);
    if (ctx.player.statuses.some((s) => s.id === 'freezereduce')) dmg = Math.round(dmg * 0.5);
    let toShield = ctx.player.shield || 0;
    const absorbed = Math.min(toShield, dmg);
    ctx.player.shield = toShield - absorbed;
    const overflow = dmg - absorbed;
    ctx.player.hp -= overflow;
    ctx.stats.damageTaken += overflow;
    if (ctx.player.hp <= 0) {
      ctx.player.hp = 0;
      ctx.result = 'death';
    }
    return overflow;
  }

  function revealCounter(ctx, enemy) {
    enemy.counterRevealed = true;
    if (enemy.currentCounter && enemy.currentCounter !== 'none') {
      ctx.player.knownCounters.add(enemy.currentCounter);
    }
  }

  function counterKnown(ctx, enemy) {
    return enemy.counterRevealed || ctx.player.knownCounters.has(enemy.currentCounter);
  }

  /* handled = (已揭示 OR Known) AND 正确行为 */
  function resolveCounterOnAttack(ctx, enemy, action) {
    const c = enemy.currentCounter;
    if (!c || c === 'none' || enemy.counterConsumed) {
      return { mitigation: 0, recoil: 0, blocked: false, suppressed: false };
    }
    const known = counterKnown(ctx, enemy);
    let handled = false;
    let suppressed = false;

    if (c === 'intercept') {
      if (action.directAttack) {
        // 迎击：第一次 DirectAttack 伤害=0 并反伤
        enemy.counterConsumed = true;
        const recoil = INTERCEPT_RECOIL[enemy.rank || 1] || 2;
        if (known) {
          handled = true; // 读对+做对：若玩家用非直接手段，则不吃
        }
        return { mitigation: known ? COUNTER_MITIGATION[enemy.rank || 1] || 3 : 0, recoil: known ? 0 : recoil, blocked: true, suppressed: false, known, handled: known };
      }
      // 玩家没用 DirectAttack = 正确应对
      handled = true;
    } else if (c === 'draw_light') {
      if (action.tags?.includes?.('light') || action.tags?.includes?.('moon') || action.light) handled = true;
    } else if (c === 'iron') {
      if (action.armorBreak > 0 || action.suppressWhenRevealed || action.ignoreShield) handled = true;
    } else if (c === 'seal_first' || c === 'seal_last') {
      // 用廉价辅助先/后吃封印 = 正确
      if (action.sacrificialSeal) handled = true;
      else if (known) handled = false;
    }

    if (action.suppressWhenRevealed && known) {
      suppressed = true;
      enemy.counterConsumed = true;
      handled = true;
    }

    const mitigation = handled && known ? (COUNTER_MITIGATION[enemy.rank || 1] || 3) : 0;
    if (handled && known) {
      enemy.counterHandled = true;
      ctx.stats.countersHandled++;
      enemy.counterConsumed = true;
    } else if (c === 'seal_first' || c === 'seal_last') {
      if (!handled) {
        // 封玩家蛊
        const guId = action.guId;
        if (guId) ctx.player.sealed[guId] = 1;
        enemy.counterConsumed = true;
      }
    } else if (c === 'draw_light' && !handled) {
      // 敌方伤害 +40%，下次 enemyAct 用
      enemy.pendingDrawLightBonus = true;
      enemy.counterConsumed = true;
    } else if (c === 'iron') {
      enemy.ironShield = IRON_SHIELD[enemy.rank || 1] || 6;
      enemy.counterConsumed = true;
    }

    return { mitigation, recoil: 0, blocked: false, suppressed, known, handled: handled && known };
  }

  function canUseGu(ctx, guId) {
    const g = ctx.guIndex[guId];
    if (!g) return { ok: false, reason: 'unknown_gu' };
    if ((ctx.player.owned[guId] || 0) <= 0) return { ok: false, reason: 'not_owned' };
    if (ctx.player.sealed[guId] > 0) return { ok: false, reason: 'sealed' };
    if ((ctx.player.cooldowns[guId] || 0) > 0) return { ok: false, reason: 'cooldown' };
    if (g.rank > ctx.player.rank) return { ok: false, reason: 'rank_too_high' };
    const cost = qiCostFor(g.qi, ctx.player.rank, g.rank);
    if (cost == null) return { ok: false, reason: 'rank_too_high' };
    if (ctx.player.qi < cost) return { ok: false, reason: 'qi' };
    if (ctx.player.thought < (g.thought || 1)) return { ok: false, reason: 'thought' };
    return { ok: true, cost, thought: g.thought || 1 };
  }

  function useGu(ctx, guId, targetUid) {
    const chk = canUseGu(ctx, guId);
    if (!chk.ok) return { ok: false, reason: chk.reason };
    const g = ctx.guIndex[guId];
    const enemy = ctx.enemies.find((e) => e.uid === targetUid) || aliveEnemies(ctx)[0];
    const action = {
      guId,
      directAttack: Number(g.damage || 0) > 0,
      damage: Number(g.damage || 0),
      armorBreak: 0,
      ignoreShield: 0,
      tags: g.tags || [],
      light: g.tags?.includes?.('light') || g.tags?.includes?.('moon'),
      suppressWhenRevealed: !!g.status && String(g.status).includes('suppress'),
      thought: g.thought || 1,
    };
    ctx.player.thought -= chk.thought;
    ctx.player.qi -= chk.cost;
    ctx.stats.qiSpent += chk.cost;
    ctx.stats.guUsed.add(guId);
    ctx.player.lastActions.push(guId);
    if (ctx.player.lastActions.length > 4) ctx.player.lastActions.shift();

    let countered = { mitigation: 0, recoil: 0, blocked: false };
    if (enemy && !enemy.dead) countered = resolveCounterOnAttack(ctx, enemy, action);

    if (countered.recoil) applyDamageToPlayer(ctx, countered.recoil, { true: true });

    if (!countered.blocked && enemy && !enemy.dead && action.damage > 0) {
      applyDamageToEnemy(ctx, enemy, action.damage, {
        mitigation: countered.mitigation,
        counteredMitigation: countered.mitigation,
        tag: (g.tags || []).find((t) => t !== 'direct') || 'moon',
        ignoreShield: g.status?.includes?.('ignore_shield') ? 8 : 0,
        armorBreak: g.status?.includes?.('pierce') ? 2 : 0,
      });
    }

    if (g.block) ctx.player.shield += Number(g.block);
    if (g.status === 'reveal_counter' && enemy) revealCounter(ctx, enemy);
    if (g.status === 'moon_dust' && enemy) {
      enemy.statuses.push({ id: 'moon_dust', duration: 2 });
    }
    if (g.status === 'frost2' && enemy) {
      enemy.frost = (enemy.frost || 0) + 2;
      if (enemy.frost >= 3) {
        enemy.frost = 0;
        enemy.statuses.push({ id: 'freeze', duration: 1 });
        ctx.stats.controlsApplied++;
      }
    }
    if (g.status === 'bleed3x3' && enemy) {
      enemy.bleed = { amount: 3, duration: 3 };
    }
    if (g.hp) applyDamageToPlayer(ctx, Number(g.hp), { true: true, self: true });

    ctx.player.cooldowns[guId] = Number(g.cd || 0) + 1; // 使用后 cd 空 cd 回合；startPlayerTurn 递减
    return { ok: true, countered };
  }

  function useKillMove(ctx, moveId, targetUid) {
    const m = ctx.moveIndex[moveId];
    if (!m) return { ok: false, reason: 'unknown_move' };
    for (const id of m.coreGu || []) {
      if ((ctx.player.owned[id] || 0) <= 0) return { ok: false, reason: 'missing_core' };
      if (ctx.player.sealed[id] > 0) return { ok: false, reason: 'core_sealed' };
      if ((ctx.player.cooldowns[id] || 0) > 0) return { ok: false, reason: 'core_cd' };
    }
    for (const id of m.supportGu || []) {
      if (m.supportMode === 'required' && (ctx.player.owned[id] || 0) <= 0) return { ok: false, reason: 'missing_support' };
    }
    if (ctx.player.thought < m.thoughtCost) return { ok: false, reason: 'thought' };
    if (ctx.player.qi < m.qiCost) return { ok: false, reason: 'qi' };
    if (m.hpCost && ctx.player.hp <= m.hpCost) return { ok: false, reason: 'hp' };

    // 只支付一次 composite cost
    ctx.player.thought -= m.thoughtCost;
    ctx.player.qi -= m.qiCost;
    ctx.stats.qiSpent += m.qiCost;
    if (m.hpCost) applyDamageToPlayer(ctx, m.hpCost, { self: true, true: true });
    ctx.stats.movesUsed.add(moveId);

    const enemy = ctx.enemies.find((e) => e.uid === targetUid) || aliveEnemies(ctx)[0];
    let total = 0;
    for (const eff of m.effects || []) {
      if (eff.type === 'damage') {
        let hits = eff.hits || 1;
        let amount = eff.amount;
        for (let i = 0; i < hits; i++) {
          if (!enemy || enemy.dead) break;
          const action = { directAttack: true, damage: amount, tags: m.tags || [], suppressWhenRevealed: false };
          const c = resolveCounterOnAttack(ctx, enemy, action);
          if (!c.blocked) {
            total += applyDamageToEnemy(ctx, enemy, amount, {
              counteredMitigation: c.mitigation,
              tag: 'moon',
              armorBreak: eff.armorBreak || (eff.firstFourArmorBreak && i < 4 ? 4 : 0),
              ignoreShield: eff.ignoreShield || 0,
            });
          }
          if (eff.sameTargetDecay) amount = Math.max(1, amount - eff.sameTargetDecay);
        }
      } else if (eff.type === 'block') {
        ctx.player.shield += eff.amount;
      } else if (eff.type === 'status' && enemy) {
        if (eff.id === 'frost') {
          enemy.frost = (enemy.frost || 0) + (eff.stacks || 1);
          if (enemy.frost >= 3) {
            enemy.frost = 0;
            if (enemy.isBoss) enemy.statuses.push({ id: 'freezereduce', duration: 1 });
            else enemy.statuses.push({ id: 'freeze', duration: 1 });
            ctx.stats.controlsApplied++;
          }
        } else if (eff.id === 'bleed') {
          enemy.bleed = { amount: eff.amount, duration: eff.duration };
        } else if (eff.id === 'freeze') {
          if (enemy.isBoss) enemy.statuses.push({ id: 'freezereduce', duration: 1 });
          else enemy.statuses.push({ id: 'freeze', duration: 1 });
        } else if (eff.id === 'no_move' || eff.id === 'seal_action') {
          enemy.statuses.push({ id: eff.id, duration: eff.duration || 1 });
          ctx.stats.controlsApplied++;
        }
      } else if (eff.type === 'stealth') {
        ctx.player.statuses.push({ id: 'stealth', duration: eff.duration || 1 });
      } else if (eff.type === 'illusion') {
        ctx.player.statuses.push({ id: 'illusion', stacks: eff.count || 1 });
      } else if (eff.type === 'inspect' && enemy) {
        revealCounter(ctx, enemy);
      } else if (eff.type === 'qi_restore') {
        ctx.player.qi = Math.min(ctx.player.maxQi, ctx.player.qi + Math.round(ctx.player.maxQi * (eff.pct / 100)));
      } else if (eff.type === 'max_qi_reduce' && enemy) {
        enemy.maxQi = Math.max(10, Math.round(enemy.maxQi * (1 - eff.pct / 100)));
        if (enemy.qi > enemy.maxQi) enemy.qi = enemy.maxQi;
      }
    }

    // 组件冷却
    const compCd = Math.max(Number(m.cooldown || 0), ...[...(m.coreGu || []), ...(m.supportGu || [])].map((id) => Number(ctx.guIndex[id]?.cd || 0)));
    for (const id of [...(m.coreGu || []), ...(m.supportGu || [])]) {
      ctx.player.cooldowns[id] = Math.max(ctx.player.cooldowns[id] || 0, compCd + 1);
    }
    return { ok: true, damage: total };
  }

  function observe(ctx, targetUid) {
    if (ctx.player.thought < 1) return { ok: false, reason: 'thought' };
    ctx.player.thought -= 1;
    const enemy = ctx.enemies.find((e) => e.uid === targetUid) || aliveEnemies(ctx)[0];
    if (enemy) revealCounter(ctx, enemy);
    return { ok: true };
  }

  function moveCloser(ctx) {
    if (ctx.player.thought < 1) return { ok: false, reason: 'thought' };
    ctx.player.thought -= 1;
    ctx.player.distance = Math.max(0, ctx.player.distance - 1);
    return { ok: true };
  }

  function brace(ctx) {
    if (ctx.player.thought < 1) return { ok: false, reason: 'thought' };
    if (ctx.player.statuses.some((s) => s.id === 'reverse_breath')) return { ok: false, reason: 'reverse_blocks' };
    ctx.player.thought -= 1;
    ctx.player.statuses.push({ id: 'brace', duration: 1 });
    return { ok: true };
  }

  function reverseBreath(ctx) {
    // 触发：有伤害蛊但都因 Qi 不足
    const hasDamageGu = Object.keys(ctx.player.owned).some((id) => (ctx.player.owned[id] || 0) > 0 && Number(ctx.guIndex[id]?.damage || 0) > 0);
    const anyAffordable = Object.keys(ctx.player.owned).some((id) => {
      const g = ctx.guIndex[id];
      if (!g || (ctx.player.owned[id] || 0) <= 0 || Number(g.damage || 0) <= 0) return false;
      const c = qiCostFor(g.qi, ctx.player.rank, g.rank);
      return c != null && ctx.player.qi >= c && ctx.player.thought >= (g.thought || 1);
    });
    if (!hasDamageGu || anyAffordable) return { ok: false, reason: 'not_starved' };
    if (ctx.player.thought < 1) return { ok: false, reason: 'thought' };
    if (ctx.player.statuses.some((s) => s.id === 'reverse_cd')) return { ok: false, reason: 'cd' };
    ctx.player.thought -= 1;
    const hpCost = Math.ceil(ctx.player.maxHp * 0.08);
    applyDamageToPlayer(ctx, hpCost, { self: true, true: true });
    ctx.player.qi = Math.min(ctx.player.maxQi, ctx.player.qi + 15);
    ctx.player.statuses.push({ id: 'reverse_breath', duration: 1 });
    ctx.player.statuses.push({ id: 'reverse_cd', duration: 2 });
    return { ok: true };
  }

  function pickIntent(ctx, enemy) {
    const pool = (enemy.intents || []).filter((it) => {
      if (it.phaseRequirement && enemy.phase < it.phaseRequirement) return false;
      return true;
    });
    if (!pool.length) return null;
    let total = 0;
    for (const it of pool) total += Number(it.weight || 1);
    let r = ctx.streams.intent() * total;
    for (const it of pool) {
      r -= Number(it.weight || 1);
      if (r <= 0) return { ...it, counterPool: it.counterPool || enemy.counters || ['none'] };
    }
    return { ...pool[0], counterPool: pool[0].counterPool || enemy.counters || ['none'] };
  }

  function pickCounter(ctx, intent) {
    const pool = intent?.counterPool?.length ? intent.counterPool : ['none'];
    const idx = Math.floor(ctx.streams.counter() * pool.length);
    return pool[Math.min(idx, pool.length - 1)];
  }

  function enemyPlan(ctx) {
    for (const e of aliveEnemies(ctx)) {
      const intent = pickIntent(ctx, e);
      e.currentIntent = intent;
      e.currentCounter = pickCounter(ctx, intent);
      e.counterRevealed = ctx.player.knownCounters.has(e.currentCounter);
      e.counterHandled = false;
      e.counterConsumed = false;
      e.pendingDrawLightBonus = false;
    }
  }

  function hitRoll(ctx, bonus = 0) {
    return ctx.streams.hit() * 100 < 100 + bonus; // 基础 100%；闪避单独减
  }

  function enemyAct(ctx) {
    for (const e of aliveEnemies(ctx)) {
      // Freeze
      const fr = e.statuses.find((s) => s.id === 'freeze');
      if (fr) {
        e.statuses = e.statuses.filter((s) => s.id !== 'freeze');
        continue;
      }
      const frRed = e.statuses.find((s) => s.id === 'freezereduce');
      const intent = e.currentIntent;
      if (!intent) continue;
      if (intent.special === 'reveal_stealth' || intent.special === 'track_stealth_repeat_reduce25') {
        ctx.player.statuses = ctx.player.statuses.filter((s) => s.id !== 'stealth');
      }
      if (!intent.damage) continue;

      // Stealth: 普通单体锁定不能选中
      const stealth = ctx.player.statuses.find((s) => s.id === 'stealth');
      if (stealth && !e.special?.id?.includes?.('track') && !intent.aoe) {
        continue;
      }
      // Illusion
      const ill = ctx.player.statuses.find((s) => s.id === 'illusion');
      if (ill && ill.stacks > 0 && !intent.aoe) {
        ill.stacks -= 1;
        continue;
      }

      let dmg = intent.damage;
      if (e.pendingDrawLightBonus) dmg = Math.round(dmg * 1.4);
      if (frRed) dmg = Math.round(dmg * 0.5);
      if (e.ironShield > 0) {
        // iron 是敌方防御，玩家攻击侧处理；此处敌方行动不受 iron 影响
      }
      if (!hitRoll(ctx, 0)) continue;
      applyDamageToPlayer(ctx, dmg, {});
      if (intent.qiStealPct) {
        const steal = Math.round(ctx.player.maxQi * intent.qiStealPct / 100);
        ctx.player.qi = Math.max(0, ctx.player.qi - steal);
        e.qi = Math.min(e.maxQi, e.qi + steal);
      }
    }
  }

  function resolveDOT(ctx) {
    for (const e of aliveEnemies(ctx)) {
      if (e.bleed && e.bleed.duration > 0) {
        applyDamageToEnemy(ctx, e, e.bleed.amount, { tag: 'blood' });
        e.bleed.duration -= 1;
      }
    }
  }

  function resolveDuration(ctx) {
    const tick = (list) => list.map((s) => ({ ...s, duration: s.duration - 1 })).filter((s) => s.duration > 0);
    ctx.player.statuses = tick(ctx.player.statuses);
    for (const e of ctx.enemies) e.statuses = tick(e.statuses);
    for (const k of Object.keys(ctx.player.cooldowns)) {
      if (ctx.player.cooldowns[k] > 0) ctx.player.cooldowns[k] -= 1;
    }
    for (const k of Object.keys(ctx.player.sealed)) {
      if (ctx.player.sealed[k] > 0) ctx.player.sealed[k] -= 1;
    }
  }

  function startRound(ctx) {
    ctx.round++;
    if (ctx.round > ctx.maxRounds) {
      ctx.result = 'timeout';
      return false;
    }
    return true;
  }

  function startPlayerTurn(ctx) {
    ctx.player.thought = ctx.player.maxThought;
  }

  function endPlayerTurn(ctx) {
    ctx.player.thought = 0;
  }

  function deathCheck(ctx) {
    if (ctx.player.hp <= 0) {
      ctx.result = 'death';
      return false;
    }
    if (!aliveEnemies(ctx).length) {
      ctx.result = 'clear';
      return false;
    }
    return true;
  }

  function isStalemate(ctx, history) {
    if (history.length < 8) return false;
    const last8 = history.slice(-8);
    return last8.every((h) => h.playerHp === last8[0].playerHp && h.enemyHp === last8[0].enemyHp);
  }

  /* 简单 autoplay：按评分选行动，不读隐藏 Counter / 未来 Intent */
  function autoplayAction(ctx) {
    const p = ctx.player;
    const targets = aliveEnemies(ctx);
    const t = targets[0];
    if (!t) return null;

    // 逆息窗
    const canReverse = reverseBreath(ctx);
    if (canReverse.ok) return { type: 'reverse' };

    const options = [];
    for (const [id, n] of Object.entries(p.owned)) {
      if (n <= 0) continue;
      const chk = canUseGu(ctx, id);
      if (!chk.ok) continue;
      const g = ctx.guIndex[id];
      let score = Number(g.damage || 0) + Number(g.block || 0) * 0.5 + Number(g.heal || 0) * 0.8;
      if (g.status === 'reveal_counter' && !t.counterRevealed) score += 6;
      if (g.status?.includes?.('suppress') && t.counterRevealed) score += 8;
      if ((t.currentCounter === 'intercept' && !t.counterRevealed) || (t.currentCounter === 'intercept' && p.knownCounters.has('intercept'))) {
        // 读对：若已知迎击，避免 DirectAttack
        if (Number(g.damage || 0) > 0) score -= 20;
        else score += 3;
      }
      if (t.currentCounter === 'draw_light' && (g.tags?.includes?.('light') || g.tags?.includes?.('moon'))) score += 4;
      score -= Number(g.qi || 0) * 0.05;
      options.push({ type: 'gu', id, score });
    }
    for (const mid of p.movesKnown || []) {
      const m = ctx.moveIndex[mid];
      if (!m) continue;
      const probe = useKillMoveProbe(ctx, mid);
      if (!probe.ok) continue;
      let score = 8 + (m.effects || []).reduce((a, e) => a + (e.amount || 0) * (e.hits || 1), 0) * 0.3;
      score -= m.qiCost * 0.04;
      if (m.requiredState?.includes?.('inspected_target') && !t.counterRevealed) score -= 50;
      options.push({ type: 'move', id: mid, score });
    }
    if (t.currentCounter && t.currentCounter !== 'none' && !t.counterRevealed) {
      options.push({ type: 'observe', score: 5 });
    }
    options.push({ type: 'brace', score: p.hp < p.maxHp * 0.35 ? 4 : 0.5 });
    options.push({ type: 'move_closer', score: p.distance > 2 ? 3 : 0.2 });

    options.sort((a, b) => b.score - a.score);
    return options[0] || { type: 'wait' };
  }

  function useKillMoveProbe(ctx, moveId) {
    const m = ctx.moveIndex[moveId];
    if (!m) return { ok: false };
    for (const id of m.coreGu || []) {
      if ((ctx.player.owned[id] || 0) <= 0 || ctx.player.sealed[id] > 0 || (ctx.player.cooldowns[id] || 0) > 0) return { ok: false };
    }
    if (ctx.player.thought < m.thoughtCost || ctx.player.qi < m.qiCost) return { ok: false };
    return { ok: true };
  }

  function runBattle(cfg) {
    const ctx = createContext(cfg);
    const history = [];
    const playerActs = (action) => {
      if (!action) return;
      if (action.type === 'gu') useGu(ctx, action.id, action.target);
      else if (action.type === 'move') useKillMove(ctx, action.id, action.target);
      else if (action.type === 'observe') observe(ctx, action.target);
      else if (action.type === 'brace') brace(ctx);
      else if (action.type === 'move_closer') moveCloser(ctx);
      else if (action.type === 'reverse') reverseBreath(ctx);
    };

    while (!ctx.result) {
      if (!startRound(ctx)) break;
      enemyPlan(ctx);
      startPlayerTurn(ctx);
      playerActs(autoplayAction(ctx));
      if (ctx.player.thought > 0) playerActs(autoplayAction(ctx));
      endPlayerTurn(ctx);
      if (!deathCheck(ctx)) break;
      enemyAct(ctx);
      if (!deathCheck(ctx)) break;
      resolveDOT(ctx);
      resolveDuration(ctx);
      if (!deathCheck(ctx)) break;
      history.push({ round: ctx.round, playerHp: ctx.player.hp, enemyHp: aliveEnemies(ctx).reduce((a, e) => a + e.hp, 0) });
      if (isStalemate(ctx, history)) {
        ctx.result = 'stalemate';
        break;
      }
    }
    if (!ctx.result) ctx.result = 'timeout';

    return {
      result: ctx.result,
      rounds: ctx.round,
      playerHp: ctx.player.hp,
      playerQi: ctx.player.qi,
      stats: {
        ...ctx.stats,
        guUsed: [...ctx.stats.guUsed],
        movesUsed: [...ctx.stats.movesUsed],
      },
      seed: ctx.battleSeed,
    };
  }

  return Object.freeze({
    qiCostFor,
    createContext,
    runBattle,
    useGu,
    useKillMove,
    observe,
    reverseBreath,
    applyDamageToEnemy,
    applyDamageToPlayer,
    deriveStreams,
    COUNTER_MITIGATION,
  });
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.VBattle;
