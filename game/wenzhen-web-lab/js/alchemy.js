// 炼蛊台。普通脚本：全局 renderAlchemy；依赖 data.js 的 DATA 与 describe.js 的 effectText。
// 只渲染「炼化野生蛊」与「炼蛊台配方」两块：已炼化的蛊虫归整备页的蛊仓页签，避免两处同一份列表。
// 查找走 GU_BY_ID：配方输入多时 DATA.gu.find 是 draw 热点（O(n²)）。
const iconOf = (id) => {
  const g = (typeof GU_BY_ID !== 'undefined' && GU_BY_ID[id]) || DATA.gu.find((x) => x.id === id);
  return g ? `../assets/wenzhen/gu/${g.icon}.png` : '';
};
const nameOf = (id) => {
  const g = (typeof GU_BY_ID !== 'undefined' && GU_BY_ID[id]) || DATA.gu.find((x) => x.id === id);
  return (g && g.name) || id;
};

function renderAlchemy(root) {
  const owned = DATA.gu.filter((g) => (state.owned[g.id] || 0) > 0);
  const wild = DATA.gu.filter((g) => (state.wild[g.id] || 0) > 0);
  const guByIdMap = typeof GU_BY_ID !== 'undefined' ? GU_BY_ID : Object.fromEntries(DATA.gu.map((x) => [x.id, x]));
  const wildCards = wild.map((g) => {
    const cost = GuRules.attuneCost(g.rank);
    const affordable = state.qi >= cost;
    return `<article class="gu ${g.rank > 1 ? 'r2' : ''}">
      <span class="cnt">×${state.wild[g.id]}</span>
      <img src="../assets/wenzhen/gu/${g.icon}.png" alt="">
      <div class="gn">${g.name}</div>
      <div class="gm">${g.rank} 转 · ${GuRules.buildRoleOf(g, guByIdMap)} · 野生 · 炼化真元 ${cost}</div>
      <div class="ge">${effectText(g.effect)}</div>
      <button style="margin-top:11px" ${affordable ? '' : 'disabled'} data-attune="${g.id}">炼化</button>
      <div class="gm">${affordable ? `当前真元 ${state.qi}` : `真元不足 · 当前 ${state.qi}`}</div>
    </article>`;
  }).join('');

  const live = GuRules.liveRecipes(DATA.recipes);
  const forks = GuRules.forkGroups(DATA.recipes);
  const forkIds = new Set(forks.flatMap((f) => f.branches.map((b) => b.id)));
  const rows = live.map((r) => {
    const need = countBy(r.inputs);
    const miss = Object.entries(need).filter(([id, n]) => (state.owned[id] || 0) < n);
    const poor = (r.stoneCost || 0) > state.stones;
    const ok = !miss.length && !poor;
    const inputs = Object.entries(need).map(([id, n]) =>
      `<span style="display:inline-flex;align-items:center;gap:5px">
         <img src="${iconOf(id)}" alt="">${nameOf(id)}<span style="color:var(--cinnabar)">×${n}</span>
       </span>`).join('<span class="arrow">+</span>');
    const src = (r.source || '').replace(/^蛊真人-clean\.txt\s*/, '原文 ');
    const branch = r.branchLabel
      ? `<div class="meta" style="color:var(--cinnabar)">${r.branchLabel} · 消耗所列组件</div>`
      : '';
    return `<div class="recipe ${forkIds.has(r.id) ? 'fork-branch' : ''}">
      <div class="io">${inputs}<span class="arrow">→</span>
        <span style="display:inline-flex;align-items:center;gap:5px">
          <img src="${iconOf(r.output)}" alt="">${nameOf(r.output)}
        </span>
      </div>
      ${branch}
      ${r.inputs.some(id => guByIdMap[id]?.effect?.kind === 'body_training') ? '<div class="meta">已得肉身力量保留；投入锻体蛊后，失去该蛊继续增力的能力。</div>' : ''}
      <div class="meta">
        ${r.kind === 'advance' ? '升炼' : '合炼'} · 成算 ${r.successRollMax >= 100 ? '必成' : `${r.successRollMax}%`}${r.stoneCost ? ` · 元石 ${r.stoneCost}` : ''}
        <span class="src">${src.slice(0, 96)}</span>
      </div>
      <button ${ok ? '' : 'disabled'} data-forge="${r.id}">开炉</button>
      ${ok ? '' : `<span class="gm" style="color:var(--cinnabar);font-size:11px">${poor ? '元石不足' : '蛊虫不足'}</span>`}
    </div>`;
  }).join('');

  const forkNotes = forks.map((f) => `
    <div class="meta" style="margin:8px 0 16px;padding:8px 10px;border-left:3px solid var(--cinnabar)">
      <b>分支节点</b> · 投入 ${f.inputs.map(nameOf).join(' + ')}
      → ${f.branches.map((b) => b.branchLabel || nameOf(b.output)).join(' ／ ')}
      <div style="font-size:12px;opacity:.85">这些路线争用同一批组件；再次取得组件后，可以尝试另一条路线。</div>
    </div>`).join('');

  root.innerHTML = `
    <div class="pane-note">已在手的蛊虫见「蛊仓」页签（卖蛊也在那里）；本页把它们当作合炼与升炼的投入。</div>
    <h2 style="margin-top:22px">炼化野生蛊 · ${wild.length} 种待炼化</h2>
    <p class="lead muted">野生蛊不能催动；炼化后按实例加入已炼化蛊仓。</p>
    <div class="grid">${wildCards || '<div class="empty">暂无野生蛊。</div>'}</div>
    <h2 style="margin-top:22px">炼蛊台 · 合炼与分支 · ${owned.length} 种可作投入</h2>
    ${forkNotes}
    <div class="recipes">${rows}</div>`;
  // 点击由 journey.js 整备页事件委托收口，避免重绘后逐钮重绑。
}

function countBy(ids) {
  return ids.reduce((m, id) => ((m[id] = (m[id] || 0) + 1), m), {});
}
