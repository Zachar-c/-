// 非战斗节点（险地 / 市集 / 野蛊 / 休整 / 静修）的动作选择规则。Godot 来源逐条照搬，
// 不新设计：
// - scripts/domain/social_command_rules.gd:747-803（standard actions 的转移与 effect id）
//     work             :749-750  → 元石 +3，action_work_paid
//     harvest          :751-752  → 元石 +2，action_harvest_stone
//     buy_information  :764-765  → 门禁元石 ≥ 2，成功扣 2 并记事实 bought_information
//     trade            :766-767  → 门禁元石 ≥ 2，成功扣 2 并记事实 bought_service
//     cross            :768-771  → 门禁真元 ≥ 1，成功扣 1，action_cross_cost
//     meditate         :772-773  → 真元 +1，action_meditate_essence（seclusion 节点用）
//     leave            :799      → 记事实 route_left_behind，action_leave_route
//     scout            :801      → 记事实 route_scouted，action_scout_route
//     withdraw         :802      → 记事实 withdrawn_safely，action_withdraw_safely
//     未列出的 action   :803      → 拒绝 unsupported_standard_action
//   辅助函数照抄语义：_resource_transition:814-821（before 记改之前的值、after 记改之后的值）、
//   _spend_stone_for_fact:823-831（元石 < 2 直接拒绝，不改状态）、_fact_transition:881-887。
// - scripts/domain/rest_rules.gd（休整节点 type=rest 的一次收益门禁）
//     REST_CLASS_TYPES  :27      → ["rest", "refinement", "cultivation"]；seclusion 不在其中，
//                                  所以静修节点没有这道门禁，可用全部标准动作后离开。
//     _rest_heal        :121-141 → 探访已消费则拒绝 rest_already_used；成功：
//                                  气血 = min(上限, 当前 + max(1, floor(上限 × 0.30)))、
//                                  真元 = min(上限, 当前 + 2)，事件 reason rest_recovered，
//                                  标记 <节点id>_used = "used"（:125,128）。
//     _consume_rest_visit :165-179 → 其余收益方式写 <节点id>_used="used" 与 <节点id>_mode="true"，
//                                  事件 rest_visit_consumed（本片未搬，见下）。
//     离开门禁的领域侧支点：social_command_rules.gd:586-589（_travel）与
//     encounter_session_resolver.gd:121-126（_leave）——休息类节点探访未消费时离开被
//     rest_choice_required 拒绝；本模块把该门禁落在「离开休整」卡上（rest_rules.gd 本身
//     不含离开路径）。放行后沿用 lab 既有 leave 转移（action_leave_route + route_left_behind），
//     与其它节点类型的「离开」口径一致。
// - scripts/domain/action_preview_service.gd（休整卡集合与文案）
//     _append_rest_cards :746-808 → 本片只搬两张卡：
//       node.rest_heal :750-758 → 标题「歇脚恢复」（:752）、summary 取节点自己的 summary（:753）；
//         卡片 expected_gain（:756）写死「恢复气血 2 点。/恢复真元 2 点。」，与 rest_rules.gd:129-131
//         的实际效果不符（文案与实现漂移，已登记在覆盖页）。lab 显示按当前数值算出的真实恢复量。
//       node.leave     :799-808 → 标题「离开休整」（:801）、summary「结束休整，返回地图选择下一条路线。」（:802）、
//         executable 只在探访已消费时为真（:803），否则 block_reason「休整抉择未定：须先选择恢复、强化或移除其一，
//         才能离开。」（:804）、expected_gain「结束当前遭遇。」（:806）。
//     _append_rest_option :811-831 → executable = not used and available；已消费的收益卡禁用并显示
//         block_reason「本次休整已处置完毕。」（:822-823）。
// - scripts/domain/action_preview_service.gd:992-1128（可用性判定与玩家可见文案）
//     标准卡遍历 choices 时跳过 leave（:992-995），leave 卡另外总是补上（:44-45：节点类型不在
//     caravan/refinement/cultivation/ledger/shop/event/rest 名单里时）。
//     卡片 summary 取自节点自己的 summary（:1119）；leave 卡标题与 summary 是固定文案（:1198-1208）。
//     本模块服务的五类节点（hazard/market/wild_gu/rest/seclusion）里只有 rest 在 :44 的排除名单内，
//     所以标准节点一律补 leave 卡；休整节点不补（它用自己的「离开休整」）。
// 预览卡片里 cross 的成本键是 "spirit"（display_text.gd:459-460 显示为「真元」），
// 领域键是 "essence"；本模块统一叫 essence，lab 侧对应 state.qi。元石门禁文案里的
// 「还差 %d 枚」按 _stone_remedies:1306-1309 的 shortfall 语义补全。
//
// 不搬（登记在覆盖页，不在此实现）：
// - deceive / retreat（效果落在 state.pursuit 追击压力，lab 无 pursuit 槽）
// - open / prepare / scheme（效果落在 state.ascension 升仙五项，lab 无升仙窗口）
// - take_imprint（写 body_imprints 体印，lab 无体印系统；静修节点 choices 里有它，本模块不出这张卡）
// - accept / ally / claim / inspect / lure 与 contact/caravan 专属动作（只记事实，lab 的
//   knownFacts 至今没有任何分支消费）
// - 休整节点的另四种收益（upgrade_card :759-768 / remove_card :769-778 / remove_imprint :779-788 /
//   remove_curse :789-798）：lab 没有蛊卡强化、免费移除、印记与反噬系统，搬进来就是空按钮。
// - refine / cultivate（各自有专属模块；rest-class 门禁在 rest 上已搬，refinement/cultivation
//   两类节点 lab 未接入）、claim_recon / claim_token（inheritance_claim_rules.gd）、
//   settle_feeding / accept_debt（总账）
globalThis.NodeActionRules = (() => {
  // 本模块服务的节点类型。rest 之外的四个都不在 action_preview_service.gd:44-45 的排除名单里；
  // rest 在名单内（休整走自己的卡片集合，不走 choices 出标准卡）。
  const NODE_TYPES = ['hazard', 'market', 'wild_gu', 'rest', 'seclusion'];
  // 休整节点类型与它的一次性门禁（rest_rules.gd:22 REST_NODE_TYPE / :27 REST_CLASS_TYPES）。
  const REST_TYPE = 'rest';
  const LEAVE_ID = 'leave';
  // 已搬动作全集。顺序只用于 options() 的缺省值，实际以节点模板的 choices 为准。
  const ACTION_IDS = ['work', 'harvest', 'buy_information', 'trade', 'cross', 'scout', 'withdraw', 'meditate', 'leave'];

  // social_command_rules.gd:768-771：cross 要求 essence >= 1，成功后扣 1。
  const CROSS_ESSENCE_COST = 1;
  // social_command_rules.gd:823-831：购买情报 / 交易要求 stone >= 2，成功后扣 2。
  const STONE_SERVICE_COST = 2;

  // action_preview_service.gd 的 block_reason 原文。
  const BLOCK_REASON = {
    insufficient_essence: '真元不足：需要 1 点。',              // :1027
    insufficient_stone: '元石不足：需要 2 枚，还差 %d 枚。',      // :1034
  };
  // 休整节点的卡片文案（action_preview_service.gd）。
  const REST_HEAL_ID = 'node.rest_heal';                      // :751
  const REST_LEAVE_ID = 'node.leave';                         // :800
  const REST_HEAL_TITLE = '歇脚恢复';                           // :752
  const REST_LEAVE_BLOCK = '休整抉择未定：须先选择恢复、强化或移除其一，才能离开。';  // :804
  const REST_USED_BLOCK = '本次休整已处置完毕。';                    // :823
  const REST_LEAVE_CARD = {
    title: '离开休整',                                        // :801
    summary: '结束休整，返回地图选择下一条路线。',                 // :802
    gain: ['结束当前遭遇。'],                                 // :806
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
    meditate: {
      gain: ['恢复 1 点真元。'],                                     // :1068-1069
      risk: [],
      result: '你静修片刻，恢复了一点真元。',                          // display_text.gd:234
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
    // meditate（seclusion 节点）：真元 +1。Godot 的 _resource_transition:814-821 不做上限截断，
    // lab 按 L2 口径在真元上限（essenceMax）处截断；调用点一律传 state.qiMax。
    meditate: { kind: 'essence', delta: 1, reason: 'action_meditate_essence' },
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
    const essenceCost = transition.kind === 'essence' && transition.cost ? transition.cost : 0;
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
  // 只对已搬动作出卡：choices 里未搬的动作（body_imprint_ritual 的 take_imprint）不出禁用空按钮，
  // 按覆盖页登记不实现（单个 option() 对未搬动作仍给 Godot 兜底卡，供契约测试用）。
  function options({ choices = ACTION_IDS, stones = 0, essence = 0 } = {}) {
    const cards = [...(choices || [])]
      .filter((choiceId) => {
        const id = String(choiceId || '');
        return id !== LEAVE_ID && ACTION_IDS.includes(id);
      })
      .map((choiceId) => option(choiceId, { stones, essence }));
    cards.push(option(LEAVE_ID, { stones, essence }));
    return cards;
  }

  function resolve(choiceId, {
    stones = 0, essence = 0, essenceMax, knownFacts = [],
  } = {}) {
    const id = String(choiceId || '');
    const beforeStones = stoneOf(stones);
    const beforeEssence = essenceOf(essence);
    // 真元上限：meditate 用；不传即不截断（Godot _resource_transition 无上限语义，lab 调用点一律传 qiMax）。
    const essenceCap = essenceMax === undefined ? Infinity : essenceOf(essenceMax);
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
      if (transition.cost) {
        if (beforeEssence < transition.cost) {
          return { ok: false, reason: 'insufficient_essence', ...base };
        }
        const after = beforeEssence - transition.cost;
        return { ok: true, reason: transition.reason, ...base, essence: after, essenceAfter: after };
      }
      const after = Math.min(essenceCap, beforeEssence + Number(transition.delta || 0));
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

  // ---- 休整节点（type=rest）：一次收益门禁 + 两张卡 ------------------------------
  // 恢复数值单一来源：run_rules.js::restHeal（镜像 rest_rules.gd::_rest_heal:121-141），
  // 本模块不再重写公式。
  function restRecovery({ health = 0, healthMax = 0, essence = 0, essenceMax = 0 } = {}) {
    const healthBefore = Math.max(0, Number(health) || 0);
    const essenceBefore = essenceOf(essence);
    const after = RunRules.restHeal({
      health: healthBefore,
      maxHealth: Math.max(0, Number(healthMax) || 0),
      essence: essenceBefore,
      essenceMax: essenceOf(essenceMax),
    });
    return {
      healthBefore,
      healthAfter: after.health,
      healthGain: after.health - healthBefore,
      essenceBefore,
      essenceAfter: after.essence,
      essenceGain: after.essence - essenceBefore,
    };
  }

  // action_preview_service.gd:746-808 的休整卡集合，本片只搬两张
  // （node.rest_heal :750-758 与 node.leave :799-808）。收益卡 expected_gain 的「2 点」
  // 与 rest_rules.gd:129-131 不符，lab 改报按当前数值算出的真实恢复量（覆盖页已登记）。
  function restCards({ summary = '', used = false, health = 0, healthMax = 0, essence = 0, essenceMax = 0 } = {}) {
    const visited = used === true;
    const recovery = restRecovery({ health, healthMax, essence, essenceMax });
    return [
      {
        id: REST_HEAL_ID,
        title: REST_HEAL_TITLE,                                // :752
        summary: String(summary || ''),                        // :753
        available: !visited,                                   // :822 executable = not used and available
        reason: visited ? 'rest_already_used' : '',
        blockReason: visited ? REST_USED_BLOCK : '',           // :823
        stoneCost: 0,
        essenceCost: 0,
        remedy: [],
        gain: [`恢复气血 ${recovery.healthGain} 点。`, `恢复真元 ${recovery.essenceGain} 点。`],
        risk: [],
        recovery,
      },
      {
        id: REST_LEAVE_ID,
        title: REST_LEAVE_CARD.title,
        summary: REST_LEAVE_CARD.summary,
        available: visited,                                    // :803 executable = used
        reason: visited ? '' : 'rest_choice_required',
        blockReason: visited ? '' : REST_LEAVE_BLOCK,          // :804
        stoneCost: 0,
        essenceCost: 0,
        remedy: [],
        gain: [...REST_LEAVE_CARD.gain],
        risk: [],
      },
    ];
  }

  // rest_rules.gd:121-141（取收益）+ :803 的离开门禁。被拒分支一律不改状态（照抄 _rejected 语义）。
  // 放行走沿用 lab 的 leave 转移（action_leave_route + route_left_behind，social_command_rules.gd:799）。
  function resolveRest(choiceId, {
    used = false, health = 0, healthMax = 0, essence = 0, essenceMax = 0, knownFacts = [],
  } = {}) {
    const id = String(choiceId || '');
    const visited = used === true;
    const recovery = restRecovery({ health, healthMax, essence, essenceMax });
    // 被拒分支不改状态：after 一律等于 before、增益为 0（照抄 _rejected 语义）。
    const unchanged = {
      healthBefore: recovery.healthBefore,
      healthAfter: recovery.healthBefore,
      healthGain: 0,
      essenceBefore: recovery.essenceBefore,
      essenceAfter: recovery.essenceBefore,
      essenceGain: 0,
    };
    const facts = factList(knownFacts);
    const base = {
      ok: false,
      reason: '',
      text: '',
      title: '',
      used: visited,
      usedBefore: visited,
      knownFacts: facts,
      fact: '',
      ...unchanged,
    };
    if (id === REST_HEAL_ID) {
      if (visited) {
        return { ...base, reason: 'rest_already_used', title: REST_HEAL_TITLE };
      }
      return {
        ...base,
        ok: true,
        reason: 'rest_recovered',                              // rest_rules.gd:137
        title: REST_HEAL_TITLE,
        used: true,
        ...recovery,
        // lab 侧提示口径：Godot 的 ACTION_RESULTS 没有 rest 键（display_text.gd:223-244），
        // 落地在无 action_id 的兜底路径（:510-518）；这里按 lab 既有的「动作 · 数值增减」报真实恢复量。
        text: `${REST_HEAL_TITLE} · 气血 +${recovery.healthGain} · 真元 +${recovery.essenceGain}`,
      };
    }
    if (id === REST_LEAVE_ID) {
      if (!visited) {
        return { ...base, reason: 'rest_choice_required', title: REST_LEAVE_CARD.title };
      }
      return {
        ...base,
        ok: true,
        reason: 'action_leave_route',
        title: REST_LEAVE_CARD.title,
        knownFacts: knownFactsWith(facts, 'route_left_behind'),
        fact: 'route_left_behind',
        text: textOf(LEAVE_ID).result,                         // display_text.gd:232
      };
    }
    return { ...base, reason: 'unsupported_standard_action' };
  }

  const restReasonLabel = (reason) => {
    const text = reason === 'rest_choice_required' ? REST_LEAVE_BLOCK
      : reason === 'rest_already_used' ? REST_USED_BLOCK
        : '';
    return text || blockReasonText(reason);
  };

  // 节点类型显示名：data/names.json → types 优先；该分区缺 rest 键（数据缺口，覆盖页登记），
  // 回退名取自 scripts/presentation/display_text.gd:54 的 const TYPES（rest = 「休整」）。
  const TYPE_FALLBACK = { rest: '休整' };
  const typeLabel = (type, labels = {}) => {
    const key = String(type || '');
    return String(labels?.[key] || TYPE_FALLBACK[key] || '');
  };
  const typeLabels = (labels = {}) => ({ ...TYPE_FALLBACK, ...labels });

  return Object.freeze({
    nodeTypes: NODE_TYPES,
    restNodeType: REST_TYPE,
    actionIds: ACTION_IDS,
    leaveId: LEAVE_ID,
    restHealId: REST_HEAL_ID,
    restLeaveId: REST_LEAVE_ID,
    crossEssenceCost: CROSS_ESSENCE_COST,
    stoneServiceCost: STONE_SERVICE_COST,
    option,
    options,
    resolve,
    reasonLabel,
    resultText,
    typeLabel,
    typeLabels,
    restRecovery,
    restCards,
    resolveRest,
    restReasonLabel,
  });
})();
