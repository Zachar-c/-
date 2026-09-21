// 状态与主循环。普通脚本：全局 state / act；判定走 rules.js / run_rules.js，面板来自 alchemy.js / killmove.js / battle.js。

const READY = {
  seed: DATA.runSeed ?? 1,
  cultivation: 1,
  cultivationStage: 0,
  school: DATA.loot.school,
  stones: 3, blood: 24, bloodMax: 24,
  lifeTime: 60,
  soul: 1, soulMax: 4,
  aptitude: 'bing', stage: 'one',
  owned: {
    moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_grass_gu: 1,
    jade_skin_gu: 1, white_boar_strength_gu: 1, blood_farewell_gu: 1, blood_droplet_gu: 1,
    light_rec_1_10_gu: 1,
    fire_atk_2_01_gu: 1, water_atk_3_05_gu: 1, wisdom_rec_1_20_gu: 1,
    wisdom_atk_3_13_gu: 1, blood_atk_5_02_gu: 1,
  },
  wild: {
    small_light_gu: 2,
  },
};

// 需要走节点动作页的节点类型（险地 / 市集 / 野蛊 / 休整 / 静修）；由 NodeActionRules 单点定义，
// 避免两处分叉。必须声明在下面的 `let state = fresh()` 之前：fresh 生成固定图时要过滤模板池。
const NODE_ACTION_TYPES = NodeActionRules.nodeTypes;

let state = fresh();

function fresh(difficulty = 'normal') {
  const thoughts = RunRules.actionPointsPerTurn(READY.soul);
  const qiMax = RunRules.essenceMax(READY.cultivation, READY.aptitude, {
    essenceBase: DATA.aptitude.essence_base,
    aptitudeFactor: DATA.aptitude.aptitude_factor,
    cultivationFactor: DATA.aptitude.cultivation_factor,
  });
  const enemyById = Object.fromEntries(DATA.enemies.map((enemy) => [enemy.id, enemy]));
  const graph = RunFlow.generateGraph({
    seed: READY.seed,
    difficulty,
    difficulties: DATA.flow.difficulties,
    pools: DATA.flow.poolsBySegment,
    enemyById,
    nonCombatTemplates: DATA.nodes.filter((node) => NODE_ACTION_TYPES.includes(node.type)),
    nonCombatTypeLabels: NodeActionRules.typeLabels(DATA.nodeTypes),
  });
  const journey = {
    difficulty,
    graph,
    nodeId: null,
    availableNodeIds: graph.roots,
    completed: [],
    started: false,
  };
  return {
    ...READY, owned: { ...READY.owned }, wild: { ...READY.wild }, equipped: [], battle: null, qiMax, qi: qiMax,
    thought: thoughts, thoughtMax: thoughts,
    journey, prepFor: null, reward: null, ending: null, shopSold: [], restUsed: false, journal: [],
    materials: {}, page: 'hall', lootPity: 0, materialPityByTier: {},
    globalCodexIds: [], knownFacts: [],
    eventLog: [{
      id: 'event_0000', time: 0, nodeId: journey.nodeId, action: 'run_started',
      reason: 'new_run',
      after: { stones: READY.stones, owned: { ...READY.owned }, wild: { ...READY.wild } },
    }],
  };
}

const $ = (s) => document.querySelector(s);

function toast(msg, kind = '') {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'on ' + kind;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.className = kind), 2400);
}

function recordEvent(action, after = {}, reason = '', targets = []) {
  state.eventLog.push({
    id: `event_${String(state.eventLog.length).padStart(4, '0')}`,
    time: state.eventLog.length,
    nodeId: state.journey.nodeId,
    action,
    after,
    reason,
    targets,
  });
}

const STAGE_BY_RANK = ['', 'one', 'two', 'three', 'four', 'five'];
const GU_BY_ID = Object.fromEntries(DATA.gu.map((gu) => [gu.id, gu]));

function recomputeQiMax() {
  state.qiMax = RunRules.essenceMax(state.cultivation, state.aptitude, {
    essenceBase: DATA.aptitude.essence_base,
    aptitudeFactor: DATA.aptitude.aptitude_factor,
    cultivationFactor: DATA.aptitude.cultivation_factor,
  });
  state.qi = Math.min(state.qi, state.qiMax);
}

function currentCombatRoster(usedInstances = {}, sealedInstances = {}) {
  return GuRules.combatRoster(DATA.gu, state.owned, {
    playerRank: state.cultivation,
    trueQi: state.qi,
    thought: state.thought,
    actionLimitReached: false,
    usedInstances,
    sealedInstances,
  });
}

function rollVictoryLoot(battle) {
  const tier = RunRules.resolveBattleTier(battle.enemies);
  const layer = battle.layer || 1;
  const table = LootRules.layerTable(DATA.loot.tables, DATA.loot.pacingLayers, tier, layer);
  const tick = state.eventLog.length;
  const targets = DATA.loot.materialPityTargetsByTier[tier] || [];
  const materialRoll = table
    ? LootRules.rollMaterials(table, {
        seed: state.seed,
        tick,
        tier,
        countAdjustment: Math.max(0, state.cultivation - 1),
        materialPityByTier: state.materialPityByTier,
        targets,
        pityConfig: DATA.loot.pity,
      })
    : { materialIds: [] };
  const supportPool = DATA.flow.supportGuBySegment[String(layer)] || [];
  const guRoll = table
    ? LootRules.rollGuChoices(table, {
        seed: state.seed,
        tick,
        tier,
        lootPity: state.lootPity,
        pityConfig: DATA.loot.pity,
        school: state.school,
        schoolPools: DATA.loot.schoolPools,
        guById: GU_BY_ID,
        supportPool,
        choiceCount: DATA.flow.rewardGuChoiceCount || 3,
      })
    : { guIds: [], rarity: '' };
  return {
    stones: RunRules.battleStoneReward(tier, layer, DATA.battle.stoneRewards),
    tier,
    layer,
    tick,
    materialIds: materialRoll.materialIds,
    guChoices: guRoll.guIds || [],
    guRarity: guRoll.rarity || '',
    materialPityByTier: LootRules.nextMaterialPity(
      state.materialPityByTier,
      tier,
      materialRoll.materialIds,
      targets,
    ),
    lootPity: LootRules.nextLootPity(state.lootPity, guRoll.rarity, DATA.loot.pity),
  };
}

function hud() {
  $('#hud-qi').style.width = (state.qi / state.qiMax) * 100 + '%';
  $('#hud-qi-num').textContent = `${Math.round(state.qi)}/${state.qiMax}`;
  $('#hud-thought').textContent = state.thought;
  $('#hud-stone').textContent = state.stones;
  $('#hud-blood').textContent = state.blood;
  $('#hud-life').textContent = state.lifeTime;
  $('#hud-soul').textContent = `${state.soul}/${state.soulMax}`;
  const apt = { jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' }[state.aptitude];
  $('#hud-talent').textContent = `${apt} · ${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}`;
}

function draw() {
  hud();
  renderJourneyPages();
  renderBattle($('#panel-battle'));
  renderCover($('#panel-cover'));
}

const aliveEnemies = (b) => b.enemies.filter((e) => e.hp > 0);
const targetOf = (b) => b.enemies.find((e) => e.id === b.targetId && e.hp > 0)
  || b.enemies.find((e) => e.hp > 0) || null;

// 敌方回合 + 刻痕结算 + 真元回复 + 回合推进。返回 true 表示战斗已结束。
// 意图选取与冷却门禁见 rules.js（语义来自数据自带的 _phases_note）。
function enemyTurn(b) {
  for (const enemy of aliveEnemies(b)) {
    const it = enemy.enemyIntent;
    const prefix = b.enemies.length > 1 ? `<b>${enemy.name}</b> · ` : '';
    if (!it) {
      b.log.push(`${prefix}蓄势不动（cooldown_wait）`);
      continue;
    }
    enemy.lastFired[it.id] = b.turn;
    if (it.kind === 'seal') {
      const candidates = currentCombatRoster(b.guUsedThisTurn, b.guSealed)
        .filter((entry) => !entry.sealed);
      const sealed = candidates.length
        ? candidates[b.turn % candidates.length]
        : null;
      if (sealed) {
        b.guSealed[sealed.instanceId] = Math.max(1, Number(it.seal_turns || 1));
        b.log.push(`${prefix}<b>${sealed.name}</b> 被封印 ${b.guSealed[sealed.instanceId]} 回合`);
      } else {
        b.log.push(`${prefix}无可封印的蛊虫`);
      }
    }
    if (it.damage) {
      const rawDamage = Number(it.damage || 0);
      const weaken = Number(enemy.intentWeaken || 0);
      const damage = RunRules.weakenedDamage(rawDamage, weaken);
      if (weaken > 0) {
        enemy.intentWeaken = 0;
        b.log.push(`${prefix}<b>意图弱化</b> 减免 ${Math.min(rawDamage, weaken)}`);
      }
      const absorbed = Math.min(b.block, damage);
      b.block -= absorbed;
      const taken = damage - absorbed;
      state.blood -= taken;
      b.log.push(absorbed
        ? `${prefix}<b>${it.label}</b>，<span class="dmg">伤 ${taken}</span>（护体挡下 ${absorbed}）`
        : `${prefix}<b>${it.label}</b>，<span class="dmg">伤 ${damage}</span>`);
      Sfx.hurt();
    } else {
      b.log.push(`${prefix}<b>${it.label}</b>`);
    }
    if (it.soul_drain) {
      state.soul = RunRules.drainSoul(state.soul, it.soul_drain);
      b.log.push(`${prefix}<span class="dmg">魂魄被抽 ${it.soul_drain}</span>`);
    }
    if (it.life_cost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, it.life_cost);
      b.log.push(`${prefix}<span class="dmg">寿元被夺 ${it.life_cost}</span>`);
    }
    if (it.essence_burn) {
      state.qi = Math.max(0, state.qi - it.essence_burn);
      b.log.push(`${prefix}<span class="dmg">真元被焚 ${it.essence_burn}</span>`);
    }
    if (state.blood <= 0) break;
    if (RunRules.lifeDefeated(state.lifeTime)) break;
    if (RunRules.soulDefeated(state.soul)) break;
  }
  if (state.blood <= 0) {
    state.blood = 0;
    b.over = '败';
    b.log.push('气血耗尽');
    Sfx.lose();
    return true;
  }
  if (RunRules.lifeDefeated(state.lifeTime)) {
    state.lifeTime = 0;
    b.over = '败';
    b.deathCause = 'life_cost';
    b.log.push('寿元耗尽');
    Sfx.lose();
    return true;
  }
  if (RunRules.soulDefeated(state.soul)) {
    state.soul = 0;
    b.over = '败';
    b.deathCause = 'soul';
    b.log.push('魂魄耗尽');
    Sfx.lose();
    return true;
  }
  for (const enemy of aliveEnemies(b)) enemy.intentWeaken = 0;
  for (const enemy of aliveEnemies(b)) {
    const layers = Number(enemy.statuses?.marked || 0);
    const damage = RunRules.markScratchDamage(
      layers,
      DATA.battle.markScratchPerLayer,
      DATA.battle.markScratchCap,
    );
    if (damage <= 0) continue;
    enemy.hp = Math.max(0, enemy.hp - damage);
    b.log.push(`<b>${enemy.name}</b> · 刻痕划伤，<span class="dmg">伤 ${damage}</span>`);
  }
  if (!aliveEnemies(b).length) {
    b.over = '胜';
    Sfx.win();
    return true;
  }
  if (!aliveEnemies(b).some((enemy) => enemy.id === b.targetId)) {
    b.targetId = aliveEnemies(b)[0].id;
  }
  b.swordIntent = RunRules.decaySwordIntent(b.swordIntent);
  b.guSealed = b.guSealed || {};
  for (const [instanceId, turns] of Object.entries(b.guSealed)) {
    const remaining = Number(turns) - 1;
    if (remaining <= 0) delete b.guSealed[instanceId];
    else b.guSealed[instanceId] = remaining;
  }
  state.qi = Math.min(
    state.qiMax,
    state.qi + RunRules.battleRegen(state.qiMax, DATA.battle.regenPct[state.aptitude]),
  );
  state.thoughtMax = RunRules.actionPointsPerTurn(state.soul);
  state.thought = state.thoughtMax;
  b.guUsedThisTurn = {};
  b.killMoveUsedThisTurn = {};
  b.actionsUsed = 0;
  b.actionLimit = state.thoughtMax;
  b.turnSupports = {};
  b.turn += 1;
  b.log.push(`— 第 ${b.turn} 回合 —`);
  if (fireDelayedEffects(b)) return true;
  aliveEnemies(b).forEach((enemy) => act._pickIntent(b, enemy));
  return false;
}

function openBattleOutcome() {
  const b = state.battle;
  if (!b || !b.over) return;
  if (b.over === '败') {
    const lifeDeath = b.deathCause === 'life_cost';
    const soulDeath = b.deathCause === 'soul';
    state.ending = {
      title: lifeDeath ? '寿元耗尽' : soulDeath ? '魂魄耗尽' : '气血耗尽',
      detail: lifeDeath
        ? '寿元归零，败于当前遭遇。'
        : soulDeath
          ? '你的魂魄被抽干，败于当前遭遇。'
          : '气血耗尽，败于当前遭遇。',
      turn: b.turn,
    };
    state.battle = null;
    showPage('ending');
  } else {
    const loot = rollVictoryLoot(b);
    const healed = Math.ceil(state.bloodMax * (DATA.flow.postBattleHealPct || 0) / 100);
    state.blood = Math.min(state.bloodMax, state.blood + healed);
    state.qi = state.qiMax;
    state.stones += loot.stones;
    for (const materialId of loot.materialIds || []) {
      state.materials[materialId] = (state.materials[materialId] || 0) + 1;
    }
    state.materialPityByTier = { ...loot.materialPityByTier };
    state.lootPity = loot.lootPity;
    state.journal.unshift(`战后收获 · 元石 +${loot.stones} · 气血 +${healed} · 真元回满`);
    recordEvent('battle_loot', {
      stones: state.stones,
      materials: { ...state.materials },
      true_qi: state.qi,
      health: state.blood,
      material_pity_by_tier: { ...state.materialPityByTier },
      loot_pity: state.lootPity,
    }, loot.guChoices.length ? 'gu_choices_pending' : 'auto_rewards_granted', loot.materialIds);
    state.reward = {
      ...loot,
      nodeId: b.nodeId,
      healed,
      turn: b.turn,
    };
    state.battle = null;
    showPage('reward');
  }
  draw();
}

function applyEffectPlan(b, target, plan, label) {
  if (plan.heal) {
    state.blood = Math.min(state.bloodMax, state.blood + plan.heal);
    b.log.push(`<b>${label}</b> · <span class="heal">回气 +${plan.heal}</span>`);
  }
  if (plan.block) {
    b.block += plan.block;
    b.log.push(`<b>${label}</b> · 护体 +${plan.block}`);
  }
  if (plan.damage) {
    target.hp -= plan.damage;
    b.log.push(`<b>${target.name}</b> · <b>${label}</b> 命中，<span class="dmg">伤 ${plan.damage}</span>`);
    Sfx.hit();
    const box = $('#foe-box');
    if (box) { box.classList.add('hit'); setTimeout(() => box.classList.remove('hit'), 300); }
  }
  if (plan.statuses.length) {
    target.statuses = target.statuses || {};
    for (const status of plan.statuses) {
      target.statuses[status.name] = (target.statuses[status.name] || 0) + status.amount;
      b.log.push(`<b>${target.name}</b> · ${status.name} +${status.amount}`);
    }
  }
  if (plan.consumeStatus && target.statuses?.[plan.consumeStatus]) {
    const consumed = Number(target.statuses[plan.consumeStatus] || 0);
    delete target.statuses[plan.consumeStatus];
    b.log.push(`<b>${target.name}</b> · 消耗 ${statusLabel(plan.consumeStatus)} ${consumed} 层`);
  }
  if (plan.intentWeaken) {
    target.intentWeaken = (target.intentWeaken || 0) + plan.intentWeaken;
    b.log.push(`<b>${target.name}</b> · 意图弱化 ${plan.intentWeaken}`);
  }
  if (plan.swordIntent) {
    b.swordIntent = RunRules.addSwordIntent(b.swordIntent, plan.swordIntent);
    b.log.push(`<b>${label}</b> · 剑意 +${plan.swordIntent}`);
  }
  if (plan.support) {
    b.turnSupports[plan.support.school] =
      (b.turnSupports[plan.support.school] || 0) + plan.support.bonus;
    b.log.push(`<b>${label}</b> · ${schoolLabel(plan.support.school)}支援 +${plan.support.bonus}`);
  }
}

function scheduleEffect(b, effect, school, label) {
  const turns = Math.max(1, Number(effect.delay?.turns || 1));
  b.delayedEffects.push({
    effect: { ...effect, delay: undefined },
    school,
    dueTurn: RunRules.delayDueTurn(b.turn, turns),
    label,
  });
  b.log.push(`<b>${label}</b> · 延迟 ${turns} 回合，将于第 ${RunRules.delayDueTurn(b.turn, turns)} 回合结算`);
}

function fireDelayedEffects(b) {
  if (!b.delayedEffects?.length) return false;
  const remaining = [];
  for (const entry of b.delayedEffects) {
    if (entry.dueTurn > b.turn) {
      remaining.push(entry);
      continue;
    }
    const target = aliveEnemies(b)[0];
    if (!target) break;
    const effect = { ...entry.effect };
    delete effect.delay;
    const plan = GuRules.effectPlan(effect, {
      school: entry.school,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    applyEffectPlan(b, target, plan, `${entry.label}（延迟）`);
    b.log.push(`第 ${b.turn} 回合 · 延迟效果到期`);
    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }
    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      return true;
    }
  }
  b.delayedEffects = remaining;
  return false;
}

function finishPlayerAction(b) {
  if (!b.over && state.thought <= 0) return act.endTurn();
  draw();
}

const act = {
  attuneGu(definitionId) {
    const gu = GU_BY_ID[definitionId];
    if (!gu) return toast('未找到该蛊数据', 'bad');
    const result = GuRules.attuneWild(state.wild, state.owned, state.qi, definitionId, gu.rank);
    if (!result.ok) {
      return toast(
        result.reason === 'insufficient_essence'
          ? `真元不足 · 需要 ${result.cost}`
          : '没有可炼化的该野生蛊',
        'bad',
      );
    }
    const first = !state.eventLog.some((event) => event.action === 'attune_gu');
    state.wild = result.wild;
    state.owned = result.owned;
    state.qi = result.trueQi;
    recordEvent(
      'attune_gu',
      { trueQi: state.qi, owned: { ...state.owned }, wild: { ...state.wild } },
      first ? 'first_gu_attuned' : 'gu_attuned',
      [definitionId],
    );
    Sfx.success();
    toast(`炼化成功 · ${gu.name}`, 'good');
    draw();
  },

  forge(recipeId) {
    const r = DATA.recipes.find((x) => x.id === recipeId);
    if (!r) return;
    const need = r.inputs.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
    for (const [id, n] of Object.entries(need)) if ((state.owned[id] || 0) < n) return toast('材料不足', 'bad');
    const materialNeed = r.materials || {};
    for (const [id, n] of Object.entries(materialNeed)) {
      if ((state.materials[id] || 0) < n) return toast(`材料不足 · ${materialById(id).name}`, 'bad');
    }
    if ((r.stoneCost || 0) > state.stones) return toast('元石不足', 'bad');

    for (const [id, n] of Object.entries(need)) state.owned[id] -= n;
    for (const [id, n] of Object.entries(materialNeed)) state.materials[id] -= n;
    state.stones = Math.max(0, state.stones - (r.stoneCost || 0));
    if (Object.keys(materialNeed).length) {
      recordEvent('refine_gu', { materials: { ...state.materials } }, 'refinement_materials_spent', Object.keys(materialNeed));
    }
    Sfx.forge();

    const outName = (DATA.gu.find((g) => g.id === r.output) || {}).name || r.output;
    const roll = RunRules.refinementRoll(state.seed, r.id, state.eventLog.length);
    if (RunRules.refinementSucceeds(roll, r)) {
      state.owned[r.output] = (state.owned[r.output] || 0) + 1;
      recordEvent('refine_gu', { owned: { ...state.owned } }, 'refinement_succeeded', [r.output]);
      Sfx.success();
      toast(`开炉成功 · ${outName}`, 'good');
    } else {
      recordEvent('refine_gu', { owned: { ...state.owned } }, 'refinement_failed_destroyed_inputs', r.inputs || []);
      Sfx.fail();
      toast('开炉失败 · 投入蛊虫全部消亡', 'bad');
    }
    draw();
  },

  toggleMove(id) {
    const i = state.equipped.indexOf(id);
    if (i >= 0) { state.equipped.splice(i, 1); Sfx.click(); }
    else if (state.equipped.length >= 3) return toast('杀招槽已满（三）', 'bad');
    else { state.equipped.push(id); Sfx.click(); }
    draw();
  },

  startRun(difficulty = 'normal') {
    state = fresh(difficulty);
    state.journey.started = true;
    showPage('map');
    Sfx.click();
    draw();
    toast(`已开局 · ${DATA.flow.difficulties[state.journey.difficulty].label}`);
  },

  chooseNode(nodeId) {
    const node = nodeById(nodeId);
    if (!node || !state.journey.availableNodeIds.includes(nodeId)) return;
    state.journey.nodeId = nodeId;
    state.journey.availableNodeIds = [];
    state.prepFor = null;
    state.reward = null;
    state.shopSold = [];
    state.battle = null;
    // 休整的「本次探访已消费」标记按节点重置：lab 一节点一处理，进入节点即清零，
    // 与 Godot 的 <节点id>_used 旗标（rest_rules.gd:125,167）同语义。
    state.restUsed = false;
    if (NODE_ACTION_TYPES.includes(node.type)) return act.enterNodeAction();
    if (!node.enemyIds?.length) {
      state.journey.availableNodeIds = node.nextIds || [];
      state.journey.nodeId = null;
      return showPage('map');
    }
    act.startBattle(node.enemyIds, node.id);
  },

  // 非战斗节点（险地 / 市集 / 野蛊 / 休整 / 静修）：进入后等玩家在节点动作页选一个动作。
  enterNodeAction() {
    const node = currentNode();
    if (!node || !NODE_ACTION_TYPES.includes(node.type)) return showPage('map');
    showPage('node-action');
    Sfx.click();
    draw();
  },

  // 解析节点动作选择。转移与拒绝口径见 js/node_action_rules.js（照搬 social_command_rules.gd
  // 的 standard actions 与 action_preview_service.gd 的预览门禁）。
  // 休整节点是唯一的两步交互：先取「歇脚恢复」，才解禁「离开休整」（rest_rules.gd:121-141 的一次性门禁）。
  resolveNodeAction(choiceId) {
    const node = currentNode();
    if (!node || !NODE_ACTION_TYPES.includes(node.type)) return;
    if (state.prepFor === node.id) return; // 已解析：节点只剩统一整备
    if (node.type === NodeActionRules.restNodeType) return act.resolveRestAction(choiceId);
    const beforeStones = state.stones;
    const beforeQi = state.qi;
    const result = NodeActionRules.resolve(choiceId, {
      stones: state.stones,
      essence: state.qi,
      essenceMax: state.qiMax,
      knownFacts: state.knownFacts,
    });
    if (!result.ok) {
      return toast(NodeActionRules.reasonLabel(result.reason, { stones: state.stones }), 'bad');
    }
    state.stones = result.stones;
    state.qi = result.essence;
    state.knownFacts = result.knownFacts;
    const stoneDelta = state.stones - beforeStones;
    const qiDelta = state.qi - beforeQi;
    state.journal.unshift(`${node.name} · ${actionLabel(choiceId)}`
      + `${stoneDelta ? ` · 元石 ${stoneDelta > 0 ? '+' : ''}${stoneDelta}` : ''}`
      + `${qiDelta ? ` · 真元 ${qiDelta > 0 ? '+' : ''}${qiDelta}` : ''}`);
    recordEvent('choose_action', {
      stone: state.stones,
      true_qi: state.qi,
      known_facts: [...state.knownFacts],
    }, result.reason, [node.routeTemplateId]);
    Sfx.success();
    toast(NodeActionRules.resultText(choiceId) || actionLabel(choiceId), 'good');
    act.openPrep();
  },

  // 休整节点的一步：取收益（歇脚恢复）后留在本页，离开卡才结束节点进统一整备。
  // 被拒只提示、不改状态、不推进页面（沿用 slice-10 口径）。
  resolveRestAction(choiceId) {
    const node = currentNode();
    if (!node || node.type !== NodeActionRules.restNodeType) return;
    const result = NodeActionRules.resolveRest(choiceId, {
      used: state.restUsed === true,
      health: state.blood,
      healthMax: state.bloodMax,
      essence: state.qi,
      essenceMax: state.qiMax,
      knownFacts: state.knownFacts,
    });
    if (!result.ok) {
      return toast(NodeActionRules.restReasonLabel(result.reason), 'bad');
    }
    state.blood = result.healthAfter;
    state.qi = result.essenceAfter;
    state.knownFacts = result.knownFacts;
    state.restUsed = result.used;
    state.journal.unshift(choiceId === NodeActionRules.restHealId
      ? `${node.name} · ${result.text}`
      : `${node.name} · ${result.title}`);
    recordEvent('choose_action', {
      health: state.blood,
      true_qi: state.qi,
      rest_used: state.restUsed,
    }, result.reason, [node.routeTemplateId]);
    Sfx.success();
    toast(result.text, 'good');
    if (choiceId === NodeActionRules.restLeaveId) return act.openPrep();
    draw();
  },

  completeCurrentNode(reason = '整备完成') {
    const node = currentNode();
    if (!node) return act.endJourney('行程已尽');
    if (!state.journey.completed.includes(node.id)) state.journey.completed.push(node.id);
    state.journal.unshift(`${node.name} · ${reason}`);
    recordEvent('complete_node', { graph_progress: [...state.journey.completed] }, 'node_completed', [node.id]);
    state.prepFor = null;
    state.journey.nodeId = null;
    state.journey.availableNodeIds = [...(node.nextIds || [])];
    state.battle = null;
    state.reward = null;
    if (!state.journey.availableNodeIds.length) {
      return act.endJourney('五段行程已走完');
    }
    showPage('map');
    Sfx.click();
    draw();
  },

  advanceJourney(reason) {
    return act.completeCurrentNode(reason);
  },

  endJourney(title) {
    state.ending = {
      title,
      detail: state.journal[0] || '本局没有产生可归因记录。',
      turn: state.battle ? state.battle.turn : 0,
    };
    state.battle = null;
    showPage('ending');
    Sfx.win();
    draw();
  },

  restartRun(difficulty = state.journey?.difficulty || 'normal') {
    state = fresh(difficulty);
    showPage('hall');
    Sfx.click();
    draw();
    toast('已重开本局');
  },

  startBattle(enemyIds, nodeId = null) {
    const ids = Array.isArray(enemyIds) ? enemyIds : [enemyIds];
    const picked = ids.map((id) => DATA.enemies.find((x) => x.id === id)).filter(Boolean);
    if (!picked.length) return toast('未找到敌人数据', 'bad');
    const enemies = picked.map((e) => ({
      ...e, hpMax: e.hp, hp: e.hp,
      revealed: false, flags: {}, lastFired: {},
      phaseIndex: undefined, phaseTotal: 0, enemyIntent: null, intentWeaken: 0,
    }));
    state.thoughtMax = RunRules.actionPointsPerTurn(state.soul);
    state.thought = state.thoughtMax;
    state.battle = {
      enemies, targetId: enemies[0].id,
      block: 0, turn: 1, over: null, nodeId,
      layer: (nodeId && nodeById(nodeId)?.layer) || 1,
      guUsedThisTurn: {}, guSealed: {}, killMoveUsedThisTurn: {}, buffs: {},
      turnSupports: {}, swordIntent: 0, delayedEffects: [],
      actionsUsed: 0, actionLimit: state.thoughtMax,
      log: [`<b>${enemies.map((e) => e.name).join('、')}</b> 逼近。`],
    };
    state.battle.enemies.forEach((enemy) => act._pickIntent(state.battle, enemy));
    showPage('battle');
    Sfx.click();
    draw();
  },

  // 选本回合敌方意图：阶段 + 冷却门禁（全部在冷却则为 null = cooldown_wait）
  _pickIntent(b, enemy = targetOf(b)) {
    if (!enemy || enemy.hp <= 0) return;
    const view = phaseView(enemy);
    const idx = view.phase ? view.phase.index : null;
    if (enemy.phaseIndex !== undefined && idx !== enemy.phaseIndex && idx !== null) {
      b.log.push(`<b>${enemy.name} 转入第 ${idx + 1} 阶段</b>`);
    }
    enemy.phaseIndex = idx;
    enemy.phaseTotal = view.phase ? view.phase.total : 0;
    const prevId = enemy.enemyIntent ? enemy.enemyIntent.id : null;
    enemy.enemyIntent = selectIntent(view.intents, enemy.lastFired, b.turn);
    const nextId = enemy.enemyIntent ? enemy.enemyIntent.id : null;
    if (nextId !== prevId) {
      const prefix = b.enemies.length > 1 ? `${enemy.name} · ` : '';
      b.log.push(`${prefix}意图：${intentText(enemy.enemyIntent)}`);
    }
  },

  setTarget(enemyId) {
    const b = state.battle;
    if (!b || !b.enemies.some((e) => e.id === enemyId && e.hp > 0)) return;
    b.targetId = enemyId;
    Sfx.click();
    draw();
  },

  basicAttack() {
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target) return openBattleOutcome();
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');
    if (state.thought < 1) return toast('念头不足', 'bad');

    state.thought -= 1;
    b.actionsUsed += 1;
    const damage = Number(DATA.battle.fightDamageBase || 1)
      + Number(b.buffs?.force || 0)
      + Number(b.buffs?.yi_zhang || 0);
    target.hp = Math.max(0, target.hp - damage);
    b.log.push(`<b>${target.name}</b> · <b>拳脚</b> 命中，<span class="dmg">伤 ${damage}</span>`);
    Sfx.hit();
    const box = $('#foe-box');
    if (box) { box.classList.add('hit'); setTimeout(() => box.classList.remove('hit'), 300); }
    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }
    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      openBattleOutcome();
      return;
    }
    finishPlayerAction(b);
  },

  observe() {
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target || target.revealed) return;
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');
    if (state.thought < 1) return toast('念头不足', 'bad');
    state.thought -= 1;
    b.actionsUsed += 1;
    target.revealed = true;
    Sfx.click();
    b.log.push(`你凝神细察 <b>${target.name}</b>，看清了它的线索与反击。`);
    finishPlayerAction(b);
  },

  useMove(id) {
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target) return openBattleOutcome();
    const m = DATA.killMoves.find((x) => x.id === id);
    if (!m) return toast('未找到该杀招', 'bad');
    if (b.killMoveUsedThisTurn?.[id]) return toast('本回合已使用该杀招', 'bad');
    const recipeInstances = GuRules.killMoveRecipeInstances(
      m,
      state.owned,
      b.guUsedThisTurn,
      b.guSealed,
    );
    if (recipeInstances.some((instanceId) => !instanceId)) {
      return toast('配方蛊本回合已使用或封印', 'bad');
    }
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');
    if (state.qi < m.true_qi_cost || state.thought < m.thought_cost) return toast('真元或念头不足', 'bad');
    const gate = GuRules.gateMissReason(m.effect, {
      hp: state.blood,
      hpMax: state.bloodMax,
      enemiesAlive: aliveEnemies(b).length,
      turn: b.turn,
      statusStacks: target.statuses || {},
    });
    if (gate) return toast(guReasonLabel(gate), 'bad');

    state.qi -= m.true_qi_cost;
    state.thought -= m.thought_cost;
    b.actionsUsed += 1;
    for (const instanceId of recipeInstances) b.guUsedThisTurn[instanceId] = true;
    b.killMoveUsedThisTurn[id] = true;
    if (m.life_cost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, m.life_cost);
      b.log.push(`<b>${m.label}</b> · 寿元 -${m.life_cost}`);
      if (RunRules.lifeDefeated(state.lifeTime)) {
        state.lifeTime = 0;
        b.over = '败';
        b.deathCause = 'life_cost';
        b.log.push('寿元耗尽');
        Sfx.lose();
        openBattleOutcome();
        return;
      }
    }
    // 真实规则：直接攻击会被生效中的反击吞掉，且敌方随即转入对应状态、该反击此后不再预警。
    // 见 scripts/domain/action_preview_service.gd `_live_counter_labels`。
    if (isDirectStrike(m)) {
      const hit = liveReactions(target)[0];
      if (hit) {
        if (hit.counter_status === 'bound') target.flags.enemy_bound = true;
        if (hit.counter_status === 'guarded') target.flags.guarded = true;
        b.log.push(`<b>${target.name}</b> · <b>${m.label}</b> 被「${hit.label}」吞掉，<span class="dmg">未造成伤害</span>`);
        b.log.push(`敌方转入「${statusZh(hit.counter_status)}」，该反击此后不再预警`);
        Sfx.fail();
        finishPlayerAction(b);
        return;
      }
    }
    if (m.effect?.delay) {
      scheduleEffect(b, m.effect, m.tag, m.label);
      finishPlayerAction(b);
      return;
    }

    const plan = GuRules.effectPlan(m.effect, {
      school: m.tag,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    applyEffectPlan(b, target, plan, m.label);
    const extraDamage = Number(m.damage || 0);
    if (extraDamage > 0) {
      target.hp = Math.max(0, target.hp - extraDamage);
      b.log.push(`<b>${target.name}</b> · <b>${m.label}</b> 追加命中，<span class="dmg">伤 ${extraDamage}</span>`);
      Sfx.hit();
    }
    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }

    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      openBattleOutcome();
      return;
    }

    finishPlayerAction(b);
  },

  useGu(instanceId) {
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target) return openBattleOutcome();
    const gu = currentCombatRoster(b.guUsedThisTurn, b.guSealed)
      .find((entry) => entry.instanceId === instanceId);
    if (!gu) return toast('未找到该蛊', 'bad');
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');

    const reason = GuRules.activationReason(gu, {
      playerRank: state.cultivation,
      trueQi: state.qi,
      thought: state.thought,
      usedThisTurn: !!b.guUsedThisTurn[instanceId],
      actionLimitReached: b.actionsUsed >= b.actionLimit,
    });
    if (reason) return toast(guReasonLabel(reason), 'bad');

    const gate = GuRules.gateMissReason(gu.battleEffect, {
      hp: state.blood,
      hpMax: state.bloodMax,
      enemiesAlive: aliveEnemies(b).length,
      turn: b.turn,
      statusStacks: target.statuses || {},
    });
    if (gate) return toast(guReasonLabel(gate), 'bad');

    state.qi -= gu.trueQiCost;
    state.thought -= gu.thoughtCost;
    b.actionsUsed += 1;
    b.guUsedThisTurn[instanceId] = true;
    b.log.push(`催动 <b>${gu.name}</b> · 真元 -${gu.trueQiCost} · 念头 -${gu.thoughtCost}`);
    if (gu.lifeCost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, gu.lifeCost);
      b.log.push(`<b>${gu.name}</b> · 寿元 -${gu.lifeCost}`);
      if (RunRules.lifeDefeated(state.lifeTime)) {
        state.lifeTime = 0;
        b.over = '败';
        b.deathCause = 'life_cost';
        b.log.push('寿元耗尽');
        Sfx.lose();
        openBattleOutcome();
        return;
      }
    }
    if (isDirectStrike({ effect: gu.battleEffect })) {
      const hit = liveReactions(target)[0];
      if (hit) {
        if (hit.counter_status === 'bound') target.flags.enemy_bound = true;
        if (hit.counter_status === 'guarded') target.flags.guarded = true;
        b.log.push(`<b>${target.name}</b> · <b>${gu.name}</b> 被「${hit.label}」吞掉，<span class="dmg">未造成伤害</span>`);
        b.log.push(`敌方转入「${statusZh(hit.counter_status)}」，该反击此后不再预警`);
        Sfx.fail();
        finishPlayerAction(b);
        return;
      }
    }
    if (gu.battleEffect?.delay) {
      scheduleEffect(b, gu.battleEffect, gu.school, gu.name);
      finishPlayerAction(b);
      return;
    }

    const plan = GuRules.effectPlan(gu.battleEffect, {
      school: gu.school,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    applyEffectPlan(b, target, plan, gu.name);

    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }

    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      openBattleOutcome();
      return;
    }

    finishPlayerAction(b);
  },

  buyOffer(offerId) {
    const offer = DATA.shopOffers.find((o) => o.id === offerId);
    if (!offer || !canBuyOffer(offer)) return;
    const cost = offerCost(offer);
    state.stones -= cost;
    if (offer.kind === 'purchase') {
      state.owned[offer.gu_id] = (state.owned[offer.gu_id] || 0) + 1;
    } else if (offer.kind === 'material_purchase') {
      state.materials[offer.material_id] = (state.materials[offer.material_id] || 0) + 1;
    } else if (offer.kind === 'gu_fang_unlock') {
      state.globalCodexIds.push(offer.gu_id);
    }
    state.shopSold.push(offer.id);
    state.journal.unshift(`坊市 · 购入${offerName(offer)} · 元石 ${cost}`);
    recordEvent('shop', {
      stones: state.stones,
      owned: { ...state.owned },
      materials: { ...state.materials },
      global_codex_ids: [...state.globalCodexIds],
      cost,
    }, offer.kind === 'gu_fang_unlock' ? 'shop_gu_fang_unlock_completed' : 'shop_purchase', [offer.id]);
    Sfx.success();
    toast(`已购入 · ${offerName(offer)}`, 'good');
    draw();
  },

  leaveShop() {
    showPage(state.prepFor ? 'prep' : 'map');
    draw();
  },

  breakthrough(mode = 'stone') {
    const result = RunFlow.nextBreakthrough({
      rank: state.cultivation,
      stageIndex: state.cultivationStage,
      stones: state.stones,
      aptitude: state.aptitude,
      owned: state.owned,
    }, DATA.flow);
    if (!result.ok && !(result.kind === 'small' && mode === 'sari' && result.canSari)) {
      const reason = result.missing === 'insufficient_aptitude'
        ? `资质不足 · 需要${({ jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' })[result.requiredApt]}`
        : result.missing === 'insufficient_stone'
          ? `元石不足 · 需要 ${result.stoneCost}`
          : result.kind === 'max'
            ? '已至五转巅峰'
            : '舍利蛊不足或阶位不符';
      return toast(reason, 'bad');
    }

    const oldQiMax = state.qiMax;
    if (result.kind === 'small') {
      if (mode === 'sari') {
        if (!result.sariId || !result.canSari) return toast('没有当前转数同阶舍利蛊', 'bad');
        state.owned[result.sariId] -= 1;
      } else {
        if (!result.canStone) return toast(`元石不足 · 需要 ${result.stoneCost}`, 'bad');
        state.stones -= result.stoneCost;
      }
      state.cultivationStage = result.targetStageIndex;
      state.journal.unshift(`小突破 · ${result.targetLabel}`);
      recordEvent('breakthrough', {
        cultivation: state.cultivation,
        cultivation_stage: state.cultivationStage,
        stone: state.stones,
        owned: { ...state.owned },
      }, mode === 'sari' ? 'small_breakthrough_sari' : 'small_breakthrough_stone', result.sariId ? [result.sariId] : []);
    } else {
      state.stones -= result.stoneCost;
      state.cultivation = result.targetRank;
      state.cultivationStage = 0;
      state.stage = STAGE_BY_RANK[result.targetRank];
      state.journal.unshift(`大突破 · ${result.targetRank} 转`);
      recordEvent('breakthrough', {
        cultivation: state.cultivation,
        cultivation_stage: state.cultivationStage,
        stone: state.stones,
      }, `rank_${result.targetRank}_breakthrough`);
    }
    recomputeQiMax();
    state.qi = Math.min(oldQiMax, state.qiMax);
    Sfx.success();
    toast(`突破成功 · ${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}`, 'good');
    draw();
  },

  useAptitudeGu() {
    const guId = DATA.flow.aptitudeGuId;
    if (!Number(state.owned[guId] || 0)) return toast('没有资质蛊', 'bad');
    const order = DATA.flow.aptitudeOrder || [];
    const current = order.indexOf(state.aptitude);
    if (current < 0 || current >= order.length - 1) return toast('资质已至甲等', 'bad');
    state.owned[guId] -= 1;
    state.aptitude = order[current + 1];
    recomputeQiMax();
    state.qi = state.qiMax;
    state.journal.unshift(`使用资质蛊 · 资质提升至${({ jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' })[state.aptitude]}`);
    recordEvent('aptitude_gu_used', {
      aptitude: state.aptitude,
      owned: { ...state.owned },
      essence_capacity: state.qiMax,
    }, 'aptitude_raised', [guId]);
    Sfx.success();
    toast(`资质提升 · ${({ jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' })[state.aptitude]}`, 'good');
    draw();
  },

  sellGu(guId) {
    const gu = GU_BY_ID[guId];
    if (!gu || Number(state.owned[guId] || 0) <= 0) return toast('没有可卖出的该蛊', 'bad');
    const price = RunFlow.sellValue(gu.value);
    state.owned[guId] -= 1;
    state.stones += price;
    const invalid = [];
    for (const move of DATA.killMoves) {
      if (!state.equipped.includes(move.id)) continue;
      const enough = (move.recipe || []).every((id) => Number(state.owned[id] || 0) > 0);
      if (!enough) invalid.push(move);
    }
    if (invalid.length) {
      const invalidIds = new Set(invalid.map((move) => move.id));
      state.equipped = state.equipped.filter((id) => !invalidIds.has(id));
    }
    state.journal.unshift(`卖蛊 · ${gu.name} · 元石 +${price}${invalid.length ? ` · 自动卸下${invalid.map((m) => m.label).join('、')}` : ''}`);
    recordEvent('sell_gu', {
      owned: { ...state.owned },
      stone: state.stones,
    }, 'gu_sold', [guId]);
    Sfx.success();
    toast(`卖出 ${gu.name} · 元石 +${price}${invalid.length ? ' · 已自动卸下失效杀招' : ''}`, 'good');
    draw();
  },

  leaveRest() {
    return act.leavePrep();
  },

  leavePrep() {
    return act.completeCurrentNode('结束整备');
  },

  openPrep() {
    if (!currentNode()) return showPage('map');
    state.prepFor = currentNode().id;
    state.reward = null;
    showPage('prep');
    draw();
  },

  chooseRewardGu(guId) {
    const reward = state.reward;
    if (!reward || !(reward.guChoices || []).includes(guId)) return;
    state.owned[guId] = (state.owned[guId] || 0) + 1;
    state.journal.unshift(`战后三选一 · ${(GU_BY_ID[guId] || {}).name || guId}`);
    recordEvent('battle_loot', { owned: { ...state.owned }, loot_pity: state.lootPity }, 'loot_gu_gained', [guId]);
    Sfx.success();
    act.openPrep();
  },

  continueReward() {
    const reward = state.reward;
    if (!reward) return showPage('map');
    if ((reward.guChoices || []).length) return toast('请先选择一只蛊虫', 'bad');
    state.reward = null;
    act.openPrep();
  },

  endTurn() {
    const b = state.battle;
    if (!b || b.over) return;
    Sfx.click();
    b.log.push('你结束本回合。');
    if (enemyTurn(b)) { openBattleOutcome(); return; }
    draw();
  },

  endBattle() {
    const b = state.battle;
    if (b && b.over) return openBattleOutcome();
    state.battle = null;
    showPage('map');
    Sfx.click();
    draw();
  },
};

// 覆盖页：让开发者一眼看清"这页验了什么、没验什么"。
function renderCover(root) {
  const c = DATA.mechanisms;
  root.innerHTML = `
    <h2>已覆盖 · 可在页面上当场验证</h2>
    <div class="cover-list">${c.covered.map((x) => `
      <div class="cover ok">
        <div class="cv">${x.name}</div>
        <div class="cd">${x.detail}</div>
        <div class="cs">来源：${x.source}</div>
      </div>`).join('')}</div>
    <h2 style="margin-top:32px">未覆盖 · 不要以为这页已经完整</h2>
    <div class="cover-list">${c.notCovered.map((x) => `
      <div class="cover no">
        <div class="cv">${x.name}</div>
        <div class="cd">${x.why}</div>
      </div>`).join('')}</div>`;
}

// 面板切换。ending 没有常驻页签，由终局流程直接打开。
function showPage(page) {
  const panelIds = [...document.querySelectorAll('.panel')].map((p) => p.id);
  const next = typeof page === 'string' && panelIds.includes(`panel-${page}`) ? page : 'hall';
  state.page = next;
  document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('on', b.dataset.tab === next));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('on', p.id === `panel-${next}`));
}

const tabs = [...document.querySelectorAll('#tabs button')];
tabs.forEach((b) => b.addEventListener('click', () => {
  showPage(b.dataset.tab);
  Sfx.click();
}));
$('#reset').addEventListener('click', () => act.restartRun());
document.addEventListener('pointerdown', () => Sfx.click(), { once: true });

draw();
showPage(state.page);
document.documentElement.dataset.ready = '1';
