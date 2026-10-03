// 杀招组装。普通脚本：全局 renderKillmove。
// 名称/图标走 GU_BY_ID；variant 只对「可组或已装备」展开，避免每次整备重绘都做笛卡尔积。
function renderKillmove(root) {
  const guMap = typeof GU_BY_ID !== 'undefined' ? GU_BY_ID : Object.fromEntries(DATA.gu.map((x) => [x.id, x]));
  const nameOf = (id) => (guMap[id] && guMap[id].name) || id;
  const iconOf = (id) => {
    const g = guMap[id];
    return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
  };
  const killMoves = currentKillMoves().sort((a, b) => Number(b.playable === true) - Number(a.playable === true));
  const kmById = Object.fromEntries(killMoves.map((m) => [m.id, m]));
  const draft = Array.isArray(state.killmoveDraft) ? state.killmoveDraft : [];
  const customRecipes = Array.isArray(state.customMoveRecipes) ? state.customMoveRecipes : [];
  const customIds = new Set(customRecipes.map((recipe) => {
    const result = GuRules.composeKillMove(recipe, guMap);
    return result.ok ? result.move.id : '';
  }).filter(Boolean));
  const components = ['moonlight_gu', 'small_light_gu', 'moon_glow_gu'];
  const held = (id) => Math.max(0, Number(state.owned?.[id]) || 0);
  const draftCount = (id) => draft.filter((part) => part === id).length;

  const slots = Array.from({ length: 3 }, (_, i) => {
    const id = state.equipped[i];
    if (!id) return '<div class="slot">空</div>';
    const km = kmById[id];
    if (!km) return '<div class="slot">空</div>';
    return `<div class="slot filled" title="${km.label}">${(km.recipe[0] && `<img src="${iconOf(km.recipe[0])}" alt="">`) || km.label}</div>`;
  }).join('');

  const cards = killMoves.map((m) => {
    const can = m.playable === true && GuRules.killMoveRecipeInstances(m, state.owned, {}, {}).every(Boolean);
    const on = state.equipped.includes(m.id);
    const mats = m.recipe.map((id) =>
      `<span title="${nameOf(id)}" style="display:inline-flex;align-items:center;gap:5px;margin-right:9px">
         <img src="${iconOf(id)}" style="width:22px;height:22px;object-fit:contain">${nameOf(id)}</span>`).join('');
    const variants = (can || on)
      ? GuRules.killMoveVariants(m, state.owned, guMap).filter((v) => v.changed)
      : [];
    const variantNote = variants.length
      ? `<div class="mr" style="opacity:.85">Variant：${variants.slice(0, 2).map((v) => `${v.recipe.map(nameOf).join('+')} → ${v.signature}`).join('；')}</div>`
      : '';
    const forget = customIds.has(m.id)
      ? '<button style="margin:8px 0 0 8px" data-compose-forget="' + m.id + '">移除实验配方</button>'
      : '';
    return `<div class="move ${can ? 'ready' : ''}">
      <div class="ml">${m.label}${m.experimental ? ' · 实验同催' : ''}</div>
      <div class="mr">${mats}</div>
      <div class="me">${killMoveEffectText(m, guMap)}</div>
      ${variantNote}
      <div class="mc">真元 ${m.true_qi_cost} · 操控 ${m.thought_cost}${m.life_cost ? ` · 寿元 ${m.life_cost}` : ''}</div>
      <button style="margin-top:11px" ${can ? '' : 'disabled'} data-km="${m.id}">${on ? '卸下' : m.playable === true ? '记入杀招' : '尚未开放'}</button>${forget}
    </div>`;
  }).join('');

  const draftResult = GuRules.composeKillMove(draft, guMap);
  const rankRequired = draft.length
    ? Math.max(...draft.map((id) => Number(guMap[id]?.rank) || 1))
    : 0;
  const rankReady = rankRequired > 0 && draft.every((id) => GuRules.canActivate(state.cultivation, guMap[id]?.rank, guMap[id]?.lowRankException));
  const draftCounts = components.map((id) =>
    `<span title="${nameOf(id)}" style="display:inline-flex;align-items:center;gap:5px;margin-right:12px">
      <img src="${iconOf(id)}" style="width:22px;height:22px;object-fit:contain">${nameOf(id)} ×${held(id)}</span>`).join('');
  const addButtons = components.map((id) => {
    const disabled = draft.length >= 3 || draftCount(id) >= held(id);
    return `<button data-compose-add="${id}" ${disabled ? 'disabled' : ''}>加入 ${nameOf(id)}</button>`;
  }).join(' ');
  const selected = draft.length
    ? draft.map((id, i) => `<span style="display:inline-flex;align-items:center;gap:5px;margin:4px 8px 4px 0">
        <img src="${iconOf(id)}" style="width:22px;height:22px;object-fit:contain">${nameOf(id)}
        <button data-compose-remove="${i}" aria-label="移除第 ${i + 1} 个组件">移除</button></span>`).join('')
    : '<span class="gm">还没有选择组件。</span>';
  const draftInventoryValid = draft.length >= 2 && draft.length <= 3
    && components.every((id) => draftCount(id) <= held(id));
  const composeNotes = draftResult.ok ? draftResult.notes : [
    ...(draft.includes('small_light_gu') && !draft.includes('moonlight_gu')
      ? ['小光蛊只辅助月光蛊；配方没有月光蛊时不会增强其他组件。'] : []),
    ...(draft.filter((id) => id === 'small_light_gu').length > 1 ? ['小光蛊的同类辅助不叠加。'] : []),
  ];
  const preview = draftResult.ok
    ? `<div class="me">${killMoveEffectText(draftResult.move, guMap)}</div>
       <div class="mc">合计：真元 ${draftResult.move.true_qi_cost} · 操控 ${draftResult.move.thought_cost}${draftResult.move.life_cost ? ` · 寿元 ${draftResult.move.life_cost}` : ''} · ${rankRequired}转以上${rankReady ? '（当前可催动）' : '（当前修为不足，不能催动）'}</div>
       ${composeNotes.map((note) => `<div class="mr">${note}</div>`).join('')}`
    : `<div class="mr">${draft.length < 2 ? '请选择两个或三个组件。' : draftResult.reason === 'strike_required' ? '该实验构筑当前没有有效伤害，不能保存或催动。' : '该组合目前不能构筑。'}</div>
       ${composeNotes.map((note) => `<div class="mr">${note}</div>`).join('')}`;
  const canRemember = draftResult.ok && draftInventoryValid && !customIds.has(draftResult.move.id);

  root.innerHTML = `
    <h2>杀招槽 · 组合即用法</h2><p class="gm">凝光是月光与小光同催的实验名称；真元与操控按两只蛊合计，催动占一次行动。其他固定杀招待验证后开放。</p>
    <div class="slots">${slots}</div>
    <h2>实验构筑 · 自由同催草案</h2>
    <p class="gm">仅用月光蛊、小光蛊、月芒蛊试验组合；这是实验构筑，不代表原著已证招式。保存草案不装备，也不消耗蛊虫。</p>
    <div class="mr">当前持有：${draftCounts}</div>
    <div class="button-row" style="margin-top:10px">${addButtons}</div>
    <div class="mr" style="margin-top:10px">已选：${selected}</div>
    ${preview}
    <button style="margin-top:10px" data-compose-remember ${canRemember ? '' : 'disabled'}>${draftResult.ok && customIds.has(draftResult.move.id) ? '已保存此实验草案' : '保存实验草案'}</button>
    <h2>杀招筹备 · 组合依据与试玩适配</h2>
    <div class="moves">${cards}</div>`;
  // 点击由 journey.js 整备页事件委托收口。
}
