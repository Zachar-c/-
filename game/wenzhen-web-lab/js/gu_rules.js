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

  // P5 冰道语义（L0 裁决 A'⑥）：持有蛊的被动护甲（冰肌蛊 passive_effect.kind=armor）。
  // canon：冰肌一经练成无须真元支持——常驻承伤语法，不占回合、不是催动 effectPlan。
  // 索引缺失 + 有 guRefs → fail-fast（No Silent Fallback）；无 guRefs → 0。
  function carriedGuPassiveArmor(enemy) {
    const refs = enemy?.guRefs || [];
    if (!refs.length) return 0;
    const idx = (typeof GU_BY_ID !== 'undefined' && GU_BY_ID)
      || globalThis.MVP_GU_CONTEXT?.guById || null;
    if (!idx) throw new Error('gu_rules: enemy.guRefs 非空但缺蛊索引（No Silent Fallback）');
    let total = 0;
    for (const gid of refs) {
      const g = idx[gid];
      if (!g) throw new Error(`gu_rules: 敌人装载蛊 ${gid} 不在蛊索引（No Silent Fallback）`);
      const pe = g.passive_effect || g.passiveEffect;
      if (pe?.kind === 'armor') total += Math.max(0, Number(pe.amount || 0));
    }
    return total;
  }

  // L0 Phase 1：敌人问题轴 × 玩家解法。每个问题至少两种可辩护方案。
  // 返回修订后的 damage 与 trace notes（Gate 1 只看行为痕迹）。
  function resolveProblemHit(enemy, plan, rawDamage) {
    let damage = Math.max(0, Number(rawDamage || 0));
    const notes = [];
    const axis = String(enemy?.problemAxis || '');
    if (damage <= 0) return { damage: 0, notes };

    const guArmor = carriedGuPassiveArmor(enemy);
    if (axis === 'armor' || guArmor > 0) {
      let armor = Math.max(0, Number(enemy.armorValue || 0)) + guArmor;
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
        // RUL-2026-09-25-001 frozen_invariant「No Silent Fallback」：未知 effect verb 一律
        // fail-fast，禁止静默 no-op——Canon 新机制看似进数据实则无效是最危险的换皮形态。
        // 新增 verb 须走 Wiki/Canon rule → Game Semantic binding → Effect verb。
        throw new Error(
          `gu_rules.applyPart: unknown effect kind "${String(part?.kind)}"（No Silent Fallback，RUL-2026-09-25-001）`,
        );
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

  // ---- Phase 2：构筑角色与三套最小能力组合 ----
  // 角色：Core / Support / Transform / Resource / Defense / Information / Finisher
  const BUILD_ROLES = Object.freeze([
    'Core', 'Support', 'Transform', 'Resource', 'Defense', 'Information', 'Finisher',
  ]);

  const DEFAULT_BUILD_ROLE = Object.freeze({
    vitality_grass_gu: 'Resource',
    stone_shell_gu: 'Defense',
    jade_skin_gu: 'Defense',
    white_jade_gu: 'Defense',
    blood_droplet_gu: 'Core',
    blood_bat_gu: 'Resource',
    bear_strength_gu: 'Resource',
  });

  function buildRoleOf(guOrId, guById = {}) {
    const gu = typeof guOrId === 'string' ? (guById[guOrId] || {}) : (guOrId || {});
    const id = String(gu.id || guOrId || '');
    return String(gu.buildRole || DEFAULT_BUILD_ROLE[id] || gu.role || 'Core');
  }

  function buildTagsOf(guOrId, guById = {}) {
    const gu = typeof guOrId === 'string' ? (guById[guOrId] || {}) : (guOrId || {});
    if (Array.isArray(gu.buildTags) && gu.buildTags.length) return [...gu.buildTags];
    const effect = gu.v1_effect || gu.battleEffect || {};
    const tags = [];
    if (effect.inspect) tags.push('inspect');
    if (effect.suppress || effect.suppressWhenRevealed) tags.push('suppress');
    if (effect.armorBreak || effect.pierce) tags.push('armorBreak');
    if (effect.ignoreEvasion) tags.push('ignoreEvasion');
    if (effect.kind === 'heal' || effect.kind === 'heal_and_strike') tags.push('sustain');
    if (effect.kind === 'shield' || effect.kind === 'grant_block') tags.push('guard');
    return tags;
  }

  // 三套最小能力组合（L0 Phase 2）。成员是「能改变解法」的元件，不是纯数值。
  const BUILD_KITS = Object.freeze({
    kit_info_suppress: Object.freeze({
      id: 'kit_info_suppress',
      label: '信息→压制',
      axis: 'info',
      members: Object.freeze(['small_light_gu', 'moon_glow_gu']),
      optional: Object.freeze(['light_rec_1_10_gu', 'wisdom_rec_1_20_gu']),
      structure: Object.freeze(['inspect', 'suppress', 'strike']),
    }),
    kit_pierce_burst: Object.freeze({
      id: 'kit_pierce_burst',
      label: '破甲→爆发',
      axis: 'armor',
      members: Object.freeze(['white_boar_strength_gu', 'blood_farewell_gu']),
      optional: Object.freeze(['moon_ray_gu', 'blood_atk_5_02_gu']),
      structure: Object.freeze(['pierce', 'burst']),
    }),
    kit_stable_sustain: Object.freeze({
      id: 'kit_stable_sustain',
      label: '稳定命中→持续',
      axis: 'evasion',
      members: Object.freeze(['moonlight_gu', 'blood_droplet_gu', 'vitality_grass_gu']),
      optional: Object.freeze(['blood_bat_gu', 'bear_strength_gu']),
      structure: Object.freeze(['stable_hit', 'chip', 'sustain']),
    }),
  });

  function kitById(kitId) {
    return BUILD_KITS[kitId] || null;
  }

  function kitCoverage(kitId, owned = {}, guById = {}) {
    const kit = BUILD_KITS[kitId];
    if (!kit) return { ok: false, missing: [], present: [] };
    const present = [];
    const missing = [];
    for (const id of kit.members) {
      if (Number(owned[id] || 0) > 0) present.push(id);
      else missing.push(id);
    }
    return { ok: missing.length === 0, missing, present, kit };
  }

  // 面对某问题轴时，该构筑的有效行动结构签名（Gate 2）。
  // 同一 Build 对不同轴必须分叉；不同 Build 对同一轴也必须分叉。
  function actionStructureFor(kitId, enemyOrAxis = {}) {
    const kit = BUILD_KITS[kitId];
    if (!kit) return { signature: 'unknown', steps: [] };
    const axis = String(enemyOrAxis.problemAxis || enemyOrAxis.axis || '');
    const steps = [];
    if (kitId === 'kit_info_suppress') {
      if (axis === 'info') steps.push('inspect', 'suppress', 'controlled_strike');
      else if (axis === 'armor') steps.push('inspect', 'suppress', 'chip_strike');
      else if (axis === 'evasion') steps.push('inspect', 'suppress', 'low_stable_strike');
      else steps.push(...kit.structure);
    } else if (kitId === 'kit_pierce_burst') {
      if (axis === 'armor') steps.push('pierce', 'burst');
      else if (axis === 'evasion') steps.push('pierce', 'stable_finisher');
      else if (axis === 'info') steps.push('read_or_avoid', 'pierce', 'burst');
      else steps.push(...kit.structure);
    } else if (kitId === 'kit_stable_sustain') {
      if (axis === 'evasion') steps.push('ignoreEvasion', 'chip', 'sustain');
      else if (axis === 'armor') steps.push('chip', 'chip', 'sustain');
      else if (axis === 'info') steps.push('inspect', 'stable_hit', 'sustain');
      else steps.push(...kit.structure);
    } else {
      steps.push(...(kit.structure || []));
    }
    return {
      kitId,
      axis,
      steps,
      signature: `${kitId}|${axis}|${steps.join('>')}`,
    };
  }

  // ---- Phase 3：获得新蛊 → 构筑改变 ----
  // 同角色或同解法语义族的蛊可替换杀招组件；固定家族 + Variant，不做自由生成。
  function compatibleSubstitutes(definitionId, guById = {}) {
    const base = guById[definitionId] || {};
    const baseRole = buildRoleOf(base, guById);
    const baseTags = new Set(buildTagsOf(base, guById));
    const baseEffect = base.v1_effect || base.battleEffect || {};
    const baseKind = String(baseEffect.kind || '');
    const baseAttack = Number(baseEffect.amount || 0) > 0
      || baseKind === 'strike' || baseKind === 'heal_and_strike';
    return Object.values(guById)
      .filter((g) => {
        if (!g || g.id === definitionId) return false;
        if (!g.battleEffect && !g.v1_effect) return false;
        if (buildRoleOf(g, guById) === baseRole) return true;
        const tags = buildTagsOf(g, guById);
        if (tags.some((t) => baseTags.has(t))) return true;
        // 同效果族：攻/防/疗可互相顶位（杀招槽兼容替换）
        const eff = g.v1_effect || g.battleEffect || {};
        const kind = String(eff.kind || '');
        if (baseKind && kind && baseKind === kind) return true;
        const attack = Number(eff.amount || 0) > 0
          || kind === 'strike' || kind === 'heal_and_strike';
        if (baseAttack && attack) return true;
        return false;
      })
      .map((g) => String(g.id))
      .sort();
  }

  function killMoveVariants(move, owned = {}, guById = {}) {
    if (!move?.recipe?.length) return [];
    const slotOptions = (move.recipe || []).map((definitionId) => {
      const primary = Number(owned[definitionId] || 0) > 0 ? [String(definitionId)] : [];
      const alts = compatibleSubstitutes(definitionId, guById)
        .filter((id) => Number(owned[id] || 0) > 0);
      // 主件优先；替代仅在主件缺失或显式列出时进入 Variant
      const list = primary.length ? [String(definitionId), ...alts.filter((id) => id !== definitionId)] : alts;
      return list.length ? list : [String(definitionId)];
    });
    const variants = [];
    const walk = (index, recipe) => {
      if (index >= slotOptions.length) {
        const plan = killMoveEffectPlan({ ...move, recipe }, guById, {});
        const changed = recipe.join('+') !== (move.recipe || []).join('+');
        variants.push({
          moveId: move.id,
          label: move.label,
          recipe: [...recipe],
          changed,
          plan,
          signature: `dmg${plan.damage}|heal${plan.heal}|blk${plan.block}|ab${plan.armorBreak || 0}|ev${plan.ignoreEvasion ? 1 : 0}|in${plan.inspect ? 1 : 0}|su${plan.suppressCounter ? 1 : 0}`,
        });
        return;
      }
      for (const id of slotOptions[index]) walk(index + 1, [...recipe, id]);
    };
    walk(0, []);
    return variants;
  }

  function killMoveVariantByRecipe(move, recipe, guById = {}, context = {}) {
    return killMoveEffectPlan({ ...move, recipe: [...recipe] }, guById, context);
  }

  // ---- Phase 4：最小炼蛊分支网络 ----
  // 同投入多去向 = 真分支；炼一支必须关闭/推迟另一未来。
  const forkInputKey = (recipe) => [...(recipe.inputs || [])].map(String).sort().join('+');

  function forkGroups(recipes = []) {
    const groups = new Map();
    for (const r of liveRecipes(recipes)) {
      const key = r.forkId || forkInputKey(r);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(r);
    }
    return [...groups.entries()]
      .filter(([, list]) => list.length >= 2)
      .map(([forkId, branches]) => ({
        forkId,
        inputs: [...(branches[0].inputs || [])],
        branches: branches.map((b) => ({
          id: b.id,
          output: b.output,
          branchLabel: b.branchLabel || b.output,
          branchAxis: b.branchAxis || null,
          closes: [...(b.closes || [])],
          delays: [...(b.delays || [])],
          stoneCost: Number(b.stoneCost || 0),
        })),
      }));
  }

  function isStrictlyDominatedRecipe(recipe, all = []) {
    return all.some((o) => {
      if (!o || o === recipe || o.output !== recipe.output) return false;
      if (o.retired || recipe.retired) return false;
      const oIn = (o.inputs || []).map(String);
      const rIn = (recipe.inputs || []).map(String);
      if (!rIn.every((id) => oIn.includes(id))) return false;
      if (Number(o.stoneCost || 0) > Number(recipe.stoneCost || 0)) return false;
      const cheaper = oIn.length < rIn.length
        || Number(o.stoneCost || 0) < Number(recipe.stoneCost || 0);
      return cheaper;
    });
  }

  // 炼成某支后的未来：打开什么、关闭/推迟什么（Gate 4）。
  function branchFutures(recipe, options = {}) {
    const { guById = {}, killMoves = [], owned = {} } = options;
    const opens = [];
    const closes = [...(recipe.closes || [])];
    const delays = [...(recipe.delays || [])];
    const output = String(recipe.output || '');
    if (guById[output]) {
      opens.push({ kind: 'gu', id: output, name: guById[output].name || output });
    }
    for (const kit of Object.values(BUILD_KITS)) {
      if (kit.members.includes(output) || (kit.optional || []).includes(output)) {
        opens.push({ kind: 'kit', id: kit.id, label: kit.label });
      }
    }
    for (const move of killMoves || []) {
      if ((move.recipe || []).includes(output)) {
        opens.push({ kind: 'killmove', id: move.id, label: move.label });
      }
    }
    // 投入被吃掉 → 相关组合/杀招被推迟
    for (const inputId of recipe.inputs || []) {
      if (Number(owned[inputId] || 0) <= 1) {
        for (const kit of Object.values(BUILD_KITS)) {
          if (kit.members.includes(inputId) && !delays.includes(kit.id)) delays.push(kit.id);
        }
      }
    }
    return {
      recipeId: recipe.id,
      output,
      branchLabel: recipe.branchLabel || output,
      branchAxis: recipe.branchAxis || null,
      opens,
      closes: [...new Set(closes)],
      delays: [...new Set(delays)],
    };
  }

  // Gate 4：同一初始资产下，炼 A 与炼 B 的差异签名。
  function forgeBranchSignatures(forkId, recipes = [], options = {}) {
    const group = forkGroups(recipes).find((g) => g.forkId === forkId);
    if (!group) return [];
    return group.branches.map((b) => {
      const recipe = liveRecipes(recipes).find((r) => r.id === b.id) || b;
      const futures = branchFutures(recipe, options);
      const afterOwned = { ...(options.owned || {}) };
      for (const inputId of recipe.inputs || []) {
        afterOwned[inputId] = Math.max(0, Number(afterOwned[inputId] || 0) - 1);
      }
      afterOwned[recipe.output] = Number(afterOwned[recipe.output] || 0) + 1;
      const kits = Object.values(BUILD_KITS).map((k) => kitCoverage(k.id, afterOwned, options.guById || {}));
      const signature = [
        `out:${recipe.output}`,
        `axis:${recipe.branchAxis || '-'}`,
        `close:${futures.closes.join(',') || '-'}`,
        `kit:${kits.map((c, i) => (c.ok ? Object.values(BUILD_KITS)[i].id : '')).filter(Boolean).join(',') || '-'}`,
        `open:${futures.opens.map((o) => o.id).join(',')}`,
      ].join('|');
      return { branchId: b.id, output: recipe.output, signature, futures, afterOwned };
    });
  }

  // 获得新蛊后的构筑关联：可替换 / 可炼 / 可组杀招 / 可进哪套组合。
  function gainInsight(guId, options = {}) {
    const {
      owned = {}, recipes = [], killMoves = [], guById = {},
    } = options;
    const id = String(guId || '');
    const gu = guById[id] || {};
    const role = buildRoleOf(gu, guById);
    const tags = buildTagsOf(gu, guById);
    const substitutes = compatibleSubstitutes(id, guById)
      .filter((sid) => Number(owned[sid] || 0) > 0)
      .map((sid) => ({
        id: sid,
        name: (guById[sid] || {}).name || sid,
        role: buildRoleOf(sid, guById),
      }));

    const refineInto = (recipes || [])
      .filter((r) => isLiveRecipe(r) && (r.inputs || []).includes(id))
      .map((r) => ({
        id: r.id,
        output: r.output,
        outputName: (guById[r.output] || {}).name || r.output,
        inputs: [...(r.inputs || [])],
      }));

    const killMoveForms = [];
    for (const move of killMoves || []) {
      const slots = move.recipe || [];
      const usesDirectly = slots.includes(id);
      const fillsGap = slots.some((sid) => Number(owned[sid] || 0) <= 0
        && compatibleSubstitutes(sid, guById).includes(id));
      const variants = killMoveVariants(move, { ...owned, [id]: (Number(owned[id] || 0) + 1) }, guById);
      const changedVariants = variants.filter((v) => v.changed);
      if (usesDirectly || fillsGap || changedVariants.length) {
        const basePlan = killMoveEffectPlan(move, guById, {});
        const bestChanged = changedVariants[0] || null;
        killMoveForms.push({
          moveId: move.id,
          label: move.label,
          usesDirectly,
          fillsGap,
          canForm: variants.some((v) => v.recipe.every((rid) => Number({ ...owned, [id]: 1 }[rid] || 0) > 0)),
          baseSignature: `dmg${basePlan.damage}|heal${basePlan.heal}|blk${basePlan.block}`,
          variantSignature: bestChanged ? bestChanged.signature : null,
          variantRecipe: bestChanged ? bestChanged.recipe : null,
          changesPattern: !!(bestChanged && bestChanged.signature !== `dmg${basePlan.damage}|heal${basePlan.heal}|blk${basePlan.block}`),
        });
      }
    }

    const kitJoins = [];
    const ownedBefore = { ...owned };
    const beforeCount = Math.max(0, Number(owned[id] || 0) - 1);
    if (beforeCount > 0) ownedBefore[id] = beforeCount;
    else delete ownedBefore[id];
    for (const kit of Object.values(BUILD_KITS)) {
      const direct = kit.members.includes(id) || (kit.optional || []).includes(id);
      const coversGap = kit.members.some((mid) => Number(ownedBefore[mid] || 0) <= 0
        && (mid === id || compatibleSubstitutes(mid, guById).includes(id)));
      if (direct || coversGap) {
        // 用「获得之后」的库存对照「获得之前」，判断是否刚好补完
        const after = kitCoverage(kit.id, owned, guById);
        const before = kitCoverage(kit.id, ownedBefore, guById);
        kitJoins.push({
          kitId: kit.id,
          label: kit.label,
          axis: kit.axis,
          direct,
          coversGap,
          completes: !!after.ok && !before.ok,
          stillMissing: after.missing,
        });
      }
    }

    const decisions = [];
    if (substitutes.length) {
      decisions.push({
        kind: 'replace',
        label: '替换旧元件',
        detail: `可换下：${substitutes.map((s) => s.name).join('、')}`,
      });
    }
    if (refineInto.length) {
      decisions.push({
        kind: 'forge',
        label: '进入炼蛊',
        detail: `可炼成：${refineInto.map((r) => r.outputName).join('、')}`,
      });
    }
    if (killMoveForms.some((k) => k.usesDirectly || k.fillsGap || k.changesPattern)) {
      decisions.push({
        kind: 'killmove',
        label: '进入杀招',
        detail: `可组成/改变：${killMoveForms.map((k) => k.label).join('、')}`,
      });
    }
    if (kitJoins.length) {
      decisions.push({
        kind: 'kit',
        label: '进入组合',
        detail: `推进：${kitJoins.map((k) => k.label).join('、')}`,
      });
    }
    decisions.push({
      kind: 'keep',
      label: '保留库存',
      detail: '暂不重构，维持旧 Build',
    });
    if (Number(gu.value || 0) > 0) {
      decisions.push({
        kind: 'sell',
        label: '出售',
        detail: `可变现 ${Math.floor(Number(gu.value || 0) * 0.5)} 元石`,
      });
    }

    const realKinds = new Set(decisions.map((d) => d.kind).filter((k) => k !== 'keep' && k !== 'sell'));
    return {
      guId: id,
      name: gu.name || id,
      role,
      tags,
      substitutes,
      refineInto,
      killMoveForms,
      kitJoins,
      decisions,
      hasRealDecision: realKinds.size > 0 || substitutes.length > 0 || killMoveForms.length > 0,
    };
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
    carriedGuPassiveArmor,
    addVerbs,
    BUILD_ROLES,
    BUILD_KITS,
    buildRoleOf,
    buildTagsOf,
    kitById,
    kitCoverage,
    actionStructureFor,
    compatibleSubstitutes,
    killMoveVariants,
    killMoveVariantByRecipe,
    gainInsight,
    forkGroups,
    isStrictlyDominatedRecipe,
    branchFutures,
    forgeBranchSignatures,
  });
})();
