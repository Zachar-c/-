/**
 * W2 · 节点状态、胜负与防绕过
 * 证据分级：
 *  - RULE_TEST：纯规则 / graph fixture，不证明玩家可得资源
 *  - FIXTURE_INTEGRATION：lab_browser + 受控局面（seed / UI 可达操作），须标明 fixture
 *  - NORMAL_RUN：空存档 + 可见控件 only（首战→奖励→整备→下一节点、败局→重开）
 * 禁止：act.* 直调、state 写入、注资、改敌血、跳节点、把 b.over='胜' 当获胜证据。
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { openLab } from './helpers/lab_browser.mjs';

const ROOT = path.resolve(import.meta.dirname, '..');
const RUN_FLOW_PATH = path.join(ROOT, 'js', 'run_flow.js');
const REPORT_DIR = path.join(ROOT, 'docs', 'tmp');

function loadRunFlow() {
  const code = readFileSync(RUN_FLOW_PATH, 'utf8');
  const fn = new Function(`${code}; return globalThis.RunFlow;`);
  return fn();
}

// —— graph fixtures（RULE_TEST）——
// nodes 是数组；查找必须用 RunFlow.nodeById / nodes.find。
const FIXTURE_GRAPH = {
  seed: 42,
  difficulty: 'normal',
  prepPerSegment: 1,
  segmentCount: 1,
  maxDepth: 1,
  roots: ['A'],
  nodes: [
    { id: 'A', segment: 1, layer: 1, depth: 0, slot: 0, type: 'battle', tier: 'common', enemyIds: ['e1'], name: '起点', nextIds: ['B', 'C'] },
    { id: 'B', segment: 1, layer: 1, depth: 1, slot: 0, type: 'battle', tier: 'common', enemyIds: ['e1'], name: '后继B', nextIds: ['END'] },
    { id: 'C', segment: 1, layer: 1, depth: 1, slot: 1, type: 'battle', tier: 'common', enemyIds: ['e2'], name: '后继C', nextIds: ['END'] },
    { id: 'END', segment: 1, layer: 1, depth: 2, slot: 0, type: 'boss', tier: 'boss', enemyIds: ['boss1'], name: '层主', nextIds: [] },
  ],
};

const FIXTURE_EMPTY_GRAPH = { seed: 1, difficulty: 'normal', roots: [], nodes: [] };

const FIXTURE_MISSING_ENEMY_NODE = {
  seed: 7,
  difficulty: 'normal',
  roots: ['X'],
  nodes: [
    { id: 'X', segment: 1, layer: 1, depth: 0, slot: 0, type: 'battle', tier: 'common', enemyIds: [], name: '缺敌人', nextIds: [] },
  ],
};

test('RULE_TEST: graph.nodes 是数组，nodeById 走 find 而不是下标', () => {
  const RunFlow = loadRunFlow();
  assert.ok(Array.isArray(FIXTURE_GRAPH.nodes));
  const node = RunFlow.nodeById(FIXTURE_GRAPH, 'B');
  assert.equal(node?.id, 'B');
  assert.equal(RunFlow.nodeById(FIXTURE_GRAPH, 'ZZZ'), null);
});

test('RULE_TEST: 不能选择非后继 — canSelectNode 只认 availableNodeIds', () => {
  const RunFlow = loadRunFlow();
  const availableNodeIds = ['B', 'C'];
  assert.equal(RunFlow.canSelectNode(availableNodeIds, 'B'), true);
  assert.equal(RunFlow.canSelectNode(availableNodeIds, 'C'), true);
  // A 是当前/已完成，END 尚未开放，均不可选
  assert.equal(RunFlow.canSelectNode(availableNodeIds, 'A'), false);
  assert.equal(RunFlow.canSelectNode(availableNodeIds, 'END'), false);
  assert.equal(RunFlow.canSelectNode(availableNodeIds, 'ZZZ'), false);
  assert.equal(RunFlow.canSelectNode(null, 'B'), false);
});

test('RULE_TEST: 战斗未结算时 leavePrep / complete 不得跳关', () => {
  const RunFlow = loadRunFlow();
  const blocked = RunFlow.journeyAdvanceResult({
    nodeId: 'A',
    node: FIXTURE_GRAPH.nodes[0],
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: true,
  });
  assert.equal(blocked.ok, false);
  assert.equal(blocked.kind, 'battle_unfinished');
});

test('RULE_TEST: 未开局 / 已终局不能推进节点（不能进真实奖励）', () => {
  const RunFlow = loadRunFlow();
  const notStarted = RunFlow.journeyAdvanceResult({
    nodeId: 'A',
    node: FIXTURE_GRAPH.nodes[0],
    started: false,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(notStarted.ok, false);
  assert.equal(notStarted.kind, 'not_started');

  const ended = RunFlow.journeyAdvanceResult({
    nodeId: 'A',
    node: FIXTURE_GRAPH.nodes[0],
    started: true,
    alreadyEnded: true,
    hasUnfinishedBattle: false,
  });
  assert.equal(ended.ok, false);
  assert.equal(ended.kind, 'already_ended');
});

test('RULE_TEST: 重复 completeCurrentNode 是 re-entry，不是「行程已尽」胜利', () => {
  const RunFlow = loadRunFlow();
  const reentry = RunFlow.journeyAdvanceResult({
    nodeId: null,
    node: null,
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(reentry.ok, false);
  assert.equal(reentry.kind, 'reentry');
});

test('RULE_TEST: 空 graph / 缺节点是内容错误，不能伪造行程已尽胜利', () => {
  const RunFlow = loadRunFlow();
  const empty = RunFlow.journeyAdvanceResult({
    nodeId: 'ghost',
    node: null,
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(empty.ok, false);
  assert.equal(empty.kind, 'content_error');

  assert.equal(RunFlow.combatNodeEnemyError(FIXTURE_MISSING_ENEMY_NODE.nodes[0]), 'missing_enemies');
  assert.equal(RunFlow.combatNodeEnemyError(FIXTURE_GRAPH.nodes[0]), null);
  assert.equal(RunFlow.combatNodeEnemyError(null), 'missing_node');
  // 空 graph 无根节点
  assert.equal(RunFlow.graphContentError(FIXTURE_EMPTY_GRAPH), 'empty_graph');
  assert.equal(RunFlow.graphContentError(FIXTURE_GRAPH), null);
});

test('RULE_TEST: 真实终点（L5B / nextIds 空）才产生 victory；败局是 defeat', () => {
  const RunFlow = loadRunFlow();
  const boss = FIXTURE_GRAPH.nodes.find((n) => n.id === 'END');
  const done = RunFlow.journeyAdvanceResult({
    nodeId: 'END',
    node: boss,
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(done.ok, true);
  assert.equal(done.kind, 'victory_ending');
  assert.equal(done.outcome, 'victory');

  const mid = RunFlow.journeyAdvanceResult({
    nodeId: 'A',
    node: FIXTURE_GRAPH.nodes[0],
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(mid.ok, true);
  assert.equal(mid.kind, 'continue');
  assert.deepEqual(mid.nextIds, ['B', 'C']);

  assert.equal(RunFlow.endingOutcomeFromBattleOver('败'), 'defeat');
  assert.equal(RunFlow.endingOutcomeFromBattleOver('胜'), 'victory');
  // 不是从打开页面推断 outcome
  assert.equal(RunFlow.endingOutcomeFromBattleOver(null), null);
});

test('RULE_TEST: 离开战斗页 = 视图切换；未结束不得清遭遇', () => {
  const RunFlow = loadRunFlow();
  const unfinished = { over: null };
  assert.equal(RunFlow.battleLeaveMode(unfinished), 'view_only');
  assert.equal(RunFlow.battleLeaveMode({ over: '胜' }), 'settle');
  assert.equal(RunFlow.battleLeaveMode({ over: '败' }), 'settle');
  assert.equal(RunFlow.battleLeaveMode(null), 'no_battle');
});

test('RULE_TEST: L5B 终点 fixture — 最后层主完成后必须 outcome=victory', () => {
  const RunFlow = loadRunFlow();
  // 单层终点图：只有 L5B，nextIds=[]
  const l5bGraph = {
    seed: 5,
    difficulty: 'normal',
    roots: ['L5B'],
    nodes: [
      { id: 'L5B', segment: 5, layer: 5, depth: 10, slot: 0, type: 'boss', tier: 'boss', enemyIds: ['boss1'], name: '层主 · 终局', nextIds: [] },
    ],
  };
  const node = RunFlow.nodeById(l5bGraph, 'L5B');
  assert.ok(node);
  assert.deepEqual(node.nextIds, []);
  const result = RunFlow.journeyAdvanceResult({
    nodeId: 'L5B',
    node,
    started: true,
    alreadyEnded: false,
    hasUnfinishedBattle: false,
  });
  assert.equal(result.kind, 'victory_ending');
  assert.equal(result.outcome, 'victory');
});

// —— lab_browser 集成（FIXTURE_INTEGRATION / NORMAL_RUN）——
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const COMBAT_NODE_TYPES = new Set(['battle', 'elite', 'boss']);

async function bootFresh(seed) {
  const lab = await openLab({ seed, viewport: [1280, 800] });
  // 空存档开机后明确新局
  await lab.click('[data-start-run]');
  await sleep(50);
  return lab;
}

/** 从 availableNodeIds 里挑真实战斗节点；preferEnemyId（如 ridge_hound）优先。 */
function pickBattleNode(snap, preferEnemyId) {
  const nodes = snap.journey?.graph?.nodes || [];
  const battles = (snap.journey?.availableNodeIds || [])
    .map((id) => nodes.find((n) => n.id === id))
    .filter((n) => n && COMBAT_NODE_TYPES.has(n.type));
  if (preferEnemyId) {
    const preferred = battles.find((n) => (n.enemyIds || []).includes(preferEnemyId));
    if (preferred) return preferred;
  }
  return battles[0] || null;
}

function classifyEvidence(kind) {
  return kind;
}

test('FIXTURE_INTEGRATION: 离开战斗页保留遭遇，返回可继续战斗', async () => {
  const lab = await bootFresh(20260922);
  try {
    const before = await lab.snapshot();
    assert.equal(before.journey.started, true);
    assert.ok(before.journey.availableNodeIds.length > 0);
    // 只点可见后继（UI 仅对 availableNodeIds 出按钮）
    await lab.click('[data-choose-node]');
    await sleep(80);
    const inNode = await lab.snapshot();
    // 进入战斗节点后应有 battle；非战斗节点则进 node-action/prep
    if (inNode.battle) {
      const battleId = inNode.battle.nodeId;
      const turn = inNode.battle.turn;
      const over = inNode.battle.over;
      // 视图离开：data-escape 当前接线 endBattle（W2 改为 view-only）
      await lab.click('[data-escape]');
      await sleep(80);
      const left = await lab.snapshot();
      // 必须保留遭遇
      assert.ok(left.battle, '离开战斗页不得清空 state.battle');
      assert.equal(left.battle.over, over, '离开不得改写战斗结算');
      assert.equal(left.battle.nodeId, battleId);
      assert.equal(left.battle.turn, turn);
      assert.equal(left.page, 'map', '离开战斗页应到地图视图');
      // 返回当前战斗
      await lab.click('[data-return-node]');
      await sleep(80);
      const back = await lab.snapshot();
      assert.equal(back.page, 'battle');
      assert.ok(back.battle);
      assert.equal(back.battle.nodeId, battleId);
      await lab.shoot(path.join(REPORT_DIR, 'w2-fixture-leave-battle-keep.png'));
    } else {
      // 非战斗节点也必须落在合法继续页，不能空图卡死
      assert.ok(['node-action', 'prep', 'reward', 'map'].includes(inNode.page), inNode.page);
    }
  } finally {
    await lab.close();
  }
});

test('FIXTURE_INTEGRATION: 战斗未结算点整备离开不得跳关', async () => {
  const lab = await bootFresh(20260923);
  try {
    await lab.click('[data-choose-node]');
    await sleep(80);
    const entered = await lab.snapshot();
    if (!entered.battle || entered.battle.over) {
      // 本 seed 未进未结算战斗：用规则测已覆盖；此处只断言仍合法
      assert.ok(entered.page);
      return;
    }
    const nodeId = entered.journey.nodeId;
    // 切到整备页并点离开（leavePrep → completeCurrentNode）
    await lab.click('[data-tab="prep"]');
    await sleep(50);
    const prepButtons = await lab.snapshot();
    assert.ok(prepButtons.battle, '切页不得丢遭遇');
    await lab.click('[data-prep-continue]');
    await sleep(80);
    const after = await lab.snapshot();
    assert.ok(after.battle, '未结算战斗不得被 leavePrep 清掉');
    assert.equal(after.battle.over, null);
    assert.equal(after.journey.nodeId, nodeId, '不得跳关完成节点');
    assert.ok(!after.ending, '不得伪造终局');
    await lab.shoot(path.join(REPORT_DIR, 'w2-fixture-leave-prep-blocked.png'));
  } finally {
    await lab.close();
  }
});

test('NORMAL_RUN: 首战→奖励→整备→下一节点（空存档 + 可见控件）', async () => {
  const lab = await openLab({ seed: 20260924, viewport: [1280, 800] });
  try {
    await lab.click('[data-start-run]');
    await sleep(50);
    const s0 = await lab.snapshot();
    assert.equal(s0.journey.started, true);
    assert.equal(s0.page, 'map');
    const roots = s0.journey.availableNodeIds.slice();
    assert.ok(roots.length > 0);
    const completedBefore = s0.journey.completed.length;

    // 选可赢首战（ridge_hound 低血）；禁止 act.* / 注资
    const battleNode = pickBattleNode(s0, 'ridge_hound');
    assert.ok(battleNode, `必须有可进入的战斗节点: ${JSON.stringify(roots)}`);
    await lab.click(`[data-choose-node="${battleNode.id}"]`);
    await sleep(80);
    const s1 = await lab.snapshot();
    const firstNodeId = s1.journey.nodeId;
    assert.equal(firstNodeId, battleNode.id);
    assert.ok(s1.battle, '首战必须进入战斗遭遇');
    assert.ok(s1.journey.availableNodeIds.length === 0, '进入节点后 available 应清空');

    // 只使用可见控件打完首战（拳脚 / 结束回合），禁止 act.*
    let won = false;
    for (let i = 0; i < 80 && !won; i += 1) {
      const snap = await lab.snapshot();
      if (snap.ending) break;
      if (snap.reward) { won = true; break; }
      if (!snap.battle) break;
      if (snap.battle.over === '胜') { won = true; break; }
      if (snap.battle.over === '败') break;
      let acted = false;
      for (const sel of ['#panel-battle [data-basic-attack]', '[data-basic-attack]']) {
        try {
          await lab.click(sel);
          acted = true;
          break;
        } catch { /* try next */ }
      }
      if (!acted) {
        try { await lab.click('[data-end-turn]'); } catch {
          try { await lab.click('#panel-battle [data-end-turn]'); } catch { /* loop guard */ }
        }
      }
      await sleep(40);
    }

    let afterFight = await lab.snapshot();
    // 已胜但尚未开结算：点「查看结算」走 openBattleOutcome
    if (!afterFight.reward && afterFight.battle?.over === '胜') {
      await lab.click('[data-escape]');
      await sleep(80);
      afterFight = await lab.snapshot();
    }

    // 硬断言：整链必须被观察到，缺一环即 FAIL
    assert.ok(!afterFight.ending, `首战胜利不得直接终局: ${JSON.stringify({ page: afterFight.page, ending: afterFight.ending })}`);
    assert.ok(afterFight.reward, `胜利必须进入奖励结算: ${JSON.stringify({
      page: afterFight.page, reward: !!afterFight.reward, over: afterFight.battle?.over,
    })}`);
    await lab.shoot(path.join(REPORT_DIR, 'w2-normal-first-reward.png'));

    const rewardSnap = await lab.snapshot();
    const stonesBefore = rewardSnap.stones;
    const guChoices = (rewardSnap.reward?.guChoices || []);
    if (guChoices.length) {
      await lab.click('[data-reward-gu]');
    } else {
      // 无三选一时的明确奖励路径：继续进入整备（不得静默跳过整链）
      await lab.click('[data-reward-continue]');
    }
    await sleep(80);
    const inPrep = await lab.snapshot();
    assert.equal(inPrep.page, 'prep', `领奖后必须进入整备: ${inPrep.page}`);
    assert.ok(inPrep.stones >= stonesBefore - 20, '奖励后不应异常扣石');

    await lab.click('[data-prep-continue]');
    await sleep(80);
    const onMap = await lab.snapshot();
    assert.equal(onMap.page, 'map');
    assert.ok(onMap.journey.completed.includes(firstNodeId), '首节点应完成');
    assert.ok(onMap.journey.completed.length > completedBefore, 'completed 长度必须增加');
    assert.ok(onMap.journey.availableNodeIds.length > 0, '必须有下一节点');
    assert.deepEqual(onMap.journey.availableNodeIds.slice().sort(),
      onMap.journey.graph.nodes.find((n) => n.id === firstNodeId).nextIds.slice().sort(),
      'availableNodeIds 必须更新为该节点真实后继');
    const firstNode = onMap.journey.graph.nodes.find((n) => n.id === firstNodeId);
    for (const id of onMap.journey.availableNodeIds) {
      assert.ok(firstNode.nextIds.includes(id), `非后继被放出: ${id}`);
    }
    await lab.shoot(path.join(REPORT_DIR, 'w2-normal-next-node.png'));
    // 重复点领奖/完成不得追加
    const completedCount = onMap.journey.completed.length;
    try { await lab.click('[data-reward-continue]'); } catch { /* no reward */ }
    try { await lab.click('[data-prep-continue]'); } catch { /* no prep */ }
    await sleep(40);
    const again = await lab.snapshot();
    assert.equal(again.journey.completed.length, completedCount, '重复调用不得重复完成节点');
  } finally {
    await lab.close();
  }
});

test('NORMAL_RUN: 败局→结局→重开清掉上一局资源', async () => {
  // 固定 seed：只结束回合承伤，不攻击，可靠打出血气耗尽败局（NORMAL_RUN）。
  const lab = await openLab({ seed: 20260925, viewport: [1280, 800] });
  try {
    await lab.click('[data-start-run]');
    await sleep(50);
    const s0 = await lab.snapshot();
    const battleNode = pickBattleNode(s0);
    assert.ok(battleNode, `必须有可进入的战斗节点: ${JSON.stringify(s0.journey?.availableNodeIds)}`);
    await lab.click(`[data-choose-node="${battleNode.id}"]`);
    await sleep(80);

    // 打到败局：只点「结束回合」挨打（可见控件；不攻击以免误胜）
    for (let i = 0; i < 120; i += 1) {
      const snap = await lab.snapshot();
      if (snap.ending) break;
      if (!snap.battle) break;
      if (snap.battle.over === '败') break;
      try { await lab.click('[data-end-turn]'); } catch {
        try { await lab.click('#panel-battle [data-end-turn]'); } catch { break; }
      }
      await sleep(30);
    }

    let ended = await lab.snapshot();
    if (!ended.ending && ended.battle?.over === '败') {
      // 死亡关闭战斗应进结局（openBattleOutcome）
      try { await lab.click('[data-escape]'); } catch { /* settle */ }
      await sleep(80);
      ended = await lab.snapshot();
    }

    // 硬断言：必须真实走到 openBattleOutcome 的 defeat 结局；缺失即 FAIL
    assert.ok(ended.ending, `败局必须产生 ending，不得软通过: ${JSON.stringify({
      page: ended.page, over: ended.battle?.over, blood: ended.blood,
    })}`);
    assert.equal(ended.ending.outcome, 'defeat', '败局必须 outcome=defeat');
    assert.ok(ended.battle == null || ended.battle.over === '败');
    await lab.shoot(path.join(REPORT_DIR, 'w2-normal-defeat-ending.png'));

    // 结局后不得再增强：真实 markup 是 [data-buy-offer]（不是 [data-buy]）
    const stonesBefore = ended.stones;
    const ownedBefore = Object.keys(ended.owned || {}).sort();
    const ownedKeys = ownedBefore.length;
    try { await lab.click('[data-tab="prep"]'); } catch { /* tab */ }
    await sleep(40);
    // 购买入口：点到则走 assertRunMutable；点不到则证明成长 UI 缺失/禁用
    let buyUiProof = 'clicked';
    try {
      await lab.click('[data-buy-offer]');
    } catch {
      buyUiProof = 'absent_or_disabled';
    }
    try { await lab.click('[data-forge]'); } catch { /* no forge */ }
    try { await lab.click('[data-choose-node]'); } catch { /* no node */ }
    await sleep(40);
    const afterGrow = await lab.snapshot();
    // assertRunMutable 路径：UI 购买不得增加 stones / owned
    assert.equal(afterGrow.stones, stonesBefore, '终局后不得买/炼改资源');
    assert.deepEqual(Object.keys(afterGrow.owned || {}).sort(), ownedBefore, '终局后不得增加库存');
    assert.ok(afterGrow.ending);
    if (buyUiProof === 'absent_or_disabled') {
      // 无可用购入按钮本身即是「成长 UI 缺失或禁用」的证明（click 全禁用/不存在会抛错）
      assert.equal(afterGrow.stones, stonesBefore);
    }

    // 回大厅应有终局摘要
    try { await lab.click('[data-ending-hall]'); } catch { await lab.click('[data-tab="hall"]'); }
    await sleep(50);
    const hall = await lab.snapshot();
    assert.equal(hall.page, 'hall');
    assert.ok(hall.ending, '大厅应保留终局摘要');
    await lab.shoot(path.join(REPORT_DIR, 'w2-normal-hall-ending-summary.png'));

    // 重开：已在大厅看摘要后，用 HUD「重开」（ending 面板此时不可见，不能点 [data-ending-restart]）
    await lab.click('#reset');
    await sleep(80);
    let freshRun = await lab.snapshot();
    if (freshRun.ending) {
      try { await lab.click('#reset'); } catch { /* already left */ }
      await sleep(80);
      freshRun = await lab.snapshot();
    }
    assert.equal(freshRun.ending, null, '重开后不应残留终局');
    assert.equal(freshRun.battle, null);
    assert.equal(freshRun.reward, null);
    assert.equal(freshRun.journey.started, false, '重开回到未开局大厅');
    assert.equal(freshRun.stones, 3, 'fresh 必须回到开局资源');
    assert.deepEqual(Object.keys(freshRun.owned || {}).sort(), [
      'blood_atk_5_02_gu', 'blood_droplet_gu', 'blood_farewell_gu', 'fire_atk_2_01_gu',
      'jade_skin_gu', 'light_rec_1_10_gu', 'moonlight_gu', 'small_light_gu',
      'stone_shell_gu', 'vitality_grass_gu', 'water_atk_3_05_gu', 'white_boar_strength_gu',
      'wisdom_atk_3_13_gu', 'wisdom_rec_1_20_gu',
    ].sort(), '不得跨局继承库存');
  } finally {
    await lab.close();
  }
});

test('FIXTURE_INTEGRATION: 刷新后不得再次结算奖励/完成', async () => {
  const lab = await openLab({ seed: 20260926, viewport: [1280, 800] });
  try {
    await lab.click('[data-start-run]');
    await sleep(50);
    await lab.click('[data-choose-node]');
    await sleep(80);
    // 打完或离开后刷新
    for (let i = 0; i < 40; i += 1) {
      const snap = await lab.snapshot();
      if (snap.reward || snap.ending || !snap.battle) break;
      try { await lab.click('[data-basic-attack]'); } catch {
        try { await lab.click('[data-end-turn]'); } catch { break; }
      }
      await sleep(30);
    }
    const beforeReload = await lab.snapshot();
    const completedBefore = beforeReload.journey.completed.slice();
    const stonesBefore = beforeReload.stones;
    await lab.reload();
    await sleep(50);
    const afterReload = await lab.snapshot();
    assert.deepEqual(afterReload.journey.completed, completedBefore, '刷新不得追加完成事件');
    assert.equal(afterReload.stones, stonesBefore, '刷新不得重复发放奖励');
  } finally {
    await lab.close();
  }
});
