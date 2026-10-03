// 状态与主循环。普通脚本：全局 state / act；判定走 rules.js / run_rules.js，面板来自 alchemy.js / killmove.js / battle.js。

const READY = {
  seed: DATA.runSeed ?? 1,
  cultivation: 1,
  cultivationStage: 0,
  school: DATA.loot.school,
  stones: 3, blood: 10, bloodMax: 10,
  lifeTime: 60,
  soul: 1, soulMax: 1,
  aptitude: 'bing', stage: 'one',
  owned: {
    moonlight_gu: 1, small_light_gu: 1, stone_shell_gu: 1, vitality_leaf_gu: 2,
    jade_skin_gu: 1, white_boar_strength_gu: 1,
  },
  wild: {
    small_light_gu: 2,
  },
};

// 需要走节点动作页的节点类型（险地 / 市集 / 野蛊 / 休整 / 静修 / 异闻）；由 NodeActionRules 单点定义，
// 避免两处分叉。必须声明在下面的 `let state = fresh()` 之前：fresh 生成固定图时要过滤模板池。
const NODE_ACTION_TYPES = NodeActionRules.nodeTypes;

// —— 种子与存档提交边界（W1）——
// READY.seed 只是模板残留，不得覆盖已选择/已存档种子。
// ?seed= 只服务「明确的新局」；继续始终优先存档里的 seed。
let nextRunSeedValue = null;
let saveWriteBlockedUntilNewRun = false;
let skipPersistOnce = false;
let bootSaveIssue = null; // null | 'outdated' | 'unreadable' | 'storage_error'
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
  return DATA.saveCompatibilityVersion || DATA.contentVersion || '';
}

function compatibleSaveVersions() {
  return Array.isArray(DATA.compatibleContentVersions) ? DATA.compatibleContentVersions : [];
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

// 存档 JSON + localStorage.setItem 是同步长任务，放在点击帧会把 1% low 打穿。
// 合并到下一宏任务：同一帧多次 commit 只写一次；测试 click 后有 sleep，仍能读到档。
let persistScheduled = false;
function schedulePersistSave() {
  if (persistScheduled) return;
  persistScheduled = true;
  setTimeout(() => {
    persistScheduled = false;
    persistSave();
  }, 0);
}

function commit() {
  draw();
  schedulePersistSave();
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
  const result = LabSave.read(saveStorage(), contentVersion(), compatibleSaveVersions());
  if (result.ok && result.state) {
    state = result.state;
    bootSaveIssue = null;
    saveWriteBlockedUntilNewRun = false;
    if (result.legacyContentVersion) {
      const migrated = LabSave.write(saveStorage(), state, contentVersion());
      if (!migrated.ok) lastSaveStatus = migrated;
    }
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
  // 坏档 / 版本不匹配：保留原文，不覆盖；由玩家明确重新开局。
  bootSaveIssue = result.reason === 'content_mismatch' ? 'outdated' : 'unreadable';
  saveWriteBlockedUntilNewRun = true;
  state = fresh();
}

let state;

function fresh(difficulty = 'normal', seed) {
  const runSeed = resolveRunSeed(seed);
  const thoughts = HumanRules.BASELINE.thoughtMax;
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
    events: DATA.events,
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
    ...READY, seed: runSeed, owned: { ...READY.owned }, wild: { ...READY.wild }, equipped: [], customMoveRecipes: [], killmoveDraft: [], battle: null, qiMax, qi: qiMax,
    thought: thoughts, thoughtMax: thoughts, modifierLedger: [],
    journey, prepFor: null, reward: null, ending: null, shopSold: [], restUsed: false, journal: [],
    page: 'hall', lootPity: 0,
    globalCodexIds: [], knownFacts: [],
    eventLog: [{
      id: 'event_0000', time: 0, nodeId: journey.nodeId, action: 'run_started',
      reason: 'new_run',
      after: { stones: READY.stones, owned: { ...READY.owned }, wild: { ...READY.wild } },
    }],
  };
}

function archiveRun(ending) {
  if (!globalThis.LabSave?.appendArchive) return { ok: false, reason: 'archive_unavailable' };
  const now = new Date();
  const visitedIds = [...(state.journey.completed || [])];
  const currentId = state.journey.nodeId;
  if (currentId && !visitedIds.includes(currentId)) visitedIds.push(currentId);
  const trail = visitedIds
    .map((id) => RunFlow.nodeById(state.journey.graph, id))
    .filter(Boolean)
    .map((node) => ({ segment: node.segment, type: node.type, name: node.name }));
  const record = {
    id: `${now.toISOString()}-${state.seed}`,
    endedAt: now.toISOString(),
    seed: state.seed,
    difficulty: state.journey.difficulty,
    outcome: ending.outcome,
    title: ending.title,
    detail: ending.detail,
    completedNodes: state.journey.completed.length,
    visitedNodes: trail.length,
    totalNodes: state.journey.graph.prepPerSegment * state.journey.graph.segmentCount
      + state.journey.graph.segmentCount,
    rank: RunFlow.stageLabel(state.cultivation, state.cultivationStage),
    trail,
    journal: (state.journal || []).slice(0, 12),
  };
  return LabSave.appendArchive(saveStorage(), record);
}

function saveEndingArchive(ending) {
  if (ending.archiveSaved !== undefined) return { ok: ending.archiveSaved };
  const result = archiveRun(ending);
  ending.archiveSaved = result.ok;
  ending.archiveIssue = result.ok ? '' : result.reason;
  return result;
}

bootFromSave();

const $ = (s) => document.querySelector(s);

function toast(msg, kind = '') {
  const t = $('#toast');
  // CSS 里的 top 是常量估算；HUD/行程脊在窄屏会换行变高，按实际底边定位才不压页签。
  const spineBottom = $('#spine')?.getBoundingClientRect().bottom;
  if (Number.isFinite(spineBottom) && spineBottom > 0) t.style.top = `${Math.round(spineBottom + 12)}px`;
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
    // .foe / .enemy-actor 在 CSS 常驻 relative；此处只补意外宿主，避免热路径 getComputedStyle。
    if (!host.style.position) host.style.position = 'relative';
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
    window.Motion?.float(node);
    setTimeout(() => node.remove(), 760);
  },
  pulse(el) {
    const target = el || document.querySelector('.foe img') || document.querySelector('.foe .fn') || document.querySelector('.foe .hpline i');
    if (!target) return;
    // 用动画重启代替 void offsetWidth 强制 reflow（布局抖动在战斗热路径上会掉帧）。
    target.classList.remove('dmg-pop');
    requestAnimationFrame(() => target.classList.add('dmg-pop'));
    setTimeout(() => target.classList.remove('dmg-pop'), 560);
  },
  shakeBox() {
    const box = document.querySelector('#foe-box');
    if (!box) return;
    box.classList.add('hit');
    window.Motion?.shake(box);
    setTimeout(() => box.classList.remove('hit'), 300);
  },
  pulsePlayerPool(id) {
    const el = document.querySelector(`#${id}`) || document.querySelector(`.pool.${id === 'hud-blood' ? 'blood' : id === 'hud-qi' ? 'qi' : ''}`);
    const node = el || document.querySelector('#hud')?.querySelector('.pool.blood, .pool.qi');
    if (!node) return;
    node.classList.remove('dmg-pop');
    requestAnimationFrame(() => node.classList.add('dmg-pop'));
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
// 敌人补充语义只作缺省资料；不能覆盖主蛊的成本、价格和已投影战斗效果。
const GU_BY_ID = { ...(DATA.guSemanticsById || {}) };
for (const gu of DATA.gu) GU_BY_ID[gu.id] = { ...GU_BY_ID[gu.id], ...gu };

function recomputeQiMax() {
  state.qiMax = RunRules.essenceMax(state.cultivation, state.aptitude);
  state.qi = Math.min(state.qi, state.qiMax);
}

// 自定义只存组件；费用与效果每次由同一规则派生，不信任存档中的数值。
function currentKillMoves() {
  const custom = (Array.isArray(state.customMoveRecipes) ? state.customMoveRecipes : []).map(recipe => GuRules.composeKillMove(recipe, GU_BY_ID))
    .filter(result => result.ok).map(result => ({ ...result.move, custom: true }));
  return [...DATA.killMoves, ...custom];
}

function currentCombatRoster(usedInstances = {}, sealedInstances = {}) {
  return GuRules.combatRoster(DATA.gu, state.owned, {
    playerRank: state.cultivation,
    trueQi: state.qi,
    thought: state.thought,
    actionLimitReached: false,
    usedInstances,
    sealedInstances,
    healingLocked: state.leafRecoveryNodeId === state.journey?.nodeId,
    health: state.blood, healthMax: state.bloodMax,
  });
}

function rollVictoryLoot(battle) {
  const tier = RunRules.resolveBattleTier(battle.enemies);
  const layer = battle.layer || 1;
  const table = LootRules.layerTable(DATA.loot.tables, DATA.loot.pacingLayers, tier, layer);
  const tick = state.eventLog.length;
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
        discoveryPool: Object.values(DATA.loot.schoolPools).flat(),
        choiceCount: DATA.flow.rewardGuChoiceCount || 3,
        // P5 掉落派生：被击败敌人的装载蛊进入战利品候选（夺蛊=原著标准战利品语义）；
        // innate 敌人池空 → 流程与原表完全一致。
        carriedPool: (battle.enemies || []).flatMap((e) => e.guRefs || []),
      })
    : { guIds: [], rarity: '' };
  // L0 Phase 6：精英/Boss 至少塞进一个「新未来」候选（补组合/开杀招）
  let guChoices = guRoll.guIds || [];
  if (tier === 'elite' || tier === 'boss') {
    const newFuture = LootRules.newFutureGuIds({
      owned: state.owned,
      guById: GU_BY_ID,
      killMoves: DATA.killMovesEnabled ? currentKillMoves().filter(move => move.playable === true) : [],
      buildKits: GuRules.BUILD_KITS,
    });
    guChoices = LootRules.ensureNewFutureChoice(guChoices, newFuture, {
      seed: state.seed, tick, tier,
      byRarity: table?.gu_pool?.by_rarity || {},
    });
  }
  const stones = RunRules.battleStoneReward(tier, layer, DATA.battle.stoneRewards);
  const rewardCore = {
    stones,
    guChoices,
  };
  const valueKinds = LootRules.classifyReward(rewardCore, { guById: GU_BY_ID });
  return {
    stones,
    tier,
    layer,
    tick,
    guChoices,
    guRarity: guRoll.rarity || '',
    valueKinds,
    lootIdentity: tier === 'boss' ? 'new_future'
      : tier === 'elite' ? 'build_component'
        : 'economy_growth',
    lootPity: LootRules.nextLootPity(state.lootPity, guRoll.rarity, DATA.loot.pity),
  };
}

// HUD 数值变化时让对应数字弹一下（涨玉色 / 跌朱色；Motion 缺席时静默跳过，只读提示不阻塞）。
const hudPrevNum = {};
function hudNumFx(id, text) {
  const el = $(`#${id}`);
  if (!el) return;
  el.textContent = text;
  const prev = hudPrevNum[id];
  hudPrevNum[id] = text;
  if (prev === undefined || prev === text) return;
  const a = parseFloat(prev);
  const b = parseFloat(text);
  window.Motion?.hudNum(el, Number.isFinite(a) && Number.isFinite(b) && b !== a ? (b > a ? 1 : -1) : 0);
}

function hud() {
  const qiPct = Math.max(0, Math.min(100, (state.qi / Math.max(1, state.qiMax)) * 100));
  $('#hud-qi').style.width = qiPct + '%';
  hudNumFx('hud-qi-num', `${Math.round(state.qi)}/${state.qiMax}`);
  $('#hud-qi-meter').setAttribute('aria-valuemax', String(state.qiMax));
  $('#hud-qi-meter').setAttribute('aria-valuenow', String(Math.round(state.qi)));
  hudNumFx('hud-thought', String(state.thought));
  hudNumFx('hud-stone', String(state.stones));
  hudNumFx('hud-blood', String(state.blood));
  hudNumFx('hud-life', String(state.lifeTime));
  hudNumFx('hud-soul', `${state.soul}/${state.soulMax}`);
  const apt = { jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' }[state.aptitude];
  $('#hud-talent').textContent = `${apt} · ${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}`;
  document.body.dataset.runActive = state.journey.started ? 'true' : 'false';
  const progress = journeyProgress();
  const node = currentNode() || (state.ending ? progress.positionNode : null);
  const position = node || progress.positionNode;
  const segment = position ? `第 ${position.segment} 段 · ${segmentTitle(position.segment)}` : '五境修行';
  let context = '尚未开始修行';
  if (state.ending) {
    context = state.ending.outcome === 'victory' ? '修行有成 · 五境走尽' : '修行止步 · 败局已录';
  } else if (state.battle) {
    context = `${segment} · 交锋中 · 第 ${state.battle.turn} 回合`;
  } else if (state.reward) {
    context = `${segment} · 战后收获 · 选择蛊虫并整备`;
  } else if (node) {
    const isAction = NodeActionRules.nodeTypes.includes(node.type) && state.prepFor !== node.id;
    const phase = state.prepFor === node.id ? '整备中'
      : isAction ? '节点抉择' : state.page === 'battle' ? '迎战' : '择路前行';
    context = `${segment} · ${phase} · ${node.name}`;
  } else if (state.journey.started) {
    context = `${segment} · 选择下一站`;
  }
  $('#run-context').textContent = context;
  $('#run-progress').textContent = state.journey.started
    ? `行程 ${progress.visitedNodes} / ${progress.totalNodes} · ${DATA.flow.difficulties[state.journey.difficulty]?.label || '修行中'}`
    : `五境 · ${progress.totalNodes} 个必经节点`;
  $('#reset').hidden = !isInProgressRun();
}

function draw() {
  // 性能：只绘当前页 + HUD。showPage 切页时单独渲染目标页，避免每次动作重建全部面板。
  hud();
  updateSceneArt();
  renderJourneyPage(state.page);
  if (state.page === 'battle') renderBattle($('#panel-battle'));
  else if (state.page === 'cover') renderCover($('#panel-cover'));
  updateNavigation();
  syncDock();
}

function updateSceneArt() {
  const graph = state?.journey?.graph;
  const current = currentNode();
  const next = state?.journey?.availableNodeIds?.[0]
    ? RunFlow.nodeById(graph, state.journey.availableNodeIds[0])
    : null;
  const completed = state?.journey?.completed || [];
  const lastId = completed[completed.length - 1];
  const last = lastId ? RunFlow.nodeById(graph, lastId) : null;
  const segment = Number(current?.segment || next?.segment || last?.segment || 1);
  document.body.dataset.scene = String(Math.max(1, Math.min(5, segment)));
}

const aliveEnemies = (b) => b.enemies.filter((e) => e.hp > 0);
const targetOf = (b) => b.enemies.find((e) => e.id === b.targetId && e.hp > 0)
  || b.enemies.find((e) => e.hp > 0) || null;

function heldPlayerGuInstances() {
  return Object.entries(state.owned || {}).flatMap(([id, count]) =>
    Array.from({ length: Math.max(0, Math.floor(Number(count || 0))) }, (_, index) =>
      HumanRules.guInstance(id, index + 1)));
}

// 模拟在临时人类对象上，不改局内资源；预览和实际提交共用一个规则。
function bodyTrainingPreview(gu) {
  if (gu?.effect?.kind !== 'body_training') return { ok: false, reason: 'not_training_gu' };
  const human = HumanRules.actor({ id: 'body_training', rank: state.cultivation, guInstances: heldPlayerGuInstances() });
  human.modifierLedger = (state.modifierLedger || []).map(entry => ({ ...entry }));
  human.essence = state.qi;
  const result = HumanRules.trainBody(human, `${gu.id}::1`, {
    attribute: gu.effect.attribute, step: gu.effect.amount, cap: gu.effect.cap,
    cost: gu.trueQiCost, visitId: state.prepFor || 'preview',
  });
  const current = result.total - (result.ok ? result.gained : 0);
  const reason = !state.prepFor ? 'not_preparing'
    : state.stones < gu.feedingCost ? 'insufficient_stone' : result.reason;
  return { ...result, ok: result.ok && !reason, reason, current, human };
}

function leafProductionPreview(gu) {
  return GuRules.produceGu(gu, {
    owned: state.owned, playerRank: state.cultivation, trueQi: state.qi,
    visitId: state.prepFor, lastVisitId: state.leafProductionVisit,
  });
}

function consumeLeaf(gu) {
  const result = GuRules.consumeHealingGu(gu, {
    owned: state.owned, health: state.blood, healthMax: state.bloodMax,
    healingLocked: state.leafRecoveryNodeId === state.journey.nodeId,
  });
  if (!result.ok) return result;
  state.owned = result.owned;
  state.blood = result.health;
  state.leafRecoveryNodeId = state.journey.nodeId;
  recordEvent('consume_healing_gu', { owned: { ...state.owned }, health: state.blood,
    recovery_node_id: state.leafRecoveryNodeId }, 'leaf_consumed', [gu.id]);
  return result;
}

function startMaintainedGu(human, instanceId, gu, turn) {
  const effect = gu?.battleEffect;
  if (effect?.kind !== 'maintained') return { ok: false, reason: 'not_maintained' };
  return HumanRules.startMaintained(human, instanceId, {
    startCost: gu.trueQiCost,
    upkeepCost: effect.upkeep_qi,
    hitCost: effect.hit_qi || 0,
    defenseGroup: effect.defense_group,
    focusCost: effect.focus_cost || 0,
    turn,
    modifiers: (effect.modifiers || []).map((entry) => ({
      attribute: entry.attribute, amount: entry.amount,
      sourceEffectId: entry.effect_id,
    })),
  });
}

function refreshHumanControl(human) {
  for (const item of human.maintainedGu) {
    const effect = GU_BY_ID[item.instanceId.split('::')[0]]?.battleEffect;
    if (item.active && effect?.kind === 'maintained') item.focusCost = Number(effect.focus_cost || 0);
  }
  return HumanRules.refreshControl(human);
}

function receiveHumanHit(b, human, damage, owner) {
  // 续档的费用缓存跟随现行蛊定义，避免保留旧的收支相抵参数。
  for (const item of human.maintainedGu) {
    const effect = GU_BY_ID[item.instanceId.split('::')[0]]?.battleEffect;
    if (item.active && effect?.kind === 'maintained') item.hitCost = Number(effect.hit_qi || 0);
  }
  const result = HumanRules.receiveHit(human, damage);
  for (const event of result.events) {
    const gu = GU_BY_ID[event.instanceId.split('::')[0]];
    b.log.push(event.ok
      ? `${owner}以 <b>${gu?.name || event.instanceId}</b> 承击 · 真元 -${event.cost}`
      : `${owner}无法以 <b>${gu?.name || event.instanceId}</b> 承击 · 防护解除`);
  }
  return result;
}

function receivePlayerHit(b, damage) {
  if (!b.playerHuman) return { damage, absorbed: 0 };
  b.playerHuman.essence = state.qi;
  const result = receiveHumanHit(b, b.playerHuman, damage, '你');
  state.qi = b.playerHuman.essence;
  return result;
}

function pluginHumanPlan(b, enemy) {
  const human = enemy.human;
  const stone = human.guInstances.find((item) => item.definitionId === 'stone_shell_gu' && item.state === 'held');
  const canStone = stone && !stone.sealed
    && !human.maintainedGu.some((item) => item.instanceId === stone.instanceId && item.active)
    && !GuRules.activationReason(GU_BY_ID[stone.definitionId], {
      playerRank: human.rank, trueQi: human.essence, thought: human.thought,
      actionLimitReached: false,
    });
  const roll = RunRules.seededIndex(10, state.seed, `${b.nodeId}:${enemy.id}:action`, b.turn);
  if (canStone && roll < 7) {
    return { kind: 'gu', guInstanceId: stone.instanceId, guId: stone.definitionId, label: GU_BY_ID[stone.definitionId].name };
  }
  return { kind: 'basic_attack', label: '拳脚攻击' };
}

function resolvePluginHumanTurn(b, enemy) {
  const human = enemy.human;
  const plan = enemy.plannedAction || pluginHumanPlan(b, enemy);
  if (plan.kind === 'gu') {
    const gu = GU_BY_ID[plan.guId];
    const gate = GuRules.activationReason(gu, {
      playerRank: human.rank, trueQi: human.essence, thought: human.thought,
      actionLimitReached: false,
    });
    if (!gate) {
      const result = startMaintainedGu(human, plan.guInstanceId, gu, b.turn);
      if (result.ok) {
        human.thought -= gu.thoughtCost;
        b.log.push(`<b>${enemy.name}</b> 催动 <b>${gu.name}</b> · 真元 -${result.cost} · 操控 -${gu.thoughtCost}；防御 ${HumanRules.attribute(human, 'defense')}`);
        return;
      }
    }
    b.log.push(`<b>${enemy.name}</b> 原定催蛊失效，转为拳脚攻击`);
  }
  const strike = HumanRules.basicStrikePlan(human);
  const pending = enemy.pendingBasicAttack;
  if (strike.delayTurns > 0) {
    enemy.pendingBasicAttack = { damage: strike.damage, dueTurn: b.turn + strike.delayTurns };
    b.log.push(`<b>${enemy.name}</b> 石臂沉重 · 拳脚将在第 ${enemy.pendingBasicAttack.dueTurn} 回合落下`);
    if (!pending || pending.dueTurn > b.turn) return;
  } else {
    enemy.pendingBasicAttack = null;
  }
  const incoming = pending && pending.dueTurn <= b.turn ? pending.damage : strike.damage;
  const protection = receivePlayerHit(b, incoming);
  const damage = protection.damage;
  const blocked = Math.min(b.block, damage);
  b.block -= blocked;
  const absorbed = blocked + protection.absorbed;
  const taken = damage - blocked;
  state.blood -= taken;
  b.log.push(`<b>${enemy.name}</b> · 拳脚攻击，<span class="dmg">伤 ${taken}</span>${absorbed ? `（护体挡下 ${absorbed}）` : ''}`);
  b.lastBlow = { attacker: enemy.name, label: '拳脚攻击', damage: taken || damage, turn: b.turn, absorbed };
  if (absorbed > 0) BattleFx.shieldHit(absorbed);
  if (taken > 0) BattleFx.selfDamage(taken);
}

// 敌方回合 + 刻痕结算 + 真元回复 + 回合推进。返回 true 表示战斗已结束。
// 意图选取与冷却门禁见 rules.js（语义来自数据自带的 _phases_note）。
function enemyTurn(b) {
  for (const enemy of aliveEnemies(b)) {
    if (enemy.human) {
      resolvePluginHumanTurn(b, enemy);
      if (state.blood <= 0) break;
      continue;
    }
    const it = enemy.enemyIntent;
    const prefix = b.enemies.length > 1 ? `<b>${enemy.name}</b> · ` : '';
    if (!it) {
      b.log.push(`${prefix}蓄势不动，本回合不攻击`);
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
        if (b.playerHuman) HumanRules.stopMaintained(b.playerHuman, sealed.instanceId, 'sealed');
        b.log.push(`${prefix}<b>${sealed.name}</b> 被封印 ${b.guSealed[sealed.instanceId]} 回合`);
      } else {
        b.log.push(`${prefix}无可封印的蛊虫`);
      }
    }
    if (it.damage) {
      const rawDamage = Number(it.damage || 0)
        + (it.tag === 'charge' ? Math.max(0, Number(enemy.ironRage || 0)) : 0);
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
      const protection = receivePlayerHit(b, damage);
      const blocked = Math.min(b.block, protection.damage);
      b.block -= blocked;
      const absorbed = blocked + protection.absorbed;
      const taken = protection.damage - blocked;
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
      if (RunRules.soulDefeated(state.soul)) b.lastResourceBlow = {
        attacker: enemy.name, label: it.label, resource: 'soul', amount: it.soul_drain, turn: b.turn,
      };
      b.log.push(`${prefix}<span class="dmg">魂魄被抽 ${it.soul_drain}</span>`);
    }
    if (it.life_cost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, it.life_cost);
      if (RunRules.lifeDefeated(state.lifeTime)) b.lastResourceBlow = {
        attacker: enemy.name, label: it.label, resource: 'life', amount: it.life_cost, turn: b.turn,
      };
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
  state.qi = Math.min(state.qiMax, state.qi + RunRules.essenceRegen(state.cultivation));
  if (b.playerHuman) {
    b.playerHuman.essence = state.qi;
    for (const event of HumanRules.upkeep(b.playerHuman)) {
      if (event.ok && event.cost === 0) continue;
      const gu = GU_BY_ID[event.instanceId.split('::')[0]];
      b.log.push(event.ok
        ? `你维持 <b>${gu?.name || event.instanceId}</b> · 真元 -${event.cost}`
        : `你无法维持 <b>${gu?.name || event.instanceId}</b> · 效果解除`);
    }
    state.qi = b.playerHuman.essence;
    state.thought = refreshHumanControl(b.playerHuman);
  }
  b.guUsedThisTurn = {};
  b.killMoveUsedThisTurn = {};
  b.actionsUsed = 0;
  b.actionLimit = RunRules.actionPointsPerTurn(state.soul);
  b.turnSupports = {};
  b.turn += 1;
  b.log.push(`— 第 ${b.turn} 回合 —`);
  if (fireDelayedEffects(b)) return true;
  for (const enemy of aliveEnemies(b)) {
    if (!enemy.human) continue;
    enemy.human.essence = Math.min(
      HumanRules.attribute(enemy.human, 'essenceMax'),
      enemy.human.essence + HumanRules.attribute(enemy.human, 'essenceRegen'),
    );
    for (const event of HumanRules.upkeep(enemy.human)) {
      if (event.ok && event.cost === 0) continue;
      const gu = GU_BY_ID[event.instanceId.split('::')[0]];
      b.log.push(event.ok
        ? `<b>${enemy.name}</b> 维持 <b>${gu?.name || event.instanceId}</b> · 真元 -${event.cost}`
        : `<b>${enemy.name}</b> 无法维持 <b>${gu?.name || event.instanceId}</b> · 防护解除`);
    }
    refreshHumanControl(enemy.human);
  }
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
  const resource = b.deathCause === 'soul' ? 'soul' : b.deathCause === 'life_cost' ? 'life' : '';
  const resourceBlow = b.lastResourceBlow?.resource === resource ? b.lastResourceBlow : null;
  if (resource) {
    const label = resource === 'soul' ? '魂魄' : '寿元';
    parts.push(resourceBlow
      ? `败因：${resourceBlow.attacker} · ${resourceBlow.label}（${label}减少 ${resourceBlow.amount} 后耗尽）`
      : `败因：${label}耗尽于第 ${b.turn || 0} 回合`);
  } else {
    parts.push(blow
      ? `败因：${blow.attacker} · ${blow.label}（伤 ${blow.damage}${blow.absorbed ? `，护体挡下 ${blow.absorbed}` : ''}）`
      : `败因：资源耗尽于第 ${b.turn || 0} 回合`);
  }
  if (counter) parts.push(`关键失误：「${counter.label}」曾被「${counter.counterId}」反制吞掉（第 ${counter.turn} 回合）`);
  if (last3.length) parts.push(`最后三条战斗记录：${last3.join(' / ')}`);
  return { lastBlow: blow, lastResourceBlow: resourceBlow, lastCounter: counter, last3, detail: parts.join('；') };
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
    saveEndingArchive(state.ending);
    state.battle = null;
    showPage('ending');
    Sfx.lose();
  } else if (outcome === 'victory') {
    const loot = rollVictoryLoot(b);
    const healBudget = Math.ceil(state.bloodMax * (DATA.flow.postBattleHealPct || 0) / 100);
    const healed = Math.min(healBudget, Math.max(0, state.bloodMax - state.blood));
    state.blood += healed;
    state.qi = state.qiMax;
    state.stones += loot.stones;
    state.lootPity = loot.lootPity;
    state.journal.unshift(`战后收获 · 元石 +${loot.stones} · 气血 +${healed} · 真元回满`);
    recordEvent('battle_loot', {
      stones: state.stones,
      true_qi: state.qi,
      health: state.blood,
      loot_pity: state.lootPity,
    }, loot.guChoices.length ? 'gu_choices_pending' : 'auto_rewards_granted');
    state.reward = {
      ...loot,
      nodeId: b.nodeId,
      healed,
      turn: b.turn,
      battleLog: b.log.slice(-80),
    };
    state.battle = null;
    showPage('reward');
  }
  draw();
}

function resolveProblemHit(b, target, plan, label) {
  const problem = (typeof GuRules !== 'undefined' && GuRules.resolveProblemHit)
    ? GuRules.resolveProblemHit(target, plan, plan.damage)
    : { damage: plan.damage, notes: [] };
  for (const note of problem.notes || []) {
    if (note === 'evaded') b.log.push(`<b>${target.name}</b> · <b>${label}</b> <span class="dmg">被闪避</span>`);
    if (note === 'armored') b.log.push(`<b>${target.name}</b> · 厚甲吞伤 · <b>${label}</b> 未破防`);
    if (note === 'armor_tax') b.log.push(`<b>${target.name}</b> · 厚甲减伤`);
    if (note === 'pierce_armor') b.log.push(`<b>${label}</b> · <span class="heal">破甲/穿透</span>`);
    if (note === 'chip_through_armor') b.log.push(`<b>${label}</b> · 蹭血穿甲`);
    if (note === 'ignore_evasion') b.log.push(`<b>${label}</b> · <span class="heal">稳定必中</span>`);
    if (note === 'locked_on') b.log.push(`<b>${label}</b> · 已锁定 · 必中`);
    if (note === 'stable_hit') b.log.push(`<b>${label}</b> · 稳定命中`);
    if (note === 'suppressed_rule') b.log.push(`<b>${label}</b> · <span class="heal">镇压规则</span>`);
    if (note === 'read_rule') b.log.push(`<b>${label}</b> · 已读破规则`);
  }
  if ((problem.notes || []).includes('unread_tax')) {
    const tax = Math.max(1, Math.ceil(Number(problem.damage || 0) / 2));
    state.blood = Math.max(0, state.blood - tax);
    b.log.push(`未识破规则 · <span class="dmg">反噬 ${tax}</span>`);
    BattleFx.selfDamage(tax);
    if (state.blood <= 0) {
      b.over = '败';
      b.deathCause = 'info_tax';
    }
  }
  if (target.human && problem.damage > 0) {
    problem.damage = receiveHumanHit(b, target.human, problem.damage, target.name).damage;
  }
  return problem;
}

function applyEffectPlan(b, target, plan, label) {
  if (plan.heal) {
    const healed = Math.min(plan.heal, Math.max(0, state.bloodMax - state.blood));
    state.blood += healed;
    b.log.push(`<b>${label}</b> · <span class="heal">气血 +${healed}</span>`);
    if (healed > 0) BattleFx.heal(healed);
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
      // L0 Phase 1：先结算问题轴（重甲/闪避/信息税），再进反制管线
      const problem = resolveProblemHit(b, target, plan, label);
      const coreEnemy = core.toCoreEnemy(target, globalThis.MVP_CONTENT?.enemyProfiles);
      const res = core.resolveDirectStrike(coreEnemy, {
        damage: problem.damage,
        bypassCounter: !!plan.bypassCounter || !!plan.armorBreak,
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
    if (plan.support.targetGuId) {
      const targets = b.turnSupports.guTargets ||= {};
      const list = targets[plan.support.targetGuId] ||= [];
      if (!plan.support.nonStacking || !list.some(s => s.multiplier === plan.support.multiplier && s.nonStacking)) {
        list.push({ ...plan.support });
      }
      b.log.push(`<b>${label}</b> · 本回合下一次${GU_BY_ID[plan.support.targetGuId]?.name || plan.support.targetGuId} ×${plan.support.multiplier}（同类不叠加）`);
    } else {
      b.turnSupports[plan.support.school] =
        (b.turnSupports[plan.support.school] || 0) + plan.support.bonus;
      b.log.push(`<b>${label}</b> · ${schoolLabel(plan.support.school)}支援 +${plan.support.bonus}`);
    }
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
    const target = entry.basicAttack
      ? aliveEnemies(b).find(enemy => enemy.id === entry.targetId)
      : aliveEnemies(b)[0];
    if (!target) {
      if (entry.basicAttack) { b.log.push('石臂拳脚 · 原目标已倒下，本击落空'); continue; }
      break;
    }
    const effect = { ...entry.effect };
    delete effect.delay;
    const plan = GuRules.effectPlan(effect, {
      school: entry.school,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    if (entry.basicAttack) {
      const hit = resolveProblemHit(b, target, plan, entry.label);
      target.hp = Math.max(0, target.hp - hit.damage);
      b.log.push(`<b>${target.name}</b> · <b>${entry.label}</b> 落下，<span class="dmg">伤 ${hit.damage}</span>`);
      if (hit.damage > 0) BattleFx.damage(hit.damage);
    } else applyEffectPlan(b, target, plan, `${entry.label}（延迟）`);
    b.log.push(`第 ${b.turn} 回合 · 延迟效果到期`);
    if (b.over === '败' || state.blood <= 0) {
      b.over = '败';
      openBattleOutcome();
      return true;
    }
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
  if (!b.over && b.actionsUsed >= b.actionLimit) return act.endTurn();
  draw();
}

const act = {
  produceLeaf(guId) {
    if (!assertRunMutable() || state.page !== 'prep' || !state.prepFor) return;
    const gu = GU_BY_ID[guId];
    const result = leafProductionPreview(gu);
    if (!result.ok) return toast(guReasonLabel(result.reason), 'bad');
    state.owned = result.owned;
    state.qi = result.trueQi;
    state.leafProductionVisit = state.prepFor;
    state.journal.unshift(`${gu.name}催生 · 生机叶 +${result.produced} · 真元 -${result.cost}`);
    recordEvent('produce_gu', { owned: { ...state.owned }, true_qi: state.qi,
      production_visit: state.leafProductionVisit }, 'leaf_produced', [gu.id, gu.effect.output_gu_id]);
    draw();
  },

  useLeaf(guId) {
    if (!assertRunMutable() || state.page !== 'prep') return;
    const gu = GU_BY_ID[guId];
    const result = consumeLeaf(gu);
    if (!result.ok) return toast(guReasonLabel(result.reason), 'bad');
    state.journal.unshift(`生机叶疗伤 · 气血 +${result.healed} · 叶片 -1`);
    draw();
  },
  trainBody(guId) {
    if (!assertRunMutable() || state.page !== 'prep' || !state.prepFor) return;
    const gu = GU_BY_ID[guId];
    const preview = bodyTrainingPreview(gu);
    if (!preview.ok) return toast('当前不能锻体 · ' + ({
      repeated_visit: '本次整备已锻体', cap_reached: '已达同型力量上限',
      insufficient_essence: '真元不足', insufficient_stone: '补饲元石不足',
      gu_unavailable: '未持有可用蛊虫',
    }[preview.reason] || preview.reason), 'bad');
    state.qi = preview.human.essence;
    state.stones -= gu.feedingCost;
    state.modifierLedger = preview.human.modifierLedger.map(entry => ({ ...entry }));
    state.journal.unshift(`${gu.name}锻体 · 永久力量 +${preview.gained} · 同型累计 ${preview.total}/${gu.effect.cap}`);
    recordEvent('body_training', {
      gu_id: gu.id, strength: preview.total, true_qi: state.qi,
      stones: state.stones, modifier_ledger: state.modifierLedger.map(entry => ({ ...entry })),
    }, 'permanent_strength_gained', [gu.id]);
    Sfx.success();
    draw();
  },

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
    state.lastGainInsight = GuRules.gainInsight(definitionId, {
      owned: state.owned,
      recipes: GuRules.liveRecipes(DATA.recipes),
      killMoves: DATA.killMovesEnabled ? currentKillMoves().filter(move => move.playable === true) : [],
      buildKits: GuRules.BUILD_KITS,
      guById: GU_BY_ID,
    });
    Sfx.success();
    toast(`炼化成功 · ${gu.name}`, 'good');
    draw();
  },

  forge(recipeId) {
    if (!assertRunMutable()) return;
    const r = GuRules.liveRecipes(DATA.recipes).find((x) => x.id === recipeId);
    if (!r) return;
    const need = r.inputs.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
    for (const [id, n] of Object.entries(need)) if ((state.owned[id] || 0) < n) return toast('蛊虫不足', 'bad');
    if ((r.stoneCost || 0) > state.stones) return toast('元石不足', 'bad');

    for (const [id, n] of Object.entries(need)) state.owned[id] -= n;
    state.stones = Math.max(0, state.stones - (r.stoneCost || 0));
    // 合炼吃掉组件后，卸下缺件杀招，避免幽灵可点。
    {
      const invalid = [];
      for (const move of currentKillMoves()) {
        if (!state.equipped.includes(move.id)) continue;
        if (!GuRules.killMoveRecipeInstances(move, state.owned, {}, {}).every(Boolean)) invalid.push(move);
      }
      if (invalid.length) {
        const invalidIds = new Set(invalid.map((move) => move.id));
        state.equipped = state.equipped.filter((id) => !invalidIds.has(id));
      }
    }
    Sfx.forge();

    const outName = (DATA.gu.find((g) => g.id === r.output) || {}).name || r.output;
    const roll = RunRules.refinementRoll(state.seed, r.id, state.eventLog.length);
    if (RunRules.refinementSucceeds(roll, r)) {
      state.owned[r.output] = (state.owned[r.output] || 0) + 1;
      recordEvent('refine_gu', { owned: { ...state.owned } }, 'refinement_succeeded', [r.output]);
      state.lastGainInsight = GuRules.gainInsight(r.output, {
        owned: state.owned,
        recipes: GuRules.liveRecipes(DATA.recipes),
        killMoves: DATA.killMovesEnabled ? currentKillMoves().filter(move => move.playable === true) : [],
        buildKits: GuRules.BUILD_KITS,
        guById: GU_BY_ID,
      });
      Sfx.success();
      toast(`开炉成功 · ${outName}`, 'good');
    } else {
      recordEvent('refine_gu', { owned: { ...state.owned } }, 'refinement_failed_destroyed_inputs', r.inputs || []);
      Sfx.fail();
      toast('开炉失败 · 投入蛊虫全部消亡', 'bad');
    }
    draw();
  },

  addMoveComponent(id) {
    if (!assertRunMutable() || state.page !== 'prep') return;
    if (!['moonlight_gu', 'small_light_gu', 'moon_glow_gu'].includes(id)) return toast('此蛊同催尚未验证', 'bad');
    const draft = state.killmoveDraft || [];
    if (draft.length >= 3) return toast('当前试验最多三个组件', 'bad');
    if (draft.filter(item => item === id).length >= Number(state.owned[id] || 0)) return toast('没有可加入的该蛊实例', 'bad');
    state.killmoveDraft = [...draft, id];
    draw();
  },

  removeMoveComponent(index) {
    if (!assertRunMutable() || state.page !== 'prep') return;
    const draft = state.killmoveDraft || [];
    if (!Number.isInteger(index) || index < 0 || index >= draft.length) return;
    state.killmoveDraft = draft.filter((_, i) => i !== index);
    draw();
  },

  rememberCustomMove() {
    if (!assertRunMutable() || state.page !== 'prep') return;
    const result = GuRules.composeKillMove(state.killmoveDraft || [], GU_BY_ID);
    if (!result.ok) return toast('至少选两组件，并包含一只攻击蛊', 'bad');
    if (GuRules.killMoveRecipeInstances(result.move, state.owned, {}, {}).some(instance => !instance)) return toast('组件库存不足', 'bad');
    if ((state.customMoveRecipes || []).some(recipe => GuRules.composeKillMove(recipe, GU_BY_ID).move?.id === result.move.id)) return toast('此组件组合已记下', 'bad');
    state.customMoveRecipes = [...(state.customMoveRecipes || []), [...result.move.recipe]];
    state.killmoveDraft = [];
    recordEvent('compose_kill_move', { move_id: result.move.id, recipe: [...result.move.recipe] }, 'experimental_recipe_remembered');
    toast('已记下同催配方；可选择记入杀招槽', 'good');
    draw();
  },

  forgetCustomMove(id) {
    if (!assertRunMutable() || state.page !== 'prep') return;
    state.customMoveRecipes = (state.customMoveRecipes || []).filter(recipe => GuRules.composeKillMove(recipe, GU_BY_ID).move?.id !== id);
    state.equipped = state.equipped.filter(moveId => moveId !== id);
    draw();
  },

  toggleMove(id) {
    if (!assertRunMutable()) return;
    if (!DATA.killMovesEnabled) return toast('杀招系统暂未开放', 'bad');
    const i = state.equipped.indexOf(id);
    if (i >= 0) { state.equipped.splice(i, 1); Sfx.click(); draw(); return; }
    if (state.equipped.length >= 3) return toast('杀招槽已满（三）', 'bad');
    const move = currentKillMoves().find((m) => m.id === id);
    if (!move) return toast('未找到该杀招', 'bad');
    if (move.playable !== true) return toast('此杀招尚未开放', 'bad');
    // 组件按实例占用校验：重复配方不能用「持有>0」蒙混。
    const instances = GuRules.killMoveRecipeInstances(move, state.owned, {}, {});
    if (instances.some((x) => !x)) return toast('组件不足 · 无法装备该杀招', 'bad');
    state.equipped.push(id);
    Sfx.click();
    draw();
  },

  startRun(difficulty = 'normal', seedOverride) {
    if (!confirmAbandon('开始新局将放弃当前局，确定？')) {
      skipPersistOnce = true;
      return;
    }
    saveWriteBlockedUntilNewRun = false;
    bootSaveIssue = ['unreadable', 'outdated'].includes(bootSaveIssue) ? null : bootSaveIssue;
    // ?seed= 只影响明确的新局；继续不会走到这里。
    const explicitSeed = Number(seedOverride);
    const seed = Number.isFinite(explicitSeed) && explicitSeed > 0
      ? Math.floor(explicitSeed)
      : readUrlSeed();
    state = fresh(difficulty, seed);
    state.journey.started = true;
    nextRunSeedValue = null;
    showPage('map');
    Sfx.click();
    toast(seedOverride ? `重走旧路 · 种子 ${state.seed}` : `已开局 · ${DATA.flow.difficulties[state.journey.difficulty].label}`);
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

  // 非战斗节点（险地 / 市集 / 野蛊 / 休整 / 静修 / 异闻）：进入后等玩家在节点动作页选一个动作。
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
    if (node.type === NodeActionRules.eventNodeType) {
      const result = NodeActionRules.resolveEvent(choiceId, node.event, {
        health: state.blood,
        stones: state.stones,
      });
      if (!result.ok) {
        return toast(result.reason === 'insufficient_health'
          ? '气血不足以承受这份代价。'
          : '这条异闻暂不可应答。', 'bad');
      }
      state.blood = result.healthAfter;
      state.stones = result.stoneAfter;
      state.journal.unshift(`${node.name} · ${result.text}`);
      recordEvent('choose_action', {
        health: state.blood,
        stone: state.stones,
      }, result.reason, [node.eventId || node.routeTemplateId]);
      Sfx.success();
      toast(result.text, 'good');
      return act.openPrep();
    }
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
    saveEndingArchive(state.ending);
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
      if (e.grade === 'cultivator' && e.guLoadout) {
        const instances = (e.guLoadout.required || []).map((guId, index) => HumanRules.guInstance(guId, index + 1));
        const human = HumanRules.actor({ id: e.id, rank: e.rank, guInstances: instances });
        const precast = e.guLoadout.precast === 'seeded_half'
          && RunRules.seededIndex(2, state.seed, `${nodeId}:${e.id}:precast`, 0) === 0;
        const precastLog = [];
        if (precast) {
          for (const instance of instances) {
            const gu = GU_BY_ID[instance.definitionId];
            if (gu?.battleEffect?.kind !== 'maintained') continue;
            const gate = GuRules.activationReason(gu, {
              playerRank: human.rank, trueQi: human.essence, thought: human.thought,
              actionLimitReached: false,
            });
            if (gate) continue;
            const result = startMaintainedGu(human, instance.instanceId, gu, 0);
            if (result.ok) {
              human.thought -= gu.thoughtCost;
              precastLog.push(`${gu.name}：真元 -${result.cost}、操控 -${gu.thoughtCost}`);
            }
          }
        }
        return { ...e, hpMax: human.baseline.hpMax, hp: human.hp, human,
          plannedAction: null, precastLog, flags: {}, statuses: {}, intentWeaken: 0 };
      }
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
    state.thoughtMax = HumanRules.BASELINE.thoughtMax;
    state.thought = state.thoughtMax;
    state.qi = state.qiMax;
    const playerHuman = HumanRules.actor({
      id: 'player', rank: state.cultivation, guInstances: heldPlayerGuInstances(),
      baseline: { ...HumanRules.base(state.cultivation), essenceMax: state.qiMax },
    });
    playerHuman.modifierLedger = (state.modifierLedger || []).map((entry) => ({ ...entry }));
    state.battle = {
      enemies, targetId: enemies[0].id, playerHuman,
      block: 0, turn: 1, over: null, nodeId,
      layer: (nodeId && nodeById(nodeId)?.layer) || 1,
      guUsedThisTurn: {}, guSealed: {}, killMoveUsedThisTurn: {}, buffs: {},
      turnSupports: {}, swordIntent: 0, delayedEffects: [],
      actionsUsed: 0, actionLimit: RunRules.actionPointsPerTurn(state.soul),
      log: [`<b>${enemies.map((e) => e.name).join('、')}</b> 逼近。`,
        ...enemies.flatMap((enemy) => (enemy.precastLog || []).map((line) =>
          `<b>${enemy.name}</b> 战前催动 ${line}`))],
    };
    state.battle.enemies.forEach((enemy) => act._pickIntent(state.battle, enemy));
    showPage('battle');
    Sfx.click();
    draw();
  },

  // 选本回合敌方意图：阶段 + 冷却门禁（全部在冷却则为 null = cooldown_wait）
  _pickIntent(b, enemy = targetOf(b)) {
    if (!enemy || enemy.hp <= 0) return;
    if (enemy.human) {
      enemy.plannedAction = pluginHumanPlan(b, enemy);
      return;
    }
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
    const strike = b.playerHuman ? HumanRules.basicStrikePlan(b.playerHuman) : { damage: HumanRules.BASELINE.attack, delayTurns: 0 };
    const raw = strike.damage
      + Number(b.buffs?.force || 0)
      + Number(b.buffs?.yi_zhang || 0);
    if (strike.delayTurns > 0) {
      scheduleEffect(b, { kind: 'strike', amount: raw, delay: { turns: strike.delayTurns } }, '', '石臂拳脚');
      Object.assign(b.delayedEffects.at(-1), { basicAttack: true, targetId: target.id });
      finishPlayerAction(b);
      return;
    }
    const problem = resolveProblemHit(b, target, { damage: raw }, '拳脚');
    target.hp = Math.max(0, target.hp - problem.damage);
    b.log.push(problem.damage > 0
      ? `<b>${target.name}</b> · <b>拳脚</b> 命中，<span class="dmg">伤 ${problem.damage}</span>`
      : `<b>${target.name}</b> · <b>拳脚</b> 未造成伤害`);
    Sfx.hit();
    const box = $('#foe-box');
    if (box) { box.classList.add('hit'); setTimeout(() => box.classList.remove('hit'), 300); }
    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }
    if (b.over === '败') {
      openBattleOutcome();
      return;
    }
    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      openBattleOutcome();
      return;
    }
    finishPlayerAction(b);
  },

  /** MVP 逆息：真元锁死时 1 操控 · 气血-2 · 真元+3 */
  exhaust() {
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    if (state.thought < 1) return toast('本回合操控余量不足', 'bad');
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
    if (state.thought < 1) return toast('本回合操控余量不足', 'bad');
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
    if (!DATA.killMovesEnabled) return toast('杀招系统暂未开放', 'bad');
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over) return;
    const target = targetOf(b);
    if (!target) return openBattleOutcome();
    const m = currentKillMoves().find((x) => x.id === id);
    if (!m) return toast('未找到该杀招', 'bad');
    if (m.playable !== true) return toast('此杀招尚未开放', 'bad');
    if (!state.equipped.includes(id)) return toast('此杀招尚未记入', 'bad');
    if (m.recipe.some(guId => !GuRules.canActivate(state.cultivation, GU_BY_ID[guId]?.rank, GU_BY_ID[guId]?.lowRankException)))
      return toast('组件所需真元品质不足', 'bad');
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
    if (state.qi < m.true_qi_cost || state.thought < m.thought_cost) return toast('真元或操控不足', 'bad');
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
    b.log.push(`同催 <b>${m.label}</b> · 真元 -${m.true_qi_cost} · 操控 -${m.thought_cost}`);
    recordEvent('use_kill_move', { true_qi: state.qi, thought: state.thought,
      move_id: id, component_instances: [...recipeInstances],
      gu_used_this_turn: { ...b.guUsedThisTurn }, kill_move_used_this_turn: { ...b.killMoveUsedThisTurn },
    }, 'components_activated', recipeInstances);
    if (m.life_cost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, m.life_cost);
      if (RunRules.lifeDefeated(state.lifeTime)) b.lastResourceBlow = {
        attacker: '自身催动', label: m.label, resource: 'life', amount: m.life_cost, turn: b.turn,
      };
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

    if (b.over === '败' || state.blood <= 0) {
      b.over = '败';
      openBattleOutcome();
      return;
    }
    if (!aliveEnemies(b).length) {
      b.over = '胜';
      Sfx.win();
      openBattleOutcome();
      return;
    }

    finishPlayerAction(b);
  },

  stopGu(instanceId) {
    if (!assertRunMutable()) return;
    const b = state.battle;
    if (!b || b.over || !b.playerHuman?.maintainedGu.some(item => item.instanceId === instanceId && item.active)) return;
    HumanRules.stopMaintained(b.playerHuman, instanceId, 'player_stopped');
    b.log.push(`你停止催动 <b>${GU_BY_ID[instanceId.split('::')[0]]?.name || instanceId}</b> · 防护解除`);
    recordEvent('stop_gu', { instance_id: instanceId });
    draw();
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
      healingLocked: state.leafRecoveryNodeId === state.journey.nodeId,
      health: state.blood, healthMax: state.bloodMax,
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

    if (gu.battleEffect?.kind === 'maintained') {
      const human = b.playerHuman;
      human.essence = state.qi;
      const activated = startMaintainedGu(human, instanceId, gu, b.turn);
      if (!activated.ok) return toast(guReasonLabel(activated.reason), 'bad');
      state.qi = human.essence;
      state.thought -= gu.thoughtCost;
      human.thought = state.thought;
      b.actionsUsed += 1;
      b.usedDefenseThisTurn = true;
      b.guUsedThisTurn[instanceId] = true;
      b.log.push(`你催动 <b>${gu.name}</b> · 真元 -${activated.cost} · 操控 -${gu.thoughtCost}；防御 ${HumanRules.attribute(human, 'defense')}`);
      finishPlayerAction(b);
      return;
    }

    let consumedLeaf = null;
    if (gu.battleEffect?.consumable) {
      consumedLeaf = consumeLeaf(gu);
      if (!consumedLeaf.ok) return toast(guReasonLabel(consumedLeaf.reason), 'bad');
    }
    state.qi -= gu.trueQiCost;
    state.thought -= gu.thoughtCost;
    // 定向辅助作为同催准备；原有单行动回合仍能完成辅助 + 主蛊。
    if (!(gu.battleEffect?.kind === 'support' && gu.battleEffect.target_gu_id)) b.actionsUsed += 1;
    b.guUsedThisTurn[instanceId] = true;
    b.log.push(`催动 <b>${gu.name}</b> · 真元 -${gu.trueQiCost} · 操控 -${gu.thoughtCost}`);
    if (gu.lifeCost) {
      state.lifeTime = RunRules.spendLife(state.lifeTime, gu.lifeCost);
      if (RunRules.lifeDefeated(state.lifeTime)) b.lastResourceBlow = {
        attacker: '自身催动', label: gu.name, resource: 'life', amount: gu.lifeCost, turn: b.turn,
      };
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
      guId: gu.id,
      school: gu.school,
      supports: b.turnSupports,
      swordIntent: b.swordIntent,
      statusStacks: target.statuses || {},
    });
    if (consumedLeaf) {
      plan.heal = 0;
      b.log.push(`<b>${gu.name}</b> · 气血 +${consumedLeaf.healed} · 叶片消耗1；本节点不再有效疗伤`);
      BattleFx.heal(consumedLeaf.healed);
    }
    applyEffectPlan(b, target, plan, gu.name);
    if (plan.damage > 0 && b.turnSupports.guTargets) delete b.turnSupports.guTargets[gu.id];

    if (target.hp <= 0) {
      b.log.push(`<b>${target.name}</b> 伏诛`);
      const next = aliveEnemies(b)[0];
      if (next) b.targetId = next.id;
    }

    if (b.over === '败' || state.blood <= 0) {
      b.over = '败';
      openBattleOutcome();
      return;
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
      state.lastGainInsight = GuRules.gainInsight(offer.gu_id, {
        owned: state.owned,
        recipes: GuRules.liveRecipes(DATA.recipes),
        killMoves: DATA.killMovesEnabled ? currentKillMoves().filter(move => move.playable === true) : [],
        buildKits: GuRules.BUILD_KITS,
        guById: GU_BY_ID,
      });
    } else if (offer.kind === 'gu_fang_unlock') {
      state.globalCodexIds.push(offer.gu_id);
    }
    state.shopSold.push(offer.id);
    state.journal.unshift(`坊市 · 购入${offerName(offer)} · 元石 ${cost}`);
    recordEvent('shop', {
      stones: state.stones,
      owned: { ...state.owned },
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
    for (const move of currentKillMoves()) {
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
    // L0 Phase 3：获得后明确关联装备/炼蛊/杀招未来，不自动装备
    const insight = GuRules.gainInsight(guId, {
      owned: state.owned,
      recipes: GuRules.liveRecipes(DATA.recipes),
      killMoves: DATA.killMovesEnabled ? currentKillMoves().filter(move => move.playable === true) : [],
      buildKits: GuRules.BUILD_KITS,
      guById: GU_BY_ID,
    });
    state.lastGainInsight = insight;
    recordEvent('battle_loot', { insight: {
      gu_id: insight.guId,
      role: insight.role,
      decisions: insight.decisions.map((d) => d.kind),
      kill_moves: insight.killMoveForms.map((k) => k.moveId),
      kits: insight.kitJoins.map((k) => k.kitId),
      has_real_decision: insight.hasRealDecision,
      opens_new_choice: typeof LootRules !== 'undefined' && LootRules.opensNewChoice
        ? LootRules.opensNewChoice(reward || {}, insight)
        : insight.hasRealDecision,
    } }, 'build_insight_offered', [guId]);
    // 领取后立刻失效 reward，防重复点击追加
    state.reward = null;
    Sfx.success();
    toast(`获得 ${insight.name} · ${insight.decisions.map((d) => d.label).join(' / ')}`, 'good');
    act.openPrep();
  },

  continueReward(discardGu = false) {
    if (!assertRunMutable()) return;
    const reward = state.reward;
    if (!reward) return showPage('map');
    if ((reward.guChoices || []).length && !discardGu) return toast('选择一只蛊虫，或明确放弃本次蛊虫', 'bad');
    if (discardGu && (reward.guChoices || []).length) {
      recordEvent('battle_loot', { owned: { ...state.owned }, stones: state.stones }, 'loot_gu_declined');
      state.journal.unshift('放弃本次蛊虫 · 已到账资源保留');
      Sfx.click();
    }
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
  document.body.dataset.page = next;
  // 切到哪页就绘哪页（draw 只维护当前页；不切页的提交走 draw）。
  renderJourneyPage(next);
  if (next === 'battle') renderBattle($('#panel-battle'));
  else if (next === 'cover') renderCover($('#panel-cover'));
  hud();
  document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('on', b.dataset.tab === next));
  document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('on', p.id === `panel-${next}`));
  window.Motion?.pageEnter(document.getElementById(`panel-${next}`));
  updateNavigation();
  syncDock();
}

// 主行动坞：当前场景的「下一步」提升到底部固定位置。
// 克隆并转发点击到场景内原件，避免重绘丢监听。
const DOCK_HINTS = {
  hall: '选择难度后开始修行',
  map: '从当前可走节点中择一；未选择前不预设路线',
  battle: '先看敌方意图，再从可用行动中选择；不预设攻击',
  prep: '整备完成后继续行程',
  reward: '先比较战后收获；不替你预选蛊虫',
  'node-action': '核对代价，再选择当前节点行动',
  ending: '本局已写入旧录，可回大厅开新局',
  cover: '开发覆盖页 · 非正式流程',
};

function syncDock() {
  const slot = document.querySelector('#dock-slot');
  const hint = document.querySelector('#dock-hint');
  if (!slot || !hint) return;
  const page = state.page;
  const prevDock = slot.firstElementChild ? slot.firstElementChild.textContent : '';
  hint.textContent = DOCK_HINTS[page] || '处理当前场景中的下一步';
  slot.innerHTML = '';
  const panel = document.querySelector(`#panel-${page}`);
  if (!panel) return;
  if (page === 'hall' && panel.querySelector('[data-continue-run]')) {
    hint.textContent = '行程已保存，可继续修行或明确选择另起新局';
  }
  if (page === 'map' && panel.querySelector('.map-node.available')) {
    hint.textContent = '选择一条可走道路；每个节点的后果以规则预览为准';
  }
  if (page === 'battle' && panel.querySelector('[data-basic-attack]')) {
    hint.textContent = '观察意图后，自行选择攻击、御守或结束回合';
  }
  if (page === 'reward' && panel.querySelector('.reward-choices')) {
    hint.textContent = '比较三只蛊虫，再选择收入蛊仓的那一只';
  }
  const preferredByPage = {
    hall: '[data-continue-run], [data-start-run]',
    map: '[data-return-node]',
    battle: '[data-start-encounter]',
    prep: '[data-prep-continue]',
    reward: '[data-reward-continue]',
    'node-action': null,
    ending: '[data-ending-hall]',
  };
  const preferred = Object.prototype.hasOwnProperty.call(preferredByPage, page)
    ? preferredByPage[page]
    : 'button.primary:not(:disabled)';
  if (!preferred) return;
  const src = panel.querySelector(preferred);
  if (!src) return;
  const mirror = dockMirrorButton(src);
  mirror.addEventListener('click', (ev) => {
    ev.preventDefault();
    src.click();
  });
  slot.appendChild(mirror);
  if (mirror.textContent !== prevDock) window.Motion?.dockIn(mirror);
}

// 卡片式按钮（地图节点 / 战后三选一）不镜像进 dock：多选场景由玩家在场景内直接选择，
// dock 保持「不替你预设路线 / 不替你预选蛊虫」的口径，slot 为空即隐藏。
function dockMirrorButton(src) {
  const clone = src.cloneNode(true);
  clone.classList.add('primary');
  clone.removeAttribute('id');
  return clone;
}

function updateNavigation() {
  const node = currentNode();
  const available = {
    hall: true,
    map: !!state.journey.started && !state.ending,
    battle: !!state.battle && !state.ending,
    prep: !!node && state.prepFor === node.id && !state.ending,
    cover: /(?:\?|&)debug=1(?:&|$)/.test(String(location.search || '')),
  };
  const reason = {
    map: '开局后可查看行程',
    battle: '进入战斗节点后可查看战况',
    prep: '结算节点后可进入整备',
    cover: '开发调试页',
  };
  document.querySelectorAll('#tabs button').forEach((button) => {
    const enabled = button.hidden || available[button.dataset.tab] !== false;
    button.disabled = !enabled;
    button.setAttribute('aria-disabled', String(!enabled));
    button.title = enabled ? '' : (reason[button.dataset.tab] || '当前不可用');
  });
}

const tabs = [...document.querySelectorAll('#tabs button')];
if (/(?:\?|&)debug=1(?:&|$)/.test(String(location.search || ''))) {
  document.querySelector('[data-tab="cover"]')?.removeAttribute('hidden');
}
tabs.forEach((b) => b.addEventListener('click', () => {
  if (b.disabled) return;
  showPage(b.dataset.tab);
  Sfx.click();
}));
$('#reset').addEventListener('click', () => act.restartRun());
document.addEventListener('pointerdown', () => Sfx.click(), { once: true });

draw();
showPage(resumePage());
syncDock();
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
    // 动效层诊断（js/motion.js）：只读，供走盘与探针确认 GSAP 是否在驱动。
    motion: {
      gsap: (window.gsap && window.gsap.version) || null,
      active: !!(window.Motion && window.Motion.active),
      motionOn: document.documentElement.classList.contains('motion-on'),
    },
  };
};
document.documentElement.dataset.ready = '1';
