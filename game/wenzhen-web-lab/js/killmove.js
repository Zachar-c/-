// 杀招组装。普通脚本：全局 renderKillmove。
function renderKillmove(root) {
  const nameOf = (id) => (DATA.gu.find((g) => g.id === id) || {}).name || id;
  const iconOf = (id) => {
    const g = DATA.gu.find((x) => x.id === id);
    return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
  };

  const slots = Array.from({ length: 3 }, (_, i) => {
    const id = state.equipped[i];
    if (!id) return '<div class="slot">空</div>';
    const km = DATA.killMoves.find((m) => m.id === id);
    if (!km) return '<div class="slot">空</div>';
    return `<div class="slot filled" title="${km.label}">${(km.recipe[0] && `<img src="${iconOf(km.recipe[0])}" alt="">`) || km.label}</div>`;
  }).join('');

  const cards = DATA.killMoves.map((m) => {
    const can = m.recipe.every((id) => (state.owned[id] || 0) > 0);
    const on = state.equipped.includes(m.id);
    const mats = m.recipe.map((id) =>
      `<span title="${nameOf(id)}" style="display:inline-flex;align-items:center;gap:5px;margin-right:9px">
         <img src="${iconOf(id)}" style="width:22px;height:22px;object-fit:contain">${nameOf(id)}</span>`).join('');
    return `<div class="move ${can ? 'ready' : ''}">
      <div class="ml">${m.label}</div>
      <div class="mr">${mats}</div>
      <div class="me">${effectText(m.effect)}</div>
      <div class="mc">真元 ${m.true_qi_cost} · 念头 ${m.thought_cost}${m.life_cost ? ` · 寿元 ${m.life_cost}` : ''}</div>
      <button style="margin-top:11px" ${can ? '' : 'disabled'} data-km="${m.id}">${on ? '卸下' : '记入杀招'}</button>
    </div>`;
  }).join('');

  root.innerHTML = `
    <h2>杀招槽 · 组合即用法</h2>
    <div class="slots">${slots}</div>
    <h2>可组杀招 · 配方来自原著数据表</h2>
    <div class="moves">${cards}</div>`;

  root.querySelectorAll('[data-km]').forEach((b) =>
    b.addEventListener('click', () => act.toggleMove(b.dataset.km)));
}
