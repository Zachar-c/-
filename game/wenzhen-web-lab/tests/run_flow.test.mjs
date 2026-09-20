import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/run_flow.js', import.meta.url), 'utf8'), context);
const flow = context.RunFlow;

const pools = Object.fromEntries([1, 2, 3, 4, 5].map((segment) => [String(segment), {
  battle: [`c${segment}`],
  elite: [`e${segment}`],
  boss: [`b${segment}`],
}]));
const enemyById = Object.fromEntries(
  [1, 2, 3, 4, 5].flatMap((segment) => [
    [`c${segment}`, { id: `c${segment}`, name: `普通${segment}` }],
    [`e${segment}`, { id: `e${segment}`, name: `精英${segment}` }],
    [`b${segment}`, { id: `b${segment}`, name: `层主${segment}` }],
  ]),
);

test('difficulty controls preparation depth without changing segment count', () => {
  for (const [difficulty, prep] of [['easy', 15], ['normal', 10], ['hard', 5]]) {
    const graph = flow.generateGraph({ seed: 1, difficulty, pools, enemyById });
    assert.equal(graph.prepPerSegment, prep);
    assert.equal(graph.segmentCount, 5);
    assert.equal(graph.nodes.length, 5 * (prep * 3 + 1));
  }
});

test('graph generation is deterministic and every preparation row has three successors', () => {
  const first = flow.generateGraph({ seed: 101, difficulty: 'normal', pools, enemyById });
  const second = flow.generateGraph({ seed: 101, difficulty: 'normal', pools, enemyById });
  assert.equal(JSON.stringify(first), JSON.stringify(second));
  assert.equal(first.roots.length, 3);
  for (let segment = 1; segment <= 5; segment += 1) {
    for (let depth = 0; depth < first.prepPerSegment - 1; depth += 1) {
      for (let slot = 0; slot < 3; slot += 1) {
        const node = flow.nodeById(first, flow.nodeId(segment, depth, slot));
        assert.equal(node.nextIds.length, 3);
      }
    }
    for (let slot = 0; slot < 3; slot += 1) {
      const node = flow.nodeById(first, flow.nodeId(segment, first.prepPerSegment - 1, slot));
      assert.equal(node.nextIds.join(','), flow.bossId(segment));
    }
  }
});

test('small breakthrough accepts current-rank sari gu only', () => {
  const config = {
    smallBreakthroughCosts: { 2: [4, 6, 8] },
    bigStoneCosts: { 3: 12 },
    aptitudeOrder: ['ding', 'bing', 'yi', 'jia'],
    aptitudeGateByTargetRank: { 3: 'yi' },
    sariByRank: { 2: 'gold_atk_2_11_gu' },
  };
  const result = flow.nextBreakthrough({
    rank: 2,
    stageIndex: 0,
    stones: 0,
    aptitude: 'bing',
    owned: { gold_atk_2_11_gu: 1, gold_atk_3_13_gu: 9 },
  }, config);
  assert.equal(result.kind, 'small');
  assert.equal(result.sariId, 'gold_atk_2_11_gu');
  assert.equal(result.canSari, true);
  assert.equal(result.canStone, false);
});

test('big breakthrough requires both aptitude and stones', () => {
  const config = {
    smallBreakthroughCosts: {},
    bigStoneCosts: { 3: 12 },
    aptitudeOrder: ['ding', 'bing', 'yi', 'jia'],
    aptitudeGateByTargetRank: { 3: 'yi' },
    sariByRank: {},
  };
  const blocked = flow.nextBreakthrough({
    rank: 2, stageIndex: 3, stones: 12, aptitude: 'bing', owned: {},
  }, config);
  assert.equal(blocked.ok, false);
  assert.equal(blocked.missing, 'insufficient_aptitude');
  const ready = flow.nextBreakthrough({
    rank: 2, stageIndex: 3, stones: 12, aptitude: 'yi', owned: {},
  }, config);
  assert.equal(ready.ok, true);
  assert.equal(ready.targetRank, 3);
});

test('sell value floors at half of the configured value', () => {
  assert.equal(flow.sellValue(5), 2);
  assert.equal(flow.sellValue(0), 0);
});

test('generated lab data exposes non-combat sari and aptitude gu', () => {
  vm.runInContext(fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8'), context);
  const data = vm.runInContext('DATA', context);
  const support = data.gu.filter((gu) => gu.role === 'support');
  assert.ok(support.some((gu) => gu.id === 'aptitude_gu'));
  assert.ok(support.some((gu) => gu.id === 'gold_atk_2_11_gu' && gu.rank === 2));
  assert.equal(support.every((gu) => gu.combat === ''), true);
  assert.equal(data.flow.sariByRank['2'], 'gold_atk_2_11_gu');
});
