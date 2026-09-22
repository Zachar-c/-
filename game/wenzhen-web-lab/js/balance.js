/* 《问真》10 分钟原型 · 数值工程校验工具 v1
 *
 * 身份（L0 2026-09-21 纠偏令 + L1 兼容裁决）：
 *   **数值工程校验工具**——报警器，不是法律。
 *   不是 P3 Effect 定价规范，不是「这只蛊值多少」的裁判。
 *   上位公理：docs/ORIGINAL_POWER_SYSTEM_AXIOMS.md
 *   偏移审计：docs/power-system-shift-audit.md
 *
 * Rank 真源（Integration 刀1 · EXISTING_CAPABILITY_MAP）：
 *   WORLD = game/data/balance.json（rank_power_budget / rank_step_ratio /
 *           human_base_health / thought_base_capacity / stone_to_essence_per_stone）
 *   运行时访问点 = scripts/domain/gu_balance.gd
 *   本文件只做 LAB 投影，禁止再发明第三套 Rank。
 *   Node 工具须先设 globalThis.WORLD_BALANCE = balance.json；
 *   未注入时使用 FALLBACK，并由 tools/check_balance.mjs 断言与 JSON 一致。
 *
 * 本工具负责发现：异常超模 / 明显低模 / 无限资源 / 不合理 DPR /
 *   敌人数学错误 / 战斗时长与资源曲线异常。
 * 本工具不负责决定：是否优秀、是否该选、是否该淘汰、是否与同转「公平」。
 * 禁止：「超过同转预算 → 必须削弱」。须再问品质、条件、资源、杀招依赖与路线竞争。
 *
 * 两个 scope，各自单一真源（禁止「双真源」、禁止隐式双向同步）：
 *   WORLD: game/data/balance.json     → 正式世界量纲
 *   LAB:   game/wenzhen-web-lab/js/balance.js → 10 分钟验证量纲
 * 只允许 WORLD --projection--> LAB。
 *
 * LAB_BUDGET_PROJECTION = 20
 *   labBudget(rank) = rankPowerBudget(rank) / LAB_BUDGET_PROJECTION
 *   40/80/160/320/640 → 2/4/8/16/32
 *   20× 是投影比例，**不是**最终 Effect→amount 公式。
 *   允许 lab 内：1 PP ≈ 1 lab damage。禁止写成「1 PP = 1 damage（全仓）」。
 *
 * LAB_PRICING_V1（检测用相对尺，非正式定价/税法）：
 *   PP: damage 1 / block 1.2 / heal 1.5 / inspect 1.5 / support 1.2 / suppress 2.5
 *   costTax = 1 + qi×0.15 + hp×0.25 + (thought-1)×0.20 + cooldown×0.10
 *
 * LAB 分层常量（有意 ≠ 全仓；逆息/胜利回复/炼耗 = lab 阀门，非 world 规则）：
 *   thoughtsPerTurn=2（全仓 thought_base_capacity=3）· 1石→2 Qi（全仓 stone_to_essence_per_stone=5）
 *   playerHp=24（全仓 human_base_health=100）——一律 PROJECTION，禁止修齐。
 *
 * 双层门禁：kitDpr=静态估算；autoplay=真实验收。不造第二套战斗模拟。
 * counterZeroRate 仅 lab 遭遇估算，非通用战斗规则。
 * MVP 蛊（月光/小光/月芒/白豕）= 10 分钟实验组合，禁止反推全库定价模板。
 */
globalThis.MvpBalance = (() => {
  /* WORLD → LAB 显式投影。改这里等于改投影，不是改全仓预算。 */
  const LAB_BUDGET_PROJECTION = 20;

  /* Rank 真源：优先 WORLD_BALANCE（game/data/balance.json）；否则冻结快照。 */
  const WORLD_FALLBACK = Object.freeze({
    rank_step_ratio: 2,
    standard_hit_ratio: 0.2,
    human_base_health: 100,
    standard_human_hp: 100,
    player_start_hp: 100,
    thought_base_capacity: 3,
    stone_to_essence_per_stone: 5,
    rank_power_budget: Object.freeze({
      rank1_budget: 40,
      budget_by_rank: Object.freeze({ 1: 40, 2: 80, 3: 160, 4: 320, 5: 640 }),
    }),
  });
  const WORLD = Object.freeze({ ...WORLD_FALLBACK, ...(globalThis.WORLD_BALANCE || {}) });

  function worldRankBudget(rank) {
    const table = WORLD.rank_power_budget?.budget_by_rank || WORLD_FALLBACK.rank_power_budget.budget_by_rank;
    return Number(table[String(rank)] ?? table[rank] ?? WORLD_FALLBACK.rank_power_budget.rank1_budget);
  }

  function worldRankMultiplier(rank) {
    const step = Number(WORLD.rank_step_ratio || 2);
    return Math.pow(step, Math.max(1, Number(rank || 1)) - 1);
  }

  /* Rank 纵轴 · cross_rank_cost_curve（RUL-010 q5）：独立曲线，禁止 rank_multiplier。
     0.65^(playerRank-guRank)，最低 1 Qi；guRank>playerRank → null（不可催动）。 */
  function crossRankQiCost(baseQi, playerRank, guRank) {
    const p = Number(playerRank || 1);
    const g = Number(guRank || 1);
    if (g > p) return null;
    return Math.max(1, Math.round(Number(baseQi || 0) * Math.pow(0.65, p - g)));
  }

  /* killer_move complexity_points：stable cap 规格位；affects_player=false（未限用） */
  function complexityPoints(km) {
    const recipe = Array.isArray(km?.recipe) ? km.recipe.length : 0;
    const thought = Number(km?.thought_cost || 1);
    const effectSlots = Array.isArray(km?.effect) ? km.effect.length : 1;
    return recipe * 1 + Math.max(0, thought - 1) * 2 + effectSlots;
  }

  const LAB = Object.freeze({
    thoughtsPerTurn: 2, // PROJECTION of thought_base_capacity=3
    playerHp: 24, // PROJECTION of human_base_health=100
    playerQi: 12,
    LAB_EXCHANGE_RATE: Object.freeze({ stones: 1, qi: 2 }), // PROJECTION of stone_to_essence_per_stone=5
    LAB_BUDGET_PROJECTION,
    world: WORLD,
    fullGame: Object.freeze({
      humanHp: Number(WORLD.human_base_health || 100),
      rank1PowerBudget: Number(WORLD.rank_power_budget?.rank1_budget || 40),
      thoughtBaseCapacity: Number(WORLD.thought_base_capacity || 3),
      stoneToEssence: Number(WORLD.stone_to_essence_per_stone || 5),
      labToFullHp: 24 / Number(WORLD.human_base_health || 100),
      note: '只允许 projection 到 LAB；禁止 LAB 回写 WORLD',
    }),
  });

  /* ---------------- 效果 → 预算点（Power Point, PP） ----------------
     LAB_PRICING_V1。1 PP ≈ 1 lab damage。禁止写成「1 PP = 1 damage（全仓）」。
     suppress 必须保持昂贵，防止「改规则」变成纯收益选项。 */
  const PP = Object.freeze({
    damage: 1,
    block: 1.2,
    heal: 1.5,
    inspect: 1.5,
    support: 1.2,
    suppress: 2.5,
  });
  const PRICING_ID = 'LAB_PRICING_V1';

  function isDamageAction(action) {
    return Number(action?.damage || 0) > 0 || Number(action?.woundedDamage || 0) > 0;
  }

  /* 全仓同形术语（L1 P2-A4）：rankMultiplier(rank) = rank_step_ratio^(rank-1)。
     与 GuBalance.rank_multiplier 同义（读 WORLD.balance.json）；
     预算 = rankPowerBudget(rank) / LAB_BUDGET_PROJECTION。 */
  function rankMultiplier(rank) {
    return worldRankMultiplier(rank);
  }

  /* 实战期望伤害（wounded/support 半程）——**只**给 kitDpr / encounter 估算用。
     禁止进入 priceGu 基础定价（L1 P1-E4）：本体价格只回答「这只蛊本身值多少」。 */
  function expectedDamagePerUse(action) {
    const base = Number(action.damage || 0);
    const wounded = Number(action.woundedDamage || 0);
    if (wounded > base) return base + (wounded - base) * 0.5;
    if (action.supportedDamage) {
      return base + (Number(action.supportedDamage) - base) * 0.5;
    }
    return base;
  }

  /* 本体效果预算：用 base 伤，不用 wounded/support 期望。 */
  function guBudget(action) {
    if (!action) return { total: 0, breakdown: {} };
    const dmg = Number(action.damage || 0);
    const breakdown = {
      damage: dmg * PP.damage,
      block: Number(action.block || 0) * PP.block,
      heal: Number(action.heal || 0) * PP.heal,
      inspect: action.inspect ? PP.inspect : 0,
      support: action.support ? PP.support : 0,
      suppress: action.suppressWhenRevealed ? PP.suppress : 0,
    };
    const total = Object.values(breakdown).reduce((a, b) => a + b, 0);
    return { total, breakdown, baseDamage: dmg, pricingId: PRICING_ID };
  }

  /* LAB_PRICING_V1 costTax。与 light_cost_ratio 不强行换算。 */
  function costTax(action) {
    return 1
      + Number(action.qi || 0) * 0.15
      + Number(action.hp || 0) * 0.25
      + Math.max(0, Number(action.thought || 1) - 1) * 0.2
      + Number(action.cooldown || 0) * 0.1;
  }

  /* ---------------- 行动经济 → 期望 DPR ----------------
     kitDpr v1 身份（L1 P1-F3）：**静态预算估算器，不是战斗真相模拟器**。
     实战可玩性以 autoplay 为准。不要造第二套战斗模拟。
     用 expectedDamagePerUse（含 wounded/support 期望）——这是 encounter 估算，
     不是本体定价（见 P1-E4）。 */
  function instanceUsesPerTurn(action, count) {
    const cycle = 1 + Number(action.cooldown || 0);
    return Math.min(Number(count || 0), Number(count || 0) / cycle);
  }

  function kitDpr(owned, actions, options = {}) {
    const thoughts = Number(options.thoughts ?? LAB.thoughtsPerTurn);
    const entries = [];
    for (const [id, count] of Object.entries(owned || {})) {
      const action = actions?.[id];
      if (!action || !isDamageAction(action)) continue;
      const n = Number(count || 0);
      if (n <= 0) continue;
      const dmg = expectedDamagePerUse(action);
      const cycle = 1 + Number(action.cooldown || 0);
      const th = Math.max(1, Number(action.thought || 1));
      /* 每实例每回合期望出手 = 1/cycle；再受念头约束 */
      const rawUses = n / cycle;
      const dmgPerThought = dmg / th;
      entries.push({ id, n, dmg, cycle, th, rawUses, dmgPerThought });
    }
    entries.sort((a, b) => b.dmgPerThought - a.dmgPerThought);

    let thoughtsLeft = thoughts;
    let dpr = 0;
    const plan = [];
    for (const e of entries) {
      const want = e.rawUses;
      const afford = thoughtsLeft / e.th;
      const uses = Math.min(want, afford);
      if (uses <= 0) continue;
      thoughtsLeft -= uses * e.th;
      const contrib = uses * e.dmg;
      dpr += contrib;
      plan.push({ id: e.id, usesPerTurn: uses, contrib });
    }
    return {
      dpr,
      plan,
      thoughtPressure: thoughts - thoughtsLeft,
      note: 'throughput；不含逆息、不含一回合双爆发',
    };
  }

  /* ---------------- 反制税：回合里打不出伤害的比例 ----------------
     仅 lab 遭遇估算参数（L1 G 组）——不是通用战斗规则。
     迎击吞的是直接攻击，不是整个玩家回合（仍可观察/辅助/防御/逆息）。
     禁止让 Godot 全仓采用「intercept = 1.0 零输出回合」这种静态结论。 */
  function counterZeroRate(sequence, options = {}) {
    const hasSuppress = !!options.hasSuppress;
    const weight = (c) => {
      if (c === 'none') return 0;
      if (c === 'intercept' || c === 'iron') return hasSuppress ? 0.25 : 1;
      return 0;
    };
    const list = sequence || [];
    if (!list.length) return 0;
    let zeros = 0;
    for (const slot of list) {
      const c = !slot || slot === 'none' ? 'none' : String(slot);
      zeros += weight(c);
    }
    return zeros / list.length;
  }

  /* ---------------- 遭遇推导（L1 P0-H1 口径） ----------------
     禁止的是「无预算依据的手写 HP」，不是「手写 HP 本身」。
     每个遭遇必须：
       1. 有 deriveEnemyHp() 基准值；
       2. 手写值必须经过 checkEncounter；
       3. 偏离推导值 >20% 必须写 override_reason；
       4. 最终还必须过真实战斗/autoplay。
     公式给预算基线；设计者允许在预算附近调节。
     「公式算出 15」是建议，不是神谕。 */
  const OVERRIDE_THRESHOLD = 0.2;

  function deriveEnemyHp({ dpr, targetTurns, zeroRate = 0, margin = 1, minHp = 1 }) {
    const t = Number(targetTurns);
    const effective = Math.max(0.5, t * (1 - Number(zeroRate || 0)));
    const raw = Number(dpr) * effective * Number(margin || 1);
    return Math.max(minHp, Math.round(raw));
  }

  function achievableTurns({ dpr, enemyHp, zeroRate = 0 }) {
    const effDpr = Number(dpr) * (1 - Number(zeroRate || 0));
    if (effDpr <= 0) return Infinity;
    return Number(enemyHp) / effDpr;
  }

  /* 威胁预算（L1 P1-H2 冻结 v1）：
     handleRate = 0.35（全遭遇一致）
     survivalRate 按等级：猎犬 0.20 / 山猪 0.25 / 悍客 0.30 / 狼王 0.35
     不要上 0.40——跨战 HP 持久，Boss 高存活率会与前三战累计损耗双重惩罚。 */
  const THREAT_V1 = Object.freeze({
    handleRate: 0.35,
    survivalRateByTier: Object.freeze({
      hound: 0.2,
      common: 0.25,
      elite: 0.3,
      boss: 0.35,
    }),
  });

  function deriveEnemyDamagePerTurn({
    playerHp,
    targetTurns,
    survivalRate = 0.35,
    handleRate = THREAT_V1.handleRate,
  }) {
    const totalTaken = Number(playerHp) * (1 - Number(survivalRate || 0));
    const effective = Math.max(0.5, Number(targetTurns) * (1 - Number(handleRate || 0)));
    return totalTaken / effective;
  }

  /* 校验 + H1 override 门。 */
  function checkEncounter({
    name,
    dpr,
    enemyHp,
    turnWindow,
    zeroRate = 0,
    margin = 1.08,
    targetTurns = null,
    overrideReason = '',
  }) {
    const [lo, hi] = turnWindow;
    const turns = achievableTurns({ dpr, enemyHp, zeroRate });
    const okWindow = turns + 1e-9 >= lo && turns <= hi + 1e-9;
    const mid = targetTurns != null ? targetTurns : (lo + hi) / 2;
    const recommended = deriveEnemyHp({ dpr, targetTurns: mid, zeroRate, margin, minHp: 4 });
    const deviation = recommended > 0 ? Math.abs(enemyHp - recommended) / recommended : 0;
    const needsOverride = deviation > OVERRIDE_THRESHOLD;
    const overrideOk = !needsOverride || String(overrideReason || '').trim().length > 0;
    return {
      name,
      ok: okWindow && overrideOk,
      windowOk: okWindow,
      overrideOk,
      needsOverride,
      deviation,
      overrideReason: String(overrideReason || ''),
      achievableTurns: turns,
      turnWindow,
      enemyHp,
      recommendedHp: recommended,
      dpr,
      zeroRate,
      slack: turns <= hi ? turns - lo : turns - hi,
    };
  }

  /* ---------------- 规模化：蛊工厂（检测用，不是价值裁判） ----------------
     只回答「基础效果量级是否异常」。
     禁止输出「最终价值 / 是否该选 / 是否该淘汰 / 同转是否公平」。
     品质差、构筑价值、环境价值见公理 2——不进本函数。
     【刀5 Economy】市价/回收/估值 OWNER = scripts/domain/market_rules.gd
       + balance.json（stone_per_t1_material / public_buyback_ratio / demand_price_tiers）。
       本 priceGu 只是 lab 预算→效果量的检测投影，**不是**市场定价，禁止当商店价。
     budget = rankPowerBudget / LAB_BUDGET_PROJECTION；定价用 base 伤（P1-E4）。 */
  function priceGu({ rank = 1, role = 'attack', archetype = 'strike', thought = 1, qi = 0, hp = 0, cooldown = 0, modifier = {} }) {
    const budget = worldRankBudget(rank) / LAB_BUDGET_PROJECTION;
    const tax = 1 + qi * 0.15 + hp * 0.25 + Math.max(0, thought - 1) * 0.2 + cooldown * 0.1;
    const spendable = budget * tax;
    const out = {
      rank,
      role,
      archetype,
      budget,
      tax,
      spendable,
      thought,
      qi,
      hp,
      cooldown,
      pricingId: PRICING_ID,
      labBudgetProjection: LAB_BUDGET_PROJECTION,
      ...modifier,
    };

    if (archetype === 'strike') {
      out.damage = Math.max(1, Math.round(spendable * 0.7));
      if (modifier.supportedDamage == null && modifier.light) out.supportedDamage = out.damage + 1;
      if (modifier.woundedDamage == null && modifier.breaksCounterWhenWounded) out.woundedDamage = out.damage + 3;
    } else if (archetype === 'shield') {
      out.block = Math.max(1, Math.round(spendable / PP.block));
    } else if (archetype === 'heal') {
      out.heal = Math.max(1, Math.round(spendable / PP.heal));
    } else if (archetype === 'inspect') {
      out.inspect = true;
    } else if (archetype === 'support') {
      out.support = true;
    } else if (archetype === 'utility') {
      out.utilityPoints = spendable;
    }
    return Object.freeze(out);
  }

  const api = Object.freeze({
    LAB,
    PP,
    PRICING_ID,
    THREAT_V1,
    OVERRIDE_THRESHOLD,
    LAB_BUDGET_PROJECTION,
    WORLD,
    worldRankBudget,
    worldRankMultiplier,
    crossRankQiCost,
    complexityPoints,
    rankMultiplier,
    isDamageAction,
    expectedDamagePerUse,
    guBudget,
    costTax,
    kitDpr,
    counterZeroRate,
    deriveEnemyHp,
    deriveEnemyDamagePerTurn,
    achievableTurns,
    checkEncounter,
    priceGu,
  });
  return api;
})();

if (typeof module !== 'undefined' && module.exports) module.exports = globalThis.MvpBalance;
