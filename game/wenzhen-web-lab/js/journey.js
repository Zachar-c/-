// 路线、节点图、整备页与终局页。状态转换仍全部收口到 main.js 的 act。
const STAGE_LABEL = { one: '一转', two: '二转', three: '三转', four: '四转', five: '五转' };

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

function nodeTypeLabel(type) {
  return ({ battle: '战斗', elite: '精英', boss: '层主' }[type]) || type || '未知';
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

function segmentTitle(segment) {
  return DATA.flow.segmentTitles?.[String(segment)] || `第 ${segment} 段`;
}

function renderJourneyPages() {
  renderHall(document.querySelector('#panel-hall'));
  renderMap(document.querySelector('#panel-map'));
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
  root.innerHTML = `
    <div class="hall-grid">
      <section class="hall-main">
        <div class="eyebrow">问真 · Web 拼装局</div>
        <h1>问真</h1>
        <p class="hall-copy">固定节点图、战斗、战后三选一、统一整备。选择难度后开局；当前局面只展示可走的后续边。</p>
        <div class="difficulty-row">
          ${Object.entries(DATA.flow.difficulties).map(([key, value]) => `
            <button class="${key === difficulty ? 'on' : ''}" data-difficulty="${key}">
              <b>${value.label}</b><span>每段 ${value.prepPerSegment} 个准备节点</span>
            </button>`).join('')}
        </div>
        <div class="hall-actions">
          <button class="primary" data-start-run>${started ? '重新开局' : '开始新局'}</button>
          ${started ? '<button class="ghost" data-go-map>返回节点图</button>' : ''}
        </div>
      </section>
      <aside class="hall-side">
        <div class="kicker">当前局面</div>
        <div class="hall-big">${completed}<span>/ ${state.journey.graph.nodes.length}</span></div>
        <div class="hall-node">${currentNode() ? `${nodeTypeLabel(currentNode().type)} · ${currentNode().name}` : started ? '等待选择下一个节点' : '尚未开局'}</div>
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
      state = fresh(button.dataset.difficulty);
      draw();
    });
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
    ${selected ? `<div class="leave-row"><button class="primary" data-return-node>${state.battle ? '返回当前战斗' : state.reward ? '查看结算' : '继续整备'}</button></div>` : ''}`;

  root.querySelectorAll('[data-choose-node]').forEach((button) => {
    button.addEventListener('click', () => act.chooseNode(button.dataset.chooseNode));
  });
  root.querySelector('[data-return-node]')?.addEventListener('click', () => {
    showPage(state.battle ? 'battle' : state.reward ? 'reward' : 'prep');
  });
}

function mapNodeCard(node, selected, available, completed) {
  const isSelected = node.id === selected;
  const isAvailable = available.has(node.id);
  const isDone = completed.has(node.id);
  const stateClass = isSelected ? 'current' : isDone ? 'done' : isAvailable ? 'available' : 'locked';
  const enemies = nodeEnemyIds(node).map((id) => (enemyById(id) || {}).name || id).join('、');
  return `<article class="map-node ${stateClass}">
    <div class="rn-top"><span>${node.type === 'boss' ? '层主' : `L${node.segment} · ${node.depth + 1}`}</span><em>${nodeTypeLabel(node.type)}</em></div>
    <div class="rn-name">${node.name}</div>
    <div class="rn-enemies">${enemies || '无战斗数据'}</div>
    ${isAvailable ? `<button data-choose-node="${node.id}">进入</button>` : `<span class="rn-state">${isSelected ? '当前' : isDone ? '已过' : '未选'}</span>`}
  </article>`;
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

function inventoryCard(gu) {
  const count = Number(state.owned[gu.id] || 0);
  if (count <= 0) return '';
  const price = RunFlow.sellValue(gu.value);
  return `<article class="inventory-card">
    <img src="../assets/wenzhen/gu/${gu.icon}.png" alt="">
    <div>
      <b>${gu.name} ×${count}</b>
      <span>${gu.rank} 转 · ${schoolLabel(gu.school)} · ${effectText(gu.effect)}</span>
    </div>
    <button class="ghost" data-sell-gu="${gu.id}">卖 ${price}</button>
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
  root.innerHTML = `
    <div class="prep-head">
      <div>
        <div class="kicker">${segmentTitle(node.segment)} · ${nodeTypeLabel(node.type)} · 整备</div>
        <h2>${node.name}</h2>
      </div>
      <div class="prep-resources">
        <span>${RunFlow.stageLabel(state.cultivation, state.cultivationStage)}</span>
        <span>气血 ${state.blood}/${state.bloodMax}</span>
        <span>真元 ${state.qi}/${state.qiMax}</span>
        <span>元石 ${state.stones}</span>
      </div>
    </div>
    <div class="prep-grid">
      <section class="prep-panel">
        <div class="kicker">修炼突破</div>
        <h3>${next.kind === 'small' ? `冲击 ${next.targetLabel}` : next.kind === 'big' ? `冲击 ${next.targetRank} 转` : '五转巅峰'}</h3>
        ${next.kind === 'small' ? `
          <p>小突破消耗元石，或消耗 1 只当前转数同阶舍利蛊。</p>
          <div class="button-row">
            <button class="${next.canStone ? 'primary' : ''}" ${next.canStone ? '' : 'disabled'} data-break="stone">元石 ${next.stoneCost}</button>
            <button class="${next.canSari ? 'primary' : ''}" ${next.canSari ? '' : 'disabled'} data-break="sari">${sariName} ×1</button>
          </div>
        ` : next.kind === 'big' ? `
          <p>大突破要求资质与元石同时达标。</p>
          <div class="prep-line">资质 ${next.aptitudeOk ? '达标' : `需要 ${({ jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' })[next.requiredApt]}`}</div>
          <div class="prep-line">元石 ${next.stoneCost}</div>
          <button class="${next.ok ? 'primary' : ''}" ${next.ok ? '' : 'disabled'} data-break="stone">冲击下一转</button>
        ` : '<p>已经到达当前修炼上限。</p>'}
      </section>
      <section class="prep-panel">
        <div class="kicker">资质蛊</div>
        <h3>资质 ${({ jia: '甲等', yi: '乙等', bing: '丙等', ding: '丁等' })[state.aptitude] || state.aptitude}</h3>
        <p>使用后立即提升一档，并同步更新真元容量与恢复。</p>
        <button class="${Number(state.owned[aptId] || 0) > 0 ? 'primary' : ''}" ${Number(state.owned[aptId] || 0) > 0 ? '' : 'disabled'} data-use-aptitude>使用资质蛊 ×${Number(state.owned[aptId] || 0)}</button>
      </section>
      <section class="prep-panel wide">
        <div class="kicker">坊市 · 本节点货架</div>
        <p>本页买完即售罄，进入下一节点后刷新。</p>
        <div class="shop-grid">${offers.map(shopOfferCard).join('') || '<div class="empty">本层暂无可用货物。</div>'}</div>
      </section>
      <section class="prep-panel wide">
        <div class="kicker">蛊仓</div>
        <p>卖蛊返还价值 50%；若令杀招配方失效，会自动卸下对应杀招。</p>
        <div class="inventory-list">${DATA.gu.map(inventoryCard).join('') || '<div class="empty">蛊仓为空。</div>'}</div>
      </section>
      <section class="prep-panel wide">
        <div class="kicker">材料</div>
        <div class="inventory-list">${materials.map((material) => `<div class="material-line"><span>${material.name}</span><b>×${state.materials[material.id]}</b></div>`).join('') || '<div class="empty">暂无材料。</div>'}</div>
      </section>
    </div>
    <section class="prep-section"><div id="prep-alchemy"></div></section>
    <section class="prep-section"><div id="prep-killmove"></div></section>
    <div class="leave-row"><button class="primary" data-prep-continue>完成整备 · 选择下一个节点</button></div>`;

  renderAlchemy(root.querySelector('#prep-alchemy'));
  renderKillmove(root.querySelector('#prep-killmove'));
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
  root.innerHTML = `
    <div class="ending-sheet">
      <div class="kicker">终局归因</div>
      <h1>${ending.title}</h1>
      <p class="lead">${ending.detail}</p>
      <div class="ending-stats">
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
