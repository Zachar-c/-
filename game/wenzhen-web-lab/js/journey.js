// 路线、节点图、整备页与终局页。状态转换仍全部收口到 main.js 的 act。
const STAGE_LABEL = { one: '一转', two: '二转', three: '三转', four: '四转', five: '五转' };
const APTITUDE_LABEL = { jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' };

// 整备页右侧工作区的页签。选中项必须活过整页重绘——否则在蛊仓里卖一只蛊，
// 界面会把你弹回坊市（2026-09-20）。
let prepTab = 'shop';
const PREP_TABS = [
  { id: 'shop', label: '坊市' },
  { id: 'gu', label: '蛊仓' },
  { id: 'alchemy', label: '炼蛊' },
  { id: 'killmove', label: '杀招' },
];

function guById(id) {
  return DATA.gu.find((g) => g.id === id) || null;
}

function nodeById(id) {
  if (!id) return null;
  return RunFlow.nodeById(state.journey.graph, id);
}

function currentNode() {
  return nodeById(state.journey.nodeId);
}

function materialById(id) {
  return DATA.materials.find((m) => m.id === id) || { id, name: id };
}

function npcById(id) {
  return DATA.npcs.find((n) => n.id === id) || null;
}

function eventById(id) {
  return DATA.events.find((e) => e.id === id) || null;
}

// 节点类型中文名优先取 Godot 侧 data/names.json 的 types 分区（DATA.nodeTypes）；该分区缺
// rest 键（数据缺口，覆盖页已登记），回退名由 NodeActionRules.typeLabel 提供
// （来源 scripts/presentation/display_text.gd:54）。
// battle/elite/boss 是原型自己的战斗节点分层，不在该分区内，走回退。
function nodeTypeLabel(type) {
  return NodeActionRules.typeLabel(type, DATA.nodeTypes)
    || ({ battle: '战斗', elite: '精英', boss: '层主' }[type])
    || type || '未知';
}

function actionLabel(action) {
  return DATA.actions[action] || action;
}

function stageLabel(stage) {
  return STAGE_LABEL[stage] || stage || '—';
}

function nodeEnemyIds(node) {
  if (!node) return [];
  return [...new Set([...(node.enemyIds || []), node.enemyKind, ...(node.enemyKinds || [])].filter(Boolean))];
}

function enemyById(id) {
  return DATA.enemies.find((e) => e.id === id) || null;
}

function currentSegment() {
  return Number(currentNode()?.segment || 1);
}

// 选中节点后该回到哪一页：战斗/结算/未解析的节点动作/统一整备。
function currentNodePage() {
  if (state.battle) return 'battle';
  if (state.reward) return 'reward';
  const node = currentNode();
  if (node && NodeActionRules.nodeTypes.includes(node.type) && state.prepFor !== node.id) return 'node-action';
  return 'prep';
}

function segmentTitle(segment) {
  return DATA.flow.segmentTitles?.[String(segment)] || `第 ${segment} 段`;
}

function renderJourneyPages() {
  renderHall(document.querySelector('#panel-hall'));
  renderMap(document.querySelector('#panel-map'));
  renderNodeActions(document.querySelector('#panel-node-action'));
  renderPrep(document.querySelector('#panel-prep'));
  renderReward(document.querySelector('#panel-reward'));
  renderEnding(document.querySelector('#panel-ending'));
}

function renderHall(root) {
  if (!root) return;
  const difficulty = state.journey.difficulty || 'normal';
  const preset = DATA.flow.difficulties[difficulty] || DATA.flow.difficulties.normal;
  const started = !!state.journey.started;
  const completed = state.journey.completed.length;
  const inProgress = typeof isInProgressRun === 'function' ? isInProgressRun() : false;
  const saveIssue = typeof bootSaveIssue !== 'undefined' ? bootSaveIssue : null;
  const saveStatus = typeof lastSaveStatus !== 'undefined' ? lastSaveStatus : { ok: true, reason: '' };
  const cannotRead = saveIssue === 'unreadable';
  const storageDown = saveIssue === 'storage_error' || saveStatus.ok === false;
  const saveLine = cannotRead
    ? '<div class="hall-save bad">无法读取存档 · 原文已保留 · 请明确选择重新开局</div>'
    : storageDown
      ? '<div class="hall-save bad">存储不可用 · 本局无法续玩 · 不会假称已保存</div>'
      : inProgress
        ? '<div class="hall-save ok">本局会自动保存 · 刷新后可继续</div>'
        : started
          ? '<div class="hall-save">本局已结束 · 可直接开始新局</div>'
          : '';
  root.innerHTML = `
    <div class="hall-grid">
      <section class="hall-main">
        <div class="eyebrow">问真 · Web 拼装局</div>
        <h1>问真</h1>
        <p class="hall-copy">固定节点图、战斗、节点动作（险地 / 市集 / 野蛊 / 休整 / 静修）、战后三选一、统一整备。选择难度后开局；当前局面只展示可走的后续边。</p>
        ${saveLine}
        ${state.ending ? `
        <div class="hall-ending" data-hall-ending>
          <div class="kicker">终局摘要 · ${state.ending.outcome === 'victory' ? '胜局' : '败局'}</div>
          <h2>${state.ending.title}</h2>
          <p>${state.ending.detail}</p>
          <div class="resource-row">
            <span>outcome: ${state.ending.outcome}</span>
            <span>回合 ${state.ending.turn || 0}</span>
            <span>已完成 ${state.journey.completed.length}</span>
          </div>
        </div>` : ''}
        <div class="difficulty-row">
          ${Object.entries(DATA.flow.difficulties).map(([key, value]) => `
            <button class="${key === difficulty ? 'on' : ''}" data-difficulty="${key}">
              <b>${value.label}</b><span>每段 ${value.prepPerSegment} 个准备节点</span>
            </button>`).join('')}
        </div>
        <div class="hall-actions">
          ${inProgress ? '<button class="primary" data-continue-run>继续当前局</button>' : ''}
          <button class="${inProgress ? 'ghost' : 'primary'}" data-start-run>${inProgress ? '开始新局' : started ? '重新开局' : '开始新局'}</button>
          ${started && !state.ending ? '<button class="ghost" data-go-map>返回节点图</button>' : ''}
        </div>
      </section>
      <aside class="hall-side">
        <div class="kicker">当前局面</div>
        <div class="hall-big">${completed}<span>/ ${state.journey.graph.nodes.length}</span></div>
        <div class="hall-node">${currentNode() ? `${nodeTypeLabel(currentNode().type)} · ${currentNode().name}` : state.ending ? `已终局 · ${state.ending.outcome}` : started ? '等待选择下一个节点' : '尚未开局'}</div>
        <div class="resource-row">
          <span>${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}</span>
          <span>真元 ${state.qi}/${state.qiMax}</span>
          <span>元石 ${state.stones}</span>
          <span>气血 ${state.blood}/${state.bloodMax}</span>
        </div>
        <div class="hall-preset">${preset.label} · 五段 · 第五层主为终局</div>
      </aside>
    </div>
    <h2 style="margin-top:28px">本局记录</h2>
    ${state.journal.length
      ? `<div class="journal">${state.journal.slice(0, 8).map((line, i) => `<div><span>${String(state.journal.length - i).padStart(2, '0')}</span>${line}</div>`).join('')}</div>`
      : '<div class="empty">还没有记录。开局后，节点结算、奖励与整备会写在这里。</div>'}`;

  root.querySelectorAll('[data-difficulty]').forEach((button) => {
    button.addEventListener('click', () => {
      if (typeof requestDifficultyChange === 'function') {
        requestDifficultyChange(button.dataset.difficulty);
        return;
      }
      state = fresh(button.dataset.difficulty);
      draw();
    });
  });
  root.querySelector('[data-continue-run]')?.addEventListener('click', () => {
    if (typeof continueRun === 'function') continueRun();
  });
  root.querySelector('[data-start-run]').addEventListener('click', () => act.startRun(state.journey.difficulty || 'normal'));
  root.querySelector('[data-go-map]')?.addEventListener('click', () => showPage('map'));
}

function renderMap(root) {
  if (!root) return;
  const selected = state.journey.nodeId;
  const available = new Set(state.journey.availableNodeIds || []);
  const completed = new Set(state.journey.completed || []);
  const firstAvailable = available.size ? RunFlow.nodeById(state.journey.graph, [...available][0]) : null;
  const segment = selected ? Number(currentNode().segment) : Number(firstAvailable?.segment || 1);
  const current = currentNode();
  const candidates = [...available]
    .map((id) => RunFlow.nodeById(state.journey.graph, id))
    .filter(Boolean)
    .sort((a, b) => a.depth - b.depth || a.slot - b.slot);
  const pathNodes = (state.journey.graph.nodes || [])
    .filter((node) => completed.has(node.id) && node.segment === segment)
    .sort((a, b) => a.depth - b.depth || a.slot - b.slot);
  const depthText = current
    ? `第 ${current.depth + 1} / ${state.journey.graph.prepPerSegment} 个准备节点`
    : candidates[0]?.type === 'boss'
      ? '层主'
      : `第 ${Number(candidates[0]?.depth || 0) + 1} / ${state.journey.graph.prepPerSegment} 个准备节点`;
  const totalDepth = state.journey.graph.prepPerSegment;
  root.innerHTML = `
    <div class="section-head">
      <div>
        <div class="kicker">第 ${segment} 段 · ${segmentTitle(segment)} · ${depthText}</div>
        <h2>${selected ? '节点结算中' : '选择下一个节点'}</h2>
      </div>
      <div class="legend"><span class="dot current"></span>当前 <span class="dot done"></span>已过 <span class="dot locked"></span>可走</div>
    </div>
    <div class="map-help">每段沿路径经过 ${totalDepth} 个准备节点；当前节点会展开 2 至 3 条后继边。</div>
    ${pathNodes.length ? `<div class="journey-trail">${pathNodes.map((node) => `<span>${node.depth + 1}. ${nodeTypeLabel(node.type)}</span>`).join('')}</div>` : ''}
    ${current ? `<div class="map-nodes map-choices">${mapNodeCard(current, selected, new Set([current.id]), completed)}</div>` : ''}
    ${!current && candidates.length ? `<h3 class="map-choice-title">当前可走后继</h3><div class="map-nodes map-choices">${candidates.map((node) => mapNodeCard(node, selected, available, completed)).join('')}</div>` : ''}
    ${selected ? `<div class="leave-row"><button class="primary" data-return-node>${{ battle: '返回当前战斗', reward: '查看结算', 'node-action': '返回选择', prep: '继续整备' }[currentNodePage()]}</button></div>` : ''}`;

  root.querySelectorAll('[data-choose-node]').forEach((button) => {
    button.addEventListener('click', () => act.chooseNode(button.dataset.chooseNode));
  });
  root.querySelector('[data-return-node]')?.addEventListener('click', () => {
    showPage(currentNodePage());
  });
}

function mapNodeCard(node, selected, available, completed) {
  const isSelected = node.id === selected;
  const isAvailable = available.has(node.id);
  const isDone = completed.has(node.id);
  const stateClass = isSelected ? 'current' : isDone ? 'done' : isAvailable ? 'available' : 'locked';
  const isActionNode = NodeActionRules.nodeTypes.includes(node.type);
  const detail = isActionNode
    ? nodeActionMenuLabels(node).join(' · ')
    : nodeEnemyIds(node).map((id) => (enemyById(id) || {}).name || id).join('、');
  return `<article class="map-node ${stateClass}">
    <div class="rn-top"><span>${node.type === 'boss' ? '层主' : `L${node.segment} · ${node.depth + 1}`}</span><em>${nodeTypeLabel(node.type)}</em></div>
    <div class="rn-name">${node.name}</div>
    <div class="rn-enemies">${detail || '无战斗数据'}</div>
    ${isActionNode && node.summary ? `<div class="rn-summary">${node.summary}</div>` : ''}
    ${isAvailable ? `<button data-choose-node="${node.id}">进入</button>` : `<span class="rn-state">${isSelected ? '当前' : isDone ? '已过' : '未选'}</span>`}
  </article>`;
}

// 地图卡片上的动作摘要：休整节点列自己的两张卡（歇脚恢复 / 离开休整，标题与卡片同源），
// 其余标准节点只列本模块真的会出卡的动作——choices 里未搬的动作不列（如体印仪式的 take_imprint）。
function nodeActionMenuLabels(node) {
  if (node.type === NodeActionRules.restNodeType) {
    return NodeActionRules.restCards({ summary: node.summary }).map((card) => card.title);
  }
  return (node.choices || [])
    .filter((choiceId) => NodeActionRules.actionIds.includes(String(choiceId)))
    .map(actionLabel);
}

// 节点动作页底注（lab 侧说明文案，不是 Godot 原文）。
const NODE_ACTION_HELP = '节点动作按 Godot standard actions 结算：做工 +3 元石、采集 +2 元石；购买情报与交易各耗 2 枚元石；探查、退回与离开只记事实；穿越消耗 1 点真元；静修恢复 1 点真元（真元上限处截断）；解析后进入统一整备。';
const REST_ACTION_HELP = '休整节点是一次收益门禁：先取「歇脚恢复」（气血按上限的 30% 向下取整、至少 1 点，真元 +2，均不超上限），「离开休整」才会解禁；本次探访只能取一项收益。数值来源 rest_rules.gd:121-141。';

// 节点动作页（险地 / 市集 / 野蛊 / 休整 / 静修）：标准节点列模板 choices 的 standard action 卡
// （另按 :44-45 补一张 leave 卡）；休整节点出自己的一套卡（歇脚恢复 + 离开休整，后者是两步交互的门禁）。
// 规则、门禁、文案全部来自 js/node_action_rules.js，页面不另算。
function renderNodeActions(root) {
  if (!root) return;
  const node = currentNode();
  if (!node || !NodeActionRules.nodeTypes.includes(node.type) || state.prepFor === node.id) {
    root.innerHTML = '<div class="empty">当前没有待处理的节点动作。</div>';
    return;
  }
  const isRest = node.type === NodeActionRules.restNodeType;
  const cards = isRest
    ? NodeActionRules.restCards({
        summary: node.summary,
        used: state.restUsed === true,
        health: state.blood,
        healthMax: state.bloodMax,
        essence: state.qi,
        essenceMax: state.qiMax,
      })
    : NodeActionRules.options({
        choices: node.choices,
        stones: state.stones,
        essence: state.qi,
      });
  root.innerHTML = `
    <div class="section-head">
      <div>
        <div class="kicker">${segmentTitle(node.segment)} · ${nodeTypeLabel(node.type)} · 第 ${node.depth + 1} / ${state.journey.graph.prepPerSegment} 个准备节点</div>
        <h2>${node.name}</h2>
      </div>
      <div class="prep-resources">
        <span>真元 ${state.qi}/${state.qiMax}</span>
        <span>元石 ${state.stones}</span>
        <span>气血 ${state.blood}/${state.bloodMax}</span>
      </div>
    </div>
    <div class="node-action-choices">${cards.map((option) => `
      <article class="node-action-choice ${option.available ? 'ready' : ''}">
        <div class="na-head"><b>${option.title || actionLabel(option.id)}</b><span>${nodeActionCostText(option)}</span></div>
        ${option.summary || node.summary ? `<p class="na-summary">${option.summary || node.summary}</p>` : ''}
        ${(option.gain || []).map((line) => `<p>${line}</p>`).join('')}
        ${(option.risk || []).map((line) => `<p class="risk">${line}</p>`).join('')}
        ${option.available ? '' : `<p class="blocked">${option.blockReason}</p>`}
        ${(option.remedy || []).map((line) => `<p class="remedy">${line}</p>`).join('')}
        <button class="${option.available ? 'primary' : ''}" ${option.available ? '' : 'disabled'} data-node-action="${option.id}">${option.available ? '执行' : '不可用'}</button>
      </article>`).join('')}</div>
    <div class="map-help">${isRest ? REST_ACTION_HELP : NODE_ACTION_HELP}</div>`;
  root.querySelectorAll('[data-node-action]').forEach((button) => {
    button.addEventListener('click', () => act.resolveNodeAction(button.dataset.nodeAction));
  });
}

// 成本文案口径同 display_text.gd:455-462（元石 X / 真元 Y），无成本显示「无消耗」。
function nodeActionCostText(option) {
  const parts = [];
  if (option.essenceCost > 0) parts.push(`真元 -${option.essenceCost}`);
  if (option.stoneCost > 0) parts.push(`元石 -${option.stoneCost}`);
  return parts.length ? parts.join(' · ') : '无消耗';
}

function currentShopContext() {
  const node = currentNode();
  return {
    seed: state.seed,
    nodeKey: node?.id || 'free_shop',
    pacingLayers: DATA.loot.pacingLayers,
    layer: node?.segment || currentSegment(),
    school: state.school,
  };
}

function offerCost(offer) {
  const base = Number(offer.stone_cost || 0);
  return ShopRules.layerPrice(DATA.loot.pacingLayers, currentShopContext().layer, base);
}

function offerStocked(offer) {
  return ShopRules.offerIsStocked(DATA.shopOffers, offer.id, currentShopContext());
}

function canBuyOffer(offer) {
  if (state.shopSold.includes(offer.id)) return false;
  if (!offerStocked(offer)) return false;
  if (offerCost(offer) > state.stones) return false;
  if (offer.kind === 'gu_fang_unlock' && state.globalCodexIds.includes(offer.gu_id)) return false;
  return ['purchase', 'material_purchase', 'gu_fang_unlock'].includes(offer.kind);
}

function shopKindLabel(kind) {
  return { purchase: '蛊', material_purchase: '材', gu_fang_unlock: '方' }[kind] || '服';
}

function shopGuName(guId) {
  const known = DATA.shopOffers.find((offer) => offer.gu_id === guId && offer.gu_name);
  return (guById(guId) || {}).name || known?.gu_name || '无名蛊';
}

function shopTradeName(offer) {
  if (offer.kind === 'gu_fang_unlock') return `古方·${shopGuName(offer.gu_id)}`;
  return '神秘交易';
}

function offerName(offer) {
  if (offer.kind === 'purchase' && offer.gu_id) return shopGuName(offer.gu_id);
  if (offer.kind === 'material_purchase' && offer.material_id) return materialById(offer.material_id).name;
  return shopTradeName(offer);
}

function offerDetail(offer) {
  if (offer.kind === 'gu_fang_unlock') return '持方即知产物，免未知损失';
  if (offer.gu_id) {
    const gu = guById(offer.gu_id);
    return gu ? `${gu.rank} 转 · ${schoolLabel(gu.school)} · ${effectText(gu.effect)}` : '蛊虫货物';
  }
  if (offer.material_id) return `材料 · ${materialById(offer.material_id).name}`;
  return '尚未说明的交易';
}

function shopStock() {
  const context = currentShopContext();
  const goods = ShopRules.stock(DATA.shopOffers, context)
    .map((id) => DATA.shopOffers.find((offer) => offer.id === id))
    .filter(Boolean);
  const services = DATA.shopOffers.filter((offer) => ShopRules.serviceKinds.includes(offer.kind));
  return [...goods, ...services];
}

function shopOfferCard(offer) {
  const sold = state.shopSold.includes(offer.id);
  const can = canBuyOffer(offer);
  const reason = sold
    ? '已购入'
    : !offerStocked(offer)
      ? '本店未上架'
      : offerCost(offer) > state.stones
        ? '元石不足'
        : '可购入';
  return `<article class="shop-offer ${can ? 'ready' : ''}">
    <div class="so-kind">${shopKindLabel(offer.kind)}</div>
    <div class="so-name">${offerName(offer)}</div>
    <div class="so-detail">${offerDetail(offer)}</div>
    <div class="so-foot"><span>元石 ${offerCost(offer)}</span><span>${reason}</span></div>
    <button ${can ? '' : 'disabled'} data-buy-offer="${offer.id}">购入</button>
  </article>`;
}

// 蛊仓卡片：与坊市、炼蛊台共用 .gu 卡片外观。
// 早先这里是全宽单行列表——14 行、每行为了右侧一个「卖」按钮横跨整个页面宽度，
// 既占地方又难扫（2026-09-20）。
function inventoryCard(gu) {
  const count = Number(state.owned[gu.id] || 0);
  if (count <= 0) return '';
  const price = RunFlow.sellValue(gu.value);
  return `<article class="gu ${gu.rank > 1 ? 'r2' : ''}">
    <span class="cnt">×${count}</span>
    <img src="../assets/wenzhen/gu/${gu.icon}.png" alt="">
    <div class="gn">${gu.name}</div>
    <div class="gm">${gu.rank} 转 · ${schoolLabel(gu.school)} · 值 ${gu.value}</div>
    <div class="ge">${effectText(gu.effect)}</div>
    <div class="gu-foot"><span>卖 ${price}</span><button class="ghost" data-sell-gu="${gu.id}">卖出</button></div>
  </article>`;
}

function renderPrep(root) {
  if (!root) return;
  const node = currentNode();
  if (!node) {
    root.innerHTML = '<div class="empty">当前没有待整备节点。</div>';
    return;
  }
  const next = RunFlow.nextBreakthrough({
    rank: state.cultivation,
    stageIndex: state.cultivationStage,
    stones: state.stones,
    aptitude: state.aptitude,
    owned: state.owned,
  }, DATA.flow);
  const materials = DATA.materials.filter((material) => Number(state.materials[material.id] || 0) > 0);
  const offers = shopStock();
  const aptId = DATA.flow.aptitudeGuId;
  const sariName = next.sariId ? (guById(next.sariId) || {}).name : '同阶舍利蛊';
  // 界面必须区分「需求」与「持有」：早先这里直接把需求蛊写成 `名字 ×1`，
  // 读起来就是背包条目，玩家会以为已经持有（2026-09-20 实测踩到）。
  // 舍利不可越阶替代，所以持有但转数不符时要把持有清单摊开说明原因。
  const sariRankById = Object.fromEntries(
    Object.entries(DATA.flow.sariByRank || {}).map(([rank, id]) => [id, Number(rank)]),
  );
  const sariHeld = next.sariId ? Number(state.owned[next.sariId] || 0) : 0;
  const heldSari = Object.keys(sariRankById)
    .filter((id) => Number(state.owned[id] || 0) > 0 && !(next.canSari && id === next.sariId))
    .map((id) => `${(guById(id) || {}).name || id} ×${Number(state.owned[id])}（${sariRankById[id]} 转）`);
  const ownedGu = DATA.gu.filter((gu) => Number(state.owned[gu.id] || 0) > 0);
  const aptCount = Number(state.owned[aptId] || 0);
  const tab = PREP_TABS.some((entry) => entry.id === prepTab) ? prepTab : 'shop';
  const tabCount = {
    shop: offers.length,
    gu: ownedGu.length,
    alchemy: DATA.recipes.length,
    killmove: DATA.killMoves.length,
  };
  root.innerHTML = `
    <div class="prep-head">
      <div class="prep-title">
        <div class="kicker">${segmentTitle(node.segment)} · ${nodeTypeLabel(node.type)} · 整备</div>
        <h2>${node.name}</h2>
      </div>
      <div class="prep-resources">
        <span>${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}</span>
        <span>气血 ${state.blood}/${state.bloodMax}</span>
        <span>真元 ${state.qi}/${state.qiMax}</span>
        <span>元石 ${state.stones}</span>
      </div>
      <button class="primary prep-leave" data-prep-continue>完成整备 · 选择下一节点</button>
    </div>
    <div class="prep-shell">
      <aside class="prep-rail">
        <section class="rail-block">
          <div class="kicker">修炼突破</div>
          <h3>${next.kind === 'small' ? `冲击 ${next.targetLabel}` : next.kind === 'big' ? `冲击 ${next.targetRank} 转` : '五转巅峰'}</h3>
          ${next.kind === 'small' ? `
            <p>小突破消耗元石，或消耗 1 只当前转数同阶舍利蛊。</p>
            <div class="button-row">
              <button class="${next.canStone ? 'primary' : ''}" ${next.canStone ? '' : 'disabled'} data-break="stone">元石 ${next.stoneCost}</button>
              <button class="${next.canSari ? 'primary' : ''}" ${next.canSari ? '' : 'disabled'} data-break="sari">消耗 ${sariName}</button>
            </div>
            <div class="prep-line">需要 1 只 ${sariName} · 你持有 ${sariHeld}</div>
            ${heldSari.length ? `<div class="prep-line">舍利不可越阶替代；你还持有 ${heldSari.join('、')}</div>` : ''}
          ` : next.kind === 'big' ? `
            <p>大突破要求资质与元石同时达标。</p>
            <div class="prep-line">资质 ${next.aptitudeOk ? '达标' : `需要 ${APTITUDE_LABEL[next.requiredApt] || next.requiredApt}`}</div>
            <div class="prep-line">元石 ${next.stoneCost}</div>
            <button class="${next.ok ? 'primary' : ''}" ${next.ok ? '' : 'disabled'} data-break="stone">冲击下一转</button>
          ` : '<p>已经到达当前修炼上限。</p>'}
        </section>
        <section class="rail-block">
          <div class="kicker">资质蛊</div>
          <h3>资质 ${APTITUDE_LABEL[state.aptitude] || state.aptitude}</h3>
          <p>使用后立即提升一档，并同步更新真元容量与恢复。</p>
          <button style="margin-top:13px" class="${aptCount > 0 ? 'primary' : ''}" ${aptCount > 0 ? '' : 'disabled'} data-use-aptitude>使用资质蛊 ×${aptCount}</button>
        </section>
        <section class="rail-block">
          <div class="kicker">材料 · ${materials.length} 种</div>
          <div class="material-list">${materials.map((material) => `<div class="material-line"><span>${material.name}</span><b>×${state.materials[material.id]}</b></div>`).join('') || '<div class="empty">暂无材料。</div>'}</div>
        </section>
      </aside>
      <div class="prep-work">
        <nav class="prep-tabs">
          ${PREP_TABS.map((entry) => `<button data-prep-tab="${entry.id}" class="${entry.id === tab ? 'on' : ''}">${entry.label}<span class="tab-count">${tabCount[entry.id]}</span></button>`).join('')}
        </nav>
        <div class="prep-pane${tab === 'shop' ? ' on' : ''}" data-pane="shop">
          <div class="pane-note">本页买完即售罄，进入下一节点后刷新。</div>
          <div class="shop-grid">${offers.map(shopOfferCard).join('') || '<div class="empty">本层暂无可用货物。</div>'}</div>
        </div>
        <div class="prep-pane${tab === 'gu' ? ' on' : ''}" data-pane="gu">
          <div class="pane-note">卖蛊返还价值 50%；若令杀招配方失效，会自动卸下对应杀招。</div>
          <div class="grid">${ownedGu.map(inventoryCard).join('') || '<div class="empty">蛊仓为空。</div>'}</div>
        </div>
        <div class="prep-pane${tab === 'alchemy' ? ' on' : ''}" data-pane="alchemy"><div id="prep-alchemy"></div></div>
        <div class="prep-pane${tab === 'killmove' ? ' on' : ''}" data-pane="killmove"><div id="prep-killmove"></div></div>
      </div>
    </div>`;

  renderAlchemy(root.querySelector('#prep-alchemy'));
  renderKillmove(root.querySelector('#prep-killmove'));
  root.querySelectorAll('[data-prep-tab]').forEach((button) => {
    button.addEventListener('click', () => {
      prepTab = button.dataset.prepTab;
      root.querySelectorAll('[data-prep-tab]').forEach((tabButton) => tabButton.classList.toggle('on', tabButton === button));
      root.querySelectorAll('[data-pane]').forEach((pane) => pane.classList.toggle('on', pane.dataset.pane === prepTab));
    });
  });
  root.querySelectorAll('[data-buy-offer]').forEach((button) => {
    button.addEventListener('click', () => act.buyOffer(button.dataset.buyOffer));
  });
  root.querySelectorAll('[data-sell-gu]').forEach((button) => {
    button.addEventListener('click', () => act.sellGu(button.dataset.sellGu));
  });
  root.querySelectorAll('[data-break]').forEach((button) => {
    button.addEventListener('click', () => act.breakthrough(button.dataset.break));
  });
  root.querySelector('[data-use-aptitude]')?.addEventListener('click', () => act.useAptitudeGu());
  root.querySelector('[data-prep-continue]').addEventListener('click', () => act.leavePrep());
}

function renderReward(root) {
  if (!root) return;
  const reward = state.reward;
  if (!reward) {
    root.innerHTML = '<div class="empty">当前没有待领取的战后收获。</div>';
    return;
  }
  const node = nodeById(reward.nodeId);
  const choices = (reward.guChoices || []).map((guId) => guById(guId)).filter(Boolean);
  root.innerHTML = `
    <div class="reward-sheet">
      <div class="kicker">战后结算 · 自动奖励已到账</div>
      <h1>${node ? node.name : '遭遇'} · 伏诛</h1>
      <div class="reward-lines">
        <div><span>元石</span><b>+${reward.stones}</b></div>
        <div><span>气血</span><b>+${reward.healed || 0} · 真元回满</b></div>
        ${(reward.materialIds || []).length ? `<div><span>材料</span><b>${Object.entries(countBy(reward.materialIds)).map(([id, count]) => `${materialById(id).name}×${count}`).join('、')}</b></div>` : ''}
        <div><span>回合</span><b>${reward.turn}</b></div>
      </div>
      ${choices.length ? `
        <h2>战后出蛊 · 三选一</h2>
        <div class="reward-choices">${choices.map((gu) => `
          <button data-reward-gu="${gu.id}">
            <img src="../assets/wenzhen/gu/${gu.icon}.png" alt="">
            <b>${gu.name}</b>
            <span>${gu.rank} 转 · ${schoolLabel(gu.school)}</span>
            <em>${effectText(gu.effect)}</em>
          </button>`).join('')}</div>
      ` : '<p class="muted">本次没有蛊虫掉落，直接进入统一整备。</p>'}
      ${choices.length ? '' : '<button class="primary" data-reward-continue>进入整备</button>'}
    </div>`;
  root.querySelectorAll('[data-reward-gu]').forEach((button) => {
    button.addEventListener('click', () => act.chooseRewardGu(button.dataset.rewardGu));
  });
  root.querySelector('[data-reward-continue]')?.addEventListener('click', () => act.continueReward());
}

function renderEnding(root) {
  if (!root) return;
  const ending = state.ending;
  if (!ending) {
    root.innerHTML = '<div class="empty">本局尚未结束。</div>';
    return;
  }
  const outcomeLabel = ending.outcome === 'victory' ? '胜局' : ending.outcome === 'defeat' ? '败局' : '终局';
  root.innerHTML = `
    <div class="ending-sheet">
      <div class="kicker">终局摘要 · ${outcomeLabel}</div>
      <h1>${ending.title}</h1>
      <p class="lead">${ending.detail}</p>
      <div class="ending-stats">
        <span>outcome: ${ending.outcome || 'unknown'}</span>
        <span>节点 ${state.journey.completed.length}</span>
        <span>气血 ${state.blood}</span>
        <span>元石 ${state.stones}</span>
        <span>回合 ${ending.turn || 0}</span>
      </div>
      <div class="hall-actions">
        <button class="primary" data-ending-hall>回到大厅</button>
        <button class="ghost" data-ending-restart>重新开始</button>
      </div>
    </div>`;
  root.querySelector('[data-ending-hall]').addEventListener('click', () => showPage('hall'));
  root.querySelector('[data-ending-restart]').addEventListener('click', () => act.restartRun());
}
