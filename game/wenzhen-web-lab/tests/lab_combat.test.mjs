/** W3: real browser actions plus an explicitly synthetic observe fixture. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
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
    assert.equal(after.battle.turn, before.battle.turn + 1, 'second action advances exactly one turn');
    await lab.click('[data-basic-attack]');
    const next = await lab.snapshot();
    assert.ok(next.battle.enemies.find(e => e.id === id).hp <
      after.battle.enemies.find(e => e.id === id).hp, 'settled reaction must not swallow twice');
    assert.equal(next.thought, after.thought - 1);
    assert.equal(next.battle.actionsUsed, after.battle.actionsUsed + 1);
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
    assert.equal(after.thought, before.thought - 1);
    assert.equal(after.qi, before.qi);
    assert.equal(after.battle.actionsUsed, before.battle.actionsUsed + 1);
  } finally { await lab.close(); }
});
