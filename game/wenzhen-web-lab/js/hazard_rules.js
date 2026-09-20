// 险地节点选择规则。两个 Godot 来源逐条照搬，不新设计：
// - scripts/domain/social_command_rules.gd:747-803（standard actions 的转移与 effect id）
// - scripts/domain/action_preview_service.gd:992-1128（可用性判定与玩家可见文案）
// 预览卡片里 cross 的成本键是 "spirit"（display_text.gd:459-460 显示为「真元」），
// 领域键是 "essence"；本模块统一叫 essence，lab 侧对应 state.qi。
globalThis.HazardRules = (() => {
  const CHOICE_IDS = ['scout', 'cross', 'withdraw'];

  // social_command_rules.gd:768-771：cross 要求 essence >= 1，成功后扣 1。
  const CROSS_ESSENCE_COST = 1;

  // action_preview_service.gd:1025-1028 的 block_reason 原文。
  const BLOCK_REASON = { insufficient_essence: '真元不足：需要 1 点。' };
  // display_text.gd:503-505：任意被拒行动的兜底文案（含 unsupported_standard_action）。
  const REJECT_FALLBACK = '行动未能完成。';

  // gain/risk 取自 action_preview_service.gd:1024、1077、1086-1087；
  // result 取自 display_text.gd:228、238、242（ACTION_RESULTS）。
  // 预览在 cross 被拒时还给了一条 remedy（action_preview_service.gd:1028），
  // 指向「静修/恢复真元的路线」，lab 固定图没有该路线，故不搬运。
  const CHOICE_TEXTS = {
    scout: {
      gain: ['查明前路的已知征兆。'],
      risk: [],
      result: '你探明前路，留下了可靠的路径情报。',
    },
    cross: {
      gain: ['消耗真元强行穿越，保住前行时机。'],
      risk: [],
      result: '你耗去真元，穿过了眼前险处。',
    },
    withdraw: {
      gain: ['安全收手，保留当前资源与情报。'],
      risk: ['放弃此处机缘，之后无法再从当前路线取得。'],
      result: '你及时收手，暂时全身而退。',
    },
  };

  // social_command_rules.gd:768-771、801-802；未列出的选择见同文件 803 行兜底。
  const TRANSITIONS = {
    scout: { kind: 'fact', fact: 'route_scouted', reason: 'action_scout_route' },
    cross: { kind: 'essence', cost: CROSS_ESSENCE_COST, reason: 'action_cross_cost' },
    withdraw: { kind: 'fact', fact: 'withdrawn_safely', reason: 'action_withdraw_safely' },
  };

  const textOf = (choiceId) => CHOICE_TEXTS[String(choiceId || '')]
    || { gain: [], risk: [], result: '' };

  const essenceOf = (essence) => Math.max(0, Number(essence) || 0);
  const factList = (facts) => [...(facts || [])].map(String);

  // resolver_helpers.gd:24-26（add_fact：已存在则不重复追加）
  function knownFactsWith(facts, factId) {
    const list = factList(facts);
    if (factId && !list.includes(factId)) list.push(factId);
    return list;
  }

  function option(choiceId, { essence = 0 } = {}) {
    const id = String(choiceId || '');
    const texts = textOf(id);
    const transition = TRANSITIONS[id];
    if (!transition) {
      return {
        id, available: false, essenceCost: 0, reason: 'unsupported_standard_action', ...texts,
      };
    }
    const essenceCost = transition.kind === 'essence' ? transition.cost : 0;
    const available = essenceOf(essence) >= essenceCost;
    return {
      id,
      available,
      essenceCost,
      reason: available ? '' : 'insufficient_essence',
      ...texts,
    };
  }

  function options({ choices = CHOICE_IDS, essence = 0 } = {}) {
    return [...(choices || [])].map((choiceId) => option(choiceId, { essence }));
  }

  function resolve(choiceId, { essence = 0, knownFacts = [] } = {}) {
    const id = String(choiceId || '');
    const transition = TRANSITIONS[id];
    const current = essenceOf(essence);
    const facts = factList(knownFacts);
    if (!transition) {
      return { ok: false, reason: 'unsupported_standard_action', essence: current, knownFacts: facts, fact: '' };
    }
    if (transition.kind === 'essence') {
      if (current < transition.cost) {
        return { ok: false, reason: 'insufficient_essence', essence: current, knownFacts: facts, fact: '' };
      }
      return {
        ok: true,
        reason: transition.reason,
        essence: current - transition.cost,
        knownFacts: facts,
        fact: '',
      };
    }
    return {
      ok: true,
      reason: transition.reason,
      essence: current,
      knownFacts: knownFactsWith(facts, transition.fact),
      fact: transition.fact,
    };
  }

  const reasonLabel = (reason) => BLOCK_REASON[String(reason || '')] || REJECT_FALLBACK;
  const resultText = (choiceId) => textOf(choiceId).result;

  return Object.freeze({
    choiceIds: CHOICE_IDS,
    crossEssenceCost: CROSS_ESSENCE_COST,
    option,
    options,
    resolve,
    reasonLabel,
    resultText,
  });
})();
