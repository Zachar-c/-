// 炼蛊台。普通脚本：全局 renderAlchemy；依赖 data.js 的 DATA 与 describe.js 的 effectText。
// 只渲染「炼化野生蛊」与「炼蛊台配方」两块：已炼化的蛊虫归整备页的蛊仓页签，避免两处同一份列表。
const iconOf = (id) => {
  const g = DATA.gu.find((x) => x.id === id);
  return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
};
const nameOf = (id) => (DATA.gu.find((g) => g.id === id) || {}).name || id;

function renderAlchemy(root) {
  const owned = DATA.gu.filter((g) => (state.owned[g.id] || 0) > 0);
  const wild = DATA.gu.filter((g) => (state.wild[g.id] || 0) > 0);
  const wildCards = wild.map((g) => {
    const cost = GuRules.attuneCost(g.rank);
    const affordable = state.qi >= cost;
    return `<article class="gu ${g.rank > 1 ? 'r2' : ''}">
      <span class="cnt">×${state.wild[g.id]}</span>
      <img src="../assets/wenzhen/gu/${g.icon}.png" alt="">
      <div class="gn">${g.name}</div>
      <div class="gm">${g.rank} 转 · 野生 · 炼化真元 ${cost}</div>
      <div class="ge">${effectText(g.effect)}</div>
      <button style="margin-top:11px" ${affordable ? '' : 'disabled'} data-attune="${g.id}">炼化</button>
      <div class="gm">${affordable ? `当前真元 ${state.qi}` : `真元不足 · 当前 ${state.qi}`}</div>
    </article>`;
  }).join('');

  const rows = DATA.recipes.map((r) => {
    const need = countBy(r.inputs);
    const miss = Object.entries(need).filter(([id, n]) => (state.owned[id] || 0) < n);
    const materialNeed = r.materials || {};
    const materialMiss = Object.entries(materialNeed).filter(([id, n]) => (state.materials[id] || 0) < n);
    const poor = (r.stoneCost || 0) > state.stones;
    const ok = !miss.length && !materialMiss.length && !poor;
    const inputs = Object.entries(need).map(([id, n]) =>
      `<span style="display:inline-flex;align-items:center;gap:5px">
         <img src="${iconOf(id)}" alt="">${nameOf(id)}<span style="color:var(--cinnabar)">×${n}</span>
       </span>`).join('<span class="arrow">+</span>');
    const src = (r.source || '').replace(/^蛊真人-clean\.txt\s*/, '原文 ');
    return `<div class="recipe">
      <div class="io">${inputs}<span class="arrow">→</span>
        <span style="display:inline-flex;align-items:center;gap:5px">
          <img src="${iconOf(r.output)}" alt="">${nameOf(r.output)}
        </span>
      </div>
      <div class="meta">
        ${r.kind === 'advance' ? '升炼' : '合炼'} · 成算 ${r.successRollMax >= 100 ? '必成' : `${r.successRollMax}%`}${r.stoneCost ? ` · 元石 ${r.stoneCost}` : ''}
        ${Object.keys(materialNeed).length ? ` · ${Object.entries(materialNeed).map(([id, n]) => `${materialById(id).name}×${n}`).join('、')}` : ''}
        <span class="src">${src.slice(0, 96)}</span>
      </div>
      <button ${ok ? '' : 'disabled'} data-forge="${r.id}">开炉</button>
      ${ok ? '' : `<span class="gm" style="color:var(--cinnabar);font-size:11px">${poor ? '元石不足' : '材料不足'}</span>`}
    </div>`;
  }).join('');

  root.innerHTML = `
    <div class="pane-note">已在手的蛊虫见「蛊仓」页签（卖蛊也在那里）；本页把它们当作合炼与升炼的投入。</div>
    <h2 style="margin-top:22px">炼化野生蛊 · ${wild.length} 种待炼化</h2>
    <p class="lead muted">野生蛊不能催动；炼化后按实例加入已炼化蛊仓。</p>
    <div class="grid">${wildCards || '<div class="empty">暂无野生蛊。</div>'}</div>
    <h2 style="margin-top:22px">炼蛊台 · 合炼与升炼 · ${owned.length} 种可作投入</h2>
    <div class="recipes">${rows}</div>`;

  root.querySelectorAll('[data-forge]').forEach((el) =>
    el.addEventListener('click', () => act.forge(el.dataset.forge)));
  root.querySelectorAll('[data-attune]').forEach((el) =>
    el.addEventListener('click', () => act.attuneGu(el.dataset.attune)));
}

function countBy(ids) {
  return ids.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
}
