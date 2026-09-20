import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/run_flow.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/hazard_rules.js', import.meta.url), 'utf8'), context);
const plain = (value) => JSON.parse(JSON.stringify(value));
const flow = context.RunFlow;
const rules = context.HazardRules;

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
// 与 data/nodes.json 的三个险地模板同形。
const hazardTemplates = [
  { id: 'toxic_mountain_path', name: '毒瘴山道', summary: '毒瘴沿山口沉降。', choices: ['scout', 'cross', 'withdraw'] },
  { id: 'flooded_cave', name: '积水石窟', summary: '暗河倒灌石洞，水声中有蛊虫振翅。', choices: ['scout', 'cross', 'withdraw'] },
  { id: 'black_mud_marsh', name: '黑泥沼地', summary: '', choices: ['scout', 'cross', 'withdraw'] },
];
const generate = (overrides = {}) => flow.generateGraph({
  seed: 20260920, difficulty: 'normal', pools, enemyById, hazardTemplates, ...overrides,
});

test('the three hazard choices mirror the Godot standard action transitions', () => {
  assert.deepEqual(plain(rules.resolve('scout', { essence: 3, knownFacts: [] })), {
    ok: true, reason: 'action_scout_route', essence: 3, knownFacts: ['route_scouted'], fact: 'route_scouted',
  });
  assert.deepEqual(plain(rules.resolve('cross', { essence: 3, knownFacts: [] })), {
    ok: true, reason: 'action_cross_cost', essence: 2, knownFacts: [], fact: '',
  });
  assert.deepEqual(plain(rules.resolve('withdraw', { essence: 3, knownFacts: ['route_scouted'] })), {
    ok: true, reason: 'action_withdraw_safely', essence: 3,
    knownFacts: ['route_scouted', 'withdrawn_safely'], fact: 'withdrawn_safely',
  });
});

test('cross is rejected below one essence without spending or recording', () => {
  const rejected = rules.resolve('cross', { essence: 0, knownFacts: ['route_scouted'] });
  assert.equal(rejected.ok, false);
  assert.equal(rejected.reason, 'insufficient_essence');
  assert.equal(rejected.essence, 0);
  assert.deepEqual(plain(rejected.knownFacts), ['route_scouted']);
  assert.equal(rejected.fact, '');
  assert.equal(rules.reasonLabel(rejected.reason), '真元不足：需要 1 点。');
});

test('fact choices record once and unknown choices follow the Godot fallback', () => {
  const twice = rules.resolve('scout', { essence: 1, knownFacts: ['route_scouted'] });
  assert.deepEqual(plain(twice.knownFacts), ['route_scouted']);
  const unknown = rules.resolve('fight', { essence: 9, knownFacts: [] });
  assert.equal(unknown.ok, false);
  assert.equal(unknown.reason, 'unsupported_standard_action');
  assert.equal(unknown.essence, 9);
  assert.equal(rules.reasonLabel(unknown.reason), '行动未能完成。');
  assert.equal(rules.reasonLabel('something_else'), '行动未能完成。');
});

test('options expose availability, block reason and the preview wording', () => {
  const choices = ['scout', 'cross', 'withdraw'];
  const blocked = rules.options({ choices, essence: 0 });
  assert.deepEqual(plain(blocked.map((option) => [option.id, option.available])),
    [['scout', true], ['cross', false], ['withdraw', true]]);
  assert.equal(blocked[1].essenceCost, 1);
  assert.equal(blocked[1].reason, 'insufficient_essence');
  assert.deepEqual(plain(blocked[0].gain), ['查明前路的已知征兆。']);
  assert.deepEqual(plain(blocked[1].gain), ['消耗真元强行穿越，保住前行时机。']);
  assert.deepEqual(plain(blocked[2].risk), ['放弃此处机缘，之后无法再从当前路线取得。']);
  const ready = rules.options({ choices, essence: 1 });
  assert.equal(ready.every((option) => option.available), true);
  assert.equal(rules.crossEssenceCost, 1);
  assert.equal(rules.resultText('cross'), '你耗去真元，穿过了眼前险处。');
  assert.equal(rules.resultText('scout'), '你探明前路，留下了可靠的路径情报。');
  assert.equal(rules.resultText('withdraw'), '你及时收手，暂时全身而退。');
});

test('one hazard per preparation layer, deterministic for the same seed', () => {
  const first = generate();
  const second = generate();
  assert.equal(JSON.stringify(first), JSON.stringify(second));
  assert.equal(first.nodes.filter((node) => node.type === 'hazard').length, 5 * first.prepPerSegment);
  for (let segment = 1; segment <= 5; segment += 1) {
    for (let depth = 0; depth < first.prepPerSegment; depth += 1) {
      const nodes = [0, 1, 2].map((slot) => flow.nodeById(first, flow.nodeId(segment, depth, slot)));
      const hazards = nodes.filter((node) => node.type === 'hazard');
      assert.equal(hazards.length, 1);
      assert.ok(hazardTemplates.some((template) => template.id === hazards[0].hazardId));
      assert.equal(hazards[0].enemyIds.length, 0);
      assert.deepEqual(plain(hazards[0].choices), ['scout', 'cross', 'withdraw']);
      assert.equal(hazards[0].name, `险地 · ${hazardTemplates.find((t) => t.id === hazards[0].hazardId).name}`);
      assert.equal(hazards[0].tier, 'hazard');
    }
  }
  // 固定 seed 的槽位与模板（用实际生成值钉死，防止规则漂移）。
  assert.equal(flow.nodeById(first, flow.nodeId(1, 0, 0)).type, 'battle');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 0, 2)).hazardId, 'flooded_cave');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 4, 0)).hazardId, 'toxic_mountain_path');
  assert.equal(flow.nodeById(first, flow.nodeId(5, 9, 2)).hazardId, 'flooded_cave');
});

test('every difficulty keeps the three-slot rows and the boss funnel', () => {
  for (const [difficulty, prep] of [['easy', 15], ['normal', 10], ['hard', 5]]) {
    const graph = generate({ difficulty });
    assert.equal(graph.prepPerSegment, prep);
    assert.equal(graph.segmentCount, 5);
    assert.equal(graph.nodes.length, 5 * (prep * 3 + 1));
    assert.equal(graph.nodes.filter((node) => node.type === 'hazard').length, 5 * prep);
    assert.equal(graph.roots.length, 3);
    for (let segment = 1; segment <= 5; segment += 1) {
      for (let depth = 0; depth < prep - 1; depth += 1) {
        const expected = [0, 1, 2].map((slot) => flow.nodeId(segment, depth + 1, slot)).join(',');
        for (let slot = 0; slot < 3; slot += 1) {
          assert.equal(flow.nodeById(graph, flow.nodeId(segment, depth, slot)).nextIds.join(','), expected);
        }
      }
      for (let slot = 0; slot < 3; slot += 1) {
        assert.equal(flow.nodeById(graph, flow.nodeId(segment, prep - 1, slot)).nextIds.join(','), flow.bossId(segment));
      }
    }
  }
});

test('a graph built without hazard templates stays battle / elite / boss only', () => {
  const plain = flow.generateGraph({ seed: 20260920, difficulty: 'normal', pools, enemyById });
  assert.equal(plain.nodes.filter((node) => node.type === 'hazard').length, 0);
  assert.deepEqual([...new Set(plain.nodes.map((node) => node.type))].sort(), ['battle', 'boss', 'elite']);
});

test('a hazard template without choices is ignored instead of soft-locking the node', () => {
  const graph = generate({ hazardTemplates: [{ id: 'empty_hazard', name: '空险地', choices: [] }] });
  assert.equal(graph.nodes.filter((node) => node.type === 'hazard').length, 0);
  assert.deepEqual([...new Set(graph.nodes.map((node) => node.type))].sort(), ['battle', 'boss', 'elite']);
});

test('generated data still carries the three hazard templates', () => {
  const dataContext = vm.createContext({});
  vm.runInContext(
    fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
    dataContext,
  );
  const hazards = dataContext.DATA.nodes.filter((node) => node.type === 'hazard');
  assert.deepEqual(plain(hazards.map((node) => node.id)), ['toxic_mountain_path', 'flooded_cave', 'black_mud_marsh']);
  assert.deepEqual(plain(hazards.map((node) => node.name)), ['毒瘴山道', '积水石窟', '黑泥沼地']);
  assert.ok(hazards.every((node) => node.choices.join(',') === 'scout,cross,withdraw'));
});
