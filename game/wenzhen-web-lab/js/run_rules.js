// Domain-aligned pure rules shared by the Web lab. Values and formulas mirror
// the Godot scripts noted beside each function.
globalThis.RunRules = (() => {
  const ceilPct = (value, percent) => Math.ceil((Number(value) * Number(percent)) / 100);

  // L1 HumanBaseline V1：念头是每场复杂行动预算，行动槽固定每回合一格。
  const actionPointsPerTurn = () => 1;

  // v1_battle_resolver.gd::_ceil_pct / start()
  const battleRegen = (trueQiMax, percent) => ceilPct(trueQiMax, percent);

  // school_rules.gd::sword_intent / add_sword_intent / decay_sword_intent
  const swordIntentCap = 5;
  const addSwordIntent = (current, amount) =>
    Math.max(0, Math.min(swordIntentCap, Number(current || 0) + Number(amount || 0)));
  const decaySwordIntent = (current) => Math.floor(Math.max(0, Number(current || 0)) / 2);

  // v1_battle_resolver.gd::_settle_marks
  const markScratchDamage = (layers, perLayer = 1, cap = 10) =>
    Math.min(Math.max(0, Number(layers || 0)), Math.max(0, Number(cap || 0)))
    * Math.max(0, Number(perLayer || 0));

  // v1_battle_resolver.gd::_resolve_enemy_intent (soul_drain / _check_player_death)
  const drainSoul = (current, amount) =>
    Math.max(0, Math.floor(Number(current || 0)) - Math.max(0, Math.floor(Number(amount || 0))));
  const soulDefeated = (soul) => Number(soul) <= 0;

  // v1_battle_resolver.gd::_spend_costs / _resolve_enemy_intent / _check_player_death
  const spendLife = (current, amount) =>
    Math.max(0, Math.floor(Number(current || 0)) - Math.max(0, Math.floor(Number(amount || 0))));
  const lifeDefeated = (lifeTime) => Number(lifeTime) <= 0;

  // v1_battle_resolver.gd::_resolve_enemy_intent (weaken_intent)
  const weakenedDamage = (damage, weaken) =>
    Math.max(0, Math.floor(Number(damage || 0)) - Math.max(0, Math.floor(Number(weaken || 0))));

  // v1_battle_resolver.gd::_apply_effect / _fire_delayed_effects
  const delayDueTurn = (turn, turns) =>
    Math.max(1, Math.floor(Number(turn || 1))) + Math.max(1, Math.floor(Number(turns || 0)));

  // rest_rules.gd::_rest_heal
  function restHeal({ health, maxHealth, essence, essenceMax }) {
    return {
      health: Math.min(maxHealth, health + Math.max(1, Math.floor(maxHealth * 0.30))),
      essence: Math.min(essenceMax, essence + 2),
    };
  }

  // seeded_roll.gd + rng.gd — Web 侧唯一确定性随机入口（与 Godot 同 seed 同结果）。
  // 禁止在 shop/mvp/loot 等处再写 saltHash/LCG 副本；不引入 seedrandom 等会改序列的库。
  function saltHash(salt) {
    let digest = 0;
    for (const character of String(salt)) {
      digest = digest * 31 + character.charCodeAt(0);
    }
    return digest;
  }

  function mixedSeed(seed, salt) {
    let state = Math.abs((Number(seed) * 1000003) + saltHash(salt)) % 2147483647;
    if (state === 0) state = 1;
    return state;
  }

  function seededIndex(bound, seed, salt, tick) {
    if (bound <= 1) return 0;
    let state = mixedSeed(seed, salt);
    for (let i = 0; i < Math.max(Number(tick) || 0, 0); i += 1) {
      state = (state * 48271) % 2147483647;
    }
    state = (state * 48271) % 2147483647;
    return state % bound;
  }

  // shop_command_rules.gd::_shop_shuffle — Fisher-Yates on the SeededRng stream.
  function seededShuffle(seed, salt, items) {
    const shuffled = [...(items || [])];
    let state = mixedSeed(seed, salt);
    for (let i = shuffled.length - 1; i > 0; i -= 1) {
      state = (state * 48271) % 2147483647;
      const j = state % (i + 1);
      const held = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = held;
    }
    return shuffled;
  }

  // refine_command_rules.gd::_refinement_roll
  const refinementRoll = (seed, recipeId, tick) => seededIndex(100, seed, recipeId, tick) + 1;

  // refine_command_rules.gd::_apply_fixed_recipe
  const refinementSucceeds = (roll, recipe) => roll <= (recipe.successRollMax ?? 100);

  // loot_resolver.gd::_stone_reward
  function resolveBattleTier(enemies) {
    const tiers = new Set((enemies || []).map((enemy) => enemy.tier || 'common'));
    if (tiers.has('boss')) return 'boss';
    if (tiers.has('elite')) return 'elite';
    return 'common';
  }

  function battleStoneReward(tier, layer, config) {
    const base = Number(config.base_by_tier?.[tier] || 0);
    if (base <= 0) return 0;
    const stepPct = Number(config.layer_step_pct || 0);
    return base + Math.trunc((base * stepPct * (Math.max(1, layer) - 1)) / 100);
  }

  // L1 HumanBaseline V1：以转数表加资质小幅修正，废除旧乘法膨胀。
  const rankEssence = Object.freeze([0, 6, 8, 10, 12, 14]);
  const rankRegen = Object.freeze([0, 2, 2, 3, 3, 4]);
  const aptitudeOffset = Object.freeze({ ding: -1, bing: 0, yi: 1, jia: 2, neutral: 0 });
  function essenceMax(rank, aptitude, _legacyData, guModifier = 0) {
    const level = Math.max(1, Math.min(5, Math.floor(Number(rank) || 1)));
    return rankEssence[level] + (aptitudeOffset[aptitude] || 0) + Number(guModifier || 0);
  }
  function essenceRegen(rank, guModifier = 0) {
    const level = Math.max(1, Math.min(5, Math.floor(Number(rank) || 1)));
    return rankRegen[level] + Number(guModifier || 0);
  }

  // refine_command_rules.gd::_breakthrough
  function nextBreakthrough(currentRank, stones, costs) {
    const current = Math.max(1, Number(currentRank) || 1);
    if (current >= 5) return { ok: false, reason: 'cultivation_already_max' };
    const targetRank = current + 1;
    const cost = Number(costs?.[targetRank] || 0);
    if (stones < cost) return { ok: false, reason: 'insufficient_stone', targetRank, cost };
    return { ok: true, targetRank, cost };
  }

  return Object.freeze({
    ceilPct,
    actionPointsPerTurn,
    battleRegen,
    swordIntentCap,
    addSwordIntent,
    decaySwordIntent,
    markScratchDamage,
    drainSoul,
    soulDefeated,
    spendLife,
    lifeDefeated,
    weakenedDamage,
    delayDueTurn,
    restHeal,
    saltHash,
    mixedSeed,
    seededIndex,
    seededShuffle,
    refinementRoll,
    refinementSucceeds,
    resolveBattleTier,
    battleStoneReward,
    essenceMax,
    essenceRegen,
    nextBreakthrough,
  });
})();
