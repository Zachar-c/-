// Domain-aligned pure rules shared by the Web lab. Values and formulas mirror
// the Godot scripts noted beside each function.
globalThis.RunRules = (() => {
  const ceilPct = (value, percent) => Math.ceil((Number(value) * Number(percent)) / 100);

  // action_points.gd::per_turn
  function actionPointsPerTurn(soul) {
    const value = Number(soul || 0);
    for (const [threshold, points] of [[10000, 6], [1000, 5], [100, 4], [10, 3]]) {
      if (value >= threshold) return points;
    }
    return 2;
  }

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

  // essence_capacity.gd::essence_max_for
  function essenceMax(rank, aptitude, data) {
    const cultivation = Math.max(1, Number(rank) || 1);
    const base = Number(data.essenceBase || 10);
    const aptitudeFactor = Number(data.aptitudeFactor?.[aptitude] || 1);
    const cultivationFactor = Number(data.cultivationFactor?.[cultivation] || 1);
    return base * aptitudeFactor * cultivationFactor;
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
    nextBreakthrough,
  });
})();
