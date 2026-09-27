// 杀招组装。普通脚本：全局 renderKillmove。
// 名称/图标走 GU_BY_ID；variant 只对「可组或已装备」展开，避免每次整备重绘都做笛卡尔积。
function renderKillmove(root) {
  const guMap = typeof GU_BY_ID !== 'undefined' ? GU_BY_ID : Object.fromEntries(DATA.gu.map((x) => [x.id, x]));
  const nameOf = (id) => (guMap[id] && guMap[id].name) || id;
  const iconOf = (id) => {
    const g = guMap[id];
    return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
  };
  const kmById = Object.fromEntries(DATA.killMoves.map((m) => [m.id, m]));

  const slots = Array.from({ length: 3 }, (_, i) => {
    const id = state.equipped[i];
    if (!id) return '<div class="slot">空</div>';
    const km = kmById[id];
    if (!km) return '<div class="slot">空</div>';
    return `<div class="slot filled" title="${km.label}">${(km.recipe[0] && `<img src="${iconOf(km.recipe[0])}" alt="">`) || km.label}</div>`;
  }).join('');

  const cards = DATA.killMoves.map((m) => {
    const can = GuRules.killMoveRecipeInstances(m, state.owned, {}, {}).every(Boolean);
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
    return `<div class="move ${can ? 'ready' : ''}">
      <div class="ml">${m.label}</div>
      <div class="mr">${mats}</div>
      <div class="me">${killMoveEffectText(m, GU_BY_ID)}</div>
      ${variantNote}
      <div class="mc">真元 ${m.true_qi_cost} · 念头 ${m.thought_cost}${m.life_cost ? ` · 寿元 ${m.life_cost}` : ''}</div>
      <button style="margin-top:11px" ${can ? '' : 'disabled'} data-km="${m.id}">${on ? '卸下' : '记入杀招'}</button>
    </div>`;
  }).join('');

  root.innerHTML = `
    <h2>杀招槽 · 组合即用法</h2>
    <div class="slots">${slots}</div>
    <h2>可组杀招 · 配方来自原著数据表</h2>
    <div class="moves">${cards}</div>`;
  // 点击由 journey.js 整备页事件委托收口。
}
