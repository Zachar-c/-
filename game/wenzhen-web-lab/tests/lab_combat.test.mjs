/** W3: real browser actions plus an explicitly synthetic observe fixture. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { openLab } from './helpers/lab_browser.mjs';

const source = readFileSync(new URL('../js/main.js', import.meta.url), 'utf8');
test('ACTION_FIXTURE: observe preserves counter knowledge and charges once', () => {
  const foe = { id: 'fixture', hp: 10, currentCounter: 'intercept', revealed: false,
    knownCounters: ['draw_light'] };
  const state = { thought: 2, battle: { enemies: [foe], actionsUsed: 0, actionLimit: 2, log: [] } };
  let finished = 0;
  const ctx = vm.createContext({ state, assertRunMutable: () => true,
    targetOf: b => b.enemies[0], Sfx: { click() {} },
    finishPlayerAction: () => { finished += 1; }, toast() {} });
  for (const name of ['mvp_logic', 'combat_core'])
    vm.runInContext(readFileSync(new URL(`../js/${name}.js`, import.meta.url), 'utf8'), ctx);
  const start = source.indexOf('  observe() {');
  const end = source.indexOf('  useMove(id) {', start);
  assert.ok(start >= 0 && end > start);
  vm.runInContext(`const act = {${source.slice(start, end)}}; act.observe(); act.observe();`, ctx);
  assert.equal(foe.currentCounter, 'intercept');
  assert.equal(foe.revealed, true);
  assert.equal(foe.counterRevealed, true);
  assert.deepEqual(Array.from(foe.knownCounters), ['draw_light', 'intercept']);
  assert.equal(state.thought, 1);
  assert.equal(state.battle.actionsUsed, 1);
  assert.equal(finished, 1);
});

async function assertResourceHud(lab, snap) {
  assert.equal(await lab.text('#hud .pool.thought label'), '操控');
  for (const [id, value] of Object.entries({
    'hud-qi-num': `${Math.round(snap.qi)}/${snap.qiMax}`, 'hud-stone': String(snap.stones),
    'hud-blood': String(snap.blood), 'hud-thought': String(snap.thought),
    'hud-life': String(snap.lifeTime), 'hud-soul': `${snap.soul}/${snap.soulMax}`,
  })) assert.equal(await lab.text(`#${id}`), value, `${id} must match actual resources`);
}

async function enterBattle(lab) {
  await lab.click('[data-start-run]');
  const map = await lab.snapshot();
  const node = map.journey.graph.nodes.find(n =>
    map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
  assert.ok(node, 'normal start must offer a battle');
  await lab.click(`[data-choose-node="${node.id}"]`);
  const snap = await lab.snapshot();
  const foe = snap.battle.enemies.find(e => e.id === snap.battle.targetId);
  const reaction = foe.reactions.find(r =>
    r.trigger === 'direct_strike' && r.window === 'before_damage');
  assert.ok(reaction, 'selected encounter must have a direct-strike reaction');
  return { id: foe.id, flag: reaction.counter_status === 'bound' ? 'enemy_bound' : 'guarded' };
}

test('NORMAL_RUN: observed reaction swallows punch once, then permits the next punch', async () => {
  const lab = await openLab({ seed: 20260924 });
  try {
    const { id, flag } = await enterBattle(lab);
    await lab.click('[data-observe]');
    const before = await lab.snapshot();
    assert.equal(before.battle.enemies.find(e => e.id === id).revealed, true);
    await lab.click('[data-basic-attack]');
    const after = await lab.snapshot();
    assert.equal(after.battle.enemies.find(e => e.id === id).hp,
      before.battle.enemies.find(e => e.id === id).hp);
    assert.equal(after.battle.enemies.find(e => e.id === id).flags[flag], true);
    assert.ok(after.battle.log.some(line => line.includes('吞掉')));
    assert.equal(after.battle.turn, before.battle.turn + 1, 'one active action advances the turn');
    await lab.click('[data-basic-attack]');
    const next = await lab.snapshot();
    assert.ok(next.battle.enemies.find(e => e.id === id).hp <
      after.battle.enemies.find(e => e.id === id).hp, 'settled reaction must not swallow twice');
    assert.equal(next.thought, after.thought, 'basic attack does not spend battle thought');
    assert.equal(next.battle.turn, after.battle.turn + 1);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: hidden legacy reaction does not newly block a punch', async () => {
  const lab = await openLab({ seed: 20260924 });
  try {
    const { id } = await enterBattle(lab);
    const before = await lab.snapshot();
    await lab.click('[data-basic-attack]');
    const after = await lab.snapshot();
    assert.ok(after.battle.enemies.find(e => e.id === id).hp <
      before.battle.enemies.find(e => e.id === id).hp);
    assert.equal(after.thought, before.thought, 'basic attack does not spend battle thought');
    assert.equal(after.qi, before.qi);
    assert.equal(after.battle.turn, before.battle.turn + 1);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: Small Light prepares Moonlight without using the sole action and survives reload', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    assert.match(await lab.text('[data-starting-kit]'), /野生小光蛊/);
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    assert.deepEqual(Object.keys(map.owned).sort(), ['moonlight_gu', 'small_light_gu', 'jade_skin_gu', 'stone_shell_gu', 'vitality_leaf_gu', 'white_boar_strength_gu'].sort());
    const node = map.journey.graph.nodes.find(n =>
      map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(node);
    await lab.click(`[data-choose-node="${node.id}"]`);
    const before = await lab.snapshot();
    assert.match(await lab.text('[data-use-gu="moonlight_gu::1"]'), /击伤/);
    assert.match(await lab.text('[data-use-gu="vitality_leaf_gu::1"]'), /恢复气血/);
    assert.match(await lab.text('[data-use-gu="small_light_gu::1"]'), /操控 1/);
    await lab.click('[data-use-gu="small_light_gu::1"]');
    const prepared = await lab.snapshot();
    assert.equal(prepared.battle.turn, before.battle.turn);
    assert.equal(prepared.battle.actionsUsed, before.battle.actionsUsed);
    assert.equal(prepared.qi, before.qi - 1);
    assert.equal(prepared.thought, before.thought - 1);
    assert.equal(prepared.battle.turnSupports.guTargets.moonlight_gu[0].multiplier, 2);
    await lab.reload();
    const restored = await lab.snapshot();
    assert.deepEqual(restored.battle.turnSupports, prepared.battle.turnSupports);
    assert.equal(restored.qi, prepared.qi);
    await lab.click('[data-use-gu="moonlight_gu::1"]');
    const after = await lab.snapshot();
    assert.ok(after.reward || after.battle?.turn > before.battle.turn,
      'prepared Moonlight must resolve through the ordinary battle flow');
    assert.equal(lab.logs().filter(l => l.includes('[exception]')).length, 0);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: zero-focus Stone Shell can be cast repeatedly across refreshed turns', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n =>
      map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(node);
    await lab.click(`[data-choose-node="${node.id}"]`);

    for (let cast = 1; cast <= 4; cast += 1) {
      const before = await lab.snapshot();
      assert.ok(before.battle && !before.battle.over, `battle must remain live before cast ${cast}`);
      assert.match(await lab.text('[data-use-gu="stone_shell_gu::1"]'), /操控 1/);
      await lab.click('[data-use-gu="stone_shell_gu::1"]');
      const active = await lab.snapshot();
      assert.equal(active.battle.playerHuman.maintainedGu
        .some(g => g.instanceId === 'stone_shell_gu::1' && g.active), true);
      assert.equal(active.thought, 3, `zero focus restores all control after cast ${cast}`);
      await lab.click('[data-stop-gu="stone_shell_gu::1"]');
      const stopped = await lab.snapshot();
      assert.equal(stopped.thought, active.thought, 'stopping does not grant an extra refresh');
    }
  } finally { await lab.close(); }
});

test('NORMAL_RUN: control refreshes after an enemy turn, retained focus reduces it, and stopping is free', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n =>
      map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    const observed = await lab.snapshot();
    assert.equal(observed.thought, 3, 'the enemy response refreshes control for the next turn');
    await lab.click('[data-use-gu="jade_skin_gu::1"]');
    const jade = await lab.snapshot();
    assert.equal(jade.thought, 2, 'maintained Jade Skin reserves one control');
    await lab.click('[data-stop-gu="jade_skin_gu::1"]');
    const stopped = await lab.snapshot();
    assert.equal(stopped.thought, jade.thought, 'free stopping does not refill current control');
    await lab.click('[data-use-gu="stone_shell_gu::1"]');
    const stone = await lab.snapshot();
    assert.equal(stone.thought, 3, 'Stone Shell reserves no control after its action resolves');
    assert.ok(stone.battle && !stone.battle.over);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: Stone Shell stays maintained for free and delays a real punch until after the enemy acts', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n =>
      map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(node, 'normal start must offer a battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');

    const revealed = await lab.snapshot();
    const initialTarget = revealed.battle.enemies.find(e => e.id === revealed.battle.targetId);
    await lab.click('[data-basic-attack]');
    const clearedReaction = await lab.snapshot();
    assert.ok(clearedReaction.reward || clearedReaction.battle.enemies.find(e => e.id === initialTarget.id).hp < initialTarget.hp
      || ['enemy_bound', 'guarded'].some(flag => clearedReaction.battle.enemies.find(e => e.id === initialTarget.id).flags[flag]),
    'the first punch resolves or consumes the revealed reaction before the delayed punch check');

    const before = await lab.snapshot();
    assert.equal(before.thought, 3, 'observing and clearing the reaction end with a refreshed turn');
    assert.match(await lab.text('[data-use-gu="stone_shell_gu::1"]'), /石皮蛊/);
    await lab.click('[data-use-gu="stone_shell_gu::1"]');
    const active = await lab.snapshot();
    const maintained = active.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'stone_shell_gu::1');
    assert.equal(maintained.active, true);
    assert.equal(maintained.upkeepCost, 0);
    assert.equal(maintained.hitCost, 0);
    assert.deepEqual(active.battle.playerHuman.modifierLedger
      .filter(m => m.sourceGuInstanceId === 'stone_shell_gu::1' && m.active)
      .map(m => [m.attribute, m.amount]).sort(), [['attack', 1], ['attackDelay', 1], ['defense', 3]]);
    assert.equal(active.thought, 3, 'Stone Shell has zero focus cost after its action resolves');
    assert.match(await lab.text('[data-stop-gu="stone_shell_gu::1"]'), /停止 石皮蛊/);
    assert.ok(active.battle.log.some(line => line.includes('你催动') && line.includes('石皮蛊') && line.includes('真元 -1')));
    assert.ok(!active.battle.log.some(line => line.includes('石皮蛊') && /承击 · 真元 -|维持 · 真元 -/.test(line)),
      'Stone Shell has no hit or upkeep charge');
    assert.equal(active.qi, Math.min(before.qiMax, before.qi - 1 + 2),
      'only startup is charged; the ordinary turn regeneration still applies');

    await assert.rejects(lab.click('[data-use-gu="jade_skin_gu::1"]'), /禁用|不可见/);
    const mutuallyExclusive = await lab.snapshot();
    assert.equal(mutuallyExclusive.thought, active.thought);
    assert.equal(mutuallyExclusive.battle.playerHuman.maintainedGu
      .some(g => g.instanceId === 'jade_skin_gu::1' && g.active), false,
    'Jade Skin cannot start while Stone Shell owns the defense group');
    assert.equal(mutuallyExclusive.battle.playerHuman.maintainedGu
      .find(g => g.instanceId === 'stone_shell_gu::1').active, true);

    await lab.reload();
    const restored = await lab.snapshot();
    assert.equal(restored.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'stone_shell_gu::1').active, true);
    assert.equal(restored.qi, active.qi);
    assert.equal(restored.thought, active.thought);
    assert.match(await lab.text('[data-stop-gu="stone_shell_gu::1"]'), /停止 石皮蛊/);

    await lab.click('[data-stop-gu="stone_shell_gu::1"]');
    const stopped = await lab.snapshot();
    assert.equal(stopped.thought, active.thought, 'stopping costs no thought and grants no immediate refresh');
    assert.equal(stopped.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'stone_shell_gu::1').active, false);
    assert.equal(stopped.battle.playerHuman.modifierLedger
      .filter(m => m.sourceGuInstanceId === 'stone_shell_gu::1' && m.active).length, 0);
    assert.equal(stopped.battle.playerHuman.baseline.defense, 0);
    assert.equal(stopped.battle.playerHuman.baseline.attack, 3);
    assert.equal(stopped.battle.playerHuman.baseline.attackDelay, 0);
    assert.equal(stopped.battle.delayedEffects.length, 0);

    await lab.click('[data-use-gu="stone_shell_gu::1"]');
    const restarted = await lab.snapshot();
    assert.equal(restarted.thought, 3, 'Stone Shell still leaves all three control available');
    assert.equal(restarted.battle.playerHuman.maintainedGu.some(g => g.instanceId === 'stone_shell_gu::1' && g.active), true);
    const targetId = restarted.battle.targetId;
    const targetHp = restarted.battle.enemies.find(e => e.id === targetId).hp;
    const priorLog = restarted.battle.log.length;
    await lab.click('[data-basic-attack]');
    const queued = await lab.snapshot();
    if (queued.battle && !queued.battle.over) assert.equal(queued.thought, 3, 'a punch turn refreshes control');
    assert.equal(queued.battle?.delayedEffects.length || 0, 0, 'the due punch resolves after the enemy response in this turn');
    assert.ok(queued.reward || queued.battle.enemies.find(e => e.id === targetId).hp < targetHp,
      'stone-arm punch must eventually damage its original target');
    const turnLog = queued.reward?.battleLog || queued.battle.log.slice(priorLog);
    const enemyAttack = turnLog.findLastIndex(line => /<span class="dmg">伤/.test(line) && !line.includes('石臂拳脚'));
    const stonePunch = turnLog.findLastIndex(line => line.includes('石臂拳脚') && line.includes('落下'));
    assert.ok(enemyAttack >= 0 && stonePunch > enemyAttack,
      'the enemy must act before the delayed stone-arm punch lands');
    assert.equal(lab.logs().filter(line => line.includes('[exception]')).length, 0);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: Jade Skin stays maintained across reload and can be stopped without resources', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n =>
      map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(node, 'normal start must offer a battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    const observed = await lab.snapshot();
    assert.equal(observed.thought, 3);
    await lab.click('[data-use-gu="small_light_gu::1"]');
    const before = await lab.snapshot();
    assert.equal(before.thought, 2, 'Small Light uses one control without advancing the turn');
    assert.match(await lab.text('[data-use-gu="jade_skin_gu::1"]'), /玉皮蛊/);

    await lab.click('[data-use-gu="jade_skin_gu::1"]');
    const active = await lab.snapshot();
    assert.equal(active.thought, 2, 'Jade Skin reserves one control across its enemy response');
    assert.equal(active.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'jade_skin_gu::1').active, true);
    assert.equal(active.battle.playerHuman.modifierLedger.find(m => m.sourceGuInstanceId === 'jade_skin_gu::1').active, true);
    assert.match(await lab.text('[data-stop-gu="jade_skin_gu::1"]'), /停止 玉皮蛊/);
    assert.ok(active.battle.log.some(line => line.includes('你催动') && line.includes('玉皮蛊') && line.includes('真元 -1')));
    assert.ok(active.battle.log.some(line => line.includes('玉皮蛊') && line.includes('承击 · 真元 -2')),
      'a damaging hit must charge the maintained defense');
    assert.equal(active.qi, before.qi - 2, 'startup 1 + hit 2 + upkeep 1 minus turn regeneration 2');

    await lab.reload();
    const restored = await lab.snapshot();
    assert.equal(restored.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'jade_skin_gu::1').active, true);
    assert.equal(restored.battle.playerHuman.modifierLedger.find(m => m.sourceGuInstanceId === 'jade_skin_gu::1').active, true);
    assert.equal(restored.qi, active.qi);
    assert.equal(restored.thought, active.thought);
    assert.match(await lab.text('[data-stop-gu="jade_skin_gu::1"]'), /停止 玉皮蛊/);

    const turn = restored.battle.turn;
    await lab.click('[data-stop-gu="jade_skin_gu::1"]');
    const stopped = await lab.snapshot();
    assert.equal(stopped.qi, restored.qi, 'stopping is free');
    assert.equal(stopped.thought, restored.thought, 'stopping does not spend thought');
    assert.equal(stopped.battle.turn, turn, 'stopping does not consume an action');
    assert.equal(stopped.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'jade_skin_gu::1').active, false);
    const defense = stopped.battle.playerHuman.modifierLedger.find(m => m.sourceGuInstanceId === 'jade_skin_gu::1');
    assert.equal(defense.active, false);
    assert.equal(defense.removalReason, 'player_stopped');
    assert.equal(stopped.battle.playerHuman.baseline.defense, 0);
    assert.equal(stopped.battle.playerHuman.modifierLedger
      .filter(m => m.attribute === 'defense' && m.active && m.persistence === 'maintained').length, 0);

    await lab.reload();
    const stoppedReload = await lab.snapshot();
    assert.equal(stoppedReload.battle.playerHuman.maintainedGu.find(g => g.instanceId === 'jade_skin_gu::1').active, false);
    assert.equal(stoppedReload.qi, stopped.qi);
    await lab.click('[data-basic-attack]');
    const punched = await lab.snapshot();
    if (punched.battle && !punched.battle.over) assert.equal(punched.thought, 3, 'the punch response refreshes control');
    assert.ok(punched.reward || punched.battle.turn > stopped.battle.turn,
      'basic attack must resolve without thought');
    assert.equal(lab.logs().filter(line => line.includes('[exception]')).length, 0);
  } finally { await lab.close(); }
});


test('NORMAL_RUN: White Boar trains in preparation, saves permanent strength and cannot charge twice', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n => map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    for (let i = 0; i < 12; i++) {
      const snap = await lab.snapshot();
      if (snap.reward) break;
      await lab.click('[data-basic-attack]');
    }
    const won = await lab.snapshot();
    assert.ok(won.reward, 'first encounter must finish via normal actions');
    await lab.click(won.reward.guChoices?.length ? '[data-reward-skip]' : '[data-reward-continue]');
    const planning = await lab.text('[data-refinement-plan]');
    assert.match(planning, /白玉蛊/);
    assert.match(planning, /15元石/);
    assert.match(planning, /还差|资金已足/);
    await lab.click('[data-prep-tab="gu"]');
    const before = await lab.snapshot();
    await lab.click('[data-train-body="white_boar_strength_gu"]');
    const trained = await lab.snapshot();
    await assertResourceHud(lab, trained);
    assert.equal(trained.qi, before.qi - 1);
    assert.equal(trained.stones, before.stones - 1);
    assert.equal(trained.modifierLedger.length, before.modifierLedger.length + 1);
    assert.equal(trained.modifierLedger.at(-1).persistence, 'session_permanent');
    assert.equal(trained.modifierLedger.at(-1).amount, 1);
    await assert.rejects(lab.click('[data-train-body="white_boar_strength_gu"]'), /禁用|不可见/);
    await lab.reload();
    const restored = await lab.snapshot();
    await assertResourceHud(lab, restored);
    assert.deepEqual(restored.modifierLedger, trained.modifierLedger);
    assert.equal(restored.qi, trained.qi);
    assert.equal(restored.stones, trained.stones);
    await lab.click('[data-prep-continue]');
    const nextMap = await lab.snapshot();
    const next = nextMap.journey.graph.nodes.find(n => nextMap.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    if (next) {
      await lab.click(`[data-choose-node="${next.id}"]`);
      const fight = await lab.snapshot();
      assert.deepEqual(fight.battle.playerHuman.modifierLedger, trained.modifierLedger);
      assert.equal(fight.battle.playerHuman.modifierLedger.at(-1).amount, 1);
    }
    assert.equal(lab.logs().filter(l => l.includes('[exception]')).length, 0);
  } finally { await lab.close(); }
});


test('NORMAL_RUN: healing leaf is consumed once and recovery interval survives reload', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    assert.equal(map.owned.vitality_leaf_gu, 2);
    assert.equal(map.owned.vitality_grass_gu, undefined);
    const node = map.journey.graph.nodes.find(n => map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    const before = await lab.snapshot();
    assert.ok(before.blood < before.bloodMax);
    await lab.click('[data-use-gu="vitality_leaf_gu::1"]');
    const after = await lab.snapshot();
    assert.equal(after.owned.vitality_leaf_gu, 1);
    assert.equal(after.leafRecoveryNodeId, node.id);
    assert.equal(after.battle.turn, before.battle.turn + 1);
    assert.ok(after.battle.log.some(line => line.includes(`气血 +${Math.min(3, before.bloodMax - before.blood)}`) && line.includes('叶片消耗1')));
    assert.equal(after.blood, Math.min(before.bloodMax, before.blood + 3) - 1, 'heal clamps before the known one-damage reply');
    assert.match(await lab.text('[data-use-gu="vitality_leaf_gu::1"]'), /疗伤间隔/);
    await assert.rejects(lab.click('[data-use-gu="vitality_leaf_gu::1"]'), /被禁用或不可见/);
    await lab.reload();
    const restored = await lab.snapshot();
    assert.equal(restored.owned.vitality_leaf_gu, 1);
    assert.equal(restored.leafRecoveryNodeId, node.id);
    assert.match(await lab.text('[data-use-gu="vitality_leaf_gu::1"]'), /疗伤间隔/);
    await assert.rejects(lab.click('[data-use-gu="vitality_leaf_gu::1"]'), /被禁用或不可见/);
    assert.equal(lab.logs().filter(line => line.includes('[exception]')).length, 0);
  } finally { await lab.close(); }
});

// 使用真实首战所得资金购入，验证预览与成交读取同一层价。
test('NORMAL_RUN: purchase preview matches the real cost and stops reserving funds after sale', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n => map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    for (let i = 0; i < 12; i++) {
      if ((await lab.snapshot()).reward) break;
      await lab.click('[data-basic-attack]');
    }
    const won = await lab.snapshot();
    assert.ok(won.reward);
    await lab.click(won.reward.guChoices?.length ? '[data-reward-skip]' : '[data-reward-continue]');
    await lab.click('[data-prep-tab="shop"]');
    const before = await lab.snapshot();
    const ctx = vm.createContext({});
    vm.runInContext(readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA=DATA;', ctx);
    for (const file of ['run_rules', 'shop_rules'])
      vm.runInContext(readFileSync(new URL(`../js/${file}.js`, import.meta.url), 'utf8'), ctx);
    const data = ctx.DATA;
    const shopContext = { seed: before.seed, nodeKey: before.journey.nodeId,
      pacingLayers: data.loot.pacingLayers, layer: node.segment, school: before.school };
    const ids = ctx.ShopRules.stock(data.shopOffers, shopContext);
    const offer = data.shopOffers.find(o => ids.includes(o.id) && o.kind === 'purchase'
      && ctx.ShopRules.layerPrice(data.loot.pacingLayers, node.segment, o.stone_cost) <= before.stones);
    assert.ok(offer, 'normal first reward must fund at least one stocked Gu');
    const cost = ctx.ShopRules.layerPrice(data.loot.pacingLayers, node.segment, offer.stone_cost);
    const card = `.shop-offer:has([data-buy-offer="${offer.id}"])`;
    const preview = await lab.text(card);
    await lab.shoot(fileURLToPath(new URL('../docs/tmp/purchase-budget.png', import.meta.url)));
    assert.match(preview, new RegExp(`购后元石 ${before.stones - cost}`));
    assert.match(preview, /下一突破/);
    assert.equal((await lab.snapshot()).stones, before.stones, 'reading preview costs nothing');
    await lab.click(`[data-buy-offer="${offer.id}"]`);
    const after = await lab.snapshot();
    assert.equal(after.stones, before.stones - cost);
    assert.equal(after.owned[offer.gu_id], Number(before.owned[offer.gu_id] || 0) + 1);
    assert.doesNotMatch(await lab.text(card), /购后元石/, 'sold card must not project a second purchase');
    await lab.reload();
    assert.equal((await lab.snapshot()).stones, after.stones);
    assert.doesNotMatch(await lab.text(card), /购后元石/);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: Converge equips, survives reload and casts both existing Gu with their full costs', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n => map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    for (let i = 0; i < 12; i++) {
      if ((await lab.snapshot()).reward) break;
      await lab.click('[data-basic-attack]');
    }
    const won = await lab.snapshot();
    assert.ok(won.reward);
    await lab.click(won.reward.guChoices?.length ? '[data-reward-skip]' : '[data-reward-continue]');
    await lab.click('[data-prep-tab="killmove"]');
    assert.match(await lab.text('#prep-killmove'), /实验同催/);
    assert.match(await lab.text('[data-km="km_blood_ember"]'), /尚未开放/);
    await lab.click('[data-km="km_light_converge"]');
    assert.ok((await lab.snapshot()).equipped.includes('km_light_converge'));
    await lab.reload();
    assert.ok((await lab.snapshot()).equipped.includes('km_light_converge'));
    await lab.click('[data-prep-continue]');
    const nextMap = await lab.snapshot();
    const next = nextMap.journey.graph.nodes.find(n => nextMap.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(next, 'actual next row must offer a combat encounter');
    await lab.click(`[data-choose-node="${next.id}"]`);
    const before = await lab.snapshot();
    await lab.click('[data-use="km_light_converge"]');
    const after = await lab.snapshot();
    const event = after.eventLog.findLast(e => e.action === 'use_kill_move');
    assert.ok(event, 'component activation must be recorded before victory refills');
    assert.equal(event.after.true_qi, before.qi - 3);
    assert.equal(event.after.thought, before.thought - 2);
    assert.deepEqual(event.after.component_instances, ['moonlight_gu::1', 'small_light_gu::1']);
    assert.equal(event.after.gu_used_this_turn['moonlight_gu::1'], true);
    assert.equal(event.after.gu_used_this_turn['small_light_gu::1'], true);
    assert.equal(event.after.kill_move_used_this_turn.km_light_converge, true);
    assert.ok(after.reward || after.battle?.turn > before.battle.turn);
    await lab.shoot(fileURLToPath(new URL('../docs/tmp/converge-result.png', import.meta.url)));
    assert.equal(after.owned.moonlight_gu, before.owned.moonlight_gu);
    assert.equal(after.owned.small_light_gu, before.owned.small_light_gu);
  } finally { await lab.close(); }
});

test('NORMAL_RUN: freely selected duplicate support is saved, cast and remains nonstacking', async () => {
  const lab = await openLab({ seed: 103 });
  try {
    await lab.click('[data-start-run]');
    const map = await lab.snapshot();
    const node = map.journey.graph.nodes.find(n => map.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    await lab.click(`[data-choose-node="${node.id}"]`);
    await lab.click('[data-observe]');
    for (let i = 0; i < 12; i++) {
      if ((await lab.snapshot()).reward) break;
      await lab.click('[data-basic-attack]');
    }
    const won = await lab.snapshot();
    assert.ok(won.reward);
    await lab.click(won.reward.guChoices?.length ? '[data-reward-skip]' : '[data-reward-continue]');
    await lab.click('[data-prep-tab="alchemy"]');
    await lab.click('[data-attune="small_light_gu"]');
    await lab.click('[data-prep-tab="killmove"]');
    await lab.click('[data-compose-add="moonlight_gu"]');
    await lab.click('[data-compose-add="small_light_gu"]');
    await lab.click('[data-compose-add="small_light_gu"]');
    const before = await lab.snapshot();
    const preview = await lab.text('#prep-killmove');
    assert.match(preview, /同类辅助不叠加/);
    assert.match(preview, /合计：真元 4 · 操控 3/);
    await lab.shoot(fileURLToPath(new URL('../docs/tmp/custom-compose-preview.png', import.meta.url)));
    await lab.click('[data-compose-remember]');
    const saved = await lab.snapshot();
    assert.equal(saved.customMoveRecipes.length, 1);
    assert.equal(saved.equipped.length, 0, 'saving does not equip');
    assert.equal(saved.stones, before.stones);
    assert.equal(saved.qi, before.qi);
    assert.deepEqual(saved.owned, before.owned);
    await lab.reload();
    const restored = await lab.snapshot();
    assert.deepEqual(restored.customMoveRecipes, saved.customMoveRecipes);
    await lab.click('[data-prep-tab="killmove"]');
    const recipe = restored.customMoveRecipes[0];
    const id = `km_custom_${recipe.join('__')}`;
    await lab.click(`[data-km="${id}"]`);
    await lab.click('[data-prep-continue]');
    const nextMap = await lab.snapshot();
    const next = nextMap.journey.graph.nodes.find(n => nextMap.journey.availableNodeIds.includes(n.id) && n.type === 'battle');
    assert.ok(next);
    await lab.click(`[data-choose-node="${next.id}"]`);
    // 真实恢复操作；若整备炼化后尚缺真元，结束回合承担敌人行动再恢复。
    for (let i = 0; i < 3; i++) {
      if ((await lab.snapshot()).qi >= 4) break;
      await lab.click('[data-end-turn]');
    }
    const castBefore = await lab.snapshot();
    await lab.click(`[data-use="${id}"]`);
    const after = await lab.snapshot();
    const receipt = after.eventLog.findLast(e => e.action === 'use_kill_move');
    assert.equal(receipt.after.move_id, id);
    assert.equal(receipt.after.true_qi, castBefore.qi - 4);
    assert.equal(receipt.after.thought, castBefore.thought - 3);
    assert.equal(receipt.after.component_instances.length, 3);
    assert.ok(receipt.after.component_instances.includes('small_light_gu::1'));
    assert.ok(receipt.after.component_instances.includes('small_light_gu::2'));
    assert.ok(Object.values(receipt.after.gu_used_this_turn).every(Boolean));
    assert.equal(after.owned.small_light_gu, 2);
    assert.ok(after.reward, 'existing plan defeats this weak enemy');
    assert.ok(after.reward.battleLog.some(line => /伤 6/.test(line)), 'actual damage stays 6, not 12 from stacking');
    await lab.click(after.reward.guChoices?.length ? '[data-reward-skip]' : '[data-reward-continue]');
    await lab.click('[data-prep-tab="killmove"]');
    await lab.click(`[data-compose-forget="${id}"]`);
    assert.equal((await lab.snapshot()).customMoveRecipes.length, 0);
    assert.equal((await lab.snapshot()).equipped.includes(id), false);
    await lab.reload();
    assert.equal((await lab.snapshot()).customMoveRecipes.length, 0);
  } finally { await lab.close(); }
});
