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

// —— 种子与存档提交边界（W1）——
// READY.seed 只是模板残留，不得覆盖已选择/已存档种子。
// ?seed= 只服务「明确的新局」；继续始终优先存档里的 seed。
let nextRunSeedValue = null;
let saveWriteBlockedUntilNewRun = false;
let skipPersistOnce = false;
let bootSaveIssue = null; // null | 'unreadable' | 'storage_error'
let lastSaveStatus = { ok: true, reason: '' };

function nextRunSeed() {
  if (globalThis.crypto && typeof globalThis.crypto.getRandomValues === 'function') {
    const buf = new Uint32Array(1);
    globalThis.crypto.getRandomValues(buf);
    return (buf[0] % 2147483646) + 1;
  }
  return Math.floor(Math.random() * 2147483646) + 1;
}

function readUrlSeed() {
  try {
    const raw = new URLSearchParams(String(globalThis.location?.search || '')).get('seed');
    const n = Number(raw);
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : null;
  } catch {
    return null;
  }
}

function resolveRunSeed(seed) {
  const n = Number(seed);
  if (Number.isFinite(n) && n > 0) {
    nextRunSeedValue = Math.floor(n);
    return nextRunSeedValue;
  }
  if (nextRunSeedValue == null) nextRunSeedValue = nextRunSeed();
  return nextRunSeedValue;
}

function saveStorage() {
  try {
    return globalThis.localStorage || null;
  } catch {
    return null;
  }
}

function contentVersion() {
  return DATA.contentVersion || '';
}

function isInProgressRun() {
  return !!(state && state.journey && state.journey.started && !state.ending);
}

// 终局后禁止再买/炼/战斗等局内增强。
function assertRunMutable() {
  if (state && state.ending) {
    toast('本局已结束', 'bad');
    return false;
  }
  return true;
}

function confirmAbandon(message) {
  if (!isInProgressRun()) return true;
  try {
    return globalThis.confirm(message || '放弃当前局？') === true;
  } catch {
    return false;
  }
}

function clearSaveOnAbandon() {
  saveWriteBlockedUntilNewRun = true;
  if (!globalThis.LabSave) return;
  const result = LabSave.clear(saveStorage());
  lastSaveStatus = result;
}

// 完整动作/结算后的统一提交点。禁止在 recordEvent 半笔扣款中途保存、禁止每帧保存。
function persistSave() {
  if (skipPersistOnce) {
    skipPersistOnce = false;
    return;
  }
  if (!globalThis.LabSave) return;
  if (saveWriteBlockedUntilNewRun) return;
  if (!state || !state.journey || !state.journey.started) return;
  const result = LabSave.write(saveStorage(), state, contentVersion());
  lastSaveStatus = result;
  if (!result.ok && result.reason === 'storage_error') {
    bootSaveIssue = bootSaveIssue || 'storage_error';
  }
}

function commit() {
  draw();
  persistSave();
}

function resumePage() {
  if (!state || !state.journey) return 'hall';
  if (state.battle) return 'battle';
  if (state.reward) return 'reward';
  const node = currentNode();
  if (node && NodeActionRules.nodeTypes.includes(node.type) && state.prepFor !== node.id) return 'node-action';
  if (node) return 'prep';
  return state.journey.started ? 'map' : 'hall';
}

function continueRun() {
  if (!isInProgressRun()) return;
  showPage(resumePage());
  Sfx.click();
  draw();
}

function requestDifficultyChange(difficulty) {
  if (!confirmAbandon('修改难度将放弃当前局，确定？')) {
    skipPersistOnce = true;
    persistSave();
    return;
  }
  if (isInProgressRun()) clearSaveOnAbandon();
  state = fresh(difficulty);
  draw();
}

function bootFromSave() {
  if (!globalThis.LabSave) {
    bootSaveIssue = 'storage_error';
    state = fresh();
    return;
  }
  const result = LabSave.read(saveStorage(), contentVersion());
  if (result.ok && result.state) {
    state = result.state;
    bootSaveIssue = null;
    saveWriteBlockedUntilNewRun = false;
    return;
  }
  if (result.reason === 'empty') {
    bootSaveIssue = null;
    saveWriteBlockedUntilNewRun = false;
    state = fresh();
    return;
  }
  if (result.reason === 'storage_error') {
    bootSaveIssue = 'storage_error';
    saveWriteBlockedUntilNewRun = false;
    state = fresh();
    return;
  }
  // 坏档 / 版本不匹配：保留原文，不覆盖；UI 显示无法读取，由玩家明确重新开局。
  bootSaveIssue = 'unreadable';
  saveWriteBlockedUntilNewRun = true;
  state = fresh();
}

let state;

function fresh(difficulty = 'normal', seed) {
  const runSeed = resolveRunSeed(seed);
  const thoughts = RunRules.actionPointsPerTurn(READY.soul);
  const qiMax = RunRules.essenceMax(READY.cultivation, READY.aptitude, {
    essenceBase: DATA.aptitude.essence_base,
    aptitudeFactor: DATA.aptitude.aptitude_factor,
    cultivationFactor: DATA.aptitude.cultivation_factor,
  });
  const enemyById = Object.fromEntries(DATA.enemies.map((enemy) => [enemy.id, enemy]));
  const graph = RunFlow.generateGraph({
    seed: runSeed,
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
    // seed 必须写在 READY 展开之后：禁止 READY.seed 覆盖已选择种子。
    ...READY, seed: runSeed, owned: { ...READY.owned }, wild: { ...READY.wild }, equipped: [], battle: null, qiMax, qi: qiMax,
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

bootFromSave();

const $ = (s) => document.querySelector(s);

function toast(msg, kind = '') {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'on ' + kind;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (t.className = kind), 2400);
}

/* Battle feedback layer — wired to combat events (L0 UX Sprint). */
const BattleFx = {
  host(sel) {
    return document.querySelector(sel) || document.querySelector('.foe') || document.querySelector('#foe-box');
  },
  floatOn(el, amount, kind = 'dmg') {
    if (!el || !Number.isFinite(Number(amount)) || Number(amount) === 0) return;
    const host = el.closest?.('.foe') || el.closest?.('.enemy-actor') || el.parentElement || el;
    if (!host) return;
    if (getComputedStyle(host).position === 'static') host.style.position = 'relative';
    const node = document.createElement('span');
    const abs = Math.abs(Number(amount));
    const text = kind === 'heal' || kind === 'qi' || kind === 'block'
      ? `+${abs}`
      : kind === 'tag'
        ? String(amount)
        : `-${abs}`;
    node.className = `float-dmg${kind === 'heal' || kind === 'qi' || kind === 'block' ? ' heal' : ''}${kind === 'tag' || kind === 'counter' || kind === 'rule' ? ' fx-tag' : ''}`;
    node.textContent = text;
    if (kind === 'counter') node.textContent = '反制';
    if (kind === 'rule') node.textContent = String(amount);
    host.appendChild(node);
    setTimeout(() => node.remove(), 760);
  },
  pulse(el) {
    const target = el || document.querySelector('.foe img') || document.querySelector('.foe .fn') || document.querySelector('.foe .hpline i');
    if (!target) return;
    target.classList.remove('dmg-pop');
    void target.offsetWidth;
    target.classList.add('dmg-pop');
    setTimeout(() => target.classList.remove('dmg-pop'), 560);
  },
  shakeBox() {
    const box = document.querySelector('#foe-box');
    if (!box) return;
    box.classList.add('hit');
    setTimeout(() => box.classList.remove('hit'), 300);
  },
  pulsePlayerPool(id) {
    const el = document.querySelector(`#${id}`) || document.querySelector(`.pool.${id === 'hud-blood' ? 'blood' : id === 'hud-qi' ? 'qi' : ''}`);
    const node = el || document.querySelector('#hud')?.querySelector('.pool.blood, .pool.qi');
    if (!node) return;
    node.classList.remove('dmg-pop');
    void node.offsetWidth;
    node.classList.add('dmg-pop');
    setTimeout(() => node.classList.remove('dmg-pop'), 560);
  },
  damage(amount) {
    this.floatOn(this.host('.foe img') || this.host('.foe'), amount, 'dmg');
    this.pulse();
    this.shakeBox();
    Sfx.hit();
  },
  selfDamage(amount) {
    this.floatOn(document.querySelector('#hud-blood') || document.querySelector('#hud'), amount, 'dmg');
    this.pulsePlayerPool('hud-blood');
    Sfx.hurt?.();
  },
  heal(amount) {
    this.floatOn(document.querySelector('#hud-blood') || document.querySelector('#hud'), amount, 'heal');
    this.pulsePlayerPool('hud-blood');
  },
  qi(amount) {
    this.floatOn(document.querySelector('#hud-qi') || document.querySelector('#hud'), amount, 'qi');
    this.pulsePlayerPool('hud-qi');
  },
  block(amount) {
    this.floatOn(this.host('.foe') || this.host('#foe-box'), amount, 'block');
  },
  shieldHit(amount) {
    this.floatOn(this.host('.foe') || this.host('#foe-box'), amount, 'block');
    this.pulse();
  },
  shieldBreak() {
    this.floatOn(this.host('.foe') || this.host('#foe-box'), '破盾', 'rule');
    this.pulse();
    this.shakeBox();
  },
  essenceBurn(amount) {
    this.qi(-Math.abs(Number(amount) || 0));
    toast(`真元被焚 · -${Math.abs(Number(amount) || 0)}`, 'bad');
  },
  countered(label) {
    this.floatOn(this.host('.foe') || this.host('#foe-box'), '反制', 'counter');
    this.shakeBox();
    Sfx.hit();
  },
  counterRevealed() {
    document.querySelectorAll('.forewarn, .chip.live, [data-counter-reveal]').forEach((el) => {
      el.classList.add('fx-reveal');
      setTimeout(() => el.classList.remove('fx-reveal'), 900);
    });
    const intel = document.querySelector('.intel-lines') || document.querySelector('.chips');
    if (intel) {
      intel.classList.add('fx-reveal');
      setTimeout(() => intel.classList.remove('fx-reveal'), 900);
    }
  },
  suppress() {
    document.querySelectorAll('.chip.live, .forewarn, [data-counter-badge]').forEach((el) => {
      el.classList.add('fx-suppress');
      setTimeout(() => el.classList.remove('fx-suppress'), 1200);
    });
  },
};

function pulseDamage(el) {
  BattleFx.pulse(el);
}

function floatDamage(amount, heal = false) {
  BattleFx.floatOn(BattleFx.host('.foe img') || BattleFx.host('.foe'), amount, heal ? 'heal' : 'dmg');
}

function floatNumber(targetEl, amount, kind = 'dmg') {
  if (!targetEl) return;
  BattleFx.floatOn(targetEl, amount, kind === 'heal' ? 'heal' : kind === 'counter' ? 'counter' : 'dmg');
  targetEl.classList.remove('hit');
  void targetEl.offsetWidth;
  targetEl.classList.add('hit');
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
      const rawDamage = Number(it.damage || 0)
        + (it.tag === 'charge' ? Math.max(0, Number(enemy.ironRage || 0)) : 0)
        + (enemy.currentCounter === 'draw_light' && !enemy.counterRevealed ? 0 : 0);
      /* 吸收 MVP：读对+做对减伤 / 逐光未用光 +3 */
      const core = globalThis.CombatCore;
      let handledCut = 0;
      if (core?.previewEnemyDamage) {
        const pv = core.previewEnemyDamage(enemy, it, {
          usedLight: !!b.usedLightThisTurn,
          usedDefense: !!b.usedDefenseThisTurn,
          attacked: !!b.attackedThisTurn,
        });
        handledCut = Math.max(0, Number(pv.base || rawDamage) - Number(pv.projected || pv.base || rawDamage));
      }
      const weaken = Number(enemy.intentWeaken || 0);
      let damage = RunRules.weakenedDamage(rawDamage - handledCut, weaken);
      if (enemy.currentCounter === 'draw_light' && !enemy.counterRevealed && !b.usedLightThisTurn) {
        damage += 3;
        b.log.push(`${prefix}逐光 · <span class="dmg">伤害 +3</span>（本回合未用光道）`);
      }
      if (handledCut > 0) {
        b.log.push(`${prefix}反制读对+做对 · 减伤 ${handledCut}`);
      }
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
      if (absorbed > 0) BattleFx.shieldHit(absorbed);
      if (taken > 0) BattleFx.selfDamage(taken);
      else Sfx.hurt();
      b.lastBlow = {
        attacker: enemy.name,
        label: it.label,
        damage: taken || damage,
        turn: b.turn,
        absorbed,
      };
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
      BattleFx.essenceBurn(it.essence_burn);
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

function buildDeathReport(b) {
  const lines = Array.isArray(b.log) ? b.log : [];
  const plain = lines.map((s) => String(s).replace(/<[^>]+>/g, ''));
  const last3 = plain.slice(-3);
  const blow = b.lastBlow || null;
  const counter = b.lastCounter || null;
  const parts = [];
  parts.push(blow
    ? `败因：${blow.attacker} · ${blow.label}（伤 ${blow.damage}${blow.absorbed ? `，护体挡下 ${blow.absorbed}` : ''}）`
    : `败因：资源耗尽于第 ${b.turn || 0} 回合`);
  if (counter) parts.push(`关键失误：「${counter.label}」曾被「${counter.counterId}」反制吞掉（第 ${counter.turn} 回合）`);
  if (last3.length) parts.push(`最后三回合：${last3.join(' / ')}`);
  return { lastBlow: blow, lastCounter: counter, last3, detail: parts.join('；') };
}

function openBattleOutcome() {
  const b = state.battle;
  if (!b || !b.over) return;
  // 防重复结算：奖励已开出或已终局时不得再次 roll loot / 重写 ending。
  if (state.ending) return;
  if (b.over === '胜' && state.reward) return;
  const outcome = RunFlow.endingOutcomeFromBattleOver(b.over);
  if (b.over === '败') {
    const lifeDeath = b.deathCause === 'life_cost';
    const soulDeath = b.deathCause === 'soul';
    const report = buildDeathReport(b);
    state.ending = {
      title: lifeDeath ? '寿元耗尽' : soulDeath ? '魂魄耗尽' : '气血耗尽',
      detail: (lifeDeath
        ? '寿元归零，败于当前遭遇。'
        : soulDeath
          ? '你的魂魄被抽干，败于当前遭遇。'
          : '气血耗尽，败于当前遭遇。') + report.detail,
      turn: b.turn,
      outcome: 'defeat',
      deathReport: report,
    };
    state.battle = null;
    showPage('ending');
    Sfx.lose();
  } else if (outcome === 'victory') {
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
    BattleFx.heal(plan.heal);
  }
  if (plan.block) {
    b.block += plan.block;
    b.log.push(`<b>${label}</b> · 护体 +${plan.block}`);
    BattleFx.block(plan.block);
  }
  if (plan.damage) {
    /* 吸收 MVP：直接攻击过反制（迎击/铁皮吞伤、压制、handled 减伤） */
    const core = globalThis.CombatCore;
    const asStrike = Number(plan.damage) > 0;
    if (core?.resolveDirectStrike && asStrike) {
      const coreEnemy = core.toCoreEnemy(target, globalThis.MVP_CONTENT?.enemyProfiles);
      const res = core.resolveDirectStrike(coreEnemy, {
        damage: plan.damage,
        bypassCounter: !!plan.bypassCounter,
        suppressCounter: !!plan.suppressCounter,
        attacked: true,
      });
      target.hp = res.enemy.hp;
      target.currentCounter = res.enemy.currentCounter;
      target.counterDisabled = res.enemy.counterDisabled;
      target.suppressed = res.enemy.suppressed;
      target.ironRage = res.enemy.ironRage;
      target.counterBroke = res.enemy.counterBroke;
      if (plan.suppressCounter || res.suppressed) {
        BattleFx.suppress();
        b.log.push(`<b>${label}</b> · <span class="heal">镇压</span> · 反制规则被压下`);
      }
      if (res.selfDamage) {
        state.blood = Math.max(0, state.blood - res.selfDamage);
        b.log.push(`迎击反噬 · <span class="dmg">气血 -${res.selfDamage}</span>`);
        BattleFx.selfDamage(res.selfDamage);
      }
      if (res.swallowed) {
        b.log.push(`<b>${target.name}</b> · <b>${label}</b> 被反制吞掉（${res.counterId}）`);
        b.lastCounter = { label, counterId: res.counterId, turn: b.turn };
        BattleFx.countered(label);
      } else if (res.damage > 0) {
        b.log.push(`<b>${target.name}</b> · <b>${label}</b> 命中，<span class="dmg">伤 ${res.damage}</span>`);
        BattleFx.damage(res.damage);
      } else if (res.counterBroke || target.counterBroke) {
        b.log.push(`<b>${target.name}</b> · <b>${label}</b> · <span class="heal">破盾/破反</span>`);
        BattleFx.shieldBreak();
      } else {
        b.log.push(`<b>${target.name}</b> · <b>${label}</b> 未造成伤害`);
        BattleFx.pulse();
      }
    } else {
      target.hp -= plan.damage;
      b.log.push(`<b>${target.name}</b> · <b>${label}</b> 命中，<span class="dmg">伤 ${plan.damage}</span>`);
      BattleFx.damage(plan.damage);
    }
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
    if (!assertRunMutable()) return;
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
    if (!assertRunMutable()) return;
    const r = GuRules.liveRecipes(DATA.recipes).find((x) => x.id === recipeId);
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
    // 合炼吃掉组件后，卸下缺件杀招，避免幽灵可点。
    {
      const invalid = [];
      for (const move of DATA.killMoves) {
        if (!state.equipped.includes(move.id)) continue;
        if (!GuRules.killMoveRecipeInstances(move, state.owned, {}, {}).every(Boolean)) invalid.push(move);
      }
      if (invalid.length) {
        const invalidIds = new Set(invalid.map((move) => move.id));
        state.equipped = state.equipped.filter((id) => !invalidIds.has(id));
      }
    }
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
    if (i >= 0) { state.equipped.splice(i, 1); Sfx.click(); draw(); return; }
    if (state.equipped.length >= 3) return toast('杀招槽已满（三）', 'bad');
    const move = DATA.killMoves.find((m) => m.id === id);
    if (!move) return toast('未找到该杀招', 'bad');
    // 组件按实例占用校验：重复配方不能用「持有>0」蒙混。
    const instances = GuRules.killMoveRecipeInstances(move, state.owned, {}, {});
    if (instances.some((x) => !x)) return toast('组件不足 · 无法装备该杀招', 'bad');
    state.equipped.push(id);
    Sfx.click();
    draw();
  },

  startRun(difficulty = 'normal') {
    if (!confirmAbandon('开始新局将放弃当前局，确定？')) {
      skipPersistOnce = true;
      return;
    }
    saveWriteBlockedUntilNewRun = false;
    bootSaveIssue = bootSaveIssue === 'unreadable' ? null : bootSaveIssue;
    // ?seed= 只影响明确的新局；继续不会走到这里。
    state = fresh(difficulty, readUrlSeed());
    state.journey.started = true;
    nextRunSeedValue = null;
    showPage('map');
    Sfx.click();
    toast(`已开局 · ${DATA.flow.difficulties[state.journey.difficulty].label}`);
  },

  chooseNode(nodeId) {
    if (state.ending) return;
    if (state.battle && !state.battle.over) return toast('战斗尚未结算', 'bad');
    const node = nodeById(nodeId);
    if (!RunFlow.canSelectNode(state.journey.availableNodeIds, nodeId) || !node) return;
    const enemyError = RunFlow.combatNodeEnemyError(node);
    if (enemyError) {
      // 内容错误：不跳关、不伪造「行程已尽」
      return toast('内容错误 · 该节点缺少敌人数据', 'bad');
    }
    if (!NODE_ACTION_TYPES.includes(node.type)) {
      const missing = (node.enemyIds || []).filter((id) => !DATA.enemies.find((x) => x.id === id));
      if (missing.length) return toast('内容错误 · 未找到敌人数据', 'bad');
    }
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
    if (!assertRunMutable()) return;
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
    if (!assertRunMutable()) return;
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
    const result = RunFlow.journeyAdvanceResult({
      nodeId: state.journey.nodeId,
      node: currentNode(),
      started: !!state.journey.started,
      alreadyEnded: !!state.ending,
      hasUnfinishedBattle: !!(state.battle && !state.battle.over),
    });
    if (!result.ok) {
      if (result.kind === 'battle_unfinished') return toast('战斗尚未结算', 'bad');
      if (result.kind === 'content_error') {
        const graphErr = RunFlow.graphContentError(state.journey?.graph);
        return toast(graphErr === 'empty_graph'
          ? '内容错误 · 节点图为空'
          : '内容错误 · 节点数据缺失', 'bad');
      }
      // reentry / not_started / already_ended：静默不重复结算
      return;
    }
    const node = currentNode();
    if (!state.journey.completed.includes(node.id)) state.journey.completed.push(node.id);
    state.journal.unshift(`${node.name} · ${reason}`);
    recordEvent('complete_node', { graph_progress: [...state.journey.completed] }, 'node_completed', [node.id]);
    state.prepFor = null;
    state.journey.nodeId = null;
    state.journey.availableNodeIds = result.kind === 'continue' ? [...result.nextIds] : [];
    state.battle = null;
    state.reward = null;
    if (result.kind === 'victory_ending') {
      return act.endJourney(result.title || '五段行程已走完', 'victory');
    }
    showPage('map');
    Sfx.click();
    draw();
  },

  advanceJourney(reason) {
    return act.completeCurrentNode(reason);
  },

  // outcome 必须显式传入；null/缺省视为非法，不得默认成 victory。
  endJourney(title, outcome) {
    if (state.ending) return;
    if (outcome !== 'victory' && outcome !== 'defeat') return;
    state.ending = {
      title,
      detail: state.journal[0] || '本局没有产生可归因记录。',
      turn: state.battle ? state.battle.turn : 0,
      outcome,
    };
    state.battle = null;
    showPage('ending');
    if (outcome === 'victory') Sfx.win();
    else Sfx.lose();
    draw();
  },

  restartRun(difficulty = state.journey?.difficulty || 'normal') {
    if (!confirmAbandon('重开将放弃当前局，确定？')) {
      skipPersistOnce = true;
      return;
    }
    clearSaveOnAbandon();
    nextRunSeedValue = null;
    state = fresh(difficulty);
    showPage('hall');
    Sfx.click();
    draw();
    toast('已重开本局');
  },

  startBattle(enemyIds, nodeId = null) {
    if (!assertRunMutable()) return;
    const ids = Array.isArray(enemyIds) ? enemyIds : [enemyIds];
    const picked = ids.map((id) => DATA.enemies.find((x) => x.id === id)).filter(Boolean);
    if (!picked.length) return toast('内容错误 · 未找到敌人数据', 'bad');
    const enemies = picked.map((e) => {
      const core = (globalThis.CombatCore?.toCoreEnemy
        ? globalThis.CombatCore.toCoreEnemy({ ...e, hpMax: e.hp }, globalThis.MVP_CONTENT?.enemyProfiles)
        : null) || {};
      return {
        ...e,
        ...core,
        hpMax: e.hp,
        hp: e.hp,
        revealed: false,
        counterRevealed: !!core.counterRevealed,
        currentCounter: core.currentCounter || '',
        flags: {},
        lastFired: {},
        phaseIndex: undefined,
        phaseTotal: 0,
        enemyIntent: core.currentIntent || null,
        intentWeaken: 0,
      };
    });
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
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target) return openBattleOutcome();
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');
    if (state.thought < 1) return toast('念头不足', 'bad');

    state.thought -= 1;
    b.actionsUsed += 1;
    // 直接攻击会被生效中的反击吞掉（与 useMove/useGu 同口径；代价已付，不造成伤害）。
    const hit = liveReactions(target)[0];
    if (hit) {
      if (hit.counter_status === 'bound') target.flags.enemy_bound = true;
      if (hit.counter_status === 'guarded') target.flags.guarded = true;
      b.log.push(`<b>${target.name}</b> · <b>拳脚</b> 被「${hit.label}」吞掉，<span class="dmg">未造成伤害</span>`);
      b.log.push(`敌方转入「${statusZh(hit.counter_status)}」，该反击此后不再预警`);
      Sfx.fail();
      finishPlayerAction(b);
      return;
    }
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

  /** MVP 逆息：真元锁死时 1 念头 · 气血-2 · 真元+3 */
  exhaust() {
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    if (state.thought < 1) return toast('念头不足', 'bad');
    if (b.exhaustUsedThisTurn) return toast('本回合已逆息', 'bad');
    if (b.exhaustCooldown > 0) return toast(`逆息冷却 ${b.exhaustCooldown} 回合`, 'bad');
    const roster = currentCombatRoster(b.guUsedThisTurn, b.guSealed);
    const damageGu = roster.filter((g) => g.battleEffect?.kind === 'strike' || Number(g.battleEffect?.amount || 0) > 0);
    const qiLocked = damageGu.length > 0 && !damageGu.some((g) => state.qi >= Number(g.trueQiCost || 0));
    if (!qiLocked) return toast('未陷入真元枯竭，无须逆息', 'bad');
    state.thought -= 1;
    state.blood = Math.max(0, state.blood - 2);
    state.qi = Math.min(state.qiMax, state.qi + 3);
    b.exhaustUsedThisTurn = true;
    b.exhaustCooldown = 2;
    b.actionsUsed += 1;
    b.log.push('逆息 · <span class="dmg">气血 -2</span> · 真元 +3');
    BattleFx.selfDamage(2);
    BattleFx.qi(3);
    BattleFx.selfDamage(2);
    BattleFx.qi(3);
    Sfx.click();
    draw();
  },

  observe() {
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target || target.revealed) return;
    if (b.actionsUsed >= b.actionLimit) return toast('本回合行动数已尽', 'bad');
    if (state.thought < 1) return toast('念头不足', 'bad');
    state.thought -= 1;
    b.actionsUsed += 1;
    target.revealed = true;
    target.counterRevealed = true;
    if (globalThis.CombatCore?.revealCounter) {
      // revealCounter(enemy) 只收当前敌兵；传 state/coreEnemy 会把 currentCounter 写回 undefined。
      const after = globalThis.CombatCore.revealCounter(target);
      target.knownCounters = after.knownCounters;
    }
    if (typeof Sfx !== 'undefined' && Sfx.success) Sfx.success();
    if (typeof BattleFx !== 'undefined' && BattleFx.counterRevealed) BattleFx.counterRevealed();
    b.log.push(`你凝神细察 <b>${target.name}</b>，看清了它的线索与反击。<span class="heal">已看破</span>`);
    toast('观察揭示反击 · 已看破', 'good');
    finishPlayerAction(b);
  },

  useMove(id) {
    if (!assertRunMutable()) return;
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
    // L0 2026-09-25：门禁读组件合成权威，不再读预制 m.effect。
    const gate = GuRules.killMoveGateMissReason(m, GU_BY_ID, {
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
    if (GuRules.killMoveIsDirectStrike(m, GU_BY_ID, {
      school: m.tag,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    })) {
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

    // L0 2026-09-22：杀招 = 组件按 recipe 顺序合成，不再消费预制 effect/damage。
    const plan = GuRules.killMoveEffectPlan(m, GU_BY_ID, {
      school: m.tag,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    applyEffectPlan(b, target, plan, m.label);
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
    if (!assertRunMutable()) return;
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
      lowRankException: !!(state.lowRankGu && state.lowRankGu[gu.id]),
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
    if (!assertRunMutable()) return;
    const offer = DATA.shopOffers.find((o) => o.id === offerId);
    if (!offer || !canBuyOffer(offer)) return;
    const cost = offerCost(offer);
    if (cost > state.stones) return toast('元石不足', 'bad');
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
    if (!assertRunMutable()) return;
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
    if (!assertRunMutable()) return;
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
    if (!assertRunMutable()) return;
    const gu = GU_BY_ID[guId];
    if (!gu || Number(state.owned[guId] || 0) <= 0) return toast('没有可卖出的该蛊', 'bad');
    const price = RunFlow.sellValue(gu.value);
    state.owned[guId] -= 1;
    state.stones += price;
    const invalid = [];
    for (const move of DATA.killMoves) {
      if (!state.equipped.includes(move.id)) continue;
      const enough = GuRules.killMoveRecipeInstances(move, state.owned, {}, {}).every(Boolean);
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
    if (!assertRunMutable()) return;
    const reward = state.reward;
    if (!reward || !(reward.guChoices || []).includes(guId)) return;
    state.owned[guId] = (state.owned[guId] || 0) + 1;
    state.journal.unshift(`战后三选一 · ${(GU_BY_ID[guId] || {}).name || guId}`);
    recordEvent('battle_loot', { owned: { ...state.owned }, loot_pity: state.lootPity }, 'loot_gu_gained', [guId]);
    // 领取后立刻失效 reward，防重复点击追加
    state.reward = null;
    Sfx.success();
    act.openPrep();
  },

  continueReward() {
    if (!assertRunMutable()) return;
    const reward = state.reward;
    if (!reward) return showPage('map');
    if ((reward.guChoices || []).length) return toast('请先选择一只蛊虫', 'bad');
    state.reward = null;
    act.openPrep();
  },

  endTurn() {
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    Sfx.click();
    b.log.push('你结束本回合。');
    if (enemyTurn(b)) { openBattleOutcome(); return; }
    b.usedLightThisTurn = false;
    b.attackedThisTurn = false;
    b.usedDefenseThisTurn = false;
    b.exhaustUsedThisTurn = false;
    if (b.exhaustCooldown > 0) b.exhaustCooldown -= 1;
    draw();
  },

  endBattle() {
    const b = state.battle;
    const mode = RunFlow.battleLeaveMode(b);
    if (mode === 'settle') return openBattleOutcome();
    if (mode === 'no_battle') return showPage('map');
    // view_only：离开战斗页只是视图切换，必须保留遭遇，禁止付费逃跑/丢遭遇。
    showPage('map');
    Sfx.click();
    draw();
  },
};

// 统一提交边界：每个公开 act 方法终止后保存一次。
// _pickIntent 等内部方法不包装，避免战斗中途/半笔结算保存。
for (const actKey of Object.keys(act)) {
  if (actKey.startsWith('_')) continue;
  const rawAct = act[actKey];
  if (typeof rawAct !== 'function') continue;
  act[actKey] = function wrappedAct(...args) {
    const result = rawAct.apply(this, args);
    commit();
    return result;
  };
}

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
if (/(?:\?|&)debug=1(?:&|$)/.test(String(location.search || ''))) {
  document.querySelector('[data-tab="cover"]')?.removeAttribute('hidden');
}
tabs.forEach((b) => b.addEventListener('click', () => {
  showPage(b.dataset.tab);
  Sfx.click();
}));
$('#reset').addEventListener('click', () => act.restartRun());
document.addEventListener('pointerdown', () => Sfx.click(), { once: true });

draw();
showPage(resumePage());
// 只读快照入口：供 tests/helpers/lab_browser.mjs 读取完整可序列化 state。
// 不是改状态 / 调 act 的捷径。
globalThis.__labSnapshot = function labSnapshot() {
  return JSON.parse(JSON.stringify(state));
};
globalThis.__labBootInfo = function labBootInfo() {
  return {
    bootSaveIssue,
    lastSaveStatus: { ...lastSaveStatus },
    contentVersion: contentVersion(),
    inProgress: isInProgressRun(),
  };
};
document.documentElement.dataset.ready = '1';
