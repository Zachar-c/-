// 非战斗节点（险地 / 市集 / 野蛊）的 standard action 选择规则。两个 Godot 来源逐条照搬，
// 不新设计：
// - scripts/domain/social_command_rules.gd:747-803（standard actions 的转移与 effect id）
//     work             :749-750  → 元石 +3，action_work_paid
//     harvest          :751-752  → 元石 +2，action_harvest_stone
//     buy_information  :764-765  → 门禁元石 ≥ 2，成功扣 2 并记事实 bought_information
//     trade            :766-767  → 门禁元石 ≥ 2，成功扣 2 并记事实 bought_service
//     cross            :768-771  → 门禁真元 ≥ 1，成功扣 1，action_cross_cost
//     leave            :799      → 记事实 route_left_behind，action_leave_route
//     scout            :801      → 记事实 route_scouted，action_scout_route
//     withdraw         :802      → 记事实 withdrawn_safely，action_withdraw_safely
//     未列出的 action   :803      → 拒绝 unsupported_standard_action
//   辅助函数照抄语义：_resource_transition:814-821（before 记改之前的值、after 记改之后的值）、
//   _spend_stone_for_fact:823-831（元石 < 2 直接拒绝，不改状态）、_fact_transition:881-887。
// - scripts/domain/action_preview_service.gd:992-1128（可用性判定与玩家可见文案）
//     标准卡遍历 choices 时跳过 leave（:992-995），leave 卡另外总是补上（:44-45：节点类型不在
//     caravan/refinement/cultivation/ledger/shop/event/rest 名单里时）；本模块只服务
//     hazard/market/wild_gu 三类，三类都在名单外，所以 leave 卡一律补。
//     卡片 summary 取自节点自己的 summary（:1119）；leave 卡标题与 summary 是固定文案（:1198-1208）。
// 预览卡片里 cross 的成本键是 "spirit"（display_text.gd:459-460 显示为「真元」），
// 领域键是 "essence"；本模块统一叫 essence，lab 侧对应 state.qi。元石门禁文案里的
// 「还差 %d 枚」按 _stone_remedies:1306-1309 的 shortfall 语义补全。
//
// 不搬（登记在覆盖页，不在此实现）：
// - deceive / retreat（效果落在 state.pursuit 追击压力，lab 无 pursuit 槽）
// - open / prepare / scheme（效果落在 state.ascension 升仙五项，lab 无升仙窗口）
// - take_imprint（写 body_imprints 体印，lab 无体印系统）
// - accept / ally / claim / inspect / lure 与 contact/caravan 专属动作（只记事实，lab 的
//   knownFacts 至今没有任何分支消费）
// - refine / cultivate / rest（各自有专属模块与 rest-class 一次性门禁）、
//   claim_recon / claim_token（inheritance_claim_rules.gd）、settle_feeding / accept_debt（总账）
globalThis.NodeActionRules = (() => {
  // 本模块服务的节点类型；三类都在 action_preview_service.gd:44-45 的排除名单外。
  const NODE_TYPES = ['hazard', 'market', 'wild_gu'];
  const LEAVE_ID = 'leave';
  // 已搬动作全集。顺序只用于 options() 的缺省值，实际以节点模板的 choices 为准。
  const ACTION_IDS = ['work', 'harvest', 'buy_information', 'trade', 'cross', 'scout', 'withdraw', 'leave'];

  // social_command_rules.gd:768-771：cross 要求 essence >= 1，成功后扣 1。
  const CROSS_ESSENCE_COST = 1;
  // social_command_rules.gd:823-831：购买情报 / 交易要求 stone >= 2，成功后扣 2。
  const STONE_SERVICE_COST = 2;

  // action_preview_service.gd 的 block_reason 原文。
  const BLOCK_REASON = {
    insufficient_essence: '真元不足：需要 1 点。',              // :1027
    insufficient_stone: '元石不足：需要 2 枚，还差 %d 枚。',      // :1034
  };
  // display_text.gd:503-505：任意被拒行动的兜底文案（含 unsupported_standard_action）。
  const REJECT_FALLBACK = '行动未能完成。';
  // action_preview_service.gd:1306-1309 的三条 remedy，shortfall 由调用点算。
  const STONE_REMEDIES = [
    '可出售已炼化蛊虫。',
    '可前往资源节点补足 %d 枚元石。',
    '也可选择不消耗元石的行动。',
  ];
  // action_preview_service.gd:1198-1208 的 leave 卡固定文案。
  const LEAVE_CARD = {
    title: '离开遭遇',
    summary: '主动结束当前遭遇，返回地图选择下一条路线。',
    gain: ['结束当前遭遇。'],
    risk: [],
  };

  // gain/risk 取自 action_preview_service.gd；result 取自 display_text.gd:223-244（ACTION_RESULTS）。
  // cross 被拒时 Godot 还给了一条 remedy（:1028，「可先选择静修…」），lab 固定图没有该路线，故不搬。
  const CHOICE_TEXTS = {
    work: {
      gain: ['完成短工，获得元石 3 枚。'],                          // :1114-1115
      risk: [],
      result: '你做完短工，换得了元石。',                             // display_text.gd:243
    },
    harvest: {
      gain: ['获得元石 2 枚。'],                                    // :1043-1044
      risk: [],
      result: '你从此处采得了可用的元石收获。',                        // display_text.gd:230
    },
    buy_information: {
      gain: ['获得一条可用情报。'],                                  // :1031
      risk: [],
      result: '你付出元石，换得了可用情报。',                          // display_text.gd:226
    },
    trade: {
      gain: ['获得一次明确服务。'],                                  // :1031
      risk: [],
      result: '你付出元石，换得了一项可调用的服务。',                    // display_text.gd:241
    },
    cross: {
      gain: ['消耗真元强行穿越，保住前行时机。'],                        // :1024
      risk: [],
      result: '你耗去真元，穿过了眼前险处。',                          // display_text.gd:228
    },
    scout: {
      gain: ['查明前路的已知征兆。'],                                 // :1076-1077
      risk: [],
      result: '你探明前路，留下了可靠的路径情报。',                      // display_text.gd:238
    },
    withdraw: {
      gain: ['安全收手，保留当前资源与情报。'],                         // :1086
      risk: ['放弃此处机缘，之后无法再从当前路线取得。'],                 // :1087
      result: '你及时收手，暂时全身而退。',                            // display_text.gd:242
    },
    leave: {
      gain: LEAVE_CARD.gain,
      risk: LEAVE_CARD.risk,
      result: '你放下眼前收益，保留了退路。',                           // display_text.gd:232
    },
  };

  // social_command_rules.gd:747-803 的转移表（kind 对应同文件三个辅助函数）。
  // stoneDelta：_resource_transition(state, "stone", +N)；
  // stoneCost ：_spend_stone_for_fact 的 2 枚门禁 + 扣减 + 记事实；
  // essenceCost：cross 的 1 点门禁 + 扣减；
  // fact      ：_fact_transition 只记事实。
  const TRANSITIONS = {
    work: { kind: 'stone', delta: 3, reason: 'action_work_paid' },
    harvest: { kind: 'stone', delta: 2, reason: 'action_harvest_stone' },
    buy_information: { kind: 'stone', cost: STONE_SERVICE_COST, fact: 'bought_information', reason: 'action_bought_information' },
    trade: { kind: 'stone', cost: STONE_SERVICE_COST, fact: 'bought_service', reason: 'action_trade_service' },
    cross: { kind: 'essence', cost: CROSS_ESSENCE_COST, reason: 'action_cross_cost' },
    scout: { kind: 'fact', fact: 'route_scouted', reason: 'action_scout_route' },
    withdraw: { kind: 'fact', fact: 'withdrawn_safely', reason: 'action_withdraw_safely' },
    leave: { kind: 'fact', fact: 'route_left_behind', reason: 'action_leave_route' },
  };

  const textOf = (choiceId) => CHOICE_TEXTS[String(choiceId || '')]
    || { gain: [], risk: [], result: '' };

  const stoneOf = (stones) => Math.max(0, Math.trunc(Number(stones) || 0));
  const essenceOf = (essence) => Math.max(0, Number(essence) || 0);
  const factList = (facts) => [...(facts || [])].map(String);

  // resolver_helpers.gd:24-26（add_fact：已存在则不重复追加）
  function knownFactsWith(facts, factId) {
    const list = factList(facts);
    if (factId && !list.includes(factId)) list.push(factId);
    return list;
  }

  function blockReasonText(reason, { stones = 0 } = {}) {
    const template = BLOCK_REASON[String(reason || '')];
    if (!template) return REJECT_FALLBACK;
    if (!template.includes('%d')) return template;
    return template.replace('%d', String(Math.max(0, STONE_SERVICE_COST - stoneOf(stones))));
  }

  function stoneRemedies(stones) {
    const shortfall = STONE_SERVICE_COST - stoneOf(stones);
    if (shortfall <= 0) return [];
    return STONE_REMEDIES.map((line) => line.replace('%d', String(shortfall)));
  }

  function option(choiceId, { stones = 0, essence = 0 } = {}) {
    const id = String(choiceId || '');
    const texts = textOf(id);
    const transition = TRANSITIONS[id];
    if (!transition) {
      return {
        id,
        title: '',
        summary: '',
        available: false,
        stoneCost: 0,
        essenceCost: 0,
        reason: 'unsupported_standard_action',
        blockReason: REJECT_FALLBACK,
        remedy: [],
        ...texts,
      };
    }
    const essenceCost = transition.kind === 'essence' ? transition.cost : 0;
    const stoneCost = transition.kind === 'stone' && transition.cost ? transition.cost : 0;
    const available = essenceOf(essence) >= essenceCost && stoneOf(stones) >= stoneCost;
    const reason = available
      ? ''
      : essenceOf(essence) < essenceCost ? 'insufficient_essence' : 'insufficient_stone';
    const base = {
      id,
      title: id === LEAVE_ID ? LEAVE_CARD.title : '',
      summary: id === LEAVE_ID ? LEAVE_CARD.summary : '',
      available,
      stoneCost,
      essenceCost,
      reason,
      blockReason: available ? '' : blockReasonText(reason, { stones }),
      remedy: reason === 'insufficient_stone' ? stoneRemedies(stones) : [],
      ...texts,
    };
    return base;
  }

  // 与 action_preview_service.gd:992-995 同序：先按 choices 出卡（跳过 leave），再补 leave 卡。
  function options({ choices = ACTION_IDS, stones = 0, essence = 0 } = {}) {
    const cards = [...(choices || [])]
      .filter((choiceId) => String(choiceId || '') !== LEAVE_ID)
      .map((choiceId) => option(choiceId, { stones, essence }));
    cards.push(option(LEAVE_ID, { stones, essence }));
    return cards;
  }

  function resolve(choiceId, { stones = 0, essence = 0, knownFacts = [] } = {}) {
    const id = String(choiceId || '');
    const beforeStones = stoneOf(stones);
    const beforeEssence = essenceOf(essence);
    const facts = factList(knownFacts);
    const base = {
      stones: beforeStones,
      stoneBefore: beforeStones,
      stoneAfter: beforeStones,
      essence: beforeEssence,
      essenceBefore: beforeEssence,
      essenceAfter: beforeEssence,
      knownFacts: facts,
      fact: '',
    };
    const transition = TRANSITIONS[id];
    if (!transition) {
      return { ok: false, reason: 'unsupported_standard_action', ...base };
    }
    if (transition.kind === 'essence') {
      if (beforeEssence < transition.cost) {
        return { ok: false, reason: 'insufficient_essence', ...base };
      }
      const after = beforeEssence - transition.cost;
      return { ok: true, reason: transition.reason, ...base, essence: after, essenceAfter: after };
    }
    if (transition.kind === 'stone') {
      if (transition.fact) {
        // social_command_rules.gd:823-831：不足直接拒绝，before/after 都不产生。
        if (beforeStones < transition.cost) {
          return { ok: false, reason: 'insufficient_stone', ...base };
        }
        const after = beforeStones - transition.cost;
        return {
          ok: true,
          reason: transition.reason,
          ...base,
          stones: after,
          stoneAfter: after,
          knownFacts: knownFactsWith(facts, transition.fact),
          fact: transition.fact,
        };
      }
      const after = beforeStones + transition.delta;
      return { ok: true, reason: transition.reason, ...base, stones: after, stoneAfter: after };
    }
    return {
      ok: true,
      reason: transition.reason,
      ...base,
      knownFacts: knownFactsWith(facts, transition.fact),
      fact: transition.fact,
    };
  }

  const reasonLabel = (reason, context) => blockReasonText(reason, context);
  const resultText = (choiceId) => textOf(choiceId).result;

  return Object.freeze({
    nodeTypes: NODE_TYPES,
    actionIds: ACTION_IDS,
    leaveId: LEAVE_ID,
    crossEssenceCost: CROSS_ESSENCE_COST,
    stoneServiceCost: STONE_SERVICE_COST,
    option,
    options,
    resolve,
    reasonLabel,
    resultText,
  });
})();
