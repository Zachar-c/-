// 炼蛊台。普通脚本：全局 renderAlchemy；依赖 data.js 的 DATA 与 describe.js 的 effectText/schoolLabel。
const iconOf = (id) => {
  const g = DATA.gu.find((x) => x.id === id);
  return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
};
const nameOf = (id) => (DATA.gu.find((g) => g.id === id) || {}).name || id;

function renderAlchemy(root) {
  const owned = DATA.gu.filter((g) => (state.owned[g.id] || 0) > 0);
  const cards = owned.map((g) => `
    <div class="gu ${g.rank > 1 ? 'r2' : ''}">
      <span class="cnt">×${state.owned[g.id]}</span>
      <img src="../assets/wenzhen/gu/${g.icon}.png" alt="">
      <div class="gn">${g.name}</div>
      <div class="gm">${g.rank} 转 · ${g.rarity} · ${schoolLabel(g.school)} · 值 ${g.value}</div>
      <div class="ge">${effectText(g.effect)}</div>
    </div>`).join('');

  const rows = DATA.recipes.map((r) => {
    const need = countBy(r.inputs);
    const miss = Object.entries(need).filter(([id, n]) => (state.owned[id] || 0) < n);
    const poor = (r.stoneCost || 0) > state.stones;
    const ok = !miss.length && !poor;
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
        ${r.kind === 'advance' ? '升炼' : '合炼'} · 成算 七成${r.stoneCost ? ` · 元石 ${r.stoneCost}` : ''}
        <span class="src">${src.slice(0, 96)}</span>
      </div>
      <button ${ok ? '' : 'disabled'} data-forge="${r.id}">开炉</button>
      ${ok ? '' : `<span class="gm" style="color:var(--cinnabar);font-size:11px">${poor ? '元石不足' : '材料不足'}</span>`}
    </div>`;
  }).join('');

  root.innerHTML = `
    <h2>蛊虫 · ${owned.length} 种在手</h2>
    <div class="grid">${cards}</div>
    <h2 style="margin-top:32px">炼蛊台 · 合炼与升炼</h2>
    <div class="recipes">${rows}</div>`;

  root.querySelectorAll('[data-forge]').forEach((el) =>
    el.addEventListener('click', () => act.forge(el.dataset.forge)));
}

function countBy(ids) {
  return ids.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
}
