/* lab.html 整局验收驱动（2026-09-26 复核批）。
 * 与 autoplay_lab.mjs 的差别：一次会话内覆盖整局验收四项——
 *   ① 胜利轨迹：完整走到 ending，全程记录节点序列与资源账本；
 *   ② 重载续玩：地图页与战斗中各重载一次，state 深比较；
 *   ③ 异闻代价：accept_event 结算前后 blood/stones 精确断言（node.event.health_cost / stone_gain）；
 *   ④ 旧种子复走：ending 后经大厅 archive-replay 重开，图与节点前缀须与原局一致。
 * 只点可见按钮，不写 state；判定读 __labSnapshot 只读序列化。
 * 用法：
 *   node tools/acceptance_lab.mjs --seed 7 --difficulty easy --policy balanced --shots <dir>
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { openLab } from '../tests/helpers/lab_browser.mjs';

const MAX_ACTIONS = 20000;
const STALL_LIMIT = 40;
const VIEWPORT = [1280, 720];
const REPLAY_PREFIX_NODES = 10;

function parseArgs(argv) {
  const opts = { seed: 101, difficulty: 'normal', policy: 'balanced', shots: '', edge: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === '--seed') opts.seed = Number(next());
    else if (a === '--difficulty') opts.difficulty = String(next());
    else if (a === '--policy') opts.policy = String(next());
    else if (a === '--shots') opts.shots = String(next());
    else if (a === '--edge') opts.edge = String(next());
    else throw new Error(`未知参数: ${a}`);
  }
  if (!['easy', 'normal', 'hard'].includes(opts.difficulty)) throw new Error(`--difficulty 无效: ${opts.difficulty}`);
  if (!['balanced', 'refine', 'gu_first', 'survival', 'moon'].includes(opts.policy)) throw new Error(`--policy 无效: ${opts.policy}`);
  if (!Number.isFinite(opts.seed)) throw new Error('--seed 无效');
  return opts;
}

function clickFirstSelectors(policy) {
  if (policy === 'refine') {
    return {
      battle: ['[data-basic-attack]', '[data-observe]', '[data-use]', '[data-use-gu]', '[data-end-turn]', '[data-exhaust]'],
      prep: ['[data-forge]', '[data-attune]', '[data-buy-offer]', '[data-km]', '[data-break]', '[data-prep-continue]'],
    };
  }
  if (['gu_first', 'survival', 'moon'].includes(policy)) {
    // 蛊技优先：拳脚在战斗内是带 ⚠ 的高风险动作，只有无技可用时才落到它。
    return {
      battle: ['[data-use-gu]', '[data-use]', '[data-observe]', '[data-basic-attack]', '[data-end-turn]'],
      prep: ['[data-buy-offer]', '[data-attune]', '[data-km]', '[data-break]', '[data-forge]', '[data-prep-continue]'],
    };
  }
  return {
    battle: ['[data-basic-attack]', '[data-use]', '[data-use-gu]', '[data-end-turn]'],
    prep: ['[data-buy-offer]', '[data-attune]', '[data-km]', '[data-break]', '[data-forge]', '[data-prep-continue]'],
  };
}

async function clickFirst(lab, selectors, skip = new Set()) {
  for (const selector of selectors) {
    if (skip.has(selector)) continue;
    try {
      await lab.click(selector);
      return selector;
    } catch { /* disabled, invisible, or missing */ }
  }
  return null;
}

// 按玩家可见的整备按钮锻体；不会写入或注入游戏状态。
async function trainAtPrep(lab, snap) {
  const rows = (snap.modifierLedger || []).filter(r => r.sourceGuDefinitionId === 'white_boar_strength_gu' && r.sourceEffectId === 'body_training');
  if (!snap.owned?.white_boar_strength_gu || !snap.prepFor || snap.qi < 1 || snap.stones < 1
    || rows.some(r => r.createdAt === snap.prepFor) || rows.reduce((n, r) => n + r.amount, 0) >= 3) return null;
  await lab.click('[data-prep-tab="gu"]');
  try {
    await lab.click('[data-train-body="white_boar_strength_gu"]');
    return 'body_training';
  } finally { await lab.click('[data-prep-tab="shop"]'); }
}

async function investAtPrep(lab, snap, policy) {
  if (!['survival', 'moon'].includes(policy)) return null;
  const leafActions = [];
  if (snap.owned.vitality_leaf_gu && snap.blood <= snap.bloodMax - 3
    && snap.leafRecoveryNodeId !== snap.journey.nodeId) leafActions.push('[data-use-leaf="vitality_leaf_gu"]');
  if (snap.owned.vitality_grass_gu && snap.cultivation >= 2 && snap.qi >= 2
    && snap.leafProductionVisit !== snap.prepFor) leafActions.push('[data-produce-leaf="vitality_grass_gu"]');
  if (leafActions.length) {
    await lab.click('[data-prep-tab="gu"]');
    let acted;
    try { acted = await clickFirst(lab, leafActions); }
    finally { await lab.click('[data-prep-tab="shop"]'); }
    if (acted) return acted;
  }
  if (policy === 'moon') {
    if (!snap.owned.moon_glow_gu) {
      await lab.click('[data-prep-tab="alchemy"]');
      let acted;
      try {
        if ((snap.owned.small_light_gu || 0) < 2 && snap.wild?.small_light_gu && snap.qi >= 4)
          acted = await clickFirst(lab, ['[data-attune="small_light_gu"]']);
        else acted = await clickFirst(lab, ['[data-forge="moonlight_glow"]']);
      } finally { await lab.click('[data-prep-tab="shop"]'); }
      return acted || await clickFirst(lab, ['[data-prep-continue]']);
    }
    if (snap.cultivation < 2) return await clickFirst(lab, ['[data-break]', '[data-prep-continue]']);
    return await clickFirst(lab, ['[data-prep-continue]']);
  }
  const strength = (snap.modifierLedger || []).filter(r => r.sourceGuDefinitionId === 'white_boar_strength_gu' && r.sourceEffectId === 'body_training').reduce((sum, r) => sum + Number(r.amount), 0);
  if (strength >= 3 && !snap.owned.white_jade_gu && snap.owned.white_boar_strength_gu && snap.owned.jade_skin_gu) {
    await lab.click('[data-prep-tab="alchemy"]');
    let forged = null;
    try { forged = await clickFirst(lab, ['[data-forge="white_jade_basic"]']); }
    finally { await lab.click('[data-prep-tab="shop"]'); }
    // 买零散蛊与攒钱合炼是实际机会成本；不足时保留资金继续行程。
    return forged || await clickFirst(lab, ['[data-prep-continue]']);
  }
  if (snap.owned.white_jade_gu && snap.cultivation < 2) {
    return await clickFirst(lab, ['[data-break]', '[data-prep-continue]']);
  }
  return null;
}

function tacticalSelectors(snap, policy) {
  if (!['gu_first', 'survival', 'moon'].includes(policy)) return [];
  const target = snap.battle.enemies.find(e => e.id === snap.battle.targetId);
  const out = [];
  // 意图已经展示在敌人按钮上：先选中本回合会耗尽魂魄的敌手。
  const soulThreat = snap.battle.enemies.find(e => e.hp > 0
    && Number(e.enemyIntent?.soul_drain || 0) >= snap.soul
    && Number(e.enemyIntent?.soul_drain || 0) > 0);
  if (soulThreat && soulThreat.id !== snap.battle.targetId)
    return [`[data-target="${soulThreat.id}"]`];
  if (target?.problemAxis === 'info' && !target.revealed) out.push('[data-observe]');
  if (['survival', 'moon'].includes(policy)) {
    const incoming = snap.battle.enemies.filter(e => e.hp > 0).reduce((sum, e) => sum + Number(e.enemyIntent?.damage || 0), 0);
    // 已展示的肉身力量用于无耗出拳；闪避敌仍需月道补足命中。
    const human = snap.battle.playerHuman;
    const strength = Number(human?.baseline.attack || 3) + (human?.modifierLedger || []).filter(r => r.active && r.attribute === 'attack' && r.persistence === 'session_permanent').reduce((sum, r) => sum + Number(r.amount), 0);
    if (incoming >= snap.blood && (target?.hp > strength || target?.problemAxis === 'evasion')) {
      out.push('[data-use-gu="white_jade_gu::1"]', '[data-use-gu="stone_shell_gu::1"]', '[data-use-gu="jade_skin_gu::1"]');
    }
    if (soulThreat?.id === target?.id && target.hp > strength && snap.owned.moon_glow_gu)
      out.push('[data-use-gu="moon_glow_gu::1"]');
    if (policy === 'survival' && strength >= 4 && target?.problemAxis !== 'evasion') out.push('[data-basic-attack]');
    if (snap.blood < snap.bloodMax && incoming === 0) out.push('[data-use-gu="vitality_leaf_gu::1"]');
  }
  if (policy === 'moon') {
    // 仅消费已揭示的反击提示：先用拳脚试探，避免吞掉高耗月芒。
    if (target?.revealed && (target.reactions || []).some(r => r.trigger === 'direct_strike'
      && r.window === 'before_damage' && !(r.counter_status === 'bound' && target.flags.enemy_bound)
      && !(r.counter_status === 'guarded' && target.flags.guarded))) out.push('[data-basic-attack]');
    if (snap.owned.moon_glow_gu) out.push('[data-use-gu="moon_glow_gu::1"]');
  }
  if (snap.qi >= 3 && snap.thought >= 2 && snap.owned.moonlight_gu && snap.owned.small_light_gu
    && !snap.battle.guUsedThisTurn['moonlight_gu::1'] && !snap.battle.turnSupports.guTargets?.moonlight_gu)
    out.push('[data-use-gu="small_light_gu::1"]');
  return out;
}

function deepDiff(a, b, prefix = '', out = []) {
  if (a === b) return out;
  if (typeof a !== typeof b || a == null || b == null || typeof a !== 'object') {
    out.push(`${prefix || '<root>'}: ${JSON.stringify(a)} -> ${JSON.stringify(b)}`);
    return out;
  }
  if (Array.isArray(a) !== Array.isArray(b)) {
    out.push(`${prefix || '<root>'}: array mismatch`);
    return out;
  }
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const k of keys) deepDiff(a[k], b[k], prefix ? `${prefix}.${k}` : k, out);
  return out;
}

function pickNodeId(state, visited, policy) {
  const available = state?.journey?.availableNodeIds || [];
  if (!available.length) return null;
  const nodes = state?.journey?.graph?.nodes || [];
  const byId = new Map(nodes.map((n) => [n.id, n]));
  // 生存策略只用已展示的路线类型与当前气血，不读取未来随机结果。
  if (['survival', 'moon'].includes(policy) && state.blood < state.bloodMax * 0.75) {
    const rest = available.find(id => ['rest', 'rest_site'].includes(byId.get(id)?.type));
    if (rest) return rest;
  }
  // 异闻优先：优先进入事件节点（保证代价结算覆盖）；否则按可见顺序取第一个。
  const eventNode = available.find((id) => byId.get(id)?.type === 'event' && !visited.includes(id));
  if (['survival', 'moon'].includes(policy) && state.blood < state.bloodMax * 0.75) {
    const safer = available.find(id => { const node = byId.get(id); return node && !['elite', 'boss'].includes(node.type) && !(node.type === 'event' && Number(node.event?.health_cost || 0) > 0); });
    if (safer) return safer;
  }
  return eventNode || available[0];
}

async function runFullRun({ lab, seed, difficulty, policy, shots, record }) {
  const actions = clickFirstSelectors(policy);
  const visited = [];
  const eventChecks = [];
  let reloadMapCheck = null;
  let reloadBattleCheck = null;
  let mapReloadDone = false;
  let battleReloadDone = false;
  let outcome = 'timeout';
  let terminalReason = '';
  const skip = new Set();
  let stall = 0;
  let lastKey = '';
  let unchangedCombat = 0;
  let lastCombatProgress = '';
  const stateAt = () => record.stateAt();

  let snap = await lab.snapshot();
  const initial = {
    seed: snap.seed,
    roots: snap.journey.graph.roots,
    available0: snap.journey.availableNodeIds,
    difficulty: snap.journey.difficulty,
  };
  record.push({ kind: 'boot', initial });

  for (let steps = 0; steps < MAX_ACTIONS; steps += 1) {
    snap = await lab.snapshot();
    if (!snap) throw new Error('snapshot 丢失');
    if (snap.ending?.outcome) {
      outcome = snap.ending.outcome;
      terminalReason = snap.ending.title || snap.ending.outcome;
      record.push({ kind: 'ending', outcome, terminalReason, ending: snap.ending });
      if (shots) await lab.shoot(path.join(shots, `ending-seed${seed}.png`));
      break;
    }

    let acted = null;

    // ① 奖励页
    if (snap.page === 'reward' || snap.reward) {
      acted = await clickFirst(lab, ['[data-reward-gu]', '[data-reward-continue]']);
      if (acted) record.push({ step: steps, kind: 'reward', via: acted, choices: snap.reward?.guChoices });
    }

    // ② 战斗中
    if (!acted && snap.battle && !snap.battle.over) {
      // 战斗中重载（一次）：第 2 回合起、本战斗未被重载过
      if (!battleReloadDone && snap.battle.turn >= 2) {
        battleReloadDone = true;
        const before = snap;
        if (shots) await lab.shoot(path.join(shots, `reload-battle-before-seed${seed}.png`));
        await lab.reload();
        let after = await lab.snapshot();
        const boot = await lab.bootInfo();
        const cont = await clickFirst(lab, ['[data-continue-run]', '[data-go-map]']);
        after = await lab.snapshot();
        const battleDiff = deepDiff(before.battle, after.battle);
        // boot 的 resumePage()：存档带 battle 时直接落战斗页，无需「继续」按钮（main.js:143-149）。
        // 可续玩判据 = 状态还原 + （点了继续 或 战斗原样可操作）。
        const battleResumed = (!!after.battle && !after.battle.over) || !!cont;
        reloadBattleCheck = {
          restored: !battleDiff.length,
          resumed: battleResumed,
          landedPage: after.page || '',
          inProgress: boot.inProgress,
          diffs: battleDiff.slice(0, 20),
          turn: before.battle.turn,
          enemiesBefore: (before.battle.enemies || []).map((e) => `${e.id}:${e.hp}`),
          enemiesAfter: (after.battle?.enemies || []).map((e) => `${e.id}:${e.hp}`),
        };
        record.push({ kind: 'reload_battle', check: reloadBattleCheck });
        if (shots) await lab.shoot(path.join(shots, `reload-battle-after-seed${seed}.png`));
        acted = 'reload_battle';
      } else {
        const before = snap;
        const tactical = tacticalSelectors(snap, policy);
        acted = await clickFirst(lab, [...tactical, ...actions.battle], skip);
        if (acted) {
          const afterSnap = await lab.snapshot();
          if (JSON.stringify(afterSnap.battle) === JSON.stringify(before.battle)
            && afterSnap.qi === before.qi && afterSnap.thought === before.thought
            && afterSnap.blood === before.blood) {
            skip.add(acted);
            stall += 1;
          } else {
            skip.clear();
            stall = 0;
          }
        }
      }
    }

    // ③ 战斗结束结算
    if (!acted && snap.battle?.over) {
      acted = await clickFirst(lab, ['[data-reward-continue]', '[data-prep-continue]', '[data-go-map]', '[data-open-outcome]']);
      if (acted) record.push({ step: steps, kind: 'settle', via: acted });
    }

    // ④ 整备页
    if (!acted && (snap.page === 'prep' || snap.prepFor)) {
      acted = (policy === 'moon' ? null : await trainAtPrep(lab, snap)) || await investAtPrep(lab, snap, policy) || await clickFirst(lab, actions.prep);
      if (acted) record.push({ step: steps, kind: 'prep', via: acted });
    }

    // ⑤ 节点动作页（含异闻）
    if (!acted && !snap.battle) {
      const nodeId = snap.journey?.nodeId;
      const node = nodeId ? (snap.journey.graph.nodes || []).find((n) => n.id === nodeId) : null;
      const isEventNode = node?.type === 'event';
      if (isEventNode) {
        const ev = node.event || {};
        const before = snap;
        let via = null;
        try {
          await lab.click('[data-node-action="accept_event"]');
          via = 'accept_event';
        } catch {
          try {
            await lab.click('[data-node-action="leave"]');
            via = 'leave';
          } catch { via = null; }
        }
        if (via) {
          const after = await lab.snapshot();
          const check = {
            nodeId,
            eventId: ev.id || null,
            title: ev.title || '',
            healthCost: Number(ev.health_cost || 0),
            stoneGain: Number(ev.stone_gain || 0),
            choice: via,
            bloodBefore: before.blood,
            bloodAfter: after.blood,
            stonesBefore: before.stones,
            stonesAfter: after.stones,
            acceptBlocked: via === 'leave' && Number(ev.health_cost || 0) > 0 && before.blood <= Number(ev.health_cost || 0),
          };
          if (via === 'accept_event') {
            check.bloodDeltaOk = after.blood === before.blood - Number(ev.health_cost || 0);
            check.stoneDeltaOk = after.stones === before.stones + Number(ev.stone_gain || 0);
          }
          eventChecks.push(check);
          record.push({ step: steps, kind: 'event', check });
          if (shots) await lab.shoot(path.join(shots, `event-seed${seed}-${eventChecks.length}.png`));
          acted = `event:${via}`;
        }
      }
      if (!acted) {
        acted = await clickFirst(lab, ['[data-node-action]']);
        if (acted) record.push({ step: steps, kind: 'node_action', via: acted, nodeId });
      }
    }

    // ⑥ 选节点
    if (!acted && !snap.battle && !snap.prepFor) {
      const nodeId = pickNodeId(snap, visited, policy);
      if (nodeId) {
        try {
          await lab.click(`[data-choose-node="${nodeId}"]`);
          visited.push(nodeId);
          record.push({ step: steps, kind: 'choose_node', nodeId });
          acted = `choose:${nodeId}`;
          await clickFirst(lab, ['[data-start-encounter]']);
        } catch { /* 不可选 */ }
      }
    }

    // ⑦ 导航
    if (!acted) {
      acted = await clickFirst(lab, ['[data-go-map]', '[data-prep-continue]']);
      if (acted) record.push({ step: steps, kind: 'nav', via: acted });
    }

    if (!acted) {
      record.push({ step: steps, kind: 'softlock', summary: { page: snap.page, battle: !!snap.battle, prepFor: snap.prepFor } });
      outcome = 'softlock';
      break;
    }

    const afterAction = await lab.snapshot();
    record.push({ step: steps, kind: 'action_result', via: acted,
      before: { blood: snap.blood, qi: snap.qi, thought: snap.thought, stones: snap.stones, cultivation: snap.cultivation, owned: snap.owned },
      after: { blood: afterAction.blood, qi: afterAction.qi, thought: afterAction.thought, stones: afterAction.stones, cultivation: afterAction.cultivation, owned: afterAction.owned },
      enemiesBefore: snap.battle?.enemies.map(e => ({ id: e.id, hp: e.hp, intent: e.enemyIntent })),
      enemiesAfter: afterAction.battle?.enemies.map(e => ({ id: e.id, hp: e.hp })),
      log: afterAction.battle?.log.slice(snap.battle?.log.length || 0),
      events: afterAction.eventLog?.slice(snap.eventLog?.length || 0),
    });

    // ⑧ 地图页重载（一次）：完成 ≥6 节点后、不在战斗
    if (!mapReloadDone && !snap.battle && snap.page === 'map'
      && (snap.journey?.completed?.length || 0) >= 6) {
      mapReloadDone = true;
      const before = await stateAt();
      if (shots) await lab.shoot(path.join(shots, `reload-map-before-seed${seed}.png`));
      await lab.reload();
      const boot = await lab.bootInfo();
      await clickFirst(lab, ['[data-continue-run]', '[data-go-map]']);
      const after = await stateAt();
      const diffs = deepDiff(before, after);
      reloadMapCheck = {
        restored: diffs.length === 0,
        inProgress: boot.inProgress,
        diffCount: diffs.length,
        diffs: diffs.slice(0, 20),
        completedBefore: before.journey?.completed?.length ?? null,
        completedAfter: after.journey?.completed?.length ?? null,
      };
      record.push({ kind: 'reload_map', check: reloadMapCheck });
      if (shots) await lab.shoot(path.join(shots, `reload-map-after-seed${seed}.png`));
      continue;
    }

    const combatProgress = snap.battle ? JSON.stringify([
      snap.battle.nodeId, snap.blood, snap.qi, snap.thought, snap.soul, snap.lifeTime,
      snap.battle.enemies.map(enemy => [enemy.id, enemy.hp, enemy.statuses, enemy.flags]),
      snap.battle.delayedEffects.map(entry => [entry.label, Math.max(0, entry.dueTurn - snap.battle.turn)]),
    ]) : '';
    unchangedCombat = combatProgress && combatProgress === lastCombatProgress ? unchangedCombat + 1 : 0;
    lastCombatProgress = combatProgress;
    if (unchangedCombat >= STALL_LIMIT) {
      record.push({ kind: 'combat_stalled', nodeId: snap.battle.nodeId, turn: snap.battle.turn, resources: { blood: snap.blood, qi: snap.qi, thought: snap.thought, soul: snap.soul }, enemies: snap.battle.enemies.map(enemy => ({ id: enemy.id, hp: enemy.hp, axis: enemy.problemAxis })), log: snap.battle.log.slice(-24) });
      outcome = 'stalled';
      terminalReason = '连续行动没有改变气血、真元、念头、敌人或待结算效果';
      break;
    }
    const key = JSON.stringify([
      snap.page, snap.ending?.outcome || '', snap.battle?.over || '',
      snap.battle?.enemies.map(enemy => [enemy.id, enemy.hp, enemy.statuses, enemy.flags]),
      snap.thought, snap.soul, snap.lifeTime,
      snap.battle?.delayedEffects.map(entry => [entry.label, Math.max(0, entry.dueTurn - snap.battle.turn)]),
      snap.stones, snap.blood, snap.qi, snap.journey?.completed?.length,
    ]);
    if (key === lastKey) {
      stall += 1;
      if (stall >= STALL_LIMIT) {
        record.push({ kind: 'stalled', key });
        outcome = 'stalled';
        break;
      }
    } else {
      stall = 0;
      lastKey = key;
    }
  }

  const finalSnap = await lab.snapshot();
  return {
    outcome,
    terminalReason,
    visited,
    eventChecks,
    reloadMapCheck,
    reloadBattleCheck,
    initial,
    final: {
      blood: finalSnap?.blood, stones: finalSnap?.stones, life: finalSnap?.lifeTime,
      soul: finalSnap?.soul, soulMax: finalSnap?.soulMax,
      completed: finalSnap?.journey?.completed?.length ?? null,
      ending: finalSnap?.ending ? { outcome: finalSnap.ending.outcome, title: finalSnap.ending.title, turn: finalSnap.ending.turn } : null,
    },
  };
}

async function replayFromHall({ lab, seed, policy, shots, record, originalVisited, originalInitial }) {
  // 终局页 → 大厅 → 复走按钮 → 校验新局种子/图与原局初始一致 → 前缀节点一致
  const cont = await clickFirst(lab, ['[data-ending-hall]', '[data-go-map]']);
  record.push({ kind: 'to_hall', via: cont });
  if (shots) await lab.shoot(path.join(shots, `hall-archive-seed${seed}.png`));
  let clicked = null;
  try {
    await lab.click('.archive-replay');
    clicked = true;
  } catch { clicked = false; }
  if (!clicked) return { ok: false, reason: 'archive_replay_button_missing' };
  const after = await lab.snapshot();
  const seedOk = after.seed === seed;
  const rootsOk = JSON.stringify(after.journey?.graph?.roots) === JSON.stringify(originalInitial.roots);
  const availableOk = JSON.stringify(after.journey?.availableNodeIds) === JSON.stringify(originalInitial.available0);
  record.push({ kind: 'replay_started', seedOk, rootsOk, availableOk, newSeed: after.seed });

  // 前缀重走：同一策略走 REPLAY_PREFIX_NODES 个节点，节点序列须一致
  const actions = clickFirstSelectors(policy);
  const visited = [];
  let stall = 0;
  for (let steps = 0; steps < MAX_ACTIONS * 2; steps += 1) {
    const snap = await lab.snapshot();
    if (!snap) throw new Error('replay snapshot 丢失');
    if (snap.ending?.outcome) break;
    if (visited.length >= Math.min(REPLAY_PREFIX_NODES, originalVisited.length)) break;

    let acted = null;
    if (snap.page === 'reward' || snap.reward) {
      acted = await clickFirst(lab, ['[data-reward-gu]', '[data-reward-continue]']);
    }
    if (!acted && snap.battle && !snap.battle.over) {
      acted = await clickFirst(lab, [...tacticalSelectors(snap, policy), ...actions.battle]);
    }
    if (!acted && snap.battle?.over) {
      acted = await clickFirst(lab, ['[data-reward-continue]', '[data-prep-continue]', '[data-go-map]', '[data-open-outcome]']);
    }
    if (!acted && (snap.page === 'prep' || snap.prepFor)) {
      acted = (policy === 'moon' ? null : await trainAtPrep(lab, snap)) || await investAtPrep(lab, snap, policy) || await clickFirst(lab, actions.prep);
    }
    if (!acted && !snap.battle) {
      const nodeId = (snap.journey?.nodeId) ? snap.journey.nodeId : null;
      const node = nodeId ? (snap.journey.graph.nodes || []).find((n) => n.id === nodeId) : null;
      const isEventNode = node?.type === 'event';
      if (isEventNode) {
        let via = null;
        try {
          await lab.click('[data-node-action="accept_event"]');
          via = 'accept_event';
        } catch {
          try { await lab.click('[data-node-action="leave"]'); via = 'leave'; } catch { via = null; }
        }
        acted = via ? `event:${via}` : null;
      }
      if (!acted) acted = await clickFirst(lab, ['[data-node-action]']);
    }
    if (!acted && !snap.battle && !snap.prepFor) {
      const nextExpected = originalVisited[visited.length];
      const nodeId = nextExpected || pickNodeId(snap, visited, policy);
      if (nodeId) {
        try {
          await lab.click(`[data-choose-node="${nodeId}"]`);
          visited.push(nodeId);
          acted = `choose:${nodeId}`;
          await clickFirst(lab, ['[data-start-encounter]']);
        } catch { /* 不可选 */ }
      }
    }
    if (!acted) {
      acted = await clickFirst(lab, ['[data-go-map]', '[data-prep-continue]']);
    }
    if (!acted) { stall += 1; if (stall > STALL_LIMIT) break; } else stall = 0;
  }

  const prefixOk = originalVisited.length >= visited.length
    && visited.every((id, i) => id === originalVisited[i]);
  if (shots) await lab.shoot(path.join(shots, `replay-prefix-seed${seed}.png`));
  return {
    ok: seedOk && rootsOk && availableOk && prefixOk,
    seedOk, rootsOk, availableOk, prefixOk,
    visited,
    expectedPrefix: originalVisited.slice(0, visited.length),
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const shots = opts.shots || null;
  if (shots) mkdirSync(shots, { recursive: true });
  const record = [];
  record.stateAt = async () => (await record._lab.snapshot());
  const lab = await openLab({ entry: path.resolve(import.meta.dirname, '../lab.html'), seed: opts.seed, viewport: VIEWPORT, edge: opts.edge || undefined });
  record._lab = lab;
  let result;
  try {
    await clickFirst(lab, [`[data-difficulty="${opts.difficulty}"]`]);
    const started = await clickFirst(lab, ['[data-start-run]']);
    if (!started) throw new Error('找不到开局按钮');

    const run = await runFullRun({ lab, seed: opts.seed, difficulty: opts.difficulty, policy: opts.policy, shots, record });

    let replay = null;
    if (run.outcome === 'victory' || run.outcome === 'defeat') {
      replay = await replayFromHall({ lab, seed: opts.seed, policy: opts.policy, shots, record, originalVisited: run.visited, originalInitial: run.initial });
    }

    const consoleErrors = lab.logs().filter((l) => l.includes('[exception]') || l.includes('[console.error]'));
    result = {
      seed: opts.seed,
      difficulty: opts.difficulty,
      policy: opts.policy,
      contentVersion: (await lab.bootInfo()).contentVersion,
      run,
      replay,
      consoleErrors,
      record: record.filter((x) => typeof x === 'object'),
    };
  } finally {
    await lab.close();
  }

  const outName = `acceptance-seed${opts.seed}-${opts.difficulty}-${opts.policy}.json`;
  if (shots) writeFileSync(path.join(shots, outName), JSON.stringify(result, null, 2));

  const victory = result.run.outcome === 'victory';
  const reloadOk = (!result.run.reloadMapCheck || result.run.reloadMapCheck.restored)
    && (!result.run.reloadBattleCheck || (result.run.reloadBattleCheck.restored && result.run.reloadBattleCheck.resumed));
  const eventOk = result.run.eventChecks.length > 0
    && result.run.eventChecks.every((c) => c.choice !== 'accept_event' || (c.bloodDeltaOk && c.stoneDeltaOk));
  const replayOk = !result.replay || result.replay.ok;
  const noErrors = result.consoleErrors.length === 0;

  const verdict = { victory, reloadOk, eventOk, replayOk, noErrors, outcome: result.run.outcome };
  console.log(JSON.stringify({
    seed: result.seed, difficulty: result.difficulty, ...verdict,
    events: result.run.eventChecks.length,
    completed: result.run.final.completed,
    detail: victory && reloadOk && replayOk && noErrors ? 'PASS' : 'SEE_JSON',
    jsonPath: shots ? path.join(shots, outName) : '(stdout only)',
  }, null, 2));
  if (!(victory && reloadOk && eventOk && replayOk && noErrors)) process.exit(1);
}

main().catch((err) => {
  console.error(`FAIL: ${err && err.message ? err.message : err}`);
  process.exit(1);
});
