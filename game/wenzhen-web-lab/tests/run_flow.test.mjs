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

test('sari series follows the novel: rank 1 bronze, rank 2 red iron', () => {
  // 原著 `蛊真人-clean.txt:18066`：一转的是青铜舍利蛊 / 二转的是赤铁舍利蛊 / 三转白银。
  // 数据把阶梯第 2 级命名成了青铜舍利蛊（gold_atk_2_12_gu），rank 字段与原著定位冲突，
  // 所以 lab 按名字定转数、不读 rank；这条测试钉住那个映射与「不可越阶」。
  const config = {
    smallBreakthroughCosts: { 1: [2, 3, 4], 2: [4, 6, 8] },
    bigStoneCosts: {},
    aptitudeOrder: ['ding', 'bing', 'yi', 'jia'],
    aptitudeGateByTargetRank: {},
    sariByRank: { 1: 'gold_atk_2_12_gu', 2: 'gold_atk_2_11_gu' },
  };
  const bronze = { gold_atk_2_12_gu: 1 };
  const redIron = { gold_atk_2_11_gu: 1 };

  const rank1 = flow.nextBreakthrough({ rank: 1, stageIndex: 0, stones: 0, aptitude: 'bing', owned: bronze }, config);
  assert.equal(rank1.sariId, 'gold_atk_2_12_gu');
  assert.equal(rank1.canSari, true);

  const rank2WithBronze = flow.nextBreakthrough({ rank: 2, stageIndex: 0, stones: 0, aptitude: 'bing', owned: bronze }, config);
  assert.equal(rank2WithBronze.sariId, 'gold_atk_2_11_gu');
  assert.equal(rank2WithBronze.canSari, false, '青铜舍利蛊是一转蛊，不能替代二转的赤铁舍利蛊');

  const rank2WithRedIron = flow.nextBreakthrough({ rank: 2, stageIndex: 0, stones: 0, aptitude: 'bing', owned: redIron }, config);
  assert.equal(rank2WithRedIron.canSari, true);
});

test('generated lab data exposes non-combat sari and aptitude gu', () => {
  vm.runInContext(fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8'), context);
  const data = vm.runInContext('DATA', context);
  const support = data.gu.filter((gu) => gu.role === 'support');
  assert.ok(support.some((gu) => gu.id === 'aptitude_gu'));
  assert.ok(support.some((gu) => gu.id === 'gold_atk_2_11_gu' && gu.rank === 2));
  assert.equal(support.every((gu) => gu.combat === ''), true);
  assert.equal(data.flow.sariByRank['2'], 'gold_atk_2_11_gu');
  // 舍利系列按原著定位建（不读 gu 的 rank 字段），五转俱全。
  assert.equal(data.flow.sariByRank['1'], 'gold_atk_2_12_gu');
  assert.equal(data.flow.sariByRank['3'], 'gold_atk_3_13_gu');
  assert.equal(data.flow.sariByRank['4'], 'gold_atk_4_14_gu');
  assert.equal(data.flow.sariByRank['5'], 'gold_atk_5_15_gu');
  // 青铜舍利蛊的等级数据写的 rank=2（金色进阶链的第 2 级），但货架档位必须按
  // 原著的一转定位，否则一转区域买不到它，一转小突破就永远没有舍利可用。
  const bronzeOffer = data.shopOffers.find((offer) => offer.gu_id === 'gold_atk_2_12_gu');
  assert.equal(bronzeOffer.tier, 1);
  const redIronOffer = data.shopOffers.find((offer) => offer.gu_id === 'gold_atk_2_11_gu');
  assert.equal(redIronOffer.tier, 2);
});
