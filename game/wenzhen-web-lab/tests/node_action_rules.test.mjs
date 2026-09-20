import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../js/run_rules.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/run_flow.js', import.meta.url), 'utf8'), context);
vm.runInContext(fs.readFileSync(new URL('../js/node_action_rules.js', import.meta.url), 'utf8'), context);
const plain = (value) => JSON.parse(JSON.stringify(value));
const flow = context.RunFlow;
const rules = context.NodeActionRules;

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
// 与 data/nodes.json 的 6 个非战斗模板同形（险地 3 + 市集 2 + 野蛊 1）。
const nonCombatTemplates = [
  { id: 'toxic_mountain_path', type: 'hazard', name: '毒瘴山道', summary: '毒瘴沿山口沉降。', choices: ['scout', 'cross', 'withdraw'] },
  { id: 'flooded_cave', type: 'hazard', name: '积水石窟', summary: '暗河倒灌石洞，水声中有蛊虫振翅。', choices: ['scout', 'cross', 'withdraw'] },
  { id: 'black_mud_marsh', type: 'hazard', name: '黑泥沼地', summary: '', choices: ['scout', 'cross', 'withdraw'] },
  { id: 'village_short_work', type: 'market', name: '山村短工', summary: '山民寨子缺人守夜。短工给元石，交易则能换取情报。', choices: ['work', 'trade', 'leave'] },
  { id: 'ridge_market', type: 'market', name: '山脊市集', summary: '临时寨市接近收摊，能补资源，但会失去深入山路的时间。', choices: ['trade', 'buy_information', 'leave'] },
  { id: 'blood_moss_grove', type: 'wild_gu', name: '血苔林', summary: '血苔丛中藏着疗伤蛊与采集者，收益和伤势风险并存。', choices: ['harvest', 'trade', 'leave'] },
];
const typeLabels = { hazard: '险地', market: '市集', wild_gu: '野蛊' };
const generate = (overrides = {}) => flow.generateGraph({
  seed: 20260920,
  difficulty: 'normal',
  pools,
  enemyById,
  nonCombatTemplates,
  nonCombatTypeLabels: typeLabels,
  ...overrides,
});

test('work and harvest mirror the Godot resource transition before/after semantics', () => {
  assert.deepEqual(plain(rules.resolve('work', { stones: 3, essence: 9, knownFacts: [] })), {
    ok: true,
    reason: 'action_work_paid',
    stones: 6, stoneBefore: 3, stoneAfter: 6,
    essence: 9, essenceBefore: 9, essenceAfter: 9,
    knownFacts: [], fact: '',
  });
  assert.deepEqual(plain(rules.resolve('harvest', { stones: 0 })), {
    ok: true,
    reason: 'action_harvest_stone',
    stones: 2, stoneBefore: 0, stoneAfter: 2,
    essence: 0, essenceBefore: 0, essenceAfter: 0,
    knownFacts: [], fact: '',
  });
});

test('cross still spends one essence and rejects below one without touching state', () => {
  assert.deepEqual(plain(rules.resolve('cross', { essence: 3 })), {
    ok: true,
    reason: 'action_cross_cost',
    stones: 0, stoneBefore: 0, stoneAfter: 0,
    essence: 2, essenceBefore: 3, essenceAfter: 2,
    knownFacts: [], fact: '',
  });
  const rejected = rules.resolve('cross', { essence: 0, knownFacts: ['route_scouted'] });
  assert.equal(rejected.ok, false);
  assert.equal(rejected.reason, 'insufficient_essence');
  assert.equal(rejected.essence, 0);
  assert.equal(rejected.essenceAfter, 0);
  assert.deepEqual(plain(rejected.knownFacts), ['route_scouted']);
  assert.equal(rejected.fact, '');
  assert.equal(rules.reasonLabel(rejected.reason), '真元不足：需要 1 点。');
});

test('buy_information and trade are refused below two stones without touching state', () => {
  for (const actionId of ['buy_information', 'trade']) {
    const rejected = rules.resolve(actionId, { stones: 1, essence: 5, knownFacts: ['x'] });
    assert.equal(rejected.ok, false, actionId);
    assert.equal(rejected.reason, 'insufficient_stone');
    assert.equal(rejected.stones, 1);
    assert.equal(rejected.stoneBefore, 1);
    assert.equal(rejected.stoneAfter, 1);
    assert.equal(rejected.essence, 5);
    assert.deepEqual(plain(rejected.knownFacts), ['x']);
    assert.equal(rejected.fact, '');
  }
  assert.equal(rules.reasonLabel('insufficient_stone', { stones: 0 }), '元石不足：需要 2 枚，还差 2 枚。');
  assert.equal(rules.reasonLabel('insufficient_stone', { stones: 1 }), '元石不足：需要 2 枚，还差 1 枚。');
});

test('buy_information and trade spend two stones and record their own fact once', () => {
  assert.deepEqual(plain(rules.resolve('buy_information', { stones: 2 })), {
    ok: true,
    reason: 'action_bought_information',
    stones: 0, stoneBefore: 2, stoneAfter: 0,
    essence: 0, essenceBefore: 0, essenceAfter: 0,
    knownFacts: ['bought_information'], fact: 'bought_information',
  });
  const twice = rules.resolve('trade', { stones: 5, knownFacts: ['bought_service'] });
  assert.equal(twice.ok, true);
  assert.equal(twice.reason, 'action_trade_service');
  assert.equal(twice.stoneBefore, 5);
  assert.equal(twice.stoneAfter, 3);
  assert.deepEqual(plain(twice.knownFacts), ['bought_service']);
  assert.equal(twice.fact, 'bought_service');
});

test('leave records route_left_behind without spending anything', () => {
  assert.deepEqual(plain(rules.resolve('leave', { stones: 4, essence: 2 })), {
    ok: true,
    reason: 'action_leave_route',
    stones: 4, stoneBefore: 4, stoneAfter: 4,
    essence: 2, essenceBefore: 2, essenceAfter: 2,
    knownFacts: ['route_left_behind'], fact: 'route_left_behind',
  });
});

test('scout and withdraw still record their own fact exactly once', () => {
  assert.deepEqual(plain(rules.resolve('scout', { essence: 3 })), {
    ok: true,
    reason: 'action_scout_route',
    stones: 0, stoneBefore: 0, stoneAfter: 0,
    essence: 3, essenceBefore: 3, essenceAfter: 3,
    knownFacts: ['route_scouted'], fact: 'route_scouted',
  });
  const twice = rules.resolve('scout', { essence: 1, knownFacts: ['route_scouted'] });
  assert.deepEqual(plain(twice.knownFacts), ['route_scouted']);
  const withdraw = rules.resolve('withdraw', { essence: 3, knownFacts: ['route_scouted'] });
  assert.deepEqual(plain(withdraw.knownFacts), ['route_scouted', 'withdrawn_safely']);
  assert.equal(withdraw.fact, 'withdrawn_safely');
});

test('unlisted actions follow the Godot fallback without touching state', () => {
  for (const actionId of ['meditate', 'fight', 'deceive', 'retreat']) {
    const unknown = rules.resolve(actionId, { stones: 7, essence: 9, knownFacts: ['a'] });
    assert.equal(unknown.ok, false, actionId);
    assert.equal(unknown.reason, 'unsupported_standard_action');
    assert.equal(unknown.stones, 7);
    assert.equal(unknown.stoneAfter, 7);
    assert.equal(unknown.essence, 9);
    assert.deepEqual(plain(unknown.knownFacts), ['a']);
    assert.equal(unknown.fact, '');
  }
  assert.equal(rules.reasonLabel('unsupported_standard_action'), '行动未能完成。');
  assert.equal(rules.reasonLabel('something_else'), '行动未能完成。');
});

test('options carry the Godot preview wording verbatim', () => {
  const choices = ['scout', 'cross', 'withdraw', 'work', 'harvest', 'trade', 'buy_information'];
  const blocked = Object.fromEntries(
    rules.options({ choices, stones: 0, essence: 0 }).map((option) => [option.id, option]),
  );
  // gain/risk 原文（action_preview_service.gd 各 action 分支、:1086-1087 的 withdraw risk）
  assert.deepEqual(plain(blocked.work.gain), ['完成短工，获得元石 3 枚。']);
  assert.deepEqual(plain(blocked.harvest.gain), ['获得元石 2 枚。']);
  assert.deepEqual(plain(blocked.trade.gain), ['获得一次明确服务。']);
  assert.deepEqual(plain(blocked.buy_information.gain), ['获得一条可用情报。']);
  assert.deepEqual(plain(blocked.cross.gain), ['消耗真元强行穿越，保住前行时机。']);
  assert.deepEqual(plain(blocked.scout.gain), ['查明前路的已知征兆。']);
  assert.deepEqual(plain(blocked.withdraw.risk), ['放弃此处机缘，之后无法再从当前路线取得。']);
  // 门禁与 remedy 原文（:1027 / :1034 / _stone_remedies:1306-1309）
  assert.equal(blocked.cross.blockReason, '真元不足：需要 1 点。');
  assert.equal(blocked.buy_information.blockReason, '元石不足：需要 2 枚，还差 2 枚。');
  assert.equal(blocked.trade.blockReason, '元石不足：需要 2 枚，还差 2 枚。');
  assert.deepEqual(plain(blocked.buy_information.remedy), [
    '可出售已炼化蛊虫。',
    '可前往资源节点补足 2 枚元石。',
    '也可选择不消耗元石的行动。',
  ]);
  // 成本键：buy_information / trade 是元石 2，cross 是真元 1，work / harvest / scout / withdraw 无成本。
  assert.equal(blocked.buy_information.stoneCost, 2);
  assert.equal(blocked.trade.stoneCost, 2);
  assert.equal(blocked.cross.essenceCost, 1);
  assert.equal(blocked.work.stoneCost, 0);
  assert.equal(blocked.work.essenceCost, 0);
  // 可用性
  assert.equal(blocked.scout.available, true);
  assert.equal(blocked.cross.available, false);
  assert.equal(blocked.withdraw.available, true);
  assert.equal(blocked.work.available, true);
  assert.equal(blocked.harvest.available, true);
  assert.equal(blocked.trade.available, false);
  assert.equal(blocked.buy_information.available, false);
  assert.deepEqual(
    plain(rules.options({ choices, stones: 0, essence: 0 }).map((option) => option.id)),
    [...choices, 'leave'],
  );
  // 元石够时：恢复可用、blockReason 与 remedy 清空
  const ready = Object.fromEntries(
    rules.options({ choices, stones: 2, essence: 1 }).map((option) => [option.id, option]),
  );
  assert.equal(ready.trade.available, true);
  assert.equal(ready.trade.blockReason, '');
  assert.deepEqual(plain(ready.buy_information.remedy), []);
  assert.equal(ready.cross.available, true);
  assert.equal(rules.crossEssenceCost, 1);
  assert.equal(rules.stoneServiceCost, 2);
});

test('options always append the leave card and skip leave inside choices', () => {
  const options = rules.options({ choices: ['work', 'leave', 'trade'], stones: 0, essence: 0 });
  assert.deepEqual(plain(options.map((option) => option.id)), ['work', 'trade', 'leave']);
  const leave = options[2];
  assert.equal(leave.title, '离开遭遇');
  assert.equal(leave.summary, '主动结束当前遭遇，返回地图选择下一条路线。');
  assert.deepEqual(plain(leave.gain), ['结束当前遭遇。']);
  assert.equal(leave.available, true);
  assert.equal(leave.stoneCost, 0);
  // 险地模板的 choices 里没有 leave，卡里同样补一张（action_preview_service.gd:44-45）。
  const hazardOptions = rules.options({ choices: ['scout', 'cross', 'withdraw'], stones: 3, essence: 3 });
  assert.deepEqual(plain(hazardOptions.map((option) => option.id)), ['scout', 'cross', 'withdraw', 'leave']);
  const unknown = rules.option('meditate', { stones: 3, essence: 3 });
  assert.equal(unknown.available, false);
  assert.equal(unknown.reason, 'unsupported_standard_action');
  assert.equal(unknown.blockReason, '行动未能完成。');
});

test('result texts come from display_text ACTION_RESULTS', () => {
  assert.equal(rules.resultText('work'), '你做完短工，换得了元石。');
  assert.equal(rules.resultText('harvest'), '你从此处采得了可用的元石收获。');
  assert.equal(rules.resultText('trade'), '你付出元石，换得了一项可调用的服务。');
  assert.equal(rules.resultText('buy_information'), '你付出元石，换得了可用情报。');
  assert.equal(rules.resultText('leave'), '你放下眼前收益，保留了退路。');
  assert.equal(rules.resultText('cross'), '你耗去真元，穿过了眼前险处。');
  assert.equal(rules.resultText('scout'), '你探明前路，留下了可靠的路径情报。');
  assert.equal(rules.resultText('withdraw'), '你及时收手，暂时全身而退。');
});

test('one non-combat node per preparation layer, drawn from the merged pool', () => {
  const first = generate();
  const second = generate();
  assert.equal(JSON.stringify(first), JSON.stringify(second));
  assert.equal(first.nodes.filter((node) => rules.nodeTypes.includes(node.type)).length, 5 * first.prepPerSegment);
  const kinds = new Set();
  for (let segment = 1; segment <= 5; segment += 1) {
    for (let depth = 0; depth < first.prepPerSegment; depth += 1) {
      const nodes = [0, 1, 2].map((slot) => flow.nodeById(first, flow.nodeId(segment, depth, slot)));
      const routeNodes = nodes.filter((node) => rules.nodeTypes.includes(node.type));
      assert.equal(routeNodes.length, 1);
      const node = routeNodes[0];
      const template = nonCombatTemplates.find((entry) => entry.id === node.routeTemplateId);
      assert.ok(template, `模板 ${node.routeTemplateId} 必须来自合并池`);
      assert.equal(node.routeKind, template.type);
      assert.equal(node.tier, template.type);
      assert.equal(node.enemyIds.length, 0);
      assert.deepEqual(plain(node.choices), template.choices);
      assert.equal(node.name, `${typeLabels[template.type]} · ${template.name}`);
      kinds.add(node.routeKind);
    }
  }
  // 合并池真的生效：三类模板都出现过，不再只有险地。
  assert.deepEqual([...kinds].sort(), ['hazard', 'market', 'wild_gu']);
  // 固定 seed 的槽位与模板（用实际生成值钉死，防止规则漂移）。
  assert.equal(flow.nodeById(first, flow.nodeId(1, 0, 0)).type, 'battle');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 0, 2)).routeTemplateId, 'flooded_cave');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 0, 2)).routeKind, 'hazard');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 4, 0)).routeTemplateId, 'toxic_mountain_path');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 3, 2)).routeTemplateId, 'ridge_market');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 7, 1)).routeTemplateId, 'village_short_work');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 8, 1)).routeTemplateId, 'blood_moss_grove');
  assert.equal(flow.nodeById(first, flow.nodeId(1, 8, 1)).routeKind, 'wild_gu');
  assert.equal(flow.nodeById(first, flow.nodeId(5, 9, 2)).routeTemplateId, 'ridge_market');
  assert.equal(flow.nodeById(first, flow.nodeId(5, 9, 2)).routeKind, 'market');
});

test('every difficulty keeps the three-slot rows and the boss funnel', () => {
  for (const [difficulty, prep] of [['easy', 15], ['normal', 10], ['hard', 5]]) {
    const graph = generate({ difficulty });
    assert.equal(graph.prepPerSegment, prep);
    assert.equal(graph.segmentCount, 5);
    assert.equal(graph.nodes.length, 5 * (prep * 3 + 1));
    assert.equal(graph.nodes.filter((node) => rules.nodeTypes.includes(node.type)).length, 5 * prep);
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

test('a graph built without templates stays battle / elite / boss only', () => {
  const plainGraph = flow.generateGraph({ seed: 20260920, difficulty: 'normal', pools, enemyById });
  assert.equal(plainGraph.nodes.filter((node) => node.routeTemplateId).length, 0);
  assert.deepEqual([...new Set(plainGraph.nodes.map((node) => node.type))].sort(), ['battle', 'boss', 'elite']);
});

test('a template without choices is ignored instead of soft-locking the node', () => {
  const graph = generate({ nonCombatTemplates: [{ id: 'empty_hazard', type: 'hazard', name: '空险地', choices: [] }] });
  assert.equal(graph.nodes.filter((node) => node.routeTemplateId).length, 0);
  assert.deepEqual([...new Set(graph.nodes.map((node) => node.type))].sort(), ['battle', 'boss', 'elite']);
});

test('generated data still carries the non-combat templates and every choice is handled', () => {
  const dataContext = vm.createContext({});
  vm.runInContext(
    fs.readFileSync(new URL('../js/data.js', import.meta.url), 'utf8') + ';globalThis.DATA = DATA;',
    dataContext,
  );
  const data = dataContext.DATA;
  const hazards = data.nodes.filter((node) => node.type === 'hazard');
  assert.deepEqual(plain(hazards.map((node) => node.id)), ['toxic_mountain_path', 'flooded_cave', 'black_mud_marsh']);
  assert.deepEqual(plain(hazards.map((node) => node.name)), ['毒瘴山道', '积水石窟', '黑泥沼地']);
  assert.ok(hazards.every((node) => node.choices.join(',') === 'scout,cross,withdraw'));
  // 合并池成员：市集 2 + 野蛊 1，模板 choices 全部落在模块已搬动作上（leave 单独补卡）。
  const markets = data.nodes.filter((node) => node.type === 'market');
  const wildGu = data.nodes.filter((node) => node.type === 'wild_gu');
  assert.deepEqual(plain(markets.map((node) => node.id)), ['village_short_work', 'ridge_market']);
  assert.deepEqual(plain(wildGu.map((node) => node.id)), ['blood_moss_grove']);
  for (const template of [...markets, ...wildGu, ...hazards]) {
    const options = rules.options({ choices: template.choices, stones: 3, essence: 3 });
    // 模板 choices 里已有 leave 时原位补卡；没有时（险地）按 :44-45 追加一张。
    const expectedIds = template.choices.includes('leave')
      ? [...template.choices]
      : [...template.choices, 'leave'];
    assert.deepEqual(
      plain(options.map((option) => option.id)),
      plain(expectedIds),
      template.id,
    );
    for (const option of options) {
      assert.notEqual(option.reason, 'unsupported_standard_action', `${template.id}:${option.id}`);
      const resolved = rules.resolve(option.id, { stones: 3, essence: 3 });
      assert.equal(resolved.ok, true, `${template.id}:${option.id}`);
      assert.notEqual(resolved.reason, 'unsupported_standard_action');
    }
  }
  // 节点类型与动作的中文名来自 names.json，页面不得硬编码。
  assert.equal(data.nodeTypes.market, '市集');
  assert.equal(data.nodeTypes.wild_gu, '野蛊');
  assert.equal(data.actions.work, '做工');
  assert.equal(data.actions.harvest, '采集');
  assert.equal(data.actions.buy_information, '购买情报');
  assert.equal(data.actions.trade, '交易');
  assert.equal(data.actions.leave, '离开');
});
